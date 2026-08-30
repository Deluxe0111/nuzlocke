return function(mod, deps)
  deps=deps or {}
  -- 2.5.78: a shadow store gives schema migrators a read/write surface with
  -- mod.save semantics while keeping the real save untouched.  Every touched
  -- key retains both its pre-migration state and intended post-migration state
  -- so the same write set can power dry-run diagnostics and atomic-ish commit.
  -- Structural equality for serialized save values. Lua table equality is
  -- identity-based, but migration dry-runs need value equality so a touched
  -- table that is written back unchanged does not produce a false diff.
  local function shadowValuesEqual(a, b, seen)
      if rawequal(a, b) then return true end
      if type(a) ~= type(b) then return false end
      if type(a) ~= "table" then return a == b end

      seen = seen or {}
      local byLeft = seen[a]
      if byLeft ~= nil and byLeft[b] then return true end
      if byLeft == nil then
          byLeft = {}
          seen[a] = byLeft
      end
      byLeft[b] = true

      for key, value in pairs(a) do
          if not shadowValuesEqual(value, b[key], seen) then return false end
      end
      for key in pairs(b) do
          if a[key] == nil and b[key] ~= nil then return false end
      end
      return true
  end

  -- Presence and value are separate facts. Lua's `and/or` conditional idiom
  -- cannot represent a present literal false, so transaction/migration
  -- snapshots must select values explicitly.
  local function copyPresentValue(present, value)
      if present ~= true then return nil end
      return deps.copy(value)
  end

  mod.exports.__beta26.saveUpgrade.newShadowStore = function(baseStore)
      baseStore = baseStore or mod.save
      local entries, order = {}, {}
      local shadow = {}
      function shadow:get(key, fallback)
          local row = entries[key]
          if row ~= nil then
              if row.after_present then return deps.copy(row.after_value) end
              return deps.copy(fallback)
          end
          return deps.copy(baseStore:get(key, fallback))
      end
      function shadow:set(key, value)
          local row = entries[key]
          if row == nil then
              local sentinel = {}
              local before = baseStore:get(key, sentinel)
              row = {
                  key = key,
                  before_present = before ~= sentinel,
                  before_value = copyPresentValue(before ~= sentinel, before),
              }
              entries[key] = row
              order[#order + 1] = key
          end
          row.after_present = value ~= nil
          row.after_value = deps.copy(value)
          return true
      end
      function shadow:changes()
          -- Commit ordinary migration writes first, then the human-readable
          -- checkpoint, and the schema marker LAST.  That ordering is the
          -- transaction boundary: seeing target schema on the next load means
          -- every earlier write in this transition reached mod.save.
          table.sort(order, function(a, b)
              local ar = a == deps.SAVE_SCHEMA_KEY and 3
                  or (a == deps.SAVE_MIGRATION_KEY and 2 or 1)
              local br = b == deps.SAVE_SCHEMA_KEY and 3
                  or (b == deps.SAVE_MIGRATION_KEY and 2 or 1)
              if ar ~= br then return ar < br end
              return tostring(a) < tostring(b)
          end)
          local out = {}
          for _, key in ipairs(order) do
              local row = entries[key]
              local changed = row.before_present ~= row.after_present
                  or (row.before_present and row.after_present
                      and not shadowValuesEqual(row.before_value, row.after_value))
              if changed then
                  out[#out + 1] = {
                      key = row.key,
                      before_present = row.before_present == true,
                      before_value = deps.copy(row.before_value),
                      after_present = row.after_present == true,
                      after_value = deps.copy(row.after_value),
                  }
              end
          end
          return out
      end
      return shadow
  end

  ---------------------------------------------------------------------
  -- GAMEPLAY TRANSACTION COORDINATOR v1 (2.6.57)
  --
  -- Durable intent -> perform -> commit -> clear orchestration for gameplay
  -- mutations that need exactly-once recovery across save/reload interruption.
  -- The coordinator serializes one pending mutation at a time, retains bounded
  -- committed receipts so a stable transaction id cannot replay, and requires
  -- each mutation kind to provide a reconciliation probe.  That probe is what
  -- makes the dangerous "mutation happened, journal did not advance" window
  -- recoverable without guessing.
  ---------------------------------------------------------------------
  local TX = {
      api = 1,
      storage_key = "__nuzlocke_gameplay_txn_v1",
      receipts_key = "__nuzlocke_gameplay_txn_receipts_v1",
      receipt_limit = 96,
      handlers = {},
  }
  mod.exports.__beta26.GameplayTransactions = TX

  local function txStore(opts)
      return type(opts) == "table" and opts.store or mod.save
  end

  local function txGet(store, key, fallback)
      if type(store) ~= "table" or type(store.get) ~= "function" then
          return fallback
      end
      return store:get(key, fallback)
  end

  local function txSet(store, key, value)
      if type(store) ~= "table" or type(store.set) ~= "function" then
          return false, "store_unavailable"
      end
      local ok, result = pcall(store.set, store, key, value)
      if not ok then return false, tostring(result) end
      if result == false then return false, "store_rejected_write" end
      return true
  end

  local function txReceipts(store)
      local root = txGet(store, TX.receipts_key, {})
      if type(root) ~= "table" then root = {} end
      if type(root.order) ~= "table" then root.order = {} end
      if type(root.by_id) ~= "table" then root.by_id = {} end
      return root
  end

  local function txReceipt(store, id)
      local root = txReceipts(store)
      return root.by_id[tostring(id or "")]
  end

  -- 2.8.73: transaction identity is (id, kind, payload), not merely (id, kind).
  -- Pending journals can compare their serialized payload structurally; durable
  -- receipts keep a compact deterministic fingerprint so a reused ID cannot
  -- silently authorize a different same-kind mutation. Legacy receipts created
  -- before 2.8.73 have no fingerprint and remain readable for compatibility.
  local function txPayloadFingerprint(value)
      local chunks = {}
      local function push(token) chunks[#chunks + 1] = token end
      local function encode(v, seen)
          local t = type(v)
          if t == "nil" then push("n;"); return end
          if t == "boolean" then push(v and "b1;" or "b0;"); return end
          if t == "number" then push("d" .. string.format("%.17g", v) .. ";"); return end
          if t == "string" then
              push("s" .. tostring(#v) .. ":" .. v .. ";")
              return
          end
          if t ~= "table" then
              push("x" .. t .. ":" .. tostring(v) .. ";")
              return
          end
          seen = seen or {}
          if seen[v] then
              -- Save payloads are expected to be acyclic. Encode a stable cycle
              -- marker instead of recursing forever if a malformed caller errs.
              push("c;")
              return
          end
          seen[v] = true
          local keys = {}
          for key in pairs(v) do keys[#keys + 1] = key end
          table.sort(keys, function(a, b)
              local ta, tb = type(a), type(b)
              if ta ~= tb then return ta < tb end
              return tostring(a) < tostring(b)
          end)
          push("t" .. tostring(#keys) .. "{")
          for _, key in ipairs(keys) do
              encode(key, seen)
              encode(v[key], seen)
          end
          push("};")
          seen[v] = nil
      end
      encode(type(value) == "table" and value or {}, {})
      local text = table.concat(chunks)
      local h1, h2 = 5381, 2166136261
      for i = 1, #text do
          local byte = text:byte(i)
          h1 = (h1 * 33 + byte) % 2147483647
          h2 = (h2 * 16777619 + byte) % 4294967291
      end
      return string.format("%08x:%08x:%d", h1, h2, #text)
  end

  -- Durable monotonic attempt identities share the receipt store so they are
  -- outside gameplay objects and survive reloads without adding a second save
  -- key. Gaps are acceptable; sequence reuse is not.
  function TX.nextSequence(namespace, opts)
      local store = txStore(opts)
      namespace = tostring(namespace or "")
      if namespace == "" then return nil, "missing_namespace" end
      local root = txReceipts(store)
      if type(root.sequences) ~= "table" then root.sequences = {} end
      local previous = math.floor(tonumber(root.sequences[namespace]) or 0)
      local nextValue = previous + 1
      if nextValue <= 0 then return nil, "sequence_overflow" end
      root.sequences[namespace] = nextValue
      local ok, err = txSet(store, TX.receipts_key, root)
      if not ok then return nil, err end
      return nextValue
  end

  local function txAddReceipt(store, txn)
      local root = txReceipts(store)
      local id = tostring(txn and txn.id or "")
      if id == "" then return false, "missing_id" end
      if root.by_id[id] == nil then root.order[#root.order + 1] = id end
      root.by_id[id] = {
          id = id, kind = tostring(txn.kind or "unknown"),
          payload_fingerprint = tostring(txn.payload_fingerprint
              or txPayloadFingerprint(txn.payload)),
          build = tostring(mod.exports.__beta26.build), state = "committed",
      }
      while #root.order > TX.receipt_limit do
          local old = table.remove(root.order, 1)
          if old ~= id then root.by_id[old] = nil end
      end
      return txSet(store, TX.receipts_key, root)
  end

  function TX.register(kind, handler)
      kind = tostring(kind or "")
      if kind == "" or type(handler) ~= "table"
          or type(handler.probe) ~= "function"
          or type(handler.perform) ~= "function" then
          return false, "invalid_handler"
      end
      TX.handlers[kind] = handler
      return true
  end

  function TX.pending(opts)
      local row = txGet(txStore(opts), TX.storage_key, nil)
      return type(row) == "table" and deps.copy(row) or nil
  end

  function TX.begin(id, kind, payload, opts)
      local store = txStore(opts)
      id, kind = tostring(id or ""), tostring(kind or "")
      if id == "" then return false, "missing_id" end
      if kind == "" then return false, "missing_kind" end
      local requestedPayload = type(payload) == "table" and payload or {}
      local requestedFingerprint = txPayloadFingerprint(requestedPayload)
      local receipt = txReceipt(store, id)
      if type(receipt) == "table" then
          if tostring(receipt.kind or "") ~= kind then
              return false, "receipt_kind_mismatch"
          end
          local receiptFingerprint = receipt.payload_fingerprint
          if receiptFingerprint ~= nil
              and tostring(receiptFingerprint) ~= requestedFingerprint then
              return false, "receipt_payload_mismatch"
          end
          return false, "already_committed"
      end
      local current = txGet(store, TX.storage_key, nil)
      if type(current) == "table" then
          if tostring(current.id or "") == id
              and tostring(current.kind or "") == kind then
              if current.payload_fingerprint ~= nil then
                  if tostring(current.payload_fingerprint)
                      ~= requestedFingerprint then
                      return false, "transaction_payload_mismatch"
                  end
              elseif not shadowValuesEqual(
                  type(current.payload) == "table" and current.payload or {},
                  requestedPayload) then
                  -- Legacy pre-2.8.73 journals have no immutable request
                  -- fingerprint, so structural equality is the best exact
                  -- evidence available until that transaction finishes.
                  return false, "transaction_payload_mismatch"
              end
              return true, deps.copy(current)
          end
          return false, "busy"
      end
      local txn = {
          version = TX.api, id = id, kind = kind, state = "intent",
          payload = deps.copy(requestedPayload),
          payload_fingerprint = requestedFingerprint,
          build = tostring(mod.exports.__beta26.build),
      }
      local ok, err = txSet(store, TX.storage_key, txn)
      if not ok then return false, err end
      return true, deps.copy(txn)
  end

  local function txValidateMutableJournal(txn, id)
      if type(txn) ~= "table" then return false, "missing_transaction" end
      if tostring(txn.id or "") ~= tostring(id or "") then
          return false, "transaction_mismatch"
      end
      if tonumber(txn.version) ~= TX.api then
          return false, "newer_transaction"
      end
      return true
  end

  function TX.advance(id, state, detail, opts)
      local store = txStore(opts)
      local txn = txGet(store, TX.storage_key, nil)
      local valid, validErr = txValidateMutableJournal(txn, id)
      if not valid then return false, validErr end
      txn.state = tostring(state or txn.state or "intent")
      txn.detail = detail and tostring(detail) or nil
      local ok, err = txSet(store, TX.storage_key, txn)
      if not ok then return false, err end
      return true, deps.copy(txn)
  end

  -- Persist transaction-specific reconciliation evidence while retaining the
  -- current journal state.  Handlers use this for checkpoints that must exist
  -- before a second, separately recoverable mutation is attempted.
  function TX.checkpoint(id, key, value, opts)
      local store = txStore(opts)
      local txn = txGet(store, TX.storage_key, nil)
      local valid, validErr = txValidateMutableJournal(txn, id)
      if not valid then return false, validErr end
      key = tostring(key or "")
      if key == "" then return false, "missing_checkpoint_key" end
      if type(txn.payload) ~= "table" then txn.payload = {} end
      txn.payload[key] = deps.copy(value)
      local ok, err = txSet(store, TX.storage_key, txn)
      if not ok then return false, err end
      return true, deps.copy(txn)
  end

  function TX.clear(id, opts)
      local store = txStore(opts)
      local txn = txGet(store, TX.storage_key, nil)
      if type(txn) ~= "table" then return true end
      if id == nil then
          -- Even broad cleanup must not delete a journal from a newer
          -- transaction schema that this build cannot safely interpret.
          if tonumber(txn.version) ~= TX.api then
              return false, "newer_transaction"
          end
      else
          local valid, validErr = txValidateMutableJournal(txn, id)
          if not valid then return false, validErr end
      end
      return txSet(store, TX.storage_key, nil)
  end

  local function txProbe(handler, payload, txn, opts)
      local ok, result, detail = pcall(handler.probe, payload, txn, opts)
      if not ok then return nil, "probe_error:" .. tostring(result) end
      if result == true or result == "applied" then return "applied", detail end
      if result == false or result == "not_applied" then return "not_applied", detail end
      return "unknown", detail
  end

  function TX.execute(id, kind, payload, opts)
      opts = type(opts) == "table" and opts or {}
      local store = txStore(opts)
      -- 2.7.1: a durable committed receipt is authoritative even if the
      -- transaction handler no longer exists in this build. A crash can occur
      -- after the receipt is persisted but before the matching journal is
      -- cleared; requiring a handler first would turn a proven completed
      -- transaction into a false save-blocking handler_unavailable failure.
      local receipt = txReceipt(store, id)
      if type(receipt) == "table" then
          local requestedKind = tostring(kind or "")
          if tostring(receipt.kind or "") ~= requestedKind then
              return false, "receipt_kind_mismatch"
          end
          local receiptFingerprint = receipt.payload_fingerprint
          if receiptFingerprint ~= nil
              and tostring(receiptFingerprint) ~= txPayloadFingerprint(
                  type(payload) == "table" and payload or {}) then
              return false, "receipt_payload_mismatch"
          end
          local leftover = txGet(store, TX.storage_key, nil)
          if type(leftover) == "table"
              and tostring(leftover.id or "") == tostring(id)
              and tostring(leftover.kind or "") == requestedKind then
              local clearOk, clearErr = TX.clear(id, opts)
              if not clearOk then return false, clearErr end
          end
          return true, "already_committed"
      end
      local handler = TX.handlers[tostring(kind or "")]
      if type(handler) ~= "table" then return false, "handler_unavailable" end
      local okBegin, txn = TX.begin(id, kind, payload, opts)
      if not okBegin then
          if txn == "already_committed" then return true, txn end
          return false, txn
      end
      txn = txGet(store, TX.storage_key, txn)
      if type(txn) ~= "table" then return false, "journal_missing_after_begin" end
      -- Every coordinator entry point owns the same forward-version boundary.
      -- Do not reinterpret a future journal using this build's transaction
      -- state/payload semantics, even when execute() is called directly.
      if tonumber(txn.version) ~= TX.api then
          return false, "newer_transaction"
      end

      if txn.state == "intent" then
          local status, probeDetail = txProbe(handler, txn.payload, txn, opts)
          if status == nil then return false, probeDetail end
          if status == "unknown" then
              TX.advance(id, "intent", "reconciliation_unknown", opts)
              return false, "reconciliation_unknown"
          end
          if status == "not_applied" then
              local okPerform, performResult, performDetail =
                  pcall(handler.perform, txn.payload, txn, opts)
              if not okPerform then
                  return false, "perform_error:" .. tostring(performResult)
              end
              if performResult == false then
                  return false, tostring(performDetail or "perform_rejected")
              end
              -- 2.7.9: handler success is not proof that the durable mutation
              -- reached its declared final state. Reload the journal so any
              -- checkpoints written by perform() are visible, then require
              -- the same reconciliation probe to prove APPLIED before a
              -- performed/committed receipt can ever be minted.
              txn = txGet(store, TX.storage_key, txn)
              if type(txn) ~= "table" then
                  return false, "journal_missing_after_perform"
              end
              local verified, verifyDetail =
                  txProbe(handler, txn.payload, txn, opts)
              if verified == nil then return false, verifyDetail end
              if verified ~= "applied" then
                  return false, verified == "unknown"
                      and "post_perform_reconciliation_unknown"
                      or "post_perform_not_applied"
              end
              probeDetail = verifyDetail or performDetail or probeDetail
          end
          local advanced, advanceErr = TX.advance(id, "performed", probeDetail, opts)
          if not advanced then return false, advanceErr end
          txn = txGet(store, TX.storage_key, txn)
      end

      if txn.state == "performed" then
          -- COMMIT is deliberately a durable journal state, not a second
          -- arbitrary callback.  All externally visible mutation belongs in
          -- perform() and must be detectable by probe(); otherwise exactly-once
          -- recovery across interruption cannot be proven.
          local advanced, advanceErr = TX.advance(id, "committed", nil, opts)
          if not advanced then return false, advanceErr end
          txn = txGet(store, TX.storage_key, txn)
      end

      if txn.state == "committed" then
          local receiptOk, receiptErr = txAddReceipt(store, txn)
          if not receiptOk then return false, receiptErr end
          local clearOk, clearErr = TX.clear(id, opts)
          if not clearOk then return false, clearErr end
          return true, "committed"
      end
      return false, "invalid_state:" .. tostring(txn.state)
  end

  function TX.recover(opts)
      opts = type(opts) == "table" and opts or {}
      local txn = txGet(txStore(opts), TX.storage_key, nil)
      if type(txn) ~= "table" then return true, "clean" end
      if tonumber(txn.version) ~= TX.api then return false, "newer_transaction" end
      -- TX.execute resolves the durable receipt before consulting the current
      -- handler table. This lets a receipt-proven completed transaction clean
      -- up a stale journal even if its historical handler was later retired.
      return TX.execute(txn.id, txn.kind, txn.payload, opts)
  end

  function TX.status(opts)
      local store = txStore(opts)
      local pending = txGet(store, TX.storage_key, nil)
      local receipts = txReceipts(store)
      local handlerCount = 0
      for _ in pairs(TX.handlers) do handlerCount = handlerCount + 1 end
      return {
          api = TX.api, pending = type(pending) == "table" and deps.copy(pending) or nil,
          receipt_count = #receipts.order, handler_count = handlerCount,
      }
  end

  -- Generic durable exact-value mutation.  Higher-level transaction owners can
  -- build on this without serializing Lua functions into the save journal.
  TX.register("save.set_exact", {
      probe = function(payload, txn, opts)
          local store = txStore(opts)
          local sentinel = {}
          local current = txGet(store, payload.key, sentinel)
          if payload.after_present == false then
              if current == sentinel then return "applied" end
          elseif current ~= sentinel and shadowValuesEqual(current, payload.after_value) then
              return "applied"
          end
          if payload.before_present == false then
              if current == sentinel then return "not_applied" end
          elseif current ~= sentinel and shadowValuesEqual(current, payload.before_value) then
              return "not_applied"
          end
          return "unknown"
      end,
      perform = function(payload, txn, opts)
          return txSet(txStore(opts), payload.key,
              copyPresentValue(payload.after_present ~= false, payload.after_value))
      end,
  })

  function TX.setExact(id, key, value, opts)
      local store = txStore(opts)
      local sentinel = {}
      local before = txGet(store, key, sentinel)
      return TX.execute(id, "save.set_exact", {
          key = tostring(key),
          before_present = before ~= sentinel,
          before_value = copyPresentValue(before ~= sentinel, before),
          after_present = value ~= nil,
          after_value = deps.copy(value),
      }, opts)
  end

  -- Pure in-memory interruption harness.  It simulates the critical window in
  -- which the side effect happened but the journal still says INTENT, then
  -- verifies recovery commits exactly once and a replay of the same id is a
  -- no-op.  No live save keys are touched.
  function TX.selfTest()
      local data = {}
      local store = {}
      function store:get(key, fallback)
          local value = data[key]
          if value == nil then return fallback end
          return deps.copy(value)
      end
      function store:set(key, value)
          data[key] = deps.copy(value)
          return true
      end
      -- 2.8.77: shadow reads must never expose the journal's staged table
      -- by reference. Mutating a fetched value without shadow:set() must leave
      -- the staged value and its nested children unchanged.
      local shadowBaseData = {}
      local shadowBase = {}
      function shadowBase:get(key, fallback)
          local value = shadowBaseData[key]
          if value == nil then return fallback end
          return deps.copy(value)
      end
      function shadowBase:set(key, value)
          shadowBaseData[key] = deps.copy(value)
          return true
      end
      local shadow = mod.exports.__beta26.saveUpgrade.newShadowStore(shadowBase)
      shadow:set("selftest_shadow_copy", { value=1, nested={ value=2 } })
      local shadowRead = shadow:get("selftest_shadow_copy", {})
      shadowRead.value = 99
      shadowRead.nested.value = 88
      local shadowReadAgain = shadow:get("selftest_shadow_copy", {})
      local shadowCopyIsolation = type(shadowReadAgain) == "table"
          and shadowReadAgain.value == 1
          and type(shadowReadAgain.nested) == "table"
          and shadowReadAgain.nested.value == 2

      local applied = 0
      TX.register("__selftest_once", {
          probe = function(payload)
              return data.effect == payload.token and "applied" or "not_applied"
          end,
          perform = function(payload)
              applied = applied + 1
              data.effect = payload.token
              return true
          end,
      })
      local opts = { store = store }
      local okBegin = TX.begin("selftest:interrupted", "__selftest_once",
          { token="A" }, opts)
      if not okBegin then return { ok=false, failures={"begin"} } end
      -- Simulate side effect completed immediately before interruption.
      data.effect = "A"
      local okRecover = TX.recover(opts)
      local okReplay, replay = TX.execute("selftest:interrupted", "__selftest_once",
          { token="A" }, opts)
      local okFresh = TX.execute("selftest:fresh", "__selftest_once",
          { token="B" }, opts)
      -- Same ID/kind with a different requested payload must not inherit the
      -- committed receipt for token B.
      local receiptPayloadOk, receiptPayloadReason = TX.execute(
          "selftest:fresh", "__selftest_once", { token="DIFFERENT" }, opts)
      -- Simulate receipt persisted but journal-clear interrupted.
      txSet(store, TX.storage_key, {
          version=1, id="selftest:fresh", kind="__selftest_once",
          state="committed", payload={ token="B" },
      })
      local savedSelfTestHandler = TX.handlers.__selftest_once
      TX.handlers.__selftest_once = nil
      local okReceiptCleanup, receiptCleanup = TX.recover(opts)
      TX.handlers.__selftest_once = savedSelfTestHandler
      -- Same-tick clobber protection: a different transaction cannot begin
      -- while another intent owns the single durable journal.
      local okBusyBegin = TX.begin("selftest:busy-a", "__selftest_once",
          { token="C" }, opts)
      local sameIdPayloadOk, sameIdPayloadReason = TX.begin(
          "selftest:busy-a", "__selftest_once", { token="DIFFERENT" }, opts)
      local okBusySecond, busyReason = TX.begin("selftest:busy-b", "__selftest_once",
          { token="D" }, opts)
      TX.clear("selftest:busy-a", opts)
      local okCheckpointBegin = TX.begin("selftest:checkpoint", "__selftest_once",
          { token="E" }, opts)
      local okCheckpoint = okCheckpointBegin and TX.checkpoint(
          "selftest:checkpoint", "native_effect_returned", true, opts)
      local checkpointed = TX.pending(opts)
      -- Checkpoint fields mutate the working payload, but a legitimate replay
      -- with the original request payload must still match its immutable
      -- request fingerprint.
      local checkpointReplayOk = TX.begin(
          "selftest:checkpoint", "__selftest_once", { token="E" }, opts)
      TX.clear("selftest:checkpoint", opts)
      local seq1 = TX.nextSequence("selftest_attempts", opts)
      local seq2 = TX.nextSequence("selftest_attempts", opts)
      TX.register("__selftest_unverified", {
          probe = function() return "not_applied" end,
          perform = function() return true end,
      })
      local unverifiedOk, unverifiedReason = TX.execute(
          "selftest:unverified", "__selftest_unverified", {}, opts)
      local unverifiedReceipt = txReceipt(store, "selftest:unverified")
      TX.clear("selftest:unverified", opts)
      TX.handlers.__selftest_unverified = nil

      local futureTxn = {
          version = TX.api + 1,
          id = "selftest:future",
          kind = "__selftest_once",
          state = "intent",
          payload = {},
      }
      local futureWriteOk = txSet(store, TX.storage_key, futureTxn)
      local futureOk, futureReason =
          TX.execute("selftest:future", "__selftest_once", {}, opts)
      local futureAfterExecute = txGet(store, TX.storage_key, nil)

      local futureAdvanceOk, futureAdvanceReason =
          TX.advance("selftest:future", "performed", "must_not_write", opts)
      local futureAfterAdvance = txGet(store, TX.storage_key, nil)

      local futureCheckpointOk, futureCheckpointReason =
          TX.checkpoint("selftest:future", "must_not_write", true, opts)
      local futureAfterCheckpoint = txGet(store, TX.storage_key, nil)

      local futureClearOk, futureClearReason =
          TX.clear("selftest:future", opts)
      local futureAfterClear = txGet(store, TX.storage_key, nil)

      local futureBroadClearOk, futureBroadClearReason =
          TX.clear(nil, opts)
      local futureAfterBroadClear = txGet(store, TX.storage_key, nil)

      -- Test-only cleanup: current code must preserve the opaque future
      -- journal, so the harness removes it directly before later cases.
      txSet(store, TX.storage_key, nil)

      -- A receipt for one transaction kind must never authorize or clear a
      -- different pending kind merely because an ID collided.
      local collisionReceipt = txReceipts(store)
      collisionReceipt.by_id["selftest:collision"] = {
          id = "selftest:collision", kind = "__selftest",
          build = "selftest", state = "committed",
      }
      collisionReceipt.order[#collisionReceipt.order + 1] =
          "selftest:collision"
      local collisionReceiptOk =
          txSet(store, TX.receipts_key, collisionReceipt)
      local collisionPending = {
          version = TX.api, id = "selftest:collision",
          kind = "__selftest_other", state = "intent", payload = {},
      }
      local collisionPendingOk =
          txSet(store, TX.storage_key, collisionPending)
      local collisionOk, collisionReason = TX.execute(
          "selftest:collision", "__selftest_other", {}, opts)
      local collisionStillPending =
          txGet(store, TX.storage_key, nil)
      TX.clear("selftest:collision", opts)

      local ok = shadowCopyIsolation == true
          and okRecover == true and okReplay == true
          and replay == "already_committed" and okFresh == true and applied == 1
          and receiptPayloadOk == false
          and receiptPayloadReason == "receipt_payload_mismatch"
          and sameIdPayloadOk == false
          and sameIdPayloadReason == "transaction_payload_mismatch"
          and checkpointReplayOk == true
          and okReceiptCleanup == true and receiptCleanup == "already_committed"
          and txGet(store, TX.storage_key, nil) == nil
          and okBusyBegin == true and okBusySecond == false and busyReason == "busy"
          and okCheckpoint == true and checkpointed
          and checkpointed.payload and checkpointed.payload.native_effect_returned == true
          and seq1 == 1 and seq2 == 2
          and unverifiedOk == false
          and unverifiedReason == "post_perform_not_applied"
          and unverifiedReceipt == nil
          and futureWriteOk == true
          and futureOk == false
          and futureReason == "newer_transaction"
          and type(futureAfterExecute) == "table"
          and tonumber(futureAfterExecute.version) == TX.api + 1
          and futureAdvanceOk == false
          and futureAdvanceReason == "newer_transaction"
          and type(futureAfterAdvance) == "table"
          and tostring(futureAfterAdvance.state or "") == "intent"
          and futureCheckpointOk == false
          and futureCheckpointReason == "newer_transaction"
          and type(futureAfterCheckpoint) == "table"
          and type(futureAfterCheckpoint.payload) == "table"
          and futureAfterCheckpoint.payload.must_not_write == nil
          and futureClearOk == false
          and futureClearReason == "newer_transaction"
          and type(futureAfterClear) == "table"
          and futureBroadClearOk == false
          and futureBroadClearReason == "newer_transaction"
          and type(futureAfterBroadClear) == "table"
          and collisionReceiptOk == true
          and collisionPendingOk == true
          and collisionOk == false
          and collisionReason == "receipt_kind_mismatch"
          and type(collisionStillPending) == "table"
          and tostring(collisionStillPending.kind or "") == "__selftest_other"
      TX.handlers.__selftest_once = nil
      return { ok=ok, failures=ok and {} or {"exactly_once_recovery"},
          applied=applied, replay=tostring(replay), busy=tostring(busyReason),
          receipt_payload=tostring(receiptPayloadReason),
          pending_payload=tostring(sameIdPayloadReason),
          checkpoint_replay=tostring(checkpointReplayOk),
          receipt_cleanup=tostring(receiptCleanup),
          checkpoint=tostring(okCheckpoint), sequence=tostring(seq1) .. ":" .. tostring(seq2),
          unverified=tostring(unverifiedReason),
          shadow_copy_isolation=tostring(shadowCopyIsolation),
          future=tostring(futureReason),
          future_advance=tostring(futureAdvanceReason),
          future_checkpoint=tostring(futureCheckpointReason),
          future_clear=tostring(futureClearReason),
          future_broad_clear=tostring(futureBroadClearReason),
          collision=tostring(collisionReason) }
  end

  return mod.exports.__beta26.saveUpgrade.newShadowStore
end
