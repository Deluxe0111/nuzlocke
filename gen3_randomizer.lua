-- Gen 3 randomiser foundation: deterministic wild and trainer species.
-- Deliberately independent of Nuzlocke Enabled, unlike catch restrictions.
-- Each source namespace is isolated; no global RNG is consumed after AUTO seed resolution.
return function()
    local M = { api = 1, algorithm = 1 }
    local MAX_SEED, HASH_MOD = 99999999, 2147483647
    local definitions = {
        random_encounter_tables = { kind="boolean", default=false },
        random_trainers = { kind="boolean", default=false },
        random_starter = { kind="boolean", default=false },
        random_starter_balance = { kind="number", default=0, min=0, max=1 },
        -- Script-created wild and player gifts are distinct from wild
        -- encounters, general trainers and starter selection.
        random_static_pokemon = { kind="boolean", default=false },
        random_static_balance = { kind="number", default=0, min=0, max=1 },
        random_gift_pokemon = { kind="boolean", default=false },
        random_egg_gifts = { kind="boolean", default=false },
        random_gift_balance = { kind="number", default=0, min=0, max=1 },
        random_field_items = { kind="boolean", default=false },
        random_field_item_balance = { kind="number", default=0, min=0, max=1 },
        random_field_item_repetition = { kind="number", default=0, min=0, max=1 },
        randomizer_seed = { kind="number", default=0, min=0, max=MAX_SEED },
        random_encounter_balance = { kind="number", default=0, min=0, max=1 },
        -- Preserve a distinct replacement per native wild source within
        -- each map/method. Defaults OFF so all existing mappings survive.
        random_encounter_repetition = { kind="number", default=0, min=0, max=1 },
        random_trainer_balance = { kind="number", default=0, min=0, max=1 },
        random_species_generation = { kind="number", default=0, min=0, max=3 },
        random_trainer_diversity = { kind="number", default=0, min=0, max=1 },
        randomizer_preset = { kind="number", default=0, min=0, max=2 },
    }
    local cachedPool, cachedOwner
    local cachedItemPool, cachedItemPack, cachedItemOwner
    function M.clearCache()
        cachedPool, cachedOwner = nil, nil
        cachedItemPool, cachedItemPack, cachedItemOwner = nil, nil, nil
    end
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
        if type(s) == "table" and s.runSettingsLocked == true and s._setup ~= true then
            return false, "run_settings_locked"
        end
        local def = definitions[key]
        if not def then return false, "unsupported" end
        local r = state(s)
        if r.used then return false, "locked_after_first_randomised_result" end
        if type(value) ~= def.kind
            or (def.kind == "number" and (value ~= math.floor(value)
                or value < def.min or value > def.max)) then
            return false, "invalid_value"
        end
        -- Before the first generated result there are no authoritative
        -- assignments. Changing setup options must not retain stale slots.
        r.encounterAssignments = nil
        r.fieldItemAssignments = nil
        r.starterOptions = nil
        r.starterSource = nil
        if key == "randomizer_preset" then
            r.randomizer_preset = value
            if value ~= 0 then
                r.random_encounter_tables = true
                r.random_trainers = true
                r.random_encounter_balance = value == 2 and 1 or 0
                r.random_encounter_repetition = 0
                r.random_trainer_balance = value == 2 and 1 or 0
                r.random_species_generation = 0
                r.random_trainer_diversity = 0
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
    local function candidates(Pokemon, original, poolMode, balance, denyNational, excluded)
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
                and (poolMode == 0 or generation(item.national) == poolMode)
                and not (denyNational and denyNational(item.national))
                and not (excluded and excluded[item.id]) then
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
    -- Roll three distinct starter choices as a single transaction. Native
    -- ROM starter indices remain untouched, preserving story/rival variables.
    -- The result is saved and shared by the chooser, gift and first rival.
    function M.starters(s, Pokemon, source, originals, entropy, denyNational)
        local r = state(s)
        if not r.random_starter or type(source) ~= "string"
            or (source ~= "frlg" and source ~= "rse")
            or type(originals) ~= "table" or #originals ~= 3 then
            return nil
        end
        if type(r.starterOptions) == "table" then
            if r.starterSource ~= source or #r.starterOptions ~= 3 then
                return nil
            end
            local choices = {}
            for i = 1, 3 do
                local id = tonumber(r.starterOptions[i])
                if not id or not eligiblePokemon(Pokemon, id) then return nil end
                choices[i] = id
            end
            return choices
        end
        local chosen, used = {}, {}
        local seed = M.seed(s, entropy)
        if seed == 0 then return nil end
        for i = 1, 3 do
            local original = originals[i]
            -- No partial trio: a missing legal choice leaves all three
            -- native rather than displaying a replacement we cannot give.
            local legal = candidates(Pokemon, original,
                r.random_species_generation, r.random_starter_balance,
                denyNational, used)
            if not legal or #legal == 0 then return nil end
            local index = 1 + M.hash(M.algorithm, seed, "STARTERS",
                source, i, original) % #legal
            chosen[i] = legal[index].id
            used[chosen[i]] = true
        end
        r.starterOptions = chosen
        r.starterSource = source
        r.used = true
        return { chosen[1], chosen[2], chosen[3] }
    end

    -- Read the actual ROM evolution graph. Do not infer an evolution by
    -- adding 1 or 2 to the internal species ID: Gen 3 has holes/forms and
    -- branched evolution lines, particularly across FRLG and RSE.
    local function evolutionTargets(Pokemon, species, poolMode, denyNational)
        if type(Pokemon.evolutions) ~= "function" then return {} end
        local ok, evolutions = pcall(Pokemon.evolutions, species)
        if not ok or type(evolutions) ~= "table" then return {} end
        local out, seen = {}, {}
        for _, row in ipairs(evolutions) do
            if type(row) == "table" then
                local id = tonumber(row.target or row[3])
                if id and id == math.floor(id) and id > 0
                    and not seen[id] then
                    local entry = eligiblePokemon(Pokemon, id)
                    if entry and (not poolMode or poolMode == 0
                        or generation(entry.national) == poolMode)
                        and not (denyNational
                            and denyNational(entry.national)) then
                        seen[id] = true
                        out[#out + 1] = id
                    end
                end
            end
        end
        table.sort(out)
        return out
    end
    local function nativeStage(Pokemon, original, encountered)
        if original == encountered then return 0 end
        -- Original FRLG/RSE starter lines have at most two evolutions.
        -- Never traverse farther: a rogue ROM cyclic graph must not loop.
        for _, first in ipairs(evolutionTargets(Pokemon, original)) do
            if first == encountered then return 1 end
            for _, second in ipairs(evolutionTargets(Pokemon, first)) do
                if second == encountered then return 2 end
            end
        end
        return nil
    end

    -- Substitute only the native rival's ORIGINAL starter lineage.
    -- The rival ID whitelist lives at the runtime trainer.party boundary.
    -- Preserve the other trainers/teammates and native party progression.
    function M.rivalStarter(s, Pokemon, source, originals, nativeSpecies,
        denyNational)
        local r = state(s)
        if not r.random_starter or r.starterSource ~= source
            or type(r.starterOptions) ~= "table"
            or #r.starterOptions ~= 3 or type(originals) ~= "table"
            or #originals ~= 3 or type(Pokemon) ~= "table" then return nil end
        local id = tonumber(nativeSpecies)
        if not id and type(nativeSpecies) == "string"
            and type(Pokemon.speciesFromName) == "function" then
            local ok, numeric = pcall(Pokemon.speciesFromName, nativeSpecies)
            if ok then id = tonumber(numeric) end
        end
        if not id then return nil end
        for i, base in ipairs(originals) do
            local root = tonumber(base)
            if root then
                local stage = nativeStage(Pokemon, root, id)
                if stage ~= nil then
                    local replacement = tonumber(r.starterOptions[i])
                    if not replacement
                        or not eligiblePokemon(Pokemon, replacement) then
                        return nil
                    end
                    -- A single-stage Pokémon stays itself. Branched
                    -- evolutions choose a repeatable path using the saved
                    -- run seed rather than world encounter RNG.
                    local seed = M.seed(s)
                    for depth = 1, stage do
                        local targets = evolutionTargets(Pokemon, replacement,
                            r.random_species_generation, denyNational)
                        if #targets == 0 then break end
                        local pick = seed ~= 0 and
                            (1 + M.hash(M.algorithm, seed, "RIVAL_LINEAGE",
                                source, i, depth, replacement) % #targets) or 1
                        replacement = targets[pick]
                    end
                    local info = eligiblePokemon(Pokemon, replacement)
                    return info and info.id or nil,
                        info and info.key or nil, i, stage
                end
            end
        end
        return nil
    end

    -- Only native, buyable consumables/balls/berries enter the item pool.
    -- Key items, TM/HMs, unique story objects, zero-price special items,
    -- missing pack entries and placeholder/glitch IDs cannot be rewritten.
    local function itemEntry(ItemsData, id)
        if type(id) ~= "number" or id ~= math.floor(id)
            or id < 1 or id >= 0x4000
            or (id >= 289 and id <= 346) then return nil end
        if type(ItemsData) ~= "table"
            or type(ItemsData.info) ~= "function" then return nil end
        local ok, meta = pcall(ItemsData.info, id)
        if not ok or type(meta) ~= "table" then return nil end
        local pocket = tostring(meta.pocket or ""):upper()
        if pocket ~= "ITEMS" and pocket ~= "POKE_BALLS"
            and pocket ~= "BERRIES" and pocket ~= "BERRY_POUCH" then
            return nil
        end
        local importance = meta.importance
        if importance == true or (tonumber(importance) or 0) ~= 0 then
            return nil
        end
        local price = tonumber(meta.price) or 0
        local name = meta.name
        if price <= 0 or price > 1000000
            or type(name) ~= "string" or name == ""
            or name:find("?",1,true) then return nil end
        return {id=id, price=price, name=name}
    end
    function M.itemPool(ItemsData)
        if type(ItemsData) ~= "table"
            or type(ItemsData.ensureLoaded) ~= "function" then return {} end
        local ok, pack = pcall(ItemsData.ensureLoaded)
        if not ok or type(pack) ~= "table" then return {} end
        if ItemsData == cachedItemOwner and pack == cachedItemPack
            and cachedItemPool then return cachedItemPool end
        local pool = {}
        for id in pairs(pack) do
            local entry = itemEntry(ItemsData, id)
            if entry then pool[#pool + 1] = entry end
        end
        table.sort(pool, function(a,b) return a.id < b.id end)
        cachedItemPool,cachedItemPack,cachedItemOwner =
            pool,pack,ItemsData
        return pool
    end
    local function itemCandidates(pool, original, balance, taken)
        local valid = {}
        for _,item in ipairs(pool) do
            if item.id ~= original.id
                and not (taken and taken[item.id]) then
                valid[#valid + 1] = item
            end
        end
        if balance == 1 and #valid > 0 then
            -- Match the shop value approximately, but widen rather than
            -- risk a failed lookup when an uncommon price has no peers.
            for _, tolerance in ipairs({0.25,0.50,1.00}) do
                local close = {}
                for _,item in ipairs(valid) do
                    if math.abs(item.price-original.price)
                        <= math.max(100,original.price*tolerance) then
                        close[#close+1] = item
                    end
                end
                if #close>0 then return close end
            end
        end
        return valid
    end
    -- Pickup identity is map + native event script/hidden flag, never a
    -- transient BAG operation or a changing world RNG stream.
    function M.item(s, ItemsData, sourceId, original, entropy, scope)
        local r=state(s)
        if not r.random_field_items
            or type(sourceId)~="string" or sourceId==""
            or type(scope)~="string" or scope=="" then return nil end
        local originalId=tonumber(original)
        local orig=itemEntry(ItemsData,originalId)
        if not orig then return nil end
        local pool=M.itemPool(ItemsData)
        if #pool<2 then return nil end
        local candidate=itemCandidates(pool,orig,r.random_field_item_balance)
        if #candidate==0 then return nil end
        local assignments=type(r.fieldItemAssignments)=="table"
            and r.fieldItemAssignments[scope] or nil
        if type(assignments)~="table" then assignments=nil end
        local prior=assignments and assignments[sourceId]
        if prior~=nil then
            for _,entry in ipairs(candidate) do
                if entry.id==prior then
                    r.used=true
                    return entry.id
                end
            end
            return nil -- ROM/pack changes: preserve native pickup.
        end
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        if r.random_field_item_repetition==1 then
            local used={}
            for _,id in pairs(assignments or {}) do
                if type(id)=="number" then used[id]=true end
            end
            local fresh=itemCandidates(pool,orig,
                r.random_field_item_balance,used)
            if #fresh>0 then candidate=fresh end
        end
        local chosen=candidate[1+M.hash(M.algorithm,seed,
            "FIELD_ITEMS",sourceId,originalId)%#candidate]
        if type(r.fieldItemAssignments)~="table" then
            r.fieldItemAssignments={}
        end
        if type(r.fieldItemAssignments[scope])~="table" then
            r.fieldItemAssignments[scope]={}
        end
        r.fieldItemAssignments[scope][sourceId]=chosen.id
        r.used=true
        return chosen.id
    end

    function M.replace(s, Pokemon, source, sourceId, original, entropy,
        denyNational, excluded, wildScope, wildSlot)
        local r = state(s)
        local enabled = source == "ENCOUNTERS" and r.random_encounter_tables
            or source == "TRAINERS" and r.random_trainers
            or source == "STATIC" and r.random_static_pokemon
            or source == "GIFTS" and r.random_gift_pokemon
            or source == "EGG_GIFTS" and r.random_egg_gifts
        if not enabled or type(sourceId) ~= "string" or sourceId == ""
            or type(Pokemon) ~= "table" then return nil end
        local balance = source == "ENCOUNTERS"
            and r.random_encounter_balance
            or source == "STATIC" and r.random_static_balance
            or (source == "GIFTS" or source == "EGG_GIFTS")
                and r.random_gift_balance
            or r.random_trainer_balance
        local legal = candidates(Pokemon, original,
            r.random_species_generation, balance,denyNational,excluded)
        if not legal or #legal == 0 then return nil end
        local seed = M.seed(s, entropy)
        if seed == 0 then return nil end
        -- Encounter Variety is opt-in. Map/method is the scope, while the
        -- ORIGINAL species is the stable slot: different native levels
        -- must not allocate a different identity for the same species.
        local unique = source == "ENCOUNTERS"
            and r.random_encounter_repetition == 1
            and type(wildScope) == "string" and wildScope ~= ""
            and type(wildSlot) == "string" and wildSlot ~= ""
        local scopeAssignments = unique
            and type(r.encounterAssignments) == "table"
            and r.encounterAssignments[wildScope] or nil
        if type(scopeAssignments) ~= "table" then scopeAssignments = nil end
        if scopeAssignments and scopeAssignments[wildSlot] ~= nil then
            local prior = scopeAssignments[wildSlot]
            -- If ROM data or candidate bans have changed, fail open
            -- rather than silently assigning a new species to an old slot.
            for _, candidate in ipairs(legal) do
                if candidate.id == prior then
                    r.used = true
                    return candidate.id, candidate.key
                end
            end
            return nil
        end
        if unique then
            local taken = {}
            for _, id in pairs(scopeAssignments or {}) do
                if type(id) == "number" then taken[id] = true end
            end
            if type(excluded) == "table" then
                for id, blocked in pairs(excluded) do
                    if blocked then taken[id] = true end
                end
            end
            -- Prioritise unused replacements, then apply SIM BST to the
            -- remaining legal choices. If exhausted, reuse the native
            -- candidate pool, never an invalid/glitch species.
            local fresh = candidates(Pokemon, original,
                r.random_species_generation, balance, denyNational, taken)
            if fresh and #fresh > 0 then legal = fresh end
        end
        local identity = unique and
            ("WILD VARIETY:" .. wildScope .. ":" .. wildSlot) or sourceId
        local index = 1 + M.hash(M.algorithm, seed, source, identity) % #legal
        local new = legal[index]
        if unique then
            if type(r.encounterAssignments) ~= "table" then
                r.encounterAssignments = {}
            end
            if type(r.encounterAssignments[wildScope]) ~= "table" then
                r.encounterAssignments[wildScope] = {}
            end
            r.encounterAssignments[wildScope][wildSlot] = new.id
        end
        r.used = true
        return new.id, new.key
    end
    return M
end
