-- Module owner: PokemonIdentity
-- Stable Pokemon instance identity, species metadata lookup, and provenance persistence.
return function(mod, deps)
  deps = type(deps) == "table" and deps or {}
  local activeCompatProvider = assert(deps.activeCompatProvider, "PokemonIdentity requires activeCompatProvider")
  local forEachExistingSaveBox = assert(deps.forEachExistingSaveBox, "PokemonIdentity requires forEachExistingSaveBox")
  local getCurrentGame = assert(deps.getCurrentGame, "PokemonIdentity requires getCurrentGame")
  local getCurrentSave = assert(deps.getCurrentSave, "PokemonIdentity requires getCurrentSave")
  local getStatsModule = assert(deps.getStatsModule, "PokemonIdentity requires getStatsModule")
  local getSaveSchemaTooNew = assert(deps.getSaveSchemaTooNew, "PokemonIdentity requires getSaveSchemaTooNew")
  local function currentGameValue() return getCurrentGame() end
  local function currentSaveValue() return getCurrentSave() end

  local function collectLegacyMons(save)
      local mons = {}

      local function addFrom(list)
          if type(list) ~= "table" then
              return
          end

          for _, mon in ipairs(list) do
              if type(mon) == "table" and mon.species then
                  table.insert(mons, mon)
              end
          end
      end

      addFrom(save.party)

      forEachExistingSaveBox(save, function(box)
          addFrom(box)
      end)

      if type(save.daycare) == "table" and type(save.daycare.mon) == "table" then
          addFrom({ save.daycare.mon })
      end

      return mons
  end

  local ID_REGISTRY_KEY = "nuzlocke_pokemon_identity_registry"
  local ID_COUNTER_KEY = "nuzlocke_pokemon_identity_counter"
  local EXTERNAL_ID_MAP_KEY = "nuzlocke_external_identity_map"

  local function pokemonFingerprint(mon)
      if type(mon) ~= "table" then return nil end
      local species = tostring(mon.species or ""):upper()
      if species == "" then return nil end
      local dvs = mon.dvs
      if type(dvs) ~= "table" then
          return species .. "|DV:?"
      end

      local function dvValue(a, b)
          return tostring(dvs[a] ~= nil and dvs[a] or dvs[b] ~= nil and dvs[b] or "?")
      end
      return table.concat({
          species,
          dvValue("hp", "HP"),
          dvValue("attack", "ATTACK"),
          dvValue("defense", "DEFENSE"),
          dvValue("speed", "SPEED"),
          dvValue("special", "SPECIAL"),
      }, "|")
  end

  local function monIsShiny(mon)
      if type(mon) ~= "table" then return false end
      if type(mon.isShiny) == "boolean" then return mon.isShiny end
      if type(mon.shiny) == "boolean" then return mon.shiny end
      if type(mon.is_shiny) == "boolean" then return mon.is_shiny end
      if type(mon.dvs) == "table" then
          local Stats = getStatsModule()
          if Stats and type(Stats.isShiny) == "function" then
              local ok, value = pcall(Stats.isShiny, mon.dvs)
              if ok then return value == true end
          end
      end
      return false
  end

  local function speciesDefinition(game, species)
      local data = game and game.data and game.data.pokemon
      if type(data) ~= "table" then
          local coreData = require("src.core.Data")
          data = coreData and coreData.pokemon
      end
      if type(data) ~= "table" then return nil end

      local raw = species
      local key = tostring(raw or ""):upper()
      local direct = data[raw] or data[key]
      if type(direct) == "table" then return direct end

      -- Gen1Recomp Gen-2 data may be indexed by numeric species id while
      -- script transactions identify the Pokemon by canonical string name.
      -- Resolve those rows before the glitch classifier treats an otherwise
      -- ordinary Johto starter/gift as an unregistered species.
      for id, row in pairs(data) do
          if type(row) == "table" then
              local aliases = {
                  row.id, row.key, row.species, row.name,
                  row.internalName, row.internal_name,
              }
              for _, alias in ipairs(aliases) do
                  if alias ~= nil and tostring(alias):upper() == key then
                      return row
                  end
              end
              local numeric = tonumber(raw)
              if numeric ~= nil and (tonumber(id) == numeric
                  or tonumber(row.index) == numeric) then
                  return row
              end
          end
      end
      return nil
  end

  local function providerSpeciesMetadata(game, species)
      local provider = activeCompatProvider("species_metadata", game, nil)
      local value = provider and provider.value
      if not provider then return nil end

      local getter
      if type(value) == "function" then
          getter = value
      elseif type(value) == "table" then
          getter = value.get_metadata or value.metadata or value.get_species_metadata
      end
      if type(getter) ~= "function" then return nil end

      local ok, result = pcall(getter, game, species)
      if not ok then
          ok, result = mod.exports.__beta26.Dev.pguard(
              "provider_species_metadata", getter, species, game)
      end
      return ok and type(result) == "table" and result or nil
  end

  local function allCurrentMons(save)
      return collectLegacyMons(save)
  end

  local function identityRegistry()
      local registry = mod.save:get(ID_REGISTRY_KEY)
      if type(registry) ~= "table" then registry = {} end
      return registry
  end

  local function externalIdentityMap()
      local map = mod.save:get(EXTERNAL_ID_MAP_KEY)
      if type(map) ~= "table" then map = {} end
      return map
  end

  local function normalizePokemonId(value)
      if value == nil then return nil end
      value = tostring(value)
      if value == "" then return nil end
      return value
  end

  local function providerPokemonIdentity(mon)
      if type(mon) ~= "table" then return nil end
      local provider = activeCompatProvider("pokemon_identity", currentGameValue(), nil)
      if not provider then return nil end

      local value = provider.value
      local getter
      if type(value) == "function" then
          getter = value
      elseif type(value) == "table" then
          getter = value.get_id or value.get_identity or value.get_pokemon_id
      end
      if type(getter) ~= "function" then return nil end

      local ok, result = pcall(getter, mon, currentGameValue())
      if not ok then
          -- Some providers may prefer (game, mon). Accept that shape too.
          ok, result = pcall(getter, currentGameValue(), mon)
      end
      local externalId = ok and normalizePokemonId(result) or nil
      if not externalId then return nil end
      return tostring(provider.id) .. "|" .. externalId, provider
  end

  local function allocatePokemonId(save)
      local registry = identityRegistry()
      local counter = math.max(0, math.floor(tonumber(mod.save:get(ID_COUNTER_KEY, 0)) or 0))

      -- Recover from a lost/reset counter by scanning IDs that survived on the
      -- Pokemon themselves and IDs retained in the registry.
      for _, mon in ipairs(allCurrentMons(save or currentSaveValue() or {})) do
          local n = tostring(mon and mon.nuzlockeId or ""):match("^NZL%-(%d+)$")
          n = tonumber(n)
          if n and n > counter then counter = n end
      end
      for id in pairs(registry) do
          local n = tostring(id):match("^NZL%-(%d+)$")
          n = tonumber(n)
          if n and n > counter then counter = n end
      end

      repeat
          counter = counter + 1
      until registry["NZL-" .. tostring(counter)] == nil

      mod.save:set(ID_COUNTER_KEY, counter)
      return "NZL-" .. tostring(counter)
  end

  local function existingPokemonIdentity(mon)
      if type(mon) ~= "table" then return nil end

      local id = normalizePokemonId(mon.nuzlockeId)
      if id then return id end

      local externalKey = providerPokemonIdentity(mon)
      if externalKey then
          local map = externalIdentityMap()
          local mapped = normalizePokemonId(map[externalKey])
          if mapped then return mapped end
      end

      return nil
  end

  local function ensurePokemonIdentity(mon, save, origin)
      if type(mon) ~= "table" or not mon.species then return nil end

      -- Public and internal identity callers share this mutation boundary.
      -- Older builds must never hydrate/allocate fields on a newer-schema save.
      if getSaveSchemaTooNew() then return existingPokemonIdentity(mon) end

      local id = existingPokemonIdentity(mon)
      local externalKey, provider = providerPokemonIdentity(mon)
      if not id then
          id = allocatePokemonId(save)
          mon.nuzlockeId = id
          if externalKey then
              local map = externalIdentityMap()
              map[externalKey] = id
              mod.save:set(EXTERNAL_ID_MAP_KEY, map)
              mon.nuzlockeIdentityProvider = provider and provider.id or nil
              mon.nuzlockeExternalIdentity = externalKey
          end
      elseif externalKey then
          -- Hydration is explicit and occurs only on the mutating ensure path.
          mon.nuzlockeIdentityProvider = provider and provider.id or nil
          mon.nuzlockeExternalIdentity = externalKey
      end

      local registry = identityRegistry()
      local entry = registry[id]
      if type(entry) ~= "table" then entry = {} end
      entry.speciesAtRegistration = entry.speciesAtRegistration or tostring(mon.species or ""):upper()
      entry.currentSpecies = tostring(mon.species or ""):upper()
      if origin then entry.origin = origin end
      if mon.catchLocation then entry.catchLocation = mon.catchLocation end
      registry[id] = entry
      mod.save:set(ID_REGISTRY_KEY, registry)

      return id
  end

  local function pokemonIdentity(mon)
      return existingPokemonIdentity(mon)
  end

  local function samePokemonIdentity(entry, mon)
      if type(entry) ~= "table" or type(mon) ~= "table" then return false end

      local monId = pokemonIdentity(mon)
      local entryId = normalizePokemonId(entry.pokemonId)
      if monId and entryId then
          return monId == entryId
      end

      -- Old tracker rows have no Pokemon ID. Fingerprints remain a migration
      -- fallback only; species is the final compatibility fallback.
      local efp = entry.fingerprint
      local mfp = pokemonFingerprint(mon)
      if efp and mfp then return efp == mfp end

      return tostring(entry.species or ""):upper()
          == tostring(mon.species or ""):upper()
  end

  local function repairDuplicatePokemonIds(save)
      local seen = {}
      for _, mon in ipairs(allCurrentMons(save or {})) do
          if type(mon) == "table" then
              local id = normalizePokemonId(mon.nuzlockeId)
              if id then
                  if seen[id] and seen[id] ~= mon then
                      -- A copied Pokemon table can duplicate our custom ID.
                      -- Never let two current Pokemon share one identity.
                      mon.nuzlockeIdentityDuplicateOf = id
                      mon.nuzlockeId = nil
                      mon.nuzlockeOrigin = "EDITED"
                      ensurePokemonIdentity(mon, save, "EDITED")
                  else
                      seen[id] = mon
                  end
              end
          end
      end
  end

  local function pokemonBaseline()
      local baseline = mod.save:get("nuzlocke_pokemon_baseline")
      if type(baseline) ~= "table" then baseline = {} end
      return baseline
  end

  local function pokemonOrigins()
      local origins = mod.save:get("nuzlocke_pokemon_origins")
      if type(origins) ~= "table" then origins = {} end
      return origins
  end

  local function originBucket(origin)
      local origins = pokemonOrigins()
      origins[origin] = origins[origin] or {}
      return origins
  end

  local function setPokemonOrigin(mon, origin)
      if type(mon) ~= "table" or not origin then return end
      mon.nuzlockeOrigin = origin

      local id = normalizePokemonId(mon.nuzlockeId)
      if id then
          local registry = identityRegistry()
          local entry = registry[id]
          if type(entry) ~= "table" then entry = {} end
          entry.origin = origin
          entry.currentSpecies = tostring(mon.species or ""):upper()
          if mon.catchLocation then entry.catchLocation = mon.catchLocation end
          registry[id] = entry
          mod.save:set(ID_REGISTRY_KEY, registry)
      end
  end


  local function baselineAdd(mon, origin)
      if type(mon) ~= "table" then return end
      origin = origin or mon.nuzlockeOrigin or "NORMAL"
      local id = ensurePokemonIdentity(mon, currentSaveValue(), origin)
      setPokemonOrigin(mon, origin)

      -- The fingerprint baseline is kept only for migration from pre-ID saves.
      -- Register each persistent identity at most once so repeated save loads
      -- cannot inflate the old count-based baseline.
      local registry = identityRegistry()
      local identityEntry = id and registry[id] or nil
      if type(identityEntry) == "table" and identityEntry.baselineRegistered == true then
          return
      end

      local fp = pokemonFingerprint(mon)
      if fp then
          local baseline = pokemonBaseline()
          baseline[fp] = (tonumber(baseline[fp]) or 0) + 1
          local origins = originBucket(origin)
          origins[origin][fp] = (tonumber(origins[origin][fp]) or 0) + 1
          mod.save:set("nuzlocke_pokemon_baseline", baseline)
          mod.save:set("nuzlocke_pokemon_origins", origins)
      end

      if id then
          registry = identityRegistry()
          identityEntry = registry[id] or {}
          identityEntry.baselineRegistered = true
          identityEntry.origin = origin
          identityEntry.fingerprint = identityEntry.fingerprint or fp
          registry[id] = identityEntry
          mod.save:set(ID_REGISTRY_KEY, registry)
      end
  end

  local function consumeOrigin(origins, fp, preferred)
      local order = { preferred, "NORMAL", "PLAYER_CONFIRMED", "LEGACY", "EDITED" }
      local seen = {}
      for _, origin in ipairs(order) do
          if origin and not seen[origin] then
              seen[origin] = true
              local bucket = origins[origin]
              local count = bucket and tonumber(bucket[fp]) or 0
              if count and count > 0 then
                  bucket[fp] = count - 1
                  return origin
              end
          end
      end
      return nil
  end

  local function classifyPokemonProvenance(save, initializing)
      if type(save) ~= "table" then return end
      local mons = allCurrentMons(save)
      local baseline = pokemonBaseline()
      local origins = pokemonOrigins()

      repairDuplicatePokemonIds(save)

      if initializing then
          baseline = {}
          origins = { LEGACY = {}, NORMAL = {}, EDITED = {}, PLAYER_CONFIRMED = {} }
          mod.save:set("nuzlocke_pokemon_baseline", baseline)
          mod.save:set("nuzlocke_pokemon_origins", origins)

          local existingLog = mod.save:get("tracker_log")
          local knownNormal = {}
          local knownLegacy = {}
          if type(existingLog) == "table" then
              for area, entries in pairs(existingLog) do
                  if area ~= "__LEGACY__" and type(entries) == "table" then
                      for _, entry in ipairs(entries) do
                          if type(entry) == "table" and entry.species then
                              local sp = tostring(entry.species):upper()
                              if entry.provenance == "LEGACY"
                                  or entry.legacy == true or entry.retroactive == true then
                                  knownLegacy[sp] = (knownLegacy[sp] or 0) + 1
                              else
                                  knownNormal[sp] = (knownNormal[sp] or 0) + 1
                              end
                          end
                      end
                  end
              end
          end

          local usedNormal, usedLegacy = {}, {}
          for _, mon in ipairs(mons) do
              local sp = tostring(mon.species or ""):upper()

              -- If mod-owned fields survived but mod.save did not, preserve
              -- their explicit provenance rather than demoting the Pokemon.
              local origin = mon.nuzlockeOrigin
              if origin ~= "NORMAL" and origin ~= "PLAYER_CONFIRMED"
                  and origin ~= "LEGACY" and origin ~= "EDITED" then
                  origin = nil
              end

              if not origin then
                  origin = "LEGACY"
                  if (usedNormal[sp] or 0) < (knownNormal[sp] or 0) then
                      usedNormal[sp] = (usedNormal[sp] or 0) + 1
                      origin = "NORMAL"
                  elseif (usedLegacy[sp] or 0) < (knownLegacy[sp] or 0) then
                      usedLegacy[sp] = (usedLegacy[sp] or 0) + 1
                      origin = "LEGACY"
                  elseif mon.nuzlockeTrackerRegistered == true and mon.catchLocation then
                      origin = "NORMAL"
                  end
              end

              setPokemonOrigin(mon, origin)
              baselineAdd(mon, origin)
          end

          mod.save:set("nuzlocke_provenance_initialized", true)
          return
      end

      local remaining = {}
      for k, v in pairs(baseline) do remaining[k] = tonumber(v) or 0 end
      for _, bucket in pairs(origins) do
          if type(bucket) == "table" then
              for fp, count in pairs(bucket) do
                  bucket[fp] = tonumber(count) or 0
              end
          end
      end

      local registry = identityRegistry()

      for _, mon in ipairs(mons) do
          local id = existingPokemonIdentity(mon)
          local registered = id and registry[id]
          local registeredOrigin = type(registered) == "table" and registered.origin or nil

          if registeredOrigin then
              -- Persistent identity is authoritative. Species, DVs/IVs, EVs,
              -- gender, ability, Pokerus and moves may all change normally.
              setPokemonOrigin(mon, registeredOrigin)
              ensurePokemonIdentity(mon, save, registeredOrigin)
          elseif mon.nuzlockeOrigin
              and (id or mon.nuzlockeTrackerRegistered == true or mon.catchLocation) then
              -- Custom fields survived but the registry did not.
              ensurePokemonIdentity(mon, save, mon.nuzlockeOrigin)
              setPokemonOrigin(mon, mon.nuzlockeOrigin)
          else
              -- Pre-beta.19 compatibility path. Use the old fingerprint counts
              -- exactly once to recover provenance, then assign a persistent ID.
              local fp = pokemonFingerprint(mon)
              local known = fp and remaining[fp] or 0
              local origin

              if known and known > 0 then
                  remaining[fp] = known - 1
                  local preferred = mon.nuzlockeTrackerRegistered and "NORMAL" or nil
                  origin = fp and consumeOrigin(origins, fp, preferred)
                  origin = origin or preferred or "LEGACY"
              elseif mon.nuzlockeTrackerRegistered == true then
                  origin = mon.nuzlockeOrigin or "NORMAL"
              elseif mon.catchLocation then
                  -- A stored catch location is stronger evidence than the lack
                  -- of an old fingerprint entry.
                  origin = mon.nuzlockeOrigin or "LEGACY"
              else
                  origin = "EDITED"
              end

              setPokemonOrigin(mon, origin)
              local newId = ensurePokemonIdentity(mon, save, origin)

              -- This mon was recovered from an existing baseline; do not add a
              -- second count for the same historical Pokemon.
              if known and known > 0 and newId then
                  registry = identityRegistry()
                  local e = registry[newId] or {}
                  e.baselineRegistered = true
                  e.fingerprint = e.fingerprint or fp
                  e.origin = origin
                  registry[newId] = e
                  mod.save:set(ID_REGISTRY_KEY, registry)
              else
                  baselineAdd(mon, origin)
              end
          end
      end

      mod.save:set("nuzlocke_pokemon_origins", origins)
  end

  local function initializePokemonProvenance(save)
      local initialized = mod.save:get("nuzlocke_provenance_initialized", false) == true
      classifyPokemonProvenance(save, not initialized)

      -- Every current Pokemon should leave reconstruction with an identity,
      -- even if it came from a custom species/mod with no DVs at all.
      for _, mon in ipairs(allCurrentMons(save or {})) do
          if type(mon) == "table" and mon.species then
              local origin = mon.nuzlockeOrigin
                  or (mon.nuzlockeTrackerRegistered and "NORMAL")
                  or "LEGACY"
              ensurePokemonIdentity(mon, save, origin)
          end
      end
  end

  -- Public identity helpers for cooperative mods. Reading an existing ID does
  -- not mutate the Pokemon; ensurePokemonId is explicit for integrations that
  -- need a Nuzlocke-owned stable token immediately.
  if mod.exports.nuzlocke_compat then
      mod.exports.nuzlocke_compat.getPokemonId = function(mon)
          return pokemonIdentity(mon)
      end
      mod.exports.nuzlocke_compat.ensurePokemonId = function(mon, game, origin)
          return ensurePokemonIdentity(mon,
              game and game.save or currentSaveValue(),
              origin or (mon and mon.nuzlockeOrigin) or "NORMAL")
      end
  end



  return {
      ID_REGISTRY_KEY = ID_REGISTRY_KEY, fingerprint = pokemonFingerprint, isShiny = monIsShiny,
      speciesDefinition = speciesDefinition, providerSpeciesMetadata = providerSpeciesMetadata,
      collectLegacyMons = collectLegacyMons, allCurrentMons = allCurrentMons, identityRegistry = identityRegistry,
      existingPokemonIdentity = existingPokemonIdentity, ensurePokemonIdentity = ensurePokemonIdentity,
      pokemonIdentity = pokemonIdentity, samePokemonIdentity = samePokemonIdentity,
      setPokemonOrigin = setPokemonOrigin, baselineAdd = baselineAdd,
      initializePokemonProvenance = initializePokemonProvenance,
  }
end
