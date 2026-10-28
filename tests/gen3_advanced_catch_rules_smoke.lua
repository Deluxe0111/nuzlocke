-- ROM-free Gen 3 Catch Rules: national mapping, BST, saved switches.
local Rules = assert(loadfile("gen3_catch_rules.lua"))()()
local Core = assert(loadfile("gen3_core_rules.lua"))()()
local s = Core.normalise({})
assert(#Rules.descriptors()==4)
assert(Rules.get(s,"ban_legendaries")==false)
assert(Rules.get(s,"ban_mythicals")==false)
assert(Rules.get(s,"ban_pseudos")==false)
assert(Rules.get(s,"maximum_bst")==0)
assert(not Rules.anyEnabled(s))
local pokemon={
    national=function(id)
        return ({[277]=252,[400]=380,[401]=373,[402]=385})[id] or id
    end,
    speciesFromName=function(name)
        return ({LATIAS=400,SALAMENCE=401,JIRACHI=402})[name]
    end,
    stats=function(id)
        if id==25 then return {35,55,40,90,50,50} end -- 320
        if id==400 then return {80,80,90,110,110,130} end -- 600
        if id==401 then return {95,135,80,100,110,80} end -- 600
        if id==402 then return {100,100,100,100,100,100} end
        if id==277 then return {40,45,35,70,65,55} end -- Treecko 310
        if id==99 then return nil end
        return {50,50,50,50,50,50}
    end
}
local function allowed(id)
    return Rules.check(s,id,pokemon,Core)
end
assert(allowed(400) and allowed(401) and allowed(402),
    "every advanced catch ban defaults OFF")
assert(Rules.set(s,"ban_legendaries",true))
assert(not allowed(150),"Mewtwo legendary banned")
assert(not allowed(400),"Latias internal id 400 -> national 380 banned")
assert(allowed(402),"Jirachi is mythical, not legendary")
assert(Rules.set(s,"ban_mythicals",true))
assert(not allowed(151) and not allowed(251),"Mew and Celebi banned")
assert(not allowed(402),"Jirachi's internal ID maps to mythical")
assert(allowed(401),"pseudo is distinct from mythical/legendary")
assert(Rules.set(s,"ban_pseudos",true))
for _,id in ipairs({147,148,149,246,247,248,371,372,376,401}) do
    assert(not allowed(id),"pseudo family banned: "..tostring(id))
end
assert(allowed(277),"Treecko internal 277 is not pseudo/legendary")
assert(Rules.set(s,"maximum_bst",500))
assert(not allowed(401),"BST 600 also banned at cap 500")
assert(allowed(25),"Pikachu 320 allowed below 500")
assert(not allowed(99),"unknown stats must fail closed only with cap")
assert(Rules.get(s,"maximum_bst")==500)
assert(Rules.nextBst(500)==550 and Rules.nextBst(700)==0)
assert(not Rules.set(s,"maximum_bst",501),"only valid UI presets accepted")
assert(not Rules.set(s,"ban_pseudos",1),"toggles must be booleans")
assert(not Rules.set(s,"allow_gifts",true),"not-yet-ported keys not editable")
assert(Rules.set(s,"maximum_bst",0))
assert(allowed(99),"unknown stats not relevant with limit OFF")
assert(Rules.get({}, "maximum_bst")==0,"legacy saves default OFF")
local restored={enabled=true,catchRules={ban_legendaries=true,
    ban_mythicals=true,ban_pseudos=true,maximum_bst=500}}
assert(Rules.get(restored,"ban_legendaries")
    and Rules.get(restored,"maximum_bst")==500,
    "catch settings survive reload")
assert(Core.set(s,"nuzlocke_enabled",false)==true)
assert(allowed(150) and allowed(400) and allowed(401),
    "master OFF bypasses restrictions but retains saved settings")
assert(Core.set(s,"nuzlocke_enabled",true))
s.failed=true
assert(not Rules.set(s,"ban_legendaries",false),
    "failed run cannot change rules")
assert(Rules.check(s,400,pokemon,Core),
    "failed runs do not apply live catch restrictions")
print("Gen3 Catch Rules national-dex policy/BST/save validation: PASS")
