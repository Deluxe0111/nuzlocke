-- Gen 3 randomiser foundation: deterministic wild and trainer species.
-- Deliberately independent of Nuzlocke Enabled, unlike catch restrictions.
-- Each source namespace is isolated; no global RNG is consumed after AUTO seed resolution.
return function()
    local M = { api = 1, algorithm = 1 }
    local MAX_SEED, HASH_MOD = 99999999, 2147483647
    local definitions = {
        random_encounter_tables = { kind="boolean", default=false },
        random_trainers = { kind="boolean", default=false },
        randomizer_seed = { kind="number", default=0, min=0, max=MAX_SEED },
        random_encounter_balance = { kind="number", default=0, min=0, max=1 },
        random_trainer_balance = { kind="number", default=0, min=0, max=1 },
        random_species_generation = { kind="number", default=0, min=0, max=3 },
        randomizer_preset = { kind="number", default=0, min=0, max=2 },
    }
    local cachedPool, cachedOwner
    function M.clearCache() cachedPool, cachedOwner = nil, nil end
    local function state(s)
        if type(s.randomizer) ~= "table" then s.randomizer = {} end
        local r = s.randomizer
        for key, def in pairs(definitions) do
            local v = r[key]
            if type(v) ~= def.kind
                or (def.kind == "number" and (v ~= math.floor(v)
                    or v < def.min or v > def.max)) then
                r[key] = def.default
            end
        end
        return r
    end
    function M.get(s, key)
        if not definitions[key] then return nil end
        return state(s)[key]
    end
    function M.locked(s) return state(s).used == true end
    function M.set(s, key, value)
        local def = definitions[key]
        if not def then return false, "unsupported" end
        local r = state(s)
        if r.used then return false, "locked_after_first_randomised_result" end
        if type(value) ~= def.kind
            or (def.kind == "number" and (value ~= math.floor(value)
                or value < def.min or value > def.max)) then
            return false, "invalid_value"
        end
        if key == "randomizer_preset" then
            r.randomizer_preset = value
            if value ~= 0 then
                r.random_encounter_tables = true
                r.random_trainers = true
                r.random_encounter_balance = value == 2 and 1 or 0
                r.random_trainer_balance = value == 2 and 1 or 0
                r.random_species_generation = 0
            end
        else
            r[key] = value
            if key ~= "randomizer_seed" then r.randomizer_preset = 0 end
            if key == "randomizer_seed" then r.runSeed = nil end
        end
        return true
    end
    function M.hash(...)
        local h = 5381
        local args = {...}
        for i = 1, #args do
            local str = tostring(args[i])
            for j = 1, #str do
                h = (h * 33 + str:byte(j)) % HASH_MOD
            end
            h = (h * 33 + 124) % HASH_MOD
        end
        return h
    end
    function M.seed(s, entropy)
        local r = state(s)
        if r.randomizer_seed ~= 0 then return r.randomizer_seed end
        if type(r.runSeed) == "number" and r.runSeed >= 1
            and r.runSeed <= MAX_SEED then return r.runSeed end
        if not entropy then return 0 end
        local n = tonumber(entropy()) or 0
        r.runSeed = 1 + math.floor(math.abs(n)) % MAX_SEED
        return r.runSeed
    end
    local function eligiblePokemon(Pokemon, sp)
        local ok1, nat = pcall(Pokemon.national, sp)
        if not ok1 or type(nat) ~= "number" or nat < 1 or nat > 386 then
            return nil
        end
        local ok2, stats = pcall(Pokemon.stats, sp)
        local ok3, key = pcall(Pokemon.keyName, sp)
        if not ok2 or not ok3 or type(stats) ~= "table"
            or type(key) ~= "string" or key == "" then return nil end
        -- Game3's Pokemon.stats is a NAMED stat object, not the Gen1/2
        -- numeric array. Support both for safe registry adapters.
        local keys = {"hp", "atk", "def", "spe", "spa", "spd"}
        local bst = 0
        for i, name in ipairs(keys) do
            local value = tonumber(stats[name] or stats[i]) or 0
            if value <= 0 then return nil end
            bst = bst + value
        end
        return { id = sp, national = nat, bst = bst, key = key }
    end
    function M.pool(Pokemon)
        if Pokemon == cachedOwner and cachedPool then return cachedPool end
        if type(Pokemon) ~= "table"
            or type(Pokemon.national) ~= "function"
            or type(Pokemon.stats) ~= "function"
            or type(Pokemon.keyName) ~= "function" then return {} end
        local pool = {}
        for sp = 1, 512 do
            local entry = eligiblePokemon(Pokemon, sp)
            if entry then pool[#pool + 1] = entry end
        end
        -- If species assets weren't available yet, retry the next time.
        if #pool > 0 then cachedPool, cachedOwner = pool, Pokemon end
        return pool
    end
    local function generation(n)
        if n >= 1 and n <= 151 then return 1 end
        if n >= 152 and n <= 251 then return 2 end
        if n >= 252 and n <= 386 then return 3 end
        return nil
    end
    local function candidates(Pokemon, original, poolMode, balance)
        local all = M.pool(Pokemon)
        local originalId = tonumber(original)
        if not originalId and type(original) == "string"
            and type(Pokemon.speciesFromName) == "function" then
            local ok, value = pcall(Pokemon.speciesFromName, original)
            if ok then originalId = tonumber(value) end
        end
        if not originalId then return nil end
        local base = eligiblePokemon(Pokemon, originalId)
        if not base then return nil end
        local pool = {}
        for _, item in ipairs(all) do
            if item.id ~= originalId
                and (poolMode == 0 or generation(item.national) == poolMode) then
                pool[#pool + 1] = item
            end
        end
        if #pool == 0 then return nil end
        if balance == 1 then
            for _, tolerance in ipairs({0.15, 0.25, 0.40}) do
                local near = {}
                for _, item in ipairs(pool) do
                    if math.abs(item.bst - base.bst) <= base.bst * tolerance then
                        near[#near + 1] = item
                    end
                end
                if #near > 0 then return near end
            end
        end
        return pool
    end
    function M.replace(s, Pokemon, source, sourceId, original, entropy)
        local r = state(s)
        local enabled = source == "ENCOUNTERS" and r.random_encounter_tables
            or source == "TRAINERS" and r.random_trainers
        if not enabled or type(sourceId) ~= "string" or sourceId == ""
            or type(Pokemon) ~= "table" then return nil end
        local balance = source == "ENCOUNTERS"
            and r.random_encounter_balance or r.random_trainer_balance
        local legal = candidates(Pokemon, original,
            r.random_species_generation, balance)
        if not legal or #legal == 0 then return nil end
        local seed = M.seed(s, entropy)
        if seed == 0 then return nil end
        local index = 1 + M.hash(M.algorithm, seed, source, sourceId) % #legal
        local new = legal[index]
        r.used = true
        return new.id, new.key
    end
    return M
end
