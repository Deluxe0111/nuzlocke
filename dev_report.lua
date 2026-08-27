-- Nuzlocke 2.5.89
-- DEV REPORT / NZR6 diagnostic presentation extraction.
-- Behavior-preserving child of the 2.5.88 inline implementation.
return function(mod, deps)
  deps = deps or {}
  local getCurrentGame = assert(deps.currentGame, "dev_report requires currentGame getter")
  local SAVE_SCHEMA_KEY = assert(deps.SAVE_SCHEMA_KEY, "dev_report requires SAVE_SCHEMA_KEY")
  local CURRENT_SAVE_SCHEMA = assert(deps.CURRENT_SAVE_SCHEMA, "dev_report requires CURRENT_SAVE_SCHEMA")
  local function liveGame() return getCurrentGame() end

  ---------------------------------------------------------------------
  -- 2.8.41 DEV SYSTEM HEALTH / OWNERSHIP / PROVENANCE
  -- Read-only semantic summaries for the Dev dashboard and public diagnostics.
  ---------------------------------------------------------------------
  -- 2.8.46: bounded compatibility ownership-transition history. This is
  -- session-only diagnostic evidence. It observes the semantic provider
  -- snapshot when Dev diagnostics already inspect it; it never selects,
  -- unregisters, reprioritizes, or reclaims a provider.
  mod.exports.__beta26.Dev.maxOwnershipHistory = 32
  mod.exports.__beta26.Dev.ownershipHistoryRows =
      mod.exports.__beta26.Dev.ownershipHistoryRows or {}
  mod.exports.__beta26.Dev._ownershipState =
      mod.exports.__beta26.Dev._ownershipState or {}
  mod.exports.__beta26.Dev.observeOwnership = function(game, snapshot)
      if not mod.exports.__beta26.Dev.enabled() or type(snapshot) ~= "table" then
          return false
      end
      local dev = mod.exports.__beta26.Dev
      local gameId = type(dev.gameId) == "function"
          and dev.gameId(game or liveGame() or mod.game) or "unknown"
      local now = {}
      for _, row in ipairs(snapshot.capabilities or {}) do
          local capability = tostring(row.capability or "")
          if capability ~= "" then
              now[capability] = {
                  owner=tostring(row.selected_owner or "NUZLOCKE"),
                  state=tostring(row.state or row.selected_state or "fallback"),
                  degraded=row.degraded == true,
              }
          end
      end
      local previous = dev._ownershipState[gameId]
      if type(previous) == "table" then
          local keys = {}
          for key in pairs(previous) do keys[key] = true end
          for key in pairs(now) do keys[key] = true end
          local ordered = {}
          for key in pairs(keys) do ordered[#ordered + 1] = key end
          table.sort(ordered)
          for _, capability in ipairs(ordered) do
              local before = previous[capability]
              local after = now[capability]
              local beforeOwner = before and before.owner or "UNAVAILABLE"
              local afterOwner = after and after.owner or "UNAVAILABLE"
              local beforeState = before and before.state or "unavailable"
              local afterState = after and after.state or "unavailable"
              local beforeDegraded = before and before.degraded == true or false
              local afterDegraded = after and after.degraded == true or false
              if beforeOwner ~= afterOwner or beforeState ~= afterState
                  or beforeDegraded ~= afterDegraded then
                  dev.ownershipSequence = (tonumber(dev.ownershipSequence) or 0) + 1
                  local row = {
                      seq=dev.ownershipSequence,
                      game=gameId,
                      capability=capability,
                      from_owner=beforeOwner, to_owner=afterOwner,
                      from_state=beforeState, to_state=afterState,
                      degraded=afterDegraded,
                      build=mod.exports.__beta26.build,
                  }
                  dev.ownershipHistoryRows[#dev.ownershipHistoryRows + 1] = row
                  while #dev.ownershipHistoryRows >
                      (tonumber(dev.maxOwnershipHistory) or 32) do
                      table.remove(dev.ownershipHistoryRows, 1)
                  end
              end
          end
      end
      dev._ownershipState[gameId] = now
      return true
  end
  mod.exports.__beta26.Dev.ownershipHistory = function(limit)
      local rows = mod.exports.__beta26.Dev.ownershipHistoryRows or {}
      limit = math.max(1, math.floor(tonumber(limit) or #rows))
      local first = math.max(1, #rows - limit + 1)
      local out = {}
      for i = first, #rows do
          local row = rows[i]
          out[#out + 1] = {
              seq=row.seq, game=row.game, capability=row.capability,
              from_owner=row.from_owner, to_owner=row.to_owner,
              from_state=row.from_state, to_state=row.to_state,
              degraded=row.degraded, build=row.build,
          }
      end
      return out
  end

  mod.exports.__beta26.Dev.providerOwnership = function(game)
      game = game or liveGame() or mod.game
      local interop = mod.exports.nuzlocke and mod.exports.nuzlocke.interop
      if type(interop) ~= "table"
          or type(interop.compatibilitySnapshot) ~= "function" then
          return { status="N/A", provider_count=0, capability_count=0,
              degraded=0, selected=0, providers={}, capabilities={},
              reason="provider_registry_unavailable" }
      end
      local ok, snapshot = pcall(interop.compatibilitySnapshot)
      if not ok or type(snapshot) ~= "table" then
          return { status="FAIL", provider_count=0, capability_count=0,
              degraded=0, selected=0, providers={}, capabilities={},
              reason="provider_snapshot_error" }
      end
      local providers, capabilities = {}, {}
      for _, row in ipairs(snapshot.providers or {}) do
          providers[#providers + 1] = {
              id=row.id, name=row.name, version=row.version,
              detected=row.detected == true, advertised=row.advertised == true,
              automatic=row.automatic == true, state=row.state,
              capabilities=row.capabilities or {}, source=row.source,
          }
      end
      for _, row in ipairs(snapshot.capabilities or {}) do
          capabilities[#capabilities + 1] = {
              capability=row.capability, detected=row.detected == true,
              advertised=row.advertised == true, selected_owner=row.selected_owner,
              selected_kind=row.selected_kind, selected_state=row.selected_state,
              state=row.state, degraded=row.degraded == true,
          }
      end
      local degraded = tonumber(snapshot.degraded) or 0
      local result = {
          status=degraded > 0 and "DEGRADED" or "OK",
          provider_count=tonumber(snapshot.provider_count) or #providers,
          capability_count=tonumber(snapshot.capability_count) or #capabilities,
          selected=tonumber(snapshot.external_selected) or 0, degraded=degraded,
          providers=providers, capabilities=capabilities,
      }
      pcall(mod.exports.__beta26.Dev.observeOwnership, game, result)
      return result
  end

  mod.exports.__beta26.Dev.encounterProvenance = function(game, battle)
      game = game or liveGame() or mod.game
      local fn = mod.exports.__beta26.activeEncounterProvenance
      if type(fn) ~= "function" then
          return { active=false, state="unavailable", reason="encounter_probe_unavailable" }
      end
      local ok, value = pcall(fn, battle)
      if not ok or type(value) ~= "table" then
          return { active=false, state="error", reason="encounter_probe_error" }
      end
      return value
  end

  local function healthRow(status, reason, detail)
      return { status=tostring(status or "N/A"), reason=tostring(reason or ""),
          detail=detail }
  end

  ---------------------------------------------------------------------
  -- 2.8.46 RULE CONFIGURATION / SAVE-RUN IDENTITY HEALTH
  ---------------------------------------------------------------------
  mod.exports.__beta26.Dev.ruleConfigurationConsistency = function(game)
      game = game or liveGame() or mod.game
      local registry = mod.exports.__beta26.ruleRegistry
      local stored = type(registry) == "table"
          and type(registry.validateStored) == "function"
          and registry.validateStored() or
          { ok=false, invalid_count=0, stale_count=0, issues={},
            errors={"registry_validate_unavailable"} }
      local registryAudit = type(registry) == "table"
          and type(registry.audit) == "function" and registry.audit()
          or { ok=false, errors={"registry_audit_unavailable"} }
      local availability = type(mod.exports.__beta26.ruleAvailabilityAudit) == "function"
          and mod.exports.__beta26.ruleAvailabilityAudit()
          or { ok=false, failures={"availability_audit_unavailable"} }

      local described = type(registry) == "table"
          and type(registry.describe) == "function" and registry.describe()
          or { rows={}, count=0 }
      local defs = mod.exports.__beta26.ruleDefinitionByKey or {}
      local definitionCount = 0
      for _ in pairs(defs) do definitionCount = definitionCount + 1 end
      local descriptorKeys = {}
      for _, row in ipairs(described.rows or {}) do descriptorKeys[row.key] = true end
      local catalogMismatches = {}
      for key in pairs(defs) do
          if not descriptorKeys[key] then
              catalogMismatches[#catalogMismatches + 1] =
                  tostring(key) .. ":missing_descriptor"
          end
      end
      table.sort(catalogMismatches)

      local dormant = {}
      if type(mod.exports.__beta26.ruleOperationalState) == "function" then
          for key, spec in pairs(defs) do
              local raw = mod.save:get(key, nil)
              if raw ~= nil then
                  local default = type(spec) == "table" and spec.default or nil
                  local configured = raw ~= default
                  if configured then
                      local okState, operational, reason = pcall(
                          mod.exports.__beta26.ruleOperationalState,
                          key, false, game)
                      if okState and operational ~= true
                          and (reason == "dependency" or reason == "superseded") then
                          dormant[#dormant + 1] = {
                              key=tostring(key), reason=tostring(reason),
                              value=raw, default=default,
                          }
                      end
                  end
              end
          end
      end
      table.sort(dormant, function(a, b) return a.key < b.key end)

      local invalid = tonumber(stored.invalid_count) or 0
      local stale = tonumber(stored.stale_count) or 0
      local hard = invalid + #catalogMismatches
          + (registryAudit.ok == true and 0 or #(registryAudit.errors or {}))
          + (availability.ok == true and 0 or #(availability.failures or {}))
      local status = hard > 0 and "FAIL"
          or (stale > 0 or #dormant > 0) and "WARN" or "OK"
      return {
          status=status,
          reason=hard > 0 and "configuration_contract_error"
              or (#dormant > 0 and "dormant_configured_children"
                  or stale > 0 and "legacy_stored_values" or "consistent"),
          stored=stored,
          registry=registryAudit,
          availability=availability,
          definition_count=definitionCount,
          descriptor_count=tonumber(described.count) or #(described.rows or {}),
          catalog_mismatches=catalogMismatches,
          dormant=dormant,
          dormant_count=#dormant,
          invalid_count=invalid,
          stale_count=stale,
      }
  end

  mod.exports.__beta26.Dev.saveRunIdentityHealth = function(game)
      game = game or liveGame() or mod.game
      local identity = type(mod.exports.__beta26.Dev.editionContext) == "function"
          and mod.exports.__beta26.Dev.editionContext(game) or {}
      local storage, storageCode = nil, nil
      if type(mod.exports.__beta26.Dev.storageContext) == "function" then
          storage, storageCode = mod.exports.__beta26.Dev.storageContext(game)
      end
      local runHistory = mod.save:get("run_history_v1", nil)
      if type(runHistory) ~= "table" then runHistory = nil end
      local randomRun = type(mod.exports.__beta26.randomizerRunConfig) == "function"
          and mod.exports.__beta26.randomizerRunConfig() or nil
      local schema = tonumber(mod.save:get(SAVE_SCHEMA_KEY, CURRENT_SAVE_SCHEMA))
      local issues = {}

      local function norm(value)
          local text = tostring(value or ""):lower():gsub("[^a-z0-9]", "")
          local aliases = {
              pokemonred="red", pokemonblue="blue", pokemonyellow="yellow",
              pokemongold="gold", pokemonsilver="silver", pokemoncrystal="crystal",
          }
          return aliases[text] or text
      end
      local edition = norm(identity.edition)
      if schema ~= tonumber(CURRENT_SAVE_SCHEMA) then
          issues[#issues + 1] = {
              code="save_schema", expected=CURRENT_SAVE_SCHEMA, actual=schema,
          }
      end
      if type(storage) == "table" and storage.gameVersion ~= nil
          and norm(storage.gameVersion) ~= "" and norm(storage.gameVersion) ~= edition then
          issues[#issues + 1] = {
              code="storage_edition", expected=edition,
              actual=tostring(storage.gameVersion),
          }
      end
      if runHistory then
          if runHistory.edition ~= nil and norm(runHistory.edition) ~= edition then
              issues[#issues + 1] = {
                  code="history_edition", expected=edition,
                  actual=tostring(runHistory.edition),
              }
          end
          if tonumber(runHistory.generation) ~= nil
              and tonumber(runHistory.generation) ~= tonumber(identity.generation) then
              issues[#issues + 1] = {
                  code="history_generation", expected=identity.generation,
                  actual=runHistory.generation,
              }
          end
      end
      if type(randomRun) == "table" and randomRun.game ~= nil
          and norm(randomRun.game) ~= "" and norm(randomRun.game) ~= edition then
          issues[#issues + 1] = {
              code="randomizer_run_edition", expected=edition,
              actual=tostring(randomRun.game),
          }
      end
      local status = #issues > 0 and "WARN" or "OK"
      if schema ~= tonumber(CURRENT_SAVE_SCHEMA) then status = "FAIL" end
      return {
          status=status,
          reason=#issues > 0 and "identity_mismatch" or "identity_consistent",
          edition=identity.edition,
          generation=identity.generation,
          engine_family=identity.engine_family,
          profile_scope=identity.profile_scope,
          save_schema=schema,
          expected_schema=CURRENT_SAVE_SCHEMA,
          storage_available=type(storage) == "table",
          storage_code=storageCode,
          storage_game=type(storage) == "table" and storage.gameVersion or nil,
          storage_playthrough=type(storage) == "table"
              and storage.playthroughId or nil,
          history_run_id=runHistory and runHistory.run_id or nil,
          history_edition=runHistory and runHistory.edition or nil,
          history_generation=runHistory and runHistory.generation or nil,
          history_version=runHistory and runHistory.version or nil,
          randomizer_run_game=type(randomRun) == "table" and randomRun.game or nil,
          randomizer_run_schema=type(randomRun) == "table" and randomRun.schema or nil,
          randomizer_algorithm=type(randomRun) == "table" and randomRun.algorithm or nil,
          issues=issues,
          issue_count=#issues,
      }
  end

  ---------------------------------------------------------------------
  -- 2.8.43 TRANSACTION HEALTH / HOOK-WRAPPER DRIFT
  -- Diagnostics only. These surfaces inspect already-materialized journals
  -- and registered hook ownership; they never recover, repair, re-register,
  -- reclaim, or otherwise mutate the game/mod state.
  ---------------------------------------------------------------------
  mod.exports.__beta26.Dev.transactionHealth = function()
      local TX = mod.exports.__beta26.GameplayTransactions
      if type(TX) ~= "table" or type(TX.status) ~= "function" then
          return { status="N/A", reason="transaction_api_unavailable",
              api=nil, pending=nil, receipt_count=0, handler_count=0,
              fail_closed=true }
      end
      local ok, base = pcall(TX.status)
      if not ok or type(base) ~= "table" then
          return { status="FAIL", reason="transaction_status_error",
              error=ok and "invalid_status" or tostring(base),
              pending=nil, receipt_count=0, handler_count=0,
              fail_closed=true }
      end

      local receiptRoot = type(mod.save) == "table"
          and type(mod.save.get) == "function"
          and mod.save:get(TX.receipts_key, {}) or {}
      if type(receiptRoot) ~= "table" then receiptRoot = {} end
      local order = type(receiptRoot.order) == "table" and receiptRoot.order or {}
      local byId = type(receiptRoot.by_id) == "table" and receiptRoot.by_id or {}
      local lastId = order[#order]
      local last = lastId and byId[lastId] or nil

      local pending = type(base.pending) == "table" and base.pending or nil
      local state = pending and tostring(pending.state or "intent") or "clear"
      local status = pending and "WARN" or "OK"
      local reason = pending and ("pending_" .. state) or "journal_clear"
      local registeredKinds = {}
      for kind in pairs(type(TX.handlers) == "table" and TX.handlers or {}) do
          registeredKinds[#registeredKinds + 1] = tostring(kind)
      end
      table.sort(registeredKinds)

      local sequences = type(receiptRoot.sequences) == "table"
          and receiptRoot.sequences or {}
      local sequenceCount = 0
      for _ in pairs(sequences) do sequenceCount = sequenceCount + 1 end

      return {
          status=status, reason=reason, api=base.api,
          fail_closed=true, recovery_policy="probe_or_refuse",
          pending=pending,
          pending_id=pending and tostring(pending.id or "?") or nil,
          pending_kind=pending and tostring(pending.kind or "?") or nil,
          pending_state=pending and tostring(pending.state or "?") or nil,
          pending_detail=pending and tostring(pending.detail or "") or nil,
          pending_build=pending and tostring(pending.build or "?") or nil,
          receipt_count=tonumber(base.receipt_count) or #order,
          receipt_limit=tonumber(TX.receipt_limit) or 0,
          handler_count=tonumber(base.handler_count) or #registeredKinds,
          handlers=registeredKinds,
          sequence_namespace_count=sequenceCount,
          last_receipt=type(last) == "table" and {
              id=tostring(last.id or lastId or "?"),
              kind=tostring(last.kind or "?"),
              build=tostring(last.build or "?"),
              state=tostring(last.state or "committed"),
          } or nil,
      }
  end

  -- 2.8.44: read-only Randomizer reproducibility view. It deliberately
  -- consumes the Randomizer's existing reproducibility report, which reads
  -- only persisted seed/run-contract/source-map metadata and never asks for
  -- a new AUTO seed or materializes an unseen mapping.
  mod.exports.__beta26.Dev.randomizerReproducibility = function(game)
      game = game or liveGame() or mod.game
      local fn = mod.exports.__beta26.randomizerReproducibilityReport
      if type(fn) ~= "function" then
          return { status="N/A", reason="reproducibility_api_unavailable",
              active=false, source_maps={}, ownership={} }
      end
      local ok, report = pcall(fn, game)
      if not ok or type(report) ~= "table" then
          return { status="FAIL", reason="reproducibility_report_error",
              active=false, error=ok and "invalid_report" or tostring(report),
              source_maps={}, ownership={} }
      end
      local seed = type(report.seed) == "table" and report.seed or {}
      local run = type(report.runConfig) == "table" and report.runConfig or nil
      local active = run ~= nil or tonumber(seed.configuredSeed or 0) > 0
          or tonumber(seed.resolvedSeed or 0) > 0
      local maps = {}
      for name, row in pairs(type(report.sourceMaps) == "table"
          and report.sourceMaps or {}) do
          maps[#maps + 1] = {
              stream=tostring(name),
              save_key=type(row) == "table" and tostring(row.saveKey or "?") or "?",
              count=type(row) == "table" and tonumber(row.count or 0) or 0,
              shared=type(row) == "table" and row.shared == true or false,
          }
      end
      table.sort(maps, function(a, b) return a.stream < b.stream end)
      return {
          status=not active and "N/A"
              or (report.reproducible == true and "OK" or "WARN"),
          reason=not active and "randomizer_inactive"
              or tostring(report.note or "run_contract"),
          active=active,
          reproducible=report.reproducible == true,
          game=report.game,
          mode=seed.mode,
          configured_seed=tonumber(seed.configuredSeed or 0),
          resolved_seed=tonumber(seed.resolvedSeed or 0),
          share_code=seed.shareCode,
          algorithm=run and run.algorithm
              or (type(report.versions) == "table" and report.versions.algorithm),
          run_schema=run and run.schema or nil,
          run_game=run and run.game or nil,
          settings_drift=type(report.settingsDrift) == "table"
              and report.settingsDrift or {},
          mid_run_policy=report.midRunPolicy,
          ownership=type(report.ownership) == "table" and report.ownership or {},
          source_maps=maps,
          versions=report.versions,
      }
  end

  -- 2.8.44: shiny diagnostics report ownership, configured presentation
  -- policy, and the already-materialized identity of the current/last enemy.
  -- It never rolls shiny odds or requests a sprite/palette.
  mod.exports.__beta26.Dev.shinyDiagnostics = function(game)
      game = game or liveGame() or mod.game
      local owner = type(mod.exports.__beta26.shinySystemOwner) == "function"
          and tostring(mod.exports.__beta26.shinySystemOwner(game)) or "N/A"
      local external = type(mod.exports.__beta26.shinyExternalProvider) == "function"
          and mod.exports.__beta26.shinyExternalProvider(game) or nil
      local rateMode = type(mod.exports.__beta26.shinyRateMode) == "function"
          and tonumber(mod.exports.__beta26.shinyRateMode()) or 0
      local rateLabel = type(mod.exports.__beta26.shinyRateLabel) == "function"
          and tostring(mod.exports.__beta26.shinyRateLabel(rateMode)) or tostring(rateMode)
      -- Keep diagnostic fallbacks aligned with the authoritative Rule Catalog.
      -- Both visual controls default ON; an unset save key must report the same
      -- effective value the runtime uses.
      local colors = mod.save:get("shiny_colors", true) == true
      local intro = mod.save:get("shiny_intro", true) == true
      local encounter = mod.exports.__beta26.Dev.encounterProvenance(game)
      local life = mod.exports.__beta26.Dev.lifecycle or {}
      local battle = life.lastBattle
      local mon = type(battle) == "table" and battle.enemy
          and (battle.enemy.mon or battle.enemy) or nil
      local shiny = nil
      local source = nil
      if type(mon) == "table" then
          if type(mon.shiny) == "boolean" then shiny = mon.shiny
          elseif type(mon.isShiny) == "boolean" then shiny = mon.isShiny
          elseif type(mon.is_shiny) == "boolean" then shiny = mon.is_shiny end
          source = mon.nuzlockeShinySource or mon.shinySource
      end
      if shiny == nil and type(encounter) == "table"
          and encounter.shiny ~= nil then shiny = encounter.shiny == true end
      local providerId = nil
      if type(external) == "table" then
          providerId = tostring(external.id or external.name or "SHINY_POKEMON")
      end
      return {
          status=owner == "N/A" and "N/A" or "OK",
          owner=owner,
          external=external ~= nil,
          provider=providerId,
          provider_version=type(external) == "table"
              and tostring(external.version or external.api_version or "?") or nil,
          rate_mode=rateMode,
          rate_label=rateLabel,
          colors_enabled=colors,
          intro_enabled=intro,
          generation_owner=owner,
          presentation_owner=external and providerId or "Nuzlocke",
          current_identity=shiny,
          identity_source=source
              or (shiny ~= nil and "materialized_mon" or "unavailable"),
      }
  end

  mod.exports.__beta26.Dev.hookWrapperDrift = function()
      local registry = mod.exports.__beta26.hookRegistry
      if type(registry) ~= "table" or type(registry.describe) ~= "function" then
          return { status="N/A", reason="hook_registry_unavailable",
              checked=0, ok=0, drift=0, unavailable=0, rows={} }
      end
      local ok, described = pcall(registry.describe)
      if not ok or type(described) ~= "table" then
          return { status="FAIL", reason="hook_registry_error",
              checked=0, ok=0, drift=0, unavailable=0, rows={},
              error=ok and "invalid_registry" or tostring(described) }
      end

      local ids = {}
      for id in pairs(described) do ids[#ids + 1] = tostring(id) end
      table.sort(ids)
      local rows, countOk, drift, unavailable = {}, 0, 0, 0
      for _, id in ipairs(ids) do
          local row = described[id] or {}
          local state, reason
          if row.live == true then
              state, reason = "OK", "wrapper_still_direct"
              countOk = countOk + 1
          elseif row.live == false then
              state, reason = "DRIFT", "interposed_or_replaced"
              drift = drift + 1
          else
              state, reason = "N/A", "no_live_probe"
              unavailable = unavailable + 1
          end
          rows[#rows + 1] = {
              id=id, state=state, reason=reason,
              owner=row.owner, mode=row.mode, feature=row.feature,
              source=row.source, registrations=row.registrations,
              previous_type=row.previous_type, wrapper_type=row.wrapper_type,
          }
      end
      return {
          status=drift > 0 and "DRIFT" or "OK",
          reason=drift > 0 and "hook_interposition_observed" or "registered_hooks_stable",
          checked=#rows, ok=countOk, drift=drift, unavailable=unavailable,
          rows=rows,
      }
  end

  -- 2.8.55: read-only localization health. This observes only the
  -- translation companion lifecycle plus already-registered Nuzlocke source
  -- strings. It never installs translations, switches language, rebuilds
  -- catalogs, or mutates companion state.
  mod.exports.__beta26.Dev.localizationDiagnostics = function(game)
      game = game or liveGame() or mod.game
      local translation = mod.exports.nuzlocke_translation
      local companions = {}
      if type(translation) == "table" and type(translation.detect) == "function" then
          local ok, value = pcall(translation.detect)
          if ok and type(value) == "table" then companions = value end
      end

      local sources = {}
      if type(translation) == "table" and type(translation.sources) == "function" then
          local ok, value = pcall(translation.sources)
          if ok and type(value) == "table" then sources = value end
      end

      local catalog = {}
      if type(translation) == "table" and type(translation.catalog) == "function" then
          local ok, value = pcall(translation.catalog)
          if ok and type(value) == "table" then catalog = value end
      end

      local installed, active, restart = 0, 0, 0
      local companionRows = {}
      for _, row in ipairs(companions) do
          installed = installed + 1
          if row.translationActive == true then active = active + 1 end
          if row.restartRequired == true then restart = restart + 1 end
          companionRows[#companionRows + 1] = {
              id=row.id, name=row.name, version=row.version,
              reviewed=row.reviewed, status=row.status,
              activity=row.activity,
              translationActive=row.translationActive == true,
              bootLanguage=row.bootLanguage,
              pendingLanguage=row.pendingLanguage,
              restartRequired=row.restartRequired == true,
              edition=row.edition,
              replacementMapScripts=row.replacementMapScripts == true,
              replacementMapScriptsPresent=
                  row.replacementMapScriptsPresent == true,
              mutationReviewRequired=row.mutationReviewRequired == true,
              fixedCellCJK=row.fixedCellCJK == true,
              engineInternalsPresentationWrappers=
                  row.engineInternalsPresentationWrappers == true,
              dynamicScriptPresentationWrapper=
                  row.dynamicScriptPresentationWrapper == true,
              stringsGetWrapper=row.stringsGetWrapper == true,
              fontDrawWrapper=row.fontDrawWrapper == true,
              optionRowsWrapper=row.optionRowsWrapper == true,
              namingGridWrapper=row.namingGridWrapper == true,
              certificationFocus=type(row.certificationFocus) == "table"
                  and row.certificationFocus or {},
          }
      end

      local fallback, resolved = 0, 0
      local byKind = {}
      for _, row in ipairs(sources) do
          local source = tostring(row.source or "")
          local translated = catalog[source]
          local isFallback = translated == nil or tostring(translated) == source
          if isFallback then fallback = fallback + 1 else resolved = resolved + 1 end
          local kind = tostring(row.kind or "unknown")
          local bucket = byKind[kind] or { total=0, fallback=0, resolved=0 }
          bucket.total = bucket.total + 1
          if isFallback then bucket.fallback = bucket.fallback + 1
          else bucket.resolved = bucket.resolved + 1 end
          byKind[kind] = bucket
      end

      local status, reason = "N/A", "no_translation_companion"
      if restart > 0 then
          status, reason = "WARN", "restart_required"
      elseif active > 0 then
          status = "OK"
          reason = string.format("active=%d fallback=%d/%d",
              active, fallback, #sources)
      elseif installed > 0 then
          status, reason = "N/A", "installed_inactive"
      end

      return {
          status=status, reason=reason,
          installed=installed, active=active, restart_required=restart,
          source_count=#sources, fallback_count=fallback,
          resolved_count=resolved, companions=companionRows, by_kind=byKind,
      }
  end

  -- 2.8.62: session-only localization runtime certification ledger.
  -- Manual states live only in Dev memory and are keyed to the exact detected
  -- game/translation combination. This never writes save data and never
  -- infers a PASS from static/source diagnostics.
  local LOCALIZATION_CERT_CHECKS = {
      { id="setup_rules", label="SETUP / NUZ RULES" },
      { id="status_tracker", label="NUZ STATUS / ENC TRACKER" },
      { id="battle_denial", label="BATTLE DENIAL" },
      { id="mart_denial", label="MART BUY / SELL" },
      { id="party_info", label="PARTY / NUZ INFO" },
      { id="move_learn", label="MOVE LEARN / RARE CANDY" },
      { id="forgiveness", label="F. TOKEN / FORGIVENESS" },
      { id="randomizer", label="RANDOMIZER LABELS" },
      { id="world_building", label="WORLD BUILDING TEXT" },
      { id="dev_report", label="DEV REPORT / LOCALIZATION" },
  }

  local function localizationCertIdentity(game)
      game = game or liveGame() or mod.game
      local edition = "unknown"
      if type(mod.exports.__beta26.Dev.gameId) == "function" then
          local ok, value = pcall(mod.exports.__beta26.Dev.gameId, game)
          if ok and value ~= nil then edition = tostring(value) end
      end
      local loc = mod.exports.__beta26.Dev.localizationDiagnostics(game)
      local companions = {}
      for _, row in ipairs(loc.companions or {}) do
          companions[#companions + 1] = {
              id=tostring(row.id or "?"),
              version=tostring(row.version or "?"),
              activity=tostring(row.activity or "?"),
              bootLanguage=row.bootLanguage and tostring(row.bootLanguage) or nil,
              pendingLanguage=row.pendingLanguage and tostring(row.pendingLanguage) or nil,
              restartRequired=row.restartRequired == true,
              edition=row.edition and tostring(row.edition) or nil,
          }
      end
      table.sort(companions, function(a,b)
          if a.id ~= b.id then return a.id < b.id end
          return a.version < b.version
      end)
      local bits = { edition:lower() }
      for _, row in ipairs(companions) do
          bits[#bits + 1] = table.concat({
              row.id, row.version, row.activity,
              row.bootLanguage or "-", row.pendingLanguage or "-",
              row.restartRequired and "restart" or "steady",
              row.edition or "-"
          }, "@")
      end
      return edition, companions, table.concat(bits, "|")
  end

  local function localizationCertStore()
      local dev = mod.exports.__beta26.Dev
      dev.localizationCertificationSessions =
          type(dev.localizationCertificationSessions) == "table"
          and dev.localizationCertificationSessions or {}
      return dev.localizationCertificationSessions
  end

  mod.exports.__beta26.Dev.localizationCertification = function(game)
      game = game or liveGame() or mod.game
      local edition, companions, signature = localizationCertIdentity(game)
      local store = localizationCertStore()
      local session = store[signature]
      if type(session) ~= "table" then
          session = { states={}, createdBuild=tostring(mod.exports.__beta26.build or "?") }
          store[signature] = session
      end
      session.states = type(session.states) == "table" and session.states or {}

      local rows = {}
      local pass, fail, untested = 0, 0, 0
      for index, def in ipairs(LOCALIZATION_CERT_CHECKS) do
          local state = tostring(session.states[def.id] or "UNTESTED"):upper()
          if state ~= "PASS" and state ~= "FAIL" then state = "UNTESTED" end
          if state == "PASS" then pass = pass + 1
          elseif state == "FAIL" then fail = fail + 1
          else untested = untested + 1 end
          rows[#rows + 1] = {
              index=index, id=def.id, label=def.label, state=state,
          }
      end

      local companionBits = {}
      for _, row in ipairs(companions) do
          companionBits[#companionBits + 1] =
              tostring(row.id) .. " " .. tostring(row.version)
      end
      local companionText = #companionBits > 0
          and table.concat(companionBits, " + ") or "NO TRANSLATION"
      local summary = string.format(
          "%s / %s / %d checks / %d PASS / %d FAIL / %d UNTESTED",
          tostring(edition):upper(), companionText, #rows, pass, fail, untested)

      return {
          signature=signature, edition=edition, companions=companions,
          checks=rows, total=#rows, pass=pass, fail=fail, untested=untested,
          complete=untested == 0,
          certified=#companions > 0 and untested == 0 and fail == 0 and #rows > 0,
          summary=summary,
          session_only=true,
      }
  end

  mod.exports.__beta26.Dev.localizationCertificationMark =
      function(game, index, requested)
          local cert = mod.exports.__beta26.Dev.localizationCertification(game)
          index = math.max(1, math.min(#cert.checks,
              math.floor(tonumber(index) or 1)))
          local row = cert.checks[index]
          if not row then return false, "invalid_check" end
          local nextState = requested and tostring(requested):upper() or nil
          if nextState ~= "PASS" and nextState ~= "FAIL"
              and nextState ~= "UNTESTED" then
              if row.state == "UNTESTED" then nextState = "PASS"
              elseif row.state == "PASS" then nextState = "FAIL"
              else nextState = "UNTESTED" end
          end
          local store = localizationCertStore()
          local session = store[cert.signature]
          session.states[row.id] = nextState
          return true, mod.exports.__beta26.Dev.localizationCertification(game)
      end

  mod.exports.__beta26.Dev.localizationCertificationReset = function(game)
      local _, _, signature = localizationCertIdentity(game)
      localizationCertStore()[signature] = nil
      return true, mod.exports.__beta26.Dev.localizationCertification(game)
  end

  mod.exports.__beta26.Dev.systemHealth = function(game)
      game = game or liveGame() or mod.game
      local hook = type(mod.exports.__beta26.Dev.hookHealth) == "function"
          and mod.exports.__beta26.Dev.hookHealth(game) or {}
      local hc = hook.counts or {}
      local life = type(mod.exports.__beta26.Dev.lifecycleReport) == "function"
          and mod.exports.__beta26.Dev.lifecycleReport() or {}
      local writes = type(mod.exports.__beta26.safeStopWriteReport) == "function"
          and mod.exports.__beta26.safeStopWriteReport() or {}
      local rules = type(mod.exports.__beta26.Dev.ruleEffectiveness) == "function"
          and mod.exports.__beta26.Dev.ruleEffectiveness(game) or {}
      local rc = rules.counts or {}
      local random = type(mod.exports.__beta26.Dev.randomizerIntegrity) == "function"
          and mod.exports.__beta26.Dev.randomizerIntegrity(game) or {}
      local randomRepro = mod.exports.__beta26.Dev.randomizerReproducibility(game)
      local shinyDiag = mod.exports.__beta26.Dev.shinyDiagnostics(game)
      local providers = mod.exports.__beta26.Dev.providerOwnership(game)
      local encounter = mod.exports.__beta26.Dev.encounterProvenance(game)
      local tx = mod.exports.__beta26.Dev.transactionHealth()
      local drift = mod.exports.__beta26.Dev.hookWrapperDrift()
      local feature = type(mod.exports.__beta26.featureHealth) == "table"
          and type(mod.exports.__beta26.featureHealth.status) == "function"
          and mod.exports.__beta26.featureHealth.status() or {}
      local perf = type(mod.exports.__beta26.Dev.performanceCounters) == "function"
          and mod.exports.__beta26.Dev.performanceCounters() or
          { status="N/A", enabled=false, count=0, rows={} }
      local ruleConsistency = mod.exports.__beta26.Dev.ruleConfigurationConsistency(game)
      local identityHealth = mod.exports.__beta26.Dev.saveRunIdentityHealth(game)
      local ownershipHistory = mod.exports.__beta26.Dev.ownershipHistory(32)
      local localization = mod.exports.__beta26.Dev.localizationDiagnostics(game)

      local engineStatus = (tonumber(hc.missing) or 0) > 0 and "WARN" or "OK"
      local saveStatus = (writes.active == true or (tonumber(writes.total) or 0) > 0)
          and "FAIL" or tostring(identityHealth.status or "OK")
      local rulesStatus = (tonumber(rc.errors) or 0) > 0 and "FAIL"
          or tostring(ruleConsistency.status or "OK")
      local encounterStatus = encounter.state == "error" and "FAIL"
          or encounter.state == "unavailable" and "WARN" or "OK"
      local battleStatus = (tonumber(life.duplicate_callbacks) or 0) > 0 and "WARN"
          or math.abs(tonumber(life.battle_delta) or 0) > 1 and "WARN" or "OK"
      local randomStatus = tostring(random.status or "INACTIVE"):upper()
      if randomStatus == "ERROR" then randomStatus = "FAIL"
      elseif randomStatus == "WARN" then randomStatus = "WARN"
      elseif randomStatus == "INACTIVE" then randomStatus = "N/A"
      else randomStatus = "OK" end
      local providerStatus = tostring(providers.status or "N/A")
      local shinyStatus = "OK"
      local shinyOwner = "NUZLOCKE"
      local shinyCap = nil
      for _, row in ipairs(providers.capabilities or {}) do
          local cap = tostring(row.capability or ""):upper()
          if cap == "SHINY_IDENTITY" or cap == "SHINY_PRESENTATION" then
              shinyCap = row
              if row.state == "external_selected" and row.selected_owner then
                  shinyOwner = tostring(row.selected_owner)
              elseif row.degraded == true then shinyStatus = "DEGRADED" end
          end
      end
      local uiWarn = 0
      for key, row in pairs(feature or {}) do
          local k = tostring(key):lower()
          if (k:find("ui",1,true) or k:find("screen",1,true) or k:find("menu",1,true))
              and type(row) == "table" and tostring(row.state or ""):upper() == "FAILED" then
              uiWarn = uiWarn + 1
          end
      end
      local uiStatus = uiWarn > 0 and "WARN" or "OK"

      local rows = {
          ENGINE=healthRow(engineStatus, "hook_health", hc),
          SAVE=healthRow(saveStatus, writes.active and "safe_stop"
              or identityHealth.reason or "writes_clean",
              { writes=writes, identity=identityHealth }),
          IDENTITY=healthRow(identityHealth.status or "N/A",
              identityHealth.reason or "identity", identityHealth),
          RULES=healthRow(rulesStatus, ruleConsistency.reason or "rule_effectiveness",
              { effectiveness=rc, consistency=ruleConsistency }),
          ENCOUNTER=healthRow(encounterStatus, encounter.state or "none", encounter),
          BATTLE=healthRow(battleStatus, "lifecycle", life),
          RANDOMIZER=healthRow(randomStatus, tostring(random.status or "INACTIVE"), random),
          LOCALIZATION=healthRow(localization.status or "N/A",
              localization.reason or "localization", localization),
          PROVIDERS=healthRow(providerStatus, tostring(providers.reason or "registry"), providers),
          OWNERSHIP=healthRow("OK", "transitions=" .. tostring(#ownershipHistory),
              ownershipHistory),
          SHINY=healthRow(shinyStatus, "owner=" .. shinyOwner, shinyDiag),
          UI=healthRow(uiStatus, uiWarn > 0 and ("failed_surfaces=" .. uiWarn) or "healthy", feature),
          HOOKS=healthRow(drift.status == "DRIFT" and "WARN" or drift.status,
              drift.reason or "hook_registry", drift),
          PERFORMANCE=healthRow(perf.status or "N/A",
              perf.enabled and ("counters=" .. tostring(perf.count or 0))
                  or "dev_disabled", perf),
          TRANSACTIONS=healthRow(tx.status or "N/A", tx.reason or "transactions", tx),
      }
      local worst = "OK"
      local rank = { ["N/A"]=0, OK=1, WARN=2, DEGRADED=3, FAIL=4 }
      for _, row in pairs(rows) do
          if (rank[row.status] or 0) > (rank[worst] or 0) then worst = row.status end
      end
      return { status=worst, rows=rows, provider_ownership=providers,
          encounter=encounter, transaction_health=tx, hook_drift=drift,
          randomizer_reproducibility=randomRepro, shiny_diagnostics=shinyDiag,
          performance=perf, rule_consistency=ruleConsistency,
          localization=localization,
          save_run_identity=identityHealth, ownership_history=ownershipHistory,
          decision_count=#(mod.exports.__beta26.Dev.decisions or {}) }
  end

  -- 2.8.42: compact, read-only bug-report snapshot. This intentionally
  -- consumes only already-materialized diagnostics and passive descriptors.
  -- It must not run self-tests, resolve AUTO seeds, invoke gameplay rules,
  -- advance RNG, repair save state, or mutate encounter/transaction state.
  mod.exports.__beta26.Dev.bugReportSnapshot = function(game)
      game = game or liveGame() or mod.game
      local identity = type(mod.exports.__beta26.Dev.editionContext) == "function"
          and mod.exports.__beta26.Dev.editionContext(game) or {}
      local health = mod.exports.__beta26.Dev.systemHealth(game)
      local providers = health.provider_ownership
          or mod.exports.__beta26.Dev.providerOwnership(game)
      local encounter = health.encounter
          or mod.exports.__beta26.Dev.encounterProvenance(game)
      local decisions = type(mod.exports.__beta26.Dev.decisionTrace) == "function"
          and mod.exports.__beta26.Dev.decisionTrace(12) or {}
      local assertions = type(mod.exports.__beta26.Dev.assertions) == "function"
          and mod.exports.__beta26.Dev.assertions(game) or {}
      local crumbs = mod.exports.__beta26.Dev.breadcrumbs or {}
      local recent = {}
      local first = math.max(1, #crumbs - 11)
      for i = first, #crumbs do
          local row = crumbs[i]
          recent[#recent + 1] = {
              seq=row.seq, lastSeq=row.lastSeq, count=row.count,
              severity=row.severity,
              game=row.game, kind=row.kind, detail=row.detail,
          }
      end

      local storage = type(mod.exports.__beta26.Dev.storageContext) == "function"
          and mod.exports.__beta26.Dev.storageContext(game) or nil
      local provenance = type(mod.exports.__beta26.buildProvenance) == "function"
          and mod.exports.__beta26.buildProvenance() or {}
      local tx = health.transaction_health
          or mod.exports.__beta26.Dev.transactionHealth()
      local drift = health.hook_drift
          or mod.exports.__beta26.Dev.hookWrapperDrift()
      local randomRepro = health.randomizer_reproducibility
          or mod.exports.__beta26.Dev.randomizerReproducibility(game)
      local shinyDiag = health.shiny_diagnostics
          or mod.exports.__beta26.Dev.shinyDiagnostics(game)
      local perf = health.performance
          or (type(mod.exports.__beta26.Dev.performanceCounters) == "function"
              and mod.exports.__beta26.Dev.performanceCounters()
              or { status="N/A", count=0, rows={} })
      local ruleConsistency = health.rule_consistency
          or mod.exports.__beta26.Dev.ruleConfigurationConsistency(game)
      local identityHealth = health.save_run_identity
          or mod.exports.__beta26.Dev.saveRunIdentityHealth(game)
      local ownershipHistory = health.ownership_history
          or mod.exports.__beta26.Dev.ownershipHistory(12)

      local warnings, errors = {}, {}
      for _, row in ipairs(assertions or {}) do
          warnings[#warnings + 1] = {
              code=tostring(row.code or "assertion"),
              detail=tostring(row.detail or ""),
          }
      end
      for _, row in ipairs(recent) do
          local kind = tostring(row.kind or ""):lower()
          local severity = tostring(row.severity or ""):upper()
          if severity == "ERROR" or kind:find("error", 1, true) then
              errors[#errors + 1] = {
                  seq=row.seq, lastSeq=row.lastSeq, count=row.count or 1,
                  severity="ERROR", code=kind, detail=tostring(row.detail or ""),
              }
          elseif severity == "WARN" or kind:find("warn", 1, true)
              or kind:find("assert", 1, true) then
              warnings[#warnings + 1] = {
                  seq=row.seq, lastSeq=row.lastSeq, count=row.count or 1,
                  severity="WARN", code=kind, detail=tostring(row.detail or ""),
              }
          end
      end

      local out = {
          build = tostring(mod.exports.__beta26.build or "?"),
          parent_build = tostring(provenance.parent_version or "?"),
          game = tostring(identity.edition or "unknown"),
          generation = tonumber(identity.generation),
          engine_family = tostring(identity.engine_family or "?"),
          profile_scope = tostring(identity.profile_scope or "?"),
          environment = type(mod.exports.__beta26.runtimeEnvironment) == "function"
              and tostring(mod.exports.__beta26.runtimeEnvironment()) or "?",
          save_schema = tonumber(mod.save:get(SAVE_SCHEMA_KEY, CURRENT_SAVE_SCHEMA)),
          run_id = type(storage) == "table"
              and tostring(storage.playthroughId or storage.runId or "?") or "?",
          storage_game = type(storage) == "table"
              and tostring(storage.gameVersion or "?") or "?",
          health = health,
          providers = providers,
          encounter = encounter,
          decisions = decisions,
          warnings = warnings,
          errors = errors,
          breadcrumbs = recent,
          transactions = tx,
          hook_drift = drift,
          randomizer_reproducibility = randomRepro,
          shiny_diagnostics = shinyDiag,
          performance = perf,
          rule_consistency = ruleConsistency,
          save_run_identity = identityHealth,
          ownership_history = ownershipHistory,
          localization = health.localization,
          localization_certification =
              mod.exports.__beta26.Dev.localizationCertification(game),
      }

      local lines = {
          "NUZLOCKE BUG REPORT SNAPSHOT",
          "build=" .. out.build .. " parent=" .. out.parent_build,
          "game=" .. out.game .. " gen=" .. tostring(out.generation or "?")
              .. " engine=" .. out.engine_family,
          "profile=" .. out.profile_scope .. " env=" .. out.environment,
          "save_schema=" .. tostring(out.save_schema or "?")
              .. " run_id=" .. out.run_id,
          "health=" .. tostring((health or {}).status or "N/A"),
      }
      local healthBits = {}
      for _, key in ipairs({ "ENGINE", "SAVE", "RULES", "ENCOUNTER",
          "BATTLE", "RANDOMIZER", "LOCALIZATION", "PROVIDERS", "OWNERSHIP", "SHINY", "UI",
          "HOOKS", "PERFORMANCE", "IDENTITY", "TRANSACTIONS" }) do
          local row = health.rows and health.rows[key] or {}
          healthBits[#healthBits + 1] = key .. ":" .. tostring(row.status or "N/A")
      end
      lines[#lines + 1] = "systems=" .. table.concat(healthBits, ",")

      local localization = health.localization or
          mod.exports.__beta26.Dev.localizationDiagnostics(game)
      lines[#lines + 1] = string.format(
          "localization=%s installed=%d active=%d restart=%d fallback=%d/%d",
          tostring(localization.status or "N/A"),
          tonumber(localization.installed or 0), tonumber(localization.active or 0),
          tonumber(localization.restart_required or 0),
          tonumber(localization.fallback_count or 0),
          tonumber(localization.source_count or 0))

      local localizationCert =
          mod.exports.__beta26.Dev.localizationCertification(game)
      lines[#lines + 1] = "localization_cert=" .. tostring(localizationCert.summary)

      lines[#lines + 1] = string.format("providers=%d selected=%d degraded=%d",
          tonumber(providers.provider_count or 0), tonumber(providers.selected or 0),
          tonumber(providers.degraded or 0))
      local ownerBits = {}
      for _, row in ipairs(providers.capabilities or {}) do
          ownerBits[#ownerBits + 1] = tostring(row.capability or "?") .. ":"
              .. tostring(row.selected_owner or "NUZLOCKE") .. "/"
              .. tostring(row.state or "?")
      end
      if #ownerBits > 0 then lines[#lines + 1] = "owners=" .. table.concat(ownerBits, ",") end

      if encounter.active == true then
          lines[#lines + 1] = "encounter="
              .. tostring(encounter.area or "?") .. "/"
              .. tostring(encounter.species or "?") .. "/"
              .. tostring(encounter.encounter_type or encounter.method or "?")
              .. " source=" .. tostring(encounter.provider or encounter.source or "?")
      else
          lines[#lines + 1] = "encounter=inactive/"
              .. tostring(encounter.state or encounter.reason or "none")
      end

      lines[#lines + 1] = string.format("transactions=%s receipts=%d pending=%s",
          tostring(tx.status or "N/A"), tonumber(tx.receipt_count or 0),
          tostring(tx.pending ~= nil))
      lines[#lines + 1] = string.format("randomizer_repro=%s mode=%s seed=%s",
          tostring(randomRepro.status or "N/A"), tostring(randomRepro.mode or "?"),
          tostring(randomRepro.share_code or "none"))
      lines[#lines + 1] = string.format("shiny_owner=%s rate=%s identity=%s",
          tostring(shinyDiag.owner or "N/A"), tostring(shinyDiag.rate_label or "?"),
          tostring(shinyDiag.current_identity))
      lines[#lines + 1] = string.format(
          "rule_consistency=%s invalid=%d stale=%d dormant=%d",
          tostring(ruleConsistency.status or "N/A"),
          tonumber(ruleConsistency.invalid_count or 0),
          tonumber(ruleConsistency.stale_count or 0),
          tonumber(ruleConsistency.dormant_count or 0))
      lines[#lines + 1] = string.format(
          "save_run_identity=%s issues=%d run=%s storage=%s",
          tostring(identityHealth.status or "N/A"),
          tonumber(identityHealth.issue_count or 0),
          tostring(identityHealth.history_run_id or "none"),
          tostring(identityHealth.storage_playthrough or "none"))
      lines[#lines + 1] = "ownership_transitions=" .. tostring(#ownershipHistory)
      local topPerf = type(perf.rows) == "table" and perf.rows[1] or nil
      lines[#lines + 1] = string.format("performance=%s counters=%d top=%s:%s",
          tostring(perf.status or "N/A"), tonumber(perf.count or 0),
          tostring(topPerf and topPerf.name or "none"),
          tostring(topPerf and topPerf.count or 0))
      lines[#lines + 1] = string.format("hook_drift=%s checked=%d drift=%d",
          tostring(drift.status or "N/A"), tonumber(drift.checked or 0),
          tonumber(drift.drift or 0))
      lines[#lines + 1] = "warnings=" .. tostring(#warnings)
          .. " errors=" .. tostring(#errors)
          .. " decisions=" .. tostring(#decisions)
          .. " breadcrumbs=" .. tostring(#recent)
      for _, row in ipairs(errors) do
          lines[#lines + 1] = "ERROR " .. tostring(row.code or "?")
              .. (tonumber(row.count or 1) > 1 and (" x" .. tostring(row.count)) or "")
              .. " " .. tostring(row.detail or "")
      end
      for i = math.max(1, #warnings - 3), #warnings do
          local row = warnings[i]
          if row then
              lines[#lines + 1] = "WARN " .. tostring(row.code or "?")
                  .. (tonumber(row.count or 1) > 1 and (" x" .. tostring(row.count)) or "")
                  .. " " .. tostring(row.detail or "")
          end
      end
      for i = math.max(1, #decisions - 5), #decisions do
          local row = decisions[i]
          if row then
              lines[#lines + 1] = "DECISION "
                  .. tostring(row.domain or "rule") .. "/"
                  .. tostring(row.rule or "?") .. " "
                  .. tostring(row.result or "INFO")
                  .. (tonumber(row.count or 1) > 1 and (" x" .. tostring(row.count)) or "")
                  .. " " .. tostring(row.detail or "")
          end
      end
      for i = math.max(1, #recent - 5), #recent do
          local row = recent[i]
          if row then
              lines[#lines + 1] = "CRUMB #" .. tostring(row.seq or "?")
                  .. " " .. tostring(row.severity or "INFO")
                  .. "/" .. tostring(row.kind or "?")
                  .. (tonumber(row.count or 1) > 1 and (" x" .. tostring(row.count)) or "")
                  .. " " .. tostring(row.detail or "")
          end
      end
      out.text = table.concat(lines, "\n")
      return out
  end
  ---------------------------------------------------------------------
  -- 2.5.67 / NZR6 DEV REPORT CODE
  --
  -- A short, deterministic, human-shareable representation of the fixed
  -- diagnostic summary. It does NOT pretend arbitrary strings/breadcrumb text
  -- are reversible in seed-sized space; instead the final fingerprint binds the
  -- code to the exact full textual report. Thus the fixed summary decodes
  -- losslessly, while any free-form detail change also changes the code.
  ---------------------------------------------------------------------
  do -- compiler-budget scope: NZR6 codec helpers
  mod.exports.__beta26.Dev.reportCodeAlphabet =
      "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

  local function reportCodeClamp(value, bits)
      local maximum = (2 ^ bits) - 1
      value = math.floor(tonumber(value) or 0)
      if value < 0 then return 0 end
      if value > maximum then return maximum end
      return value
  end

  local function reportCodeHash(text, bits)
      local modulus = 2 ^ bits
      local hash = 2166136261 % modulus
      for i = 1, #tostring(text or "") do
          hash = (hash * 16777619 + string.byte(text, i)) % modulus
      end
      return math.floor(hash)
  end

  local function reportCodePushBits(bitsOut, value, count)
      value = reportCodeClamp(value, count)
      for bit = count - 1, 0, -1 do
          local power = 2 ^ bit
          bitsOut[#bitsOut + 1] =
              math.floor(value / power) % 2 == 1 and "1" or "0"
      end
  end

  local function reportCodeReadBits(bits, position, count)
      local value = 0
      for i = 0, count - 1 do
          value = value * 2
          if bits:sub(position + i, position + i) == "1" then
              value = value + 1
          end
      end
      return value, position + count
  end

  local function reportCodeBase32(bits)
      while #bits % 5 ~= 0 do bits = bits .. "0" end
      local alphabet = mod.exports.__beta26.Dev.reportCodeAlphabet
      local out = {}
      for i = 1, #bits, 5 do
          local value = 0
          for j = 0, 4 do
              value = value * 2
              if bits:sub(i + j, i + j) == "1" then value = value + 1 end
          end
          out[#out + 1] = alphabet:sub(value + 1, value + 1)
      end
      return table.concat(out)
  end

  local function reportCodeBitsFromBase32(payload)
      local alphabet = mod.exports.__beta26.Dev.reportCodeAlphabet
      payload = tostring(payload or ""):upper():gsub("[^0-9A-Z]", "")
      -- Friendly transcription aliases.
      payload = payload:gsub("O", "0"):gsub("[IL]", "1")
      local bits = {}
      for i = 1, #payload do
          local ch = payload:sub(i, i)
          local at = alphabet:find(ch, 1, true)
          if not at then return nil, "invalid_character:" .. ch end
          local value = at - 1
          for bit = 4, 0, -1 do
              bits[#bits + 1] =
                  math.floor(value / (2 ^ bit)) % 2 == 1 and "1" or "0"
          end
      end
      return table.concat(bits)
  end

  local REPORT_CODE_RESULT_IDS = {
      "dev_mode", "save_schema", "default_rule_audit",
      "encounter_slot_conflict", "shiny_clause",
      "tracker_death_projection", "species_facts",
      "mechanics_capability", "mom_heal_gate",
      "__generation__", "cap_messages_setting",
      "encounter_ball_limit_setting", "encounter_indicator_setting", "hook_health",
      "lifecycle_callbacks", "safe_stop_writes",
      "rule_effectiveness", "randomizer_integrity",
  }

  local REPORT_CODE_NZR6_PAYLOAD_CHARS = 33
  local REPORT_CODE_NZR6_MEANINGFUL_BITS = 164

  local REPORT_CODE_RANDOMIZER_STATUS = {
      INACTIVE=0, PASS=1, WARN=2, ERROR=3, DELEGATED=4,
      PAUSED=5, UNAVAILABLE=6, FALLBACK=7,
  }
  local REPORT_CODE_RANDOMIZER_LABEL = {
      [0]="INACTIVE", [1]="PASS", [2]="WARN", [3]="ERROR",
      [4]="DELEGATED", [5]="PAUSED", [6]="UNAVAILABLE", [7]="FALLBACK",
  }

  mod.exports.__beta26.Dev.reportCode = function(game, report, fullText)
      game = game or liveGame() or mod.game
      report = type(report) == "table"
          and report or mod.exports.__beta26.Dev.selfTest(game)

      local resultById = {}
      for _, row in ipairs(report.results or {}) do
          resultById[tostring(row.id or "")] = row.ok == true
      end
      local generationId = (report.generation == 2
          or report.game == "gold" or report.game == "silver"
          or report.game == "crystal") and "gold_rule_surface" or "rby_runtime"

      local bits = {}
      local major, minor, patch = tostring(report.build or "")
          :match("^(%d+)%.(%d+)%.(%d+)")
      major = tonumber(major) or 0
      minor = tonumber(minor) or 0
      patch = tonumber(patch) or 0
      reportCodePushBits(bits, major, 8)
      reportCodePushBits(bits, minor, 8)
      reportCodePushBits(bits, patch, 8)
      local editionId = ({ red=0, blue=1, yellow=2, gold=3,
          silver=4, crystal=5 })[tostring(report.game or ""):lower()] or 7
      reportCodePushBits(bits, editionId, 3)
      reportCodePushBits(bits,
          tonumber(mod.save:get(SAVE_SCHEMA_KEY, CURRENT_SAVE_SCHEMA))
              or CURRENT_SAVE_SCHEMA, 4)

      -- 2.5.53 / NZR5: the five health summaries below are already encoded
      -- later as authoritative counters/status. Do not encode a second copy;
      -- the decoder reconstructs those result flags from that evidence. This
      -- also avoids adding another top-level result-id table/local.
      for _, id in ipairs(REPORT_CODE_RESULT_IDS) do
          if id ~= "hook_health" and id ~= "lifecycle_callbacks"
              and id ~= "safe_stop_writes" and id ~= "rule_effectiveness"
              and id ~= "randomizer_integrity" then
              local ok = id == "__generation__"
                  and resultById[generationId] == true or resultById[id] == true
              reportCodePushBits(bits, ok and 1 or 0, 1)
          end
      end

      reportCodePushBits(bits, 1, 2) -- fixed cap-notice policy
      reportCodePushBits(bits, 0, 1) -- retired Encounter Indicator bit; layout preserved
      local effectiveness = report.rule_effectiveness or {}
      reportCodePushBits(bits,
          effectiveness.nuzlocke_enabled == true and 1 or 0, 1)

      local hc = (report.hook_health or {}).counts or {}
      reportCodePushBits(bits, hc.healthy, 4)
      reportCodePushBits(bits, hc.chained, 4)
      reportCodePushBits(bits, hc.pending, 4)
      reportCodePushBits(bits, hc.missing, 4)

      local lc = report.lifecycle or {}
      reportCodePushBits(bits, lc.duplicate_callbacks, 4)
      reportCodePushBits(bits,
          reportCodeClamp((tonumber(lc.battle_delta) or 0) + 15, 5), 5)

      local sw = report.safe_stop_writes or {}
      reportCodePushBits(bits, sw.total, 6)
      reportCodePushBits(bits, sw.active == true and 1 or 0, 1)

      local rc = effectiveness.counts or {}
      reportCodePushBits(bits, rc.total, 7)
      reportCodePushBits(bits, rc.delegated, 6)
      reportCodePushBits(bits, rc.changed, 6)
      reportCodePushBits(bits, rc.errors, 4)

      local ri = report.randomizer_integrity or {}
      reportCodePushBits(bits,
          REPORT_CODE_RANDOMIZER_STATUS[tostring(ri.status or "INACTIVE")]
              or 0, 3)
      reportCodePushBits(bits, ri.active == true and 1 or 0, 1)
      reportCodePushBits(bits, ri.delegated == true and 1 or 0, 1)
      reportCodePushBits(bits, ri.scanned, 10)
      reportCodePushBits(bits, ri.violation_count, 8)
      reportCodePushBits(bits, ri.truncated == true and 1 or 0, 1)

      local assertions = report.assertions or {}
      reportCodePushBits(bits, #assertions, 5)
      local assertionText = {}
      for _, row in ipairs(assertions) do
          assertionText[#assertionText + 1] =
              tostring(row.code or "") .. "=" .. tostring(row.detail or "")
      end
      table.sort(assertionText)
      reportCodePushBits(bits,
          reportCodeHash(table.concat(assertionText, "|"), 12), 12)

      -- Bind arbitrary owners, rule rows, hook detail, breadcrumbs, etc. to the
      -- compact code without claiming those free-form strings are reversible.
      -- fullText is the report body before the report_code line is inserted;
      -- excluding that generated line avoids a circular fingerprint.
      reportCodePushBits(bits,
          reportCodeHash(tostring(fullText or ""), 20), 20)

      local payload = reportCodeBase32(table.concat(bits))
      local groups = {}
      for i = 1, #payload, 4 do
          groups[#groups + 1] = payload:sub(i, i + 3)
      end
      return "NZR6-" .. table.concat(groups, "-")
  end

  mod.exports.__beta26.Dev.decodeReportCode = function(code)
      local raw = tostring(code or ""):upper():gsub("%s+", "")
      local format = tonumber(raw:match("^NZR(%d+)%-"))
      if format ~= 4 and format ~= 5 and format ~= 6 then
          return nil, "unsupported_report_code"
      end
      local payload = raw:sub(6):gsub("[^0-9A-Z]", "")
      if format == 6 and #payload ~= REPORT_CODE_NZR6_PAYLOAD_CHARS then
          return nil, "invalid_payload_length"
      end
      local bits, err = reportCodeBitsFromBase32(payload)
      if not bits then return nil, err end
      if format == 6 then
          if #bits ~= REPORT_CODE_NZR6_PAYLOAD_CHARS * 5 then
              return nil, "invalid_payload_bits"
          end
          if bits:sub(REPORT_CODE_NZR6_MEANINGFUL_BITS + 1) ~= "0" then
              return nil, "invalid_padding"
          end
      end
      local pos = 1
      local out = { format=format, raw=raw }
      out.major, pos = reportCodeReadBits(bits, pos, 8)
      out.minor, pos = reportCodeReadBits(bits, pos, 8)
      out.patch, pos = reportCodeReadBits(bits, pos, 8)
      if format >= 6 then
          local edition
          edition, pos = reportCodeReadBits(bits, pos, 3)
          out.game = ({ [0]="red", [1]="blue", [2]="yellow", [3]="gold",
              [4]="silver", [5]="crystal", [7]="unknown" })[edition] or "unknown"
          out.generation = (edition == 3 or edition == 4 or edition == 5) and 2 or 1
      else
          local gold
          gold, pos = reportCodeReadBits(bits, pos, 1)
          out.game = gold == 1 and "gold" or "rby"
          out.generation = gold == 1 and 2 or 1
      end
      out.save_schema, pos = reportCodeReadBits(bits, pos, 4)
      out.results = {}
      for _, id in ipairs(REPORT_CODE_RESULT_IDS) do
          local derived = id == "hook_health" or id == "lifecycle_callbacks"
              or id == "safe_stop_writes" or id == "rule_effectiveness"
              or id == "randomizer_integrity"
          if format == 4 or not derived then
              local value
              value, pos = reportCodeReadBits(bits, pos, 1)
              out.results[id] = value == 1
          end
      end
      out.cap_messages, pos = reportCodeReadBits(bits, pos, 2)
      local value
      value, pos = reportCodeReadBits(bits, pos, 1)
      out.encounter_indicator = value == 1
      value, pos = reportCodeReadBits(bits, pos, 1)
      out.nuzlocke_enabled = value == 1

      out.hooks = {}
      out.hooks.healthy, pos = reportCodeReadBits(bits, pos, 4)
      out.hooks.chained, pos = reportCodeReadBits(bits, pos, 4)
      out.hooks.pending, pos = reportCodeReadBits(bits, pos, 4)
      out.hooks.missing, pos = reportCodeReadBits(bits, pos, 4)

      out.lifecycle = {}
      out.lifecycle.duplicate_callbacks, pos =
          reportCodeReadBits(bits, pos, 4)
      value, pos = reportCodeReadBits(bits, pos, 5)
      out.lifecycle.battle_delta = value - 15

      out.safe_stop = {}
      out.safe_stop.attempts, pos = reportCodeReadBits(bits, pos, 6)
      value, pos = reportCodeReadBits(bits, pos, 1)
      out.safe_stop.active = value == 1

      out.rules = {}
      out.rules.total, pos = reportCodeReadBits(bits, pos, 7)
      out.rules.delegated, pos = reportCodeReadBits(bits, pos, 6)
      out.rules.changed, pos = reportCodeReadBits(bits, pos, 6)
      out.rules.errors, pos = reportCodeReadBits(bits, pos, 4)

      out.randomizer = {}
      value, pos = reportCodeReadBits(bits, pos, 3)
      out.randomizer.status = REPORT_CODE_RANDOMIZER_LABEL[value] or "INACTIVE"
      value, pos = reportCodeReadBits(bits, pos, 1)
      out.randomizer.active = value == 1
      value, pos = reportCodeReadBits(bits, pos, 1)
      out.randomizer.delegated = value == 1
      out.randomizer.scanned, pos = reportCodeReadBits(bits, pos, 10)
      out.randomizer.violations, pos = reportCodeReadBits(bits, pos, 8)
      value, pos = reportCodeReadBits(bits, pos, 1)
      out.randomizer.truncated = value == 1

      out.assertion_count, pos = reportCodeReadBits(bits, pos, 5)
      out.assertion_fingerprint, pos = reportCodeReadBits(bits, pos, 12)
      out.full_report_fingerprint, pos = reportCodeReadBits(bits, pos, 20)
      out.build = tostring(out.major) .. "." .. tostring(out.minor)
          .. "." .. tostring(out.patch)

      -- NZR5 stores each health fact once. Rebuild the five player-facing
      -- result flags from the authoritative compact evidence. NZR4 remains
      -- decodable and retains its contradiction detector for old reports.
      local derived = {
          hook_health = tonumber(out.hooks.missing or 0) == 0,
          lifecycle_callbacks =
              tonumber(out.lifecycle.duplicate_callbacks or 0) == 0,
          safe_stop_writes = tonumber(out.safe_stop.attempts or 0) == 0,
          rule_effectiveness = tonumber(out.rules.errors or 0) == 0,
          randomizer_integrity = out.randomizer.status ~= "WARN"
              and out.randomizer.status ~= "ERROR",
      }
      out.consistency = {}
      out.consistent = true
      for id, ok in pairs(derived) do
          if format >= 5 then
              out.results[id] = ok
              out.consistency[id] = true
          else
              local consistent = out.results[id] == ok
              out.consistency[id] = consistent
              if not consistent then out.consistent = false end
          end
      end
      return out
  end

  -- 2.5.61: compact deterministic code for unexpected runtime failures that
  -- are caught before they can escape a mod-owned screen. This fingerprint is
  -- intentionally short; Dev Mode still records the full traceback.
  mod.exports.__beta26.Dev.errorCode = function(label, err)
      local fingerprint = reportCodeHash(
          tostring(mod.exports.__beta26.build) .. "|"
              .. tostring(label or "runtime") .. "|" .. tostring(err or ""), 20)
      return string.format("NZERR-%s-%05X",
          tostring(mod.exports.__beta26.build), fingerprint)
  end
  -- selfTestText lives outside this compiler-budget scope, so expose
  -- the deterministic fingerprint operation rather than accidentally resolving
  -- the scoped helper name as a nonexistent global.
  mod.exports.__beta26.Dev.reportFingerprint = function(text, bits)
      return reportCodeHash(text, bits)
  end
  end -- NZR6 codec helper scope

  mod.exports.__beta26.Dev.selfTestText = function(game)
      local report = mod.exports.__beta26.Dev.selfTest(game)
      local function semanticLabel(value)
          return tostring(value or "?"):gsub("[._]", " "):upper()
      end
      local lines = {
          "NUZLOCKE DEV SELF-TEST",
          "build=" .. tostring(report.build),
          "game=" .. tostring(report.game),
          "generation=" .. tostring(report.generation or
              (mod.exports.__beta26.runtimeIsGen2(game) and 2 or 1)),
          "engine_family=" .. tostring((mod.exports.__beta26.Dev.editionContext(game)).engine_family),
          "profile_scope=" .. tostring((mod.exports.__beta26.Dev.editionContext(game)).profile_scope),
          "environment=" .. tostring(report.environment),
          "engine_developer=" .. tostring(report.engine_developer == true),
          "save_schema=" .. tostring(mod.save:get(
              SAVE_SCHEMA_KEY, CURRENT_SAVE_SCHEMA)),
          "randomizer_seed_mode=" .. tostring(
              type(mod.exports.__beta26.randomizerSeedMode) == "function"
                  and mod.exports.__beta26.randomizerSeedMode(nil) or "UNKNOWN"),
          "randomizer_run_seed=" .. string.format("%08d", math.max(0,
              math.floor(tonumber(type(mod.exports.__beta26.randomizerSeed) == "function"
                  and mod.exports.__beta26.randomizerSeed(nil, false) or 0) or 0))),
          "randomizer_run_snapshot=" .. tostring(
              type(mod.exports.__beta26.randomizerRunConfig) == "function"
                  and mod.exports.__beta26.randomizerRunConfig() ~= nil),
          "randomizer_streams=" .. tostring(
              type(mod.exports.__beta26.randomizerStreamNames) == "function"
                  and #mod.exports.__beta26.randomizerStreamNames() or 0),
          "randomizer_starter_slate_version=" .. tostring(
              type(mod.exports.__beta26.randomizerStarterInfo) == "function"
                  and (mod.exports.__beta26.randomizerStarterInfo(nil, false).starterSlateVersion or 0) or 0),
          "randomizer_starter_reroll_index=" .. tostring(
              type(mod.exports.__beta26.randomizerStarterRerollIndex) == "function"
                  and mod.exports.__beta26.randomizerStarterRerollIndex() or 0),
          "randomizer_starter_reroll_locked=" .. tostring(
              type(mod.exports.__beta26.randomizerStarterInfo) == "function"
                  and mod.exports.__beta26.randomizerStarterInfo(nil, false).rerollLocked == true),
          "randomizer_external_owners=" .. (function()
              if type(mod.exports.__beta26.randomizerCompatibilitySnapshot)
                  ~= "function" then return "unavailable" end
              local ok, snapshot = pcall(
                  mod.exports.__beta26.randomizerCompatibilitySnapshot, mod.game)
              if not ok or type(snapshot) ~= "table"
                  or type(snapshot.rows) ~= "table" then return "error" end
              local out = {}
              for _, row in ipairs(snapshot.rows) do
                  out[#out + 1] = tostring(row.mechanic or "?") .. ":"
                      .. tostring(row.delegated and (row.owner_id or "external")
                          or "nuzlocke")
              end
              return table.concat(out, ",")
          end)(),
          "stadium_compat=" .. (function()
              local api = mod.exports.nuzlocke_acquisition_provenance
              if type(api) ~= "table" or type(api.compatibilitySnapshot)
                  ~= "function" then return "unavailable" end
              local ok, snapshot = pcall(api.compatibilitySnapshot, mod.game)
              if not ok or type(snapshot) ~= "table"
                  or type(snapshot.rows) ~= "table" then return "error" end
              local out = { "edition:" .. tostring(snapshot.edition or "unknown") }
              for _, row in ipairs(snapshot.rows) do
                  out[#out + 1] = tostring(row.kind or row.id or "stadium")
                      .. ":" .. tostring(row.origin or "presentation")
              end
              if #snapshot.rows == 0 then out[#out + 1] = "none" end
              return table.concat(out, ",")
          end)(),
          "compat_api=" .. tostring(mod.exports.__beta26.compatibilityApi),
          "audited_recomp="
              .. tostring(mod.exports.__beta26.recompCompatAudited),
      }
      local contract = mod.exports.__beta26.publicApiContract
      if type(contract) == "table" then
          lines[#lines + 1] = "api_owner=" .. tostring(contract.owner or "?")
          lines[#lines + 1] = "api_stability=" .. tostring(contract.stability or "?")
          local surfaceCount = 0
          for _ in pairs(type(contract.surfaces) == "table" and contract.surfaces or {}) do
              surfaceCount = surfaceCount + 1
          end
          lines[#lines + 1] = "api_surfaces=" .. tostring(surfaceCount)
      end
      local compat = mod.exports.nuzlocke_compat
      if type(compat) == "table" and type(compat.providerCount) == "function" then
          local okProviders, count = pcall(compat.providerCount)
          if okProviders then lines[#lines + 1] = "providers=" .. tostring(count) end
      end
      local provenance = report.build_provenance
          or mod.exports.__beta26.buildProvenance()
      if type(provenance) == "table" then
          lines[#lines + 1] = "parent_build="
              .. tostring(provenance.parent_version or "?")
      end

      local storageContext =
          mod.exports.__beta26.Dev.storageContext(game)
      if type(storageContext) == "table" then
          lines[#lines + 1] = "storage_game="
              .. tostring(storageContext.gameVersion or "?")
          lines[#lines + 1] = "storage_playthrough="
              .. tostring(storageContext.playthroughId or "?")
      else
          lines[#lines + 1] = "storage_context=unavailable"
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[RESULTS]"
      local pass, warn = 0, 0
      for _, row in ipairs(report.results or {}) do
          if row.ok then pass = pass + 1 else warn = warn + 1 end
          lines[#lines + 1] = string.format(
              "%s %-26s [%s] %s",
              row.status, semanticLabel(row.id), semanticLabel(row.kind), row.detail)
      end
      lines[#lines + 1] = string.format(
          "SUMMARY pass=%d warn=%d", pass, warn)

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[ASSERTIONS]"
      if #(report.assertions or {}) == 0 then
          lines[#lines + 1] = "PASS none"
      else
          for _, row in ipairs(report.assertions or {}) do
              lines[#lines + 1] = "WARN " .. semanticLabel(row.code)
                  .. " " .. tostring(row.detail or "")
          end
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[CAPABILITIES]"
      for _, row in ipairs(report.capabilities or {}) do
          lines[#lines + 1] = row
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[RULE EFFECTIVENESS]"
      local ruleEffectiveness = report.rule_effectiveness or {}
      local ruleCounts = ruleEffectiveness.counts or {}
      lines[#lines + 1] = string.format(
          "master=%s schema_supported=%s rules=%d delegated=%d changed=%d errors=%d",
          tostring(ruleEffectiveness.nuzlocke_enabled == true),
          tostring(ruleEffectiveness.schema_supported == true),
          tonumber(ruleCounts.total or 0),
          tonumber(ruleCounts.delegated or 0),
          tonumber(ruleCounts.changed or 0),
          tonumber(ruleCounts.errors or 0))
      for _, row in ipairs(ruleEffectiveness.rows or {}) do
          lines[#lines + 1] = string.format(
              "%-28s configured=%s(%s) effective=%s owner=%s relationship=%s%s",
              tostring(row.key or "?"),
              tostring(row.configured),
              tostring(row.configured_source or "?"),
              tostring(row.effective),
              tostring(row.owner or "nuzlocke"),
              tostring(row.relationship or "owned"),
              row.error and (" error=" .. tostring(row.error)) or "")
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[RANDOMIZER INTEGRITY]"
      local randomizerIntegrity = report.randomizer_integrity or {}
      lines[#lines + 1] = string.format(
          "status=%s active=%s delegated=%s scanned=%d violations=%d truncated=%s",
          tostring(randomizerIntegrity.status or "?"),
          tostring(randomizerIntegrity.active == true),
          tostring(randomizerIntegrity.delegated == true),
          tonumber(randomizerIntegrity.scanned or 0),
          tonumber(randomizerIntegrity.violation_count or 0),
          tostring(randomizerIntegrity.truncated == true))
      if randomizerIntegrity.owner then
          lines[#lines + 1] = "owner=" .. tostring(randomizerIntegrity.owner)
              .. " relationship="
              .. tostring(randomizerIntegrity.relationship or "delegated")
      end
      if randomizerIntegrity.detail then
          lines[#lines + 1] = "detail=" .. tostring(randomizerIntegrity.detail)
      end
      for _, row in ipairs(randomizerIntegrity.violations or {}) do
          lines[#lines + 1] = string.format(
              "WARN %s species=%s reason=%s",
              tostring(row.path or "?"),
              tostring(row.species or "?"),
              tostring(row.reason or "?"))
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[HOOK HEALTH]"
      local hookHealth = report.hook_health or {}
      local hookCounts = hookHealth.counts or {}
      lines[#lines + 1] = string.format(
          "SUMMARY healthy=%d chained=%d pending=%d missing=%d",
          tonumber(hookCounts.healthy or 0),
          tonumber(hookCounts.chained or 0),
          tonumber(hookCounts.pending or 0),
          tonumber(hookCounts.missing or 0))
      lines[#lines + 1] = string.format(
          "IDENTITY edition=%s family=%s profile=%s",
          tostring(hookHealth.edition or report.game or "?"),
          tostring(hookHealth.engine_family or report.engine_family or "?"),
          tostring(hookHealth.profile_scope or report.profile_scope or "?"))
      for _, row in ipairs(hookHealth.rows or {}) do
          lines[#lines + 1] = string.format(
              "%-8s %-26s %s.%s %s",
              tostring(row.state or "?"),
              semanticLabel(row.adapter_id or row.id),
              tostring(row.path or "?"),
              tostring(row.method or "?"),
              tostring(row.detail or ""))
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[FEATURE HEALTH]"
      local featureHealth = report.feature_health or {}
      local featureKeys = {}
      for key in pairs(featureHealth) do featureKeys[#featureKeys + 1] = key end
      table.sort(featureKeys)
      if #featureKeys == 0 then lines[#lines + 1] = "no feature-health transitions recorded" end
      for _, key in ipairs(featureKeys) do
          local row = featureHealth[key] or {}
          lines[#lines + 1] = string.format("%-12s %s%s",
              tostring(row.state or "?"), semanticLabel(key),
              row.reason and (" reason=" .. tostring(row.reason)) or "")
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[GAMEPLAY TRANSACTIONS]"
      local tx = report.gameplay_transactions or {}
      lines[#lines + 1] = string.format("api=%s handlers=%s receipts=%s pending=%s",
          tostring(tx.api or "?"), tostring(tx.handler_count or 0),
          tostring(tx.receipt_count or 0), tostring(type(tx.pending) == "table"))
      if type(tx.pending) == "table" then
          lines[#lines + 1] = string.format("PENDING id=%s kind=%s state=%s",
              tostring(tx.pending.id or "?"), tostring(tx.pending.kind or "?"),
              tostring(tx.pending.state or "?"))
      end

      local gen2Parity = report.gen2_parity
      if type(gen2Parity) == "table" and gen2Parity.applies == true then
          lines[#lines + 1] = ""
          lines[#lines + 1] = "[GEN 2 EDITION PARITY]"
          lines[#lines + 1] = string.format(
              "status=%s edition=%s family=%s profile=%s hooks=%d dex=%d failures=%d",
              gen2Parity.ok == true and "PASS" or "WARN",
              tostring(gen2Parity.edition or "?"),
              tostring(gen2Parity.engine_family or "?"),
              tostring(gen2Parity.profile_scope or "?"),
              tonumber(gen2Parity.checked_rows or 0),
              tonumber(gen2Parity.species_ban_rows or 0),
              #(gen2Parity.failures or {}))
          for _, failure in ipairs(gen2Parity.failures or {}) do
              lines[#lines + 1] = "WARN " .. tostring(failure)
          end
          local reach = gen2Parity.adapter_reach
          if type(reach) == "table" then
              for _, key in ipairs({ "script_command_adapter", "givepoke",
                  "elm_starter_recognition", "starter_registration",
                  "party_native_submenu", "party_shared_row_present",
                  "party_fallback_inserted", "tracker_map_render" }) do
                  lines[#lines + 1] = string.format("reach %-24s %d",
                      semanticLabel(key), tonumber(reach.counts and reach.counts[key] or 0))
              end
              local tracker = reach.last and reach.last.tracker_map_render
              if type(tracker) == "table" then
                  lines[#lines + 1] = string.format(
                      "tracker count=%d pallet=%s",
                      tonumber(tracker.count or 0),
                      tracker.pallet_visible == true and "YES" or "NO")
              end
          end
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[LIFECYCLE]"
      local lifecycle = report.lifecycle or {}
      lines[#lines + 1] = string.format(
          "duplicate_callbacks=%d battle_delta=%d",
          tonumber(lifecycle.duplicate_callbacks or 0),
          tonumber(lifecycle.battle_delta or 0))
      for _, key in ipairs({
          "game.ready", "save.loaded", "battle.started", "battle.ended",
          "pokemon.caught", "pokemon.evolved",
      }) do
          lines[#lines + 1] = string.format(
              "%-18s count=%d duplicates=%d",
              key,
              tonumber((lifecycle.counts or {})[key]) or 0,
              tonumber((lifecycle.duplicate_by_event or {})[key]) or 0)
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[SAFE STOP WRITES]"
      local safeStopWrites = report.safe_stop_writes or {}
      lines[#lines + 1] = string.format(
          "active=%s attempts=%d first=%s last=%s",
          tostring(safeStopWrites.active == true),
          tonumber(safeStopWrites.total or 0),
          tostring(safeStopWrites.first_key or "none"),
          tostring(safeStopWrites.last_key or "none"))
      local safeKeys = {}
      for key in pairs(safeStopWrites.by_key or {}) do
          safeKeys[#safeKeys + 1] = tostring(key)
      end
      table.sort(safeKeys)
      for _, key in ipairs(safeKeys) do
          lines[#lines + 1] = string.format(
              "%s=%d", key,
              tonumber((safeStopWrites.by_key or {})[key]) or 0)
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[SYSTEM HEALTH]"
      local health = mod.exports.__beta26.Dev.systemHealth(game)
      lines[#lines + 1] = "status=" .. tostring(health.status or "?")
      for _, key in ipairs({ "ENGINE", "SAVE", "IDENTITY", "RULES", "ENCOUNTER",
          "BATTLE", "RANDOMIZER", "LOCALIZATION", "PROVIDERS", "OWNERSHIP", "SHINY", "UI",
          "HOOKS", "PERFORMANCE", "TRANSACTIONS" }) do
          local row = health.rows and health.rows[key] or {}
          lines[#lines + 1] = string.format("%-12s %-9s %s", key,
              tostring(row.status or "N/A"), tostring(row.reason or ""))
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[LOCALIZATION]"
      local localization = health.localization or
          mod.exports.__beta26.Dev.localizationDiagnostics(game)
      lines[#lines + 1] = string.format(
          "status=%s installed=%d active=%d restart=%d sources=%d fallback=%d resolved=%d",
          tostring(localization.status or "N/A"),
          tonumber(localization.installed or 0), tonumber(localization.active or 0),
          tonumber(localization.restart_required or 0),
          tonumber(localization.source_count or 0),
          tonumber(localization.fallback_count or 0),
          tonumber(localization.resolved_count or 0))
      for _, row in ipairs(localization.companions or {}) do
          lines[#lines + 1] = string.format(
              "%s %s activity=%s boot=%s pending=%s edition=%s restart=%s",
              tostring(row.id or "?"), tostring(row.version or "?"),
              tostring(row.activity or "?"), tostring(row.bootLanguage or "?"),
              tostring(row.pendingLanguage or "-"), tostring(row.edition or "?"),
              tostring(row.restartRequired == true))
          if row.mutationReviewRequired == true then
              local scriptState = row.replacementMapScripts == true and "ACTIVE/KNOWN"
                  or (row.replacementMapScriptsPresent == true and "PRESENT/LOAD UNCONFIRMED"
                      or "REVIEW REQUIRED")
              lines[#lines + 1] =
                  "  REPLACEMENT SCRIPT MUTATION REVIEW REQUIRED: " .. scriptState
          end
          if row.engineInternalsPresentationWrappers == true then
              lines[#lines + 1] =
                  "  PRESENTATION WRAPPERS: ENGINE INTERNALS / COMPOSITION REVIEW"
          end
          if row.fixedCellCJK == true then
              lines[#lines + 1] = "  TEXT MODEL: FIXED-CELL CJK"
          end
          if type(row.certificationFocus) == "table"
              and #row.certificationFocus > 0 then
              lines[#lines + 1] = "  LOCAL CERT FOCUS: "
                  .. table.concat(row.certificationFocus, "; ")
          end
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[LOCALIZATION CERTIFICATION]"
      local cert = mod.exports.__beta26.Dev.localizationCertification(game)
      lines[#lines + 1] = tostring(cert.summary)
      lines[#lines + 1] = "session_only=true certified="
          .. tostring(cert.certified == true)
      for _, row in ipairs(cert.checks or {}) do
          lines[#lines + 1] = string.format("%02d %-8s %s",
              tonumber(row.index or 0), tostring(row.state or "UNTESTED"),
              tostring(row.label or row.id or "?"))
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[PROVIDER OWNERSHIP]"
      local ownership = health.provider_ownership or {}
      lines[#lines + 1] = string.format("providers=%d capabilities=%d selected=%d degraded=%d",
          tonumber(ownership.provider_count or 0),
          tonumber(ownership.capability_count or 0),
          tonumber(ownership.selected or 0), tonumber(ownership.degraded or 0))
      for _, row in ipairs(ownership.capabilities or {}) do
          lines[#lines + 1] = string.format("%s state=%s owner=%s kind=%s",
              tostring(row.capability or "?"), tostring(row.state or "?"),
              tostring(row.selected_owner or "nuzlocke"),
              tostring(row.selected_kind or "fallback"))
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[ENCOUNTER PROVENANCE]"
      local enc = health.encounter or {}
      if enc.active ~= true then
          lines[#lines + 1] = "active=false state=" .. tostring(enc.state or "none")
      else
          for _, pair in ipairs({
              {"state",enc.state},{"area",enc.area},{"physical",enc.physical_area},
              {"species",enc.species},{"pokemon_id",enc.pokemon_id},
              {"type",enc.encounter_type},{"method",enc.encounter_method},
              {"time",enc.encounter_time},{"source",enc.source},
              {"provider",enc.provider},{"provider_version",enc.provider_version},
              {"eligible",enc.eligible},{"will_spend",enc.will_spend},
              {"free_reason",enc.free_reason},{"clause",enc.clause_conflict},
              {"area_status",enc.area_status},{"shiny",enc.shiny},
          }) do
              if pair[2] ~= nil then
                  lines[#lines + 1] = tostring(pair[1]) .. "=" .. tostring(pair[2])
              end
          end
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[RULE DECISIONS]"
      local decisions = mod.exports.__beta26.Dev.decisionTrace
          and mod.exports.__beta26.Dev.decisionTrace(12) or {}
      if #decisions == 0 then lines[#lines + 1] = "(none)" end
      for _, row in ipairs(decisions) do
          lines[#lines + 1] = string.format("#%s %s/%s %s %s",
              tostring(row.seq or "?"), tostring(row.domain or "rule"),
              tostring(row.rule or "?"), tostring(row.result or "INFO"),
              tostring(row.detail or ""))
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] = "[RECENT BREADCRUMBS]"
      local crumbs = mod.exports.__beta26.Dev.breadcrumbs or {}
      local first = 1
      if #crumbs == 0 then
          lines[#lines + 1] = "(none)"
      else
          for i = first, #crumbs do
              local row = crumbs[i]
              lines[#lines + 1] = string.format(
                  "#%s %s/%s %s",
                  tostring(row.seq or "?"),
                  tostring(row.game or "?"),
                  tostring(row.kind or "?"),
                  tostring(row.detail or ""))
          end
      end

      lines[#lines + 1] = ""
      lines[#lines + 1] =
          "NOTE: SELF-TEST PASS is diagnostic evidence, not a full RUNTIME PASS."

      -- 2.7.82: report-code/fingerprint helpers remain internal compatibility
      -- capabilities, but player-visible/exported self-test text is semantic.
      -- Package/document Release Safety is likewise build-time only.
      return table.concat(lines, "\n"), report
  end

  mod.exports.__beta26.Dev.exportSelfTest = function(game)
      if not mod.exports.__beta26.Dev.enabled() then
          return false, { error = "DEV MODE OFF" }
      end

      game = game or liveGame() or mod.game
      local text, report = mod.exports.__beta26.Dev.selfTestText(game)
      local storageKey = "dev/self_test_latest"
      local storage = mod and mod.storage
      local writeAttempted, writeReturned = false, false
      local verified, readBackMatches = false, false
      local bytesRead, storageCode, storageMessage
      local historyKey, historyWritten, historyCount
      local storageContext =
          mod.exports.__beta26.Dev.storageContext(game)

      if type(storage) == "table"
          and type(storage.writeBytes) == "function" then
          writeAttempted = true
          local ok, result, code, message = pcall(
              storage.writeBytes, storage, game, storageKey, text)
          if ok then
              writeReturned = result == true
              storageCode = code
              storageMessage = message
          else
              storageCode = "storage_error"
              storageMessage = tostring(result)
          end
      else
          storageCode = "storage_unavailable"
          storageMessage = "Gen1Recomp mod.storage.writeBytes is unavailable."
      end

      if writeReturned and type(storage.readBytes) == "function" then
          local ok, result, code, message = pcall(
              storage.readBytes, storage, game, storageKey)
          if ok and type(result) == "string" then
              bytesRead = #result
              readBackMatches = result == text
          else
              storageCode = code or storageCode
              storageMessage = message or (not ok and tostring(result))
                  or storageMessage
          end
      end

      verified = writeReturned and readBackMatches == true

      -- Keep latest for convenience plus bounded sequenced history.
      if verified and type(storage.list) == "function"
          and type(storage.delete) == "function" then
          local okList, keys = pcall(storage.list, storage, game, "dev")
          if okList and type(keys) == "table" then
              local numbered = {}
              local maxIndex = 0
              for _, key in ipairs(keys) do
                  local n = tostring(key):match("^dev/self_test_history_(%d+)$")
                  if n then
                      n = tonumber(n)
                      if n then
                          maxIndex = math.max(maxIndex, n)
                          numbered[#numbered + 1] = {
                              key = tostring(key), index = n,
                          }
                      end
                  end
              end

              local nextIndex = maxIndex + 1
              historyKey = string.format(
                  "dev/self_test_history_%06d", nextIndex)
              local okHistory, result = pcall(
                  storage.writeBytes, storage, game, historyKey, text)
              historyWritten = okHistory and result == true

              if historyWritten then
                  numbered[#numbered + 1] = {
                      key = historyKey, index = nextIndex,
                  }
                  table.sort(numbered, function(a, b)
                      return a.index < b.index
                  end)
                  while #numbered > 16 do
                      local oldest = table.remove(numbered, 1)
                      pcall(storage.delete, storage, game, oldest.key)
                  end
                  historyCount = #numbered
              else
                  historyCount = #numbered
              end
          end
      end

      mod.exports.__beta26.Dev.lastExportText = text
      mod.exports.__beta26.Dev.lastExportReport = report
      mod.exports.__beta26.Dev.lastExport = {
          clipboard = false,
          filename = nil,
          saveDirectory = nil,
          absolutePath = nil,
          info = nil,
          writeAttempted = writeAttempted,
          writeReturned = writeReturned,
          written = verified,
          verified = verified,
          readSucceeded = bytesRead ~= nil,
          readBackMatches = readBackMatches,
          storageKey = storageKey,
          historyKey = historyKey,
          historyWritten = historyWritten == true,
          historyCount = historyCount,
          storageContext = storageContext,
          storageCode = storageCode,
          storageMessage = storageMessage,
          bytesRead = bytesRead,
          expectedBytes = #text,
          breadcrumbCount = #(mod.exports.__beta26.Dev.breadcrumbs or {}),
          primary = verified and "storage" or "log",
      }

      pcall(function()
          mod.log:info(
              "[Nuzlocke:Dev] SELF-TEST EXPORT BEGIN\n%s\n[Nuzlocke:Dev] SELF-TEST EXPORT END",
              text)
      end)
      mod.exports.__beta26.Dev.push("self_test",
          string.format(
              "storageKey=%s history=%s verified=%s bytes=%s/%s code=%s",
              storageKey, tostring(historyKey or "none"),
              tostring(verified), tostring(bytesRead or "?"),
              tostring(#text), tostring(storageCode or "ok")), game)

      return true, {
          clipboard = false,
          filename = nil,
          saveDirectory = nil,
          absolutePath = nil,
          info = nil,
          writeAttempted = writeAttempted,
          writeReturned = writeReturned,
          written = verified,
          verified = verified,
          readSucceeded = bytesRead ~= nil,
          readBackMatches = readBackMatches,
          storageKey = storageKey,
          historyKey = historyKey,
          historyWritten = historyWritten == true,
          historyCount = historyCount,
          storageContext = storageContext,
          storageCode = storageCode,
          storageMessage = storageMessage,
          bytesRead = bytesRead,
          expectedBytes = #text,
          breadcrumbCount = #(mod.exports.__beta26.Dev.breadcrumbs or {}),
          text = text,
          report = report,
      }
  end

  -- 2.7.82: Dev Tools RUN remains fail-safe, but player-facing failures use
  -- readable semantic text rather than generated NZERR identifiers. The full
  -- traceback remains available to internal Dev diagnostics/logging.
  do
      local rawExportSelfTest = mod.exports.__beta26.Dev.exportSelfTest
      mod.exports.__beta26.Dev.exportSelfTest = function(game)
          local ok, result, info = xpcall(function()
              return rawExportSelfTest(game)
          end, debug and debug.traceback or tostring)
          if ok then return result, info end
          pcall(mod.exports.__beta26.Dev.recordError,
              "dev_run", result, game or liveGame() or mod.game)
          return false, {
              error = "DEV SELF-TEST ERROR",
              message = tostring(result),
          }
      end
  end

  mod.exports.__beta26.Dev.reloadStoredSelfTest = function(game, requestedKey)
      game = game or liveGame() or mod.game
      local storageKey = type(requestedKey) == "string"
          and requestedKey ~= "" and requestedKey or "dev/self_test_latest"
      local storage = mod and mod.storage
      if type(storage) ~= "table"
          or type(storage.readBytes) ~= "function" then
          return false, {
              error = "STORAGE UNAVAILABLE",
              storageKey = storageKey,
          }
      end

      local ok, text, code, message = pcall(
          storage.readBytes, storage, game, storageKey)
      if not ok or type(text) ~= "string" then
          return false, {
              error = tostring((not ok and text) or code or "NOT FOUND"),
              message = tostring(message or ""),
              storageKey = storageKey,
          }
      end

      mod.exports.__beta26.Dev.lastExportText = text
      local previous = mod.exports.__beta26.Dev.lastExport or {}
      previous.storageKey = storageKey
      previous.storageContext =
          mod.exports.__beta26.Dev.storageContext(game)
      previous.bytesRead = #text
      previous.readSucceeded = true
      previous.readBackMatches = nil
      mod.exports.__beta26.Dev.lastExport = previous
      mod.exports.__beta26.Dev.push("self_test_reload",
          "storageKey=" .. storageKey .. " bytes=" .. tostring(#text), game)
      return true, {
          text = text,
          storageKey = storageKey,
          storageContext = previous.storageContext,
          bytesRead = #text,
          readSucceeded = true,
          readBackMatches = nil,
      }
  end

  mod.exports.nuzlocke_dev = {
      api = mod.exports.__beta26.diagnosticsApi,
      build = mod.exports.__beta26.build,
      enabled = mod.exports.__beta26.Dev.enabled,
      breadcrumb = mod.exports.__beta26.Dev.push,
      breadcrumbs = function()
          local out = {}
          for i, row in ipairs(mod.exports.__beta26.Dev.breadcrumbs or {}) do
              out[i] = {
                  seq = row.seq, lastSeq = row.lastSeq, count = row.count,
                  severity = row.severity,
                  kind = row.kind, detail = row.detail,
                  build = row.build, game = row.game,
              }
          end
          return out
      end,
      assertions = mod.exports.__beta26.Dev.assertions,
      snapshot = mod.exports.__beta26.Dev.snapshot,
      hook_health = mod.exports.__beta26.Dev.hookHealth,
      hook_registry = mod.exports.__beta26.hookRegistry.describe,
      feature_health = mod.exports.__beta26.featureHealth.status,
      gameplay_transactions = mod.exports.__beta26.GameplayTransactions.status,
      transaction_health = mod.exports.__beta26.Dev.transactionHealth,
      hook_wrapper_drift = mod.exports.__beta26.Dev.hookWrapperDrift,
      randomizer_reproducibility = mod.exports.__beta26.Dev.randomizerReproducibility,
      shiny_diagnostics = mod.exports.__beta26.Dev.shinyDiagnostics,
      performance_counters = mod.exports.__beta26.Dev.performanceCounters,
      rule_configuration_consistency =
          mod.exports.__beta26.Dev.ruleConfigurationConsistency,
      save_run_identity_health = mod.exports.__beta26.Dev.saveRunIdentityHealth,
      ownership_history = mod.exports.__beta26.Dev.ownershipHistory,
      gen2_edition_parity = mod.exports.__beta26.Dev.gen2EditionParityAudit,
      gen2_description_parity = mod.exports.__beta26.gen2DescriptionParityAudit,
      rule_effectiveness = mod.exports.__beta26.Dev.ruleEffectiveness,
      randomizer_integrity = mod.exports.__beta26.Dev.randomizerIntegrity,
      system_health = mod.exports.__beta26.Dev.systemHealth,
      provider_ownership = mod.exports.__beta26.Dev.providerOwnership,
      encounter_provenance = mod.exports.__beta26.Dev.encounterProvenance,
      decision_trace = mod.exports.__beta26.Dev.decisionTrace,
      bug_report_snapshot = mod.exports.__beta26.Dev.bugReportSnapshot,
      localization_certification =
          mod.exports.__beta26.Dev.localizationCertification,
      localization_certification_mark =
          mod.exports.__beta26.Dev.localizationCertificationMark,
      localization_certification_reset =
          mod.exports.__beta26.Dev.localizationCertificationReset,
      lifecycle = mod.exports.__beta26.Dev.lifecycleReport,
      reset_lifecycle = mod.exports.__beta26.Dev.resetLifecycle,
      safe_stop_writes = mod.exports.__beta26.safeStopWriteReport,
      reset_safe_stop_writes = mod.exports.__beta26.resetSafeStopWrites,
      build_provenance = mod.exports.__beta26.buildProvenance,
      rule_registry = mod.exports.__beta26.ruleRegistry.describe,
      save_schema_descriptor = mod.exports.__beta26.saveSchemaDescriptor.describe,
      compatibility_contracts = function()
          local versions = {}
          for key, value in pairs(mod.exports.__beta26.compatCapabilityVersions or {}) do
              versions[key] = value
          end
          return {
              api = mod.exports.__beta26.compatibilityApi,
              capability_versions = versions,
          }
      end,
      contracts = {
          self_test = 1,
          hook_health = 1,
          hook_registry = 1,
          feature_health = 1,
          gameplay_transactions = 1,
          transaction_health = 1,
          hook_wrapper_drift = 1,
          randomizer_reproducibility = 1,
          shiny_diagnostics = 1,
          performance_counters = 1,
          rule_configuration_consistency = 1,
          save_run_identity_health = 1,
          ownership_history = 1,
          gen2_edition_parity = 1,
          gen2_description_parity = 1,
          rule_registry = 1,
          save_schema_descriptor = 1,
          build_provenance = 1,
          compatibility_contracts = 1,
          system_health = 1,
          provider_ownership = 1,
          encounter_provenance = 1,
          decision_trace = 1,
          bug_report_snapshot = 1,
      },
      log_snapshot = mod.exports.__beta26.Dev.logSnapshot,
      record_error = mod.exports.__beta26.Dev.recordError,
      pguard = mod.exports.__beta26.Dev.pguard,
      self_test = mod.exports.__beta26.Dev.selfTest,
      self_test_text = mod.exports.__beta26.Dev.selfTestText,
      report_code = mod.exports.__beta26.Dev.reportCode,
      decode_report_code = mod.exports.__beta26.Dev.decodeReportCode,
      error_code = mod.exports.__beta26.Dev.errorCode,
      export_self_test = mod.exports.__beta26.Dev.exportSelfTest,
      reload_self_test = mod.exports.__beta26.Dev.reloadStoredSelfTest,
      stored_self_tests = function(game)
          game = game or liveGame() or mod.game
          local storage = mod and mod.storage
          if type(storage) ~= "table" or type(storage.list) ~= "function" then
              return {}
          end
          local ok, keys = pcall(storage.list, storage, game, "dev")
          if not ok or type(keys) ~= "table" then return {} end
          local out = {}
          for _, key in ipairs(keys) do
              key = tostring(key)
              if key == "dev/self_test_latest"
                  or key:match("^dev/self_test_history_%d+$") then
                  out[#out + 1] = key
              end
          end
          table.sort(out)
          return out
      end,
      last_export_text = function()
          return mod.exports.__beta26.Dev.lastExportText
      end,
  }

  mod.events:on("game.ready", function(ev)
      mod.exports.__beta26.Dev.countLifecycle("game.ready", ev)
      local game = type(ev) == "table" and ev.game or ev or liveGame() or mod.game
      if mod.exports.__beta26.Dev.enabled() then
          mod.exports.__beta26.Dev.push("game.ready", "runtime ready", game)
          pcall(mod.exports.__beta26.Dev.logSnapshot, "game.ready", game)
      end
  end)
  mod.events:on("save.loaded", function(ev)
      mod.exports.__beta26.Dev.countLifecycle("save.loaded", ev)
      local game = type(ev) == "table" and ev.game or liveGame() or mod.game
      if mod.exports.__beta26.Dev.enabled() then
          mod.exports.__beta26.Dev.push("save.loaded", "save attached", game)
          pcall(mod.exports.__beta26.Dev.logSnapshot, "save.loaded", game)
      end
  end)
  mod.events:on("battle.started", function(ev)
      mod.exports.__beta26.Dev.countLifecycle("battle.started", ev)
      if mod.exports.__beta26.Dev.enabled() then
          local kind = type(ev) == "table" and (ev.kind or ev.battleType) or nil
          mod.exports.__beta26.Dev.push("battle.started", tostring(kind or "unknown"),
              type(ev) == "table" and ev.game or liveGame() or mod.game)
      end
  end)
  mod.events:on("battle.ended", function(ev)
      mod.exports.__beta26.Dev.countLifecycle("battle.ended", ev)
      if mod.exports.__beta26.Dev.enabled() then
          mod.exports.__beta26.Dev.push("battle.ended", "battle complete",
              type(ev) == "table" and ev.game or liveGame() or mod.game)
      end
  end)
  mod.events:on("pokemon.caught", function(ev)
      mod.exports.__beta26.Dev.countLifecycle("pokemon.caught", ev)
      if mod.exports.__beta26.Dev.enabled() then
          local mon = type(ev) == "table" and (ev.mon or ev.pokemon) or nil
          mod.exports.__beta26.Dev.push("pokemon.caught",
              tostring(mon and mon.species or "unknown"), liveGame() or mod.game)
      end
  end)
  mod.events:on("pokemon.evolved", function(ev)
      mod.exports.__beta26.Dev.countLifecycle("pokemon.evolved", ev)
      if mod.exports.__beta26.Dev.enabled() then
          local target = type(ev) == "table" and (ev.toSpecies or ev.species) or nil
          mod.exports.__beta26.Dev.push("pokemon.evolved", tostring(target or "unknown"),
              liveGame() or mod.game)
      end
  end)

  return mod.exports.__beta26.Dev
end
