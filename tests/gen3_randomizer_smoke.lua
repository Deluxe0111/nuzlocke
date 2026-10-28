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
assert(R.get(saved, "random_static_pokemon") == false)
assert(R.get(saved, "random_gift_pokemon") == false)
assert(R.get(saved, "random_egg_gifts") == false)
assert(R.get(saved, "random_shops") == false)
assert(R.get(saved, "random_shop_balance") == 0)
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
assert(not R.set(saved, "random_static_pokemon", true))
assert(not R.set(saved, "random_shops", true))
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
-- Independent scripted encounter/gift streams, deterministic on reload
-- and not accidentally tied to ordinary wild/trainer randomisation.
local sources = {
    {"STATIC","random_static_pokemon"},
    {"GIFTS","random_gift_pokemon"},
    {"EGG_GIFTS","random_egg_gifts"},
}
for _,spec in ipairs(sources) do
    local source,toggle=spec[1],spec[2]
    local cfg={randomizer={randomizer_seed=832141,
        [toggle]=true}}
    local key="FR_MT_MOON:SCRIPT:S1:5"
    local replacement=R.replace(cfg,P,source,key,1)
    assert(replacement and replacement~=1
        and cfg.randomizer.used==true,
        "scripted stream should roll a safe replacement")
    assert(R.replace(cfg,P,source,key,1)==replacement,
        "scripted slot must not reroll")
    local replayCfg={randomizer={randomizer_seed=832141,
        [toggle]=true}}
    assert(R.replace(replayCfg,P,source,key,1)==replacement,
        "scripted stream must be stable after load")
    local disabled={randomizer={randomizer_seed=832141}}
    assert(R.replace(disabled,P,source,key,1)==nil,
        "scripted streams default OFF")
    assert(R.replace(cfg,P,source,key,1,nil,
        function()return true end)==nil,
        "a fully banned scripted pool must fail open")
end
-- Item randomisation uses only safe, buyable items from the loaded
-- native ROM pack. Important items/TMs/zero-price holes are excluded.
local itemMeta={
    [4]={id=4,name="Poke Ball",pocket="POKE_BALLS",price=200},
    [13]={id=13,name="Potion",pocket="ITEMS",price=300},
    [14]={id=14,name="Antidote",pocket="ITEMS",price=100},
    [15]={id=15,name="Burn Heal",pocket="ITEMS",price=250},
    [21]={id=21,name="Hyper Potion",pocket="ITEMS",price=1200},
    [50]={id=50,name="Ether",pocket="ITEMS",price=600},
    [139]={id=139,name="Oran Berry",pocket="BERRY_POUCH",price=200},
    [261]={id=261,name="Itemfinder",pocket="KEY_ITEMS",price=500},
    [289]={id=289,name="TM01",pocket="TM_CASE",price=3000},
    [1]={id=1,name="Master Ball",pocket="POKE_BALLS",price=0},
    [70]={id=70,name="Story Relic",pocket="ITEMS",price=900,
        importance=1},
}
local itemPack={}
for id in pairs(itemMeta) do itemPack[id]=true end
local ItemsData={
    ensureLoaded=function()return itemPack end,
    info=function(id)return itemMeta[id] end,
}
local safeItemRun={randomizer={random_field_items=true,
    randomizer_seed=12345678}}
local firstItem=R.item(safeItemRun,ItemsData,
    "VISIBLE:FR_ROUTE_1:BALL_A:13",13,nil,"MAP:FR_ROUTE_1")
assert(firstItem and firstItem~=13
    and itemMeta[firstItem].pocket~="KEY_ITEMS"
    and firstItem~=289 and firstItem~=70 and firstItem~=1)
assert(R.item(safeItemRun,ItemsData,
    "VISIBLE:FR_ROUTE_1:BALL_A:13",13,nil,"MAP:FR_ROUTE_1")==firstItem,
    "pickup must keep its replacement")
assert(R.locked(safeItemRun))
assert(not R.set(safeItemRun,"random_field_item_balance",1))
local itemSaveReplay={randomizer={random_field_items=true,
    randomizer_seed=12345678,
    fieldItemAssignments=safeItemRun.randomizer.fieldItemAssignments}}
assert(R.item(itemSaveReplay,ItemsData,
    "VISIBLE:FR_ROUTE_1:BALL_A:13",13,nil,"MAP:FR_ROUTE_1")==firstItem,
    "item identity must persist across save/load")
local itemFreshReplay={randomizer={random_field_items=true,
    randomizer_seed=12345678}}
assert(R.item(itemFreshReplay,ItemsData,
    "VISIBLE:FR_ROUTE_1:BALL_A:13",13,nil,"MAP:FR_ROUTE_1")==firstItem,
    "fixed seed should reproduce pickup independently")
for _,id in ipairs({1,261,289,70,9999}) do
    assert(R.item({randomizer={random_field_items=true,
        randomizer_seed=42}},ItemsData,"STORY:"..id,id,nil,
        "MAP:FR_ROUTE_1")==nil,
        "protected and unsupported originals must stay native")
end
assert(R.item({randomizer={random_field_items=false,
    randomizer_seed=42}},ItemsData,"ID",13,nil,"MAP:FR_ROUTE_1")==nil)
local similar={randomizer={random_field_items=true,
    random_field_item_balance=1,randomizer_seed=314159}}
local similarResult=R.item(similar,ItemsData,"PICKUP",13,nil,
    "MAP:FR_ROUTE_1")
assert(similarResult and math.abs(itemMeta[similarResult].price-300)<=100,
    "SIM VALUE must prefer approximately similar-price items")
local uniqueItems={randomizer={random_field_items=true,
    random_field_item_repetition=1,randomizer_seed=775533}}
local uniqueA=R.item(uniqueItems,ItemsData,"BALL_A",13,nil,"MAP:ROUTE")
local uniqueB=R.item(uniqueItems,ItemsData,"HIDDEN_B",13,nil,"MAP:ROUTE")
assert(uniqueA and uniqueB and uniqueA~=uniqueB,
    "UNIQUE AREA must avoid duplicates across visible and hidden")
assert(R.item(uniqueItems,ItemsData,"BALL_A",13,nil,"MAP:ROUTE")==uniqueA)
local otherMap=R.item(uniqueItems,ItemsData,"BALL_A",13,nil,"MAP:NEXT")
assert(otherMap and uniqueItems.randomizer.fieldItemAssignments["MAP:NEXT"],
    "area variety must remain scoped per map")
-- Shop stock randomisation: real mart item lists only, with original
-- Poké Balls and progression-critical stock protected.
local originalMart={4,13,14,21,261,289}
local shopState={randomizer={random_shops=true,randomizer_seed=12345678}}
local sourceMart="MAP:FR_ROUTE_1:MART:0xCAFEBABE"
local mart=R.shop(shopState,ItemsData,sourceMart,originalMart)
assert(mart and #mart==#originalMart
    and mart[1]==4 and mart[5]==261 and mart[6]==289
    and originalMart[2]==13 and R.locked(shopState),
    "mart source stock must be untouched and key stock preserved")
local uniqueStock={}
local modified=0
for i,id in ipairs(mart) do
    assert(not uniqueStock[id],"shop replacement list has duplicates")
    uniqueStock[id]=true
    if id~=originalMart[i] then modified=modified+1 end
end
assert(modified>0)
local replayStock=R.shop(shopState,ItemsData,sourceMart,originalMart)
for i=1,#mart do assert(replayStock[i]==mart[i]) end
assert(replayStock~=mart, "shop result must be cloned per open")
local reloadState={randomizer={
    random_shops=true,randomizer_seed=12345678,
    shopAssignments=shopState.randomizer.shopAssignments}}
local reloadStock=R.shop(reloadState,ItemsData,sourceMart,originalMart)
for i=1,#mart do assert(reloadStock[i]==mart[i]) end
local replayFresh={randomizer={random_shops=true,randomizer_seed=12345678}}
local freshStock=R.shop(replayFresh,ItemsData,sourceMart,originalMart)
for i=1,#mart do assert(freshStock[i]==mart[i]) end
assert(not R.set(shopState,"random_shop_balance",1),
    "shop result must lock run settings")
assert(R.shop({randomizer={randomizer_seed=99}},ItemsData,
    sourceMart,originalMart)==nil, "shops default OFF")
assert(R.shop({randomizer={random_shops=true,randomizer_seed=99}},
    ItemsData,"",originalMart)==nil, "missing native pointer fails open")
assert(R.shop({randomizer={random_shops=true,randomizer_seed=99}},
    ItemsData,sourceMart,{4,289,261})==nil,
    "protected-only stock must remain native")
local simShop=R.shop({randomizer={random_shops=true,
    random_shop_balance=1,randomizer_seed=1991}},
    ItemsData,"MAP:SIM:MART:1",{4,13,261})
assert(simShop and simShop[1]==4 and simShop[3]==261
    and math.abs(itemMeta[simShop[2]].price-300)<=100,
    "SIM VALUE should use a close-priced, valid item")
local badStock={randomizer={random_shops=true,randomizer_seed=12345678,
    shopAssignments=shopState.randomizer.shopAssignments}}
assert(R.shop(badStock,ItemsData,sourceMart,{4,13,14,50,261,289})
    ==nil, "saved stock must never be reused against a changed native list")
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
local function onlyTwo(n) return n~=3 and n~=4 end
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

-- A separate ROM-shaped registry validates evolution stages without
-- disturbing established randomiser seeds/pool mock sizes.
local EvoP = {
    national = function(id) if id >= 1 and id <= 16 then return id end end,
    keyName = function(id)
        if id >= 1 and id <= 16 then return "EV" .. tostring(id) end
    end,
    speciesFromName = function(name)
        return tonumber(tostring(name):match("^EV(%d+)$"))
    end,
    stats = function(id)
        if id < 1 or id > 16 then return nil end
        return {hp=60,atk=60,def=60,spe=60,spa=60,spd=60}
    end,
    evolutions = function(id)
        local paths = {
            [1] = {{method=4,param=16,target=2}},
            [2] = {{method=4,param=36,target=3}},
            [4] = {{method=4,param=16,target=5}},
            [5] = {{method=4,param=36,target=6}},
            [7] = {{method=4,param=16,target=8},
                   {method=7,param=1,target=9}},
            [8] = {{method=4,param=36,target=10}},
            [9] = {{method=4,param=36,target=11}},
            [12] = {{method=4,param=16,target=13}},
            [13] = {{method=4,param=36,target=14}},
        }
        return paths[id] or {}
    end,
}
local evoRun = {randomizer={random_starter=true,
    starterSource="frlg",starterOptions={7,4,15},
    randomizer_seed=991234}}
local bases = {1,4,12}
local function mapped(original)
    local id,key,slot,stage=R.rivalStarter(evoRun,EvoP,
        "frlg",bases,original)
    return id,key,slot,stage
end
assert(mapped(1)==7 and mapped(4)==4 and mapped(12)==15,
    "rival's first battle must use the saved starter options")
local middle,_,slot,stage=mapped(2)
assert((middle==8 or middle==9) and slot==1 and stage==1,
    "middle rival battle must follow a real branch of the new starter")
local final=mapped(3)
assert((middle==8 and final==10) or (middle==9 and final==11),
    "final rival battle must follow the SAME deterministic branch")
assert(mapped(5)==5 and mapped(6)==6,
    "second starter must advance through its two native stages")
assert(mapped(13)==15 and mapped(14)==15,
    "single-stage replacement must not invent evolutions")
assert(mapped(3)==final and mapped(2)==middle,
    "replayed rival battles must not reroll the lineage")
assert(mapped(16)==nil,
    "non-starter native party members must not be replaced by lineage")
assert(R.rivalStarter({randomizer={random_starter=false}},EvoP,
    "frlg",bases,1)==nil,
    "Random Starters OFF must not touch rival lineages")
local hoennRun={randomizer={random_starter=true,starterSource="rse",
    starterOptions={7,4,15},randomizer_seed=991234}}
assert(R.rivalStarter(hoennRun,EvoP,"rse",bases,3)==final,
    "Hoenn rival lineage must independently match original evolution")
assert(R.rivalStarter(evoRun,EvoP,"rse",bases,1)==nil,
    "trio must never leak between game families")
-- Runtime hook integration: compose downstream rules, retain levels/metadata.
package.loaded["src.core.game3.pokemon"] = P
package.loaded["src.core.game3.items_data"] = ItemsData
local fieldReceipts={}
local FakeField={
    pickUpHiddenItem=function(g,hidden)
        fieldReceipts[#fieldReceipts+1]={method="pickup",record=hidden}
        return true
    end,
    digUpUnderfootItem=function(g,hidden)
        fieldReceipts[#fieldReceipts+1]={method="underfoot",record=hidden}
        return true
    end,
}
package.loaded["src.core.game3.field"]=FakeField
local shopOpenings={}
local FakeShop={open=false,
    show=function(opts)
        shopOpenings[#shopOpenings+1]=opts
        return "shop_opened"
    end,
    handleInput=function() return "native_action" end,
}
local romMart={4,13,14,21,261,289}
local romMartEntry={ptr=3735928559,items=romMart,martType="NORMAL"}
package.loaded["src.ui.game3.shop_menu"]=FakeShop
package.loaded["src.core.game3.marts"]={
    _byKey={[romMartEntry.ptr]=romMartEntry}}
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
assert(api.set("random_static_pokemon", true))
assert(api.set("random_gift_pokemon", true))
assert(api.set("random_egg_gifts", true))
assert(api.set("random_field_items", true))
assert(api.set("random_shops", true))
assert(api.set("random_encounter_tables", true))
assert(api.set("random_encounter_repetition", 1))
assert(api.set("random_trainers", true))
assert(api.set("random_trainer_diversity", 1))
-- Shop.show is the native inventory display/transaction boundary.
-- Install via the normal map-entered lifecycle, not manual hook calls.
assert(type(handlers["map.entered"])=="function")
handlers["map.entered"]({mapId="FR_ROUTE_1"})
assert(FakeShop.show({items=romMart,session=game.session})=="shop_opened")
local firstShop=shopOpenings[#shopOpenings]
assert(firstShop.items~=romMart and firstShop.mart~=romMartEntry
    and firstShop.mart.items==firstShop.items
    and firstShop.items[1]==4 and firstShop.items[5]==261
    and firstShop.items[6]==289 and romMart[2]==13,
    "native mart must receive independent shop stock for display/purchases")
FakeShop.show({items=romMart,session=game.session})
local secondShop=shopOpenings[#shopOpenings]
for i=1,#romMart do assert(secondShop.items[i]==firstShop.items[i]) end
assert(FakeShop.show({items=romMart,session=game.session,
    martType="DECOR"})=="shop_opened")
assert(shopOpenings[#shopOpenings].items==romMart,
    "decoration shops must preserve their separate namespace")
local unknownMart={3,2,1}
FakeShop.show({items=unknownMart,session=game.session})
assert(shopOpenings[#shopOpenings].items==unknownMart,
    "unidentifiable mart pointer must fail open")
-- RSE UI and native gift must call the same resolver.
game.session.version="emerald"
local rseStarter=starterChooser.species(nil,0)
assert(rseStarter and rseStarter~=1
    and starterChooser.species(nil,0)==rseStarter)
assert(starterChooser.species(nil,1)~=rseStarter)
local rseOpts=saves.gen3_classic_v1.randomizer.starterOptions
assert(rseOpts[1]==rseStarter
    and starterChooser.species(nil,2)==rseOpts[3])
-- Native FireRed selection sets Oak's temporary starter variables
-- before showmonpic and givemon; test that earliest safe boundary.
-- New disposable state for a separate game's starter trio.
saves.gen3_classic_v1.randomizer.starterOptions=nil
saves.gen3_classic_v1.randomizer.starterSource=nil
saves.gen3_classic_v1.randomizer.used=false
game.session.version="firered"
game.session.map="FR_PALLET_TOWN_PROFESSOR_OAKS_LAB"
local savedParty=game.session.party
game.session.party={} -- Oak's scripted gift occurs before the first party mon.
local _,frlgStarter=starterQuery.BY_NAME.GetStarterSpecies({})
assert(frlgStarter and frlgStarter~=1)
local originalScript={op="setvar",[1]=0x4002,[2]=1}
local seenScript
local function nativeScript(_, op, row)
    seenScript=row
    return false
end
hooks["script.command"](nativeScript,{}, "setvar",originalScript)
assert(seenScript~=originalScript and seenScript[2]==frlgStarter
    and originalScript[2]==1,
    "Oak script's portrait and givemon source must be randomised")
local rivalScript={op="setvar",[1]=0x4003,[2]=4}
hooks["script.command"](nativeScript,{}, "setvar",rivalScript)
assert(seenScript[2]~=4 and rivalScript[2]==4,
    "Oak's rival-choice dialogue should use the matching random option")
game.session.map="FR_ROUTE_1"
hooks["script.command"](nativeScript,{}, "setvar",originalScript)
assert(seenScript==originalScript,
    "other maps must not intercept scripted species variables")
game.session.party=savedParty
-- The script-command seam must work with Nuzlocke OFF and clone native
-- opcode rows, preserving levels/items. Each category is independent.
game.session.map="FR_MT_MOON"
local originalStatic={op="setwildbattle",[1]=1,[2]=30,[3]=88}
hooks["script.command"](nativeScript,{}, "setwildbattle",originalStatic)
assert(seenScript~=originalStatic and seenScript[1]~=1
    and seenScript[2]==30 and seenScript[3]==88
    and originalStatic[1]==1,
    "scripted wild must mutate only its cloned species operand")
local staticResult=seenScript[1]
hooks["script.command"](nativeScript,{}, "setwildbattle",originalStatic)
assert(seenScript[1]==staticResult,
    "scripted wild must keep its species across repeat runs")
local originalGift={op="givemon",[1]=2,[2]=20,[3]=100}
hooks["script.command"](nativeScript,{}, "givemon",originalGift)
assert(seenScript~=originalGift and seenScript[1]~=2
    and seenScript[2]==20 and seenScript[3]==100,
    "scripted gifts must preserve level and held item")
local originalEgg={op="giveegg",[1]=3}
hooks["script.command"](nativeScript,{}, "giveegg",originalEgg)
assert(seenScript~=originalEgg and seenScript[1]~=3,
    "NPC gift eggs must use their own independent species roll")
-- The event special must build the native encounter descriptor first,
-- then replace only its species. Preserve its fateful/level/item flags.
local oldNatives=package.loaded["src.core.game3.scripting.natives"]
local oldEnc=package.loaded["src.core.game3.encounters"]
local fakeEnc={}
package.loaded["src.core.game3.encounters"]=fakeEnc
package.loaded["src.core.game3.scripting.natives"]={
    specialName=function(id)
        return id==777 and "CreateEnemyEventMon" or "Unrelated"
    end
}
local specialRow={op="special",[1]=777}
local passed=hooks["script.command"](function(_,name,row)
    assert(name=="special" and row==specialRow)
    fakeEnc._pendingWild={
        species=1,level=40,item=66,modernFatefulEncounter=true,
    }
    return "native_success"
end,{},"special",specialRow)
assert(passed=="native_success"
    and fakeEnc._pendingWild.species~=1
    and fakeEnc._pendingWild.level==40
    and fakeEnc._pendingWild.item==66
    and fakeEnc._pendingWild.modernFatefulEncounter==true,
    "event Pokemon special must preserve its native side effects")
package.loaded["src.core.game3.scripting.natives"]=oldNatives
package.loaded["src.core.game3.encounters"]=oldEnc
-- Variable-backed gift sources must keep native script text variables
-- aligned with the actual awarded species, not mutate authored opcodes.
local oldFlags=package.loaded["src.core.game3.scripting.flags"]
local oldSpace=package.loaded["src.core.game3.scripting.space"]
local varStore={vars={[0x4006]=2}}
package.loaded["src.core.game3.scripting.flags"]={
    getVar=function(store,ctx,id) return store.vars[id] end,
    setVar=function(store,ctx,id,value) store.vars[id]=value end,
}
package.loaded["src.core.game3.scripting.space"]={store=varStore}
local variableGift={op="givemon",[1]=0x4006,[2]=15}
hooks["script.command"](nativeScript,{runner={ctx={}}},
    "givemon",variableGift)
assert(seenScript~=variableGift and seenScript[1]~=2
    and seenScript[1]==varStore.vars[0x4006]
    and variableGift[1]==0x4006
    and seenScript[2]==15,
    "variable-backed gift text and acquired species must agree")
package.loaded["src.core.game3.scripting.flags"]=oldFlags
package.loaded["src.core.game3.scripting.space"]=oldSpace
game.session.map="FR_POKEMON_TOWER_6F"
hooks["script.command"](nativeScript,{}, "setwildbattle",originalStatic)
assert(seenScript==originalStatic,"Tower ghost must remain native")
game.session.map="FR_ROUTE_1"
-- Visible item-ball awards route via STD_FIND_ITEM / callstd 1.
-- Native slot is VAR_0x8000; do not mutate the opcode or unrelated
-- scripted NPC gifts using STD_OBTAIN_ITEM / callstd 0.
local oldItemFlags=package.loaded["src.core.game3.scripting.flags"]
local oldItemSpace=package.loaded["src.core.game3.scripting.space"]
local itemStore={vars={[0x8000]=13}}
package.loaded["src.core.game3.scripting.flags"]={
    getVar=function(store,ctx,id)return store.vars[id] end,
    setVar=function(store,ctx,id,value)store.vars[id]=value end,
}
package.loaded["src.core.game3.scripting.space"]={store=itemStore}
local ballScript={op="callstd",[1]=1}
local ballContext={runner={_scriptKey="Route1_Ball_1",ctx={}}}
hooks["script.command"](nativeScript,ballContext,"callstd",ballScript)
local ballResult=itemStore.vars[0x8000]
assert(ballResult and ballResult~=13 and seenScript==ballScript,
    "item-ball must replace the native award var before the callstd")
itemStore.vars[0x8000]=13
hooks["script.command"](nativeScript,ballContext,"callstd",ballScript)
assert(itemStore.vars[0x8000]==ballResult,
    "item ball species-independent source should replay")
itemStore.vars[0x8000]=261
hooks["script.command"](nativeScript,ballContext,"callstd",ballScript)
assert(itemStore.vars[0x8000]==261,
    "key item ball must never be randomised")
itemStore.vars[0x8000]=289
hooks["script.command"](nativeScript,ballContext,"callstd",ballScript)
assert(itemStore.vars[0x8000]==289,
    "TM/HM pickups must remain progression-safe")
itemStore.vars[0x8000]=13
hooks["script.command"](nativeScript,ballContext,"callstd",{op="callstd",[1]=0})
assert(itemStore.vars[0x8000]==13,
    "scripted NPC item gift is not a field pickup")
package.loaded["src.core.game3.scripting.flags"]=oldItemFlags
package.loaded["src.core.game3.scripting.space"]=oldItemSpace
-- Hidden pickups in both FRLG and RSE must pass a COPY to native field
-- handling; it still owns message display, quantity and flag changes.
local hidden={item=13,x=4,y=7,flag=888,quantity=2}
assert(FakeField.pickUpHiddenItem(game,hidden))
assert(#fieldReceipts==1
    and fieldReceipts[1].record~=hidden
    and fieldReceipts[1].record.item~=13
    and fieldReceipts[1].record.flag==888
    and fieldReceipts[1].record.quantity==2 and hidden.item==13,
    "hidden item must preserve native flag/quantity and source record")
local hiddenResult=fieldReceipts[1].record.item
assert(FakeField.digUpUnderfootItem(game,hidden))
assert(fieldReceipts[2].record.item==hiddenResult,
    "underfoot Itemfinder pickup must use same persistent assignment")
local keyHidden={item=261,x=9,y=9,flag=1005}
assert(FakeField.pickUpHiddenItem(game,keyHidden))
assert(fieldReceipts[3].record==keyHidden,
    "hidden key item must pass unchanged to native")
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
    and model.rows[6]=="RANDOM STATIC: ON"
    and model.rows[7]=="RANDOM GIFTS: ON"
    and model.rows[8]=="RANDOM EGGS: ON"
    and model.rows[9]=="RANDOM FIELD ITEMS: ON"
    and model.rows[10]=="RANDOM SHOPS: ON"
    and model.rows[11]=="SHOP BALANCE: CHAOS"
    and model.rows[12]=="ITEM BALANCE: CHAOS"
    and model.rows[13]=="ITEM VARIETY: NORMAL"
    and model.rows[17]=="WILD VARIETY: UNIQUE AREA",
    "Randomiser menu must expose working settings")
local soon=false
for _,label in ipairs(model.rows) do
    assert(label~="[Soon] Rndm Strtr",
        "working starter randomiser must not be marked Soon")
    if label=="[Soon] Strtr Style" then soon=true end
end
assert(soon,"unimplemented starter styles must remain [Soon]")
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
