-- Gen 3 BATTLE CLAUSES: pure policy, side scopes and save persistence.
local B=assert(loadfile("gen3_battle_clauses.lua"))()()
local Core=assert(loadfile("gen3_core_rules.lua"))()()
local state=Core.normalise({})
assert(#B.descriptors()==6)
local definitions=B.descriptors()
local keys={}
for _,d in ipairs(definitions) do
    keys[#keys+1]=d.key
    assert(d.status=="working" and B.get(state,d.key)==d.default)
end
assert(not B.set(state,"ohko_clause",true),
    "OHKO remains unavailable until its own safe native guard")
assert(Core.set(state,"nuzlocke_enabled",true))
assert(B.get(state,"evasion_clause")==false)
assert(B.next(state,"evasion_clause")==true)
assert(B.set(state,"evasion_clause",true))
assert(B.next(state,"evasion_clause")==false)
assert(B.set(state,"evasion_clause",false))
assert(B.label(state,"evasion_clause")=="OFF")
local scoped={"flinch_clause_scope","trap_clause_scope",
    "setup_move_scope","status_accuracy_scope","other_stat_drop_scope"}
for _,key in ipairs(scoped) do
    assert(B.get(state,key)==0 and B.label(state,key)=="OFF")
    assert(B.set(state,key,1))
    assert(B.label(state,key)=="SELF")
    assert(B.applies(state,key,"player",Core))
    assert(not B.applies(state,key,"enemy",Core))
    assert(B.next(state,key)==2)
    assert(B.set(state,key,2))
    assert(not B.applies(state,key,"player",Core))
    assert(B.applies(state,key,"enemy",Core))
    assert(B.set(state,key,3))
    assert(B.applies(state,key,{side="enemy"},Core))
    assert(B.applies(state,key,{side="player"},Core))
    assert(not B.applies(state,key,"neutral",Core))
    assert(B.next(state,key)==0)
    assert(B.set(state,key,0))
    assert(not B.applies(state,key,"player",Core))
end
assert(B.set(state,"flinch_clause_scope",1))
assert(B.denyEffect(state,"FLINCH",{side="player"},Core))
assert(not B.denyEffect(state,"FLINCH",{side="enemy"},Core))
assert(not B.denyEffect(state,"WRAP",{side="player"},Core))
assert(B.set(state,"trap_clause_scope",2))
assert(B.denyEffect(state,"WRAP",{side="enemy"},Core))
assert(not B.denyEffect(state,"WRAP",{side="player"},Core))
assert(not B.denyEffect(state,"BURN",{side="enemy"},Core),
    "status bans are a separate group")
assert(B.set(state,"setup_move_scope",1))
assert(B.denyStat(state,"attack",2,{side="player"},Core))
assert(not B.denyStat(state,"attack",2,{side="enemy"},Core))
assert(not B.denyStat(state,"attack",-2,{side="player"},Core))
assert(B.set(state,"evasion_clause",true))
assert(B.denyStat(state,"evasion",1,{side="enemy"},Core),
    "Evasion Clause applies to both sides")
assert(not B.denyStat(state,"accuracy",-1,{side="player"},Core))
assert(B.set(state,"status_accuracy_scope",3))
assert(B.denyStat(state,"accuracy",-1,{side="player"},Core))
assert(B.denyStat(state,"accuracy",-1,{side="enemy"},Core))
assert(not B.denyStat(state,"defense",-1,{side="enemy"},Core))
assert(B.set(state,"other_stat_drop_scope",2))
assert(B.denyStat(state,"defense",-1,{side="enemy"},Core))
assert(not B.denyStat(state,"defense",-1,{side="player"},Core))
assert(not B.denyStat(state,"accuracy",-1,{side="enemy"},Core)==false,
    "accuracy remains independently blocked by its own clause")
assert(not B.set(state,"trap_clause_scope",4))
assert(not B.set(state,"trap_clause_scope",1.5))
assert(not B.set(state,"evasion_clause",1))
assert(not B.set(state,"nonexistent_rule",true))
local reloaded={enabled=true,battleClauses=state.battleClauses}
assert(B.get(reloaded,"setup_move_scope")==1)
assert(B.get(reloaded,"flinch_clause_scope")==1)
assert(B.get(reloaded,"status_accuracy_scope")==3)
assert(Core.set(state,"nuzlocke_enabled",false))
assert(not B.denyEffect(state,"FLINCH","player",Core))
assert(not B.denyStat(state,"attack",1,"player",Core))
assert(Core.set(state,"nuzlocke_enabled",true))
state.failed=true
assert(not B.set(state,"evasion_clause",false))
assert(not B.denyEffect(state,"FLINCH","player",Core),
    "failed runs have no battle-effect enforcement")
print("Gen3 Advanced Battle Clauses policy and save-state test: PASS")
