-- Module owner: SpeciesPolicy
-- Configurable species-restriction facts and deterministic Locke policy.
-- Pokemon instance identity/provenance, tracker state, shiny generation/presentation,
-- Randomizer mappings, and acquisition enforcement orchestration remain external.
return function(mod, deps)
  deps = type(deps) == "table" and deps or {}
  local Identity = assert(deps.Identity, "SpeciesPolicy requires Identity")
  local getCurrentGame = assert(deps.getCurrentGame, "SpeciesPolicy requires getCurrentGame")
  local getGameVersion = assert(deps.getGameVersion, "SpeciesPolicy requires getGameVersion")
  local getLegendarySet = assert(deps.getLegendarySet, "SpeciesPolicy requires getLegendarySet")
  local getMythicalSet = assert(deps.getMythicalSet, "SpeciesPolicy requires getMythicalSet")
  local getPseudoSet = assert(deps.getPseudoSet, "SpeciesPolicy requires getPseudoSet")
  local speciesDefinition = assert(Identity.speciesDefinition, "SpeciesPolicy requires Identity.speciesDefinition")
  local providerSpeciesMetadata = assert(Identity.providerSpeciesMetadata, "SpeciesPolicy requires Identity.providerSpeciesMetadata")
  local function currentGameValue() return getCurrentGame() end
  local function gameVersionValue() return getGameVersion() end
  local function legendarySetValue() return getLegendarySet() end
  local function mythicalSetValue() return getMythicalSet() end
  local function pseudoSetValue() return getPseudoSet() end

  ---------------------------------------------------------------------
  -- TYPE LOCKE (MONOLOCKE / DUOLOCKE / TRILOCKE / QUADLOCKE / PENTALOCKE / HEXALOCKE)
  --
  -- This stable canonical type vocabulary is shared by R/B/Y and Gold.
  -- DARK/STEEL/FAIRY stay selectable even when a base game lacks them so
  -- content providers can make those variants viable without changing rule
  -- semantics. Unknown truly custom type schemas still fail open rather than
  -- falsely banning a provider-owned species.
  ---------------------------------------------------------------------
  local TYPE_LOCK_TYPES = {
      [0] = "NORMAL", [1] = "FIGHTING", [2] = "FLYING", [3] = "POISON",
      [4] = "GROUND", [5] = "ROCK", [6] = "BUG", [7] = "GHOST",
      [8] = "FIRE", [9] = "WATER", [10] = "GRASS", [11] = "ELECTRIC",
      [12] = "PSYCHIC_TYPE", [13] = "ICE", [14] = "DRAGON",
      [15] = "DARK", [16] = "STEEL",
      -- Keep selector value 17 permanently reserved for the existing RANDOM
      -- sentinel so old saves/setup profiles cannot silently change meaning.
      -- FAIRY is appended at 18 and becomes concrete only when selected/rolled.
      [18] = "FAIRY",
  }
  local TYPE_LOCK_TYPE_COUNT = 18 -- concrete types; selector span also contains RANDOM
  local TYPE_LOCK_RANDOM = 17 -- compatibility-stable selector sentinel; never an allowed type
  local TYPE_LOCK_SLOT_KEYS = {
      "type_lock_primary", "type_lock_secondary", "type_lock_tertiary",
      "type_lock_quaternary", "type_lock_quinary", "type_lock_senary",
  }
  local TYPE_LOCK_SLOT_DEFAULTS = { 0, 9, 10, 8, 11, 2 }
  -- 2.5.8: config/update closures can survive a mod reload on some runtime
  -- paths. Expose canonical slot/default tables through lifecycle-stable
  -- accessors so Type Locke edits never depend on a stale local table upvalue.
  mod.exports.__beta26.typeLockSlotKeys = function()
      if type(TYPE_LOCK_SLOT_KEYS) == "table" then return TYPE_LOCK_SLOT_KEYS end
      return {
          "type_lock_primary", "type_lock_secondary", "type_lock_tertiary",
          "type_lock_quaternary", "type_lock_quinary", "type_lock_senary",
      }
  end
  mod.exports.__beta26.typeLockSlotDefaults = function()
      if type(TYPE_LOCK_SLOT_DEFAULTS) == "table" then return TYPE_LOCK_SLOT_DEFAULTS end
      return { 0, 9, 10, 8, 11, 2 }
  end
  local TYPE_LOCK_SLOT_INDEX = {}
  for i, key in ipairs(TYPE_LOCK_SLOT_KEYS) do TYPE_LOCK_SLOT_INDEX[key] = i end
  -- 2.5.9: setup/profile code lives outside this lexical block. Never let it
  -- resolve TYPE_LOCK_SLOT_INDEX/KEYS as accidental globals again. These
  -- accessors keep the canonical tables owned here while exposing only the
  -- stable lookup operations the later UI/save paths need.
  mod.exports.__beta26.typeLockSlotIndex = function(key)
      return TYPE_LOCK_SLOT_INDEX[tostring(key or "")]
  end
  mod.exports.__beta26.typeLockSlotKey = function(index)
      return TYPE_LOCK_SLOT_KEYS[math.floor(tonumber(index) or 0)]
  end
  local TYPE_LOCK_MODE_LABELS = {
      [0] = "OFF", [1] = "MONO", [2] = "DUO", [3] = "TRI",
      [4] = "QUAD", [5] = "PENTA", [6] = "HEXA",
  }
  local TYPE_LOCK_MODE_NAMES = {
      [1] = "Monolocke", [2] = "Duolocke", [3] = "Trilocke",
      [4] = "Quadlocke", [5] = "Pentalocke", [6] = "Hexalocke",
  }
  local TYPE_LOCK_SET = {}
  for _, id in pairs(TYPE_LOCK_TYPES) do TYPE_LOCK_SET[id] = true end

  local function normalizeTypeLockType(value)
      if type(value) == "table" then
          value = value.id or value.key or value.name or value.type
      end
      local key = tostring(value or ""):upper()
          :gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%s%-]+", "_")
      if key == "PSYCHIC" then key = "PSYCHIC_TYPE" end
      if key ~= "PSYCHIC_TYPE" and key:sub(-5) == "_TYPE" then
          key = key:sub(1, -6)
      end
      return TYPE_LOCK_SET[key] and key or nil
  end

  local function appendSpeciesTypes(out, seen, row)
      if type(row) ~= "table" then return end
      local source = row.types
      if type(source) == "table" then
          for _, value in ipairs(source) do
              local key = normalizeTypeLockType(value)
              if key and not seen[key] then
                  seen[key] = true
                  out[#out + 1] = key
              end
          end
      elseif source ~= nil then
          local key = normalizeTypeLockType(source)
          if key and not seen[key] then seen[key] = true; out[#out + 1] = key end
      end
      local function add(value)
          local key = normalizeTypeLockType(value)
          if key and not seen[key] then seen[key] = true; out[#out + 1] = key end
      end
      add(row.type)
      add(row.type1)
      add(row.type2)
      add(row.primaryType)
      add(row.secondaryType)
      add(row.primary_type)
      add(row.secondary_type)
  end

  local function speciesTypeLockTypes(game, species)
      local out, seen = {}, {}
      appendSpeciesTypes(out, seen, speciesDefinition(game, species))
      appendSpeciesTypes(out, seen, providerSpeciesMetadata(game, species))
      return #out > 0 and out or nil
  end

  -- Once a concrete Pokemon exists, its runtime typing is more authoritative
  -- than the base species record. This lets form/type transformation mods such
  -- as Delta Type compose with Mono/Duo/Trilocke without hardcoding their IDs.
  -- Unknown runtime metadata still falls back to merged species/provider data.
  local function pokemonTypeLockTypes(game, mon)
      if type(mon) ~= "table" then return nil end
      local out, seen = {}, {}
      -- A provider may persist a permanent transformation separately from
      -- mon.types because an engine identity refresh can restore species base
      -- types later. Prefer that explicit transformed payload when present.
      local extra = mon.extra
      if type(extra) == "table" then
          appendSpeciesTypes(out, seen, extra.delta)
          if #out > 0 then return out end
      end
      -- Otherwise a concrete mon's own runtime type fields are authoritative.
      -- Do not union them with base species types: a permanent transformation
      -- from FIRE to WATER must not pass a FIRE lock because its species began
      -- as FIRE.
      appendSpeciesTypes(out, seen, mon)
      if #out > 0 then return out end
      return speciesTypeLockTypes(game, mon.species)
  end

  mod.exports.__beta26.typeLockTypes = TYPE_LOCK_TYPES
  mod.exports.__beta26.typeLockTypeCount = TYPE_LOCK_TYPE_COUNT
  mod.exports.__beta26.typeLockRandomIndex = TYPE_LOCK_RANDOM

  -- Concrete Type Locke values are intentionally sparse: 17 remains RANDOM
  -- for save compatibility while FAIRY lives at 18.
  mod.exports.__beta26.normalizeTypeLockIndex = function(index, fallback)
      index = math.floor(tonumber(index) or -1)
      if TYPE_LOCK_TYPES[index] ~= nil then return index end
      fallback = math.floor(tonumber(fallback) or 0)
      return TYPE_LOCK_TYPES[fallback] ~= nil and fallback or 0
  end

  mod.exports.__beta26.nextTypeLockConcreteIndex = function(index, exclude)
      index = mod.exports.__beta26.normalizeTypeLockIndex(index, 0)
      exclude = tonumber(exclude)
      -- Selector span is 0..18; skip the reserved RANDOM sentinel at 17.
      for step = 1, 19 do
          local candidate = (index + step) % 19
          if candidate ~= TYPE_LOCK_RANDOM
              and TYPE_LOCK_TYPES[candidate] ~= nil
              and (exclude == nil or candidate ~= exclude) then
              return candidate
          end
      end
      return 0
  end

  mod.exports.__beta26.typeLockTypeLabel = function(index)
      index = math.floor(tonumber(index) or 0)
      if index == TYPE_LOCK_RANDOM then return "RANDOM" end
      local key = TYPE_LOCK_TYPES[index] or "NORMAL"
      return key == "PSYCHIC_TYPE" and "PSYCHIC" or key
  end

  -- RANDOM should never create an impossible vanilla run merely because the
  -- shared Gen-I+II vocabulary contains a type that the current species pool
  -- does not. Build the roll pool from the live merged species data (including
  -- provider metadata); if no usable type metadata exists, fall back to the
  -- full stable vocabulary rather than guessing.
  mod.exports.__beta26.typeLockViableIndices = function(game)
      game = game or currentGameValue() or mod.game
      local pokemon = game and game.data and game.data.pokemon or {}
      local seen, out = {}, {}
      for species in pairs(pokemon) do
          local types = speciesTypeLockTypes(game, species)
          for _, typeId in ipairs(types or {}) do
              for index, knownType in pairs(TYPE_LOCK_TYPES) do
                  if knownType == typeId and not seen[index] then
                      seen[index] = true
                      out[#out + 1] = index
                      break
                  end
              end
          end
      end
      if #out == 0 then
          for index in pairs(TYPE_LOCK_TYPES) do out[#out + 1] = index end
      end
      table.sort(out)
      return out
  end

  local function randomTypeLockIndex(exclude, game)
      local pool = mod.exports.__beta26.typeLockViableIndices(game)
      local choices = {}
      for _, index in ipairs(pool) do
          if exclude == nil or index ~= exclude then choices[#choices + 1] = index end
      end
      if #choices == 0 then
          -- A provider could expose only one recognizable type. DUO still
          -- requires two distinct selections, so fall back to the remaining
          -- stable vocabulary only when the live pool has no second choice.
          for index in pairs(TYPE_LOCK_TYPES) do
              if exclude == nil or index ~= exclude then choices[#choices + 1] = index end
          end
          table.sort(choices)
      end
      local pick
      if love and love.math and love.math.random then
          pick = love.math.random(1, #choices)
      else
          pick = math.random(1, #choices)
      end
      return choices[pick]
  end

  -- RANDOM is a setup/UI request, never a runtime legality value. Resolve it
  -- once at the NEW GAME boundary (or immediately for an in-game edit) and
  -- persist the concrete type(s), so reloads cannot reroll a Type Locke.
  mod.exports.__beta26.resolveRandomTypeLockSelection = function(profile)
      if type(profile) ~= "table" then return profile end
      local slotKeys = mod.exports.__beta26.typeLockSlotKeys()
      local slotDefaults = mod.exports.__beta26.typeLockSlotDefaults()
      local mode = math.max(0, math.min(6, math.floor(tonumber(profile.type_lock_mode) or 0)))
      if mode <= 0 then
          for _, key in ipairs(slotKeys) do profile[key] = nil end
          return profile
      end
      if profile.type_lock_draft == true then
          for i = mode + 1, #slotKeys do profile[slotKeys[i]] = nil end
          return profile
      end
      local selected = {}
      for i = 1, mode do
          local key, fallback = slotKeys[i], slotDefaults[i]
          local value = math.floor(tonumber(profile[key]) or fallback)
          if value == TYPE_LOCK_RANDOM then
              local guard, duplicate = 0, false
              repeat
                  value = randomTypeLockIndex(nil, currentGameValue() or mod.game)
                  guard = guard + 1
                  duplicate = false
                  for _, prior in ipairs(selected) do if prior == value then duplicate = true; break end end
              until not duplicate or guard >= 64
          end
          value = mod.exports.__beta26.normalizeTypeLockIndex(value, fallback)
          local duplicate = false
          for _, prior in ipairs(selected) do if prior == value then duplicate = true; break end end
          if duplicate then
              local candidate, guard = value, 0
              repeat
                  candidate = mod.exports.__beta26.nextTypeLockConcreteIndex(candidate)
                  guard = guard + 1
                  duplicate = false
                  for _, prior in ipairs(selected) do if prior == candidate then duplicate = true; break end end
              until not duplicate or guard >= 19
              value = candidate
          end
          selected[#selected + 1] = value
          profile[key] = value
      end
      for i = mode + 1, #slotKeys do profile[slotKeys[i]] = nil end
      return profile
  end

  mod.exports.__beta26.typeLockModeLabel = function(mode)
      mode = math.max(0, math.min(6, math.floor(tonumber(mode) or 0)))
      return TYPE_LOCK_MODE_LABELS[mode] or "OFF"
  end
  mod.exports.__beta26.typeLockModeName = function(mode)
      mode = math.max(0, math.min(6, math.floor(tonumber(mode) or 0)))
      return TYPE_LOCK_MODE_NAMES[mode] or "Type Locke"
  end
  mod.exports.__beta26.typeLockMode = function()
      if mod.save:get("nuzlocke_enabled", true) == false then return 0 end
      return math.max(0, math.min(6, math.floor(tonumber(mod.save:get("type_lock_mode", 0)) or 0)))
  end
  mod.exports.__beta26.typeLockDraftActive = function()
      return mod.exports.__beta26.typeLockMode() > 0 and mod.save:get("type_lock_draft", false) == true
  end
  mod.exports.__beta26.typeLockDraftStatus = function()
      local mode, filled = mod.exports.__beta26.typeLockMode(), 0
      for i = 1, mode do
          local raw = mod.save:get(TYPE_LOCK_SLOT_KEYS[i], nil)
          if raw ~= nil and TYPE_LOCK_TYPES[math.floor(tonumber(raw) or -1)] ~= nil then filled = filled + 1 end
      end
      return filled, mode, mode > 0 and filled >= mode
  end
  mod.exports.__beta26.typeLockAllowedTypes = function()
      local mode = mod.exports.__beta26.typeLockMode()
      if mode <= 0 then return {} end
      local out = {}
      for i = 1, mode do
          local raw = mod.save:get(TYPE_LOCK_SLOT_KEYS[i], nil)
          if raw ~= nil then
              local index = mod.exports.__beta26.normalizeTypeLockIndex(raw, TYPE_LOCK_SLOT_DEFAULTS[i])
              local key = TYPE_LOCK_TYPES[index]
              if key then out[#out + 1] = key end
          end
      end
      return out
  end
  mod.exports.__beta26.recordTypeLockDraftCatch = function(game, mon, species)
      if not mod.exports.__beta26.typeLockDraftActive() then return false end
      local filled, mode, complete = mod.exports.__beta26.typeLockDraftStatus()
      if complete or filled >= mode then return false end
      local actual = type(mon) == "table" and pokemonTypeLockTypes(game, mon) or speciesTypeLockTypes(game, species)
      if type(actual) ~= "table" or #actual == 0 then return false end
      local already = {}
      for _, key in ipairs(mod.exports.__beta26.typeLockAllowedTypes()) do already[key] = true end
      local chosen = actual[1]
      for _, key in ipairs(actual) do if not already[key] then chosen = key; break end end
      local chosenIndex
      for index, key in pairs(TYPE_LOCK_TYPES) do if key == chosen then chosenIndex = index; break end end
      if chosenIndex == nil then return false end
      local slot = filled + 1
      mod.save:set(TYPE_LOCK_SLOT_KEYS[slot], chosenIndex)
      return true, slot, chosen, slot >= mode
  end

  local function typeLockAllowsTypes(actual)
      if mod.exports.__beta26.typeLockDraftActive() then
          local _, _, complete = mod.exports.__beta26.typeLockDraftStatus()
          if not complete then return true end
      end
      local allowed = mod.exports.__beta26.typeLockAllowedTypes()
      if #allowed == 0 then return true end
      if actual == nil then return true end
      local wanted = {}
      for _, key in ipairs(allowed) do wanted[key] = true end
      for _, key in ipairs(actual) do
          if wanted[key] then return true end
      end
      return false
  end

  mod.exports.__beta26.typeLockAllowsSpecies = function(game, species)
      return typeLockAllowsTypes(speciesTypeLockTypes(game, species))
  end

  mod.exports.__beta26.typeLockAllowsPokemon = function(game, mon)
      if type(mon) ~= "table" then
          return mod.exports.__beta26.typeLockAllowsSpecies(game, mon)
      end
      return typeLockAllowsTypes(pokemonTypeLockTypes(game, mon))
  end

  -- 2.9.25: Colorlocke / Alphabetlocke share one prospective-acquisition
  -- legality layer. They never invalidate existing party/box members or later
  -- evolutions. Canonical identity/metadata, not localized text or sprite pixels,
  -- owns classification.
  local COLORLOCKE_COLORS = { "BLACK", "BLUE", "BROWN", "GRAY", "GREEN", "PINK", "PURPLE", "RED", "WHITE", "YELLOW" }
  local COLORLOCKE_BY_ID = { [1]="BLACK", [2]="BLUE", [3]="BROWN", [4]="GRAY", [5]="GREEN", [6]="PINK", [7]="PURPLE", [8]="RED", [9]="WHITE", [10]="YELLOW" }
  -- 2.9.30: canonical Pokedex-search color ids for National Dex #001-#251.
  -- Source classification: PokeAPI/Veekun pokemon_species color_id. This is
  -- semantic species metadata; sprite palettes, shinies and presentation mods
  -- never affect Colorlocke legality.
  local COLORLOCKE_GEN12_BY_DEX = { 5, 5, 5, 8, 8, 8, 2, 2, 2, 5, 5, 9, 3, 10, 10, 3, 3, 3, 7, 3, 3, 3, 7, 7, 10, 10, 10, 10, 2, 2, 2, 7, 7, 7, 6, 6, 3, 10, 6, 6, 7, 7, 2, 2, 8, 8, 8, 7, 7, 3, 3, 10, 10, 10, 2, 3, 3, 3, 3, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 2, 2, 3, 3, 3, 10, 10, 6, 6, 4, 4, 3, 3, 3, 9, 9, 7, 7, 7, 7, 7, 7, 7, 4, 10, 10, 8, 8, 8, 8, 6, 10, 3, 3, 3, 3, 6, 7, 7, 4, 4, 6, 2, 3, 2, 2, 8, 8, 3, 7, 6, 5, 8, 10, 8, 3, 3, 8, 2, 2, 7, 3, 2, 10, 8, 6, 2, 2, 3, 3, 7, 1, 2, 10, 10, 2, 2, 3, 7, 6, 5, 5, 5, 10, 10, 10, 2, 2, 2, 3, 3, 3, 3, 8, 8, 5, 8, 7, 2, 2, 10, 6, 6, 9, 9, 5, 5, 9, 6, 10, 5, 2, 2, 3, 5, 6, 5, 2, 7, 10, 10, 8, 2, 2, 7, 1, 1, 6, 4, 1, 2, 10, 4, 7, 10, 7, 4, 6, 7, 4, 8, 10, 2, 1, 3, 3, 8, 8, 3, 3, 6, 4, 8, 8, 7, 4, 1, 1, 2, 2, 4, 8, 3, 9, 7, 3, 6, 10, 8, 6, 6, 10, 3, 2, 5, 4, 5, 9, 8, 5 }
  local function challengeHash(text)
      local h = 2166136261
      for i=1,#text do h = (h * 16777619 + text:byte(i)) % 4294967296 end
      return h
  end
  local function challengeSeed(game)
      local seed = type(mod.exports.__beta26.randomizerSeed) == "function" and mod.exports.__beta26.randomizerSeed(game) or nil
      if tonumber(seed) and tonumber(seed) > 0 then return tostring(math.floor(tonumber(seed))) end
      local save = game and game.save
      return tostring(save and (save.nuzlockeRunId or save.playerId or save.trainerId) or gameVersionValue() or "NUZLOCKE")
  end
  local function canonicalSpeciesKey(species)
      local raw = type(species)=="table" and (species.species or species.id or species.key or species.name) or species
      return tostring(raw or ""):upper():gsub("[^A-Z0-9]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  end
  mod.exports.__beta26.colorlockeColorLabel = function(index)
      return COLORLOCKE_COLORS[math.max(1,math.min(10,math.floor(tonumber(index) or 1)))] or "BLACK"
  end
  mod.exports.__beta26.alphabetlockeLetterLabel = function(index)
      return string.char(64 + math.max(1,math.min(26,math.floor(tonumber(index) or 1))))
  end
  local function speciesCanonicalColor(game, species)
      local def = speciesDefinition(game, canonicalSpeciesKey(species))
      local facts = type(mod.exports.__beta26.getSpeciesFacts)=="function" and mod.exports.__beta26.getSpeciesFacts(game, species) or nil
      local raw = type(facts)=="table" and (facts.color or facts.speciesColor or facts.pokedexColor) or nil
      if raw == nil and type(def)=="table" then raw = def.color or def.speciesColor or def.pokedexColor or def.colorId end
      if tonumber(raw) then return COLORLOCKE_BY_ID[math.floor(tonumber(raw))] end
      local key = tostring(raw or ""):upper():gsub("GREY","GRAY")
      for _,v in ipairs(COLORLOCKE_COLORS) do if key==v then return v end end
      -- Vanilla Gen-I/II registries do not carry the later Pokedex-search color
      -- field. Resolve canonical species by National Dex number before failing
      -- open for genuinely unknown/custom species.
      local dex = type(mod.exports.__beta26.nationalDexIndexForSpecies)=="function"
          and mod.exports.__beta26.nationalDexIndexForSpecies(game, species) or nil
      local colorId = dex and COLORLOCKE_GEN12_BY_DEX[dex] or nil
      return colorId and COLORLOCKE_BY_ID[colorId] or nil
  end
  -- Private diagnostic surface: lets Release Safety prove semantic viability,
  -- not merely that Colorlocke wiring strings exist.
  mod.exports.__beta26.speciesCanonicalColor = speciesCanonicalColor
  mod.exports.__beta26.colorlockeDataAudit = function(game)
      local failures = {}
      if #COLORLOCKE_GEN12_BY_DEX ~= 251 then
          failures[#failures+1] = "canonical_count=" .. tostring(#COLORLOCKE_GEN12_BY_DEX)
      end
      for i=1,251 do
          local value = COLORLOCKE_GEN12_BY_DEX[i]
          if type(value) ~= "number" or COLORLOCKE_BY_ID[value] == nil then
              failures[#failures+1] = "invalid_dex=" .. tostring(i)
              if #failures >= 16 then break end
          end
      end
      local expected = {
          BULBASAUR="GREEN", SQUIRTLE="BLUE", PIDGEY="BROWN", ONIX="GRAY",
          SNORLAX="BLACK", CLEFAIRY="PINK", EKANS="PURPLE", CHARMANDER="RED",
          SEEL="WHITE", PIKACHU="YELLOW",
      }
      if game then
          for species,wanted in pairs(expected) do
              local actual = speciesCanonicalColor(game, species)
              if actual ~= wanted then
                  failures[#failures+1] = species .. "=" .. tostring(actual)
              end
          end
      end
      return { ok=#failures==0, failures=failures, canonical_count=#COLORLOCKE_GEN12_BY_DEX }
  end
  local function representedInitials(game)
      local seen,out={},{}
      for species in pairs(game and game.data and game.data.pokemon or {}) do
          local c=canonicalSpeciesKey(species):match("^([A-Z])")
          if c and not seen[c] then seen[c]=true; out[#out+1]=c end
      end
      table.sort(out); return out
  end
  mod.exports.__beta26.colorlockeResolvedColor = function(game)
      local mode=math.max(0,math.min(2,math.floor(tonumber(mod.save:get("colorlocke_mode",0)) or 0)))
      if mode==0 then return nil end
      if mode==2 then return mod.exports.__beta26.colorlockeColorLabel(mod.save:get("colorlocke_color",1)) end
      return COLORLOCKE_COLORS[1 + (challengeHash(challengeSeed(game)..":colorlocke") % #COLORLOCKE_COLORS)]
  end
  mod.exports.__beta26.alphabetlockeResolvedLetter = function(game)
      local mode=math.max(0,math.min(2,math.floor(tonumber(mod.save:get("alphabetlocke_mode",0)) or 0)))
      if mode==0 then return nil end
      if mode==2 then return mod.exports.__beta26.alphabetlockeLetterLabel(mod.save:get("alphabetlocke_letter",1)) end
      local pool=representedInitials(game); if #pool==0 then return nil end
      return pool[1 + (challengeHash(challengeSeed(game)..":alphabetlocke") % #pool)]
  end
  mod.exports.__beta26.colorlockeAllowsSpecies = function(game,species)
      local wanted=mod.exports.__beta26.colorlockeResolvedColor(game); if not wanted then return true end
      local actual=speciesCanonicalColor(game,species); if not actual then return true end
      return actual==wanted
  end
  mod.exports.__beta26.alphabetlockeAllowsSpecies = function(game,species)
      local wanted=mod.exports.__beta26.alphabetlockeResolvedLetter(game); if not wanted then return true end
      local actual=canonicalSpeciesKey(species):match("^([A-Z])"); if not actual then return true end
      return actual==wanted
  end
  mod.exports.__beta26.challengeSpeciesAllows = function(game,species)
      if not mod.exports.__beta26.colorlockeAllowsSpecies(game,species) then return false,"colorlocke" end
      if not mod.exports.__beta26.alphabetlockeAllowsSpecies(game,species) then return false,"alphabetlocke" end
      return true
  end

  -- MissingNo and custom glitch species can arrive as names, raw numeric IDs,
  -- or partially malformed records. Classify without mutating/deleting them.
  -- A missing merged registry entry is considered glitch-shaped only when no
  -- active species-metadata provider recognizes it either.
  mod.exports.__beta26.getGlitchSpeciesInfo = function(game, species)
      local raw = species
      if type(raw) == "table" then
          raw = raw.species or raw.id or raw.key or raw.name
      end
      local rawType = type(raw)
      local text = (rawType == "string" or rawType == "number")
          and tostring(raw) or ""
      local key = text:upper():gsub("^%s+", ""):gsub("%s+$", "")
      local compact = key:gsub("[^A-Z0-9]", "")
      local registry = game and game.data and game.data.pokemon
      local registryAvailable = type(registry) == "table" and next(registry) ~= nil
      local def = key ~= "" and speciesDefinition(game, raw) or nil
      local meta = key ~= "" and providerSpeciesMetadata(game, raw) or nil
      local category = tostring((type(def) == "table"
          and (def.category or def.classification)) or (type(meta) == "table"
          and (meta.category or meta.classification)) or ""):lower()
      local flagged = (type(def) == "table" and (def.glitch == true
              or def.isGlitch == true or def.is_glitch == true))
          or (type(meta) == "table" and (meta.glitch == true
              or meta.isGlitch == true or meta.is_glitch == true))
          or category == "glitch"
      local missingNo = compact:find("MISSINGNO", 1, true) == 1
          or compact == "MISSINGNUMBER" or compact == "MISSINGNUM"
      local malformed = rawType ~= "string" and rawType ~= "number"
          or key == "" or (registryAvailable and def == nil and meta == nil)
      local isGlitch = flagged or missingNo or malformed
      local label
      if missingNo then
          label = "MISSINGNO"
      elseif isGlitch then
          label = key ~= "" and ("GLITCH " .. key):sub(1, 16) or "GLITCH"
      else
          label = key
      end
      return {
          isGlitch = isGlitch == true,
          missingNo = missingNo == true,
          malformed = malformed == true,
          key = key ~= "" and key or "GLITCH",
          label = label ~= "" and label or "GLITCH",
          raw = species,
          definition = def,
          metadata = meta,
      }
  end

  mod.exports.__beta26.safeSpeciesLabel = function(game, species)
      local info = mod.exports.__beta26.getGlitchSpeciesInfo(game, species)
      if info.isGlitch then return info.label end
      return info.key ~= "" and info.key or "???"
  end

  mod.exports.__beta26.glitchCatchesAllowed = function()
      return mod.save:get("nuzlocke_enabled", true) ~= false
          and mod.save:get("allow_glitch_pokemon", false) == true
  end

  -- Read BST from the live merged species registry first, with the optional
  -- species-metadata provider as a compatibility supplement. Gen 1 species
  -- have five base stats (SPECIAL counted once); Gen 2/custom schemas may
  -- expose split Special Attack and Special Defense, which are both counted.
  -- Unknown or incomplete schemas fail open instead of falsely banning a mon.
  mod.exports.__beta26.getSpeciesBST = function(game, species)
      if mod.exports.__beta26.getGlitchSpeciesInfo(game, species).isGlitch then
          return nil
      end
      local def = speciesDefinition(game, species)
      local meta = providerSpeciesMetadata(game, species)

      local function directBST(row)
          if type(row) ~= "table" then return nil end
          local value = tonumber(row.bst or row.baseStatTotal
              or row.base_stat_total or row.totalBaseStats)
          return value and value > 0 and math.floor(value) or nil
      end
      local direct = directBST(def) or directBST(meta)
      if direct then return direct end

      local function statTable(row)
          if type(row) ~= "table" then return nil end
          return row.baseStats or row.base_stats or row.stats
      end
      local stats = statTable(def) or statTable(meta)
      if type(stats) ~= "table" then return nil end

      -- Accept array-form registries as a conservative compatibility path:
      -- Gen 1 = HP/ATK/DEF/SPD/SPECIAL, Gen 2+ = six base stats.
      if #stats == 5 or #stats == 6 then
          local total = 0
          for i = 1, #stats do
              local value = tonumber(stats[i])
              if not value or value < 0 then return nil end
              total = total + value
          end
          return total > 0 and math.floor(total) or nil
      end

      local function pick(...)
          for i = 1, select("#", ...) do
              local key = select(i, ...)
              local value = tonumber(stats[key])
              if value ~= nil then return value end
          end
          return nil
      end
      local hp = pick("hp", "HP", "health")
      local attack = pick("attack", "atk", "ATTACK", "ATK")
      local defense = pick("defense", "defence", "def", "DEFENSE", "DEF")
      local speed = pick("speed", "spd", "SPEED", "SPD")
      if not (hp and attack and defense and speed) then return nil end

      local specialAttack = pick("specialAttack", "special_attack", "spAttack",
          "sp_attack", "spAtk", "sp_atk", "SPECIAL_ATTACK", "SP_ATTACK")
      local specialDefense = pick("specialDefense", "special_defense", "spDefense",
          "sp_defense", "spDef", "sp_def", "SPECIAL_DEFENSE", "SP_DEFENSE")
      local special = pick("special", "spc", "SPECIAL", "SPC")
      local total = hp + attack + defense + speed
      if specialAttack ~= nil or specialDefense ~= nil then
          if specialAttack == nil or specialDefense == nil then return nil end
          total = total + specialAttack + specialDefense
      elseif special ~= nil then
          total = total + special
      else
          return nil
      end
      return total > 0 and math.floor(total) or nil
  end

  mod.exports.__beta26.getMaximumBST = function()
      if mod.save:get("nuzlocke_enabled", true) == false then return 0 end
      return math.max(0, math.min(999,
          math.floor(tonumber(mod.save:get("maximum_bst", 0)) or 0)))
  end

  local function metadataHasFlag(meta, kind)
      if type(meta) ~= "table" then return false end
      if kind == "legendary" then
          if meta.isLegendary == true or meta.legendary == true or meta.is_legendary == true then return true end
      elseif kind == "mythical" then
          if meta.isMythical == true or meta.mythical == true or meta.is_mythical == true then return true end
      elseif kind == "pseudo" then
          if meta.isPseudoLegendary == true or meta.pseudoLegendary == true
              or meta.is_pseudo_legendary == true or meta.pseudo == true then return true end
      end
      local category = tostring(meta.category or meta.classification or meta.rarity or ""):lower()
      if category == kind then return true end

      -- Generic content editors and species-expansion mods often expose
      -- classification through tag/flag collections instead of dedicated
      -- booleans. Accept common table/array shapes but never infer a category
      -- from stats, dex number, name, or an unknown schema. Unknown species
      -- therefore continue to fail open for category bans.
      local function collectionHas(value)
          if type(value) == "string" then
              local text = value:lower():gsub("[%s_%-]+", "_")
              return text == kind or text == (kind .. "_pokemon")
                  or (kind == "pseudo" and (text == "pseudo_legendary"
                      or text == "pseudolegendary"))
          end
          if type(value) ~= "table" then return false end
          for k, v in pairs(value) do
              local candidate
              if type(k) == "string" and (v == true or v == 1) then
                  candidate = k
              elseif type(v) == "string" then
                  candidate = v
              end
              if candidate and collectionHas(candidate) then return true end
          end
          return false
      end
      return collectionHas(meta.tags) or collectionHas(meta.flags)
          or collectionHas(meta.traits) or collectionHas(meta.categories)
  end

  local function speciesHasFlag(game, species, kind)
      local def = speciesDefinition(game, species)
      if metadataHasFlag(def, kind) then return true end
      return metadataHasFlag(providerSpeciesMetadata(game, species), kind)
  end

  -- 2.4.34: one normalized read-only species-facts surface for challenge
  -- filters. It intentionally derives from the final merged registry plus
  -- provider metadata and fails open when a field is unknown. Existing
  -- specialized helpers remain compatibility aliases over the same sources.
  mod.exports.__beta26.getSpeciesFacts = function(game, species)
      local id = tostring(species or ""):upper()
      local def = speciesDefinition(game, species)
      local meta = providerSpeciesMetadata(game, species)
      local types = speciesTypeLockTypes(game, species)
      local evolutions = type(def) == "table" and def.evolutions or nil
      if type(evolutions) ~= "table" and type(meta) == "table" then
          evolutions = meta.evolutions or meta.evolution or meta.evolutionData or meta.evolution_data
      end
      local function firstNumber(...)
          for i = 1, select("#", ...) do
              local row = select(i, ...)
              if type(row) == "table" then
                  local value = tonumber(row.generation or row.gen
                      or row.introducedGeneration or row.introduced_generation)
                  if value then return math.max(1, math.floor(value)) end
              end
          end
      end
      local generation = firstNumber(def, meta)
      local bst = mod.exports.__beta26.getSpeciesBST(game, species)
      return {
          id = id,
          bst = bst,
          types = types,
          generation = generation,
          legendary = (type(legendarySetValue()) == "table" and legendarySetValue()[id] == true)
              or metadataHasFlag(def, "legendary") or metadataHasFlag(meta, "legendary"),
          mythical = (type(mythicalSetValue()) == "table" and mythicalSetValue()[id] == true)
              or metadataHasFlag(def, "mythical") or metadataHasFlag(meta, "mythical"),
          pseudo = (type(pseudoSetValue()) == "table" and pseudoSetValue()[id] == true)
              or metadataHasFlag(def, "pseudo") or metadataHasFlag(meta, "pseudo"),
          evolutions = type(evolutions) == "table" and evolutions or nil,
          metadata = {
              bst = bst ~= nil, types = types ~= nil, generation = generation ~= nil,
              legendary = metadataHasFlag(def, "legendary") or metadataHasFlag(meta, "legendary")
                  or (type(legendarySetValue()) == "table" and legendarySetValue()[id] == true),
              mythical = metadataHasFlag(def, "mythical") or metadataHasFlag(meta, "mythical")
                  or (type(mythicalSetValue()) == "table" and mythicalSetValue()[id] == true),
              pseudo = metadataHasFlag(def, "pseudo") or metadataHasFlag(meta, "pseudo")
                  or (type(pseudoSetValue()) == "table" and pseudoSetValue()[id] == true),
          },
          source = type(def) == "table" and "merged" or (type(meta) == "table" and "provider" or "unknown"),
      }
  end

  local function isLegendarySpecies(game, species)
      return mod.exports.__beta26.getSpeciesFacts(game, species).legendary == true
  end

  local function isMythicalSpecies(game, species)
      return mod.exports.__beta26.getSpeciesFacts(game, species).mythical == true
  end

  local function isPseudoSpecies(game, species)
      return mod.exports.__beta26.getSpeciesFacts(game, species).pseudo == true
  end

  return {
      speciesTypeLockTypes = speciesTypeLockTypes,
      pokemonTypeLockTypes = pokemonTypeLockTypes,
      isLegendarySpecies = isLegendarySpecies,
      isMythicalSpecies = isMythicalSpecies,
      isPseudoSpecies = isPseudoSpecies,
  }
end
