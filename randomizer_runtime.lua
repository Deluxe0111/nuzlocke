-- Module owner: RandomizerRuntime
return function(mod, deps)
  deps = deps or {}
  local getCurrentGame = assert(deps.getCurrentGame, "randomizer_runtime requires getCurrentGame")
  local getCurrentSave = assert(deps.getCurrentSave, "randomizer_runtime requires getCurrentSave")
  local getNewGameRulesSnapshot = assert(deps.getNewGameRulesSnapshot, "randomizer_runtime requires getNewGameRulesSnapshot")
  local getPendingNewGameRules = assert(deps.getPendingNewGameRules, "randomizer_runtime requires getPendingNewGameRules")
  local saveBlocked = assert(deps.saveBlocked, "randomizer_runtime requires saveBlocked")
  local externalRuleDelegation = assert(deps.externalRuleDelegation, "randomizer_runtime requires externalRuleDelegation")
  local getGameVersion = assert(deps.getGameVersion, "randomizer_runtime requires getGameVersion")
  local specialAcquisitionDenied = assert(deps.specialAcquisitionDenied, "randomizer_runtime requires specialAcquisitionDenied")
  -- 2.6.74: one authoritative registry owns every Nuzlocke randomizer RNG
  -- stream name. Keep the string values identical to 2.6.73 so existing
  -- seeded results do not move; consumers reference this table instead of
  -- maintaining independent literals.
  local RANDOMIZER_STREAMS = {
      STARTER = "STARTER",
      STARTER_SLATE = "STARTER_SLATE",
      ENCOUNTERS = "ENCOUNTERS",
      FIELD_ITEMS = "FIELD_ITEMS",
      LEARNSETS = "LEARNSETS",
  }
  local RANDOMIZER_STREAM_ORDER = {
      "STARTER", "STARTER_SLATE", "ENCOUNTERS", "FIELD_ITEMS", "LEARNSETS",
  }

  -- 2.6.75: one authoritative source-map registry owns the durable save
  -- buckets used by the currently shipped randomizers. Existing bucket
  -- keys are preserved byte-for-byte; FIELD_ITEMS gains an explicit
  -- persisted source map while keeping its historical seeded choice input.
  local RANDOMIZER_SOURCE_MAPS = {
      STARTER = {
          saveKey = "__nuzlocke_random_starter_choices",
          stream = "STARTER",
      },
      STARTER_SLATE = {
          saveKey = "__nuzlocke_random_starter_choices",
          stream = "STARTER_SLATE",
      },
      ENCOUNTERS = {
          saveKey = "__nuzlocke_random_encounter_slots",
          stream = "ENCOUNTERS",
      },
      FIELD_ITEMS = {
          saveKey = "__nuzlocke_random_field_item_slots",
          stream = "FIELD_ITEMS",
      },
      LEARNSETS = {
          saveKey = "__nuzlocke_random_learnset_slots",
          stream = "LEARNSETS",
      },
  }

  -- 2.6.77: explicit ownership contracts for the only shipped randomizer
  -- systems that temporarily project into shared live registries. The registry
  -- is structural metadata; mutable baseline/applied identities remain on the
  -- Randomizer state so existing provider-drift behavior stays unchanged.
  local RANDOMIZER_PROJECTIONS = {
      ENCOUNTERS = {
          owner = "nuzlocke.randomizer.encounters",
          domain = "encounters",
          rule = "random_encounter_tables",
      },
      LEARNSETS = {
          owner = "nuzlocke.randomizer.learnsets",
          domain = "learnsets",
          rule = "random_learnsets",
      },
  }
  local RANDOMIZER_PROJECTION_ORDER = { "ENCOUNTERS", "LEARNSETS" }


  ---------------------------------------------------------------------
  -- TABLE / LEARNSET RANDOMIZERS (30.0.0.1)
  --
  -- These transform only the live merged registries and keep a pristine
  -- snapshot of the fields they own. This makes toggling reversible and lets
  -- upstream/provider registry composition happen first. Random choices are
  -- persisted by semantic slot key so reloads do not silently reroll a run.
  ---------------------------------------------------------------------
  do
      local Randomizer = {
          encounterSnapshot = nil,
          learnsetSnapshot = nil,
          encounterRegistry = nil,
          learnsetRegistry = nil,
          lastAutoSeed = nil,
          encounterApplied = nil,
          learnsetApplied = nil,
          projectionState = {
              ENCOUNTERS = { state = "idle", registry = nil },
              LEARNSETS = { state = "idle", registry = nil },
          },
      }
      local RUN_SEED_KEY = "__nuzlocke_randomizer_run_seed"
      local RUN_CONFIG_KEY = "__nuzlocke_randomizer_run_config"
      local RUN_CONFIG_SCHEMA = 1
      local DIAGNOSTIC_KEY = "__nuzlocke_randomizer_constraint_diagnostics"
      local DIAGNOSTIC_LIMIT = 24

      -- These are the settings that define the currently shipped randomizer
      -- world. The snapshot is additive in 2.6.74: existing runtime behavior
      -- still reads the same durable rule values, while the immutable copy
      -- gives future migrations/diagnostics a stable run contract.
      local RANDOMIZER_CONFIG_KEYS = {
          "randomizer_seed",
          "random_starter",
          "random_starter_style",
          "random_starter_balance",
          "random_starter_trio_typing",
          "random_starter_rerolls",
          "random_encounter_tables",
          "random_field_items",
          "random_field_item_balance",
          "random_field_item_repetition",
          "random_encounter_balance",
          "random_encounter_repetition",
          "random_encounter_diversity_strength",
          "randomizer_info_policy",
          "random_species_generation",
          "random_learnsets",
          "random_learnset_generation",
      }

      local function copy(value)
          if type(value) ~= "table" then return value end
          local out = {}
          for k, v in pairs(value) do out[k] = copy(v) end
          return out
      end

      local function sameValue(a, b, seen)
          if a == b then return true end
          if type(a) ~= type(b) then return false end
          if type(a) ~= "table" then return false end
          seen = seen or {}
          if seen[a] == b then return true end
          seen[a] = b
          for k, v in pairs(a) do
              if not sameValue(v, b[k], seen) then return false end
          end
          for k in pairs(b) do
              if a[k] == nil then return false end
          end
          return true
      end

      Randomizer.algorithmVersion = 1

      local function seedHash(text)
          local value = 5381
          text = tostring(text or "")
          for i = 1, #text do
              value = (value * 33 + text:byte(i)) % 2147483647
          end
          return value
      end

      local function boundedSeed(value)
          value = tonumber(value) or 0
          return math.max(0, math.min(99999999, math.floor(value)))
      end

      local function entropySeed(exclude)
          exclude = boundedSeed(exclude)
          local rng = love and love.math and love.math.random or math.random
          for _ = 1, 4 do
              local ok, value = pcall(rng, 1, 99999999)
              value = ok and boundedSeed(value) or 0
              if value > 0 and value ~= exclude then return value end
          end
          local now = os and os.time and os.time() or 1
          local value = 1 + (seedHash(tostring(now) .. ":NUZLOCKE:"
              .. tostring(exclude)) % 99999999)
          if value == exclude then value = (value % 99999999) + 1 end
          return value
      end

      -- `randomizer_seed` is the player's CONFIGURATION. Zero remains AUTO.
      -- AUTO's resolved seed lives separately in the current playthrough so a
      -- fresh NEW GAME can roll again without rewriting the staged Setup
      -- profile to a fixed seed. Existing nonzero seeds remain fixed/replayable.
      mod.exports.__beta26.randomizerSeed = function(profile, create)
          if type(profile) == "table" then
              return boundedSeed(profile.randomizer_seed)
          end

          local configured = boundedSeed(mod.save:get("randomizer_seed", 0))
          if configured > 0 then return configured end

          local resolved = boundedSeed(mod.save:get(RUN_SEED_KEY, 0))
          if resolved > 0 then
              Randomizer.lastAutoSeed = resolved
              return resolved
          end
          if create == true then
              resolved = entropySeed(Randomizer.lastAutoSeed)
              mod.save:set(RUN_SEED_KEY, resolved)
              Randomizer.lastAutoSeed = resolved
          end
          return resolved
      end

      local function randomizerConfigValue(profile, key)
          if type(profile) == "table" and profile[key] ~= nil then
              return copy(profile[key])
          end
          return copy(mod.save:get(key, nil))
      end

      local function randomizerConfigured(profile)
          local function enabled(key)
              if type(profile) == "table" and profile[key] ~= nil then
                  return profile[key] == true
              end
              return mod.save:get(key, false) == true
          end
          return enabled("random_starter")
              or enabled("random_encounter_tables")
              or enabled("random_field_items")
              or enabled("random_learnsets")
      end

      local function captureRandomizerRunConfig(profile, resolvedSeed)
          if not randomizerConfigured(profile) then
              mod.save:set(RUN_CONFIG_KEY, nil)
              return nil
          end
          local existing = mod.save:get(RUN_CONFIG_KEY, nil)
          if type(existing) == "table" and existing.schema == RUN_CONFIG_SCHEMA then
              return copy(existing)
          end
          local settings = {}
          for _, key in ipairs(RANDOMIZER_CONFIG_KEYS) do
              settings[key] = randomizerConfigValue(profile, key)
          end
          local snapshot = {
              schema = RUN_CONFIG_SCHEMA,
              algorithm = Randomizer.algorithmVersion,
              seed = boundedSeed(resolvedSeed),
              game = tostring(getGameVersion() or "UNKNOWN"),
              settings = settings,
          }
          mod.save:set(RUN_CONFIG_KEY, snapshot)
          return copy(snapshot)
      end

      mod.exports.__beta26.randomizerRunConfigKey = RUN_CONFIG_KEY
      mod.exports.__beta26.randomizerRunConfigSchema = RUN_CONFIG_SCHEMA
      mod.exports.__beta26.randomizerRunConfig = function()
          local snapshot = mod.save:get(RUN_CONFIG_KEY, nil)
          return type(snapshot) == "table" and copy(snapshot) or nil
      end
      mod.exports.__beta26.randomizerCaptureRunConfig = captureRandomizerRunConfig

      local function constraintDiagnostic(entry)
          if type(entry) ~= "table" then return false end
          local row = {
              subsystem = tostring(entry.subsystem or "UNKNOWN"):upper(),
              source = tostring(entry.source or ""),
              requested = tostring(entry.requested or ""),
              result = tostring(entry.result or ""),
              stage = math.max(0, math.floor(tonumber(entry.stage) or 0)),
              input = math.max(0, math.floor(tonumber(entry.input) or 0)),
              safe = math.max(0, math.floor(tonumber(entry.safe) or 0)),
              candidates = math.max(0, math.floor(tonumber(entry.candidates) or 0)),
              relaxed = entry.relaxed == true,
              fallback = entry.fallback == true,
              reason = tostring(entry.reason or ""),
          }
          local log = mod.save:get(DIAGNOSTIC_KEY, {})
          if type(log) ~= "table" then log = {} end
          log[#log + 1] = row
          while #log > DIAGNOSTIC_LIMIT do table.remove(log, 1) end
          mod.save:set(DIAGNOSTIC_KEY, log)
          return true
      end

      mod.exports.__beta26.randomizerConstraintDiagnosticKey = DIAGNOSTIC_KEY
      mod.exports.__beta26.randomizerConstraintDiagnostic = constraintDiagnostic
      mod.exports.__beta26.randomizerConstraintDiagnostics = function()
          local log = mod.save:get(DIAGNOSTIC_KEY, {})
          return type(log) == "table" and copy(log) or {}
      end
      mod.exports.__beta26.clearRandomizerConstraintDiagnostics = function()
          mod.save:set(DIAGNOSTIC_KEY, {})
          return true
      end

      mod.exports.__beta26.randomizerStreamNames = function()
          local out = {}
          for i, name in ipairs(RANDOMIZER_STREAM_ORDER) do out[i] = name end
          return out
      end

      mod.exports.__beta26.randomizerSeedMode = function(profile)
          local configured = type(profile) == "table"
              and boundedSeed(profile.randomizer_seed)
              or boundedSeed(mod.save:get("randomizer_seed", 0))
          return configured > 0 and "FIXED" or "AUTO"
      end

      mod.exports.__beta26.resetRandomizerRunSeed = function()
          mod.save:set(RUN_SEED_KEY, nil)
          mod.save:set(RUN_CONFIG_KEY, nil)
          return true
      end

      mod.exports.__beta26.randomizerRerollSeed = function(profile)
          local current = type(profile) == "table"
              and boundedSeed(profile.randomizer_seed)
              or boundedSeed(mod.save:get("randomizer_seed", 0))
          local value = entropySeed(current > 0 and current or Randomizer.lastAutoSeed)
          if type(profile) == "table" then
              profile.randomizer_seed = value
              profile.random_starter_reroll_index = 0
              profile.__randomizer_legacy = nil
          else
              mod.save:set("randomizer_seed", value)
              mod.save:set("__nuzlocke_random_starter_reroll_index", 0)
              mod.save:set(RUN_SEED_KEY, nil)
              mod.save:set(RUN_CONFIG_KEY, nil)
          end
          return value
      end

      mod.exports.__beta26.ensureRandomizerRunSeed = function(profile)
          profile = type(profile) == "table" and profile or nil
          local configured = profile and boundedSeed(profile.randomizer_seed)
              or boundedSeed(mod.save:get("randomizer_seed", 0))
          local enabled = randomizerConfigured(profile)
          if not enabled then
              mod.save:set(RUN_SEED_KEY, nil)
              mod.save:set(RUN_CONFIG_KEY, nil)
              return 0
          end

          local resolved
          if configured > 0 then
              mod.save:set(RUN_SEED_KEY, nil)
              resolved = configured
          else
              resolved = mod.exports.__beta26.randomizerSeed(nil, true)
          end
          captureRandomizerRunConfig(profile, resolved)
          return resolved
      end

      mod.exports.__beta26.randomizerRunSeedKey = RUN_SEED_KEY

      mod.exports.__beta26.randomizerAlgorithmVersion = function()
          return Randomizer.algorithmVersion
      end

      local function seededIndexFor(seed, stream, slot, count)
          count = math.max(1, math.floor(tonumber(count) or 1))
          if count <= 1 then return 1 end
          seed = boundedSeed(seed)
          local value = seedHash(table.concat({
              tostring(Randomizer.algorithmVersion), tostring(seed),
              tostring(stream or "RNG"), tostring(slot or "")
          }, ":"))
          return 1 + (value % count)
      end

      local function seededIndex(stream, slot, count)
          if count <= 1 then return 1 end
          local seed = mod.exports.__beta26.randomizerSeed(nil, true)
          if seed <= 0 then
              local rng = love and love.math and love.math.random or math.random
              return rng(1, count)
          end
          return seededIndexFor(seed, stream, slot, count)
      end

      -- Cross-phase consumers must use an exported helper rather than reaching
      -- for this block's local seededIndex/Randomizer names. Lua resolves an
      -- out-of-scope local as a global at runtime, which is exactly how the
      -- 2.5.22 starter regression escaped compile-only validation.
      mod.exports.__beta26.randomizerSeededIndex = seededIndex
      mod.exports.__beta26.randomizerSeededIndexFor = seededIndexFor

      -- Structural self-audit for the stream registry. It intentionally hashes
      -- stream identifiers directly rather than comparing modulo selections,
      -- which could collide by chance for a small candidate pool.
      mod.exports.__beta26.randomizerStreamRegistryAudit = function()
          local report = { ok = true, count = 0, names = {}, failures = {} }
          local seenNames, seenHashes = {}, {}
          for _, key in ipairs(RANDOMIZER_STREAM_ORDER) do
              local name = RANDOMIZER_STREAMS[key]
              report.count = report.count + 1
              report.names[#report.names + 1] = name
              if type(name) ~= "string" or name == "" then
                  report.ok = false
                  report.failures[#report.failures + 1] = tostring(key) .. ":invalid_name"
              elseif seenNames[name] then
                  report.ok = false
                  report.failures[#report.failures + 1] = name .. ":duplicate_name"
              else
                  seenNames[name] = true
                  local fingerprint = seedHash("STREAM:" .. name)
                  if seenHashes[fingerprint] then
                      report.ok = false
                      report.failures[#report.failures + 1] = name .. ":hash_collision"
                  else
                      seenHashes[fingerprint] = name
                  end
              end
          end
          return report
      end

      mod.exports.__beta26.randomizerSourceMapRegistry = function()
          local out = {}
          for _, key in ipairs(RANDOMIZER_STREAM_ORDER) do
              local source = RANDOMIZER_SOURCE_MAPS[key]
              if source then
                  out[key] = {
                      saveKey = source.saveKey,
                      stream = source.stream,
                  }
              end
          end
          return out
      end

      mod.exports.__beta26.randomizerSourceMapAudit = function()
          local report = { ok = true, count = 0, failures = {}, buckets = {} }
          local seenStream = {}
          for _, key in ipairs(RANDOMIZER_STREAM_ORDER) do
              local source = RANDOMIZER_SOURCE_MAPS[key]
              report.count = report.count + 1
              if type(source) ~= "table" then
                  report.ok = false
                  report.failures[#report.failures + 1] = key .. ":missing_source_map"
              else
                  local stream = RANDOMIZER_STREAMS[source.stream]
                  if type(source.saveKey) ~= "string" or source.saveKey == "" then
                      report.ok = false
                      report.failures[#report.failures + 1] = key .. ":invalid_save_key"
                  end
                  if type(stream) ~= "string" or stream == "" then
                      report.ok = false
                      report.failures[#report.failures + 1] = key .. ":invalid_stream_owner"
                  else
                      seenStream[source.stream] = true
                  end
                  local stored = mod.save:get(source.saveKey, nil)
                  if stored ~= nil and type(stored) ~= "table" then
                      report.ok = false
                      report.failures[#report.failures + 1] = key .. ":corrupt_saved_map"
                  end
                  report.buckets[key] = source.saveKey
              end
          end
          for _, key in ipairs(RANDOMIZER_STREAM_ORDER) do
              if not seenStream[key] then
                  report.ok = false
                  report.failures[#report.failures + 1] = key .. ":unowned_stream"
              end
          end
          return report
      end

      -- Pure, synthetic isolation audit. It never reads/writes run state and
      -- therefore cannot consume the player's randomizer seed or mappings.
      -- It proves each named stream is stable under interleaving and that the
      -- stream identifier participates in the deterministic hash namespace.
      mod.exports.__beta26.randomizerStreamIsolationAudit = function()
          local report = { ok = true, checked = 0, failures = {} }
          local seeds = { 1, 12345678, 99999999 }
          local slots = { "probe:A", "probe:B", "probe:C" }
          for _, seed in ipairs(seeds) do
              for _, slot in ipairs(slots) do
                  local before = {}
                  local fingerprints = {}
                  for _, key in ipairs(RANDOMIZER_STREAM_ORDER) do
                      local stream = RANDOMIZER_STREAMS[key]
                      before[key] = seededIndexFor(seed, stream, slot, 1000003)
                      local fingerprint = seedHash(table.concat({
                          tostring(Randomizer.algorithmVersion), tostring(seed),
                          tostring(stream), tostring(slot)
                      }, ":"))
                      if fingerprints[fingerprint] then
                          report.ok = false
                          report.failures[#report.failures + 1] =
                              key .. ":namespace_collision:" .. fingerprints[fingerprint]
                      else
                          fingerprints[fingerprint] = key
                      end
                      report.checked = report.checked + 1
                  end
                  for _, key in ipairs(RANDOMIZER_STREAM_ORDER) do
                      local stream = RANDOMIZER_STREAMS[key]
                      seededIndexFor(seed, stream, slot .. ":interleave", 997)
                  end
                  for _, key in ipairs(RANDOMIZER_STREAM_ORDER) do
                      local stream = RANDOMIZER_STREAMS[key]
                      local after = seededIndexFor(seed, stream, slot, 1000003)
                      if after ~= before[key] then
                          report.ok = false
                          report.failures[#report.failures + 1] =
                              key .. ":interleaving_changed_output"
                      end
                  end
              end
          end
          return report
      end

      -- 2.6.76 Phase A: shared candidate-policy primitives. These helpers are
      -- intentionally pure and additive in this release: existing randomizer
      -- features keep their historical selection algorithms/seed inputs while
      -- future migrations can consume one governed policy surface.
      --
      -- Hard safety predicates are never relaxed. Soft preference stages may
      -- widen in caller-authored order, and diversity is expressed as a weight
      -- rather than a hard exclusion so constrained pools cannot dead-end.
      local function candidateKey(value)
          if type(value) == "table" then
              local id = value.id or value.key or value.name or value.species or value.item
              if id ~= nil then return tostring(id):upper() end
          end
          return tostring(value or ""):upper()
      end

      local function semanticSafeCandidates(candidates, predicates)
          local out, rejected = {}, {}
          predicates = type(predicates) == "table" and predicates or {}
          for _, candidate in ipairs(type(candidates) == "table" and candidates or {}) do
              local safe, reason = true, nil
              for _, predicate in ipairs(predicates) do
                  if type(predicate) == "function" then
                      local ok, allowed, why = pcall(predicate, candidate)
                      if not ok or allowed ~= true then
                          safe = false
                          reason = ok and tostring(why or "rejected") or "predicate_error"
                          break
                      end
                  end
              end
              if safe then
                  out[#out + 1] = candidate
              else
                  rejected[#rejected + 1] = {
                      key = candidateKey(candidate),
                      reason = reason or "rejected",
                  }
              end
          end
          return out, rejected
      end

      local function progressiveCandidatePool(candidates, predicates, stages)
          local safe, rejected = semanticSafeCandidates(candidates, predicates)
          local report = {
              input = type(candidates) == "table" and #candidates or 0,
              safe = #safe,
              stage = 0,
              relaxed = false,
              rejected = rejected,
          }
          if #safe == 0 then return safe, report end
          stages = type(stages) == "table" and stages or {}
          for index, stage in ipairs(stages) do
              if type(stage) == "function" then
                  local filtered = {}
                  for _, candidate in ipairs(safe) do
                      local ok, accepted = pcall(stage, candidate)
                      if ok and accepted == true then filtered[#filtered + 1] = candidate end
                  end
                  if #filtered > 0 then
                      report.stage = index
                      report.relaxed = index > 1
                      report.result = #filtered
                      return filtered, report
                  end
              end
          end
          -- No soft stage matched: fall back only to the hard-safe pool.
          report.stage = #stages + 1
          report.relaxed = #stages > 0
          report.result = #safe
          return safe, report
      end

      local function diversityWeights(candidates, usage, penalty)
          local out, total = {}, 0
          usage = type(usage) == "table" and usage or {}
          penalty = tonumber(penalty) or 0.5
          if penalty <= 0 or penalty > 1 then penalty = 0.5 end
          for index, candidate in ipairs(type(candidates) == "table" and candidates or {}) do
              local used = math.max(0, math.floor(tonumber(usage[candidateKey(candidate)]) or 0))
              local weight = penalty ^ used
              -- Keep every legal candidate reachable. Diversity is a soft
              -- preference and must never turn into an accidental hard ban.
              if weight <= 0 then weight = 0.000001 end
              out[index] = weight
              total = total + weight
          end
          return out, total
      end

      local function weightedCandidateIndex(seed, stream, slot, candidates, usage, penalty)
          if type(candidates) ~= "table" or #candidates == 0 then return nil end
          if #candidates == 1 then return 1 end
          local weights, total = diversityWeights(candidates, usage, penalty)
          if total <= 0 then return seededIndexFor(seed, stream, slot, #candidates) end
          -- Use a large deterministic integer bucket rather than mutable RNG
          -- state. Existing feature algorithms do not call this helper yet.
          local bucketCount = 1000000
          local bucket = seededIndexFor(seed, stream, tostring(slot) .. ":diversity",
              bucketCount) - 1
          local target = (bucket / bucketCount) * total
          local cumulative = 0
          for index, weight in ipairs(weights) do
              cumulative = cumulative + weight
              if target < cumulative then return index end
          end
          return #candidates
      end

      local function withoutReplacementPool(candidates, used)
          local available, exhausted = {}, false
          used = type(used) == "table" and used or {}
          for _, candidate in ipairs(type(candidates) == "table" and candidates or {}) do
              if used[candidateKey(candidate)] ~= true then
                  available[#available + 1] = candidate
              end
          end
          if #available == 0 and type(candidates) == "table" and #candidates > 0 then
              exhausted = true
              for _, candidate in ipairs(candidates) do available[#available + 1] = candidate end
          end
          return available, exhausted
      end

      local function selectWithoutReplacement(seed, stream, slot, candidates, used)
          local pool, exhausted = withoutReplacementPool(candidates, used)
          if #pool == 0 then return nil, exhausted, pool end
          local index = seededIndexFor(seed, stream, tostring(slot) .. ":unique", #pool)
          return pool[index], exhausted, pool
      end

      mod.exports.__beta26.randomizerWithoutReplacementPool = withoutReplacementPool
      mod.exports.__beta26.randomizerSelectWithoutReplacement = selectWithoutReplacement

      local function resolveCandidatePolicy(context, candidates, predicates, stages)
          context = type(context) == "table" and context or {}
          local pool, meta = progressiveCandidatePool(candidates, predicates, stages)
          local requested = tostring(context.requested or "")
          local result
          if #pool == 0 then
              result = "NO_SAFE_CANDIDATES"
          elseif meta.stage > #(type(stages) == "table" and stages or {}) then
              result = "HARD_SAFE_POOL"
          else
              result = "PREFERENCE_STAGE_" .. tostring(meta.stage)
          end
          if context.record ~= false then
              constraintDiagnostic({
                  subsystem = context.subsystem,
                  source = context.source,
                  requested = requested,
                  result = result,
                  stage = meta.stage,
                  input = meta.input,
                  safe = meta.safe,
                  candidates = #pool,
                  relaxed = meta.relaxed,
                  fallback = meta.relaxed or #pool == 0,
                  reason = tostring(context.reason or ""),
              })
          end
          return pool, meta
      end

      mod.exports.__beta26.randomizerResolveCandidatePolicy = resolveCandidatePolicy
      mod.exports.__beta26.randomizerSemanticSafeCandidates = semanticSafeCandidates
      mod.exports.__beta26.randomizerProgressiveCandidatePool = progressiveCandidatePool
      mod.exports.__beta26.randomizerDiversityWeights = diversityWeights
      mod.exports.__beta26.randomizerWeightedCandidateIndex = weightedCandidateIndex

      mod.exports.__beta26.randomizerCandidatePolicyAudit = function()
          local report = { ok = true, checked = 0, failures = {} }
          local candidates = { "A", "B", "C", "D" }
          local hard = {
              function(value)
                  if value == "D" then return false, "unsafe" end
                  return true
              end,
          }
          local stages = {
              function(value) return value == "Z" end,
              function(value) return value == "B" or value == "C" end,
          }
          local pool, meta = progressiveCandidatePool(candidates, hard, stages)
          report.checked = report.checked + 1
          if #pool ~= 2 or pool[1] ~= "B" or pool[2] ~= "C"
              or meta.stage ~= 2 or meta.relaxed ~= true then
              report.ok = false
              report.failures[#report.failures + 1] = "progressive_relaxation"
          end
          report.checked = report.checked + 1
          for _, value in ipairs(pool) do
              if value == "D" then
                  report.ok = false
                  report.failures[#report.failures + 1] = "hard_safety_relaxed"
              end
          end
          local safeOnly, safeMeta = progressiveCandidatePool(candidates, hard, {
              function() return false end,
          })
          report.checked = report.checked + 1
          if #safeOnly ~= 3 or safeMeta.stage ~= 2 then
              report.ok = false
              report.failures[#report.failures + 1] = "safe_pool_fallback"
          end
          local weights = diversityWeights({ "A", "B", "C" }, { A = 0, B = 1, C = 3 }, 0.5)
          report.checked = report.checked + 1
          if not (weights[1] > weights[2] and weights[2] > weights[3]
              and weights[3] > 0) then
              report.ok = false
              report.failures[#report.failures + 1] = "soft_diversity_weights"
          end
          local a = weightedCandidateIndex(12345678, RANDOMIZER_STREAMS.ENCOUNTERS,
              "policy_probe", { "A", "B", "C" }, { A = 0, B = 1, C = 2 }, 0.5)
          local b = weightedCandidateIndex(12345678, RANDOMIZER_STREAMS.ENCOUNTERS,
              "policy_probe", { "A", "B", "C" }, { A = 0, B = 1, C = 2 }, 0.5)
          report.checked = report.checked + 1
          if a ~= b or a == nil then
              report.ok = false
              report.failures[#report.failures + 1] = "diversity_not_deterministic"
          end
          local uniquePool, exhausted = withoutReplacementPool(
              { "A", "B", "C" }, { A = true })
          report.checked = report.checked + 1
          if exhausted or #uniquePool ~= 2 or uniquePool[1] ~= "B" or uniquePool[2] ~= "C" then
              report.ok = false
              report.failures[#report.failures + 1] = "without_replacement_filter"
          end
          local fallbackPool, fallbackExhausted = withoutReplacementPool(
              { "A", "B" }, { A = true, B = true })
          report.checked = report.checked + 1
          if not fallbackExhausted or #fallbackPool ~= 2 then
              report.ok = false
              report.failures[#report.failures + 1] = "without_replacement_exhaustion"
          end
          local uniqueA = selectWithoutReplacement(12345678,
              RANDOMIZER_STREAMS.STARTER_SLATE, "unique_probe",
              { "A", "B", "C" }, { A = true })
          local uniqueB = selectWithoutReplacement(12345678,
              RANDOMIZER_STREAMS.STARTER_SLATE, "unique_probe",
              { "A", "B", "C" }, { A = true })
          report.checked = report.checked + 1
          if uniqueA == nil or uniqueA ~= uniqueB or uniqueA == "A" then
              report.ok = false
              report.failures[#report.failures + 1] = "without_replacement_determinism"
          end
          return report
      end

      local function setProjectionState(key, state, registry)
          local row = Randomizer.projectionState[key]
          if type(row) ~= "table" then
              row = {}
              Randomizer.projectionState[key] = row
          end
          row.state = tostring(state or "idle")
          row.registry = registry
      end

      mod.exports.__beta26.randomizerProjectionRegistry = function()
          local out = {}
          for _, key in ipairs(RANDOMIZER_PROJECTION_ORDER) do
              local def = RANDOMIZER_PROJECTIONS[key]
              local state = Randomizer.projectionState[key] or {}
              out[key] = {
                  owner = def.owner,
                  domain = def.domain,
                  rule = def.rule,
                  state = state.state or "idle",
                  hasRegistry = state.registry ~= nil,
              }
          end
          return out
      end

      mod.exports.__beta26.randomizerProjectionAudit = function()
          local report = { ok = true, count = 0, failures = {} }
          local owners = {}
          for _, key in ipairs(RANDOMIZER_PROJECTION_ORDER) do
              report.count = report.count + 1
              local def = RANDOMIZER_PROJECTIONS[key]
              local state = Randomizer.projectionState[key]
              if type(def) ~= "table" or type(def.owner) ~= "string"
                  or def.owner == "" or type(def.domain) ~= "string"
                  or def.domain == "" or type(def.rule) ~= "string" or def.rule == "" then
                  report.ok = false
                  report.failures[#report.failures + 1] = key .. ":invalid_contract"
              elseif owners[def.owner] then
                  report.ok = false
                  report.failures[#report.failures + 1] = key .. ":duplicate_owner"
              else
                  owners[def.owner] = key
              end
              if type(state) ~= "table" or (state.state ~= "idle"
                  and state.state ~= "snapshotted"
                  and state.state ~= "applied"
                  and state.state ~= "delegated"
                  and state.state ~= "provider_adopted"
                  and state.state ~= "restored"
                  and state.state ~= "disabled") then
                  report.ok = false
                  report.failures[#report.failures + 1] = key .. ":invalid_state"
              end
          end
          return report
      end

      mod.exports.__beta26.randomizerConstraintDiagnosticAudit = function()
          local report = { ok = true, checked = 0, failures = {} }
          report.checked = report.checked + 1
          if type(DIAGNOSTIC_KEY) ~= "string" or DIAGNOSTIC_KEY == ""
              or DIAGNOSTIC_LIMIT ~= 24 then
              report.ok = false
              report.failures[#report.failures + 1] = "diagnostic_contract"
          end
          local row = {
              subsystem = "ENCOUNTERS",
              source = "probe",
              requested = "SIM_BST",
              result = "SAFE_POOL",
              stage = 2,
              input = 10,
              safe = 7,
              candidates = 4,
              relaxed = true,
              fallback = true,
              reason = "probe",
          }
          report.checked = report.checked + 1
          if row.input < row.safe or row.safe < row.candidates
              or row.relaxed ~= true or row.fallback ~= true then
              report.ok = false
              report.failures[#report.failures + 1] = "diagnostic_shape"
          end
          -- The actual ledger writer is intentionally not invoked here:
          -- diagnostics/self-tests must not mutate a player's run state.
          return report
      end

      mod.exports.__beta26.randomSpeciesGeneration = function(def)
          if type(def) ~= "table" then return nil end
          local explicit = tonumber(def.generation or def.gen)
          if explicit and explicit >= 1 then return math.floor(explicit) end
          local index = tonumber(def.index or def.dex or def.dexNumber or def.number)
          if not index then return nil end
          if index >= 1 and index <= 151 then return 1 end
          if index >= 152 and index <= 251 then return 2 end
          if index >= 252 and index <= 386 then return 3 end
          return nil
      end

      mod.exports.__beta26.randomSpeciesPoolAllows = function(def, mode)
          mode = math.max(0, math.min(3, math.floor(tonumber(mode) or 0)))
          if mode == 0 then return true end
          local generation = mod.exports.__beta26.randomSpeciesGeneration(def)
          if mode == 1 then return generation == 1 end
          if mode == 2 then return generation == 2 end
          return generation == 1 or generation == 2
      end

      local function effectiveRandomSpeciesGeneration()
          if mod.save:get("random_encounter_tables", false) ~= true then
              return 0
          end
          return math.max(0, math.min(3, math.floor(tonumber(
              mod.save:get("random_species_generation", 0)) or 0)))
      end

      local function effectiveRandomLearnsetGeneration()
          if mod.save:get("random_learnsets", false) ~= true then
              return 0
          end
          return math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_learnset_generation", 0)) or 0)))
      end

      mod.exports.__beta26.effectiveRandomSpeciesGeneration =
          effectiveRandomSpeciesGeneration
      mod.exports.__beta26.effectiveRandomLearnsetGeneration =
          effectiveRandomLearnsetGeneration

      mod.exports.__beta26.randomEncounterRuntimeSafe = function(game, species, level)
          species = tostring(species or ""):upper()
          level = math.max(1, math.floor(tonumber(level) or 5))
          local data = game and game.data
          local def = data and data.pokemon and data.pokemon[species]
          if type(def) ~= "table" or type(def.name) ~= "string" or def.name == ""
              or type(def.baseStats) ~= "table" or type(def.types) ~= "table" then
              return false
          end
          if mod.exports.__beta26.runtimeIsGen2(game) then
              if type(def.levelMoves) ~= "table" or type(def.evolutions) ~= "table"
                  or def.growthRate == nil or tonumber(def.catchRate) == nil
                  or tonumber(def.baseExp) == nil
                  or type(def.spriteFront) ~= "string" or def.spriteFront == ""
                  or type(def.spriteBack) ~= "string" or def.spriteBack == "" then
                  return false
              end
              local required = { "hp", "attack", "defense", "speed",
                  "specialAttack", "specialDefense" }
              for _, key in ipairs(required) do
                  if tonumber(def.baseStats[key]) == nil then return false end
              end
              for _, entry in ipairs(def.levelMoves) do
                  if type(entry) ~= "table" or tonumber(entry.level) == nil
                      or entry.move == nil then return false end
                  if tonumber(entry.level) <= level then
                      local move = data.moves and data.moves[entry.move]
                      if type(move) ~= "table" or tonumber(move.pp) == nil
                          or type(move.name) ~= "string" then return false end
                  end
              end
              return true
          end
          return type(mod.exports.__beta26.randomStarterRuntimeSafe) ~= "function"
              or mod.exports.__beta26.randomStarterRuntimeSafe(game, species, level)
      end

      local function speciesPool(game)
          local universe = {}
          local pokemon = game and game.data and game.data.pokemon or {}
          for id in pairs(pokemon) do
              local species = tostring(id or ""):upper()
              if species ~= "" then universe[#universe + 1] = species end
          end
          table.sort(universe)

          local mode = effectiveRandomSpeciesGeneration()
          local safe = mod.exports.__beta26.randomizerSemanticSafeCandidates(
              universe, {
                  function(species)
                      species = tostring(species or ""):upper()
                      local def = pokemon[species]
                      if species == "EGG" or species == "NONE"
                          or type(def) ~= "table" then
                          return false, "reserved_or_missing"
                      end
                      local glitch = mod.exports.__beta26.getGlitchSpeciesInfo(
                          game, species)
                      if glitch.isGlitch then return false, "glitch_species" end
                      if not mod.exports.__beta26.randomSpeciesPoolAllows(def, mode) then
                          return false, "species_pool"
                      end
                      if not mod.exports.__beta26.randomEncounterRuntimeSafe(
                          game, species, 5) then
                          return false, "runtime_unsafe"
                      end
                      if type(specialAcquisitionDenied) == "function"
                          and specialAcquisitionDenied(
                              game, species, nil, "random_encounter") ~= nil then
                          return false, "acquisition_denied"
                      end
                      return true
                  end,
              })
          return safe
      end

      local function movePool(game, generation)
          local out = {}
          generation = math.max(0, math.min(2, math.floor(tonumber(generation) or 0)))
          for id, def in pairs(game and game.data and game.data.moves or {}) do
              if type(def) == "table" then
                  local index = tonumber(def.index or def.id or def.number)
                  local allowed = generation == 0
                      or (generation == 1 and index and index >= 1 and index <= 165)
                      or (generation == 2 and index and index >= 166 and index <= 251)
                  local key = tostring(id or ""):upper()
                  if allowed and key ~= "" and key ~= "NONE"
                      and key ~= "NO_MOVE" and key ~= "STRUGGLE" then
                      out[#out + 1] = key
                  end
              end
          end
          table.sort(out)
          return out
      end

      local function persistedMap(key)
          local value = mod.save:get(key, {})
          return type(value) == "table" and value or {}
      end

      local function stableChoice(key, slot, pool, valid, stream, scope, options)
          if #pool == 0 then return nil end
          options = type(options) == "table" and options or {}
          local storageSlot = tostring(options.storageSlot or slot)
          local seedSlot = tostring(options.seedSlot or slot)
          local map = persistedMap(key)
          local seed = mod.exports.__beta26.randomizerSeed(nil, true)
          local storageScoped = seed > 0 and table.concat({
              "v" .. tostring(Randomizer.algorithmVersion),
              "s" .. tostring(seed), tostring(scope or "default"), storageSlot
          }, ":") or storageSlot
          local seedScoped = seed > 0 and table.concat({
              "v" .. tostring(Randomizer.algorithmVersion),
              "s" .. tostring(seed), tostring(scope or "default"), seedSlot
          }, ":") or seedSlot

          local saved = tostring(map[storageScoped] or ""):upper()
          if saved ~= "" and (not valid or valid(saved)) then return saved end

          -- Optional subsystem-policy migration: adopt an older scope row into
          -- the new policy namespace when its result is still legal there.
          for _, legacyScope in ipairs(type(options.legacyScopes) == "table"
              and options.legacyScopes or {}) do
              local legacyScoped = seed > 0 and table.concat({
                  "v" .. tostring(Randomizer.algorithmVersion),
                  "s" .. tostring(seed), tostring(legacyScope), storageSlot
              }, ":") or storageSlot
              local prior = tostring(map[legacyScoped] or ""):upper()
              if prior ~= "" and (not valid or valid(prior)) then
                  map[storageScoped] = prior
                  mod.save:set(key, map)
                  return prior
              end
          end

          -- When storage identity is upgraded, adopt the exact historical
          -- seed-scoped row first. This separates persistence identity from RNG
          -- identity without moving established or fresh v1 seeded outputs.
          if storageScoped ~= seedScoped then
              local prior = tostring(map[seedScoped] or ""):upper()
              if prior ~= "" and (not valid or valid(prior)) then
                  map[storageScoped] = prior
                  mod.save:set(key, map)
                  return prior
              end
          end

          -- Preserve pre-seed randomizer results on upgraded runs.
          local legacy = tostring(map[seedSlot] or map[storageSlot] or ""):upper()
          local legacyMarker = "__legacy_adopted:" .. storageSlot
          if map[legacyMarker] ~= true and legacy ~= "" and map[storageScoped] == nil
              and (not valid or valid(legacy)) then
              map[storageScoped] = legacy
              map[legacyMarker] = true
              mod.save:set(key, map)
              return legacy
          end

          local choice
          if type(options.choose) == "function" then
              local ok, index = pcall(options.choose, {
                  seed = seed,
                  stream = stream,
                  seedScoped = seedScoped,
                  storageScoped = storageScoped,
                  pool = pool,
              })
              if ok and tonumber(index) then
                  index = math.max(1, math.min(#pool,
                      math.floor(tonumber(index) or 1)))
                  choice = pool[index]
              end
          end
          if choice == nil then
              choice = pool[seededIndex(stream, seedScoped, #pool)]
          end
          map[storageScoped] = choice
          mod.save:set(key, map)
          return choice
      end

      local function evolutionShape(game)
          local pokemon = game and game.data and game.data.pokemon or {}
          local incoming, children = {}, {}
          for species, def in pairs(pokemon) do
              species = tostring(species or ""):upper()
              children[species] = children[species] or {}
              for _, evo in ipairs(type(def) == "table" and def.evolutions or {}) do
                  local target = type(evo) == "table" and tostring(evo.species or ""):upper() or ""
                  if target ~= "" and type(pokemon[target]) == "table" then
                      children[species][#children[species] + 1] = target
                      incoming[target] = (incoming[target] or 0) + 1
                  end
              end
          end
          local function stage(species)
              species = tostring(species or ""):upper()
              local hasParent = (incoming[species] or 0) > 0
              local hasChild = children[species] and #children[species] > 0
              if not hasParent and not hasChild then return "single" end
              if not hasParent then return "base" end
              if hasChild then return "middle" end
              return "final"
          end
          local function threeStageBase(species)
              species = tostring(species or ""):upper()
              if (incoming[species] or 0) > 0 then return false end
              for _, child in ipairs(children[species] or {}) do
                  if children[child] and #children[child] > 0 then return true end
              end
              return false
          end
          return stage, threeStageBase
      end

      -- Phase C #5-6: bounded evolution/progression profile used by EVO
      -- and BALANCED. This is deliberately read-only and cycle-safe.
      local function encounterEvolutionProfile(game)
          local pokemon = game and game.data and game.data.pokemon or {}
          local children, parents = {}, {}
          for species, def in pairs(pokemon) do
              species = tostring(species or ""):upper()
              children[species] = children[species] or {}
              parents[species] = parents[species] or {}
              for _, evo in ipairs(type(def) == "table" and def.evolutions or {}) do
                  local target = type(evo) == "table"
                      and tostring(evo.species or ""):upper() or ""
                  if target ~= "" and target ~= species
                      and type(pokemon[target]) == "table" then
                      children[species][#children[species] + 1] = target
                      parents[target] = parents[target] or {}
                      parents[target][#parents[target] + 1] = species
                  end
              end
              table.sort(children[species])
          end
          for _, list in pairs(parents) do table.sort(list) end

          local depthMemo, remainingMemo, ceilingMemo = {}, {}, {}
          local function minDepth(species, visiting)
              species = tostring(species or ""):upper()
              if depthMemo[species] ~= nil then return depthMemo[species] end
              visiting = visiting or {}
              if visiting[species] then return 0 end
              visiting[species] = true
              local ps = parents[species] or {}
              local best
              for _, parent in ipairs(ps) do
                  local value = minDepth(parent, visiting) + 1
                  best = best and math.min(best, value) or value
              end
              visiting[species] = nil
              best = best or 0
              depthMemo[species] = best
              return best
          end
          local function remaining(species, visiting)
              species = tostring(species or ""):upper()
              if remainingMemo[species] ~= nil then return remainingMemo[species] end
              visiting = visiting or {}
              if visiting[species] then return 0 end
              visiting[species] = true
              local best = 0
              for _, child in ipairs(children[species] or {}) do
                  best = math.max(best, remaining(child, visiting) + 1)
              end
              visiting[species] = nil
              remainingMemo[species] = best
              return best
          end
          local function ceilingBst(species, visiting)
              species = tostring(species or ""):upper()
              if ceilingMemo[species] ~= nil then return ceilingMemo[species] end
              visiting = visiting or {}
              if visiting[species] then
                  return tonumber(mod.exports.__beta26.getSpeciesBST(game, species)) or 0
              end
              visiting[species] = true
              local best = tonumber(mod.exports.__beta26.getSpeciesBST(game, species)) or 0
              for _, child in ipairs(children[species] or {}) do
                  best = math.max(best, ceilingBst(child, visiting))
              end
              visiting[species] = nil
              ceilingMemo[species] = best
              return best
          end
          local stage = evolutionShape(game)
          return {
              stage = stage,
              depth = minDepth,
              remaining = remaining,
              ceilingBst = ceilingBst,
          }
      end

      local function encounterSlotLevel(node)
          node = type(node) == "table" and node or {}
          local direct = tonumber(node.level)
          if direct then return math.max(1, math.floor(direct)) end
          local lo = tonumber(node.minLevel or node.levelMin)
          local hi = tonumber(node.maxLevel or node.levelMax)
          if lo and hi then return math.max(1, math.floor((lo + hi) / 2 + 0.5)) end
          if lo then return math.max(1, math.floor(lo)) end
          if hi then return math.max(1, math.floor(hi)) end
          if type(node.levels) == "table" then
              local total, count = 0, 0
              for _, value in pairs(node.levels) do
                  value = tonumber(value)
                  if value then total, count = total + value, count + 1 end
              end
              if count > 0 then return math.max(1, math.floor(total / count + 0.5)) end
          end
          return 5
      end

      local function encounterProgressionScore(game, profile, species, level)
          local current = tonumber(mod.exports.__beta26.getSpeciesBST(game, species))
          if not current then return nil end
          local ceiling = profile and profile.ceilingBst(species) or current
          -- Evolutionary ceiling matters more in later encounter bands while
          -- current BST remains dominant early. Capped at 45% of remaining
          -- potential to avoid turning this into a final-form-only metric.
          local factor = math.max(0, math.min(1, (tonumber(level) or 5) / 50))
          return current + math.max(0, ceiling - current) * (0.15 + 0.30 * factor)
      end

      local function similarBstPool(game, original, pool)
          local base = mod.exports.__beta26.getSpeciesBST(game, original)
          if not base then return {} end
          local tolerance = math.max(25, math.floor(base * 0.15 + 0.5))
          local out = {}
          for _, species in ipairs(pool) do
              local bst = mod.exports.__beta26.getSpeciesBST(game, species)
              if bst and math.abs(bst - base) <= tolerance then
                  out[#out + 1] = species
              end
          end
          return out
      end

      local function liveEncounterRegistry(game)
          if not (game and game.data) then return nil end
          if mod.exports.__beta26.runtimeIsGen2(game) then
              return game.data.gen2Encounters or game.data.encounters
          end
          return game.data.encounters
      end

      local function restoreEncounterRegistry(game)
          local registry = liveEncounterRegistry(game)
          if Randomizer.encounterSnapshot and Randomizer.encounterRegistry
              and registry == Randomizer.encounterRegistry then
              -- A provider may mutate the SAME registry table after Nuzlocke's
              -- pass.  Identity alone cannot detect that.  If live contents no
              -- longer equal our last applied image, the live table is the new
              -- authority: adopt it instead of repainting a stale snapshot.
              if Randomizer.encounterApplied
                  and not sameValue(registry, Randomizer.encounterApplied) then
                  Randomizer.encounterSnapshot = copy(registry)
                  Randomizer.encounterApplied = nil
                  setProjectionState("ENCOUNTERS", "provider_adopted", registry)
                  return
              end
              for k in pairs(registry) do registry[k] = nil end
              for k, v in pairs(Randomizer.encounterSnapshot) do
                  registry[k] = copy(v)
              end
              setProjectionState("ENCOUNTERS", "restored", registry)
          end
      end

      local function snapshotEncounters(game)
          local registry = liveEncounterRegistry(game)
          if type(registry) ~= "table" then return false end
          if Randomizer.encounterRegistry ~= registry then
              Randomizer.encounterRegistry = registry
              Randomizer.encounterSnapshot = copy(registry)
              setProjectionState("ENCOUNTERS", "snapshotted", registry)
          end
          return true
      end

      -- Phase C #2: encounter persistence owns a formal source identity
      -- separate from the historical RNG semantic slot. Path remains part of the
      -- identity as a collision-proof structural fallback when providers do not
      -- expose map/source/method/slot metadata.
      local function encounterIdentityToken(value)
          if value == nil then return "" end
          return tostring(value):upper()
              :gsub("%%", "%%25")
              :gsub("|", "%%7C")
              :gsub("=", "%%3D")
              :gsub("%s+", "_")
      end

      local function encounterSourceIdentity(node, path)
          node = type(node) == "table" and node or {}
          path = tostring(path or "encounters")
          local sourceId = node.nuzlockeSourceId or node.sourceId
          local mapId = node.mapId or node.areaId
          local method = node.method or node.encounterMethod
              or node.type or node.encounterType
          local tableId = node.tableId or node.encounterTableId
              or node.groupId or node.zoneId
          local slotId = node.slotId or node.slot or node.index
          local parts = {
              "map=" .. encounterIdentityToken(mapId),
              "source=" .. encounterIdentityToken(sourceId),
              "method=" .. encounterIdentityToken(method),
              "table=" .. encounterIdentityToken(tableId),
              "slot=" .. encounterIdentityToken(slotId),
              "path=" .. encounterIdentityToken(path),
          }
          return {
              canonical = table.concat(parts, "|"),
              legacySlot = path .. ".species",
              path = path,
              mapId = mapId,
              sourceId = sourceId,
              method = method,
              tableId = tableId,
              slotId = slotId,
          }
      end
      mod.exports.__beta26.randomizerEncounterSourceIdentity =
          encounterSourceIdentity

      local function encounterSourceGroupIdentity(identity)
          identity = type(identity) == "table" and identity or {}
          local path = tostring(identity.path or "encounters")
          local parentPath = path:gsub("%.[^%.]+$", "")
          return table.concat({
              "map=" .. encounterIdentityToken(identity.mapId),
              "class=" .. encounterIdentityToken(identity.encounterClass
                  or identity.method),
              "time=" .. encounterIdentityToken(identity.timeBucket),
              "table=" .. encounterIdentityToken(identity.tableId),
              "path=" .. encounterIdentityToken(parentPath),
          }, "|")
      end
      mod.exports.__beta26.randomizerEncounterGroupIdentity =
          encounterSourceGroupIdentity

      -- Phase C #8: normalize encounter table class/time semantics without
      -- changing the canonical persistence key or historical RNG slot.
      local function encounterTableClass(node, identity)
          node = type(node) == "table" and node or {}
          identity = type(identity) == "table" and identity or {}
          local raw = tostring(node.encounterClass or node.class
              or identity.method or ""):upper()
          local path = tostring(identity.path or ""):upper()
          local tableId = tostring(identity.tableId or ""):upper()
          local hay = table.concat({ raw, path, tableId }, "|")

          if hay:find("HEADBUTT", 1, true) or hay:find("TREE", 1, true) then
              return "TREE"
          elseif hay:find("FISH", 1, true)
              or hay:find("ROD", 1, true) then
              return "FISH"
          elseif hay:find("SURF", 1, true)
              or hay:find("WATER", 1, true) then
              return "SURF"
          elseif hay:find("BUG_CONTEST", 1, true)
              or hay:find("BUGCONTEST", 1, true)
              or hay:find("CONTEST", 1, true) then
              return "BUG_CONTEST"
          elseif hay:find("ROAMER", 1, true)
              or hay:find("ROAMING", 1, true) then
              return "ROAMER"
          elseif hay:find("CAVE", 1, true) then
              return "CAVE"
          elseif hay:find("GRASS", 1, true)
              or hay:find("WALK", 1, true)
              or hay:find("LAND", 1, true) then
              return "LAND"
          end
          return raw ~= "" and raw or "OTHER"
      end

      local function encounterTimeBucket(node, identity)
          node = type(node) == "table" and node or {}
          identity = type(identity) == "table" and identity or {}
          local raw = tostring(node.timeOfDay or node.daytime or node.time
              or identity.tableId or ""):upper()
          local path = tostring(identity.path or ""):upper()
          local hay = raw .. "|" .. path
          if hay:find("MORN", 1, true) or hay:find("MORNING", 1, true) then
              return "MORN"
          elseif hay:find("NITE", 1, true) or hay:find("NIGHT", 1, true)
              or hay:find("DARK", 1, true) then
              return "NITE"
          elseif hay:find("DAY", 1, true) then
              return "DAY"
          end
          return "ANY"
      end

      mod.exports.__beta26.randomizerEncounterTableClass =
          encounterTableClass
      mod.exports.__beta26.randomizerEncounterTimeBucket =
          encounterTimeBucket

      local function encounterLeafProtectionReason(node, identity)
          node = type(node) == "table" and node or {}
          identity = type(identity) == "table" and identity or {}
          if node.nuzlockeRandomizable == false or node.randomizable == false then
              return "record_opt_out"
          end
          if node.static == true or node.fixed == true
              or node.story == true or node.progression == true
              or node.quest == true or node.roamer == true
              or node.roaming == true then
              return "protected_flag"
          end
          local kind = tostring(node.kind or node.sourceType
              or node.encounterType or node.type or ""):upper()
          if kind == "STATIC" or kind == "FIXED" or kind == "STORY"
              or kind == "PROGRESSION" or kind == "QUEST"
              or kind == "GIFT" or kind == "TRAINER"
              or kind == "ROAMER" or kind == "ROAMING" then
              return "protected_kind"
          end
          local policy = tostring(node.randomization
              or node.nuzlockeRandomization or ""):lower()
          if policy == "deny" or policy == "provider"
              or policy == "preserve" or policy == "story"
              or policy == "external" or policy == "owned" then
              return "protected_policy"
          end
          local path = tostring(identity.path or ""):lower()
          if path:find(".static", 1, true) or path:find(".fixed", 1, true)
              or path:find(".story", 1, true)
              or path:find(".progression", 1, true)
              or path:find(".quest", 1, true)
              or path:find(".gift", 1, true)
              or path:find(".roamer", 1, true)
              or path:find(".roaming", 1, true) then
              return "protected_path"
          end
          return nil
      end
      mod.exports.__beta26.randomizerEncounterProtectionReason =
          encounterLeafProtectionReason

      local function collectEncounterLeaves(node, path, out)
          if type(node) ~= "table" then return end
          if type(node.species) == "string" then
              local identity = encounterSourceIdentity(node, path)
              identity.encounterClass = encounterTableClass(node, identity)
              identity.timeBucket = encounterTimeBucket(node, identity)
              out[#out + 1] = {
                  node = node,
                  identity = identity,
              }
          end
          local keys = {}
          for key, value in pairs(node) do
              if key ~= "species" and type(value) == "table" then
                  keys[#keys + 1] = key
              end
          end
          table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
          for _, key in ipairs(keys) do
              collectEncounterLeaves(node[key],
                  path .. "." .. tostring(key), out)
          end
      end

      local function encounterPreferenceStages(
          game, node, original, pool, balance, sharedProfile)
          if balance <= 0 then return {}, "CHAOS" end
          local profile = sharedProfile or encounterEvolutionProfile(game)
          local originalStage = profile.stage(original)
          local originalDepth = profile.depth(original)
          local originalRemaining = profile.remaining(original)
          local level = encounterSlotLevel(node)
          local baseBst = mod.exports.__beta26.getSpeciesBST(game, original)
          local progression = encounterProgressionScore(
              game, profile, original, level)

          local function bstBand(scale)
              if not baseBst then return function() return false end end
              local tolerance = math.max(25,
                  math.floor(baseBst * scale + 0.5))
              return function(species)
                  local bst = mod.exports.__beta26.getSpeciesBST(game, species)
                  return bst ~= nil and math.abs(bst - baseBst) <= tolerance
              end
          end
          local bst15, bst25, bst40 =
              bstBand(0.15), bstBand(0.25), bstBand(0.40)

          local function sameStage(species)
              return profile.stage(species) == originalStage
          end
          local function sameProgressionShape(species)
              return sameStage(species)
                  and math.abs(profile.depth(species) - originalDepth) <= 1
                  and math.abs(profile.remaining(species) - originalRemaining) <= 1
          end
          local function progressionNear(species, fraction)
              if not progression then return false end
              local score = encounterProgressionScore(
                  game, profile, species, level)
              local tolerance = math.max(30, progression * fraction)
              return score ~= nil and math.abs(score - progression) <= tolerance
          end

          if balance == 1 then
              return { bst15, bst25, bst40 }, "SIM_BST"
          elseif balance == 2 then
              return {
                  sameProgressionShape,
                  sameStage,
                  function(species) return progressionNear(species, 0.20) end,
              }, "EVO"
          end
          return {
              function(species)
                  return sameProgressionShape(species) and bst15(species)
              end,
              function(species)
                  return sameStage(species)
                      and progressionNear(species, 0.15)
              end,
              sameProgressionShape,
              sameStage,
              bst15,
              bst25,
              bst40,
          }, "BALANCED"
      end

      local ENCOUNTER_POLICY_VERSION = 2

      local function randomizeEncounterLeaf(
          game, leaf, pool, pokemon, groupUsage, repetition, sharedProfile)
          local node = leaf.node
          local identity = leaf.identity
          local protectedReason = encounterLeafProtectionReason(node, identity)
          if protectedReason ~= nil then
              return false
          end
          local allow = true
          if mod.exports.nuzlocke and mod.exports.nuzlocke.content then
              local ok, permitted = pcall(
                  mod.exports.nuzlocke.content.shouldRandomizeEncounter, {
                      id=identity.sourceId,
                      sourceId=identity.sourceId,
                      mapId=identity.mapId,
                      species=node.species,
                      randomizable=node.nuzlockeRandomizable ~= nil
                          and node.nuzlockeRandomizable or node.randomizable,
                      path=identity.path,
                      method=identity.method,
                      tableId=identity.tableId,
                      slotId=identity.slotId,
                      encounterClass=identity.encounterClass,
                      timeBucket=identity.timeBucket,
                      protected=false,
                  })
              if ok and permitted == false then allow = false end
          end
          if not allow then return false end

          local original = tostring(node.species or ""):upper()
          local balance = math.max(0, math.min(3, math.floor(tonumber(
              mod.save:get("random_encounter_balance", 0)) or 0)))
          repetition = math.max(0, math.min(2,
              math.floor(tonumber(repetition) or 0)))
          local diversityStrength = math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_encounter_diversity_strength", 1)) or 1)))
          local diversityFactors = { [0]=0.70, [1]=0.45, [2]=0.25 }
          local diversityFactor = diversityFactors[diversityStrength] or 0.45
          local generation = effectiveRandomSpeciesGeneration()
          local stages, requested =
              encounterPreferenceStages(
                  game, node, original, pool, balance, sharedProfile)
          local candidates = mod.exports.__beta26.randomizerResolveCandidatePolicy({
              subsystem = "ENCOUNTERS",
              source = identity.canonical,
              requested = requested,
              reason = "encounter_balance",
          }, pool, {}, stages)

          local groupKey = encounterSourceGroupIdentity(identity)
          local usage = groupUsage[groupKey]
          if type(usage) ~= "table" then
              usage = { counts = {}, used = {} }
              groupUsage[groupKey] = usage
          end

          local uniquenessExhausted = false
          if repetition == 2 then
              candidates, uniquenessExhausted =
                  mod.exports.__beta26.randomizerWithoutReplacementPool(
                      candidates, usage.used)
              if uniquenessExhausted then
                  mod.exports.__beta26.randomizerConstraintDiagnostic({
                      subsystem = "ENCOUNTERS",
                      source = identity.canonical,
                      requested = "UNIQUE",
                      result = "UNIQUENESS_EXHAUSTED",
                      stage = 0,
                      input = #candidates,
                      safe = #candidates,
                      candidates = #candidates,
                      relaxed = true,
                      fallback = true,
                      reason = "encounter_group_pool_exhausted",
                  })
              end
          end

          local oldScope = "b" .. tostring(balance)
              .. ".g" .. tostring(generation)
          local policyActive = balance > 0 or repetition > 0
          local scopeParts = {
              "ep" .. tostring(ENCOUNTER_POLICY_VERSION),
              "b" .. tostring(balance),
              "g" .. tostring(generation),
              "r" .. tostring(repetition),
          }
          if repetition == 1 and diversityStrength ~= 1 then
              scopeParts[#scopeParts + 1] = "d" .. tostring(diversityStrength)
          end
          local scope = policyActive and table.concat(scopeParts, ".")
              or oldScope

          local options = {
              storageSlot = identity.canonical,
              seedSlot = identity.legacySlot,
          }
          -- Adopt 2.6.82 balance-mode mappings only when repetition remains
          -- ALLOW. Switching to DIVERSE/UNIQUE is an intentional new world
          -- preference and therefore receives its own mapping.
          if balance > 0 and repetition == 0 then
              options.legacyScopes = { oldScope }
          end
          if repetition == 1 then
              options.choose = function(context)
                  return mod.exports.__beta26.randomizerWeightedCandidateIndex(
                      context.seed, context.stream, context.seedScoped,
                      context.pool, usage.counts, diversityFactor)
              end
          end

          local choice = stableChoice(
              RANDOMIZER_SOURCE_MAPS.ENCOUNTERS.saveKey,
              identity.canonical,
              candidates,
              function(id)
                  if type(pokemon[id]) ~= "table" then return false end
                  for _, candidate in ipairs(candidates) do
                      if candidate == id then return true end
                  end
                  return false
              end,
              RANDOMIZER_STREAMS.ENCOUNTERS,
              scope,
              options)
          if choice then
              choice = tostring(choice):upper()
              node.species = choice
              usage.counts[choice] = (tonumber(usage.counts[choice]) or 0) + 1
              usage.used[choice] = true
              return true
          end
          return false
      end

      -- Phase C #3: materialize the complete encounter work plan, sort by
      -- canonical source identity, then apply. Generation therefore cannot
      -- depend on map visit order, provider table insertion order, or which
      -- table a consumer happens to inspect first.
      local function encounterProfileForPass(game, balance, perfStats)
          balance = math.max(0, math.min(3,
              math.floor(tonumber(balance) or 0)))
          if balance <= 0 then return nil end
          if type(perfStats) == "table" then
              perfStats.profileBuilds =
                  (tonumber(perfStats.profileBuilds) or 0) + 1
          end
          return encounterEvolutionProfile(game)
      end

      local function randomizeEncounterRegistry(
          game, registry, pool, pokemon, perfStats)
          local leaves = {}
          collectEncounterLeaves(registry, "encounters", leaves)
          table.sort(leaves, function(a, b)
              if a.identity.canonical ~= b.identity.canonical then
                  return a.identity.canonical < b.identity.canonical
              end
              return a.identity.legacySlot < b.identity.legacySlot
          end)
          local repetition = math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_encounter_repetition", 0)) or 0)))
          local balance = math.max(0, math.min(3, math.floor(tonumber(
              mod.save:get("random_encounter_balance", 0)) or 0)))
          local sharedProfile =
              encounterProfileForPass(game, balance, perfStats)
          local groupUsage = {}
          for _, leaf in ipairs(leaves) do
              randomizeEncounterLeaf(
                  game, leaf, pool, pokemon, groupUsage, repetition,
                  sharedProfile)
          end
          return leaves
      end

      mod.exports.__beta26.randomizerEncounterProfileBuildAudit =
          function(game)
              game = game or getCurrentGame() or mod.game
              local report = { ok = true, checked = 0, failures = {} }
              local function check(id, balance, expected)
                  local stats = { profileBuilds = 0 }
                  encounterProfileForPass(game, balance, stats)
                  report.checked = report.checked + 1
                  if stats.profileBuilds ~= expected then
                      report.ok = false
                      report.failures[#report.failures + 1] =
                          tostring(id) .. ":" .. tostring(stats.profileBuilds)
                  end
              end
              -- Exact expectations matter: balanced modes require one build,
              -- while CHAOS must retain the zero-build cheap path.
              check("chaos_apply_boundary", 0, 0)
              check("balanced_apply_boundary", 3, 1)
              check("chaos_info_boundary", 0, 0)
              check("balanced_info_boundary", 2, 1)
              return report
          end

      mod.exports.__beta26.randomizerEncounterPlan = function(game)
          game = game or getCurrentGame() or mod.game
          local registry = liveEncounterRegistry(game)
          if type(registry) ~= "table" then return {} end
          local leaves = {}
          collectEncounterLeaves(registry, "encounters", leaves)
          table.sort(leaves, function(a, b)
              if a.identity.canonical ~= b.identity.canonical then
                  return a.identity.canonical < b.identity.canonical
              end
              return a.identity.legacySlot < b.identity.legacySlot
          end)
          local out = {}
          for index, leaf in ipairs(leaves) do
              out[index] = copy(leaf.identity)
          end
          return out
      end

      -- Phase C #10: area-split settings are tracker/logical-catch identity,
      -- not randomizer source identity. Expose that state explicitly so UIs and
      -- compatibility tools can invalidate projections without rebuilding or
      -- rerolling the physical encounter registry.
      mod.exports.__beta26.randomizerEncounterSplitState = function(game)
          game = game or getCurrentGame() or mod.game
          local function flag(key)
              return mod.save:get(key, false) == true
          end
          local function mode(key)
              return math.max(0, math.min(1,
                  math.floor(tonumber(mod.save:get(key, 0)) or 0)))
          end
          local routeSplit = mod.exports.__beta26.routeSplitActive
          return {
              route2 = type(routeSplit) == "function"
                  and routeSplit("route_2_split") == true
                  or flag("route_2_split"),
              route10 = type(routeSplit) == "function"
                  and routeSplit("route_10_split") == true
                  or flag("route_10_split"),
              route20 = type(routeSplit) == "function"
                  and routeSplit("route_20_split") == true
                  or flag("route_20_split"),
              mtMoon = mode("mt_moon_splits"),
              safari = mode("safari_zone_splits"),
              goldTime = flag("gold_time_split"),
              goldHeadbutt = flag("gold_headbutt_split"),
              edition = tostring(getGameVersion() or ""),
          }
      end

      mod.exports.__beta26.randomizerEncounterSplitChanged = function(game, key)
          game = game or getCurrentGame() or mod.game
          local state = mod.exports.__beta26.randomizerEncounterSplitState(game)
          state.changedKey = tostring(key or "")
          -- Do NOT call applyEncounters here. Split toggles reproject tracker /
          -- logical encounter ownership only; physical randomizer source identity
          -- and persisted mappings remain authoritative and unchanged.
          if mod.exports.nuzlocke and mod.exports.nuzlocke.registry
              and type(mod.exports.nuzlocke.registry.changed) == "function" then
              mod.exports.nuzlocke.registry.changed(
                  "encounter_identity", game, "area_split")
          end
          return state
      end

      local function encounterInfoRows(game, reveal, perfStats)
          local registry = liveEncounterRegistry(game)
          if type(registry) ~= "table" then return {}, 0, 0 end
          local leaves = {}
          collectEncounterLeaves(registry, "encounters", leaves)
          table.sort(leaves, function(a, b)
              if a.identity.canonical ~= b.identity.canonical then
                  return a.identity.canonical < b.identity.canonical
              end
              return a.identity.legacySlot < b.identity.legacySlot
          end)

          local originalSpecies = {}
          if type(Randomizer.encounterSnapshot) == "table" then
              local originalLeaves = {}
              collectEncounterLeaves(
                  Randomizer.encounterSnapshot, "encounters", originalLeaves)
              for _, originalLeaf in ipairs(originalLeaves) do
                  originalSpecies[originalLeaf.identity.canonical] =
                      tostring(originalLeaf.node.species or ""):upper()
              end
          end

          local pool = speciesPool(game)
          local balance = math.max(0, math.min(3, math.floor(tonumber(
              mod.save:get("random_encounter_balance", 0)) or 0)))
          local sharedProfile =
              encounterProfileForPass(game, balance, perfStats)
          local protectedCount = 0
          local rows = {}
          for _, leaf in ipairs(leaves) do
              local node = leaf.node
              local identity = leaf.identity
              local protectedReason = encounterLeafProtectionReason(node, identity)
              local row = {
                  canonical = identity.canonical,
                  legacySlot = identity.legacySlot,
                  mapId = identity.mapId,
                  sourceId = identity.sourceId,
                  method = identity.method,
                  tableId = identity.tableId,
                  slotId = identity.slotId,
                  encounterClass = identity.encounterClass,
                  timeBucket = identity.timeBucket,
                  group = encounterSourceGroupIdentity(identity),
                  protected = protectedReason ~= nil,
                  protectedReason = protectedReason,
              }
              if protectedReason ~= nil then
                  protectedCount = protectedCount + 1
                  row.candidateCount = 0
              else
                  local original = originalSpecies[identity.canonical]
                      or tostring(node.species or ""):upper()
                  local stages, requested =
                      encounterPreferenceStages(
                          game, node, original, pool, balance, sharedProfile)
                  row.originalSpeciesKnown =
                      originalSpecies[identity.canonical] ~= nil
                  local candidates, meta =
                      mod.exports.__beta26.randomizerResolveCandidatePolicy({
                          subsystem = "ENCOUNTERS",
                          source = identity.canonical,
                          requested = requested,
                          reason = "encounter_info",
                          record = false,
                      }, pool, {}, stages)
                  row.requested = requested
                  row.candidateCount = #candidates
                  row.preferenceStage = type(meta) == "table"
                      and tonumber(meta.stage) or nil
                  row.relaxed = type(meta) == "table"
                      and meta.relaxed == true or false
                  if reveal == true then
                      row.species = tostring(node.species or ""):upper()
                  end
              end
              rows[#rows + 1] = row
          end
          return rows, #leaves, protectedCount
      end

      -- Phase C #11: spoiler-aware read-only encounter diagnostics. This never
      -- calls stableChoice/applyEncounters and candidate resolution disables
      -- constraint-ledger writes, so reading it consumes zero RNG and mutates no
      -- randomizer mapping.
      mod.exports.__beta26.randomizerEncounterInfo = function(game, reveal)
          game = game or getCurrentGame() or mod.game
          local rows, sourceCount, protectedCount =
              encounterInfoRows(game, reveal == true)
          local diagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
              and mod.exports.__beta26.randomizerConstraintDiagnostics() or {}
          local constraints = {}
          for _, row in ipairs(diagnostics) do
              if tostring(row.subsystem or ""):upper() == "ENCOUNTERS" then
                  local copyRow = copy(row)
                  if reveal ~= true then
                      -- Constraint rows currently carry source identity and
                      -- counts, not randomized species, so they are safe under
                      -- BLIND. Keep this guard for future schema extensions.
                      copyRow.species = nil
                      copyRow.choice = nil
                      copyRow.resultSpecies = nil
                  end
                  constraints[#constraints + 1] = copyRow
              end
          end

          local mapping = mod.save:get(
              RANDOMIZER_SOURCE_MAPS.ENCOUNTERS.saveKey, {})
          local mappingCount = 0
          if type(mapping) == "table" then
              for key, value in pairs(mapping) do
                  if type(key) == "string"
                      and not key:match("^__legacy_adopted:")
                      and type(value) == "string" then
                      mappingCount = mappingCount + 1
                  end
              end
          end

          return {
              algorithmVersion =
                  mod.exports.__beta26.randomizerAlgorithmVersion(),
              encounterPolicyVersion = ENCOUNTER_POLICY_VERSION,
              seed = math.max(0, math.floor(tonumber(
                  mod.exports.__beta26.randomizerSeed(nil, false)) or 0)),
              balance = math.max(0, math.min(3, math.floor(tonumber(
                  mod.save:get("random_encounter_balance", 0)) or 0))),
              repetition = math.max(0, math.min(2, math.floor(tonumber(
                  mod.save:get("random_encounter_repetition", 0)) or 0))),
              diversityStrength = math.max(0, math.min(2, math.floor(tonumber(
                  mod.save:get("random_encounter_diversity_strength", 1)) or 1))),
              speciesGeneration = effectiveRandomSpeciesGeneration(),
              sourceCount = sourceCount,
              protectedCount = protectedCount,
              persistedMappingCount = mappingCount,
              splitState =
                  mod.exports.__beta26.randomizerEncounterSplitState(game),
              sources = rows,
              constraints = constraints,
              speciesRevealed = reveal == true,
          }
      end

      mod.exports.__beta26.randomizerEncounterSplitAudit = function(game)
          local report = { ok = true, checked = 0, failures = {} }
          game = game or getCurrentGame() or mod.game

          local node = {
              species = "RATTATA",
              mapId = "ROUTE_2",
              sourceId = "GRASS_SLOT_1",
              method = "WALK",
              tableId = "DAY",
              slotId = 1,
          }
          local before = encounterSourceIdentity(
              node, "encounters.ROUTE_2.grass.day.1")
          local state = mod.exports.__beta26.randomizerEncounterSplitState(game)
          local after = encounterSourceIdentity(
              node, "encounters.ROUTE_2.grass.day.1")

          report.checked = report.checked + 1
          if before.canonical ~= after.canonical
              or before.legacySlot ~= after.legacySlot then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "split_changed_randomizer_source_identity"
          end

          report.checked = report.checked + 1
          if type(state) ~= "table"
              or state.route2 == nil or state.route10 == nil
              or state.route20 == nil or state.mtMoon == nil
              or state.safari == nil or state.goldTime == nil
              or state.goldHeadbutt == nil then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "split_state_contract"
          end

          report.checked = report.checked + 1
          local map = mod.save:get(
              RANDOMIZER_SOURCE_MAPS.ENCOUNTERS.saveKey, {})
          if map ~= nil and type(map) ~= "table" then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "encounter_mapping_shape"
          end

          report.sourceIdentity = before.canonical
          report.splitState = state
          return report
      end

      mod.exports.__beta26.randomizerEncounterInfoAudit = function(game)
          local report = { ok = true, checked = 0, failures = {} }
          game = game or getCurrentGame() or mod.game

          local beforeDiagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics() or 0
          local beforeMap = mod.save:get(
              RANDOMIZER_SOURCE_MAPS.ENCOUNTERS.saveKey, {})
          local beforeMapCount = 0
          if type(beforeMap) == "table" then
              for _ in pairs(beforeMap) do beforeMapCount = beforeMapCount + 1 end
          end

          local okBlind, blind = pcall(
              mod.exports.__beta26.randomizerEncounterInfo, game, false)
          local middleDiagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics() or 0
          local okOpen, open = pcall(
              mod.exports.__beta26.randomizerEncounterInfo, game, true)
          local afterDiagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics() or 0
          local afterMap = mod.save:get(
              RANDOMIZER_SOURCE_MAPS.ENCOUNTERS.saveKey, {})
          local afterMapCount = 0
          if type(afterMap) == "table" then
              for _ in pairs(afterMap) do afterMapCount = afterMapCount + 1 end
          end

          report.checked = report.checked + 1
          if not (okBlind and okOpen and type(blind) == "table"
              and type(open) == "table"
              and blind.speciesRevealed == false
              and open.speciesRevealed == true) then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "open_blind_contract"
          end

          report.checked = report.checked + 1
          if beforeDiagnostics ~= middleDiagnostics
              or middleDiagnostics ~= afterDiagnostics then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "diagnostic_read_mutated_ledger"
          end

          report.checked = report.checked + 1
          if beforeMapCount ~= afterMapCount then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "diagnostic_read_mutated_mapping"
          end

          report.checked = report.checked + 1
          if type(blind) == "table" and type(blind.sources) == "table" then
              for _, row in ipairs(blind.sources) do
                  if row.species ~= nil then
                      report.ok = false
                      report.failures[#report.failures + 1] =
                          "blind_species_leak"
                      break
                  end
              end
          end

          return report
      end

      mod.exports.__beta26.randomizerEncounterIdentityAudit = function(game)
          local report = { ok = true, checked = 0, failures = {} }

          local a = encounterSourceIdentity({
              mapId = "ROUTE_1", sourceId = "GRASS",
              method = "WALK", tableId = "DAY", slotId = 1,
              species = "RATTATA",
          }, "encounters.ROUTE_1.grass.1")
          local b = encounterSourceIdentity({
              slotId = 1, tableId = "DAY", method = "WALK",
              sourceId = "GRASS", mapId = "ROUTE_1",
              species = "PIDGEY",
          }, "encounters.ROUTE_1.grass.1")
          report.checked = report.checked + 1
          if a.canonical ~= b.canonical
              or a.legacySlot ~= "encounters.ROUTE_1.grass.1.species" then
              report.ok = false
              report.failures[#report.failures + 1] = "source_identity_stability"
          end

          local syntheticA = {
              z = { species = "RATTATA", mapId = "A", slotId = 2 },
              a = { species = "PIDGEY", mapId = "A", slotId = 1 },
          }
          local syntheticB = {
              a = { species = "PIDGEY", mapId = "A", slotId = 1 },
              z = { species = "RATTATA", mapId = "A", slotId = 2 },
          }
          local leavesA, leavesB = {}, {}
          collectEncounterLeaves(syntheticA, "encounters", leavesA)
          collectEncounterLeaves(syntheticB, "encounters", leavesB)
          local function orderedIds(leaves)
              table.sort(leaves, function(x, y)
                  if x.identity.canonical ~= y.identity.canonical then
                      return x.identity.canonical < y.identity.canonical
                  end
                  return x.identity.legacySlot < y.identity.legacySlot
              end)
              local ids = {}
              for i, leaf in ipairs(leaves) do ids[i] = leaf.identity.canonical end
              return table.concat(ids, "\n")
          end
          report.checked = report.checked + 1
          if orderedIds(leavesA) ~= orderedIds(leavesB) then
              report.ok = false
              report.failures[#report.failures + 1] = "table_order_dependence"
          end

          game = game or getCurrentGame() or mod.game
          local plan = mod.exports.__beta26.randomizerEncounterPlan(game)
          local seen = {}
          report.checked = report.checked + 1
          for _, identity in ipairs(plan) do
              local key = tostring(identity.canonical or "")
              if key == "" or seen[key] then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      key == "" and "empty_identity" or "duplicate_identity"
                  break
              end
              seen[key] = true
          end
          report.sources = #plan
          return report
      end

      mod.exports.__beta26.randomizerEncounterPolicyAudit = function(game)
          local report = { ok = true, checked = 0, failures = {} }

          local pool, exhausted =
              mod.exports.__beta26.randomizerWithoutReplacementPool(
                  { "A", "B", "C" }, { A = true })
          report.checked = report.checked + 1
          if exhausted or #pool ~= 2 or pool[1] ~= "B" or pool[2] ~= "C" then
              report.ok = false
              report.failures[#report.failures + 1] = "unique_filter"
          end

          local fallback, fallbackExhausted =
              mod.exports.__beta26.randomizerWithoutReplacementPool(
                  { "A", "B" }, { A = true, B = true })
          report.checked = report.checked + 1
          if not fallbackExhausted or #fallback ~= 2 then
              report.ok = false
              report.failures[#report.failures + 1] = "unique_exhaustion"
          end

          local weights = mod.exports.__beta26.randomizerDiversityWeights(
              { "A", "B", "C" }, { A = 0, B = 1, C = 3 }, 0.45)
          report.checked = report.checked + 1
          if not (weights[1] > weights[2]
              and weights[2] > weights[3] and weights[3] > 0) then
              report.ok = false
              report.failures[#report.failures + 1] = "diversity_weights"
          end

          local g1 = encounterSourceGroupIdentity({
              mapId="ROUTE_1", sourceId="GRASS", method="WALK",
              tableId="DAY", slotId=1,
              path="encounters.ROUTE_1.grass.1",
          })
          local g2 = encounterSourceGroupIdentity({
              mapId="ROUTE_1", sourceId="GRASS", method="WALK",
              tableId="DAY", slotId=2,
              path="encounters.ROUTE_1.grass.2",
          })
          report.checked = report.checked + 1
          if g1 ~= g2 then
              report.ok = false
              report.failures[#report.failures + 1] = "group_slot_split"
          end

          report.checked = report.checked + 1
          if ENCOUNTER_POLICY_VERSION ~= 2 then
              report.ok = false
              report.failures[#report.failures + 1] = "policy_version"
          end

          game = game or getCurrentGame() or mod.game
          if game and game.data and game.data.pokemon then
              local profile = encounterEvolutionProfile(game)
              report.checked = report.checked + 1
              if type(profile) ~= "table"
                  or type(profile.depth) ~= "function"
                  or type(profile.remaining) ~= "function"
                  or type(profile.ceilingBst) ~= "function" then
                  report.ok = false
                  report.failures[#report.failures + 1] = "progression_profile"
              end
          end
          return report
      end

      mod.exports.__beta26.randomizerEncounterClassProtectionAudit =
          function()
          local report = { ok = true, checked = 0, failures = {} }

          local cases = {
              { node={ method="walk" }, path="encounters.ROUTE_1.grass.1",
                class="LAND", time="ANY" },
              { node={ method="walk", timeOfDay="MORN" },
                path="encounters.ROUTE_29.grass.morn.1",
                class="LAND", time="MORN" },
              { node={ method="surf" }, path="encounters.ROUTE_40.water.1",
                class="SURF", time="ANY" },
              { node={ method="old_rod" }, path="encounters.ROUTE_32.fishing.1",
                class="FISH", time="ANY" },
              { node={ method="headbutt" }, path="encounters.ILEX.tree.1",
                class="TREE", time="ANY" },
              { node={ method="bug_contest" }, path="encounters.PARK.contest.1",
                class="BUG_CONTEST", time="ANY" },
              { node={ method="roamer" }, path="encounters.ROAMER.1",
                class="ROAMER", time="ANY" },
          }
          for index, row in ipairs(cases) do
              local identity = encounterSourceIdentity(row.node, row.path)
              local class = encounterTableClass(row.node, identity)
              local time = encounterTimeBucket(row.node, identity)
              report.checked = report.checked + 1
              if class ~= row.class or time ~= row.time then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      "class_case_" .. tostring(index)
              end
          end

          local protected = {
              { static=true }, { fixed=true }, { story=true },
              { progression=true }, { quest=true }, { roamer=true },
              { kind="gift" }, { encounterType="STATIC" },
              { randomization="deny" },
          }
          for index, node in ipairs(protected) do
              local identity = encounterSourceIdentity(
                  node, "encounters.protected." .. tostring(index))
              report.checked = report.checked + 1
              if encounterLeafProtectionReason(node, identity) == nil then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      "protection_case_" .. tostring(index)
              end
          end

          local factors = { [0]=0.70, [1]=0.45, [2]=0.25 }
          report.checked = report.checked + 1
          if not (factors[0] > factors[1]
              and factors[1] > factors[2] and factors[2] > 0) then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "diversity_strength_order"
          end
          return report
      end

      function Randomizer.applyEncounters(game)
          if saveBlocked() then return false end
          game = game or getCurrentGame() or mod.game
          local delegated = externalRuleDelegation
              and externalRuleDelegation("random_encounter_tables", game)
          if delegated then
              -- Do not repaint a snapshot over an externally owned randomizer.
              -- If ownership later returns, snapshot the then-authoritative
              -- encounter registry before applying Nuzlocke's pass.
              Randomizer.encounterSnapshot = nil
              Randomizer.encounterRegistry = nil
              Randomizer.encounterApplied = nil
              setProjectionState("ENCOUNTERS", "delegated", nil)
              return true, "delegated"
          end
          local enabled = mod.save:get("random_encounter_tables", false) == true
          if not enabled then
              if Randomizer.encounterSnapshot ~= nil then
                  if liveEncounterRegistry(game) == nil then
                      return false, "restore_unavailable"
                  end
                  restoreEncounterRegistry(game)
                  Randomizer.encounterApplied = copy(liveEncounterRegistry(game))
              end
              setProjectionState("ENCOUNTERS", "disabled", nil)
              return true, "disabled"
          end
          if not snapshotEncounters(game) then
              return false, "registry_unavailable"
          end
          restoreEncounterRegistry(game)
          local pool = speciesPool(game)
          if #pool == 0 then return false end
          randomizeEncounterRegistry(game, liveEncounterRegistry(game),
              pool, game.data.pokemon or {})
          Randomizer.encounterApplied = copy(liveEncounterRegistry(game))
          setProjectionState("ENCOUNTERS", "applied", liveEncounterRegistry(game))
          if mod.exports.nuzlocke and mod.exports.nuzlocke.registry then
              mod.exports.nuzlocke.registry.changed("encounters", game, "random_encounters")
          end
          return true, "applied"
      end

      -- Learnset ownership is deliberately projected to the only three fields
      -- Nuzlocke mutates.  Comparing/capturing the full Pokémon registry lets
      -- unrelated provider changes (stats/types/metadata) masquerade as
      -- learnset drift and can poison the restoration baseline.
      local function projectLearnsets(pokemon)
          local projected = {}
          for species, def in pairs(type(pokemon) == "table" and pokemon or {}) do
              if type(def) == "table" then
                  projected[species] = {
                      level1Moves = copy(def.level1Moves or {}),
                      learnset = copy(def.learnset or {}),
                      levelMoves = copy(def.levelMoves or {}),
                  }
              end
          end
          return projected
      end

      local function restoreLearnsets(game)
          local pokemon = game and game.data and game.data.pokemon
          if not (Randomizer.learnsetSnapshot and Randomizer.learnsetRegistry
              and pokemon == Randomizer.learnsetRegistry) then return end
          local liveProjection = projectLearnsets(pokemon)
          if Randomizer.learnsetApplied
              and not sameValue(liveProjection, Randomizer.learnsetApplied) then
              Randomizer.learnsetSnapshot = liveProjection
              Randomizer.learnsetApplied = nil
              setProjectionState("LEARNSETS", "provider_adopted", pokemon)
              return
          end
          for species, original in pairs(Randomizer.learnsetSnapshot) do
              local def = pokemon[species]
              if type(def) == "table" then
                  def.level1Moves = copy(original.level1Moves)
                  def.learnset = copy(original.learnset)
                  def.levelMoves = copy(original.levelMoves)
              end
          end
          setProjectionState("LEARNSETS", "restored", pokemon)
      end

      local function snapshotLearnsets(game)
          local pokemon = game and game.data and game.data.pokemon
          if type(pokemon) ~= "table" then return false end
          if Randomizer.learnsetRegistry ~= pokemon then
              Randomizer.learnsetRegistry = pokemon
              Randomizer.learnsetSnapshot = projectLearnsets(pokemon)
              setProjectionState("LEARNSETS", "snapshotted", pokemon)
          end
          return true
      end

      function Randomizer.applyLearnsets(game)
          if saveBlocked() then return false end
          game = game or getCurrentGame() or mod.game
          local delegated = externalRuleDelegation
              and externalRuleDelegation("random_learnsets", game)
          if delegated then
              -- Provider ownership is provider-agnostic. Once another active
              -- randomizer owns learnsets, Nuzlocke must not restore a stale
              -- snapshot over that registry. Forget local ownership so a later
              -- hand-back snapshots whatever registry is authoritative then.
              Randomizer.learnsetSnapshot = nil
              Randomizer.learnsetRegistry = nil
              Randomizer.learnsetApplied = nil
              setProjectionState("LEARNSETS", "delegated", nil)
              return true, "delegated"
          end
          local enabled = mod.save:get("random_learnsets", false) == true
          if not enabled then
              if Randomizer.learnsetSnapshot ~= nil then
                  if not (game and game.data
                      and type(game.data.pokemon) == "table") then
                      return false, "restore_unavailable"
                  end
                  restoreLearnsets(game)
              end
              setProjectionState("LEARNSETS", "disabled", nil)
              return true, "disabled"
          end
          if not snapshotLearnsets(game) then
              return false, "registry_unavailable"
          end
          restoreLearnsets(game)
          local generation = effectiveRandomLearnsetGeneration()
          local pool = movePool(game, generation)
          -- GEN2 on an R/B/Y registry intentionally fails open: no fake moves.
          if #pool == 0 then return false end
          local moves = game.data.moves or {}
          local speciesIds = {}
          for species in pairs(game.data.pokemon or {}) do speciesIds[#speciesIds + 1] = species end
          table.sort(speciesIds, function(a, b) return tostring(a) < tostring(b) end)
          for _, species in ipairs(speciesIds) do
              local def = game.data.pokemon[species]
              local allowSpecies = type(def) == "table"
              if allowSpecies and mod.exports.nuzlocke and mod.exports.nuzlocke.content then
                  local ok, permitted = pcall(mod.exports.nuzlocke.content.shouldRandomizeLearnset,
                      species, def)
                  if ok and permitted == false then allowSpecies = false end
              end
              if allowSpecies then
                  for i in ipairs(def.level1Moves or {}) do
                      local slot = tostring(species) .. ".level1." .. tostring(i)
                      local choice = stableChoice(RANDOMIZER_SOURCE_MAPS.LEARNSETS.saveKey,
                          slot, pool,
                          function(id) return type(moves[id]) == "table" end,
                          RANDOMIZER_STREAMS.LEARNSETS, "g" .. tostring(generation))
                      if choice then def.level1Moves[i] = choice end
                  end
                  for i, entry in ipairs(def.learnset or {}) do
                      if type(entry) == "table" then
                          local slot = tostring(species) .. ".level." .. tostring(i)
                          local choice = stableChoice(RANDOMIZER_SOURCE_MAPS.LEARNSETS.saveKey,
                              slot, pool,
                              function(id) return type(moves[id]) == "table" end,
                              RANDOMIZER_STREAMS.LEARNSETS, "g" .. tostring(generation))
                          if choice then entry.move = choice end
                      end
                  end
                  -- Gold/Gen2 species use levelMoves rather than the Gen1
                  -- level1Moves/learnset pair. Preserve the level and row count
                  -- exactly; only replace the move id through the same seeded
                  -- LEARNSETS stream. If a provider exposes both shapes, both
                  -- remain deterministic and internally consistent.
                  for i, entry in ipairs(def.levelMoves or {}) do
                      if type(entry) == "table" then
                          local slot = tostring(species) .. ".levelMoves." .. tostring(i)
                          local choice = stableChoice(RANDOMIZER_SOURCE_MAPS.LEARNSETS.saveKey,
                              slot, pool,
                              function(id) return type(moves[id]) == "table" end,
                              RANDOMIZER_STREAMS.LEARNSETS, "g" .. tostring(generation))
                          if choice then entry.move = choice end
                      end
                  end
              end
          end
          Randomizer.learnsetApplied = projectLearnsets(game.data.pokemon or {})
          setProjectionState("LEARNSETS", "applied", game.data.pokemon)
          if mod.exports.nuzlocke and mod.exports.nuzlocke.registry then
              mod.exports.nuzlocke.registry.changed("learnsets", game, "random_learnsets")
          end
          return true, "applied"
      end

      -- 2.5.25 visible field/item-ball randomizer. This is intentionally
      -- acquisition-time rather than a registry rewrite: native object/event
      -- disappearance, bag-capacity handling, item text, and sounds remain
      -- engine-owned. Hidden items, gifts, shops, fruit/apricorn trees, and
      -- other scripted rewards do not pass through these seams.
      -- Phase D #3: classify field-item eligibility once. Progression/key
      -- protection is authoritative hard safety; later Phase D semantic pools
      -- may refine preferences but can never relax this classification.
      local function fieldItemClassification(itemId, def)
          local id = tostring(itemId or ""):upper()
          local result = {
              id = id,
              protected = false,
              category = "ORDINARY",
              reason = nil,
          }

          local function protect(category, reason)
              result.protected = true
              result.category = category
              result.reason = reason
              return result
          end

          if id == "" or id == "0" or id == "NONE" or id == "NO_ITEM" then
              return protect("INVALID", "reserved_or_empty")
          end
          if type(def) ~= "table" then
              return protect("INVALID", "missing_definition")
          end

          if def.keyItem == true or def.key_item == true
              or def.isKeyItem == true then
              return protect("KEY_ITEM", "explicit_key_item")
          end
          local pocket = tostring(def.pocket or def.bagPocket or ""):upper()
          if pocket == "KEY_ITEM" or pocket == "KEY ITEMS"
              or pocket == "KEYITEM" then
              return protect("KEY_ITEM", "key_item_pocket")
          end

          -- Providers can mark story/progression ownership directly. These
          -- fields are intentionally broad aliases because a false negative
          -- could remove a required world-progression object.
          if def.progression == true or def.progressionItem == true
              or def.progression_item == true or def.story == true
              or def.storyItem == true or def.story_item == true
              or def.quest == true or def.questItem == true
              or def.quest_item == true or def.required == true
              or def.requiredForProgression == true
              or def.required_for_progression == true then
              return protect("PROGRESSION", "progression_metadata")
          end
          if def.nuzlockeRandomizable == false
              or def.randomizable == false then
              return protect("PROTECTED", "record_opt_out")
          end
          local randomization = tostring(def.randomization
              or def.nuzlockeRandomization or ""):lower()
          if randomization == "deny" or randomization == "provider"
              or randomization == "preserve" or randomization == "story"
              or randomization == "external" or randomization == "owned" then
              return protect("PROTECTED", "protected_policy")
          end

          -- HMs are progression-critical even though Gold stores them in the
          -- shared TM/HM pocket.
          local machine = def.machine
          if type(machine) == "table" then
              local kind = tostring(machine.kind or machine.type or ""):upper()
              if kind == "HM" then
                  return protect("PROGRESSION", "hm_machine")
              end
          elseif tostring(machine or ""):upper() == "HM" then
              return protect("PROGRESSION", "hm_machine")
          end

          if id:match("^HM_") then
              return protect("PROGRESSION", "hm_identifier")
          end
          if id:find("BADGE", 1, true) then
              return protect("PROGRESSION", "badge_identifier")
          end
          if id:find("TERU_SAMA", 1, true)
              or id:find("UNUSED", 1, true)
              or id:find("DUMMY", 1, true) then
              return protect("INVALID", "placeholder_identifier")
          end

          local name = tostring(def.name or "")
          local upperName = name:upper()
          if name == "" or upperName == "?" or upperName == "NONE"
              or upperName:find("TERU%-SAMA") then
              return protect("INVALID", "placeholder_name")
          end
          return result
      end

      local function fieldItemProtected(itemId, def)
          return fieldItemClassification(itemId, def).protected == true
      end

      -- Phase D #10: the engine exposes one merged data.items registry, but
      -- R/B/Y and Gold/Silver encode item semantics differently. Keep one live
      -- registry while normalizing the edition-specific table model explicitly.
      local function fieldItemEditionProfile(game)
          game = game or getCurrentGame() or mod.game
          local gen2 = mod.exports.__beta26.runtimeIsGen2(game) == true
          local edition = tostring(getGameVersion() or ""):upper()
          if edition == "" then edition = gen2 and "GEN2" or "GEN1" end
          return {
              edition = edition,
              generation = gen2 and 2 or 1,
              registry = "data.items",
              tableModel = gen2 and "GEN2_POCKETS" or "GEN1_FLAT",
              visibleSource = gen2
                  and "HiddenItems.ballPickupScript"
                  or "OverworldController.talkTo",
              hiddenOwned = false,
          }
      end

      local function fieldItemEditionTableClassForGeneration(
          generation, itemId, def)
          def = type(def) == "table" and def or {}
          local id = tostring(itemId or ""):upper()
          local pocket = tostring(def.pocket or def.bagPocket or ""):upper()
          local machine = def.machine
          local machineKind = ""
          if type(machine) == "table" then
              machineKind = tostring(machine.kind or machine.type or ""):upper()
          else
              machineKind = tostring(machine or ""):upper()
          end

          if tonumber(generation) == 2 then
              if pocket == "KEY_ITEM" or pocket == "KEY ITEMS"
                  or pocket == "KEYITEM" then
                  return "GEN2_KEY_ITEM"
              elseif pocket == "BALL" then
                  return "GEN2_BALL"
              elseif pocket == "TM_HM" or pocket == "TM" then
                  if machineKind == "HM" or id:match("^HM_?%d+")
                      or id:match("^HM_") then
                      return "GEN2_HM"
                  end
                  return "GEN2_TM"
              end
              if machineKind == "HM" then return "GEN2_HM" end
              if machineKind == "TM" then return "GEN2_TM" end
              return "GEN2_ITEM"
          end

          -- R/B/Y uses a primarily flat Bag/item table. Preserve provider pocket
          -- metadata when present, but prefer record capabilities and canonical
          -- machine/ball identifiers over a Gen2-style pocket assumption.
          if def.keyItem == true or def.key_item == true
              or def.isKeyItem == true or pocket == "KEY_ITEM" then
              return "GEN1_KEY_ITEM"
          end
          if def.ball ~= nil and def.ball ~= false then return "GEN1_BALL" end
          if pocket == "BALL" or id:find("BALL", 1, true) then
              return "GEN1_BALL"
          end
          if machineKind == "HM" or id:match("^HM_?%d+")
              or id:match("^HM_") then
              return "GEN1_HM"
          end
          if machineKind == "TM" or id:match("^TM_?%d+")
              or id:match("^TM_") then
              return "GEN1_TM"
          end
          return "GEN1_ITEM"
      end

      local function fieldItemEditionTableClass(game, itemId, def)
          game = game or getCurrentGame() or mod.game
          local profile = fieldItemEditionProfile(game)
          return fieldItemEditionTableClassForGeneration(
              profile.generation, itemId, def)
      end

      mod.exports.__beta26.randomFieldItemEditionProfile =
          fieldItemEditionProfile
      mod.exports.__beta26.randomFieldItemEditionTableClass =
          fieldItemEditionTableClass

      local function fieldItemSemanticCategory(itemId, def, game)
          local id = tostring(itemId or ""):upper()
          def = type(def) == "table" and def or {}
          local tableClass = fieldItemEditionTableClass(game, itemId, def)
          if tableClass:find("_BALL", 1, true) then return "BALL" end
          if tableClass:find("_TM", 1, true) then return "MACHINE" end
          local pocket = tostring(def.pocket or def.bagPocket or ""):upper()
          local name = tostring(def.name or id):upper()
          local machine = def.machine
          if type(machine) == "table" then
              local kind = tostring(machine.kind or machine.type or ""):upper()
              if kind == "TM" then return "MACHINE" end
          elseif tostring(machine or ""):upper() == "TM" then
              return "MACHINE"
          end
          if id:match("^TM_") or pocket == "TM_HM" or pocket == "TM" then
              return "MACHINE"
          end
          if pocket == "BALL" or id:find("BALL",1,true) then return "BALL" end
          if id:find("REPEL",1,true) then return "REPEL" end
          if id == "ESCAPE_ROPE" or name:find("ESCAPE ROPE",1,true) then return "ESCAPE" end
          if id:find("STONE",1,true) or id:find("EVOLUTION",1,true) then return "EVOLUTION" end
          if id:find("X_",1,true) == 1 or id:find("DIRE_HIT",1,true)
              or id:find("GUARD_SPEC",1,true) then return "BATTLE" end
          if id:find("ANTIDOTE",1,true) or id:find("PARLYZ",1,true)
              or id:find("AWAKEN",1,true) or id:find("BURN_HEAL",1,true)
              or id:find("ICE_HEAL",1,true) or id:find("FULL_HEAL",1,true) then
              return "STATUS"
          end
          if id:find("POTION",1,true) or id:find("RESTORE",1,true)
              or id:find("REVIVE",1,true) or id:find("FRESH_WATER",1,true)
              or id:find("SODA_POP",1,true) or id:find("LEMONADE",1,true)
              or id:find("MOOMOO_MILK",1,true) then return "HEAL" end
          if id:find("ETHER",1,true) or id:find("ELIXIR",1,true)
              or id == "PP_UP" or id == "PP_MAX" then return "PP" end
          if id:find("RARE_CANDY",1,true) or id:find("HP_UP",1,true)
              or id:find("PROTEIN",1,true) or id:find("IRON",1,true)
              or id:find("CARBOS",1,true) or id:find("CALCIUM",1,true)
              or id:find("ZINC",1,true) then return "GROWTH" end
          return "GENERAL"
      end

      local function fieldItemUtilityTier(itemId, def, game)
          local category = fieldItemSemanticCategory(itemId, def, game)
          if category == "BALL" or category == "HEAL" or category == "STATUS"
              or category == "REPEL" or category == "ESCAPE" then return 1 end
          if category == "BATTLE" or category == "PP"
              or category == "GROWTH" or category == "EVOLUTION" then return 2 end
          if category == "MACHINE" then return 3 end
          return 0
      end

      local function fieldItemSourceAllows(category, context)
          context = type(context) == "table" and context or {}
          local allow = context.allowedCategories or context.fieldItemCategories
          if type(allow) == "table" and next(allow) ~= nil then
              local ok = false
              for k, v in pairs(allow) do
                  local value = type(k) == "number" and v or k
                  if tostring(value):upper() == category and v ~= false then
                      ok = true
                      break
                  end
              end
              if not ok then return false, "source_category_not_allowed" end
          end
          local deny = context.forbiddenCategories or context.fieldItemForbiddenCategories
          if type(deny) == "table" then
              for k, v in pairs(deny) do
                  local value = type(k) == "number" and v or k
                  if tostring(value):upper() == category and v ~= false then
                      return false, "source_category_forbidden"
                  end
              end
          end
          return true
      end

      mod.exports.__beta26.randomFieldItemSemanticCategory = fieldItemSemanticCategory

      -- Phase D #1/#4-6: shared hard-safety candidate engine with semantic
      -- category/tier soft preferences layered above authoritative protection.
      local function fieldItemPool(game, context)
          context = type(context) == "table" and context or {}
          local universe = {}
          local items = game and game.data and game.data.items
          if type(items) ~= "table" then return universe, nil end
          for id in pairs(items) do
              if type(id) == "string" then universe[#universe + 1] = id end
          end
          table.sort(universe)

          local original = tostring(context.originalItem or ""):upper()
          local originalDef = items[original]
          local originalCategory = fieldItemSemanticCategory(original, originalDef, game)
          local originalTier = fieldItemUtilityTier(original, originalDef, game)
          local balance = math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_field_item_balance", 0)) or 0)))

          local hard = {
              function(id)
                  local classification = fieldItemClassification(id, items[id])
                  if classification.protected then
                      return false, classification.reason
                  end
                  local allowed, reason = fieldItemSourceAllows(
                      fieldItemSemanticCategory(id, items[id], game), context)
                  if not allowed then return false, reason end
                  return true
              end,
          }
          local stages = {}
          if balance == 1 then
              stages = {
                  function(id)
                      return fieldItemSemanticCategory(id, items[id], game)
                          == originalCategory
                  end,
              }
          elseif balance == 2 then
              stages = {
                  function(id)
                      return fieldItemSemanticCategory(id, items[id], game)
                          == originalCategory
                          and fieldItemUtilityTier(id, items[id], game) == originalTier
                  end,
                  function(id)
                      return fieldItemSemanticCategory(id, items[id], game)
                          == originalCategory
                  end,
                  function(id)
                      return fieldItemUtilityTier(id, items[id], game) == originalTier
                  end,
              }
          end

          return mod.exports.__beta26.randomizerResolveCandidatePolicy({
              subsystem = "FIELD_ITEMS",
              source = tostring(context.source or "pool"),
              requested = ({[0]="CHAOS",[1]="CATEGORY",[2]="BALANCED"})[balance],
              reason = "field_item_balance",
              record = not (context.record == false),
          }, universe, hard, stages)
      end

      -- Phase D #2: permanent source identity is independent from the authored
      -- item currently occupying the source. The historical RNG semantic slot
      -- remains `<semanticSlot>:<originalItem>` so this migration does not
      -- intentionally reshuffle established Randomizer-v1 field-item results.
      local FIELD_ITEM_SOURCE_VERSION = 1
      local function fieldItemSourceIdentity(game, semanticSlot, context)
          context = type(context) == "table" and context or {}
          local edition = tostring(context.edition
              or getGameVersion() or ""):upper()
          if edition == "" then
              edition = mod.exports.__beta26.runtimeIsGen2(game)
                  and "GEN2" or "GEN1"
          end
          local source = tostring(context.sourceId
              or context.objectId or semanticSlot or "unknown")
          return {
              version = FIELD_ITEM_SOURCE_VERSION,
              edition = edition,
              semanticSlot = tostring(semanticSlot or "unknown"),
              sourceId = source,
              canonical = table.concat({
                  "FIELD_ITEM",
                  "v" .. tostring(FIELD_ITEM_SOURCE_VERSION),
                  edition,
                  tostring(semanticSlot or "unknown"),
              }, ":"),
          }
      end

      mod.exports.__beta26.randomFieldItemProtected = fieldItemProtected
      mod.exports.__beta26.randomFieldItemClassification =
          fieldItemClassification
      mod.exports.__beta26.randomFieldItemSourceIdentity =
          fieldItemSourceIdentity

      local function fieldItemOwnership(context)
          context = type(context) == "table" and context or {}
          local kind = tostring(context.sourceKind
              or context.kind or context.fieldItemKind or "VISIBLE"):upper()
          if kind == "VISIBLE" or kind == "ITEM_BALL"
              or kind == "ITEMBALL" or kind == "OVERWORLD_VISIBLE" then
              return { owned=true, kind="VISIBLE", reason=nil }
          end
          if kind == "HIDDEN" or kind == "BG_EVENT"
              or kind == "HIDDEN_ITEM" or kind == "BGEVENT" then
              return {
                  owned=false, kind="HIDDEN",
                  reason="hidden_item_not_owned",
              }
          end
          return {
              owned=false, kind=kind ~= "" and kind or "OTHER",
              reason="source_kind_not_owned",
          }
      end

      local function fieldItemSourceOrdinal(semanticSlot, context)
          context = type(context) == "table" and context or {}
          local direct = tonumber(context.sourceOrdinal
              or context.objectOrdinal or context.objectId
              or context.sourceId)
          if direct then
              return math.max(0, math.floor(direct)), true
          end
          local tail = tostring(semanticSlot or ""):match("(%d+)$")
          if tail then return math.max(0, tonumber(tail) or 0), true end

          -- Stable fallback for provider-defined nonnumeric source ids. This is
          -- deterministic but cannot make the same injective guarantee as a
          -- native numeric object/source ordinal, so UNIQUE reports degraded
          -- ownership in diagnostics rather than pretending otherwise.
          local text = tostring(context.sourceId or semanticSlot or "unknown")
          local hash = 0
          for i = 1, #text do
              hash = (hash * 131 + text:byte(i)) % 2147483647
          end
          return hash, false
      end

      local function fieldItemPoolSignature(pool)
          return table.concat(pool or {}, "\31")
      end

      local function fieldItemPlacementGroup(identity, context, pool, balance)
          context = type(context) == "table" and context or {}
          return table.concat({
              "FIELD_ITEM_GROUP",
              tostring(identity and identity.edition or ""),
              tostring(context.mapId or ""),
              tostring(fieldItemOwnership(context).kind or ""),
              "b" .. tostring(balance or 0),
              fieldItemPoolSignature(pool),
          }, "|")
      end

      local function fieldItemPlacementIndexForSeed(
          seed, identity, semanticSlot, context, pool, balance)
          if #pool == 0 then return nil, false end
          local ordinal, exactOrdinal =
              fieldItemSourceOrdinal(semanticSlot, context)
          local group = fieldItemPlacementGroup(
              identity, context, pool, balance)
          local offset = seededIndexFor(
              math.max(1, math.floor(tonumber(seed) or 1)),
              RANDOMIZER_STREAMS.FIELD_ITEMS,
              "PLACEMENT:" .. group, #pool) - 1
          return ((offset + ordinal) % #pool) + 1, exactOrdinal
      end

      local function fieldItemPlacementIndex(
          identity, semanticSlot, context, pool, balance)
          local seed = mod.exports.__beta26.randomizerSeed(nil, true)
          if seed <= 0 then seed = 1 end
          return fieldItemPlacementIndexForSeed(
              seed, identity, semanticSlot, context, pool, balance)
      end

      mod.exports.__beta26.randomFieldItemOwnership = fieldItemOwnership

      function Randomizer.fieldItem(game, originalItem, semanticSlot, context)
          if saveBlocked() then return originalItem end
          game = game or getCurrentGame() or mod.game
          if mod.save:get("random_field_items", false) ~= true then
              return originalItem
          end
          local ownership = fieldItemOwnership(context)
          if ownership.owned ~= true then return originalItem end
          local items = game and game.data and game.data.items
          local originalDef = type(items) == "table"
              and items[originalItem] or nil
          local originalClass =
              fieldItemClassification(originalItem, originalDef)
          -- Protected authored pickups stay exactly where their source/provider
          -- put them. Required key/HM/story/progression items are never moved.
          if originalClass.protected then
              return originalItem
          end

          local identity = fieldItemSourceIdentity(
              game, semanticSlot, context)
          local fieldContext = type(context) == "table" and context or {}
          fieldContext.source = identity.canonical
          fieldContext.originalItem = originalItem
          fieldContext.record = true
          local pool = fieldItemPool(game, fieldContext)
          if #pool == 0 then return originalItem end

          local repetition = math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_field_item_repetition", 0)) or 0)))
          if repetition == 0 and #pool > 1 then
              local withoutOriginal = {}
              for _, candidate in ipairs(pool) do
                  if candidate ~= originalItem then
                      withoutOriginal[#withoutOriginal + 1] = candidate
                  end
              end
              if #withoutOriginal > 0 then pool = withoutOriginal end
          end

          local historicalSlot = table.concat({
              tostring(semanticSlot or "unknown"),
              tostring(originalItem or "")
          }, ":")
          local map = persistedMap(
              RANDOMIZER_SOURCE_MAPS.FIELD_ITEMS.saveKey)
          local seed = mod.exports.__beta26.randomizerSeed(nil, true)

          local balance = math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_field_item_balance", 0)) or 0)))
          local canonicalIdentity = identity.canonical
          if balance > 0 then
              canonicalIdentity = canonicalIdentity
                  .. ":balance" .. tostring(balance)
          end
          if repetition > 0 then
              canonicalIdentity = canonicalIdentity
                  .. ":repeat" .. tostring(repetition)
          end
          local canonicalScoped = seed > 0 and table.concat({
              "v" .. tostring(Randomizer.algorithmVersion),
              "s" .. tostring(seed), canonicalIdentity,
          }, ":") or canonicalIdentity
          local historicalScoped = seed > 0 and table.concat({
              "v" .. tostring(Randomizer.algorithmVersion),
              "s" .. tostring(seed), historicalSlot,
          }, ":") or historicalSlot

          local function valid(id)
              id = tostring(id or ""):upper()
              if type(items[id]) ~= "table"
                  or fieldItemClassification(id, items[id]).protected then
                  return false
              end
              for _, candidate in ipairs(pool) do
                  if candidate == id then return true end
              end
              return false
          end

          local saved = tostring(map[canonicalScoped] or ""):upper()
          if saved ~= "" and valid(saved) then
              return saved
          end

          -- Adopt the exact pre-D permanent mapping when available.
          local legacy = tostring(map[historicalScoped] or ""):upper()
          if repetition == 0 and legacy ~= "" and valid(legacy) then
              map[canonicalScoped] = legacy
              mod.save:set(RANDOMIZER_SOURCE_MAPS.FIELD_ITEMS.saveKey, map)
              return legacy
          end

          -- Fresh ALLOW generation intentionally hashes the old semantic slot.
          -- DIVERSE/UNIQUE use only FIELD_ITEMS stream derivatives and never
          -- consume or perturb any other subsystem stream.
          local choice
          if repetition == 0 then
              choice = pool[seededIndex(
                  RANDOMIZER_STREAMS.FIELD_ITEMS,
                  historicalSlot, #pool)] or originalItem
          else
              local uniqueIndex, exactOrdinal =
                  fieldItemPlacementIndex(
                      identity, semanticSlot, context, pool, balance)
              if repetition == 2 then
                  choice = pool[uniqueIndex] or originalItem
                  if not exactOrdinal then
                      mod.exports.__beta26.randomizerConstraintDiagnostic({
                          subsystem="FIELD_ITEMS",
                          source=identity.canonical,
                          requested="UNIQUE",
                          result="DEGRADED_SOURCE_ORDINAL",
                          stage=0, input=#pool, safe=#pool,
                          candidates=#pool, relaxed=true, fallback=true,
                          reason="nonnumeric_source_ordinal",
                      })
                  end
              else
                  -- DIVERSE deterministically chooses the injective placement
                  -- lane on 3/4 of source/seed combinations, while one quarter
                  -- retains the independent historical lane. This reduces
                  -- repeats without making any hard-safe candidate unreachable.
                  local gate = seededIndex(
                      RANDOMIZER_STREAMS.FIELD_ITEMS,
                      "DIVERSE:" .. identity.canonical, 4)
                  if gate <= 3 then
                      choice = pool[uniqueIndex]
                  else
                      choice = pool[seededIndex(
                          RANDOMIZER_STREAMS.FIELD_ITEMS,
                          historicalSlot, #pool)]
                  end
              end
          end
          map[canonicalScoped] = choice
          mod.save:set(RANDOMIZER_SOURCE_MAPS.FIELD_ITEMS.saveKey, map)
          return choice
      end

      mod.exports.__beta26.randomizeFieldItem = function(
          game, originalItem, semanticSlot, context)
          return Randomizer.fieldItem(
              game, originalItem, semanticSlot, context)
      end

      -- Phase D #11: spoiler-aware, read-only Field Item diagnostics.
      -- This surface never calls Randomizer.fieldItem/stableChoice/applyAll and
      -- never requests a writable seed, so inspecting it consumes zero RNG and
      -- does not materialize or rewrite pickup mappings.
      mod.exports.__beta26.randomizerFieldItemInfo = function(game, reveal)
          game = game or getCurrentGame() or mod.game
          local items = game and game.data and game.data.items or {}
          local profile = fieldItemEditionProfile(game)
          local categories, tableClasses = {}, {}
          local totalItems, protectedItems, hardSafeItems = 0, 0, 0

          for id, def in pairs(type(items) == "table" and items or {}) do
              if type(id) == "string" then
                  totalItems = totalItems + 1
                  local classification = fieldItemClassification(id, def)
                  local tableClass = fieldItemEditionTableClass(game, id, def)
                  tableClasses[tableClass] =
                      (tonumber(tableClasses[tableClass]) or 0) + 1
                  if classification.protected then
                      protectedItems = protectedItems + 1
                  else
                      hardSafeItems = hardSafeItems + 1
                      local category =
                          fieldItemSemanticCategory(id, def, game)
                      categories[category] =
                          (tonumber(categories[category]) or 0) + 1
                  end
              end
          end

          local map = mod.save:get(
              RANDOMIZER_SOURCE_MAPS.FIELD_ITEMS.saveKey, {})
          local mappings, mappingCount, legacyMappingCount = {}, 0, 0
          if type(map) == "table" then
              local keys = {}
              for key, value in pairs(map) do
                  if type(key) == "string" and type(value) == "string" then
                      keys[#keys + 1] = key
                  end
              end
              table.sort(keys)
              for _, key in ipairs(keys) do
                  local value = tostring(map[key] or ""):upper()
                  local canonical = key:find("FIELD_ITEM:v"
                      .. tostring(FIELD_ITEM_SOURCE_VERSION) .. ":", 1, true)
                      ~= nil
                  if canonical then
                      mappingCount = mappingCount + 1
                      local row = {
                          sourceKey = key,
                          canonical = true,
                      }
                      if reveal == true then
                          row.item = value
                          local def = items[value]
                          local class = fieldItemClassification(value, def)
                          row.category =
                              fieldItemSemanticCategory(value, def, game)
                          row.tableClass =
                              fieldItemEditionTableClass(game, value, def)
                          row.protected = class.protected == true
                          row.protectionReason = class.reason
                      end
                      mappings[#mappings + 1] = row
                  else
                      legacyMappingCount = legacyMappingCount + 1
                  end
              end
          end

          local diagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics)
              == "function"
              and mod.exports.__beta26.randomizerConstraintDiagnostics() or {}
          local constraints = {}
          for _, row in ipairs(diagnostics) do
              if tostring(row.subsystem or ""):upper() == "FIELD_ITEMS" then
                  local copyRow = copy(row)
                  if reveal ~= true then
                      copyRow.item = nil
                      copyRow.choice = nil
                      copyRow.resultItem = nil
                  end
                  constraints[#constraints + 1] = copyRow
              end
          end

          return {
              algorithmVersion =
                  mod.exports.__beta26.randomizerAlgorithmVersion(),
              fieldItemSourceVersion = FIELD_ITEM_SOURCE_VERSION,
              seed = math.max(0, math.floor(tonumber(
                  mod.exports.__beta26.randomizerSeed(nil, false)) or 0)),
              enabled = mod.save:get("random_field_items", false) == true,
              balance = math.max(0, math.min(2, math.floor(tonumber(
                  mod.save:get("random_field_item_balance", 0)) or 0))),
              repetition = math.max(0, math.min(2, math.floor(tonumber(
                  mod.save:get("random_field_item_repetition", 0)) or 0))),
              editionProfile = profile,
              ownership = {
                  visible = fieldItemOwnership({sourceKind="VISIBLE"}),
                  hidden = fieldItemOwnership({sourceKind="HIDDEN"}),
              },
              totalItems = totalItems,
              hardSafeItems = hardSafeItems,
              protectedItems = protectedItems,
              categoryCounts = categories,
              tableClassCounts = tableClasses,
              persistedMappingCount = mappingCount,
              legacyMappingCount = legacyMappingCount,
              mappings = mappings,
              constraints = constraints,
              itemsRevealed = reveal == true,
          }
      end

      mod.exports.__beta26.randomizerFieldItemEditionAudit =
          function()
          local report = { ok=true, checked=0, failures={} }
          local cases = {
              {1, "POKE_BALL", {name="Poke Ball", ball=true}, "GEN1_BALL"},
              {1, "TM_24", {name="TM24", machine={kind="TM"}}, "GEN1_TM"},
              {1, "HM_03", {name="HM03", machine={kind="HM"}}, "GEN1_HM"},
              {1, "POTION", {name="Potion"}, "GEN1_ITEM"},
              {2, "POKE_BALL", {name="Poke Ball", pocket="BALL"}, "GEN2_BALL"},
              {2, "TM_24", {name="TM24", pocket="TM_HM",
                  machine={kind="TM"}}, "GEN2_TM"},
              {2, "HM_03", {name="HM03", pocket="TM_HM",
                  machine={kind="HM"}}, "GEN2_HM"},
              {2, "BICYCLE", {name="Bicycle", pocket="KEY_ITEM"},
                  "GEN2_KEY_ITEM"},
              {2, "POTION", {name="Potion", pocket="ITEM"}, "GEN2_ITEM"},
          }
          for index, row in ipairs(cases) do
              report.checked = report.checked + 1
              if fieldItemEditionTableClassForGeneration(
                  row[1], row[2], row[3]) ~= row[4] then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      "edition_case_" .. tostring(index)
              end
          end
          return report
      end

      mod.exports.__beta26.randomizerFieldItemInfoAudit = function(game)
          local report = { ok=true, checked=0, failures={} }
          game = game or getCurrentGame() or mod.game

          local beforeDiagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics)
              == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics()
              or 0
          local beforeMap = mod.save:get(
              RANDOMIZER_SOURCE_MAPS.FIELD_ITEMS.saveKey, {})
          local beforeCount = 0
          if type(beforeMap) == "table" then
              for _ in pairs(beforeMap) do beforeCount = beforeCount + 1 end
          end

          local okBlind, blind = pcall(
              mod.exports.__beta26.randomizerFieldItemInfo, game, false)
          local middleDiagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics)
              == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics()
              or 0
          local okOpen, open = pcall(
              mod.exports.__beta26.randomizerFieldItemInfo, game, true)
          local afterDiagnostics = type(
              mod.exports.__beta26.randomizerConstraintDiagnostics)
              == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics()
              or 0
          local afterMap = mod.save:get(
              RANDOMIZER_SOURCE_MAPS.FIELD_ITEMS.saveKey, {})
          local afterCount = 0
          if type(afterMap) == "table" then
              for _ in pairs(afterMap) do afterCount = afterCount + 1 end
          end

          report.checked = report.checked + 1
          if not (okBlind and okOpen
              and type(blind) == "table" and type(open) == "table"
              and blind.itemsRevealed == false
              and open.itemsRevealed == true) then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "open_blind_contract"
          end

          report.checked = report.checked + 1
          if beforeDiagnostics ~= middleDiagnostics
              or middleDiagnostics ~= afterDiagnostics then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "info_read_mutated_diagnostics"
          end

          report.checked = report.checked + 1
          if beforeCount ~= afterCount then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "info_read_mutated_mappings"
          end

          report.checked = report.checked + 1
          if type(blind) == "table"
              and type(blind.mappings) == "table" then
              for _, row in ipairs(blind.mappings) do
                  if row.item ~= nil or row.category ~= nil
                      or row.tableClass ~= nil then
                      report.ok = false
                      report.failures[#report.failures + 1] =
                          "blind_item_leak"
                      break
                  end
              end
          end

          report.checked = report.checked + 1
          local profile = fieldItemEditionProfile(game)
          if type(profile) ~= "table"
              or (profile.tableModel ~= "GEN1_FLAT"
                  and profile.tableModel ~= "GEN2_POCKETS")
              or profile.registry ~= "data.items" then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "edition_profile_contract"
          end

          return report
      end

      mod.exports.__beta26.randomizerFieldItemPlacementAudit =
          function(game)
          local report = { ok = true, checked = 0, failures = {} }
          game = game or getCurrentGame() or mod.game

          report.checked = report.checked + 1
          local visible = fieldItemOwnership({sourceKind="VISIBLE"})
          local hidden = fieldItemOwnership({sourceKind="HIDDEN"})
          if visible.owned ~= true or visible.kind ~= "VISIBLE"
              or hidden.owned ~= false or hidden.kind ~= "HIDDEN"
              or hidden.reason ~= "hidden_item_not_owned" then
              report.ok = false
              report.failures[#report.failures + 1] = "ownership_boundary"
          end

          report.checked = report.checked + 1
          local identity = fieldItemSourceIdentity(
              game, "rby:TEST:obj:1", {
                  sourceId="1", objectId="1", mapId="TEST",
                  sourceKind="VISIBLE",
              })
          local pool = {"A","B","C","D","E"}
          local seen = {}
          for ordinal = 0, 4 do
              local index, exact = fieldItemPlacementIndexForSeed(
                  12345678, identity, "rby:TEST:obj:" .. tostring(ordinal), {
                      objectId=ordinal, sourceId=ordinal,
                      mapId="TEST", sourceKind="VISIBLE",
                  }, pool, 0)
              if exact ~= true or seen[index] then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      "unique_source_permutation"
                  break
              end
              seen[index] = true
          end

          report.checked = report.checked + 1
          local first = fieldItemPlacementIndexForSeed(
              12345678, identity, "rby:TEST:obj:2", {
                  objectId=2, mapId="TEST", sourceKind="VISIBLE",
              }, pool, 0)
          local second = fieldItemPlacementIndexForSeed(
              12345678, identity, "rby:TEST:obj:2", {
                  objectId=2, mapId="TEST", sourceKind="VISIBLE",
              }, pool, 0)
          if first ~= second then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "placement_not_deterministic"
          end

          report.checked = report.checked + 1
          local _, exact = fieldItemSourceOrdinal(
              "provider:NONNUMERIC", {
                  sourceId="NONNUMERIC",
                  sourceKind="VISIBLE",
              })
          if exact ~= false then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "provider_ordinal_degradation"
          end

          report.checked = report.checked + 1
          local repetition = math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_field_item_repetition", 0)) or 0)))
          if repetition < 0 or repetition > 2 then
              report.ok = false
              report.failures[#report.failures + 1] = "repetition_range"
          end

          return report
      end

      mod.exports.__beta26.randomizerFieldItemSemanticAudit =
          function(game)
          local report = { ok = true, checked = 0, failures = {} }
          local cases = {
              { "POKE_BALL", {name="Poke Ball", pocket="BALL"}, "BALL", 1 },
              { "SUPER_POTION", {name="Super Potion", pocket="ITEM"}, "HEAL", 1 },
              { "ANTIDOTE", {name="Antidote", pocket="ITEM"}, "STATUS", 1 },
              { "MAX_REPEL", {name="Max Repel", pocket="ITEM"}, "REPEL", 1 },
              { "X_ATTACK", {name="X Attack", pocket="ITEM"}, "BATTLE", 2 },
              { "PP_UP", {name="PP Up", pocket="ITEM"}, "PP", 2 },
              { "FIRE_STONE", {name="Fire Stone", pocket="ITEM"}, "EVOLUTION", 2 },
              { "TM_THUNDER", {name="TM Thunder", pocket="TM_HM",
                  machine={kind="TM"}}, "MACHINE", 3 },
          }
          for index, row in ipairs(cases) do
              report.checked = report.checked + 1
              if fieldItemSemanticCategory(row[1], row[2]) ~= row[3]
                  or fieldItemUtilityTier(row[1], row[2]) ~= row[4] then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      "category_case_" .. tostring(index)
              end
          end

          report.checked = report.checked + 1
          local okAllowed = fieldItemSourceAllows("HEAL", {
              allowedCategories = {"HEAL", "STATUS"},
          })
          local noBall = fieldItemSourceAllows("BALL", {
              allowedCategories = {"HEAL", "STATUS"},
          })
          if okAllowed ~= true or noBall ~= false then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "source_allow_categories"
          end

          report.checked = report.checked + 1
          local allowedGeneral = fieldItemSourceAllows("GENERAL", {
              forbiddenCategories = {"MACHINE"},
          })
          local deniedMachine = fieldItemSourceAllows("MACHINE", {
              forbiddenCategories = {"MACHINE"},
          })
          if allowedGeneral ~= true or deniedMachine ~= false then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "source_forbidden_categories"
          end

          report.checked = report.checked + 1
          local balance = math.max(0, math.min(2, math.floor(tonumber(
              mod.save:get("random_field_item_balance", 0)) or 0)))
          if balance < 0 or balance > 2 then
              report.ok = false
              report.failures[#report.failures + 1] = "balance_range"
          end
          return report
      end

      mod.exports.__beta26.randomizerFieldItemFoundationAudit =
          function(game)
          local report = { ok = true, checked = 0, failures = {} }
          game = game or getCurrentGame() or mod.game

          report.checked = report.checked + 1
          local keyClass = fieldItemClassification("TEST_KEY", {
              name = "Test Key", keyItem = true,
          })
          if not keyClass.protected or keyClass.category ~= "KEY_ITEM" then
              report.ok = false
              report.failures[#report.failures + 1] = "key_item_classification"
          end

          report.checked = report.checked + 1
          local hmClass = fieldItemClassification("HM_SURF", {
              name = "Surf", machine = { kind = "HM" },
          })
          if not hmClass.protected
              or hmClass.category ~= "PROGRESSION" then
              report.ok = false
              report.failures[#report.failures + 1] = "hm_classification"
          end

          report.checked = report.checked + 1
          local storyClass = fieldItemClassification("STORY_TOKEN", {
              name = "Story Token", progression = true,
          })
          if not storyClass.protected
              or storyClass.reason ~= "progression_metadata" then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "progression_metadata_classification"
          end

          report.checked = report.checked + 1
          local ordinary = fieldItemClassification("POTION", {
              name = "Potion", pocket = "ITEM",
          })
          if ordinary.protected or ordinary.category ~= "ORDINARY" then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "ordinary_item_classification"
          end

          report.checked = report.checked + 1
          local a = fieldItemSourceIdentity(
              game, "rby:ROUTE_1:obj:7", { sourceId = "7" })
          local b = fieldItemSourceIdentity(
              game, "rby:ROUTE_1:obj:7", { sourceId = "7" })
          if a.canonical ~= b.canonical
              or a.canonical:find("POTION", 1, true) ~= nil then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "permanent_source_identity"
          end

          report.checked = report.checked + 1
          local pool = fieldItemPool(game, {
              source = "audit",
              record = false,
          })
          local items = game and game.data and game.data.items or {}
          for _, id in ipairs(pool) do
              if fieldItemClassification(id, items[id]).protected then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      "protected_candidate_in_pool"
                  break
              end
          end
          report.candidates = #pool

          report.checked = report.checked + 1
          if FIELD_ITEM_SOURCE_VERSION ~= 1 then
              report.ok = false
              report.failures[#report.failures + 1] =
                  "source_identity_version"
          end

          return report
      end

      function Randomizer.applyAll(game)
          local report = { ok = true, encounters = nil, learnsets = nil, failures = {} }
          if saveBlocked() then
              report.ok = false
              report.failures[#report.failures + 1] = "save_blocked"
              Randomizer.lastApplyReport = report
              return false, report
          end
          game = game or getCurrentGame() or mod.game
          local okEnc, encResult, encState =
              pcall(Randomizer.applyEncounters, game)
          report.encounters = okEnc and encResult == true
          report.encounter_state =
              okEnc and tostring(encState or "applied") or "error"
          if not okEnc or encResult ~= true then
              report.ok = false
              report.failures[#report.failures + 1] = okEnc
                  and ("encounters_" .. tostring(encState or "returned_false"))
                  or ("encounters_error:" .. tostring(encResult))
          end
          local okLearn, learnResult, learnState =
              pcall(Randomizer.applyLearnsets, game)
          report.learnsets = okLearn and learnResult == true
          report.learnset_state =
              okLearn and tostring(learnState or "applied") or "error"
          if not okLearn or learnResult ~= true then
              report.ok = false
              report.failures[#report.failures + 1] = okLearn
                  and ("learnsets_" .. tostring(learnState or "returned_false"))
                  or ("learnsets_error:" .. tostring(learnResult))
          end
          report.active = report.encounter_state ~= "disabled"
              or report.learnset_state ~= "disabled"
          Randomizer.lastApplyReport = report
          return report.ok, report
      end

      mod.exports.__beta26.Randomizer = Randomizer
      -- 2.2.10 optional modern Physical/Special Split.  The source table is
      -- intentionally keyed by move id so provider-owned records can keep their
      -- own names/categories unless they use one of the canonical Gen 1/2 ids.
      -- Every other damaging canonical move in 1-251 is physical under the
      -- modern split; status moves retain their engine category unchanged.
      mod.exports.__beta26.MODERN_SPECIAL_MOVES = {
          RAZOR_WIND=true, GUST=true, SONIC_BOOM=true, ACID=true,
          EMBER=true, FLAMETHROWER=true, WATER_GUN=true, HYDRO_PUMP=true,
          SURF=true, ICE_BEAM=true, BLIZZARD=true, PSYBEAM=true,
          BUBBLE_BEAM=true, AURORA_BEAM=true, HYPER_BEAM=true,
          ABSORB=true, MEGA_DRAIN=true, SOLAR_BEAM=true, PETAL_DANCE=true,
          DRAGON_RAGE=true, FIRE_SPIN=true, THUNDER_SHOCK=true,
          THUNDERBOLT=true, THUNDER=true, CONFUSION=true, PSYCHIC=true,
          NIGHT_SHADE=true, SMOG=true, SLUDGE=true, FIRE_BLAST=true,
          SWIFT=true, DREAM_EATER=true, BUBBLE=true, PSYWAVE=true,
          TRI_ATTACK=true, SNORE=true, AEROBLAST=true, POWDER_SNOW=true,
          SLUDGE_BOMB=true, MUD_SLAP=true, OCTAZOOKA=true, ZAP_CANNON=true,
          ICY_WIND=true, GIGA_DRAIN=true, DRAGON_BREATH=true,
          HIDDEN_POWER=true, TWISTER=true, ANCIENT_POWER=true,
          SHADOW_BALL=true, FUTURE_SIGHT=true, WHIRLPOOL=true,
          MIRROR_COAT=true,
      }

      mod.exports.__beta26.modernMoveCategory = function(move, moveId)
          if type(move) ~= "table" then return nil end
          local function normalizedCategory(value)
              local c = tostring(value or ""):lower():gsub("[%s%-]+", "_")
              if c == "physical" or c == "special" or c == "status" then return c end
          end
          -- 2.6.44: an explicit provider/live category contract outranks our
          -- Gen 1/2 fallback map. Plain `move.category` on canonical old moves
          -- may still be the native type-era category, so providers can mark it
          -- explicit or use one of the semantic category fields below.
          local explicit = normalizedCategory(move.nuzlockeMoveCategory
              or move.damageClass or move.damage_class or move.moveClass
              or move.move_class or move.physicalSpecialCategory
              or move.physical_special_category)
          if not explicit and move.nuzlockeCategoryExplicit == true then
              explicit = normalizedCategory(move.category)
          end
          if explicit then return explicit end
          if move.category == "status" then return "status" end
          -- Only recategorize actual damaging records.  Fixed-damage/special
          -- effect moves retain their engine handling rather than being forced
          -- through the ordinary Attack/Defense formula.
          if (tonumber(move.power) or 0) <= 0 then return move.category end
          local id = tostring(moveId or move.id or ""):upper()
          if id == "" then return move.category end
          if mod.exports.__beta26.MODERN_SPECIAL_MOVES[id] then return "special" end
          local index = tonumber(move.index or move.number or move.id)
          if index and index >= 1 and index <= 251 then return "physical" end
          -- Provider/future-generation moves keep an explicit per-move category
          -- when one exists.  This makes Hoenn/content providers additive.
          return move.category
      end

      mod.hooks:wrap("battle.damage", function(next, ctx)
          if mod.save:get("physical_special_split", false) ~= true
              or type(ctx) ~= "table" or type(ctx.move) ~= "table" then
              return next(ctx)
          end
          local category = mod.exports.__beta26.modernMoveCategory(
              ctx.move, ctx.moveId)
          if category ~= "physical" and category ~= "special" then
              return next(ctx)
          end

          if mod.exports.__beta26.runtimeIsGen2(getCurrentGame() or mod.game) then
              -- Gold's formula asks its type table for physical/special.  Give
              -- this one calculation a shallow type-record override; never
              -- mutate the shared registry or another mod's move record.
              local opts = ctx.opts
              local moveType = ctx.move.type
              if type(opts) == "table" and moveType ~= nil then
                  local scopedCtx = {}
                  for key, value in pairs(ctx) do scopedCtx[key] = value end
                  local scopedOpts = {}
                  for key, value in pairs(opts) do scopedOpts[key] = value end
                  local originalTypes = opts.types
                  local copiedTypes = {}
                  for key, value in pairs(originalTypes or {}) do
                      copiedTypes[key] = value
                  end
                  local typeRecord = {}
                  for key, value in pairs((originalTypes or {})[moveType] or {}) do
                      typeRecord[key] = value
                  end
                  typeRecord.category = category
                  copiedTypes[moveType] = typeRecord
                  scopedOpts.types = copiedTypes
                  -- hitOnce computed the native screen category before the
                  -- hook. Recompute it only on this copied calculation.
                  if ctx.battle and type(ctx.battle.screenActive) == "function" then
                      scopedOpts.screen = ctx.battle:screenActive(
                          ctx.target, category == "physical")
                  end
                  scopedCtx.opts = scopedOpts
                  return next(scopedCtx)
              end
              return next(ctx)
          end

          -- Gen 1 Damage.compute already gives move.category priority over the
          -- native type category.  Copy the move so the registry stays owned by
          -- the engine/provider and only this damage calculation is changed.
          local move = {}
          for key, value in pairs(ctx.move) do move[key] = value end
          move.category = category
          ctx.move = move
          return next(ctx)
      end)

      mod.exports.randomizer = {
          api = 1,
          build = mod.exports.__beta26.build,
          rngVersion = Randomizer.algorithmVersion,
          seed = function(create) return mod.exports.__beta26.randomizerSeed(nil, create == true) end,
          apply = Randomizer.applyAll,
          applyEncounters = Randomizer.applyEncounters,
          applyLearnsets = Randomizer.applyLearnsets,
      }

      -- Re-apply after provider registries have settled and when a save/game
      -- becomes authoritative. Idempotent snapshots prevent stacking rolls.
      local function applyForLifecycle(game)
          local ok, report = Randomizer.applyAll(game)
          if ok ~= true and type(mod.exports.__beta26.noteFeatureHealth) == "function" then
              mod.exports.__beta26.noteFeatureHealth("randomizer.apply", "FAIL",
                  type(report) == "table" and table.concat(report.failures or {}, ",")
                      or "apply_failed", "randomizer.apply")
          elseif ok == true and type(mod.exports.__beta26.noteFeatureHealth) == "function" then
              if type(report) == "table" and report.active == false then
                  mod.exports.__beta26.noteFeatureHealth("randomizer.apply", "N/A",
                      "encounter/learnset randomizers disabled", "randomizer.apply")
              else
                  mod.exports.__beta26.noteFeatureHealth("randomizer.apply", "ACTIVE", nil,
                      "randomizer.apply")
              end
          end
          return ok, report
      end
      mod.events:on("mods.loaded", function()
          applyForLifecycle(getCurrentGame() or mod.game)
      end)
      mod.events:on("game.ready", function(ev)
          local game = type(ev) == "table" and ev.game or ev
          applyForLifecycle(game or getCurrentGame() or mod.game)
      end)
      mod.events:on("save.loaded", function()
          applyForLifecycle(getCurrentGame() or mod.game)
      end)
  end

  ---------------------------------------------------------------------
  -- STARTER-ONLY RANDOMIZER
  -- One choice is persisted per new run so retries/reloads cannot reroll the
  -- starter. Story selection flags deliberately continue to describe the
  -- ball the player chose; this preserves every Rival and progression branch.
  ---------------------------------------------------------------------
  local starterLineageState = {
      registry = nil,
      lineage = nil,
  }
  local function starterCopy(value)
      if type(value) ~= "table" then return value end
      local out = {}
      for key, child in pairs(value) do out[key] = starterCopy(child) end
      return out
  end

  -- A starter candidate has to satisfy more than "there is a pokemon
  -- record".  Pokemon.new consumes growth/base-stat/learnset data, and the
  -- party SummaryMenu immediately dereferences the species types plus every
  -- move definition the new level-5 mon knows.  Compatibility providers may
  -- legitimately expose partial species metadata for BST/type legality; those
  -- records must never enter the concrete starter pool or Yellow can receive a
  -- mon that exists in the registry but crashes as soon as its status page is
  -- opened.
  mod.exports.__beta26.randomStarterRuntimeSafe = function(game, species, level)
      species = tostring(species or ""):upper()
      level = math.max(1, math.floor(tonumber(level) or 5))
      local data = game and game.data
      local pokemon = data and data.pokemon or {}
      local moves = data and data.moves or {}
      local def = pokemon[species]
      if type(def) ~= "table" or type(def.name) ~= "string"
          or def.name == "" or def.growthRate == nil
          or type(def.types) ~= "table" then
          return false
      end

      -- 2.5.70: Gen 2 is NOT constructed through src.pokemon.Pokemon.
      -- Gen1Recomp's src.battle.gen2.Mon consumes baseStats + levelMoves; the
      -- previous safety gate required Gen 1-only level1Moves + learnset fields
      -- and therefore rejected the entire legitimate Johto pool. That made the
      -- deterministic slate correctly but misleadingly fall back to the three
      -- vanilla Elm starters. Keep the current transaction/slate architecture,
      -- but validate each generation against its actual native constructor.
      if mod.exports.__beta26.runtimeIsGen2(game) then
          if tonumber(def.index) == nil or type(def.baseStats) ~= "table"
              or type(def.levelMoves) ~= "table" then
              return false
          end
          local stats = def.baseStats
          if tonumber(stats.hp) == nil or tonumber(stats.attack) == nil
              or tonumber(stats.defense) == nil or tonumber(stats.speed) == nil
              or tonumber(stats.specialAttack) == nil
              or tonumber(stats.specialDefense) == nil then
              return false
          end
          -- Mon.movesAtLevel reads only levelMoves at/below the grant level and
          -- tolerates display-name differences; validate the exact move records
          -- it will materialize without constructing throwaway mons or consuming
          -- the engine RNG while merely building the candidate pool.
          for _, entry in ipairs(def.levelMoves) do
              if type(entry) ~= "table" or tonumber(entry.level) == nil
                  or entry.move == nil then
                  return false
              end
              if tonumber(entry.level) <= level then
                  local moveDef = moves[entry.move]
                  if type(moveDef) ~= "table" or tonumber(moveDef.pp) == nil then
                      return false
                  end
              end
          end
          return true
      end

      if type(def.level1Moves) ~= "table"
          or type(def.learnset) ~= "table" then
          return false
      end

      -- Pokemon.movesAtLevel dedupes level-1 and learned moves. Validate the
      -- same source rows here because SummaryMenu page 2 expects every stored
      -- move to resolve to a real move definition with a printable name.
      local needed = {}
      for _, moveId in ipairs(def.level1Moves) do
          needed[moveId] = true
      end
      for _, entry in ipairs(def.learnset) do
          if type(entry) ~= "table" or tonumber(entry.level) == nil
              or entry.move == nil then
              return false
          end
          if tonumber(entry.level) <= level then needed[entry.move] = true end
      end
      for moveId in pairs(needed) do
          local moveDef = moves[moveId]
          if type(moveDef) ~= "table" or type(moveDef.name) ~= "string"
              or tonumber(moveDef.pp) == nil then
              return false
          end
      end

      -- Stats.calc is the Gen 1 concrete construction contract. Keep this
      -- guarded so a provider's partial base-stat record is skipped rather than
      -- turning a random-starter roll into a runtime crash.
      local okStats, Stats = pcall(require, "src.pokemon.Stats")
      if okStats and type(Stats) == "table" and type(Stats.calc) == "function" then
          local dvs = { hp = 7, attack = 7, defense = 7, speed = 7, special = 7 }
          local okCalc, calculated = pcall(Stats.calc, def, level, dvs, {
              hp = 0, attack = 0, defense = 0, speed = 0, special = 0,
          })
          if not okCalc or type(calculated) ~= "table"
              or tonumber(calculated.hp) == nil then
              return false
          end
      end
      return true
  end

  -- Phase B 4: capture one authoritative pre-randomization evolution
  -- lineage image from the merged species registry. Starter classification and
  -- rival-family synchronization consume this image rather than any later
  -- randomized/projected evolution data.
  local function starterOriginalLineage(game)
      local pokemon = game and game.data and game.data.pokemon
      if type(pokemon) ~= "table" then return nil end
      if starterLineageState.registry == pokemon
          and type(starterLineageState.lineage) == "table" then
          return starterLineageState.lineage
      end

      local nodes, incoming = {}, {}
      for id, def in pairs(pokemon) do
          local species = tostring(id or ""):upper()
          if species ~= "" and type(def) == "table" then
              local children = {}
              for _, evo in ipairs(def.evolutions or {}) do
                  local target = type(evo) == "table"
                      and tostring(evo.species or ""):upper() or ""
                  if target ~= "" and type(pokemon[target]) == "table"
                      and target ~= species then
                      children[#children + 1] = target
                      incoming[target] = (incoming[target] or 0) + 1
                  end
              end
              table.sort(children)
              nodes[species] = { children = children }
          end
      end

      local function depth(species, visiting)
          species = tostring(species or ""):upper()
          local node = nodes[species]
          if not node then return 0 end
          if (incoming[species] or 0) == 0 then return 0 end
          visiting = visiting or {}
          if visiting[species] then return 0 end
          visiting[species] = true
          local best
          for parent, pnode in pairs(nodes) do
              for _, child in ipairs(pnode.children or {}) do
                  if child == species then
                      local d = depth(parent, visiting) + 1
                      best = best and math.min(best, d) or d
                  end
              end
          end
          visiting[species] = nil
          return best or 0
      end

      local function root(species)
          species = tostring(species or ""):upper()
          local seen = {}
          local current = species
          while current ~= "" and not seen[current] do
              seen[current] = true
              local parents = {}
              for parent, pnode in pairs(nodes) do
                  for _, child in ipairs(pnode.children or {}) do
                      if child == current then parents[#parents + 1] = parent end
                  end
              end
              table.sort(parents)
              if #parents == 0 then return current end
              current = parents[1]
          end
          return species
      end

      local function descendantAtDepth(species, targetDepth)
          species = tostring(species or ""):upper()
          targetDepth = math.max(0, math.floor(tonumber(targetDepth) or 0))
          local current, currentDepth = species, 0
          local seen = {}
          while currentDepth < targetDepth and not seen[current] do
              seen[current] = true
              local node = nodes[current]
              if not node or #(node.children or {}) == 0 then break end
              -- Split lines are deterministic: canonical lexical child order.
              current = node.children[1]
              currentDepth = currentDepth + 1
          end
          return current
      end

      local lineage = {
          nodes = nodes,
          incoming = incoming,
          stage = function(species)
              species = tostring(species or ""):upper()
              local node = nodes[species]
              if not node then return "single" end
              local hasParent = (incoming[species] or 0) > 0
              local hasChild = #(node.children or {}) > 0
              if not hasParent and not hasChild then return "single" end
              if not hasParent then return "base" end
              if hasChild then return "middle" end
              return "final"
          end,
          threeStageBase = function(species)
              species = tostring(species or ""):upper()
              if (incoming[species] or 0) > 0 then return false end
              local node = nodes[species]
              if not node then return false end
              for _, child in ipairs(node.children or {}) do
                  local childNode = nodes[child]
                  if childNode and #(childNode.children or {}) > 0 then return true end
              end
              return false
          end,
          depth = depth,
          root = root,
          descendantAtDepth = descendantAtDepth,
      }
      starterLineageState.registry = pokemon
      starterLineageState.lineage = lineage
      return lineage
  end
  mod.exports.__beta26.randomizerStarterOriginalLineage = starterOriginalLineage
  mod.events:on("game.ready", function(ev)
      local game = type(ev) == "table" and ev.game or ev
      pcall(starterOriginalLineage, game or getCurrentGame() or mod.game)
  end)

  mod.exports.__beta26.randomStarterCandidates = function(game, original, options)
      local universe = {}
      local pokemon = game and game.data and game.data.pokemon or {}
      local gold = mod.exports.__beta26.runtimeIsGen2(game)
      original = tostring(original or ""):upper()
      for id in pairs(pokemon) do
          local species = tostring(id or ""):upper()
          if species ~= "" then universe[#universe + 1] = species end
      end
      table.sort(universe)

      -- Phase B 1: use the shared candidate engine for the hard-safety layer.
      -- Starter Style is deliberately supplied only as a soft preference stage,
      -- so preference fallback can never resurrect an unsafe candidate.
      local hardPredicates = {
          function(species)
              species = tostring(species or ""):upper()
              if species == original or species == "EGG" or species == "NONE" then
                  return false, "reserved_or_original"
              end
              local def = pokemon[species]
              if type(def) ~= "table" then return false, "missing_species" end
              local glitch = mod.exports.__beta26.getGlitchSpeciesInfo(game, species)
              if glitch.isGlitch then return false, "glitch_species" end
              if gold and tonumber(def.index) == nil then return false, "invalid_gen2_index" end
              if not mod.exports.__beta26.randomSpeciesPoolAllows(def, 0) then
                  return false, "species_pool"
              end
              if not mod.exports.__beta26.randomStarterRuntimeSafe(game, species, 5) then
                  return false, "runtime_unsafe"
              end
              if not mod.exports.__beta26.typeLockAllowsSpecies(game, species) then
                  return false, "type_lock"
              end
              if type(specialAcquisitionDenied) == "function"
                  and specialAcquisitionDenied(game, species, nil, "starter") ~= nil then
                  return false, "acquisition_denied"
              end
              return true
          end,
      }

      local style = math.max(0, math.min(3, math.floor(tonumber(
          mod.save:get("random_starter_style", 0)) or 0)))
      local requested, preference = "ANY", nil

      if style > 0 then
          local lineage = starterOriginalLineage(game)
          local stage = lineage and lineage.stage or function() return "single" end
          local threeStageBase = lineage and lineage.threeStageBase or function() return false end

          if style == 1 then
              requested = "3_STAGE"
              preference = function(species) return threeStageBase(species) end
          elseif style == 2 then
              requested = "BASE"
              preference = function(species)
                  local shape = stage(species)
                  return shape == "base" or shape == "single"
              end
          else
              requested = "SIM_BST"
              local originalBst = mod.exports.__beta26.getSpeciesBST(game, original)
              local tolerance = originalBst
                  and math.max(25, math.floor(originalBst * 0.15 + 0.5)) or nil
              preference = function(species)
                  if not tolerance then return false end
                  local bst = mod.exports.__beta26.getSpeciesBST(game, species)
                  return bst ~= nil and math.abs(bst - originalBst) <= tolerance
              end
          end
      end

      local stages = preference and { preference } or {}
      local resolved = mod.exports.__beta26.randomizerResolveCandidatePolicy({
          subsystem = "STARTER",
          source = original,
          requested = requested,
          reason = "starter_style",
          record = not (type(options) == "table" and options.record == false),
      }, universe, hardPredicates, stages)
      return resolved
  end

  local function randomStarterChoiceValid(game, species)
      species = tostring(species or ""):upper()
      if species == "" then return false end
      local pokemon = game and game.data and game.data.pokemon or {}
      local def = pokemon[species]
      return type(def) == "table"
          and (not mod.exports.__beta26.runtimeIsGen2(game)
              or tonumber(def.index) ~= nil)
          and mod.exports.__beta26.randomSpeciesPoolAllows(def,
              0)
          and mod.exports.__beta26.randomStarterRuntimeSafe(game, species, 5)
          and mod.exports.__beta26.typeLockAllowsSpecies(game, species)
          and (type(specialAcquisitionDenied) ~= "function"
              or specialAcquisitionDenied(game, species, nil, "starter") == nil)
  end

  local function randomStarterMap()
      local raw = mod.save:get(RANDOMIZER_SOURCE_MAPS.STARTER.saveKey, {})
      local out = {}
      if type(raw) == "table" then
          for original, choice in pairs(raw) do
              local key = tostring(original or "")
              choice = tostring(choice or ""):upper()

              -- 2.5.35: species-id keys are case-insensitive, but scoped cache
              -- keys are opaque semantic identities and must retain their
              -- authored casing. 2.5.32-2.5.34 uppercased the entire key on
              -- read, which made GOLD_STARTER_SLATE:v1:s...:style... miss its
              -- own cache. Canonicalize only that known legacy uppercase form
              -- so existing saves heal themselves without inventing a new
              -- cache namespace.
              local seed, style, species = key:match(
                  "^GOLD_STARTER_SLATE:V1:S(%d+):STYLE(%d+):(.+)$")
              if seed then
                  key = "GOLD_STARTER_SLATE:v1:s" .. seed
                      .. ":style" .. style .. ":" .. tostring(species):upper()
              elseif not key:find(":", 1, true) then
                  key = key:upper()
              end

              if key ~= "" and choice ~= "" then out[key] = choice end
          end
      end
      return out
  end

  -- NEW GAME changes mod.save backing when the fresh save is adopted. Gold's
  -- starter transaction can occur while the immutable Setup snapshot is still
  -- the authoritative rule source, so Random Starter must resolve through the
  -- same staged-or-durable policy as the rest of NEW GAME instead of trusting
  -- only the currently attached mod.save bucket. External provider ownership
  -- still wins absolutely.
  local function randomStarterRuleEnabled(game)
      local runtimeGame = game or getCurrentGame() or mod.game
      if externalRuleDelegation
          and externalRuleDelegation("random_starter", runtimeGame) then
          return false
      end
      local profile = getNewGameRulesSnapshot() or getPendingNewGameRules()
      if type(profile) == "table" and profile.random_starter_reroll_index ~= nil
          and math.max(0, math.floor(tonumber(
              mod.save:get("__nuzlocke_random_starter_reroll_index", 0)) or 0)) == 0 then
          mod.save:set("__nuzlocke_random_starter_reroll_index", math.max(0,
              math.floor(tonumber(profile.random_starter_reroll_index) or 0)))
      end
      if mod.save:get("random_starter", false) == true then return true end
      if type(profile) ~= "table" or profile.random_starter ~= true then
          return false
      end

      -- Gold NEW GAME adopts a fresh mod.save bucket after Setup staged its
      -- immutable profile. If the normal snapshot commit has not run yet, move
      -- the Random Starter inputs plus staged reroll index across now so the first Elm
      -- POKEPIC/GIVEPOKE uses the exact toggle/style/balance/typing/reroll/seed state. The normal
      -- full-profile commit remains authoritative and will verify the same
      -- values later.
      mod.save:set("random_starter", true)
      if profile.random_starter_style ~= nil then
          mod.save:set("random_starter_style", math.max(0, math.min(3,
              math.floor(tonumber(profile.random_starter_style) or 0))))
      end
      if profile.random_starter_balance ~= nil then
          mod.save:set("random_starter_balance", math.max(0, math.min(1,
              math.floor(tonumber(profile.random_starter_balance) or 0))))
      end
      if profile.random_starter_trio_typing ~= nil then
          mod.save:set("random_starter_trio_typing", math.max(0, math.min(1,
              math.floor(tonumber(profile.random_starter_trio_typing) or 0))))
      end
      if profile.random_starter_rerolls ~= nil then
          mod.save:set("random_starter_rerolls",
              profile.random_starter_rerolls == true)
      end
      if profile.random_starter_reroll_index ~= nil then
          mod.save:set("__nuzlocke_random_starter_reroll_index", math.max(0,
              math.floor(tonumber(profile.random_starter_reroll_index) or 0)))
      end
      if profile.randomizer_seed ~= nil then
          mod.save:set("randomizer_seed", math.max(0, math.min(99999999,
              math.floor(tonumber(profile.randomizer_seed) or 0))))
      end
      return true
  end
  mod.exports.__beta26.randomStarterRuleEnabled = randomStarterRuleEnabled

  -- Phase B 2-3: starter choices are generated as one atomic, persisted
  -- slate for the edition's native starter transaction. R/B and Gold/Silver
  -- have three physical choices. Yellow persists its Pikachu player position
  -- and Eevee rival position together; rival synchronization consumes that same
  -- positional slate.
  local STARTER_SLATE_VERSION = 3
  local STARTER_POSITION_KEY = "__nuzlocke_random_starter_positions"
  local STARTER_REROLL_INDEX_KEY = "__nuzlocke_random_starter_reroll_index"
  local STARTER_REROLL_LOCK_KEY = "__nuzlocke_random_starter_reroll_locked"

  local function starterSlateOrder(game, original)
      original = tostring(original or ""):upper()
      if mod.exports.__beta26.runtimeIsGen2(game) then
          if original == "CHIKORITA" or original == "CYNDAQUIL"
              or original == "TOTODILE" then
              return { "CHIKORITA", "CYNDAQUIL", "TOTODILE" }, "GEN2"
          end
      elseif original == "BULBASAUR" or original == "CHARMANDER"
          or original == "SQUIRTLE" then
          return { "BULBASAUR", "CHARMANDER", "SQUIRTLE" }, "RBY"
      elseif original == "PIKACHU" or original == "EEVEE" then
          return { "PIKACHU", "EEVEE" }, "YELLOW"
      end
      return { original }, "SINGLE"
  end

  local function starterPositionState()
      local raw = mod.save:get(STARTER_POSITION_KEY, {})
      return type(raw) == "table" and starterCopy(raw) or {}
  end

  local function persistStarterPositions(editionTag, seed, style, balance, trioTyping, rerollIndex, scopeVersion, order, slate)
      local state = {
          schema = 1,
          slateVersion = math.max(1, math.floor(tonumber(scopeVersion) or STARTER_SLATE_VERSION)),
          edition = tostring(editionTag or "UNKNOWN"),
          seed = math.max(0, math.floor(tonumber(seed) or 0)),
          style = math.max(0, math.floor(tonumber(style) or 0)),
          balance = math.max(0, math.min(1, math.floor(tonumber(balance) or 0))),
          trioTyping = math.max(0, math.min(1, math.floor(tonumber(trioTyping) or 0))),
          rerollIndex = math.max(0, math.floor(tonumber(rerollIndex) or 0)),
          order = {},
          slots = {},
      }
      for index, original in ipairs(order or {}) do
          original = tostring(original or ""):upper()
          state.order[index] = original
          state.slots[original] = tostring(slate and slate[original] or ""):upper()
      end
      mod.save:set(STARTER_POSITION_KEY, state)
      return starterCopy(state)
  end

  mod.exports.__beta26.randomStarterPositionKey = STARTER_POSITION_KEY
  mod.exports.__beta26.randomStarterPositions = starterPositionState

  -- 2.6.80 Phase B #7: score current strength plus a partial share of
  -- evolutionary ceiling. This is deliberately simple and deterministic rather
  -- than a competitive-power model.
  local function starterEvolutionCeilingBst(game, lineage, species, visiting)
      species = tostring(species or ""):upper()
      local current = tonumber(mod.exports.__beta26.getSpeciesBST(game, species)) or 0
      local best = current
      if not lineage or type(lineage.nodes) ~= "table" then return best end
      visiting = visiting or {}
      if visiting[species] then return best end
      visiting[species] = true
      local node = lineage.nodes[species]
      for _, child in ipairs(type(node) == "table" and node.children or {}) do
          local childBest = starterEvolutionCeilingBst(game, lineage, child, visiting)
          if childBest > best then best = childBest end
      end
      visiting[species] = nil
      return best
  end

  local function starterStrengthScore(game, lineage, species)
      local current = tonumber(mod.exports.__beta26.getSpeciesBST(game, species))
      if not current then return nil end
      local ceiling = starterEvolutionCeilingBst(game, lineage, species, {})
      return current + math.max(0, ceiling - current) * 0.35
  end
  mod.exports.__beta26.randomizerStarterStrengthScore = function(game, species)
      game = game or getCurrentGame() or mod.game
      return starterStrengthScore(game, starterOriginalLineage(game), species)
  end

  -- 2.6.80 Phase B #8: standard Gen 1/2 offensive super-effectiveness
  -- relationships. AUTO uses full dual typing. Unknown/provider types do not
  -- fabricate relationships; they simply make the type preference relax.
  local TYPE_SUPER = {
      NORMAL={},
      FIRE={GRASS=true,ICE=true,BUG=true,STEEL=true},
      WATER={FIRE=true,GROUND=true,ROCK=true},
      ELECTRIC={WATER=true,FLYING=true},
      GRASS={WATER=true,GROUND=true,ROCK=true},
      ICE={GRASS=true,GROUND=true,FLYING=true,DRAGON=true},
      FIGHTING={NORMAL=true,ICE=true,ROCK=true,DARK=true,STEEL=true},
      POISON={GRASS=true},
      GROUND={FIRE=true,ELECTRIC=true,POISON=true,ROCK=true,STEEL=true},
      FLYING={GRASS=true,FIGHTING=true,BUG=true},
      PSYCHIC={FIGHTING=true,POISON=true},
      BUG={GRASS=true,PSYCHIC=true,DARK=true},
      ROCK={FIRE=true,ICE=true,FLYING=true,BUG=true},
      GHOST={PSYCHIC=true,GHOST=true},
      DRAGON={DRAGON=true},
      DARK={PSYCHIC=true,GHOST=true},
      STEEL={ICE=true,ROCK=true},
  }
  local TYPE_RESIST = {
      NORMAL={ROCK=true,STEEL=true,GHOST="immune"},
      FIRE={FIRE=true,WATER=true,ROCK=true,DRAGON=true},
      WATER={WATER=true,GRASS=true,DRAGON=true},
      ELECTRIC={ELECTRIC=true,GRASS=true,DRAGON=true,GROUND="immune"},
      GRASS={FIRE=true,GRASS=true,POISON=true,FLYING=true,BUG=true,DRAGON=true,STEEL=true},
      ICE={WATER=true,ICE=true,STEEL=true},
      FIGHTING={POISON=true,FLYING=true,PSYCHIC=true,BUG=true,GHOST="immune"},
      POISON={POISON=true,GROUND=true,ROCK=true,GHOST=true,STEEL="immune"},
      GROUND={GRASS=true,BUG=true,FLYING="immune"},
      FLYING={ELECTRIC=true,ROCK=true,STEEL=true},
      PSYCHIC={PSYCHIC=true,STEEL=true,DARK="immune"},
      BUG={FIRE=true,FIGHTING=true,POISON=true,FLYING=true,GHOST=true,STEEL=true},
      ROCK={FIGHTING=true,GROUND=true,STEEL=true},
      GHOST={DARK=true,NORMAL="immune"},
      DRAGON={STEEL=true},
      DARK={FIGHTING=true,DARK=true,STEEL=true},
      STEEL={FIRE=true,WATER=true,ELECTRIC=true,STEEL=true},
  }

  local function normalizedSpeciesTypes(game, species)
      local def = game and game.data and game.data.pokemon
          and game.data.pokemon[tostring(species or ""):upper()]
      local out, seen = {}, {}
      if type(def) == "table" and type(def.types) == "table" then
          for _, value in pairs(def.types) do
              local t = tostring(value or ""):upper():gsub("[%s%-]+", "_")
              if t ~= "" and not seen[t] then
                  seen[t] = true
                  out[#out + 1] = t
              end
          end
      end
      return out
  end

  local function typeMultiplier(game, attackType, defenseTypes)
      attackType = tostring(attackType or ""):upper()
      local mult = 1
      for _, defenseType in ipairs(defenseTypes or {}) do
          defenseType = tostring(defenseType or ""):upper()
          local resist = TYPE_RESIST[attackType] and TYPE_RESIST[attackType][defenseType]
          local super = TYPE_SUPER[attackType] and TYPE_SUPER[attackType][defenseType]
          if not mod.exports.__beta26.runtimeIsGen2(game) then
              if attackType == "BUG" and defenseType == "POISON" then
                  super, resist = true, nil
              elseif attackType == "POISON" and defenseType == "BUG" then
                  super, resist = true, nil
              elseif attackType == "GHOST" and defenseType == "PSYCHIC" then
                  super, resist = nil, "immune"
              elseif attackType == "ICE" and defenseType == "FIRE" then
                  super, resist = nil, nil
              end
          end
          if resist == "immune" then return 0 end
          if super then mult = mult * 2 end
          if resist == true then mult = mult * 0.5 end
      end
      return mult
  end

  local function speciesHasAdvantage(game, attacker, defender)
      local attackTypes = normalizedSpeciesTypes(game, attacker)
      local defenseTypes = normalizedSpeciesTypes(game, defender)
      if #attackTypes == 0 or #defenseTypes == 0 then return false end
      for _, attackType in ipairs(attackTypes) do
          if typeMultiplier(game, attackType, defenseTypes) > 1 then return true end
      end
      return false
  end

  local function starterSlateTypeCycle(game, order, slate)
      if type(order) ~= "table" or #order ~= 3 then return false end
      local a = slate and slate[order[1]]
      local b = slate and slate[order[2]]
      local c = slate and slate[order[3]]
      if not a or not b or not c then return false end
      return (speciesHasAdvantage(game, a, b)
              and speciesHasAdvantage(game, b, c)
              and speciesHasAdvantage(game, c, a))
          or (speciesHasAdvantage(game, b, a)
              and speciesHasAdvantage(game, c, b)
              and speciesHasAdvantage(game, a, c))
  end
  mod.exports.__beta26.randomizerStarterTypeCycle = starterSlateTypeCycle

  local function atomicStarterSlate(game, seed, style, requestedOriginal)
      local order, editionTag = starterSlateOrder(game, requestedOriginal)
      local choices = randomStarterMap()
      local balance = math.max(0, math.min(1, math.floor(tonumber(
          mod.save:get("random_starter_balance", 0)) or 0)))
      local trioTyping = math.max(0, math.min(1, math.floor(tonumber(
          mod.save:get("random_starter_trio_typing", 0)) or 0)))
      local balanceActive = balance == 1 and #order == 3
      local trioActive = trioTyping == 1 and #order == 3
      local rerollIndex = math.max(0, math.floor(tonumber(
          mod.save:get(STARTER_REROLL_INDEX_KEY, 0)) or 0))
      local previousPosition = starterPositionState()

      -- Defaults stay on the exact 2.6.79 v2 namespace so INDEPENDENT/OFF
      -- reproduces existing starter slates. Only an active new preference moves
      -- the starter transaction to the v3 namespace.
      local scopeVersion = (balanceActive or trioActive or rerollIndex > 0)
          and STARTER_SLATE_VERSION or 2
      local scopeParts = {
          "STARTER_SLATE",
          "v" .. tostring(scopeVersion),
          editionTag,
          "s" .. tostring(seed),
          "style" .. tostring(style),
      }
      if scopeVersion >= 3 then
          scopeParts[#scopeParts + 1] = "balance" .. tostring(balance)
          scopeParts[#scopeParts + 1] = "trio" .. tostring(trioTyping)
          if rerollIndex > 0 then
              scopeParts[#scopeParts + 1] = "reroll" .. tostring(rerollIndex)
          end
      end
      local scope = table.concat(scopeParts, ":")

      local cached, seen, cacheHealthy = {}, {}, true
      local cachedRelaxed = choices[scope .. ":__UNIQUENESS_RELAXED"] == "YES"
      for _, original in ipairs(order) do
          local key = scope .. ":" .. original
          local choice = tostring(choices[key] or ""):upper()
          if not randomStarterChoiceValid(game, choice)
              or (seen[choice] and not cachedRelaxed) then
              cacheHealthy = false
              break
          end
          cached[original] = choice
          seen[choice] = true
      end
      if cacheHealthy then
          persistStarterPositions(editionTag, seed, style, balance, trioTyping, rerollIndex, scopeVersion, order, cached)
          return cached
      end

      local slate, used = {}, {}
      local uniquenessRelaxed = false

      -- Adopt only prior choices from the SAME seed/style namespace. Bare
      -- mirrors are intentionally not enough: they can belong to another
      -- Starter Style, and adopting them would make a style change ineffective.
      local oldAlgorithm = mod.exports.__beta26.randomizerAlgorithmVersion()
      if scopeVersion == 2 then
          for _, original in ipairs(order) do
              local legacyKey
              if editionTag == "GEN2" then
                  legacyKey = table.concat({
                      "GOLD_STARTER_SLATE", "v1",
                      "s" .. tostring(seed), "style" .. tostring(style), original,
                  }, ":")
              else
                  legacyKey = table.concat({
                      "v" .. tostring(oldAlgorithm), "s" .. tostring(seed),
                      "style" .. tostring(style), "g0", original,
                  }, ":")
              end
              local saved = tostring(choices[legacyKey] or ""):upper()
              if randomStarterChoiceValid(game, saved) and not used[saved] then
                  slate[original] = saved
                  used[saved] = true
              end
          end
      end

      local missing, candidatePools = {}, {}
      for _, original in ipairs(order) do
          if slate[original] == nil then
              missing[#missing + 1] = original
              candidatePools[original] =
                  mod.exports.__beta26.randomStarterCandidates(game, original)
          end
      end

      local function deterministicCandidateOrder(original, candidates)
          local out = {}
          for _, choice in ipairs(candidates or {}) do out[#out + 1] = choice end
          if seed > 0 then
              table.sort(out, function(a, b)
                  local aRank = mod.exports.__beta26.randomizerSeededIndexFor(
                      seed, RANDOMIZER_STREAMS.STARTER_SLATE,
                      scope .. ":" .. original .. ":candidate:" .. tostring(a),
                      1000003)
                  local bRank = mod.exports.__beta26.randomizerSeededIndexFor(
                      seed, RANDOMIZER_STREAMS.STARTER_SLATE,
                      scope .. ":" .. original .. ":candidate:" .. tostring(b),
                      1000003)
                  if aRank ~= bRank then return aRank < bRank end
                  return tostring(a) < tostring(b)
              end)
          end
          return out
      end

      -- Phase B 7-8: preference search is bounded and deterministic so it
      -- cannot turn an optional balance/type request into startup work that
      -- scales cubically across an arbitrarily large provider registry. Hard
      -- legality and the later complete distinct matcher remain unbounded.
      local lineage = starterOriginalLineage(game)
      local preferredPoolCache = {}
      local function preferredOrderedPool(original)
          if preferredPoolCache[original] then return preferredPoolCache[original] end
          local ordered = deterministicCandidateOrder(
              original, candidatePools[original] or {})
          local out = {}
          local limit = math.min(#ordered, 80)
          for index = 1, limit do out[index] = ordered[index] end
          preferredPoolCache[original] = out
          return out
      end

      local function preferredSearch(maxSpread, requireCycle)
          local preferredSlate, preferredUsed = {}, {}
          for key in pairs(used) do preferredUsed[key] = true end
          for key, value in pairs(slate) do preferredSlate[key] = value end
          local scoreMin, scoreMax

          local function rec(index, currentMin, currentMax)
              if index > #missing then
                  if requireCycle and not starterSlateTypeCycle(
                      game, order, preferredSlate) then return false end
                  if rerollIndex > 0 and type(previousPosition.slots) == "table" then
                      local same = true
                      for _, original in ipairs(order) do
                          if tostring(preferredSlate[original] or ""):upper()
                              ~= tostring(previousPosition.slots[original] or ""):upper() then
                              same = false
                              break
                          end
                      end
                      if same then return false end
                  end
                  return true
              end
              local original = missing[index]
              for _, pick in ipairs(preferredOrderedPool(original)) do
                  local key = tostring(pick or ""):upper()
                  if not preferredUsed[key] then
                      local nextMin, nextMax = currentMin, currentMax
                      local withinPreference = true
                      if maxSpread ~= nil then
                          local score = starterStrengthScore(game, lineage, pick)
                          if score ~= nil then
                              nextMin = nextMin and math.min(nextMin, score) or score
                              nextMax = nextMax and math.max(nextMax, score) or score
                              withinPreference = (nextMax - nextMin) <= maxSpread
                          end
                      end
                      if withinPreference then
                          preferredSlate[original] = pick
                          preferredUsed[key] = true
                          if rec(index + 1, nextMin, nextMax) then return true end
                          preferredUsed[key] = nil
                          preferredSlate[original] = nil
                      end
                  end
              end
              return false
          end

          if rec(1, scoreMin, scoreMax) then
              for key in pairs(slate) do slate[key] = nil end
              for key in pairs(used) do used[key] = nil end
              for key, value in pairs(preferredSlate) do
                  slate[key] = value
                  used[tostring(value):upper()] = true
              end
              return true
          end
          return false
      end

      local preferredComplete = false
      local preferenceStage = 0
      if balanceActive or trioActive then
          local tolerances = balanceActive and { 55, 85, 125, 180 } or { false }
          for index, tolerance in ipairs(tolerances) do
              local spread = tolerance ~= false and tolerance or nil
              if preferredSearch(spread, trioActive) then
                  preferredComplete = true
                  preferenceStage = index
                  break
              end
          end
          -- If both preferences cannot coexist, preserve BALANCED before
          -- relaxing to the ordinary distinct slate. AUTO typing is a soft
          -- relationship preference and never blocks a valid run.
          if not preferredComplete and balanceActive and trioActive then
              for index, tolerance in ipairs({ 55, 85, 125, 180 }) do
                  if preferredSearch(tolerance, false) then
                      preferredComplete = true
                      preferenceStage = 10 + index
                      mod.exports.__beta26.randomizerConstraintDiagnostic({
                          subsystem = "STARTER",
                          source = scope,
                          requested = "BALANCED+TYPE_AUTO",
                          result = "TYPE_RELAXED",
                          stage = index,
                          input = #missing,
                          safe = #missing,
                          candidates = #missing,
                          relaxed = true,
                          fallback = true,
                          reason = "no_balanced_type_cycle_in_search_window",
                      })
                      break
                  end
              end
          end
          if not preferredComplete and trioActive and not balanceActive then
              mod.exports.__beta26.randomizerConstraintDiagnostic({
                  subsystem = "STARTER",
                  source = scope,
                  requested = "TYPE_AUTO",
                  result = "TYPE_RELAXED",
                  stage = 1,
                  input = #missing,
                  safe = #missing,
                  candidates = #missing,
                  relaxed = true,
                  fallback = true,
                  reason = "no_type_cycle_in_search_window",
              })
          elseif not preferredComplete and balanceActive then
              mod.exports.__beta26.randomizerConstraintDiagnostic({
                  subsystem = "STARTER",
                  source = scope,
                  requested = "BALANCED",
                  result = "BALANCE_RELAXED",
                  stage = 4,
                  input = #missing,
                  safe = #missing,
                  candidates = #missing,
                  relaxed = true,
                  fallback = true,
                  reason = "no_balanced_distinct_slate_in_search_window",
              })
          end
      end

      -- Full distinct matching remains the authoritative safety fallback and is
      -- exhaustive over the legal candidate pools.
      local function sameAsPreviousSlate(candidateSlate)
          if rerollIndex <= 0 or type(previousPosition.slots) ~= "table" then
              return false
          end
          for _, original in ipairs(order) do
              if tostring(candidateSlate[original] or ""):upper()
                  ~= tostring(previousPosition.slots[original] or ""):upper() then
                  return false
              end
          end
          return true
      end

      local function assignDistinct(index)
          if index > #missing then
              return not sameAsPreviousSlate(slate)
          end
          local original = missing[index]
          local ordered = deterministicCandidateOrder(
              original, candidatePools[original] or {})
          local available = mod.exports.__beta26.randomizerWithoutReplacementPool(
              ordered, used)
          for _, pick in ipairs(available) do
              local key = tostring(pick or ""):upper()
              if not used[key] then
                  slate[original] = pick
                  used[key] = true
                  if assignDistinct(index + 1) then return true end
                  used[key] = nil
                  slate[original] = nil
              end
          end
          return false
      end

      local distinctComplete = preferredComplete or assignDistinct(1)
      if not distinctComplete then
          uniquenessRelaxed = true
          mod.exports.__beta26.randomizerConstraintDiagnostic({
              subsystem = "STARTER",
              source = scope,
              requested = "ATOMIC_DISTINCT",
              result = "DISTINCT_MATCHING_EXHAUSTED",
              stage = 0,
              input = #missing,
              safe = #missing,
              candidates = 0,
              relaxed = true,
              fallback = true,
              reason = "no_complete_distinct_assignment",
          })

          -- Compatibility safety valve: if hard-safe pools are too constrained,
          -- fill remaining rows deterministically and permit duplicates only
          -- after the complete distinct matching search has proven impossible.
          for _, original in ipairs(missing) do
              if slate[original] == nil then
                  local candidates = candidatePools[original] or {}
                  if #candidates == 0 then
                      slate[original] = original
                  elseif seed > 0 then
                      local pick = mod.exports.__beta26.randomizerSelectWithoutReplacement(
                          seed, RANDOMIZER_STREAMS.STARTER_SLATE,
                          scope .. ":" .. original .. ":fallback", candidates, used)
                      slate[original] = pick or original
                  else
                      local pool = mod.exports.__beta26.randomizerWithoutReplacementPool(
                          candidates, used)
                      local rng = love and love.math and love.math.random or math.random
                      slate[original] = pool[rng(1, #pool)] or original
                  end
                  used[tostring(slate[original]):upper()] = true
              end
          end
      end

      -- Validate the complete transaction before writing any scoped slate row.
      -- Distinctness may relax only if the legal pools genuinely could not
      -- supply another species; individual selections are already hard-safe.
      for _, original in ipairs(order) do
          local choice = tostring(slate[original] or ""):upper()
          if choice == "" or (choice ~= original
              and not randomStarterChoiceValid(game, choice)) then
              return nil
          end
      end

      for _, original in ipairs(order) do
          local choice = slate[original]
          choices[scope .. ":" .. original] = choice
          choices[original] = choice
      end
      choices[scope .. ":__UNIQUENESS_RELAXED"] = uniquenessRelaxed and "YES" or nil
      choices[scope .. ":__BALANCE"] = tostring(balance)
      choices[scope .. ":__TRIO_TYPING"] = tostring(trioTyping)
      choices[scope .. ":__PREFERENCE_STAGE"] = tostring(preferenceStage or 0)
      choices[scope .. ":__REROLL_INDEX"] = tostring(rerollIndex)
      mod.save:set(RANDOMIZER_SOURCE_MAPS.STARTER.saveKey, choices)
      persistStarterPositions(editionTag, seed, style, balance, trioTyping, rerollIndex, scopeVersion, order, slate)
      return slate
  end

  mod.exports.__beta26.randomStarterSlateVersion = STARTER_SLATE_VERSION
  mod.exports.__beta26.randomStarterSlate = atomicStarterSlate

  function mod.exports.__beta26.goldRandomStarterSlate(game, seed, style)
      if not mod.exports.__beta26.runtimeIsGen2(game) then return nil end
      return atomicStarterSlate(game, seed, style, "CHIKORITA")
  end

  -- Previewing a starter must not commit the run's chosen starter. R/B and
  -- Gold both let the player inspect multiple balls before deciding, so each
  -- vanilla ball gets one persisted random result. The actual selected ball
  -- is committed separately at the transaction seam.
  mod.exports.__beta26.selectRandomStarter = function(game, original)
      original = tostring(original or ""):upper()
      if not randomStarterRuleEnabled(game) then return original end

      local choices = randomStarterMap()
      local seed = mod.exports.__beta26.randomizerSeed(nil, true)
      local style = math.max(0, math.min(3, math.floor(tonumber(
          mod.save:get("random_starter_style", 0)) or 0)))
      -- Species Pool belongs to Random Encounters. Random Starter's
      -- deterministic namespace therefore stays on the full legal live pool.
      local generation = 0

      local starterSlateOriginal = original == "BULBASAUR"
          or original == "CHARMANDER" or original == "SQUIRTLE"
          or original == "PIKACHU" or original == "CHIKORITA"
          or original == "CYNDAQUIL" or original == "TOTODILE"
      if starterSlateOriginal then
          local slate = atomicStarterSlate(game, seed, style, original)
          local choice = slate and slate[original]
          if randomStarterChoiceValid(game, choice) then return choice end
      end

      -- Pre-seed builds stored one choice directly under the vanilla starter.
      -- On the first 2.2.19 seed, preserve that established result for the
      -- default ANY style by copying it into the seed-scoped namespace. If the
      -- player later chooses a structured Starter Style, its different scope
      -- gets a fresh deterministic result instead of reviving the legacy roll.
      local saved = tostring(choices[original] or ""):upper()
      local legacyOriginal = tostring(mod.save:get(
          "__nuzlocke_random_starter_original", "") or ""):upper()
      local legacyChoice = tostring(mod.save:get(
          "__nuzlocke_random_starter_choice", "") or ""):upper()
      if saved == "" and legacyOriginal == original then saved = legacyChoice end

      local candidates = mod.exports.__beta26.randomStarterCandidates(
          game, original)
      if #candidates == 0 then return original end

      -- Compatibility fallback for nonstandard/provider starter species that
      -- are outside the canonical atomic slate adapters. Supported R/B/Y/G/S
      -- starter transactions return through atomicStarterSlate above.
      local used = {}
      for otherOriginal, choice in pairs(choices) do
          local otherKey = tostring(otherOriginal or ""):upper()
          -- 2.5.84 / RS-CACHE-DEDUP-001: only the canonical bare
          -- per-starter mirror entries participate in legacy unseeded
          -- distinct-choice bookkeeping. Seed/style/scoped cache rows share
          -- this table and can contain perfectly valid species values, but
          -- counting those stale values as already used incorrectly shrinks
          -- the live unseeded pool. Internal marker rows are likewise not
          -- starter slots. Seeded selection is intentionally unchanged.
          local canonicalMirror = otherKey ~= ""
              and not otherKey:find(":", 1, true)
              and otherKey:sub(1, 2) ~= "__"
          if canonicalMirror and otherKey ~= original
              and randomStarterChoiceValid(game, choice) then
              used[tostring(choice):upper()] = true
          end
      end
      local unused = {}
      for _, choice in ipairs(candidates) do
          if not used[choice] then unused[#unused + 1] = choice end
      end
      local algorithmVersion = mod.exports.__beta26.randomizerAlgorithmVersion()
      local scopeKey = table.concat({
          "v" .. tostring(algorithmVersion), "s" .. tostring(seed),
          "style" .. tostring(style), "g" .. tostring(generation), original }, ":")
      local scopedSaved = tostring(choices[scopeKey] or ""):upper()
      if randomStarterChoiceValid(game, scopedSaved) then return scopedSaved end
      local legacyMarker = "__LEGACY_ADOPTED_" .. original
      if style == 0 and choices[legacyMarker] ~= "YES" and saved ~= ""
          and randomStarterChoiceValid(game, saved) then
          choices[scopeKey] = saved
          choices[original] = saved
          choices[legacyMarker] = "YES"
          mod.save:set(RANDOMIZER_SOURCE_MAPS.STARTER.saveKey, choices)
          return saved
      end

      local pool = seed > 0 and candidates or (#unused > 0 and unused or candidates)
      local choice
      if seed > 0 then
          -- Use the same versioned hash/stream path as encounter and learnset
          -- randomization. Algorithm v1 produces the exact same hash input as
          -- the historical starter implementation, so current seeded results
          -- remain stable while any future version bump stays synchronized.
          choice = pool[mod.exports.__beta26.randomizerSeededIndex(
              RANDOMIZER_STREAMS.STARTER, scopeKey, #pool)]
          choices[scopeKey] = choice
      else
          local rng = love and love.math and love.math.random or math.random
          choice = pool[rng(1, #pool)]
      end
      choices[original] = choice
      mod.save:set(RANDOMIZER_SOURCE_MAPS.STARTER.saveKey, choices)
      return choice
  end

  -- Phase B #11: current Yellow's Cerulean Bulbasaur gift still gates on
  -- starter-Pikachu happiness >=147. A non-Pikachu randomized opening starter
  -- cannot naturally advance that starter-only meter, so satisfy only that
  -- orphaned story field and leave normal Pikachu runs untouched.
  local function ensureYellowRandomStarterProgression(game, choice)
      game = game or getCurrentGame() or mod.game
      choice = tostring(choice or mod.save:get(
          "__nuzlocke_random_starter_choice", "") or ""):upper()
      if tostring(getGameVersion() or ""):upper() ~= "YELLOW"
          or choice == "" or choice == "PIKACHU" then return false end
      local save = game and game.save
      if not save then return false end
      local current = tonumber(save.pikachuHappiness) or 90
      if current < 147 then
          save.pikachuHappiness = 147
          return true
      end
      return false
  end
  mod.exports.__beta26.ensureYellowRandomStarterProgression =
      ensureYellowRandomStarterProgression

  mod.exports.__beta26.commitRandomStarter = function(game, original, choice)
      original = tostring(original or ""):upper()
      choice = tostring(choice or ""):upper()
      if not randomStarterRuleEnabled(game)
          or original == "" or choice == "" then return choice end

      local choices = randomStarterMap()
      choices[original] = choice
      mod.save:set(RANDOMIZER_SOURCE_MAPS.STARTER.saveKey, choices)
      -- These legacy/current scalar fields now mean the starter the player
      -- ACTUALLY accepted, not whichever ball happened to be previewed first.
      mod.save:set("__nuzlocke_random_starter_choice", choice)
      mod.save:set("__nuzlocke_random_starter_original", original)
      mod.save:set(STARTER_REROLL_LOCK_KEY, true)
      ensureYellowRandomStarterProgression(game, choice)
      return choice
  end

  local function starterRerollIndex(profile)
      if type(profile) == "table" then
          return math.max(0, math.floor(tonumber(
              profile.random_starter_reroll_index) or 0))
      end
      return math.max(0, math.floor(tonumber(
          mod.save:get(STARTER_REROLL_INDEX_KEY, 0)) or 0))
  end

  local function starterAccepted(game)
      if mod.save:get(STARTER_REROLL_LOCK_KEY, false) == true then return true end
      if tostring(mod.save:get("__nuzlocke_random_starter_choice", "") or "") ~= "" then
          return true
      end
      local save = game and game.save
      local flags = save and save.flags or {}
      return flags.EVENT_GOT_STARTER == true
          or tonumber(flags.EVENT_GOT_STARTER) == 1
  end

  mod.exports.__beta26.randomizerCanRerollStarter = function(profile, game)
      if type(profile) == "table" then
          return profile.random_starter == true
              and profile.random_starter_rerolls == true
      end
      game = game or getCurrentGame() or mod.game
      return mod.save:get("random_starter", false) == true
          and mod.save:get("random_starter_rerolls", false) == true
          and not starterAccepted(game)
  end

  mod.exports.__beta26.randomizerRerollStarter = function(profile, game)
      if not mod.exports.__beta26.randomizerCanRerollStarter(profile, game) then
          return nil
      end
      local nextIndex = starterRerollIndex(profile) + 1
      if type(profile) == "table" then
          profile.random_starter_reroll_index = nextIndex
          return nextIndex
      end
      mod.save:set(STARTER_REROLL_INDEX_KEY, nextIndex)
      -- Keep the previous positional slate long enough for atomic generation to
      -- reject an identical reroll. The next starter preview/materialization
      -- replaces it with the new deterministic reroll-index slate.
      return nextIndex
  end

  mod.exports.__beta26.randomizerStarterRerollIndex = starterRerollIndex

  mod.events:on("game.ready", function(ev)
      local game = type(ev) == "table" and ev.game or ev
      pcall(ensureYellowRandomStarterProgression,
          game or getCurrentGame() or mod.game)
  end)
  mod.events:on("save.loaded", function()
      pcall(ensureYellowRandomStarterProgression,
          getCurrentGame() or mod.game)
  end)

  -- Read-only starter diagnostics. Candidate counts explicitly disable
  -- constraint-ledger recording so opening information surfaces mutates nothing.
  mod.exports.__beta26.randomizerStarterInfo = function(game, reveal)
      game = game or getCurrentGame() or mod.game
      local version = tostring(getGameVersion() or ""):upper()
      local original = mod.exports.__beta26.runtimeIsGen2(game) and "CHIKORITA"
          or (version == "YELLOW" and "PIKACHU" or "BULBASAUR")
      local order = select(1, starterSlateOrder(game, original))
      local position = starterPositionState()
      local info = {
          algorithmVersion = mod.exports.__beta26.randomizerAlgorithmVersion(),
          starterSlateVersion = tonumber(position.slateVersion)
              or ((starterRerollIndex() > 0
                  or tonumber(mod.save:get("random_starter_balance", 0)) == 1
                  or tonumber(mod.save:get("random_starter_trio_typing", 0)) == 1)
                  and STARTER_SLATE_VERSION or 2),
          seed = math.max(0, math.floor(tonumber(
              mod.exports.__beta26.randomizerSeed(nil, false)) or 0)),
          style = math.max(0, math.min(3, math.floor(tonumber(
              position.style ~= nil and position.style
                  or mod.save:get("random_starter_style", 0)) or 0))),
          balance = math.max(0, math.min(1, math.floor(tonumber(
              position.balance ~= nil and position.balance
                  or mod.save:get("random_starter_balance", 0)) or 0))),
          trioTyping = math.max(0, math.min(1, math.floor(tonumber(
              position.trioTyping ~= nil and position.trioTyping
                  or mod.save:get("random_starter_trio_typing", 0)) or 0))),
          rerollsEnabled = mod.save:get("random_starter_rerolls", false) == true,
          rerollIndex = starterRerollIndex(),
          materializedRerollIndex = math.max(0, math.floor(tonumber(
              position.rerollIndex) or 0)),
          rerollLocked = starterAccepted(game),
          edition = tostring(position.edition or version),
          order = {},
          candidateCounts = {},
          constraints = {},
      }
      for i, key in ipairs(order or {}) do
          info.order[i] = key
          local candidates = mod.exports.__beta26.randomStarterCandidates(
              game, key, { record = false })
          info.candidateCounts[key] = #candidates
      end
      if reveal == true and type(position.slots) == "table" then
          info.slate = starterCopy(position.slots)
      else
          info.slateHidden = type(position.slots) == "table"
      end
      local diagnostics = type(mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
          and mod.exports.__beta26.randomizerConstraintDiagnostics() or {}
      for _, row in ipairs(diagnostics) do
          if tostring(row.subsystem or ""):upper() == "STARTER" then
              info.constraints[#info.constraints + 1] = starterCopy(row)
          end
      end
      return info
  end

  mod.exports.__beta26.randomizerStarterPositionAudit = function(game)
      local report = { ok = true, checked = 0, failures = {} }
      local state = starterPositionState()
      if next(state) == nil then
          report.empty = true
          return report
      end
      report.checked = report.checked + 1
      if tonumber(state.schema) ~= 1
          or (tonumber(state.slateVersion) ~= 2
              and tonumber(state.slateVersion) ~= STARTER_SLATE_VERSION) then
          report.ok = false
          report.failures[#report.failures + 1] = "position_schema"
      end
      report.checked = report.checked + 1
      if type(state.order) ~= "table" or type(state.slots) ~= "table" then
          report.ok = false
          report.failures[#report.failures + 1] = "position_shape"
      else
          local seen = {}
          for _, original in ipairs(state.order) do
              original = tostring(original or ""):upper()
              local choice = tostring(state.slots[original] or ""):upper()
              if original == "" or choice == "" or seen[original] then
                  report.ok = false
                  report.failures[#report.failures + 1] = "position_identity"
                  break
              end
              seen[original] = true
          end
      end
      report.checked = report.checked + 1
      if type(state.edition) ~= "string" or state.edition == "" then
          report.ok = false
          report.failures[#report.failures + 1] = "position_edition"
      end
      return report
  end

  mod.exports.__beta26.randomizerStarterLineageAudit = function(game)
      local report = { ok = true, checked = 0, failures = {} }
      game = game or getCurrentGame() or mod.game
      local lineage = starterOriginalLineage(game)
      report.checked = report.checked + 1
      if type(lineage) ~= "table" or type(lineage.nodes) ~= "table"
          or type(lineage.stage) ~= "function"
          or type(lineage.threeStageBase) ~= "function"
          or type(lineage.root) ~= "function"
          or type(lineage.depth) ~= "function"
          or type(lineage.descendantAtDepth) ~= "function" then
          report.ok = false
          report.failures[#report.failures + 1] = "lineage_contract"
          return report
      end
      local count = 0
      for species, node in pairs(lineage.nodes) do
          count = count + 1
          if type(species) ~= "string" or type(node) ~= "table"
              or type(node.children) ~= "table" then
              report.ok = false
              report.failures[#report.failures + 1] = "lineage_node"
              break
          end
      end
      report.checked = report.checked + 1
      report.species = count
      if count == 0 then
          report.ok = false
          report.failures[#report.failures + 1] = "lineage_empty"
      end
      return report
  end

  mod.exports.__beta26.randomizerStarterPreferenceAudit = function(game)
      local report = { ok = true, checked = 0, failures = {} }
      game = game or getCurrentGame() or mod.game
      local lineage = starterOriginalLineage(game)

      report.checked = report.checked + 1
      local probe = mod.exports.__beta26.runtimeIsGen2(game) and "CHIKORITA" or "BULBASAUR"
      local score = starterStrengthScore(game, lineage, probe)
      if tonumber(score) == nil or score <= 0 then
          report.ok = false
          report.failures[#report.failures + 1] = "strength_score"
      end

      report.checked = report.checked + 1
      local order, slate
      if mod.exports.__beta26.runtimeIsGen2(game) then
          order = { "CHIKORITA", "CYNDAQUIL", "TOTODILE" }
          slate = {
              CHIKORITA = "CHIKORITA",
              CYNDAQUIL = "CYNDAQUIL",
              TOTODILE = "TOTODILE",
          }
      else
          order = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" }
          slate = {
              BULBASAUR = "BULBASAUR",
              CHARMANDER = "CHARMANDER",
              SQUIRTLE = "SQUIRTLE",
          }
      end
      if not starterSlateTypeCycle(game, order, slate) then
          report.ok = false
          report.failures[#report.failures + 1] = "native_type_cycle"
      end

      report.checked = report.checked + 1
      local state = starterPositionState()
      if next(state) ~= nil and tonumber(state.slateVersion) == STARTER_SLATE_VERSION then
          local balance = tonumber(state.balance)
          local trio = tonumber(state.trioTyping)
          if (balance ~= 0 and balance ~= 1) or (trio ~= 0 and trio ~= 1) then
              report.ok = false
              report.failures[#report.failures + 1] = "position_preference_state"
          end
      end
      return report
  end

  mod.exports.starter_randomizer = {
      api = 2,
      build = mod.exports.__beta26.build,
      select = mod.exports.__beta26.selectRandomStarter,
      commit = mod.exports.__beta26.commitRandomStarter,
  }
  mod.exports.nuzlocke_compat.selectRandomStarter =
      mod.exports.__beta26.selectRandomStarter
  mod.exports.nuzlocke_compat.commitRandomStarter =
      mod.exports.__beta26.commitRandomStarter

  -- Phase B 6: rival starter-family synchronization. The rival never rolls a
  -- second random species. Canonical rival starter-family members are mapped
  -- to the corresponding persisted native starter position, preserving the
  -- original member's evolution depth through the captured original lineage.
  local function canonicalRivalClass(game, classId)
      local values = { tostring(classId or "") }
      local data = game and game.data
      local classes = data and data.gen2Trainers and data.gen2Trainers.classes
      local class = type(classes) == "table" and classes[classId] or nil
      if class == nil and type(classes) == "table" then
          for id, row in pairs(classes) do
              if tostring(id) == tostring(classId) then class = row; break end
          end
      end
      if type(class) == "table" then
          values[#values + 1] = tostring(class.id or "")
          values[#values + 1] = tostring(class.name or "")
          values[#values + 1] = tostring(class.class or "")
      end
      for _, value in ipairs(values) do
          local compact = value:upper():gsub("[^A-Z0-9]", "")
          if compact:match("^RIVAL%d*$")
              or compact:match("^OPPRIVAL%d*$")
              or compact:match("^TRAINERRIVAL%d*$") then
              return true
          end
      end
      return false
  end

  -- 2.6.95: keep the rival-sync audit below canonicalRivalClass so the audit
  -- closes over the intended local helper. Defining this audit earlier caused
  -- Lua to resolve canonicalRivalClass as a global nil at runtime.
  mod.exports.__beta26.randomizerRivalSyncAudit = function()
      local report = { ok = true, checked = 0, failures = {} }
      report.checked = report.checked + 1
      if type(mod.exports.__beta26.randomizerSynchronizedRivalSpecies) ~= "function" then
          report.ok = false
          report.failures[#report.failures + 1] = "missing_sync_helper"
      end
      report.checked = report.checked + 1
      local classes = { "RIVAL", "OPP_RIVAL1", "TRAINER_RIVAL2" }
      for _, classId in ipairs(classes) do
          if not canonicalRivalClass(nil, classId) then
              report.ok = false
              report.failures[#report.failures + 1] = "class:" .. classId
          end
      end
      return report
  end

  local function canonicalStarterFamilyRoot(game, species)
      local lineage = starterOriginalLineage(game)
      if not lineage then return nil end
      local root = tostring(lineage.root(species) or ""):upper()
      local version = tostring(getGameVersion() or ""):upper()
      local allowed
      if mod.exports.__beta26.runtimeIsGen2(game) then
          allowed = { CHIKORITA=true, CYNDAQUIL=true, TOTODILE=true }
      elseif version == "YELLOW" then
          allowed = { EEVEE=true }
      else
          allowed = { BULBASAUR=true, CHARMANDER=true, SQUIRTLE=true }
      end
      return allowed[root] and root or nil
  end

  local function rivalSyncSpeciesValid(game, species)
      species = tostring(species or ""):upper()
      local def = game and game.data and game.data.pokemon
          and game.data.pokemon[species]
      return species ~= "" and type(def) == "table"
          and not mod.exports.__beta26.getGlitchSpeciesInfo(game, species).isGlitch
          and (not mod.exports.__beta26.runtimeIsGen2(game)
              or tonumber(def.index) ~= nil)
  end

  local function synchronizedRivalSpecies(game, species)
      species = tostring(species or ""):upper()
      local lineage = starterOriginalLineage(game)
      if not lineage then return species end
      local anchor = canonicalStarterFamilyRoot(game, species)
      if not anchor then return species end

      -- Once a starter transaction has materialized, its persisted positional
      -- slate is authoritative for rival continuity. This prevents later edits
      -- to Starter Style/Balance/Trio Typing from rewriting an established run.
      local position = starterPositionState()
      local chosen = type(position.slots) == "table"
          and tostring(position.slots[anchor] or ""):upper() or ""
      if chosen == "" then
          local seed = mod.exports.__beta26.randomizerSeed(nil, true)
          local style = math.max(0, math.min(3, math.floor(tonumber(
              mod.save:get("random_starter_style", 0)) or 0)))
          local slate = atomicStarterSlate(game, seed, style, anchor)
          chosen = slate and tostring(slate[anchor] or ""):upper() or ""
      end
      if chosen == "" or not randomStarterChoiceValid(game, chosen) then
          return species
      end
      local targetDepth = lineage.depth(species)
      local resolved = lineage.descendantAtDepth(chosen, targetDepth)
      resolved = tostring(resolved or chosen):upper()
      return rivalSyncSpeciesValid(game, resolved) and resolved or chosen
  end
  mod.exports.__beta26.randomizerSynchronizedRivalSpecies = synchronizedRivalSpecies

  mod.hooks:wrap("trainer.party", function(next, classId, partyIndex, party)
      local resolved = next(classId, partyIndex, party) or party
      local game = getCurrentGame() or mod.game
      if not randomStarterRuleEnabled(game)
          or not canonicalRivalClass(game, classId) or type(resolved) ~= "table" then
          return resolved
      end
      local out = starterCopy(resolved)
      local node = out.party or out.team or out.roster or out.pokemon
          or out.mons or out.members or out
      if type(node) ~= "table" then return resolved end
      local changed = false
      for key, mon in pairs(node) do
          if type(key) == "number" and type(mon) == "table" and mon.species ~= nil then
              local before = tostring(mon.species or ""):upper()
              local after = synchronizedRivalSpecies(game, before)
              if after ~= "" and after ~= before then
                  mon.species = after
                  changed = true
              end
          end
      end
      return changed and out or resolved
  end, 92000)

  -- R/B/Y's supported pre-creation gift event lets the actual Pokemon be
  -- transformed without replacing Commands.give_pokemon. Restrict it to the
  -- first party acquisition and Oak's canonical starter species.
  mod.events:on("pokemon.before_give", function(gift)
      local ctx = type(gift) == "table" and gift.ctx or nil
      local game = ctx and ctx.game or getCurrentGame() or mod.game
      local save = ctx and ctx.save or game and game.save
      if mod.exports.__beta26.runtimeIsGen2(game)
          or not save or #(save.party or {}) ~= 0 then return end
      local original = tostring(gift and gift.species or ""):upper()
      if original ~= "BULBASAUR" and original ~= "CHARMANDER"
          and original ~= "SQUIRTLE" and original ~= "PIKACHU" then return end
      local area = tostring((ctx and (ctx.mapId or ctx.map))
          or (ctx and ctx.overworld and ctx.overworld.map
              and ctx.overworld.map.id)
          or (save.player and save.player.map) or ""):upper()
      if area ~= "PALLET_TOWN" and not area:find("OAK", 1, true)
          and not area:find("LAB", 1, true) then return end
      gift.nuzlockeOriginalStarter = original
      gift.species = mod.exports.__beta26.selectRandomStarter(game, original)
      if (not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) and mod.save:get("random_starter", false) == true) then
          mod.exports.__beta26.commitRandomStarter(
              game, original, gift.species)
      end
  end)

  -- Oak's received-mon line appears immediately before give_pokemon. Rewrite
  -- only that reveal buffer so R/B/Y names the species the persisted roll will
  -- actually grant; the earlier ball/Dex preview still describes the player's
  -- chosen vanilla ball and therefore keeps the intended choice semantics.
  -- 2.3.32 primary Gym Team Size gate.
  -- Phase B #11 static Yellow dependency audit. The current package already
  -- repairs the confirmed post-lab Pikachu-only presentation dependency above;
  -- opening-starter tracking/nickname logic keys off committed provenance rather
  -- than literal Pikachu; and non-Pikachu randomized starters receive the narrow
  -- Cerulean Bulbasaur happiness-gate compatibility repair.
  mod.exports.__beta26.randomizerYellowStarterDependencyAudit = function(game)
      local report = { ok = true, checked = 0, failures = {} }
      game = game or getCurrentGame() or mod.game
      if tostring(getGameVersion() or ""):upper() ~= "YELLOW" then
          report.notApplicable = true
          return report
      end
      report.checked = report.checked + 1
      local order, tag = starterSlateOrder(game, "PIKACHU")
      if tag ~= "YELLOW" or #order ~= 2
          or order[1] ~= "PIKACHU" or order[2] ~= "EEVEE" then
          report.ok = false
          report.failures[#report.failures + 1] = "yellow_position_contract"
      end
      report.checked = report.checked + 1
      if type(mod.exports.__beta26.isOpeningStarterAcquisition) ~= "function" then
          report.ok = false
          report.failures[#report.failures + 1] = "opening_provenance_helper"
      end
      report.checked = report.checked + 1
      if type(mod.exports.__beta26.randomizerSynchronizedRivalSpecies) ~= "function" then
          report.ok = false
          report.failures[#report.failures + 1] = "yellow_rival_sync"
      end
      report.checked = report.checked + 1
      local accepted = tostring(mod.save:get(
          "__nuzlocke_random_starter_choice", "") or ""):upper()
      if accepted ~= "" and accepted ~= "PIKACHU"
          and tonumber(game and game.save and game.save.pikachuHappiness or 90) < 147 then
          report.ok = false
          report.failures[#report.failures + 1] = "cerulean_bulbasaur_happiness_gate"
      end
      return report
  end

  -- Standard R/B/Y Gym Leaders (including Yellow Brock) enter through
  -- OverworldState:engageTrainer -> trainer.before_battle, not necessarily
  -- through the script.command/start_battle path. Defer here, show the
  -- tiered refusal, then cancel cleanly before BattleState.newTrainer exists.
  mod.hooks:wrap("trainer.before_battle",
      function(next, game, context, continueBattle)
          if mod.save:get("nuzlocke_enabled", true) ~= true
              or mod.save:get("gym_team_size", false) ~= true then
              return next(game, context, continueBattle)
          end

          local info = mod.exports.__beta26.isNextGymLeaderBattleContext(
              game, context)
          if not info then
              return next(game, context, continueBattle)
          end

          local save = game and game.save or getCurrentSave()
          local have = mod.exports.__beta26.playerGymTeamCount(save)
          local limit = tonumber(info.limit or info.teamSize)
          if not limit or have <= limit then
              return next(game, context, continueBattle)
          end

          -- 2.4.8: the refusal text may be observed through more than one
          -- pre-battle callback in the same trainer engagement. Show it once
          -- for this battle-attempt transaction, but never weaken enforcement.
          --
          -- A later talk/challenge gets a fresh context and can explain again.
          if type(context) == "table" and context.nuzlockeGymCapTextShown == true then
              continueBattle({ cancel = true })
              return true
          end
          if type(context) == "table" then
              context.nuzlockeGymCapTextShown = true
          end

          local completed = false
          local function cancelAfterDialogue()
              if completed then return end
              completed = true
              continueBattle({ cancel = true })
          end
          mod.exports.__beta26.rejectGymTeamSize(
              game, info, have, "trainer.before_battle", cancelAfterDialogue)

          -- trainer.before_battle interprets true as "a preparation provider
          -- owns this decision for now"; cancelAfterDialogue resolves that
          -- deferred transaction after the player closes the refusal text.
          return true
      end, 95000)

  mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
      -- R/B starter Dex preview: keep the selected ball/story branch vanilla,
      -- but show the same persisted randomized species that will actually be
      -- granted a few rows later. This fixes a Charmander/Squirtle/Bulbasaur
      -- portrait mismatch without rerolling or changing Rival counter-picks.
      if ctx and ctx.generation ~= 2 and name == "ask"
          and type(args) == "table" and ctx.save
          and #(ctx.save.party or {}) == 0
          and (not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) and mod.save:get("random_starter", false) == true) then
          local textId = tostring(args[1] or "")
          local original = textId:find("Charmander", 1, true) and "CHARMANDER"
              or textId:find("Squirtle", 1, true) and "SQUIRTLE"
              or textId:find("Bulbasaur", 1, true) and "BULBASAUR" or nil
          if original then
              local choice = mod.exports.__beta26.selectRandomStarter(
                  ctx.game or getCurrentGame() or mod.game, original)
              local rewritten = {}
              for i, value in ipairs(args) do rewritten[i] = value end
              rewritten[1] = "So! You want " .. choice .. "?"
              return next(ctx, name, rewritten, cmd)
          end
      end

      if ctx and ctx.generation ~= 2 and name == "push_screen"
          and type(args) == "table" and args[1] == "DexEntryMenu"
          and type(args[2]) == "table" and ctx.save
          and #(ctx.save.party or {}) == 0
          and (not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) and mod.save:get("random_starter", false) == true) then
          local original = tostring(args[2].species or ""):upper()
          if original == "BULBASAUR" or original == "CHARMANDER"
              or original == "SQUIRTLE" then
              local rewritten, opts = {}, {}
              for i, value in ipairs(args) do rewritten[i] = value end
              for key, value in pairs(args[2]) do opts[key] = value end
              opts.species = mod.exports.__beta26.selectRandomStarter(
                  ctx.game or getCurrentGame() or mod.game, original)
              rewritten[2] = opts
              return next(ctx, name, rewritten, cmd)
          end
      end

      -- Yellow's native post-lab-battle sequence assumes the starter is
      -- Pikachu: it spawns the Pikachu follower, plays Pikachu's cry, and
      -- prints two Pikachu-specific lines. When Random Starter chose anything
      -- else, suppress only that presentation. Battle-result/story flags and
      -- Rival progression have already been committed and remain untouched.
      if ctx and ctx.generation ~= 2 and getGameVersion() == "YELLOW"
          and (not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) and mod.save:get("random_starter", false) == true) then
          local choice = tostring(mod.save:get(
              "__nuzlocke_random_starter_choice", "") or ""):upper()
          local mapId = tostring((ctx.overworld and ctx.overworld.map
              and ctx.overworld.map.id) or ctx.mapId or ""):upper()
          if choice ~= "" and choice ~= "PIKACHU"
              and (mapId == "OAKS_LAB" or mapId:find("OAK", 1, true)) then
              if name == "spawn_pikachu_follower" then return nil end
              if name == "play_cry" and type(args) == "table"
                  and tostring(args[1] or ""):upper() == "PIKACHU" then
                  return nil
              end
              if name == "show_text" and type(args) == "table" then
                  local textId = tostring(args[1] or "")
                  if textId == "_OaksLabPikachuDislikesPokeballsText1" then
                      local rewritten = {}
                      for i, value in ipairs(args) do rewritten[i] = value end
                      rewritten[1] = choice .. " looks ready to travel with you!"
                      return next(ctx, name, rewritten, cmd)
                  elseif textId == "_OaksLabPikachuDislikesPokeballsText2" then
                      return nil
                  end
              end
          end
      end

      if ctx and ctx.generation ~= 2 and name == "show_text"
          and type(args) == "table"
          and tostring(args[1] or "") == "_OaksLabRivalMyPokemonLooksStrongerText" then
          local rewritten = {}
          for i, value in ipairs(args) do rewritten[i] = value end
          rewritten[1] = "My Pokemon's ready.\nMeet me outside!"
          return next(ctx, name, rewritten, cmd)
      end

      if ctx and ctx.generation ~= 2 and name == "show_text"
          and type(args) == "table" and type(args[2]) == "table"
          and (args[1] == "_OaksLabReceivedMonText"
              or args[1] == "_OaksLabReceivedText")
          and ctx.save and #(ctx.save.party or {}) == 0
          and (not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) and mod.save:get("random_starter", false) == true) then
          local original = tostring(args[2].RAM or ""):upper()
          if original == "BULBASAUR" or original == "CHARMANDER"
              or original == "SQUIRTLE" or original == "PIKACHU" then
              local reveal = {}
              for key, value in pairs(args[2]) do reveal[key] = value end
              reveal.RAM = mod.exports.__beta26.selectRandomStarter(
                  ctx.game or getCurrentGame() or mod.game, original)
              local rewritten = {}
              for i, value in ipairs(args) do rewritten[i] = value end
              rewritten[2] = reveal
              return next(ctx, name, rewritten, cmd)
          end
      end
      return next(ctx, name, args, cmd)
  end)

  -- Static status is provenance, not a species list. Script-command adapters
  -- stamp fixed wild battles before battle.started; compatible encounter mods
  -- may also provide one of these explicit fields themselves. This keeps
  -- randomizers correct when a normally static species appears in grass.
  mod.exports.__beta26.isStaticEncounter = function(game, battle)
      if type(battle) ~= "table" then return false end
      local encounterType = tostring(battle.encounterType
          or battle.encounterSource or battle.source or ""):lower()
      return battle.nuzlockeStaticEncounter == true
          or battle.staticEncounter == true
          or battle.isStaticEncounter == true
          or battle.fixedEncounter == true
          or encounterType == "static"
          or encounterType == "fixed"
  end


  return {
      randomStarterChoiceValid = randomStarterChoiceValid,
      randomStarterRuleEnabled = randomStarterRuleEnabled,
  }
end
