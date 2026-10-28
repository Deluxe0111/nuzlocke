-- Gen 3 randomiser policy, isolation, species safety and native hooks.
local R = assert(loadfile("gen3_randomizer.lua"))()()
local names = { [1]="ALPHA", [2]="BETA", [3]="GAMMA",
    [4]="DELTA", [5]="EPSILON", [6]="ZETA", [7]="ETA" }
local ids = {}
for id, name in pairs(names) do ids[name] = id end
local P = {
    keyName = function(id) return names[id] end,
    speciesFromName = function(name) return ids[name] end,
    national = function(id) return id end,
    stats = function(id)
        if not names[id] then return nil end
        local n = ({48, 49, 80, 82, 49, 30, 60})[id]
        return {hp=n,atk=n,def=n,spe=n,spa=n,spd=n}
    end,
}
local saved = {}
assert(R.get(saved, "random_encounter_tables") == false)
assert(R.get(saved, "random_trainers") == false)
assert(R.get(saved, "randomizer_seed") == 0)
assert(R.get(saved, "random_trainer_diversity") == 0)
assert(R.get(saved, "random_starter") == false)
assert(R.get(saved, "random_starter_balance") == 0)
assert(R.get(saved, "random_encounter_repetition") == 0)
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
assert(not R.set(saved, "random_trainer_diversity", 1))
assert(not R.set(saved, "random_starter", true))
assert(not R.set(saved, "random_encounter_repetition", 1))
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
    randomizer_seed = 12345678, random_encounter_tables=true,
    random_encounter_balance=1 }}
assert(R.replace(other, P, "ENCOUNTERS", "FR_ROUTE_1:GRASS:1:5", 1)
    == R.replace(recovered, P, "ENCOUNTERS", "FR_ROUTE_1:GRASS:1:5", 1),
    "trainer ON/OFF must not perturb encounters")
-- Candidate exclusion is deterministic and does not disturb existing
-- mappings when Trainer Variety is OFF.
local distinct = {randomizer={
    randomizer_seed=12345678, random_trainers=true,
    random_trainer_diversity=1 }}
local one = R.replace(distinct,P,"TRAINERS","LEADER:1",1)
local two = R.replace(distinct,P,"TRAINERS","LEADER:2",1,nil,nil,
    { [one] = true })
assert(one and two and one ~= two,
    "unique-team mode must exclude already selected replacements")
assert(R.replace(distinct,P,"TRAINERS","LEADER:2",1,nil,nil,
    { [one] = true }) == two,
    "unique-team exclusion must be reproducible without mutable RNG")
-- Optional wild variety tracks original species by habitat, rather than
-- allocating a new replacement at each level / each spawn position.
local variety = {randomizer={randomizer_seed=7654321,
    random_encounter_tables=true,random_encounter_repetition=1}}
local scope = "STEP:FR_ROUTE_1:grass"
local firstWild = R.replace(variety,P,"ENCOUNTERS","FR_ROUTE_1:grass:1:5",
    1,nil,nil,nil,scope,"1")
local sameSource = R.replace(variety,P,"ENCOUNTERS","FR_ROUTE_1:grass:1:20",
    1,nil,nil,nil,scope,"1")
assert(firstWild and sameSource==firstWild,
    "a native species must retain its identity across wild levels")
local differentWild = R.replace(variety,P,"ENCOUNTERS","FR_ROUTE_1:grass:2:7",
    2,nil,nil,nil,scope,"2")
assert(differentWild and differentWild~=firstWild,
    "unique-area variety must avoid allocated replacements when possible")
local otherScope = "OWE:FR_ROUTE_1:land"
local oweWild = R.replace(variety,P,"ENCOUNTERS","OWE:FR_ROUTE_1:land:1",
    1,nil,nil,nil,otherScope,"1")
assert(oweWild and variety.randomizer.encounterAssignments[otherScope]["1"]
    == oweWild, "OWE sources need an independently saved scope")
local replay = {randomizer={randomizer_seed=7654321,
    random_encounter_tables=true,random_encounter_repetition=1,
    encounterAssignments=variety.randomizer.encounterAssignments}}
assert(R.replace(replay,P,"ENCOUNTERS","different level",1,
    nil,nil,nil,scope,"1")==firstWild
    and R.replace(replay,P,"ENCOUNTERS","different source key",2,
        nil,nil,nil,scope,"2")==differentWild,
    "allocated varieties must survive a save/load")
-- A pool restricted to two possible replacements must fall back to
-- repeats after both are used, not alter native species or stop encounters.
local small={randomizer={randomizer_seed=1234,
    random_encounter_tables=true,random_encounter_repetition=1}}
local function onlyTwo(n) return n~=3 and n~=4 and n~=7 end
local slot1=R.replace(small,P,"ENCOUNTERS","slot1",1,nil,onlyTwo,nil,
    "STEP:SMALL:grass","1")
local slot2=R.replace(small,P,"ENCOUNTERS","slot2",2,nil,onlyTwo,nil,
    "STEP:SMALL:grass","2")
local slot3=R.replace(small,P,"ENCOUNTERS","slot3",5,nil,onlyTwo,nil,
    "STEP:SMALL:grass","5")
assert(slot1 and slot2 and slot1~=slot2
    and (slot3==slot1 or slot3==slot2),
    "exhausted wild variety must repeat a safe candidate")
assert(R.replace(small,P,"ENCOUNTERS","slot1 new level",1,nil,onlyTwo,nil,
    "STEP:SMALL:grass","1")==slot1,
    "exhaustion must not mutate existing replacements")
local normal={randomizer={randomizer_seed=1234,
    random_encounter_tables=true}}
local normal1=R.replace(normal,P,"ENCOUNTERS","same legacy key",1)
local normal2=R.replace(normal,P,"ENCOUNTERS","same legacy key",1,
    nil,nil,nil,"STEP:SMALL:grass","1")
assert(normal1==normal2 and normal.randomizer.encounterAssignments==nil,
    "NORMAL mode must be byte-for-byte equivalent and save no mappings")
-- Atomic starter trio: same seed/ROM yields same three unique species,
-- irrespective of wild/trainer stream history, and survives save/load.
local starterSave = {randomizer={randomizer_seed=17171717,
    random_starter=true}}
local trio = R.starters(starterSave,P,"frlg",{1,2,3})
assert(trio and #trio==3 and trio[1]~=trio[2]
    and trio[2]~=trio[3] and trio[1]~=trio[3],
    "starter randomiser must produce a distinct three-choice trio")
assert(R.locked(starterSave))
assert(not R.set(starterSave,"random_starter_balance",1))
local prior = {trio[1],trio[2],trio[3]}
assert(R.starters(starterSave,P,"frlg",{1,2,3})[2] == prior[2])
local starterReplay = {randomizer={randomizer_seed=17171717,
    random_starter=true}}
local replayTrio=R.starters(starterReplay,P,"frlg",{1,2,3})
for i=1,3 do assert(replayTrio[i]==prior[i]) end
assert(R.starters(starterSave,P,"rse",{1,2,3})==nil,
    "a starter trio must not leak across game families")
local starterBlocked={randomizer={randomizer_seed=17,
    random_starter=true}}
assert(not R.starters(starterBlocked,P,"frlg",{1,2,3},nil,
    function(n) return n~=6 and n~=5 end),
    "missing a third safe starter must fail open as one trio")
assert(not R.locked(starterBlocked) and
    starterBlocked.randomizer.starterOptions==nil)
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

-- PKMN BAN is a hard candidate exclusion in Nuzlocke-owned
-- randomizer pools (both wild and trainer). The deterministic stream
-- must never select a banned National Dex species.
local C=assert(loadfile("gen3_catch_rules.lua"))()()
local banSave={randomizer={randomizer_seed=87654,
    random_encounter_tables=true,random_trainers=true}}
assert(C.toggleNational(banSave,2))
assert(C.toggleNational(banSave,3))
assert(C.toggleNational(banSave,4))
assert(C.toggleNational(banSave,5))
assert(C.toggleNational(banSave,7))
local function bannedNat(nat) return C.isBannedNational(banSave,nat) end
for _,source in ipairs({"ENCOUNTERS","TRAINERS"}) do
    local chosen=R.replace(banSave,P,source,"ban-pool-test",1,nil,bannedNat)
    assert(chosen==6,"only unbanned candidate should be selected")
end
assert(R.replace(banSave,P,"ENCOUNTERS","depleted",1,nil,
    function()return true end)==nil,
    "fully banned replacement pool leaves native original unchanged")

-- Runtime hook integration: compose downstream rules, retain levels/metadata.
package.loaded["src.core.game3.pokemon"] = P
local starterView={species={1,2,3}}
local starterChooser={
    manifest=function() return starterView end,
    species=function(man,sel) return (man or starterView).species[sel+1] end,
}
package.loaded["src.ui.game3.rse.starter_choose"]=starterChooser
local starterQuery={
    BY_NAME={GetStarterSpecies=function()
        return false, 1
    end}
}
package.loaded["src.core.game3.scripting.natives_queries"]=starterQuery
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
assert(api.set("random_starter", true))
assert(api.set("random_encounter_tables", true))
assert(api.set("random_encounter_repetition", 1))
assert(api.set("random_trainers", true))
assert(api.set("random_trainer_diversity", 1))
-- RSE UI and native gift must call the same resolver.
game.session.version="emerald"
local rseStarter=starterChooser.species(nil,0)
assert(rseStarter and rseStarter~=1
    and starterChooser.species(nil,0)==rseStarter)
assert(starterChooser.species(nil,1)~=rseStarter)
local rseOpts=saves.gen3_classic_v1.randomizer.starterOptions
assert(rseOpts[1]==rseStarter
    and starterChooser.species(nil,2)==rseOpts[3])
-- Native FireRed selection passes through the GetStarterSpecies special,
-- and the normal before_give event selects the same persistent result.
-- New disposable state for a separate game's starter trio.
saves.gen3_classic_v1.randomizer.starterOptions=nil
saves.gen3_classic_v1.randomizer.starterSource=nil
saves.gen3_classic_v1.randomizer.used=false
game.session.version="firered"
game.session.map="FR_PALLET_TOWN_PROFESSOR_OAKS_LAB"
local _,frlgStarter=starterQuery.BY_NAME.GetStarterSpecies({})
assert(frlgStarter and frlgStarter~=1)
local gift={speciesId=1,species="ALPHA",level=5}
handlers["pokemon.before_give"](gift)
assert(gift.species==frlgStarter,
    "Kanto starter chooser and acquired Pokemon must agree")
game.session.map="FR_ROUTE_1"
local ordinaryGift={speciesId=1,species="ALPHA",level=5}
handlers["pokemon.before_give"](ordinaryGift)
assert(ordinaryGift.species=="ALPHA",
    "other maps must not randomise gifted Pokemon")
local count=0
local wild={species="ALPHA",speciesId=1,level=7,item="BERRY"}
local ctx={mapId="FR_ROUTE_1",terrain="grass"}
local function downstream(v) count=count+1;return v end
local first=hooks["encounter.species"](downstream,wild,ctx)
assert(first.speciesId ~= 1 and first.level == 7 and first.item=="BERRY")
assert(wild.speciesId == 1, "native encounter object must not mutate")
assert(hooks["encounter.species"](downstream,wild,ctx).speciesId == first.speciesId)
assert(count==2,"compose downstream provider exactly once")
-- Opening rival uses the paired randomised starter when the trainer
-- source is a known first-rival single species.
local rivalOut=hooks["trainer.party"](function(_,_,p) return p end,
    "RIVAL",326,{{species=1,level=5}})
assert(rivalOut[1].speciesId==frlgStarter,
    "first rival must use the persistent random starter map")
local wildAltLevel=hooks["encounter.species"](downstream,
    {species="ALPHA",speciesId=1,level=18,item="BERRY"},ctx)
assert(wildAltLevel.speciesId==first.speciesId,
    "wild variety must keep the same native species across levels")
local secondWild=hooks["encounter.species"](downstream,
    {species="BETA",speciesId=2,level=7},ctx)
assert(secondWild.speciesId and secondWild.speciesId~=first.speciesId,
    "second source in same grass scope should use a different replacement")
assert(saves.gen3_classic_v1.randomizer.encounterAssignments
    ["STEP:FR_ROUTE_1:grass"]["1"]==first.speciesId,
    "assigned wild species must be persisted with the run state")
-- Untamed-Advanced does not call encounter.species. It calls a separate
-- opt-in hook before its visible sprite and battle enemy are constructed.
local owctx={source="untamed_advanced",mapId="FR_ROUTE_1",
    terrain="land",x=4,y=7}
local ow={species=1,level=8,item="BERRY"}
local called=0
local function nextOwe(enc, origin)
    called=called+1
    assert(origin == nil or type(origin)=="table")
    return enc
end
local rendered=hooks["untamed.owe.species"](nextOwe,ow,owctx)
assert(called==1 and rendered~=ow and rendered.species~=1
    and rendered.level==8 and rendered.item=="BERRY"
    and ow.species==1, "visible OWE must randomise without mutating input")
local second=hooks["untamed.owe.species"](nextOwe,ow,
    {source="untamed_advanced",mapId="FR_ROUTE_1",
    terrain="land",x=12,y=1})
assert(second.species==rendered.species,
    "same original species/route must be deterministic across spawn tiles")
local otherOwe=hooks["untamed.owe.species"](nextOwe,
    {species=2,level=9},owctx)
assert(otherOwe.species and otherOwe.species~=rendered.species,
    "Untamed should avoid repeats for distinct native overworld sources")
assert(api.effectiveSeed()==12345678)
local wrongProvider={species=1,level=8}
assert(hooks["untamed.owe.species"](nextOwe,wrongProvider,
    {source="some_other_mod",mapId="FR_ROUTE_1",terrain="land"})
    == wrongProvider, "do not claim unrelated providers")
local fakeRoamer={species=1,level=8,roamer=true}
assert(hooks["untamed.owe.species"](nextOwe,fakeRoamer,owctx)
    == fakeRoamer, "special roamers cannot be rewritten")
assert(hooks["untamed.owe.species"](nextOwe,ow,nil)==ow,
    "missing context fails open")
assert(hooks["untamed.owe.species"](nextOwe,ow,
    {source="untamed_advanced",mapId="FR_ROUTE_1",terrain="cave"})
    == ow, "only Untamed land/water wild slots can be randomised")
local fish={species="ALPHA",speciesId=1,level=9}
local f=hooks["encounter.fishing"](function() return fish end,
    "OLD_ROD","FR_ROUTE_1",{})
assert(f.speciesId ~= 1 and f.level == 9 and fish.speciesId == 1)
local f2=hooks["encounter.fishing"](function() return
    {species="BETA",speciesId=2,level=11} end,
    "OLD_ROD","FR_ROUTE_1",{})
assert(f2.speciesId and f2.speciesId~=f.speciesId,
    "fishing variety should exclude replacements used by the same rod")
local trainerParty={
    {species="ALPHA",speciesId=1,level=13,moves={"TACKLE"}},
    {species="BETA",speciesId=2,level=15,heldItem="POTION"},
}
local out=hooks["trainer.party"](function(_,_,party)
    return party end,"LEADER",414,trainerParty)
assert(#out==2 and out[1].speciesId ~= 1 and out[2].speciesId ~= 2)
assert(out[1].speciesId ~= out[2].speciesId,
    "Trainer Variety should avoid duplicate team replacements")
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
local stack = {}
package.loaded["src.ui.game3.stack"] = {
    push = function(id, module) stack[#stack + 1] = {id=id,module=module} end,
    pop = function(id)
        assert(stack[#stack] and stack[#stack].id == id)
        stack[#stack] = nil
    end,
}
assert(mod.exports.gen3_menu.open(game))
local function press(key)
    local top=assert(stack[#stack])
    top.module.handleInput({
        wasPressed=function(_,button) return button==key end
    })
end
press("a") -- NUZ RULES
local cat=mod.exports.gen3_menu.catalog()
local catalogHasRandomizer=false
for _,c in ipairs(cat) do
    if c.title=="RANDOMIZER" then catalogHasRandomizer=true end
end
assert(catalogHasRandomizer,"randomiser category remains in legacy catalog")
-- Navigation must use the actual displayed menu, not the catalog index.
-- Advanced Rules collapses nine catalog entries into one visible row.
local position
for i,label in ipairs(mod.exports.gen3_menu.model().rows) do
    if label=="RANDOMIZER" then position=i end
end
assert(position,"RANDOMIZER must remain accessible on the rules menu")
for i=2,position do press("down") end
press("a")
local model=mod.exports.gen3_menu.model()
assert(model.title=="RANDOMIZER"
    and model.rows[1]:find("PRESET",1,true)
    and model.rows[2]=="RANDOM WILD: ON"
    and model.rows[3]=="RANDOM TRAINERS: ON"
    and model.rows[4]=="RANDOM STARTERS: ON"
    and model.rows[5]=="STARTER BALANCE: CHAOS"
    and model.rows[7]=="WILD VARIETY: UNIQUE AREA",
    "Randomiser menu must expose working settings")
local soon=false
for _,label in ipairs(model.rows) do
    if label=="[Soon] Rndm Strtr" then soon=true end
end
assert(soon,"unimplemented starter randomiser must stay [Soon]")
press("b");press("b");press("b")
assert(#stack==0)
-- Disposable test state: simulate a fresh run so the seed editor is writable.
saves.gen3_classic_v1.randomizer.used = false
assert(mod.exports.gen3_menu.open(game))
press("a")
for i=2,position do press("down") end
press("a")
local rngPage=mod.exports.gen3_menu.model()
local seedRow
for i,label in ipairs(rngPage.rows) do
    if label:sub(1,5)=="SEED:" then seedRow=i end
end
assert(seedRow and rngPage.rows[seedRow]=="SEED: 12345678")
for i=2,seedRow do press("down") end
press("a")
assert(mod.exports.gen3_menu.model().title=="EDIT RNG SEED")
press("down") -- first digit
press("a") -- 1 becomes 2
assert(mod.exports.gen3_menu.model().rows[1]=="SEED: 22345678")
for i=1,8 do press("down") end -- APPLY SEED
press("a")
assert(api.get("randomizer_seed")==22345678,
    "eight-digit seed editor must apply the exact chosen value")
press("b");press("b");press("b")
assert(#stack==0)
print("Gen3 randomiser policy, native hooks, seed editor and menu: PASS")
