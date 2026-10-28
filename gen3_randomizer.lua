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
        random_starter_style = { kind="number", default=0, min=0, max=2 },
        random_starter_trio_typing = { kind="number", default=0, min=0, max=1 },
        random_starter_rerolls = { kind="number", default=0, min=0, max=2 },
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
        random_shops = { kind="boolean", default=false },
        random_shop_balance = { kind="number", default=0, min=0, max=1 },
        random_tms = { kind="boolean", default=false },
        -- NATIVE / RANDOM 50% / ALL. HMs always use ROM compatibility.
        random_tm_compatibility = { kind="number", default=0, min=0, max=2 },
        randomizer_seed = { kind="number", default=0, min=0, max=MAX_SEED },
        random_encounter_balance = { kind="number", default=0, min=0, max=1 },
        -- Preserve a distinct replacement per native wild source within
        -- each map/method. Defaults OFF so all existing mappings survive.
        random_encounter_repetition = { kind="number", default=0, min=0, max=1 },
        random_encounter_diversity_strength = { kind="number", default=0, min=0, max=2 },
        randomizer_info_policy = { kind="number", default=0, min=0, max=1 },
        random_trainer_balance = { kind="number", default=0, min=0, max=1 },
        random_species_generation = { kind="number", default=0, min=0, max=3 },
        random_trainer_diversity = { kind="number", default=0, min=0, max=1 },
        random_trainer_theme = { kind="number", default=0, min=0, max=1 },
        random_learnsets = { kind="boolean", default=false },
        random_learnset_generation = { kind="number", default=0, min=0, max=3 },
        random_learnset_stab = { kind="number", default=0, min=0, max=2 },
        random_evolutions = { kind="boolean", default=false },
        random_evolution_balance = { kind="number", default=0, min=0, max=1 },
        random_tm_locations = { kind="boolean", default=false },
        random_gift_items = { kind="boolean", default=false },
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
        r.shopAssignments = nil
        r.tmMoves = nil
        r.tmOriginals = nil
        r.tmLocationMap = nil
        r.giftItemAssignments = nil
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
    local function primaryType(Pokemon, id)
        if type(Pokemon.types)~="function" then return nil end
        local ok,types=pcall(Pokemon.types,id)
        if not ok or type(types)~="table" then return nil end
        return tonumber(types[1])
    end
    local function nativeEvolutionGraph(Pokemon)
        local targets={}
        local resolver=Pokemon.__nuzNativeEvolutions or Pokemon.evolutions
        if type(resolver)~="function" then return targets end
        for _,entry in ipairs(M.pool(Pokemon)) do
            local ok,rows=pcall(resolver,entry.id)
            if ok and type(rows)=="table" then
                for _,row in ipairs(rows) do
                    local id=tonumber(row.target or row[3])
                    if id then targets[id]=true end
                end
            end
        end
        return targets
    end
    local function starterAllowed(Pokemon,id,style,targets)
        if style==0 then return true end
        local resolver=Pokemon.__nuzNativeEvolutions or Pokemon.evolutions
        if type(resolver)~="function" then return false end
        local ok,rows=pcall(resolver,id)
        if not ok or type(rows)~="table" then return false end
        if style==1 then return not targets[id] and #rows>0 end
        return targets[id] and #rows==0
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
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        local targets=r.random_starter_style~=0
            and nativeEvolutionGraph(Pokemon) or {}
        local attempts=({1,3,5})[r.random_starter_rerolls+1] or 1
        local chosen,bestSpread
        for attempt=1,attempts do
            local trial,used,types={}, {}, {}
            local valid=true
            for i=1,3 do
                local original=originals[i]
                local legal=candidates(Pokemon,original,
                    r.random_species_generation,r.random_starter_balance,
                    denyNational,used)
                local filtered={}
                for _,entry in ipairs(legal or {}) do
                    local t=primaryType(Pokemon,entry.id)
                    if starterAllowed(Pokemon,entry.id,
                        r.random_starter_style,targets)
                        and (r.random_starter_trio_typing~=1
                            or (t~=nil and not types[t])) then
                        filtered[#filtered+1]=entry
                    end
                end
                if #filtered==0 then valid=false;break end
                local index=1+M.hash(M.algorithm,seed,"STARTERS",
                    source,i,original,attempt)%#filtered
                trial[i]=filtered[index].id
                used[trial[i]]=true
                local t=primaryType(Pokemon,trial[i])
                if t~=nil then types[t]=true end
            end
            if valid then
                local bsts={}
                for i=1,3 do
                    local v=eligiblePokemon(Pokemon,trial[i])
                    bsts[i]=v and v.bst or 0
                end
                table.sort(bsts)
                local spread=bsts[3]-bsts[1]
                if not chosen or spread<bestSpread then
                    chosen,bestSpread=trial,spread
                end
            end
        end
        if not chosen then return nil end
        r.starterOptions = chosen
        r.starterSource = source
        r.used = true
        return { chosen[1], chosen[2], chosen[3] }
    end

    -- Read the actual ROM evolution graph. Do not infer an evolution by
    -- adding 1 or 2 to the internal species ID: Gen 3 has holes/forms and
    -- branched evolution lines, particularly across FRLG and RSE.
    local function evolutionTargets(Pokemon, species, poolMode, denyNational, useNative)
        if type(Pokemon.evolutions) ~= "function" then return {} end
        local resolver=useNative and Pokemon.__nuzNativeEvolutions
            or Pokemon.evolutions
        local ok, evolutions = pcall(resolver, species)
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
        for _, first in ipairs(evolutionTargets(Pokemon, original,
            nil,nil,true)) do
            if first == encountered then return 1 end
            for _, second in ipairs(evolutionTargets(Pokemon, first,
                nil,nil,true)) do
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
    function M.item(s, ItemsData, sourceId, original, entropy, scope, kind)
        local r=state(s)
        kind=kind=="GIFT" and "GIFT" or "FIELD"
        if not (kind=="GIFT" and r.random_gift_items
            or kind=="FIELD" and r.random_field_items)
            or type(sourceId)~="string" or sourceId==""
            or type(scope)~="string" or scope=="" then return nil end
        local originalId=tonumber(original)
        local orig=itemEntry(ItemsData,originalId)
        -- Preserve the Poké Balls awarded by scripted early-game NPCs.
        if not orig or (kind=="GIFT" and originalId==4) then return nil end
        local pool=M.itemPool(ItemsData)
        if #pool<2 then return nil end
        local candidate=itemCandidates(pool,orig,r.random_field_item_balance)
        if #candidate==0 then return nil end
        local assignmentKey=kind=="GIFT"
            and "giftItemAssignments" or "fieldItemAssignments"
        local assignments=type(r[assignmentKey])=="table"
            and r[assignmentKey][scope] or nil
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
            kind=="GIFT" and "GIFT_ITEMS" or "FIELD_ITEMS",
            sourceId,originalId)%#candidate]
        if type(r[assignmentKey])~="table" then
            r[assignmentKey]={}
        end
        if type(r[assignmentKey][scope])~="table" then
            r[assignmentKey][scope]={}
        end
        r[assignmentKey][scope][sourceId]=chosen.id
        r.used=true
        return chosen.id
    end

    -- A single bijection of TM01..50 keeps all TM placements in the
    -- active ROM and never touches HM01..08. Copying a TM reward twice
    -- gives the same replacement, not a new random draw.
    function M.tmLocation(s,original,entropy)
        local r=state(s)
        local id=tonumber(original)
        if not r.random_tm_locations or not id or id<289 or id>338
            or id~=math.floor(id) then return nil end
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        if type(r.tmLocationMap)~="table" then
            local pool={}
            for i=289,338 do pool[#pool+1]=i end
            -- Deterministic Fisher-Yates, no math.random / RNG stream
            -- mutations after runSeed was resolved.
            for i=50,2,-1 do
                local j=1+M.hash(M.algorithm,seed,"TM_LOCATIONS",i)%i
                pool[i],pool[j]=pool[j],pool[i]
            end
            -- Repair accidental fixed points without changing the set.
            for i=1,50 do
                if pool[i]==288+i then
                    local nextI=i%50+1
                    pool[i],pool[nextI]=pool[nextI],pool[i]
                end
            end
            r.tmLocationMap=pool
        end
        local map=r.tmLocationMap
        if #map~=50 then return nil end
        local used={}
        for i=1,50 do
            local v=tonumber(map[i])
            if not v or v<289 or v>338 or used[v] then return nil end
            used[v]=true
        end
        r.used=true
        return map[id-288]
    end

    -- Each native Pokemart pointer/map gets one saved transaction.
    -- This is a display stock rewrite; native purchase pricing, bags,
    -- transaction callbacks, inventory limits and story logic own awards.
    function M.shop(s, ItemsData, sourceId, originals, entropy)
        local r=state(s)
        if not r.random_shops or type(sourceId)~="string"
            or sourceId=="" or type(originals)~="table"
            or #originals==0 or #originals>128 then return nil end
        local native={}
        for i=1,#originals do
            local id=tonumber(originals[i])
            if not id or id~=math.floor(id) or id<1
                or id>=0x4000 then return nil end
            native[i]=id
        end
        local pool=M.itemPool(ItemsData)
        if #pool<2 then return nil end
        local prev=type(r.shopAssignments)=="table"
            and r.shopAssignments[sourceId] or nil
        if prev~=nil then
            if type(prev)~="table" or type(prev.originals)~="table"
                or type(prev.items)~="table"
                or #prev.originals~=#native
                or #prev.items~=#native then return nil end
            local copy={}
            for i=1,#native do
                if tonumber(prev.originals[i])~=native[i] then return nil end
                local id=tonumber(prev.items[i])
                if id~=native[i] and not itemEntry(ItemsData,id) then
                    return nil
                end
                if not id then return nil end
                copy[i]=id
            end
            r.used=true
            return copy
        end
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        local result,protected,changed={},{},false
        -- The starter Poké Ball remains available in marts that
        -- originally carry it. Story/key/TM stock is untouched too.
        -- Reserve these slots before assigning any replacement.
        for i,id in ipairs(native) do
            if id==4 or not itemEntry(ItemsData,id) then
                result[i]=id
                protected[id]=true
            end
        end
        for i,id in ipairs(native) do
            if not result[i] then
                local orig=itemEntry(ItemsData,id)
                local candidates=itemCandidates(pool,orig,
                    r.random_shop_balance,protected)
                if #candidates==0 then
                    result[i]=id
                else
                    local index=1+M.hash(M.algorithm,seed,"SHOPS",
                        sourceId,i,id)%#candidates
                    result[i]=candidates[index].id
                    if result[i]~=id then changed=true end
                end
                protected[result[i]]=true
            end
        end
        if not changed then return nil end
        if type(r.shopAssignments)~="table" then
            r.shopAssignments={}
        end
        r.shopAssignments[sourceId]={
            originals=native,items=result
        }
        r.used=true
        return result
    end

    local validTmMove
    -- Level-up moves from the native Pokemon.learnset resolver. Never
    -- change the ROM move registry or replace an HM with an unforgettably
    -- learned field move. Preserve every original learning LEVEL and
    -- duplicate count; only move IDs change.
    local function moveGen(id)
        if id<=165 then return 1 end
        if id<=251 then return 2 end
        return 3
    end
    function M.learnset(s,Pokemon,species,rows,entropy)
        local r=state(s)
        if not r.random_learnsets or type(rows)~="table"
            or #rows==0 or not eligiblePokemon(Pokemon,tonumber(species)) then
            return nil end
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        local legal,stab={},{}
        local types
        if type(Pokemon.types)=="function" then
            local ok,t=pcall(Pokemon.types,tonumber(species))
            if ok and type(t)=="table" then types=t end
        end
        for id=1,354 do
            if validTmMove(Pokemon,id)
                and (r.random_learnset_generation==0
                    or moveGen(id)==r.random_learnset_generation) then
                legal[#legal+1]=id
                if types then
                    local ok,move=pcall(Pokemon.battleMove,id)
                    if ok and type(move)=="table" then
                        local t=tonumber(move.type or move.typeId)
                        if t and (t==types[1] or t==types[2]) then
                            stab[#stab+1]=id
                        end
                    end
                end
            end
        end
        if #legal==0 then return nil end
        local out,used={},{}
        for i,e in ipairs(rows) do
            if type(e)~="table" then return nil end
            local original=tonumber(e[2] or e.move)
            local level=tonumber(e[1] or e.level)
            if not original or not level then return nil end
            local chosenPool=legal
            if #stab>0 and r.random_learnset_stab>0 then
                if r.random_learnset_stab==2 or
                    M.hash(M.algorithm,seed,"LEVEL_STAB",
                        species,level,i)%3~=0 then
                    chosenPool=stab
                end
            end
            local available={}
            for _,id in ipairs(chosenPool) do
                if id~=original and not used[id] then
                    available[#available+1]=id
                end
            end
            if #available==0 then
                for _,id in ipairs(chosenPool) do
                    if id~=original then available[#available+1]=id end
                end
            end
            if #available==0 then available=chosenPool end
            local idx=1+M.hash(M.algorithm,seed,"LEARNSET",
                species,level,i,original)%#available
            local item={}
            for k,v in pairs(e) do item[k]=v end
            if e[2]~=nil then item[2]=available[idx] end
            if e.move~=nil then item.move=available[idx] end
            out[i]=item
            used[available[idx]]=true
        end
        r.used=true
        return out
    end

    -- Evolution scans read Pokemon.evolutions at the native boundary.
    -- Changing ONLY the target retains trade, stone, level and other
    -- method prerequisites. To avoid evolution cycles the replacement
    -- strictly ascends (BST, internal species ID) from the source species.
    -- Nincada's special Ninjask/Shedinja pair is left native.
    function M.evolutions(s,Pokemon,species,rows,entropy)
        local r=state(s)
        local source=eligiblePokemon(Pokemon,tonumber(species))
        if not r.random_evolutions or not source
            or type(rows)~="table" or #rows==0 then return nil end
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        local all=M.pool(Pokemon)
        local out,changed={},false
        for i,e in ipairs(rows) do
            if type(e)~="table" then return nil end
            local original=tonumber(e.target or e[3])
            local method=tonumber(e.method or e[1])
            if not original then return nil end
            local copy={}
            for k,v in pairs(e) do copy[k]=v end
            if method~=13 and method~=14 then
                local target=eligiblePokemon(Pokemon,original)
                local possible={}
                for _,candidate in ipairs(all) do
                    if candidate.id~=source.id and candidate.id~=original
                        and (candidate.bst>source.bst
                            or candidate.bst==source.bst
                                and candidate.id>source.id)
                        and (r.random_species_generation==0
                            or generation(candidate.national)
                                ==r.random_species_generation) then
                        possible[#possible+1]=candidate
                    end
                end
                if r.random_evolution_balance==1 and target then
                    local near={}
                    for _,entry in ipairs(possible) do
                        if math.abs(entry.bst-target.bst)
                            <=math.max(40,target.bst*.25) then
                            near[#near+1]=entry
                        end
                    end
                    if #near>0 then possible=near end
                end
                if #possible>0 then
                    local at=1+M.hash(M.algorithm,seed,
                        "EVOLUTION",source.id,i,original,method)
                        %#possible
                    local id=possible[at].id
                    if e[3]~=nil then copy[3]=id end
                    if e.target~=nil then copy.target=id end
                    changed=true
                end
            end
            out[i]=copy
        end
        if not changed then return nil end
        r.used=true
        return out
    end

    -- Game 3 has 50 TM item IDs (289..338), then eight HM items
    -- (339..346). Use actual native ROM TM moves as the input fingerprint.
    -- Replacement moves are valid installed Gen 3 battle moves, excluding
    -- Struggle and all HM field moves. Neither Pokemon._tmhm nor TM items
    -- are mutated: a shared resolver drives the Case, party preflight and
    -- teaching so presentation always matches the actual learned move.
    validTmMove = function(Pokemon, id)
        id=tonumber(id)
        if not id or id~=math.floor(id) or id<1 or id>354
            or id==165 then return false end -- Struggle
        if type(Pokemon)~="table"
            or type(Pokemon.battleMove)~="function"
            or type(Pokemon.moveName)~="function"
            or type(Pokemon.isHmMove)~="function" then return false end
        local okHm,hm=pcall(Pokemon.isHmMove,id)
        if not okHm or hm then return false end
        local okRow,row=pcall(Pokemon.battleMove,id)
        local okName,name=pcall(Pokemon.moveName,id)
        return okRow and type(row)=="table"
            and (tonumber(row.pp) or 0)>0
            and okName and type(name)=="string"
            and name~="" and name~="-------"
    end
    function M.tms(s,Pokemon,originals,entropy)
        local r=state(s)
        if not r.random_tms or type(originals)~="table"
            or #originals~=50 then return nil end
        local base={}
        for i=1,50 do
            local id=tonumber(originals[i])
            if not id or id~=math.floor(id) or id<1 or id>354 then
                return nil
            end
            base[i]=id
        end
        if r.tmMoves~=nil or r.tmOriginals~=nil then
            if type(r.tmMoves)~="table"
                or type(r.tmOriginals)~="table"
                or #r.tmMoves~=50 or #r.tmOriginals~=50 then return nil end
            local copy={}
            for i=1,50 do
                if r.tmOriginals[i]~=base[i]
                    or not validTmMove(Pokemon,r.tmMoves[i]) then
                    return nil -- changed ROM mapping: fail open
                end
                copy[i]=r.tmMoves[i]
            end
            r.used=true
            return copy
        end
        local pool={}
        for id=1,354 do
            if validTmMove(Pokemon,id) then pool[#pool+1]=id end
        end
        if #pool<50 then return nil end
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        local result,chosen={},{}
        for i,original in ipairs(base) do
            local at=1+M.hash(M.algorithm,seed,"TM_MOVES",i,original)
                %#pool
            local picked
            for j=0,#pool-1 do
                local id=pool[1+(at-1+j)%#pool]
                if id~=original and not chosen[id] then
                    picked=id
                    break
                end
            end
            if not picked then return nil end
            result[i]=picked
            chosen[picked]=true
        end
        r.tmMoves=result
        r.tmOriginals=base
        r.used=true
        local copy={}
        for i=1,50 do copy[i]=result[i] end
        return copy
    end
    function M.tmCanLearn(s,Pokemon,species,tmIndex,entropy)
        local r=state(s)
        if r.random_tm_compatibility==0 then return nil end
        tmIndex=tonumber(tmIndex)
        if not tmIndex or tmIndex~=math.floor(tmIndex)
            or tmIndex<0 or tmIndex>=50
            or not eligiblePokemon(Pokemon,tonumber(species)) then
            return nil -- HM indexes 50..57 always remain native
        end
        local seed=M.seed(s,entropy)
        if seed==0 then return nil end
        local allowed=r.random_tm_compatibility==2
            or M.hash(M.algorithm,seed,"TM_COMPAT",
                tonumber(species),tmIndex)%2==0
        r.used=true
        return allowed
    end

    function M.replace(s, Pokemon, source, sourceId, original, entropy,
        denyNational, excluded, wildScope, wildSlot, themeType)
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
        if source=="TRAINERS" and r.random_trainer_theme==1
            and themeType~=nil then
            local themed={}
            for _,entry in ipairs(legal) do
                local t=primaryType(Pokemon,entry.id)
                if t==themeType then themed[#themed+1]=entry end
            end
            if #themed>0 then legal=themed end
        end
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
        if unique and r.random_encounter_diversity_strength>0
            and type(Pokemon.types)=="function" then
            local blocked={}
            for _,prior in pairs(scopeAssignments or {}) do
                local ok,types=pcall(Pokemon.types,prior)
                if ok and type(types)=="table" then
                    blocked[types[1]]=true
                    if r.random_encounter_diversity_strength==2 then
                        blocked[types[2]]=true
                    end
                end
            end
            local diverse={}
            for _,entry in ipairs(legal) do
                local ok,t=pcall(Pokemon.types,entry.id)
                if ok and type(t)=="table" and not blocked[t[1]]
                    and (r.random_encounter_diversity_strength~=2
                        or not blocked[t[2]]) then
                    diverse[#diverse+1]=entry
                end
            end
            if #diverse>0 then legal=diverse end
        end
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
