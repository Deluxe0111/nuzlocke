-- Seeded, non-destructive Gen 3 Randomizer. Phase 1: wild and trainers.
-- Separate deterministic source hashes mean traversal order never changes rolls.
return function()
    local M = { api = 1, version = 1 }
    local MAX_SEED = 99999999
    local MOD = 2147483647
    local function config(s)
        if type(s.randomizer) ~= "table" then s.randomizer = {} end
        local r = s.randomizer
        if type(r.seed) ~= "number" or r.seed < 0 or r.seed > MAX_SEED then r.seed = 0 end
        if type(r.wild) ~= "boolean" then r.wild = false end
        if type(r.trainers) ~= "boolean" then r.trainers = false end
        return r
    end
    function M.get(s) return config(s) end
    function M.set(s, key, value)
        if key ~= "seed" and key ~= "wild" and key ~= "trainers" then
            return false, "unsupported_randomizer_setting"
        end
        if s.failed then return false, "run_failed" end
        local r = config(s)
        if key == "seed" then
            if type(value) ~= "number" or value % 1 ~= 0
                or value < 0 or value > MAX_SEED then return false, "invalid_seed" end
        elseif type(value) ~= "boolean" then return false, "boolean_required" end
        r[key] = value
        return true
    end
    -- Lua 5.1 number arithmetic, no bit operations and no global RNG changes.
    local function hash(seed, namespace, identity)
        local n = (tonumber(seed) or 0) % MOD
        local text = tostring(namespace) .. "|" .. tostring(identity)
        for i = 1, #text do
            n = (n * 127 + text:byte(i)) % MOD
        end
        return n
    end
    M.hash = hash
    function M.choose(seed, stream, identity, pool)
        if type(pool) ~= "table" or #pool == 0 then return nil end
        return pool[(hash(seed, stream, identity) % #pool) + 1]
    end
    function M.pool(Pokemon)
        if type(Pokemon) ~= "table" or type(Pokemon.keyName) ~= "function" then
            return nil
        end
        local result = {}
        -- Gen 3 native species 1..386 include version-specific reserved slots.
        -- Validate each through the merged registry; exclude special eggs/forms.
        for id = 1, 386 do
            local ok, key = pcall(Pokemon.keyName, id)
            if ok and type(key) == "string" and key ~= ""
                and key ~= "EGG" and key ~= "NONE"
                and key:find("UNOWN") ~= 1
                and not key:find("BAD_EGG", 1, true) then
                result[#result + 1] = { id = id, name = key }
            end
        end
        return #result > 0 and result or nil
    end
    local function safeSpecies(Pokemon, ref)
        if type(Pokemon) ~= "table"
            or type(Pokemon.keyName) ~= "function" then return false end
        local id = tonumber(ref)
        if not id and type(ref) == "string"
            and type(Pokemon.speciesFromName) == "function" then
            local converted, resolved = pcall(Pokemon.speciesFromName, ref)
            if converted then id = tonumber(resolved) end
        end
        if not id then return false end
        local ok, name = pcall(Pokemon.keyName, id)
        return ok and type(name) == "string" and name ~= ""
    end
    local function selectSpecies(r, stream, identity, Pokemon)
        local pool = M.pool(Pokemon)
        local selected = M.choose(r.seed, stream, identity, pool)
        return selected and selected.id, selected and selected.name
    end
    function M.wild(s, encounter, ctx, Pokemon)
        local r = config(s)
        if not r.wild or r.seed == 0 or type(encounter) ~= "table"
            or encounter.roamer or encounter.legendary
            or encounter.wildScripted or encounter.scripted
            or not safeSpecies(Pokemon, encounter.speciesId or encounter.species)
            or type(ctx) ~= "table" then return encounter end
        local map = ctx.mapId
        if map == nil then return encounter end
        -- Fixed per-map / terrain / native species / level. Repeated encounters
        -- map consistently. Leaves level, method, held item, and other fields.
        local identity = table.concat({
            tostring(map), tostring(ctx.terrain), tostring(encounter.speciesId or encounter.species),
            tostring(encounter.level)
        }, ":")
        local id, name = selectSpecies(r, "WILD", identity, Pokemon)
        if not id then return encounter end
        local copy = {}
        for k,v in pairs(encounter) do copy[k]=v end
        copy.speciesId = id
        copy.species = name
        return copy
    end
    function M.trainers(s, party, trainerId, Pokemon)
        local r = config(s)
        if not r.trainers or r.seed == 0
            or tonumber(trainerId) == nil or type(party) ~= "table"
            or #party == 0 then return party end
        local out = {}
        for i, member in ipairs(party) do
            if type(member) ~= "table"
                or not safeSpecies(Pokemon, member.species) then
                out[i] = member
            else
                local id, name = selectSpecies(r, "TRAINER",
                    tostring(trainerId) .. ":" .. tostring(i), Pokemon)
                if name then
                    local copy={}
                    for k,v in pairs(member) do copy[k]=v end
                    copy.species = name
                    copy.speciesId = id
                    -- Native trainer construction recalculates default moves
                    -- when authored move data is absent; do not invent moves.
                    out[i]=copy
                else out[i]=member end
            end
        end
        return out
    end
    return M
end
