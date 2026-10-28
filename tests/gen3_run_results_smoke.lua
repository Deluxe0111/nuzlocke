-- Gen 3 end-run summary, terminal UI and PNG export contract (Lua 5.1).
local Policy=assert(loadfile("gen3_run_results.lua"))()()
local View=assert(loadfile("gen3_results_screen.lua"))()()
local Display={
    pokemonName=function(mon)return mon.nickname or mon.name or "POKEMON" end,
    speciesName=function(mon)return mon.speciesName or "SQUIRTLE" end,
    areaName=function(id)return tostring(id or "UNKNOWN") end,
}
local mon={species=7,nickname="Shell",level=38,personality=781,
    hp=75,maxHp=92,atk=57,def=81,spe=61,spa=75,spd=80,
    moves={33,57},ivs={atk=19},evs={hp=15}}
local dead={species=4,speciesName="Charmander",name="Pyro",
    nickname="Pyro",level=25,area="FR_MT_MOON",cause="Critical hit",
    archive={species=4,personality=123,level=25,hp=0,maxHp=57,
        atk=40,def=36,spe=44,spa=51,spd=40,moves={10,15}}}
local session={name="RED",version="firered",
    party={mon},playTimeHours=12,playTimeMinutes=41,playTimeSeconds=5}
local saved={enabled=true,areas={
    FR_ROUTE_1={caught=true,spent=true},
    FR_ROUTE_2={spent=true},
    FR_ROUTE_3={caught=false,spent=false},
},graveyard={dead},shinyExceptionsUsed=2}
local failed=Policy.finish(saved,session,Display,"FAILED","Whiteout",5)
assert(failed and failed.schema==1 and saved.failed==true)
assert(Policy.isTerminal(saved) and failed.outcome=="FAILED")
assert(failed.playtime=="12:41:05" and failed.badges==5)
assert(failed.encounters==3 and failed.caught==1 and failed.spent==2)
assert(failed.deaths==1 and #failed.party==1 and #failed.graveyard==1)
assert(failed.party[1].name=="Shell" and failed.party[1].species==7)
assert(failed.graveyard[1].name=="Pyro"
    and failed.graveyard[1].cause=="Critical hit")
assert(failed.graveyard[1].area=="FR_MT_MOON")
assert(failed.graveyard[1].hp==0 and failed.graveyard[1].maxHp==57)
mon.level=99;dead.archive.hp=88
assert(failed.party[1].level==38 and failed.graveyard[1].hp==0,
    "result snapshot must not alias mutable native party/archive")
assert(Policy.finish(saved,session,Display,"VICTORY","Afterwards",8)==failed,
    "terminal result must never be overwritten")
assert(not Policy.finish({enabled=false},session,Display,"FAILED"))
local champState={enabled=true,areas={},graveyard={}}
local win=Policy.finish(champState,session,Display,"VICTORY",
    "Champion defeated",8)
assert(win and win.outcome=="VICTORY" and champState.failed~=true)
assert(not Policy.isTerminal(champState))
assert(win.party[1].level==99)
local manual={enabled=true,areas={},graveyard={}}
local forfeit=Policy.finish(manual,session,Display,"FORFEIT",
    "Ended manually",0)
assert(forfeit and manual.failed and Policy.isTerminal(manual))
-- A stub of the game3 modal UI stack. Input is handled by the TOP layer.
local layers={}
package.loaded["src.ui.game3.stack"]={
    push=function(id,mod)
        for i=#layers,1,-1 do
            if layers[i].id==id then table.remove(layers,i) end
        end
        layers[#layers+1]={id=id,mod=mod}
    end,
    pop=function(id)
        for i=#layers,1,-1 do
            if layers[i].id==id then table.remove(layers,i);return true end
        end
    end,
    has=function(id)
        for _,entry in ipairs(layers) do
            if entry.id==id then return true end
        end
        return false
    end,
}
local game={returnToTitle=function(self) self.quit=true end}
local function press(k)
    View.handleInput({wasPressed=function(_,button)return k==button end})
end
local function selectPrefix(prefix)
    local m=assert(View.model())
    for i,label in ipairs(m.rows) do
        if label:sub(1,#prefix)==prefix then
            while View.model().index~=i do press("down") end
            press("a")
            return true
        end
    end
    return false
end
assert(View.open(game,failed))
assert(View.isOpen())
local lost=View.model()
assert(lost.title=="NUZ RUN RESULTS" and lost.outcome=="FAILED")
for _,label in ipairs(lost.rows) do
    assert(label~="CONTINUE ADVENTURE",
        "failed run must not expose a gameplay continue action")
end
press("b");press("start")
assert(View.isOpen() and View.model().depth==1,
    "failure results must not be closable with B or START")
assert(selectPrefix("STATS / PLAY TIME"))
assert(View.model().title=="RUN STATISTICS")
press("b");assert(View.model().title=="NUZ RUN RESULTS")
assert(selectPrefix("GRAVEYARD"))
assert(View.model().title=="IN MEMORIAM")
assert(selectPrefix("1. Pyro"))
local monScreen=View.model()
assert(monScreen.title=="POKEMON RECORD"
    and table.concat(monScreen.rows," "):find("Critical hit",1,true))
press("b");press("b")
assert(View.model().title=="NUZ RUN RESULTS")

-- One dynamic-height PNG contains BOTH rosters and all run statistics.
-- Fail with any pagination controls, dropped graveyard members or missing
-- current-party Pokemon. Mock the real restricted mod sandbox.
local savedPng=nil
local dimensions={}
local allText={}
local drawnSprites=0
local exportCount=0
local gfx={
    newCanvas=function(w,h)
        dimensions={w,h}
        assert(w==1200 and h>540,"full poster must be dynamic, not a page")
        return {newImageData=function()
            return {encode=function(_,fmt,path)
                assert(fmt=="png")
                savedPng=path
                exportCount=exportCount+1
            end}
        end}
    end,
    newFont=function(size)
        return {getWidth=function(_,s)return #s*size*.52 end}
    end,
    getSystemLimits=function()return {texturesize=8192} end,
    push=function()end,
    pop=function()end,
    setCanvas=function()end,
    clear=function()end,
    setColor=function()end,
    setFont=function()end,
    rectangle=function()end,
    print=function(s)
        allText[#allText+1]=s
    end,
    draw=function()drawnSprites=drawnSprites+1 end,
}
local loveBefore=love
love={graphics=gfx}
setmetatable(love,{__index=function(_,key)
    if key=="filesystem" then
        error("love.filesystem is not available to mods",2)
    end
end})
package.loaded["src.core.game3.pokemon"]={
    monFrontPic=function()return {image={},w=64,h=64} end,
    moveName=function(id)return "MOVE "..id end,
}
-- The actual test case has eight deaths; the last card MUST appear
-- in the same export alongside the current party and summary.
for i=2,8 do
    local copy={}
    for k,v in pairs(failed.graveyard[1]) do copy[k]=v end
    copy.name="Memory"..i
    copy.speciesName="Species"..i
    copy.level=10+i
    failed.graveyard[#failed.graveyard+1]=copy
end
failed.deaths=#failed.graveyard
assert(View.open(game,failed))
local w,h=View.posterDimensions(failed)
assert(w==1200 and h>1000,"8 memorial entries need a taller poster")
assert(View.model().rows[5]=="SHARE COMPLETE RUN PNG")
assert(selectPrefix("SHARE COMPLETE RUN PNG"))
assert(View.model().title=="SHARE RESULT")
assert(savedPng and savedPng:match("^nuzlocke_")
    and savedPng:match("_FULL%.png$")
    and exportCount==1 and drawnSprites==9,
    "single share image must include 1 party + all 8 fallen Pokemon")
local rendered=table.concat(allText," ")
for _,expected in ipairs({
    "FINAL PARTY", "IN MEMORIAM", "Shell", "Pyro",
    "Memory2", "Memory3", "Memory4", "Memory5", "Memory6",
    "Memory7", "Memory8", "PLAY TIME", "BADGES",
    "CAUGHT", "FAINTED", "AREAS", "SLOTS USED",
}) do
    assert(rendered:find(expected,1,true),
        "whole-run PNG omitted "..expected)
end
assert(not rendered:find("ATK ?",1,true),
    "missing stats should be labelled, not filled with question marks")
press("b")
assert(selectPrefix("QUIT TO TITLE"))
assert(game.quit==true)
View.close()
assert(not View.isOpen())

-- Victories should still show the graveyard and party together.
assert(View.open(game,win))
local winning=View.model()
assert(winning.outcome=="VICTORY")
local previous=exportCount
allText={}
drawnSprites=0
assert(selectPrefix("SHARE COMPLETE RUN PNG"))
assert(exportCount==previous+1)
assert(drawnSprites==2,
    "Champion poster must show living party plus fallen Pokemon")
press("b")
assert(selectPrefix("CONTINUE ADVENTURE"))
assert(not View.isOpen() and game.quit==true,
    "victory continue must close the result overlay without quitting")
love=loveBefore
print("Gen 3 run results policy, failure lock, victory and PNG: PASS")
