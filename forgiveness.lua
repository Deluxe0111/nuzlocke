-- Module owner: Forgiveness
return function(mod, deps)
  deps = deps or {}
  local Strings = assert(deps.Strings, "forgiveness requires Strings")
  local Identity = assert(deps.Identity, "forgiveness requires Identity")
  local ROUTE_ORDER = assert(deps.ROUTE_ORDER, "forgiveness requires ROUTE_ORDER")
  local areaKey = assert(deps.areaKey, "forgiveness requires areaKey")
  local caughtAreas = assert(deps.caughtAreas, "forgiveness requires caughtAreas")
  local defaultRuleValue = assert(deps.defaultRuleValue, "forgiveness requires defaultRuleValue")
  local ensurePokemonIdentity = assert(deps.ensurePokemonIdentity, "forgiveness requires ensurePokemonIdentity")
  local getDisplayRoutes = assert(deps.getDisplayRoutes, "forgiveness requires getDisplayRoutes")
  local isTrackedArea = assert(deps.isTrackedArea, "forgiveness requires isTrackedArea")
  local marqueeText = assert(deps.marqueeText, "forgiveness requires marqueeText")
  local pokemonIdentity = assert(deps.pokemonIdentity, "forgiveness requires pokemonIdentity")
  local routeKey = assert(deps.routeKey, "forgiveness requires routeKey")
  local routeName = assert(deps.routeName, "forgiveness requires routeName")
  local syncCaughtAreasFromLog = assert(deps.syncCaughtAreasFromLog, "forgiveness requires syncCaughtAreasFromLog")
  local trackerLog = assert(deps.trackerLog, "forgiveness requires trackerLog")
  local wrapText = assert(deps.wrapText, "forgiveness requires wrapText")
  local getCurrentGame = assert(deps.getCurrentGame, "forgiveness requires getCurrentGame")
  local getCurrentSave = assert(deps.getCurrentSave, "forgiveness requires getCurrentSave")
  local engineBoxConstants = assert(deps.engineBoxConstants, "forgiveness requires engineBoxConstants")
  local TX = assert(deps.GameplayTransactions, "forgiveness requires GameplayTransactions")

  local function checkedSaveSet(key, value)
      local ok, result = pcall(mod.save.set, mod.save, key, value)
      if not ok then return false, tostring(result) end
      if result == false then return false, "store_rejected_write" end
      return true
  end

  local function runHistoryHasDedupe(game, dedupe)
      dedupe = tostring(dedupe or "")
      if dedupe == "" then return false end
      local history = mod.exports.__beta26.RunHistory
      if type(history) ~= "table" or type(history.hasDedupe) ~= "function" then
          return nil, "run_history_query_unavailable"
      end
      local ok, present, detail = pcall(history.hasDedupe, game, dedupe)
      if not ok then return nil, "run_history_query_error:" .. tostring(present) end
      if present == nil then return nil, tostring(detail or "run_history_unavailable") end
      return present == true, detail
  end

  local function ensureForgivenessHistory(game, mode, target, payload, tokens)
      local dedupe = tostring(payload and payload.history_dedupe or "")
      if dedupe == "" then return false, "missing_history_dedupe" end
      local present, presentErr = runHistoryHasDedupe(game, dedupe)
      if present == nil then return false, presentErr end
      if present then return true end
      local history = mod.exports.__beta26.RunHistory
      if type(history) ~= "table"
          or type(history.recordForgivenessUse) ~= "function" then
          return false, "run_history_unavailable"
      end
      local ok, result, detail = pcall(history.recordForgivenessUse,
          game, mode, target, {
              tokens = tokens, source = "bag", dedupe = dedupe,
          })
      if not ok then return false, "run_history_error:" .. tostring(result) end
      if result ~= true and tostring(detail or "") ~= "duplicate" then
          return false, "run_history_rejected:" .. tostring(detail or result)
      end
      local persisted, persistedErr = runHistoryHasDedupe(game, dedupe)
      if persisted == nil then return false, persistedErr end
      return persisted == true, persisted and nil or "run_history_not_persisted"
  end
  ---------------------------------------------------------------------
  -- FORGIVENESS TOKEN ITEM / REVIVAL ARCHIVE (2.5.40)
  --
  -- Route Forgiveness is now player-directed inventory rather than an
  -- automatic failed-encounter prompt or Mart purchase. A carried F. TOKEN
  -- can reopen the CURRENT area's FAILED encounter slot, or revive one
  -- Pokemon whose exact record was archived when Permadeath removed it.
  ---------------------------------------------------------------------
  mod.exports.__beta26.forgivenessDeadArchive = function()
      local archive = mod.save:get("route_forgiveness_dead_archive", {})
      if type(archive) ~= "table" then
          archive = {}
          mod.save:set("route_forgiveness_dead_archive", archive)
      end
      return archive
  end

  mod.exports.__beta26.archiveForgivenessDeath = function(game, mon)
      if type(mon) ~= "table" or mon.nuzlockeDead ~= true
          or not mod.exports.__beta26.canWriteNuzlockeSave(game) then
          return false
      end
      local id = Identity.ensurePokemonIdentity(mon,
          game and game.save or getCurrentSave(), mon.nuzlockeOrigin or "NORMAL")
      if id == nil then return false end
      local archive = mod.exports.__beta26.forgivenessDeadArchive()
      -- Snapshot plain save data instead of retaining the live battle object.
      -- This prevents later faint/cleanup code from mutating the archived
      -- revival record after Permadeath has removed the Pokemon from play.
      local function snapshot(value, seen)
          if type(value) ~= "table" then
              return type(value) == "function" and nil or value
          end
          seen = seen or {}
          if seen[value] then return nil end
          seen[value] = true
          local out = {}
          for key, item in pairs(value) do
              if type(key) ~= "function" and type(item) ~= "function" then
                  local copiedKey = snapshot(key, seen)
                  local copiedValue = snapshot(item, seen)
                  if copiedKey ~= nil then out[copiedKey] = copiedValue end
              end
          end
          seen[value] = nil
          return out
      end
      archive[tostring(id)] = {
          pokemonId = id,
          name = mon.nickname,
          species = mon.species,
          -- Persist the exact record before Permadeath removes it. This keeps
          -- level, DVs/IVs, moves/PP, held item, Stat EXP, OT and all
          -- generation-specific fields rather than reconstructing a species.
          mon = snapshot(mon),
      }
      local okArchive, archiveErr =
          checkedSaveSet("route_forgiveness_dead_archive", archive)
      if not okArchive then
          mon.nuzlockeForgivenessArchivePending = true
          return false, "archive_write:" .. tostring(archiveErr)
      end
      mon.nuzlockeForgivenessArchivePending = nil
      return true, id
  end

  mod.exports.__beta26.forgivenessDeadRows = function(game)
      local archive = mod.exports.__beta26.forgivenessDeadArchive()
      local rows, seen = {}, {}
      local function add(mon, id, record)
          if type(mon) ~= "table" or mon.nuzlockeDead ~= true then return end
          id = id or Identity.pokemonIdentity(mon)
              or Identity.ensurePokemonIdentity(mon,
                  game and game.save or getCurrentSave(),
                  mon.nuzlockeOrigin or "NORMAL")
          if id == nil or seen[tostring(id)] then return end
          seen[tostring(id)] = true
          rows[#rows + 1] = {
              pokemonId = id,
              name = tostring(mon.nickname or mon.species or "POKEMON"),
              species = tostring(mon.species or "UNKNOWN"),
              level = tonumber(mon.level),
              mon = mon,
              record = record,
          }
      end
      for key, record in pairs(archive) do
          if type(record) == "table" then
              add(record.mon, record.pokemonId or key, record)
          end
      end
      local save = game and game.save
      if type(save) == "table" then
          for _, mon in ipairs(save.party or {}) do add(mon) end
          mod.exports.__beta26.forEachExistingSaveBox(save, function(box)
              for _, mon in ipairs(box) do add(mon) end
          end)
      end
      table.sort(rows, function(a, b)
          local an, bn = tostring(a.name), tostring(b.name)
          if an == bn then return tostring(a.pokemonId) < tostring(b.pokemonId) end
          return an < bn
      end)
      return rows
  end

  mod.exports.__beta26.forgivenessAreaEligible = function(game, requestedKey)
      game = game or getCurrentGame() or mod.game
      local key = routeKey(requestedKey) or requestedKey
      if not key or key == "UNKNOWN" or not isTrackedArea(key) then
          return false, Strings("There is no encounter slot to reroll there.")
      end
      syncCaughtAreasFromLog()
      if caughtAreas()[key] ~= nil then
          return false, Strings("This area's catch is already complete.")
      end
      local states = mod.exports.__beta26.encounterStates()
      local state = states[key]
      if type(state) ~= "table" or state.status ~= "FAILED" then
          return false, Strings("This area's encounter is already open.")
      end
      return true, nil, key
  end

  mod.exports.__beta26.forgivenessAreaRows = function(game)
      game = game or getCurrentGame() or mod.game
      if type(mod.exports.__beta26.ensureEncounterProjection) == "function" then
          pcall(mod.exports.__beta26.ensureEncounterProjection)
      end
      syncCaughtAreasFromLog()
      local rows, seen = {}, {}
      for _, area in ipairs(getDisplayRoutes(game) or {}) do
          local key = area and (routeKey(area.id) or area.id)
          if key and not seen[key] then
              local ok = mod.exports.__beta26.forgivenessAreaEligible(game, key)
              if ok then
                  seen[key] = true
                  rows[#rows + 1] = {
                      key = key,
                      name = tostring(area.name or routeName(key)),
                  }
              end
          end
      end
      -- Defensive fallback for projected FAILED rows that are valid tracker
      -- areas but are not currently present in getDisplayRoutes().
      local states = mod.exports.__beta26.encounterStates()
      for key, state in pairs(states) do
          if type(state) == "table" and state.status == "FAILED"
              and not seen[key] and isTrackedArea(key)
              and caughtAreas()[key] == nil then
              seen[key] = true
              rows[#rows + 1] = { key = key, name = tostring(routeName(key)) }
          end
      end
      table.sort(rows, function(a, b)
          local ao, bo = ROUTE_ORDER[a.key] or 999999, ROUTE_ORDER[b.key] or 999999
          if ao == bo then return tostring(a.name) < tostring(b.name) end
          return ao < bo
      end)
      return rows
  end

  local function encounterStateIsFailed(state)
      return type(state) == "table" and state.status == "FAILED"
  end

  mod.exports.__beta26.forgivenessFailedProjectionStateSelfTest = function()
      local cases = {
          { value = { status = "FAILED" }, expected = true, name = "failed" },
          { value = { status = "CAUGHT" }, expected = false, name = "caught" },
          { value = { status = "AVAILABLE" }, expected = false, name = "other" },
          { value = {}, expected = false, name = "missing_status" },
          { value = nil, expected = false, name = "nil" },
      }
      local failures = {}
      for _, case in ipairs(cases) do
          if encounterStateIsFailed(case.value) ~= case.expected then
              failures[#failures + 1] = case.name
          end
      end
      return { ok = #failures == 0, failures = failures, checked = #cases }
  end

  local function areaHasFailedProjection(game, key)
      local states = mod.exports.__beta26.encounterStates()
      if type(states) == "table" and encounterStateIsFailed(states[key]) then
          return true
      end
      local ledger = mod.save:get("encounter_area_state_ledger", {})
      if type(ledger) ~= "table" then return false end
      for ledgerKey, row in pairs(ledger) do
          if type(row) == "table" and row.status == "FAILED" then
              local physical = routeKey(row.encounterMapId)
                  or routeKey(ledgerKey) or row.encounterMapId
              local base = mod.exports.__beta26.projectEncounterArea(physical)
                  or physical
              local projected = mod.exports.__beta26.projectGoldEncounterArea(
                  game, base, row) or base
              if (routeKey(projected) or projected) == key then return true end
          end
      end
      return false
  end

  local function applyForgivenessArea(game, requestedKey, txCtx)
      game = game or getCurrentGame() or mod.game
      local rewards = mod.exports.__beta26.TrainerRewards
      if not txCtx then
          if not (rewards and rewards.forgivenessEnabled
              and rewards.forgivenessEnabled(game, nil)) then
              return false, Strings("Route Forgiveness is not active.")
          end
          if rewards.forgivenessTokens() <= 0 then
              return false, Strings("You have no F. TOKEN.")
          end
      end
      local key = requestedKey
      if key == nil then key = areaKey(game, nil) end
      key = routeKey(key) or key
      if not txCtx then
          local eligible, reason, normalized =
              mod.exports.__beta26.forgivenessAreaEligible(game, key)
          if not eligible then return false, reason end
          key = normalized or key
      end

      local states = mod.exports.__beta26.encounterStates()
      local ledger = mod.save:get("encounter_area_state_ledger", {})
      if type(ledger) ~= "table" then ledger = {} end
      for ledgerKey, row in pairs(ledger) do
          if type(row) == "table" and row.status == "FAILED" then
              local physical = routeKey(row.encounterMapId)
                  or routeKey(ledgerKey) or row.encounterMapId
              local base = mod.exports.__beta26.projectEncounterArea(physical)
                  or physical
              local projected = mod.exports.__beta26.projectGoldEncounterArea(
                  game, base, row) or base
              if (routeKey(projected) or projected) == key then
                  ledger[ledgerKey] = nil
              end
          end
      end
      states[key] = nil
      local okStates, errStates = checkedSaveSet("encounter_states", states)
      if not okStates then return false, "encounter_states_write:" .. tostring(errStates) end
      local okLedger, errLedger =
          checkedSaveSet("encounter_area_state_ledger", ledger)
      if not okLedger then
          return false, "encounter_ledger_write:" .. tostring(errLedger)
      end
      local last = mod.save:get("last_failed_encounter", {})
      if type(last) == "table"
          and (routeKey(last.area) or last.area) == key then
          local okLast, errLast =
              checkedSaveSet("last_failed_encounter", {})
          if not okLast then
              return false, "last_failed_write:" .. tostring(errLast)
          end
      end
      pcall(mod.exports.__beta26.reprojectEncounterAreas)

      local beforeTokens = math.max(0, math.floor(tonumber(
          txCtx and txCtx.before_tokens) or rewards.forgivenessTokens()))
      local afterTokens = math.max(0, beforeTokens - 1)
      local liveTokens = rewards.forgivenessTokens()
      if liveTokens == beforeTokens then
          if rewards.setForgivenessTokens(afterTokens) ~= true then
              return false, Strings("The F. TOKEN could not be committed safely.")
          end
      elseif liveTokens ~= afterTokens then
          return false, Strings("F. TOKEN state changed during recovery.")
      end
      if txCtx then
          local okHistory, historyErr = ensureForgivenessHistory(
              game, "area", key, txCtx, afterTokens)
          if not okHistory then
              return false, "run_history:" .. tostring(historyErr)
          end
      end
      return true, Strings("F. TOKEN used.\n%s is open again.", routeName(key))
  end

  local function applyForgivenessRevive(game, pokemonId, txCtx)
      game = game or getCurrentGame() or mod.game
      local rewards = mod.exports.__beta26.TrainerRewards
      if not txCtx then
          if not (rewards and rewards.forgivenessEnabled
              and rewards.forgivenessEnabled(game, nil)) then
              return false, Strings("Route Forgiveness is not active.")
          end
          if rewards.forgivenessTokens() <= 0 then
              return false, Strings("You have no F. TOKEN.")
          end
      end
      local wanted = tostring(pokemonId or "")
      local archive = mod.exports.__beta26.forgivenessDeadArchive()
      local record = archive[wanted]
      local mon = type(record) == "table" and record.mon or nil
      local save = game and game.save
      if type(save) ~= "table" then
          return false, Strings("The save is unavailable.")
      end

      -- Prefer a physical dead record if another compatible system retained
      -- it in storage; otherwise use the full Permadeath archive snapshot.
      local physical, physicalBox, physicalPartyIndex = nil, nil, nil
      local function same(candidate)
          if type(candidate) ~= "table" then return false end
          local id = Identity.pokemonIdentity(candidate)
          return id ~= nil and tostring(id) == wanted
      end
      for index, candidate in ipairs(save.party or {}) do
          if same(candidate) then
              physical, physicalPartyIndex = candidate, index
              break
          end
      end
      if not physical then
          mod.exports.__beta26.forEachExistingSaveBox(save,
              function(box, boxIndex)
                  for _, candidate in ipairs(box) do
                      if same(candidate) then
                          physical, physicalBox = candidate, boxIndex
                          return false
                      end
                  end
              end)
      end
      mon = physical or mon
      if type(mon) ~= "table" then
          return false, Strings("That fallen Pokemon cannot be restored.")
      end
      if not txCtx and mon.nuzlockeDead ~= true then
          return false, Strings("That fallen Pokemon cannot be restored.")
      end

      local party = save.party or {}
      local limit = math.max(1, math.min(6, math.floor(tonumber(
          mod.save:get("party_size_limit",
              defaultRuleValue("party_size_limit"))) or 6)))

      -- A compatible provider may retain a dead Pokemon physically in the
      -- party. If Party Size Limit was lowered after that death, reviving in
      -- place must not reactivate a party that is already above the cap. Move
      -- that retained record to legal PC storage before clearing nuzlockeDead.
      if physicalPartyIndex ~= nil and #party > limit then
          local destination, destinationBox
          if mod.exports.__beta26.runtimeIsGen2(game) then
              local okBoxes, Boxes = pcall(require, "src.core.gen2.Boxes")
              if not okBoxes or type(Boxes) ~= "table" then
                  return false, Strings("No PC storage is available.")
              end
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              for i = 1, count do
                  local box = type(Boxes.box) == "function" and Boxes.box(save, i)
                      or (save.boxes and save.boxes[i])
                  if type(box) == "table" and #box < capacity then
                      destination, destinationBox = i, box
                      break
                  end
              end
          else
              local okBoxes, Boxes = pcall(require, "src.pokemon.Boxes")
              if not okBoxes or type(Boxes) ~= "table"
                  or type(Boxes.ensure) ~= "function" then
                  return false, Strings("No PC storage is available.")
              end
              local boxes = Boxes.ensure(save)
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              for i = 1, count do
                  if type(boxes[i]) == "table" and #boxes[i] < capacity then
                      destination, destinationBox = i, boxes[i]
                      break
                  end
              end
          end
          if not destination or type(destinationBox) ~= "table" then
              return false, Strings("The PC is full. No token was spent.")
          end
          table.remove(party, physicalPartyIndex)
          destinationBox[#destinationBox + 1] = mon
          save.party = party
          physicalBox = destination
          physicalPartyIndex = nil
      end

      -- If Permadeath removed the mon completely, put the archived full record
      -- back into the run. Party Size Limit is respected; a full/capped party
      -- sends the revival to the first PC box with room instead.
      if not physical then
          if #party < limit then
              party[#party + 1] = mon
              save.party = party
          elseif mod.exports.__beta26.runtimeIsGen2(game) then
              local okBoxes, Boxes = pcall(require, "src.core.gen2.Boxes")
              if not okBoxes or type(Boxes) ~= "table" then
                  return false, Strings("No PC storage is available.")
              end
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              local destination
              for i = 1, count do
                  local box = type(Boxes.box) == "function" and Boxes.box(save, i)
                      or (save.boxes and save.boxes[i])
                  if type(box) == "table" and #box < capacity then
                      destination = i
                      break
                  end
              end
              if not destination then
                  return false, Strings("The PC is full. No token was spent.")
              end
              local box = type(Boxes.box) == "function" and Boxes.box(save, destination)
                  or (save.boxes and save.boxes[destination])
              if type(box) ~= "table" or #box >= capacity then
                  return false, Strings("The PC is full. No token was spent.")
              end
              box[#box + 1] = mon
              physicalBox = destination
          else
              local okBoxes, Boxes = pcall(require, "src.pokemon.Boxes")
              if not okBoxes or type(Boxes) ~= "table"
                  or type(Boxes.ensure) ~= "function" then
                  return false, Strings("No PC storage is available.")
              end
              local boxes = Boxes.ensure(save)
              local layout = engineBoxConstants(game, Boxes)
              local count, capacity = layout.count, layout.capacity
              local destination
              for i = 1, count do
                  if type(boxes[i]) == "table" and #boxes[i] < capacity then
                      destination = i
                      break
                  end
              end
              if not destination then
                  return false, Strings("The PC is full. No token was spent.")
              end
              boxes[destination][#boxes[destination] + 1] = mon
              physicalBox = destination
          end
      end

      local maxHp = math.max(1, math.floor(tonumber(mon.maxHp)
          or tonumber(mon.stats and mon.stats.hp) or 1))
      mon.hp = math.max(1, math.floor(maxHp / 2))
      mon.nuzlockeDead = nil
      mon.status = nil
      mon.statusTurns = nil
      mon.toxicCounter = nil
      mon.deathLocation = nil
      mon.deathCause = nil
      mon.deathCauseText = nil
      mon.deathEncounterType = nil
      mon.deathOpponentSpecies = nil
      mon.deathMove = nil
      mon.deathCritical = nil
      mon.deathStatusCondition = nil

      local history = mod.save:get("nuzlocke_history", {})
      if type(history) == "table" then
          for _, row in ipairs(history) do
              if type(row) == "table" and row.pokemonId ~= nil
                  and tostring(row.pokemonId) == wanted
                  and row.status == "DEAD" then
                  row.status = "REVIVED"
                  row.revivedByForgiveness = true
              end
          end
          local okHistoryWrite, historyWriteErr =
              checkedSaveSet("nuzlocke_history", history)
          if not okHistoryWrite then
              return false, "nuzlocke_history_write:" .. tostring(historyWriteErr)
          end
      end
      local log = trackerLog()
      for _, entries in pairs(log) do
          if type(entries) == "table" then
              for _, catch in ipairs(entries) do
                  if type(catch) == "table" and catch.pokemonId ~= nil
                      and tostring(catch.pokemonId) == wanted then
                      catch.dead = nil
                      catch.status = catch.isShiny and "SHINY" or "CAUGHT"
                      catch.deathCause = nil
                      catch.deathLocation = nil
                      catch.deathOpponentSpecies = nil
                      catch.deathMove = nil
                      catch.deathCritical = nil
                      catch.deathStatusCondition = nil
                  end
              end
          end
      end
      local okTracker, trackerErr = checkedSaveSet("tracker_log", log)
      if not okTracker then
          return false, "tracker_log_write:" .. tostring(trackerErr)
      end
      if type(mod.exports.__beta26.syncTrackerDeathProjection) == "function" then
          pcall(mod.exports.__beta26.syncTrackerDeathProjection)
      end
      archive[wanted] = nil
      local okArchive, archiveErr =
          checkedSaveSet("route_forgiveness_dead_archive", archive)
      if not okArchive then
          return false, "dead_archive_write:" .. tostring(archiveErr)
      end
      local beforeTokens = math.max(0, math.floor(tonumber(
          txCtx and txCtx.before_tokens) or rewards.forgivenessTokens()))
      local afterTokens = math.max(0, beforeTokens - 1)
      local liveTokens = rewards.forgivenessTokens()
      if liveTokens == beforeTokens then
          if rewards.setForgivenessTokens(afterTokens) ~= true then
              return false, Strings("The F. TOKEN could not be committed safely.")
          end
      elseif liveTokens ~= afterTokens then
          return false, Strings("F. TOKEN state changed during recovery.")
      end
      if txCtx then
          local okHistory, historyErr = ensureForgivenessHistory(
              game, "revive", wanted, txCtx, afterTokens)
          if not okHistory then
              return false, "run_history:" .. tostring(historyErr)
          end
      end
      local name = tostring(mon.nickname or mon.species or "Pokemon")
      local suffix = physicalBox and Strings("\nSent to PC Box %d.", physicalBox)
          or ""
      return true, Strings("F. TOKEN used.\n%s was revived!", name) .. suffix
  end

  local function findForgivenessPhysical(game, wanted)
      local save = game and game.save
      if type(save) ~= "table" then return nil end
      local function same(candidate)
          if type(candidate) ~= "table" then return false end
          local id = Identity.pokemonIdentity(candidate)
          return id ~= nil and tostring(id) == tostring(wanted)
      end
      for _, candidate in ipairs(save.party or {}) do
          if same(candidate) then return candidate end
      end
      local found
      mod.exports.__beta26.forEachExistingSaveBox(save, function(box)
          for _, candidate in ipairs(box) do
              if same(candidate) then found = candidate; return false end
          end
      end)
      return found
  end

  if type(TX.register) == "function" then
      TX.register("forgiveness_area_v1", {
          probe = function(payload)
              local game = getCurrentGame() or mod.game
              local rewards = mod.exports.__beta26.TrainerRewards
              if type(rewards) ~= "table" then return "unknown", "rewards_unavailable" end
              local key = routeKey(payload and payload.area_key) or (payload and payload.area_key)
              local before = math.max(0, math.floor(tonumber(payload and payload.before_tokens) or 0))
              local after = math.max(0, before - 1)
              local tokens = rewards.forgivenessTokens()
              local failed = areaHasFailedProjection(game, key)
              local historyOk, historyErr = runHistoryHasDedupe(
                  game, payload and payload.history_dedupe)
              if historyOk == nil then return "unknown", tostring(historyErr) end
              if not failed and tokens == after and historyOk then
                  return "applied"
              end
              if (tokens == before or tokens == after) then return "not_applied" end
              return "unknown", "forgiveness_area_state_ambiguous"
          end,
          perform = function(payload)
              local game = getCurrentGame() or mod.game
              return applyForgivenessArea(game, payload and payload.area_key, payload)
          end,
      })
      TX.register("forgiveness_revive_v1", {
          probe = function(payload)
              local game = getCurrentGame() or mod.game
              local rewards = mod.exports.__beta26.TrainerRewards
              if type(rewards) ~= "table" then return "unknown", "rewards_unavailable" end
              local wanted = tostring(payload and payload.pokemon_id or "")
              local before = math.max(0, math.floor(tonumber(payload and payload.before_tokens) or 0))
              local after = math.max(0, before - 1)
              local tokens = rewards.forgivenessTokens()
              local archive = mod.exports.__beta26.forgivenessDeadArchive()
              local physical = findForgivenessPhysical(game, wanted)
              local archived = type(archive[wanted]) == "table"
              local revived = type(physical) == "table"
                  and physical.nuzlockeDead ~= true and not archived
              local historyOk, historyErr = runHistoryHasDedupe(
                  game, payload and payload.history_dedupe)
              if historyOk == nil then return "unknown", tostring(historyErr) end
              if revived and tokens == after and historyOk then
                  return "applied"
              end
              if (tokens == before or tokens == after)
                  and (archived or type(physical) == "table") then
                  return "not_applied"
              end
              return "unknown", "forgiveness_revive_state_ambiguous"
          end,
          perform = function(payload)
              local game = getCurrentGame() or mod.game
              return applyForgivenessRevive(game, payload and payload.pokemon_id, payload)
          end,
      })
  end

  mod.exports.__beta26.reopenFailedEncounterWithForgiveness = function(game, requestedKey)
      game = game or getCurrentGame() or mod.game
      local rewards = mod.exports.__beta26.TrainerRewards
      if not (rewards and rewards.forgivenessEnabled
          and rewards.forgivenessEnabled(game, nil)) then
          return false, Strings("Route Forgiveness is not active.")
      end
      if rewards.forgivenessTokens() <= 0 then
          return false, Strings("You have no F. TOKEN.")
      end
      local key = requestedKey
      if key == nil then key = areaKey(game, nil) end
      key = routeKey(key) or key
      local eligible, reason, normalized =
          mod.exports.__beta26.forgivenessAreaEligible(game, key)
      if not eligible then return false, reason end
      key = normalized or key
      local attempt = TX.nextSequence("forgiveness_area_v1")
      if attempt == nil then return false, Strings("F. TOKEN transaction unavailable.") end
      local id = table.concat({ "forgiveness_area", "v1", tostring(key), tostring(attempt) }, ":")
      local ok, err = TX.execute(id, "forgiveness_area_v1", {
          area_key = key, before_tokens = rewards.forgivenessTokens(),
          history_dedupe = id,
      })
      if ok ~= true then return false, Strings("F. TOKEN could not be used safely: %s", tostring(err)) end
      return true, Strings("F. TOKEN used.\n%s is open again.", routeName(key))
  end

  mod.exports.__beta26.reviveWithForgiveness = function(game, pokemonId)
      game = game or getCurrentGame() or mod.game
      local rewards = mod.exports.__beta26.TrainerRewards
      if not (rewards and rewards.forgivenessEnabled
          and rewards.forgivenessEnabled(game, nil)) then
          return false, Strings("Route Forgiveness is not active.")
      end
      if rewards.forgivenessTokens() <= 0 then
          return false, Strings("You have no F. TOKEN.")
      end
      local wanted = tostring(pokemonId or "")
      local archive = mod.exports.__beta26.forgivenessDeadArchive()
      local physical = findForgivenessPhysical(game, wanted)
      local record = archive[wanted]
      local candidate = physical or (type(record) == "table" and record.mon or nil)
      if type(candidate) ~= "table" or candidate.nuzlockeDead ~= true then
          return false, Strings("That fallen Pokemon cannot be restored.")
      end
      local attempt = TX.nextSequence("forgiveness_revive_v1")
      if attempt == nil then return false, Strings("F. TOKEN transaction unavailable.") end
      local id = table.concat({ "forgiveness_revive", "v1", wanted, tostring(attempt) }, ":")
      local ok, err = TX.execute(id, "forgiveness_revive_v1", {
          pokemon_id = wanted, before_tokens = rewards.forgivenessTokens(),
          history_dedupe = id,
      })
      if ok ~= true then return false, Strings("F. TOKEN could not be used safely: %s", tostring(err)) end
      local mon = findForgivenessPhysical(game, wanted)
      local name = tostring(mon and (mon.nickname or mon.species) or "Pokemon")
      return true, Strings("F. TOKEN used.\n%s was revived!", name)
  end

  mod.content.screens:register("NuzlockeForgivenessArea", {
      new = function(game, ctx)
          ctx = ctx or {}
          local self = {
              game = game,
              screenId = "NuzlockeForgivenessArea",
              isOpaque = true,
              rows = mod.exports.__beta26.forgivenessAreaRows(game),
              index = 1,
              scroll = 0,
              phase = "list",
              confirmChoice = 0, -- deliberately no YES/NO default
              notice = nil,
              ctx = ctx,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "forgiveness_area"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true
          self.__nuzlockeOwnsForgivenessLayout = true
          mod.exports.__beta26.UiSystem.applyLayout(self, "centered", ctx and ctx.parent)

          local function clamp()
              local count = #self.rows
              if count <= 0 then self.index, self.scroll = 1, 0; return end
              self.index = math.max(1, math.min(self.index, count))
              if self.index <= self.scroll then self.scroll = self.index - 1 end
              if self.index > self.scroll + 6 then self.scroll = self.index - 6 end
              self.scroll = math.max(0, math.min(self.scroll, math.max(0, count - 6)))
          end
          local function selected()
              return self.rows[self.index]
          end
          local function beginConfirm(row)
              if not row then return end
              local ok, reason = mod.exports.__beta26.forgivenessAreaEligible(game, row.key)
              if not ok then
                  self.notice = reason
                  self.rows = mod.exports.__beta26.forgivenessAreaRows(game)
                  clamp()
                  return
              end
              self.phase = "confirm"
              self.confirmChoice = 0
          end
          if ctx.initialKey then
              local wanted = routeKey(ctx.initialKey) or ctx.initialKey
              for i, row in ipairs(self.rows) do
                  if row.key == wanted then self.index = i; break end
              end
              clamp()
              if ctx.confirmImmediately == true and selected() then
                  beginConfirm(selected())
              end
          end

          function self:update(_dt)
              if self.notice then
                  if game.input:wasPressed("a") or game.input:wasPressed("b") then
                      self.notice = nil
                      if self.ctx.closeAfterNotice == true then game.stack:pop() end
                  end
                  return
              end
              if self.phase == "confirm" then
                  if game.input:wasPressed("b") then
                      if self.ctx.confirmImmediately == true then
                          game.stack:pop()
                      else
                          self.phase = "list"
                          self.confirmChoice = 0
                      end
                      return
                  end
                  local chooseYes = game.input:wasPressed("left") or game.input:wasPressed("up")
                  local chooseNo = game.input:wasPressed("right") or game.input:wasPressed("down")
                  if chooseYes or chooseNo then
                      -- Direction selects an explicit choice. Repeating the same direction
                      -- must be idempotent for this irreversible F. TOKEN confirmation.
                      self.confirmChoice = chooseYes and 1 or 2
                      return
                  end
                  if game.input:wasPressed("a") then
                      if self.confirmChoice == 0 then return end
                      if self.confirmChoice == 2 then
                          if self.ctx.confirmImmediately == true then
                              game.stack:pop()
                          else
                              self.phase = "list"
                              self.confirmChoice = 0
                          end
                          return
                      end
                      local row = selected()
                      local ok, message
                      if row then
                          ok, message = mod.exports.__beta26.reopenFailedEncounterWithForgiveness(
                              game, row.key)
                      else
                          ok, message = false, Strings("No reroll area is selected.")
                      end
                      self.notice = message
                      if ok then
                          if type(self.ctx.onSpent) == "function" then pcall(self.ctx.onSpent, row.key) end
                          self.rows = mod.exports.__beta26.forgivenessAreaRows(game)
                          self.phase = "list"
                          self.confirmChoice = 0
                          self.ctx.closeAfterNotice = self.ctx.closeAfterSpend == true
                          clamp()
                      end
                      return
                  end
                  return
              end
              if game.input:wasPressed("b") then game.stack:pop(); return end
              if #self.rows == 0 then return end
              if game.input:wasPressed("up") then
                  self.index = self.index == 1 and #self.rows or self.index - 1
                  clamp()
              elseif game.input:wasPressed("down") then
                  self.index = self.index == #self.rows and 1 or self.index + 1
                  clamp()
              elseif game.input:wasPressed("a") then
                  beginConfirm(selected())
              end
          end

          function self:draw()
              local rewards = mod.exports.__beta26.TrainerRewards
              local tokens = rewards and rewards.forgivenessTokens
                  and rewards.forgivenessTokens() or 0
              local row = selected()
              local areaName = row and row.name or "?"
              if mod.exports.__beta26.runtimeIsGen2(game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  Chrome.clear(); Chrome.box(0,0,20,18)
                  local GoldFont = require("src.render.Font")
                  mod.exports.__beta26.drawGen2NuzTitle(Chrome, GoldFont, Strings("REROLL AREA"))
                  if self.notice then
                      local GoldFont = require("src.render.Font")
                      local notice = mod.exports.__beta26.UiSystem.notice(
                          Strings("INFO"), Strings("F. TOKEN"), self.notice, Strings("A/B:BACK"))
                      mod.exports.__beta26.UiSystem.gen2Notice(Chrome, GoldFont, notice, {
                          x = 2, y = 4, widthCols = 16, footerRow = 15,
                      })
                      return
                  end
                  if self.phase == "confirm" then
                      Chrome.printWrapped(Strings("Are you sure? This will spend your F. TOKEN on %s.", areaName), 2, 4, 16, 6)
                      if self.confirmChoice == 1 then Chrome.cursor(4, 12) end
                      if self.confirmChoice == 2 then Chrome.cursor(11, 12) end
                      Chrome.print(Strings("YES"), 5, 12)
                      Chrome.print(Strings("NO"), 12, 12)
                      Chrome.print(Strings("MOVE:CHOOSE A:OK"), 2, 15)
                      Chrome.print(Strings("B:CANCEL"), 6, 16)
                      return
                  end
                  if #self.rows == 0 then
                      Chrome.printWrapped(Strings("No failed encounter areas are available to reroll."), 2, 5, 16, 5)
                  else
                      for slot=1,6 do
                          local i=self.scroll+slot; local r=self.rows[i]
                          if not r then break end
                          local ty=3+(slot-1)*2
                          if i==self.index then Chrome.cursor(1,ty) end
                          Chrome.print(marqueeText(Strings(r.name), 15, 0), 2, ty)
                      end
                  end
                  Chrome.print(Strings("TOKENS %d", tokens), 2, 15)
                  Chrome.print(Strings("A:SELECT B:BACK"), 7, 16)
                  return
              end
              local Font = mod.ui.Font
              local Theme = require("src.ui.Theme")
              love.graphics.setColor(1,1,1,1)
              love.graphics.rectangle("fill",0,0,160,144)
              Font.drawBox(0,0,20,18)
              Font.draw(Strings("REROLL AREA"), 36, 10)
              if self.notice then
                  local notice = mod.exports.__beta26.UiSystem.notice(
                      Strings("INFO"), Strings("F. TOKEN"), self.notice, Strings("A/B:BACK"))
                  mod.exports.__beta26.UiSystem.gen1Notice(Font, notice, 160)
                  return
              end
              if self.phase == "confirm" then
                  local prompt = Strings("Are you sure? This will spend your F. TOKEN on %s.", areaName)
                  local lines=wrapText(tostring(prompt),17); local y=28
                  for i=1,math.min(#lines,6) do Font.draw(lines[i],12,y); y=y+12 end
                  if self.confirmChoice == 1 then Font.drawCode(Theme.cursor, 34, 94) end
                  if self.confirmChoice == 2 then Font.drawCode(Theme.cursor, 98, 94) end
                  Font.draw(Strings("YES"),50,94)
                  Font.draw(Strings("NO"),114,94)
                  Font.draw(Strings("MOVE:CHOOSE"),28,112)
                  Font.draw(Strings("A:OK B:CANCEL"),24,124)
                  return
              end
              if #self.rows == 0 then
                  local lines=wrapText(Strings("No failed encounter areas are available to reroll."),16)
                  local y=42; for i=1,#lines do Font.draw(lines[i],16,y); y=y+12 end
              else
                  for slot=1,6 do
                      local i=self.scroll+slot; local r=self.rows[i]
                      if not r then break end
                      local y=28+(slot-1)*14
                      if i==self.index then Font.drawCode(Theme.cursor,12,y) end
                      Font.draw(marqueeText(Strings(r.name),15,0),30,y)
                  end
              end
              Font.draw(Strings("TOKENS %d",tokens),48,108)
              Font.draw(Strings("A:SELECT B:BACK"),20,124)
          end
          return self
      end,
  })

  mod.content.screens:register("NuzlockeForgivenessItem", {
      new = function(game, ctx)
          local self = {
              game = game,
              screenId = "NuzlockeForgivenessItem",
              isOpaque = true,
              cursor = 1,
              ctx = ctx or {},
              notice = nil,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "forgiveness"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true
          self.__nuzlockeOwnsForgivenessLayout = true
          mod.exports.__beta26.UiSystem.applyLayout(self, "centered", self.ctx and self.ctx.parent)
          function self:update(dt)
              if self.notice then
                  if game.input:wasPressed("a") or game.input:wasPressed("b") then
                      self.notice = nil
                  end
                  return
              end
              if game.input:wasPressed("up") or game.input:wasPressed("down")
                  or game.input:wasPressed("left") or game.input:wasPressed("right") then
                  self.cursor = self.cursor == 1 and 2 or 1
              elseif game.input:wasPressed("b") then
                  game.stack:pop()
              elseif game.input:wasPressed("a") then
                  if self.cursor == 1 then
                      local rows = mod.exports.__beta26.forgivenessAreaRows(game)
                      if #rows == 0 then
                          self.notice = Strings("No failed encounter areas are available to reroll.")
                      else
                          mod.ui.push(game, "NuzlockeForgivenessArea", {
                              onSpent = self.ctx.onSpent,
                          })
                      end
                  else
                      local rows = mod.exports.__beta26.forgivenessDeadRows(game)
                      if #rows == 0 then
                          self.notice = Strings("No fallen Pokemon are available to revive.")
                      else
                          mod.ui.push(game, "NuzlockeForgivenessRevive", {
                              parent = self, rows = rows,
                              onSpent = self.ctx.onSpent,
                          })
                      end
                  end
              end
          end
          function self:draw()
              local rewards = mod.exports.__beta26.TrainerRewards
              local tokens = rewards and rewards.forgivenessTokens
                  and rewards.forgivenessTokens() or 0
              if mod.exports.__beta26.runtimeIsGen2(game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  Chrome.clear(); Chrome.box(0, 0, 20, 18)
                  Chrome.print(Strings("F. TOKEN"), 6, 2)
                  local GoldFont = require("src.render.Font")
                  if self.notice then
                      local notice = mod.exports.__beta26.UiSystem.notice(
                          Strings("INFO"), Strings("F. TOKEN"), self.notice, Strings("A/B:BACK"))
                      mod.exports.__beta26.UiSystem.gen2Notice(Chrome, GoldFont, notice, {
                          x = 2, y = 4, widthCols = 16, footerRow = 15,
                      })
                      return
                  end
                  Chrome.printWrapped(Strings("Choose how to spend it."), 2, 5, 16, 2)
                  mod.exports.__beta26.UiSystem.gen2Row(Chrome, GoldFont, {
                      label = Strings("REROLL ENCOUNTER"), focused = self.cursor == 1,
                  }, { x = 3, y = 8, rightCol = 18 })
                  mod.exports.__beta26.UiSystem.gen2Row(Chrome, GoldFont, {
                      label = Strings("REVIVE POKEMON"), focused = self.cursor == 2,
                  }, { x = 3, y = 10, rightCol = 18 })
                  Chrome.print(Strings("TOKENS %d", tokens), 4, 13)
                  Chrome.print(Strings("B:CANCEL"), 4, 15)
                  return
              end
              local Font = mod.ui.Font
              -- 2.5.48: use the exact full-page R/B/Y pattern already proven
              -- by Nuzlocke Config/Status/Loadout screens. Font.drawBox takes
              -- TILE coordinates, not pixels; the old (8,10,18,15) call was
              -- therefore drawing the box in the lower-right of the screen.
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.rectangle("fill", 0, 0, 160, 144)
              Font.drawBox(0, 0, 20, 18)
              Font.draw(Strings("F. TOKEN"), 48, 10)
              if self.notice then
                  local notice = mod.exports.__beta26.UiSystem.notice(
                      Strings("INFO"), Strings("F. TOKEN"), self.notice, Strings("A/B:BACK"))
                  mod.exports.__beta26.UiSystem.gen1Notice(Font, notice, 160)
              else
                  Font.draw(Strings("Choose how to"), 24, 34)
                  Font.draw(Strings("spend it."), 40, 46)
                  local Theme = require("src.ui.Theme")
                  mod.exports.__beta26.UiSystem.gen1Row(Font, Theme, {
                      label = Strings("REROLL ENCOUNTER"), focused = self.cursor == 1,
                  }, { x = 30, y = 70, right = 148 })
                  mod.exports.__beta26.UiSystem.gen1Row(Font, Theme, {
                      label = Strings("REVIVE POKEMON"), focused = self.cursor == 2,
                  }, { x = 30, y = 86, right = 148 })
                  Font.draw(Strings("TOKENS %d", tokens), 48, 108)
                  Font.draw(Strings("B:CANCEL"), 48, 122)
              end
          end
          return self
      end,
  })

  mod.content.screens:register("NuzlockeForgivenessRevive", {
      new = function(game, ctx)
          local self = {
              game = game,
              screenId = "NuzlockeForgivenessRevive",
              isOpaque = true,
              ctx = ctx or {},
              rows = (ctx and ctx.rows) or {},
              index = 1,
              scroll = 0,
              notice = nil,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "forgiveness_revive"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true
          self.__nuzlockeOwnsForgivenessLayout = true
          mod.exports.__beta26.UiSystem.applyLayout(self, "centered", self.ctx and self.ctx.parent)
          function self:update(dt)
              if self.notice then
                  if game.input:wasPressed("a") or game.input:wasPressed("b") then
                      game.stack:pop()
                      if self.ctx.parent then self.ctx.parent.notice = self.notice end
                  end
                  return
              end
              local count = #self.rows
              if game.input:wasPressed("up") and count > 0 then
                  self.index = self.index <= 1 and count or self.index - 1
              elseif game.input:wasPressed("down") and count > 0 then
                  self.index = self.index >= count and 1 or self.index + 1
              elseif game.input:wasPressed("b") then
                  game.stack:pop()
              elseif game.input:wasPressed("a") and self.rows[self.index] then
                  local ok, message = mod.exports.__beta26.reviveWithForgiveness(
                      game, self.rows[self.index].pokemonId)
                  self.notice = message
                  if ok and type(self.ctx.onSpent) == "function" then
                      pcall(self.ctx.onSpent)
                  end
              end
              if self.index <= self.scroll then self.scroll = self.index - 1 end
              if self.index > self.scroll + 5 then self.scroll = self.index - 5 end
          end
          function self:draw()
              if mod.exports.__beta26.runtimeIsGen2(game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  Chrome.clear(); Chrome.box(0,0,20,18)
                  Chrome.print(Strings("REVIVE WHO?"), 5, 2)
                  local GoldFont = require("src.render.Font")
                  if self.notice then
                      local notice = mod.exports.__beta26.UiSystem.notice(
                          Strings("INFO"), Strings("REVIVE"), self.notice, Strings("A/B:BACK"))
                      mod.exports.__beta26.UiSystem.gen2Notice(Chrome, GoldFont, notice, {
                          x = 2, y = 4, widthCols = 16, footerRow = 15,
                      })
                      return
                  end
                  for n=1,5 do
                      local i=self.scroll+n; local row=self.rows[i]
                      if row then
                          mod.exports.__beta26.UiSystem.gen2Row(Chrome, GoldFont, {
                              label = row.name,
                              value = "L" .. (row.level and tostring(math.floor(row.level)) or "?"),
                              focused = i == self.index,
                          }, { x = 2, y = 4 + n * 2, rightCol = 18 })
                      end
                  end
                  Chrome.print(Strings("B:CANCEL"),5,16)
                  return
              end
              local Font=mod.ui.Font
              love.graphics.setColor(1,1,1,1)
              love.graphics.rectangle("fill",0,0,160,144)
              Font.drawBox(0,0,20,18)
              Font.draw(Strings("REVIVE WHO?"),36,10)
              if self.notice then
                  local notice = mod.exports.__beta26.UiSystem.notice(
                      Strings("INFO"), Strings("REVIVE"), self.notice, Strings("A/B:BACK"))
                  mod.exports.__beta26.UiSystem.gen1Notice(Font, notice, 160)
              else
                  for n=1,5 do
                      local i=self.scroll+n; local row=self.rows[i]
                      if row then
                          local y = 38 + n * 14
                          mod.exports.__beta26.UiSystem.gen1Row(
                              Font, require("src.ui.Theme"), {
                                  label = row.name,
                                  value = "L" .. (row.level and tostring(math.floor(row.level)) or "?"),
                                  focused = i == self.index,
                              }, { x = 30, y = y, right = 148 })
                      end
                  end
                  Font.draw(Strings("B: CANCEL"),48,122)
              end
              love.graphics.setColor(1,1,1,1)
          end
          return self
      end,
  })


  mod.exports.__beta26.reconcileForgivenessDeathArchive = function(game)
      game = game or getCurrentGame() or mod.game
      local save = game and game.save or getCurrentSave()
      if type(save) ~= "table" or not mod.exports.__beta26.canWriteNuzlockeSave(game) then
          return false, "save_unavailable"
      end
      local recovered = 0
      local function reconcileContainer(container)
          if type(container) ~= "table" then return end
          for i = #container, 1, -1 do
              local mon = container[i]
              if type(mon) == "table" and mon.nuzlockeDead == true
                  and mon.nuzlockeForgivenessArchivePending == true then
                  local ok = mod.exports.__beta26.archiveForgivenessDeath(game, mon)
                  if ok == true then
                      table.remove(container, i)
                      recovered = recovered + 1
                  end
              end
          end
      end
      reconcileContainer(save.party)
      mod.exports.__beta26.forEachExistingSaveBox(save, function(box)
          reconcileContainer(box)
      end)
      return true, recovered
  end

  mod.events:on("game.ready", function(ev)
      pcall(mod.exports.__beta26.reconcileForgivenessDeathArchive,
          (type(ev) == "table" and ev.game) or getCurrentGame() or mod.game)
  end)
  mod.events:on("save.loaded", function(ev)
      pcall(mod.exports.__beta26.reconcileForgivenessDeathArchive,
          (type(ev) == "table" and ev.game) or getCurrentGame() or mod.game)
  end)

  -- 2.9.50: R/B/Y Forgiveness Token shop filtering moved from main.lua.
  ---------------------------------------------------------------------
  -- FORGIVENESS TOKEN SHOP FILTER (2.5.40)
  --
  -- The carried token is never merchandise. Filter it from both BUY stock
  -- and R/B/Y's inventory-backed SELL list, including the SELL list rebuild
  -- that happens after SELECT reordering. Gold's native Pack-backed SELL
  -- surface is filtered in G2.installMartGate below.
  ---------------------------------------------------------------------
  mod.exports.__beta26.installForgivenessRbyShopFilter = function()
      if mod.exports.__beta26.isSaveEditorSession() then return true end
      local okList, ListMenu = pcall(require, "src.ui.ListMenu")
      if not okList or type(ListMenu) ~= "table"
          or type(ListMenu.new) ~= "function" then return false end
      local session = ListMenu.__nuzlockeForgivenessShopFilterSession
      if type(session) == "table" and session.owner == mod
          and ListMenu.new == session.wrapper then return true end
      if type(session) == "table" and session.owner ~= mod
          and ListMenu.new == session.wrapper
          and type(session.previous) == "function" then
          ListMenu.new = session.previous
      end
      local previous = ListMenu.new
      local wrapper
      local function semanticShopKind(title, opts)
          -- Prefer semantic ListMenu metadata when supplied by the engine or
          -- another compatible menu layer. Display text is never uppercased
          -- and compared to English literals.
          if type(opts) == "table" then
              local raw = opts.kind or opts.shopKind or opts.action
                  or opts.semanticKind
              local kind = tostring(raw or ""):lower()
              if kind == "buy" or kind == "shop_buy" or kind == "mart_buy"
                  or kind == "item_shop_buy" then return "BUY" end
              if kind == "sell" or kind == "shop_sell" or kind == "mart_sell"
                  or kind == "item_shop_sell" then return "SELL" end
          end
          -- Older native ListMenu constructors expose only the already
          -- localized title. Compare against the canonical Strings source so
          -- translation packs remain authoritative; never add language-
          -- specific BUY/SELL spellings here.
          local shown = tostring(title or "")
          if shown == tostring(Strings("BUY")) then return "BUY" end
          if shown == tostring(Strings("SELL")) then return "SELL" end
          return nil
      end

      wrapper = function(game, title, items, opts, ...)
          local shop = semanticShopKind(title, opts)
          local tokenId = tostring(
              mod.exports.__beta26.forgivenessTokenItemId or "")
          local function filter(rows)
              if type(rows) ~= "table" or tokenId == "" then return rows end
              local out = {}
              for _, row in ipairs(rows) do
                  if tostring(row and row.value or "") ~= tokenId then
                      out[#out + 1] = row
                  end
              end
              return out
          end
          if shop == "BUY" or shop == "SELL" then
              items = filter(items)
              if shop == "SELL" and type(opts) == "table"
                  and type(opts.onSelectKey) == "function" then
                  local copied = {}
                  for key, value in pairs(opts) do copied[key] = value end
                  local priorSelect = copied.onSelectKey
                  copied.onSelectKey = function(item, list, ...)
                      local result = priorSelect(item, list, ...)
                      if type(list) == "table" then
                          list.items = filter(list.items)
                          list.index = math.min(list.index or 1,
                              math.max(1, #(list.items or {})))
                      end
                      return result
                  end
                  opts = copied
              end
          end
          return previous(game, title, items, opts, ...)
      end
      ListMenu.new = wrapper
      ListMenu.__nuzlockeForgivenessShopFilterSession = {
          owner = mod, previous = previous, wrapper = wrapper,
      }
      return true
  end
  mod.exports.__beta26.attemptInstall("gen1.forgiveness_shop_filter", mod.exports.__beta26.installForgivenessRbyShopFilter)
  mod.events:on("game.ready", function()
      mod.exports.__beta26.attemptInstall("gen1.forgiveness_shop_filter", mod.exports.__beta26.installForgivenessRbyShopFilter)
  end)
  mod.events:on("save.loaded", function()
      mod.exports.__beta26.attemptInstall("gen1.forgiveness_shop_filter", mod.exports.__beta26.installForgivenessRbyShopFilter)
  end)



  return true
end
