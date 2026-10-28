-- Gen 3 ADVANCED RULES / CATCH RULES: species eligibility for wild catches.
-- The native battle owns Poké Ball consumption, shake animation and storage.
-- This policy only allows/denies the existing catch.rate transaction.
return function()
    local M = { api = 1, schema = 1 }
    local RULES = {
        { key = "ban_legendaries", label = "No Legendaries",
          default = false, kind = "toggle" },
        { key = "ban_mythicals", label = "No Mythicals",
          default = false, kind = "toggle" },
        { key = "ban_pseudos", label = "No Pseudos",
          default = false, kind = "toggle" },
        { key = "no_static_encounters", label = "No Static Enc",
          default = false, kind = "toggle" },
        { key = "no_fishing", label = "No Fishing",
          default = false, kind = "toggle" },
        { key = "maximum_bst", label = "Maximum BST",
          default = 0, kind = "cycle" },
    }
    -- 0 = unlimited. Explicit presets keep the 240x160 menu compact.
    local BST_LIMITS = { 0, 300, 350, 400, 450, 500, 550, 600, 650, 700 }
    local byKey = {}
    for _, rule in ipairs(RULES) do byKey[rule.key] = rule end
    local function asState(s)
        if type(s) ~= "table" then return {} end
        if type(s.catchRules) ~= "table" then s.catchRules = {} end
        return s.catchRules
    end
    function M.descriptors()
        local copy = {}
        for i, d in ipairs(RULES) do
            copy[i] = { key=d.key, label=d.label, kind=d.kind, status="working" }
        end
        return copy
    end
    function M.get(s, key)
        local d = byKey[key]
        if not d then return nil end
        local rules = asState(s)
        local v = rules[key]
        if d.kind == "toggle" then
            return type(v) == "boolean" and v or d.default
        end
        for _, option in ipairs(BST_LIMITS) do
            if v == option then return v end
        end
        return d.default
    end
    function M.set(s, key, value)
        local d = byKey[key]
        if not d then return false, "not_implemented" end
        if s and s.failed then return false, "run_failed" end
        if d.kind == "toggle" then
            if type(value) ~= "boolean" then return false, "boolean_required" end
        else
            local valid = false
            for _, option in ipairs(BST_LIMITS) do
                if value == option then valid = true; break end
            end
            if not valid then return false, "invalid_bst" end
        end
        asState(s)[key] = value
        return true
    end
    function M.nextBst(value)
        for i, option in ipairs(BST_LIMITS) do
            if option == value then return BST_LIMITS[i % #BST_LIMITS + 1] end
        end
        return 0
    end
    function M.anyEnabled(s)
        for _, d in ipairs(RULES) do
            if M.get(s, d.key) ~= d.default then return true end
        end
        return false
    end

    -- Scripted wild battles expose both flags on the native Gen 3 battle
    -- state, unlike the public battle.started event's short payload.
    -- Roamers are intentionally excluded even when a battle is marked
    -- legendary: they are roaming, not fixed overworld/scripted encounters.
    function M.checkBattle(s, battle, core)
        if not core or not core.active(s)
            or not M.get(s, "no_static_encounters") then return true end
        if type(battle) == "table" and battle.roamer ~= true
            and (battle.wildScripted == true or battle.legendary == true) then
            return false,
                "No Static Encounters: scripted wild Pokemon cannot be caught."
        end
        return true
    end
    function M.fishingBlocked(s, core)
        return core and core.active(s)
            and M.get(s, "no_fishing") == true or false
    end

    -- National Dex IDs, NOT internal Gen 3 species IDs! Hoenn internal IDs
    -- do not match National IDs (e.g. Treecko's internal index is 277).
    -- Query Pokemon.national() before classifying; never mistake internal
    -- gaps/form slots for banned species.
    local LEGENDARIES = {
        [144]=true,[145]=true,[146]=true,[150]=true,
        [243]=true,[244]=true,[245]=true,[249]=true,[250]=true,
        [377]=true,[378]=true,[379]=true,[380]=true,[381]=true,
        [382]=true,[383]=true,[384]=true,
    }
    local MYTHICALS = { [151]=true,[251]=true,[385]=true,[386]=true }
    -- Whole pseudo-legendary evolution lines, not just final evolutions.
    local PSEUDOS = {
        [147]=true,[148]=true,[149]=true,
        [246]=true,[247]=true,[248]=true,
        [371]=true,[372]=true,[373]=true,
        [374]=true,[375]=true,[376]=true,
    }
    function M.check(s, species, pokemon, core)
        if not core or not core.active(s) then return true end
        if not M.anyEnabled(s) then return true end
        local id = tonumber(species)
        if not id and pokemon and type(pokemon.speciesFromName)=="function" then
            local ok, resolved = pcall(pokemon.speciesFromName, species)
            if ok then id = tonumber(resolved) end
        end
        local national
        if id and pokemon and type(pokemon.national) == "function" then
            local ok, resolved = pcall(pokemon.national, id)
            if ok then national = tonumber(resolved) end
        elseif id and id <= 251 then
            national = id -- only safe for Kanto + Johto
        end
        if national then
            if M.get(s,"ban_legendaries") and LEGENDARIES[national] then
                return false, "No Legendaries: this Pokemon cannot be caught."
            end
            if M.get(s,"ban_mythicals") and MYTHICALS[national] then
                return false, "No Mythicals: this Pokemon cannot be caught."
            end
            if M.get(s,"ban_pseudos") and PSEUDOS[national] then
                return false, "No Pseudos: this evolution family is banned."
            end
        end
        local cap = M.get(s, "maximum_bst")
        if cap > 0 then
            local stats
            if id and pokemon and type(pokemon.stats)=="function" then
                local ok, result = pcall(pokemon.stats, id)
                if ok then stats = result end
            end
            -- A configured maximum is a hard restriction. Unknown stats
            -- must not silently bypass the limit.
            if type(stats) ~= "table" then
                return false, "Maximum BST: unable to verify Pokemon stats."
            end
            local bst = 0
            for i=1,6 do
                local n = tonumber(stats[i])
                if not n or n < 0 then
                    return false, "Maximum BST: unable to verify Pokemon stats."
                end
                bst = bst + n
            end
            if bst > cap then
                return false, "Maximum BST: " .. tostring(bst)
                    .. " exceeds " .. tostring(cap) .. "."
            end
        end
        return true
    end
    return M
end
