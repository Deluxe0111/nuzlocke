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
      check("audited_0_2_25", main:find('recompCompatAudited = "0.2.25"', 1, true) ~= nil)
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
