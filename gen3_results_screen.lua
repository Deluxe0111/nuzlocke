-- Gen 3 terminal run-results UI: native 240x160 presentation,
-- plus 960x540 shareable PNG with real native Pokemon front sprites.
return function()
    local M={isMenu=true}
    local ID="nuzlocke.gen3.results"
    local result,game,opts,stack,pages={},nil,{},nil,{}
    local current,scroll,pageIndex=1,0,1
    local lastExport=nil
    local function present(title,rows)
        pages[#pages+1]={title=title,rows=rows,index=1,scroll=0}
    end
    local function active()return pages[#pages] end
    local function row(label,fn)
        return {label=tostring(label or ""),action=fn}
    end
    local function text(v)
        local s=tostring(v==nil and "?" or v)
        return s
    end
    local function entries(mode)
        return mode=="party" and (result.party or {})
            or (result.graveyard or {})
    end
    local function formatMon(mon)
        return text(mon.name).." Lv"..text(mon.level)
    end
    local function detail(mon)
        local rows={
            row("NAME: "..text(mon.name)),
            row("SPECIES: "..text(mon.speciesName)),
            row("LEVEL: "..text(mon.level)),
            row("HP: "..text(mon.hp).."/"..text(mon.maxHp)),
            row("ATK/DEF: "..text(mon.attack).."/"..text(mon.defense)),
            row("SPA/SPD: "..text(mon.spAttack).."/"..text(mon.spDefense)),
            row("SPEED: "..text(mon.speed)),
        }
        if mon.area then rows[#rows+1]=row("LOST: "..text(mon.area)) end
        if mon.cause then rows[#rows+1]=row("CAUSE: "..mon.cause) end
        if mon.ability then rows[#rows+1]=row("ABILITY ID: "..text(mon.ability)) end
        if mon.nature then rows[#rows+1]=row("NATURE: "..text(mon.nature)) end
        if type(mon.moves)=="table" then
            local moveNames={}
            local ok,Pokemon=pcall(require,"src.core.game3.pokemon")
            for _,mv in ipairs(mon.moves) do
                local id=type(mv)=="table" and (mv.id or mv.move) or mv
                local move=ok and Pokemon and Pokemon.moveName and Pokemon.moveName(id)
                moveNames[#moveNames+1]=move or text(id)
            end
            if #moveNames>0 then rows[#rows+1]=row("MOVES: "..table.concat(moveNames,",")) end
        end
        present("POKEMON RECORD",rows)
    end
    local function roster(mode)
        local members=entries(mode)
        local rows={}
        for i,mon in ipairs(members) do
            local picked=mon
            rows[#rows+1]=row(i..". "..formatMon(mon),function()
                detail(picked)
            end)
        end
        if #rows==0 then rows[1]=row("NO POKEMON RECORDED") end
        present(mode=="party" and "FINAL PARTY" or "IN MEMORIAM",rows)
    end
    local function stats()
        local rows={
            row("RESULT: "..text(result.outcome)),
            row("TIME: "..text(result.playtime)),
            row("BADGES: "..text(result.badges)),
            row("AREAS: "..text(result.encounters)),
            row("CATCHES: "..text(result.caught)),
            row("USED SLOTS: "..text(result.spent)),
            row("DEATHS: "..text(result.deaths)),
            row("SHINY EXCEPTIONS: "..text(result.shinyExceptions)),
            row("REGION: "..text(result.version)),
            row("ENDED: "..text(result.date)),
            row("REASON: "..text(result.reason)),
        }
        present("RUN STATISTICS",rows)
    end
    -- Optional native sprite; the share card is still useful if the ROM
    -- assets are not yet available (e.g. isolated test environment).
    local function drawSprite(g,mon,x,y)
        local id=tonumber(mon.species)
        if not id then return end
        local ok,Pokemon=pcall(require,"src.core.game3.pokemon")
        if not ok or type(Pokemon.monFrontPic)~="function" then return end
        local source={species=id,personality=tonumber(mon.personality) or 0,
            shiny=mon.shiny==true,level=mon.level}
        local good,pic=pcall(Pokemon.monFrontPic,source,nil,"hof")
        if good and type(pic)=="table" and pic.image then
            local w,h=tonumber(pic.w) or 64,tonumber(pic.h) or 64
            local scale=math.min(90/w,90/h)
            g.setColor(1,1,1,1)
            g.draw(pic.image,x+(90-w*scale)/2,y,0,scale,scale)
        end
    end
    local function exportImage(mode,offset)
        if not (love and love.graphics and love.filesystem
            and love.graphics.newCanvas) then
            return false,"PNG EXPORT UNAVAILABLE"
        end
        local g=love.graphics
        local pushed=false
        local ok,filename=pcall(function()
            local list=entries(mode)
            local canvas=g.newCanvas(960,540)
            g.push("all")
            pushed=true
            g.setCanvas(canvas)
            g.clear(.035,.06,.12,1)
            local gold={.97,.78,.38}
            local accent=result.outcome=="VICTORY"
                and {.18,.68,.49} or {.69,.29,.34}
            local function color(rgb,a)
                g.setColor(rgb[1],rgb[2],rgb[3],a or 1)
            end
            local fontBig=g.newFont(33)
            local font=g.newFont(17)
            local small=g.newFont(14)
            color(accent)
            g.rectangle("fill",0,0,960,9)
            color(gold);g.setFont(fontBig)
            g.print(result.outcome=="VICTORY"
                and "CHAMPION HALL OF FAME" or "IN MEMORIAM",38,26)
            g.setFont(font)
            g.setColor(.74,.83,.92,1)
            g.print("TRAINER  "..text(result.trainer),42,78)
            g.print("TIME "..text(result.playtime).."   BADGES "
                ..text(result.badges).."   CAUGHT "..text(result.caught)
                .."   LOST "..text(result.deaths),42,104)
            for i=1,6 do
                local mon=list[offset+i]
                if mon then
                    local col=(i-1)%3
                    local rw=math.floor((i-1)/3)
                    local x=35+col*304
                    local y=155+rw*171
                    g.setColor(.10,.16,.26,1)
                    g.rectangle("fill",x,y,285,157,9,9)
                    color(accent,.95)
                    g.rectangle("fill",x,y,5,157)
                    drawSprite(g,mon,x+12,y+10)
                    g.setFont(font)
                    g.setColor(1,1,1,1)
                    g.print(text(mon.name):sub(1,21),x+112,y+18)
                    g.setFont(small)
                    g.setColor(.72,.80,.88,1)
                    g.print(text(mon.speciesName):sub(1,23),x+112,y+46)
                    g.print("LEVEL "..text(mon.level),x+112,y+69)
                    if mon.area then
                        g.print("ATK "..text(mon.attack).."  DEF "
                            ..text(mon.defense),x+112,y+92)
                        g.print(text(mon.area):sub(1,29),x+12,y+116)
                    else
                        g.print("HP "..text(mon.hp).."/"..text(mon.maxHp),
                            x+112,y+92)
                    end
                    if mon.cause then
                        g.print(text(mon.cause):sub(1,31),x+12,y+136)
                    else
                        g.print("ATK "..text(mon.attack).." / DEF "
                            ..text(mon.defense),x+112,y+115)
                    end
                end
            end
            g.setFont(small)
            color(gold)
            g.print("NUZLOCKE  //  GEN 3",38,515)
            g.setColor(.62,.7,.8,1)
            g.print(text(result.date),750,515)
            g.setCanvas()
            g.pop()
            pushed=false
            local name=tostring(result.trainer):gsub("[^%w%-_]","_")
            local suffix=os.date and os.date("!%Y%m%d_%H%M%S") or "run"
            local rel="nuzlocke_results/"..name.."_"..result.outcome
                .."_"..suffix.."_"..tostring(offset+1)..".png"
            assert(love.filesystem.createDirectory("nuzlocke_results"))
            local data=canvas:newImageData()
            data:encode("png",rel)
            return love.filesystem.getSaveDirectory().."/"..rel
        end)
        if ok then return true,filename end
        -- Restore the graphics stack even if an external sprite renderer
        -- throws during a PNG render. Never strand the native game on an
        -- offscreen Canvas after a failed export.
        if pushed then pcall(g.pop) end
        pcall(g.setCanvas)
        return false,tostring(filename)
    end
    local function exportPage()
        local mode=result.outcome=="VICTORY" and "party" or "graveyard"
        local list=entries(mode)
        if #list==0 then
            present("SHARE IMAGE",{row("NO RECORDED POKEMON")})
            return
        end
        local total=math.max(1,math.ceil(#list/6))
        pageIndex=math.min(pageIndex,total)
        local function shareRows()
            return {
                row("PAGE "..pageIndex.." / "..total,function()
                    pageIndex=pageIndex%total+1
                    active().rows=shareRows()
                end),
                row("SAVE PAGE AS PNG",function()
                    local ok,path=exportImage(mode,(pageIndex-1)*6)
                    local rows={}
                    if ok then
                        rows[#rows+1]=row("PNG SAVED")
                        rows[#rows+1]=row("LOVE SAVE FOLDER")
                        rows[#rows+1]=row("nuzlocke_results/")
                        rows[#rows+1]=row(path:match("([^/]+)$") or path)
                    else
                        rows[#rows+1]=row("EXPORT FAILED")
                        rows[#rows+1]=row(tostring(path):sub(1,65))
                    end
                    present("SHARE RESULT",rows)
                end),
            }
        end
        present("SHARE "..(mode=="party" and "PARTY" or "MEMORIAL"),
            shareRows())
    end
    local function quit()
        local fn=opts and opts.onQuit
        if type(fn)=="function" then return fn() end
        if game and type(game.returnToTitle)=="function" then
            return game:returnToTitle()
        end
    end
    local function home()
        pages={}
        local rosterMode=result.outcome=="VICTORY" and "party" or "graveyard"
        local rows={
            row("RESULT: "..text(result.outcome)),
            row("STATS / PLAY TIME",stats),
            row("FINAL PARTY",function() roster("party") end),
            row("GRAVEYARD: "..text(result.deaths),function()
                roster("graveyard")
            end),
            row("SHARE "..(rosterMode=="party" and "PARTY" or "MEMORIAL")
                .." PNG",exportPage),
        }
        if result.saveError then
            rows[#rows+1]=row("AUTOSAVE FAILED")
        end
        if result.outcome~="VICTORY" and opts
            and type(opts.onSave)=="function" then
            rows[#rows+1]=row("RETRY / SAVE RUN",function()
                local ok,why=opts.onSave()
                present("RUN SAVE",{
                    row(ok and "SAVE COMPLETE" or "SAVE FAILED"),
                    row(ok and "FINAL RECORD WRITTEN"
                        or tostring(why or "UNKNOWN ERROR")),
                })
            end)
        end
        if result.outcome=="VICTORY" then
            rows[#rows+1]=row("CONTINUE ADVENTURE",function()
                M.close()
                if opts and type(opts.onContinue)=="function" then
                    opts.onContinue()
                end
            end)
        end
        rows[#rows+1]=row("QUIT TO TITLE",quit)
        present("NUZ RUN RESULTS",rows)
    end
    function M.open(g,record,options)
        if type(record)~="table" then return false end
        result,game,opts=record,g,options or {}
        stack=require("src.ui.game3.stack")
        pageIndex=1
        home()
        stack.push(ID,M,{hideBelow=true,fullscreen=true})
        return true
    end
    function M.isOpen()
        return stack and stack.has and stack.has(ID) or false
    end
    function M.ensureTop()
        if not M.isOpen() or not stack or not stack.top then
            return false
        end
        local top=stack.top()
        if top and top.id==ID then return true end
        -- Preserve the current result subpage if another native
        -- menu gets layered above the failed-run terminal overlay.
        stack.push(ID,M,{hideBelow=true,fullscreen=true})
        return true
    end
    function M.close()
        if stack then stack.pop(ID) end
        pages={}
    end
    function M.handleInput(input)
        if not input or not active() then return end
        local p=active()
        if input:wasPressed("up") then
            p.index=((p.index-2)%#p.rows)+1
        elseif input:wasPressed("down") then
            p.index=(p.index%#p.rows)+1
        elseif input:wasPressed("a") then
            local selected=p.rows[p.index]
            if selected and selected.action then selected.action() end
        elseif input:wasPressed("b") or input:wasPressed("start") then
            if #pages>1 then pages[#pages]=nil end
            -- Terminal failures must never dismiss the screen and enter
            -- gameplay; they can only view data/share or quit to title.
        end
        p=active()
        if p then
            if p.index<=p.scroll then p.scroll=p.index-1 end
            if p.index>p.scroll+6 then p.scroll=p.index-6 end
        end
    end
    function M.update()end
    function M.draw()
        local p=active()
        if not p then return end
        local Window=require("src.ui.game3.window")
        local Chrome=require("src.ui.game3.chrome")
        Window.fill(Window.template(0,0,30,20),1,1,1,1)
        Chrome.fixedStdFrame(1,1,28,18)
        Window.printPx(p.title,24,13,{maxWidth=190})
        Window.printPx(p.index.."/"..#p.rows,185,13,
            {maxWidth=35,small=true})
        for i=1,6 do
            local line=p.rows[p.scroll+i]
            if line then
                local y=31+(i-1)*17
                if p.scroll+i==p.index then Window.cursorPx(18,y) end
                Window.printPx(line.label,32,y,
                    {maxWidth=184,small=true})
            end
        end
        Window.printPx("A: VIEW   B: BACK",28,138,
            {maxWidth=185,small=true})
    end
    function M.model()
        local p=active()
        if not p then return nil end
        local labels={}
        for i,v in ipairs(p.rows) do labels[i]=v.label end
        return {title=p.title,rows=labels,index=p.index,
            depth=#pages,outcome=result.outcome}
    end
    return M
end
