-- Gen 3 randomiser policy, isolation, species safety and native hooks.
local R = assert(loadfile("gen3_randomizer.lua"))()()
local names = { [1]="ALPHA", [2]="BETA", [3]="GAMMA",
    [4]="DELTA", [5]="EPSILON", [6]="ZETA" }
local ids = {}
for id, name in pairs(names) do ids[name] = id end
local P = {
    keyName = function(id) return names[id] end,
    speciesFromName = function(name) return ids[name] end,
    national = function(id) return id end,
    stats = function(id)
        if not names[id] then return nil end
        local n = ({48, 49, 80, 82, 49, 30})[id]
        return {hp=n,atk=n,def=n,spe=n,spa=n,spd=n}
    end,
}
local saved = {}
assert(R.get(saved, "random_encounter_tables") == false)
assert(R.get(saved, "random_trainers") == false)
assert(R.get(saved, "randomizer_seed") == 0)
assert(R.set(saved, "randomizer_seed", 12345678))
assert(R.set(saved, "random_encounter_tables", true))
assert(R.set(saved, "random_trainers", true))
assert(R.set(saved, "random_encounter_balance", 1))
assert(R.set(saved, "random_trainer_balance", 1))
assert(R.set(saved, "random_species_generation", 0))
assert(R.seed(saved) == 12345678)
local a, aname = R.replace(saved, P, "ENCOUNTERS", "FR_ROUTE_1:GRASS:1:5", 1)
assert(a and a ~= 1 and names[a] == aname)
local b = R.replace(saved, P, "TRAINERS", "RIVAL:326:1:1", 1)
assert(b and b ~= 1)
for i=1,4 do
    assert(R.replace(saved, P, "ENCOUNTERS", "FR_ROUTE_1:GRASS:1:5", 1) == a)
end
assert(R.locked(saved))
assert(not R.set(saved, "randomizer_seed", 999),
    "fixed randomiser settings cannot change after species results exist")
assert(not R.set(saved, "random_trainers", false))
local recovered = {randomizer = {
    randomizer_seed = 12345678, random_encounter_tables=true,
    random_trainers=true, random_encounter_balance=1,
    random_trainer_balance=1,
}}
assert(R.replace(recovered, P, "ENCOUNTERS",
    "FR_ROUTE_1:GRASS:1:5", 1) == a,
    "same seed/source/settings must reproduce on reload")
assert(R.replace(recovered, P, "TRAINERS", "RIVAL:326:1:1", 1) == b,
    "trainer stream must not depend on wild stream order")
local other = {randomizer = {
    randomizer_seed = 12345678, random_encounter_tables=true }}
assert(R.replace(other, P, "ENCOUNTERS", "FR_ROUTE_1:GRASS:1:5", 1)
    == R.replace(recovered, P, "ENCOUNTERS", "FR_ROUTE_1:GRASS:1:5", 1),
    "trainer ON/OFF must not perturb encounters")
local empty = {randomizer={ randomizer_seed=99,
    random_encounter_tables=true }}
assert(not R.replace(empty, P, "ENCOUNTERS", "route", 511),
    "unsupported species fail open")
assert(not R.locked(empty))
local auto = {randomizer={random_encounter_tables=true}}
local rolled = 0
local id = R.replace(auto, P, "ENCOUNTERS", "route", 1,
    function() rolled=rolled+1; return 923749 end)
assert(id and rolled == 1 and R.seed(auto) == 923750)
R.replace(auto, P, "ENCOUNTERS", "other", 1,
    function() rolled=rolled+1; return 99 end)
assert(rolled == 1, "AUTO seed resolved once, without global RNG each roll")
local preset = {}
assert(R.set(preset, "randomizer_preset", 2))
assert(R.get(preset,"random_encounter_tables") == true)
assert(R.get(preset,"random_trainers") == true)
assert(R.get(preset,"random_encounter_balance") == 1)
assert(R.get(preset,"random_trainer_balance") == 1)
assert(R.set(preset,"random_trainers",false))
assert(R.get(preset,"randomizer_preset") == 0)
assert(R.set(preset,"random_species_generation",3))
local hoenn = R.replace(preset, P, "ENCOUNTERS", "FR_ROUTE_1", 1,
    function() return 123 end)
assert(not hoenn and not R.locked(preset),
    "generation filter with empty safe pool leaves native intact")

-- Runtime hook integration: compose downstream rules, retain levels/metadata.
package.loaded["src.core.game3.pokemon"] = P
local handlers, hooks, saves = {}, {}, {}
local game = {generation=3, session={map="FR_ROUTE_1",
    version="firered",party={{species=1,hp=14,personality=4}},flags={}}}
local mod = {game=game,exports={},
    save = {
        get=function(_,key,default) return saves[key] or default end,
        set=function(_,key,value) saves[key]=value end,
    },
    events = {on=function(_,name,fn) handlers[name]=fn end},
    hooks = {wrap=function(_,name,fn) hooks[name]=fn end},
    read = function(_,path)
        local f=assert(io.open(path,"rb"));local txt=f:read("*a");f:close()
        return txt
    end,
}
assert(loadfile("gen3_runtime.lua")()(mod) == nil)
local api=mod.exports.gen3_randomizer
assert(api.set("randomizer_seed", 12345678))
assert(api.set("random_encounter_tables", true))
assert(api.set("random_trainers", true))
local count=0
local wild={species="ALPHA",speciesId=1,level=7,item="BERRY"}
local ctx={mapId="FR_ROUTE_1",terrain="grass"}
local function downstream(v) count=count+1;return v end
local first=hooks["encounter.species"](downstream,wild,ctx)
assert(first.speciesId ~= 1 and first.level == 7 and first.item=="BERRY")
assert(wild.speciesId == 1, "native encounter object must not mutate")
assert(hooks["encounter.species"](downstream,wild,ctx).speciesId == first.speciesId)
assert(count==2,"compose downstream provider exactly once")
local fish={species="ALPHA",speciesId=1,level=9}
local f=hooks["encounter.fishing"](function() return fish end,
    "OLD_ROD","FR_ROUTE_1",{})
assert(f.speciesId ~= 1 and f.level == 9 and fish.speciesId == 1)
local trainerParty={
    {species="ALPHA",speciesId=1,level=13,moves={"TACKLE"}},
    {species="BETA",speciesId=2,level=15,heldItem="POTION"},
}
local out=hooks["trainer.party"](function(_,_,party)
    return party end,"LEADER",414,trainerParty)
assert(#out==2 and out[1].speciesId ~= 1 and out[2].speciesId ~= 2)
assert(out[1].level==13 and out[2].heldItem=="POTION"
    and out[1].moves[1]=="TACKLE")
assert(trainerParty[1].speciesId==1 and trainerParty[2].speciesId==2)
assert(api.locked() and api.effectiveSeed()==12345678)
assert(not api.set("random_trainer_balance", 1))
assert(#mod.exports.gen3_notices.history()>0,
    "player gets randomiser-lock explanation")
local unchanged=hooks["encounter.species"](downstream,
    {species="ALPHA",speciesId=1,level=6,roamer=true},ctx)
assert(unchanged.speciesId==1,"roamers must retain persistent identity")
local invalid=hooks["encounter.species"](downstream,wild,nil)
assert(invalid.speciesId==1)
-- Non-Gen3 / Nuzlocke-off is irrelevant: randomiser operates independently.
assert(not saves.gen3_classic_v1.enabled)
assert(first.speciesId ~= 1)
print("Gen3 randomiser policy and native wild/fishing/trainer hooks: PASS")
