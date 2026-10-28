-- End-to-end Gen3 run end: menu forfeit, native save reload, battle
-- whiteout autosave, and genuine Hall of Fame close with postgame resume.
local layers,events,hooks,values={},{},{},{}
local writes,disk,quits=0,nil,0
local function copy(v)
    if type(v)~="table" then return v end
    local out={}
    for k,x in pairs(v) do out[k]=copy(x) end
    return out
end
local Stack={}
function Stack.push(id,module)
    for i=#layers,1,-1 do
        if layers[i].id==id then table.remove(layers,i) end
    end
    layers[#layers+1]={id=id,mod=module}
end
function Stack.pop(id)
    for i=#layers,1,-1 do
        if layers[i].id==id then table.remove(layers,i);return true end
    end
end
function Stack.has(id)
    for _,v in ipairs(layers) do if v.id==id then return true end end
    return false
end
package.loaded["src.ui.game3.stack"]=Stack
local Hof={open=false,close=function(self) self.open=false end}
package.loaded["src.ui.game3.hall_of_fame"]=Hof
package.loaded["src.core.game3.pokemon"]={
    name=function(id) return ({[1]="BULBASAUR",[4]="CHARMANDER",
        [7]="SQUIRTLE"})[id] or "POKEMON" end,
    speciesOf=function(mon)return mon.species end,
}
local function pokemon(id,hp,name)
    return {species=id,level=10,personality=100+id,hp=hp,
        maxHp=28,nickname=name or "",atk=20,def=18,spe=17,spa=19,spd=18}
end
local session={version="firered",map="FR_ROUTE_1",
    name="RED",party={pokemon(1,28,"Leaf")},flags={}}
local game={generation=3,session=session}
function game:writeSave()
    writes=writes+1
    disk=copy(values.gen3_classic_v1)
    return true
end
function game:returnToTitle()
    quits=quits+1
    layers={}
end
local mod={game=game,exports={},
    save={
        get=function(_,key,default)return values[key] or default end,
        set=function(_,key,value)values[key]=value end,
    },
    events={on=function(_,name,fn)events[name]=fn end},
    hooks={wrap=function(_,name,fn)hooks[name]=fn end},
    read=function(_,path)
        local f=assert(io.open(path,"rb"))
        local content=f:read("*a");f:close()
        return content
    end,
}
values.gen3_classic_v1={enabled=true,areas={
    FR_ROUTE_1={caught=true,spent=true}},
    graveyard={{species=4,speciesName="Charmander",name="Flame",
        nickname="Flame",level=9,area="FR_ROUTE_1",cause="Critical hit",
        archive=pokemon(4,0,"Flame")}}}
assert(loadfile("gen3_runtime.lua")()(mod)==nil)
assert(type(events["save.loaded"])=="function"
    and type(events["battle.ended"])=="function")
assert(type(Hof.close)=="function" and Hof.__nuzResultsOwner==mod,
    "Hall of Fame is patched at native completion boundary")
-- User chooses END RUN, receives a separate irreversible confirmation.
assert(mod.exports.gen3_menu.open(game))
local function pressTop(button)
    local top=assert(layers[#layers])
    top.mod.handleInput({
        wasPressed=function(_,key) return key==button end,
    })
end
local function advanceTo(label)
    local top=assert(layers[#layers])
    local model=assert(top.mod.model())
    local target=nil
    for i,v in ipairs(model.rows) do
        if v==label then target=i;break end
    end
    assert(target,"Missing control "..label)
    for _=1,#model.rows+1 do
        if top.mod.model().index==target then break end
        pressTop("down")
    end
    assert(top.mod.model().index==target)
    pressTop("a")
end
advanceTo("END RUN")
assert(mod.exports.gen3_menu.model().title=="END THIS RUN?")
assert(writes==0 and values.gen3_classic_v1.failed~=true,
    "opening confirmation cannot end run")
pressTop("b")
assert(writes==0 and values.gen3_classic_v1.failed~=true,
    "cancel must leave run active")
advanceTo("END RUN")
advanceTo("CONFIRM END RUN")
local terminal=values.gen3_classic_v1
assert(terminal.failed and terminal.finalResult
    and terminal.finalResult.outcome=="FORFEIT"
    and writes==1 and disk and disk.failed,
    "manual end run must snapshot and autosave once")
assert(Stack.has("nuzlocke.gen3.results"))
local results=layers[#layers].mod
assert(results.model().title=="NUZ RUN RESULTS")
for _,name in ipairs(results.model().rows) do
    assert(name~="CONTINUE ADVENTURE")
end
pressTop("b")
assert(Stack.has("nuzlocke.gen3.results"),
    "failed run cannot escape with B")
advanceTo("QUIT TO TITLE")
assert(quits==1 and #layers==0)
-- Continue from the actual saved terminal record. The title's CONTINUE
-- may restore the game session but must never expose live gameplay.
values.gen3_classic_v1=copy(disk)
game.session={version="firered",map="FR_ROUTE_1",
    name="RED",party={pokemon(1,28,"Leaf")},flags={}}
events["save.loaded"]()
assert(Stack.has("nuzlocke.gen3.results")
    and layers[#layers].mod.model().outcome=="FORFEIT",
    "reloading failed save must reopen terminal results")
assert(writes==1,"reloading a terminal save must not overwrite it")
advanceTo("QUIT TO TITLE")
assert(quits==2)
-- New run must be able to end from native battle end with autosave.
values.gen3_classic_v1={enabled=true,areas={},graveyard={}}
game.session={version="firered",map="FR_ROUTE_1",
    name="RED",party={pokemon(7,0,"Shell")},flags={}}
events["save.created"]()
events["battle.ended"]({result="lose",battle={}})
assert(values.gen3_classic_v1.failed
    and values.gen3_classic_v1.finalResult.outcome=="FAILED"
    and writes==2 and disk.finalResult.outcome=="FAILED"
    and Stack.has("nuzlocke.gen3.results"),
    "native whiteout should autosave and lock into final results")
advanceTo("QUIT TO TITLE")
-- Champion path is triggered by completed native HOF induction, NOT a
-- trainer victory. The player can continue after viewing/exporting.
values.gen3_classic_v1={enabled=true,areas={},graveyard={}}
game.session={version="emerald",map="EM_EVER_GRANDE_CITY",
    name="MAY",party={pokemon(1,75,"Flora")},flags={},
    game_cleared=true,hallOfFameTeams={{{species=1,level=55}}}}
events["save.created"]()
Hof.open=true
Hof.close(Hof)
assert(values.gen3_classic_v1.finalResult
    and values.gen3_classic_v1.finalResult.outcome=="VICTORY"
    and values.gen3_classic_v1.failed~=true
    and writes==3 and disk.finalResult.outcome=="VICTORY"
    and Stack.has("nuzlocke.gen3.results"),
    "native Champion induction commits the victory and saves it")
advanceTo("CONTINUE ADVENTURE")
assert(not Stack.has("nuzlocke.gen3.results")
    and values.gen3_classic_v1.failed~=true
    and quits==3, -- only the three failed runs returned to title
    "Champion result must allow continuing without quitting")
print("Gen 3 End Run native save/reload, battle failure and champion: PASS")
