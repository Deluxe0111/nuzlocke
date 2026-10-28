-- Gen 3 Type Locke: canonical GBA types, selected lanes and save policy.
local V=assert(loadfile("gen3_variants.lua"))()()
local Core=assert(loadfile("gen3_core_rules.lua"))()()
local s=Core.normalise({})
local P={
    speciesFromNational=function(n)
        return n<=6 and n or nil
    end,
    keyName=function(id)
        return ({[1]="CHARMANDER",[2]="SQUIRTLE",
            [3]="BULBASAUR",[4]="PIDGEY",
            [5]="GASTLY",[6]="MAGNEMITE",
            [7]="PROVIDER"})[id]
    end,
    speciesFromName=function(name)
        return ({CHARMANDER=1,SQUIRTLE=2,BULBASAUR=3,
            PIDGEY=4,GASTLY=5,MAGNEMITE=6,PROVIDER=7})[name]
    end,
    types=function(id)
        return ({
            [1]={10,10}, -- FIRE
            [2]={11,11}, -- WATER
            [3]={12,3},  -- GRASS / POISON
            [4]={0,2},   -- NORMAL / FLYING
            [5]={7,3},   -- GHOST / POISON
            [6]={13,8},  -- ELECTRIC / STEEL
            [7]={14,9},  -- custom PSYCHIC / MYSTERY
        })[id] or {0,0}
    end,
}
local function check(id,seed) return V.check(s,id,P,Core,seed or "trainer:1") end
assert(#V.descriptors()==7)
assert(V.get(s,"type_lock_mode")==0)
assert(V.get(s,"type_lock_primary")==0)
assert(V.label(s,"type_lock_mode")=="OFF")
assert(V.label(s,"type_lock_primary")=="RANDOM")
assert(not V.set(s,"type_lock_mode",7))
assert(not V.set(s,"type_lock_primary",18))
assert(not V.set(s,"type_lock_draft",true))
assert(not V.set(s,"wonderlocke",true))
assert(V.next(s,"type_lock_mode")==1)
assert(V.next(s,"type_lock_primary")==1)
assert(Core.set(s,"nuzlocke_enabled",true), "Type Locke only enforces when the master is ON")
assert(V.set(s,"type_lock_mode",1))
assert(V.set(s,"type_lock_primary",10)) -- GBA FIRE
assert(V.label(s,"type_lock_mode")=="MONO")
assert(V.label(s,"type_lock_primary")=="FIRE")
assert(check(1),"same type admitted")
assert(not check(2),"WATER is illegal in Mono FIRE")
assert(not check(3),"GRASS/POISON is illegal in Mono FIRE")
local accepted,why=check("SQUIRTLE")
assert(not accepted and why:find("Type Locke",1,true))
assert(V.set(s,"type_lock_mode",2))
assert(V.label(s,"type_lock_mode")=="DUO")
assert(V.set(s,"type_lock_secondary",11)) -- GBA WATER
assert(check(1) and check(2),"either configured lane qualifies")
assert(not check(4),"NORMAL/FLYING still fails")
assert(V.set(s,"type_lock_secondary",4)) -- POISON
assert(check(3),"dual typed GRASS/POISON matches secondary POISON")
assert(check(5),"GHOST/POISON also matches")
assert(V.set(s,"type_lock_secondary",11))
assert(V.set(s,"type_lock_mode",6))
assert(V.label(s,"type_lock_mode")=="HEXA")
for i,key in ipairs(V.keys()) do
    assert(V.get(s,key)~=nil,"all six lane settings exposed")
end
assert(V.set(s,"type_lock_mode",0))
assert(check(4),"OFF permits non-matching Pokemon")
assert(Core.set(s,"nuzlocke_enabled",true))
assert(V.set(s,"type_lock_mode",2))
assert(V.set(s,"type_lock_primary",10))
assert(V.set(s,"type_lock_secondary",11))
assert(check(1) and check(2))
assert(not check(4))
assert(check(9999),"unknown/provider-only types fail open")
assert(Core.set(s,"nuzlocke_enabled",false))
assert(check(4),"Nuzlocke master OFF leaves wild catches native")
assert(Core.set(s,"nuzlocke_enabled",true))
assert(V.set(s,"type_lock_mode",3))
assert(V.set(s,"type_lock_primary",0))
assert(V.set(s,"type_lock_secondary",0))
assert(V.set(s,"type_lock_tertiary",0))
assert(V.prepare(s,P,"trainer:1"))
local r=s.variantRules.random_types
assert(type(r)=="table" and r[1] and r[2] and r[3])
assert(r[1]~=r[2] and r[1]~=r[3] and r[2]~=r[3],
    "RANDOM lanes should be distinct")
local t1,t2,t3=V.label(s,"type_lock_primary"),
    V.label(s,"type_lock_secondary"),V.label(s,"type_lock_tertiary")
assert(t1:find("RND:",1,true)==1)
assert(not V.prepare(s,P,"trainer:999"),
    "after resolution, changed seed cannot reroll saved types")
assert(V.label(s,"type_lock_primary")==t1
    and V.label(s,"type_lock_secondary")==t2
    and V.label(s,"type_lock_tertiary")==t3)
local clone={enabled=true,rules=s.rules,variantRules=s.variantRules}
assert(V.label(clone,"type_lock_primary")==t1
    and V.label(clone,"type_lock_secondary")==t2,
    "resolved lane identities persist across save reload")
assert(V.set(s,"type_lock_primary",10))
assert(s.variantRules.random_types==nil,
    "changing a lane resets only generated allocations")
assert(V.prepare(s,P,"trainer:1"))
assert(V.get(s,"type_lock_primary")==10)
assert(V.label(s,"type_lock_primary")=="FIRE")
assert(V.label(s,"type_lock_secondary")~="RND:FIRE",
    "random lane must never duplicate a manually chosen type")
assert(V.set(s,"type_lock_mode",1))
assert(V.set(s,"type_lock_primary",16)) -- GBA DRAGON
assert(not check(1))
assert(V.set(s,"type_lock_primary",1)) -- FIGHTING
assert(not check(1),"FIRE is not FIGHTING")
assert(V.set(s,"type_lock_primary",17)) -- GBA DARK
assert(not check(4),"NORMAL / FLYING is not DARK")
assert(V.set(s,"type_lock_primary",14)) -- GBA PSYCHIC
assert(check(7),"provider Pokémon matches PSYCHIC")
local corrupt={enabled=true,rules=s.rules,
    variantRules={type_lock_mode=90,type_lock_primary=900}}
assert(V.get(corrupt,"type_lock_mode")==0)
assert(V.get(corrupt,"type_lock_primary")==0)
s.failed=true
assert(not V.set(s,"type_lock_mode",0))
assert(not V.set(s,"type_lock_primary",0))
assert(check(4),"failed run disables catch enforcement")
print("Gen 3 Type Locke native-type, six-lane, RNG and save policy: PASS")
