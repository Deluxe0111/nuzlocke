-- Gen 3 ADVANCED RULES / STATUS BANS.
-- Scope is determined by the *source* of the status, not its target.
return function()
    local M = { api = 1, schema = 1 }
    local STATUS = {
        { "status_paralysis_scope", "Paralysis" },
        { "status_confusion_scope", "Confusion" },
        { "status_sleep_scope", "Sleep Ban" },
        { "status_poison_scope", "Poison/Toxic" },
        { "status_burn_scope", "Burn Ban" },
        { "status_freeze_scope", "Freeze" },
    }
    local definitions = {
        { key="status_move_scope", label="No Status Moves",
            default=0,kind="scope",parent=true },
    }
    for _,entry in ipairs(STATUS) do
        definitions[#definitions+1]={key=entry[1],label=entry[2],
            default=0,kind="scope",child=true}
    end
    -- Sleep Clause deliberately stays [Soon]. Tracking prior sleep origins
    -- across switched/boxed/traded Pokemon is not certified yet.
    local byKey={}
    for _,d in ipairs(definitions) do byKey[d.key]=d end
    local LABELS={"OFF","SELF","ENEMY","ALL"}
    local EFFECT_KEY={
        PARALYSIS="status_paralysis_scope",PAR="status_paralysis_scope",
        CONFUSION="status_confusion_scope",
        SLEEP="status_sleep_scope",SLP="status_sleep_scope",
        POISON="status_poison_scope",PSN="status_poison_scope",
        TOXIC="status_poison_scope",TOX="status_poison_scope",
        BURN="status_burn_scope",BRN="status_burn_scope",
        FREEZE="status_freeze_scope",FRZ="status_freeze_scope",
    }
    function M.descriptors()
        local r={}
        for i,d in ipairs(definitions) do
            r[i]={key=d.key,label=d.label,default=d.default,
                kind=d.kind,status="working"}
        end
        return r
    end
    function M.get(s,key)
        if not byKey[key] then return nil end
        local rows=type(s)=="table" and s.statusBans or nil
        local v=type(rows)=="table" and rows[key] or nil
        if type(v)=="number" and v>=0 and v<=3
            and v==math.floor(v) then return v end
        return 0
    end
    function M.set(s,key,value)
        local def=byKey[key]
        if not def then return false,"not_implemented" end
        if type(s)~="table" then return false,"invalid_state" end
        if s.failed then return false,"run_failed" end
        if type(value)~="number" or value~=math.floor(value)
            or value<0 or value>3 then return false,"invalid_scope" end
        if not def.parent and M.get(s,"status_move_scope")~=0 then
            return false,"parent_controls_children"
        end
        if type(s.statusBans)~="table" then s.statusBans={} end
        s.statusBans[key]=value
        if def.parent then
            -- The parent is a bulk setter, not an additional blanket ban
            -- on all non-damaging moves. A return to OFF resets its children
            -- to OFF; players may then configure children individually.
            for _,entry in ipairs(STATUS) do
                s.statusBans[entry[1]]=value
            end
        end
        return true
    end
    function M.next(s,key)
        local v=M.get(s,key)
        if v==nil then return nil end
        return (v+1)%4
    end
    function M.label(s,key)
        local v=M.get(s,key)
        if v==nil then return "UNKNOWN" end
        return LABELS[v+1]
    end
    function M.childKeys()
        local r={}
        for _,v in ipairs(STATUS) do r[#r+1]=v[1] end
        return r
    end
    function M.childrenHidden(s)
        return M.get(s,"status_move_scope")~=0
    end
    function M.applies(s,key,source,core)
        if not core or not core.active(s) then return false end
        local v=M.get(s,key)
        if not v or v==0 then return false end
        local side=type(source)=="table" and source.side or source
        if side~="player" and side~="enemy" then return false end
        return v==3 or (v==1 and side=="player")
            or (v==2 and side=="enemy")
    end
    function M.deny(s,effect,source,target,core)
        local key=EFFECT_KEY[effect]
        if not key then return false end
        -- Rest and other self-induced sleep are explicitly allowed.
        if (effect=="SLEEP" or effect=="SLP")
            and type(source)=="table" and source==target then
            return false
        end
        return M.applies(s,key,source,core)
    end
    return M
end
