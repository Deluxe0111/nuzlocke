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

    local function safeNativeName(Pokemon, mon)
        if not Pokemon then return nil end
        if type(Pokemon.speciesOf) == "function"
            and type(Pokemon.name) == "function" then
            local okId, number = pcall(Pokemon.speciesOf, mon)
            if okId and number then
                local okName, name = pcall(Pokemon.name, number)
                if okName and nonblank(name) and name ~= "?????" then
                    return name
                end
            end
        end
        -- Old graveyard rows may contain a bare internal species integer.
        if type(Pokemon.name) == "function" then
            local ok, name = pcall(Pokemon.name,
                mon.species or mon.speciesId)
            if ok and nonblank(name) and name ~= "?????" then return name end
        end
        return nil
    end

    function M.speciesName(mon)
        if type(mon) ~= "table" then return "Unknown Pokémon" end
        local stored = mon.speciesName
        if nonblank(stored) then return stored end
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

    return M
end
