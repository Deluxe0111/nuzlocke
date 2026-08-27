return function(mod, deps)
  deps = deps or {}
  local function safeRead(path)
    local ok, content = pcall(mod.read, mod, path)
    if ok and type(content) == "string" and #content > 0 then
      return content, nil
    end
    return nil, tostring(content)
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
      healing_service = { late, { "function G2.installHealingServiceGate", "specialName ~= \"HealParty\"", "gen2.healing_service_gate" } },
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
    local late = safeRead("late_runtime.lua") or ""
    local catalog = safeRead("rule_catalog.lua") or ""
    local manifest = safeRead("manifest.json") or ""
    local report = { ok=true, checked=0, failures={} }
    local required = {
      { "optional_dependency", manifest, '"SHINY_POKEMON"' },
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
      { main, 'difficultyImpactChanges("vanilla"' },
      { main, 'proposedId = nextId' },
      { main, 'title = "DIFFICULTY WARNING"' },
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
      main:find("emitFailedEncounterFeedback(game, key)", 1, true) ~= nil)
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
        check("engine_profile_save", profile.save_format == 4)
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
    local continuityTerm = "hand" .. "off"
    local forbidden = {
      continuityTerm, "hand" .. "-off",
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
      check("main_source_header", firstLine == "-- Nuzlocke " .. buildText, firstLine)
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
    local function docHeaderMatches(path, firstLine)
      local escaped = buildText:gsub("%.", "%%.")
      if path == "README.md" then
        return firstLine == "# Nuzlocke " .. buildText
          or firstLine:match("^## " .. escaped .. "%f[%D]") ~= nil
      elseif path == "CHANGELOG.md" then
        return firstLine == "# " .. buildText
          or firstLine:find("# " .. buildText .. " — ", 1, true) == 1
          or firstLine == "## " .. buildText
          or firstLine:find("## " .. buildText .. " — ", 1, true) == 1
      elseif path == "RELEASE_NOTES.md" then
        return firstLine == "# Nuzlocke " .. buildText .. " — Release Notes"
          or firstLine == "## " .. buildText
          or firstLine:find("## " .. buildText .. " — ", 1, true) == 1
      elseif path == "docs/API.md" then
        return firstLine == "# Nuzlocke API — " .. buildText
      elseif path == "docs/COMPATIBILITY.md" then
        return firstLine == "# Nuzlocke Compatibility — " .. buildText
      elseif path == "docs/DOCUMENTATION_CHANGELOG.md" then
        return firstLine == "# Documentation Changelog — " .. buildText
          or firstLine == "## " .. buildText
          or firstLine:find("## " .. buildText .. " — ", 1, true) == 1
      elseif path == "docs/FEATURE_CONFIDENCE.md" then
        return firstLine == "# Feature Confidence — " .. buildText
      elseif path == "docs/USER_GUIDE.md" then
        return firstLine == "# Nuzlocke User Guide — " .. buildText
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
          docHeaderMatches(path, firstLine), firstLine)
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
      check("audited_current_engine", main:find('recompCompatAudited = "0.2.29"', 1, true) ~= nil)
      check("engine_developer_signal", main:find("Dev.engineDeveloper = mod.developer == true", 1, true) ~= nil)
      local markerCount = 0
      for _ in main:gmatch("isModOptions%s*=%s*true") do markerCount = markerCount + 1 end
      if late then for _ in late:gmatch("isModOptions%s*=%s*true") do markerCount = markerCount + 1 end end
      check("options_screen_markers", markerCount == 3)
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

  -- 2.8.48 / Gen1Recomp 0.2.29 compatibility gate. Protect the public
  -- R/B/Y catch nickname seam, palette-aware Gen II Nuzlocke utility surfaces,
  -- current audited profile, and the source-revalidated Crystal shiny-flash
  -- safety boundary without claiming exact-edition runtime certification.
  mod.exports.__beta26.gen1Recomp029FocusedAudit = function()
    local report = { ok = true, checked = 0, failures = {}, skipped = {} }
    local function check(id, condition)
      report.checked = report.checked + 1
      if condition then return end
      report.ok = false
      report.failures[#report.failures + 1] = id
    end
    local main = safeRead("main.lua")
    local late = safeRead("late_runtime.lua")
    local classic = safeRead("classic_ui.lua")
    local compat = safeRead("docs/COMPATIBILITY.md")
    if main then
      check("audited_0_2_29",
        main:find('recompCompatAudited = "0.2.29"', 1, true) ~= nil)
      check("profile_0_2_27",
        main:find('["0.2.27"] = {', 1, true) ~= nil)
      check("profile_0_2_28",
        main:find('["0.2.28"] = {', 1, true) ~= nil)
      check("profile_0_2_29",
        main:find('["0.2.29"] = {', 1, true) ~= nil)
      check("catch_nickname_public_hook",
        main:find('mod.hooks:wrap("catch.nickname"', 1, true) ~= nil)
      check("catch_nickname_old_engine_fallback",
        main:find('mod.hooks:wrap("battle.nickname"', 1, true) ~= nil)
      check("nickname_ui_enforcement_preserved",
        main:find('__nuzlockeNicknameScreenSession', 1, true) ~= nil)
      check("shiny_127_target",
        main:find('tested = "Stone fork 1.2.7"', 1, true) ~= nil)
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
      check("gen2_shiny_flash_029_marker",
        late:find('audited_engine = "0.2.29"', 1, true) ~= nil)
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
      check("compat_docs_0_2_29",
        compat:find('Gen1Recomp 0.2.29', 1, true) ~= nil)
      check("compat_docs_runtime_caveat",
        compat:find('runtime certification', 1, true) ~= nil)
    else
      report.skipped[#report.skipped + 1] = "docs/COMPATIBILITY.md"
    end
    return report
  end
  -- Historical internal name kept as a read-only alias for older tooling.
  mod.exports.__beta26.gen1Recomp027FocusedAudit =
    mod.exports.__beta26.gen1Recomp029FocusedAudit

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
    run("gen2_semantic_seams", mod.exports.__beta26.gen2SemanticSeamAudit)
    run("gen1recomp_0_2_24", mod.exports.__beta26.gen1Recomp024Audit)
    run("gen1recomp_0_2_29", mod.exports.__beta26.gen1Recomp029FocusedAudit)
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
      add("translation_semantic_shop_filter",
        mainSource:find("local function semanticShopKind(title, opts)", 1, true) ~= nil
        and mainSource:find('shown == tostring(Strings("BUY"))', 1, true) ~= nil
        and mainSource:find('shown == tostring(Strings("SELL"))', 1, true) ~= nil
        and mainSource:find('local shop = tostring(title or ""):upper()', 1, true) == nil)
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
      local failedCritical =
        mainSource:find(
          'worldMechanic(game, "failed:" .. tostring(key), t1, t2, t3, true)',
          1, true) ~= nil
      local criticalOk = giftCritical and tradeCritical and failedCritical
      local optionalStillOptional =
        mainSource:find(
          'local function worldMechanic(game, key, tier1, tier2, tier3, critical)',
          1, true) ~= nil
        and mainSource:find(
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
      add("compat_api_35_semantic_status",
        tonumber(mod.exports.__beta26.compatibilityApi) == 35
        and type(publicCompat) == "table"
        and tonumber(publicCompat.version) == 35
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

    -- Keep the read-only structural Randomizer performance audit in the
    -- promotion gate. It does not benchmark host speed or materialize mappings.
    run("randomizer_performance_structural",
      mod.exports.__beta26.randomizerPerformanceAudit, deps.game or mod.game)

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
