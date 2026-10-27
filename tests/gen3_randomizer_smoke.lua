-- Gen 3 Randomizer phase 1: deterministic and native integration smoke.
local Random = assert(loadfile("gen3_randomizer.lua"))()()
local Pokemon = {
    keyName = function(id)
        return ({[1]="BULBASAUR",[4]="CHARMANDER",[7]="SQUIRTLE",
            [16]="PIDGEY",[25]="PIKACHU"})[id]
    end,
}
local saved = {}
assert(Random.get(saved).seed == 0)
assert(Random.set(saved,"wild",true))
assert(Random.set(saved,"trainers",true))
assert(Random.set(saved,"seed",24681357))
assert(not Random.set(saved,"seed",100000000))
local nativeWild = { species="PIDGEY", speciesId=16, level=5, item="BERRY" }
local ctx = { mapId="FR_ROUTE_1", terrain="grass" }
local chosen = Random.wild(saved,nativeWild,ctx,Pokemon)
assert(chosen ~= nativeWild and chosen.speciesId and chosen.level == 5)
assert(chosen.item == "BERRY" and nativeWild.speciesId == 16)
assert(Random.wild(saved,nativeWild,ctx,Pokemon).species == chosen.species)
local differentMap = Random.wild(saved,nativeWild,
    {mapId="FR_ROUTE_2",terrain="grass"},Pokemon)
assert(differentMap.speciesId,"different map should still produce a valid replacement")
assert(Random.wild(saved,{speciesId=16,level=5,roamer=true},ctx,Pokemon).speciesId==16)
assert(Random.wild(saved,nativeWild,nil,Pokemon)==nativeWild)
local team = {{species="PIKACHU",level=15,heldItem="POTION"},
    {species="PIDGEY",level=17}}
local shuffled = Random.trainers(saved,team,414,Pokemon)
assert(shuffled~=team and #shuffled==2)
assert(shuffled[1].level==15 and shuffled[2].level==17)
assert(shuffled[1].heldItem=="POTION")
assert(team[1].species=="PIKACHU")
assert(Random.trainers(saved,team,414,Pokemon)[1].species==shuffled[1].species)
local preserved = {}
assert(Random.trainers(saved,preserved,414,Pokemon)==preserved)
assert(Random.trainers(saved,team,nil,Pokemon)==team)
Random.set(saved,"wild",false)
assert(Random.wild(saved,nativeWild,ctx,Pokemon)==nativeWild)

-- Runtime native hook wiring: no global math.random, no encounter RNG draw.
package.loaded["src.core.game3.pokemon"] = Pokemon
package.loaded["src.core.game3.battle.experience"] = {
    expForLevel = function(_,level) return level*100 end,
}
local events,hooks,values={},{},{}
local g={generation=3,session={version="firered",
    map="FR_ROUTE_1",party={},flags={}}}
local mod={game=g,exports={},
    save={
        get=function(_,k,def) return values[k] or def end,
        set=function(_,k,v) values[k]=v end,
    },
    events={on=function(_,name,fn) events[name]=fn end},
    hooks={wrap=function(_,name,fn) hooks[name]=fn end},
    read=function(_,path)
        local f=assert(io.open(path,"rb"))
        local s=f:read("*a");f:close();return s
    end,
}
assert(loadfile("gen3_runtime.lua")()(mod)==nil)
local api=mod.exports.gen3_randomizer
assert(api and api.version==1)
assert(api.set("seed",24681357))
assert(api.set("wild",true))
assert(api.set("trainers",true))
local actual=hooks["encounter.species"](function(a) return a end,
    nativeWild,ctx)
assert(actual.speciesId==chosen.speciesId and actual.level==5)
local actualTeam=hooks["trainer.party"](function(_,_,list) return list end,
    "LEADER",414,team)
assert(actualTeam[1].species==shuffled[1].species)
assert(actualTeam[1].level==15 and team[1].species=="PIKACHU")
assert(api.set("wild",false))
assert(hooks["encounter.species"](function(x)return x end,
    nativeWild,ctx)==nativeWild)
print("Gen3 Randomizer phase 1 determinism, safety and native hooks: PASS")
