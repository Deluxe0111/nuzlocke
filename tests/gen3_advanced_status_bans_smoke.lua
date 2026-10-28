-- Status Bans: parent synchronisation, source scope, aliases and saves.
local B=assert(loadfile("gen3_status_bans.lua"))()()
local Core=assert(loadfile("gen3_core_rules.lua"))()()
local s=Core.normalise({})
assert(#B.descriptors()==7)
assert(B.get(s,"status_move_scope")==0)
assert(B.get(s,"status_sleep_scope")==0)
assert(B.get(s,"sleep_clause")==nil)
assert(not B.childrenHidden(s))
assert(not B.deny(s,"BURN","enemy",nil,Core))
assert(Core.set(s,"nuzlocke_enabled",true))
assert(B.set(s,"status_move_scope",1))
assert(B.childrenHidden(s))
for _,key in ipairs(B.childKeys()) do
    assert(B.get(s,key)==1 and B.label(s,key)=="SELF")
    assert(not B.set(s,key,3),
        "parent must own child scopes when active")
end
assert(B.deny(s,"PARALYSIS","player",nil,Core))
assert(B.deny(s,"CONFUSION",{side="player"},nil,Core))
assert(B.deny(s,"TOXIC","player",nil,Core))
assert(B.deny(s,"FREEZE","player",nil,Core))
assert(not B.deny(s,"FREEZE","enemy",nil,Core))
assert(not B.deny(s,"FLINCH","player",nil,Core),
    "No Status Moves parent is NOT an all-non-damaging-moves ban")
local self={side="player"}, other={side="enemy"}
assert(not B.deny(s,"SLEEP",self,self,Core),
    "self-induced Rest sleep is always allowed")
assert(B.deny(s,"SLEEP",self,other,Core))
assert(B.set(s,"status_move_scope",2))
assert(B.deny(s,"PSN","enemy",nil,Core))
assert(not B.deny(s,"PSN","player",nil,Core))
assert(B.set(s,"status_move_scope",3))
assert(B.deny(s,"BRN","enemy",nil,Core)
    and B.deny(s,"BRN","player",nil,Core))
assert(B.next(s,"status_move_scope")==0)
assert(B.set(s,"status_move_scope",0))
assert(not B.childrenHidden(s))
for _,key in ipairs(B.childKeys()) do assert(B.get(s,key)==0) end
assert(B.set(s,"status_sleep_scope",1))
assert(B.set(s,"status_poison_scope",2))
assert(B.set(s,"status_paralysis_scope",3))
assert(B.deny(s,"SLEEP","player",other,Core))
assert(not B.deny(s,"SLEEP","enemy",other,Core))
assert(B.deny(s,"TOX","enemy",nil,Core))
assert(not B.deny(s,"TOX","player",nil,Core))
assert(B.deny(s,"PAR","enemy",nil,Core)
    and B.deny(s,"PAR","player",nil,Core))
assert(not B.deny(s,"FRZ","player",nil,Core))
assert(not B.deny(s,"PAR",nil,nil,Core),
    "unknown source must never be guessed")
assert(not B.set(s,"sleep_clause",true),
    "Sleep Clause must remain [Soon]")
assert(not B.set(s,"status_move_scope",4))
assert(not B.set(s,"status_move_scope",-1))
assert(not B.set(s,"status_move_scope",1.5))
assert(not B.set(s,"status_move_scope",true))
local saved={statusBans=s.statusBans}
assert(B.get(saved,"status_sleep_scope")==1
    and B.get(saved,"status_poison_scope")==2)
assert(Core.set(s,"nuzlocke_enabled",false))
assert(not B.deny(s,"SLEEP","player",other,Core))
assert(Core.set(s,"nuzlocke_enabled",true))
s.failed=true
assert(not B.set(s,"status_move_scope",3))
assert(not B.deny(s,"PAR","player",nil,Core))
print("Gen3 Status Bans policy parent/child/scope/save regression: PASS")
