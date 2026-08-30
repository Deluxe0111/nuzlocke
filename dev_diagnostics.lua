return function(mod, deps)
  deps = deps or {}
  local compatPublicCopy = assert(deps.compatPublicCopy,
      "dev_diagnostics requires compatPublicCopy")

  -- 2.6.1: executable property checks for pure helpers used by production
  -- configuration/economy/item-policy paths. These are deterministic and
  -- read-only, so Release Safety and DEV diagnostics can run them repeatedly.
  mod.exports.__beta26.pureHelperAudit = function()
      local report = { ok = true, checked = 0, failures = {} }
      local function check(id, condition, detail)
          report.checked = report.checked + 1
          if condition then return end
          report.ok = false
          report.failures[#report.failures + 1] = tostring(id)
              .. (detail and (":" .. tostring(detail)) or "")
      end

      check("finite_identity", deps.finiteNumber(42, 7) == 42)
      check("finite_nan_fallback", deps.finiteNumber(0/0, 7) == 7)
      check("finite_inf_fallback", deps.finiteNumber(math.huge, 7) == 7)

      check("movement_bool_true", deps.movementAssistMode(true) == 1)
      check("movement_bool_false", deps.movementAssistMode(false) == 0)
      check("movement_low_clamp", deps.movementAssistMode(-99) == 0)
      check("movement_high_clamp", deps.movementAssistMode(99) == 2)
      check("movement_floor", deps.movementAssistMode(1.9) == 1)

      check("cycle_forward_wrap", deps.cycleIntegerRange(2, 0, 2, 1) == 0)
      check("cycle_backward_wrap", deps.cycleIntegerRange(0, 0, 2, -1) == 2)
      check("cycle_large_step", deps.cycleIntegerRange(1, 0, 2, 4) == 2)
      check("cycle_clamps_input", deps.cycleIntegerRange(99, 0, 2, 1) == 0)

      check("percent_vanilla", deps.scalePercentFloor(101, 100) == 101)
      check("percent_floor", deps.scalePercentFloor(101, 25) == 25)
      check("percent_scale_up", deps.scalePercentFloor(101, 150) == 151)
      check("percent_negative_amount", deps.scalePercentFloor(-20, 100) == 0)

      check("item_spaces", deps.normalizeItemPolicyKey("poke ball") == "POKE_BALL")
      check("item_hyphen", deps.normalizeItemPolicyKey("x-accuracy") == "X_ACCURACY")
      check("item_table", deps.normalizeItemPolicyKey({ name = "super repel" }) == "SUPER_REPEL")

      local bstValues = deps.maximumBstPresetValues or {}
      for index = 0, 9 do
          local resolved, exact = deps.maximumBstPresetIndex(bstValues[index])
          check("bst_exact_" .. tostring(index), resolved == index and exact == true)
      end
      local nearest, nearestExact = deps.maximumBstPresetIndex(525)
      check("bst_nearest_tie", nearest == 5 and nearestExact == false)

      local statValues = deps.statExpPresetValues or {}
      check("stat_exp_zero", statValues[0] == 0)
      check("stat_exp_cap", statValues[5] == 65535)
      for index = 1, 5 do
          check("stat_exp_monotonic_" .. tostring(index),
              tonumber(statValues[index]) > tonumber(statValues[index - 1]))
      end

      check("coerce_dupes_legacy_true",
          deps.coerceRuleValue("dupes_mode", true, "read") == 2)
      check("coerce_shiny_high",
          deps.coerceRuleValue("shiny_clause", 99, "read") == 4)
      check("coerce_party_low",
          deps.coerceRuleValue("party_size_limit", -5, "read") == 1)

      if type(deps.configValuesDiffer) == "function" then
          check("preset_diff_number_same", deps.configValuesDiffer(2, 2) == false)
          check("preset_diff_number_string", deps.configValuesDiffer("2", 2) == false)
          check("preset_diff_number_changed", deps.configValuesDiffer(3, 2) == true)
          check("preset_diff_bool_same", deps.configValuesDiffer(true, true) == false)
          check("preset_diff_bool_changed", deps.configValuesDiffer(false, true) == true)
      else
          check("preset_diff_helper_available", false)
      end

      if type(deps.cardinalPhysicalArea) == "function" then
          check("area_split_ns_north", deps.cardinalPhysicalArea("ROUTE_1", 4, 2, 10, 20) == "ROUTE_1_NORTH")
          check("area_split_ns_south", deps.cardinalPhysicalArea("ROUTE_1", 4, 18, 10, 20) == "ROUTE_1_SOUTH")
          check("area_split_missing_position_parent", deps.cardinalPhysicalArea("ROUTE_1", nil, nil, 10, 20) == "ROUTE_1")
      else
          check("area_split_helper_available", false)
      end

      if type(deps.randomSpeciesGeneration) == "function"
          and type(deps.randomSpeciesPoolAllows) == "function" then
          check("random_pool_gen1", deps.randomSpeciesGeneration({ index = 25 }) == 1)
          check("random_pool_gen2", deps.randomSpeciesGeneration({ index = 200 }) == 2)
          check("random_pool_gen3", deps.randomSpeciesGeneration({ index = 300 }) == 3)
          check("random_pool_gen1_only", deps.randomSpeciesPoolAllows({ index = 25 }, 1) == true
              and deps.randomSpeciesPoolAllows({ index = 200 }, 1) == false)
          check("random_pool_gen2_only", deps.randomSpeciesPoolAllows({ index = 200 }, 2) == true
              and deps.randomSpeciesPoolAllows({ index = 25 }, 2) == false)
          check("random_pool_gen12", deps.randomSpeciesPoolAllows({ index = 25 }, 3) == true
              and deps.randomSpeciesPoolAllows({ index = 200 }, 3) == true
              and deps.randomSpeciesPoolAllows({ index = 300 }, 3) == false)
      else
          check("random_pool_helpers_available", false)
      end

      if type(deps.composeLevelCap) == "function" then
          local cap, name, owner = deps.composeLevelCap(50, "BOSS", 45, "OTHER")
          check("level_cap_other_stricter", cap == 45 and name == "OTHER" and owner == "OTHER")
          cap, name, owner = deps.composeLevelCap(50, "BOSS", 50, "OTHER")
          check("level_cap_shared", cap == 50 and name == "BOSS + KR" and owner == "SHARED")
          cap, name, owner = deps.composeLevelCap(50, "BOSS", 55, "OTHER")
          check("level_cap_nuz_stricter", cap == 50 and name == "BOSS" and owner == "NUZLOCKE")
      else
          check("level_cap_helper_available", false)
      end

      if type(deps.runHistoryDedupeKey) == "function" then
          check("history_catch_dedupe", deps.runHistoryDedupeKey("catch", "P1") == "catch:P1")
          check("history_death_dedupe", deps.runHistoryDedupeKey("death", "P1", 2) == "death:P1:2")
          check("history_death_floor", deps.runHistoryDedupeKey("death", "P1", 2.9) == "death:P1:2")
          check("history_missing_identity", deps.runHistoryDedupeKey("catch", nil) == nil)
      else
          check("history_dedupe_helper_available", false)
      end

      local registry = mod.exports.__beta26.ruleRegistry
      if type(registry) == "table" and type(registry.validateStored) == "function" then
          local valid = registry.validateStored({
              dupes_mode = 2, nickname_rule = true, party_size_limit = 6,
          })
          check("stored_validator_valid", valid.ok == true
              and valid.invalid_count == 0)
          local invalid = registry.validateStored({ dupes_mode = 99 })
          check("stored_validator_range", invalid.ok == false
              and invalid.invalid_count >= 1)
          local stale = registry.validateStored({ dupes_mode = true })
          check("stored_validator_legacy", stale.ok == true
              and stale.stale_count == 1)
      else
          check("stored_validator_available", false)
      end

      return report
  end

  -- 2.6.15: read-only validation for persisted state that lives outside the
  -- Rule Registry. This reports malformed/stale rows but never rewrites them.
  mod.exports.__beta26.storedStateAudit = function()
      local report = { ok = true, checked = 0, present = 0, failures = {}, warnings = {} }
      local function check(id, condition, present, detail, warning)
          report.checked = report.checked + 1
          if present then report.present = report.present + 1 end
          if condition then return end
          local text = tostring(id) .. (detail and (":" .. tostring(detail)) or "")
          if warning then
              report.warnings[#report.warnings + 1] = text
          else
              report.ok = false
              report.failures[#report.failures + 1] = text
          end
      end

      local historyKey = mod.exports.__beta26.RunHistory
          and mod.exports.__beta26.RunHistory.storage_key or "run_history_v1"
      local history = mod.save:get(historyKey, nil)
      if history ~= nil then
          check("history_root", type(history) == "table", true)
          if type(history) == "table" then
              local expectedHistoryVersion = mod.exports.__beta26.RunHistory
                  and mod.exports.__beta26.RunHistory.storage_version
              check("history_version",
                  tonumber(history.version) == tonumber(expectedHistoryVersion),
                  true, tostring(history.version))
              check("history_events", type(history.events) == "table", true)
              check("history_summary", type(history.summary) == "table", true)
              check("history_dedupe", type(history.dedupe) == "table", true)
              if type(mod.exports.__beta26.RunHistory) == "table"
                  and type(mod.exports.__beta26.RunHistory.dedupeIndexMatches)
                      == "function" then
                  local okDedupe, detail =
                      mod.exports.__beta26.RunHistory.dedupeIndexMatches(history)
                  check("history_dedupe_index", okDedupe == true, true,
                      tostring(detail or "ok"))
              else
                  check("history_dedupe_index", false, true, "helper_missing")
              end
              local maxSeq = 0
              if type(history.events) == "table" then
                  for _, event in ipairs(history.events) do
                      maxSeq = math.max(maxSeq, math.floor(tonumber(event and event.seq) or 0))
                  end
              end
              local nextSeq = tonumber(history.next_seq)
              check("history_next_seq", nextSeq ~= nil and nextSeq >= 1
                  and math.floor(nextSeq) == nextSeq and nextSeq > maxSeq,
                  true, tostring(history.next_seq))
              for key, value in pairs(type(history.summary) == "table" and history.summary or {}) do
                  check("history_summary_" .. tostring(key), tonumber(value) ~= nil
                      and tonumber(value) >= 0 and math.floor(tonumber(value)) == tonumber(value),
                      true, tostring(value))
              end
          end
      end

      local runSeedKey = type(mod.exports.__beta26.randomizerRunSeedKey) == "string"
          and mod.exports.__beta26.randomizerRunSeedKey
          or "__nuzlocke_randomizer_run_seed"
      local runSeed = mod.save:get(runSeedKey, nil)
      if runSeed ~= nil then
          local n = tonumber(runSeed)
          check("randomizer_run_seed", n ~= nil and n >= 1 and n <= 99999999
              and math.floor(n) == n, true, tostring(runSeed))
      end

      local runConfigKey = type(mod.exports.__beta26.randomizerRunConfigKey) == "string"
          and mod.exports.__beta26.randomizerRunConfigKey
          or "__nuzlocke_randomizer_run_config"
      local runConfig = mod.save:get(runConfigKey, nil)
      if runConfig ~= nil then
          local expectedSchema = tonumber(mod.exports.__beta26.randomizerRunConfigSchema) or 1
          check("randomizer_run_config", type(runConfig) == "table", true)
          if type(runConfig) == "table" then
              check("randomizer_run_config_schema", tonumber(runConfig.schema) == expectedSchema,
                  true, tostring(runConfig.schema))
              check("randomizer_run_config_algorithm", tonumber(runConfig.algorithm) ~= nil
                  and tonumber(runConfig.algorithm) >= 1, true, tostring(runConfig.algorithm))
              local snapshotSeed = tonumber(runConfig.seed)
              check("randomizer_run_config_seed", snapshotSeed ~= nil and snapshotSeed >= 1
                  and snapshotSeed <= 99999999 and math.floor(snapshotSeed) == snapshotSeed,
                  true, tostring(runConfig.seed))
              check("randomizer_run_config_game", type(runConfig.game) == "string"
                  and runConfig.game ~= "", true, tostring(runConfig.game))
              check("randomizer_run_config_settings", type(runConfig.settings) == "table", true)
          end
      end

      if type(mod.exports.__beta26.randomizerStreamRegistryAudit) == "function" then
          local ok, streamReport = pcall(mod.exports.__beta26.randomizerStreamRegistryAudit)
          local expectedStreams = type(mod.exports.__beta26.randomizerStreamNames) == "function"
              and #mod.exports.__beta26.randomizerStreamNames() or nil
          check("randomizer_stream_registry", ok and type(streamReport) == "table"
              and streamReport.ok == true and expectedStreams ~= nil
              and tonumber(streamReport.count) == expectedStreams, true,
              ok and ("count=" .. tostring(streamReport.count)
                  .. "/" .. tostring(expectedStreams) .. " "
                  .. table.concat(streamReport.failures or {}, ","))
                  or tostring(streamReport))
      else
          check("randomizer_stream_registry", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerStreamIsolationAudit) == "function" then
          local ok, isolation = pcall(mod.exports.__beta26.randomizerStreamIsolationAudit)
          check("randomizer_stream_isolation", ok and type(isolation) == "table"
              and isolation.ok == true and tonumber(isolation.checked) ==
                  ((type(mod.exports.__beta26.randomizerStreamNames) == "function"
                      and #mod.exports.__beta26.randomizerStreamNames() or 0) * 9), true,
              ok and table.concat(isolation.failures or {}, ",") or tostring(isolation))
      else
          check("randomizer_stream_isolation", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerSourceMapAudit) == "function" then
          local ok, sourceMaps = pcall(mod.exports.__beta26.randomizerSourceMapAudit)
          local expectedStreams = type(mod.exports.__beta26.randomizerStreamNames) == "function"
              and #mod.exports.__beta26.randomizerStreamNames() or nil
          check("randomizer_source_maps", ok and type(sourceMaps) == "table"
              and sourceMaps.ok == true and expectedStreams ~= nil
              and tonumber(sourceMaps.count) == expectedStreams, true,
              ok and ("count=" .. tostring(sourceMaps.count)
                  .. "/" .. tostring(expectedStreams) .. " "
                  .. table.concat(sourceMaps.failures or {}, ","))
                  or tostring(sourceMaps))
      else
          check("randomizer_source_maps", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerCandidatePolicyAudit) == "function" then
          local ok, policy = pcall(mod.exports.__beta26.randomizerCandidatePolicyAudit)
          check("randomizer_candidate_policy", ok and type(policy) == "table"
              and policy.ok == true and tonumber(policy.checked) == 8, true,
              ok and table.concat(policy.failures or {}, ",") or tostring(policy))
      else
          check("randomizer_candidate_policy", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerProjectionAudit) == "function" then
          local ok, projection = pcall(mod.exports.__beta26.randomizerProjectionAudit)
          local expectedProjectionCount = nil
          if type(mod.exports.__beta26.randomizerProjectionRegistry) == "function" then
              local okRegistry, registry = pcall(mod.exports.__beta26.randomizerProjectionRegistry)
              if okRegistry and type(registry) == "table" then
                  expectedProjectionCount = 0
                  for _ in pairs(registry) do expectedProjectionCount = expectedProjectionCount + 1 end
              end
          end
          check("randomizer_projection_ownership", ok and type(projection) == "table"
              and projection.ok == true and expectedProjectionCount ~= nil
              and tonumber(projection.count) == expectedProjectionCount, true,
              ok and ("count=" .. tostring(projection.count)
                  .. "/" .. tostring(expectedProjectionCount) .. " "
                  .. table.concat(projection.failures or {}, ","))
                  or tostring(projection))
      else
          check("randomizer_projection_ownership", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerConstraintDiagnosticAudit) == "function" then
          local ok, constraints = pcall(mod.exports.__beta26.randomizerConstraintDiagnosticAudit)
          check("randomizer_constraint_diagnostics", ok and type(constraints) == "table"
              and constraints.ok == true and tonumber(constraints.checked) == 2, true,
              ok and table.concat(constraints.failures or {}, ",") or tostring(constraints))
      else
          check("randomizer_constraint_diagnostics", false, false, "missing")
      end

      -- 2.9.10: TM_LOCATIONS is an independent Randomizer method even though
      -- it deliberately shares the physical pickup hook with FIELD_ITEMS.
      -- Require explicit DEV hook-health rows so session-key/wrapper drift is
      -- visible instead of being masked by the older Field Item diagnostic.
      do
          local hook = type(mod.exports.__beta26.Dev) == "table"
              and type(mod.exports.__beta26.Dev.hookHealth) == "function"
              and mod.exports.__beta26.Dev.hookHealth(mod.game) or nil
          local seen = false
          for _, row in ipairs(type(hook) == "table" and hook.rows or {}) do
              if tostring(row.id or ""):find("random_tm_locations", 1, true) then
                  seen = true
                  break
              end
          end
          check("randomizer_tm_locations_hook_health", seen, true,
              seen and "TM_LOCATIONS hook-health coverage present" or "missing")
      end

      if type(mod.exports.__beta26.randomizerCompatibilitySnapshot) == "function" then
          local ok, snapshot = pcall(
              mod.exports.__beta26.randomizerCompatibilitySnapshot, mod.game)
          local rows = ok and type(snapshot) == "table"
              and snapshot.rows or nil
          -- The compatibility snapshot is intentionally extensible: new
          -- Randomizer subsystems add rows. Validate the live shape rather
          -- than freezing an old mechanic count into player diagnostics.
          check("randomizer_external_compat",
              type(rows) == "table" and #rows > 0,
              true,
              ok and ("mechanics=" .. tostring(type(rows) == "table"
                  and #rows or 0)) or tostring(snapshot))
      else
          check("randomizer_external_compat", false, false, "missing")
      end

      do
          local api = mod.exports.nuzlocke_acquisition_provenance
          if type(api) == "table" and type(api.compatibilitySnapshot) == "function"
              and type(api.markImported) == "function" then
              local ok, snapshot = pcall(api.compatibilitySnapshot, mod.game)
              local rows = ok and type(snapshot) == "table" and snapshot.rows or nil
              check("stadium_import_compat",
                  type(rows) == "table"
                      and snapshot.acquisition_policy == "explicit_only"
                      and type(snapshot.edition) == "string",
                  true,
                  ok and ("edition=" .. tostring(snapshot.edition)
                      .. ",providers=" .. tostring(type(rows) == "table" and #rows or 0))
                      or tostring(snapshot))
          else
              check("stadium_import_compat", false, false, "missing")
          end
      end

      -- 2.9.16: Graveyard is a read-only projection. DEV reports structural
      -- health without creating tombstones, changing death state, or writing saves.
      if type(mod.exports.__beta26.graveyardHealth) == "function" then
          local ok, health = pcall(mod.exports.__beta26.graveyardHealth, mod.game)
          check("graveyard_viewer_health", ok and type(health) == "table"
              and health.read_only == true and health.ok == true, true,
              ok and ("fallen=" .. tostring(health.fallen or 0)
                  .. ",legacy=" .. tostring(health.legacy_recovered or 0)
                  .. ",duplicates=" .. tostring(health.duplicate_identities or 0))
                  or tostring(health))
      else
          check("graveyard_viewer_health", false, false, "missing")
      end

      -- 2.9.17: Almanac/Run Recap is likewise a read-only projection over
      -- persisted Run History v2 and recorded Randomizer metadata.
      if type(mod.exports.__beta26.almanacHealth) == "function" then
          local ok, health = pcall(mod.exports.__beta26.almanacHealth, mod.game)
          check("almanac_run_recap_health", ok and type(health) == "table"
              and health.read_only == true and health.ok == true, true,
              ok and ("available=" .. tostring(health.available == true)
                  .. ",partial=" .. tostring(health.partial == true)
                  .. ",events=" .. tostring(health.retained_events or 0))
                  or tostring(health))
      else
          check("almanac_run_recap_health", false, false, "missing")
      end

      -- 2.9.18: lifecycle UI is inert until explicit destructive confirmation.
      if type(mod.exports.__beta26.runLifecycleHealth) == "function" then
          local ok, health = pcall(mod.exports.__beta26.runLifecycleHealth, mod.game)
          check("end_run_lifecycle_health", ok and type(health) == "table"
              and health.ok == true
              and health.write_action == "explicit_confirmation_only", true,
              ok and ("active=" .. tostring(health.active == true)
                  .. ",completed=" .. tostring(health.completed == true)
                  .. ",abandoned=" .. tostring(health.abandoned == true))
                  or tostring(health))
      else
          check("end_run_lifecycle_health", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerFieldItemEditionAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerFieldItemEditionAudit)
          check("randomizer_field_item_editions",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) == 9,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_field_item_editions", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerFieldItemInfoAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerFieldItemInfoAudit, mod.game)
          check("randomizer_field_item_info_read_only",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) == 5,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_field_item_info_read_only", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerFieldItemPlacementAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerFieldItemPlacementAudit, mod.game)
          check("randomizer_field_item_placement",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) == 5,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_field_item_placement", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerFieldItemSemanticAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerFieldItemSemanticAudit, mod.game)
          check("randomizer_field_item_semantics",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) == 11,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_field_item_semantics", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerFieldItemFoundationAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerFieldItemFoundationAudit, mod.game)
          check("randomizer_field_item_foundation",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) == 7,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_field_item_foundation", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerEncounterSplitAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerEncounterSplitAudit, mod.game)
          check("randomizer_encounter_split_contract",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) == 3,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_encounter_split_contract", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerEncounterInfoAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerEncounterInfoAudit, mod.game)
          check("randomizer_encounter_info_read_only",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) == 4,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_encounter_info_read_only", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerEncounterIdentityAudit) == "function" then
          local ok, encounter = pcall(
              mod.exports.__beta26.randomizerEncounterIdentityAudit, mod.game)
          check("randomizer_encounter_identity", ok and type(encounter) == "table"
              and encounter.ok == true and tonumber(encounter.checked) == 3,
              true,
              ok and table.concat(encounter.failures or {}, ",") or tostring(encounter))
      else
          check("randomizer_encounter_identity", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerEncounterPolicyAudit) == "function" then
          local ok, policy = pcall(
              mod.exports.__beta26.randomizerEncounterPolicyAudit, mod.game)
          check("randomizer_encounter_policy", ok and type(policy) == "table"
              and policy.ok == true and tonumber(policy.checked) >= 5,
              true,
              ok and table.concat(policy.failures or {}, ",") or tostring(policy))
      else
          check("randomizer_encounter_policy", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerEncounterClassProtectionAudit) == "function" then
          local ok, audit = pcall(
              mod.exports.__beta26.randomizerEncounterClassProtectionAudit)
          check("randomizer_encounter_class_protection",
              ok and type(audit) == "table" and audit.ok == true
                  and tonumber(audit.checked) >= 17,
              true,
              ok and table.concat(audit.failures or {}, ",") or tostring(audit))
      else
          check("randomizer_encounter_class_protection", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerStarterPositionAudit) == "function" then
          local ok, position = pcall(mod.exports.__beta26.randomizerStarterPositionAudit,
              mod.game)
          check("randomizer_starter_positions", ok and type(position) == "table"
              and position.ok == true, true,
              ok and table.concat(position.failures or {}, ",") or tostring(position))
      else
          check("randomizer_starter_positions", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerStarterLineageAudit) == "function" then
          local ok, lineage = pcall(mod.exports.__beta26.randomizerStarterLineageAudit,
              mod.game)
          check("randomizer_starter_lineage", ok and type(lineage) == "table"
              and lineage.ok == true, true,
              ok and table.concat(lineage.failures or {}, ",") or tostring(lineage))
      else
          check("randomizer_starter_lineage", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerStarterPreferenceAudit) == "function" then
          local ok, preference = pcall(mod.exports.__beta26.randomizerStarterPreferenceAudit,
              mod.game)
          check("randomizer_starter_preferences", ok and type(preference) == "table"
              and preference.ok == true and tonumber(preference.checked) == 3, true,
              ok and table.concat(preference.failures or {}, ",") or tostring(preference))
      else
          check("randomizer_starter_preferences", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerItemEconomyRegressionAudit) == "function" then
          local okH, reportH = pcall(mod.exports.__beta26.randomizerItemEconomyRegressionAudit, mod.game)
          check("randomizer_phase_h_economy_progression", okH and type(reportH)=="table" and reportH.ok==true, true,
              okH and type(reportH)=="table" and table.concat(reportH.failures or {}, ",") or tostring(reportH))
      else
          check("randomizer_phase_h_economy_progression", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerStarterInfo) == "function" then
          local before = type(mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics() or 0
          local okA, a = pcall(mod.exports.__beta26.randomizerStarterInfo, mod.game, false)
          local middle = type(mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics() or 0
          local okB, b = pcall(mod.exports.__beta26.randomizerStarterInfo, mod.game, false)
          local after = type(mod.exports.__beta26.randomizerConstraintDiagnostics) == "function"
              and #mod.exports.__beta26.randomizerConstraintDiagnostics() or 0
          check("randomizer_starter_info_read_only",
              okA and okB and type(a) == "table" and type(b) == "table"
                  and before == middle and middle == after
                  and tonumber(a.rerollIndex) == tonumber(b.rerollIndex)
                  and tonumber(a.starterSlateVersion) == tonumber(b.starterSlateVersion),
              true, tostring(before) .. "/" .. tostring(middle) .. "/" .. tostring(after))
      else
          check("randomizer_starter_info_read_only", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerYellowStarterDependencyAudit) == "function" then
          local ok, yellow = pcall(mod.exports.__beta26.randomizerYellowStarterDependencyAudit,
              mod.game)
          check("randomizer_yellow_starter_dependencies",
              ok and type(yellow) == "table" and yellow.ok == true,
              true, ok and table.concat(yellow.failures or {}, ",") or tostring(yellow))
      else
          check("randomizer_yellow_starter_dependencies", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerRivalSyncAudit) == "function" then
          local ok, rival = pcall(mod.exports.__beta26.randomizerRivalSyncAudit)
          check("randomizer_rival_sync", ok and type(rival) == "table"
              and rival.ok == true and tonumber(rival.checked) == 2, true,
              ok and table.concat(rival.failures or {}, ",") or tostring(rival))
      else
          check("randomizer_rival_sync", false, false, "missing")
      end

      local choices = mod.save:get("__nuzlocke_random_starter_choices", nil)
      if choices ~= nil then
          check("random_starter_choices", type(choices) == "table", true)
          if type(choices) == "table" then
              for key, value in pairs(choices) do
                  check("random_starter_choice_" .. tostring(key),
                      type(key) == "string" and type(value) == "string"
                          and value ~= "", true, tostring(value))
              end
          end
      end

      for _, scope in ipairs({ "gen1", "gold", "silver", "crystal" }) do
          local profile = mod.save:get("__nuzlocke_staged_new_game_profile:" .. scope, nil)
          if profile ~= nil then
              check("staged_profile_" .. scope, type(profile) == "table", true)
              if type(profile) == "table" then
                  local registry = mod.exports.__beta26.ruleRegistry
                  if type(registry) == "table" and type(registry.validateStored) == "function" then
                      local ok, profileReport = pcall(registry.validateStored, profile)
                      check("staged_profile_rules_" .. scope, ok and type(profileReport) == "table"
                          and (tonumber(profileReport.invalid_count) or 0) == 0, true,
                          ok and table.concat(profileReport.errors or {}, ",") or tostring(profileReport),
                          ok and type(profileReport) == "table"
                              and (tonumber(profileReport.stale_count) or 0) > 0)
                  end
              end
          end
      end
      return report
  end

  mod.exports.__beta26.Dev.assertions = function(game)
      game = game or deps.currentGame() or mod.game
      local warnings = {}
      local function warn(code, detail)
          warnings[#warnings + 1] = { code = code, detail = detail }
      end
  
      local schema = tonumber(mod.save:get(deps.SAVE_SCHEMA_KEY, deps.CURRENT_SAVE_SCHEMA))
      if schema ~= deps.CURRENT_SAVE_SCHEMA then
          warn("save_schema", "expected " .. tostring(deps.CURRENT_SAVE_SCHEMA)
              .. ", got " .. tostring(schema))
      end
      if deps.saveSchemaTooNew() then warn("save_schema_too_new", "newer save schema loaded") end
      if deps.saveMigrationError() then warn("save_migration", tostring(deps.saveMigrationError())) end

      local descParity = mod.exports.__beta26.gen2DescriptionParityAudit
      if type(descParity) == "function" then
          local okDesc, descReport = pcall(descParity)
          if not okDesc or type(descReport) ~= "table" or descReport.ok ~= true then
              local detail = not okDesc and tostring(descReport)
                  or table.concat(descReport and descReport.failures or {}, ", ")
              warn("gen2_description_parity", detail ~= "" and detail or "audit failed")
          end
      end

      local editionParity = mod.exports.__beta26.Dev
          and mod.exports.__beta26.Dev.gen2EditionParityAudit
      if type(editionParity) == "function"
          and mod.exports.__beta26.runtimeIsGen2(game) then
          local okEdition, editionReport = pcall(editionParity, game)
          if not okEdition or type(editionReport) ~= "table"
              or editionReport.ok ~= true then
              local detail = not okEdition and tostring(editionReport)
                  or table.concat(editionReport and editionReport.failures or {}, ", ")
              warn("gen2_edition_identity", detail ~= "" and detail or "audit failed")
          end
      end

      local helperAudit = mod.exports.__beta26.pureHelperAudit
      if type(helperAudit) == "function" then
          local okHelpers, helperReport = pcall(helperAudit)
          if not okHelpers or type(helperReport) ~= "table" or helperReport.ok ~= true then
              local detail = not okHelpers and tostring(helperReport)
                  or table.concat(helperReport and helperReport.failures or {}, ", ")
              warn("pure_helper_contract", detail ~= "" and detail or "audit failed")
          end
      end

      local storedStateAudit = mod.exports.__beta26.storedStateAudit
      if type(storedStateAudit) == "function" then
          local okState, stateReport = pcall(storedStateAudit)
          if not okState or type(stateReport) ~= "table" or stateReport.ok ~= true then
              local detail = not okState and tostring(stateReport)
                  or table.concat(stateReport and stateReport.failures or {}, ", ")
              warn("stored_state_validation", detail ~= "" and detail or "audit failed")
          end
      end

      local registry = mod.exports.__beta26.ruleRegistry
      if type(registry) == "table" and type(registry.validateStored) == "function" then
          local okStored, storedReport = pcall(registry.validateStored)
          if not okStored then
              warn("stored_rule_validation", tostring(storedReport))
          elseif type(storedReport) == "table"
              and ((tonumber(storedReport.invalid_count) or 0) > 0
                  or (tonumber(storedReport.stale_count) or 0) > 0) then
              local parts = {}
              for _, item in ipairs(storedReport.errors or {}) do parts[#parts + 1] = item end
              for _, item in ipairs(storedReport.warnings or {}) do parts[#parts + 1] = item end
              warn("stored_rule_validation", table.concat(parts, ", "))
          end
      end
  
      -- 2.5.73: the chronology journal is intentionally flat/bounded.  Keep
      -- those invariants executable so future Graveyard/Almanac/Confessional
      -- work cannot accidentally persist engine objects or corrupt ordering.
      local runHistoryAudit = mod.exports.__beta26.RunHistory
          and mod.exports.__beta26.RunHistory.audit
      if type(runHistoryAudit) == "function" then
          local okHistory, historyReport = pcall(runHistoryAudit)
          if not okHistory or type(historyReport) ~= "table"
              or historyReport.ok ~= true then
              local detail = not okHistory and tostring(historyReport)
                  or table.concat(historyReport and historyReport.failures or {}, ", ")
              warn("run_history_integrity", detail ~= "" and detail or "audit failed")
          end
      end
  
      local function safeDiagnosticSource(path)
          local okRead, source = pcall(mod.read, mod, path)
          if okRead and type(source) == "string" then return source end
          return nil
      end

      -- 2.9.38: surface the generated save-reference index without making
      -- package-source introspection a runtime dependency. Missing source,
      -- dynamic references and detail truncation are bounded diagnostics only.
      local saveReferenceIndex = mod.exports.__beta26.saveReferenceConsumerIndex
      if type(saveReferenceIndex) == "function" then
          local okIndex, index = pcall(saveReferenceIndex)
          if not okIndex or type(index) ~= "table" then
              warn("save_reference_index", "index error: " .. tostring(index))
          else
              if index.complete ~= true or index.truncated == true then
                  warn("save_reference_index",
                      "status=" .. tostring(index.status)
                          .. " unreadable=" .. tostring(index.unreadable_count or 0)
                          .. " dynamic=" .. tostring(index.dynamic_reference_count or 0)
                          .. " truncated=" .. tostring(index.truncated == true))
              end
              local undescribed = index.undescribed_literal_keys or {}
              if #undescribed > 0 then
                  local sample = {}
                  for i = 1, math.min(8, #undescribed) do sample[#sample + 1] = undescribed[i] end
                  warn("save_reference_undescribed",
                      "count=" .. tostring(#undescribed) .. " sample=" .. table.concat(sample, ","))
              end
          end
      end

      -- 2.5.57: the trainer-reward subsystem carries executable source-level
      -- contracts for every gameplay-state mutator plus explicit OFF-state
      -- exceptions. Surface any drift in DEV assertions as well as failing
      -- module installation, so the regression is visible in diagnostics.
      local rewardModule = mod.exports.__beta26.TrainerRewards
      if type(rewardModule) == "table"
          and type(rewardModule.activeGuardAudit) == "function" then
          local rewardSource = safeDiagnosticSource("trainer_rewards.lua")
          local okGuard, guardReport = true, nil
          if rewardSource then
              okGuard, guardReport = pcall(rewardModule.activeGuardAudit, rewardSource)
          end
          if rewardSource and (not okGuard or type(guardReport) ~= "table" or guardReport.ok ~= true) then
              local detail = not okGuard and tostring(guardReport)
                  or table.concat(guardReport and guardReport.failures or {}, ", ")
              warn("active_guard_contract", detail ~= "" and detail or "audit failed")
          end
      end
  
      -- 2.5.58: mirror the module-load cross-table invariant gate in DEV
      -- diagnostics. Static drift should already fail fast at startup, but the
      -- report makes the exact relationship visible during development too.
      local invariantAudit = mod.exports.__beta26.crossTableInvariantAudit
      if type(invariantAudit) == "function" then
          local okInvariant, invariantReport = pcall(invariantAudit)
          if not okInvariant or type(invariantReport) ~= "table"
              or invariantReport.ok ~= true then
              local detail = not okInvariant and tostring(invariantReport)
                  or table.concat(invariantReport and invariantReport.failures or {}, ", ")
              warn("cross_table_invariant", detail ~= "" and detail or "audit failed")
          end
      end
  
      -- 2.5.59 / 2.7.60: repeat the dead-fallback source lint in DEV
      -- diagnostics. Presentation/source drift is diagnostic at startup and
      -- promotion-blocking in Release Safety, not a reason to brick loading.
      local deadFallbackAudit = mod.exports.__beta26.deadFallbackAudit
      if type(deadFallbackAudit) == "function" then
          local mainSource = safeDiagnosticSource("main.lua")
          local worldSource = safeDiagnosticSource("world_building.lua")
          local combinedSource = mainSource
          if combinedSource and worldSource then
              combinedSource = combinedSource .. "\n" .. worldSource
          end
          local okFallback, fallbackReport = true, nil
          if combinedSource then
              okFallback, fallbackReport = pcall(deadFallbackAudit, combinedSource)
          end
          if combinedSource and (not okFallback or type(fallbackReport) ~= "table"
              or fallbackReport.ok ~= true) then
              local detail = not okFallback and tostring(fallbackReport)
                  or table.concat(fallbackReport and fallbackReport.failures or {}, ", ")
              warn("dead_fallback_lint", detail ~= "" and detail or "audit failed")
          end
      end
  
      -- 2.5.60: catalog golden/snapshot backstop. This semantic snapshot
      -- covers every catalog row across the three presentation tiers and both
      -- supported regions without depending on source whitespace or comments.
      local catalogSnapshotAudit = mod.exports.__beta26.catalogSnapshotAudit
      if type(catalogSnapshotAudit) == "function" then
          local okSnapshot, snapshotReport = pcall(catalogSnapshotAudit)
          if not okSnapshot or type(snapshotReport) ~= "table"
              or snapshotReport.ok ~= true then
              local detail = not okSnapshot and tostring(snapshotReport)
                  or table.concat(snapshotReport and snapshotReport.failures or {}, ", ")
              warn("catalog_snapshot", detail ~= "" and detail or "audit failed")
          end
      end
  

      local maximumBstMessageDetailAudit =
          mod.exports.__beta26.maximumBstMessageDetailAudit
      if type(maximumBstMessageDetailAudit) == "function" then
          local worldSource = safeDiagnosticSource("world_building.lua")
          if worldSource then
              local okDetail, detailReport = pcall(
                  maximumBstMessageDetailAudit, worldSource)
              if not okDetail or type(detailReport) ~= "table"
                  or detailReport.ok ~= true then
                  local detail = not okDetail and tostring(detailReport)
                      or table.concat(detailReport and detailReport.failures or {}, ", ")
                  warn("maximum_bst_message_detail",
                      detail ~= "" and detail or "audit failed")
              end
          end
      end

      local safeStopWrites = mod.exports.__beta26.safeStopWriteReport()
      if tonumber(safeStopWrites.total or 0) > 0 then
          warn("safe_stop_write_attempt",
              "count=" .. tostring(safeStopWrites.total)
                  .. " first=" .. tostring(safeStopWrites.first_key or "?")
                  .. " last=" .. tostring(safeStopWrites.last_key or "?"))
      end
  
      local save = game and game.save
      local party = save and save.party or {}
      local limit = math.max(1, math.min(6, math.floor(tonumber(
          mod.save:get("party_size_limit", deps.defaultRuleValue("party_size_limit"))) or 6)))
      if mod.save:get("nuzlocke_enabled", true) == true and #party > limit then
          warn("party_over_cap", tostring(#party) .. "/" .. tostring(limit))
      end
      for i, mon in ipairs(party) do
          if type(mon) == "table" and mon.nuzlockeDead == true
              and (tonumber(mon.hp) or 0) > 0 then
              warn("dead_hp", "slot " .. tostring(i) .. " hp=" .. tostring(mon.hp))
          end
          if type(mon) == "table" and mon.nuzlockePcLocked == true then
              warn("pc_lock_in_party", "slot " .. tostring(i) .. " "
                  .. tostring(mon.species or "UNKNOWN"))
          end
          if type(mon) == "table" and mon.nuzlockeOrigin == "EDITED" then
              warn("external_mon", "slot " .. tostring(i) .. " "
                  .. tostring(mon.species or "UNKNOWN"))
          end
      end
  
      -- 2.4.59: passive integrity checks for encounter/shiny state. These are
      -- read-only and deliberately avoid treating legal rule changes (for
      -- example lowering a spent Shiny allowance mid-run) as corruption.
      if mod.save:get("encounter_limit", deps.defaultRuleValue("encounter_limit")) == true then
          local caught = mod.save:get("caught_areas", {})
          local states = mod.save:get("encounter_states", {})
          if type(caught) ~= "table" then
              warn("caught_areas_type", "expected table, got " .. type(caught))
              caught = {}
          end
          if type(states) ~= "table" then
              warn("encounter_states_type", "expected table, got " .. type(states))
              states = {}
          end
          for key, state in pairs(states) do
              if type(state) == "table" and state.status == "CAUGHT"
                  and state.consumedArea ~= false and caught[key] == nil then
                  warn("encounter_state_area_mismatch",
                      tostring(key) .. " state=CAUGHT caught_areas=missing")
              elseif type(state) == "table" and state.status == "FAILED"
                  and caught[key] ~= nil then
                  warn("encounter_state_area_conflict",
                      tostring(key) .. " state=FAILED caught_areas=present")
              end
          end
      end
  
      local rawShinyMode = mod.save:get("shiny_clause", nil)
      if rawShinyMode ~= nil then
          if type(rawShinyMode) == "boolean" then
              warn("shiny_clause_mode_boolean", tostring(rawShinyMode))
          else
              local numericMode = tonumber(rawShinyMode)
              if numericMode == nil or numericMode < 0 or numericMode > 4
                  or math.floor(numericMode) ~= numericMode then
                  warn("shiny_clause_mode_invalid", tostring(rawShinyMode))
              end
          end
      end
      local rawBallLimit = mod.save:get("encounter_ball_limit", nil)
      if rawBallLimit ~= nil then
          if type(rawBallLimit) == "boolean" then
              warn("encounter_ball_limit_boolean", tostring(rawBallLimit))
          else
              local numericBallLimit = tonumber(rawBallLimit)
              if numericBallLimit == nil or numericBallLimit < 0
                  or numericBallLimit > 5
                  or math.floor(numericBallLimit) ~= numericBallLimit then
                  warn("encounter_ball_limit_invalid", tostring(rawBallLimit))
              end
          end
      end
      -- 2.5.2 diagnostic-only hardening. randomizer_info_policy has always
      -- had a numeric setter, so there is no legitimate historical boolean
      -- encoding to migrate. If an imported/hand-edited/corrupt save contains
      -- one, report it rather than silently inventing semantics for true/false.
      local rawInfoPolicy = mod.save:get("randomizer_info_policy", nil)
      if rawInfoPolicy ~= nil then
          if type(rawInfoPolicy) == "boolean" then
              warn("randomizer_info_policy_boolean", tostring(rawInfoPolicy))
          else
              local numericInfoPolicy = tonumber(rawInfoPolicy)
              if numericInfoPolicy == nil or numericInfoPolicy < 0
                  or numericInfoPolicy > 1
                  or math.floor(numericInfoPolicy) ~= numericInfoPolicy then
                  warn("randomizer_info_policy_invalid",
                      tostring(rawInfoPolicy))
              end
          end
      end
      local rawShinyUsed = mod.save:get("shiny_clause_used", nil)
      if rawShinyUsed ~= nil then
          local numericUsed = tonumber(rawShinyUsed)
          if numericUsed == nil or numericUsed < 0
              or math.floor(numericUsed) ~= numericUsed then
              warn("shiny_clause_used_invalid", tostring(rawShinyUsed))
          end
      end
  
      local okDefaults, badDefault = pcall(mod.exports.__beta26.auditNewRuleDefaults)
      if not okDefaults then
          warn("default_audit_error", tostring(badDefault))
      elseif badDefault ~= true then
          warn("default_audit", tostring(badDefault))
      end
      return warnings
  end


  -- 2.9.46: read-only extended diagnostics moved from main.lua with explicit
  -- dependency ownership. Mutable game identity stays behind a live getter.
  mod.exports.__beta26.Dev.ruleEffectiveness = function(game)
      game = game or deps.currentGame() or mod.game
      local identity = mod.exports.__beta26.Dev.editionContext(game)
      local gen2 = identity.generation == 2
      local rows = {}
      local counts = { total=0, delegated=0, changed=0, errors=0 }

      local function sameValue(a, b)
          if type(a) == "number" or type(b) == "number" then
              local na, nb = tonumber(a), tonumber(b)
              if na ~= nil and nb ~= nil then return na == nb end
          end
          return a == b
      end

      for _, category in ipairs(deps.ruleCategories or {}) do
          for _, rule in ipairs(category.rules or {}) do
              local applies = not ((rule.gen2Only == true or rule.goldOnly == true) and not gen2)
                  and not (rule.rbyOnly == true and gen2)
              if applies and type(rule.key) == "string" and rule.key ~= "" then
                  local key = rule.key
                  local raw = mod.save:get(key, nil)
                  local configured = raw
                  local source = "save"
                  if configured == nil then
                      configured = deps.defaultRuleValue(key)
                      source = "default"
                  end

                  local okEffective, effective = pcall(deps.getConfigValue, key, false)
                  local okOwner, delegated = pcall(
                      deps.externalRuleDelegation, key, game)
                  local row = {
                      key = key,
                      category = tostring(category.title or ""),
                      configured = configured,
                      configured_source = source,
                      effective = okEffective and effective or nil,
                      owner = "nuzlocke",
                      relationship = "owned",
                      delegated = false,
                  }

                  if not okEffective then
                      row.error = "effective: " .. tostring(effective)
                      counts.errors = counts.errors + 1
                  end
                  if not okOwner then
                      row.error = (row.error and (row.error .. "; ") or "")
                          .. "owner: " .. tostring(delegated)
                      counts.errors = counts.errors + 1
                  elseif type(delegated) == "table" then
                      row.delegated = true
                      row.owner = tostring(delegated.name or delegated.id
                          or "external")
                      row.owner_id = tostring(delegated.id
                          or delegated.name or "external")
                      row.relationship = tostring(
                          delegated.relationship or delegated.capability
                              or "delegated")
                      row.capability = delegated.capability
                      counts.delegated = counts.delegated + 1
                  end

                  if okEffective and not sameValue(configured, effective) then
                      row.changed = true
                      counts.changed = counts.changed + 1
                  else
                      row.changed = false
                  end
                  counts.total = counts.total + 1
                  rows[#rows + 1] = row
              end
          end
      end

      table.sort(rows, function(a, b)
          return tostring(a.key) < tostring(b.key)
      end)
      return {
          game = identity.edition,
          edition = identity.edition,
          engine_family = identity.engine_family,
          profile_scope = identity.profile_scope,
          generation = identity.generation,
          nuzlocke_enabled = mod.save:get("nuzlocke_enabled", true) == true,
          schema_supported = mod.exports.__beta26.saveSchemaSupported(),
          counts = counts,
          rows = rows,
      }
  end

  ---------------------------------------------------------------------
  -- 2.4.68 DEV RANDOMIZER INTEGRITY AUDIT
  --
  -- Read-only scan of the currently applied Nuzlocke-owned wild encounter
  -- registry. The audit reuses the same legality dimensions as speciesPool():
  -- generation mode, glitch/runtime safety, and specialAcquisitionDenied().
  -- Externally delegated encounter randomizers and content-opted-out slots are
  -- intentionally not judged as Nuzlocke-owned output.
  ---------------------------------------------------------------------
  mod.exports.__beta26.Dev.randomizerIntegrity = function(game)
      game = game or deps.currentGame() or mod.game
      local identity = mod.exports.__beta26.Dev.editionContext(game)
      local result = {
          game = identity.edition,
          edition = identity.edition,
          generation = identity.generation,
          engine_family = identity.engine_family,
          profile_scope = identity.profile_scope,
          active = mod.save:get("random_encounter_tables", false) == true,
          delegated = false,
          status = "INACTIVE",
          scanned = 0,
          violations = {},
          violation_count = 0,
          truncated = false,
      }

      if not result.active then return result end
      if not mod.exports.__beta26.saveSchemaSupported() then
          result.status = "PAUSED"
          result.detail = "newer save schema"
          return result
      end

      local okOwner, owner = pcall(deps.externalRuleDelegation,
          "random_encounter_tables", game)
      if not okOwner then
          result.status = "ERROR"
          result.detail = "delegation: " .. tostring(owner)
          return result
      end
      if type(owner) == "table" then
          result.delegated = true
          result.status = "DELEGATED"
          result.owner = tostring(owner.name or owner.id or "external")
          result.relationship = tostring(owner.relationship
              or owner.capability or "delegated")
          return result
      end

      local registry = game and game.data and (
          mod.exports.__beta26.runtimeIsGen2(game)
              and (game.data.gen2Encounters or game.data.encounters)
              or game.data.encounters)
      if type(registry) ~= "table" then
          result.status = "UNAVAILABLE"
          result.detail = "encounter registry unavailable"
          return result
      end

      local pokemon = game.data and game.data.pokemon or {}
      local mode = type(mod.exports.__beta26.effectiveRandomSpeciesGeneration)
          == "function"
          and mod.exports.__beta26.effectiveRandomSpeciesGeneration() or 0

      -- 2.4.62 intentionally restores/leaves vanilla encounters when no legal
      -- randomized species exist. Do not scan that deliberate fallback as if it
      -- were Nuzlocke-owned randomized output.
      local candidateCount = 0
      for id, def in pairs(pokemon) do
          local species = tostring(id or ""):upper()
          local glitch = mod.exports.__beta26.getGlitchSpeciesInfo(game, species)
          if species ~= "" and species ~= "EGG" and species ~= "NONE"
              and type(def) == "table" and not (glitch and glitch.isGlitch)
              and mod.exports.__beta26.randomSpeciesPoolAllows(def, mode)
              and mod.exports.__beta26.randomEncounterRuntimeSafe(game, species, 5)
              and (type(specialAcquisitionDenied) ~= "function"
                  or specialAcquisitionDenied(
                      game, species, nil, "random_encounter") == nil) then
              candidateCount = candidateCount + 1
          end
      end
      result.candidate_count = candidateCount
      if candidateCount == 0 then
          result.status = "FALLBACK"
          result.detail = "legal species pool empty; vanilla encounters retained"
          return result
      end

      local seen = setmetatable({}, { __mode = "k" })
      local maxRows = 64

      local function addViolation(path, species, reason)
          result.violation_count = result.violation_count + 1
          if #result.violations < maxRows then
              result.violations[#result.violations + 1] = {
                  path = tostring(path),
                  species = tostring(species),
                  reason = tostring(reason),
              }
          else
              result.truncated = true
          end
      end

      local function contentAllows(node, path)
          local content = mod.exports.nuzlocke
              and mod.exports.nuzlocke.content
          if not (content and type(content.shouldRandomizeEncounter)
              == "function") then return true end
          local ok, permitted = pcall(content.shouldRandomizeEncounter, {
              id = node.nuzlockeSourceId or node.sourceId,
              sourceId = node.nuzlockeSourceId or node.sourceId,
              mapId = node.mapId or node.areaId,
              species = node.species,
              randomizable = node.nuzlockeRandomizable ~= nil
                  and node.nuzlockeRandomizable or node.randomizable,
              path = path,
          })
          return not ok or permitted ~= false
      end

      local function checkNode(node, path)
          if type(node) ~= "table" or seen[node] then return end
          seen[node] = true

          if type(node.species) == "string" and contentAllows(node, path) then
              local species = tostring(node.species or ""):upper()
              result.scanned = result.scanned + 1
              local def = pokemon[species]
              local reason
              if species == "" or species == "EGG" or species == "NONE"
                  or type(def) ~= "table" then
                  reason = "invalid_species"
              else
                  local glitch = mod.exports.__beta26.getGlitchSpeciesInfo(
                      game, species)
                  if glitch and glitch.isGlitch then
                      reason = "glitch_species"
                  elseif not mod.exports.__beta26.randomSpeciesPoolAllows(
                      def, mode) then
                      reason = "generation_mode"
                  elseif not mod.exports.__beta26.randomEncounterRuntimeSafe(
                      game, species, 5) then
                      reason = "runtime_unsafe"
                  elseif type(specialAcquisitionDenied) == "function" then
                      local denied = specialAcquisitionDenied(
                          game, species, nil, "random_encounter")
                      if denied ~= nil then
                          reason = "nuzlocke_legality:" .. tostring(denied)
                      end
                  end
              end
              if reason then addViolation(path .. ".species", species, reason) end
          end

          local keys = {}
          for key, value in pairs(node) do
              if type(value) == "table" then keys[#keys + 1] = key end
          end
          table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
          for _, key in ipairs(keys) do
              checkNode(node[key], path .. "." .. tostring(key))
          end
      end

      checkNode(registry, "encounters")
      table.sort(result.violations, function(a, b)
          if a.path == b.path then return a.species < b.species end
          return a.path < b.path
      end)
      result.status = result.violation_count == 0 and "PASS" or "WARN"
      result.mode = mode
      return result
  end

  ---------------------------------------------------------------------
  -- 2.4.64 DEV HOOK / ADAPTER HEALTH
  --
  -- Read-only. Never require/import a module merely to inspect it: doing so
  -- would change boot order and could make diagnostics install what they test.
  -- Only modules already present in package.loaded are inspected.
  --
  -- HEALTHY = our recorded wrapper is the live top-level function.
  -- CHAINED = our marker/wrapper exists, but the live top-level differs.
  --           Another mod may legitimately be composing above us, so this is
  --           evidence to inspect rather than an automatic failure.
  -- MISSING = a relevant module is loaded but our expected marker is absent.
  -- PENDING = the relevant module has not loaded yet; never a failure.
  ---------------------------------------------------------------------
  mod.exports.__beta26.Dev.gen2EditionParityAudit = function(game, hookHealth)
      game = game or deps.currentGame() or mod.game
      local identity = mod.exports.__beta26.Dev.editionContext(game)
      local report = {
          ok = true,
          applies = identity.generation == 2,
          edition = identity.edition,
          generation = identity.generation,
          engine_family = identity.engine_family,
          profile_scope = identity.profile_scope,
          checked_rows = 0,
          failures = {},
      }
      if not report.applies then return report end

      local function fail(text)
          report.ok = false
          report.failures[#report.failures + 1] = tostring(text)
      end
      if mod.exports.__beta26.runtimeIsGen2(game) ~= true then
          fail("exact Gold/Silver/Crystal runtime did not resolve through shared Gen 2 predicate")
      end
      local installAttempts = mod.exports.__beta26.installHealth
          and mod.exports.__beta26.installHealth.attempts or {}
      for _, adapter in ipairs({ "gen2.gift_tracking", "gen2.capture_gate" }) do
          local row = installAttempts[adapter]
          if type(row) ~= "table" or row.ok ~= true then
              fail(adapter .. ": shared Gen 2 adapter not installed")
          end
      end
      if identity.edition ~= "gold" and identity.edition ~= "silver"
          and identity.edition ~= "crystal" then
          fail("supported Gen 2 runtime must identify as gold, silver, or crystal")
      end
      if identity.engine_family ~= "gen2" or identity.generation ~= 2 then
          fail("Gen 2 family metadata mismatch")
      end
      if identity.edition == "gold" or identity.edition == "silver" or identity.edition == "crystal" then
          if identity.profile_scope ~= identity.edition then
              fail("profile scope does not match exact edition")
          end
      end

      hookHealth = type(hookHealth) == "table" and hookHealth
          or mod.exports.__beta26.Dev.hookHealth(game)
      if type(hookHealth) ~= "table" then
          fail("hook health unavailable")
          return report
      end
      for _, field in ipairs({ "edition", "generation", "engine_family",
          "profile_scope" }) do
          if hookHealth[field] ~= identity[field] then
              fail("hook health " .. field .. " mismatch")
          end
      end
      for _, row in ipairs(hookHealth.rows or {}) do
          if row.generation == "gen2" then
              report.checked_rows = report.checked_rows + 1
              if row.edition ~= identity.edition then
                  fail(tostring(row.id or "?") .. ": edition mismatch")
              end
              if row.engine_family ~= "gen2" then
                  fail(tostring(row.id or "?") .. ": engine family mismatch")
              end
              if row.profile_scope ~= identity.profile_scope then
                  fail(tostring(row.id or "?") .. ": profile scope mismatch")
              end
              if type(row.adapter_id) ~= "string" or row.adapter_id == ""
                  or row.adapter_id:find("_gold", 1, true) then
                  fail(tostring(row.id or "?") .. ": semantic adapter id missing")
              end
          end
      end

      report.national_dex_limit = type(mod.exports.__beta26.nationalDexLimitForGame)
          == "function" and mod.exports.__beta26.nationalDexLimitForGame(game) or 0
      if report.national_dex_limit ~= 251 then
          fail("Gen 2 PKMN BAN National Dex limit is not 251")
      end
      if type(mod.exports.__beta26.speciesBanRows) == "function" then
          local okRows, speciesRows = pcall(mod.exports.__beta26.speciesBanRows, game)
          report.species_ban_rows = okRows and type(speciesRows) == "table"
              and #speciesRows or 0
          if report.species_ban_rows ~= 251 then
              fail("Gen 2 PKMN BAN selector does not expose 251 rows")
          end
      end

      local reach = mod.exports.__beta26.gen2AdapterReach
      if type(reach) == "table" then
          report.adapter_reach = { counts = {}, last = {} }
          for key, value in pairs(reach.counts or {}) do
              report.adapter_reach.counts[key] = value
          end
          for key, value in pairs(reach.last or {}) do
              report.adapter_reach.last[key] = value
          end
      end

      local starterHealthFn = mod.exports.__beta26.gen2RandomStarterTransactionHealth
          or mod.exports.__beta26.goldRandomStarterTransactionHealth
      local starterHealth = type(starterHealthFn) == "function"
          and starterHealthFn(game) or nil
      if type(starterHealth) == "table" and starterHealth.state ~= "N/A" then
          if starterHealth.edition ~= identity.edition then
              fail("Random Starter health edition mismatch")
          end
          if starterHealth.engine_family ~= "gen2"
              or starterHealth.generation ~= 2 then
              fail("Random Starter health family mismatch")
          end
          if starterHealth.profile_scope ~= identity.profile_scope then
              fail("Random Starter health profile mismatch")
          end
          if starterHealth.adapter_id ~= "random_starter_transaction_gen2" then
              fail("Random Starter semantic adapter id missing")
          end
      end
      return report
  end

  mod.exports.__beta26.Dev.storageContext = function(game)
      game = game or deps.currentGame() or mod.game
      local storage = mod and mod.storage
      if type(storage) ~= "table" or type(storage.context) ~= "function" then
          return nil, "storage_unavailable",
              "Gen1Recomp mod.storage is unavailable in this runtime."
      end
      local ok, context, code, message = pcall(storage.context, storage, game)
      if not ok then
          return nil, "storage_error", tostring(context)
      end
      if type(context) ~= "table" then
          return nil, tostring(code or "storage_unavailable"),
              tostring(message or "No active playthrough storage context.")
      end
      return context
  end

  -- 2.9.48: remaining live/read-only Dev diagnostics moved from main.lua.
  -- Mutable runtime game selection is resolved through deps.currentGame on every call;
  -- configuration helpers are injected explicitly. No gameplay authority is owned here.
  mod.exports.__beta26.Dev.hookHealth = function(game)
      game = game or deps.currentGame() or mod.game
      local identity = mod.exports.__beta26.Dev.editionContext(game)
      local gen2 = identity.generation == 2
      local rows = {}
      local descriptors = {
          { id="item_rules", path="src.inventory.ItemEffects", method="use",
            owner="__nuzlockeItemRuleGateOwner",
            wrapper="__nuzlockeItemRuleGateFunction", generation="all" },
          { id="shop_rules", path="src.ui.ShopMenu", method="new",
            session="__nuzlockeShopRuleGateSession", generation="rby" },
          { id="title_setup_gold", path="src.ui.gen2.MainMenu", method="choose",
            owner="__nuzlockeTitleSetupOwner",
            wrapper="__nuzlockeTitleSetupFunction", generation="gen2" },
          { id="title_setup_gold_list", path="src.ui.gen2.MainMenu", method="buildList",
            owner="__nuzlockeTitleSetupListOwner",
            wrapper="__nuzlockeTitleSetupListFunction", generation="gen2" },
          { id="default_names_rby", path="src.ui.OakSpeech", method="runStep",
            owner="__nuzlockeDefaultNamesOwner",
            wrapper="__nuzlockeDefaultNamesFunction", generation="rby" },
          { id="default_names_gold_player", path="src.ui.gen2.OakSpeech",
            method="openNamePick", owner="__nuzlockeDefaultNamesOwner",
            wrapper="__nuzlockeDefaultNamesFunction", generation="gen2" },
          { id="default_names_gold_rival", path="src.world.gen2.World",
            method="nameRival", owner="__nuzlockeDefaultNamesOwner",
            wrapper="__nuzlockeDefaultNamesFunction", generation="gen2" },
          { id="stat_rules_wild", path="src.battle.BattleState", method="newWild",
            owner="__nuzlockeStatWildOwner",
            wrapper="__nuzlockeStatWildFunction", generation="rby" },
          { id="stat_rules_trainer", path="src.battle.BattleState",
            method="newTrainer", owner="__nuzlockeStatTrainerOwner",
            wrapper="__nuzlockeStatTrainerFunction", generation="rby" },
          { id="stat_exp_gate", path="src.battle.Experience", method="apply",
            owner="__nuzlockeStatExpOwner",
            wrapper="__nuzlockeStatExpFunction", generation="rby" },
          { id="badge_stat_gold", path="src.battle.gen2.Battle",
            method="battleStat", owner="__nuzlockeDifficultyStatOwner",
            wrapper="__nuzlockeDifficultyStatFunction", generation="gen2" },
          { id="badge_type_gold", path="src.battle.gen2.Battle",
            method="badgeTypeBoost", owner="__nuzlockeDifficultyTypeOwner",
            wrapper="__nuzlockeDifficultyTypeFunction", generation="gen2" },
          { id="encounter_hud_rby", path="src.battle.BattleState", method="draw",
            owner="__nuzlockeEncounterSpendHudOwner",
            wrapper="__nuzlockeEncounterSpendHudFunction", generation="rby" },
          { id="encounter_hud_gold", path="src.ui.gen2.BattleState", method="draw",
            owner="__nuzlockeEncounterSpendHudOwner",
            wrapper="__nuzlockeEncounterSpendHudFunction", generation="gen2" },
          { id="catch_gate_rby", path="src.battle.BattleState", method="throwBall",
            session="__nuzlockeCatchGateSession", generation="rby" },
          { id="catch_finalize_rby", path="src.battle.BattleState", method="finish",
            session="__nuzlockeCatchFinishSession", generation="rby" },
          { id="nickname_screen_rby", path="src.battle.BattleState",
            method="askNicknameUI", session="__nuzlockeNicknameScreenSession",
            generation="rby" },
          { id="random_field_items_rby", hook="world.talk",
            sessionExport="rbyFieldItemWorldTalkSession2971", generation="rby" },
          -- 2.9.10: TM Locations shares the physical-pickup seam with
          -- Field Items, but is an independent Randomizer ownership method. Keep
          -- an explicit health row so a dead/mistyped pickup hook cannot hide
          -- behind FIELD_ITEMS coverage.
          { id="random_tm_locations_rby", hook="world.talk",
            sessionExport="rbyFieldItemWorldTalkSession2971", generation="rby" },
          { id="random_field_items_gold", path="src.world.gen2.HiddenItems",
            method="ballPickupScript",
            session="__nuzlockeRandomFieldItemBallSession2808", generation="gen2" },
          { id="random_field_items_gold_hidden", path="src.world.gen2.HiddenItems",
            method="pickupScript",
            session="__nuzlockeRandomHiddenItemSession2808", generation="gen2" },
          { id="random_tm_locations_gold", path="src.world.gen2.HiddenItems",
            method="ballPickupScript",
            session="__nuzlockeRandomFieldItemBallSession2808", generation="gen2" },
          { id="random_tm_locations_gold_hidden", path="src.world.gen2.HiddenItems",
            method="pickupScript",
            session="__nuzlockeRandomHiddenItemSession2808", generation="gen2" },
          { id="field_poison_rby", path="src.world.OverworldController",
            method="applyFieldPoison",
            session="__nuzlockeFieldPoisonPermadeathSession", generation="rby" },
          { id="field_poison_warp_rby", path="src.world.OverworldController",
            method="warpToHealPoint",
            session="__nuzlockeFieldPoisonWarpSession29315", generation="rby" },
          { id="party_limit_rby", path="src.ui.BoxMenu", method="new",
            session="__nuzlockePartyLimitNewSession29315", generation="rby" },
          { id="capture_gate_gold", path="src.ui.gen2.BattleState", method="useItem",
            session="__nuzlockeCaptureGateSession", generation="gen2" },
          { id="nickname_answer_gold", path="src.ui.gen2.BattleState",
            method="answerNickname", session="__nuzlockeNicknameAnswerSession",
            generation="gen2" },
          { id="nickname_accept_gold", path="src.ui.gen2.NamingScreen",
            method="accept", session="__nuzlockeNicknameAcceptSession",
            generation="gen2" },
          { id="whiteout_gold", path="src.ui.gen2.BattleState",
            method="finishBattle", session="__nuzlockeGoldWhiteoutSession29315",
            generation="gen2" },
          { id="whiteout_recovery_pc_gold", path="src.ui.gen2.PcMenu",
            method="new", session="__nuzlockeWhiteoutRecoveryPcSession2531",
            generation="gen2" },
          { id="field_poison_gold", path="src.world.gen2.World",
            method="poisonFaintScript",
            session="__nuzlockeFieldPoisonPermadeathSession", generation="gen2" },
          { id="field_poison_warp_gold", path="src.world.gen2.World",
            method="warpToSpawn", session="__nuzlockeFieldPoisonWarpSession29315",
            generation="gen2" },
          { id="headbutt_tracking_gold", path="src.world.gen2.World",
            method="tryHeadbutt", session="__nuzlockeHeadbuttTrackingSession29315",
            generation="gen2" },
          { id="party_limit_gold_withdraw", path="src.ui.gen2.BoxMenu",
            method="doWithdraw", session="__nuzlockePartyLimitWithdrawSession29315",
            generation="gen2" },
          { id="party_limit_gold_move", path="src.ui.gen2.BoxMenu",
            method="checkSpaceInDestination",
            session="__nuzlockePartyLimitSpaceSession29315", generation="gen2" },
          { id="no_day_care_gold_deposit", path="src.core.gen2.Breeding",
            method="canDeposit", session="__nuzlockeNoDayCareDepositSession29315",
            generation="gen2" },
          { id="no_day_care_gold_menu", path="src.ui.gen2.DayCareMenu",
            method="refuse", session="__nuzlockeNoDayCareRefuseSession29315",
            generation="gen2" },
      }
      local counts = { healthy=0, chained=0, missing=0, pending=0, skipped=0 }

      for _, spec in ipairs(descriptors) do
          local applies = spec.generation == "all"
              or (spec.generation == "gen2" and gen2)
              or (spec.generation == "rby" and not gen2)
          if not applies then
              counts.skipped = counts.skipped + 1
          else
              local loaded = spec.path and package and package.loaded
                  and package.loaded[spec.path] or nil
              local row = {
                  id=spec.id,
                  adapter_id=spec.generation == "gen2"
                      and tostring(spec.id):gsub("_gold", "_gen2") or spec.id,
                  path=spec.path, method=spec.method, hook=spec.hook,
                  generation=spec.generation,
                  edition=identity.edition,
                  engine_family=identity.engine_family,
                  profile_scope=identity.profile_scope,
              }

              if spec.hook then
                  local session = spec.sessionExport
                      and mod.exports.__beta26[spec.sessionExport] or nil
                  if type(session)=="table" and session.owner==mod
                      and type(session.callback)=="function"
                      and type(session.unregister)=="function" then
                      row.state = "HEALTHY"
                      row.detail = "nuzlocke hook-bus registration is live"
                      counts.healthy = counts.healthy + 1
                  else
                      row.state = "MISSING"
                      row.detail = "nuzlocke hook-bus session marker absent"
                      counts.missing = counts.missing + 1
                  end
              elseif type(loaded) ~= "table" then
                  row.state = "PENDING"
                  row.detail = "module not loaded"
                  counts.pending = counts.pending + 1
              elseif type(loaded[spec.method]) ~= "function" then
                  row.state = "MISSING"
                  row.detail = "live method unavailable"
                  counts.missing = counts.missing + 1
              elseif spec.session then
                  local session = loaded[spec.session]
                  if type(session) == "table" and session.owner == mod
                      and type(session.wrapper) == "function"
                      and loaded[spec.method] == session.wrapper then
                      row.state = "HEALTHY"
                      row.detail = "nuzlocke wrapper is live top-level"
                      counts.healthy = counts.healthy + 1
                  elseif type(session) == "table" and session.owner == mod
                      and type(session.wrapper) == "function" then
                      row.state = "CHAINED"
                      row.detail = "live function differs from recorded wrapper"
                      counts.chained = counts.chained + 1
                  else
                      row.state = "MISSING"
                      row.detail = "nuzlocke session marker absent"
                      counts.missing = counts.missing + 1
                  end
              else
                  local owner = loaded[spec.owner]
                  local wrapper = loaded[spec.wrapper]
                  if owner == mod and type(wrapper) == "function"
                      and loaded[spec.method] == wrapper then
                      row.state = "HEALTHY"
                      row.detail = "nuzlocke wrapper is live top-level"
                      counts.healthy = counts.healthy + 1
                  elseif owner == mod and type(wrapper) == "function" then
                      row.state = "CHAINED"
                      row.detail = "live function differs from recorded wrapper"
                      counts.chained = counts.chained + 1
                  else
                      row.state = "MISSING"
                      row.detail = owner == nil
                          and "nuzlocke owner marker absent"
                          or "nuzlocke wrapper marker incomplete"
                      counts.missing = counts.missing + 1
                  end
              end
              -- 2.6.57: project the proven live/session metadata into the
              -- central Hook Registry without changing wrapper ownership.
              if not spec.hook and type(loaded) == "table"
                  and type(loaded[spec.method]) == "function"
                  and type(mod.exports.__beta26.registerHook) == "function" then
                  local previous, wrapper
                  if spec.session then
                      local session = loaded[spec.session]
                      if type(session) == "table" and session.owner == mod then
                          previous, wrapper = session.previous, session.wrapper
                      end
                  else
                      wrapper = loaded[spec.wrapper]
                  end
                  if type(wrapper) == "function" then
                      local target, methodName, wrapperFn = loaded, spec.method, wrapper
                      mod.exports.__beta26.registerHook(spec.id, {
                          owner="nuzlocke", previous=previous, wrapper=wrapperFn,
                          priority=100, mode="direct_method", feature=spec.id,
                          source=spec.path,
                          live=function() return target[methodName] == wrapperFn end,
                      })
                  end
              end
              rows[#rows + 1] = row
          end
      end

      local function addMultiSessionHealth(id, path, sessionKey, methods, applies)
          if not applies then
              counts.skipped = counts.skipped + 1
              return
          end
          local loaded = package and package.loaded and package.loaded[path] or nil
          local row = { id=id,
              adapter_id=gen2 and tostring(id):gsub("_gold", "_gen2") or id,
              path=path, method=table.concat(methods, ","),
              generation=identity.engine_family,
              edition=identity.edition, engine_family=identity.engine_family,
              profile_scope=identity.profile_scope }
          if type(loaded) ~= "table" then
              row.state, row.detail = "PENDING", "module not loaded"
              counts.pending = counts.pending + 1
          else
              local session = loaded[sessionKey]
              if type(session) ~= "table" or session.owner ~= mod then
                  row.state, row.detail = "MISSING", "nuzlocke session marker absent"
                  counts.missing = counts.missing + 1
              else
                  local live, checked = true, 0
                  for _, method in ipairs(methods) do
                      local rec = session.methods and session.methods[method]
                      if type(rec) == "table" and type(rec.wrapper) == "function" then
                          checked = checked + 1
                          if loaded[method] ~= rec.wrapper then live = false end
                      else
                          live = false
                      end
                  end
                  if live and checked == #methods then
                      row.state, row.detail = "HEALTHY",
                          "all recorded nuzlocke wrappers are live top-level"
                      counts.healthy = counts.healthy + 1
                  else
                      row.state, row.detail = "CHAINED",
                          "one or more live functions differ from recorded wrappers"
                      counts.chained = counts.chained + 1
                  end
              end
          end
          if type(loaded) == "table" and type(mod.exports.__beta26.registerHook) == "function" then
              local session = loaded[sessionKey]
              if type(session) == "table" and session.owner == mod then
                  for _, method in ipairs(methods) do
                      local rec = session.methods and session.methods[method]
                      if type(rec) == "table" and type(rec.wrapper) == "function" then
                          local target, methodName, wrapperFn = loaded, method, rec.wrapper
                          mod.exports.__beta26.registerHook(id .. ":" .. method, {
                              owner="nuzlocke", previous=rec.previous,
                              wrapper=wrapperFn, priority=100,
                              mode="direct_method", feature=id, source=path,
                              live=function() return target[methodName] == wrapperFn end,
                          })
                      end
                  end
              end
          end
          rows[#rows + 1] = row
      end

      addMultiSessionHealth("permadeath_rby", "src.battle.BattleState",
          "__nuzlockePermadeathSession",
          { "onFaint", "playerMonFainted", "finish" }, not gen2)
      addMultiSessionHealth("mart_rules_gold", "src.ui.gen2.MartMenu",
          "__nuzlockeMartGateSession29314",
          { "enterBuy", "enterSell", "completePurchase", "completeSale" }, gen2)

      if gen2 then
          local Specials = package and package.loaded
              and package.loaded["src.script.gen2.Specials"] or nil
          if type(Specials) ~= "table" then
              counts.pending = counts.pending + 1
              rows[#rows + 1] = { id="gambling_gold", adapter_id="gambling_gen2",
                  state="PENDING", detail="module not loaded",
                  path="src.script.gen2.Specials",
                  generation="gen2", edition=identity.edition,
                  engine_family=identity.engine_family,
                  profile_scope=identity.profile_scope }
          else
              local session = Specials.__nuzlockeGamblingSession
              local owner = type(session) == "table" and session.owner == mod
              local live, checked = owner, 0
              for _, name in ipairs({ "SlotMachine", "CardFlip" }) do
                  local rec = owner and session.methods and session.methods[name]
                  if type(rec) == "table" then
                      if rec.wrapperHandlers then
                          checked = checked + 1
                          if not Specials.HANDLERS
                              or Specials.HANDLERS[name] ~= rec.wrapperHandlers then
                              live = false
                          end
                      end
                      if rec.wrapperAll then
                          checked = checked + 1
                          if not Specials.ALL
                              or Specials.ALL[name] ~= rec.wrapperAll then
                              live = false
                          end
                      end
                  end
              end
              local row = { id="gambling_gold", adapter_id="gambling_gen2",
                  path="src.script.gen2.Specials",
                  generation="gen2", edition=identity.edition,
                  engine_family=identity.engine_family,
                  profile_scope=identity.profile_scope }
              if live and checked > 0 then
                  row.state, row.detail = "HEALTHY",
                      "slot/card wrappers are live top-level"
                  counts.healthy = counts.healthy + 1
              elseif owner and checked > 0 then
                  row.state, row.detail = "CHAINED",
                      "slot/card live functions differ from recorded wrappers"
                  counts.chained = counts.chained + 1
              else
                  row.state, row.detail = "MISSING",
                      "nuzlocke gambling session marker absent"
                  counts.missing = counts.missing + 1
              end
              rows[#rows + 1] = row
          end
      else
          counts.skipped = counts.skipped + 1
      end

      -- 2.8.77: semantic Runtime hooks do not own a concrete module method
      -- session marker, so inspect trainer.party through RandomizerRuntime's
      -- authoritative chain probe instead of pretending it is a direct wrapper.
      do
          local probe = mod.exports.__beta26.randomTrainerHookHealth
          local status = type(probe) == "function" and probe(game) or nil
          local row = {
              id="random_trainers_hook_chain",
              adapter_id="random_trainers_hook_chain",
              path="src.mods.Runtime",
              method="trainer.party",
              generation=identity.engine_family,
              edition=identity.edition,
              engine_family=identity.engine_family,
              profile_scope=identity.profile_scope,
              semantic_hook=true,
              diagnostics=status,
          }
          if type(status) ~= "table" then
              row.state, row.detail = "PENDING",
                  "Randomizer trainer.party health probe unavailable"
              counts.pending = counts.pending + 1
          elseif status.wants_hook ~= true then
              row.state, row.detail = "MISSING",
                  "Runtime does not advertise trainer.party"
              counts.missing = counts.missing + 1
          elseif status.primary_registered == true
              and status.finalizer_registered == true then
              row.state = "HEALTHY"
              row.detail = status.last_error and status.last_error ~= ""
                  and ("trainer.party chain live; last Gen2 builder error: "
                      .. tostring(status.last_error))
                  or "trainer.party primary/finalizer callbacks registered"
              counts.healthy = counts.healthy + 1
          else
              row.state, row.detail = "MISSING",
                  string.format("trainer.party primary=%s finalizer=%s",
                      tostring(status.primary_registered == true),
                      tostring(status.finalizer_registered == true))
              counts.missing = counts.missing + 1
          end
          rows[#rows + 1] = row
      end

      local function addOptionalCompatHealth(id, providerId, inspect)
          local okFind, provider = pcall(mod.find, providerId)
          if not okFind or type(provider) ~= "table" then
              counts.skipped = counts.skipped + 1
              return
          end
          local state, detail = inspect(provider)
          state = state or "MISSING"
          detail = detail or "compatibility wrapper unavailable"
          rows[#rows + 1] = { id=id, adapter_id=id, path="mod:" .. providerId,
              generation="all", edition=identity.edition,
              engine_family=identity.engine_family, profile_scope=identity.profile_scope,
              state=state, detail=detail }
          local key = state:lower()
          if counts[key] ~= nil then counts[key] = counts[key] + 1
          else counts.missing = counts.missing + 1 end
      end

      addOptionalCompatHealth("qol_auto_repel", "qol_toggles", function(provider)
          local exports = provider.exports
          if type(exports) ~= "table" or type(exports.applyAutoRepel) ~= "function" then
              return "MISSING", "AUTO-REPEL export unavailable"
          end
          if exports.__nuzlockeAutoRepelGuardOwner == mod
              and type(exports.__nuzlockeAutoRepelGuardFunction) == "function" then
              if exports.applyAutoRepel == exports.__nuzlockeAutoRepelGuardFunction then
                  return "HEALTHY", "No Repels AUTO-REPEL guard is live"
              end
              return "CHAINED", "AUTO-REPEL live function differs from guard wrapper"
          end
          return "MISSING", "No Repels AUTO-REPEL guard marker absent"
      end)

      addOptionalCompatHealth("wilds_capture", "overworld_wild_spawns",
          function(provider)
              local exports = provider.exports
              local catching = type(exports) == "table" and exports.catching or nil
              local gameCompat = type(exports) == "table" and exports.gameCompat or nil
              local session = type(catching) == "table"
                  and (catching.__nuzlockeCompat2828 or catching.__nuzlockeCompat2411) or nil
              if type(catching) ~= "table" or type(gameCompat) ~= "table" then
                  return "MISSING", "Wilds capture compatibility surface unavailable"
              end
              if type(session) == "table" and session.owner == mod
                  and type(session.resolveWrapper) == "function"
                  and type(session.giveWrapper) == "function" then
                  if catching._resolveCapture == session.resolveWrapper
                      and gameCompat.giveCaughtPokemon == session.giveWrapper then
                      local pv = tostring(session.providerVersion or (exports and exports.version) or "")
                      local audit = tostring(session.auditVersion or "")
                      if pv == "2.2.0" and audit == "2.2.0" then
                          return "HEALTHY", "Wilds 2.2.0 audited pre/post capture wrappers are live"
                      end
                      return "CHAINED", "capture wrappers live; provider version " .. pv
                          .. " is outside the explicit 2.2.0 audit"
                  end
                  return "CHAINED",
                      "one or both Wilds capture functions differ from recorded wrappers"
              end
              return "MISSING", "Wilds Nuzlocke capture session marker absent"
          end)

      -- 2.8.36 / Shiny Pokemon 1.2.7: maintained compatibility API v1 is
      -- generation-neutral. Gen II no longer runs the inherited Gen-I entry,
      -- so health must inspect exports.shiny_pokemon rather than requiring the
      -- historical top-level isShiny/rollShiny pair.
      addOptionalCompatHealth("shiny_pokemon", "SHINY_POKEMON",
          function(provider)
              local exports = provider.exports
              local api = type(exports) == "table"
                  and (exports.shiny_pokemon or exports.shiny_compat) or nil
              if type(api) == "table" and type(api.isShiny) == "function"
                  and type(api.capability) == "function" then
                  local identity = api.capability("shiny_identity")
                  local presentation = api.capability("shiny_presentation")
                  if type(identity) == "table" and type(presentation) == "table"
                      and tostring(identity.owner or ""):upper() == "SHINY_POKEMON"
                      and tostring(presentation.owner or ""):upper() == "SHINY_POKEMON" then
                      return "HEALTHY",
                          (gen2 and "Gen II" or "Gen I")
                          .. " shiny generation/presentation delegated through Shiny Pokemon API v1; Nuzlocke consumes identity/rules only"
                  end
              end
              if type(exports) == "table" and type(exports.isShiny) == "function"
                  and type(exports.rollShiny) == "function" then
                  return "HEALTHY",
                      "Legacy Shiny Pokemon identity/roll surface detected; delegated through compatibility fallback"
              end
              return "CHAINED",
                  "Shiny Pokemon is loaded but neither its maintained API v1 nor legacy identity/roll surface is complete"
          end)

      -- 2.8.33: PotatoVoxel is presentation-only from Nuzlocke's perspective.
      -- Do not key gameplay to its release/version strings: v1.9.6 exposes
      -- capability surfaces while packaged internal version labels may lag the
      -- release tag. Health is therefore capability-based and edition-aware.
      addOptionalCompatHealth("potato_voxel_render", "potato_voxel",
          function(provider)
              local exports = provider.exports
              if type(exports) ~= "table" then
                  return "MISSING", "PotatoVoxel exports unavailable"
              end
              if gen2 then
                  if exports.gen2Compatible == true
                      and type(exports.goldBridgeStatus) == "function" then
                      return "HEALTHY",
                          "Gen II voxel renderer bridge present; Nuzlocke renderer ownership remains isolated"
                  end
                  return "CHAINED",
                      "PotatoVoxel is loaded but its Gen II renderer bridge surface is incomplete"
              end
              if type(exports.isLoading) == "function"
                  and type(exports.lib) == "table" then
                  return "HEALTHY",
                      "Gen I voxel renderer surface present; Nuzlocke gameplay hooks remain composed"
              end
              return "CHAINED",
                  "PotatoVoxel is loaded but the audited Gen I renderer surface is incomplete"
          end)

      -- Hook health remains the detailed engine-facing view. Feature Health is
      -- the stable support/UI/API summary; installer-originated N/A/PENDING
      -- states remain distinct rather than being mislabeled ACTIVE.
      if type(mod.exports.__beta26.noteFeatureHealth) == "function" then
          for _, row in ipairs(rows) do
              if row.state == "HEALTHY" then
                  mod.exports.__beta26.noteFeatureHealth(row.id, "ACTIVE", nil, "hook_health")
              elseif row.state == "CHAINED" then
                  mod.exports.__beta26.noteFeatureHealth(row.id, "DEGRADED", row.detail, "hook_health")
              elseif row.state == "MISSING" then
                  mod.exports.__beta26.noteFeatureHealth(row.id, "UNAVAILABLE", row.detail, "hook_health")
              end
          end
      end

      return {
          game = identity.edition,
          edition = identity.edition,
          generation = identity.generation,
          engine_family = identity.engine_family,
          profile_scope = identity.profile_scope,
          counts = counts,
          rows = rows,
      }
  end

  -- 2.9.71: edition-aware read-only Random Field Item pipeline evidence.
  -- This distinguishes hook installation from mapping/projection behavior so a
  -- future runtime failure can be localized without materializing new RNG.
  mod.exports.__beta26.Dev.fieldItemPipeline = function(game)
      game = game or deps.currentGame() or mod.game
      local gen2 = mod.exports.__beta26.runtimeIsGen2(game) == true
      local fn = gen2 and mod.exports.__beta26.auditGen2FieldItemPipeline
          or mod.exports.__beta26.auditRbyFieldItemPipeline
      if type(fn) ~= "function" then
          return { ok=false, generation=gen2 and 2 or 1,
              error="pipeline_audit_unavailable" }
      end
      local ok, report = pcall(fn, game)
      if not ok or type(report) ~= "table" then
          return { ok=false, generation=gen2 and 2 or 1,
              error=ok and "invalid_report" or tostring(report) }
      end
      report.generation = gen2 and 2 or 1
      report.selected = mod.save:get("random_field_items", false) == true
      report.lastNormalization = mod.exports.__beta26.lastFieldItemNormalization
      return report
  end

  -- 2.6.27: Silver-focused diagnostic confidence audit.  Shared Gen 2 adapter
  -- ownership is expected, but every runtime report must still carry the exact
  -- edition/profile identity so Gold evidence cannot masquerade as Silver
  -- evidence.  Hook HEALTHY/MISSING state is deliberately not judged here;
  -- hookHealth already owns that.  This audit checks only diagnostic identity.


  -- 2.9.48: snapshot/error/self-test diagnostics moved from main.lua.
  mod.exports.__beta26.Dev.snapshot = function(game, reason)
      game = game or deps.currentGame() or mod.game
      local identity = mod.exports.__beta26.Dev.editionContext(game)
      local save = game and game.save
      local party = save and save.party or {}
      local dead, external = 0, 0
      for _, mon in ipairs(party) do
          if type(mon) == "table" then
              if mon.nuzlockeDead == true then dead = dead + 1 end
              if mon.nuzlockeOrigin == "EDITED" then external = external + 1 end
          end
      end
      local compatReport = mod.exports.__beta26.compat
          and mod.exports.__beta26.compat.Mods
          and mod.exports.__beta26.compat.Mods.report
          and mod.exports.__beta26.compat.Mods.report() or nil
      local hookHealth = mod.exports.__beta26.Dev.hookHealth(game)
      local capabilities = {}
      for _, capability in ipairs({
          "battle_stats", "stat_growth", "identity_dvs",
          "move_category_model", "species_metadata", "species_evolutions",
      }) do
          capabilities[capability] = mod.exports.__beta26.mechanicsCapability(
              capability, game)
      end
      return {
          reason = tostring(reason or "manual"),
          build = mod.exports.__beta26.build,
          environment = mod.exports.__beta26.runtimeEnvironment(),
          game = identity.edition,
          edition = identity.edition,
          generation = identity.generation,
          engine_family = identity.engine_family,
          profile_scope = identity.profile_scope,
          save_schema = tonumber(mod.save:get(SAVE_SCHEMA_KEY, CURRENT_SAVE_SCHEMA)),
          nuzlocke_enabled = mod.save:get("nuzlocke_enabled", true) == true,
          locke_type = tonumber(mod.save:get("locke_type",
              deps.defaultRuleValue("locke_type")))
              or deps.defaultRuleValue("locke_type"),
          rule_revision = tonumber(mod.save:get("nuzlocke_rule_revision", 0)) or 0,
          randomizer_seed_mode = type(mod.exports.__beta26.randomizerSeedMode) == "function"
              and mod.exports.__beta26.randomizerSeedMode(nil) or "UNKNOWN",
          randomizer_run_seed = type(mod.exports.__beta26.randomizerSeed) == "function"
              and tonumber(mod.exports.__beta26.randomizerSeed(nil, false)) or 0,
          randomizer_run_snapshot = type(mod.exports.__beta26.randomizerRunConfig) == "function"
              and mod.exports.__beta26.randomizerRunConfig() or nil,
          randomizer_streams = type(mod.exports.__beta26.randomizerStreamNames) == "function"
              and mod.exports.__beta26.randomizerStreamNames() or {},
          party = { count = #party, dead = dead, external = external,
              limit = tonumber(mod.save:get("party_size_limit", 6)) or 6 },
          assertions = mod.exports.__beta26.Dev.assertions(game),
          compat = compatReport,
          capabilities = capabilities,
          hook_health = hookHealth,
          hook_registry = mod.exports.__beta26.hookRegistry.describe(),
          feature_health = mod.exports.__beta26.featureHealth.status(),
          gameplay_transactions = mod.exports.__beta26.GameplayTransactions.status(),
          gen2_parity = mod.exports.__beta26.Dev.gen2EditionParityAudit(game, hookHealth),
          rule_effectiveness = mod.exports.__beta26.Dev.ruleEffectiveness(game),
          randomizer_integrity = mod.exports.__beta26.Dev.randomizerIntegrity(game),
          field_item_pipeline = mod.exports.__beta26.Dev.fieldItemPipeline(game),
          lifecycle = mod.exports.__beta26.Dev.lifecycleReport(),
          safe_stop_writes = mod.exports.__beta26.safeStopWriteReport(),
          breadcrumb_count = #(mod.exports.__beta26.Dev.breadcrumbs or {}),
          breadcrumb_last = mod.exports.__beta26.Dev.breadcrumbs[
              #(mod.exports.__beta26.Dev.breadcrumbs or {})],
      }
  end

  mod.exports.__beta26.Dev.recordError = function(label, err, game)
      if not mod.exports.__beta26.Dev.enabled() then return false end
      mod.exports.__beta26.Dev.push("error",
          tostring(label or "nuzlocke") .. ": " .. tostring(err or "unknown"), game)
      pcall(function()
          mod.log:error("[Nuzlocke:Dev] ERROR [%s] %s", tostring(label or "nuzlocke"),
              tostring(err or "unknown"))
      end)
      pcall(mod.exports.__beta26.Dev.logSnapshot,
          "error:" .. tostring(label or "nuzlocke"), game)
      return true
  end

  mod.exports.__beta26.Dev.logSnapshot = function(reason, game)
      if not mod.exports.__beta26.Dev.enabled() then return false end
      local snap = mod.exports.__beta26.Dev.snapshot(game, reason)
      local warningCount = #(snap.assertions or {})
      mod.exports.__beta26.Dev.push("snapshot",
          string.format("%s schema=%s party=%d/%d dead=%d external=%d warnings=%d",
              snap.reason, tostring(snap.save_schema), snap.party.count,
              snap.party.limit, snap.party.dead, snap.party.external, warningCount),
          game)
      for _, warning in ipairs(snap.assertions or {}) do
          pcall(function()
              mod.log:warn("[Nuzlocke:Dev] ASSERT [%s] %s", tostring(warning.code),
                  tostring(warning.detail or ""))
          end)
      end
      return snap
  end

  ---------------------------------------------------------------------
  -- 2.4.49 DEV TOOLS SELF-TEST / OFFICIAL STORAGE
  --
  -- All checks are read-only. They inspect current wiring/state and never
  -- fabricate a gameplay transaction or mutate rules, RNG, encounters,
  -- party, inventory, progression, or save schema.
  ---------------------------------------------------------------------
  mod.exports.__beta26.Dev.selfTest = function(game)
      game = game or deps.currentGame() or mod.game
      local rows = {}
      local function add(id, ok, detail, kind)
          rows[#rows + 1] = {
              id = tostring(id),
              ok = ok == true,
              status = ok == true and "PASS" or "WARN",
              kind = tostring(kind or "wiring"),
              detail = tostring(detail or ""),
          }
      end

      add("dev_mode", mod.exports.__beta26.Dev.enabled(),
          "Dev Mode is enabled.", "config")

      local schema = tonumber(mod.save:get(SAVE_SCHEMA_KEY, CURRENT_SAVE_SCHEMA))
      add("save_schema", schema == CURRENT_SAVE_SCHEMA,
          "current=" .. tostring(schema) .. " expected="
              .. tostring(CURRENT_SAVE_SCHEMA), "schema")

      local whiteoutCounts = mod.exports.__beta26.whiteoutRecoveryCounts(game)
      add("whiteout_recovery_policy",
          type(mod.exports.__beta26.whiteoutDecision) == "function"
              and type(mod.exports.__beta26.whiteoutRecoveryEligiblePokemon) == "function"
              and type(whiteoutCounts) == "table"
              and mod.save:get("whiteout_semantics_restored_2531", false) == true,
          "whiteout=" .. tostring(mod.save:get("whiteout_clause", false))
              .. " party=" .. tostring(whiteoutCounts.party or 0)
              .. " box=" .. tostring(whiteoutCounts.boxed or 0),
          "rules")

      local policyWritable = mod.exports.__beta26.canWriteNuzlockeSave(game)
      local policyEnabled = mod.exports.__beta26.isNuzlockeEnabled()
      local policyEnforce = mod.exports.__beta26.shouldEnforceNuzlocke(game, nil)
      add("battle_write_policy",
          type(mod.exports.__beta26.canWriteNuzlockeSave) == "function"
              and type(mod.exports.__beta26.isNuzlockeEnabled) == "function"
              and type(mod.exports.__beta26.shouldEnforceNuzlocke) == "function"
              and (not policyEnforce or (policyWritable and policyEnabled)),
          string.format("writable=%s enabled=%s enforce=%s",
              tostring(policyWritable), tostring(policyEnabled),
              tostring(policyEnforce)),
          "schema")

      local okDefaults, defaultResult = pcall(
          mod.exports.__beta26.auditNewRuleDefaults)
      add("default_rule_audit", okDefaults and defaultResult == true,
          okDefaults and tostring(defaultResult) or tostring(defaultResult),
          "defaults")

      local descriptionParity = type(mod.exports.__beta26.gen2DescriptionParityAudit)
          == "function" and mod.exports.__beta26.gen2DescriptionParityAudit() or nil
      add("gen2_description_parity",
          type(descriptionParity) == "table" and descriptionParity.ok == true,
          type(descriptionParity) == "table"
              and string.format("checked=%d failures=%d",
                  tonumber(descriptionParity.checked or 0),
                  #(descriptionParity.failures or {}))
              or "Gen 2 description parity audit unavailable",
          "setup")

      local ruleRegistryAudit = mod.exports.__beta26.ruleRegistry
          and mod.exports.__beta26.ruleRegistry.audit()
      add("rule_registry_descriptor",
          type(ruleRegistryAudit) == "table" and ruleRegistryAudit.ok == true,
          type(ruleRegistryAudit) == "table"
              and string.format("rules=%d errors=%d",
                  tonumber(ruleRegistryAudit.count or 0),
                  #(ruleRegistryAudit.errors or {}))
              or "rule registry descriptor unavailable",
          "defaults")

      local saveDescriptorAudit = mod.exports.__beta26.saveSchemaDescriptor
          and mod.exports.__beta26.saveSchemaDescriptor.audit()
      add("save_config_descriptor",
          type(saveDescriptorAudit) == "table" and saveDescriptorAudit.ok == true,
          type(saveDescriptorAudit) == "table"
              and string.format("schema=%d fields=%d errors=%d",
                  tonumber(saveDescriptorAudit.save_schema or 0),
                  tonumber(saveDescriptorAudit.field_count or 0),
                  #(saveDescriptorAudit.errors or {}))
              or "save configuration descriptor unavailable",
          "schema")

      local provenance = mod.exports.__beta26.buildProvenance()
      add("build_provenance",
          type(provenance) == "table"
              and provenance.version == mod.exports.__beta26.build
              and provenance.parent_version == mod.exports.__beta26.parentVersion
              and type(provenance.parent_sha256) == "string"
              and #provenance.parent_sha256 == 64,
          type(provenance) == "table"
              and ("parent=" .. tostring(provenance.parent_version))
              or "build provenance unavailable",
          "build")

      local wrapperHarness = mod.exports.__beta26.Dev.wrapperInterpositionHarness()
      add("wrapper_interposition", type(wrapperHarness) == "table" and wrapperHarness.ok == true,
          type(wrapperHarness) == "table"
              and string.format("external=%s first=%s second=%s",
                  tostring(wrapperHarness.external_preserved), tostring(wrapperHarness.first),
                  tostring(wrapperHarness.second))
              or "wrapper harness unavailable", "compat")

      local capabilityVersionCount = 0
      for _, capability in ipairs(COMPAT_CAPABILITIES or {}) do
          if mod.exports.__beta26.compatCapabilityVersions[capability] ~= nil then
              capabilityVersionCount = capabilityVersionCount + 1
          end
      end
      add("compat_capability_versions",
          capabilityVersionCount == #(COMPAT_CAPABILITIES or {}),
          string.format("versioned=%d advertised=%d",
              capabilityVersionCount, #(COMPAT_CAPABILITIES or {})),
          "compat")

      add("encounter_slot_conflict",
          type(mod.exports.__beta26.encounterSlotConflict) == "function",
          "Shared CAUGHT/FAILED conflict resolver installed.", "encounter")
      add("shiny_clause",
          type(mod.exports.__beta26.shinyClauseAvailable) == "function"
              and type(mod.exports.__beta26.consumeShinyClauseAllowance)
                  == "function",
          "Finite Shiny Clause accounting helpers installed.", "encounter")
      add("tracker_death_projection",
          type(mod.exports.__beta26.syncTrackerDeathProjection) == "function",
          "Persistent-ID DEAD projection installed.", "tracker")
      add("species_facts",
          type(mod.exports.__beta26.getSpeciesFacts) == "function",
          "Shared species facts resolver installed.", "content")
      add("mechanics_capability",
          type(mod.exports.__beta26.mechanicsCapability) == "function",
          "Provider capability resolver installed.", "compat")

      local gen2 = mod.exports.__beta26.runtimeIsGen2(game)
      local exactEdition = mod.exports.__beta26.Dev.gameId(game)
      local exactIdentity = mod.exports.__beta26.Dev.editionContext(game)
      add("game_identity", exactEdition ~= "",
          "edition=" .. tostring(exactEdition)
              .. " generation=" .. tostring(gen2 and 2 or 1)
              .. " family=" .. tostring(exactIdentity.engine_family)
              .. " profile=" .. tostring(exactIdentity.profile_scope),
          "generation")
      add("late_runtime_phase_2",
          mod.exports.__beta26.lateRuntimePhase2Ready == true,
          mod.exports.__beta26.lateRuntimePhase2Ready == true
              and "staged runtime phase executed"
              or ("error=" .. tostring(mod.exports.__beta26.lateRuntimePhase2Error or "missing")),
          "lifecycle")
      if not gen2 then
          local oakDemoHealth = type(mod.exports.__beta26.oakCatchTutorialGateHealth) == "function"
              and mod.exports.__beta26.oakCatchTutorialGateHealth(game) or nil
          add("oak_catch_demo_gate",
              type(oakDemoHealth) == "table" and oakDemoHealth.state == "HEALTHY",
              type(oakDemoHealth) == "table" and oakDemoHealth.detail
                  or "Oak catch-demo gate health unavailable.",
              "hooks")
          local momHealth = type(mod.exports.__beta26.momHealGateHealth) == "function"
              and mod.exports.__beta26.momHealGateHealth(game) or nil
          add("mom_heal_gate",
              type(momHealth) == "table" and momHealth.state == "HEALTHY",
              type(momHealth) == "table" and momHealth.detail
                  or "Mom heal gate health unavailable.",
              "hooks")
          add("rby_starter_transaction_gate",
              type(momHealth) == "table" and momHealth.resolve_live == true,
              type(momHealth) == "table"
                  and ("give_pokemon resolver=" .. tostring(momHealth.resolve_live == true))
                  or "R/B/Y command resolver health unavailable.",
              "hooks")
      end
      local randomFieldItemsSelected =
          mod.save:get("random_field_items", false) == true
      local randomFieldItemsReady =
          type(mod.exports.__beta26.randomizeFieldItem) == "function"
          and type(mod.exports.__beta26.installRandomFieldItemHooks) == "function"
      local fieldPipelineFn = gen2
          and mod.exports.__beta26.auditGen2FieldItemPipeline
          or mod.exports.__beta26.auditRbyFieldItemPipeline
      local fieldPipeline
      if randomFieldItemsSelected and type(fieldPipelineFn) == "function" then
          local okPipeline, report = pcall(fieldPipelineFn, game)
          if okPipeline and type(report) == "table" then
              fieldPipeline = report
          else
              fieldPipeline = { ok=false,
                  error=okPipeline and "invalid_report" or tostring(report) }
          end
      end
      local fieldPipelineHealthy = not randomFieldItemsSelected
          or (randomFieldItemsReady and type(fieldPipeline)=="table"
              and fieldPipeline.ok == true)
      add("random_field_items_setting",
          fieldPipelineHealthy,
          "selected=" .. tostring(randomFieldItemsSelected)
              .. " helper=" .. tostring(randomFieldItemsReady)
              .. " pipeline=" .. tostring(
                  type(fieldPipeline)=="table" and fieldPipeline.ok or "n/a"),
          "setup")

      if gen2 then
          add("gold_rule_surface",
              type(mod.exports.__beta26.gen2BetaRules) == "table",
              string.upper(exactEdition) .. " uses the shared Gen 2 rule surface.",
              "generation")
          local gen2StarterHealthFn = mod.exports.__beta26.gen2RandomStarterTransactionHealth
              or mod.exports.__beta26.goldRandomStarterTransactionHealth
          local gen2StarterHealth = type(gen2StarterHealthFn) == "function"
              and gen2StarterHealthFn(game) or nil
          add("gold_random_starter_transaction_gate",
              type(gen2StarterHealth) == "table"
                  and gen2StarterHealth.state == "HEALTHY",
              type(gen2StarterHealth) == "table" and gen2StarterHealth.detail
                  or (string.upper(exactEdition)
                      .. " Gen 2 Random Starter transaction health unavailable."),
              "hooks")
      else
          add("rby_runtime", game ~= nil,
              string.upper(exactEdition) .. " runtime game attached.", "generation")
      end

      add("cap_messages_setting",
          mod.exports.__beta26.levelCapNoticeFrequency() == 1,
          "fixed=once per battle on first blocked EXP",
          "ui")
      local starterChoice = mod.save:get("__nuzlocke_random_starter_choice", nil)
      local starterOriginal = mod.save:get("__nuzlocke_random_starter_original", nil)
      add("opening_starter_commit",
          starterChoice == nil or tostring(starterChoice) ~= "",
          "original=" .. tostring(starterOriginal or "-")
              .. " choice=" .. tostring(starterChoice or "-"),
          "content")
      local starterPreview = mod.save:get(
          "__nuzlocke_random_starter_selected_preview", nil)
      local starterPreviewMismatch = mod.save:get(
          "__nuzlocke_random_starter_preview_mismatch", false) == true
      local previewParityOk = not starterPreviewMismatch
          and (starterChoice == nil or starterChoice == ""
              or (starterPreview ~= nil and tostring(starterPreview) ~= ""
                  and tostring(starterPreview):upper()
                      == tostring(starterChoice):upper()))
      add("opening_starter_preview_award_parity",
          previewParityOk,
          "preview=" .. tostring(starterPreview or "-")
              .. " award=" .. tostring(starterChoice or "-"),
          "content")
      if not gen2 then
          local runtimeSave = game and game.save
          local randomStarterSelected = mod.save:get("random_starter", false) == true
          local randomStarterReady = type(mod.exports.__beta26.randomizerSeededIndex)
              == "function" and type(mod.exports.__beta26.randomizerAlgorithmVersion)
              == "function"
          add("random_starter_setting",
              not randomStarterSelected or randomStarterReady,
              "selected=" .. tostring(randomStarterSelected)
                  .. " helper=" .. tostring(randomStarterReady)
                  .. " choice=" .. tostring(starterChoice or "-"),
              "setup")

          local skipSelected = mod.save:get("skip_catch_tutorial", false) == true
          local oakHealth = type(mod.exports.__beta26.oakCatchTutorialGateHealth) == "function"
              and mod.exports.__beta26.oakCatchTutorialGateHealth(game) or nil
          local skipCarried = runtimeSave
              and runtimeSave.nuzlockeSkipCatchTutorial == true or false
          add("skip_catch_demo_setting",
              not skipSelected or (type(oakHealth) == "table"
                  and oakHealth.state == "HEALTHY" and skipCarried),
              "selected=" .. tostring(skipSelected)
                  .. " carried=" .. tostring(skipCarried)
                  .. " gate=" .. tostring(type(oakHealth) == "table"
                      and oakHealth.state or "missing"),
              "setup")

          local momSelected = mod.save:get("no_mom_heal", false) == true
          local momHealth = type(mod.exports.__beta26.momHealGateHealth) == "function"
              and mod.exports.__beta26.momHealGateHealth(game) or nil
          add("no_mom_heal_setting",
              not momSelected or (type(momHealth) == "table"
                  and momHealth.state == "HEALTHY"),
              "selected=" .. tostring(momSelected)
                  .. " gate=" .. tostring(type(momHealth) == "table"
                      and momHealth.state or "missing"),
              "setup")
      end
      local ballLimitStored = mod.save:get("encounter_ball_limit",
          deps.defaultRuleValue("encounter_ball_limit"))
      local ballLimitRead = deps.getConfigValue("encounter_ball_limit", false)
      add("encounter_ball_limit_setting",
          type(ballLimitRead) == "number"
              and ballLimitRead >= 0 and ballLimitRead <= 5
              and type(ballLimitStored) ~= "boolean",
          "stored=" .. tostring(ballLimitStored)
              .. " read=" .. tostring(ballLimitRead),
          "ui")

      local installHealth = mod.exports.__beta26.installHealth or {}
      local installFailureCount = 0
      for _ in pairs(installHealth.failures or {}) do installFailureCount = installFailureCount + 1 end
      add("install_health", installFailureCount == 0,
          "failures=" .. tostring(installFailureCount), "hooks")

      -- 2.6.68: verify the diagnostic registry itself so contradictory
      -- installer accounting is caught in code rather than inferred from UI.
      local installConsistency = true
      local installConsistencyDetail = {}
      for name, reason in pairs(installHealth.failures or {}) do
          local attempt = installHealth.attempts and installHealth.attempts[name]
          if type(attempt) ~= "table" or attempt.ok ~= false then
              installConsistency = false
              installConsistencyDetail[#installConsistencyDetail + 1] =
                  tostring(name) .. ":failure_without_failed_attempt"
          end
      end
      for name, attempt in pairs(installHealth.attempts or {}) do
          if type(attempt) == "table" and attempt.ok == false
              and (installHealth.failures or {})[name] == nil then
              installConsistency = false
              installConsistencyDetail[#installConsistencyDetail + 1] =
                  tostring(name) .. ":failed_attempt_without_failure"
          end
      end
      add("diagnostic_health_consistency", installConsistency,
          installConsistency and "install registry consistent"
              or table.concat(installConsistencyDetail, "; "), "hooks")

      local hookHealth = mod.exports.__beta26.Dev.hookHealth(game)
      local hookCounts = hookHealth and hookHealth.counts or {}
      add("hook_health",
          tonumber(hookCounts.missing or 0) == 0,
          string.format("healthy=%d chained=%d pending=%d missing=%d",
              tonumber(hookCounts.healthy or 0),
              tonumber(hookCounts.chained or 0),
              tonumber(hookCounts.pending or 0),
              tonumber(hookCounts.missing or 0)),
          "hooks")

      local gen2Parity = mod.exports.__beta26.Dev.gen2EditionParityAudit(
          game, hookHealth)
      add("gen2_edition_parity",
          type(gen2Parity) == "table" and gen2Parity.ok == true,
          type(gen2Parity) == "table"
              and string.format("edition=%s profile=%s hooks=%d dex=%d failures=%d",
                  tostring(gen2Parity.edition or "?"),
                  tostring(gen2Parity.profile_scope or "?"),
                  tonumber(gen2Parity.checked_rows or 0),
                  tonumber(gen2Parity.species_ban_rows or 0),
                  #(gen2Parity.failures or {}))
              or "Gen 2 edition parity audit unavailable",
          "generation")

      local lifecycle = mod.exports.__beta26.Dev.lifecycleReport()
      add("lifecycle_callbacks",
          tonumber(lifecycle.duplicate_callbacks or 0) == 0,
          string.format("duplicates=%d battle_delta=%d",
              tonumber(lifecycle.duplicate_callbacks or 0),
              tonumber(lifecycle.battle_delta or 0)),
          "lifecycle")

      local safeStopWrites = mod.exports.__beta26.safeStopWriteReport()
      add("safe_stop_writes",
          tonumber(safeStopWrites.total or 0) == 0,
          string.format("active=%s attempts=%d first=%s last=%s",
              tostring(safeStopWrites.active == true),
              tonumber(safeStopWrites.total or 0),
              tostring(safeStopWrites.first_key or "none"),
              tostring(safeStopWrites.last_key or "none")),
          "schema")

      local ruleEffectiveness =
          mod.exports.__beta26.Dev.ruleEffectiveness(game)
      local ruleCounts = ruleEffectiveness and ruleEffectiveness.counts or {}
      add("rule_effectiveness",
          tonumber(ruleCounts.errors or 0) == 0,
          string.format("rules=%d delegated=%d changed=%d errors=%d",
              tonumber(ruleCounts.total or 0),
              tonumber(ruleCounts.delegated or 0),
              tonumber(ruleCounts.changed or 0),
              tonumber(ruleCounts.errors or 0)),
          "rules")

      local randomizerIntegrity =
          mod.exports.__beta26.Dev.randomizerIntegrity(game)
      add("randomizer_integrity",
          randomizerIntegrity.status ~= "WARN"
              and randomizerIntegrity.status ~= "ERROR",
          string.format("status=%s scanned=%d violations=%d",
              tostring(randomizerIntegrity.status or "?"),
              tonumber(randomizerIntegrity.scanned or 0),
              tonumber(randomizerIntegrity.violation_count or 0)),
          "randomizer")

      local capabilities = {}
      for _, capability in ipairs({
          "battle_stats", "stat_growth", "identity_dvs",
          "move_category_model", "species_metadata", "species_evolutions",
      }) do
          local ok, value = pcall(
              mod.exports.__beta26.mechanicsCapability, capability, game)
          local owner = "none"
          if ok and type(value) == "table" then
              owner = tostring(value.owner or value.id or value.mode
                  or value.provider or "resolved")
          elseif ok and value ~= nil then
              owner = tostring(value)
          end
          capabilities[#capabilities + 1] = capability .. "=" .. owner
      end

      return {
          api = mod.exports.__beta26.diagnosticsApi,
          build = mod.exports.__beta26.build,
          game = exactIdentity.edition,
          edition = exactIdentity.edition,
          generation = exactIdentity.generation,
          engine_family = exactIdentity.engine_family,
          profile_scope = exactIdentity.profile_scope,
          environment = mod.exports.__beta26.runtimeEnvironment(),
          engine_developer = mod.exports.__beta26.Dev.engineDeveloper == true,
          results = rows,
          assertions = mod.exports.__beta26.Dev.assertions(game),
          capabilities = capabilities,
          hook_health = hookHealth,
          install_health = installHealth,
          gen2_parity = gen2Parity,
          description_parity = descriptionParity,
          lifecycle = lifecycle,
          safe_stop_writes = safeStopWrites,
          rule_effectiveness = ruleEffectiveness,
          randomizer_integrity = randomizerIntegrity,
          field_item_pipeline = fieldPipeline,
          build_provenance = provenance,
          rule_registry = ruleRegistryAudit,
          save_schema_descriptor = saveDescriptorAudit,
          compatibility_contracts = {
              api = mod.exports.__beta26.compatibilityApi,
              capability_versions = compatPublicCopy(
                  mod.exports.__beta26.compatCapabilityVersions),
          },
      }
  end



  return mod.exports.__beta26.Dev.assertions
end
