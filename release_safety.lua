return function(mod, deps)
  deps = deps or {}
  local function safeRead(path)
    local ok, content = pcall(mod.read, mod, path)
    if ok and type(content) == "string" and #content > 0 then
      return content, nil
    end
    return nil, tostring(content)
  end

  -- 2.9.57: canonical source-owner registry. Positive source assertions should
  -- inspect the semantic owner; package-wide negative assertions may inspect
  -- all Lua sources. This avoids assuming implementation still lives in main.lua.
  local SOURCE_OWNERS = {
    main = "main.lua",
    compatibility = "compatibility_runtime.lua",
    diagnostics = "dev_diagnostics.lua",
    rules = "rule_catalog.lua",
    tracker = "encounter_tracker.lua",
    world = "world_building.lua",
    forgiveness = "forgiveness.lua",
    identity = "pokemon_identity.lua",
    species_policy = "species_policy.lua",
    item_policy = "item_policy.lua",
    evolution_policy = "evolution_policy.lua",
    randomizer = "randomizer_runtime.lua",
    interop = "public_interop.lua",
    migration = "save_migration.lua",
    late = "late_runtime.lua",
    run_history = "run_history.lua",
    classic_ui = "classic_ui.lua",
    dev_report = "dev_report.lua",
  }
  local function ownerSource(owner)
    local path = SOURCE_OWNERS[owner]
    if not path then return nil, "unknown source owner: " .. tostring(owner) end
    return safeRead(path)
  end

  -- 2.6.1: executable shape/contract assertions for the two public
  -- compatibility surfaces. This validates only the stable core that exists
  -- before later gameplay-specific aliases are installed.
  -- 2.7.62: cross-generation semantic seam tripwire. Public coverage may
  -- claim RBYGS only when the shipped Gen 2 adapter visibly installs the
  -- corresponding semantic owners. This is intentionally source-based and
  -- promotion-facing; runtime evidence remains edition-specific.
  mod.exports.__beta26.gen2SemanticSeamAudit = function()
    local report = { ok = true, checked = 0, failures = {} }
    local late = safeRead("late_runtime.lua") or ""
    local main = safeRead("main.lua") or ""
    local battle = safeRead("battle_clauses.lua") or ""
    local randomizer = safeRead("randomizer_runtime.lua") or ""
    local required = {
      healing_service = { late, { "function G2.installHealingServiceGate", "semanticSpecial ~= \"healparty\"", "gen2.healing_service_gate" } },
      mart = { late, { "function G2.installMartGate", "gen2.mart_gate" } },
      capture = { late, { "function G2.installCaptureGate", "gen2.capture_gate" } },
      nickname = { late, { "function G2.installNicknameGate", "gen2.nickname_gate" } },
      gift = { late, { "function G2.installGiftTracking", "gen2.gift_tracking" } },
      trade = { late, { "function G2.installTradeGate", "gen2.trade_gate" } },
      static = { late, { "function G2.installStaticTracking", "gen2.static_tracking" } },
      held_item = { late, { "function G2.installHeldItemGate", "gen2.held_item_gate" } },
      field_item = { late, { "function G2.installFieldItemGate", "gen2.field_item_gate" } },
      whiteout = { late, { "function G2.installWhiteoutGate", "gen2.whiteout_gate" } },
      daycare = { main, { "src.core.gen2.Breeding", "Breeding.canDeposit", "src.ui.gen2.DayCareMenu" } },
      pc_lock = { main, { "src.ui.gen2.BoxMenu", "checkSpaceInDestination", "askRelease" } },
      battle_status = { battle, { "src.battle.gen2.Battle", "gen2.sleep", "gen2.status" } },
      battle_stages = { battle, { "gen2.evasion", "gen2.stat_drops", "gen2.setup" } },
      randomizer_gen2 = { randomizer, { "GEN2", "gen2" } },
      battle_party_native = { main, {
        "Gen2 BattleState owns its battle-party lifecycle",
        "and ctx and ctx.battle == true then return result end",
        "src.ui.PartyMenu is a write-through facade on Gen II",
        "PartyMenu.__nuzlockeNoDayCarePickSession2649 = nil",
      } },
      party_item_instance_scope = { late, {
        "intercept the target A press on this exact",
        "chooser.update = function(screen, dt, ...)",
        "function G2.installPartyConsumableExecution",
        "prompt = \"useItem\"",
      } },
      party_wrapper_retirement = { late, {
        "function G2.retirePartyMenuMethodWrappers",
        "gen2.party_menu_native_ownership",
        "retire(\"__nuzlockeUseItemChooserSession27105\", \"new\")",
        "retire(\"__nuzlockeNoDayCarePickSession2649\", \"new\")",
        "retire(\"__nuzlockeUseItemOpenSession27105\", \"openSubmenu\")",
        "retire(\"__nuzlockeNuzInfoFallbackSession2677\", \"submenuItems\")",
      } },
    }
    for id, row in pairs(required) do
      report.checked = report.checked + 1
      local src, needles = row[1], row[2]
      local ok = true
      for _, needle in ipairs(needles) do
        if not src:find(needle, 1, true) then ok = false break end
      end
      if not ok then
        report.ok = false
        report.failures[#report.failures + 1] = id
      end
    end
    report.checked = report.checked + 1
    local retiredPartyInstallers = {
      "function G2.installPartyItemChooserContract",
      "PartyMenu.new = wrapper",
      "PartyMenu.openSubmenu = openWrapper",
      "function G2.installPartySubmenuFallback",
      "PartyMenu.submenuItems = wrapper",
      "gen2.party_nuz_info_fallback",
      "gen2.party_item_chooser",
    }
    for _, needle in ipairs(retiredPartyInstallers) do
      if late:find(needle, 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] =
          "party_method_wrapper_retired:" .. needle
      end
    end
    return report
  end



  -- 2.9.2: battle-stack ownership audit. Protect the distinction between
  -- modern combat/stat providers and Nuzlocke challenge-policy seams. This is
  -- source/static evidence only; it must never promote a combined stack to
  -- Runtime PASS.
  mod.exports.__beta26.battleStackOwnershipAudit = function()
    local main = safeRead("main.lua") or ""
    local late = safeRead("late_runtime.lua") or ""
    local report = { ok=true, checked=0, failures={}, evidence={ semantic=0, source=0 } }
    local function check(id, condition, mode)
      report.checked = report.checked + 1
      report.evidence[mode] = (report.evidence[mode] or 0) + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = id
    end

    -- Adapter metadata has a structured owner; inspect it semantically rather
    -- than matching an exact Lua serialization or field order.
    local adapters = mod.exports.__beta26.compat
      and mod.exports.__beta26.compat.Mods
      and mod.exports.__beta26.compat.Mods.adapters or {}
    local function adapter(id)
      local row = adapters[id]
      if type(row) == "table" and type(row.alias) == "string" then
        row = adapters[row.alias] or row
      end
      return type(row) == "table" and row or {}
    end
    for _, id in ipairs({"g9-battle-engine", "g9-battle-engine-beta"}) do
      local row = adapter(id)
      check(id .. "_declared", next(row) ~= nil, "semantic")
      check(id .. "_gen2_scope", row.games == "GEN2", "semantic")
      check(id .. "_battle_stats", row.battle_stats == "exclusive", "semantic")
      check(id .. "_stat_growth", row.stat_growth == "exclusive", "semantic")
      check(id .. "_identity_dvs", row.identity_dvs == "compose", "semantic")
      check(id .. "_battle_lifecycle", row.battle_lifecycle == "observe", "semantic")
      check(id .. "_held_items", row.held_items == "observe", "semantic")
      check(id .. "_battle_status", row.battle_status == "observe", "semantic")
    end

    -- Runtime implementation boundaries do not yet expose an equivalent
    -- structured descriptor, so these remain narrowly source-reviewed.
    local requiredSource = {
      { "gen2_party_native", main, "Gen2 BattleState owns its battle-party lifecycle" },
      { "gen2_rule_denials_native", late, "Gen II battle-rule denials remain entirely BattleState-owned" },
      { "held_item_trigger_semantic", main, 'mod.hooks:wrap("held_item.trigger"' },
      { "qol_poison_case_specific", main, "POISON SAVE cannot preempt a Nuzlocke Permadeath field-poison faint" },
    }
    for _, row in ipairs(requiredSource) do
      check(row[1], row[2]:find(row[3], 1, true) ~= nil, "source")
    end
    return report
  end

  -- 2.9.9: hook lifecycle/install-order audit. Hook registration must remain
  -- observable, duplicate-required registrations are defects, and fail-soft
  -- optional installers must not turn incidental load order into ownership.
  mod.exports.__beta26.hookLifecycleInstallOrderAudit = function()
    local main=safeRead("main.lua") or ""
    local late=safeRead("late_runtime.lua") or ""
    local report={ok=true,checked=0,failures={},runtimeRequired=true}
    local required={
      {"hook_registry", main, "hookRegistry = { api = 1"},
      {"hook_registry_audit", main, "hookRegistry.audit"},
      {"safe_install", main, "safeInstall"},
      {"attempt_install", main, "attemptInstall"},
      {"feature_health", main, "featureHealth"},
      {"mods_loaded_resolution", main, 'mod.events:on("mods.loaded"'},
      {"late_runtime_module", main, 'loadRequiredModuleChunk("late_runtime.lua")'},
      {"gen2_native_battle_owner", late, "BattleState-owned"},
      {"party_native_owner", main, "Gen2 BattleState owns its battle-party lifecycle"},
      {"presentation_not_gameplay_owner", main, "presentation"},
    }
    for _,row in ipairs(required) do
      report.checked=report.checked+1
      if not row[2]:find(row[3],1,true) then report.failures[#report.failures+1]=row[1] end
    end
    local registry=mod.exports.__beta26.hookRegistry
    if registry and type(registry.audit)=="function" then
      report.checked=report.checked+1
      local ok,res=pcall(registry.audit)
      if not ok or type(res)~="table" or res.ok~=true then report.failures[#report.failures+1]="live_hook_registry_audit" end
    end
    report.ok=#report.failures==0
    return report
  end

  -- 2.9.9: edition-capability and failure-policy reconciliation. Edition
  -- support is explicit and evidence remains edition-specific. Unknown custom
  -- metadata generally fails open; durable transaction/schema ambiguity and
  -- policy-evaluator exceptions fail closed where guessing could corrupt a run.
  mod.exports.__beta26.editionCapabilityFailurePolicyAudit = function()
    local main=safeRead("main.lua") or ""
    local manifest=safeRead("manifest.json") or ""
    local migration=safeRead("save_migration.lua") or ""
    local randomizer=safeRead("randomizer_runtime.lua") or ""
    local speciesPolicy=safeRead("species_policy.lua") or ""
    local compatibilityRuntime=safeRead("compatibility_runtime.lua") or ""
    local report={ok=true,checked=0,failures={},runtimeRequired=true}
    local required={
      {"manifest_red", manifest, '"red"'}, {"manifest_blue", manifest, '"blue"'},
      {"manifest_yellow", manifest, '"yellow"'}, {"manifest_gold", manifest, '"gold"'},
      {"manifest_silver", manifest, '"silver"'}, {"manifest_crystal", manifest, '"crystal"'},
      {"runtime_gen2_detector", main, "runtimeIsGen2"},
      {"unknown_type_fail_open", speciesPolicy, "Unknown truly custom type schemas still fail open"},
      {"unknown_bst_fail_open", speciesPolicy, "Unknown or incomplete schemas fail open"},
      {"unknown_gym_fail_open", main, "unknown Gym: fail open"},
      {"newer_tx_fail_closed", migration, "newer_transaction"},
      {"policy_exception_fail_closed", main, "policy_exception_did_not_fail_closed"},
      {"unsupported_stack_explicit", compatibilityRuntime, "this forced stack is unsupported"},
      {"runtime_evidence_edition_specific", randomizer, "runtimeCertified"},
    }
    for _,row in ipairs(required) do
      report.checked=report.checked+1
      if not row[2]:find(row[3],1,true) then report.failures[#report.failures+1]=row[1] end
    end
    report.editions={red="mature",blue="mature",yellow="mature",gold="beta",silver="beta",crystal="alpha"}
    report.policy={unknown_metadata="fail_open",durable_ambiguity="fail_closed",policy_exception="fail_closed",optional_install="fail_soft"}
    report.ok=#report.failures==0
    return report
  end

  -- 2.9.8: cross-rule interaction matrix. This is a source/static contract
  -- audit: it checks that high-risk combinations converge on shared semantic
  -- policy surfaces instead of installing a second mutation owner.
  mod.exports.__beta26.ruleInteractionMatrixAudit = function()
    local main=safeRead("main.lua") or ""
    local late=safeRead("late_runtime.lua") or ""
    local randomizer=safeRead("randomizer_runtime.lua") or ""
    local interop=safeRead("public_interop.lua") or ""
    local speciesPolicy=safeRead("species_policy.lua") or ""
    local report={ok=true,checked=0,failures={},runtimeRequired=true}
    local required={
      {"permadeath_healing", main, "nuzlockeDead"},
      {"one_per_area_provenance", late, "pokemonProvenance"},
      {"type_lock_normalized_facts", speciesPolicy, "getSpeciesFacts"},
      {"maximum_bst_normalized_facts", main, "maximumBst"},
      {"level_cap_provider_compose", main, "composeLevelCap"},
      {"external_item_semantic_seam", main, "item_use"},
      {"external_shop_semantic_seam", interop, "purchase_commit"},
      {"randomizer_ownership_registry", randomizer, "randomizerSubsystemOwnership"},
      {"randomizer_persisted_source_maps", randomizer, "sourceMaps"},
      {"gen2_native_battle_denials", late, "Gen II battle-rule denials remain entirely BattleState-owned"},
      {"shiny_clause_separate_policy", main, "shiny_clause"},
      {"difficulty_species_facts", main, "Difficulty.speciesTypes"},
    }
    for _,row in ipairs(required) do
      report.checked=report.checked+1
      if not row[2]:find(row[3],1,true) then report.failures[#report.failures+1]=row[1] end
    end
    report.matrix={
      "Permadeath x healing/services","One Per Area x acquisition provenance",
      "Type Locke x transformed/custom types","Maximum BST x Randomizer",
      "No Buying/Selling x external shops","Level Caps x trainer-level providers",
      "Hardcore/battle rules x QoL","Randomizer x expanded species",
      "Shiny Clause x shiny ownership","Gen-II battle rules x native party routing",
    }
    report.ok=#report.failures==0
    return report
  end

  -- 2.9.8: save migration/idempotence audit. Presence and value remain
  -- separate facts; schema is committed last; dry-runs use isolated shadow
  -- copies; transaction recovery must remain exactly-once/fail-closed.
  mod.exports.__beta26.saveMigrationIdempotenceAudit = function()
    local src=safeRead("save_migration.lua") or ""
    local main=safeRead("main.lua") or ""
    local report={ok=true,checked=0,failures={},runtimeRequired=true}
    local required={
      {"shadow_store", src, "saveUpgrade.newShadowStore"},
      {"structural_equality", src, "shadowValuesEqual"},
      {"false_presence_preservation", src, "copyPresentValue"},
      {"schema_marker_last", src, "schema marker LAST"},
      {"shadow_copy_isolation", src, "shadowCopyIsolation"},
      {"transaction_payload_fingerprint", src, "payload_fingerprint"},
      {"transaction_payload_mismatch", src, "transaction_payload_mismatch"},
      {"receipt_payload_mismatch", src, "receipt_payload_mismatch"},
      {"newer_transaction_fail_closed", src, "newer_transaction"},
      {"save_schema_descriptor", main, "saveSchemaDescriptor"},
      {"schema_value_selector", main, "schemaTxnValue"},
    }
    for _,row in ipairs(required) do
      report.checked=report.checked+1
      if not row[2]:find(row[3],1,true) then report.failures[#report.failures+1]=row[1] end
    end
    local upgrade=mod.exports.__beta26.saveUpgrade
    if upgrade and type(upgrade.audit)=="function" then
      report.checked=report.checked+1
      local ok,res=pcall(upgrade.audit)
      if not ok or type(res)~="table" or res.ok~=true then report.failures[#report.failures+1]="save_upgrade_audit" end
    end
    local tx=mod.exports.__beta26.GameplayTransactions
    if tx and type(tx.selfTest)=="function" then
      report.checked=report.checked+1
      local ok,res=pcall(tx.selfTest)
      if not ok or type(res)~="table" or res.ok~=true then report.failures[#report.failures+1]="transaction_exactly_once_selftest" end
    end
    report.ok=#report.failures==0
    return report
  end

  -- 2.9.7: DEV/diagnostics completeness + lifecycle-contract audit. Passive
  -- diagnostics must remain observational, while installation/ownership and
  -- durable persistence stay in their explicit lifecycle stages.
  mod.exports.__beta26.diagnosticsLifecycleContractAudit = function()
    local main=safeRead("main.lua") or ""
    local dev=safeRead("dev_diagnostics.lua") or ""
    local reportSrc=safeRead("dev_report.lua") or ""
    local randomizer=safeRead("randomizer_runtime.lua") or ""
    local report={ok=true,checked=0,failures={},runtimeRequired=true}
    local required={
      {"diagnostics_api", main, "diagnosticsApi"},
      {"dev_stored_state", dev, "storedStateAudit"},
      {"dev_randomizer_stream", dev, "randomizerStreamRegistryAudit"},
      {"dev_randomizer_constraints", dev, "randomizerConstraintDiagnosticAudit"},
      {"dev_shiny", reportSrc, "Dev.shinyDiagnostics"},
      {"dev_localization", reportSrc, "Dev.localizationDiagnostics"},
      {"dev_lifecycle_report", reportSrc, "Dev.lifecycleReport"},
      {"diagnostic_evidence_warning", reportSrc, "SELF-TEST PASS is diagnostic evidence, not a full RUNTIME PASS"},
      {"randomizer_read_only_regression", randomizer, "sourceMapsUnchanged=#mutated == 0"},
      {"randomizer_runtime_uncertified", randomizer, "runtimeCertified=false"},
      {"ownership_resolution", randomizer, "randomizerSubsystemOwnership"},
      {"build_provenance", main, "buildProvenance"},
    }
    for _,row in ipairs(required) do
      report.checked=report.checked+1
      if not row[2]:find(row[3],1,true) then report.failures[#report.failures+1]=row[1] end
    end
    -- A passive diagnostic source must not directly call the Randomizer's
    -- mapping materializers or RNG primitives. Named self-tests may invoke
    -- exported read-only audits, but not choose/materialize gameplay results.
    local forbidden={"randomizerSeededIndex(","randomizerSeededIndexFor(","math.random(","love.math.random("}
    for _,needle in ipairs(forbidden) do
      report.checked=report.checked+1
      if dev:find(needle,1,true) then report.failures[#report.failures+1]="diagnostic_mutation_risk:"..needle end
    end
    report.lifecycle={"Discover","Normalize","Resolve","Install","Freeze","Observe","Persist"}
    report.ok=#report.failures==0
    return report
  end

  -- 2.9.6: final static Randomizer contract audit. This intentionally checks
  -- the complete owned subsystem vocabulary, deterministic/persisted mapping
  -- contract, ownership delegation boundaries, and the two still-unresolved
  -- Gen-II projection diagnostics without converting static evidence into a
  -- Runtime PASS.
  mod.exports.__beta26.finalRandomizerStaticAudit = function()
    local randomizer = safeRead("randomizer_runtime.lua") or ""
    local main = safeRead("main.lua") or ""
    local dev = safeRead("dev_diagnostics.lua") or ""
    local report = { ok=true, checked=0, failures={}, runtimeRequired=true,
      unresolvedRuntime={"GEN1_FIELD_ITEMS","GEN2_TRAINERS","GEN2_FIELD_ITEMS"} }
    local required = {
      {"algorithm_v1", randomizer, "Randomizer.algorithmVersion = 1"},
      {"starter", randomizer, "STARTER"}, {"encounters", randomizer, "ENCOUNTERS"},
      {"field_items", randomizer, "FIELD_ITEMS"}, {"learnsets", randomizer, "LEARNSETS"},
      {"trainers", randomizer, "TRAINERS"}, {"evolutions", randomizer, "EVOLUTIONS"},
      {"shops", randomizer, "SHOPS"}, {"tms", randomizer, "TMS"},
      {"tm_locations", randomizer, "TM_LOCATIONS"}, {"gift_items", randomizer, "GIFT_ITEMS"},
      {"persisted_source_maps", randomizer, "RANDOMIZER_SOURCE_MAPS"},
      {"stream_registry", randomizer, "RANDOMIZER_STREAM_ORDER"},
      {"seeded_index_export", randomizer, "randomizerSeededIndexFor"},
      {"whole_regression", randomizer, "randomizerWholeRegressionAudit"},
      {"runtime_matrix", randomizer, 'runtimeMatrixRequired={"RED","BLUE","YELLOW","GOLD","SILVER","CRYSTAL"}'},
      {"runtime_not_certified", randomizer, "runtimeCertified=false"},
      {"ownership_surface", randomizer, "randomizerSubsystemOwnership"},
      {"gen2_trainer_diagnostic", randomizer, "auditGen2TrainerRandomizerPipeline"},
      {"rby_field_diagnostic", main, "auditRbyFieldItemPipeline"},
      {"gen2_field_diagnostic", main, "auditGen2FieldItemPipeline"},
    }
    for _, row in ipairs(required) do
      report.checked=report.checked+1
      if not row[2]:find(row[3],1,true) then report.failures[#report.failures+1]=row[1] end
    end
    report.ok=#report.failures==0
    return report
  end

  -- 2.9.5: compatibility-registry reconciliation. This is deliberately
  -- source/static: it protects target identity, manifest signaling and explicit
  -- exclusions without converting detection into gameplay ownership.
  mod.exports.__beta26.compatibilityRegistryReconciliationAudit = function()
    local report = { ok=true, checked=0, failures={} }
    local main = safeRead("main.lua") or ""
    local manifest = safeRead("manifest.json") or ""
    local requiredMain = {
      'modern_party_ui = {', 'qol_toggles = {', 'wonder_trade = {',
      '["g9-battle-engine"] = {', '["g9-battle-engine-beta"] = {',
      'delta_type = {', 'dex_overflow = {', 'safari_all = {',
      'kanto_ascendant = {', '["kanto-reforged"] = {',
      '["vanilla-plus"] = {', 'double_battles = {', 'blackjack_corner = {', 'free_fly = {',
      'next_encounter_spawner = {', 'pokeball_colors = {', '["gen1-better-menus"] = {',
      'level_match = {', 'modern_start_menu_ui = {',
    }
    for _, token in ipairs(requiredMain) do
      report.checked = report.checked + 1
      if not main:find(token, 1, true) then report.failures[#report.failures+1] = "missing_adapter:" .. token end
    end
    local requiredOptional = {
      '"modern_party_ui"', '"qol_toggles"', '"wonder_trade"',
      '"g9-battle-engine"', '"g9-battle-engine-beta"', '"delta_type"',
      '"dex_overflow"', '"safari_all"', '"useful_bag"',
      '"modern_bag_ui"', '"bag_sort"', '"potato_voxel"',
      '"PokePCFollowers_VoxelMerge"', '"FOLLOWERS_EX"',
      '"double_battles"', '"free_fly"',
    }
    for _, token in ipairs(requiredOptional) do
      report.checked = report.checked + 1
      if not manifest:find(token, 1, true) then report.failures[#report.failures+1] = "missing_optional:" .. token end
    end
    report.checked = report.checked + 2
    if manifest:find('"kanto_ascendant"', 1, true) then report.failures[#report.failures+1] = "conflict_advertised:kanto_ascendant" end
    if manifest:find('"SHINY_POKEMON"', 1, true) then report.failures[#report.failures+1] = "reciprocal_cycle:SHINY_POKEMON" end
    report.ok = #report.failures == 0
    return report
  end

  -- 2.9.29: trainer-transform and START-menu semantic composition audit.
  -- External trainer modifiers may own orthogonal dimensions such as levels,
  -- moves and roster cardinality while Random Trainers owns species identity.
  mod.exports.__beta26.trainerTransformCompositionAudit = function()
    local main = safeRead("main.lua") or ""
    local randomizer = safeRead("randomizer_runtime.lua") or ""
    local report = { ok=true, checked=0, failures={} }
    local required = {
      { "level_match_target", main, 'level_match = {' },
      { "level_match_version", main, 'tested = "0.7.0"' },
      { "dimension_contract", main, 'trainer_party = "compose_by_dimension"' },
      { "modern_start_target", main, 'modern_start_menu_ui = {' },
      { "modern_start_version", main, 'tested = "0.1.14"' },
      { "stable_start_id", main, 'id = "nuzlocke.menu"' },
      { "composed_roster_primary", randomizer, 'transform the COMPOSED incoming roster' },
      { "resolved_shape_final", randomizer, 'authoritative output shape is `resolved`' },
    }
    for _, row in ipairs(required) do
      report.checked = report.checked + 1
      if not row[2]:find(row[3], 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = row[1]
      end
    end
    return report
  end

  -- 2.9.3: healing/service ownership audit. Service identity, item healing,
  -- post-battle convenience healing and story healing are separate semantic
  -- dimensions. This is source/static evidence only.
  mod.exports.__beta26.healingServiceOwnershipAudit = function()
    local main = safeRead("main.lua") or ""
    local late = safeRead("late_runtime.lua") or ""
    local interop = safeRead("public_interop.lua") or ""
    local report = { ok=true, checked=0, failures={} }
    local required = {
      { "gen2_service_gate", late, "function G2.installHealingServiceGate" },
      { "gen2_healparty_semantic", late, 'semanticSpecial ~= "healparty"' },
      { "center_rule_separate", late, 'kind == "center" and "no_poke_center"' },
      { "mom_rule_separate", late, 'kind == "mom" and "no_mom_heal"' },
      { "story_heals_preserved", late, "heals elsewhere" },
      { "field_heal_separate", main, 'key == "no_field_healing"' },
      { "battle_heal_separate", main, 'mod.save:get("no_healing_items", false)' },
      { "service_provider_contract", interop, 'provider="service ownership"' },
      { "qol_healing_compose", main, 'healing = "compose"' },
      { "survivor_healing_contract", main, 'healing = "compose_survivors"' },
      { "dead_mon_reassertion", main, "cannot revive a durable nuzlockeDead mon" },
    }
    for _, row in ipairs(required) do
      report.checked = report.checked + 1
      if not row[2]:find(row[3], 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = row[1]
      end
    end
    return report
  end

  -- 2.8.33: presentation-renderer isolation. Nuzlocke challenge logic must
  -- remain below/alongside renderer mods rather than seizing their world or
  -- battle presentation owners. This is provider-neutral: it protects
  -- PotatoVoxel today and other render.compose / Gen2BattleState providers
  -- without hardcoding their implementation.
  mod.exports.__beta26.presentationRendererIsolationAudit = function()
    local files = {
      "main.lua", "late_runtime.lua", "classic_ui.lua",
      "nuzlocke_ui_system.lua", "modern_ui_integration.lua",
    }
    local report = { ok=true, checked=0, failures={} }
    local combined = ""
    for _, path in ipairs(files) do
      local src = safeRead(path)
      if type(src) == "string" then
        combined = combined .. "\n-- " .. path .. "\n" .. src
      end
    end
    local forbidden = {
      'mod.hooks:wrap("render.compose"',
      'screens:register("Gen2BattleState"',
      "BattleState.drawWidescreen =",
      "BattleState.drawPic =",
      "function BattleState:drawWidescreen",
      "function BattleState:drawPic",
    }
    for _, needle in ipairs(forbidden) do
      report.checked = report.checked + 1
      if combined:find(needle, 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = "renderer_owner:" .. needle
      end
    end
    -- Gen I Battle Menu UI may remain on the public battle.overlay seam, but
    -- Nuzlocke itself must not replace BattleState.draw: renderer mods commonly
    -- wrap that method and still call the native/public hook chain underneath.
    report.checked = report.checked + 1
    if combined:find("BattleState.draw =", 1, true)
        or combined:find("function BattleState:draw()", 1, true) then
      report.ok = false
      report.failures[#report.failures + 1] = "battle_draw_owner"
    end
    return report
  end


  -- 2.8.36: full built-in shiny presentation + provider isolation. A compatible
  -- external provider owns generation AND visuals immediately; otherwise
  -- Nuzlocke uses public shiny.roll / battle.started identity plus sanctioned
  -- pokemon.sprite, pokemon.icon and battle.overlay presentation seams.
  mod.exports.__beta26.shinyProviderIsolationAudit = function()
    local main = safeRead("main.lua") or ""
    local compatibility = ownerSource("compatibility") or ""
    local late = safeRead("late_runtime.lua") or ""
    local catalog = safeRead("rule_catalog.lua") or ""
    local manifest = safeRead("manifest.json") or ""
    local report = { ok=true, checked=0, failures={} }
    -- Shiny maintained fork declares nuzlocke as an optional dependency; preserve one-way load ordering.
    -- Nuzlocke must not declare SHINY_POKEMON back or current Gen1Recomp will
    -- reject the mutual optional-dependency cycle. Compatibility remains live
    -- through the provider registry/API after Shiny loads.
    report.checked = report.checked + 1
    if manifest:find('"SHINY_POKEMON"', 1, true) then
      report.ok = false
      report.failures[#report.failures + 1] = "shiny_optional_dependency_cycle"
    end
    local required = {
      { "shiny_target_registry", compatibility, 'SHINY_POKEMON = {' },
      { "modern_party_ui_optional_dependency", manifest, '"modern_party_ui"' },
      { "modern_party_ui_party_stack_contract", main, 'party_controller = "engine_owned"' },
      { "pokepc_optional_dependency", manifest, '"PokePCFollowers_VoxelMerge"' },
      { "followers_ex_optional_dependency", manifest, '"FOLLOWERS_EX"' },
      { "dramatic_shape_optional_dependency", manifest, '"DRAMATIC_SHAPE"' },
      { "shiny_1241_target", compatibility, 'tested = "Stone fork 1.2.41"' },
      { "pokepc_051_target", compatibility, 'PokePCFollowers_VoxelMerge = {' },
      { "followers_ex_1019_target", compatibility, 'FOLLOWERS_EX = {' },
      { "dramatic_shape_190_target", compatibility, 'tested = "1.9.0"' },
      { "battle_art_1100_target", compatibility, 'tested = "1.10.0"' },
      { "battle_cinematics_124_target", compatibility, 'tested = "1.2.4"' },
      { "provider_id_list", main, '"SHINY_POKEMON", "shiny_pokemon", "gen1recomp_shiny_pokemon"' },
      { "provider_live_handle_required", main, 'if liveProvider == nil then return nil end' },
      { "provider_registry_preferred", main, 'public.getProvider, "SHINY_POKEMON"' },
      { "provider_registry_identity", main, 'caps.SHINY_IDENTITY == true' },
      { "provider_registry_presentation", main, 'caps.SHINY_PRESENTATION == true' },
      { "provider_api_v1", main, 'exports.shiny_pokemon or exports.shiny_compat' },
      { "provider_api_identity", main, 'compat.capability("shiny_identity")' },
      { "provider_api_presentation", main, 'compat.capability("shiny_presentation")' },
      { "provider_legacy_identity_fallback", main, 'type(exports.isShiny) == "function"' },
      { "provider_legacy_roll_fallback", main, 'type(exports.rollShiny) == "function"' },
      { "provider_owner_gate", main, 'mod.exports.__beta26.externalShinyOwns = function(game)' },
      { "public_gen2_roll", main, 'mod.hooks:wrap("shiny.roll"' },
      { "gen2_decision_handoff", main, "consumeGen2ShinyDecision" },
      { "gen1_event_roll", main, 'mod.events:on("battle.started"' },
      { "gen1_event_shape_fallback", main, 'payload and (payload.battle or payload)' },
      { "rate_rule", catalog, 'key = "shiny_rate_mode"' },
      { "colors_rule", catalog, 'key = "shiny_colors"' },
      { "intro_rule", catalog, 'key = "shiny_intro"' },
      { "sprite_seam", late, 'mod.hooks:wrap("pokemon.sprite"' },
      { "icon_seam", late, 'mod.hooks:wrap("pokemon.icon"' },
      { "overlay_seam", late, 'mod.hooks:wrap("battle.overlay"' },
      { "external_visual_guard", late, 'if externalOwns() then return' },
      { "external_controls_hidden", main, 'externalShinyControl = okProvider and provider ~= nil' },
      { "gen2_shiny_flash_safety", late, 'nextEvent.kind == "shiny-flash"' },
      { "gen2_pic_restore", late, 'self.picHidden.enemy = false' },
      { "private_palette_cache_signature", late, 'shinyPaletteCacheSignature(species)' },
      { "private_palette_cache_engine_owned_note", late, 'engine Renderer/Assets resources' },
    }
    for _, row in ipairs(required) do
      report.checked = report.checked + 1
      if not row[2]:find(row[3], 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = row[1]
      end
    end
    local forbidden = {
      "__nuzlockeShinyPokemonNewWrapper",
      "__nuzlockeShinyBattleStateNewWildWrapper",
      "function Pokemon.new(data, species, level, rng)",
      "function BattleState.newWild(game, species, level, opts)",
      "Gen2BattleState.draw = function",
      "Gen2BattleState.update = function",
      "Assets.invalidate",
      "Assets.reset",
      "Renderer.invalidate",
      "Renderer.reset",
      "PaletteFX.invalidate",
    }
    for _, needle in ipairs(forbidden) do
      report.checked = report.checked + 1
      if late:find(needle, 1, true) or main:find(needle, 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = "constructor_owner:" .. needle
      end
    end
    return report
  end

  -- 2.8.35: shiny-control UX contract. Shiny Clause and Shiny Rate are
  -- adjacent but semantically separate: catch exceptions vs rarity.
  mod.exports.__beta26.shinyControlClarityAudit = function()
    local catalog = safeRead("rule_catalog.lua") or ""
    local report = { ok=true, checked=0, failures={} }
    local clause = catalog:find('key = "shiny_clause"', 1, true)
    local rate = catalog:find('key = "shiny_rate_mode"', 1, true)
    local checks = {
      { "shiny_clause_present", clause ~= nil },
      { "shiny_rate_present", rate ~= nil },
      { "shiny_controls_ordered", clause ~= nil and rate ~= nil and clause < rate },
      { "shiny_controls_adjacent", clause ~= nil and rate ~= nil and rate - clause < 1500 },
      { "clause_catch_wording", catalog:find("CATCH EXCEPTIONS ONLY", 1, true) ~= nil },
      { "rate_rarity_wording", catalog:find("RARITY ONLY", 1, true) ~= nil },
    }
    for _, row in ipairs(checks) do
      report.checked = report.checked + 1
      if not row[2] then
        report.ok = false
        report.failures[#report.failures + 1] = row[1]
      end
    end
    return report
  end


  -- 2.8.31: protect the two Silver-observed Elm text repairs without
  -- coupling them back into the already-working starter award transaction.
  mod.exports.__beta26.gen2StarterTextFinalizationAudit = function()
    local late = safeRead("late_runtime.lua") or ""
    local report = { ok=true, checked=0, failures={} }
    local required = {
      'return self:showRaw(Strings(replacement), stay)',
      'name == "getmonname" and type(commandVmState) == "table"',
      '"elm_received_name_substitution"',
      'rewrittenCmd.species = choiceIndex',
      'mandatory.scriptKey == (ctx and ctx.scriptKey)',
    }
    for _, needle in ipairs(required) do
      report.checked = report.checked + 1
      if not late:find(needle, 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = needle
      end
    end
    return report
  end

  -- 2.7.94: protect the runtime-bisected Random Starter contract. The first
  -- known-bad build (2.7.45) coupled starter eligibility to the shared
  -- generation Species Pool. Starters must remain isolated from that filter
  -- while encounters/trainers/evolutions retain it.
  mod.exports.__beta26.randomStarterSpeciesPoolIsolationAudit = function()
    local randomizer = safeRead("randomizer_runtime.lua") or ""
    local catalog = safeRead("rule_catalog.lua") or ""
    local report = { ok=true, checked=0, failures={} }
    local function expect(id, ok)
      report.checked = report.checked + 1
      if not ok then
        report.ok=false
        report.failures[#report.failures+1]=id
      end
    end
    expect("starter_candidate_pool_isolated",
      randomizer:find('randomSpeciesPoolAllows(def, 0)', 1, true) ~= nil)
    expect("starter_shared_pool_comment",
      randomizer:find('Random Starter deliberately ignores the shared', 1, true) ~= nil)
    expect("species_subsystem_excludes_starter",
      randomizer:find('local function speciesRandomizerConfigured()', 1, true) ~= nil
        and randomizer:find('return mod.save:get("random_encounter_tables", false) == true', 1, true) ~= nil)
    expect("catalog_species_parents_exclude_starter",
      catalog:find('local speciesParents = {\n      "random_encounter_tables", "random_trainers", "random_evolutions",', 1, true) ~= nil)
    return report
  end

  -- 2.7.63: Gen II Tracker MAP must not silently fall back to the Gen I
  -- seeded route catalog, and Difficulty changes must remain pre-confirmed.
  mod.exports.__beta26.gen2TrackerPresentationAudit = function()
    local src = safeRead("classic_ui.lua") or ""
    local required = {
      "local function gen2DisplayOrder",
      "data.gen2Constants",
      "constants.mapOrder",
      "NEW_BARK_TOWN",
      "gen2Allowed",
      "GEN1_SEED_IDS",
      "tracker_map_render",
    }
    local report = { ok = true, checked = #required, failures = {} }
    for _, needle in ipairs(required) do
      if not src:find(needle, 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = "missing " .. needle
      end
    end
    return report
  end

  -- 2.7.64: MOD COMPAT ownership controls must remain capability-backed,
  -- persisted as preferences, confirmation-gated for gameplay-impacting
  -- changes, and wired into actual provider resolution rather than display only.
  mod.exports.__beta26.compatOwnerControlAudit = function()
    local main = safeRead("main.lua") or ""
    local late = safeRead("late_runtime.lua") or ""
    local required = {
      { main, "COMPAT_PROVIDER_CANDIDATES" },
      { main, "compat_owner_preferences" },
      { main, "compatOwnerPreference" },
      { main, "setCompatOwnerPreference" },
      { main, "compatOwnerChoices" },
      { main, 'preference == "nuzlocke" or preference == "engine"' },
      { late, "controlCapability" },
      { late, "ownerProposal" },
      { late, "applyOwnerPreference" },
      { late, 'title = "OWNER WARNING"' },
      { late, 'wasPressed("left")' },
      { late, 'wasPressed("right")' },
    }
    local report = { ok=true, checked=#required, failures={} }
    for _, row in ipairs(required) do
      if not row[1]:find(row[2], 1, true) then
        report.ok=false
        report.failures[#report.failures+1] = "missing " .. row[2]
      end
    end
    return report
  end

  -- 2.7.65: rule availability must remain wired into both configuration
  -- presentation and effective rule reads; edition-only mechanics must not
  -- regress back into every-game rows.
  mod.exports.__beta26.ruleAvailabilitySourceAudit = function()
    local main = safeRead("main.lua") or ""
    local catalog = safeRead("rule_catalog.lua") or ""
    local required = {
      { main, "ruleAvailableForGame" },
      { main, "ruleOperationalState" },
      { main, "hiddenByOperationalContract" },
      { main, 'screens:register("NuzlockeDifficultyReview"' },
      { main, 'difficultyImpactChanges = function' },
      { main, 'proposedId = nextId' },
      { main, '"DIFFICULTY WARNING"' },
      { main, "ruleNativeAvailableForEdition" },
      { catalog, 'key = "overworld_encounters", default = false, nativeEditions = {}, capabilityGate = "overworld_encounters"' },
      { catalog, 'key = "safari_zone_splits", default = 0, nativeEditions = { red=true, blue=true, yellow=true }' },
      { catalog, 'key = "infinite_rare_candies", default = false, rbyOnly = true' },
      { catalog, 'key = "random_starter_trio_typing", default = 0, nativeEditions = { red=true, blue=true, gold=true, silver=true, crystal=true }, capabilityGate = "starter_trio"' },
      { catalog, 'type_lock_secondary=2' },
      { catalog, 'local auditedAllSix = {' },
      { catalog, '"physical_special_split", "badge_boosts", "ohko_clause"' },
      { catalog, 'byKey.evasion_clause.suppressedBy' },
      { catalog, 'capabilityGate = "pokegear_radio"' },
      { catalog, 'capabilityGate = "cherrygrove_tour"' },
      { catalog, 'key = "shop_restrictions", default = 0' },
      { main, 'CURRENT_SAVE_SCHEMA = 5' },
      { main, 'pendingNewGameRules.shop_restrictions' },
      { main, 'mod.save:set("shop_restrictions"' },
      { catalog, '"gold_bug_contest_mode",' },
      { catalog, 'requiresRule' },
      { catalog, 'requiresAll' },
      { catalog, 'suppressedBy' },
    }
    local report = { ok=true, checked=#required, failures={} }
    for _, row in ipairs(required) do
      if not row[1]:find(row[2], 1, true) then
        report.ok=false
        report.failures[#report.failures+1] = "missing " .. row[2]
      end
    end
    return report
  end

  -- 2.7.70: the old always-on battle encounter badge is intentionally
  -- retired, while post-failure encounter feedback is consequential and must
  -- remain available at every World Building tier.
  mod.exports.__beta26.encounterFeedbackContractAudit = function()
    local main = safeRead("main.lua") or ""
    local catalog = safeRead("rule_catalog.lua") or ""
    local world = safeRead("world_building.lua") or ""
    local report = { ok=true, checked=0, failures={} }
    local function expect(id, ok)
      report.checked = report.checked + 1
      if not ok then
        report.ok=false
        report.failures[#report.failures+1]=id
      end
    end
    expect("indicator_rule_retired",
      catalog:find('key = "encounter_spend_indicator"', 1, true) == nil)
    expect("battle_hud_not_installed",
      main:find("installEncounterSpendHUD", 1, true) == nil
        and main:find("ui.encounter_spend_hud", 1, true) == nil)
    expect("semantic_projection_retained",
      main:find("encounterSpendIndicator = function", 1, true) ~= nil)
    expect("failed_feedback_helper",
      main:find("emitFailedEncounterFeedback", 1, true) ~= nil)
    expect("failed_feedback_called",
      main:find("emitFailedEncounterFeedback(", 1, true) ~= nil
        and main:find("row.game or currentGame, row.area", 1, true) ~= nil)
    expect("failed_feedback_critical",
      main:find('worldMechanic(game, "failed:" .. tostring(area), t1, t2, t3, true)', 1, true) ~= nil)
    expect("failed_catalog_plain",
      world:find('failed_encounter = {', 1, true) ~= nil
        and world:find("Encounter failed. That area's chance is spent.", 1, true) ~= nil)
    return report
  end

  -- 2.7.71: generic T3 World Building messages must not append a
  -- run-summary page. Recap context belongs only on explicitly recap-oriented
  -- surfaces/events.
  mod.exports.__beta26.t3RunContextIsolationAudit = function()
    local world = safeRead("world_building.lua") or ""
    local report = { ok=true, checked=2, failures={} }
    if world:find("runContextLine", 1, true) ~= nil then
      report.ok=false
      report.failures[#report.failures+1]="runContextLine still present"
    end
    if world:find('text = tostring(text) .. "\\f" .. context', 1, true) ~= nil then
      report.ok=false
      report.failures[#report.failures+1]="generic T3 context page append still present"
    end
    return report
  end

  -- 2.7.72: shared UI must degrade explicit WIDE safely and must not
  -- re-fit Tracker text whose selected-row marquee is already finalized.
  mod.exports.__beta26.sharedUiOwnershipAudit = function()
    local ui = safeRead("nuzlocke_ui_system.lua") or ""
    local classic = safeRead("classic_ui.lua") or ""
    local report = { ok=true, checked=4, failures={} }
    local function expect(id, ok)
      if not ok then report.ok=false; report.failures[#report.failures+1]=id end
    end
    expect("wide_no_forced_304", ui:find('elseif mode == "wide" then',1,true) == nil)
    expect("wide_claim_resolved",
      ui:find('(mode == "adaptive" or mode == "wide")',1,true) ~= nil
      and ui:find('state.layoutContext.mode == "wide"',1,true) ~= nil)
    expect("row_prefitted_optout", ui:find("row.preFitted ~= true",1,true) ~= nil)
    expect("tracker_selected_prefitted",
      select(2, classic:gsub("preFitted=selected","")) >= 2)
    return report
  end

  mod.exports.__beta26.difficultyImpactWarningAudit = function()
    local src = safeRead("main.lua") or ""
    local required = {
      "difficultyImpactChanges",
      "DIFFICULTY WARNING",
      "applyDifficultyChange",
      "if yes then applyDifficultyChange() end",
    }
    local report = { ok = true, checked = #required, failures = {} }
    for _, needle in ipairs(required) do
      if not src:find(needle, 1, true) then
        report.ok = false
        report.failures[#report.failures + 1] = "missing " .. needle
      end
    end
    return report
  end

  mod.exports.__beta26.compatContractAudit = function()
    local report = { ok = true, checked = 0, failures = {} }
    local function check(id, condition, detail)
      report.checked = report.checked + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = tostring(id)
        .. (detail and (":" .. tostring(detail)) or "")
    end
    local legacy = mod.exports.nuzlocke_compat
    local modern = mod.exports.nuzlocke
    check("legacy_table", type(legacy) == "table")
    check("legacy_version", type(legacy) == "table"
      and legacy.version == mod.exports.__beta26.compatibilityApi)
    check("legacy_compatible_from", type(legacy) == "table"
      and type(legacy.compatible_from) == "number"
      and legacy.compatible_from <= legacy.version)
    check("legacy_audited_engine", type(legacy) == "table"
      and legacy.audited_recomp == mod.exports.__beta26.recompCompatAudited)
    check("legacy_capabilities", type(legacy) == "table"
      and type(legacy.capabilities) == "table")
    check("legacy_capability_versions", type(legacy) == "table"
      and type(legacy.capability_versions) == "table")
    for _, name in ipairs({
      "getCapabilityVersion", "getEngineProfile", "getCompatibilitySummary",
      "resolveCapability", "hasProviderCapability", "providersWithCapability",
      "listProviders", "providerCount",
    }) do
      check("legacy_fn_" .. name, type(legacy) == "table"
        and type(legacy[name]) == "function")
    end

    local capabilitySet = {}
    for _, capability in ipairs(type(legacy) == "table"
        and legacy.capabilities or {}) do
      capabilitySet[tostring(capability)] = true
      check("capability_version_" .. tostring(capability),
        type(legacy) == "table" and type(legacy.capability_versions) == "table"
          and legacy.capability_versions[capability] ~= nil)
    end
    if type(legacy) == "table" and type(legacy.capability_versions) == "table" then
      for capability in pairs(legacy.capability_versions) do
        check("capability_advertised_" .. tostring(capability),
          capabilitySet[tostring(capability)] == true)
      end
    end

    if type(legacy) == "table" and type(legacy.getCompatibilitySummary) == "function" then
      local okSummary, summary = pcall(legacy.getCompatibilitySummary)
      check("summary_callable", okSummary and type(summary) == "table")
      if okSummary and type(summary) == "table" then
        check("summary_version", summary.version == legacy.version)
        check("summary_compatible_from", summary.compatible_from == legacy.compatible_from)
        check("summary_audited_engine", summary.audited_recomp == legacy.audited_recomp)
        check("summary_profile", type(summary.engine_profile) == "table")
        check("summary_capability_versions", type(summary.capability_versions) == "table")
        local first = legacy.capabilities and legacy.capabilities[1]
        if first and type(summary.capability_versions) == "table" then
          local original = summary.capability_versions[first]
          summary.capability_versions[first] = 999999
          local okAgain, again = pcall(legacy.getCompatibilitySummary)
          check("summary_defensive_copy", okAgain and type(again) == "table"
            and type(again.capability_versions) == "table"
            and again.capability_versions[first] == original)
        end
      end
    end

    if type(legacy) == "table" and type(legacy.getEngineProfile) == "function" then
      local okProfile, profile = pcall(legacy.getEngineProfile, legacy.audited_recomp)
      check("engine_profile_callable", okProfile and type(profile) == "table")
      if okProfile and type(profile) == "table" then
        check("engine_profile_api", profile.api == 2)
        check("engine_profile_save", profile.save_format == 5)
        local generation = profile.generation
        check("engine_profile_generation", type(generation) == "table"
          and generation.gen1 == true and generation.gold == true)
        profile.api = 999999
        local okAgain, again = pcall(legacy.getEngineProfile, legacy.audited_recomp)
        check("engine_profile_defensive_copy", okAgain
          and type(again) == "table" and again.api == 2)
      end
    end

    if type(legacy) == "table" and type(legacy.listProviders) == "function"
        and type(legacy.providerCount) == "function" then
      local okList, providers = pcall(legacy.listProviders)
      local okCount, count = pcall(legacy.providerCount)
      check("provider_inventory_shape", okList and type(providers) == "table"
        and okCount and type(count) == "number" and count == #providers)
      if okList and type(providers) == "table" then
        local lastId, seen = nil, {}
        for index, provider in ipairs(providers) do
          local id = type(provider) == "table" and tostring(provider.id or "") or ""
          check("provider_" .. index .. "_table", type(provider) == "table")
          check("provider_" .. index .. "_id", id ~= "")
          check("provider_" .. index .. "_capabilities", type(provider) == "table"
            and type(provider.capabilities) == "table")
          check("provider_" .. index .. "_unique", id ~= "" and seen[id] ~= true)
          check("provider_" .. index .. "_sorted", lastId == nil or lastId < id)
          seen[id], lastId = true, id
        end
      end
    end

    local contract = type(legacy) == "table" and legacy.contract or nil
    check("contract_table", type(contract) == "table")
    check("contract_owner", type(contract) == "table" and contract.owner == "nuzlocke")
    check("contract_stability", type(contract) == "table" and contract.stability == "stable")
    check("contract_compat_api", type(contract) == "table"
      and contract.compatibility_api == mod.exports.__beta26.compatibilityApi)
    check("contract_surfaces", type(contract) == "table" and type(contract.surfaces) == "table")
    if type(contract) == "table" and type(contract.surfaces) == "table" then
      for _, key in ipairs({"nuzlocke_compat", "nuzlocke", "acquisitionPolicy",
          "itemPolicy", "registry", "experience", "pcPolicy",
          "encounterPolicy", "content", "autoCompat"}) do
        local row = contract.surfaces[key]
        check("contract_surface_" .. key, type(row) == "table"
          and row.owner == "nuzlocke" and type(row.stability) == "string"
          and type(row.version) == "number")
      end
    end
    check("contract_metadata_fn", type(legacy) == "table"
      and type(legacy.getContractMetadata) == "function")
    if type(legacy) == "table" and type(legacy.getContractMetadata) == "function" then
      local okMeta, meta = pcall(legacy.getContractMetadata)
      check("contract_metadata_callable", okMeta and type(meta) == "table"
        and type(meta.surfaces) == "table")
      if okMeta and type(meta) == "table" and type(meta.surfaces) == "table" then
        local row = meta.surfaces.nuzlocke_compat
        if type(row) == "table" then row.owner = "mutated" end
        local okAgain, again = pcall(legacy.getContractMetadata)
        check("contract_metadata_defensive_copy", okAgain and type(again) == "table"
          and type(again.surfaces) == "table"
          and type(again.surfaces.nuzlocke_compat) == "table"
          and again.surfaces.nuzlocke_compat.owner == "nuzlocke")
      end
    end

    check("modern_table", type(modern) == "table")
    check("modern_api", type(modern) == "table" and modern.api == 1)
    check("modern_build", type(modern) == "table"
      and modern.build == mod.exports.__beta26.build)
    local legacyFloor = type(legacy) == "table" and legacy.compatible_from or nil
    check("modern_compatibility", type(modern) == "table"
      and type(modern.compatibility) == "table"
      and modern.compatibility.api == mod.exports.__beta26.compatibilityApi
      and modern.compatibility.compatible_from == legacyFloor
      and modern.compatibility.audited_recomp == mod.exports.__beta26.recompCompatAudited)
    check("modern_interop", type(modern) == "table"
      and type(modern.interop) == "table"
      and type(modern.interop.registerProvider) == "function"
      and type(modern.interop.unregisterProvider) == "function"
      and type(modern.interop.resolveCapability) == "function")
    for _, name in ipairs({
      "acquisitionPolicy", "itemPolicy", "registry", "experience",
      "pcPolicy", "encounterPolicy", "content", "autoCompat",
    }) do
      check("modern_table_" .. name, type(modern) == "table"
        and type(modern[name]) == "table")
    end
    check("legacy_interop_alias", type(legacy) == "table"
      and legacy.interop == modern)
    return report
  end

  -- 2.6.3: shipped public documentation must stay release-focused and must
  -- not reference internal project-continuity terminology. The prohibited
  -- transition-management term is assembled below so it does not appear
  -- literally anywhere in the player package itself.
  mod.exports.__beta26.publicDocumentationAudit = function()
    local report = { ok = true, checked_files = 0, skipped_files = {}, failures = {} }
    local paths = {
      "README.md", "CHANGELOG.md", "RELEASE_NOTES.md", "docs/API.md",
      "docs/COMPATIBILITY.md", "docs/DOCUMENTATION_CHANGELOG.md",
      "docs/FEATURE_CONFIDENCE.md", "docs/USER_GUIDE.md",
    }
    local forbidden = {
      "project " .. "hand" .. "off", "project " .. "hand" .. "-off",
      "handoff document", "hand-off document",
      "internal coordination", "internal-coordination", "coordination provenance",
      "coordination sources", "project rules", "recurring-session review",
      "vertical-slice review", "review timeboxes", "stopping rules",
      "open questions ledger", "unreviewed surface", "cleared investigation",
      "brainstorm intake", "cold-read review", "definition of done",
      "regression retrospectives", "development-process changes",
      "process records remain", "process/review workflow",
      "review/process consolidation",
      "project roadmap", "project-roadmap", "project policy", "project owner",
      "project records", "development records", "suggestion ledger",
      "master workstreams", "backlog governance", "audit governance",
      "source of truth for external-mod",
      "documentation hygiene", "shipped-document hygiene",
      "public package terminology", "historical release text",
    }
    for _, path in ipairs(paths) do
      local content, err = safeRead(path)
      if content then
        report.checked_files = report.checked_files + 1
        local lower = string.lower(content)
        for _, phrase in ipairs(forbidden) do
          if string.find(lower, phrase, 1, true) then
            report.ok = false
            report.failures[#report.failures + 1] = path .. ":forbidden-public-doc-term"
          end
        end
      else
        report.skipped_files[#report.skipped_files + 1] = path .. ":" .. tostring(err)
      end
    end
    return report
  end

  -- 2.6.54: package/document/API drift checks are read-only and fail-soft
  -- when the launcher does not permit source introspection.
  mod.exports.__beta26.packageDriftAudit = function()
    local report = { ok = true, checked = 0, failures = {}, skipped = {} }
    local function check(id, condition, detail)
      report.checked = report.checked + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = tostring(id)
        .. (detail and (":" .. tostring(detail)) or "")
    end
    local buildText = tostring(mod.exports.__beta26.build)
    local mainSource = safeRead("main.lua")
    if mainSource then
      local firstLine = mainSource:match("^%s*([^\r\n]+)") or ""
      check("main_source_header",
        firstLine == "-- Nuzlocke " .. buildText
          or firstLine:find("-- Nuzlocke " .. buildText .. " — ", 1, true) == 1,
        firstLine)
    else
      report.skipped[#report.skipped + 1] = "main.lua"
    end

    local manifest = safeRead("manifest.json")
    if manifest then
      local manifestVersion = manifest:match('"version"%s*:%s*"([^"]+)"')
      check("manifest_version", manifestVersion == buildText, manifestVersion)
      check("manifest_mod_api", manifest:find('"api"%s*:%s*2') ~= nil)
      check("manifest_engine_range", manifest:find('"game_version"%s*:%s*">=0%.2%.24 <2%.0%.0"') ~= nil)
      local expectedGames = deps.expectedGames or {}
      local cursor = 1
      for _, game in ipairs(expectedGames) do
        local at = manifest:find('"' .. tostring(game) .. '"', cursor, true)
        check("manifest_game_" .. tostring(game), at ~= nil)
        if at then cursor = at + 1 end
      end
      local gameCount = 0
      local gamesBlock = manifest:match('"games"%s*:%s*%[([^%]]*)%]') or ""
      for _ in gamesBlock:gmatch('"[^"]+"') do gameCount = gameCount + 1 end
      check("manifest_game_count", gameCount == #expectedGames,
        string.format("got=%d expected=%d", gameCount, #expectedGames))
    else
      report.skipped[#report.skipped + 1] = "manifest.json"
    end

    -- 2.7.82: document roles own their header contracts. Release Safety is a
    -- build-time process check, so it accepts the package's maintained role
    -- formats rather than assuming every document begins with one obsolete
    -- universal heading shape.
    local function docHeaderMatches(path, firstLine, content)
      -- Role documents may intentionally begin with a Current-build HTML
      -- marker. Validate the first actual Markdown heading rather than line
      -- position; the marker itself is checked independently below.
      local firstHeading = content:match("[\r\n]*%s*(#[^\r\n]+)") or ""
      if firstHeading == "" and firstLine:find("#", 1, true) == 1 then
        firstHeading = firstLine
      end
      -- Role documents have independent version cadences (API/compatibility/
      -- confidence headings describe those contracts, not every player build).
      -- Require a valid role heading; require the current build only in the
      -- release-specific CHANGELOG/RELEASE_NOTES surfaces below.
      if path == "README.md" then
        return firstHeading:find("# Nuzlocke", 1, true) == 1
      elseif path == "CHANGELOG.md" then
        return content:find("# " .. buildText, 1, true) ~= nil
          or content:find("## " .. buildText, 1, true) ~= nil
      elseif path == "RELEASE_NOTES.md" then
        return firstHeading:find("# Nuzlocke " .. buildText .. " —", 1, true) == 1
          or content:find("## " .. buildText, 1, true) ~= nil
      elseif path == "docs/API.md" then
        return firstHeading:find("# Nuzlocke API — ", 1, true) == 1
      elseif path == "docs/COMPATIBILITY.md" then
        return firstHeading:find("# Nuzlocke Compatibility — ", 1, true) == 1
      elseif path == "docs/DOCUMENTATION_CHANGELOG.md" then
        return firstHeading:find("# ", 1, true) == 1
      elseif path == "docs/FEATURE_CONFIDENCE.md" then
        return firstHeading:find("# Feature Confidence — ", 1, true) == 1
      elseif path == "docs/USER_GUIDE.md" then
        return firstHeading:find("# Nuzlocke User Guide — ", 1, true) == 1
      end
      return false
    end
    local expectedDocPaths = {
      "README.md", "CHANGELOG.md", "RELEASE_NOTES.md", "docs/API.md",
      "docs/COMPATIBILITY.md", "docs/DOCUMENTATION_CHANGELOG.md",
      "docs/FEATURE_CONFIDENCE.md", "docs/USER_GUIDE.md",
    }
    for _, path in ipairs(expectedDocPaths) do
      local content = safeRead(path)
      if content then
        local firstLine = content:match("^%s*([^\r\n]+)") or ""
        check("doc_current_header_" .. path,
          docHeaderMatches(path, firstLine, content), firstLine)
        local staleBanner = nil
        for line in content:gmatch("[^\r\n]+") do
          if line:find("Current build:", 1, true) then
            local version = line:match("(%d+%.%d+%.%d+)")
            if version and version ~= buildText then staleBanner = version break end
          end
        end
        check("doc_current_banner_" .. path, staleBanner == nil,
          staleBanner and ("stale=" .. staleBanner) or "ok")
        if path == "CHANGELOG.md" then
          local count = 0
          for line in content:gmatch("[^\r\n]+") do
            if line == "# " .. buildText
              or line:find("# " .. buildText .. " — ", 1, true) == 1
              or line == "## " .. buildText
              or line:find("## " .. buildText .. " — ", 1, true) == 1 then
              count = count + 1
            end
          end
          check("changelog_current_version_unique", count == 1,
            "headings=" .. tostring(count))
        end
      else
        report.skipped[#report.skipped + 1] = path
      end
    end

    local paths = deps.packagePaths or {}
    local expectedCount = tonumber(deps.expectedPackageCount) or 30
    check("package_inventory_count", #paths == expectedCount,
      string.format("count=%d expected=%d", #paths, expectedCount))
    local seen = {}
    for _, path in ipairs(paths) do
      check("package_inventory_unique_" .. tostring(path), seen[path] ~= true)
      seen[path] = true
    end

    local owners = deps.expectedModuleOwners or {}
    for path, marker in pairs(owners) do
      local content = safeRead(path)
      if content then
        check("module_owner_" .. path, content:find(tostring(marker), 1, true) ~= nil, marker)
      else
        report.skipped[#report.skipped + 1] = path
      end
    end
    return report
  end

  mod.exports.__beta26.diagnosticPrefixAudit = function()
    local report = { ok = true, checked = 0, failures = {}, skipped = {} }
    local function checkCalls(path, content, needle)
      local from = 1
      while true do
        local at = content:find(needle, from, true)
        if not at then break end
        report.checked = report.checked + 1
        local tail = content:sub(at, math.min(#content, at + 180))
        if not tail:find("[Nuzlocke:", 1, true) then
          report.ok = false
          local line = 1 + select(2, content:sub(1, at):gsub("\n", ""))
          report.failures[#report.failures + 1] = path .. ":" .. tostring(line)
        end
        from = at + #needle
      end
    end
    for _, path in ipairs(deps.packagePaths or {}) do
      if (tostring(path):match("%.lua$") or path == "mod.card")
          and path ~= "release_safety.lua" then
        local content = safeRead(path)
        if content then
          for _, needle in ipairs({ "mod.log:info", "mod.log:warn",
              "mod.log:error", "mod.log:debug" }) do
            checkCalls(path, content, needle)
          end
          local from = 1
          while true do
            local at = content:find("pcall(print", from, true)
            if not at then break end
            local tail = content:sub(at, math.min(#content, at + 220))
            if tail:find("Nuzlocke", 1, true) then
              report.checked = report.checked + 1
              if not tail:find("[Nuzlocke:", 1, true) then
                report.ok = false
                local line = 1 + select(2, content:sub(1, at):gsub("\n", ""))
                report.failures[#report.failures + 1] = path .. ":" .. tostring(line)
              end
            end
            from = at + 10
          end
        else
          report.skipped[#report.skipped + 1] = path
        end
      end
    end
    return report
  end

  -- 2.7.84: Gen1Recomp 0.2.24-era compatibility tripwire. This is deliberately
  -- source-based and narrow: protect the exact six-edition manifest, Gen2
  -- clock/DST integration, semantic options markers, engine developer signal,
  -- and the upstream OptionRows Gen2 trap without migrating unrelated seams.
  mod.exports.__beta26.gen1Recomp024Audit = function()
    local report = { ok = true, checked = 0, failures = {}, skipped = {} }
    local function check(id, condition)
      report.checked = report.checked + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = id
    end
    local main = safeRead("main.lua")
    local late = safeRead("late_runtime.lua")
    local manifest = safeRead("manifest.json")
    if main then
      check("audited_current_engine", main:find('recompCompatAudited = "0.2.41"', 1, true) ~= nil)
      check("engine_developer_signal", main:find("Dev.engineDeveloper = mod.developer == true", 1, true) ~= nil)
      local markerCount = 0
      for _ in main:gmatch("isModOptions%s*=%s*true") do markerCount = markerCount + 1 end
      if late then for _ in late:gmatch("isModOptions%s*=%s*true") do markerCount = markerCount + 1 end end
      check("options_screen_markers", markerCount == 4)
    else
      report.skipped[#report.skipped + 1] = "main.lua"
    end
    if late then
      check("clock_host_minutes", late:find("Clock.hostMinutes", 1, true) ~= nil)
      check("clock_host_weekday", late:find("Clock.hostWeekday", 1, true) ~= nil)
      check("dst_set_branch", late:find('clockCommand == "initialsetdstflag"', 1, true) ~= nil)
      check("dst_clear_branch", late:find('clockCommand == "initialcleardstflag"', 1, true) ~= nil)
      check("dst_bit_clear", late:find("save.rtc.dst = false", 1, true) ~= nil)
    else
      report.skipped[#report.skipped + 1] = "late_runtime.lua"
    end
    if manifest then
      local block = manifest:match('"games"%s*:%s*%[([^%]]*)%]') or ""
      local games = {}
      for g in block:gmatch('"([^"]+)"') do games[#games + 1] = g end
      check("exact_six_editions", table.concat(games, ",") == "red,blue,yellow,gold,silver,crystal")
      check("crystal_alpha_declared", main and main:find('stage = "ALPHA"', 1, true) ~= nil)
    else
      report.skipped[#report.skipped + 1] = "manifest.json"
    end
    local optionRowsModule = "src.ui.Option" .. "Rows"
    local optionRowsForbidden = 'require("' .. optionRowsModule .. '")'
    local optionRowsFound = false
    for _, path in ipairs(deps.packagePaths or {}) do
      if tostring(path):match("%.lua$") then
        local text = safeRead(path)
        if text and text:find(optionRowsForbidden, 1, true) then
          optionRowsFound = true break
        end
      end
    end
    check("gen2_optionrows_trap_absent", not optionRowsFound)
    -- src.script.Commands is a valid Gen-1 dependency used by protected R/B/Y
    -- tutorial/heal seams. The Gen-2 compatibility trap is using it while a
    -- shared Gen-2 runtime is active, so protect the explicit runtime guard and
    -- the documented refusal rather than banning the module package-wide.
    check("gen2_commands_trap_guarded",
      main and main:find("require src.script.Commands for Gen2", 1, true) ~= nil
        and main:find("not mod.exports.__beta26.runtimeIsGen2(game)", 1, true) ~= nil)
    return report
  end

  -- 2.9.40: classify compatibility evidence without promoting any class to
  -- gameplay authority. Live-contract, source-reviewed, and combined-runtime-
  -- required are deliberately independent facts.
  mod.exports.__beta26.compatibilityEvidenceClassificationAudit = function()
    local report = { ok=true, checked=0, failures={}, counts={
      live_contract=0, source_reviewed=0, combined_runtime_required=0 } }
    local function check(id, condition)
      report.checked = report.checked + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = id
    end
    local fn = mod.exports.__beta26.compatibilityEvidenceReport
    check("report_callable", type(fn) == "function")
    if type(fn) ~= "function" then return report end
    local ok, data = pcall(fn)
    check("report_shape", ok and type(data) == "table"
      and data.api == 1 and type(data.classes) == "table" and type(data.rows) == "table")
    if not ok or type(data) ~= "table" or type(data.rows) ~= "table" then return report end
    for _, class in ipairs({"live_contract", "source_reviewed", "combined_runtime_required"}) do
      check("class_" .. class, data.classes[class] == true)
    end
    for id, row in pairs(data.rows) do
      local evidence = type(row) == "table" and row.evidence or nil
      check("row_evidence_" .. tostring(id), type(evidence) == "table")
      if type(evidence) == "table" then
        for class in pairs(report.counts) do
          if evidence[class] == true then report.counts[class] = report.counts[class] + 1 end
        end
      end
    end
    local adapters = mod.exports.__beta26.compat and mod.exports.__beta26.compat.Mods
      and mod.exports.__beta26.compat.Mods.adapters or {}
    local conflict = adapters.kanto_ascendant or {}
    local conflictEvidence = data.rows.kanto_ascendant and data.rows.kanto_ascendant.evidence or {}
    check("conflict_source_reviewed", conflict.status == "explicit_conflict_do_not_combine"
      and conflictEvidence.source_reviewed == true)
    check("conflict_not_runtime_cert_target", conflictEvidence.combined_runtime_required ~= true)
    local dbl = data.rows.double_battles and data.rows.double_battles.evidence or {}
    check("reviewed_stack_runtime_required", dbl.source_reviewed == true
      and dbl.combined_runtime_required == true)
    -- A static package audit normally has no other loaded mod, so zero live
    -- contracts is valid. If discovery later records one, the class may appear
    -- but still does not imply selected ownership or Runtime PASS.
    return report
  end

  -- 2.9.40: Release Safety self-audit inventory. This records which checks are
  -- semantic versus source-only and protects the newly retired exact-adapter
  -- serialization tripwires from creeping back into the G9 ownership audit.
  mod.exports.__beta26.releaseSafetySelfAudit = function()
    local report = { ok=true, checked=0, failures={}, semantic={}, source_only={} }
    local function check(id, condition)
      report.checked = report.checked + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = id
    end
    local battle = mod.exports.__beta26.battleStackOwnershipAudit
    local okBattle, battleReport = type(battle) == "function" and pcall(battle) or false, nil
    if type(battle) == "function" then okBattle, battleReport = pcall(battle) end
    check("battle_audit_callable", type(battle) == "function")
    check("battle_audit_passes", okBattle and type(battleReport) == "table" and battleReport.ok == true)
    if type(battleReport) == "table" and type(battleReport.evidence) == "table" then
      report.semantic.battle_stack = tonumber(battleReport.evidence.semantic) or 0
      report.source_only.battle_stack = tonumber(battleReport.evidence.source) or 0
      check("battle_semantic_checks_present", report.semantic.battle_stack > 0)
      check("battle_source_checks_bounded", report.source_only.battle_stack <= 4)
    else
      check("battle_evidence_inventory", false)
    end
    local source = safeRead("release_safety.lua") or ""
    for owner, path in pairs(SOURCE_OWNERS) do
      local content = safeRead(path)
      check("source_owner_readable:" .. tostring(owner), type(content) == "string" and #content > 0)
    end
    local identitySource = ownerSource("identity") or ""
    local mainSource = ownerSource("main") or ""
    check("pokemon_identity_future_schema_live_guard",
      identitySource:find("getSaveSchemaTooNew()", 1, true) ~= nil
      and identitySource:find("if saveSchemaTooNew then", 1, true) == nil
      and mainSource:find("getSaveSchemaTooNew = function() return saveSchemaTooNew == true end", 1, true) ~= nil)
    local randomizerSource = ownerSource("randomizer") or ""
    local compatibilitySource = ownerSource("compatibility") or ""
    local lateSource = ownerSource("late") or ""
    check("randomizer_trainer_species_generation_scope",
      randomizerSource:find("local function effectiveRandomSpeciesGeneration()", 1, true) ~= nil
      and randomizerSource:find("RANDOMIZER_ALGORITHM_VERSION", 1, true) == nil)
    check("compat_auto_provider_fallback_iteration",
      compatibilitySource:find("local function firstMatchingCandidate", 1, true) ~= nil
      and compatibilitySource:find("active_second", 1, true) ~= nil)
    check("gen2_rule_names_live_game",
      lateSource:find("function G2.ruleNames()", 1, true) ~= nil
      and lateSource:find("local game = getCurrentGame() or mod.game", 1, true) ~= nil)
    check("gen1recomp_0_2_39_profile",
      compatibilitySource:find('["0.2.39"] = {', 1, true) ~= nil
      and compatibilitySource:find("PresentSync/PresentProbe", 1, true) ~= nil)
    check("gen1recomp_0_2_40_profile",
      compatibilitySource:find('["0.2.40"] = {', 1, true) ~= nil
      and compatibilitySource:find("0cf543d597ce84e4d847b2aba782f1bf2799fde0", 1, true) ~= nil)
    check("gen1recomp_0_2_41_profile",
      compatibilitySource:find('["0.2.41"] = {', 1, true) ~= nil
      and compatibilitySource:find("3d3a9ba4b66832b8c70ac26e1e88dbae612efcd0", 1, true) ~= nil
      and mainSource:find('recompCompatAudited = "0.2.41"', 1, true) ~= nil)
    check("present_sync_read_only_diagnostic",
      compatibilitySource:find("presentSyncStatus", 1, true) ~= nil
      and compatibilitySource:find('ownership="engine"', 1, true) ~= nil
      and compatibilitySource:find("PresentSync.status", 1, true) ~= nil)
    local pacingForbidden = {
      "FrameCap.apply(", "VSync.apply(", "PresentSync.reprobe(",
      "PresentSync.reset(", "PresentSync.waitBeforePresent(",
      "FixedStep.refreshPeriod =", "love.timer.sleep(",
    }
    for _, token in ipairs(pacingForbidden) do
      check("engine_pacing_ownership:" .. token,
        mainSource:find(token, 1, true) == nil
        and compatibilitySource:find(token, 1, true) == nil
        and lateSource:find(token, 1, true) == nil)
    end
    check("gen2_field_item_0_2_39_signature_preserved",
      randomizerSource:find("installRandomFieldItems", 1, true) ~= nil
      and compatibilitySource:find('recompCompatAudited = "0.2.39"', 1, true) == nil)
    check("rby_field_item_world_talk_primary_2_9_71",
      mainSource:find('mod.hooks.wrap, mod.hooks, "world.talk"', 1, true) ~= nil
      and mainSource:find("rbyFieldItemWorldTalkSession2971", 1, true) ~= nil
      and mainSource:find("applyRbyFieldItem", 1, true) ~= nil
      and randomizerSource:find('or "world.talk"', 1, true) ~= nil
      and compatibilitySource:find('hook = "world.talk"', 1, true) ~= nil)
    check("rby_field_item_hook_health_2_9_71",
      devSource:find('hook="world.talk"', 1, true) ~= nil
      and devSource:find('sessionExport="rbyFieldItemWorldTalkSession2971"', 1, true) ~= nil)
    check("shiny_1241_explicit_target",
      compatibilitySource:find('tested = "Stone fork 1.2.41"', 1, true) ~= nil
      and compatibilitySource:find('reviewed_version="1.2.41"', 1, true) ~= nil)
    check("shiny_provider_fingerprint_contract",
      compatibilitySource:find("compatProviderFingerprint", 1, true) ~= nil
      and compatibilitySource:find("registration_identity", 1, true) ~= nil
      and compatibilitySource:find("hook_identity", 1, true) ~= nil
      and compatibilitySource:find("evidence_stale", 1, true) ~= nil)
    check("shiny_integration_validation_contract",
      compatibilitySource:find("shinyIntegrationValidation", 1, true) ~= nil
      and compatibilitySource:find('integrations.validate, "nuzlocke"', 1, true) ~= nil)
    check("shiny_provider_source_ownership_contract",
      compatibilitySource:find("shinyPresentationSourcePolicy", 1, true) ~= nil
      and lateSource:find('policy == "provider_owned"', 1, true) ~= nil)
    check("compat_seam_registry_contract",
      compatibilitySource:find("COMPAT_SEAM_REGISTRY", 1, true) ~= nil
      and compatibilitySource:find('surface="shiny.roll"', 1, true) ~= nil
      and compatibilitySource:find("gen2_shiny_flash_queue", 1, true) ~= nil)
    local ruleCatalogSource = ownerSource("rules") or ""
    check("shiny_config_default_drift_guard",
      ruleCatalogSource:find('{ key = "shiny_rate_mode", default = 0', 1, true) ~= nil
      and ruleCatalogSource:find('{ key = "shiny_colors", default = true', 1, true) ~= nil
      and ruleCatalogSource:find('{ key = "shiny_intro", default = true', 1, true) ~= nil
      and mainSource:find('defaultRuleValue("shiny_rate_mode")', 1, true) ~= nil)
    local localModules = {
      "rule_catalog", "species_policy", "item_policy", "evolution_policy",
      "randomizer_runtime", "compatibility_runtime", "late_runtime",
      "pokemon_identity", "encounter_tracker",
    }
    for _, moduleName in ipairs(localModules) do
      check("mod_local_loader_classification:" .. moduleName,
        mainSource:find('require("' .. moduleName .. '")', 1, true) == nil
        and mainSource:find("loadRequiredModuleChunk", 1, true) ~= nil)
    end
    check("retired_g9_exact_serialization",
      source:find("g9_" .. "published_version", 1, true) == nil
      and source:find("g9_" .. "beta_version", 1, true) == nil)
    return report
  end

  -- 2.8.78 / Gen1Recomp 0.2.33 compatibility gate. Protect the public
  -- R/B/Y catch nickname seam, palette-aware Gen II Nuzlocke utility surfaces,
  -- current audited profile, and the source-revalidated Crystal shiny-flash
  -- safety boundary without claiming exact-edition runtime certification.
  mod.exports.__beta26.gen1Recomp036FocusedAudit = function()
    local report = { ok = true, checked = 0, failures = {}, skipped = {} }
    local function check(id, condition)
      report.checked = report.checked + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = id
    end
    local main = ownerSource("compatibility")
    local buildMain = ownerSource("main")
    local late = safeRead("late_runtime.lua")
    local classic = safeRead("classic_ui.lua")
    local compat = safeRead("docs/COMPATIBILITY.md")
    if main then
      check("audited_0_2_36",
        buildMain and buildMain:find('recompCompatAudited = "0.2.41"', 1, true) ~= nil)
      check("profile_0_2_27",
        main:find('["0.2.27"] = {', 1, true) ~= nil)
      check("profile_0_2_28",
        main:find('["0.2.28"] = {', 1, true) ~= nil)
      check("profile_0_2_29",
        main:find('["0.2.29"] = {', 1, true) ~= nil)
      check("profile_0_2_30",
        main:find('["0.2.30"] = {', 1, true) ~= nil)
      check("profile_0_2_31",
        main:find('["0.2.31"] = {', 1, true) ~= nil)
      check("profile_0_2_32",
        main:find('["0.2.32"] = {', 1, true) ~= nil)
      check("profile_0_2_33",
        main:find('["0.2.33"] = {', 1, true) ~= nil)
      check("profile_0_2_34",
        main:find('["0.2.34"] = {', 1, true) ~= nil)
      check("profile_0_2_35",
        main:find('["0.2.35"] = {', 1, true) ~= nil)
      check("profile_0_2_36_plus",
        main:find('["0.2.36"] = {', 1, true) ~= nil and
        main:find('["0.2.37"] = {', 1, true) ~= nil and
        main:find('["0.2.38"] = {', 1, true) ~= nil and
        main:find('["0.2.39"] = {', 1, true) ~= nil and
        main:find('["0.2.40"] = {', 1, true) ~= nil and
        main:find('["0.2.41"] = {', 1, true) ~= nil)
      check("save_format_0_2_24_is_4",
        main:find('["0.2.24"] = {', 1, true) ~= nil
          and main:find('api = 2, save_format = 4', main:find('["0.2.24"] = {', 1, true), true) ~= nil)
      check("save_format_0_2_25_plus_is_5",
        main:find('api = 2, save_format = 5', main:find('["0.2.25"] = {', 1, true), true) ~= nil)
      check("level_visible_future_seam",
        main:find('hook = "pokemon.level_visible"', 1, true) ~= nil
          and main:find('available_not_owned_0_2_32_plus', 1, true) ~= nil)
      check("online_arena_policy_metadata",
        main:find('online_arena = {', 1, true) ~= nil
          and main:find('disableAll = true, cartOnly = true', 1, true) ~= nil
          and main:find('bypass = false', 1, true) ~= nil)
      check("catch_nickname_public_hook",
        main:find('mod.hooks:wrap("catch.nickname"', 1, true) ~= nil)
      check("catch_nickname_old_engine_fallback",
        main:find('mod.hooks:wrap("battle.nickname"', 1, true) ~= nil)
      check("nickname_ui_enforcement_preserved",
        main:find('__nuzlockeNicknameScreenSession', 1, true) ~= nil)
      check("shiny_current_target",
        main:find('tested = "Stone fork 1.2.41"', 1, true) ~= nil)
      check("shiny_127_registry_detection",
        main:find('public.getProvider, "SHINY_POKEMON"', 1, true) ~= nil)
      check("shiny_127_api_detection",
        main:find('exports.shiny_pokemon or exports.shiny_compat', 1, true) ~= nil)
    else
      report.skipped[#report.skipped + 1] = "main.lua"
    end
    if classic then
      check("gen2_status_chrome_palette",
        classic:find('if gen2Status then', 1, true) ~= nil
          and classic:find('Chrome.clear()', 1, true) ~= nil)
      check("gen2_recovery_chrome_palette",
        classic:find('if gen2Recovery then', 1, true) ~= nil
          and classic:find('Chrome.printWrapped(Strings(text)', 1, true) ~= nil)
    else
      report.skipped[#report.skipped + 1] = "classic_ui.lua"
    end
    if late then
      check("gen2_shiny_flash_event_guard",
        late:find('nextEvent.kind == "shiny-flash"', 1, true) ~= nil)
      check("gen2_shiny_flash_033_marker",
        late:find('audited_engine = "0.2.33"', 1, true) ~= nil
          and late:find('source_revalidated_0_2_33 = true', 1, true) ~= nil)
      check("gen2_shiny_restore_enemy",
        late:find('self.picHidden.enemy = false', 1, true) ~= nil)
      check("gen2_shiny_restore_player",
        late:find('self.picHidden.player = false', 1, true) ~= nil)
      check("gen2_shiny_no_draw_owner",
        late:find('Gen2BattleState.draw = function', 1, true) == nil)
      check("gen2_shiny_no_update_owner",
        late:find('Gen2BattleState.update = function', 1, true) == nil)
      check("shiny_127_private_cache_signature",
        late:find('shinyPaletteCacheSignature(species)', 1, true) ~= nil)
      check("shiny_127_no_assets_reset",
        late:find('Assets.reset', 1, true) == nil
          and late:find('Assets.invalidate', 1, true) == nil
          and late:find('Renderer.reset', 1, true) == nil
          and late:find('Renderer.invalidate', 1, true) == nil)
    else
      report.skipped[#report.skipped + 1] = "late_runtime.lua"
    end
    if compat then
      check("compat_docs_0_2_33",
        compat:find('Gen1Recomp 0.2.39', 1, true) ~= nil)
      check("compat_docs_online_arena",
        compat:find('ONLINE arena', 1, true) ~= nil
          and compat:find('ordinary content mods', 1, true) ~= nil)
      check("compat_docs_level_visible",
        compat:find('pokemon.level_visible', 1, true) ~= nil)
      check("compat_docs_runtime_caveat",
        compat:find('runtime certification', 1, true) ~= nil)
    else
      report.skipped[#report.skipped + 1] = "docs/COMPATIBILITY.md"
    end
    return report
  end
  -- Historical internal names kept as read-only aliases for older tooling.
  mod.exports.__beta26.gen1Recomp033FocusedAudit =
    mod.exports.__beta26.gen1Recomp036FocusedAudit
  mod.exports.__beta26.gen1Recomp029FocusedAudit =
    mod.exports.__beta26.gen1Recomp036FocusedAudit
  mod.exports.__beta26.gen1Recomp027FocusedAudit =
    mod.exports.__beta26.gen1Recomp036FocusedAudit

  -- 2.9.38: generated/read-only save-key/reference consumer index.
  -- This is diagnostic source introspection only. It never reads or writes live
  -- save values, never materializes migrations, and never becomes gameplay
  -- authority. Package source may be unavailable in supported launchers, so
  -- unreadable/partial source fails open with bounded diagnostic detail.
  mod.exports.__beta26.saveReferenceConsumerIndex = function()
    local MAX_KEYS = 512
    local MAX_CONSUMERS_PER_KEY = 24
    local MAX_UNRESOLVED = 64
    local descriptor = mod.exports.__beta26.saveSchemaDescriptor
    local described = type(descriptor) == "table"
      and type(descriptor.describe) == "function" and descriptor.describe() or nil
    local fields = type(described) == "table" and described.fields or {}
    local report = {
      ok = true,
      complete = true,
      status = "complete",
      limits = {
        max_keys = MAX_KEYS,
        max_consumers_per_key = MAX_CONSUMERS_PER_KEY,
        max_unresolved = MAX_UNRESOLVED,
      },
      key_count = 0,
      reference_count = 0,
      dynamic_reference_count = 0,
      unreadable_count = 0,
      truncated = false,
      keys = {},
      unresolved = {},
      unreadable = {},
      undescribed_literal_keys = {},
    }

    local orderedKeys = {}
    for key in pairs(type(fields) == "table" and fields or {}) do
      if type(key) == "string" and key ~= "" then orderedKeys[#orderedKeys + 1] = key end
    end
    table.sort(orderedKeys)
    if #orderedKeys > MAX_KEYS then
      report.truncated = true
      while #orderedKeys > MAX_KEYS do table.remove(orderedKeys) end
    end
    local keySet = {}
    for _, key in ipairs(orderedKeys) do
      keySet[key] = true
      report.keys[key] = { consumers = {}, reads = 0, writes = 0, literals = 0, truncated = false }
    end
    report.key_count = #orderedKeys

    local undescribedSeen = {}
    local function addConsumer(key, path, kind)
      local row = report.keys[key]
      if not row then return end
      if kind == "read" then row.reads = row.reads + 1
      elseif kind == "write" then row.writes = row.writes + 1
      else row.literals = row.literals + 1 end
      report.reference_count = report.reference_count + 1
      local token = tostring(path) .. ":" .. tostring(kind)
      for _, existing in ipairs(row.consumers) do
        if existing == token then return end
      end
      if #row.consumers < MAX_CONSUMERS_PER_KEY then
        row.consumers[#row.consumers + 1] = token
      else
        row.truncated = true
        report.truncated = true
      end
    end

    local function addUnresolved(path, kind)
      report.dynamic_reference_count = report.dynamic_reference_count + 1
      if #report.unresolved < MAX_UNRESOLVED then
        report.unresolved[#report.unresolved + 1] = tostring(path) .. ":" .. tostring(kind)
      else
        report.truncated = true
      end
    end

    local function scanCalls(path, source, method, kind)
      local needleCall = "mod.save:" .. method .. "("
      local pos = 1
      while true do
        local at = source:find(needleCall, pos, true)
        if not at then break end
        local arg = at + #needleCall
        while source:sub(arg, arg):match("%s") do arg = arg + 1 end
        local quote = source:sub(arg, arg)
        if quote == '"' or quote == "'" then
          local finish = arg + 1
          while finish <= #source do
            local ch = source:sub(finish, finish)
            if ch == quote and source:sub(finish - 1, finish - 1) ~= "\\" then break end
            finish = finish + 1
          end
          if finish <= #source then
            local key = source:sub(arg + 1, finish - 1)
            if keySet[key] then
              addConsumer(key, path, kind)
            elseif key ~= "" and not undescribedSeen[key] then
              undescribedSeen[key] = true
              if #report.undescribed_literal_keys < MAX_UNRESOLVED then
                report.undescribed_literal_keys[#report.undescribed_literal_keys + 1] = key
              else
                report.truncated = true
              end
            end
          else
            addUnresolved(path, kind .. "_unterminated")
          end
        else
          addUnresolved(path, kind .. "_dynamic")
        end
        pos = at + #needleCall
      end
    end

    local readableLua = 0
    for _, path in ipairs(deps.packagePaths or {}) do
      if tostring(path):match("%.lua$") then
        local source, readErr = safeRead(path)
        if type(source) == "string" then
          readableLua = readableLua + 1
          scanCalls(path, source, "get", "read")
          scanCalls(path, source, "set", "write")
          -- Record non-call literal references for described keys as a bounded
          -- consumer hint. These may be descriptors/constants/comments, so they
          -- are intentionally classified as `literal`, never as read/write.
          for _, key in ipairs(orderedKeys) do
            local row = report.keys[key]
            if row and row.reads == 0 and row.writes == 0 then
              if source:find('"' .. key .. '"', 1, true)
                or source:find("'" .. key .. "'", 1, true) then
                addConsumer(key, path, "literal")
              end
            end
          end
        else
          report.complete = false
          report.unreadable_count = report.unreadable_count + 1
          if #report.unreadable < MAX_UNRESOLVED then
            report.unreadable[#report.unreadable + 1] = tostring(path)
              .. ":" .. tostring(readErr)
          else
            report.truncated = true
          end
        end
      end
    end

    if readableLua == 0 then
      report.complete = false
      report.status = "unavailable"
    elseif report.unreadable_count > 0 then
      report.status = "partial"
    elseif report.truncated then
      report.status = "bounded"
    end
    table.sort(report.undescribed_literal_keys)
    return report
  end

  mod.exports.__beta26.saveReferenceConsumerIndexAudit = function()
    local okIndex, index = pcall(mod.exports.__beta26.saveReferenceConsumerIndex)
    if not okIndex or type(index) ~= "table" then
      return { ok=false, failures={"index_error:" .. tostring(index)} }
    end
    local failures = {}
    local limits = index.limits or {}
    if tonumber(limits.max_keys) ~= 512 then failures[#failures + 1] = "max_keys" end
    if tonumber(limits.max_consumers_per_key) ~= 24 then failures[#failures + 1] = "max_consumers_per_key" end
    if tonumber(limits.max_unresolved) ~= 64 then failures[#failures + 1] = "max_unresolved" end
    if type(index.keys) ~= "table" or type(index.unresolved) ~= "table"
      or type(index.unreadable) ~= "table" then
      failures[#failures + 1] = "shape"
    end
    if #index.unresolved > 64 or #index.unreadable > 64
      or #(index.undescribed_literal_keys or {}) > 64 then
      failures[#failures + 1] = "unbounded_detail"
    end
    return {
      ok = #failures == 0,
      failures = failures,
      complete = index.complete == true,
      status = index.status,
      key_count = index.key_count,
      reference_count = index.reference_count,
      dynamic_reference_count = index.dynamic_reference_count,
      unreadable_count = index.unreadable_count,
      truncated = index.truncated == true,
    }
  end

  mod.exports.__beta26.releaseSafetyAudit = function()
    local report = {
      ok = true, build = mod.exports.__beta26.build, checks = {},
      failures = {}, warnings = {}, check_count = 0, pass_count = 0,
    }
    local function add(id, ok, detail, fatal)
      report.check_count = report.check_count + 1
      if ok == true then report.pass_count = report.pass_count + 1 end
      report.checks[#report.checks + 1] = {
        id = tostring(id), ok = ok == true, detail = tostring(detail or ""),
        fatal = fatal ~= false,
      }
      if ok ~= true then
        local msg = tostring(id) .. ":" .. tostring(detail or "failed")
        if fatal == false then
          report.warnings[#report.warnings + 1] = msg
        else
          report.ok = false
          report.failures[#report.failures + 1] = msg
        end
      end
    end
    local function savePauseHelperScopeAudit()
        local report = { ok=true, checked=0, failures={}, skipped={} }

        local function hasBareSavePauseCall(text)
            if type(text) ~= "string" then return false end
            -- Remove the one allowed call form first. Prefixing a newline makes
            -- the bare-call detector cover a call at byte 1 as well as ordinary
            -- indented/module-local call sites.
            local stripped = "\n" .. text:gsub(
                "mod%.exports%.__beta26%.saveWritePauseReason%s*%(", "")
            return stripped:find("[^%w_%.]saveWritePauseReason%s*%(") ~= nil
        end

        -- Regression self-test: prove the detector rejects the historical bare
        -- cross-module form while accepting the required qualified export form.
        report.checked = report.checked + 2
        if not hasBareSavePauseCall("return saveWritePause" .. "Reason()") then
            report.ok = false
            report.failures[#report.failures + 1] = "selftest:missed_bare_save_pause_helper"
        end
        if hasBareSavePauseCall(
                "return mod.exports.__beta26.saveWritePauseReason()") then
            report.ok = false
            report.failures[#report.failures + 1] = "selftest:false_positive_qualified_save_pause_helper"
        end

        -- 2.6.73: scan the authoritative shipped package inventory rather than
        -- a hand-maintained caller list. The original 2.6.66 guard checked only
        -- main.lua even though the historical regression occurred in split
        -- modules. Every present and future shipped Lua module is now covered.
        for _, path in ipairs(deps.packagePaths or {}) do
            if tostring(path):match("%.lua$") then
                local text, readErr = safeRead(path)
                report.checked = report.checked + 1
                if type(text) ~= "string" then
                    -- Source introspection is diagnostic-only. A launcher may
                    -- legitimately deny mod:read(); absence of source must not
                    -- turn a gameplay-safe install into a Release Safety fail.
                    report.skipped[#report.skipped + 1] =
                        path .. ":source_unavailable:" .. tostring(readErr)
                elseif hasBareSavePauseCall(text) then
                    report.ok = false
                    report.failures[#report.failures + 1] = path .. ":bare_save_pause_helper"
                end
            end
        end
        return report
    end
    mod.exports.__beta26.savePauseHelperScopeAudit = savePauseHelperScopeAudit

    local function luaUnpackCompatibilityAudit()
        local report = { ok=true, checked=0, failures={}, skipped={} }

        local function unpackCompatibilityFailure(text)
            if type(text) ~= "string" then return nil end
            if text:find("table%.unpack%s*%(") then
                return "direct_table_unpack"
            end
            local stripped = text:gsub("table%.unpack%s+or%s+unpack", "")
            if stripped:find("[^%w_%.]unpack%s*%(") then
                return "bare_unpack_call"
            end
            return nil
        end

        -- 2.6.94: regression self-test for the exact engine-compatibility
        -- contract this audit protects. Build the forbidden call spellings in
        -- pieces so scanning release_safety.lua itself does not trip on the
        -- fixture source strings.
        report.checked = report.checked + 3
        if unpackCompatibilityFailure("return table." .. "un" .. "pack({1})")
                ~= "direct_table_unpack" then
            report.ok = false
            report.failures[#report.failures + 1] = "selftest:missed_direct_table_unpack"
        end
        if unpackCompatibilityFailure("return " .. "un" .. "pack({1})")
                ~= "bare_unpack_call" then
            report.ok = false
            report.failures[#report.failures + 1] = "selftest:missed_bare_unpack_call"
        end
        if unpackCompatibilityFailure("local f = table." .. "un" .. "pack or "
                .. "un" .. "pack") ~= nil then
            report.ok = false
            report.failures[#report.failures + 1] = "selftest:false_positive_compat_fallback"
        end

        -- 2.6.94: scan the authoritative shipped package inventory, matching
        -- the sibling savePauseHelperScopeAudit. The previous four-file list
        -- silently excluded every other split module from this compatibility
        -- guard and would miss the exact regression class after modularization.
        for _, path in ipairs(deps.packagePaths or {}) do
            if tostring(path):match("%.lua$") then
                local text, readErr = safeRead(path)
                report.checked = report.checked + 1
                if type(text) ~= "string" then
                    report.skipped[#report.skipped + 1] =
                        path .. ":source_unavailable:" .. tostring(readErr)
                else
                    local failure = unpackCompatibilityFailure(text)
                    if failure ~= nil then
                        report.ok = false
                        report.failures[#report.failures + 1] = path .. ":" .. failure
                    end
                end
            end
        end
        return report
    end
    mod.exports.__beta26.luaUnpackCompatibilityAudit = luaUnpackCompatibilityAudit

    -- 2.7.54: catch the historical Lua footgun where an earlier function calls
    -- a helper declared later with `local function name(...)` but no explicit
    -- forward declaration. Lua resolves that earlier reference through _ENV,
    -- so the mistake can silently become a nil/foreign global at runtime.
    local function forwardLocalReferenceAudit()
        local report = { ok=true, checked=0, failures={}, skipped={} }

        local function stripLine(line)
            line = tostring(line or "")
            local out, quote, escaped = {}, nil, false
            local i = 1
            while i <= #line do
                local c = line:sub(i, i)
                local n = line:sub(i, i + 1)
                if quote then
                    if escaped then escaped = false
                    elseif c == "\\" then escaped = true
                    elseif c == quote then quote = nil end
                    out[#out + 1] = " "
                elseif n == "--" then
                    break
                elseif c == "\"" or c == "'" then
                    quote = c
                    out[#out + 1] = " "
                else
                    out[#out + 1] = c
                end
                i = i + 1
            end
            return table.concat(out)
        end

        local function scan(path, text)
            local lines, declarations = {}, {}
            for raw in (tostring(text) .. "\n"):gmatch("(.-)\n") do
                lines[#lines + 1] = stripLine(raw)
            end
            for lineNo, line in ipairs(lines) do
                local name = line:match("%f[%a]local%s+function%s+([%a_][%w_]*)%s*%(")
                if name and declarations[name] == nil then declarations[name] = lineNo end
            end
            for name, declLine in pairs(declarations) do
                local forward = false
                for lineNo = 1, declLine - 1 do
                    local line = lines[lineNo]
                    if line:match("%f[%a]local%s+" .. name .. "%f[^%w_]") then
                        forward = true
                        break
                    end
                    local at = line:find(name, 1, true)
                    while at do
                        local before = at > 1 and line:sub(at - 1, at - 1) or ""
                        local after = line:sub(at + #name):match("^%s*(.)") or ""
                        local prefixOk = before == "" or not before:match("[%w_%.:]")
                        if prefixOk and after == "(" then
                            report.ok = false
                            report.failures[#report.failures + 1] = path .. ":"
                                .. tostring(lineNo) .. ":forward_local_call:" .. name
                            break
                        end
                        at = line:find(name, at + #name, true)
                    end
                    if not report.ok and report.failures[#report.failures]
                        and report.failures[#report.failures]:find(":" .. name, 1, true) then break end
                end
                report.checked = report.checked + 1
            end
        end

        -- Exact regression fixture: no forward declaration must fail; an
        -- explicit `local helper` before the caller must pass.
        local before = #report.failures
        scan("selftest_bad", "local function caller() helper() end\nlocal function helper() end")
        if #report.failures == before then
            report.ok = false
            report.failures[#report.failures + 1] = "selftest:missed_forward_local_call"
        else
            table.remove(report.failures)
            report.ok = true
        end
        before = #report.failures
        scan("selftest_good", "local helper\nlocal function caller() helper() end\nhelper = function() end")
        if #report.failures ~= before then
            report.ok = false
            report.failures[#report.failures + 1] = "selftest:false_positive_forward_declaration"
        end

        for _, path in ipairs(deps.packagePaths or {}) do
            if tostring(path):match("%.lua$") and path ~= "release_safety.lua" then
                local text, readErr = safeRead(path)
                if type(text) == "string" then
                    scan(path, text)
                else
                    report.skipped[#report.skipped + 1] = path .. ":source_unavailable:" .. tostring(readErr)
                end
            end
        end
        return report
    end
    mod.exports.__beta26.forwardLocalReferenceAudit = forwardLocalReferenceAudit

    local function run(id, fn, arg)
      if type(fn) ~= "function" then add(id, false, "audit unavailable"); return nil end
      local ok, result
      if arg ~= nil then ok, result = pcall(fn, arg) else ok, result = pcall(fn) end
      if not ok then add(id, false, result); return nil end
      local passed = result == true or (type(result) == "table" and result.ok == true)
      local detail = result
      if type(result) == "table" then
        detail = table.concat(result.failures or result.errors or {}, "; ")
        if detail == "" then detail = "ok" end
      end
      add(id, passed, detail)
      return result
    end

    run("rule_defaults", mod.exports.__beta26.auditNewRuleDefaults)
    run("rule_registry", mod.exports.__beta26.ruleRegistry and mod.exports.__beta26.ruleRegistry.audit)
    run("compat_contract", mod.exports.__beta26.compatContractAudit)
    run("compatibility_evidence", mod.exports.__beta26.compatibilityEvidenceClassificationAudit)
    run("release_safety_self_audit", mod.exports.__beta26.releaseSafetySelfAudit)
    run("gen2_semantic_seams", mod.exports.__beta26.gen2SemanticSeamAudit)
    run("gen1recomp_0_2_24", mod.exports.__beta26.gen1Recomp024Audit)
    run("gen1recomp_0_2_36", mod.exports.__beta26.gen1Recomp036FocusedAudit)
    run("gen2_tracker_map_order", mod.exports.__beta26.gen2TrackerPresentationAudit)
    run("difficulty_impact_warning", mod.exports.__beta26.difficultyImpactWarningAudit)
    run("compat_owner_controls", mod.exports.__beta26.compatOwnerControlAudit)
    run("late_runtime_message_dependencies",
      mod.exports.__beta26.lateRuntimeMessageDependencyAudit)
    run("registry_describe_context_consistency",
      mod.exports.nuzlocke and mod.exports.nuzlocke.registry
        and mod.exports.nuzlocke.registry.contextConsistencyAudit)
    run("semantic_behavior_regressions", mod.exports.__beta26.semanticBehaviorRegressionAudit)
    run("world_critical_feedback",
      mod.exports.__beta26.worldCriticalFeedbackAudit)
    run("randomizer_projection_ownership",
      mod.exports.__beta26.randomizerProjectionAudit)
    run("random_starter_species_pool_isolation",
      mod.exports.__beta26.randomStarterSpeciesPoolIsolationAudit)
    run("randomizer_encounter_profile_builds",
      mod.exports.__beta26.randomizerEncounterProfileBuildAudit)
    run("randomizer_learnset_phase_e_foundation",
      mod.exports.__beta26.randomizerLearnsetPhaseEFoundationAudit)
    run("randomizer_learnset_diagnostics",
      mod.exports.__beta26.randomizerLearnsetDiagnosticAudit)
    run("pure_helpers", mod.exports.__beta26.pureHelperAudit)
    run("public_documentation", mod.exports.__beta26.publicDocumentationAudit)
    run("package_drift", mod.exports.__beta26.packageDriftAudit)
    run("diagnostic_prefixes", mod.exports.__beta26.diagnosticPrefixAudit)

    local storedStateAudit = mod.exports.__beta26.storedStateAudit
    if type(storedStateAudit) == "function" then
      local okState, state = pcall(storedStateAudit)
      if not okState then
        add("stored_nonrule_state", false, tostring(state), false)
      elseif type(state) == "table" then
        add("stored_nonrule_state", state.ok == true,
          string.format("checked=%d present=%d failures=%d warnings=%d",
            tonumber(state.checked) or 0, tonumber(state.present) or 0,
            #(state.failures or {}), #(state.warnings or {})), false)
      else
        add("stored_nonrule_state", false, "audit returned no report", false)
      end
    end

    local storedValidator = mod.exports.__beta26.ruleRegistry
      and mod.exports.__beta26.ruleRegistry.validateStored
    if type(storedValidator) == "function" then
      local okStored, stored = pcall(storedValidator)
      if not okStored then
        add("stored_rule_values", false, tostring(stored), false)
      elseif type(stored) == "table" then
        local issueCount = (tonumber(stored.invalid_count) or 0)
          + (tonumber(stored.stale_count) or 0)
        local detail = string.format("checked=%d present=%d invalid=%d stale=%d",
          tonumber(stored.checked) or 0, tonumber(stored.present) or 0,
          tonumber(stored.invalid_count) or 0, tonumber(stored.stale_count) or 0)
        add("stored_rule_values", issueCount == 0, detail, false)
      else
        add("stored_rule_values", false, "validator returned no report", false)
      end
    else
      add("stored_rule_values", false, "validator unavailable", false)
    end

    run("save_schema_descriptor", mod.exports.__beta26.saveSchemaDescriptor and mod.exports.__beta26.saveSchemaDescriptor.audit)
    run("save_migration_integrity", mod.exports.__beta26.saveUpgrade and mod.exports.__beta26.saveUpgrade.audit)
    run("rule_interaction_matrix", mod.exports.__beta26.ruleInteractionMatrixAudit)
    run("save_migration_idempotence", mod.exports.__beta26.saveMigrationIdempotenceAudit)
    run("run_history_baseline_normalization",
      mod.exports.__beta26.RunHistory
        and mod.exports.__beta26.RunHistory.baselineNormalizationAudit)
    run("run_history_integrity",
      mod.exports.__beta26.RunHistory
        and mod.exports.__beta26.RunHistory.audit)
    run("gameplay_transaction_exactly_once",
      mod.exports.__beta26.GameplayTransactions and mod.exports.__beta26.GameplayTransactions.selfTest)
    run("rare_candy_transaction_identity",
      mod.exports.__beta26.RareCandyToCap and mod.exports.__beta26.RareCandyToCap.transactionIdentitySelfTest)
    run("hook_registry",
      mod.exports.__beta26.hookRegistry and mod.exports.__beta26.hookRegistry.audit)
    run("hook_lifecycle_install_order", mod.exports.__beta26.hookLifecycleInstallOrderAudit)
    run("edition_capability_failure_policy", mod.exports.__beta26.editionCapabilityFailurePolicyAudit)

    do
      local health = mod.exports.__beta26.featureHealth
      local install = mod.exports.__beta26.installHealth
      local valid = type(health) == "table" and health.api == 1
        and type(health.status) == "function"
        and type(install) == "table" and install.api == 3
        and type(mod.exports.__beta26.safeInstall) == "function"
      local detail = "install_api=" .. tostring(install and install.api)
        .. " feature_api=" .. tostring(health and health.api)
      add("feature_health_contract", valid, detail)

      if valid then
        local consistency = { ok=true, checked=0, failures={} }
        local expectedState = {
          ACTIVE = "ACTIVE",
          ["N/A"] = "N/A",
          PENDING = "PENDING",
        }
        for name, attempt in pairs(install.attempts or {}) do
          local feature = tostring(attempt.feature or name)
          local featureRow = health.features and health.features[feature] or nil
          -- Compare only when this installer is still the latest owner of the
          -- feature-health row. Hook health or another installer may legally
          -- supersede the same feature later in the lifecycle.
          if type(featureRow) == "table"
              and tostring(featureRow.source or "") == tostring(name) then
            consistency.checked = consistency.checked + 1
            local status = tostring(attempt.status or "")
            local expected = expectedState[status]
            if status == "FAIL" then
              expected = attempt.required == true and "UNAVAILABLE" or "DEGRADED"
            end
            if expected ~= nil and tostring(featureRow.state or "") ~= expected then
              consistency.ok = false
              consistency.failures[#consistency.failures + 1] =
                string.format("%s:%s->%s expected=%s",
                  tostring(name), status, tostring(featureRow.state), expected)
            end
          end
        end
        add("feature_health_consistency", consistency.ok,
          string.format("checked=%d failures=%d%s",
            consistency.checked, #consistency.failures,
            #consistency.failures > 0
              and (" first=" .. tostring(consistency.failures[1])) or ""),
          true)
      else
        add("feature_health_consistency", false,
          "feature/install health contract unavailable", true)
      end
    end

    do
      local stadium = mod.exports.nuzlocke_acquisition_provenance
      local stadiumBeta = mod.exports.__beta26
          and mod.exports.__beta26.StadiumPrize or nil
      local sameApi = type(stadium) == "table" and stadium == stadiumBeta
      local methodsOk = sameApi
          and tonumber(stadium.version) == 2
          and type(stadium.mark) == "function"
          and type(stadium.markImported) == "function"
          and type(stadium.describe) == "function"
          and type(stadium.compatibilitySnapshot) == "function"
      add("stadium_provenance_contract", methodsOk,
          string.format("same_api=%s version=%s mark=%s imported=%s describe=%s snapshot=%s",
            tostring(sameApi), tostring(type(stadium) == "table" and stadium.version or nil),
            tostring(type(stadium) == "table" and type(stadium.mark) or "nil"),
            tostring(type(stadium) == "table" and type(stadium.markImported) or "nil"),
            tostring(type(stadium) == "table" and type(stadium.describe) or "nil"),
            tostring(type(stadium) == "table" and type(stadium.compatibilitySnapshot) or "nil")))
    end

    local mainSource, mainErr = safeRead("main.lua")
    local worldSource, worldErr = safeRead("world_building.lua")
    if mainSource then
      local deadFallbackSource = mainSource
      if worldSource then deadFallbackSource = deadFallbackSource .. "\n" .. worldSource end
      run("dead_fallback_lint", mod.exports.__beta26.deadFallbackAudit, deadFallbackSource)

      -- 2.8.76: three focused correctness repairs.
    local mainSource2876 = safeRead("main.lua") or ""
    local forgivenessSource2876 = safeRead("forgiveness.lua") or ""
    local worldSource2876 = safeRead("world_building.lua") or ""
    add("rby_ball_policy_fail_closed",
      mainSource2876:find("safeRbyBallUsePolicy", 1, true) ~= nil
      and mainSource2876:find('"rby_ball_use:"', 1, true) ~= nil
      and mainSource2876:find('code = "policy_error"', 1, true) ~= nil
      and mainSource2876:find("local useAllowed, useDecision = safeRbyBallUsePolicy(", 1, true) ~= nil)
    add("forgiveness_failed_projection_status_exact",
      forgivenessSource2876:find("encounterStateIsFailed", 1, true) ~= nil
      and forgivenessSource2876:find("state.status == \"FAILED\"", 1, true) ~= nil
      and forgivenessSource2876:find("states[key] ~= nil then return true", 1, true) == nil)
    add("world_building_exact_six_editions",
      worldSource2876:find('"red", "blue", "yellow", "gold", "silver", "crystal"', 1, true) ~= nil
      and worldSource2876:find("exactEditionCount = #exactEditions", 1, true) ~= nil
      and worldSource2876:find("* 3 * 5", 1, true) == nil
      and worldSource2876:find("* 5 * 3 * 3", 1, true) == nil)

    -- 2.8.75: Run History death-event boolean preservation.
    local runHistorySource2875 = safeRead("run_history.lua") or ""
    add("run_history_death_shiny_false_preserved",
      runHistorySource2875:find("local shiny = fields.shiny", 1, true) ~= nil
      and runHistorySource2875:find("if shiny == nil and mon then shiny = deps.isShiny(mon) end", 1, true) ~= nil
      and runHistorySource2875:find("shiny = shiny,", 1, true) ~= nil
      and runHistorySource2875:find("fields.shiny ~= nil and fields.shiny", 1, true) == nil)
    add("run_history_death_shiny_selftest",
      type(mod.exports.__beta26.RunHistory) == "table"
      and type(mod.exports.__beta26.RunHistory.deathShinyBooleanSelfTest) == "function")

    -- 2.8.74: Gen-I acquisition catalog/fallback consistency.
    local acquisitionSource2874 = safeRead("acquisition_catalog.lua") or ""
    add("acquisition_magikarp_deterministic_gift",
      acquisitionSource2874:find("MAGIKARP = true", 1, true) ~= nil
      and acquisitionSource2874:find('species = "MAGIKARP"', 1, true) ~= nil)
    add("acquisition_catalog_consistency_selftest",
      acquisitionSource2874:find("acquisitionCatalogConsistencySelfTest", 1, true) ~= nil
      and acquisitionSource2874:find("for _, gift in ipairs(GIFT_LOCATIONS)", 1, true) ~= nil
      and acquisitionSource2874:find("gift.version == nil", 1, true) ~= nil
      and acquisitionSource2874:find('"gift", species', 1, true) ~= nil)

    -- 2.8.77: migration/interoperability/diagnostic correctness hardening.
    local migrationSource2877 = safeRead("save_migration.lua") or ""
    local interopSource2877 = safeRead("public_interop.lua") or ""
    local mainSource2877 = safeRead("main.lua") or ""
    local randomizerSource2877 = safeRead("randomizer_runtime.lua") or ""
    add("shadow_store_copy_on_read",
      migrationSource2877:find("return deps.copy(row.after_value)", 1, true) ~= nil
      and migrationSource2877:find("shadowCopyIsolation", 1, true) ~= nil
      and migrationSource2877:find("shadowRead.nested.value = 88", 1, true) ~= nil)
    add("content_bundle_prevalidation_atomicity",
      interopSource2877:find("validateContentBundle", 1, true) ~= nil
      and interopSource2877:find("Content.bundleSelfTest", 1, true) ~= nil
      and interopSource2877:find("bad late child", 1, true) ~= nil
      and interopSource2877:find("untouched = Content.areas[unique] == beforeArea", 1, true) ~= nil)
    local compatibilityOwner2877 = ownerSource("compatibility") or ""
    local diagnosticsOwner2877 = ownerSource("diagnostics") or ""
    add("compat_runtime_environment_value",
      compatibilityOwner2877:find(
        "runtime_environment = mod.exports.__beta26.runtimeEnvironment()", 1, true) ~= nil)
    add("gen2_field_item_hook_health_sessions",
      diagnosticsOwner2877:find("__nuzlockeRandomFieldItemBallSession2808", 1, true) ~= nil
      and diagnosticsOwner2877:find("__nuzlockeRandomHiddenItemSession2808", 1, true) ~= nil
      and diagnosticsOwner2877:find('id="random_field_items_gold_hidden"', 1, true) ~= nil)
    add("trainer_party_semantic_hook_health",
      randomizerSource2877:find("randomTrainerHookHealth = function", 1, true) ~= nil
      and randomizerSource2877:find('hooks.chains["trainer.party"]', 1, true) ~= nil
      and randomizerSource2877:find("primary_registered", 1, true) ~= nil
      and randomizerSource2877:find("finalizer_registered", 1, true) ~= nil
      and diagnosticsOwner2877:find('id="random_trainers_hook_chain"', 1, true) ~= nil)

    -- 2.8.73: transaction/interoperability hardening. Durable transaction
    -- identity includes payload, and external item-policy exceptions fail closed.
    local migrationSource2873 = safeRead("save_migration.lua") or ""
    local interopSource2873 = safeRead("public_interop.lua") or ""
    add("tx_same_kind_payload_collision_guard",
      migrationSource2873:find("txPayloadFingerprint", 1, true) ~= nil
      and migrationSource2873:find("transaction_payload_mismatch", 1, true) ~= nil
      and migrationSource2873:find("receipt_payload_mismatch", 1, true) ~= nil
      and migrationSource2873:find("payload_fingerprint", 1, true) ~= nil)
    add("tx_payload_collision_selftest",
      migrationSource2873:find('receiptPayloadReason == "receipt_payload_mismatch"', 1, true) ~= nil
      and migrationSource2873:find('sameIdPayloadReason == "transaction_payload_mismatch"', 1, true) ~= nil
      and migrationSource2873:find("checkpointReplayOk == true", 1, true) ~= nil)
    add("public_item_policy_fail_closed",
      interopSource2873:find('rule="policy_error"', 1, true) ~= nil
      and interopSource2873:find('reason="policy_error"', 1, true) ~= nil
      and interopSource2873:find('code="policy_error"', 1, true) ~= nil
      and interopSource2873:find('lastItemPolicyError', 1, true) ~= nil
      and interopSource2873:find("if not ok then", 1, true) ~= nil)

    -- 2.8.72: difficulty UX/documentation consolidation. Exact-edition
    -- Silver/Crystal catalogs, native confirmation cursors, scrollable chooser
    -- details, and fully documented profile mechanics are promotion gates.
    local mainSource2872 = safeRead("main.lua") or ""
    local guideSource2872 = safeRead("docs/USER_GUIDE.md") or ""
    add("difficulty_exact_gen2_edition_routing",
      mainSource2872:find('id:find("crystal",1,true) then return "crystal"', 1, true) ~= nil
      and mainSource2872:find('id:find("silver",1,true) then return "silver"', 1, true) ~= nil
      and mainSource2872:find('silver = {', 1, true) ~= nil
      and mainSource2872:find('crystal = {', 1, true) ~= nil
      and mainSource2872:find('id="silver_polished"', 1, true) ~= nil
      and mainSource2872:find('id="crystal_polished"', 1, true) ~= nil)
    add("difficulty_native_confirmation_cursor",
      mainSource2872:find('Font.drawCode(Theme.cursor,10,116)', 1, true) ~= nil
      and mainSource2872:find('Font.drawCode(Theme.cursor,72,116)', 1, true) ~= nil
      and mainSource2872:find('and "> " or "  "', 1, true) == nil)
    add("difficulty_review_scrollable_details",
      mainSource2872:find('summaryScroll=0', 1, true) ~= nil
      and mainSource2872:find('game.input:wasPressed("select")', 1, true) ~= nil
      and mainSource2872:find('"SEL:MORE"', 1, true) ~= nil
      and mainSource2872:find('"LR:PROFILE A:OK B:BACK"', 1, true) ~= nil)
    add("difficulty_player_copy_no_percent_glyph",
      mainSource2872:find('"TEAM UPGRADES: %d OF 100 / %d OF 100"', 1, true) ~= nil
      and mainSource2872:find('"LEVELS AT 25: +%d REG / +%d BOSS"', 1, true) ~= nil
      and mainSource2872:find('"LV %d%%/%d%%', 1, true) == nil
      and mainSource2872:find('pairText(from, "levelPct", "%")', 1, true) == nil)
    add("difficulty_full_documentation",
      guideSource2872:find("Difficulty Profiles — Full Mechanical Reference (2.8.72)", 1, true) ~= nil
      and guideSource2872:find("Trainer level scale.", 1, true) ~= nil
      and guideSource2872:find("Team upgrade chance.", 1, true) ~= nil
      and guideSource2872:find("Species BST tuning.", 1, true) ~= nil
      and guideSource2872:find("Silver profiles", 1, true) ~= nil
      and guideSource2872:find("Crystal profiles", 1, true) ~= nil
      and guideSource2872:find("In-game chooser versus documentation", 1, true) ~= nil)

    -- 2.8.71: Discord runtime follow-up. Gen1 Difficulty Review must not
    -- call a helper outside its lexical scope, Gen1 profile controls must render
    -- their actual state/actions, and all numeric rules must remain registry-
    -- bounded through the shared coercion path.
    local mainSource2871 = safeRead("main.lua") or ""
    add("gen1_difficulty_review_safe_wrap",
      mainSource2871:find("local sum=lines", 1, true) ~= nil
      and mainSource2871:find("local sum=wrapPixelText(text,136)", 1, true) == nil)
    add("gen1_profile_control_rendering",
      mainSource2871:find("elseif item.isSetupPresetSlot then", 1, true) ~= nil
      and mainSource2871:find('label = "SAVED"', 1, true) ~= nil
      and mainSource2871:find('label = "LOADED"', 1, true) ~= nil
      and mainSource2871:find('and "LOAD" or "EMPTY"', 1, true) ~= nil)
    add("numeric_rule_registry_coercion",
      mainSource2871:find('coerceRuleValue(key, stored, "read")', 1, true) ~= nil
      and mainSource2871:find('coerceRuleValue(key, value, "write")', 1, true) ~= nil
      and type(mod.exports.__beta26.coerceRuleValue) == "function")
    local numericRulesOk, numericRulesChecked = true, 0
    for key, rule in pairs(mod.exports.__beta26.ruleDefinitionByKey or {}) do
      if type(rule) == "table"
          and (rule.numeric == true or rule.value_type == "number") then
        numericRulesChecked = numericRulesChecked + 1
        local minValue, maxValue = tonumber(rule.min), tonumber(rule.max)
        local defaultValue = tonumber(rule.default)
        if minValue == nil or maxValue == nil or defaultValue == nil
            or minValue > maxValue
            or defaultValue < minValue or defaultValue > maxValue then
          numericRulesOk = false
          break
        end
        local low = mod.exports.__beta26.coerceRuleValue(key, minValue - 999999, "read")
        local high = mod.exports.__beta26.coerceRuleValue(key, maxValue + 999999, "read")
        if tonumber(low) ~= minValue or tonumber(high) ~= maxValue then
          numericRulesOk = false
          break
        end
      end
    end
    add("numeric_rule_registry_bounds",
      numericRulesOk and numericRulesChecked >= 67,
      "checked=" .. tostring(numericRulesChecked))

    -- 2.8.70: Run History v2 correctness repair. Abandons are durable,
    -- coverage completeness checks every summarized event kind, and stored
    -- state validation follows the current Run History storage version.
    local runHistorySource2870 = safeRead("run_history.lua") or ""
    local devDiagnosticsSource2870 = safeRead("dev_diagnostics.lua") or ""
    add("run_history_abandon_durable_summary",
      runHistorySource2870:find('["run.abandoned"] = "abandons"', 1, true) ~= nil
      and runHistorySource2870:find("stats.flags.abandoned = true", 1, true) ~= nil
      and runHistorySource2870:find("root.summary.abandons == nil", 1, true) ~= nil
      and runHistorySource2870:find("root.statistics.counters.abandons", 1, true) ~= nil)
    add("run_history_summary_driven_partial_coverage",
      runHistorySource2870:find("if total > retained then", 1, true) ~= nil
      and runHistorySource2870:find('retainedKinds["pokemon.caught"]', 1, true) == nil
      and runHistorySource2870:find('retainedKinds["pokemon.died"]', 1, true) == nil)
    add("stored_state_history_version_dynamic",
      devDiagnosticsSource2870:find("expectedHistoryVersion", 1, true) ~= nil
      and devDiagnosticsSource2870:find("RunHistory.storage_version", 1, true) ~= nil
      and devDiagnosticsSource2870:find("tonumber(history.version) == 1", 1, true) == nil)

      -- 2.8.69: translation compatibility consolidation. Keep normalized
    -- target roles, dependency ordering, and reviewed exclusions coherent.
    local mainSource2869 = safeRead("main.lua") or ""
    local manifestSource2869 = safeRead("manifest.json") or ""
    local compatDocs2869 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_registry_target_classes",
      mainSource2869:find('targetClass = "current_primary"', 1, true) ~= nil
      and mainSource2869:find('targetClass = "current_alternate"', 1, true) ~= nil
      and mainSource2869:find('targetClass = "current_overlay"', 1, true) ~= nil
      and mainSource2869:find('targetClass = "legacy"', 1, true) ~= nil
      and mainSource2869:find('targetClass = "legacy_alternate"', 1, true) ~= nil)
    add("translation_finnish_optional_dependency",
      manifestSource2869:find('"translation-nl"', 1, true) ~= nil
      and manifestSource2869:find('"finnish"', 1, true) ~= nil)
    add("translation_review_exclusions",
      mainSource2869:find('translationReviewExclusions = {', 1, true) ~= nil
      and mainSource2869:find('yyoossk/Gen1Recomp-translation-jp-mod', 1, true) ~= nil
      and mainSource2869:find('ShiraTheMogul/gen1recomp-lzh', 1, true) ~= nil
      and mainSource2869:find('zhangjiyz/gen1recomp-translation-mod-generator-cn', 1, true) ~= nil
      and mainSource2869:find('nevespt/VersaoEncarnada', 1, true) ~= nil)
    add("translation_consolidated_matrix",
      compatDocs2869:find("Translation registry consolidation — 2.8.69", 1, true) ~= nil
      and compatDocs2869:find("Reviewed but not runtime companions", 1, true) ~= nil)

    -- 2.8.68: alternate Spanish Red target. Keep it distinct from the
    -- existing primary Spanish target and reuse presentation/mutation contracts.
    local mainSource2868 = safeRead("main.lua") or ""
    local compatDocs2868 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_spanish_alternate_target",
      mainSource2868:find('["spanish_translation"] = {', 1, true) ~= nil
      and mainSource2868:find('reviewed = "0.1.0"', 1, true) ~= nil
      and mainSource2868:find('status = "alternate_spanish_red_target"', 1, true) ~= nil
      and mainSource2868:find('editions = { "red" }', 1, true) ~= nil
      and mainSource2868:find('lineage = "fork_of_versaovermelha"', 1, true) ~= nil)
    add("translation_spanish_alternate_wrappers_scripts",
      mainSource2868:find('battleUiOverride = true', 1, true) ~= nil
      and mainSource2868:find('replacementMapScripts = true', 1, true) ~= nil
      and mainSource2868:find('replacementMapScriptsPresent = true', 1, true) ~= nil
      and mainSource2868:find('mutationReviewRequired = true', 1, true) ~= nil)
    add("translation_spanish_alternate_matrix",
      compatDocs2868:find("`spanish_translation`", 1, true) ~= nil
      and compatDocs2868:find("Alternate Spanish", 1, true) ~= nil)
    -- 2.8.67: Finnish target promotion from upstream-unverified to
    -- reviewed current Red target, reusing existing presentation-wrapper and
    -- replacement-script mutation contracts.
    local mainSource2867 = safeRead("main.lua") or ""
    local devSource2867 = safeRead("dev_report.lua") or ""
    local compatDocs2867 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_finnish_target",
      mainSource2867:find('["finnish"] = {', 1, true) ~= nil
      and mainSource2867:find('reviewed = "0.1.0"', 1, true) ~= nil
      and mainSource2867:find('status = "current_finnish_target"', 1, true) ~= nil
      and mainSource2867:find('editions = { "red" }', 1, true) ~= nil
      and mainSource2867:find('fixedCellExtendedLatin = true', 1, true) ~= nil)
    add("translation_finnish_wrappers_and_scripts",
      mainSource2867:find('engineInternalsPresentationWrappers = true', 1, true) ~= nil
      and mainSource2867:find('replacementMapScripts = true', 1, true) ~= nil
      and mainSource2867:find('replacementMapScriptsPresent = true', 1, true) ~= nil
      and mainSource2867:find('mutationReviewRequired = true', 1, true) ~= nil
      and devSource2867:find('ACTIVE/KNOWN', 1, true) ~= nil)
    add("translation_finnish_matrix",
      compatDocs2867:find("`finnish`", 1, true) ~= nil
      and compatDocs2867:find("Finnish", 1, true) ~= nil
      and compatDocs2867:find("Red", 1, true) ~= nil)
    add("translation_finnish_no_gameplay_literals",
      mainSource2867:find('== "OSTA"', 1, true) == nil
      and mainSource2867:find('== "MYY"', 1, true) == nil
      and mainSource2867:find('== "PAKENE"', 1, true) == nil)

    -- 2.8.66: Dutch R/B target. Generated runtime explicitly loads
    -- mutation-capable literal handlers, so replacement-script review is known
    -- active rather than merely source-present.
    local mainSource2866 = safeRead("main.lua") or ""
    local devSource2866 = safeRead("dev_report.lua") or ""
    local compatDocs2866 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_dutch_target",
      mainSource2866:find('["translation-nl"] = {', 1, true) ~= nil
      and mainSource2866:find('reviewed = "0.0.2"', 1, true) ~= nil
      and mainSource2866:find('editions = { "red", "blue" }', 1, true) ~= nil
      and mainSource2866:find('asciiFoldedAccents = true', 1, true) ~= nil
      and mainSource2866:find('noLocalizedFont = true', 1, true) ~= nil)
    add("translation_dutch_replacement_scripts_active",
      mainSource2866:find('replacementMapScripts = true', 1, true) ~= nil
      and mainSource2866:find('replacementMapScriptsPresent = true', 1, true) ~= nil
      and mainSource2866:find('mutationReviewRequired = true', 1, true) ~= nil
      and devSource2866:find('ACTIVE/KNOWN', 1, true) ~= nil)
    add("translation_dutch_matrix",
      compatDocs2866:find("`translation-nl`", 1, true) ~= nil
      and compatDocs2866:find("Dutch", 1, true) ~= nil
      and compatDocs2866:find("Red / Blue", 1, true) ~= nil)
    add("translation_dutch_no_gameplay_literals",
      mainSource2866:find('== "KOPEN"', 1, true) == nil
      and mainSource2866:find('== "VERKOPEN"', 1, true) == nil
      and mainSource2866:find('== "VLUCHT"', 1, true) == nil)

    -- 2.8.65: Simplified Chinese R/B/Y target + generalized narrow,
    -- compositional translation-presentation wrapper contract.
    local mainSource2865 = safeRead("main.lua") or ""
    local interopSource2865 = safeRead("public_interop.lua") or ""
    local devSource2865 = safeRead("dev_report.lua") or ""
    local compatDocs2865 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_simplified_chinese_target",
      mainSource2865:find('["zh_cn"] = {', 1, true) ~= nil
      and mainSource2865:find('reviewed = "0.3.1"', 1, true) ~= nil
      and mainSource2865:find('editions = { "red", "blue", "yellow" }', 1, true) ~= nil
      and mainSource2865:find('fixedCellCJK = true', 1, true) ~= nil
      and mainSource2865:find('engineInternalsPresentationWrappers = true', 1, true) ~= nil)
    add("translation_presentation_wrapper_contract",
      interopSource2865:find("translation_presentation_wrapper={", 1, true) ~= nil
      and interopSource2865:find("must be narrow, compositional, delegate next/original behavior", 1, true) ~= nil
      and interopSource2865:find("never make Nuzlocke-owned UI depend on caller path or fixed engine coordinates", 1, true) ~= nil
      and interopSource2865:find('"translation_presentation_wrapper"', 1, true) ~= nil)
    add("translation_simplified_chinese_diagnostics",
      devSource2865:find("PRESENTATION WRAPPERS: ENGINE INTERNALS / COMPOSITION REVIEW", 1, true) ~= nil
      and devSource2865:find("TEXT MODEL: FIXED-CELL CJK", 1, true) ~= nil)
    add("translation_simplified_chinese_matrix",
      compatDocs2865:find("`zh_cn`", 1, true) ~= nil
      and compatDocs2865:find("Simplified Chinese", 1, true) ~= nil
      and compatDocs2865:find("Red / Blue / Yellow", 1, true) ~= nil)
    add("translation_chinese_no_gameplay_literals",
      mainSource2865:find('== "战斗"', 1, true) == nil
      and mainSource2865:find('== "逃跑"', 1, true) == nil
      and mainSource2865:find('== "购买"', 1, true) == nil
      and mainSource2865:find('== "出售"', 1, true) == nil)

    -- 2.8.64: Polish translation target. Keep upstream scope conservative
    -- and distinguish replacement-script presence from confirmed runtime load.
    local mainSource2864 = safeRead("main.lua") or ""
    local devSource2864 = safeRead("dev_report.lua") or ""
    local compatDocs2864 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_polish_target",
      mainSource2864:find('["recomp-polish"] = {', 1, true) ~= nil
      and mainSource2864:find('reviewed = "1.0.0"', 1, true) ~= nil
      and mainSource2864:find('editions = { "red" }', 1, true) ~= nil
      and mainSource2864:find('fixedCellExtendedLatin = true', 1, true) ~= nil
      and mainSource2864:find('partialEnglishFallback = true', 1, true) ~= nil)
    add("translation_polish_replacement_script_review",
      mainSource2864:find('replacementMapScriptsPresent = true', 1, true) ~= nil
      and mainSource2864:find('mutationReviewRequired = true', 1, true) ~= nil
      and devSource2864:find('PRESENT/LOAD UNCONFIRMED', 1, true) ~= nil)
    add("translation_polish_matrix",
      compatDocs2864:find("recomp-polish", 1, true) ~= nil
      and compatDocs2864:find("Polish", 1, true) ~= nil
      and compatDocs2864:find("Red", 1, true) ~= nil)
    add("translation_polish_no_gameplay_literals",
      mainSource2864:find('== "KUP"', 1, true) == nil
      and mainSource2864:find('== "SPRZEDAJ"', 1, true) == nil
      and mainSource2864:find('== "UCIEKAJ"', 1, true) == nil)

    -- 2.8.63: Italian translation targets + generalized replacement-script
    -- mutation contract. Translation-owned map scripts may translate vanilla
    -- interactions but must not bypass Nuzlocke semantic policy.
    local mainSource2863 = safeRead("main.lua") or ""
    local interopSource2863 = safeRead("public_interop.lua") or ""
    local compatDocs2863 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_italian_targets",
      mainSource2863:find('["translation-it"] = {', 1, true) ~= nil
      and mainSource2863:find('reviewed = "0.6.0"', 1, true) ~= nil
      and mainSource2863:find('editions = { "red", "blue", "yellow" }', 1, true) ~= nil
      and mainSource2863:find('["recomp-italian"] = {', 1, true) ~= nil
      and mainSource2863:find('reviewed = "0.1.0"', 1, true) ~= nil)
    add("translation_replacement_script_contract",
      interopSource2863:find("translation_replacement_script_mutation={", 1, true) ~= nil
      and interopSource2863:find("must preserve native Nuzlocke-gated entrypoints or call semantic policy", 1, true) ~= nil
      and interopSource2863:find('"translation_replacement_script_mutation"', 1, true) ~= nil)
    add("translation_italian_matrix",
      compatDocs2863:find("translation-it", 1, true) ~= nil
      and compatDocs2863:find("recomp-italian", 1, true) ~= nil)

    -- 2.8.62: session-only manual localization certification. Certification
    -- must never be inferred from static diagnostics or written to save data.
    local mainSource2862 = safeRead("main.lua") or ""
    local devReportSource2862 = safeRead("dev_report.lua") or ""
    local classicSource2862 = safeRead("classic_ui.lua") or ""
    add("localization_certification_session_only",
      devReportSource2862:find("local LOCALIZATION_CERT_CHECKS = {", 1, true) ~= nil
      and devReportSource2862:find("localizationCertificationSessions", 1, true) ~= nil
      and devReportSource2862:find("session_only=true", 1, true) ~= nil
      and devReportSource2862:find("mod.save:set", devReportSource2862:find("LOCALIZATION_CERT_CHECKS", 1, true) or 1, true) == nil)
    add("localization_certification_manual_states",
      devReportSource2862:find('row.state == "UNTESTED"', 1, true) ~= nil
      and devReportSource2862:find('nextState = "PASS"', 1, true) ~= nil
      and devReportSource2862:find('nextState = "FAIL"', 1, true) ~= nil
      and devReportSource2862:find('else nextState = "UNTESTED" end', 1, true) ~= nil
      and devReportSource2862:find("#companions > 0 and untested == 0 and fail == 0", 1, true) ~= nil)
    add("localization_certification_exact_identity",
      devReportSource2862:find("localizationCertIdentity(game)", 1, true) ~= nil
      and devReportSource2862:find("row.id, row.version, row.activity", 1, true) ~= nil
      and devReportSource2862:find("row.bootLanguage or", 1, true) ~= nil
      and devReportSource2862:find("row.pendingLanguage or", 1, true) ~= nil)
    add("localization_certification_dev_surface",
      classicSource2862:find('"LOCAL CERT"', 1, true) ~= nil
      and classicSource2862:find('elseif name == "LOCAL CERT" then', 1, true) ~= nil
      and classicSource2862:find("localizationCertificationMark(", 1, true) ~= nil
      and classicSource2862:find('Strings("A:MARK  U/D:CHECK")', 1, true) ~= nil
      and classicSource2862:find("local function devUiGlyphCount(text)", 1, true) ~= nil
      and classicSource2862:find("leftWidth - devUiGlyphCount(l) + 1", 1, true) ~= nil)
    add("translation_certification_sources",
      mainSource2862:find('{ source="LOCAL CERT", kind="localization_cert_ui" }', 1, true) ~= nil
      and mainSource2862:find('{ source="SETUP / NUZ RULES", kind="localization_cert_check" }', 1, true) ~= nil
      and mainSource2862:find('{ source="DEV REPORT / LOCALIZATION", kind="localization_cert_check" }', 1, true) ~= nil)

    -- 2.8.61: Japanese-driven audit of remaining owned UI byte-length /
    -- fixed-column assumptions. All localized truncation must use shared
    -- glyph boundaries or rendered-pixel fitting.
    local mainSource2861 = safeRead("main.lua") or ""
    local classicSource2861 = safeRead("classic_ui.lua") or ""
    local pokegearSource2861 = safeRead("pokegear_integration.lua") or ""
    local lateSource2861 = safeRead("late_runtime.lua") or ""
    add("localization_internal_glyph_helpers_shared",
      mainSource2861:find("mod.exports.__beta26.nuzGlyphSpans = nuzGlyphSpans", 1, true) ~= nil
      and mainSource2861:find("mod.exports.__beta26.nuzGlyphLen = nuzGlyphLen", 1, true) ~= nil
      and mainSource2861:find("mod.exports.__beta26.nuzGlyphSlice = nuzGlyphSlice", 1, true) ~= nil)
    add("localization_pokegear_glyph_safe",
      pokegearSource2861:find("beta.nuzGlyphLen", 1, true) ~= nil
      and pokegearSource2861:find("beta.nuzGlyphSlice", 1, true) ~= nil
      and pokegearSource2861:find("if #text <= width then return text end", 1, true) == nil
      and pokegearSource2861:find("text:sub(1, math.max(1, width - 1))", 1, true) == nil
      and pokegearSource2861:find('S("CAUGHT %d", snap.catches)', 1, true) ~= nil)
    add("localization_classic_no_byte_truncation",
      classicSource2861:find('species or "???"):sub(1, 12)', 1, true) == nil
      and classicSource2861:find("sp:sub(1, 11)", 1, true) == nil
      and classicSource2861:find("sp:sub(1, 10)", 1, true) == nil
      and classicSource2861:find("name):sub(1, 15)", 1, true) == nil
      and classicSource2861:find("if #label > 18 then label = label:sub(1, 18) end", 1, true) == nil
      and classicSource2861:find("clipGlyphText(compactArea", 1, true) ~= nil
      and classicSource2861:find("clipGlyphText(lastEvent", 1, true) ~= nil)
    add("localization_gen2_error_glyph_safe",
      lateSource2861:find("beta.nuzGlyphLen(detail) > 72", 1, true) ~= nil
      and lateSource2861:find("beta.nuzGlyphSlice(detail, 1, 69)", 1, true) ~= nil
      and lateSource2861:find('Strings("CAUGHT %d   LOST %d", caught, lost)', 1, true) ~= nil)
    add("translation_pokegear_status_sources",
      mainSource2861:find('{ source="NUZ %d/4", kind="pokegear_ui" }', 1, true) ~= nil
      and mainSource2861:find('{ source="RULES %d/%d", kind="pokegear_ui" }', 1, true) ~= nil
      and mainSource2861:find('{ source="CAUGHT %d   LOST %d", kind="gen2_status" }', 1, true) ~= nil)

    -- 2.8.60: Japanese/CJK compatibility target. Japanese uses the
    -- engine TTF path and UTF-8 multibyte text; Nuzlocke must preserve its
    -- glyph-span helpers and never use byte length/slicing for owned UI.
    local mainSource2860 = safeRead("main.lua") or ""
    local manifestSource2860 = safeRead("manifest.json") or ""
    local compatDocs2860 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_japanese_target",
      mainSource2860:find('["translation-ja-hrkt"] = {', 1, true) ~= nil
      and mainSource2860:find('reviewed = "0.4.2"', 1, true) ~= nil
      and mainSource2860:find('editions = { "red", "blue" }', 1, true) ~= nil
      and mainSource2860:find('fontModel = "engine_plain_pixel_ttf"', 1, true) ~= nil
      and manifestSource2860:find('"translation-ja-hrkt"', 1, true) ~= nil)
    add("translation_japanese_glyph_safe",
      mainSource2860:find("local function nuzGlyphSpans", 1, true) ~= nil
      and mainSource2860:find("Font.split(text)", 1, true) ~= nil
      and mainSource2860:find("utf8lib.codes(text)", 1, true) ~= nil
      and mainSource2860:find("local function nuzGlyphLen", 1, true) ~= nil
      and mainSource2860:find("local function nuzGlyphSlice", 1, true) ~= nil)
    add("translation_japanese_matrix",
      compatDocs2860:find("translation-ja-hrkt", 1, true) ~= nil
      and compatDocs2860:find("Japanese", 1, true) ~= nil
      and compatDocs2860:find("Red / Blue", 1, true) ~= nil)
    add("translation_japanese_no_gameplay_literals",
      mainSource2860:find('== "たたかう"', 1, true) == nil
      and mainSource2860:find('== "にげる"', 1, true) == nil
      and mainSource2860:find('== "どうぐ"', 1, true) == nil
      and mainSource2860:find('== "ポケモン"', 1, true) == nil)

    -- 2.8.59: translation compatibility matrix + remaining high-value
    -- authored source discovery. Matrix documentation must stay reconciled
    -- with the known-companion registry, and Forgiveness/Battle Clause text
    -- must remain discoverable without language-specific policy branches.
    local mainSource2859 = safeRead("main.lua") or ""
    local compatDocs2859 = safeRead("docs/COMPATIBILITY.md") or ""
    add("translation_matrix_registry_reconciled",
      compatDocs2859:find("Translation compatibility matrix", 1, true) ~= nil
      and compatDocs2859:find("gen1_pt-br", 1, true) ~= nil
      and compatDocs2859:find("versaovermelha", 1, true) ~= nil
      and compatDocs2859:find("translation-german-universal", 1, true) ~= nil
      and compatDocs2859:find("traduccion_es", 1, true) ~= nil
      and compatDocs2859:find("translation-fr", 1, true) ~= nil
      and compatDocs2859:find("trad-fr-extended", 1, true) ~= nil
      and compatDocs2859:find("finnish", 1, true) ~= nil
      and mainSource2859:find('["translation-fr"] = {', 1, true) ~= nil
      and mainSource2859:find('["traduccion_es"] = {', 1, true) ~= nil)
    add("translation_forgiveness_sources",
      mainSource2859:find('{ source="REROLL ENCOUNTER", kind="forgiveness_ui" }', 1, true) ~= nil
      and mainSource2859:find('{ source="REVIVE POKEMON", kind="forgiveness_ui" }', 1, true) ~= nil
      and mainSource2859:find('{ source="You have no F. TOKEN.", kind="forgiveness_message" }',
        1, true) ~= nil
      and mainSource2859:find('source="F. TOKEN used.\\n%s was revived!"', 1, true) ~= nil)
    add("translation_battle_clause_sources",
      mainSource2859:find('{ source="OHKO Clause blocked the move.", kind="battle_clause_message" }',
        1, true) ~= nil
      and mainSource2859:find('{ source="Sleep Clause blocked the move.", kind="battle_clause_message" }',
        1, true) ~= nil
      and mainSource2859:find('{ source="Other Stat Drops blocked the drop.", kind="battle_clause_message" }',
        1, true) ~= nil
      and mainSource2859:find('{ source="Confusion ban blocked the effect.", kind="battle_clause_message" }',
        1, true) ~= nil)
    add("translation_runtime_status_sources",
      mainSource2859:find('{ source="NUZ INFO", kind="ui_common" }', 1, true) ~= nil
      and mainSource2859:find('{ source="MOD COMPAT", kind="compat_ui" }', 1, true) ~= nil
      and mainSource2859:find('{ source="Buying is disabled.", kind="runtime_message" }', 1, true) ~= nil
      and mainSource2859:find('source="Held items are banned by your Nuzlocke rules."', 1, true) ~= nil)

    -- 2.8.58: explicit French translation compatibility. The generated
    -- base translation and the optional gap-filling overlay remain distinct
    -- content companions; neither may become gameplay-policy semantics.
    local mainSource2858 = safeRead("main.lua") or ""
    local manifestSource2858 = safeRead("manifest.json") or ""
    add("translation_french_targets",
      mainSource2858:find('["translation-fr"] = {', 1, true) ~= nil
      and mainSource2858:find('reviewed = "0.8.0"', 1, true) ~= nil
      and mainSource2858:find('["trad-fr-extended"] = {', 1, true) ~= nil
      and mainSource2858:find('reviewed = "0.2.0"', 1, true) ~= nil
      and mainSource2858:find('requiresCompanion = "translation-fr"', 1, true) ~= nil
      and manifestSource2858:find('"translation-fr"', 1, true) ~= nil
      and manifestSource2858:find('"trad-fr-extended"', 1, true) ~= nil)
    add("translation_french_all_editions_scope",
      mainSource2858:find('editions = { "red", "blue", "yellow", "gold", "silver", "crystal" }',
        1, true) ~= nil
      and mainSource2858:find('generatedBy = "gen1recomp-translation-mod-generator"',
        1, true) ~= nil)
    add("translation_french_no_gameplay_literals",
      mainSource2858:find('shop == "ACHETER"', 1, true) == nil
      and mainSource2858:find('shop == "VENDRE"', 1, true) == nil
      and mainSource2858:find('shop == "FUITE"', 1, true) == nil
      and mainSource2858:find('shop == "ATTAQUE"', 1, true) == nil)

    -- 2.8.57: explicit Spanish translation compatibility. The target is
    -- a content/LANGUAGE companion; Nuzlocke records it separately and must
    -- never add Spanish display literals to gameplay policy.
    local mainSource2857 = safeRead("main.lua") or ""
    local manifestSource2857 = safeRead("manifest.json") or ""
    add("translation_spanish_target",
      mainSource2857:find('["traduccion_es"] = {', 1, true) ~= nil
      and mainSource2857:find('reviewed = "0.1.0"', 1, true) ~= nil
      and mainSource2857:find('behavior = "localization_plus_cartridge_content"', 1, true) ~= nil
      and mainSource2857:find('editions = { "red", "blue" }', 1, true) ~= nil
      and manifestSource2857:find('"traduccion_es"', 1, true) ~= nil)
    add("translation_spanish_no_gameplay_literals",
      mainSource2857:find('shop == "COMPRAR"', 1, true) == nil
      and mainSource2857:find('shop == "VENDER"', 1, true) == nil
      and mainSource2857:find('shop == "HUIR"', 1, true) == nil
      and mainSource2857:find('shop == "LUCHAR"', 1, true) == nil)

    -- 2.8.56: long-string / variable-width localization hardening and
    -- World Building + Randomizer source-catalog expansion.
    local uiSystemSource2856 = safeRead("nuzlocke_ui_system.lua") or ""
    local classicUiSource2856 = safeRead("classic_ui.lua") or ""
    local mainSource2856 = safeRead("main.lua") or ""
    local worldSource2856 = safeRead("world_building.lua") or ""
    add("localization_glyph_safe_typography_fit",
      uiSystemSource2856:find('type(Font.split) == "function"', 1, true) ~= nil
      and uiSystemSource2856:find('type(Font.spansFitting) == "function"', 1, true) ~= nil
      and uiSystemSource2856:find("local function removeLastGlyph(value)", 1, true) ~= nil
      and uiSystemSource2856:find("valueBudget = math.max(8", 1, true) ~= nil)
    add("localization_dev_wrapper_glyph_safe",
      classicUiSource2856:find("local function glyphSpans(value)", 1, true) ~= nil
      and classicUiSource2856:find("local function glyphCount(value)", 1, true) ~= nil
      and classicUiSource2856:find("local function splitGlyphs(value, count)", 1, true) ~= nil
      and classicUiSource2856:find("token:sub(1, width)", 1, true) == nil)
    add("localization_gen2_status_bounded",
      classicUiSource2856:find('Strings("CATCH %d LOST %d", caught, lostEncounters)', 1, true) ~= nil
      and classicUiSource2856:find("16, self.ruleMarqueeTime), 2, 3)", 1, true) ~= nil
      and classicUiSource2856:find('Strings("NEXT CAP LV%d", cap)', 1, true) ~= nil)
    add("translation_world_catalog_discovery",
      mainSource2856:find("local worldCatalog = mod.exports.__beta26.worldRuleCatalog", 1, true) ~= nil
      and mainSource2856:find('"world_building_" .. field', 1, true) ~= nil
      and mainSource2856:find('{ source="%s\\nAllowed: %s", kind="world_building_dynamic" }', 1, true) ~= nil
      and worldSource2856:find("labels[#labels + 1] = Strings(label)", 1, true) ~= nil)
    add("translation_randomizer_ui_sources",
      mainSource2856:find('{ source="RNG Preset %s", kind="randomizer_ui" }', 1, true) ~= nil
      and mainSource2856:find('{ source="CUSTOM", kind="randomizer_value" }', 1, true) ~= nil
      and classicUiSource2856:find('Strings("RNG Preset %s", Strings(', 1, true) ~= nil
      and classicUiSource2856:find('Strings("Starter %s", Strings(', 1, true) ~= nil)

    -- 2.8.55: generalized localization contract. High-value Nuzlocke UI
    -- strings must be discoverable through the existing Translation API 2
    -- source catalog, while Dev localization diagnostics remain read-only and
    -- visible in System Health / DEV REPORT.
    local mainSource2855 = safeRead("main.lua") or ""
    local devReportSource2855 = safeRead("dev_report.lua") or ""
    local classicUiSource2855 = safeRead("classic_ui.lua") or ""
    add("translation_high_value_ui_sources",
      mainSource2855:find("local TRANSLATION_UI_SOURCES = {", 1, true) ~= nil
      and mainSource2855:find('{ source="RUN STATUS", kind="ui_status" }', 1, true) ~= nil
      and mainSource2855:find('{ source="ENCOUNTER LOG", kind="tracker" }', 1, true) ~= nil
      and mainSource2855:find('kind="world_summary"', 1, true) ~= nil
      and mainSource2855:find("for _, row in ipairs(TRANSLATION_UI_SOURCES) do", 1, true) ~= nil)
    add("translation_dev_localization_diagnostics",
      devReportSource2855:find("Dev.localizationDiagnostics = function", 1, true) ~= nil
      and devReportSource2855:find("translation.detect", 1, true) ~= nil
      and devReportSource2855:find("translation.sources", 1, true) ~= nil
      and devReportSource2855:find("translation.catalog", 1, true) ~= nil
      and devReportSource2855:find("fallback_count=fallback", 1, true) ~= nil
      and devReportSource2855:find("LOCALIZATION=healthRow", 1, true) ~= nil
      and devReportSource2855:find("localization = health.localization", 1, true) ~= nil)
    add("translation_dev_report_surface",
      classicUiSource2855:find('"LOCALIZATION"', 1, true) ~= nil
      and classicUiSource2855:find('elseif name == "LOCALIZATION" then', 1, true) ~= nil
      and classicUiSource2855:find('putPair("FALLBACK"', 1, true) ~= nil)
    add("translation_api_stays_v2",
      mainSource2855:find("mod.exports.nuzlocke_translation = {\n      api = 2,", 1, true) ~= nil)

    -- 2.8.54: translation compatibility distinguishes installation from
    -- active localization state, and encounter ownership remains keyed by
    -- canonical area identity rather than localized display names.
    local mainSource2854 = safeRead("main.lua") or ""
    local manifestSource2854 = safeRead("manifest.json") or ""
    add("translation_german_universal_target",
      mainSource2854:find('["translation-german-universal"] = {', 1, true) ~= nil
      and mainSource2854:find('reviewed = "0.2.0"', 1, true) ~= nil
      and mainSource2854:find('toggleAware = true', 1, true) ~= nil
      and manifestSource2854:find('"translation-german-universal"', 1, true) ~= nil)
    add("translation_activity_lifecycle",
      mainSource2854:find("mod.exports.nuzlocke_translation = {", 1, true) ~= nil
      and mainSource2854:find("mod.exports.nuzlocke_translation = {\n      api = 2,", 1, true) ~= nil
      and mainSource2854:find("local bootLanguage = type(exports.bootLanguage)", 1, true) ~= nil
      and mainSource2854:find("local pendingLanguage = nil", 1, true) ~= nil
      and mainSource2854:find("local restartRequired = false", 1, true) ~= nil
      and mainSource2854:find('activity = "restart_required"', 1, true) ~= nil
      and mainSource2854:find("translationActive = translationActive", 1, true) ~= nil)
    add("translation_area_identity_separation",
      mainSource2854:find("id = routeKey(id)", 1, true) ~= nil
      and mainSource2854:find("ROUTE_NAMES[id] = formatAreaDisplayName(name, id)", 1, true) ~= nil
      and mainSource2854:find("local function routeName(id)", 1, true) ~= nil
      and mainSource2854:find("return Strings(formatAreaDisplayName(ROUTE_NAMES[id], id))", 1, true) ~= nil
      and mainSource2854:find('local log = mod.save:get("tracker_log")', 1, true) ~= nil)

    -- 2.8.53: provider ownership selection must ignore inactive
    -- advertisers, compatibility snapshots must canonicalize aliases before
    -- counting, transaction journals must use TX.api as their single version
    -- source, and Run History must preserve an explicit critical=false.
    local interopSource2853 = safeRead("public_interop.lua") or ""
    local migrationSource2853 = safeRead("save_migration.lua") or ""
    local runHistorySource2853 = safeRead("run_history.lua") or ""
    add("interop_inactive_provider_not_preferred",
      interopSource2853:find("local eligibleExplicit, eligibleAutomatic = {}, {}", 1, true) ~= nil
      and interopSource2853:find('providerStaticState(provider) == "available"', 1, true) ~= nil
      and interopSource2853:find("preferred=eligibleExplicit[1] or eligibleAutomatic[1]", 1, true) ~= nil)
    add("interop_snapshot_canonical_capability_dedupe",
      interopSource2853:find("local resolved = Interop.resolveCapability(capability)", 1, true) ~= nil
      and interopSource2853:find("capabilitySet[tostring(resolved.capability or capability)] = true", 1, true) ~= nil)
    add("gameplay_tx_version_uses_api_constant",
      migrationSource2853:find("version = TX.api, id = id, kind = kind, state = \"intent\"", 1, true) ~= nil
      and migrationSource2853:find('if tonumber(txn.version) ~= TX.api then return false, "newer_transaction" end', 1, true) ~= nil
      and migrationSource2853:find('version = 1, id = id, kind = kind, state = "intent"', 1, true) == nil
      and migrationSource2853:find('if tonumber(txn.version) ~= 1 then return false, "newer_transaction" end', 1, true) == nil)
    add("run_history_critical_false_preserved",
      runHistorySource2853:find("local critical = fields.critical", 1, true) ~= nil
      and runHistorySource2853:find("if critical == nil and mon then critical = mon.deathCritical end", 1, true) ~= nil
      and runHistorySource2853:find("critical = critical,", 1, true) ~= nil
      and runHistorySource2853:find("critical = fields.critical ~= nil and fields.critical", 1, true) == nil)

    -- 2.8.52: SHINY Dev diagnostics must report the same defaults as
    -- the Rule Catalog/runtime. Fresh/unset saves default Colors + Intro ON.
    local devReportSource2852 = safeRead("dev_report.lua") or ""
    local ruleCatalogSource2852 = safeRead("rule_catalog.lua") or ""
    add("dev_shiny_visual_defaults_match_catalog",
      devReportSource2852:find('mod.save:get("shiny_colors", true)', 1, true) ~= nil
      and devReportSource2852:find('mod.save:get("shiny_intro", true)', 1, true) ~= nil
      and devReportSource2852:find('mod.save:get("shiny_colors", false)', 1, true) == nil
      and devReportSource2852:find('mod.save:get("shiny_intro", false)', 1, true) == nil
      and ruleCatalogSource2852:find('{ key = "shiny_colors", default = true', 1, true) ~= nil
      and ruleCatalogSource2852:find('{ key = "shiny_intro", default = true', 1, true) ~= nil)

    -- 2.8.51: presence/value transaction snapshots must preserve literal
    -- false. Never use Lua's `and/or` conditional idiom where presence and
    -- stored value are separate facts.
    local migrationSource2851 = safeRead("save_migration.lua") or ""
    local mainSource2851 = safeRead("main.lua") or ""
    add("false_value_shadow_tx_preservation",
      migrationSource2851:find("copyPresentValue(before ~= sentinel, before)", 1, true) ~= nil
      and migrationSource2851:find("copyPresentValue(payload.after_present ~= false, payload.after_value)", 1, true) ~= nil
      and migrationSource2851:find("before ~= sentinel and deps.copy(before) or nil", 1, true) == nil
      and migrationSource2851:find("payload.after_present == false and nil or deps.copy(payload.after_value)", 1, true) == nil)
    add("false_value_schema_tx_preservation",
      mainSource2851:find("local function schemaTxnValue(present, value)", 1, true) ~= nil
      and mainSource2851:find("row.after_present and row.after_value or nil", 1, true) == nil
      and mainSource2851:find("row.before_present and row.before_value or nil", 1, true) == nil
      and mainSource2851:find("old.before_present and old.before_value or nil", 1, true) == nil)
    local function schemaValueSelfTest(present, value)
      if present ~= true then return nil end
      return value
    end
    add("false_value_schema_selector_selftest",
      schemaValueSelfTest(true, false) == false
      and schemaValueSelfTest(true, true) == true
      and schemaValueSelfTest(false, false) == nil
      and schemaValueSelfTest(false, true) == nil)

    -- 2.8.50 Brazilian translation compatibility contract.
      -- Current/legacy translation identities remain distinct; presentation
      -- diagnostics are capability-shaped rather than keyed to one mod ID; and
      -- Forgiveness shop filtering must never identify BUY/SELL by uppercasing
      -- English display text.
      local manifestSource2850 = safeRead("manifest.json") or ""
      add("translation_brazil_targets",
        mainSource:find('["gen1_pt-br"] = {', 1, true) ~= nil
        and mainSource:find('["versaovermelha"] = {', 1, true) ~= nil
        and mainSource:find('reviewed = "0.2.5"', 1, true) ~= nil
        and manifestSource2850:find('"versaovermelha"', 1, true) ~= nil)
      add("translation_presentation_capability_detection",
        mainSource:find("local trainerCard = exports.trainer_card", 1, true) ~= nil
        and mainSource:find("local priceLine = exports.precos_linha", 1, true) ~= nil
        and mainSource:find("local moveLanguage = exports.idioma_golpes", 1, true) ~= nil
        and mainSource:find("local enemyLabel = exports.mostrar_inimigo", 1, true) ~= nil
        and mainSource:find('nativeTrainerCardOwnedByTranslation = id == "gen1_pt-br"',
          1, true) == nil)
      local forgivenessOwnerSource = ownerSource("forgiveness") or ""
      add("translation_semantic_shop_filter",
        forgivenessOwnerSource:find("local function semanticShopKind(title, opts)", 1, true) ~= nil
        and forgivenessOwnerSource:find('shown == tostring(Strings("BUY"))', 1, true) ~= nil
        and forgivenessOwnerSource:find('shown == tostring(Strings("SELL"))', 1, true) ~= nil
        and forgivenessOwnerSource:find('local shop = tostring(title or ""):upper()', 1, true) == nil)
      add("translation_no_portuguese_shop_literals",
        mainSource:find('shop == "COMPRAR"', 1, true) == nil
        and mainSource:find('shop == "VENDER"', 1, true) == nil
        and mainSource:find('Strings("COMPRAR")', 1, true) == nil
        and mainSource:find('Strings("VENDER")', 1, true) == nil)

      -- Consequential enforcement/state feedback must stay visible at World
      -- Building T0, while ordinary flavor remains opt-in. These source-level
      -- checks protect the exact three call sites that have regressed before.
      local giftCritical =
        mainSource:find('worldMechanic(game, "gift_post_denied:', 1, true)
          ~= nil
        and mainSource:find(
          'deleting data.",\n                  true)', 1, true) ~= nil
      local tradeCritical =
        mainSource:find('worldMechanic(game, "trade_post_denied:', 1, true)
          ~= nil
        and mainSource:find(
          'rollback was attempted.",\n                  true)', 1, true) ~= nil
      local worldOwnerSource = ownerSource("world") or ""
      local failedCritical =
        worldOwnerSource:find(
          'worldMechanic(game, "failed:" .. tostring(area), t1, t2, t3, true)',
          1, true) ~= nil
      local criticalOk = giftCritical and tradeCritical and failedCritical
      local optionalStillOptional =
        worldOwnerSource:find(
          'local function worldMechanic(game, key, tier1, tier2, tier3, critical)',
          1, true) ~= nil
        and worldOwnerSource:find(
          'if tier <= 0 and critical ~= true then return false end',
          1, true) ~= nil
      add("world_critical_callsite_contract", criticalOk and optionalStillOptional,
        "gift/trade/failed critical=" .. tostring(criticalOk)
          .. " optional_t0_suppressed=" .. tostring(optionalStillOptional))
    else
      add("dead_fallback_lint", false,
        "source introspection unavailable: " .. tostring(mainErr), false)
      add("world_critical_callsite_contract", false,
        "source introspection unavailable: " .. tostring(mainErr), false)
    end

    local randomizerSource, randomizerErr =
      safeRead("randomizer_runtime.lua")
    if randomizerSource then
      local threaded =
        randomizerSource:find(
          "game, node, original, pool, balance, sharedProfile", 1, true) ~= nil
        and randomizerSource:find(
          "game, leaf, pool, pokemon, groupUsage, repetition, sharedProfile",
          1, true) ~= nil
        and randomizerSource:find(
          "encounterProfileForPass(game, balance, perfStats)", 1, true) ~= nil
        and randomizerSource:find(
          "groupUsage, repetition,\n                  sharedProfile)", 1, true)
          ~= nil
        and randomizerSource:find(
          "game, node, original, pool, balance, sharedProfile)", 1, true)
          ~= nil
      local chaosCheap =
        randomizerSource:find(
          "if balance <= 0 then return nil end", 1, true) ~= nil
      add("randomizer_profile_pass_invariant",
        threaded and chaosCheap,
        "shared_profile_threaded=" .. tostring(threaded)
          .. " chaos_zero_build=" .. tostring(chaosCheap))
    else
      add("randomizer_profile_pass_invariant", false,
        "source introspection unavailable: " .. tostring(randomizerErr), false)
    end

    -- 2.8.38: targeted localization coverage for the first migrated batch.
    -- This is deliberately not a blanket string-literal ban: hook ids, species
    -- ids, internal transaction reasons, and source constants are not
    -- player-facing text. Protect only authored surfaces that have explicitly
    -- entered the localization contract.
    do
      local battleSource, battleErr = safeRead("battle_clauses.lua")
      local forgivenessSource, forgivenessErr = safeRead("forgiveness.lua")
      local classicSource, classicErr = safeRead("classic_ui.lua")
      if battleSource and forgivenessSource and classicSource then
        local battleLocalized =
          battleSource:find('text = Strings("Sleep Clause blocked the move.")', 1, true) ~= nil
          and battleSource:find('message = Strings("Paralysis ban blocked the effect.")', 1, true) ~= nil
          and battleSource:find('text = Strings("Trap Clause blocked the trapping effect.")', 1, true) ~= nil
          and battleSource:find('text = Strings("OHKO Clause blocked the move.")', 1, true) ~= nil
        local forgivenessLocalized =
          forgivenessSource:find('label = Strings("REROLL ENCOUNTER")', 1, true) ~= nil
          and forgivenessSource:find('label = Strings("REVIVE POKEMON")', 1, true) ~= nil
        local classicLocalized =
          classicSource:find('Strings("CATCH %d  LOST %d"', 1, true) ~= nil
          and classicSource:find('Strings("DEATH %d  TOKEN %d"', 1, true) ~= nil
          and classicSource:find('Strings("AREA %s", tostring(areaLabel))', 1, true) ~= nil
          and classicSource:find('Strings("LAST %s", tostring(lastEvent))', 1, true) ~= nil
          and classicSource:find('Strings("Unknown recovery error.")', 1, true) ~= nil
        add("localization_migrated_surfaces",
          battleLocalized and forgivenessLocalized and classicLocalized,
          "battle=" .. tostring(battleLocalized)
            .. " forgiveness=" .. tostring(forgivenessLocalized)
            .. " classic=" .. tostring(classicLocalized))
      else
        add("localization_migrated_surfaces", false,
          "source unavailable: battle=" .. tostring(battleErr)
            .. " forgiveness=" .. tostring(forgivenessErr)
            .. " classic=" .. tostring(classicErr), false)
      end
    end

    -- 2.7.1: installer lint follows the authoritative shipped Lua inventory.
    -- A hand-maintained list silently lost coverage whenever installers moved
    -- into a new split module. Unreadable package source remains diagnostic
    -- only, matching the package_read contract below.
    local installerSources = {}
    local installerReadable = 0
    for _, installerPath in ipairs(deps.packagePaths or {}) do
      if tostring(installerPath):match("%.lua$") then
        local installerSource = safeRead(installerPath)
        if installerSource then
          installerReadable = installerReadable + 1
          installerSources[#installerSources + 1] =
            "\n-- release-safety source: " .. tostring(installerPath) .. "\n"
              .. installerSource
        end
      end
    end
    if installerReadable > 0 then
      run("bare_installer_pcall",
        mod.exports.__beta26.bareInstallerPcallAudit,
        table.concat(installerSources, "\n"))
    else
      add("bare_installer_pcall", false,
        "source introspection unavailable for shipped Lua modules", false)
    end
    run("save_pause_helper_scope", mod.exports.__beta26.savePauseHelperScopeAudit)
    run("lua_unpack_compat", mod.exports.__beta26.luaUnpackCompatibilityAudit)
    run("forward_local_references", mod.exports.__beta26.forwardLocalReferenceAudit)
    run("external_save_reconciliation", mod.exports.__beta26.externalSaveReconciliationAudit)
    run("catalog_snapshot", mod.exports.__beta26.catalogSnapshotAudit)
    run("rby_ball_policy_error_fail_closed",
      mod.exports.__beta26.rbyBallPolicyErrorSelfTest)
    run("forgiveness_failed_projection_state",
      mod.exports.__beta26.forgivenessFailedProjectionStateSelfTest)
    run("randomizer_whole_regression", mod.exports.__beta26.randomizerWholeRegressionAudit, deps.game or mod.game)
    run("randomizer_seed_reproducibility_matrix", mod.exports.__beta26.randomizerSeedReproducibilityMatrix)
    run("randomizer_release_documentation", mod.exports.__beta26.randomizerReleaseDocumentationAudit)
    for _, path in ipairs({"README.md", "CHANGELOG.md", "RELEASE_NOTES.md", "docs/DOCUMENTATION_CHANGELOG.md", "docs/USER_GUIDE.md"}) do
      local content, err = safeRead(path)
      if type(content) == "string" then
        add("doc_build_marker:" .. path, content:find(mod.exports.__beta26.build, 1, true) ~= nil,
          "build=" .. tostring(mod.exports.__beta26.build))
      else
        add("doc_build_marker:" .. path, false, "source unavailable: " .. tostring(err), false)
      end
    end
    run("world_building_delivery",
      mod.exports.__beta26.worldBuildingDeliveryAudit)
    run("failed_encounter_feedback_tiers",
      mod.exports.__beta26.failedEncounterFeedbackTierAudit)
    run("encounter_feedback_contract",
      mod.exports.__beta26.encounterFeedbackContractAudit)
    run("t3_run_context_isolation",
      mod.exports.__beta26.t3RunContextIsolationAudit)
    run("shared_ui_ownership",
      mod.exports.__beta26.sharedUiOwnershipAudit)
    run("battle_stack_ownership",
      mod.exports.__beta26.battleStackOwnershipAudit)
    run("healing_service_ownership",
      mod.exports.__beta26.healingServiceOwnershipAudit)
    run("acquisition_provenance_coverage",
      mod.exports.__beta26.acquisitionProvenanceCoverageAudit)
    run("compatibility_registry_reconciliation",
      mod.exports.__beta26.compatibilityRegistryReconciliationAudit)
    run("final_randomizer_static",
      mod.exports.__beta26.finalRandomizerStaticAudit)
    run("diagnostics_lifecycle_contract",
      mod.exports.__beta26.diagnosticsLifecycleContractAudit)
    run("presentation_renderer_isolation",
      mod.exports.__beta26.presentationRendererIsolationAudit)
    run("shiny_provider_isolation",
      mod.exports.__beta26.shinyProviderIsolationAudit)
    if worldSource then
      run("maximum_bst_message_detail",
        mod.exports.__beta26.maximumBstMessageDetailAudit, worldSource)
    else
      add("maximum_bst_message_detail", false,
        "source introspection unavailable: " .. tostring(worldErr), false)
    end
    run("rule_availability_contract", mod.exports.__beta26.ruleAvailabilityAudit)
    run("rule_availability_source", mod.exports.__beta26.ruleAvailabilitySourceAudit)
    run("cross_table_invariants", mod.exports.__beta26.crossTableInvariantAudit)

    local rewardsSource, rewardsErr = safeRead("trainer_rewards.lua")
    if rewardsSource then
      run("active_guard_contract",
        mod.exports.__beta26.TrainerRewards and mod.exports.__beta26.TrainerRewards.activeGuardAudit,
        rewardsSource)
    else
      add("active_guard_contract", false, "source introspection unavailable: " .. tostring(rewardsErr), false)
    end

    local provenance = mod.exports.__beta26.buildProvenance()
    local expectedParentVersion = deps.expectedParentVersion
    local expectedParentSha256 = deps.expectedParentSha256
    local expectedPackageCount = tonumber(deps.expectedPackageCount) or 0
    -- 2.6.97: report stale lineage constants directly. Previous releases could
    -- reach a generic build_provenance failure only after setup/NUZ RULES tried
    -- to open, obscuring that executable and independent audit parent identity
    -- had drifted apart during version bumps.
    add("lineage_parent_consistency",
      tostring(mod.exports.__beta26.parentVersion or "") == tostring(expectedParentVersion or "")
        and tostring(mod.exports.__beta26.parentSha256 or "") == tostring(expectedParentSha256 or ""),
      "exec=" .. tostring(mod.exports.__beta26.parentVersion)
        .. "/" .. tostring(mod.exports.__beta26.parentSha256):sub(1, 12)
        .. " expected=" .. tostring(expectedParentVersion)
        .. "/" .. tostring(expectedParentSha256):sub(1, 12))
    add("build_provenance", type(provenance) == "table"
      and provenance.version == mod.exports.__beta26.build
      and mod.exports.__beta26.manifestVersion == mod.exports.__beta26.build
      and provenance.parent_version == mod.exports.__beta26.parentVersion
      and (expectedParentVersion == nil
        or provenance.parent_version == expectedParentVersion)
      and type(provenance.parent_sha256) == "string"
      and #provenance.parent_sha256 == 64
      and (expectedParentSha256 == nil
        or provenance.parent_sha256 == expectedParentSha256)
      and tonumber(provenance.player_package_files) == expectedPackageCount,
      type(provenance) == "table"
        and ("parent=" .. tostring(provenance.parent_version)
          .. " sha=" .. tostring(provenance.parent_sha256):sub(1, 12)
          .. " files=" .. tostring(provenance.player_package_files))
        or "build provenance unavailable")

    local capabilities = deps.compatCapabilities or {}
    local advertised, versioned = #capabilities, 0
    for _, capability in ipairs(capabilities) do
      if mod.exports.__beta26.compatCapabilityVersions[capability] ~= nil then
        versioned = versioned + 1
      end
    end
    add("compat_capability_versions", versioned == advertised,
      string.format("versioned=%d advertised=%d", versioned, advertised))

    local engineCompat = mod.exports.__beta26.compat and mod.exports.__beta26.compat.Engine
    local activeProfile = engineCompat and engineCompat.active_profile
    local activeRow = engineCompat and engineCompat.profiles
      and engineCompat.profiles[activeProfile] or nil
    add("compat_active_engine_profile", type(activeProfile) == "string"
      and activeProfile ~= "" and type(activeRow) == "table",
      "active=" .. tostring(activeProfile))

    -- 2.8.39: compatibility cleanup/diagnostic contract.  New diagnostics
    -- must distinguish discovery from selection and keep every historical
    -- fallback explicitly inventoried instead of silently deleting it.
    local compatMods = mod.exports.__beta26.compat and mod.exports.__beta26.compat.Mods
    add("compat_fallback_inventory", type(compatMods) == "table"
      and type(compatMods.fallbackInventory) == "function")
    add("compat_capability_status", type(compatMods) == "table"
      and type(compatMods.capabilityStatus) == "function")
    local publicCompat = mod.exports.nuzlocke_compat
    add("compat_public_provider_status", type(publicCompat) == "table"
      and type(publicCompat.providerStatus) == "function")
    add("compat_public_capability_status", type(publicCompat) == "table"
      and type(publicCompat.capabilityStatus) == "function")
    add("compat_public_snapshot", type(publicCompat) == "table"
      and type(publicCompat.compatibilitySnapshot) == "function")
    if type(compatMods) == "table" and type(compatMods.fallbackInventory) == "function" then
      local okFallbacks, fallbacks = pcall(compatMods.fallbackInventory)
      add("compat_fallback_rows", okFallbacks and type(fallbacks) == "table"
        and #fallbacks >= 4, okFallbacks and ("rows=" .. tostring(#fallbacks)) or tostring(fallbacks))
    end

    -- 2.8.40: recurring-regression static bundle. These checks intentionally
    -- overlap selected runtime/self-tests: they catch forbidden ownership or
    -- architectural drift before the affected code path is exercised.
    do
      local main40, main40Err = safeRead("main.lua")
      local late40, late40Err = safeRead("late_runtime.lua")
      local rand40, rand40Err = safeRead("randomizer_runtime.lua")
      if main40 and late40 and rand40 then
        local battlePartyNative =
          main40:find("Gen2 BattleState owns its battle-party lifecycle", 1, true) ~= nil
          and late40:find("function G2.retirePartyMenuMethodWrappers", 1, true) ~= nil
          and late40:find("function G2.installPartyConsumableExecution", 1, true) ~= nil
          and not late40:find("PartyMenu.new = wrapper", 1, true)
          and not late40:find("PartyMenu.openSubmenu = openWrapper", 1, true)
          and not late40:find("Gen2BattleState.draw = function", 1, true)
          and not late40:find("Gen2BattleState.update = function", 1, true)
        add("regression_bundle:battle_party_native_ownership", battlePartyNative,
          "native battle-party/item target path preserved; retired method wrappers stay retired")

        local shinyOwnerSafe =
          main40:find("if liveProvider == nil then return nil end", 1, true) ~= nil
          and main40:find("exports.shiny_pokemon or exports.shiny_compat", 1, true) ~= nil
          and late40:find("if externalOwns() then return", 1, true) ~= nil
          and not late40:find("Assets.invalidate", 1, true)
          and not late40:find("Renderer.invalidate", 1, true)
          and not late40:find("PaletteFX.invalidate", 1, true)
        add("regression_bundle:shiny_single_owner", shinyOwnerSafe,
          "external ownership requires a live provider and Nuzlocke never invalidates engine renderer resources")

        local txJournalSafe =
          main40:find('RARE_CANDY_TXN_NAMESPACE = "rare_candy_to_cap_v2"', 1, true) ~= nil
          and main40:find("TX.nextSequence(RARE_CANDY_TXN_NAMESPACE", 1, true) ~= nil
          and main40:find('"native_effect_returned", true', 1, true) ~= nil
          and main40:find('return "unknown", "partial_or_external_mutation"', 1, true) ~= nil
          and main40:find("Revisiting the exact same Pokémon state must still create a fresh id.", 1, true) ~= nil
        add("regression_bundle:transaction_journal", txJournalSafe,
          "fresh attempt ids + durable native-effect checkpoint + fail-closed external mutation handling")

        local perfTripwire =
          rand40:find("perfStats.profileBuilds", 1, true) ~= nil
          and rand40:find("encounterProfileForPass(game, balance, perfStats)", 1, true) ~= nil
          and rand40:find("randomizerPerformanceAudit = function(game)", 1, true) ~= nil
          and rand40:find("learnset_projection_scoped", 1, true) ~= nil
        add("regression_bundle:performance_tripwires", perfTripwire,
          "encounter-profile call counter and scoped learnset projection audits remain installed")

        local eventShapeSafe =
          main40:find("payload and (payload.battle or payload)", 1, true) ~= nil
          and main40:find('mod.events:on("battle.started"', 1, true) ~= nil
        add("regression_bundle:battle_started_event_shape", eventShapeSafe,
          "battle.started consumers retain wrapped-or-direct payload compatibility")
      else
        add("regression_bundle:source_read", false,
          "source unavailable main=" .. tostring(main40Err)
            .. " late=" .. tostring(late40Err)
            .. " randomizer=" .. tostring(rand40Err), false)
      end
    end

    -- 2.8.41: Dev Mode semantic-diagnostics contract. These are observational
    -- surfaces only; Release Safety verifies they remain present and that the
    -- encounter/rule traces are bounded instead of becoming mutation tools.
    do
      local dev = mod.exports.__beta26.Dev or {}
      add("dev_system_health", type(dev.systemHealth) == "function")
      add("dev_provider_ownership", type(dev.providerOwnership) == "function")
      add("dev_encounter_provenance", type(dev.encounterProvenance) == "function"
        and type(mod.exports.__beta26.activeEncounterProvenance) == "function")
      add("dev_rule_decision_trace", type(dev.recordDecision) == "function"
        and type(dev.decisionTrace) == "function"
        and tonumber(dev.maxDecisions) ~= nil and tonumber(dev.maxDecisions) <= 64,
        "max=" .. tostring(dev.maxDecisions))
      local publicDev = mod.exports.nuzlocke_dev
      local publicCompat = mod.exports.nuzlocke_compat
      add("compat_api_current_semantic_status",
        tonumber(mod.exports.__beta26.compatibilityApi) == 37
        and type(publicCompat) == "table"
        and tonumber(publicCompat.version) == 37
        and type(publicCompat.providerStatus) == "function"
        and type(publicCompat.capabilityStatus) == "function"
        and type(publicCompat.compatibilitySnapshot) == "function")

      add("dev_public_semantic_surfaces", type(publicDev) == "table"
        and type(publicDev.system_health) == "function"
        and type(publicDev.provider_ownership) == "function"
        and type(publicDev.encounter_provenance) == "function"
        and type(publicDev.decision_trace) == "function"
        and type(publicDev.bug_report_snapshot) == "function"
        and type(publicDev.transaction_health) == "function"
        and type(publicDev.hook_wrapper_drift) == "function"
        and type(publicDev.randomizer_reproducibility) == "function"
        and type(publicDev.shiny_diagnostics) == "function"
        and type(publicDev.performance_counters) == "function"
        and type(publicDev.rule_configuration_consistency) == "function"
        and type(publicDev.save_run_identity_health) == "function"
        and type(publicDev.ownership_history) == "function")

      -- 2.8.42: the bug snapshot must stay observational. It may aggregate
      -- passive diagnostics, but it must never invoke the self-test or any
      -- mutation/repair path merely to render a report.
      local devSource = safeRead("dev_report.lua")
      local classicSource = safeRead("classic_ui.lua")
      local bugSnapshotSafe = type(dev.bugReportSnapshot) == "function"
        and type(devSource) == "string"
        and devSource:find("bugReportSnapshot = function", 1, true) ~= nil
        and devSource:find("NUZLOCKE BUG REPORT SNAPSHOT", 1, true) ~= nil
        and devSource:find("out.text = table.concat", 1, true) ~= nil
      add("dev_bug_report_snapshot", bugSnapshotSafe)
      add("dev_bug_report_page", type(classicSource) == "string"
        and classicSource:find('"BUG REPORT"', 1, true) ~= nil)

      -- 2.8.43: transaction and hook-drift diagnostics remain passive. The
      -- transaction page may inspect the durable journal/receipts but must not
      -- call recover/execute; hook drift may observe interposition but must not
      -- reassign or reclaim a wrapped engine/mod surface.
      local transactionDiagnosticSafe =
        type(dev.transactionHealth) == "function"
        and type(devSource) == "string"
        and devSource:find("transactionHealth = function", 1, true) ~= nil
        and devSource:find('recovery_policy="probe_or_refuse"', 1, true) ~= nil
      add("dev_transaction_health", transactionDiagnosticSafe)
      local hookDriftSafe =
        type(dev.hookWrapperDrift) == "function"
        and type(devSource) == "string"
        and devSource:find("hookWrapperDrift = function", 1, true) ~= nil
        and devSource:find('"interposed_or_replaced"', 1, true) ~= nil
      add("dev_hook_wrapper_drift", hookDriftSafe)
      add("dev_transaction_drift_pages", type(classicSource) == "string"
        and classicSource:find('"TRANSACTIONS"', 1, true) ~= nil
        and classicSource:find('"HOOK DRIFT"', 1, true) ~= nil)

      -- 2.8.44: Randomizer reproducibility and shiny diagnostics are passive.
      -- The former must use the established read-only reproducibility report;
      -- the latter must never call shiny RNG/presentation to inspect identity.
      add("dev_randomizer_reproducibility", type(dev.randomizerReproducibility) == "function"
        and type(devSource) == "string"
        and devSource:find("randomizerReproducibility = function", 1, true) ~= nil
        and devSource:find("randomizerReproducibilityReport", 1, true) ~= nil)
      add("dev_shiny_diagnostics", type(dev.shinyDiagnostics) == "function"
        and type(devSource) == "string"
        and devSource:find("shinyDiagnostics = function", 1, true) ~= nil
        and devSource:find('"READ ONLY / NO ROLL"', 1, true) == nil)
      add("dev_randomizer_shiny_pages", type(classicSource) == "string"
        and classicSource:find('"RANDOM REPRO"', 1, true) ~= nil
        and classicSource:find('"SHINY"', 1, true) ~= nil
        and classicSource:find("READ ONLY / ZERO RNG", 1, true) ~= nil
        and classicSource:find("READ ONLY / NO ROLL", 1, true) ~= nil)

      -- 2.8.45: bounded diagnostic rings must retain severity/count metadata,
      -- and performance counters must remain Dev-only/in-memory rather than
      -- becoming save-backed profiling or gameplay control state.
      local mainSource = safeRead("main.lua")
      add("dev_severity_coalescing", type(mainSource) == "string"
        and mainSource:find("Dev.severityFor = function", 1, true) ~= nil
        and mainSource:find("previous.count =", 1, true) ~= nil
        and mainSource:find("previous.lastSeq =", 1, true) ~= nil
        and mainSource:find("severity ~= \"INFO\"", 1, true) ~= nil)
      add("dev_performance_counters", type(dev.performanceCounters) == "function"
        and type(mainSource) == "string"
        and mainSource:find("Dev.perfCount = function", 1, true) ~= nil
        and mainSource:find("if not mod.exports.__beta26.Dev.enabled()", 1, true) ~= nil)
      add("dev_performance_page", type(classicSource) == "string"
        and classicSource:find('"PERFORMANCE"', 1, true) ~= nil
        and classicSource:find("IN MEMORY / DEV ONLY", 1, true) ~= nil)

      -- 2.8.46: final Dev Mode consistency/identity/ownership-history surfaces
      -- are observational. Rule diagnostics may validate but never coerce/write;
      -- save/run identity may compare but never repair; ownership history may
      -- observe transitions but never select/reclaim providers.
      add("dev_rule_configuration_consistency",
        type(dev.ruleConfigurationConsistency) == "function"
        and type(devSource) == "string"
        and devSource:find("ruleConfigurationConsistency = function", 1, true) ~= nil
        and devSource:find("validateStored", 1, true) ~= nil)
      add("dev_save_run_identity_health",
        type(dev.saveRunIdentityHealth) == "function"
        and type(devSource) == "string"
        and devSource:find("saveRunIdentityHealth = function", 1, true) ~= nil
        and devSource:find("identity_mismatch", 1, true) ~= nil)
      add("dev_ownership_history_bounded",
        type(dev.ownershipHistory) == "function"
        and tonumber(dev.maxOwnershipHistory) == 32
        and type(devSource) == "string"
        and devSource:find("observeOwnership = function", 1, true) ~= nil
        and devSource:find("while #dev.ownershipHistoryRows", 1, true) ~= nil)
      add("dev_remaining_pages", type(classicSource) == "string"
        and classicSource:find('"RULE CONFIG"', 1, true) ~= nil
        and classicSource:find('"SAVE/RUN"', 1, true) ~= nil
        and classicSource:find('"OWNER HISTORY"', 1, true) ~= nil
        and classicSource:find("READ ONLY / NO FIX", 1, true) ~= nil
        and classicSource:find("READ ONLY / NO REPAIR", 1, true) ~= nil
        and classicSource:find("SESSION ONLY / NO RECLAIM", 1, true) ~= nil)
    end

    -- 2.8.49: achievement evidence must remain durable across bounded
    -- chronology pruning. The Run History schema is independently versioned;
    -- this does not authorize a global Save Schema bump or synthetic backfill.
    local runHistorySource = safeRead("run_history.lua")
    local mainSourceAchievement = safeRead("main.lua")
    add("run_history_v2_achievement_evidence",
      type(mod.exports.__beta26.RunHistory) == "table"
      and tonumber(mod.exports.__beta26.RunHistory.api) == 2
      and tonumber(mod.exports.__beta26.RunHistory.storage_version) == 2
      and type(mod.exports.__beta26.RunHistory.statistics) == "function"
      and type(mod.exports.__beta26.RunHistory.achievementEvidence) == "function"
      and type(runHistorySource) == "string"
      and runHistorySource:find("durable achievement-evidence ledger", 1, true) ~= nil
      and runHistorySource:find("applyEventToStatistics", 1, true) ~= nil
      and runHistorySource:find('"encounter.failed"', 1, true) ~= nil)
    add("run_history_rule_integrity_capture",
      type(runHistorySource) == "string"
      and runHistorySource:find("recordRuleConfigurationChange", 1, true) ~= nil
      and type(mainSourceAchievement) == "string"
      and mainSourceAchievement:find("recordRuleConfigurationChange", 1, true) ~= nil)
    add("run_history_failed_encounter_capture",
      type(runHistorySource) == "string"
      and runHistorySource:find("recordEncounterFailed", 1, true) ~= nil
      and type(mainSourceAchievement) == "string"
      and mainSourceAchievement:find("recordEncounterFailed", 1, true) ~= nil)
    add("run_history_no_save_schema_bump",
      type(mainSourceAchievement) == "string"
      and mainSourceAchievement:find("CURRENT_SAVE_SCHEMA = 5", 1, true) ~= nil)

    -- 2.9.10: audit-confirmed defect repairs. TM_LOCATIONS must have an
    -- independent DEV diagnostic identity even though it shares pickup hooks
    -- with FIELD_ITEMS; RunHistory.list without a cursor must select the
    -- recent tail while cursor calls retain forward pagination.
    local devDiagnostics2910 = safeRead("dev_diagnostics.lua")
    local devReport2910 = safeRead("dev_report.lua")
    add("randomizer_tm_locations_dev_coverage",
      type(devDiagnostics2910) == "string"
      and devDiagnostics2910:find('id="random_tm_locations_rby"', 1, true) ~= nil
      and devDiagnostics2910:find('id="random_tm_locations_gold"', 1, true) ~= nil
      and type(devDiagnostics2910) == "string"
      and devDiagnostics2910:find("randomizer_tm_locations_hook_health", 1, true) ~= nil
      and type(devReport2910) == "string"
      and devReport2910:find("randomizerTmLocationsHealth", 1, true) ~= nil)
    add("run_history_recent_limit_semantics",
      type(runHistorySource) == "string"
      and runHistorySource:find("local hasAfter = opts.after_seq ~= nil", 1, true) ~= nil
      and runHistorySource:find("#matched - limit + 1", 1, true) ~= nil
      and runHistorySource:find("hasAfter and math.min(#matched, limit)", 1, true) ~= nil)

    -- 2.9.12: protect the two audit-confirmed repairs. TM Locations must be
    -- represented in the declarative cross-randomizer matrix, and R/B/Y Elite
    -- Four wins must use transactional progression so Run History cannot omit
    -- those milestones.
    local randomizerSource2912 = safeRead("randomizer_runtime.lua")
    local trainerRewardsSource2912 = safeRead("trainer_rewards.lua")
    add("randomizer_tm_locations_compatibility_matrix",
      type(randomizerSource2912) == "string"
      and randomizerSource2912:find('a="FIELD_ITEMS", b="TM_LOCATIONS"', 1, true) ~= nil
      and randomizerSource2912:find("tm_locations_precede_field_items_for_authored_tm_pickups", 1, true) ~= nil)
    add("rby_elite_four_run_history_progression",
      type(trainerRewardsSource2912) == "string"
      and trainerRewardsSource2912:find('"league_progression:rby:e4:"', 1, true) ~= nil
      and trainerRewardsSource2912:find('storage_key = "nuzlocke_e4_defeated"', 1, true) ~= nil
      and trainerRewardsSource2912:find('"badge:rby:e4:"', 1, true) ~= nil)

    -- 2.9.13: tracker-derived player-facing counts must stay inside the same
    -- current tracked-area universe used by display-route denominators. This
    -- also applies to the optional Pokegear snapshot so stale/renamed keys do
    -- not inflate totals through a second implementation.
    local pokegearSource2913 = safeRead("pokegear_integration.lua")
    add("tracker_current_area_count_filtering",
      type(mainSourceAchievement) == "string"
      and mainSourceAchievement:find('isTrackedArea(key) and type(entries) == "table"', 1, true) ~= nil
      and mainSourceAchievement:find('value ~= nil and isTrackedArea(key)', 1, true) ~= nil
      and type(pokegearSource2913) == "string"
      and pokegearSource2913:find('isTrackedArea(key) and type(entries) == "table"', 1, true) ~= nil
      and pokegearSource2913:find('value ~= nil and isTrackedArea(key)', 1, true) ~= nil)

    -- 2.9.16: Graveyard must remain a read-only historical projection over
    -- existing death/history state, with translation-safe UI and no second
    -- persistent graveyard ledger. Future deaths may enrich existing history
    -- records with level, but the viewer itself performs no save writes.
    local classicUiSource2916 = safeRead("classic_ui.lua")
    -- 2.9.62: ClassicUI and LateRuntime both consume the Gen-I seeded-area
    -- identity table. Its owner is encounter_tracker.lua; main.lua must bind
    -- the exported stable table before either module registration. This guards
    -- against the 2.9.61 Yellow fatal-load regression caused by an unresolved
    -- _ENV GEN1_SEED_IDS dependency.
    do
      local trackerSource2962 = safeRead("encounter_tracker.lua") or ""
      local mainSource2962 = safeRead("main.lua") or ""
      add("gen1_seed_ids_explicit_owner_export",
        trackerSource2962:find("GEN1_SEED_IDS = GEN1_SEED_IDS", 1, true) ~= nil)
      add("gen1_seed_ids_bound_before_classic_ui",
        mainSource2962:find("local GEN1_SEED_IDS = assert(EncounterTracker.GEN1_SEED_IDS", 1, true) ~= nil
        and (mainSource2962:find("local GEN1_SEED_IDS = assert(EncounterTracker.GEN1_SEED_IDS", 1, true) or math.huge)
          < (mainSource2962:find('loadRequiredModuleChunk("classic_ui.lua")', 1, true) or -1))
      add("gen1_seed_ids_no_env_dependency",
        mainSource2962:find("local GEN1_SEED_IDS = assert(EncounterTracker.GEN1_SEED_IDS", 1, true) ~= nil)
      add("legacy_candidates_explicit_owner_export",
        trackerSource2962:find("legacyCandidates = legacyCandidates", 1, true) ~= nil)
      local legacyBind = mainSource2962:find(
        "local legacyCandidates = assert(EncounterTracker.legacyCandidates", 1, true)
      local classicLoad = mainSource2962:find(
        'loadRequiredModuleChunk("classic_ui.lua")', 1, true)
      add("legacy_candidates_bound_before_classic_ui",
        legacyBind ~= nil and classicLoad ~= nil and legacyBind < classicLoad)
      add("legacy_candidates_no_env_dependency", legacyBind ~= nil)

      -- Complete ClassicUI injection-name coverage: every required deps.NAME
      -- assertion in classic_ui.lua must have a corresponding NAME = entry in
      -- the main.lua ClassicUI registration table. This catches missing wires
      -- before one assertion at a time reaches runtime.
      local classicSource2963 = safeRead("classic_ui.lua") or ""
      local classicBlockStart = mainSource2962:find(
        'loadRequiredModuleChunk("classic_ui.lua")()(mod, {', 1, true)
      local classicBlockEnd = classicBlockStart and
        mainSource2962:find("\n  })", classicBlockStart, true) or nil
      local classicBlock = (classicBlockStart and classicBlockEnd)
        and mainSource2962:sub(classicBlockStart, classicBlockEnd) or ""
      local missing = {}
      for depName in classicSource2963:gmatch(
          'assert%(deps%.([%w_]+), "classic_ui requires [%w_]+"%)') do
        local wired = classicBlock:find(depName .. " =", 1, true) ~= nil
          or classicBlock:find(depName .. ",", 1, true) ~= nil
        if not wired then missing[#missing + 1] = depName end
      end
      add("classic_ui_required_dependency_coverage", #missing == 0,
        #missing > 0 and table.concat(missing, ",") or nil)
    end

    add("graveyard_viewer_read_only_contract",
      type(classicUiSource2916) == "string"
      and classicUiSource2916:find('local function graveyardRows(game)', 1, true) ~= nil
      and classicUiSource2916:find('row.status == "DEAD"', 1, true) ~= nil
      and classicUiSource2916:find('Strings("GRAVEYARD")', 1, true) ~= nil
      and classicUiSource2916:find('Strings("IN MEMORY")', 1, true) ~= nil
      and classicUiSource2916:find('read_only = true', 1, true) ~= nil
      and classicUiSource2916:find('mod.save:set("nuzlocke_graveyard"', 1, true) == nil)
    add("graveyard_dev_health_contract",
      type(devDiagnostics2910) == "string"
      and devDiagnostics2910:find("graveyard_viewer_health", 1, true) ~= nil)

    -- 2.9.17: Almanac/Run Recap must remain a read-only consumer of the
    -- existing Run History v2/statistics ledger and recorded Randomizer run
    -- snapshot. It must label incomplete evidence rather than reconstructing it.
    add("almanac_run_recap_read_only_contract",
      type(classicUiSource2916) == "string"
      and classicUiSource2916:find('local function almanacSnapshot(game)', 1, true) ~= nil
      and classicUiSource2916:find('Strings("ALMANAC")', 1, true) ~= nil
      and classicUiSource2916:find('Strings("RUN RECAP")', 1, true) ~= nil
      and classicUiSource2916:find('coverage.detail_complete == false', 1, true) ~= nil
      and classicUiSource2916:find('randomizerRunConfigKey', 1, true) ~= nil
      and classicUiSource2916:find('mod.save:set("nuzlocke_almanac"', 1, true) == nil)
    add("almanac_dev_health_contract",
      type(devDiagnostics2910) == "string"
      and devDiagnostics2910:find("almanac_run_recap_health", 1, true) ~= nil)

    -- 2.9.18: END RUN is an explicit-confirmation lifecycle action. Natural
    -- completion stays progression-owned; abandonment commits history before
    -- disabling the master switch and defaults the destructive prompt to NO.
    local mainSource2918 = safeRead("main.lua")
    local runHistorySource2918 = safeRead("run_history.lua")
    add("end_run_lifecycle_contract",
      type(mainSource2918) == "string"
      and mainSource2918:find('label = "END RUN"', 1, true) ~= nil
      and classicUiSource2916:find('Strings("ABANDON RUN?")', 1, true) ~= nil
      and classicUiSource2916:find('confirm.index = 1', 1, true) ~= nil
      and classicUiSource2916:find('setConfigValue("nuzlocke_enabled", false', 1, true) ~= nil
      and type(runHistorySource2918) == "string"
      and runHistorySource2918:find('RunHistory.recordAbandoned', 1, true) ~= nil
      and runHistorySource2918:find('"run.abandoned"', 1, true) ~= nil)
    add("end_run_dev_health_contract",
      type(devDiagnostics2910) == "string"
      and devDiagnostics2910:find("end_run_lifecycle_health", 1, true) ~= nil)

    -- 2.9.21: Split-Evolution Dupes is an explicit fourth Dupes mode. The
    -- default/legacy FAMILY contract remains mode 2; SPLIT is mode 3 and must
    -- use directional ancestor/descendant traversal so sibling branches remain
    -- eligible without weakening ordinary exact/linear-family duplicates.
    local ruleCatalog2921 = safeRead("rule_catalog.lua")
    local mainSource2921 = safeRead("main.lua")
    add("split_evolution_dupes_contract",
      type(ruleCatalog2921) == "string"
      and ruleCatalog2921:find('key = "dupes_mode"', 1, true) ~= nil
      and ruleCatalog2921:find('max = 3', 1, true) ~= nil
      and ruleCatalog2921:find('SPLIT = ancestor/descendant lines are dupes', 1, true) ~= nil
      and type(mainSource2921) == "string"
      and mainSource2921:find('if mode == 3 then', 1, true) ~= nil
      and mainSource2921:find('local function evolvesInto(fromSpecies, targetSpecies)', 1, true) ~= nil
      and mainSource2921:find('evolvesInto(species, caughtSpecies)', 1, true) ~= nil
      and mainSource2921:find('evolvesInto(caughtSpecies, species)', 1, true) ~= nil)

    -- 2.9.22: guard the complete SPLIT enum path, not merely catalog/UI tokens.
    -- Mode 3 must survive runtime normalization and the main Config marquee
    -- must represent it truthfully. Movement Assist remains a 0..2 enum.
    add("split_evolution_dupes_end_to_end_contract",
      type(mainSource2921) == "string"
      and mainSource2921:find('mod.exports.__beta26.dupesMode = function()', 1, true) ~= nil
      and mainSource2921:find('math.min(3, math.floor(tonumber(value) or 0))',
          mainSource2921:find('mod.exports.__beta26.dupesMode = function()', 1, true), true) ~= nil
      and mainSource2921:find('local labels = { [0] = "OFF", [1] = "SPEC", [2] = "FAM", [3] = "SPLIT" }', 1, true) ~= nil
      and mainSource2921:find('local function normalizeMovementAssistMode(value)', 1, true) ~= nil
      and mainSource2921:find('return math.max(0, math.min(2, math.floor(tonumber(value) or 0)))',
          mainSource2921:find('local function normalizeMovementAssistMode(value)', 1, true), true) ~= nil)
    add("party_size_catch_decision_trace_contract",
      type(mainSource2921) == "string"
      and mainSource2921:find('pcall(Dev.recordDecision, "catch", "party_size_limit", "BLOCK",', 1, true) ~= nil
      and mainSource2921:find('"party_size", game)', 1, true) ~= nil)

    -- 2.9.25: Colorlocke/Alphabetlocke must exist end-to-end as catalogued
    -- prospective acquisition rules and share the same catch/special-acquisition gate.
    local rules2925 = safeRead("rule_catalog.lua") or ""
    local main2925 = safeRead("main.lua") or ""
    local speciesPolicy2925 = safeRead("species_policy.lua") or ""
    add("color_alphabet_locke_end_to_end_contract",
      rules2925:find('key = "colorlocke_mode"', 1, true) ~= nil
      and rules2925:find('key = "alphabetlocke_mode"', 1, true) ~= nil
      and speciesPolicy2925:find('challengeSpeciesAllows', 1, true) ~= nil
      and speciesPolicy2925:find('return false,"colorlocke"', 1, true) ~= nil
      and speciesPolicy2925:find('return false,"alphabetlocke"', 1, true) ~= nil
      and main2925:find('return denied(challengeReason)', 1, true) ~= nil
      and main2925:find('return challengeReason', 1, true) ~= nil)

    -- 2.9.30: wiring alone is insufficient for data-dependent rules. Prove
    -- that the complete Gen-I/II canonical color dataset is internally valid
    -- and, when a live registry is available, that all ten categories resolve
    -- on representative ordinary Gen-I species.
    run("colorlocke_canonical_data_semantics",
      mod.exports.__beta26.colorlockeDataAudit, deps.game or mod.game)

    -- 2.9.36: implementation is not sufficient if an edition-specific
    -- configuration surface silently filters the rule out. Verify the live
    -- catalog + Gen-II reachability tables for both parent/child rows.
    run("challenge_locke_gen2_reachability",
      mod.exports.__beta26.challengeLockeGen2ReachabilityAudit)

    -- 2.9.37: catch refusal policy and numeric enum/range metadata are now
    -- reconciled semantically rather than inferred from scattered branches.
    run("catch_denial_disposition_reconciliation",
      mod.exports.__beta26.catchDenialDispositionAudit)
    run("rule_enum_range_completeness",
      mod.exports.__beta26.ruleEnumRangeCompletenessAudit)

    -- 2.9.39: structured rule-status explanations must preserve exact-edition
    -- reachability and runtime evidence boundaries. This audit checks the
    -- diagnostic projection only; it does not certify gameplay behavior.
    run("rule_status_certification_projection",
      mod.exports.__beta26.ruleStatusCertificationAudit)

    -- 2.9.38: source-derived persistence reference map. The structural audit
    -- is promotion-facing, while source availability/completeness remains a
    -- non-fatal diagnostic because supported launchers may deny mod:read().
    local saveIndexAudit = run("save_reference_consumer_index",
      mod.exports.__beta26.saveReferenceConsumerIndexAudit)
    if type(saveIndexAudit) == "table" and saveIndexAudit.complete ~= true then
      add("save_reference_consumer_index_source", false,
        "status=" .. tostring(saveIndexAudit.status)
          .. " unreadable=" .. tostring(saveIndexAudit.unreadable_count or 0)
          .. " truncated=" .. tostring(saveIndexAudit.truncated == true), false)
    end

    -- 2.9.65: Nuzlocke-owned UI surfaces expose explicit repeat/edge
    -- semantics so input-repeat/accessibility mods can distinguish navigation
    -- and value stepping from activation and destructive confirmation.
    local uiSystem2965 = safeRead("nuzlocke_ui_system.lua") or ""
    add("ui_input_contract_version",
      uiSystem2965:find("inputContractVersion = 1", 1, true) ~= nil)
    add("ui_input_repeat_edge_modes",
      uiSystem2965:find('repeat_safe = "repeat_safe"', 1, true) ~= nil
      and uiSystem2965:find('edge_only = "edge_only"', 1, true) ~= nil
      and uiSystem2965:find("function UI.isRepeatSafe", 1, true) ~= nil
      and uiSystem2965:find("function UI.requiresEdge", 1, true) ~= nil)
    add("ui_destructive_confirmation_contract",
      uiSystem2965:find('UI.registerPolicy("NuzlockeAbandonConfirmScreen"', 1, true) ~= nil
      and uiSystem2965:find('profile = "destructive_confirmation"', 1, true) ~= nil
      and uiSystem2965:find("function UI.isDestructive", 1, true) ~= nil)
    add("ui_contract_is_presentation_only",
      uiSystem2965:find("They do not intercept engine input", 1, true) ~= nil
      and uiSystem2965:find("mod.exports.nuzlocke_ui_system = UI", 1, true) ~= nil)
    add("ui_contract_screen_policy_coverage",
      select(2, uiSystem2965:gsub('UI.registerPolicy%("Nuzlocke', "")) == 27
      and uiSystem2965:find('UI.registerPolicy("NuzlockeConfigScreen"', 1, true) ~= nil
      and uiSystem2965:find('UI.registerPolicy("NuzlockeAbandonConfirmScreen"', 1, true) ~= nil)

    -- 2.9.72: normalize Gen-II numeric item operands before Randomizer
    -- classification/persistence, prevent legal shop no-op replacements, keep
    -- trainer accepted-roster evidence visible, and recolor only private shiny
    -- ImageData copies so palette changes cannot bleed into shared engine art.
    local randomizer2972 = safeRead("randomizer_runtime.lua") or ""
    local late2972 = safeRead("late_runtime.lua") or ""
    local devReport2972 = safeRead("dev_report.lua") or ""
    local classic2972 = safeRead("classic_ui.lua") or ""
    add("gen2_item_reference_normalization_2_9_72",
      randomizer2972:find("normalizeItemReference", 1, true) ~= nil
      and randomizer2972:find("nativeItemReference", 1, true) ~= nil
      and randomizer2972:find("lastFieldItemNormalization", 1, true) ~= nil)
    add("random_shop_non_noop_2_9_72",
      randomizer2972:find("if #pool > 1 then", 1, true) ~= nil
      and randomizer2972:find("lastRandomShopTrace", 1, true) ~= nil)
    add("random_trainer_boundary_trace_2_9_72",
      randomizer2972:find("lastTrainerRandomizerPrimaryTrace", 1, true) ~= nil
      and randomizer2972:find("randomTrainerTrace", 1, true) ~= nil
      and devReport2972:find("random_trainer_trace", 1, true) ~= nil
      and classic2972:find("ACCEPT S", 1, true) ~= nil)
    add("shiny_private_image_copy_2_9_72",
      late2972:find("local sourceId = Assets.imageData(path)", 1, true) ~= nil
      and late2972:find("sourceId.clone", 1, true) ~= nil
      and late2972:find("copy.paste", 1, true) ~= nil
      and late2972:find("lastShinyPresentationTrace", 1, true) ~= nil)

    -- 2.9.71: R/B/Y visible Random Field Items use the public world.talk
    -- hook so the transformation composes at the engine-supported A-press seam.
    local main2971 = safeRead("main.lua") or ""
    local randomizer2971 = safeRead("randomizer_runtime.lua") or ""
    local dev2971 = safeRead("dev_diagnostics.lua") or ""
    add("rby_random_field_item_world_talk_contract",
      main2971:find('mod.hooks.wrap, mod.hooks, "world.talk"', 1, true) ~= nil
      and main2971:find("rbyFieldItemWorldTalkSession2971", 1, true) ~= nil
      and main2971:find('rbyFieldItemHookMode = "world.talk_unavailable"', 1, true) ~= nil
      and main2971:find('rbyFieldItemHookMode = "talkTo_fallback"', 1, true) == nil
      and randomizer2971:find('or "world.talk"', 1, true) ~= nil
      and dev2971:find('hook="world.talk"', 1, true) ~= nil
      and dev2971:find("fieldItemPipeline", 1, true) ~= nil)

    -- 2.9.70: invalid input profile names must report the profile whose
    -- behavior was actually resolved, not echo a misspelled request.
    local uiSystem2970 = safeRead("nuzlocke_ui_system.lua") or ""
    add("ui_input_profile_resolution_consistent",
      uiSystem2970:find("local resolvedProfile = profile and requestedProfile or", 1, true) ~= nil
      and uiSystem2970:find("profile = resolvedProfile", 1, true) ~= nil)

    -- 2.9.69: presentation ownership booleans must not collapse conditional
    -- gameplay-authority descriptors into unconditional ownership.
    local uiSystem2969 = safeRead("nuzlocke_ui_system.lua") or ""
    add("ui_conditional_gameplay_authority_semantics",
      uiSystem2969:find("function UI.gameplayAuthorityFor", 1, true) ~= nil
      and uiSystem2969:find(
          'gameplayAuthority = "nuzlocke_randomizer_when_enabled"', 1, true) ~= nil
      and uiSystem2969:find(
          'return authority == true or authority == "nuzlocke"', 1, true) ~= nil)

    -- 2.9.68: Gold/Gen-II Nuzlocke utility pages use the shared typography
    -- contract for centered titles. Keep centerX in the typography surface so
    -- ClassicUI never falls through to a nil field at draw time.
    local uiSystem2968 = safeRead("nuzlocke_ui_system.lua") or ""
    local classic2968 = safeRead("classic_ui.lua") or ""
    add("ui_typography_center_x_contract",
      uiSystem2968:find("function T.centerX", 1, true) ~= nil
      and classic2968:find("T.centerX(label, 8, 152)", 1, true) ~= nil)

    -- 2.9.67: Dev Report must not depend on an accidental _ENV/global for
    -- compatibility projection. compatPublicCopy is owned by main.lua and is
    -- injected explicitly into dev_diagnostics.lua.
    local devDiagnostics2967 = safeRead("dev_diagnostics.lua") or ""
    local main2967 = safeRead("main.lua") or ""
    add("dev_diagnostics_compat_copy_dependency",
      devDiagnostics2967:find(
          'local compatPublicCopy = assert(deps.compatPublicCopy', 1, true) ~= nil
      and main2967:find(
          'compatPublicCopy = compatPublicCopy,', 1, true) ~= nil
      and devDiagnostics2967:find(
          'capability_versions = compatPublicCopy(', 1, true) ~= nil)

    -- 2.9.66: presentation ownership and shared trainer-constructor chaining.
    local uiSystem2966 = safeRead("nuzlocke_ui_system.lua") or ""
    local compat2966 = ownerSource("compatibility") or ""
    local randomizer2966 = safeRead("randomizer_runtime.lua") or ""
    local manifest2966 = safeRead("manifest.json") or ""
    add("ui_presentation_contract_version",
      uiSystem2966:find("presentationContractVersion = 1", 1, true) ~= nil
      and uiSystem2966:find("apiVersion = 8", 1, true) ~= nil)
    add("ui_presentation_surface_ownership",
      uiSystem2966:find("UI.presentationSurfaces = {", 1, true) ~= nil
      and uiSystem2966:find('party = {', 1, true) ~= nil
      and uiSystem2966:find('battle_art = {', 1, true) ~= nil
      and uiSystem2966:find('trainer_party = {', 1, true) ~= nil
      and uiSystem2966:find("function UI.externalPresentationAllowed", 1, true) ~= nil)
    add("hgss_visual_overhaul_102_target",
      compat2966:find("HGSS_SPRITES = {", 1, true) ~= nil
      and compat2966:find('tested = "1.0.2"', 1, true) ~= nil
      and manifest2966:find('"HGSS_SPRITES"', 1, true) ~= nil)
    add("gen1_trainer_wrapper_chain_contract",
      randomizer2966:find("chainContractVersion=1", 1, true) ~= nil
      and randomizer2966:find("callsPreviousExactlyOncePerPath=true", 1, true) ~= nil
      and randomizer2966:find("presentationAgnostic=true", 1, true) ~= nil
      and randomizer2966:find(
          "gen1TrainerWrapperChainHealth = function()", 1, true) ~= nil)
    add("gen1_trainer_wrapper_not_outermost_required",
      randomizer2966:find("externalOuterWrapper", 1, true) ~= nil
      and randomizer2966:find("current ~= ownWrapper", 1, true) ~= nil
      and randomizer2966:find("This diagnostic never rewrites the chain.", 1, true) ~= nil)


    -- Keep the read-only structural Randomizer performance audit in the
    -- promotion gate. It does not benchmark host speed or materialize mappings.
    run("randomizer_performance_structural",
      mod.exports.__beta26.randomizerPerformanceAudit, deps.game or mod.game)

    run("gen1_seed_ids_dependency",
      mod.exports.__beta26.gen1SeedIdsDependencyAudit)

    -- Engine/runtime source introspection is diagnostic only. A supported
    -- launcher may legitimately deny mod:read() for package files; that must
    -- never make the gameplay mod unbootable.
    for _, path in ipairs(deps.packagePaths or {}) do
      local content, err = safeRead(path)
      add("package_read:" .. path, content ~= nil,
        content and ("bytes=" .. tostring(#content))
          or ("unavailable: " .. tostring(err)), false)
    end
    return report
  end

  -- 2.9.62: split-safety regression guard. GEN1_SEED_IDS is private tracker
  -- state consumed by ClassicUI/LateRuntime and must be explicitly exported
  -- and locally bound before either consumer is registered.
  mod.exports.__beta26.gen1SeedIdsDependencyAudit = function()
    local tracker = safeRead("encounter_tracker.lua") or ""
    local main = safeRead("main.lua") or ""
    local classic = safeRead("classic_ui.lua") or ""
    local late = safeRead("late_runtime.lua") or ""
    local failures = {}
    local function check(id, ok)
      if not ok then failures[#failures + 1] = id end
    end
    check("tracker_exports_gen1_seed_ids",
      tracker:find("GEN1_SEED_IDS = GEN1_SEED_IDS,", 1, true) ~= nil)
    check("main_binds_tracker_gen1_seed_ids",
      main:find("local GEN1_SEED_IDS = assert(EncounterTracker.GEN1_SEED_IDS", 1, true) ~= nil)
    check("classic_receives_gen1_seed_ids",
      main:find("GEN1_SEED_IDS = GEN1_SEED_IDS,", 1, true) ~= nil
      and classic:find("classic_ui requires GEN1_SEED_IDS", 1, true) ~= nil)
    check("late_requires_owned_gen1_seed_ids",
      late:find("late_runtime requires GEN1_SEED_IDS", 1, true) ~= nil)
    return { ok = #failures == 0, checked = 4, failures = failures }
  end

  mod.exports.__beta26.assertReleaseSafety = function()
    local report = mod.exports.__beta26.releaseSafetyAudit()
    if not report.ok then
      return false, report
    end
    return true, report
  end

  local ok, report = pcall(mod.exports.__beta26.releaseSafetyAudit)
  if ok then
    mod.exports.__beta26.releaseSafetyBootReport = report
  else
    mod.exports.__beta26.releaseSafetyBootReport = {
      ok = false, failures = { "release_safety_runner:" .. tostring(report) },
      warnings = {}, checks = {},
    }
  end
  return mod.exports.__beta26.releaseSafetyBootReport
end
