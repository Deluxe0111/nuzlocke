return function(mod, deps)
  deps = deps or {}
  ---------------------------------------------------------------------
  -- RUN HISTORY v2 / ACHIEVEMENT EVIDENCE (2.8.49)
  --
  -- The visible chronology remains a bounded append-only journal for future
  -- Graveyard, Almanac, Confessional, meta-run and companion-mod surfaces.
  -- v2 adds a separate durable aggregate/evidence ledger that is updated
  -- before journal pruning, so future achievements can evaluate lifetime run
  -- facts without relying on the oldest 512 detailed rows still being present.
  -- Missing pre-ledger detail is explicitly marked PARTIAL and never guessed.
  -- This subsystem is independently versioned inside Save Schema 5.
  ---------------------------------------------------------------------
  mod.exports.__beta26.RunHistory = {
      api = 2,
      storage_version = 2,
      storage_key = "run_history_v1",
      max_events = 512,
      summary_kinds = {
          ["pokemon.caught"] = "catches",
          ["pokemon.died"] = "deaths",
          ["encounter.failed"] = "failed_encounters",
          ["badge.earned"] = "badges",
          ["forgiveness.awarded"] = "forgiveness_awarded",
          ["forgiveness.used"] = "forgiveness_used",
          ["run.blackout"] = "blackouts",
          ["run.completed"] = "completions",
          ["run.abandoned"] = "abandons",
      },
  }
  
  mod.exports.__beta26.RunHistory.safeScalar = function(value)
      local kind = type(value)
      if kind == "string" or kind == "number" or kind == "boolean" then
          return value
      end
      return nil
  end
  
  mod.exports.__beta26.RunHistory.cleanPayload = function(payload)
      local out = {}
      if type(payload) ~= "table" then return out end
      -- Keep the on-disk/event-bus contract intentionally flat.  Rich UI can
      -- join against Pokemon identity / tracker state when needed; persisting
      -- arbitrary engine objects here would make history fragile across builds.
      for key, value in pairs(payload) do
          local clean = mod.exports.__beta26.RunHistory.safeScalar(value)
          if clean ~= nil then out[tostring(key)] = clean end
      end
      return out
  end
  
  mod.exports.__beta26.RunHistory.rebuildDedupe = function(root)
      root.dedupe = {}
      for _, row in ipairs(root.events or {}) do
          if type(row) == "table" and type(row.dedupe) == "string"
              and row.dedupe ~= "" then
              root.dedupe[row.dedupe] = row.seq or true
          end
      end
      return root.dedupe
  end
  
  mod.exports.__beta26.RunHistory.dedupeIndexMatches = function(root)
      if type(root) ~= "table" or type(root.events) ~= "table"
          or type(root.dedupe) ~= "table" then
          return false, "missing_table"
      end
      local expected = {}
      for _, row in ipairs(root.events) do
          if type(row) == "table" and type(row.dedupe) == "string"
              and row.dedupe ~= "" then
              expected[row.dedupe] = row.seq or true
          end
      end
      for key, value in pairs(expected) do
          if root.dedupe[key] ~= value then
              return false, "missing_or_wrong:" .. tostring(key)
          end
      end
      for key, value in pairs(root.dedupe) do
          if expected[key] ~= value then
              return false, "phantom_or_wrong:" .. tostring(key)
          end
      end
      return true
  end

  local function normalizeBaselineCounter(value)
      local normalized = math.max(0, math.floor(tonumber(value) or 0))
      return normalized, value ~= normalized
  end

  mod.exports.__beta26.RunHistory.deathShinyBooleanSelfTest = function()
      local originalAppend = mod.exports.__beta26.RunHistory.append
      local captured = nil
      mod.exports.__beta26.RunHistory.append = function(game, kind, payload, opts)
          captured = { kind = kind, payload = payload, opts = opts }
          return true
      end

      local fakeMon = {
          species = "MAGIKARP",
          nickname = "TEST",
          nuzlockeDeathSequence = 1,
      }
      local okCall, result = pcall(
          mod.exports.__beta26.RunHistory.recordDeath,
          { id = "RED" },
          fakeMon,
          { shiny = false, pokemonId = "selftest:death", deathSequence = 1 })

      mod.exports.__beta26.RunHistory.append = originalAppend

      local ok = okCall == true and result == true
          and type(captured) == "table"
          and captured.kind == "pokemon.died"
          and type(captured.payload) == "table"
          and captured.payload.shiny == false

      return {
          ok = ok,
          failures = ok and {} or { "explicit_false_not_preserved" },
          captured = type(captured) == "table"
              and type(captured.payload) == "table"
              and tostring(captured.payload.shiny) or "nil",
      }
  end

  mod.exports.__beta26.RunHistory.baselineNormalizationAudit = function()
      local cases = {
          { value = 3, expected = 3, changed = false },
          { value = "3", expected = 3, changed = true },
          { value = -4, expected = 0, changed = true },
          { value = 2.9, expected = 2, changed = true },
          { value = "bad", expected = 0, changed = true },
      }
      local failures = {}
      for index, case in ipairs(cases) do
          local normalized, changed = normalizeBaselineCounter(case.value)
          if normalized ~= case.expected or changed ~= case.changed then
              failures[#failures + 1] = "case_" .. tostring(index)
          end
      end
      return { ok = #failures == 0, failures = failures, checked = #cases }
  end

  -- 2.8.49: durable achievement-evidence ledger. The visible history journal
  -- remains bounded, but these aggregates are updated before pruning so future
  -- achievement evaluation does not depend on the oldest event rows surviving.
  -- Unknown/older history is marked partial rather than guessed.
  local function statIncrement(tbl, key, amount)
      if type(tbl) ~= "table" then return end
      key = tostring(key or "")
      if key == "" then return end
      tbl[key] = math.max(0, math.floor(tonumber(tbl[key]) or 0))
          + math.max(0, math.floor(tonumber(amount) or 1))
  end

  local function copyEvidence(value, seen)
      if type(value) ~= "table" then return value end
      seen = seen or {}
      if seen[value] then return nil end
      seen[value] = true
      local out = {}
      for key, child in pairs(value) do
          local cleanKey = key
          if type(key) ~= "string" and type(key) ~= "number" then
              cleanKey = tostring(key)
          end
          out[cleanKey] = copyEvidence(child, seen)
      end
      seen[value] = nil
      return out
  end

  local function statDimension(stats, group, value, amount)
      if type(stats) ~= "table" or value == nil then return end
      stats.dimensions = type(stats.dimensions) == "table" and stats.dimensions or {}
      stats.dimensions[group] = type(stats.dimensions[group]) == "table"
          and stats.dimensions[group] or {}
      statIncrement(stats.dimensions[group], tostring(value), amount)
  end

  local function captureRuleValues()
      local out = {}
      local defs = mod.exports.__beta26.ruleDefinitionByKey
      if type(defs) ~= "table" then return out end
      for key, spec in pairs(defs) do
          local default = type(spec) == "table" and spec.default or nil
          local value = mod.save:get(key, default)
          local scalar = mod.exports.__beta26.RunHistory.safeScalar(value)
          if scalar ~= nil then out[tostring(key)] = scalar end
      end
      return out
  end

  local function updateStatsContext(stats, game)
      if type(stats) ~= "table" then return end
      local live = game or deps.currentGame() or mod.game
      stats.context = type(stats.context) == "table" and stats.context or {}
      stats.context.edition = stats.context.edition
          or mod.exports.__beta26.Dev.gameId(live)
      stats.context.generation = stats.context.generation
          or (tonumber(live and live.generation)
              or (mod.exports.__beta26.runtimeIsGen2(live) and 2 or 1))
      stats.context.first_build = stats.context.first_build
          or mod.exports.__beta26.build
      stats.context.last_build = mod.exports.__beta26.build
      if type(mod.exports.__beta26.randomizerRunConfig) == "function" then
          local ok, run = pcall(mod.exports.__beta26.randomizerRunConfig)
          if ok and type(run) == "table" then
              stats.context.randomizer_seen = true
              stats.context.randomizer_algorithm = run.algorithm
              stats.context.randomizer_schema = run.schema
              stats.context.randomizer_game = run.game
          end
      end
  end

  local function applyEventToStatistics(stats, kind, row)
      if type(stats) ~= "table" then return end
      row = type(row) == "table" and row or {}
      stats.event_counts = type(stats.event_counts) == "table"
          and stats.event_counts or {}
      stats.counters = type(stats.counters) == "table" and stats.counters or {}
      stats.flags = type(stats.flags) == "table" and stats.flags or {}
      stats.first = type(stats.first) == "table" and stats.first or {}
      stats.last = type(stats.last) == "table" and stats.last or {}
      statIncrement(stats.event_counts, kind, 1)

      if kind == "pokemon.caught" then
          statIncrement(stats.counters, "catches", 1)
          statDimension(stats, "catch_species", row.species or row.rawSpecies)
          statDimension(stats, "catch_encounter_type", row.encounterType)
          statDimension(stats, "catch_source", row.encounterSource or row.source)
          if row.shiny == true then
              statIncrement(stats.counters, "shiny_catches", 1)
              stats.flags.caught_shiny = true
          end
          if stats.first.catch_species == nil then
              stats.first.catch_species = row.species or row.rawSpecies
              stats.first.catch_area = row.area
              stats.first.catch_encounter_type = row.encounterType
          end
          stats.last.catch_species = row.species or row.rawSpecies
          stats.last.catch_area = row.area
      elseif kind == "pokemon.died" then
          statIncrement(stats.counters, "deaths", 1)
          statDimension(stats, "death_species", row.species or row.rawSpecies)
          statDimension(stats, "death_cause", row.cause)
          statDimension(stats, "death_opponent_species", row.opponentSpecies)
          if row.shiny == true then
              statIncrement(stats.counters, "shiny_deaths", 1)
          end
          stats.flags.had_death = true
          if stats.first.death_species == nil then
              stats.first.death_species = row.species or row.rawSpecies
              stats.first.death_cause = row.cause
          end
          stats.last.death_species = row.species or row.rawSpecies
          stats.last.death_cause = row.cause
      elseif kind == "encounter.failed" then
          statIncrement(stats.counters, "failed_encounters", 1)
          statDimension(stats, "failed_encounter_species", row.species)
          statDimension(stats, "failed_encounter_type", row.encounterType)
          stats.flags.had_failed_encounter = true
          if stats.first.failed_encounter_species == nil then
              stats.first.failed_encounter_species = row.species
              stats.first.failed_encounter_area = row.area
          end
          stats.last.failed_encounter_species = row.species
          stats.last.failed_encounter_area = row.area
      elseif kind == "badge.earned" then
          statIncrement(stats.counters, "badges", 1)
          statDimension(stats, "badges", row.badge or row.name)
          stats.last.badge = row.badge or row.name
      elseif kind == "forgiveness.awarded" then
          statIncrement(stats.counters, "forgiveness_awarded", 1)
      elseif kind == "forgiveness.used" then
          statIncrement(stats.counters, "forgiveness_used", 1)
          statDimension(stats, "forgiveness_mode", row.mode)
          stats.flags.used_forgiveness = true
      elseif kind == "run.blackout" then
          statIncrement(stats.counters, "blackouts", 1)
          stats.flags.blacked_out = true
      elseif kind == "run.completed" then
          statIncrement(stats.counters, "completions", 1)
          statDimension(stats, "completion_target", row.target or row.name)
          stats.flags.completed = true
          stats.last.completion_target = row.target or row.name
      elseif kind == "run.abandoned" then
          statIncrement(stats.counters, "abandons", 1)
          stats.flags.abandoned = true
      end
      stats.last.event_kind = kind
      stats.last.event_seq = row.seq
      stats.last.event_build = row.build or mod.exports.__beta26.build
  end

  local function buildStatisticsFromHistory(root, game)
      local stats = {
          version = 1,
          coverage_start_build = root.coverage_start_build
              or mod.exports.__beta26.build,
          event_counts = {},
          counters = {},
          flags = {},
          dimensions = {},
          first = {},
          last = {},
          coverage = {
              partial = root.partial == true,
              imported_history_v1 = tonumber(root.version) == 1,
              retained_events = #(root.events or {}),
              journal_truncated = false,
              detail_complete = true,
          },
          rule_integrity = {
              start_values = captureRuleValues(),
              last_values = captureRuleValues(),
              changed = {},
              change_count = 0,
              partial = root.partial == true,
          },
      }
      local totalRecorded = math.max(0, (tonumber(root.next_seq) or 1) - 1)
      stats.coverage.journal_truncated = totalRecorded > #(root.events or {})
      if stats.coverage.journal_truncated then
          stats.coverage.partial = true
          stats.coverage.detail_complete = false
      end

      -- Summary counters survive journal pruning. Seed aggregate totals from
      -- them (plus pre-history baselines) before scanning retained rows only
      -- for dimensions/facts that older builds did not aggregate.
      local summary = type(root.summary) == "table" and root.summary or {}

      local retainedKinds = {}
      for _, row in ipairs(root.events or {}) do
          if type(row) == "table" and type(row.kind) == "string" then
              statIncrement(retainedKinds, row.kind, 1)
              -- Apply into a temporary copy for dimensions/flags only; restore
              -- summary-backed total counters afterwards to avoid double count.
              applyEventToStatistics(stats, row.kind, row)
          end
      end
      for kind, count in pairs(retainedKinds) do
          stats.event_counts[kind] = count
      end
      -- Restore authoritative durable totals from one mapping so new
      -- summarized event kinds cannot silently miss rebuild/coverage logic.
      -- Catches/deaths retain their pre-ledger baselines in addition to v2
      -- summary totals; all other kinds use their durable summary total.
      for kind, summaryKey in pairs(
          mod.exports.__beta26.RunHistory.summary_kinds) do
          local total = math.max(0,
              math.floor(tonumber(summary[summaryKey]) or 0))
          if kind == "pokemon.caught" then
              total = total + math.max(0,
                  math.floor(tonumber(root.baseline_catches) or 0))
          elseif kind == "pokemon.died" then
              total = total + math.max(0,
                  math.floor(tonumber(root.baseline_deaths) or 0))
          end
          stats.counters[summaryKey] = total
          if total > 0 then stats.event_counts[kind] = total end

          -- Durable aggregate > retained detailed rows means dimensions/first/
          -- last information for this kind is incomplete after migration or
          -- bounded-journal pruning. Never claim detail completeness then.
          local retained = math.max(0,
              math.floor(tonumber(retainedKinds[kind]) or 0))
          if total > retained then
              stats.coverage.detail_complete = false
              stats.coverage.partial = true
          end
      end

      if stats.counters.deaths > 0 then stats.flags.had_death = true end
      if stats.counters.blackouts > 0 then stats.flags.blacked_out = true end
      if stats.counters.forgiveness_used > 0 then
          stats.flags.used_forgiveness = true
      end
      if stats.counters.completions > 0 then stats.flags.completed = true end
      if stats.counters.abandons > 0 then stats.flags.abandoned = true end
      updateStatsContext(stats, game)
      return stats
  end

  -- 2.8.70: repair/maintain coverage on already-materialized v2 statistics
  -- without rebuilding dimensions or rule-integrity history. This mirrors the
  -- summary-driven completeness rule used by buildStatisticsFromHistory.
  local function reconcileStatisticsCoverage(root)
      local stats = type(root.statistics) == "table" and root.statistics or nil
      if type(stats) ~= "table" then return false end
      stats.coverage = type(stats.coverage) == "table" and stats.coverage or {}
      stats.counters = type(stats.counters) == "table" and stats.counters or {}
      stats.flags = type(stats.flags) == "table" and stats.flags or {}
      local changed = false
      local retainedKinds = {}
      for _, row in ipairs(root.events or {}) do
          if type(row) == "table" and type(row.kind) == "string" then
              statIncrement(retainedKinds, row.kind, 1)
          end
      end
      local summary = type(root.summary) == "table" and root.summary or {}
      local incomplete = false
      for kind, summaryKey in pairs(
          mod.exports.__beta26.RunHistory.summary_kinds) do
          local total = math.max(0,
              math.floor(tonumber(summary[summaryKey]) or 0))
          if kind == "pokemon.caught" then
              total = total + math.max(0,
                  math.floor(tonumber(root.baseline_catches) or 0))
          elseif kind == "pokemon.died" then
              total = total + math.max(0,
                  math.floor(tonumber(root.baseline_deaths) or 0))
          end
          local retained = math.max(0,
              math.floor(tonumber(retainedKinds[kind]) or 0))
          if total > retained then incomplete = true end
          if stats.counters[summaryKey] == nil
              or tonumber(stats.counters[summaryKey]) ~= total then
              stats.counters[summaryKey] = total
              changed = true
          end
      end
      local totalRecorded = math.max(0, (tonumber(root.next_seq) or 1) - 1)
      if totalRecorded > #(root.events or {}) then incomplete = true end
      if incomplete then
          if stats.coverage.detail_complete ~= false then
              stats.coverage.detail_complete = false; changed = true
          end
          if stats.coverage.partial ~= true then
              stats.coverage.partial = true; changed = true
          end
          if totalRecorded > #(root.events or {})
              and stats.coverage.journal_truncated ~= true then
              stats.coverage.journal_truncated = true; changed = true
          end
      end
      if (tonumber(stats.counters.abandons) or 0) > 0
          and stats.flags.abandoned ~= true then
          stats.flags.abandoned = true
          changed = true
      end
      return changed
  end

  mod.exports.__beta26.RunHistory.statistics = function(game)
      local root, err = mod.exports.__beta26.RunHistory.ensure(game)
      if type(root) ~= "table" then return nil, err end
      return copyEvidence(root.statistics)
  end

  mod.exports.__beta26.RunHistory.achievementEvidence = function(game)
      local stats, err = mod.exports.__beta26.RunHistory.statistics(game)
      if type(stats) ~= "table" then return nil, err end
      return stats
  end

  -- Called by the live rule editor only after Run History already exists.
  -- This avoids creating a run merely because a title/setup option changed.
  mod.exports.__beta26.RunHistory.recordRuleConfigurationChange =
      function(game, key, before, after, source)
      local root = mod.save:get(mod.exports.__beta26.RunHistory.storage_key, nil)
      if type(root) ~= "table" or tonumber(root.version) == nil then
          return false, "history_not_started"
      end
      if before == after then return false, "unchanged" end
      local ensured, err = mod.exports.__beta26.RunHistory.ensure(game)
      if type(ensured) ~= "table" then return false, err end
      local stats = ensured.statistics
      if type(stats) ~= "table" then return false, "statistics_unavailable" end
      stats.rule_integrity = type(stats.rule_integrity) == "table"
          and stats.rule_integrity or {
              start_values = captureRuleValues(), last_values = {},
              changed = {}, change_count = 0, partial = true,
          }
      local ri = stats.rule_integrity
      ri.last_values = type(ri.last_values) == "table"
          and ri.last_values or {}
      ri.changed = type(ri.changed) == "table" and ri.changed or {}
      local cleanAfter = mod.exports.__beta26.RunHistory.safeScalar(after)
      if cleanAfter ~= nil then ri.last_values[tostring(key)] = cleanAfter end
      local row = ri.changed[tostring(key)]
      if type(row) ~= "table" then
          row = {
              first_before = mod.exports.__beta26.RunHistory.safeScalar(before),
              last_after = cleanAfter,
              count = 0,
              first_build = mod.exports.__beta26.build,
          }
          ri.changed[tostring(key)] = row
      end
      row.count = (tonumber(row.count) or 0) + 1
      row.last_after = cleanAfter
      row.last_build = mod.exports.__beta26.build
      row.source = tostring(source or "config")
      ri.change_count = (tonumber(ri.change_count) or 0) + 1
      stats.flags = type(stats.flags) == "table" and stats.flags or {}
      stats.flags.rules_changed_during_run = true
      updateStatsContext(stats, game)
      mod.save:set(mod.exports.__beta26.RunHistory.storage_key, ensured)
      return true
  end

  mod.exports.__beta26.RunHistory.ensure = function(game)
      if deps.saveBlocked() then return nil, "newer_schema" end
      local root = mod.save:get(mod.exports.__beta26.RunHistory.storage_key, {})
      if type(root) ~= "table" then root = {} end
      local changed = false
      local storedVersion = tonumber(root.version)
      local currentVersion = mod.exports.__beta26.RunHistory.storage_version
      if storedVersion ~= nil and storedVersion > currentVersion then
          return nil, "newer_history_schema"
      end
      if storedVersion == nil then
          -- Fresh/legacy initialization. Preserve known pre-ledger catches and
          -- deaths as baselines, but mark detail coverage partial when the run
          -- had already progressed before the history ledger existed.
          local legacy = mod.save:get("nuzlocke_history", {})
          local baselineCatches = 0
          if type(deps.countTrackerCatches) == "function" then
              local okCount, count = pcall(deps.countTrackerCatches)
              if okCount then
                  baselineCatches = math.max(0, math.floor(tonumber(count) or 0))
              end
          end
          local baselineDeaths = math.max(0, math.floor(tonumber(
              mod.save:get("nuzlocke_losses", 0)) or 0))
          local progressed = baselineCatches > 0 or baselineDeaths > 0
              or (type(legacy) == "table" and #legacy > 0)
          root = {
              version = currentVersion,
              coverage_start_build = mod.exports.__beta26.build,
              partial = progressed == true,
              baseline_catches = baselineCatches,
              baseline_deaths = baselineDeaths,
              events = {}, summary = {}, dedupe = {}, next_seq = 1,
          }
          changed = true
      elseif storedVersion == 1 then
          -- 2.8.49 Run History v1 -> v2 migration. Unlike the old first-format
          -- initializer, this preserves the entire v1 journal/summary and adds
          -- the achievement-evidence aggregate beside it.
          if type(root.events) ~= "table" then root.events = {} end
          if type(root.summary) ~= "table" then root.summary = {} end
          root.statistics = buildStatisticsFromHistory(root, game)
          root.version = currentVersion
          changed = true
      elseif storedVersion ~= currentVersion then
          return nil, "unsupported_history_schema:" .. tostring(storedVersion)
      end
      if type(root.events) ~= "table" then root.events = {}; changed = true end
      if type(root.summary) ~= "table" then root.summary = {}; changed = true end

      -- 2.8.70 repair: 2.8.49-2.8.69 counted run.abandoned in the durable
      -- statistics ledger but omitted it from root.summary. Backfill the new
      -- summary counter from the persisted statistics total when available so
      -- already-pruned abandon events remain recoverable. If statistics are
      -- absent, retained detailed rows are the best non-guessed evidence.
      if root.summary.abandons == nil then
          local durableAbandons = type(root.statistics) == "table"
              and type(root.statistics.counters) == "table"
              and tonumber(root.statistics.counters.abandons) or nil
          if durableAbandons == nil then
              durableAbandons = 0
              for _, row in ipairs(root.events) do
                  if type(row) == "table" and row.kind == "run.abandoned" then
                      durableAbandons = durableAbandons + 1
                  end
              end
          end
          root.summary.abandons = math.max(0,
              math.floor(tonumber(durableAbandons) or 0))
          changed = true
      end
      local dedupeOk = type(root.dedupe) == "table"
          and mod.exports.__beta26.RunHistory.dedupeIndexMatches(root) == true
      if not dedupeOk then
          mod.exports.__beta26.RunHistory.rebuildDedupe(root)
          changed = true
      end
      if root.coverage_start_build == nil then
          root.coverage_start_build = mod.exports.__beta26.build
          changed = true
      end
      if root.partial == nil then root.partial = false; changed = true end
      local normalizedBaselineCatches, catchesChanged =
          normalizeBaselineCounter(root.baseline_catches)
      local normalizedBaselineDeaths, deathsChanged =
          normalizeBaselineCounter(root.baseline_deaths)
      if catchesChanged or deathsChanged then changed = true end
      root.baseline_catches = normalizedBaselineCatches
      root.baseline_deaths = normalizedBaselineDeaths
      -- 2.7.4: recover sequence state from the retained journal. A malformed
      -- or stale next_seq must never reuse an earlier event number.
      local maxRetainedSeq = 0
      for _, row in ipairs(root.events) do
          if type(row) == "table" then
              maxRetainedSeq = math.max(maxRetainedSeq,
                  math.max(0, math.floor(tonumber(row.seq) or 0)))
          end
      end
      local storedNextSeq = math.floor(tonumber(root.next_seq) or 0)
      local repairedNextSeq = math.max(1, maxRetainedSeq + 1, storedNextSeq)
      if storedNextSeq ~= repairedNextSeq then changed = true end
      root.next_seq = repairedNextSeq
      if root.edition == nil then
          root.edition = mod.exports.__beta26.Dev.gameId(game or deps.currentGame() or mod.game)
          changed = true
      end
      if root.generation == nil then
          local live = game or deps.currentGame() or mod.game
          root.generation = tonumber(live and live.generation)
              or (mod.exports.__beta26.runtimeIsGen2(live) and 2 or 1)
          changed = true
      end
      if root.run_id == nil then
          local live = game or deps.currentGame() or mod.game
          local player = live and live.save and live.save.player
          local playerId = player and (player.id or player.name) or "unknown"
          root.run_id = tostring(root.edition) .. ":" .. tostring(playerId)
          changed = true
      end
      if type(root.statistics) ~= "table"
          or tonumber(root.statistics.version) ~= 1 then
          root.statistics = buildStatisticsFromHistory(root, game)
          changed = true
      else
          updateStatsContext(root.statistics, game)
          root.statistics.rule_integrity =
              type(root.statistics.rule_integrity) == "table"
              and root.statistics.rule_integrity or {
                  start_values = captureRuleValues(),
                  last_values = captureRuleValues(),
                  changed = {}, change_count = 0,
                  partial = root.partial == true,
              }
      end
      if reconcileStatisticsCoverage(root) then changed = true end
      if changed then
          local okWrite, writeResult = pcall(mod.save.set, mod.save,
              mod.exports.__beta26.RunHistory.storage_key, root)
          if not okWrite then
              return nil, "history_repair_write_error:" .. tostring(writeResult)
          end
          if writeResult == false then
              return nil, "history_repair_write_rejected"
          end
      end
      return root
  end

  mod.exports.__beta26.RunHistory.hasDedupe = function(game, dedupe)
      dedupe = tostring(dedupe or "")
      if dedupe == "" then return false end
      local root, ensureErr = mod.exports.__beta26.RunHistory.ensure(game)
      if type(root) ~= "table" then
          return nil, tostring(ensureErr or "unavailable")
      end
      return root.dedupe[dedupe] ~= nil, root.dedupe[dedupe]
  end
  
  mod.exports.__beta26.RunHistory.append = function(game, kind, payload, opts)
      opts = opts or {}
      if deps.saveBlocked() then return false, "newer_schema" end
      kind = tostring(kind or "")
      if kind == "" then return false, "missing_kind" end
      local root, ensureErr = mod.exports.__beta26.RunHistory.ensure(game)
      if type(root) ~= "table" then
          return false, tostring(ensureErr or "unavailable")
      end
      local dedupe = tostring(opts.dedupe or "")
      if dedupe ~= "" and root.dedupe[dedupe] ~= nil then
          return false, "duplicate"
      end
      local row = mod.exports.__beta26.RunHistory.cleanPayload(payload)
      row.seq = root.next_seq
      root.next_seq = root.next_seq + 1
      row.kind = kind
      row.edition = mod.exports.__beta26.Dev.gameId(game or deps.currentGame() or mod.game)
      local live = game or deps.currentGame() or mod.game
      row.generation = tonumber(live and live.generation)
          or (mod.exports.__beta26.runtimeIsGen2(live) and 2 or 1)
      row.build = mod.exports.__beta26.build
      if dedupe ~= "" then row.dedupe = dedupe end
      root.events[#root.events + 1] = row
      if dedupe ~= "" then root.dedupe[dedupe] = row.seq end
      local summaryKey = mod.exports.__beta26.RunHistory.summary_kinds[kind]
      if summaryKey then
          root.summary[summaryKey] = (tonumber(root.summary[summaryKey]) or 0) + 1
      end
      if type(root.statistics) ~= "table" then
          root.statistics = buildStatisticsFromHistory(root, game)
      else
          applyEventToStatistics(root.statistics, kind, row)
          updateStatsContext(root.statistics, game)
          if type(root.statistics.rule_integrity) == "table" then
              root.statistics.rule_integrity.last_values = captureRuleValues()
          end
      end
      local pruned = false
      while #root.events > mod.exports.__beta26.RunHistory.max_events do
          table.remove(root.events, 1)
          pruned = true
      end
      if pruned and type(root.statistics) == "table" then
          root.statistics.coverage =
              type(root.statistics.coverage) == "table"
              and root.statistics.coverage or {}
          root.statistics.coverage.journal_truncated = true
          root.statistics.coverage.detail_complete = false
          root.statistics.coverage.partial = true
      end
      if #root.events >= mod.exports.__beta26.RunHistory.max_events then
          mod.exports.__beta26.RunHistory.rebuildDedupe(root)
      end
      local okWrite, writeResult = pcall(mod.save.set, mod.save,
          mod.exports.__beta26.RunHistory.storage_key, root)
      if not okWrite then
          return false, "history_write_error:" .. tostring(writeResult)
      end
      if writeResult == false then
          return false, "history_write_rejected"
      end
      if mod.events and type(mod.events.emit) == "function" then
          pcall(mod.events.emit, mod.events, "nuzlocke.run_history", {
              game = live, event = row, run_id = root.run_id,
          })
      end
      return true, row
  end
  
  mod.exports.__beta26.RunHistory.dedupeKey = function(kind, pokemonId, occurrence)
      if pokemonId == nil then return nil end
      kind = tostring(kind or "")
      if kind == "catch" then
          return "catch:" .. tostring(pokemonId)
      elseif kind == "death" then
          occurrence = tonumber(occurrence)
          if occurrence == nil then return nil end
          occurrence = math.max(1, math.floor(occurrence))
          return "death:" .. tostring(pokemonId) .. ":" .. tostring(occurrence)
      end
      return nil
  end

  mod.exports.__beta26.RunHistory.recordCatch = function(game, mon, fields)
      fields = fields or {}
      local species = fields.species or (mon and mon.species)
      local pokemonId = fields.pokemonId or (mon and deps.pokemonIdentity(mon))
      local shiny = fields.shiny
      if shiny == nil and mon then shiny = deps.isShiny(mon) end
      local payload = {
          species = species,
          rawSpecies = fields.rawSpecies,
          pokemonId = pokemonId,
          name = fields.name or (mon and (mon.nickname or mon.name or mon.species)),
          level = fields.level or (mon and mon.level),
          area = fields.area or fields.catchLocation or (mon and mon.catchLocation),
          encounterType = fields.encounterType or (mon and mon.encounterType),
          encounterMethod = fields.encounterMethod or (mon and mon.nuzlockeEncounterMethod),
          encounterTime = fields.encounterTime or (mon and mon.nuzlockeEncounterTime),
          roamerSpecies = fields.roamerSpecies or (mon and mon.nuzlockeRoamerSpecies),
          encounterSource = fields.encounterSource or (mon and mon.nuzlockeEncounterSource),
          encounterProvider = fields.encounterProvider or (mon and mon.nuzlockeEncounterProvider),
          encounterProviderVersion = fields.encounterProviderVersion
              or (mon and mon.nuzlockeEncounterProviderVersion),
          provenance = fields.provenance or (mon and mon.nuzlockeOrigin),
          consumedArea = fields.consumedArea,
          shiny = shiny,
          pcLocked = fields.pcLocked,
          pcLockReason = fields.pcLockReason,
          pcBox = fields.pcBox,
          source = fields.source,
      }
      local dedupe = fields.dedupe
          or mod.exports.__beta26.RunHistory.dedupeKey("catch", pokemonId)
      return mod.exports.__beta26.RunHistory.append(
          game, "pokemon.caught", payload, { dedupe = dedupe })
  end
  
  mod.exports.__beta26.RunHistory.recordDeath = function(game, mon, fields)
      fields = fields or {}
      local pokemonId = fields.pokemonId or (mon and deps.pokemonIdentity(mon))
      local critical = fields.critical
      if critical == nil and mon then critical = mon.deathCritical end
      local shiny = fields.shiny
      if shiny == nil and mon then shiny = deps.isShiny(mon) end
      if shiny == nil then shiny = false end
      local payload = {
          species = fields.species or (mon and mon.species),
          rawSpecies = fields.rawSpecies,
          pokemonId = pokemonId,
          name = fields.name or (mon and (mon.nickname or mon.name or mon.species)),
          area = fields.area or fields.deathLocation or (mon and mon.deathLocation),
          catchLocation = fields.catchLocation or (mon and mon.catchLocation),
          encounterType = fields.encounterType or (mon and mon.encounterType),
          cause = fields.cause or fields.deathCause or (mon and (mon.deathCauseText or mon.deathCause)),
          opponentSpecies = fields.opponentSpecies or (mon and mon.deathOpponentSpecies),
          move = fields.move or (mon and mon.deathMove),
          critical = critical,
          statusCondition = fields.statusCondition or (mon and mon.deathStatusCondition),
          shiny = shiny,
          source = fields.source,
      }
      local deathSequence = tonumber(fields.deathSequence
          or (mon and mon.nuzlockeDeathSequence))
      if deathSequence ~= nil then
          deathSequence = math.max(1, math.floor(deathSequence))
          payload.deathSequence = deathSequence
      end
      -- A Pokemon can legitimately die again after an F. TOKEN revival, so
      -- dedupe must identify the committed death occurrence rather than the
      -- Pokemon lifetime. The authoritative death bridges increment and
      -- persist nuzlockeDeathSequence before archiving/removing the mon.
      local dedupe = fields.dedupe
          or mod.exports.__beta26.RunHistory.dedupeKey(
              "death", pokemonId, deathSequence)
      return mod.exports.__beta26.RunHistory.append(
          game, "pokemon.died", payload, { dedupe = dedupe })
  end
  
  mod.exports.__beta26.RunHistory.recordEncounterFailed = function(game, fields)
      fields = fields or {}
      local area = fields.area or fields.key
      local dedupe = fields.dedupe
          or (area and ("encounter_failed:" .. tostring(area)) or nil)
      return mod.exports.__beta26.RunHistory.append(game, "encounter.failed", {
          area = area,
          species = fields.species,
          encounterType = fields.encounterType,
          encounterMethod = fields.encounterMethod,
          encounterTime = fields.encounterTime,
          roamerSpecies = fields.roamerSpecies,
          sourceMapId = fields.sourceMapId,
          source = fields.source or "encounter_resolution",
      }, { dedupe = dedupe })
  end

  mod.exports.__beta26.RunHistory.recordForgivenessAward = function(game, source, target, fields)
      fields = fields or {}
      local payload = {
          source = tostring(source or fields.source or "unknown"),
          target = tostring(target or fields.target or ""),
          tokens = fields.tokens,
          map = fields.map,
          leader = fields.leader,
      }
      return mod.exports.__beta26.RunHistory.append(game, "forgiveness.awarded",
          payload, { dedupe = fields.dedupe })
  end

  mod.exports.__beta26.RunHistory.recordForgivenessUse = function(game, mode, target, fields)
      fields = fields or {}
      return mod.exports.__beta26.RunHistory.append(game, "forgiveness.used", {
          mode = tostring(mode or "unknown"),
          target = tostring(target or ""),
          tokens = fields.tokens,
          source = fields.source,
      }, { dedupe = fields.dedupe })
  end


  mod.exports.__beta26.RunHistory.recordBadge = function(game, badge, fields)
      fields = fields or {}
      badge = tostring(badge or fields.badge or fields.leader or "UNKNOWN")
      local dedupe = fields.dedupe or ("badge:" .. badge:upper())
      return mod.exports.__beta26.RunHistory.append(game, "badge.earned", {
          badge = badge,
          name = badge,
          leader = fields.leader,
          region = fields.region,
          map = fields.map,
          source = fields.source or "progression",
      }, { dedupe = dedupe })
  end

  mod.exports.__beta26.RunHistory.recordBlackout = function(game, fields)
      fields = fields or {}
      local sequence = math.max(1, math.floor(tonumber(fields.sequence) or 1))
      return mod.exports.__beta26.RunHistory.append(game, "run.blackout", {
          name = fields.name or "BLACKOUT",
          area = fields.area,
          source = fields.source,
          sequence = sequence,
          deaths = fields.deaths,
      }, { dedupe = fields.dedupe or ("blackout:" .. tostring(sequence)) })
  end

  mod.exports.__beta26.RunHistory.recordCompleted = function(game, fields)
      fields = fields or {}
      local target = tostring(fields.target or fields.name or "COMPLETE")
      return mod.exports.__beta26.RunHistory.append(game, "run.completed", {
          name = target,
          target = target,
          source = fields.source or "progression",
          phase = fields.phase,
      }, { dedupe = fields.dedupe or ("complete:" .. target:upper()) })
  end

  -- 2.9.18: explicit player abandonment is a durable lifecycle event. It is
  -- intentionally distinct from natural completion and is deduped per run so
  -- repeated confirmation/input can never inflate abandon totals.
  mod.exports.__beta26.RunHistory.recordAbandoned = function(game, fields)
      fields = fields or {}
      local root, err = mod.exports.__beta26.RunHistory.ensure(game)
      if type(root) ~= "table" then return false, tostring(err or "unavailable") end
      local dedupe = fields.dedupe or ("abandon:" .. tostring(root.run_id or "unknown"))
      return mod.exports.__beta26.RunHistory.append(game, "run.abandoned", {
          name = fields.name or "ABANDONED",
          source = fields.source or "player",
          reason = fields.reason or "player_abandoned",
          phase = fields.phase,
      }, { dedupe = dedupe })
  end
  
  mod.exports.__beta26.RunHistory.list = function(game, opts)
      opts = opts or {}
      local root, ensureErr = mod.exports.__beta26.RunHistory.ensure(game)
      if type(root) ~= "table" then
          return nil, tostring(ensureErr or "unavailable")
      end
      local out = {}
      local kind = opts.kind and tostring(opts.kind) or nil
      local hasAfter = opts.after_seq ~= nil
      local after = tonumber(opts.after_seq) or 0
      local limit = math.max(1, math.min(512, math.floor(tonumber(opts.limit) or 512)))
      local matched = {}
      for _, row in ipairs(root.events or {}) do
          if (not kind or row.kind == kind) and (tonumber(row.seq) or 0) > after then
              matched[#matched + 1] = row
          end
      end
      -- 2.9.10: without an explicit cursor, list(limit=N) means the most
      -- recent N matching events. Preserve chronological order inside that
      -- tail so existing timeline consumers still render oldest -> newest.
      -- With after_seq, retain forward-pagination semantics: first N rows
      -- strictly after the supplied sequence.
      local first = hasAfter and 1 or math.max(1, #matched - limit + 1)
      local last = hasAfter and math.min(#matched, limit) or #matched
      for i = first, last do
          local copy = {}
          for key, value in pairs(matched[i]) do copy[key] = value end
          out[#out + 1] = copy
      end
      return out
  end
  
  mod.exports.__beta26.RunHistory.report = function(game)
      local root, ensureErr = mod.exports.__beta26.RunHistory.ensure(game)
      if type(root) ~= "table" then
          return nil, tostring(ensureErr or "unavailable")
      end
      local summary = {}
      for key, value in pairs(root.summary or {}) do summary[key] = value end
      return {
          api = mod.exports.__beta26.RunHistory.api,
          storage_version = root.version,
          run_id = root.run_id,
          edition = root.edition,
          generation = root.generation,
          retained_events = #(root.events or {}),
          lifetime = summary,
          partial = root.partial == true,
          coverage_start_build = root.coverage_start_build,
          baseline_catches = root.baseline_catches or 0,
          baseline_deaths = root.baseline_deaths or 0,
          statistics = copyEvidence(root.statistics),
          achievement_evidence_version = type(root.statistics) == "table"
              and root.statistics.version or nil,
          achievement_evidence_partial = not (
              type(root.statistics) == "table"
              and type(root.statistics.coverage) == "table"
              and root.statistics.coverage.partial == false),
          first_seq = root.events and root.events[1] and root.events[1].seq or nil,
          last_seq = root.events and root.events[#root.events]
              and root.events[#root.events].seq or nil,
      }
  end
  
  mod.exports.__beta26.RunHistory.audit = function()
      local root = mod.save:get(mod.exports.__beta26.RunHistory.storage_key, nil)
      if root == nil then return { ok = true, events = 0, initialized = false } end
      local failures = {}
      if type(root) ~= "table" then
          failures[#failures + 1] = "root is " .. type(root)
          return { ok = false, failures = failures, events = 0 }
      end
      if tonumber(root.version) ~= mod.exports.__beta26.RunHistory.storage_version then
          failures[#failures + 1] = "storage version mismatch"
      end
      if type(root.coverage_start_build) ~= "string" or root.coverage_start_build == "" then
          failures[#failures + 1] = "missing coverage start"
      end
      if type(root.partial) ~= "boolean" then
          failures[#failures + 1] = "partial flag is " .. type(root.partial)
      end
      if tonumber(root.baseline_catches) == nil or tonumber(root.baseline_catches) < 0
          or tonumber(root.baseline_deaths) == nil or tonumber(root.baseline_deaths) < 0 then
          failures[#failures + 1] = "invalid baseline counters"
      end
      if type(root.events) ~= "table" then
          failures[#failures + 1] = "events is " .. type(root.events)
          return { ok = false, failures = failures, events = 0 }
      end
      if #root.events > mod.exports.__beta26.RunHistory.max_events then
          failures[#failures + 1] = "event cap exceeded"
      end
      if type(root.statistics) ~= "table"
          or tonumber(root.statistics.version) ~= 1 then
          failures[#failures + 1] = "missing achievement statistics"
      else
          if type(root.statistics.event_counts) ~= "table"
              or type(root.statistics.counters) ~= "table"
              or type(root.statistics.coverage) ~= "table"
              or type(root.statistics.rule_integrity) ~= "table" then
              failures[#failures + 1] = "achievement statistics malformed"
          end
      end
      local previous = 0
      local seen = {}
      for index, row in ipairs(root.events) do
          if type(row) ~= "table" then
              failures[#failures + 1] = "row " .. tostring(index) .. " is " .. type(row)
          else
              local seq = tonumber(row.seq)
              if seq == nil or seq <= previous then
                  failures[#failures + 1] = "non-monotonic seq at " .. tostring(index)
              else
                  previous = seq
              end
              if type(row.kind) ~= "string" or row.kind == "" then
                  failures[#failures + 1] = "missing kind at " .. tostring(index)
              end
              for key, value in pairs(row) do
                  local valueType = type(value)
                  if valueType ~= "string" and valueType ~= "number"
                      and valueType ~= "boolean" then
                      failures[#failures + 1] = "non-scalar " .. tostring(key)
                          .. " at " .. tostring(index)
                  end
              end
              if type(row.dedupe) == "string" and row.dedupe ~= "" then
                  if seen[row.dedupe] then
                      failures[#failures + 1] = "duplicate dedupe " .. row.dedupe
                  end
                  seen[row.dedupe] = true
              end
          end
      end
      if type(root.summary) ~= "table" then
          failures[#failures + 1] = "summary is " .. type(root.summary)
      else
          for key, value in pairs(root.summary) do
              if tonumber(value) == nil or tonumber(value) < 0 then
                  failures[#failures + 1] = "invalid summary " .. tostring(key)
              end
          end
      end
      if tonumber(root.next_seq) == nil then
          failures[#failures + 1] = "next_seq missing or invalid"
      elseif tonumber(root.next_seq) <= previous then
          failures[#failures + 1] = "next_seq does not advance"
      end
      local dedupeOk, dedupeDetail =
          mod.exports.__beta26.RunHistory.dedupeIndexMatches(root)
      if dedupeOk ~= true then
          failures[#failures + 1] =
              "dedupe index mismatch:" .. tostring(dedupeDetail)
      end
      return { ok = #failures == 0, failures = failures, events = #root.events }
  end
  
  mod.exports.nuzlocke_run_history = {
      version = 2,
      audited_recomp = mod.exports.__beta26.recompCompatAudited,
      list = mod.exports.__beta26.RunHistory.list,
      report = mod.exports.__beta26.RunHistory.report,
      statistics = mod.exports.__beta26.RunHistory.statistics,
      achievement_evidence = mod.exports.__beta26.RunHistory.achievementEvidence,
      record = function(kind, payload, opts)
          return mod.exports.__beta26.RunHistory.append(
              deps.currentGame() or mod.game, kind, payload, opts)
      end,
      event = "nuzlocke.run_history",
      kinds = {
          "pokemon.caught", "pokemon.died", "encounter.failed",
          "badge.earned", "forgiveness.awarded", "forgiveness.used",
          "run.blackout", "run.completed", "run.abandoned", "note",
      },
      statistics_version = 1,
      statistics_contract =
          "durable aggregates survive bounded journal pruning; partial coverage is explicit",
  }
  
  -- Initialize before ordinary run events whenever possible. Gold/Silver NEW
  -- GAME can replace the mod.save backing after game.ready, so save.created is
  -- also a required boundary. This is metadata initialization only; it does
  -- not synthesize historical rows for an existing run.
  mod.events:on("game.ready", function(payload)
      pcall(mod.exports.__beta26.RunHistory.ensure,
          type(payload) == "table" and payload.game or deps.currentGame() or mod.game)
  end)
  mod.events:on("save.loaded", function(payload)
      pcall(mod.exports.__beta26.RunHistory.ensure,
          type(payload) == "table" and payload.game or deps.currentGame() or mod.game)
  end)
  mod.events:on("save.created", function(payload)
      pcall(mod.exports.__beta26.RunHistory.ensure,
          type(payload) == "table" and payload.game or deps.currentGame() or mod.game)
  end)
  return mod.exports.__beta26.RunHistory
end
