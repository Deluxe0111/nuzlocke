-- Shiny Nuzlocke Gen3 playstyle: eligibility, precedence, notices and menu.
local Style = assert(loadfile("gen3_playstyles.lua"))()()
local Core = assert(loadfile("gen3_core_rules.lua"))()()
local state = Core.normalise({})
assert(Style.get(state,"shiny_nuzlocke")==false
    and Style.descriptors()[1].status=="working")
assert(not Style.active(state,Core))
assert(Style.set(state,"shiny_nuzlocke",true))
assert(not Style.active(state,Core),
    "the Nuzlocke master switch controls the playstyle")
assert(Core.set(state,"nuzlocke_enabled",true))
assert(Style.active(state,Core))
assert(not Style.qualifies(state,Core,false))
assert(Style.qualifies(state,Core,true))
assert(not Style.allowShinyException(state,Core))
assert(not Style.set(state,"shiny_nuzlocke",3))
assert(not Style.set(state,"no_such_variant",true))
local recovered=Style.normalise({playstyles={shiny_nuzlocke=true}})
assert(Style.get(recovered,"shiny_nuzlocke")==true,
    "playstyle must survive reloading saved state")
recovered.failed=true
assert(not Style.set(recovered,"shiny_nuzlocke",false),
    "failed runs cannot change playstyle")

local events,hooks,values={},{},{}
local battleText={}
package.loaded["src.core.game3.pokemon"]={
    isShiny=function(mon) return type(mon)=="table"
        and mon.isShiny==true end,
    speciesOf=function(mon) return tonumber(mon.species or mon.speciesId) end,
    name=function(id)
        return ({[4]="CHARMANDER",[16]="PIDGEY",[25]="PIKACHU",
            [160]="FERALIGATR"})[tonumber(id)]
    end,
}
package.loaded["src.core.game3.battle.ui"]={
    push=function(line) battleText[#battleText+1]=line end,
}
package.loaded["src.import.gba.map_sections_extract"]={
    getInfo=function(_,map) return {
        resolved=true,
        rawName=map=="FR_ROUTE_1" and "ROUTE 1" or tostring(map),
        name=map=="FR_ROUTE_1" and "ROUTE 1" or tostring(map),
    } end,
}
local g={generation=3,session={version="firered",map="FR_ROUTE_1",
    party={{species=25,personality=10,level=9,hp=35}},flags={}}}
local stack={}
package.loaded["src.ui.game3.stack"]={
    push=function(id,m) stack[#stack+1]={id=id,module=m} end,
    pop=function(id)
        assert(stack[#stack] and stack[#stack].id==id)
        stack[#stack]=nil
    end,
}
local mod={game=g,exports={},
    save={
        get=function(_,k,default)return values[k] or default end,
        set=function(_,k,v)values[k]=v end,
    },
    events={on=function(_,n,fn)events[n]=fn end},
    hooks={wrap=function(_,n,fn)hooks[n]=fn end},
    read=function(_,path)
        local f=assert(io.open(path,"rb"))
        local t=f:read("*a");f:close();return t
    end,
}
assert(loadfile("gen3_runtime.lua")()(mod)==nil)
local styles=mod.exports.gen3_playstyles
local core=mod.exports.gen3_core
assert(styles.api==1 and styles.schema==1 and
    styles.getRule("shiny_nuzlocke")==false)
assert(core.setRule("nuzlocke_enabled",true))
assert(styles.setRule("shiny_nuzlocke",true))
assert(styles.getRule("shiny_nuzlocke"))
assert(mod.exports.gen3_notices.history()[1].code=="PLAYSTYLE_CHANGED")
local function ev(name,payload)
    assert(events[name],name)(payload)
end
local function map(id)
    g.session.map=id
    ev("map.entered",{mapId=id})
end
local function battle(species, shiny, options)
    options=options or {}
    local mon={species=species or 16,isShiny=shiny==true,
        personality=shiny and 77 or 1}
    local b={enemy={mon=mon}}
    ev("battle.started",{battle=b,kind="wild",speciesId=species or 16})
    return b,mon
end
local function ball(b,mon)
    local nextCalled=0
    local caught,shakes=hooks["catch.rate"](function()
        nextCalled=nextCalled+1
        return true,4
    end,"POKE_BALL",mon,mon.species,{battle=b})
    ev("battle.ball_thrown",{battle=b,caught=caught,shakes=shakes})
    return caught,shakes,nextCalled
end
-- Many normal wilds can be encountered and even have balls thrown without
-- consuming the first route's chance with Failed Encounters ON.
map("FR_ROUTE_1")
for i=1,3 do
    local b,mon=battle(16,false)
    local caught,shakes,called=ball(b,mon)
    assert(not caught and shakes==0 and called==0,
        "ordinary wild Pokemon must not enter the native catch roll")
    local a=values.gen3_classic_v1.areas.FR_ROUTE_1
    assert(a==nil or a.spent==false,
        "nonshinies must never claim route on attempt")
    assert(battleText[#battleText]:find("only shiny Pokemon",1,true)
        and battleText[#battleText]:find("do not use your route",1,true),
        "blocked ball must explain the shiny restriction and unused route")
    ev("battle.ended",{battle=b,result="run"})
end
local b,mon=battle(16,true)
assert(values.gen3_classic_v1.areas.FR_ROUTE_1.spent==true,
    "first eligible shiny claims area with Failed Encounters ON")
assert(select(1,ball(b,mon))==true)
ev("pokemon.caught",{battle=b,speciesId=16,mon=mon})
assert(values.gen3_classic_v1.areas.FR_ROUTE_1.caught)
ev("battle.ended",{battle=b,result="catch"})
b,mon=battle(25,false)
assert(select(1,ball(b,mon))==false,
    "normal Pokemon also denied when the route was already claimed")
assert(battleText[#battleText]:find("route is already used",1,true),
    "a spent route must not be falsely reported as open")
ev("battle.ended",{battle=b,result="run"})
b,mon=battle(25,true)
assert(select(1,ball(b,mon))==false,
    "second shiny cannot use claimed map")
ev("battle.ended",{battle=b,result="run"})

-- Shiny Clause UNLIMITED must NOT create unlimited shiny catches
-- or bypass Dupes when playing Shiny Nuzlocke.
assert(mod.exports.gen3_clauses.setMode("shiny_clause",4))
b,mon=battle(25,true)
assert(select(1,ball(b,mon))==false)
assert(values.gen3_classic_v1.shinyExceptionsUsed==0)
ev("battle.ended",{battle=b,result="run"})

-- Failed Encounters OFF: shinies that flee are still eligible until caught.
assert(core.setRule("failed_encounter",false))
map("FR_ROUTE_2")
b,mon=battle(160,false)
assert(select(1,ball(b,mon))==false)
ev("battle.ended",{battle=b,result="run"})
b,mon=battle(160,true)
assert(not values.gen3_classic_v1.areas.FR_ROUTE_2.spent)
-- Simulate a natural ball failure, never fabricate a successful catch.
local passed=0
local result=hooks["catch.rate"](function()
    passed=passed+1;return false,2
end,"POKE_BALL",mon,160,{battle=b})
assert(result==false and passed==1)
ev("battle.ended",{battle=b,result="run"})
b,mon=battle(160,true)
assert(select(1,ball(b,mon))==true,"retry shiny after failed catch")
ev("pokemon.caught",{battle=b,speciesId=160,mon=mon})
assert(values.gen3_classic_v1.areas.FR_ROUTE_2.spent)
ev("battle.ended",{battle=b,result="catch"})

-- Dupes Clause excludes an already-owned shiny before it can claim
-- the first area slot. Another eligible shiny can still be caught there.
assert(mod.exports.gen3_clauses.setMode("dupes_mode",1))
map("FR_ROUTE_DUPES")
b,mon=battle(25,true) -- player's starter is Pikachu
assert(values.gen3_classic_v1.areas.FR_ROUTE_DUPES==nil,
    "duplicate shiny cannot use up the route's one encounter")
assert(select(1,ball(b,mon))==false,
    "Shiny Nuzlocke does not disable Dupes Clause")
ev("battle.ended",{battle=b,result="run"})
b,mon=battle(4,true)
assert(select(1,ball(b,mon))==true,
    "a different eligible shiny remains available")
ev("pokemon.caught",{battle=b,speciesId=4,mon=mon})
ev("battle.ended",{battle=b,result="catch"})
assert(mod.exports.gen3_clauses.setMode("dupes_mode",0))

-- Shiny rate (including ALWAYS) is separate from the capture rule.
assert(mod.exports.gen3_clauses.getMode("shiny_rate_mode")==0)
-- With One Per Area OFF, each shiny can be caught, but never a normal.
assert(core.setRule("encounter_limit",false))
map("FR_ROUTE_3")
for i=1,2 do
    b,mon=battle(160,true)
    assert(select(1,ball(b,mon))==true)
    ev("battle.ended",{battle=b,result="catch"})
end
b,mon=battle(16,false)
assert(select(1,ball(b,mon))==false)
ev("battle.ended",{battle=b,result="run"})

-- A wild target lacking an enemy-mon at battle.started must still be
-- rejected if not shiny and claimed once when the ball reveals shiny ID.
assert(core.setRule("encounter_limit",true))
assert(core.setRule("failed_encounter",true))
map("FR_ROUTE_4")
local late={enemy={}}
ev("battle.started",{battle=late,kind="wild",speciesId=16})
assert(values.gen3_classic_v1.areas.FR_ROUTE_4==nil)
local lateMon={species=16,isShiny=true}
assert(select(1,ball(late,lateMon))==true)
assert(values.gen3_classic_v1.areas.FR_ROUTE_4.spent)
ev("pokemon.caught",{battle=late,speciesId=16,mon=lateMon})
ev("battle.ended",{battle=late,result="catch"})

-- Even if the game does not report its current map, no ordinary wild can
-- bypass shiny-only enforcement. Leave unknown-area bookkeeping untouched.
g.session.map=nil
ev("map.entered",{})
b,mon=battle(16,false)
assert(select(1,ball(b,mon))==false)
ev("battle.ended",{battle=b,result="run"})

-- Toggle off: native catches are permitted, master Nuzlocke OFF also
-- disables variant enforcement while stored configuration remains ON.
assert(styles.setRule("shiny_nuzlocke",false))
map("FR_ROUTE_5")
b,mon=battle(16,false)
assert(select(1,ball(b,mon))==true)
ev("battle.ended",{battle=b,result="run"})
assert(styles.setRule("shiny_nuzlocke",true))
assert(core.setRule("nuzlocke_enabled",false))
b,mon=battle(16,false)
assert(select(1,ball(b,mon))==true)
ev("battle.ended",{battle=b,result="run"})

-- Menu exposes an actual PLAYSTYLES category and writes live state.
local start=hooks["ui.start_menu.items"](function(_,items)return items end,g,{})
assert(start[#start].label=="NUZ MENU")
start[#start].onSelect()
local function press(button)
    assert(stack[#stack])
    stack[#stack].module.handleInput({
        wasPressed=function(_,name)return name==button end
    })
end
press("a") -- NUZ RULES
local catalog=mod.exports.gen3_menu.catalog()
local position
for i,c in ipairs(catalog) do
    if c.title=="PLAYSTYLES" then position=i end
end
assert(position and position>1)
for i=2,position do press("down") end
press("a")
assert(mod.exports.gen3_menu.model().title=="PLAYSTYLES")
local rows=mod.exports.gen3_menu.model().rows
assert(#rows==4, "PLAYSTYLES must have only toggle/details pairs")
assert(rows[1]=="SHINY NUZ: ON" and rows[2]=="  DETAILS: SHINY NUZ"
    and rows[3]=="HARDCORE: OFF" and rows[4]=="  DETAILS: HARDCORE",
    "each playstyle switch must be followed immediately by its DETAILS")
press("a")
assert(mod.exports.gen3_menu.model().rows[1]=="SHINY NUZ: OFF")
assert(styles.getRule("shiny_nuzlocke")==false)
press("down");press("a") -- Shiny details
local details=mod.exports.gen3_menu.model()
assert(details.title=="SHINY NUZLOCKE"
    and #details.rows>=10, "shiny conditions must live on details page")
assert(table.concat(details.rows,";"):find("SHINY CLAUSE: NO BONUS",1,true))
press("b") -- keep position at Shiny details
assert(mod.exports.gen3_menu.model().index==2)
press("down");press("a") -- Hardcore ON
assert(mod.exports.gen3_menu.model().rows[3]=="HARDCORE: ON")
assert(styles.getRule("hardcore_nuzlocke")==true)
press("down");press("a") -- Hardcore details
details=mod.exports.gen3_menu.model()
assert(details.title=="HARDCORE NUZLOCKE"
    and #details.rows>=12,"hardcore restrictions must live on details page")
assert(table.concat(details.rows,";"):find("FORCED SET BATTLE STYLE",1,true))
press("b");press("up");press("a") -- Hardcore OFF
assert(mod.exports.gen3_menu.model().rows[3]=="HARDCORE: OFF")
assert(styles.getRule("hardcore_nuzlocke")==false)
press("b");press("b");press("b")
assert(#stack==0)
print("Gen3 Shiny Nuzlocke policy, native catches, area precedence, feedback and menu: PASS")
