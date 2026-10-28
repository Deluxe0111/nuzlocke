-- Shiny artwork for Gen 3 Nuzlocke result cards and native PC visuals.
-- Normal game artwork stays native. For confirmed shinies, use the ROM's
-- extracted front_shiny RGBA directly: box mini-icons have only a normal
-- palette in vanilla Gen 3 and can otherwise misrepresent the Pokemon.
return function()
    local M={api=1}
    local loadedCache,fronts,icons=nil,{},{}
    function M.isShiny(Pokemon,mon)
        if type(mon)~="table" then return false end
        if mon.shinyKnown==true then return mon.shiny==true end
        if type(mon.isShiny)=="boolean" then return mon.isShiny end
        if type(mon.shiny)=="boolean" then return mon.shiny end
        if type(Pokemon)=="table"
            and type(Pokemon.isShiny)=="function" then
            local ok,shiny=pcall(Pokemon.isShiny,mon)
            if ok then return shiny==true end
        end
        return false
    end
    local function cache()
        local ok,Dataset=pcall(require,"src.core.game3.dataset")
        if ok and type(Dataset.cache)=="function" then
            local success,c=pcall(Dataset.cache)
            if success and type(c)=="table"
                and type(c.read)=="function" then return c end
        end
        return nil
    end
    local function frontInfo(Pokemon,mon)
        local original=tonumber(mon.species or mon.speciesId)
        if not original then return nil end
        local pid=tonumber(mon.personality) or 0
        local species=original
        if type(Pokemon.monPicSpecies)=="function" then
            local ok,res=pcall(Pokemon.monPicSpecies,mon)
            if ok and tonumber(res) then species=tonumber(res) end
        elseif type(Pokemon.picSpecies)=="function" then
            local ok,res=pcall(Pokemon.picSpecies,original,pid)
            if ok and tonumber(res) then species=tonumber(res) end
        end
        -- Spinda's spots require a personality-dependent renderer.
        -- Native frontPic handles these safely.
        return species,pid
    end
    function M.front(Pokemon,mon)
        if type(Pokemon)~="table" or type(mon)~="table"
            or not M.isShiny(Pokemon,mon) then return nil end
        local species,pid=frontInfo(Pokemon,mon)
        if not species then return nil end
        local c=cache()
        if c~=loadedCache then
            loadedCache,fronts,icons=c,{},{}
        end
        local suffix=""
        if type(Pokemon.deoxysFormSuffix)=="function" then
            local ok,value=pcall(Pokemon.deoxysFormSuffix,species)
            if ok and type(value)=="string" then suffix=value end
        end
        local key=tostring(species)..suffix
        if species~=308 and c and love and love.image
            and love.graphics and type(love.image.newImageData)=="function"
            and type(love.graphics.newImage)=="function" then
            if fronts[key] then return fronts[key] end
            local root="data/generated/gba"
            local okPaths,Paths=pcall(require,"src.core.game3.cache_paths")
            if okPaths and type(Paths.CACHE_ROOT)=="string" then
                root=Paths.CACHE_ROOT
            end
            local rel=root.."/pokemon/front_shiny/"..key..".rgba"
            local okRead,bytes=pcall(c.read,c,rel)
            if okRead and type(bytes)=="string" and #bytes>=16384 then
                local okPic,pic=pcall(function()
                    local data=love.image.newImageData(
                        64,64,"rgba8",bytes:sub(1,16384))
                    local image=love.graphics.newImage(data)
                    if image.setFilter then
                        image:setFilter("nearest","nearest")
                    end
                    return {image=image,w=64,h=64}
                end)
                if okPic and pic then
                    fronts[key]=pic
                    return pic
                end
            end
        end
        -- Fallback to the engine's explicit shiny palette selector. This
        -- also handles Spinda's individual spots and ROM form variants.
        if type(Pokemon.frontPic)=="function" then
            local ok,pic=pcall(Pokemon.frontPic,species,nil,true,pid)
            if ok and type(pic)=="table" and pic.image then return pic end
        end
        return nil
    end
    function M.icon(Pokemon,mon)
        if not M.isShiny(Pokemon,mon) then return nil end
        local species,pid=frontInfo(Pokemon,mon)
        if not species then return nil end
        local key=tostring(species)..":"..(species==308
            and tostring(pid) or "0")
        if icons[key] then return icons[key] end
        local pic=M.front(Pokemon,mon)
        if not pic or not pic.image or not (love and love.graphics) then
            return nil
        end
        local g=love.graphics
        if type(g.newCanvas)~="function"
            or type(g.newQuad)~="function" then return nil end
        local pushed=false
        local ok,item=pcall(function()
            local canvas=g.newCanvas(32,64)
            g.push("all");pushed=true
            g.setCanvas(canvas)
            g.clear(0,0,0,0)
            g.setColor(1,1,1,1)
            -- Native mini-icon slots are 32x32, with two 32px frames.
            -- Reuse the correct shiny front art for both frames rather
            -- than returning the always-normal Gen 3 icon palette.
            g.draw(pic.image,0,0,0,.5,.5)
            g.draw(pic.image,0,32,0,.5,.5)
            g.setCanvas();g.pop();pushed=false
            return {image=canvas,w=32,h=32,sheetH=64,frames=2,
                quads={
                    [0]=g.newQuad(0,0,32,32,32,64),
                    [1]=g.newQuad(0,32,32,32,32,64),
                }}
        end)
        if pushed then pcall(g.pop);pcall(g.setCanvas) end
        if ok and item then
            icons[key]=item
            return item
        end
        return nil
    end
    function M.drawPcPortrait(Pokemon,mon)
        local pic=M.front(Pokemon,mon)
        if not pic or not pic.image or not love or not love.graphics
            then return false end
        local g=love.graphics
        local w,h=pic.w or 64,pic.h or 64
        g.setColor(1,1,1,1)
        g.draw(pic.image,40-w/2,48-h/2)
        -- Even if the ROM has no shiny icon art, the PC portrait clearly
        -- denotes its shiny identity without changing the native save.
        if type(g.polygon)=="function" then
            g.setColor(.98,.79,.34,1)
            g.polygon("fill",70,19,74,24,70,29,66,24)
        end
        g.setColor(1,1,1,1)
        return true
    end
    return M
end
