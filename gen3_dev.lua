-- Gen 3 developer-only state editing. Does not edit the engine's party or PC.
-- All mutations require explicit dev opt-in, are battle-gated and mark the
-- Nuzlocke save as a test run. Never export mutating methods to other mods.
return function(api)
    local M = { api = 1 }
    local getState = assert(api.getState)
    local setState = assert(api.setState)
    local getCurrentArea = assert(api.getCurrentArea)
    local inBattle = assert(api.inBattle)
    local getSession = assert(api.getSession)

    local function context(s)
        if type(s.dev) ~= "table" then s.dev = {} end
        local dev = s.dev
        dev.enabled = dev.enabled == true
        dev.tainted = dev.tainted == true
        dev.edits = math.max(0, math.floor(tonumber(dev.edits) or 0))
        if type(dev.history) ~= "table" then dev.history = {} end
        return dev
    end

    local function audit(s, action)
        local d = context(s)
        d.tainted = true
        d.edits = d.edits + 1
        d.lastAction = tostring(action)
        d.history[#d.history + 1] = d.lastAction
        if #d.history > 20 then table.remove(d.history, 1) end
        setState(s)
    end

    local function guard()
        if inBattle() then return nil, "battle_active" end
        local s = getState()
        if not context(s).enabled then return nil, "dev_disabled" end
        return s
    end

    function M.status()
        local s = getState()
        local d = context(s)
        return {
            enabled = d.enabled, tainted = d.tainted,
            edits = d.edits, lastAction = d.lastAction,
        }
    end

    -- Opt in via a confirmation in the menu. Once tainted, always tainted
    -- for this run, even when dev tools are switched back off.
    function M.enable()
        if inBattle() then return false, "battle_active" end
        local s = getState()
        local d = context(s)
        if not d.enabled then
            d.enabled = true
            audit(s, "DEV ENABLE")
        end
        return true
    end

    function M.disable()
        local s, err = guard()
        if not s then return false, err end
        context(s).enabled = false
        audit(s, "DEV DISABLE")
        return true
    end

    function M.currentArea()
        return getCurrentArea()
    end

    function M.areas()
        local s = getState()
        local out = {}
        for key, value in pairs(s.areas or {}) do
            if type(key) == "string" and type(value) == "table" then
                out[#out + 1] = {
                    key = key,
                    caught = value.caught == true,
                    spent = api.areaSpent(value),
                    attempts = tonumber(value.attempts) or 0,
                }
            end
        end
        table.sort(out, function(a, b) return a.key < b.key end)
        return out
    end

    function M.inspect()
        local s = getState()
        local party = getSession() and getSession().party or {}
        local spent, open, caught = 0, 0, 0
        for _, area in pairs(s.areas or {}) do
            if api.areaSpent(area) then spent = spent + 1
            else open = open + 1 end
            if type(area) == "table" and area.caught then
                caught = caught + 1
            end
        end
        local d = context(s)
        return {
            enabled = s.enabled == true,
            failed = s.failed == true,
            party = type(party) == "table" and #party or 0,
            map = getCurrentArea(),
            areasSpent = spent, areasOpen = open, areasCaught = caught,
            deaths = #(s.graveyard or {}),
            edits = d.edits,
            tainted = d.tainted,
            lastAction = d.lastAction,
        }
    end

    function M.setArea(key, mode)
        local s, err = guard()
        if not s then return false, err end
        if type(key) ~= "string" or key == "" then
            return false, "unknown_map"
        end
        if mode ~= "open" and mode ~= "spent"
            and mode ~= "caught" and mode ~= "clear" then
            return false, "invalid_mode"
        end
        if mode == "clear" then
            if s.areas[key] == nil then return false, "not_recorded" end
            s.areas[key] = nil
        else
            local existing = s.areas[key]
            local entry = type(existing) == "table" and existing or {}
            -- A dev edit is a deliberate override of the map's claim state,
            -- not an edit to any actual captured/boxed Pokémon.
            entry.spent = mode ~= "open"
            entry.caught = mode == "caught"
            entry.attempts = tonumber(entry.attempts) or 0
            s.areas[key] = entry
        end
        audit(s, "AREA " .. mode:upper() .. " " .. key)
        return true
    end

    function M.clearAllAreas()
        local s, err = guard()
        if not s then return false, err end
        s.areas = {}
        audit(s, "AREAS CLEAR ALL")
        return true
    end

    function M.clearGraveyard()
        local s, err = guard()
        if not s then return false, err end
        s.graveyard = {}
        audit(s, "GRAVEYARD CLEAR")
        return true
    end

    -- A run can be re-armed only if the native party is already nonempty.
    -- This never recreates deleted Pokémon, heals anyone or touches the PC.
    function M.clearFailed()
        local s, err = guard()
        if not s then return false, err end
        local native = getSession()
        if type(native) ~= "table" or type(native.party) ~= "table"
            or #native.party == 0 then
            return false, "empty_party"
        end
        s.failed = false
        audit(s, "RUN FAILURE CLEAR")
        return true
    end

    return M
end
