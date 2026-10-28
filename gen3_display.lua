-- Human-facing Gen 3 labels for graveyard, encounter tracker and status.
-- Keep canonical raw IDs in saves for rules and debug diagnostics. Prefer
-- ROM-backed names, with deterministic fallbacks when cache isn't ready.
return function()
    local M = { api = 1 }

    local function nonblank(value)
        return type(value) == "string" and value:match("%S") ~= nil
    end

    local function nativePokemon()
        local ok, p = pcall(require, "src.core.game3.pokemon")
        return ok and type(p) == "table" and p or nil
    end

    local function formatProper(value)
        if not nonblank(value) then return nil end
        return (value:gsub("(%a[%a']*)", function(word)
            return word:sub(1, 1):upper() .. word:sub(2):lower()
        end))
    end

    local function displayCase(value)
        if nonblank(value) and value == value:upper() then
            return formatProper(value) or value
        end
        return value
    end

    local function safeNativeName(Pokemon, mon)
        if not Pokemon then return nil end
        if type(Pokemon.speciesOf) == "function"
            and type(Pokemon.name) == "function" then
            local okId, number = pcall(Pokemon.speciesOf, mon)
            if okId and number then
                local okName, name = pcall(Pokemon.name, number)
                if okName and nonblank(name) and name ~= "?????" then
                    return displayCase(name)
                end
            end
        end
        -- Old graveyard rows may contain a bare internal species integer.
        if type(Pokemon.name) == "function" then
            local ok, name = pcall(Pokemon.name,
                mon.species or mon.speciesId)
            if ok and nonblank(name) and name ~= "?????" then
                return displayCase(name)
            end
        end
        return nil
    end

    function M.speciesName(mon)
        if type(mon) ~= "table" then return "Unknown Pokémon" end
        local stored = mon.speciesName
        if nonblank(stored) then return displayCase(stored) end
        local raw = mon.species or mon.speciesId
        local fromEngine = safeNativeName(nativePokemon(), mon)
        if fromEngine then return fromEngine end
        if type(raw) == "string" and nonblank(raw)
            and not tonumber(raw) then
            return formatProper(raw:gsub("_", " ")) or raw
        end
        if raw ~= nil then return "Pokémon #" .. tostring(raw) end
        return "Unknown Pokémon"
    end

    function M.pokemonName(mon)
        if type(mon) ~= "table" then return "Unknown Pokémon" end
        if nonblank(mon.nickname) then return mon.nickname end
        if nonblank(mon.name) then return mon.name end
        return M.speciesName(mon)
    end

    -- Display only: does not merge two maps into one encounter area.
    function M.areaName(mapId)
        if not nonblank(mapId) then return "Unknown location" end
        local ok, Sections = pcall(require, "src.import.gba.map_sections_extract")
        if ok and type(Sections) == "table"
            and type(Sections.getInfo) == "function" then
            local worked, info = pcall(Sections.getInfo, nil, mapId, 0)
            if worked and type(info) == "table"
                and info.resolved == true then
                local native = info.rawName or info.name
                if nonblank(native) and native ~= "???" then
                    return formatProper(native) or native
                end
            end
        end

        -- When a ROM's map section cache is unavailable, prefer readable
        -- map identifiers to misleading placeholders like Pallet Town.
        local name = mapId:gsub("^FR_", ""):gsub("^SEVII_", "")
        name = name:gsub("^RS_", ""):gsub("^RSE_", "")
        name = name:gsub("^EM_", ""):gsub("^EMERALD_", "")
        name = name:gsub("_", " "):gsub("(%a)(%d)", "%1 %2")
        name = name:gsub("(%d)(%a)", "%1 %2")
        name = name:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return formatProper(name) or mapId
    end

    -- Serialize display hints for future localisation/cache failures, but use
    -- the raw area/species as the authoritative identifiers. Older records
    -- with only {species, level, area} remain readable.
    function M.memorial(mon, mapId, cause)
        mon = type(mon) == "table" and mon or {}
        local nick = nonblank(mon.nickname) and mon.nickname or nil
        return {
            species = mon.species or mon.speciesId,
            speciesNumbering = mon.speciesNumbering,
            speciesName = M.speciesName(mon),
            nickname = nick,
            name = M.pokemonName(mon),
            level = mon.level,
            area = mapId,
            areaName = M.areaName(mapId),
            cause = cause,
        }
    end

    -- Identity is resolved at display time because the native nickname prompt
    -- can run AFTER pokemon.caught. Never substitute today's level for the
    -- level stored at capture, and never guess details for old save rows.
    function M.trackerCatch(entry, native, graveyard)
        if type(entry) ~= "table" or entry.caught ~= true then return nil end
        local speciesId = entry.caughtSpeciesId
        local personality = entry.caughtPersonality
        local owner = entry.caughtTrainerId
        local function matches(mon)
            return type(mon) == "table" and personality ~= nil
                and mon.personality == personality
                and tostring(mon.species or mon.speciesId or "")
                    == tostring(speciesId or "")
                and (owner == nil or tostring(mon.otId or mon.trainerId or "")
                    == tostring(owner))
        end
        local found
        if type(native) == "table" then
            for _, mon in ipairs(native.party or {}) do
                if matches(mon) then found = mon; break end
            end
            if not found then
                for _, box in ipairs(native.storage and native.storage.boxes or {}) do
                    for slot = 1, 30 do
                        local mon = box and box.mons and box.mons[slot]
                        if matches(mon) then found = mon; break end
                    end
                    if found then break end
                end
            end
        end
        if not found then
            for _, death in ipairs(graveyard or {}) do
                if type(death) == "table" and matches(death.archive) then
                    found = death
                    break
                end
            end
        end
        local species = (found and M.speciesName(found))
            or (nonblank(entry.caughtSpeciesName)
                and displayCase(entry.caughtSpeciesName))
            or (speciesId ~= nil
                and M.speciesName({species = speciesId}))
            or "Unknown Pokémon"
        local nickname = found and found.nickname or entry.caughtNickname
        if not nonblank(nickname) then nickname = nil end
        return {
            name = nickname or species,
            species = species,
            level = tonumber(entry.caughtLevel),
            known = speciesId ~= nil,
        }
    end

    return M
end
