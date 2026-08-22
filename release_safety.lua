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
      check("manifest_engine_range", manifest:find('"game_version"%s*:%s*">=0%.1%.86 <2%.0%.0"') ~= nil)
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

    -- Documents have different jobs. Do not force every file into a changelog-
    -- shaped version heading; verify the exact role-specific current header.
    local expectedDocHeaders = {
      ["README.md"] = "# Nuzlocke " .. buildText,
      ["CHANGELOG.md"] = "# " .. buildText,
      ["RELEASE_NOTES.md"] = "# Nuzlocke " .. buildText .. " — Release Notes",
      ["docs/API.md"] = "# Nuzlocke API — " .. buildText,
      ["docs/COMPATIBILITY.md"] = "# Nuzlocke Compatibility — " .. buildText,
      ["docs/DOCUMENTATION_CHANGELOG.md"] = "# Documentation Changelog — " .. buildText,
      ["docs/FEATURE_CONFIDENCE.md"] = "# Feature Confidence — " .. buildText,
      ["docs/USER_GUIDE.md"] = "# Nuzlocke User Guide — " .. buildText,
    }
    for path, expectedHeader in pairs(expectedDocHeaders) do
      local content = safeRead(path)
      if content then
        local firstLine = content:match("^%s*([^\r\n]+)") or ""
        local headerMatches = firstLine == expectedHeader
        if path == "CHANGELOG.md" then
          -- Changelog headings may append a descriptive release title after
          -- the exact current build, e.g. "# 2.6.68 — Diagnostics repair".
          headerMatches = firstLine == expectedHeader
            or firstLine:find(expectedHeader .. " — ", 1, true) == 1
        end
        check("doc_current_header_" .. path, headerMatches, firstLine)
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
          local base = "# " .. buildText
          for line in content:gmatch("[^\r\n]+") do
            if line == base or line:find(base .. " — ", 1, true) == 1 then
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
        local report = { ok=true, checked=0, failures={} }

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
                local text = mod:read(path)
                report.checked = report.checked + 1
                if type(text) ~= "string" then
                    report.ok = false
                    report.failures[#report.failures + 1] = path .. ":unreadable"
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
        local report = { ok=true, checked=0, failures={} }

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
                local text = mod:read(path)
                report.checked = report.checked + 1
                if type(text) ~= "string" then
                    report.ok = false
                    report.failures[#report.failures + 1] = path .. ":unreadable"
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
    run("semantic_behavior_regressions", mod.exports.__beta26.semanticBehaviorRegressionAudit)
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
    end

    local mainSource, mainErr = safeRead("main.lua")
    if mainSource then
      run("dead_fallback_lint", mod.exports.__beta26.deadFallbackAudit, mainSource)
      local installerSources = { mainSource }
      for _, installerPath in ipairs({ "battle_clauses.lua", "late_runtime.lua" }) do
        local installerSource = safeRead(installerPath)
        if installerSource then installerSources[#installerSources + 1] = installerSource end
      end
      run("bare_installer_pcall",
        mod.exports.__beta26.bareInstallerPcallAudit,
        table.concat(installerSources, "\n"))
    else
      add("dead_fallback_lint", false, "source introspection unavailable: " .. tostring(mainErr), false)
    end
    run("save_pause_helper_scope", mod.exports.__beta26.savePauseHelperScopeAudit)
    run("lua_unpack_compat", mod.exports.__beta26.luaUnpackCompatibilityAudit)
    run("catalog_snapshot", mod.exports.__beta26.catalogSnapshotAudit)
    run("world_building_delivery",
      mod.exports.__beta26.worldBuildingDeliveryAudit)
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
