-- Module owner: ClassicUI
return function(mod, deps)
  local unpackValues = table.unpack or unpack
  assert(type(unpackValues) == "function", "Nuzlocke requires Lua unpack support")
  deps = deps or {}
  local Strings = assert(deps.Strings, "classic_ui requires Strings")
  local getCurrentGame = assert(deps.getCurrentGame, "classic_ui requires getCurrentGame")
  local getCurrentSave = assert(deps.getCurrentSave, "classic_ui requires getCurrentSave")
  local saveBlocked = assert(deps.saveBlocked, "classic_ui requires saveBlocked")
  local active = assert(deps.active, "classic_ui requires active")
  local activeCompatProvider = assert(deps.activeCompatProvider, "classic_ui requires activeCompatProvider")
  local providerExclusive = assert(deps.providerExclusive, "classic_ui requires providerExclusive")
  local isTrainerDefinition = assert(deps.isTrainerDefinition, "classic_ui requires isTrainerDefinition")
  local wrapText = assert(deps.wrapText, "classic_ui requires wrapText")
  local ALL_ROUTES = assert(deps.ALL_ROUTES, "classic_ui requires ALL_ROUTES")
  local ROUTE_ORDER = assert(deps.ROUTE_ORDER, "classic_ui requires ROUTE_ORDER")
  local GEN1_SEED_IDS = assert(deps.GEN1_SEED_IDS, "classic_ui requires GEN1_SEED_IDS")
  local routeKey = assert(deps.routeKey, "classic_ui requires routeKey")
  local registerArea = assert(deps.registerArea, "classic_ui requires registerArea")
  local isTrackedArea = assert(deps.isTrackedArea, "classic_ui requires isTrackedArea")
  local routeName = assert(deps.routeName, "classic_ui requires routeName")
  local discoverAllKnownAreas = assert(deps.discoverAllKnownAreas, "classic_ui requires discoverAllKnownAreas")
  local caughtAreas = assert(deps.caughtAreas, "classic_ui requires caughtAreas")
  local trackerLog = assert(deps.trackerLog, "classic_ui requires trackerLog")
  local areaKey = assert(deps.areaKey, "classic_ui requires areaKey")
  local markVisited = assert(deps.markVisited, "classic_ui requires markVisited")
  local collectLegacyMons = assert(deps.collectLegacyMons, "classic_ui requires collectLegacyMons")
  local Identity = assert(deps.Identity, "classic_ui requires Identity")
  local ID_REGISTRY_KEY = assert(deps.ID_REGISTRY_KEY, "classic_ui requires ID_REGISTRY_KEY")
  local identityRegistry = assert(deps.identityRegistry, "classic_ui requires identityRegistry")
  local ensurePokemonIdentity = assert(deps.ensurePokemonIdentity, "classic_ui requires ensurePokemonIdentity")
  local pokemonIdentity = assert(deps.pokemonIdentity, "classic_ui requires pokemonIdentity")
  local setPokemonOrigin = assert(deps.setPokemonOrigin, "classic_ui requires setPokemonOrigin")
  local baselineAdd = assert(deps.baselineAdd, "classic_ui requires baselineAdd")
  local legacyCandidates = assert(deps.legacyCandidates, "classic_ui requires legacyCandidates")
  local ruleCategories = assert(deps.ruleCategories, "classic_ui requires ruleCategories")
  local LockePreset = assert(deps.LockePreset, "classic_ui requires LockePreset")
  local defaultRuleValue = assert(deps.defaultRuleValue, "classic_ui requires defaultRuleValue")
  local legacyLevelCapScope = assert(deps.legacyLevelCapScope, "classic_ui requires legacyLevelCapScope")
  local worldTier = assert(deps.worldTier, "classic_ui requires worldTier")
  local levelCapScope = assert(deps.levelCapScope, "classic_ui requires levelCapScope")
  local championDefeated = assert(deps.championDefeated, "classic_ui requires championDefeated")
  local nextLevelCapInfo = assert(deps.nextLevelCapInfo, "classic_ui requires nextLevelCapInfo")
  local nextLevelCap = assert(deps.nextLevelCap, "classic_ui requires nextLevelCap")
  local Difficulty = assert(deps.Difficulty, "classic_ui requires Difficulty")
  local countTrackerCatches = assert(deps.countTrackerCatches, "classic_ui requires countTrackerCatches")
  local countCaughtAreas = assert(deps.countCaughtAreas, "classic_ui requires countCaughtAreas")
  local countVisitedAreas = assert(deps.countVisitedAreas, "classic_ui requires countVisitedAreas")
  local getConfigValue = assert(deps.getConfigValue, "classic_ui requires getConfigValue")
  local marqueeText = assert(deps.marqueeText, "classic_ui requires marqueeText")
  local uiRememberedScreen = assert(deps.uiRememberedScreen, "classic_ui requires uiRememberedScreen")
  local externalRuleDelegation = deps.externalRuleDelegation

  -- 2.6.29: this module owns the bounded pixel fit used by NUZ STATUS.
  -- The pre-split helper lived in main.lua; keeping a module-local copy avoids
  -- a lexical/global dependency while preserving the same native Font budget.
  local function fitPixelText(text, budget)
      local Font = mod.ui.Font
      text = Strings(tostring(text or ""))
      budget = math.max(0, tonumber(budget) or 0)
      if type(Font.width) ~= "function"
          or type(Font.split) ~= "function"
          or type(Font.spansFitting) ~= "function"
          or Font.width(text) <= budget then
          return text
      end
      local spans = Font.split(text)
      if type(spans) ~= "table" or #spans == 0 then return text end
      local fit = math.max(0, tonumber(Font.spansFitting(spans, budget)) or 0)
      if fit <= 0 then return "" end
      local last = spans[math.min(#spans, fit)]
      return last and last.to and text:sub(1, last.to) or ""
  end

  local isTownArea
  local getDisplayRoutes
  local refreshGymGuideVisibility
  local function getGameVersion(...)
      local fn = deps.getGameVersion and deps.getGameVersion() or nil
      if type(fn) == "function" then return fn(...) end
      return nil
  end
  local function getEncounterState(...)
      local fn = deps.getEncounterState and deps.getEncounterState() or nil
      if type(fn) == "function" then return fn(...) end
      return nil
  end

  -- BUILD DISPLAY ROUTE LIST
  -- RouteList OFF: only visited/caught areas are shown.
  -- RouteList ON: every tracked area is shown.
  ---------------------------------------------------------------------
  local function syncCurrentArea(game)
      if not game then
          return
      end

      discoverAllKnownAreas(game)

      -- Check every save/runtime representation of the current location.
      -- Different engine paths populate these at slightly different times
      -- during map transitions, so relying on only one of them can miss a city
      -- on an older save.
      local candidates = {}

      if game.overworld and game.overworld.map then
          candidates[#candidates + 1] = game.overworld.map.id
      end

      if game.world and game.world.map then
          candidates[#candidates + 1] = game.world.map.id
      end

      if game.save and game.save.player then
          candidates[#candidates + 1] = game.save.player.map
      end

      if game.save and type(game.save.lastOutdoor) == "table" then
          candidates[#candidates + 1] = game.save.lastOutdoor.id
      end

      for _, rawId in ipairs(candidates) do
          local key = registerArea(rawId)
          if key then
              markVisited(key)
          end
      end
  end

  do -- compiler-budget scope: town classifier
  local TOWN_AREA_IDS = {
      PALLET_TOWN = true, VIRIDIAN_CITY = true, PEWTER_CITY = true,
      CERULEAN_CITY = true, VERMILION_CITY = true, LAVENDER_TOWN = true,
      FUCHSIA_CITY = true, CELADON_CITY = true, SAFFRON_CITY = true,
      CINNABAR_ISLAND = true,
  }

  local TOWN_PREFIXES = {
      -- Keep "vermillion" as a common custom-map misspelling for tolerance;
      -- canonical Gen 1 IDs continue to use the correct "vermilion".
      "pallet", "viridian", "pewter", "cerulean", "vermillion",
      "vermilion", "lavender", "fuchsia", "celadon", "saffron",
      "cinnabar",
  }

  local TOWN_INTERIOR_WORDS = {
      "mart", "pokemart", "poke mart", "pokemon mart", "pkmn mart",
      "center", "pokemon center", "pokecenter", "poke center",
      "gym", "hotel", "house", "lab", "museum", "shop", "gate",
      "dept store", "department store", "game corner", "bike shop",
      "fishing guru", "name rater",
  }

  isTownArea = function(id, name)
      id = tostring(id or "")
      if TOWN_AREA_IDS[id] then return true end

      local text = tostring(name or id or ""):lower()
      text = text:gsub("_+", " ")
      text = text:gsub("([a-z])([A-Z])", "%1 %2"):lower()
      if text:find("city", 1, true)
          or text:find("town", 1, true)
          or text:find("village", 1, true) then
          return true
      end

      -- Treat named town/city interiors as town locations even when their
      -- individual map ID has no CITY/TOWN suffix (e.g. CeruleanMart4).
      local hasTownPrefix = false
      for _, prefix in ipairs(TOWN_PREFIXES) do
          if text:find(prefix, 1, true) == 1 then
              hasTownPrefix = true
              break
          end
      end
      if hasTownPrefix then
          for _, word in ipairs(TOWN_INTERIOR_WORDS) do
              if text:find(word, 1, true) then return true end
          end
      end

      return false
  end

  end -- town classifier scope

  local function areaAllowedByConfig(area)
      if not area then
          return false
      end

      local routeFamily = mod.exports.__beta26.splitFamilyFor(area.id)
      if routeFamily and routeFamily.parent:match("^ROUTE_%d+$") then
          local selector = routeFamily.selector
          return selector ~= nil and mod.exports.__beta26.routeSplitActive(selector)
      end
      if mod.exports.__beta26.routeCardinalAxes[area.id] then
          local selectedFamily = mod.exports.__beta26.encounterSplitAreas[
              "route_" .. tostring(area.id):match("ROUTE_(%d+)")]
          local splitOn = selectedFamily and selectedFamily.selector
              and mod.exports.__beta26.routeSplitActive(selectedFamily.selector)
          return not splitOn
              or (type(trackerLog()[area.id]) == "table"
                  and #trackerLog()[area.id] > 0)
              or caughtAreas()[area.id] ~= nil
              or (type(mod.save:get("encounter_states", {})) == "table"
                  and mod.save:get("encounter_states", {})[area.id] ~= nil)
      end

      local moon = mod.exports.__beta26.encounterSplitAreas.mt_moon
      local moonMode = math.max(0, math.min(1,
          math.floor(tonumber(mod.save:get("mt_moon_splits", 0)) or 0)))
      if area.id == moon.parent then
          return moonMode == 0
              or (type(trackerLog()[moon.parent]) == "table"
                  and #trackerLog()[moon.parent] > 0)
              or caughtAreas()[moon.parent] ~= nil
              or (type(mod.save:get("encounter_states", {})) == "table"
                  and mod.save:get("encounter_states", {})[moon.parent] ~= nil)
      end
      if moon.members[area.id] then return moonMode == 1 end

      local safari = mod.exports.__beta26.encounterSplitAreas.safari
      local safariMode = type(mod.exports.__beta26.safariClauseMode) == "function"
          and mod.exports.__beta26.safariClauseMode()
          or math.max(0, math.min(3, math.floor(tonumber(
              mod.save:get("safari_zone_splits", 0)) or 0)))
      if area.id == safari.parent then
          return (safariMode == 0 or safariMode == 2)
              or (type(trackerLog()[safari.parent]) == "table"
                  and #trackerLog()[safari.parent] > 0)
              or caughtAreas()[safari.parent] ~= nil
              or (type(mod.save:get("encounter_states", {})) == "table"
                  and mod.save:get("encounter_states", {})[safari.parent] ~= nil)
      end
      if safari.members[area.id] then return safariMode == 1 or safariMode == 3 end

      -- Pallet Town and New Bark Town are the mandatory starter hometown
      -- slots for their respective generations. Keep them visible on the
      -- encounter MAP even when ordinary town catches are disabled.
      if area.id == "NEW_BARK_TOWN"
          and mod.exports.__beta26.runtimeIsGen2(getCurrentGame()) then return true end
      if area.id == "PALLET_TOWN"
          and not mod.exports.__beta26.runtimeIsGen2(getCurrentGame()) then return true end

      if isTownArea(area.id, area.name) and not mod.save:get("town_catches", false) then
          -- Existing evidence must never disappear merely because the player
          -- later turns Town Catches OFF.
          local states = mod.save:get("encounter_states", {})
          local hasEvidence = (type(trackerLog()[area.id]) == "table" and #trackerLog()[area.id] > 0)
              or caughtAreas()[area.id] ~= nil
              or (type(states) == "table" and states[area.id] ~= nil)
          if not hasEvidence then return false end
      end
      return true
  end

  -- 2.7.95: the host Gen-2 map table is an engine/catalog order, not a
  -- player-facing progression order. The MAP page must read like a normal
  -- Gold/Silver/Crystal journey: Johto progression first, then Kanto, then
  -- genuinely custom/unknown encounter areas. This is display-only; physical
  -- area keys, provenance, encounter legality and tracker storage are unchanged.
  local GEN2_TRACKER_ORDER = {
      -- Johto opening / Violet
      "NEW_BARK_TOWN", "ROUTE_29", "CHERRYGROVE_CITY", "ROUTE_30",
      "ROUTE_31", "DARK_CAVE", "VIOLET_CITY", "SPROUT_TOWER",
      "RUINS_OF_ALPH", "ROUTE_32", "UNION_CAVE",
      -- Azalea / Goldenrod
      "ROUTE_33", "AZALEA_TOWN", "SLOWPOKE_WELL", "ILEX_FOREST",
      "ROUTE_34", "GOLDENROD_CITY", "ROUTE_35", "NATIONAL_PARK",
      "ROUTE_36", "ROUTE_37",
      -- Ecruteak / Olivine / Cianwood
      "ECRUTEAK_CITY", "BURNED_TOWER", "BURNT_TOWER", "TIN_TOWER",
      "BELL_TOWER", "ROUTE_38", "ROUTE_39", "OLIVINE_CITY",
      "OLIVINE_LIGHTHOUSE", "ROUTE_40", "ROUTE_41", "WHIRL_ISLANDS",
      "CIANWOOD_CITY",
      -- Mahogany / Blackthorn / League approach
      "ROUTE_42", "MT_MORTAR", "MAHOGANY_TOWN", "ROUTE_43",
      "LAKE_OF_RAGE", "ROUTE_44", "ICE_PATH", "BLACKTHORN_CITY",
      "DRAGONS_DEN", "ROUTE_45", "ROUTE_46", "ROUTE_27",
      "TOHJO_FALLS", "ROUTE_26", "VICTORY_ROAD", "INDIGO_PLATEAU",
      -- Kanto return, in the usual Gen-2 traversal order.
      "VERMILION_CITY", "ROUTE_6", "SAFFRON_CITY", "ROUTE_7",
      "CELADON_CITY", "ROUTE_16", "ROUTE_17", "ROUTE_18",
      "FUCHSIA_CITY", "ROUTE_15", "ROUTE_14", "ROUTE_13",
      "ROUTE_12", "LAVENDER_TOWN", "ROUTE_10", "POWER_PLANT",
      "ROCK_TUNNEL", "ROUTE_8", "ROUTE_5", "CERULEAN_CITY",
      "ROUTE_24", "ROUTE_25", "ROUTE_9", "ROUTE_4", "MT_MOON",
      "PEWTER_CITY", "ROUTE_3", "ROUTE_2", "VIRIDIAN_FOREST",
      "VIRIDIAN_CITY", "ROUTE_1", "PALLET_TOWN", "ROUTE_21",
      "CINNABAR_ISLAND", "ROUTE_20", "SEAFOAM_ISLANDS", "ROUTE_19",
      "ROUTE_22", "ROUTE_28", "MT_SILVER", "SILVER_CAVE",
  }
  local GEN2_TRACKER_RANK = {}
  for i, id in ipairs(GEN2_TRACKER_ORDER) do GEN2_TRACKER_RANK[id] = i end

  local function gen2EncounterAreaSet(game)
      if not mod.exports.__beta26.runtimeIsGen2(game) then return nil end
      local data = game and game.data
      if type(data) ~= "table" then return {} end
      local registry = data.gen2Encounters or data.encountersByMap
          or data.wildEncounters or data.encounters
      local out = {}
      if type(registry) == "table" then
          for rawId in pairs(registry) do
              if type(rawId) == "string" then
                  local id = routeKey(rawId) or rawId
                  out[id] = true
              end
          end
      end
      return out
  end

  local function gen2TrackerRank(id)
      id = tostring(id or ""):upper()
      local direct = GEN2_TRACKER_RANK[id]
      if direct then return direct * 100 end
      -- Evidence-backed interiors/custom submaps should follow their parent
      -- town/landmark rather than jumping to the beginning of MAP because of
      -- ROM bank order. Example: OLIVINE_CAFE sorts after OLIVINE_CITY.
      for parent, rank in pairs(GEN2_TRACKER_RANK) do
          local stem = parent:gsub("_CITY$", ""):gsub("_TOWN$", "")
          if #stem >= 4 and id:find(stem, 1, true) then
              return rank * 100 + 50
          end
      end
      local route = tonumber(id:match("^ROUTE_(%d+)"))
      if route then return 900000 + route end
      return 999999
  end

  local function gen2DisplayOrder(game)
      if not mod.exports.__beta26.runtimeIsGen2(game) then return nil, nil end
      local data = game and game.data
      local constants = type(data) == "table" and data.gen2Constants or nil
      local order = type(constants) == "table" and constants.mapOrder or nil
      local allowed = {}
      if type(order) == "table" then
          for _, raw in ipairs(order) do
              local id = type(raw) == "table" and (raw.id or raw.map or raw.key) or raw
              if type(id) == "string" and id ~= "" then allowed[id] = true end
          end
      end
      return GEN2_TRACKER_RANK, allowed, gen2EncounterAreaSet(game)
  end

  getDisplayRoutes = function(game)
      if type(mod.exports.__beta26.ensureEncounterProjection) == "function" then
          pcall(mod.exports.__beta26.ensureEncounterProjection)
      end
      syncCurrentArea(game)
      local list = {}
      local gen2Rank, gen2Allowed, gen2EncounterAreas = gen2DisplayOrder(game)

      -- 2.7.101: MAP is prospective, not a visited-area log.
      if mod.exports.__beta26.runtimeIsGen2(game) then
          for _, id in ipairs(GEN2_TRACKER_ORDER) do registerArea(id) end
      end

      for _, r in ipairs(ALL_ROUTES) do
          -- On Gold/Silver, only show maps that actually belong to the active
          -- Gen II map catalog. This removes the Gen I seed rows (Pallet, Route
          -- 1, etc.) until their real Gen II Kanto counterparts occur in the
          -- host map order. Dynamically discovered custom maps remain visible.
          local permitted = true
          if mod.exports.__beta26.runtimeIsGen2(game) then
              local states = mod.save:get("encounter_states", {})
              local seen = mod.save:get("visited_areas", {})
              local hasTrackerEvidence =
                  (type(trackerLog()[r.id]) == "table" and #trackerLog()[r.id] > 0)
                  or caughtAreas()[r.id] ~= nil
                  or (type(states) == "table" and states[r.id] ~= nil)
              local hasEvidence = (type(seen) == "table" and seen[r.id] == true)
                  or hasTrackerEvidence
              local interior = tostring(r.id or ""):upper()
              local ordinaryInterior = interior:find("HOUSE", 1, true)
                  or interior:find("LAB", 1, true)
                  or interior:find("MART", 1, true)
                  or interior:find("CENTER", 1, true)
                  or interior:find("GYM", 1, true)
                  or interior:find("GATE", 1, true)
                  or interior:find("BEDROOM", 1, true)
                  or interior:find("ROOM", 1, true)
                  or interior:find("OFFICE", 1, true)
                  or interior:find("CAFE", 1, true)
                  or interior:find("SHOP", 1, true)
              local isEncounterArea = type(gen2EncounterAreas) == "table"
                  and gen2EncounterAreas[r.id] == true
              if ordinaryInterior and not hasTrackerEvidence then
                  permitted = false
              elseif r.id == "NEW_BARK_TOWN" then
                  -- Mandatory starter hometown remains visible even though it
                  -- is not a wild encounter table.
                  permitted = true
              elseif GEN2_TRACKER_RANK[r.id] then
                  -- 2.7.101: MAP is prospective. The explicit canonical Gen2
                  -- progression catalog is authoritative for browseable areas;
                  -- it must not collapse to the evidence/visited subset when a
                  -- host encounter registry uses a different internal shape.
                  -- areaAllowedByConfig below still applies Town Catches and
                  -- every other active area rule before presentation.
                  permitted = true
              elseif GEN1_SEED_IDS[r.id] then
                  permitted = hasEvidence or isEncounterArea
              elseif gen2Allowed then
                  permitted = isEncounterArea or hasEvidence
              else
                  permitted = isEncounterArea or hasEvidence
              end
          end
          if permitted and areaAllowedByConfig(r) then
              table.insert(list, r)
          end
      end

      table.sort(list, function(a, b)
          local ao = gen2Rank and gen2TrackerRank(a.id)
              or (ROUTE_ORDER[a.id] or 999999)
          local bo = gen2Rank and gen2TrackerRank(b.id)
              or (ROUTE_ORDER[b.id] or 999999)
          if ao == bo then return tostring(a.name) < tostring(b.name) end
          return ao < bo
      end)

      if mod.exports.__beta26.runtimeIsGen2(game)
          and type(mod.exports.__beta26.noteGen2AdapterReach) == "function" then
          local palletVisible = false
          for _, row in ipairs(list) do
              if row.id == "PALLET_TOWN" then palletVisible = true break end
          end
          pcall(mod.exports.__beta26.noteGen2AdapterReach, "tracker_map_render",
              { count=#list, pallet_visible=palletVisible })
      end
      return list
  end

  -- beta.26 canonical starter cleanup: older diagnostic runs could record
  -- the same starter in PALLET_TOWN and OAKS_LAB. Remove only the provable
  -- duplicate starter row; never delete unrelated custom-area catches.
  mod.exports.__beta26.cleanupStarterDuplicate = function()
      local log = trackerLog()
      local pallet = log["PALLET_TOWN"]
      if type(pallet) ~= "table" or #pallet == 0 then return false end

      -- Keep this helper self-contained. In earlier B7 code it referenced the
      -- later local mod.exports.__beta26.isStarterSpecies() definition and therefore resolved a nil
      -- global from this earlier lexical position.
      local starters = {}
      for _, entry in ipairs(pallet) do
          local sp = tostring(entry and entry.species or ""):upper()
          if sp == "BULBASAUR" or sp == "CHARMANDER" or sp == "SQUIRTLE"
              or sp == "PIKACHU" then
              starters[sp] = true
          end
      end
      if next(starters) == nil then return false end

      local changed = false
      local areas = caughtAreas()
      local states = mod.save:get("encounter_states", {})
      if type(states) ~= "table" then states = {} end

      for key, entries in pairs(log) do
          local k = tostring(key or ""):upper()
          if key ~= "PALLET_TOWN" and type(entries) == "table"
              and (k:find("OAK", 1, true) or k:find("LAB", 1, true)) then
              local kept = {}
              local removedStarter = false
              for _, entry in ipairs(entries) do
                  local sp = tostring(entry and entry.species or ""):upper()
                  if starters[sp] then
                      changed = true
                      removedStarter = true
                  else
                      kept[#kept + 1] = entry
                  end
              end
              if #kept > 0 then log[key] = kept else log[key] = nil end
              if removedStarter and starters[tostring(areas[key] or ""):upper()] then
                  areas[key] = nil
              end
              local st = states[key]
              if removedStarter and type(st) == "table"
                  and starters[tostring(st.species or ""):upper()] then
                  states[key] = nil
              end
          end
      end

      if changed then
          mod.save:set("tracker_log", log)
          mod.save:set("caught_areas", areas)
          mod.save:set("encounter_states", states)
      end
      return changed
  end

  ---------------------------------------------------------------------
  -- TRACKER DEATH PROJECTION
  --
  -- Tracker rows describe the encounter/catch event, while nuzlocke_history
  -- owns later lifecycle events. Project DEAD history back onto the exact
  -- caught Pokemon by persistent pokemonId so removing a dead Pokemon from
  -- the party cannot make its area row look alive again.
  --
  -- Legacy rows without IDs get a conservative fallback only when one
  -- same-species catch exists in the recorded catch area.
  ---------------------------------------------------------------------
  mod.exports.__beta26.syncTrackerDeathProjection = function()
      local history = mod.save:get("nuzlocke_history", {})
      local log = trackerLog()
      if type(history) ~= "table" or type(log) ~= "table" then return false end

      local deadById = {}
      local legacyDead = {}
      for _, row in ipairs(history) do
          if type(row) == "table" and row.status == "DEAD" then
              if row.pokemonId ~= nil then
                  deadById[tostring(row.pokemonId)] = row
              elseif row.catchLocation ~= nil and row.species ~= nil then
                  legacyDead[#legacyDead + 1] = row
              end
          end
      end

      local changed = false
      local function applyDeath(catch, row)
          if type(catch) ~= "table" or type(row) ~= "table" then return end
          if catch.dead ~= true or catch.status ~= "DEAD"
              or catch.deathCause ~= row.deathCause
              or catch.deathLocation ~= row.deathLocation then
              catch.dead = true
              catch.status = "DEAD"
              catch.deathCause = row.deathCause
              catch.deathLocation = row.deathLocation
              catch.deathOpponentSpecies = row.deathOpponentSpecies
              catch.deathMove = row.deathMove
              catch.deathCritical = row.deathCritical
              catch.deathStatusCondition = row.deathStatusCondition
              changed = true
          end
      end

      for _, entries in pairs(log) do
          if type(entries) == "table" then
              for _, catch in ipairs(entries) do
                  if type(catch) == "table" and catch.pokemonId ~= nil then
                      local row = deadById[tostring(catch.pokemonId)]
                      if row then applyDeath(catch, row) end
                  end
              end
          end
      end

      -- Pre-ID compatibility: only mark when catchLocation + species resolves
      -- to exactly one saved tracker row. Ambiguous old data is left alone.
      for _, row in ipairs(legacyDead) do
          local area = routeKey(row.catchLocation) or row.catchLocation
          local entries = log[area]
          if type(entries) == "table" then
              local candidate, count = nil, 0
              for _, catch in ipairs(entries) do
                  if type(catch) == "table"
                      and tostring(catch.species or ""):upper()
                          == tostring(row.species or ""):upper() then
                      candidate = catch
                      count = count + 1
                  end
              end
              if count == 1 then applyDeath(candidate, row) end
          end
      end

      if changed then mod.save:set("tracker_log", log) end
      return changed
  end

  ---------------------------------------------------------------------
  -- TRACKER DISPLAY ROWS
  -- The save is grouped by area, but the tracker is displayed row-by-row.
  -- Never comma-join multiple catches from the same area.
  ---------------------------------------------------------------------
  local function getTrackerLogRows(prepared)
      if prepared ~= true then
          if type(mod.exports.__beta26.ensureEncounterProjection) == "function" then
              pcall(mod.exports.__beta26.ensureEncounterProjection)
          end
          mod.exports.__beta26.cleanupStarterDuplicate()
      end
      local log = trackerLog()
      local states = mod.save:get("encounter_states", {})
      if type(states) ~= "table" then states = {} end
      local keys, known = {}, {}
      for key, entries in pairs(log) do
          if type(entries) == "table" and #entries > 0 then
              table.insert(keys, key)
              known[key] = true
          end
      end
      -- Failed encounters are real route outcomes even without a catch.
      -- Surface them in LOG instead of leaving the route visually blank.
      for key, state in pairs(states) do
          if key ~= "__LEGACY__" and not known[key]
              and type(state) == "table" and state.status == "FAILED" then
              table.insert(keys, key)
              known[key] = true
          end
      end
      table.sort(keys, function(a, b)
          local ao = (a == "__LEGACY__") and 999998 or (ROUTE_ORDER[a] or 999999)
          local bo = (b == "__LEGACY__") and 999998 or (ROUTE_ORDER[b] or 999999)
          if ao == bo then return tostring(a) < tostring(b) end
          return ao < bo
      end)
      local rows = {}
      for _, key in ipairs(keys) do
          local entries = log[key]
          if type(entries) == "table" and #entries > 0 then
              for _, catch in ipairs(entries) do
                  if type(catch) == "table" then
                      table.insert(rows, { area = key, catch = catch })
                  end
              end
          else
              local state = states[key]
              if type(state) == "table" and state.status == "FAILED" then
                  table.insert(rows, { area = key, catch = {
                      species = state.species,
                      encounterType = state.encounterType or "wild",
                      failed = true,
                  } })
              end
          end
      end
      return rows
  end

  local function getTrackerMapRows(game, prepared)
      if prepared ~= true then
          mod.exports.__beta26.cleanupStarterDuplicate()
      end
      local log = trackerLog()
      local states = mod.save:get("encounter_states", {})
      if type(states) ~= "table" then states = {} end
      local rows = {}
      -- Display evidence priority: tracker_log > FAILED encounter_state >
      -- caught_areas legacy/retroactive fallback > unknown.
      for _, route in ipairs(getDisplayRoutes(game)) do
          local catches = log[route.id]
          if type(catches) == "table" and #catches > 0 then
              for _, catch in ipairs(catches) do
                  if type(catch) == "table" then
                      table.insert(rows, { area = route, catch = catch })
                  end
              end
          else
              local state = states[route.id]
              if type(state) == "table" and state.status == "FAILED" then
                  table.insert(rows, { area = route, catch = {
                      species = state.species,
                      encounterType = state.encounterType or "wild",
                      failed = true,
                  } })
              elseif caughtAreas()[route.id] ~= nil then
                  table.insert(rows, { area = route, catch = {
                      species = caughtAreas()[route.id],
                      encounterType = "unknown",
                      retroactive = true,
                  } })
              else
                  table.insert(rows, { area = route, catch = nil })
              end
          end
      end
      return rows
  end

  ---------------------------------------------------------------------
  -- 2.6.5 compact read-only status/diagnostic presentation helpers.
  -- Every caller applies its own pixel/tile clipping; these helpers only
  -- normalize state so Gen 1 and Gen 2 surfaces present the same facts.
  ---------------------------------------------------------------------
  local function nuzStatusEncounterSnapshot(game)
      local key = areaKey(game, nil)
      local label = key and routeName(key) or Strings("UNKNOWN")
      local status = "OPEN"
      if key and caughtAreas()[key] ~= nil then
          status = "CAUGHT"
      else
          local state = key and getEncounterState(key) or nil
          if type(state) == "table" and state.status == "FAILED" then
              status = "FAILED"
          end
      end
      return tostring(label or key or "UNKNOWN"), status
  end

  local function nuzStatusLastHistoryEvent(game)
      local history = mod.exports.__beta26.RunHistory
      local storageKey = history and history.storage_key
      if type(storageKey) ~= "string" then return "NONE" end
      local root = mod.save:get(storageKey, nil)
      local rows = type(root) == "table" and root.events or nil
      if type(rows) ~= "table" or #rows == 0 then return "NONE" end
      local row = rows[#rows]
      local kind = tostring(row.kind or "EVENT")
      local name = tostring(row.name or row.species or row.target or row.area or "")
      local labels = {
          ["pokemon.caught"] = "CAUGHT", ["pokemon.died"] = "DIED",
          ["forgiveness.awarded"] = "TOKEN+", ["forgiveness.used"] = "TOKEN-",
          ["badge.earned"] = "BADGE", ["run.blackout"] = "BLACKOUT",
          ["run.completed"] = "COMPLETE",
      }
      local label = labels[kind] or kind:upper():gsub("^.-%.", "")
      return name ~= "" and (label .. " " .. name) or label
  end

  local function nuzStatusTokenBalance()
      local fn = mod.exports.__beta26.forgivenessTokens
      if type(fn) ~= "function" and mod.exports.__beta26.TrainerRewards then
          fn = mod.exports.__beta26.TrainerRewards.forgivenessTokens
      end
      local ok, value = false, 0
      if type(fn) == "function" then ok, value = pcall(fn) end
      return math.max(0, math.floor(tonumber(value) or 0))
  end

  local function nuzCompatIdentityLine(game)
      local edition = mod.exports.__beta26.Dev.gameLabel(game)
      return tostring(edition) .. " / G1R "
          .. tostring(mod.exports.__beta26.recompCompatAudited or "?")
          .. " / NUZ " .. tostring(mod.exports.__beta26.build or "?")
  end

  local function nuzTrackerSummary(rows)
      local summary = { open = 0, caught = 0, failed = 0 }
      for _, row in ipairs(type(rows) == "table" and rows or {}) do
          local catch = type(row) == "table" and row.catch or nil
          if catch == nil then
              summary.open = summary.open + 1
          elseif type(catch) ~= "table" then
              -- Legacy/provider rows may contain a bare species token instead
              -- of the canonical catch table. Count them as occupied/caught
              -- rather than indexing the malformed value and crashing UI.
              summary.caught = summary.caught + 1
          elseif catch.failed == true or catch.status == "FAILED" then
              summary.failed = summary.failed + 1
          else
              summary.caught = summary.caught + 1
          end
      end
      return summary
  end


  -- 2.6.72: preserve the engine ListMenu as the state/input owner while
  -- giving Nuzlocke informational lists the same readable title/header
  -- treatment already proven on NUZ INFO.
  local function decorateNativeInfoList(menu, title, opts)
      if type(menu) ~= "table" or type(menu.draw) ~= "function" then return menu end
      opts = type(opts) == "table" and opts or {}
      local baseDraw = menu.draw

      local function trackedWidth(Font, label, tracking)
          local spans = type(Font.split) == "function" and Font.split(label) or nil
          if type(spans) ~= "table" or #spans == 0 then
              return (type(Font.width) == "function" and Font.width(label)
                  or #tostring(label or "") * 8)
          end
          local width = 0
          for i, span in ipairs(spans) do
              local glyph = label:sub(span.from, span.to)
              width = width + (type(Font.width) == "function"
                  and Font.width(glyph) or 8)
              if i < #spans then width = width + tracking end
          end
          return width
      end

      local function centeredTrackedBold(Font, value, y, tracking)
          local label = Strings(tostring(value or ""))
          tracking = tracking or 1
          local spans = type(Font.split) == "function" and Font.split(label) or nil
          if type(spans) ~= "table" or #spans == 0 then
              local width = trackedWidth(Font, label, tracking)
              local x = math.max(8, math.floor((160 - width) / 2))
              Font.draw(label, x, y)
              Font.draw(label, x + 1, y)
              return
          end
          local x = math.max(8, math.floor((160 - trackedWidth(
              Font, label, tracking)) / 2))
          for i, span in ipairs(spans) do
              local glyph = label:sub(span.from, span.to)
              Font.draw(glyph, x, y)
              Font.draw(glyph, x + 1, y)
              x = x + (type(Font.width) == "function"
                  and Font.width(glyph) or 8)
              if i < #spans then x = x + tracking end
          end
      end

      menu.draw = function(self)
          baseDraw(self)
          local Font = require("src.render.Font")
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.rectangle("fill", 0, 0, 160, 15)
          love.graphics.setColor(0, 0, 0, 1)
          centeredTrackedBold(Font, title or self.title, 4, 1)

          if opts.headers == true then
              for row = 1, self.rows or 7 do
                  local index = (self.scroll or 0) + row
                  local item = self.items and self.items[index]
                  if type(item) == "table" and item.nuzlockeBoldHeader == true then
                      local y = 8 + row * 16
                      love.graphics.setColor(1, 1, 1, 1)
                      love.graphics.rectangle("fill", 0, y - 1, 160, 11)
                      love.graphics.setColor(0, 0, 0, 1)
                      centeredTrackedBold(Font, item.label or "", y, 1)
                  end
              end
          end
          love.graphics.setColor(1, 1, 1, 1)
      end
      return menu
  end

  local function pushNuzlockeRunHistoryViewer(game)
      local history = mod.exports.__beta26.RunHistory
      local storageKey = history and history.storage_key
      local root = type(storageKey) == "string" and mod.save:get(storageKey, nil) or nil
      local rows = type(root) == "table" and root.events or nil
      local items = {}
      local cap = nextLevelCap(game and game.save)
      items[#items + 1] = {
          label = cap >= 100 and Strings("CURRENT CAP MAX")
              or Strings("CURRENT CAP LV%d", cap),
          right = "",
      }
      local labels = {
          ["pokemon.caught"] = "CATCH",
          ["pokemon.died"] = "DEATH",
          ["badge.earned"] = "BADGE",
          ["forgiveness.awarded"] = "TOKEN+",
          ["forgiveness.used"] = "TOKEN-",
          ["run.blackout"] = "BLACKOUT",
          ["run.completed"] = "COMPLETE",
      }
      if type(rows) == "table" and #rows > 0 then
          local first = math.max(1, #rows - 99)
          for i = #rows, first, -1 do
              local row = rows[i]
              if type(row) == "table" then
                  local kind = tostring(row.kind or "EVENT")
                  local label = labels[kind] or kind:upper():gsub("^.-%.", "")
                  local detail = tostring(row.name or row.badge or row.species
                      or row.target or row.area or "")
                  if #detail > 12 then detail = detail:sub(1, 12) end
                  items[#items + 1] = {
                      label = Strings(detail ~= "" and (label .. " " .. detail) or label),
                      right = tostring(row.seq or ""),
                  }
              end
          end
      else
          items[#items + 1] = { label = Strings("NO EVENTS YET"), right = "" }
      end
      local menu = mod.ui.ListMenu.new(game, Strings("RUN HISTORY"), items, {
          kind = "nuzlocke_run_history", pageJump = true, wrap = false,
      })
      if type(menu) == "table" then
          menu.screenId = "NuzlockeRunHistoryScreen"
          menu.rows = mod.exports.__beta26.runtimeIsGen2(game) and 8 or 7
          menu.footer = Strings("B:BACK")
          if mod.exports.__beta26.runtimeIsGen2(game) and type(menu.draw) == "function" then
              -- 2.8.05: Gen II needs an actual Nuzlocke-owned framed renderer.
              -- The generic ListMenu draw path is intentionally native/minimal and
              -- produced the borderless RUN HISTORY screen seen in Crystal.
              menu.draw = function(self)
                  local Chrome = require("src.ui.gen2.Chrome")
                  local GoldFont = require("src.render.Font")
                  local UiSystem = mod.exports.__beta26.UiSystem
                  UiSystem.gen2ScreenFrame(Chrome, { headerRows = 3, footerRows = 2 })
                  mod.exports.__beta26.drawGen2NuzTitle(Chrome, GoldFont,
                      "RUN HISTORY", nil, { row = 1 })
                  local total = #(self.items or {})
                  local rowsVisible = 8
                  local index = math.max(1, math.min(math.max(1, total), self.index or 1))
                  local scroll = math.max(0, math.floor(tonumber(self.scroll) or 0))
                  if index <= scroll then scroll = index - 1 end
                  if index > scroll + rowsVisible then scroll = index - rowsVisible end
                  scroll = math.max(0, math.min(math.max(0, total - rowsVisible), scroll))
                  self.scroll = scroll
                  for slot = 1, rowsVisible do
                      local i = scroll + slot
                      local item = self.items and self.items[i]
                      if not item then break end
                      UiSystem.gen2Row(Chrome, GoldFont, {
                          label = item.label or "",
                          value = item.right or "",
                          focused = i == index,
                      }, { x = 2, y = 3 + slot - 1, rightCol = 18 })
                  end
                  if scroll > 0 then Chrome.cursor(18, 3, true) end
                  if scroll + rowsVisible < total then
                      GoldFont.drawCode(Chrome.DOWN_ARROW, 18 * 8, 14 * 8)
                  end
                  Chrome.print(Strings("B:BACK"), 7, 16)
              end
          else
              decorateNativeInfoList(menu, "RUN HISTORY")
          end
      end
      if game and game.stack and menu then game.stack:push(menu) end
      return menu
  end
  mod.exports.__beta26.pushRunHistoryViewer = pushNuzlockeRunHistoryViewer

  local function recordRunBlackout(game, source)
      if not (game and mod.exports.__beta26.canWriteNuzlockeSave(game)) then return false end
      local sequence = math.max(0, math.floor(tonumber(
          mod.save:get("nuzlocke_blackout_sequence", 0)) or 0)) + 1
      mod.save:set("nuzlocke_blackout_sequence", sequence)
      local history = mod.exports.__beta26.RunHistory
      if type(history) == "table" and type(history.recordBlackout) == "function" then
          local area = areaKey(game, nil)
          pcall(history.recordBlackout, game, {
              sequence = sequence, source = source,
              area = area and routeName(area) or nil,
              deaths = tonumber(mod.save:get("nuzlocke_losses", 0)) or 0,
          })
      end
      return true
  end

  ---------------------------------------------------------------------
  -- TRAINER CARD Nuzlocke status page
  --
  -- The vanilla Trainer Card remains the front page.  A flips to a live
  -- Nuzlocke status page whose rule list is read directly from mod.save.
  -- Changes made in the in-game RULES menu therefore appear immediately
  -- the next time this page is drawn.
  --
  -- MONEY intentionally stays off this page because it is already shown on
  -- the vanilla front of the Trainer Card.
  ---------------------------------------------------------------------
  mod.content.screens:register("NuzlockeTrainerCardScreen", {
      new = function(game, ctx)
          ctx = ctx or {}
          -- 2.1.18: statusOnly is the compatibility-safe START-menu surface.
          -- It never constructs or wraps the engine TrainerCard, so opening the
          -- native NAME/card row remains 100% upstream-owned. The historical
          -- combined card/status mode is retained only for compatibility with
          -- an external caller that explicitly requests it.
          local statusOnly = ctx.statusOnly == true
          local vanilla
          if not statusOnly then
              local okCard, TrainerCard = pcall(require, "src.ui.TrainerCard")
              if okCard and TrainerCard and type(TrainerCard.new) == "function" then
                  local okVanilla, card = pcall(TrainerCard.new, game, { onCancel = nil })
                  if okVanilla then vanilla = card end
              end
              -- If the native card cannot be constructed, degrade to the
              -- standalone status page instead of crashing the game.
              if not vanilla then statusOnly = true end
          end

          local self = {
              game = game,
              screenId = "NuzlockeTrainerCardScreen",
              vanilla = vanilla,
              statusOnly = statusOnly,
              isOpaque = true,
              nuzlockeStatusPage = statusOnly,
              ruleScroll = 0,
              ruleArrowTime = 0,
              ruleMarqueeTime = 0,
              ruleRevision = tonumber(mod.save:get("nuzlocke_rule_revision", 0)) or 0,
          }

          local function activeRuleSnapshot()
              -- The Trainer Card must use the exact same active-save state as
              -- the in-game Rules screen.  Never read the staged NEW GAME
              -- table here; once the save exists, mod.save is authoritative.
              local names = {}
              if mod.save:get("nuzlocke_enabled", true) ~= true then
                  local offLabel = Strings("Nuzlocke OFF")
                  local offNames = { offLabel }
                  local offGroups = {
                      { title = "CORE", names = { offLabel } }
                  }
                  -- World Building is an independent presentation option and
                  -- remains active when the challenge master switch is OFF.
                  local tier = math.max(0, math.min(3,
                      math.floor(tonumber(mod.save:get("world_building_tier",
                          defaultRuleValue("world_building_tier")))
                          or defaultRuleValue("world_building_tier"))))
                  if tier > 0 then
                      local worldLabel = Strings("World %s", Strings(
                          ({ [1] = "TIER 1", [2] = "TIER 2",
                             [3] = "TIER 3" })[tier]))
                      offNames[#offNames + 1] = worldLabel
                      offGroups[#offGroups + 1] = {
                          title = "WORLD",
                          names = { worldLabel },
                      }
                  end
                  return offNames, offGroups
              end
              local lockeType = math.max(0, math.min(6,
                  math.floor(tonumber(mod.save:get("locke_type",
                      defaultRuleValue("locke_type")))
                      or defaultRuleValue("locke_type"))))
              if lockeType > 0 then
                  names[#names + 1] = Strings("Loadout %s",
                      Strings(LockePreset.names[lockeType] or "CUSTOM"))
              end
              local function boolSetting(value)
                  if value == true then return true end
                  if type(value) == "number" then return value ~= 0 end
                  if type(value) == "string" then
                      local v = value:lower()
                      return v == "true" or v == "on" or v == "yes" or tonumber(v) == 1
                  end
                  return false
              end
              local function activeLabel(rule)
                  -- NUZ STATUS describes the challenge currently being played,
                  -- not the NEW GAME/setup form or utility/service controls.
                  -- setupOnly values are immutable launch configuration and
                  -- Gym Guide Candy is a convenience service, not a rule.
                  if rule.setupOnly == true or rule.key == "infinite_rare_candies" then
                      return nil
                  end
                  local value = getConfigValue(rule.key, false)
                  if rule.key == "nuzlocke_enabled"
                      or rule.key == "dev_mode" or rule.key == "catch_info"
                      or rule.key == "stat_info" or rule.key == "move_info"
                      or rule.key == "area_guide_enabled"
                      or rule.key == "battle_menu_ui" then
                      return nil
                  elseif rule.key == "world_building_tier" then
                      local tier = tonumber(value) or 0
                      if tier > 0 then return Strings("World %s", Strings(
                          ({ [1] = "TIER 1", [2] = "TIER 2", [3] = "TIER 3" })[tier])) end
                      return nil
                  elseif rule.key == "level_cap_scope" then
                      local rawScope = mod.save:get("level_cap_scope", nil)
                      local scope = rawScope == nil and legacyLevelCapScope() or (tonumber(rawScope) or 0)
                      if scope > 0 then return Strings("Level Caps %s", Strings(
                          ({ [1] = "GYMS", [2] = "E4", [3] = "CHAMP", [4] = "POST" })[scope])) end
                      return nil
                  elseif rule.key == "dupes_mode" then
                      local mode = tonumber(value) or 0
                      if mode == 1 then return Strings("Dupes SPEC") end
                      if mode == 2 then return Strings("Dupes FAM") end
                      return nil
                  elseif rule.key == "evolution_limit" then
                      local mode = tonumber(value) or 0
                      if mode == 1 then return Strings("No Final Evo") end
                      if mode == 2 then return Strings("No Evolution") end
                      return nil
                  elseif rule.key == "party_size_limit" then
                      local limit = tonumber(value) or 6
                      if limit < 6 then return Strings("Party Limit %d", limit) end
                      return nil
                  elseif rule.key == "travel_restrictions" then
                      local mode = tonumber(value) or 0
                      if mode == 1 then return Strings("No Fly") end
                      if mode == 2 then return Strings("No Fly+Teleport") end
                      return nil
                  elseif rule.key == "run_surf" then
                      local mode = mod.exports.__beta26.movementAssistMode(value)
                      return mode > 0 and Strings("Run/Surf %s", Strings(
                          mod.exports.__beta26.movementAssistLabel(mode))) or nil
                  elseif rule.key == "shiny_clause" then
                      local mode = tonumber(value) or 0
                      if mode == 4 then return Strings("Shiny UNLIMITED") end
                      if mode > 0 then
                          local used = math.max(0, math.floor(tonumber(mod.save:get("shiny_clause_used", 0)) or 0))
                          return Strings("Shiny %d/%d", math.max(0, mode - used), mode)
                      end
                      return nil
                  elseif rule.key == "encounter_ball_limit" then
                      local limit = mod.exports.__beta26.encounterBallLimitValues[
                          tonumber(value) or 0] or 0
                      return limit > 0 and Strings("Ball Limit %d", limit) or nil
                  elseif rule.key == "type_lock_mode" then
                      local mode = math.max(0, math.min(6, tonumber(value) or 0))
                      if mode <= 0 then return nil end
                      if getConfigValue("type_lock_draft", false) == true then
                          local filled, needed, complete = mod.exports.__beta26.typeLockDraftStatus()
                          return complete
                              and Strings("%s %d Types", mod.exports.__beta26.typeLockModeLabel(mode), mode)
                              or Strings("%s Draft %d/%d", mod.exports.__beta26.typeLockModeLabel(mode), filled, needed)
                      end
                      local typeNames = {}
                      for i = 1, mode do
                          typeNames[#typeNames + 1] = Strings(mod.exports.__beta26.typeLockTypeLabel(
                              getConfigValue(mod.exports.__beta26.typeLockSlotKey(i), false)))
                      end
                      return mode <= 3
                          and Strings("%s %s", mod.exports.__beta26.typeLockModeLabel(mode), table.concat(typeNames, "/"))
                          or Strings("%s %d Types", mod.exports.__beta26.typeLockModeLabel(mode), mode)
                  elseif rule.key == "type_lock_draft" or rule.key == "type_lock_primary"
                      or rule.key == "type_lock_secondary" or rule.key == "type_lock_tertiary"
                      or rule.key == "type_lock_quaternary" or rule.key == "type_lock_quinary"
                      or rule.key == "type_lock_senary" then
                      return nil
                  elseif rule.key == "difficulty_profile" then
                      local selectedId = tostring(mod.save:get("difficulty_provider_id", "vanilla") or "vanilla")
                      local selected
                      for _, option in ipairs(mod.exports.__beta26.difficultyOptions() or {}) do
                          if tostring(option.id or "") == selectedId then selected = option; break end
                      end
                      if not selected or tostring(selected.id or "vanilla") == "vanilla" then return nil end
                      return Strings("Difficulty %s", Strings(selected.name or selected.id or "CUSTOM"))
                  elseif rule.key == "no_catching" then
                      return value == true and Strings("No Catching") or nil
                  elseif rule.key == "progression_pc_catches" then
                      return value == true and Strings("PC-Only Catches") or nil
                  elseif rule.key == "badge_boosts" then
                      return value == false and Strings("No Badge Boosts") or nil
                  elseif rule.key == "mt_moon_splits" then
                      return (tonumber(value) or 0) == 1 and Strings("Mt Moon COMMON") or nil
                  elseif rule.key == "safari_zone_splits" then
                      local mode = tonumber(value) or 0
                      if mode == 0 then return nil end
                      local labels = { [1]="Safari PER AREA",
                          [2]="Safari UNTIL CATCH", [3]="Safari AREA+CATCH" }
                      return Strings(labels[mode] or "Safari STANDARD")
                  elseif rule.key == "trainer_money_multiplier" then
                      local mode = tonumber(value) or 4
                      if mode == 4 then return nil end
                      return Strings("Trainer Money %s", Strings(
                          mod.exports.__beta26.trainerMoneyPresetLabels[mode]
                              or Strings.source("100%")))
                  elseif rule.key == "maximum_bst" then
                      local limit = tonumber(value) or 0
                      return limit > 0 and Strings("Max BST %d", limit) or nil
                  elseif rule.key == "randomizer_preset" then
                      return Strings("RNG Preset %s", ({ [0]="CUSTOM", [1]="CHAOS", [2]="BALANCED" })[tonumber(value) or 0] or "CUSTOM")
                  elseif rule.key == "randomizer_seed" then
                      local starterOwned = mod.save:get("random_starter", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_starter", self.game))
                      local encountersOwned = mod.save:get("random_encounter_tables", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", self.game))
                      local fieldItemsOwned = mod.save:get("random_field_items", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_field_items", self.game))
                      local learnsetsOwned = mod.save:get("random_learnsets", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_learnsets", self.game))
                      local trainersOwned = mod.save:get("random_trainers", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_trainers", self.game))
                      local evolutionsOwned = mod.save:get("random_evolutions", false) == true
                      local shopsOwned = mod.save:get("random_shops", false) == true
                      local tmsOwned = mod.save:get("random_tms", false) == true
                      local giftsOwned = mod.save:get("random_gift_items", false) == true
                      local seed = type(mod.exports.__beta26.randomizerSeed) == "function"
                          and tonumber(mod.exports.__beta26.randomizerSeed(nil, false))
                          or tonumber(value) or 0
                      return (starterOwned or encountersOwned or fieldItemsOwned or learnsetsOwned or trainersOwned or evolutionsOwned or shopsOwned or tmsOwned or giftsOwned) and seed > 0
                          and Strings("RNG %08d v%d", seed, mod.exports.__beta26.randomizerAlgorithmVersion()) or nil
                  elseif rule.key == "random_starter_style" then
                      if mod.save:get("random_starter", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_starter", self.game)) then return nil end
                      return Strings("Starter %s", ({ [0]="ANY", [1]="3-STAGE", [2]="BASE", [3]="SIM BST" })[tonumber(value) or 0] or "ANY")
                  elseif rule.key == "random_starter_balance" then
                      if mod.save:get("random_starter", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_starter", self.game)) then return nil end
                      return tonumber(value) == 1 and Strings("Starter BALANCED") or Strings("Starter INDEPENDENT")
                  elseif rule.key == "random_starter_trio_typing" then
                      if mod.save:get("random_starter", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_starter", self.game)) then return nil end
                      return tonumber(value) == 1 and Strings("Trio AUTO") or Strings("Trio OFF")
                  elseif rule.key == "random_field_item_balance" then
                      if mod.save:get("random_field_items", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_field_items", self.game)) then return nil end
                      return Strings("Items %s", ({ [0]="CHAOS", [1]="CATEGORY", [2]="BALANCED" })[tonumber(value) or 0] or "CHAOS")
                  elseif rule.key == "random_field_item_repetition" then
                      if mod.save:get("random_field_items", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_field_items", self.game)) then return nil end
                      return Strings("ItemRep %s", ({ [0]="ALLOW", [1]="DIVERSE", [2]="UNIQUE" })[tonumber(value) or 0] or "ALLOW")
                  elseif rule.key == "random_encounter_balance" then
                      if mod.save:get("random_encounter_tables", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", self.game)) then return nil end
                      return Strings("Enc %s", ({ [0]="CHAOS", [1]="SIM BST", [2]="EVO", [3]="BALANCED" })[tonumber(value) or 0] or "CHAOS")
                  elseif rule.key == "random_encounter_repetition" then
                      if mod.save:get("random_encounter_tables", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", self.game)) then return nil end
                      return Strings("Repeats %s", ({ [0]="ALLOW", [1]="DIVERSE", [2]="UNIQUE" })[tonumber(value) or 0] or "ALLOW")
                  elseif rule.key == "random_encounter_diversity_strength" then
                      if mod.save:get("random_encounter_tables", false) ~= true
                          or tonumber(mod.save:get("random_encounter_repetition", 0)) ~= 1
                          or (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", self.game)) then return nil end
                      return Strings("Diversity %s", ({ [0]="LIGHT", [1]="STANDARD", [2]="STRONG" })[tonumber(value) or 1] or "STANDARD")
                  elseif rule.key == "random_evolution_balance" then
                      if mod.save:get("random_evolutions", false) ~= true then return nil end
                      return Strings("Evos %s", ({ [0]="CHAOS", [1]="DEPTH", [2]="SIM BST", [3]="BALANCED" })[tonumber(value) or 0] or "CHAOS")
                  elseif rule.key == "random_shop_balance" then
                      if mod.save:get("random_shops", false) ~= true then return nil end
                      return Strings("Shops %s", ({ [0]="CHAOS", [1]="PRICE", [2]="BALANCED" })[tonumber(value) or 2] or "BALANCED")
                  elseif rule.key == "random_tm_compatibility" then
                      if mod.save:get("random_tms", false) ~= true then return nil end
                      return Strings("TM Compat %s", ({ [0]="MOVE", [1]="SLOT", [2]="FULL" })[tonumber(value) or 0] or "MOVE")
                  elseif rule.key == "random_trainer_balance" then
                      if mod.save:get("random_trainers", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_trainers", self.game)) then return nil end
                      return Strings("Trainers %s", ({ [0]="CHAOS", [1]="EVO", [2]="SIM BST", [3]="BALANCED" })[tonumber(value) or 0] or "CHAOS")
                  elseif rule.key == "random_trainer_diversity" then
                      if mod.save:get("random_trainers", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_trainers", self.game)) then return nil end
                      return Strings("Diversity %s", ({ [0]="OFF", [1]="DIVERSE", [2]="UNIQUE" })[tonumber(value) or 0] or "OFF")
                  elseif rule.key == "random_trainer_theme" then
                      if mod.save:get("random_trainers", false) ~= true
                          or (externalRuleDelegation and externalRuleDelegation("random_trainers", self.game)) then return nil end
                      return Strings("Theme %s", ({ [0]="OFF", [1]="TYPE" })[tonumber(value) or 0] or "OFF")
                  elseif rule.key == "randomizer_info_policy" then
                      local starterOwned = mod.save:get("random_starter", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_starter", self.game))
                      local encountersOwned = mod.save:get("random_encounter_tables", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", self.game))
                      local fieldItemsOwned = mod.save:get("random_field_items", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_field_items", self.game))
                      local learnsetsOwned = mod.save:get("random_learnsets", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_learnsets", self.game))
                      local trainersOwned = mod.save:get("random_trainers", false) == true
                          and not (externalRuleDelegation and externalRuleDelegation("random_trainers", self.game))
                      local evolutionsOwned = mod.save:get("random_evolutions", false) == true
                      local shopsOwned = mod.save:get("random_shops", false) == true
                      local tmsOwned = mod.save:get("random_tms", false) == true
                      local giftsOwned = mod.save:get("random_gift_items", false) == true
                      if not starterOwned and not encountersOwned
                          and not fieldItemsOwned and not learnsetsOwned
                          and not trainersOwned and not evolutionsOwned and not shopsOwned
                          and not tmsOwned and not giftsOwned then return nil end
                      return tonumber(value) == 1 and Strings("RNG BLIND") or Strings("RNG OPEN")
                  elseif rule.key == "gold_egg_encounter_mode" then
                      local mode = tonumber(value) or 0
                      return mode > 0 and Strings("Egg %s",
                          ({ [1]="RECEIVED", [2]="HATCHED", [3]="GIFT" })[mode]
                              or "RECEIVED") or nil
                  elseif rule.key == "gold_bug_contest_mode" then
                      local mode = tonumber(value) or 0
                      return mode > 0 and Strings("Contest %s",
                          ({ [1]="EXEMPT", [2]="SLOT" })[mode]
                              or "EXEMPT") or nil
                  elseif rule.numeric then
                      return (tonumber(value) or 0) > 0
                          and Strings(rule.shortName or rule.name) or nil
                  elseif boolSetting(value) then
                      return Strings(rule.shortName or rule.name)
                  end
                  return nil
              end
              local groups = {}
              for _, cat in ipairs(ruleCategories) do
                  local groupNames = {}
                  if lockeType > 0 and tostring(cat.title or ""):upper():find(
                      "CORE", 1, true) then
                      groupNames[#groupNames + 1] = Strings("Loadout %s",
                          Strings(LockePreset.names[lockeType] or "CUSTOM"))
                  end
                  for _, rule in ipairs(cat.rules or {}) do
                      local label = activeLabel(rule)
                      if label then
                          names[#names + 1] = label
                          -- The semantic loadout label above already represents
                          -- locke_type inside CORE; do not show a second raw
                          -- numeric Locke Type row in the grouped status view.
                          if rule.key ~= "locke_type" then
                              groupNames[#groupNames + 1] = label
                          end
                      end
                  end
                  if #groupNames > 0 then
                      groups[#groups + 1] = {
                          title = tostring(Strings(cat.shortTitle or cat.title or "RULES")),
                          names = groupNames,
                      }
                  end
              end
              return names, groups
          end

          local function activeRuleNames()
              local names = activeRuleSnapshot()
              return names
          end

          local function activeRuleGroups()
              local _, groups = activeRuleSnapshot()
              return groups or {}
          end

          local function setupOnlyRows()
              local rows = {}
              local gen2 = mod.exports.__beta26.runtimeIsGen2(self.game)
              for _, cat in ipairs(ruleCategories) do
                  for _, rule in ipairs(cat.rules or {}) do
                      local visible = mod.exports.__beta26.ruleForConfigSurface
                          and mod.exports.__beta26.ruleForConfigSurface(rule, gen2) or rule
                      if visible and visible.setupOnly == true then
                          local value = getConfigValue(visible.key, false)
                          local valueLabel
                          if visible.numeric then
                              valueLabel = tostring(math.floor(tonumber(value)
                                  or tonumber(defaultRuleValue(visible.key)) or 0))
                          else
                              local enabled = value == true
                                  or (type(value) == "number" and value ~= 0)
                                  or (type(value) == "string"
                                      and (value:lower() == "on"
                                          or value:lower() == "true"
                                          or tonumber(value) == 1))
                              valueLabel = enabled and "ON" or "OFF"
                          end
                          rows[#rows + 1] = {
                              label = Strings(visible.shortName or visible.name or visible.key),
                              right = Strings(valueLabel),
                          }
                      end
                  end
              end
              return rows
          end

          -- 2.1.22: the R/B/Y START-menu status surface now uses the engine's
          -- stable mod-facing ListMenu instead of a hand-drawn custom state.
          -- Runtime testing on Yellow showed the custom NUZ ST. state could
          -- still hard-crash before its deferred draw guard could recover.
          -- Build the same status/rule information as inert list rows so the
          -- host owns scrolling, drawing, cancel input, and StateStack timing.
          if statusOnly then
              local function metric(label, fn, fallback)
                  local ok, value = pcall(fn)
                  if not ok then value = fallback end
                  return { label = Strings(label), right = tostring(value or fallback or "?") }
              end
              local items = {}
              items[#items + 1] = {
                  label = Strings("RUN STATUS"), right = "",
                  nuzlockeBoldHeader = true,
              }
              items[#items + 1] = metric("CAUGHT", function()
                  return countTrackerCatches()
              end, 0)
              items[#items + 1] = metric("LOST ENC.", function()
                  local lost = 0
                  local states = mod.save:get("encounter_states", {})
                  if type(states) == "table" then
                      for key, state in pairs(states) do
                          if key ~= "__LEGACY__" and type(state) == "table"
                              and state.status == "FAILED" and isTrackedArea(key) then
                              lost = lost + 1
                          end
                      end
                  end
                  return lost
              end, 0)
              items[#items + 1] = metric("DEATHS", function()
                  return tonumber(mod.save:get("nuzlocke_losses", 0)) or 0
              end, 0)
              items[#items + 1] = metric("CAUGHT A.", function()
                  return string.format("%d/%d", countCaughtAreas(), #getDisplayRoutes(game))
              end, "0/0")
              items[#items + 1] = metric("VISITED A.", function()
                  return string.format("%d/%d", countVisitedAreas(game), #getDisplayRoutes(game))
              end, "0/0")
              items[#items + 1] = metric("NEXT CAP", function()
                  local cap = nextLevelCap(game and game.save)
                  return cap >= 100 and Strings("MAX") or Strings("LV%d", cap)
              end, "?")
              items[#items + 1] = metric("F. TOKEN", function()
                  return nuzStatusTokenBalance()
              end, 0)
              do
                  local areaLabel, areaStatus = nuzStatusEncounterSnapshot(game)
                  local compactArea = tostring(areaLabel or "?")
                  if #compactArea > 9 then compactArea = compactArea:sub(1, 8) .. "." end
                  items[#items + 1] = {
                      label = Strings("AREA"),
                      right = Strings(compactArea),
                  }
                  items[#items + 1] = {
                      label = Strings("SLOT"),
                      right = Strings(areaStatus),
                  }
              end
              do
                  local lastEvent = tostring(nuzStatusLastHistoryEvent(game) or "NONE")
                  if #lastEvent > 16 then lastEvent = lastEvent:sub(1, 15) .. "." end
                  items[#items + 1] = { label = Strings("LAST EVENT"), right = "" }
                  items[#items + 1] = { label = Strings(lastEvent), right = "" }
              end
              items[#items + 1] = {
                  label = Strings("RUN HISTORY"), right = "",
                  onSelect = function() pushNuzlockeRunHistoryViewer(game) end,
              }

              items[#items + 1] = {
                  label = Strings("ACTIVE RULES"), right = "",
                  nuzlockeBoldHeader = true,
              }
              local okGroups, groups = pcall(activeRuleGroups)
              if okGroups and type(groups) == "table" then
                  if #groups == 0 then
                      items[#items + 1] = { label = Strings("NONE"), right = "" }
                  end
                  for _, group in ipairs(groups) do
                      items[#items + 1] = {
                          label = Strings(group.title or "RULES"), right = "",
                          nuzlockeBoldHeader = true,
                      }
                      for _, name in ipairs(group.names or {}) do
                          items[#items + 1] = { label = tostring(name), right = "" }
                      end
                  end
              else
                  items[#items + 1] = { label = Strings("RULE READ ERROR"), right = "" }
              end

              items[#items + 1] = {
                  label = Strings("SETUP ONLY"), right = "",
                  nuzlockeBoldHeader = true,
              }
              local okSetup, setupRows = pcall(setupOnlyRows)
              if okSetup and type(setupRows) == "table" and #setupRows > 0 then
                  for _, row in ipairs(setupRows) do items[#items + 1] = row end
              else
                  items[#items + 1] = { label = Strings("NONE"), right = "" }
              end

              local menu = mod.ui.ListMenu.new(game, Strings("NUZ STATUS"), items, {
                  kind = "nuzlocke_status",
                  pageJump = true,
                  wrap = false,
                  onChoose = function(item, list)
                      if type(item) == "table" and type(item.onSelect) == "function" then
                          return item.onSelect(item, list)
                      end
                  end,
              })
              if type(menu) == "table" then
                  menu.screenId = "NuzlockeStatusListScreen"
                  menu.rows = 7
                  menu.index = (#items >= 2) and 2 or 1
                  menu.footer = Strings("B:BACK")
                  local baseUpdate = menu.update
                  local function syncStatusScroll(list)
                      local rows = list.rows or 7
                      if list.index - (list.scroll or 0) > rows then
                          list.scroll = list.index - rows
                      end
                      if list.index - (list.scroll or 0) < 1 then
                          list.scroll = list.index - 1
                      end
                      list.scroll = math.max(0, list.scroll or 0)
                  end
                  menu.update = function(list, dt)
                      local before = list.index or 1
                      local result = baseUpdate(list, dt)
                      local after = list.index or before
                      if items[after] and items[after].nuzlockeBoldHeader == true then
                          local dir = after >= before and 1 or -1
                          local probe = after
                          repeat probe = probe + dir
                          until probe < 1 or probe > #items
                              or items[probe].nuzlockeBoldHeader ~= true
                          if probe < 1 or probe > #items then
                              dir = -dir
                              probe = after
                              repeat probe = probe + dir
                              until probe < 1 or probe > #items
                                  or items[probe].nuzlockeBoldHeader ~= true
                          end
                          if probe >= 1 and probe <= #items then list.index = probe end
                          syncStatusScroll(list)
                      end
                      local selected = items[list.index or 1]
                      list.footer = selected and type(selected.onSelect) == "function"
                          and Strings("A:OPEN B:BACK") or Strings("B:BACK")
                      return result
                  end
                  decorateNativeInfoList(menu, "NUZ STATUS", { headers = true })
              end
              -- 2.6.70: do not fake bold text by overdrawing the header one
              -- pixel to the right; on the fixed-width GB font that looked like
              -- broken character spacing. A single clean header is clearer.
              return menu
          end

          -- Optional semantic presentation used by Gen1 Modern UI.
          -- This remains source-owned data/actions: the classic draw path below
          -- is untouched and stays the fallback whenever no presenter is active.
          function self:nuzlockeModernUiModel()
              local save = self.game and self.game.save or {}
              if self.nuzlockeStatusPage then
                  local names = activeRuleNames()
                  local rows = {}
                  for i, name in ipairs(names) do
                      rows[#rows + 1] = {
                          label = tostring(name),
                          right = i == self.ruleScroll + 1 and ">" or nil,
                      }
                  end
                  return {
                      title = Strings("NUZLOCKE STATUS"),
                      rows = rows,
                      index = math.min(#rows, self.ruleScroll + 1),
                      scroll = self.ruleScroll,
                      footer = { Strings("A: CARD"), Strings("B: BACK") },
                      details = (function()
                          local areaLabel, areaStatus = nuzStatusEncounterSnapshot(self.game)
                          return {
                              Strings("Active challenge rules"),
                              Strings("CAP %s  F. TOKEN %d", tostring(nextLevelCap(save)),
                                  nuzStatusTokenBalance()),
                              Strings("AREA %s: %s", tostring(areaLabel), tostring(areaStatus)),
                              Strings("LAST %s", nuzStatusLastHistoryEvent(self.game)),
                          }
                      end)(),
                  }
              end

              local player = save.player or {}
              local badges = 0
              local okBadges, Badges = pcall(require, "src.inventory.Badges")
              if okBadges and Badges and type(Badges.count) == "function" then
                  local okCount, count = pcall(Badges.count,
                      self.game and self.game.data, save)
                  if okCount then badges = tonumber(count) or 0 end
              end
              local seconds = math.floor(tonumber(save.playTime) or 0)
              local money = math.floor(tonumber(save.money) or 0)
              return {
                  title = Strings("TRAINER CARD"),
                  rows = {
                      { label = Strings("NAME"), right = tostring(player.name or "PLAYER") },
                      { label = Strings("ID"), right = tostring(player.id or player.trainerId or "--") },
                      { label = Strings("MONEY"), right = ("¥%d"):format(money) },
                      { label = Strings("TIME"), right = ("%d:%02d"):format(
                          math.floor(seconds / 3600), math.floor(seconds / 60) % 60) },
                      { label = Strings("BADGES"), right = tostring(badges) },
                      { label = Strings("NEXT CAP"), right = tostring(nextLevelCap(save)) },
                  },
                  index = 1,
                  scroll = 0,
                  footer = { Strings("A: NUZLOCKE"), Strings("B: BACK") },
              }
          end

          function self:nuzlockeModernUiAction(action)
              if action == "back" then
                  self.game.stack:pop()
                  return true
              elseif not self.statusOnly
                  and (action == "select" or action == "right" or action == "left") then
                  self.nuzlockeStatusPage = not self.nuzlockeStatusPage
                  self.ruleScroll = 0
                  self.ruleArrowTime = 0
                  self.ruleMarqueeTime = 0
                  return true
              elseif self.nuzlockeStatusPage and (action == "up" or action == "down") then
                  local names = activeRuleNames()
                  local maxScroll = math.max(0, #names - 2)
                  if action == "up" then
                      self.ruleScroll = math.max(0, self.ruleScroll - 1)
                  else
                      self.ruleScroll = math.min(maxScroll, self.ruleScroll + 1)
                  end
                  self.ruleMarqueeTime = 0
                  return true
              end
              return false
          end

          function self:update(dt)
              local input = self.game.input
              local revision = tonumber(mod.save:get("nuzlocke_rule_revision", 0)) or 0
              if revision ~= self.ruleRevision then
                  self.ruleRevision = revision
                  self.ruleScroll = 0
                  self.ruleArrowTime = 0
                  self.ruleMarqueeTime = 0
              end

              if input:wasPressed("a") and not self.statusOnly then
                  self.nuzlockeStatusPage = not self.nuzlockeStatusPage
                  self.ruleScroll = 0
                  self.ruleArrowTime = 0
                  self.ruleMarqueeTime = 0
                  return
              end

              if input:wasPressed("b") then
                  self.game.stack:pop()
                  return
              end

              if self.nuzlockeStatusPage then
                  local names = activeRuleNames()
                  -- draw() has two physical rule rows in the beta.21 layout.
                  -- Keep update() on that same window size so the final rule is
                  -- reachable and the native more-arrow disappears correctly.
                  local visible = 2
                  local maxScroll = math.max(0, #names - visible)

                  if input:wasPressed("down") and self.ruleScroll < maxScroll then
                      self.ruleScroll = self.ruleScroll + 1
                      self.ruleMarqueeTime = 0
                  elseif input:wasPressed("up") and self.ruleScroll > 0 then
                      self.ruleScroll = self.ruleScroll - 1
                      self.ruleMarqueeTime = 0
                  else
                      self.ruleMarqueeTime = self.ruleMarqueeTime + (dt or 0)
                  end

                  -- Clamp the scroll position every update.  The arrow is
                  -- driven by the same condition used to advance the list,
                  -- so it cannot remain visible after the final rule.
                  if self.ruleScroll > maxScroll then
                      self.ruleScroll = maxScroll
                  end

                  local canScrollDown = (self.ruleScroll + visible) < #names
                  if canScrollDown then
                      self.ruleArrowTime = self.ruleArrowTime + (dt or 0)
                  else
                      self.ruleArrowTime = 0
                  end
              else
                  self.ruleScroll = 0
                  self.ruleArrowTime = 0
                  self.ruleMarqueeTime = 0
              end
          end

          function self:draw()
              local Font = mod.ui.Font

              if not self.nuzlockeStatusPage and self.vanilla then
                  self.vanilla:draw()
                  -- Flip hint lives in the open band between the trainer
                  -- information/sprite area and the badge sprites.  Keep it
                  -- on the RIGHT side, clear of the WORD badges and dots.
                  Font.draw(Strings("A:NUZ"), 112, 78)
                  return
              end

              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.rectangle("fill", 0, 0, 160, 144)
              Font.drawBox(0, 0, 20, 18)

              if mod.exports.__beta26.runtimeIsGen2(self.game) then
                  mod.exports.__beta26.drawGen2NuzTitle(nil, Font, "NUZ STATUS",
                      mod.exports.__beta26.Dev.gameLabel(self.game),
                      { row = 1, subtitleRow = 2 })
              else
                  Font.draw(Strings("NUZ STATUS "
                      .. mod.exports.__beta26.Dev.gameLabel(self.game)), 16, 8)
              end

              local caught = countTrackerCatches()
              local deaths = tonumber(mod.save:get("nuzlocke_losses", 0)) or 0
              local lostEncounters = 0
              local states = mod.save:get("encounter_states", {})
              if type(states) == "table" then
                  for key, state in pairs(states) do
                      if key ~= "__LEGACY__" and type(state) == "table"
                          and state.status == "FAILED" and isTrackedArea(key) then
                          lostEncounters = lostEncounters + 1
                      end
                  end
              end
              local caughtAreasCount = countCaughtAreas()
              local visitedAreasCount = countVisitedAreas(self.game)
              local totalAreas = #getDisplayRoutes(self.game)
              local cap = nextLevelCap(self.game and self.game.save)
              local tokens = nuzStatusTokenBalance()
              local areaLabel, areaStatus = nuzStatusEncounterSnapshot(self.game)
              local lastEvent = nuzStatusLastHistoryEvent(self.game)

              -- 2.6.5: compact paired rows preserve all pre-existing status
              -- facts while reserving bounded rows for TOKEN, AREA, and LAST.
              -- Pixel-fit every free-text row before drawing so no status text
              -- can cross the 152px inner frame or collide with RULES/footer.
              Font.draw(fitPixelText(("CATCH %d  LOST %d"):format(
                  caught, lostEncounters), 136), 16, 20)
              Font.draw(fitPixelText(("DEATH %d  TOKEN %d"):format(
                  deaths, tokens), 136), 16, 30)
              Font.draw(fitPixelText(("AREAS %d/%d VIS %d/%d"):format(
                  caughtAreasCount, totalAreas, visitedAreasCount, totalAreas), 136), 16, 40)
              Font.draw(cap >= 100 and Strings("NEXT CAP MAX")
                  or Strings("NEXT CAP LV%d", cap), 16, 50)
              Font.draw(fitPixelText("AREA " .. tostring(areaLabel), 92), 16, 60)
              local statusText = fitPixelText(tostring(areaStatus), 36)
              local statusWidth = type(Font.width) == "function" and Font.width(statusText)
                  or (#statusText * 8)
              Font.draw(statusText, math.max(108, 144 - statusWidth), 60)
              Font.draw(fitPixelText("LAST " .. tostring(lastEvent), 136), 16, 70)

              local names = activeRuleNames()
              local visible = 2
              local maxScroll = math.max(0, #names - visible)
              if self.ruleScroll > maxScroll then
                  self.ruleScroll = maxScroll
              end
              local canScrollDown = (self.ruleScroll + visible) < #names

              local rulesY = 82
              local ruleRowsY = rulesY + 10
              Font.draw(Strings("RULES"), 16, rulesY)
              if #names == 0 then
                  Font.draw(Strings("NONE"), 16, ruleRowsY)
              else
                  for row = 1, visible do
                      local idx = self.ruleScroll + row
                      local name = names[idx]
                      if name then
                          Font.draw(marqueeText(name, 14, self.ruleMarqueeTime),
                              16, ruleRowsY + (row - 1) * 10)
                      end
                  end
              end

              -- Bottom navigation strip. The down marker uses the same native Gen 1 glyph as TextBox.
              -- when the player reaches the last rule, the scroll indicator
              -- disappears completely instead of changing into another arrow.
              -- This leaves the prompts unobstructed and makes the down-arrow
              -- mean exactly one thing: more rules are available below.
              if canScrollDown then
                  local blinkOn = math.floor(self.ruleArrowTime / 0.8) % 2 == 0
                  if blinkOn then
                       local Theme = require("src.ui.Theme")
                       Font.drawCode(Theme.moreArrow or 0xEE, 94, 122)
                   end
              end

              if self.statusOnly then
                  Font.draw(Strings("B:EXIT"), 104, 126)
              else
                  Font.draw(Strings("A:CARD"), 8, 126)
                  Font.draw(Strings("B:EXIT"), 104, 126)
              end
          end

          -- 2.1.20: status-only START-menu screen uses the same deferred
          -- recovery rule as NUZ RULES. Never pop a state from inside draw().
          do
              local function queueStatusFail(phase, err)
                  if self.__nuzStatusRuntimeError then return end
                  local msg = tostring(err or "unknown status-screen runtime error")
                  self.__nuzStatusRuntimeError = {
                      phase = tostring(phase or "runtime"), message = msg,
                  }
                  mod.exports.__beta26.lastStatusScreenError =
                      self.__nuzStatusRuntimeError.phase .. ": " .. msg
                  -- 2.4.60: status-screen update/draw failures are independent
                  -- from config-screen failures and should retain their own
                  -- full traceback plus point-in-time Dev snapshot.
                  local Dev = mod.exports.__beta26.Dev
                  if Dev and type(Dev.recordError) == "function" then
                      pcall(Dev.recordError,
                          "status_screen_" .. self.__nuzStatusRuntimeError.phase,
                          msg, self.game)
                  end
              end
              local function presentStatusFail()
                  local failure = self.__nuzStatusRuntimeError
                  if not failure or self.__nuzStatusRuntimeErrorPresented then return false end
                  self.__nuzStatusRuntimeErrorPresented = true
                  local g = self.game
                  if not (g and g.stack) then return true end
                  pcall(function()
                      if type(g.stack.pop) == "function" then g.stack:pop() end
                  end)
                  local short = tostring(failure.message):gsub("^.-:%s*", "")
                  if #short > 180 then short = short:sub(1, 180) .. "..." end
                  local body = mod.exports.__beta26.manualPagedErrorText(
                      "NUZ STATUS " .. tostring(failure.phase):upper() .. " ERROR",
                      short)
                  local okText, TextBox = pcall(require, "src.render.TextBox")
                  if okText and TextBox then
                      pcall(function() g.stack:push(TextBox.new(g, body)) end)
                  end
                  return true
              end
              local rawUpdate = self.update
              self.update = function(...)
                  if presentStatusFail() then return end
                  local args = { ... }
                  local ok, result = xpcall(function()
                      return rawUpdate(unpackValues(args))
                  end, debug and debug.traceback or tostring)
                  if not ok then
                      queueStatusFail("update", result)
                      presentStatusFail()
                      return
                  end
                  return result
              end
              local rawDraw = self.draw
              self.draw = function(...)
                  if self.__nuzStatusRuntimeError then return end
                  local args = { ... }
                  local ok, result = xpcall(function()
                      return rawDraw(unpackValues(args))
                  end, debug and debug.traceback or tostring)
                  if not ok then
                      queueStatusFail("draw", result)
                      return
                  end
                  return result
              end
          end

          return self
      end
  })


  ---------------------------------------------------------------------
  -- INFINITE RARE CANDY / GYM GUIDE
  --
  -- This is deliberately isolated from the existing Nuzlocke enforcement
  -- hooks.  When disabled, the vanilla Gym Guide handler is replayed and
  -- nothing else happens.  When enabled, the vanilla conversation finishes
  -- first, then the Guide offers a repeatable quantity menu.
  --
  -- The menu is a normal mod screen rather than a replacement for the
  -- engine's item UI.  Bag.add still enforces the normal inventory rules and
  -- the quantity is capped at 99 per conversation.
  ---------------------------------------------------------------------

  do -- compiler-budget scope: Gym Guide registration helpers
  local GYM_GUIDE_TALKS = {
      PEWTER_GYM    = "TEXT_PEWTERGYM_GYM_GUIDE",
      CERULEAN_GYM  = "TEXT_CERULEANGYM_GYM_GUIDE",
      VERMILION_GYM = "TEXT_VERMILIONGYM_GYM_GUIDE",
      FUCHSIA_GYM   = "TEXT_FUCHSIAGYM_GYM_GUIDE",
      SAFFRON_GYM   = "TEXT_SAFFRONGYM_GYM_GUIDE",
      CELADON_GYM   = "TEXT_CELADONGYM_GYM_GUIDE",
      CINNABAR_GYM  = "TEXT_CINNABARGYM_GYM_GUIDE",
      VIRIDIAN_GYM  = "TEXT_VIRIDIANGYM_GYM_GUIDE",
  }

  local RARE_CANDY_CHOICES = { 1, 10, 25, 50, 99 }

  -- A small foreground screen.  It intentionally has no dependency on the
  -- Nuzlocke config screen, so it can be used safely from any Gym Guide.
  mod.content.screens:register("NuzlockeRareCandyMenu", {
      new = function(game, context)
          context = context or {}
          local self = {
              game = game,
              selected = 1,
              choices = RARE_CANDY_CHOICES,
              isOpaque = false,
              onSelect = context.onSelect,
              onCancel = context.onCancel,
          }

          function self:update(dt)
              local input = self.game.input
              if input:wasPressed("up") then
                  self.selected = self.selected - 1
                  if self.selected < 1 then self.selected = #self.choices end
              elseif input:wasPressed("down") then
                  self.selected = self.selected + 1
                  if self.selected > #self.choices then self.selected = 1 end
              elseif input:wasPressed("a") then
                  local amount = self.choices[self.selected]
                  local callback = self.onSelect
                  self.game.stack:pop()
                  if callback then callback(amount) end
                  return
              elseif input:wasPressed("b") then
                  local callback = self.onCancel
                  self.game.stack:pop()
                  if callback then callback() end
                  return
              end
          end

          function self:draw()
              local Font = mod.ui.Font
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.rectangle("fill", 16, 18, 128, 108)
              Font.drawBox(16, 18, 16, 13)
              -- Keep every row visually centered inside the 16-tile box.
              -- This helper is local to draw() so the large main chunk does not
              -- gain another long-lived top-level local. Gen1's UI font is an
              -- 8px fixed-width grid for these ASCII labels.
              local function centeredX(text)
                  return 80 - math.floor((#tostring(text) * 8) / 2)
              end

              Font.draw(Strings("RARE CANDY"), centeredX(Strings("RARE CANDY")), 26)
              Font.draw(Strings("How many?"), centeredX(Strings("How many?")), 42)

              for i, amount in ipairs(self.choices) do
                  local y = 56 + (i - 1) * 10
                  local valueText = tostring(amount)
                  local valueX = centeredX(valueText)
                  if i == self.selected then
                      local Theme = require("src.ui.Theme")
                      Font.drawCode(Theme.cursor, valueX - 12, y)
                  end
                  Font.draw(valueText, valueX, y)
              end

              Font.draw(Strings("B:CANCEL"), centeredX(Strings("B:CANCEL")), 108)
              Font.draw(Strings("A:OK"), centeredX(Strings("A:OK")), 118)
          end

          return self
      end,
  })

  -- R/B/Y-only command access. Gold deliberately does not seed the Gen 1
  -- command table, and its VM must never receive one of those handlers. Keep
  -- the private module name behind an explicit generation gate so a future
  -- shared call site cannot accidentally patch dead Gen 1 code on Gold.
  mod.exports.__beta26.rbyCommandsFor = function(game)
      if mod.exports.__beta26.runtimeIsGen2(game) then return nil end
      local moduleName = "src.script." .. "Commands"
      local ok, Commands = pcall(require, moduleName)
      if not ok or type(Commands) ~= "table" then return nil end
      return Commands
  end

  mod.content.commands:register("nuzlocke:infinite_rare_candy", {
      foreground = true,
      fn = function(ctx)
          if ctx and ctx.generation == 2 then return end
          if mod.save:get("infinite_rare_candies", false) ~= true then return end
          if providerExclusive("npc_talk", ctx and ctx.game, nil) then return end

          local Commands = mod.exports.__beta26.rbyCommandsFor(ctx and ctx.game)
          if not Commands then return end
          Commands.show_text(ctx,
              "Psst... doing a\nNuzlocke?\fI won't tell the\nLeague.\fHow many RARE CANDY\ndo you want?")

          local tier = worldTier(ctx.game)
          if tier >= 2 and levelCapScope() > 0 then
              local cap, leader = nextLevelCapInfo(ctx.game.save)
              if championDefeated() and (tonumber(cap) or 0) >= 100 then
                  -- Champion-cleared runs whose authoritative cap is truly
                  -- MAX have no remaining ceiling to warn about. If a postgame
                  -- or compatibility provider still supplies a lower live cap,
                  -- keep the normal warning instead.
                  Commands.show_text(ctx, "Gym Guide: You've\nearned it.")
              else
                  Commands.show_text(ctx,
                      tier >= 3
                          and ("Gym Guide: Careful!\fYour current cap is\nLV. " .. tostring(cap) .. ".\f" .. tostring(leader) .. " won't\nbe impressed.")
                          or ("Nice try.\fRare Candies don't\nbeat the level cap.\fCurrent cap: LV. " .. tostring(cap) .. "."))
              end
          end

          local selectedAmount
          Commands.push_screen(ctx, "NuzlockeRareCandyMenu", {
              onSelect = function(amount) selectedAmount = tonumber(amount) end,
              onCancel = function() selectedAmount = nil end,
          })
          if not selectedAmount then return end

          local okBag, Bag = pcall(require, "src.inventory.Bag")
          if not okBag or not Bag then
              Commands.show_text(ctx, "Rare Candy service is unavailable.")
              return
          end

          local inventory = ctx.save.inventory or {}
          local room = math.max(0, 99 - (tonumber(inventory.RARE_CANDY) or 0))
          local give = math.min(selectedAmount, room)
          if give <= 0 then
              Commands.show_text(ctx, "You already have\n99 RARE CANDY!")
              return
          end
          if not Bag.add(ctx.save, "RARE_CANDY", give, ctx.game.data) then
              Commands.show_text(ctx, "Your BAG is full!")
              return
          end
          Commands.show_text(ctx,
              ("You got %d %s!"):format(give, give == 1 and "RARE CANDY" or "RARE CANDIES"))
      end,
  })

  -- Compose the actual vanilla talk rows with our post-dialogue command.
  -- This is the long-lived beta.8-beta.16 R/B/Y implementation: baseTalk()
  -- returns ScriptRunner rows, so copy those rows and append the candy command
  -- directly. Do not nest a second foreground command/runner around them.
  local function registerGymGuideCandyTalk(mapId, textId)
      local MapScripts = require("src.script.MapScripts")
      local baseRows = MapScripts.baseTalk(mapId, textId)
      local rows = {}
      if type(baseRows) == "table" then
          for i, row in ipairs(baseRows) do rows[i] = row end
      end
      rows[#rows + 1] = { "nuzlocke:infinite_rare_candy" }
      mod.content.map_scripts:register(mapId, {
          priority = 10,
          talk = { [textId] = rows },
      })
  end

  local function gymGuideObjectName(mapDef, textId, mapId)
      if not (mapDef and type(mapDef.objects) == "table") then return nil end

      local fallback
      local upperText = tostring(textId or ""):upper()
      local compactMap = tostring(mapId or ""):gsub("_", ""):upper()

      for _, obj in ipairs(mapDef.objects) do
          local name = tostring(obj.name or "")
          local upperName = name:upper()

          local text = tostring(obj.text or obj.textId or obj.textID or ""):upper()
          local sprite = tostring(obj.sprite or obj.spriteId or ""):upper()

          -- Never mistake a trainer merely because another mod reused its
          -- sprite. Actual trainer objects carry trainer metadata.
          if not isTrainerDefinition(obj) then
              -- Strongest match: the object points at this Gym Guide text.
              if text ~= "" and text == upperText then
                  return name
              end

              -- Generated object names normally preserve the ROM constant, e.g.
              -- PEWTERGYM_GYM_GUIDE.
              if compactMap ~= "" and upperName:find(compactMap, 1, true)
                  and upperName:find("GYM", 1, true)
                  and (upperName:find("GUIDE", 1, true)
                       or upperName:find("GUY", 1, true)) then
                  fallback = name
              end

              -- Some generated builds retain the sprite constant even if the
              -- object name was normalized.
              if sprite == "SPRITE_GYM_GUIDE" then
                  fallback = name
              end
          end
      end

      return fallback
  end

  refreshGymGuideVisibility = function(game)
      if saveBlocked() then return end
      -- The Gym Guide candy bridge is an R/B/Y map-script feature. Gold has a
      -- separate script VM and no Gen 2 consumer for the map_scripts registry.
      if game and tonumber(game.generation) == 2 then return end
      if mod.save:get("infinite_rare_candies", false) ~= true then
          return
      end

      local save = game and game.save
      if not save then return end

      -- If another active mod explicitly owns NPC visibility, it gets the final
      -- say. Otherwise ordinary NPC visibility behavior continues to compose
      -- with the Guide.
      if providerExclusive("npc_visibility", game, nil)
          or providerExclusive("npc_behavior", game, nil) then
          return
      end

      save.objectToggles = save.objectToggles or {}

      for mapId, textId in pairs(GYM_GUIDE_TALKS) do
          local def
          if game.overworld and game.overworld.map
              and game.overworld.map.id == mapId
              and game.overworld.map.def then
              def = game.overworld.map.def
          end

          local data = game.data
          if not def and data and data.maps then def = data.maps[mapId] end
          if not def and data and data.mapsById then def = data.mapsById[mapId] end

          local objectName = gymGuideObjectName(def, textId, mapId)
          if objectName then
              save.objectToggles[mapId] = save.objectToggles[mapId] or {}
              save.objectToggles[mapId][objectName] = true

              -- Restore the live NPC immediately if the player is already in
              -- this gym. Commands.show_object uses the engine's public seam
              -- and updates the NPC/entity lists without rebuilding the map.
              local ow = game.overworld
              if ow and ow.map and ow.map.id == mapId then
                  local Commands = mod.exports.__beta26.rbyCommandsFor(game)
                  if Commands and type(Commands.show_object) == "function" then
                      pcall(Commands.show_object, {
                          game = game, save = save, overworld = ow
                      }, mapId, objectName)
                  end
              end
          end
      end
  end

  -- Keep late-runtime/checkpoint consumers off this main-scope local so the
  -- large reconciliation closure stays below the project upvalue ceiling.
  mod.exports.__beta26.refreshGymGuideVisibility = refreshGymGuideVisibility

  -- The Gym Guide bridge is a Gen 1 map-script feature. Determine the boot
  -- target from GameVersion rather than mod.game: at mod entry time mod.game
  -- is not guaranteed to carry the active generation, which could suppress
  -- the R/B/Y registrations entirely. This restores the established R/B/Y
  -- registration path while keeping Gold away from the Gen 1 registry.
  local gymGuideGoldBoot = mod.exports.__beta26.runtimeIsGen2(nil)
  if not gymGuideGoldBoot then
      for mapId, textId in pairs(GYM_GUIDE_TALKS) do
          registerGymGuideCandyTalk(mapId, textId)
      end
  end

  mod.events:on("save.loaded", function(ev)
      if saveBlocked() then return end
      if ev and ev.save then
          if type(mod.save:get("nuzlocke_e4_defeated")) ~= "table" then
              mod.save:set("nuzlocke_e4_defeated", {})
          end
          refreshGymGuideVisibility(getCurrentGame())
      end
  end)

  mod.events:on("game.ready", function(ev)
      local game = type(ev) == "table" and ev.game or ev
      refreshGymGuideVisibility(game)
  end)

  mod.events:on("map.entered", function(ev)
      if refreshGymGuideVisibility and getCurrentGame() then
          refreshGymGuideVisibility(getCurrentGame())
      end
  end)

  -- Map reloads are another way an overworld object list can be rebuilt.
  -- Reapply once after the rebuild instead of polling or fighting another mod
  -- every frame.
  mod.events:on("map.reloaded", function()
      if refreshGymGuideVisibility and getCurrentGame() then
          refreshGymGuideVisibility(getCurrentGame())
      end
  end)

  -- Gym victory scripts can hide the Guide after the map was already entered.
  -- Refresh once at battle teardown instead of fighting other mods every frame.
  mod.events:on("battle.ended", function()
      if refreshGymGuideVisibility and getCurrentGame() then
          refreshGymGuideVisibility(getCurrentGame())
      end
  end)

  end -- Gym Guide registration helper scope

  -- Scripted CANLOSE/tournament mods may intentionally heal survivors after
  -- battle. Compose with that behavior, but never allow an already-recorded
  -- Permadeath loss to be made usable again by a later battle.ended listener.
  -- Gold trainer scripts can reload the map without map.entered, so repeat the
  -- owned invariant at map.reloaded as well.
  do -- compiler-budget scope: external-save reconciliation
  -- 2.7.54: keep the reconciliation invariants testable without touching the
  -- live save. Production supplies the real storage locker/state adapter; the
  -- regression audit below supplies synthetic equivalents.
  local function reconcileExternalSaveStateCore(save, options)
      if type(save) ~= "table" then return false end
      options = type(options) == "table" and options or {}
      local getState = options.getState
      local setState = options.setState
      local lockMon = options.lockMon
      if type(getState) ~= "function" or type(setState) ~= "function" then return false end

      local enabled = getState("nuzlocke_enabled", true) ~= false
      local permadeath = getState("permadeath", true) == true

      -- Iterate backward because a successful locker may remove the current
      -- Pokemon from save.party. This must also handle adjacent locked entries.
      if type(lockMon) == "function" then
          for i = #(save.party or {}), 1, -1 do
              local mon = save.party[i]
              if type(mon) == "table" and mon.nuzlockePcLocked == true then
                  pcall(lockMon, mon, mon.nuzlockePcLockReason or "progression_exception")
              end
          end
      end

      if enabled and permadeath then
          for _, mon in ipairs(save.party or {}) do
              if type(mon) == "table" and mon.nuzlockeDead == true then mon.hp = 0 end
          end
      end

      local limit = math.max(1, math.min(6, math.floor(tonumber(
          getState("party_size_limit", defaultRuleValue("party_size_limit"))) or 6)))
      local count = #(save.party or {})
      local over = enabled and count > limit
      setState("nuzlocke_external_party_over_cap", over)
      setState("nuzlocke_external_party_count", count)
      setState("nuzlocke_external_party_limit", limit)
      return true
  end

  local function reconcileExternalSaveState(saveOverride)
      if saveBlocked() then return false end
      local save = saveOverride or (getCurrentGame() and getCurrentGame().save) or getCurrentSave()
      if type(save) ~= "table" then return false end
      local locker = mod.exports.__beta26.lockProgressionCatchInPc
      return reconcileExternalSaveStateCore(save, {
          getState = function(key, fallback) return mod.save:get(key, fallback) end,
          setState = function(key, value) mod.save:set(key, value) end,
          lockMon = type(locker) == "function" and function(mon, reason)
              return locker(getCurrentGame() or mod.game, mon, reason)
          end or nil,
      })
  end
  mod.exports.__beta26.reconcileExternalSaveState = reconcileExternalSaveState

  -- Synthetic regression coverage for the three external-save repair jobs.
  -- This never reads or writes the player's save and deliberately exercises
  -- adjacent locked Pokemon so reverse-iteration mutation safety is frozen in.
  mod.exports.__beta26.externalSaveReconciliationAudit = function()
      local report = { ok=true, checked=0, failures={} }
      local function check(id, condition)
          report.checked = report.checked + 1
          if condition then return end
          report.ok = false
          report.failures[#report.failures + 1] = tostring(id)
      end
      local lockedA = { species="A", nuzlockePcLocked=true }
      local lockedB = { species="B", nuzlockePcLocked=true }
      local dead = { species="DEAD", nuzlockeDead=true, hp=17 }
      local live = { species="LIVE", hp=20 }
      local save = { party={ live, lockedA, lockedB, dead }, boxes={} }
      local state = { nuzlocke_enabled=true, permadeath=true, party_size_limit=1 }
      local stored = {}
      local function syntheticLocker(mon)
          for i = #save.party, 1, -1 do
              if save.party[i] == mon then
                  table.remove(save.party, i)
                  stored[#stored + 1] = mon
                  return true
              end
          end
          return false
      end
      local ok = reconcileExternalSaveStateCore(save, {
          getState=function(key, fallback)
              local value = state[key]; if value == nil then return fallback end; return value
          end,
          setState=function(key, value) state[key] = value end,
          lockMon=syntheticLocker,
      })
      check("core_completed", ok == true)
      check("adjacent_locks_stored", #stored == 2
          and ((stored[1] == lockedB and stored[2] == lockedA)
            or (stored[1] == lockedA and stored[2] == lockedB)))
      check("locked_removed_from_party", #save.party == 2
          and save.party[1] == live and save.party[2] == dead)
      check("dead_hp_rezeroed", dead.hp == 0)
      check("over_cap_detected", state.nuzlocke_external_party_over_cap == true
          and state.nuzlocke_external_party_count == 2
          and state.nuzlocke_external_party_limit == 1)
      check("live_mon_untouched", live.hp == 20)
      return report
  end

  mod.events:on("save.loaded", function(ev)
      pcall(reconcileExternalSaveState, ev and ev.save)
  end)
  mod.events:on("game.ready", function(ev)
      local game = type(ev) == "table" and ev.game or ev
      pcall(reconcileExternalSaveState, game and game.save)
  end)
  mod.events:on("battle.ended", function()
      pcall(reconcileExternalSaveState)
  end)
  mod.events:on("map.reloaded", function()
      pcall(reconcileExternalSaveState)
  end)
  mod.events:on("map.entered", function()
      pcall(reconcileExternalSaveState)
  end)

  end -- external-save reconciliation scope


  ---------------------------------------------------------------------
  -- TRACKER SCREEN
  ---------------------------------------------------------------------
  ---------------------------------------------------------------------
  -- LEGACY CATCH RECOVERY SCREEN
  --
  -- Select a legacy Pokemon, then select one of the areas that the current
  -- encounter data says could contain that species. Choosing an area records
  -- it as a retroactive catch and removes it from LEGACY.
  ---------------------------------------------------------------------
  mod.content.screens:register("NuzlockeLegacyRecoveryScreen", {
      new = function(game)
          local self = {
              game = game,
              isOpaque = true,
              cursor = 1,
              areaCursor = 1,
              mode = "list",
              scroll = 0,
              actionCursor = 1,
              typeCursor = 1,
              pendingArea = nil,
          }

          -- 2.5.61: Recovery/Encounter editing is maintenance UI over mutable
          -- save state. Reject stale/impossible combinations explicitly and
          -- convert unexpected exceptions into player-paced reportable text.
          local function showRecoveryMessage(title, detail, code)
              -- 2.5.62: keep recovery validation/error feedback owned by this
              -- screen. Pushing a TextBox from this maintenance editor could
              -- leave input apparently frozen while the state stack unwound.
              self.notice = {
                  title = tostring(title or "RECOVERY"),
                  detail = tostring(detail or "Unknown recovery error."),
                  code = code and tostring(code) or nil,
              }
              return true
          end

          local recoveryTypes = {
              "wild", "grass", "surf", "fishing", "overworld",
              "static", "gift", "trade", "safari", "unknown",
          }

          local function entries()
              local out = {}
              local legacy = trackerLog().__LEGACY__
              local mons = collectLegacyMons(game.save or {})
              local usedLegacyMons = {}

              if type(legacy) == "table" then
                  for _, savedEntry in ipairs(legacy) do
                      if type(savedEntry) == "table" then
                          -- IMPORTANT: tracker_log is persisted save data.
                          -- Never attach live Pokemon objects or UI-only fields
                          -- directly to a saved legacy record. 29.3.16 could
                          -- mutate savedEntry.mon here and REMOVE ENTRY would
                          -- later serialize that live object back through
                          -- mod.save:set("tracker_log"), which can fatally
                          -- break save serialization on existing Yellow saves.
                          local entry = {}
                          for k, v in pairs(savedEntry) do
                              if k ~= "mon" and k ~= "logEntry" then entry[k] = v end
                          end
                          entry.provenance = entry.provenance or "LEGACY"
                          entry.savedEntry = savedEntry

                          -- Attach the actual save Pokemon only to the detached
                          -- UI view. Manual assignment/removal can still update
                          -- the real mon without contaminating tracker_log.
                          local sp = tostring(entry.species or ""):upper()
                          for i, mon in ipairs(mons) do
                              local idMatch = entry.pokemonId
                                  and Identity.pokemonIdentity(mon) == entry.pokemonId
                              local speciesMatch = tostring(mon and mon.species or ""):upper() == sp
                              if not usedLegacyMons[i]
                                  and type(mon) == "table"
                                  and (idMatch or speciesMatch)
                                  and (mon.nuzlockeOrigin == "LEGACY"
                                      or mon.nuzlockeOrigin == "EDITED"
                                      or mon.nuzlockeOrigin == "PLAYER_CONFIRMED")
                                  and not mon.catchLocation then
                                  entry.mon = mon
                                  usedLegacyMons[i] = true
                                  break
                              end
                          end
                          out[#out + 1] = entry
                      end
                  end
              end

              -- Edited Pokemon are current-save objects that were not present
              -- in the Nuzlocke baseline and were not registered by an
              -- acquisition hook. They can be recovered exactly like unknown
              -- legacy Pokemon, but retain EDITED provenance.
              for i, mon in ipairs(mons) do
                  if not usedLegacyMons[i] and type(mon) == "table" and mon.species
                      and mon.nuzlockeOrigin == "EDITED"
                      and not mon.catchLocation then
                      out[#out + 1] = {
                          species = mon.species,
                          isShiny = Identity.isShiny(mon),
                          provenance = "EDITED",
                          mon = mon,
                      }
                      usedLegacyMons[i] = true
                  end
              end

              -- Recovered/player-confirmed records remain editable. Limit the
              -- editor to recovery provenance so ordinary catches cannot be
              -- rewritten accidentally from this maintenance screen.
              for area, catches in pairs(trackerLog()) do
                  if area ~= "__LEGACY__" and type(catches) == "table" then
                      for _, catch in ipairs(catches) do
                          local provenance = type(catch) == "table"
                              and tostring(catch.provenance or "") or ""
                          local editable = type(catch) == "table"
                              and (catch.retroactive == true
                                  or catch.recoveryStatus == "PLAYER_CONFIRMED"
                                  or provenance == "LEGACY"
                                  or provenance == "EDITED"
                                  or provenance == "PLAYER_CONFIRMED")
                          if editable then
                              local attached
                              for i, mon in ipairs(mons) do
                                  local idMatch = catch.pokemonId
                                      and Identity.pokemonIdentity(mon) == catch.pokemonId
                                  local locationMatch = routeKey(mon and mon.catchLocation)
                                      == routeKey(area)
                                  local speciesMatch = tostring(
                                      mon and mon.species or ""):upper()
                                      == tostring(catch.species or ""):upper()
                                  if not usedLegacyMons[i] and type(mon) == "table"
                                      and (idMatch or (locationMatch and speciesMatch)) then
                                      attached = mon
                                      usedLegacyMons[i] = true
                                      break
                                  end
                              end
                              out[#out + 1] = {
                                  assigned = true,
                                  area = area,
                                  species = catch.species,
                                  pokemonId = catch.pokemonId,
                                  fingerprint = catch.fingerprint,
                                  isShiny = catch.isShiny == true,
                                  encounterType = catch.encounterType or "unknown",
                                  provenance = provenance ~= "" and provenance
                                      or "PLAYER_CONFIRMED",
                                  possibleAreas = catch.possibleAreas,
                                  logEntry = catch,
                                  mon = attached,
                              }
                          end
                      end
                  end
              end
              return out
          end

          local function recoveryEncounterLimitApplies()
              if mod.save:get("nuzlocke_enabled", true) == false then return false end
              return mod.save:get("encounter_limit", defaultRuleValue("encounter_limit")) == true
          end

          local function areaAlreadyHasEncounter(log, areas, area, ignoredCatch)
              if not area then return false end
              local catches = log[area]
              if type(catches) == "table" then
                  for _, catch in ipairs(catches) do
                      if catch ~= ignoredCatch then return true end
                  end
              end
              -- caught_areas is a summary and cannot identify ownership. It is
              -- safe to ignore only when this editor record is the sole log row.
              if areas[area] ~= nil then
                  return not (ignoredCatch ~= nil and type(catches) == "table"
                      and #catches == 1 and catches[1] == ignoredCatch)
              end
              return false
          end

          local function filterRecoveryAreas(rawAreas, entry)
              local log = trackerLog()
              local areas = caughtAreas()
              local filtered = {}
              for _, area in ipairs(rawAreas or {}) do
                  if type(area) == "table" then
                      area = area.id or area.mapId or area.key
                  end
                  if area and (not recoveryEncounterLimitApplies()
                      or not areaAlreadyHasEncounter(log, areas, area,
                          entry and entry.logEntry)) then
                      filtered[#filtered + 1] = area
                  end
              end
              return filtered
          end

          local function candidates(entry)
              if not entry then return {} end

              local raw = nil
              if not entry.assigned and type(entry.possibleAreas) == "table"
                  and #entry.possibleAreas > 0 then
                  raw = entry.possibleAreas
              end

              if not raw and not entry.assigned then
                  local providerHistory = mod.save:get("encounter_provider_history")
                  local providerWasUsed = type(providerHistory) == "table" and next(providerHistory) ~= nil
                  if not providerWasUsed and not activeCompatProvider("encounters", game, nil) then
                      local inferred = legacyCandidates(game, entry.species)
                      if #inferred > 0 then raw = inferred end
                  end
              end

              -- UNKNOWN means the engine data cannot prove a wild source.
              -- At that point the player is explicitly confirming history,
              -- so offer the full known area list instead of inventing a
              -- location automatically.
              if not raw then
                  raw = {}
                  for _, route in ipairs(getDisplayRoutes(game)) do
                      if type(route) == "table" then
                          raw[#raw + 1] = route.id
                      elseif route ~= nil then
                          raw[#raw + 1] = route
                      end
                  end
              end

              return filterRecoveryAreas(raw, entry)
          end

          local function refreshCaughtArea(log, areas, area)
              if not area then return end
              local catches = log[area]
              if type(catches) == "table" and #catches > 0 then
                  areas[area] = catches[1].species or areas[area]
              else
                  areas[area] = nil
              end
          end

          local function detachAssignedEntry(entry, keepPending)
              if not (entry and entry.assigned and entry.area and entry.logEntry) then
                  return false
              end
              local log = trackerLog()
              local areas = caughtAreas()
              local catches = log[entry.area]
              if type(catches) == "table" then
                  local remaining = {}
                  for _, catch in ipairs(catches) do
                      if catch ~= entry.logEntry then remaining[#remaining + 1] = catch end
                  end
                  log[entry.area] = #remaining > 0 and remaining or nil
              end
              refreshCaughtArea(log, areas, entry.area)

              if keepPending then
                  log.__LEGACY__ = type(log.__LEGACY__) == "table"
                      and log.__LEGACY__ or {}
                  log.__LEGACY__[#log.__LEGACY__ + 1] = {
                      species = entry.species,
                      pokemonId = entry.pokemonId,
                      fingerprint = entry.fingerprint,
                      isShiny = entry.isShiny == true,
                      possibleAreas = entry.possibleAreas,
                      provenance = entry.provenance or "PLAYER_CONFIRMED",
                      encounterType = entry.encounterType or "unknown",
                  }
              end

              if entry.mon then
                  entry.mon.catchLocation = nil
                  entry.mon.encounterType = entry.encounterType or "unknown"
                  entry.mon.nuzlockeTrackerRegistered = nil
                  local id = Identity.pokemonIdentity(entry.mon)
                  local registry = Identity.identityRegistry()
                  if id and type(registry[id]) == "table" then
                      registry[id].catchLocation = nil
                      mod.save:set(ID_REGISTRY_KEY, registry)
                  end
              end
              -- Defensive migration guard: old 29.3.16 recovery UI
              -- sessions could have leaked transient live-Pokemon references
              -- into __LEGACY__. Strip only known UI-only fields before the
              -- tracker table crosses the save serializer again.
              if type(log.__LEGACY__) == "table" then
                  for _, legacyEntry in ipairs(log.__LEGACY__) do
                      if type(legacyEntry) == "table" then
                          legacyEntry.mon = nil
                          legacyEntry.logEntry = nil
                          legacyEntry.savedEntry = nil
                      end
                  end
              end
              mod.save:set("tracker_log", log)
              mod.save:set("caught_areas", areas)
              return true
          end

          local function chooseArea(entry, area, encounterType)
              if type(entry) ~= "table" then
                  return false, Strings("That recovery entry is no longer available.")
              end
              area = type(area) == "table" and (area.id or area.mapId or area.key)
                  or area
              if area == nil or tostring(area) == "" then
                  return false, Strings("That encounter area is invalid.")
              end
              -- 2.5.64: normalize the picker value once before it can become a
              -- tracker/save table key. The picker may surface provider/display
              -- aliases; registerArea() is the authoritative validator/canonicalizer.
              -- 2.5.66: Recovery assignment is a maintenance transaction. The
              -- picker may surface provider/display aliases, so canonicalize under
              -- protection and require a non-empty STRING key before any table
              -- read/write uses the selected area.
              local okArea, canonicalArea = pcall(registerArea, area)
              area = okArea and canonicalArea or nil
              if type(area) ~= "string" or area == "" then
                  return false, Strings("That encounter area cannot be stored. Choose another area.")
              end
              local log = trackerLog()
              local areas = caughtAreas()
              local legacy = type(log.__LEGACY__) == "table" and log.__LEGACY__ or {}
              local sp = tostring(entry.species or ""):upper()
              if sp == "" then
                  return false, Strings("That recovery entry has no species.")
              end
              local sourceMon = type(entry.mon) == "table" and entry.mon or nil

              -- A manual recovery is a new player confirmation, so it must not
              -- create a second current encounter in an area that already has
              -- one when the 1st Catch rule is active. Existing historical log
              -- entries are preserved; only new assignments are blocked.
              if recoveryEncounterLimitApplies()
                  and areaAlreadyHasEncounter(log, areas, area, entry.logEntry) then
                  return false, Strings("That area already has an encounter. Choose another area.")
              end

              local oldArea = entry.assigned and entry.area or nil
              if entry.assigned then
                  detachAssignedEntry(entry, false)
                  log = trackerLog()
                  areas = caughtAreas()
              end

              -- Build the recovered row OFF-TABLE first. Identity enrichment is
              -- useful but not required for manual recovery, so malformed imported
              -- Pokemon metadata degrades to species/fingerprint recovery instead
              -- of aborting a valid Route assignment.
              -- 2.7.78: preserve a saved legacy identity even when no live mon
              -- can be attached to the editor view. Manual recovery moves the
              -- existing encounter identity; it never manufactures an anonymous copy.
              local recoveredId = entry.pokemonId
              local recoveredFingerprint = entry.fingerprint
              if sourceMon then
                  local okId, id = pcall(Identity.ensurePokemonIdentity, sourceMon,
                      self.game and self.game.save,
                      entry.provenance or "PLAYER_CONFIRMED")
                  if okId and id ~= nil then recoveredId = id
                  elseif type(Identity.pokemonIdentity) == "function" then
                      local okExisting, existing = pcall(Identity.pokemonIdentity, sourceMon)
                      if okExisting and existing ~= nil then recoveredId = existing end
                  end
                  local okFp, fp = pcall(Identity.fingerprint, sourceMon)
                  if okFp and fp ~= nil then recoveredFingerprint = fp end
              end
              local recoveredRow = {
                  species = sp,
                  pokemonId = recoveredId,
                  fingerprint = recoveredFingerprint,
                  isShiny = entry.isShiny == true,
                  encounterType = encounterType or entry.encounterType or "wild",
                  encounterSource = "manual",
                  recoveryStatus = "PLAYER_CONFIRMED",
                  provenance = entry.provenance or "PLAYER_CONFIRMED",
                  retroactive = true,
              }
              local areaEntries = {}
              if type(log[area]) == "table" then
                  for i, row in ipairs(log[area]) do areaEntries[i] = row end
              end
              areaEntries[#areaEntries + 1] = recoveredRow

              -- Commit tracker tables only after all required keys and row fields
              -- are valid. Live-Pokemon provenance below is best effort and can no
              -- longer invalidate the tracker confirmation itself.
              log[area] = areaEntries
              if areas[area] == nil then areas[area] = sp end
              markVisited(area)
              if oldArea then refreshCaughtArea(log, areas, oldArea) end

              if sourceMon then
                  pcall(function()
                      sourceMon.catchLocation = area
                      sourceMon.encounterType = encounterType
                          or entry.encounterType or "wild"
                      sourceMon.nuzlockeTrackerRegistered = true
                      Identity.setPokemonOrigin(sourceMon, "PLAYER_CONFIRMED")
                      Identity.baselineAdd(sourceMon, "PLAYER_CONFIRMED")
                  end)
              end

              local remaining = {}
              local removed = false
              local savedEntry = entry.savedEntry or entry
              for _, e in ipairs(legacy) do
                  if not removed and e == savedEntry then
                      removed = true
                  else
                      table.insert(remaining, e)
                  end
              end

              if #remaining > 0 then
                  log.__LEGACY__ = remaining
              else
                  log.__LEGACY__ = nil
              end

              if type(log.__LEGACY__) == "table" then
                  for _, legacyEntry in ipairs(log.__LEGACY__) do
                      if type(legacyEntry) == "table" then
                          legacyEntry.mon = nil
                          legacyEntry.logEntry = nil
                          legacyEntry.savedEntry = nil
                      end
                  end
              end
              mod.save:set("tracker_log", log)
              mod.save:set("caught_areas", areas)
              return true
          end

          local function updateEncounterType(entry, encounterType)
              if not (entry and entry.assigned and entry.logEntry) then
                  return false, Strings("That recovery entry changed. Re-open it and try again.")
              end
              entry.logEntry.encounterType = encounterType
              entry.logEntry.encounterSource = "manual"
              entry.encounterType = encounterType
              if entry.mon then entry.mon.encounterType = encounterType end
              mod.save:set("tracker_log", trackerLog())
              return true
          end

          function self:update(dt)
              if self.notice then
                  if self.game.input:wasPressed("a")
                      or self.game.input:wasPressed("b")
                      or self.game.input:wasPressed("start") then
                      self.notice = nil
                  end
                  return
              end
              local list = entries()
              if #list == 0 then
                  if self.game.input:wasPressed("b") or self.game.input:wasPressed("a") then
                      self.game.stack:pop()
                  end
                  return
              end

              if self.game.input:wasPressed("b") then
                  if self.mode == "areas" or self.mode == "actions" then
                      self.mode = "list"
                      self.areaCursor = 1
                      self.actionCursor = 1
                      self.pendingArea = nil
                  elseif self.mode == "types" then
                      self.mode = self.pendingArea and "areas" or "actions"
                      self.typeCursor = 1
                  else
                      self.game.stack:pop()
                  end
                  return
              end

              if self.mode == "list" then
                  if self.game.input:wasPressed("down") then
                      self.cursor = math.min(#list, self.cursor + 1)
                  elseif self.game.input:wasPressed("up") then
                      self.cursor = math.max(1, self.cursor - 1)
                  elseif self.game.input:wasPressed("a") then
                      local entry = list[self.cursor]
                      if entry and entry.assigned then
                          self.mode = "actions"
                          self.actionCursor = 1
                      else
                          local c = candidates(entry)
                          if #c > 0 then
                              self.mode = "areas"
                              self.areaCursor = 1
                          end
                      end
                  end
              elseif self.mode == "actions" then
                  local entry = list[self.cursor]
                  if not entry then
                      self.mode = "list"
                      self.actionCursor = 1
                      showRecoveryMessage("RECOVERY CHANGED",
                          "That entry is no longer available. The list was refreshed.")
                      return
                  end
                  local actions = { "CHANGE AREA", "CHANGE TYPE", "REMOVE ENTRY" }
                  if self.game.input:wasPressed("down") then
                      self.actionCursor = math.min(#actions, self.actionCursor + 1)
                  elseif self.game.input:wasPressed("up") then
                      self.actionCursor = math.max(1, self.actionCursor - 1)
                  elseif self.game.input:wasPressed("a") then
                      if self.actionCursor == 1 then
                          self.mode = "areas"
                          self.areaCursor = 1
                      elseif self.actionCursor == 2 then
                          self.pendingArea = nil
                          self.mode = "types"
                          for i, value in ipairs(recoveryTypes) do
                              if value == entry.encounterType then self.typeCursor = i end
                          end
                      elseif self.actionCursor == 3
                          and detachAssignedEntry(entry, true) then
                          self.cursor = math.min(self.cursor, math.max(1, #entries()))
                          self.mode = "list"
                      end
                  end
              elseif self.mode == "areas" then
                  local entry = list[self.cursor]
                  if not entry then
                      self.mode = "list"
                      self.areaCursor = 1
                      self.pendingArea = nil
                      showRecoveryMessage("RECOVERY CHANGED",
                          "That entry is no longer available. The list was refreshed.")
                      return
                  end
                  local c = candidates(entry)
                  if #c == 0 then
                      self.mode = "list"
                      return
                  end

                  if self.game.input:wasPressed("down") then
                      self.areaCursor = math.min(#c, self.areaCursor + 1)
                  elseif self.game.input:wasPressed("up") then
                      self.areaCursor = math.max(1, self.areaCursor - 1)
                  elseif self.game.input:wasPressed("a") then
                      local area = c[self.areaCursor]
                      if type(area) == "table" then
                          area = area.id or area.mapId or area.key
                      end
                      self.pendingArea = area
                      self.mode = "types"
                      self.typeCursor = 1
                      for i, value in ipairs(recoveryTypes) do
                          if value == (entry.encounterType or "wild") then
                              self.typeCursor = i
                          end
                      end
                  end
              elseif self.mode == "types" then
                  local entry = list[self.cursor]
                  if not entry then
                      self.mode = "list"
                      self.pendingArea = nil
                      showRecoveryMessage("RECOVERY CHANGED",
                          "That entry is no longer available. The list was refreshed.")
                      return
                  end
                  if self.game.input:wasPressed("down") then
                      self.typeCursor = math.min(#recoveryTypes, self.typeCursor + 1)
                  elseif self.game.input:wasPressed("up") then
                      self.typeCursor = math.max(1, self.typeCursor - 1)
                  elseif self.game.input:wasPressed("a") then
                      local encounterType = recoveryTypes[self.typeCursor]
                      local ok, reason
                      if self.pendingArea then
                          ok, reason = chooseArea(entry, self.pendingArea, encounterType)
                      else
                          ok, reason = updateEncounterType(entry, encounterType)
                      end
                      if ok then
                          self.cursor = math.min(self.cursor, math.max(1, #entries()))
                          self.mode = "list"
                          self.pendingArea = nil
                      else
                          showRecoveryMessage("RECOVERY INVALID",
                              reason or "That change cannot be applied. No data was changed.")
                      end
                  end
              end
          end

          function self:draw()
              local Font = mod.ui.Font
              if self.notice then
                  local Theme = require("src.ui.Theme")
                  love.graphics.setColor(1, 1, 1, 1)
                  love.graphics.rectangle("fill", 0, 0, 160, 144)
                  love.graphics.setColor(0, 0, 0, 1)
                  love.graphics.rectangle("line", 6, 6, 148, 132)
                  love.graphics.rectangle("line", 8, 8, 144, 128)
                  love.graphics.setColor(1, 1, 1, 1)
                  local function centered(text, y)
                      text = tostring(text or "")
                      local width = type(Font.width) == "function"
                          and Font.width(text) or (#text * 8)
                      Font.draw(text, math.max(12, math.floor((160 - width) / 2)), y)
                  end
                  local titleLines = wrapText(tostring(self.notice.title or "RECOVERY"), 16)
                  local y = 14
                  for i = 1, math.min(#titleLines, 2) do
                      centered(titleLines[i], y)
                      y = y + 12
                  end
                  y = y + 6
                  local text = tostring(self.notice.detail or "")
                  if self.notice.code then
                      text = text .. " CODE " .. tostring(self.notice.code)
                  end
                  local lines = wrapText(text, 16)
                  for i = 1, math.min(#lines, 6) do
                      centered(lines[i], y)
                      y = y + 12
                  end
                  centered(Strings("A/B:BACK"), 126)
                  return
              end
              local list = entries()
              local function fitRecoveryText(value, glyphBudget)
                  local out = tostring(value or "")
                  if type(Font.split) ~= "function" then return out end
                  local spans = Font.split(out)
                  if #spans <= glyphBudget then return out end
                  local span = spans[glyphBudget]
                  return span and span.to and out:sub(1, span.to) or out
              end

              Font.drawBox(0, 0, 20, 18)

              if #list == 0 then
                  if mod.exports.__beta26.runtimeIsGen2(self.game) then
                      mod.exports.__beta26.drawGen2NuzTitle(nil, Font, "RECOVER CATCHES")
                  else
                      Font.draw(Strings("RECOVER CATCHES"), 12, 10)
                  end
                  Font.draw(Strings("ALL RECOVERED!"), 18, 52)
                  Font.draw(Strings("B:BACK"), 54, 122)
                  return
              end

              if self.mode == "list" then
                  if mod.exports.__beta26.runtimeIsGen2(self.game) then
                      mod.exports.__beta26.drawGen2NuzTitle(nil, Font,
                          "RECOVER CATCHES", "SELECT A POKEMON",
                          { row = 1, subtitleRow = 3 })
                  else
                      Font.draw(Strings("RECOVER CATCHES"), 16, 10)
                      Font.draw(Strings("SELECT A POKEMON"), 12, 24)
                  end

                  local start = math.max(1, math.min(self.cursor - 3, #list - 5))
                  for i = start, math.min(#list, start + 5) do
                      local y = 40 + ((i - start) * 14)
                      if i == self.cursor then Font.drawCode((require("src.ui.Theme")).cursor, 12, y) end
                      local entry = list[i]
                      local sp = tostring(entry.species or "???")
                      local prefix = entry.assigned and "* "
                          or (entry.provenance == "EDITED" and "E " or "L ")
                      Font.draw(prefix .. sp:sub(1, 10), 30, y)
                      if entry.assigned then
                          Font.draw(Strings("EDIT"), 122, y)
                      else
                          local count = type(entry.possibleAreas) == "table"
                              and #entry.possibleAreas or 0
                          Font.draw(count > 0 and tostring(count) or "?", 128, y)
                      end
                  end

                  Font.draw(Strings("A:CHOOSE"), 16, 126)
                  Font.draw(Strings("B:BACK"), 100, 126)
              elseif self.mode == "actions" then
                  local entry = list[self.cursor]
                  if mod.exports.__beta26.runtimeIsGen2(self.game) then
                      mod.exports.__beta26.drawGen2NuzTitle(nil, Font,
                          "EDIT RECOVERY", tostring(entry.species or "???"):sub(1, 12),
                          { row = 1, subtitleRow = 3 })
                  else
                      Font.draw(Strings("EDIT RECOVERY"), 22, 10)
                      Font.draw(tostring(entry.species or "???"):sub(1, 12), 48, 24)
                  end
                  local actions = { "CHANGE AREA", "CHANGE TYPE", "REMOVE ENTRY" }
                  for i, action in ipairs(actions) do
                      local y = 48 + (i - 1) * 20
                      if i == self.actionCursor then
                          Font.drawCode((require("src.ui.Theme")).cursor, 12, y)
                      end
                      Font.draw(Strings(action), 30, y)
                  end
                  Font.draw(Strings("A:CHOOSE"), 16, 126)
                  Font.draw(Strings("B:BACK"), 100, 126)
              elseif self.mode == "types" then
                  local entry = list[self.cursor]
                  Font.draw(Strings("ENCOUNTER TYPE"), 16, 10)
                  Font.draw(tostring(entry.species or "???"):sub(1, 12), 48, 24)
                  local start = math.max(1,
                      math.min(self.typeCursor - 3, #recoveryTypes - 5))
                  for i = start, math.min(#recoveryTypes, start + 5) do
                      local y = 42 + ((i - start) * 14)
                      if i == self.typeCursor then
                          Font.drawCode((require("src.ui.Theme")).cursor, 12, y)
                      end
                      Font.draw(Strings(recoveryTypes[i]:upper()), 30, y)
                  end
                  Font.draw(Strings("A:CONFIRM"), 16, 126)
                  Font.draw(Strings("B:BACK"), 100, 126)
              elseif self.mode == "areas" then
                  local entry = list[self.cursor]
                  local c = candidates(entry)
                  Font.draw(Strings(entry.assigned and "CHANGE AREA?"
                      or "WHERE CAUGHT?"), 26, 10)
                  Font.draw(tostring(entry.species or "???"):sub(1, 12), 48, 24)

                  if #c == 0 then
                      Font.draw(Strings("NO AVAILABLE AREAS"), 16, 58)
                      if recoveryEncounterLimitApplies() then
                          Font.draw(Strings("AREAS ALREADY TAKEN"), 10, 76)
                      else
                          Font.draw(Strings("NO KNOWN AREAS"), 30, 76)
                      end
                      Font.draw(Strings("B:BACK"), 100, 126)
                      return
                  end

                  local start = math.max(1, math.min(self.areaCursor - 3, #c - 5))
                  for i = start, math.min(#c, start + 5) do
                      local y = 42 + ((i - start) * 14)
                      if i == self.areaCursor then Font.drawCode((require("src.ui.Theme")).cursor, 12, y) end
                      local areaId = c[i]
                      if type(areaId) == "table" then
                          areaId = areaId.id or areaId.mapId or areaId.key
                      end
                      Font.draw(fitRecoveryText(routeName(areaId), 15), 30, y)
                  end

                  Font.draw(Strings("A:ASSIGN"), 16, 126)
                  Font.draw(Strings("B:BACK"), 100, 126)
              end
          end

          -- Runtime boundary for the entire recovery editor. Draw failures are
          -- deferred to update so StateStack is never changed during rendering.
          do
              local pendingRecoveryError
              local rawRecoveryUpdate = self.update
              local rawRecoveryDraw = self.draw
              local function queueRecoveryError(phase, err)
                  if pendingRecoveryError then return end
                  local traceback = tostring(err or "unknown recovery error")
                  local code = mod.exports.__beta26.Dev.errorCode(
                      "recovery_" .. tostring(phase), traceback)
                  pendingRecoveryError = {
                      phase = tostring(phase), detail = traceback, code = code,
                  }
                  pcall(mod.exports.__beta26.Dev.recordError,
                      "recovery_" .. tostring(phase), traceback, self.game)
              end
              local function presentRecoveryError()
                  if not pendingRecoveryError then return false end
                  local failure = pendingRecoveryError
                  pendingRecoveryError = nil
                  self.mode = "list"
                  self.pendingArea = nil
                  self.areaCursor = 1
                  self.actionCursor = 1
                  local short = tostring(failure.detail):gsub("^.-:%s*", "")
                  if #short > 150 then short = short:sub(1, 150) .. "..." end
                  showRecoveryMessage("RECOVERY "
                      .. tostring(failure.phase):upper() .. " ERROR",
                      short, failure.code)
                  return true
              end
              self.update = function(...)
                  if presentRecoveryError() then return end
                  local args = { ... }
                  local ok, result = xpcall(function()
                      return rawRecoveryUpdate(unpackValues(args))
                  end, debug and debug.traceback or tostring)
                  if not ok then
                      queueRecoveryError("update", result)
                      presentRecoveryError()
                      return
                  end
                  return result
              end
              self.draw = function(...)
                  if pendingRecoveryError then return end
                  local args = { ... }
                  local ok, result = xpcall(function()
                      return rawRecoveryDraw(unpackValues(args))
                  end, debug and debug.traceback or tostring)
                  if not ok then queueRecoveryError("draw", result) end
                  return ok and result or nil
              end
          end

          return self
      end
  })

  mod.content.screens:register("NuzlockeDevToolsScreen", {
      new = function(game)
          local rememberedDev = uiRememberedScreen(game, "dev_report")
          local self = {
              game = game,
              screenId = "NuzlockeDevToolsScreen",
              isOpaque = true,
              cursor = math.max(1, math.min(6,
                  math.floor(tonumber(rememberedDev.cursor) or 1))),
              status = "READY",
              lastTestStatus = "NOT RUN",
              snapshotStatus = "NOT RUN",
              exportInfo = nil,
              reportScroll = math.max(0,
                  math.floor(tonumber(rememberedDev.reportScroll) or 0)),
              reportSection = math.max(1, math.min(5,
                  math.floor(tonumber(rememberedDev.reportSection) or 1))),
              viewingReport = false,
              viewingFileInfo = false,
              fileInfoScroll = 0,
              viewingKnownIssues = false,
              knownIssuesScroll = 0,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)

          local function cachedReport()
              if type(self.liveReportText) == "string"
                  and self.liveReportText ~= "" then
                  return self.liveReportText
              end
              return tostring(mod.exports.__beta26.Dev.lastExportText or "")
          end

          local function refreshLiveReport()
              local ok, text, report = pcall(
                  mod.exports.__beta26.Dev.selfTestText, self.game)
              if ok and type(text) == "string" and text ~= "" then
                  self.liveReportText = text
                  self.liveReport = report
                  local code
                  if type(report) == "table"
                      and type(mod.exports.__beta26.Dev.reportCode) == "function" then
                      local okCode, generated = pcall(
                          mod.exports.__beta26.Dev.reportCode,
                          self.game, report, text)
                      if okCode and type(generated) == "string"
                          and generated ~= "" then
                          code = generated
                          report.report_code = generated
                      end
                  end
                  self.reportCode = code
                  self.status = "LIVE REPORT"
                  return true
              end
              local detail = tostring(text or "The live report could not be generated.")
              local code = mod.exports.__beta26.Dev.errorCode("dev_report", detail)
              pcall(mod.exports.__beta26.Dev.recordError,
                  "dev_report", detail, self.game)
              self.devError = {
                  title = "DEV REPORT ERROR", detail = detail, code = code,
              }
              self.status = "REPORT ERROR"
              return false
          end

          local function reloadStoredReport()
              local ok, info =
                  mod.exports.__beta26.Dev.reloadStoredSelfTest(self.game)
              if ok and type(info) == "table" then
                  self.exportInfo = info
                  self.liveReportText = nil
                  self.liveReport = nil
                  self.reportCode = nil
                  self.status = "LOADED"
                  self.snapshotStatus = "LOADED"
                  return true
              end
              self.status = "LOAD FAIL"
              return false
          end

          -- 2.5.7: Dev diagnostics must stay readable on the native 160px R/B/Y
          -- surface. The general wrapText helper is word-aware but deliberately
          -- leaves a single long token intact, which is wrong for report codes,
          -- playthrough IDs, storage keys, and other diagnostic identifiers.
          -- Keep a Dev-only hard wrapper so every emitted row respects the
          -- viewport width without changing normal menu/description wrapping.
          local function devUiWrapText(text, width)
              width = math.max(8, math.floor(tonumber(width) or 16))
              local out = {}
              local line = ""

              local function flush()
                  if line ~= "" then
                      out[#out + 1] = line
                      line = ""
                  end
              end

              local function appendToken(token)
                  token = tostring(token or "")
                  while #token > width do
                      if line ~= "" then flush() end
                      out[#out + 1] = token:sub(1, width)
                      token = token:sub(width + 1)
                  end
                  if token == "" then return end
                  if line == "" then
                      line = token
                  elseif #line + 1 + #token <= width then
                      line = line .. " " .. token
                  else
                      flush()
                      line = token
                  end
              end

              for token in tostring(text or ""):gmatch("%S+") do
                  appendToken(token)
              end
              flush()
              if #out == 0 then out[1] = "" end
              return out
          end

          local function appendReportCodeLines(code, width, out)
              out[#out + 1] = "REPORT CODE:"
              local groups = {}
              for group in tostring(code or ""):gmatch("[^-]+") do
                  groups[#groups + 1] = group
              end
              if #groups == 0 then return end

              -- 2.5.44: balance the fixed four-character report-code groups across
              -- viewport-safe rows instead of greedy wrapping. Greedy wrapping
              -- could leave the final two-character checksum fragment alone on
              -- a row (for example the 2.5.43 screenshot's orphaned "D8").
              local maxGroups = math.max(1,
                  math.floor((math.max(5, tonumber(width) or 16) + 1) / 5))
              local rowCount = math.max(1, math.ceil(#groups / maxGroups))
              local base = math.floor(#groups / rowCount)
              local extra = #groups - (base * rowCount)
              local counts = {}
              for i = 1, rowCount do counts[i] = base end
              if extra > 0 then
                  counts[1] = counts[1] + 1
                  extra = extra - 1
              end
              if extra > 0 and rowCount > 1 then
                  counts[rowCount] = counts[rowCount] + 1
                  extra = extra - 1
              end
              local at = 2
              while extra > 0 do
                  if at >= rowCount then at = 2 end
                  counts[at] = counts[at] + 1
                  extra = extra - 1
                  at = at + 1
              end

              local groupAt = 1
              for row = 1, rowCount do
                  local parts = {}
                  for _ = 1, counts[row] do
                      if groups[groupAt] then
                          parts[#parts + 1] = groups[groupAt]
                          groupAt = groupAt + 1
                      end
                  end
                  if #parts > 0 then
                      out[#out + 1] = table.concat(parts, "-")
                  end
              end
          end

          -- v0.2.x storage is deliberately opaque. Show the bound context and
          -- logical key without pretending Gen1Recomp gave the mod a host path.
          local function storageInfoLines(width)
              width = math.max(8, math.floor(tonumber(width) or 16))
              local e = mod.exports.__beta26.Dev.lastExport or {}
              local context = type(e.storageContext) == "table"
                  and e.storageContext or {}
              local lines = {}

              local function appendWrapped(text)
                  local wrapped = devUiWrapText(tostring(text or ""), width)
                  for _, wrappedLine in ipairs(wrapped) do
                      lines[#lines + 1] = wrappedLine
                  end
              end

              local function add(label, value)
                  appendWrapped(tostring(label))
                  value = tostring(value or "(none)")
                  if value == "" then value = "(empty)" end
                  appendWrapped(value)
              end

              appendWrapped("RUN TESTS always executes diagnostics.")
              appendWrapped("Snapshot persistence is optional.")
              local engine = context.engineVersion
                  or mod.exports.__beta26.recompCompatAudited or "UNKNOWN"
              local gameLabel = context.gameVersion
                  or (mod.exports.__beta26.Dev.gameLabel
                      and mod.exports.__beta26.Dev.gameLabel(self.game))
                  or "UNKNOWN"
              local playthrough = context.playthroughId
              if playthrough == nil or tostring(playthrough) == "" then
                  playthrough = e.verified == true and "ACTIVE"
                      or "SNAPSHOT UNAVAILABLE"
              end
              add("ENGINE:", engine)
              add("GAME:", gameLabel)
              add("PLAYTHROUGH:", playthrough)
              add("KEY:", e.storageKey or "dev/self_test_latest")
              appendWrapped("HOST PATH: NOT EXPOSED")
              local writeState = e.writeAttempted == false and "NOT ATTEMPTED"
                  or (e.writeReturned == true and "PASS" or "FAIL")
              appendWrapped("WRITE: " .. writeState)
              local readbackState
              if e.writeReturned ~= true then
                  readbackState = "NOT ATTEMPTED"
              elseif e.readBackMatches == true then
                  readbackState = "PASS"
              elseif e.readSucceeded == true then
                  readbackState = "FAIL"
              else
                  readbackState = "UNAVAILABLE"
              end
              appendWrapped("READBACK: " .. readbackState)
              appendWrapped("VERIFIED: " .. (e.verified == true and "YES" or "NO"))
              if e.historyKey then add("HISTORY:", e.historyKey) end
              if e.historyCount ~= nil then
                  appendWrapped("HISTORY COUNT: " .. tostring(e.historyCount))
              end
              if e.breadcrumbCount ~= nil then
                  appendWrapped("BREADCRUMBS: " .. tostring(e.breadcrumbCount))
              end
              if e.bytesRead ~= nil then
                  appendWrapped("SIZE: " .. tostring(e.bytesRead)
                      .. "/" .. tostring(e.expectedBytes or "?"))
              elseif e.writeReturned ~= true then
                  appendWrapped("SIZE: WRITE FAILED / "
                      .. tostring(e.expectedBytes or "?"))
              else
                  appendWrapped("SIZE: READBACK UNAVAILABLE / "
                      .. tostring(e.expectedBytes or "?"))
              end
              if e.storageCode then add("CODE:", e.storageCode) end
              if e.storageMessage then add("DETAIL:", e.storageMessage) end
              return lines
          end

          local function knownIssueLines(report, width)
              width = math.max(8, math.floor(tonumber(width) or 16))
              report = type(report) == "table" and report or {}
              local issues, seen = {}, {}
              local function addIssue(kind, text)
                  local key = tostring(kind) .. ":" .. tostring(text)
                  if seen[key] then return end
                  seen[key] = true
                  issues[#issues + 1] = tostring(kind) .. " " .. tostring(text)
              end

              local ih = report.install_health or {}
              for key, reason in pairs(ih.failures or {}) do
                  addIssue("FAIL", "INSTALL " .. tostring(key)
                      .. " " .. tostring(reason))
              end

              local hh = report.hook_health or {}
              local pending = 0
              for _, row in ipairs(hh.rows or {}) do
                  local state = tostring(row.state or ""):upper()
                  if state == "MISSING" then
                      addIssue("FAIL", "HOOK " .. tostring(
                          row.adapter_id or row.id or "?"))
                  elseif state == "PENDING" then
                      pending = pending + 1
                  end
              end
              if pending > 0 then
                  addIssue("INFO", "HOOKS PENDING " .. tostring(pending))
              end

              for _, row in ipairs(report.assertions or {}) do
                  local label = tostring(row.code or row.id or "?")
                      :gsub("[_%.]", " "):upper()
                  addIssue("WARN", "ASSERT " .. label)
              end

              local sw = report.safe_stop_writes or {}
              if sw.active == true then
                  addIssue("FAIL", "SAVE SAFE STOP " .. tostring(sw.reason or "ACTIVE"))
              end

              -- Only genuinely manual/runtime-only items live here. Automatic
              -- failures above disappear as soon as a refreshed report passes.
              addIssue("RUNTIME", "SILVER RANDOM STARTER")
              addIssue("RUNTIME", "RUN HISTORY PRODUCERS")

              if #issues == 0 then issues[1] = "NONE" end
              local out = {}
              for i, issue in ipairs(issues) do
                  local wrapped = devUiWrapText(tostring(i) .. ". " .. issue, width)
                  for _, line in ipairs(wrapped) do out[#out + 1] = line end
                  if i < #issues then out[#out + 1] = "" end
              end
              return out
          end

          local function devCompatSummaryLines(width)
              width = math.max(8, math.floor(tonumber(width) or 16))
              local audit = mod.exports.__beta26.compatContractAudit
              local okAudit, report = false, nil
              if type(audit) == "function" then okAudit, report = pcall(audit) end
              local contract = okAudit and type(report) == "table" and report.ok == true
                  and "OK" or "CHECK"
              local providerCount = 0
              local compat = mod.exports.nuzlocke_compat
              if compat and type(compat.providerCount) == "function" then
                  local ok, value = pcall(compat.providerCount)
                  if ok then providerCount = tonumber(value) or 0 end
              end
              local capInfo = mod.exports.__beta26.getNextLevelCapInfo
                  and mod.exports.__beta26.getNextLevelCapInfo(self.game and self.game.save) or nil
              local capText = type(capInfo) == "table" and tonumber(capInfo.cap) or nil
              local apiContract = mod.exports.__beta26.publicApiContract
              local raw = {
                  "IDENT " .. nuzCompatIdentityLine(self.game),
                  ("ENGINE PROFILE %s"):format(contract),
                  ("COMPAT API %d PROVIDERS %d"):format(
                      tonumber(mod.exports.__beta26.compatibilityApi) or 0, providerCount),
                  ("API %s / %s"):format(
                      tostring(type(apiContract) == "table" and apiContract.owner or "?"),
                      tostring(type(apiContract) == "table" and apiContract.stability or "?")),
                  capText and (capText >= 100 and "CURRENT CAP MAX"
                      or ("CURRENT CAP LV%d"):format(capText)) or "CURRENT CAP ?",
              }
              local out = {}
              for _, row in ipairs(raw) do
                  for _, line in ipairs(devUiWrapText(row, width)) do
                      out[#out + 1] = line
                  end
              end
              return out
          end

          local function showDevRunFailure(info)
              info = type(info) == "table" and info or {}
              local detail = tostring(info.message or info.error
                  or "The Dev self-test could not complete.")
              detail = detail:gsub("^.-:%s*", "")
              if #detail > 180 then detail = detail:sub(1, 180) .. "..." end
              -- 2.7.82: player-visible Dev failures are semantic text only.
              self.devError = { title = "DEV RUN ERROR", detail = detail }
              self.status = "ERROR"
          end

          -- 2.7.82: DEV REPORT is a semantic runtime dashboard. The old RAW
          -- machine-dump page and opaque generated codes are internal-only.
          local DEV_REPORT_SECTIONS = { "SUMMARY", "PROBLEMS", "HOOKS", "RULES", "RANDOM" }
          local function devReportSectionLines(report, rawText, width, rawFormatter)
              report = type(report) == "table" and report or {}
              local section = math.max(1, math.min(#DEV_REPORT_SECTIONS,
                  math.floor(tonumber(self.reportSection) or 1)))
              local name = DEV_REPORT_SECTIONS[section]
              local out = { "[" .. name .. "]" }
              local function put(text)
                  for _, line in ipairs(devUiWrapText(tostring(text or ""), width)) do out[#out + 1] = line end
              end
              local function putPair(left, right)
                  local leftWidth = math.max(5, math.floor((width - 1) * 0.55))
                  local rightWidth = math.max(4, width - leftWidth - 1)
                  local leftLines = devUiWrapText(tostring(left or ""), leftWidth)
                  local rightLines = devUiWrapText(tostring(right or ""), rightWidth)
                  local rows = math.max(#leftLines, #rightLines)
                  for i = 1, rows do
                      local l = tostring(leftLines[i] or "")
                      local r = tostring(rightLines[i] or "")
                      out[#out + 1] = l .. string.rep(" ",
                          math.max(1, leftWidth - #l + 1)) .. r
                  end
              end
              local problems = {}
              for _, row in ipairs(report.results or {}) do
                  if row.ok ~= true then problems[#problems + 1] = { "FAIL", row.id, row.detail } end
              end
              for _, row in ipairs(report.assertions or {}) do
                  problems[#problems + 1] = { "WARN", row.code or "assertion", row.detail }
              end
              if name == "CODE" then
                  local code = self.reportCode
                      or (type(report) == "table" and report.report_code)
                      or ""
                  appendReportCodeLines(code, width, out)
                  put("A:SUMMARY")
                  put("LEFT/RIGHT:SECTION")
              elseif name == "SUMMARY" then
                  put("BUILD " .. tostring(report.build or "?") .. " " .. tostring(report.game or "?"):upper())
                  put(#problems == 0 and "STATUS PASS" or ("STATUS CHECK " .. tostring(#problems)))
                  local hc = (report.hook_health or {}).counts or {}
                  put(string.format("HOOK H%d C%d P%d M%d", tonumber(hc.healthy or 0), tonumber(hc.chained or 0), tonumber(hc.pending or 0), tonumber(hc.missing or 0)))
                  local ih = report.install_health or {}
                  local ic, ina, ip = 0, 0, 0
                  for _ in pairs(ih.failures or {}) do ic=ic+1 end
                  for _, value in pairs(ih.skipped or {}) do
                      if tostring(value):find("^PENDING") then ip=ip+1 else ina=ina+1 end
                  end
                  put(string.format("INSTALL F%d N%d P%d", ic, ina, ip))
                  put("A:PROBLEMS")
                  put("LEFT/RIGHT:SECTION")
              elseif name == "PROBLEMS" then
                  local function shortLabel(value)
                      local text = tostring(value or "?")
                      text = text:gsub("^doc_current_header_", "HEADER ")
                          :gsub("[._]", " "):upper()
                      return text
                  end
                  local function shortDetail(value)
                      local text = tostring(value or "")
                      -- Release-safety failures carry id:detail. Surface the
                      -- actionable id first instead of an unreadable raw blob.
                      text = text:gsub("^doc_current_header_", "HEADER ")
                          :gsub("installer_returned_false", "NOT APPLICABLE / RETURNED FALSE")
                          :gsub("[._]", " ")
                      return text
                  end
                  if #problems == 0 then put("NO ACTIONABLE PROBLEMS") end
                  for i, row in ipairs(problems) do
                      put(string.format("%d %s", i, tostring(row[1] or "FAIL")))
                      put(" " .. shortLabel(row[2]))
                      if row[3] and row[3] ~= "" then put(" " .. shortDetail(row[3])) end
                  end
                  local ih = report.install_health or {}
                  local installKeys = {}
                  for key in pairs(ih.failures or {}) do installKeys[#installKeys + 1] = key end
                  table.sort(installKeys)
                  for _, key in ipairs(installKeys) do
                      put("INSTALL FAIL")
                      put(shortLabel(key))
                      put(shortDetail(ih.failures[key]))
                  end
                  if #installKeys == 0 and #problems == 0 then
                      put("ALL ACTIONABLE CHECKS PASS")
                  end
              elseif name == "HOOKS" then
                  local hh = report.hook_health or {}
                  local c = hh.counts or {}
                  put(string.format("HOOK H%d C%d P%d M%d",
                      tonumber(c.healthy or 0), tonumber(c.chained or 0),
                      tonumber(c.pending or 0), tonumber(c.missing or 0)))
                  putPair("HOOK", "STATE")
                  local ih = report.install_health or {}
                  local skippedKeys = {}
                  for key in pairs(ih.skipped or {}) do skippedKeys[#skippedKeys + 1] = key end
                  table.sort(skippedKeys)
                  for _, key in ipairs(skippedKeys) do
                      local value = tostring(ih.skipped[key] or "INFO")
                      putPair(key, value:match("^([^:]+)") or value)
                  end
                  for _, row in ipairs(hh.rows or {}) do
                      putPair(tostring(row.adapter_id or row.id or "?")
                          :gsub("[._]", " "):upper(), row.state or "?")
                      if row.detail and row.detail ~= "" then
                          put(" " .. tostring(row.detail))
                      end
                  end
              elseif name == "RULES" then
                  local re = report.rule_effectiveness or {}
                  local c = re.counts or {}
                  put(string.format("TOTAL %d ERR %d",
                      tonumber(c.total or 0), tonumber(c.errors or 0)))
                  putPair("RULE", "STATE")
                  for _, row in ipairs(re.rows or {}) do
                      if row.error or row.relationship == "delegated"
                          or row.configured ~= row.effective then
                          local state = row.error and "ERROR" or tostring(row.effective)
                          putPair(row.key or "?", state)
                          if row.owner and tostring(row.owner) ~= "nuzlocke" then
                              putPair("OWNER", row.owner)
                          end
                      end
                  end
              elseif name == "RANDOM" then
                  local r = report.randomizer_integrity or {}
                  local gen1 = not mod.exports.__beta26.runtimeIsGen2(self.game)
                  local construction = gen1
                      and mod.exports.__beta26.lastGen1TrainerConstruction or nil
                  local trainerConfigured = gen1
                      and mod.save:get("random_trainers", false) == true
                  local runtimeTrainerWarn = trainerConfigured == true
                      and type(construction) == "table"
                      and (construction.ruleEnabled ~= true
                          or (construction.fallbackApplied ~= true
                              and (construction.primaryRegistered ~= true
                                  or construction.finalizerRegistered ~= true))
                          or construction.primaryCompleted ~= true
                          or construction.finalizerCompleted ~= true
                          or construction.finalizerObserved ~= true)

                  local status = tostring(r.status or "?")
                  if runtimeTrainerWarn then status = "WARN" end
                  if trainerConfigured == true
                      and type(construction) == "table"
                      and construction.fallbackApplied == true then
                      status = "FALLBACK"
                  end

                  put("STATUS " .. status)
                  put("SCANNED " .. tostring(r.scanned or 0))
                  put("VIOLATIONS " .. tostring(r.violation_count or 0))
                  for _, row in ipairs(r.violations or {}) do
                      put(tostring(row.path or "?") .. " "
                          .. tostring(row.reason or "?"))
                  end

                  if gen1 then
                      put("")
                      put("TRAINER RANDOMIZER")
                      if type(construction) == "table" then
                          put("CONFIG "
                              .. (construction.configOn == true and "ON" or "OFF")
                              .. " RULE "
                              .. (construction.ruleEnabled == true and "ON" or "OFF"))
                          put("HOOK BUS "
                              .. (construction.runtimeWantsHook == true
                                  and "ACTIVE" or "INACTIVE"))
                          put("PRIMARY REG "
                              .. (construction.primaryRegistered == true
                                  and "YES" or "NO")
                              .. " RUN "
                              .. (construction.primaryEntered == true
                                  and (construction.primaryCompleted == true
                                      and "OK" or "FAILED")
                                  or "NO"))
                          put("FINAL REG "
                              .. (construction.finalizerRegistered == true
                                  and "YES" or "NO")
                              .. " RUN "
                              .. (construction.finalizerEntered == true
                                  and (construction.finalizerCompleted == true
                                      and "OK" or "FAILED")
                                  or "NO"))
                          put("FINAL SAMPLE "
                              .. (construction.finalizerObserved == true
                                  and "YES" or "NO"))
                          put("DIRECT "
                              .. (construction.fallbackApplied == true
                                  and "FALLBACK" or "NO"))
                          if construction.fallbackReason then
                              put("REASON " .. tostring(construction.fallbackReason))
                          end
                          if type(construction.acceptedSpecies) == "table"
                              and #construction.acceptedSpecies > 0 then
                              put("CONSTRUCT ACCEPTED "
                                  .. table.concat(construction.acceptedSpecies, ","))
                          end
                      end

                      local tr =
                          mod.exports.__beta26.lastGen1TrainerRandomizerFinalizer
                      if type(tr) ~= "table" then
                          if type(construction) ~= "table" then
                              put("NO TRAINER SAMPLE")
                              put("FIGHT TRAINER THEN A:REFRESH")
                          elseif construction.ruleEnabled ~= true then
                              put("WARN RULE NOT OWNED/ACTIVE")
                          elseif construction.primaryRegistered ~= true
                              or construction.finalizerRegistered ~= true then
                              put("WARN NUZ HOOK MISSING")
                          elseif construction.primaryCompleted ~= true
                              or construction.finalizerCompleted ~= true then
                              put("WARN HOOK CALLBACK FAILED")
                          else
                              put("WARN FINALIZER NOT OBSERVED")
                          end
                      else
                          put(string.format("CLASS %s PARTY %s",
                              tostring(tr.classId or "?"),
                              tostring(tr.partyIndex or "?")))
                          put(string.format("MEM %d GEN %d REAP %d",
                              tonumber(tr.members or 0),
                              tonumber(tr.generated or 0),
                              tonumber(tr.reapplied or 0)))
                          put(string.format("SEED %s RESET %s",
                              tostring(tr.seed or "?"),
                              tr.seedReset == true and "YES" or "NO"))
                          put("VANILLA "
                              .. (tr.allVanilla == true and "YES" or "NO"))
                          put("SPECIES MODE "
                              .. tostring(tr.configuredSpeciesMode or "?"))
                          for _, d in ipairs(tr.details or {}) do
                              put(string.format(
                                  "S%s %s>%s CHOICE %s",
                                  tostring(d.slot or "?"),
                                  tostring(d.original or "?"),
                                  tostring(d.final or "?"),
                                  tostring(d.choice or "?")))
                              local pd = d.pool
                              if type(pd) == "table" then
                                  put(string.format(
                                      " POOL U%d G%d S%d M%s>%s%s",
                                      tonumber(pd.universe or 0),
                                      tonumber(pd.generationAllowed or 0),
                                      tonumber(pd.safe or 0),
                                      tostring(pd.configuredMode or "?"),
                                      tostring(pd.effectiveMode or "?"),
                                      pd.normalized == true and " NORM" or ""))
                              end
                          end
                      end
                  end
              else
                  return rawFormatter(rawText, width)
              end
              return out
          end

          -- 2.5.6: self:update() can enter report-view mode before the helper's
          -- later assignment. Forward-declare it so the closure captures this
          -- local instead of resolving a nil global on the next frame.
          local devReportDisplayLines

          function self:update()
              local input = self.game and self.game.input
              if not input then return end

              if self.devError then
                  if input:wasPressed("a") or input:wasPressed("b")
                      or input:wasPressed("start") then
                      self.devError = nil
                      self.status = "READY"
                  end
                  return
              end

              if self.viewingReport then
                  if input:wasPressed("select") then
                  mod.ui.push(self.game, "NuzlockeUiGalleryScreen")
                  return
              end

              if input:wasPressed("b") or input:wasPressed("start") then
                      self.viewingReport = false
                      rememberedDev.reportScroll = self.reportScroll or 0
                      return
                  end
                  local width = mod.exports.__beta26.runtimeIsGen2(self.game)
                      and 18 or 16
                  local visible = mod.exports.__beta26.runtimeIsGen2(self.game) and 11 or 7
                  local rawText = cachedReport()
                  local report = self.liveReport or (self.exportInfo and self.exportInfo.report)
                      or mod.exports.__beta26.Dev.lastExportReport
                  local lines = devReportSectionLines(report, rawText, width, devReportDisplayLines)
                  local maxScroll = math.max(0, #lines - visible)
                  if input:wasPressed("down") then
                      self.reportScroll = math.min(maxScroll,
                          (self.reportScroll or 0) + 1)
                  elseif input:wasPressed("up") then
                      self.reportScroll = math.max(0,
                          (self.reportScroll or 0) - 1)
                  elseif input:wasPressed("left") or input:wasPressed("right") then
                      local dir = input:wasPressed("left") and -1 or 1
                      self.reportSection = ((self.reportSection - 1 + dir) % #DEV_REPORT_SECTIONS) + 1
                      self.reportScroll = 0
                  elseif input:wasPressed("a") then
                      refreshLiveReport()
                      self.reportScroll = 0
                  end
                  rememberedDev.reportScroll = self.reportScroll or 0
                  rememberedDev.reportSection = self.reportSection or 1
                  return
              end

              if self.viewingKnownIssues then
                  if input:wasPressed("b") or input:wasPressed("start") then
                      self.viewingKnownIssues = false
                      self.knownIssuesScroll = 0
                      return
                  end
                  local width = mod.exports.__beta26.runtimeIsGen2(self.game) and 18 or 16
                  local visible = mod.exports.__beta26.runtimeIsGen2(self.game) and 11 or 7
                  local report = self.liveReport or (self.exportInfo and self.exportInfo.report)
                      or mod.exports.__beta26.Dev.lastExportReport
                  local lines = knownIssueLines(report, width)
                  local maxScroll = math.max(0, #lines - visible)
                  if input:wasPressed("down") then
                      self.knownIssuesScroll = math.min(maxScroll,
                          (self.knownIssuesScroll or 0) + 1)
                  elseif input:wasPressed("up") then
                      self.knownIssuesScroll = math.max(0,
                          (self.knownIssuesScroll or 0) - 1)
                  end
                  return
              end

              if self.viewingFileInfo then
                  if input:wasPressed("b") or input:wasPressed("start") then
                      self.viewingFileInfo = false
                      self.fileInfoScroll = 0
                      return
                  end
                  local width = mod.exports.__beta26.runtimeIsGen2(self.game)
                      and 18 or 16
                  local lines = storageInfoLines(width)
                  local visible = mod.exports.__beta26.runtimeIsGen2(self.game) and 11 or 7
                  local maxScroll = math.max(0, #lines - visible)
                  if input:wasPressed("down") then
                      self.fileInfoScroll = math.min(maxScroll,
                          (self.fileInfoScroll or 0) + 1)
                  elseif input:wasPressed("up") then
                      self.fileInfoScroll = math.max(0,
                          (self.fileInfoScroll or 0) - 1)
                  end
                  return
              end

              if input:wasPressed("b") or input:wasPressed("start") then
                  rememberedDev.cursor = self.cursor or 1
                  rememberedDev.reportScroll = self.reportScroll or 0
                  self.game.stack:pop()
                  return
              end

              if input:wasPressed("down") then
                  self.cursor = math.min(6, self.cursor + 1)
                  rememberedDev.cursor = self.cursor
                  return
              elseif input:wasPressed("up") then
                  self.cursor = math.max(1, self.cursor - 1)
                  rememberedDev.cursor = self.cursor
                  return
              end

              if input:wasPressed("a")
                  or input:wasPressed("left")
                  or input:wasPressed("right") then
                  if self.cursor == 1 then
                      local ok, info =
                          mod.exports.__beta26.Dev.exportSelfTest(self.game)
                      self.exportInfo = type(info) == "table" and info or nil
                      if ok and self.exportInfo then
                          local report = self.exportInfo.report or {}
                          local checks = 0
                          for _, row in ipairs(report.results or {}) do
                              if row.ok ~= true then checks = checks + 1 end
                          end
                          local run = checks == 0 and "PASS" or "CHECK"
                          local snap
                          if self.exportInfo.verified then
                              snap = "SAVED"
                          elseif self.exportInfo.writeReturned then
                              snap = "UNVER"
                          else
                              snap = "LOG"
                          end
                          self.lastTestStatus = run
                          self.snapshotStatus = snap == "LOG" and "LOG"
                              or snap
                          self.status = run .. "/" .. snap
                      else
                          showDevRunFailure(self.exportInfo or info)
                      end
                  elseif self.cursor == 2 then
                      if refreshLiveReport() then
                          self.viewingReport = true
                          self.reportSection = 1
                          self.reportScroll = 0
                          rememberedDev.reportSection = 1
                          rememberedDev.reportScroll = 0
                      end
                  elseif self.cursor == 3 then
                      -- Known Issues is a live diagnostic view, not a static
                      -- ledger. Refresh before opening so resolved automatic
                      -- findings disappear and new failures appear immediately.
                      refreshLiveReport()
                      self.viewingKnownIssues = true
                      self.knownIssuesScroll = 0
                  elseif self.cursor == 4 then
                      self.viewingFileInfo = true
                      self.fileInfoScroll = 0
                  elseif self.cursor == 5 then
                      reloadStoredReport()
                  else
                      pcall(mod.exports.__beta26.Dev.logSnapshot,
                          "dev_tools_manual", self.game)
                      self.status = "LOGGED"
                      self.snapshotStatus = "LOGGED"
                  end
              end
          end

          devReportDisplayLines = function(text, width)
              width = math.max(8, math.floor(tonumber(width) or 16))
              local out = {}
              for raw in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
                  if raw == "" then
                      out[#out + 1] = ""
                  elseif raw:match("^report_code=")
                      or raw:match("fingerprint") then
                      -- Historical stored snapshots may contain machine-only
                      -- fields. Keep them in storage, but never render them.
                  else
                      local wrapped = devUiWrapText(raw, width)
                      for _, wrappedLine in ipairs(wrapped) do
                          out[#out + 1] = wrappedLine
                      end
                  end
              end
              return out
          end

          -- 2.6.31: classic R/B/Y Font.draw consumes the cartridge-encoded
          -- string produced by Strings(), not raw host ASCII. Static labels in
          -- this screen already used Strings(), but dynamic DEV REPORT / storage
          -- / error rows were handed to Font.draw raw, so ASCII byte values were
          -- interpreted as tile codes and rendered as corrupted Pokemon glyphs.
          -- Keep wrapping in host text, then encode exactly once at draw time.
          local function devClassicText(text)
              return Strings(tostring(text or ""))
          end

          -- 2.6.12: DEV TOOLS must own its text-fit helper. The Setup/NUZ RULES
          -- helper is local to that renderer and is not visible here; calling it
          -- from the R/B/Y Dev Tools draw path caused an immediate nil-function
          -- crash on Yellow. Keep this helper local and fail-soft.
          local function devFitPixelText(text, budget)
              text = Strings(tostring(text or ""))
              budget = math.max(0, tonumber(budget) or 0)
              local Font = mod.ui and mod.ui.Font
              if type(Font) ~= "table" or type(Font.width) ~= "function"
                  or type(Font.split) ~= "function"
                  or type(Font.spansFitting) ~= "function" then
                  local chars = math.max(0, math.floor(budget / 8))
                  return chars > 0 and text:sub(1, chars) or ""
              end
              if Font.width(text) <= budget then return text end
              local spans = Font.split(text)
              local fit = Font.spansFitting(spans, budget)
              if fit <= 0 then return "" end
              return text:sub(1, spans[fit].to)
          end

          local function devClassicCentered(Font, text, y)
              local encoded = devClassicText(text)
              local width = type(Font.width) == "function"
                  and Font.width(encoded) or (#tostring(text or "") * 8)
              Font.draw(encoded, math.max(8, math.floor((160 - width) / 2)), y)
          end

          -- 2.6.72: DEV titles use the same tracked bold treatment as NUZ
          -- INFO, without the underline that consumed vertical space.
          local function devClassicSectionTitle(Font, text)
              local label = Strings(tostring(text or ""))
              local tracking = 1
              local spans = type(Font.split) == "function" and Font.split(label) or nil
              if type(spans) ~= "table" or #spans == 0 then
                  local width = type(Font.width) == "function"
                      and Font.width(label) or (#tostring(label) * 8)
                  local x = math.max(8, math.floor((160 - width) / 2))
                  Font.draw(label, x, 10)
                  Font.draw(label, x + 1, 10)
                  return
              end
              local total = 0
              for i, span in ipairs(spans) do
                  local glyph = label:sub(span.from, span.to)
                  total = total + (type(Font.width) == "function"
                      and Font.width(glyph) or 8)
                  if i < #spans then total = total + tracking end
              end
              local x = math.max(8, math.floor((160 - total) / 2))
              for i, span in ipairs(spans) do
                  local glyph = label:sub(span.from, span.to)
                  Font.draw(glyph, x, 10)
                  Font.draw(glyph, x + 1, 10)
                  x = x + (type(Font.width) == "function"
                      and Font.width(glyph) or 8)
                  if i < #spans then x = x + tracking end
              end
          end

          -- Use the native more-arrow tile for both directions; rotate the
          -- upper copy rather than substituting a sideways cursor/caret.
          local function devClassicScrollIndicators(Font, Theme, canUp, canDown)
              local x = 144
              if canUp then
                  local y = 26
                  love.graphics.push()
                  love.graphics.translate(x + 4, y + 4)
                  love.graphics.rotate(math.pi)
                  love.graphics.translate(-(x + 4), -(y + 4))
                  Font.drawCode(Theme.moreArrow or 0xEE, x, y)
                  love.graphics.pop()
              end
              if canDown then Font.drawCode(Theme.moreArrow or 0xEE, x, 112) end
          end

          function self:draw()
              if mod.exports.__beta26.runtimeIsGen2(self.game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  Chrome.clear()
                  Chrome.box(0, 0, 20, 18)

                  if self.devError then
                      Chrome.print(Strings(self.devError.title or "DEV ERROR"), 2, 1)
                      local detail = tostring(self.devError.detail or "")
                      local lines = devUiWrapText(detail, 18)
                      for i = 1, math.min(#lines, 11) do
                          Chrome.print(lines[i], 1, 2 + i)
                      end
                      Chrome.print(Strings("A/B:BACK"), 10, 16)
                      return
                  end

                  if self.viewingReport then
                      -- 2.7.74 recovery: restore the post-2.7.72 Gold utility
                      -- title normalization without touching native host UI.
                      local devTitle = Strings("DEV REPORT")
                      local GoldFont = require("src.render.Font")
                      mod.exports.__beta26.drawGen2NuzTitle(Chrome, GoldFont, devTitle)
                      local rawText = cachedReport()
                      local report = self.liveReport or (self.exportInfo and self.exportInfo.report)
                          or mod.exports.__beta26.Dev.lastExportReport
                      local lines = devReportSectionLines(report, rawText, 16, devReportDisplayLines)
                      for i = 1, 11 do
                          local line = lines[(self.reportScroll or 0) + i]
                          if not line then break end
                          Chrome.print(line, 2, 2 + i)
                      end
                      if self.reportScroll > 0 then
                          Chrome.cursor(18, 3, true)
                      end
                      if self.reportScroll + 11 < #lines then
                          GoldFont.drawCode(Chrome.DOWN_ARROW, 18 * 8, 14 * 8)
                      end
                      Chrome.print(Strings("L/R:PAGE"), 2, 16)
                      Chrome.print(Strings("B:BACK"), 12, 16)
                      return
                  end

                  if self.viewingKnownIssues then
                      local GoldFont = require("src.render.Font")
                      mod.exports.__beta26.drawGen2NuzTitle(Chrome, GoldFont, "KNOWN ISSUES")
                      local report = self.liveReport or (self.exportInfo and self.exportInfo.report)
                          or mod.exports.__beta26.Dev.lastExportReport
                      local lines = knownIssueLines(report, 16)
                      for i = 1, 11 do
                          local line = lines[(self.knownIssuesScroll or 0) + i]
                          if not line then break end
                          Chrome.print(line, 2, 2 + i)
                      end
                      if self.knownIssuesScroll > 0 then Chrome.cursor(18, 3, true) end
                      if self.knownIssuesScroll + 11 < #lines then
                          GoldFont.drawCode(Chrome.DOWN_ARROW, 18 * 8, 14 * 8)
                      end
                      Chrome.print(Strings("UP/DN"), 2, 16)
                      Chrome.print(Strings("B:BACK"), 12, 16)
                      return
                  end

                  if self.viewingFileInfo then
                      local GoldFont = require("src.render.Font")
                      mod.exports.__beta26.drawGen2NuzTitle(Chrome, GoldFont, "STORAGE INFO")
                      local lines = storageInfoLines(16)
                      for i = 1, 11 do
                          local line = lines[(self.fileInfoScroll or 0) + i]
                          if not line then break end
                          Chrome.print(line, 2, 2 + i)
                      end
                      if self.fileInfoScroll > 0 then
                          Chrome.cursor(18, 3, true)
                      end
                      if self.fileInfoScroll + 11 < #lines then
                          GoldFont.drawCode(Chrome.DOWN_ARROW, 18 * 8, 14 * 8)
                      end
                      Chrome.print(Strings("UP/DN"), 2, 16)
                      Chrome.print(Strings("B:BACK"), 12, 16)
                      return
                  end

                  mod.exports.__beta26.UiSystem.gen2ScreenFrame(Chrome, { headerRows = 2, footerRows = 2 })
                  local GoldFont = require("src.render.Font")
                  mod.exports.__beta26.drawGen2NuzTitle(Chrome, GoldFont, "DEV TOOLS")
                  local rows = {
                      "RUN TESTS", "VIEW REPORT", "KNOWN ISSUES",
                      "STORAGE INFO", "LOAD SNAPSHOT", "WRITE LOG SNAP"
                  }
                  for i, label in ipairs(rows) do
                      local y = 3 + (i - 1) * 2
                      mod.exports.__beta26.UiSystem.gen2Row(Chrome, GoldFont, {
                          label = label, focused = self.cursor == i,
                      }, { x = 3, y = y, rightCol = 18 })
                  end
                  Chrome.print(Strings("SEL:GALLERY"), 1, 15)
                  Chrome.print(Strings("B:BACK"), 13, 16)
                  return
              end

              local Font = mod.ui.Font
              local Theme = require("src.ui.Theme")
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.rectangle("fill", 0, 0, 160, 144)
              love.graphics.setColor(0, 0, 0, 1)
              love.graphics.rectangle("line", 6, 6, 148, 132)
              love.graphics.rectangle("line", 8, 8, 144, 128)
              love.graphics.setColor(1, 1, 1, 1)

              if self.devError then
                  local function centered(text, y)
                      local encoded = devClassicText(text)
                      local width = type(Font.width) == "function"
                          and Font.width(encoded) or (#tostring(text or "") * 8)
                      Font.draw(encoded, math.max(12, math.floor((160 - width) / 2)), y)
                  end
                  local titleLines = devUiWrapText(
                      self.devError.title or "DEV ERROR", 16)
                  local y = 14
                  for i = 1, math.min(#titleLines, 2) do
                      centered(titleLines[i], y)
                      y = y + 12
                  end
                  y = y + 6
                  local detail = tostring(self.devError.detail or "")
                  local lines = devUiWrapText(detail, 16)
                  for i = 1, math.min(#lines, 6) do
                      centered(lines[i], y)
                      y = y + 12
                  end
                  centered("A/B:BACK", 126)
                  return
              end

              if self.viewingReport then
                  local reportTitle = Strings("DEV REPORT")
                  local reportTitleWidth = type(Font.width) == "function"
                      and Font.width(reportTitle) or (#reportTitle * 8)
                  devClassicSectionTitle(Font, "DEV REPORT")
                  local rawText = cachedReport()
                  local report = self.liveReport or (self.exportInfo and self.exportInfo.report)
                      or mod.exports.__beta26.Dev.lastExportReport
                  local lines = devReportSectionLines(report, rawText, 16, devReportDisplayLines)
                  local y = 30
                  for i = 1, 7 do
                      local line = lines[(self.reportScroll or 0) + i]
                      if not line then break end
                      Font.draw(devClassicText(line), 12, y)
                      y = y + 11
                  end
                  devClassicScrollIndicators(Font, Theme,
                      self.reportScroll > 0, self.reportScroll + 7 < #lines)
                  local reportFooter = Strings("A:REFRESH B:BACK")
                  local reportFooterWidth = type(Font.width) == "function"
                      and Font.width(reportFooter) or (#reportFooter * 8)
                  Font.draw(reportFooter, math.max(10, math.floor((160 - reportFooterWidth) / 2)), 126)
                  return
              end

              if self.viewingKnownIssues then
                  devClassicSectionTitle(Font, "KNOWN ISSUES")
                  local report = self.liveReport or (self.exportInfo and self.exportInfo.report)
                      or mod.exports.__beta26.Dev.lastExportReport
                  local lines = knownIssueLines(report, 16)
                  local y = 30
                  for i = 1, 7 do
                      local line = lines[(self.knownIssuesScroll or 0) + i]
                      if not line then break end
                      Font.draw(devClassicText(line), 12, y)
                      y = y + 12
                  end
                  devClassicScrollIndicators(Font, Theme,
                      self.knownIssuesScroll > 0,
                      self.knownIssuesScroll + 7 < #lines)
                  Font.draw(Strings("UP/DN  B:BACK"), 22, 126)
                  return
              end

              if self.viewingFileInfo then
                  devClassicSectionTitle(Font, "STORAGE INFO")
                  local lines = storageInfoLines(16)
                  local y = 30
                  for i = 1, 7 do
                      local line = lines[(self.fileInfoScroll or 0) + i]
                      if not line then break end
                      Font.draw(devClassicText(line), 12, y)
                      y = y + 12
                  end
                  devClassicScrollIndicators(Font, Theme,
                      self.fileInfoScroll > 0,
                      self.fileInfoScroll + 7 < #lines)
                  Font.draw(Strings("UP/DN  B:BACK"), 22, 126)
                  return
              end

              devClassicSectionTitle(Font, "DEV TOOLS")
              local rows = {
                  "RUN TESTS", "VIEW REPORT", "KNOWN ISSUES",
                  "STORAGE INFO", "LOAD SNAPSHOT", "WRITE LOG SNAP"
              }
              local help = {
                  "CHECK MOD HEALTH", "DETAILS LAST TEST", "LIVE WARNINGS",
                  "SNAPSHOT STORAGE", "LOAD SAVED REPORT", "LOG CURRENT STATE"
              }
              mod.exports.__beta26.UiSystem.frame(160, 144, { header = 24, detail = 24, footer = 16 })
              local ys = { 28, 40, 52, 64, 76, 88 }
              for i, label in ipairs(rows) do
                  mod.exports.__beta26.UiSystem.gen1Row(Font, Theme, {
                      label = label, focused = self.cursor == i,
                  }, { x = 28, y = ys[i], right = 148 })
              end
              Font.draw(devFitPixelText(help[self.cursor] or "DEV ACTION", 136), 12, 104)
              mod.exports.__beta26.UiSystem.gen1Footer(Font, { footer = Strings("SEL:GALLERY   B:BACK") }, 128, 160)
          end

          return self
      end
  })

  ---------------------------------------------------------------------
  -- 2.7.56 Nuzlocke UI Gallery
  -- Dev-only synthetic presentation fixture. It never reads/writes challenge
  -- rules and exists only to stress the shared Nuzlocke presentation system.
  ---------------------------------------------------------------------
  mod.content.screens:register("NuzlockeUiGalleryScreen", {
      new = function(game)
          local self = {
              game = game,
              screenId = "NuzlockeUiGalleryScreen",
              isOpaque = true,
              page = 1,
              elapsed = 0,
          }
          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "ui_gallery"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true
          mod.exports.__beta26.UiSystem.applyLayout(self,
              mod.exports.__beta26.runtimeIsGen2(game) and "centered" or "adaptive")

          function self:update(dt)
              self.elapsed = self.elapsed + (dt or 0)
              if game.input:wasPressed("b") or game.input:wasPressed("start") then
                  game.stack:pop(); return
              end
              if game.input:wasPressed("left") or game.input:wasPressed("up") then
                  self.page = self.page <= 1 and 5 or self.page - 1
              elseif game.input:wasPressed("right") or game.input:wasPressed("down")
                  or game.input:wasPressed("a") then
                  self.page = self.page >= 5 and 1 or self.page + 1
              end
          end

          local pages = {
              { name="HIERARCHY", state="ACTIVE", rows={
                  {"PERMADEATH","ACTIVE"}, {"ONE PER AREA","ACTIVE"},
                  {"FAILED ENCOUNTERS","COUNT"}, {"DUPES","FAMILY"},
              }},
              { name="TRACKER", state="AVAILABLE", rows={
                  {"ROUTE 3 / EAST","AVAILABLE"}, {"MT. MOON B1F","USED"},
                  {"SAFARI EAST","FAILED"}, {"POWER PLANT","EXEMPT"},
              }},
              { name="DIAGNOSTICS", state="MIXED", rows={
                  {"EDITION IDENTITY","PASS"}, {"SAVE SCHEMA","PASS"},
                  {"RANDOMIZER","UNKNOWN"}, {"RUNTIME CERT","NOT TESTED"},
              }},
              { name="TYPOGRAPHY", state="STRESS", rows={
                  {"iiii llll WWWW","RIGHT EDGE"},
                  {"MAXIMUM POKEMON BST RESTRICTION","500"},
                  {"ENCOUNTER BALL LIMIT PER BATTLE","10"},
                  {"TRANSLATED-LABEL-WIDTH-STRESS","ACTIVE"},
              }},
              { name="NOTICE", state="WARNING", notice={
                  kind="WARNING", title="ENCOUNTER RULE",
                  body="This synthetic notice checks measured wrapping, parent-width continuity, and player-paced footer placement without changing run state.",
                  footer="A/B:ACKNOWLEDGE",
              }},
          }

          function self:draw()
              local sample = pages[self.page]
              if mod.exports.__beta26.runtimeIsGen2(self.game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  local GoldFont = require("src.render.Font")
                  Chrome.clear(); Chrome.box(0,0,20,18)
                  local view = mod.exports.__beta26.UiSystem.view("UI GALLERY", self.game, {
                      mode = sample.name, state = sample.state,
                      footer = "A/LR:NEXT  B:BACK",
                  })
                  mod.exports.__beta26.UiSystem.gen2Header(Chrome, GoldFont, view)
                  Chrome.print(Strings("FIXTURE %d/5", self.page), 2, 4)
                  if sample.notice then
                      local notice=mod.exports.__beta26.UiSystem.notice(
                          sample.notice.kind,sample.notice.title,sample.notice.body,
                          sample.notice.footer)
                      mod.exports.__beta26.UiSystem.gen2Notice(Chrome,GoldFont,notice,{
                          x=2,y=6,widthCols=16,footerRow=15,
                      })
                  else
                      for i,row in ipairs(sample.rows or {}) do
                          local y=5+(i-1)*2
                          mod.exports.__beta26.UiSystem.gen2Row(Chrome,GoldFont,{
                              label=row[1],value=row[2],focused=i==1,
                          },{x=2,y=y,rightCol=18})
                      end
                  end
                  mod.exports.__beta26.UiSystem.gen2Footer(Chrome, GoldFont, view,16)
                  return
              end

              local Font=mod.ui.Font
              local Theme=require("src.ui.Theme")
              local layout=self.layoutContext
                  or mod.exports.__beta26.UiSystem.applyLayout(self,"adaptive")
              local cols=layout and layout.columns or 20
              local width=cols*8
              love.graphics.setColor(1,1,1,1)
              love.graphics.rectangle("fill",0,0,width,144)
              Font.drawBox(0,0,cols,18)
              local view=mod.exports.__beta26.UiSystem.view("UI GALLERY",self.game,{
                  mode=sample.name,state=sample.state,
                  footer="A/LR:NEXT  B:BACK",
              })
              mod.exports.__beta26.UiSystem.gen1Header(Font,view,width)
              Font.draw(Strings("FIXTURE %d/5",self.page),12,36)
              if sample.notice then
                  local notice=mod.exports.__beta26.UiSystem.notice(
                      sample.notice.kind,sample.notice.title,sample.notice.body,
                      sample.notice.footer)
                  mod.exports.__beta26.UiSystem.gen1Notice(Font,notice,width)
              else
                  for i,row in ipairs(sample.rows or {}) do
                      mod.exports.__beta26.UiSystem.gen1Row(Font,Theme,{
                          label=row[1], value=row[2], focused=i==1,
                      },{ x=20, y=52+(i-1)*16, right=width-16, gap=12 })
                  end
              end
              mod.exports.__beta26.UiSystem.gen1Footer(Font,view,128,width)
              love.graphics.setColor(1,1,1,1)
          end
          return self
      end,
  })

  mod.content.screens:register("NuzlockeTrackerScreen", {
      new = function(game)
          local rememberedTracker = uiRememberedScreen(game, "enc_tracker")
          local self = {
              game = game,
              screenId = "NuzlockeTrackerScreen",
              isOpaque = true,
              tab = math.max(1, math.min(2,
                  math.floor(tonumber(rememberedTracker.tab) or 1))),
              scroll = math.max(0,
                  math.floor(tonumber(rememberedTracker.scroll) or 0)),
              log = trackerLog(),
              marqueeTime = 0,
              arrowTime = 0,
          }

          self.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(self)
          self.presentationRole = "tracker"
          self.presentationStateOwner = "nuzlocke"
          self.presentationNativeFallback = true

          -- 2.7.56: Tracker now has a real wide composition instead of
          -- widening a 160px drawing. The screen contract chooses the logical
          -- surface; gameplay/tracker projection remains unchanged.
          mod.exports.__beta26.UiSystem.applyLayout(self, "adaptive")
          self.__nuzlockeOwnsTrackerLayout = true

          -- Prepare tracker state once per refresh. All presentation paths
          -- consume the same row snapshot instead of repeating projection,
          -- cleanup, route sorting, and row construction within one frame.
          -- 2.6.13: ENC TRACKER owns its own pixel-fit helper. Do not depend
          -- on the lexically scoped NUZ RULES helper: the Tracker is a
          -- separately registered screen and that reference resolves global.
          local function trackerFitPixelText(text, budget)
              local Font = mod.ui.Font
              text = Strings(tostring(text or ""))
              budget = math.max(0, tonumber(budget) or 0)
              if type(Font.width) ~= "function"
                  or type(Font.split) ~= "function"
                  or type(Font.spansFitting) ~= "function" then
                  return text
              end
              if Font.width(text) <= budget then return text end
              local spans = Font.split(text)
              local fit = Font.spansFitting(spans, budget)
              if fit <= 0 then return "" end
              return text:sub(1, spans[fit].to)
          end

          local function trackerRuntimeFault(step, err, fatal)
              local msg = tostring(err or "unknown tracker error")
              if fatal == true then
                  self.__trackerRuntimeFault = self.__trackerRuntimeFault or {
                      step = tostring(step or "tracker"),
                      message = msg,
                  }
              end
              local Dev = mod.exports.__beta26.Dev
              if Dev and type(Dev.recordError) == "function" then
                  pcall(Dev.recordError, "enc_tracker_" .. tostring(step or "runtime"),
                      msg, self.game)
              end
              if print then
                  pcall(print, "[Nuzlocke:Tracker] " .. tostring(step or "runtime")
                      .. " failed: " .. msg)
              end
          end

          function self:refreshTrackerRows()
              -- Tracker projection is read-mostly UI preparation, but older
              -- saves and third-party providers can expose malformed route or
              -- encounter rows. No single projection failure should be able to
              -- take down the process. Keep whichever view can be built and
              -- fail the other one to an empty bounded list.
              local ok, err = pcall(syncCurrentArea, self.game)
              if not ok then trackerRuntimeFault("sync_area", err) end
              if type(mod.exports.__beta26.ensureEncounterProjection) == "function" then
                  ok, err = pcall(mod.exports.__beta26.ensureEncounterProjection)
                  if not ok then trackerRuntimeFault("projection", err) end
              end
              if type(mod.exports.__beta26.cleanupStarterDuplicate) == "function" then
                  ok, err = pcall(mod.exports.__beta26.cleanupStarterDuplicate)
                  if not ok then trackerRuntimeFault("starter_cleanup", err) end
              end
              if type(mod.exports.__beta26.syncTrackerDeathProjection) == "function" then
                  ok, err = pcall(mod.exports.__beta26.syncTrackerDeathProjection)
                  if not ok then trackerRuntimeFault("death_projection", err) end
              end

              local okLog, logRows = pcall(getTrackerLogRows, true)
              if okLog and type(logRows) == "table" then
                  self.__trackerLogRows = logRows
              else
                  self.__trackerLogRows = {}
                  trackerRuntimeFault("log_rows", logRows)
              end

              local okMap, mapRows = pcall(getTrackerMapRows, self.game, true)
              if okMap and type(mapRows) == "table" then
                  self.__trackerMapRows = mapRows
              else
                  self.__trackerMapRows = {}
                  trackerRuntimeFault("map_rows", mapRows)
              end
          end

          function self:trackerRows(tab)
              if type(self.__trackerLogRows) ~= "table"
                  or type(self.__trackerMapRows) ~= "table" then
                  self:refreshTrackerRows()
              end
              return tab == 1 and self.__trackerLogRows or self.__trackerMapRows
          end

          function self:selectedAreaKey()
              local rows = self:trackerRows(self.tab)
              local row = rows[self.scroll + 1]
              if not row then return nil end
              if self.tab == 1 then
                  return row.area ~= "__LEGACY__" and (routeKey(row.area) or row.area) or nil
              end
              local area = row.area
              return area and (routeKey(area.id) or area.id) or nil
          end

          function self:selectedAreaCanReroll()
              local key = self:selectedAreaKey()
              if not key then return false end
              local rewards = mod.exports.__beta26.TrainerRewards
              if not (rewards and rewards.forgivenessEnabled
                  and rewards.forgivenessEnabled(self.game, nil)
                  and rewards.forgivenessTokens() > 0) then return false end
              return mod.exports.__beta26.forgivenessAreaEligible(self.game, key) == true
          end

          function self:openSelectedReroll()
              local key = self:selectedAreaKey()
              if not key or not self:selectedAreaCanReroll() then return false end
              mod.ui.push(self.game, "NuzlockeForgivenessArea", {
                  initialKey = key,
                  confirmImmediately = true,
                  closeAfterSpend = true,
                  onSpent = function()
                      self:refreshTrackerRows()
                      local count = #self:trackerRows(self.tab)
                      self.scroll = math.max(0, math.min(self.scroll, math.max(0, count - 1)))
                  end,
              })
              return true
          end

          self:refreshTrackerRows()
          if mod.save:get("area_guide_enabled", true) ~= true then
              self.tab = 1
          end
          self.scroll = math.max(0, math.min(self.scroll,
              math.max(0, #self:trackerRows(self.tab) - 1)))

          local function rememberTrackerPosition()
              rememberedTracker.tab = self.tab
              rememberedTracker.scroll = self.scroll
          end
          rememberTrackerPosition()

          function self:nuzlockeModernUiModel()
              local guideEnabled = mod.save:get("area_guide_enabled", true) == true
              local rawRows = self:trackerRows(self.tab)
              local rows = {}
              for _, row in ipairs(rawRows) do
                  local areaLabel
                  local catch
                  if self.tab == 1 then
                      areaLabel = row.area == "__LEGACY__"
                          and Strings("LEGACY") or routeName(row.area)
                      catch = row.catch or {}
                  else
                      areaLabel = row.area and (row.area.name or row.area.id) or "???"
                      catch = row.catch
                  end
                  local result = "..."
                  if catch then
                      if catch.dead == true or catch.status == "DEAD" then
                          result = Strings("DEAD %s", tostring(catch.species or "???"))
                      elseif catch.failed then
                          result = Strings("FAILED %s", tostring(catch.species or "???"))
                      elseif catch.isShiny then
                          result = "*" .. tostring(catch.species or "???")
                      else
                          result = tostring(catch.species or "???")
                      end
                  end
                  local context = mod.exports.__beta26.compat21
                      and mod.exports.__beta26.compat21.trackerCatchContext
                      and mod.exports.__beta26.compat21.trackerCatchContext(
                          self.game, catch, areaLabel) or nil
                  rows[#rows + 1] = {
                      label = tostring(Strings(areaLabel)),
                      right = tostring(Strings(result)),
                      detail = context and tostring(context.tag) or nil,
                      provider = context and context.provider or nil,
                  }
              end
              local actualCount = #rows
              if actualCount == 0 then
                  rows[1] = {
                      label = tostring(Strings("NO ENTRIES YET")),
                      right = "",
                      empty = true,
                  }
              end
              local cap = nextLevelCap(self.game and self.game.save)
              return {
                  title = Strings(self.tab == 1 and "ENCOUNTER LOG" or "AREA GUIDE"),
                  rows = rows,
                  index = actualCount > 0
                      and math.min(actualCount, self.scroll + 1) or nil,
                  scroll = actualCount > 0 and self.scroll or 0,
                  footer = self:selectedAreaCanReroll()
                      and { Strings("A: REROLL"), Strings("LEFT/RIGHT: PAGE"), Strings("B: BACK") }
                      or (guideEnabled
                          and { Strings("A/LEFT/RIGHT: PAGE"), Strings("B: BACK") }
                          or { Strings("B: BACK") }),
                  details = (function()
                      local summary = nuzTrackerSummary(self:trackerRows(2))
                      local details = {
                          cap >= 100 and Strings("NEXT CAP: MAX")
                              or Strings("NEXT CAP: %d", cap),
                          Strings("OPEN %d / CAUGHT %d / FAILED %d",
                              summary.open, summary.caught, summary.failed),
                          Strings("%d entries", actualCount),
                      }
                      local rc = mod.exports.__beta26.compat21
                          and mod.exports.__beta26.compat21.randomizerTrackerContext
                          and mod.exports.__beta26.compat21.randomizerTrackerContext(self.game)
                      if rc then
                          details[#details + 1] = Strings("RNG: %s", rc.provider)
                      end
                      local selected = actualCount > 0
                          and rows[math.min(actualCount, self.scroll + 1)] or nil
                      if selected and selected.detail then
                          details[#details + 1] =
                              Strings("TYPE: %s", tostring(selected.detail))
                      end
                      if selected and selected.provider then
                          details[#details + 1] =
                              Strings("FROM: %s", tostring(selected.provider))
                      end
                      return details
                  end)(),
              }
          end

          function self:nuzlockeModernUiAction(action)
              local guideEnabled = mod.save:get("area_guide_enabled", true) == true
              if action == "back" then
                  rememberTrackerPosition()
                  self.game.stack:pop()
                  return true
              elseif action == "select" and self:selectedAreaCanReroll() then
                  return self:openSelectedReroll()
              elseif guideEnabled and (action == "select"
                  or action == "left" or action == "right") then
                  if action == "left" then
                      self.tab = 1
                  elseif action == "right" then
                      self.tab = 2
                  else
                      self.tab = self.tab == 1 and 2 or 1
                  end
                  self.scroll = 0
                  self.marqueeTime = 0
                  rememberTrackerPosition()
                  return true
              elseif action == "up" or action == "down" then
                  local count = #self:trackerRows(self.tab)
                  local maxScroll = math.max(0, count - 1)
                  if action == "up" then
                      self.scroll = math.max(0, self.scroll - 1)
                  else
                      self.scroll = math.min(maxScroll, self.scroll + 1)
                  end
                  self.marqueeTime = 0
                  rememberTrackerPosition()
                  return true
              end
              return false
          end

          function self:update(dt)
              self:refreshTrackerRows()

              if self.game.input:wasPressed("b") then
                  rememberTrackerPosition()
                  self.game.stack:pop()
                  return
              end

              local guideEnabled = mod.save:get("area_guide_enabled", true) == true
              if not guideEnabled then
                  self.tab = 1
              end

              -- A selects an eligible FAILED area for F. TOKEN reroll. On
              -- any other row it keeps the established page-toggle behavior.
              -- LEFT/RIGHT always remain available for explicit page changes.
              if self.game.input:wasPressed("a") then
                  if self:selectedAreaCanReroll() then
                      self:openSelectedReroll()
                      return
                  elseif guideEnabled then
                      self.tab = (self.tab == 1) and 2 or 1
                      self.scroll = 0
                      self.marqueeTime = 0
                  end
              end

              -- Keep left/right as a convenient secondary page control only
              -- when the Area Guide is enabled.
              if guideEnabled and self.game.input:wasPressed("left") then
                  self.tab = 1
                  self.scroll = 0
                  self.marqueeTime = 0
              elseif guideEnabled and self.game.input:wasPressed("right") then
                  self.tab = 2
                  self.scroll = 0
                  self.marqueeTime = 0
              end

              local listCount = #self:trackerRows(self.tab)
              local maxScroll = math.max(0, listCount - 1)

              if self.game.input:wasPressed("down") and self.scroll < maxScroll then
                  self.scroll = self.scroll + 1
                  self.marqueeTime = 0
              elseif self.game.input:wasPressed("up") and self.scroll > 0 then
                  self.scroll = self.scroll - 1
                  self.marqueeTime = 0
              end

              self.marqueeTime = self.marqueeTime + (dt or 0)
              rememberTrackerPosition()

              -- The arrow has its own timer so reaching the last page makes
              -- it completely inert/invisible instead of continuing a hidden
              -- blink animation. It restarts calmly when another page exists.
              local arrowListCount = #self:trackerRows(self.tab)
              local arrowMaxScroll = math.max(0, arrowListCount - 1)
              if self.scroll < arrowMaxScroll then
                  self.arrowTime = self.arrowTime + (dt or 0)
              else
                  self.arrowTime = 0
              end
          end

          function self:draw()
              -- 2.8.07: Gen II-only tracker cards. Long area names get two
              -- left-column rows; the right column stacks state/species/source.
              -- Do not expose compact O/C/F diagnostics as unexplained header text.
              if mod.exports.__beta26.runtimeIsGen2(self.game) then
                  local Chrome = require("src.ui.gen2.Chrome")
                  local GoldFont = require("src.render.Font")
                  local UiSystem = mod.exports.__beta26.UiSystem
                  local guideEnabled = mod.save:get("area_guide_enabled", true) == true
                  UiSystem.gen2ScreenFrame(Chrome, { headerRows = 3, footerRows = 2 })
                  local uiView = UiSystem.view("TRACKER", self.game, {
                      mode = self.tab == 1 and "LOG" or "MAP", footer = "B:BACK",
                  })
                  mod.exports.__beta26.drawGen2NuzTitle(Chrome, GoldFont,
                      "ENC TRACKER", self.tab == 1 and "LOG" or "MAP",
                      { row = 1, subtitleRow = 2 })

                  local rows = self:trackerRows(self.tab)
                  local listCount = #rows
                  local visible = 3
                  local maxScroll = math.max(0, listCount - visible)
                  self.scroll = math.max(0, math.min(maxScroll, self.scroll or 0))
                  local T = UiSystem.typography(GoldFont)
                  local function fit(text, cells)
                      return T.fit(Strings(tostring(text or "")), math.max(1, cells) * 8)
                  end
                  if listCount == 0 then Chrome.print(Strings("NO ENTRIES YET"), 2, 5) end

                  for slot = 1, visible do
                      local i = self.scroll + slot
                      local row = rows[i]
                      if not row then break end
                      local areaLabel, catch
                      if self.tab == 1 then
                          areaLabel = row.area == "__LEGACY__" and Strings("LEGACY")
                              or routeName(row.area)
                          catch = row.catch or {}
                      else
                          areaLabel = row.area and (row.area.name or row.area.id) or "???"
                          catch = row.catch
                      end

                      local state, species = Strings("OPEN"), Strings("--")
                      if catch then
                          species = catch.species and Strings(tostring(catch.species)) or Strings("--")
                          if catch.dead == true or catch.status == "DEAD" then
                              state = Strings("DEAD")
                          elseif catch.failed or catch.status == "FAILED" then
                              state = Strings("FAILED")
                          elseif catch.species then
                              state = Strings("CAUGHT")
                          end
                      end
                      local context = mod.exports.__beta26.compat21
                          and mod.exports.__beta26.compat21.trackerCatchContext
                          and mod.exports.__beta26.compat21.trackerCatchContext(
                              self.game, catch, areaLabel) or nil
                      local source = context and context.tag or
                          (catch and (catch.encounterType or catch.source or catch.kind)) or
                          (catch and catch.species and "WILD" or "--")

                      local y = 4 + (slot - 1) * 4
                      if slot == 1 then Chrome.cursor(1, y) end
                      -- Left lane: area may occupy two rows instead of being crushed.
                      local areaText = tostring(Strings(areaLabel))
                      local first = fit(areaText, 10)
                      Chrome.print(first, 2, y)
                      if tostring(first) ~= areaText then
                          -- A second bounded slice is preferable to border overflow.
                          local rest = areaText
                          if #areaText > #tostring(first) then
                              rest = areaText:sub(#tostring(first) + 1):gsub("^%s+", "")
                          end
                          Chrome.print(fit(rest, 10), 2, y + 1)
                      end
                      -- Right lane: all encounter facts remain visible.
                      Chrome.print(fit(state, 7), 12, y)
                      Chrome.print(fit(species, 7), 12, y + 1)
                      Chrome.print(fit(source, 7), 12, y + 2)
                  end

                  if self.scroll > 0 then Chrome.cursor(18, 3, true) end
                  if self.scroll < maxScroll then
                      GoldFont.drawCode(Chrome.DOWN_ARROW, 18 * 8, 14 * 8)
                  end
                  local cap = nextLevelCap(self.game and self.game.save)
                  Chrome.print(cap >= 100 and Strings("CAP MAX")
                      or Strings("CAP LV%d", cap), 2, 15)
                  if self:selectedAreaCanReroll() then Chrome.print(Strings("A:RER"), 10, 15)
                  elseif guideEnabled then Chrome.print(Strings("A:PG"), 10, 15) end
                  UiSystem.gen2Footer(Chrome, GoldFont, uiView, 16)
                  return
              end

              local Font = mod.ui.Font
              local guideEnabled = mod.save:get("area_guide_enabled", true) == true

              -- 2.7.56: consume the active logical surface. Wide mode
              -- uses the same semantic rows but expands the area/result lanes
              -- rather than scaling a 160px drawing.
              local layout = self.layoutContext
                  or mod.exports.__beta26.UiSystem.applyLayout(self, "adaptive")
              local trackerCols = layout and layout.columns or 20
              local trackerWidth = trackerCols * 8
              local wideMode = trackerCols >= 38
              local frame = mod.exports.__beta26.UiSystem.gen1ScreenFrame(
                  Font, trackerWidth, { header = 48, footer = 16 })
              local uiView = mod.exports.__beta26.UiSystem.view("TRACKER", self.game, {
                  mode = self.tab == 1 and "LOG" or "MAP",
                  footer = "B:BACK",
              })
              mod.exports.__beta26.UiSystem.gen1Header(Font, uiView, trackerWidth)

              local summary = nuzTrackerSummary(self:trackerRows(2))
              Font.draw(trackerFitPixelText(("OPEN %d CAUGHT %d FAILED %d"):format(
                  summary.open, summary.caught, summary.failed), trackerWidth - 24), 16, 34)
              local y = 48
              local listCount

              if self.tab == 1 then
                  mod.exports.__beta26.UiSystem.gen1Row(Font, require("src.ui.Theme"), {
                      label=Strings("AREA"), value=Strings("RESULT")
                  }, { x=16, y=y, right=trackerWidth-16, gap=16 })
                  y = y + 14
                  local rows = self:trackerRows(1)
                  listCount = #rows

                  for i = self.scroll + 1, math.min(self.scroll + 3, #rows) do
                      local row = rows[i]
                      local catch = row.catch or {}
                      local species = catch.species or "???"
                      if catch.dead == true or catch.status == "DEAD" then
                          species = Strings("DEAD %s", tostring(catch.species or "???"))
                      elseif catch.failed then
                          -- Keep the compact LOG result readable inside the fixed
                          -- result column; source/context remains on the second row.
                          species = Strings("FAIL %s", tostring(catch.species or "???"))
                      elseif catch.isShiny then
                          species = "*" .. species
                      end
                      local routeLabel = (row.area == "__LEGACY__")
                          and Strings("LEGACY") or routeName(row.area)
                      local selected = i == self.scroll + 1
                      local routeText = selected
                          and marqueeText(routeLabel, wideMode and 22 or 9, self.marqueeTime, 3.8)
                          or trackerFitPixelText(routeLabel, wideMode and 176 or 72)
                      local resultText = selected
                          and marqueeText(species, wideMode and 12 or 8, self.marqueeTime, 3.8)
                          or trackerFitPixelText(species, wideMode and 96 or 64)
                      local drawn = mod.exports.__beta26.UiSystem.gen1Row(
                          Font, require("src.ui.Theme"), {
                              label=routeText, value=resultText, focused=selected,
                              preFitted=selected,
                          }, { x=16, y=y, right=trackerWidth-16, gap=16 })
                      local context = mod.exports.__beta26.compat21
                          and mod.exports.__beta26.compat21.trackerCatchContext
                          and mod.exports.__beta26.compat21.trackerCatchContext(
                              self.game, catch, routeLabel)
                      if context and context.tag then
                          local contextText = trackerFitPixelText(
                              Strings(tostring(context.tag)), wideMode and 96 or 64)
                          local T = mod.exports.__beta26.UiSystem.typography(Font)
                          Font.draw(contextText, T.rightX(contextText, trackerWidth-16), y + 8)
                      end
                      y = y + 20
                  end
              else
                  mod.exports.__beta26.UiSystem.gen1Row(Font, require("src.ui.Theme"), {
                      label=Strings("AREA"), value=Strings("RESULT")
                  }, { x=16, y=y, right=trackerWidth-16, gap=16 })
                  y = y + 14
                  local rows = self:trackerRows(2)
                  listCount = #rows

                  for i = self.scroll + 1, math.min(self.scroll + 3, #rows) do
                      local row = rows[i]
                      local r = row.area
                      local catch = row.catch
                      local status = "..."
                      if catch then
                          if catch.dead == true or catch.status == "DEAD" then
                              status = Strings("DEAD %s", tostring(catch.species or "???"))
                          elseif catch.failed then
                              status = Strings("FAILED %s", tostring(catch.species or "???"))
                          elseif catch.isShiny then
                              status = "*" .. tostring(catch.species or "???")
                          else
                              status = tostring(catch.species or "???")
                          end
                      end
                      local selected = i == self.scroll + 1
                      local areaText = selected
                          and marqueeText(Strings(r.name), wideMode and 22 or 9,
                              self.marqueeTime, 3.8)
                          or trackerFitPixelText(Strings(r.name),
                              wideMode and 176 or 72)
                      local statusText = selected
                          and marqueeText(status, wideMode and 12 or 8,
                              self.marqueeTime, 3.8)
                          or trackerFitPixelText(status, wideMode and 96 or 64)
                      mod.exports.__beta26.UiSystem.gen1Row(
                          Font, require("src.ui.Theme"), {
                              label=areaText, value=statusText, focused=selected,
                              preFitted=selected,
                          }, { x=16, y=y, right=trackerWidth-16, gap=16 })
                      local context = mod.exports.__beta26.compat21
                          and mod.exports.__beta26.compat21.trackerCatchContext
                          and mod.exports.__beta26.compat21.trackerCatchContext(
                              self.game, catch, r and (r.name or r.id))
                      if context and context.tag then
                          local contextText = trackerFitPixelText(
                              Strings(tostring(context.tag)), wideMode and 96 or 64)
                          local T = mod.exports.__beta26.UiSystem.typography(Font)
                          Font.draw(contextText, T.rightX(contextText, trackerWidth-16), y + 8)
                      end
                      y = y + 20
                  end
              end

              if listCount == 0 then
                  Font.draw(Strings("NO ENTRIES YET"), 16, y)
              end

              local maxScroll = math.max(0, listCount - 1)
              local canScrollUp = self.scroll > 0
              local canScrollDown = self.scroll < maxScroll
              local blinkOn = math.floor(self.arrowTime / 1.0) % 2 == 0

              if canScrollUp and blinkOn then
                  Font.draw(Strings("^"), wideMode and 144 or 72, 18)
              end

              -- Bottom information stays above the reserved footer.
              local cap = nextLevelCap(self.game and self.game.save)
              local capStr = cap >= 100 and Strings("CAP:MAX")
                  or Strings("CAP:%d", cap)
              Font.draw(capStr, 14, 114)
              local action = self:selectedAreaCanReroll() and Strings("A:RER")
                  or (guideEnabled and Strings("A:PG") or "")
              if action ~= "" then
                  local T = mod.exports.__beta26.UiSystem.typography(Font)
                  Font.draw(action, T.rightX(action, trackerWidth - 14), 114)
              end
              if canScrollDown and blinkOn then
                  local Theme = require("src.ui.Theme")
                  Font.drawCode(Theme.moreArrow or 0xEE,
                      math.floor(trackerWidth / 2) - 4, 116)
              end
              mod.exports.__beta26.UiSystem.gen1Footer(
                  Font, uiView, 130, trackerWidth)
          end

          -- Runtime containment for the custom Tracker surface. Constructor
          -- projection failures are already degraded to empty row sets above;
          -- these guards additionally prevent a later provider/render error
          -- from escaping StateStack and terminating the launcher process.
          do
              local function presentTrackerFault()
                  local fault = self.__trackerRuntimeFault
                  if not fault or self.__trackerRuntimeFaultPresented then return false end
                  self.__trackerRuntimeFaultPresented = true
                  local game = self.game
                  if not (game and game.stack) then return true end
                  pcall(function() game.stack:pop() end)
                  local short = tostring(fault.message or "tracker error"):gsub("^.-:%s*", "")
                  if #short > 150 then short = short:sub(1, 150) .. "..." end
                  local okText, TextBox = pcall(require, "src.render.TextBox")
                  if okText and TextBox then
                      pcall(function()
                          game.stack:push(TextBox.new(game,
                              "ENC TRACKER unavailable.\n" .. short))
                      end)
                  end
                  return true
              end

              local rawUpdate = self.update
              if type(rawUpdate) == "function" then
                  self.update = function(...)
                      if presentTrackerFault() then return end
                      local args = { ... }
                      local ok, result = xpcall(function()
                          return rawUpdate(unpackValues(args))
                      end, debug and debug.traceback or tostring)
                      if not ok then
                          trackerRuntimeFault("update", result, true)
                          presentTrackerFault()
                          return
                      end
                      return result
                  end
              end

              local rawDraw = self.draw
              if type(rawDraw) == "function" then
                  self.draw = function(...)
                      if self.__trackerRuntimeFault then return end
                      local args = { ... }
                      local ok, result = xpcall(function()
                          return rawDraw(unpackValues(args))
                      end, debug and debug.traceback or tostring)
                      if not ok then
                          trackerRuntimeFault("draw", result, true)
                          return
                      end
                      return result
                  end
              end

              local rawModel = self.nuzlockeModernUiModel
              if type(rawModel) == "function" then
                  self.nuzlockeModernUiModel = function(...)
                      local args = { ... }
                      local ok, result = xpcall(function()
                          return rawModel(unpackValues(args))
                      end, debug and debug.traceback or tostring)
                      if ok then return result end
                      trackerRuntimeFault("modern_model", result)
                      return {
                          title = Strings("ENC TRACKER"),
                          rows = { { label = Strings("TRACKER ERROR"), right = "" } },
                          index = 1,
                          scroll = 0,
                          footer = { Strings("B: BACK") },
                          details = { Strings("Tracker data could not be displayed.") },
                      }
                  end
              end

              local rawAction = self.nuzlockeModernUiAction
              if type(rawAction) == "function" then
                  self.nuzlockeModernUiAction = function(...)
                      local args = { ... }
                      local ok, result = xpcall(function()
                          return rawAction(unpackValues(args))
                      end, debug and debug.traceback or tostring)
                      if ok then return result end
                      trackerRuntimeFault("modern_action", result)
                      return false
                  end
              end
          end

          return self
      end
  })

  ---------------------------------------------------------------------
  -- CATCH INFO SCREEN
  -- Uses the same compact layout as the working catch-info page, but now
  -- includes the Nuzlocke encounter type and a factual loss summary.
  ---------------------------------------------------------------------
  mod.content.screens:register("NuzlockeCatchInfoScreen", {
      new = function(game, ctx)
          local mon = ctx and ctx.mon

          -- R/B/Y starters are canonically a Pallet Town encounter. Keep the
          -- established repair here because NUZ INFO may be the first screen
          -- that receives the concrete mon after an older acquisition callback.
          if type(mon) == "table" and mon.species then
              local ver = getGameVersion and getGameVersion() or "RED"
              local sp = tostring(mon.species or ""):upper()
              local locText = tostring(mon.catchLocation or ""):upper()
              local rbyStarter = (ver == "YELLOW" and sp == "PIKACHU")
                  or ((ver == "RED" or ver == "BLUE")
                      and (sp == "BULBASAUR" or sp == "CHARMANDER"
                          or sp == "SQUIRTLE"))
              if rbyStarter and (locText == "" or locText == "UNKNOWN"
                  or locText:find("OAK", 1, true)
                  or locText:find("LAB", 1, true)) then
                  mon.catchLocation = "PALLET_TOWN"
                  mon.encounterType = mon.encounterType or "gift"
                  mon.nuzlockeTrackerRegistered = true
                  Identity.setPokemonOrigin(mon, mon.nuzlockeOrigin or "NORMAL")
                  Identity.baselineAdd(mon, mon.nuzlockeOrigin or "NORMAL")
              end
          end

          local self = {
              game = game,
              screenId = "NuzlockeCatchInfoScreen",
              isOpaque = true,
              mon = mon,
              pageIndex = 1,
              marqueeTime = 0,
          }

          local function enabledPages()
              local pages = {}
              if mod.save:get("catch_info", true) == true then
                  pages[#pages + 1] = "catch"
              end
              if mod.save:get("stat_info", true) == true then
                  pages[#pages + 1] = "stat"
              end
              if mod.save:get("move_info", true) == true then
                  pages[#pages + 1] = "move"
              end
              -- A stale party menu can still have NUZ INFO open while every
              -- toggle is switched off elsewhere. Fail safe to one catch page
              -- rather than constructing a zero-page screen.
              if #pages == 0 then pages[1] = "catch" end
              return pages
          end

          local function currentPage()
              local pages = enabledPages()
              if self.pageIndex > #pages then self.pageIndex = 1 end
              if self.pageIndex < 1 then self.pageIndex = #pages end
              return pages[self.pageIndex], pages
          end

          local function cycle(delta)
              local _, pages = currentPage()
              if #pages <= 1 then return end
              self.pageIndex = self.pageIndex + delta
              if self.pageIndex > #pages then self.pageIndex = 1 end
              if self.pageIndex < 1 then self.pageIndex = #pages end
          end

          function self:update(dt)
              self.marqueeTime = (self.marqueeTime or 0) + (tonumber(dt) or 0)
              local input = self.game and self.game.input
              if not input then return end
              if input:wasPressed("b") then
                  self.game.stack:pop()
              elseif input:wasPressed("right") or input:wasPressed("a") then
                  cycle(1)
              elseif input:wasPressed("left") then
                  cycle(-1)
              end
          end

          local function displayOrigin(value)
              value = value and value.nuzlockeOrigin
              if value == "LEGACY" then return Strings("LEGACY") end
              if value == "EDITED" then return Strings("EXTERNAL") end
              if value == "PLAYER_CONFIRMED" then return Strings("CONFIRMED") end
              return Strings("NORMAL")
          end

          local function displayEncounterType(value)
              if value and (value.nuzlockeGlitch == true
                  or mod.exports.__beta26.getGlitchSpeciesInfo(
                      game, value.species).isGlitch) then
                  return Strings("GLITCH")
              end
              local kind = value and (value.encounterType
                  or value.nuzlockeEncounterType)
              if not kind then return Strings("UNKNOWN") end
              local labels = {
                  overworld = "OVERWORLD", wild = "WILD", town = "TOWN",
                  safari = "SAFARI", grass = "GRASS", surf = "SURF",
                  fishing = "FISHING", old_rod = "OLD ROD",
                  good_rod = "GOOD ROD", super_rod = "SUPER ROD",
                  gift = "GIFT", starter = "STARTER", static = "STATIC",
                  trade = "TRADE", wonder_trade = "WONDER TRADE",
              }
              return Strings(labels[kind] or tostring(kind):upper())
          end

          local function legalityInfo(value)
              if not value then return nil end
              local compat21 = mod.exports.__beta26.compat21
              return compat21 and compat21.pokemonLegality
                  and compat21.pokemonLegality(self.game, value) or nil
          end

          local function provenanceInfo(value)
              if not value then return nil end
              local compat21 = mod.exports.__beta26.compat21
              return compat21 and compat21.pokemonProvenance
                  and compat21.pokemonProvenance(self.game, value) or nil
          end

          local function pokemonLabel(value)
              if not value then return Strings("NO DATA") end
              local label = value.nickname
              if label == nil or label == "" then
                  label = mod.exports.__beta26.safeSpeciesLabel(
                      self.game, value.species)
              end
              return Strings(tostring(label))
          end

          local function hpDV(dvs)
              dvs = type(dvs) == "table" and dvs or {}
              if tonumber(dvs.hp) then return math.floor(tonumber(dvs.hp)) end
              local special = tonumber(dvs.special)
                  or tonumber(dvs.specialAttack)
                  or tonumber(dvs.specialDefense) or 0
              return ((tonumber(dvs.attack) or 0) % 2) * 8
                  + ((tonumber(dvs.defense) or 0) % 2) * 4
                  + ((tonumber(dvs.speed) or 0) % 2) * 2
                  + (special % 2)
          end

          local function statLine(label, value, dv, exp)
              local stat = tonumber(value)
              local d = tonumber(dv)
              local e = tonumber(exp)
              -- 2.7.74 recovery: fixed compact columns keep Gold's narrow body
              -- readable without D/E prefixes colliding with values.
              return ("%-3s %3s %2s %5s"):format(
                  tostring(label),
                  stat and tostring(math.floor(stat)) or "--",
                  d and tostring(math.floor(d)) or "--",
                  e and tostring(math.floor(e)) or "--")
          end

          local function statLines(value)
              if not value then
                  return { Strings("STAT INFO"), Strings("NO DATA") }
              end
              local stats = type(value.stats) == "table" and value.stats or {}
              local dvs = type(value.dvs) == "table" and value.dvs or {}
              local exp = type(value.statExp) == "table" and value.statExp or {}
              local gold = mod.exports.__beta26.runtimeIsGen2(self.game)
              local maxHp = tonumber(value.maxHp) or tonumber(stats.hp)
                  or tonumber(value.hp) or 0
              local curHp = tonumber(value.hp) or maxHp
              local lines = {
                  Strings("STAT INFO"),
                  pokemonLabel(value),
                  Strings("LV %d  HP %d/%d",
                      math.floor(tonumber(value.level) or 0),
                      math.floor(curHp), math.floor(maxHp)),
                  Strings("STAT VAL DV   EXP"),
                  statLine("HP ", stats.hp or maxHp, hpDV(dvs), exp.hp),
                  statLine("ATK", stats.attack, dvs.attack, exp.attack),
                  statLine("DEF", stats.defense, dvs.defense, exp.defense),
                  statLine("SPE", stats.speed, dvs.speed, exp.speed),
              }
              if gold then
                  local sdv = dvs.special or dvs.specialAttack
                      or dvs.specialDefense
                  local sexp = exp.special or exp.specialAttack
                      or exp.specialDefense
                  lines[#lines + 1] =
                      statLine("SPA", stats.specialAttack, sdv, sexp)
                  lines[#lines + 1] =
                      statLine("SDF", stats.specialDefense, sdv, sexp)
                  lines[#lines + 1] = Strings("SPA/SDF SHARE DV EXP")
              else
                  lines[#lines + 1] =
                      statLine("SPC", stats.special, dvs.special, exp.special)
              end
              return lines
          end

          local function cleanType(value)
              value = tostring(value or "?"):upper()
              value = value:gsub("_TYPE$", "")
              if value == "PSYCHIC_TYPE" then value = "PSYCHIC" end
              return value
          end

          local function accuracyText(value)
              local n = tonumber(value)
              if not n or n <= 0 then return "--" end
              if n > 100 and n <= 255 then
                  n = math.floor((n * 100 / 255) + 0.5)
              end
              return tostring(math.floor(n))
          end

          local function moveLines(value)
              local lines = { Strings("MOVE INFO"), pokemonLabel(value) }
              if not value then
                  lines[#lines + 1] = Strings("NO DATA")
                  return lines
              end
              local moves = type(value.moves) == "table" and value.moves or {}
              for slot = 1, 4 do
                  local move = moves[slot]
                  if move then
                      local id = type(move) == "table" and move.id or move
                      local def = self.game and self.game.data
                          and self.game.data.moves
                          and self.game.data.moves[id] or nil
                      local name = (def and def.name) or tostring(id or "?")
                      if #tostring(name) > 15 then
                          name = tostring(name):sub(1, 15)
                      end
                      local currentPp = type(move) == "table"
                          and tonumber(move.pp) or nil
                      local maxPp = type(move) == "table"
                          and tonumber(move.maxPp) or nil
                      maxPp = maxPp or (def and tonumber(def.pp)) or currentPp
                      local power = def and tonumber(def.power)
                      local typeName = cleanType(def and def.type)
                      lines[#lines + 1] =
                          Strings("%d %s", slot, tostring(name))
                      lines[#lines + 1] = Strings("%s PWR%s ACC%s",
                          typeName,
                          power and power > 0 and tostring(math.floor(power)) or "--",
                          accuracyText(def and def.accuracy))
                      lines[#lines + 1] = Strings("PP %s/%s",
                          currentPp and tostring(math.floor(currentPp)) or "--",
                          maxPp and tostring(math.floor(maxPp)) or "--")
                  else
                      lines[#lines + 1] = Strings("%d --", slot)
                      lines[#lines + 1] = Strings("-- PWR-- ACC--")
                      lines[#lines + 1] = Strings("PP --/--")
                  end
              end
              return lines
          end

          function self:nuzlockeModernUiModel()
              local page, pages = currentPage()
              local rows = {}
              local title = "CATCH INFO"

              if page == "stat" then
                  title = "STAT INFO"
                  local lines = statLines(self.mon)
                  table.remove(lines, 1)
                  for _, line in ipairs(lines) do
                      rows[#rows + 1] = { label = tostring(Strings(tostring(line))) }
                  end
              elseif page == "move" then
                  title = "MOVE INFO"
                  local lines = moveLines(self.mon)
                  table.remove(lines, 1)
                  for _, line in ipairs(lines) do
                      rows[#rows + 1] = { label = tostring(Strings(tostring(line))) }
                  end
              else
                  local value = self.mon
                  if not value then
                      rows[1] = { label = Strings("NO DATA") }
                  else
                      local loc = routeName(value.catchLocation or "UNKNOWN")
                      local legality = legalityInfo(value)
                      local provenance = provenanceInfo(value)
                      rows = {
                          { label = Strings("POKéMON"), right = pokemonLabel(value) },
                          { label = Strings("LOCATION"), right = Strings(loc) },
                          { label = Strings("ENCOUNTER"), right = displayEncounterType(value) },
                          { label = Strings("ORIGIN"), right = displayOrigin(value) },
                          { label = Strings("STATUS"),
                            right = Strings(value.nuzlockeDead == true and "LOST" or "ALIVE") },
                          { label = Strings("LEGALITY"),
                            right = Strings(legality and legality.status or "UNKNOWN") },
                      }
                      if legality and type(legality.reasons) == "table"
                          and #legality.reasons > 0 then
                          rows[#rows + 1] = {
                              label = Strings("RULE"),
                              right = Strings(table.concat(legality.reasons, "/")),
                          }
                      end
                      if provenance and provenance.provider then
                          rows[#rows + 1] = {
                              label = Strings("PROVIDER"),
                              right = Strings(tostring(provenance.provider)),
                          }
                      end
                      if provenance and provenance.source then
                          rows[#rows + 1] = {
                              label = Strings("SOURCE"),
                              right = Strings(tostring(provenance.source)),
                          }
                      end
                      if value.nuzlockeDead == true then
                          rows[#rows + 1] = {
                              label = Strings("CAUSE"),
                              right = tostring(value.deathCauseText
                                  or value.deathCause or "BATTLE"),
                          }
                      elseif Identity.isShiny(value) then
                          rows[#rows + 1] = { label = Strings("SHINY"), right = "*" }
                      end
                  end
              end

              return {
                  title = Strings(title),
                  rows = rows,
                  index = 1,
                  scroll = 0,
                  footer = #pages > 1
                      and { Strings("A/LEFT/RIGHT: PAGE"), Strings("B: BACK") }
                      or { Strings("B: BACK") },
                  details = {
                      Strings("PAGE %d/%d", self.pageIndex, #pages),
                  },
              }
          end

          function self:nuzlockeModernUiAction(action)
              if action == "back" then
                  self.game.stack:pop()
                  return true
              elseif action == "select" or action == "right" then
                  cycle(1)
                  return true
              elseif action == "left" then
                  cycle(-1)
                  return true
              end
              return false
          end

          -- 2.7.74 recovered utility-screen chrome: preserve native Gen2
          -- renderer/input while giving Nuzlocke-owned info pages one stable
          -- visual hierarchy.
          local function drawGoldCenteredBold(Chrome, value, row)
              local label = tostring(Strings(tostring(value or "")))
              if #label > 18 then label = label:sub(1, 18) end
              local col = math.max(1, math.floor((20 - #label) / 2))
              Chrome.print(label, col, row)
              local ok, GoldFont = pcall(require, "src.render.Font")
              if ok and GoldFont and type(GoldFont.draw) == "function" then
                  GoldFont.draw(label, col * 8 + 1, row * 8)
              end
          end

          local function drawGoldLines(lines, title)
              local Chrome = require("src.ui.gen2.Chrome")
              Chrome.clear()
              Chrome.box(0, 0, 20, 18)
              if title then drawGoldCenteredBold(Chrome, title, 1) end
              local body = lines or {}
              local start = 3
              -- First body row is the Pokémon/subject subtitle. Center it but
              -- keep normal weight so title and subject remain distinct.
              if body[1] ~= nil then
                  local subtitle = marqueeText(Strings(tostring(body[1])), 16,
                      self.marqueeTime, 3.8)
                  local text = tostring(subtitle)
                  local col = math.max(2, math.floor((20 - #text) / 2))
                  Chrome.print(subtitle, col, start)
                  start = start + 2
              end
              for i = 2, #body do
                  local row = start + (i - 2)
                  if row <= 14 then
                      Chrome.print(marqueeText(Strings(tostring(body[i])), 16,
                          self.marqueeTime, 3.8), 2, row)
                  end
              end
              local _, pages = currentPage()
              if #pages > 1 then
                  Chrome.print(Strings("A/<>:PG"), 2, 15)
              end
              Chrome.print(Strings("B:BACK"), 12, 15)
          end

          local function drawRbyLines(lines, title)
              local Font = mod.ui.Font
              Font.drawBox(0, 0, 20, 18)
              if title then Font.draw(Strings(title), 16, 12) end
              for i, line in ipairs(lines or {}) do
                  if i <= 13 then
                      Font.draw(marqueeText(Strings(tostring(line)), 18,
                          self.marqueeTime, 3.8), 8, 14 + i * 8)
                  end
              end
              local _, pages = currentPage()
              if #pages > 1 then Font.draw(Strings("A/<>:PG"), 8, 128) end
              Font.draw(Strings("B:BACK"), 104, 128)
          end

          local function drawCatch(value)
              local lines = {}
              if not value then
                  lines = { Strings("NO DATA") }
              else
                  local loc = routeName(value.catchLocation or "UNKNOWN")
                  local encounter = displayEncounterType(value)
                  local origin = displayOrigin(value)
                  local dead = value.nuzlockeDead == true
                  local legality = legalityInfo(value)
                  local provenance = provenanceInfo(value)
                  lines = {
                      pokemonLabel(value),
                      Strings("LOCATION %s", tostring(loc)),
                      Strings("ENCOUNTER %s", tostring(encounter)),
                      Strings("ORIGIN %s", tostring(origin)),
                      Strings("STATUS %s", dead and "LOST" or "ALIVE"),
                      Strings("LEGAL %s",
                          legality and tostring(legality.status) or "UNKNOWN"),
                  }
                  if legality and type(legality.reasons) == "table"
                      and #legality.reasons > 0 then
                      lines[#lines + 1] =
                          Strings("RULE %s", table.concat(legality.reasons, "/"))
                  end
                  if provenance and provenance.provider then
                      lines[#lines + 1] =
                          Strings("FROM %s", tostring(provenance.provider))
                  end
                  if provenance and provenance.source then
                      lines[#lines + 1] =
                          Strings("SRC %s", tostring(provenance.source))
                  end
                  if dead then
                      lines[#lines + 1] = Strings("CAUSE %s", tostring(
                          value.deathCauseText or value.deathCause or "BATTLE"))
                  elseif Identity.isShiny(value) then
                      lines[#lines + 1] = Strings("SHINY")
                  end
              end
              if mod.exports.__beta26.runtimeIsGen2(self.game) then
                  drawGoldLines(lines, "CATCH INFO")
              else
                  drawRbyLines(lines, "CATCH INFO")
              end
          end

          function self:draw()
              local page = currentPage()
              if page == "stat" then
                  local lines = statLines(self.mon)
                  -- The first entry is the page title; the backend draws the
                  -- title separately so the usable body starts with the mon.
                  table.remove(lines, 1)
                  if mod.exports.__beta26.runtimeIsGen2(self.game) then
                      drawGoldLines(lines, "STAT INFO")
                  else
                      drawRbyLines(lines, "STAT INFO")
                  end
              elseif page == "move" then
                  local lines = moveLines(self.mon)
                  table.remove(lines, 1)
                  if mod.exports.__beta26.runtimeIsGen2(self.game) then
                      drawGoldLines(lines, "MOVE INFO")
                  else
                      drawRbyLines(lines, "MOVE INFO")
                  end
              else
                  drawCatch(self.mon)
              end
          end

          return self
      end
  })

  ---------------------------------------------------------------------

  return {
      isTownArea = isTownArea,
      getDisplayRoutes = getDisplayRoutes,
      refreshGymGuideVisibility = refreshGymGuideVisibility,
      syncCurrentArea = syncCurrentArea,
      areaAllowedByConfig = areaAllowedByConfig,
      nuzStatusEncounterSnapshot = nuzStatusEncounterSnapshot,
      nuzStatusLastHistoryEvent = nuzStatusLastHistoryEvent,
      nuzStatusTokenBalance = nuzStatusTokenBalance,
      nuzCompatIdentityLine = nuzCompatIdentityLine,
      pushNuzlockeRunHistoryViewer = pushNuzlockeRunHistoryViewer,
      recordRunBlackout = recordRunBlackout,
  }
end
