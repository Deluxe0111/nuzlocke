-- Terminal Gen 3 Nuzlocke records. Kept independent of renderer/save APIs.
-- Store a bounded, immutable-looking summary rather than mutable party pointers.
return function()
    local M={api=1,schema=1}
    local function count(t)
        local n=0
        for _ in pairs(type(t)=="table" and t or {}) do n=n+1 end
        return n
    end
    local function num(v)
        local n=tonumber(v)
        return n and math.floor(n) or nil
    end
    local function playtime(session)
        local p=session.playtime or session.playTime or {}
        local h=num(session.playTimeHours or session.hours or p.hours) or 0
        local m=num(session.playTimeMinutes or session.minutes or p.minutes) or 0
        local s=num(session.playTimeSeconds or session.seconds or p.seconds) or 0
        return string.format("%d:%02d:%02d",h,m,s)
    end
    local function copySmall(t,depth)
        if type(t)~="table" then return nil end
        if depth>2 then return nil end
        local out={}
        local n=0
        for k,v in pairs(t) do
            if n>=48 then break end
            if type(k)=="string" or type(k)=="number" then
                if type(v)=="string" or type(v)=="number"
                    or type(v)=="boolean" then
                    out[k]=v
                elseif type(v)=="table" then
                    out[k]=copySmall(v,depth+1)
                end
                n=n+1
            end
        end
        return out
    end
    local function capture(mon,Display,dead)
        if type(mon)~="table" then return nil end
        local raw=type(mon.archive)=="table" and mon.archive or mon
        local display=type(mon.species)=="number" and mon or raw
        local info={
            species=num(raw.species or raw.speciesId or mon.species or mon.speciesId),
            speciesNumbering=raw.speciesNumbering,
            name=Display.pokemonName(mon),
            speciesName=Display.speciesName(mon),
            nickname=mon.nickname or raw.nickname,
            level=num(mon.level or raw.level) or 1,
            personality=num(raw.personality),
            shiny=raw.shiny==true,
            hp=num(raw.hp),maxHp=num(raw.maxHp),
            attack=num(raw.atk or raw.attack),
            defense=num(raw.def or raw.defense),
            speed=num(raw.spe or raw.speed),
            spAttack=num(raw.spa or raw.spAttack),
            spDefense=num(raw.spd or raw.spDefense),
            ability=raw.ability or raw.abilityId,
            heldItem=raw.heldItem or raw.item,
            nature=raw.nature,
            ivs=copySmall(raw.ivs or raw.iv,0),
            evs=copySmall(raw.evs or raw.ev,0),
            moves=copySmall(raw.moves,0),
            cause=dead and tostring(mon.cause or "Fainted") or nil,
            area=dead and (mon.areaName or Display.areaName(mon.area)) or nil,
        }
        if info.species==nil and type(mon.species)=="number" then
            info.species=mon.species
        end
        return info
    end
    function M.isTerminal(s)
        return type(s)=="table"
            and type(s.finalResult)=="table"
            and (s.finalResult.outcome=="FAILED"
                or s.finalResult.outcome=="FORFEIT")
    end
    function M.finish(s,session,Display,outcome,reason,badges)
        if type(s)~="table" or s.enabled~=true
            or type(session)~="table"
            or type(Display)~="table"
            or (outcome~="VICTORY" and outcome~="FAILED"
                and outcome~="FORFEIT") then return nil end
        if type(s.finalResult)=="table" then return s.finalResult end
        local areas,caught,spent=0,0,0
        for _,entry in pairs(s.areas or {}) do
            areas=areas+1
            if type(entry)=="table" and entry.caught then caught=caught+1 end
            if type(entry)=="table" and (entry.spent or entry.spent==nil)
                then spent=spent+1 end
        end
        local party,graveyard={},{}
        for _,mon in ipairs(session.party or {}) do
            local record=capture(mon,Display,false)
            if record then party[#party+1]=record end
        end
        for _,mon in ipairs(s.graveyard or {}) do
            local record=capture(mon,Display,true)
            if record then graveyard[#graveyard+1]=record end
        end
        local record={
            schema=M.schema,outcome=outcome,
            reason=tostring(reason or (outcome=="VICTORY"
                and "Champion defeated" or "Run ended")),
            trainer=tostring(session.name or session.playerName or "TRAINER"),
            version=tostring(session.version or ""),
            date=os.date and os.date("!%Y-%m-%d %H:%M UTC") or "",
            playtime=playtime(session),
            badges=num(badges) or num(session.badgeCount) or 0,
            encounters=areas,caught=caught,spent=spent,
            deaths=#graveyard,party=party,graveyard=graveyard,
            shinyExceptions=num(s.shinyExceptionsUsed) or 0,
            giftCount=count(s.giftClaims),
        }
        s.finalResult=record
        if outcome~="VICTORY" then s.failed=true end
        return record
    end
    return M
end
