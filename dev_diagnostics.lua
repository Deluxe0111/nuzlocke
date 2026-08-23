return function(mod, deps)
  deps = deps or {}

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
              check("history_version", tonumber(history.version) == 1, true, tostring(history.version))
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
          check("randomizer_stream_registry", ok and type(streamReport) == "table"
              and streamReport.ok == true and tonumber(streamReport.count) == 5, true,
              ok and table.concat(streamReport.failures or {}, ",") or tostring(streamReport))
      else
          check("randomizer_stream_registry", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerStreamIsolationAudit) == "function" then
          local ok, isolation = pcall(mod.exports.__beta26.randomizerStreamIsolationAudit)
          check("randomizer_stream_isolation", ok and type(isolation) == "table"
              and isolation.ok == true and tonumber(isolation.checked) == 45, true,
              ok and table.concat(isolation.failures or {}, ",") or tostring(isolation))
      else
          check("randomizer_stream_isolation", false, false, "missing")
      end

      if type(mod.exports.__beta26.randomizerSourceMapAudit) == "function" then
          local ok, sourceMaps = pcall(mod.exports.__beta26.randomizerSourceMapAudit)
          check("randomizer_source_maps", ok and type(sourceMaps) == "table"
              and sourceMaps.ok == true and tonumber(sourceMaps.count) == 5, true,
              ok and table.concat(sourceMaps.failures or {}, ",") or tostring(sourceMaps))
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
          check("randomizer_projection_ownership", ok and type(projection) == "table"
              and projection.ok == true and tonumber(projection.count) == 2, true,
              ok and table.concat(projection.failures or {}, ",") or tostring(projection))
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

      if type(mod.exports.__beta26.randomizerCompatibilitySnapshot) == "function" then
          local ok, snapshot = pcall(
              mod.exports.__beta26.randomizerCompatibilitySnapshot, mod.game)
          local rows = ok and type(snapshot) == "table"
              and snapshot.rows or nil
          check("randomizer_external_compat",
              type(rows) == "table" and #rows == 4,
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

      for _, scope in ipairs({ "gen1", "gold", "silver" }) do
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
  
      -- 2.5.59: repeat the dead-fallback source lint in DEV diagnostics so
      -- unreachable fallback dialogue is visible in reports as well as being
      -- blocked by the module-load release gate.
      local deadFallbackAudit = mod.exports.__beta26.deadFallbackAudit
      if type(deadFallbackAudit) == "function" then
          local mainSource = safeDiagnosticSource("main.lua")
          local okFallback, fallbackReport = true, nil
          if mainSource then
              okFallback, fallbackReport = pcall(deadFallbackAudit, mainSource)
          end
          if mainSource and (not okFallback or type(fallbackReport) ~= "table"
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
  return mod.exports.__beta26.Dev.assertions
end
