-- Gen 3 CORE rule policy and configuration contract.
-- Only gameplay-backed features may be labelled "working".
-- Stored keys match the mature Nuzlocke rule IDs where semantics match.
return function()
    local M = { api = 1, schema = 1 }
    local RULES = {
        { key = "nuzlocke_enabled", label = "NUZLOCKE", default = false, status = "working" },
        { key = "permadeath", label = "PERMADEATH", default = true, status = "working" },
        { key = "encounter_limit", label = "ONE PER AREA", default = true, status = "working" },
        { key = "failed_encounter", label = "FAILED ENCOUNTERS", default = true, status = "working" },
        { key = "nickname_rule", label = "NICKNAME RULE", default = true, status = "soon" },
        { key = "first_rival_forgiveness", label = "FIRST RIVAL MERCY", default = true, status = "soon" },
        { key = "whiteout_ends_run", label = "WHITEOUT ENDS RUN", default = true, status = "wip" },
        { key = "pc_survivors_allowed", label = "PC SURVIVORS", default = false, status = "soon" },
    }
    local byKey = {}
    for _, rule in ipairs(RULES) do byKey[rule.key] = rule end

    function M.descriptors()
        local out = {}
        for i, rule in ipairs(RULES) do
            out[i] = { key = rule.key, label = rule.label, default = rule.default,
                status = rule.status }
        end
        return out
    end

    -- gen3_classic_v1 predates this registry. Keep its original 'enabled'
    -- boolean as canonical so existing test saves remain compatible.
    function M.normalise(s)
        if type(s) ~= "table" then s = {} end
        if type(s.rules) ~= "table" then s.rules = {} end
        if type(s.areas) ~= "table" then s.areas = {} end
        if type(s.graveyard) ~= "table" then s.graveyard = {} end
        s.enabled = s.enabled == true
        s.failed = s.failed == true
        for _, rule in ipairs(RULES) do
            if rule.key ~= "nuzlocke_enabled" and
                type(s.rules[rule.key]) ~= "boolean" then
                s.rules[rule.key] = rule.default
            end
        end
        return s
    end

    function M.get(s, key)
        local definition = byKey[key]
        if not definition then return nil end
        s = M.normalise(s)
        if key == "nuzlocke_enabled" then return s.enabled end
        return s.rules[key]
    end

    -- Prevent third-party calls, or a future menu bug, from claiming support
    -- for features that cannot yet enforce their selected values.
    function M.set(s, key, value)
        local definition = byKey[key]
        if not definition then return false, "unknown_rule" end
        if definition.status == "soon" then return false, "not_implemented" end
        if type(value) ~= "boolean" then return false, "boolean_required" end
        s = M.normalise(s)
        if key == "nuzlocke_enabled" then
            if s.failed and value then return false, "run_failed" end
            s.enabled = value
        else
            s.rules[key] = value
        end
        return true
    end

    function M.active(s)
        return M.get(s, "nuzlocke_enabled") == true
            and not (s and s.failed == true)
    end

    function M.enforced(s, key)
        return M.active(s) and M.get(s, key) == true
    end

    -- Preserve slots consumed by earlier versions of this mod. A missing
    -- spent flag means a legacy first encounter was already committed.
    function M.areaSpent(entry)
        if type(entry) ~= "table" then return false end
        if entry.spent ~= nil then return entry.spent == true end
        return true
    end

    function M.catchAllowed(s, key)
        if not M.enforced(s, "encounter_limit") then return true end
        return not M.areaSpent(s.areas[key])
    end

    function M.shouldSpendOnStart(s)
        return M.enforced(s, "encounter_limit")
            and M.get(s, "failed_encounter") == true
    end

    -- A battle whiteout takes precedence over PC survivors. Future Gen 3 PC
    -- recovery will implement pc_survivors_allowed; do not silently turn it on.
    function M.failedWhiteout(s, battleResult)
        local lost = battleResult == "lose"
            or battleResult == "whiteout" or battleResult == "blackout"
        return lost and M.enforced(s, "whiteout_ends_run")
    end

    return M
end
