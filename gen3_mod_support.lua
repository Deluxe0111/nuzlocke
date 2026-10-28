-- Gen 3 MOD SUPPORT: live, read-only detection for supported integration
-- surfaces. Detection is not a guarantee of combined-ROM compatibility.
-- Unlike Gen 1/2 provider preferences, Gen 3 has no safe ownership
-- switches; rule enforcement and existing hook composition stay automatic.
return function()
    local M={api=1}

    local function locate(mod,id)
        if type(mod)~="table" or type(mod.find)~="function" then
            return "UNKNOWN"
        end
        local ok,other=pcall(mod.find,mod,id)
        if not ok then return "UNKNOWN" end
        if type(other)=="table" and other~=mod then
            return "DETECTED"
        end
        return "NOT FOUND"
    end

    function M.inspect(mod,shinyRate,randomizer,s)
        local provider=shinyRate and
            type(shinyRate.externalProvider)=="function"
            and shinyRate.externalProvider(mod) or nil
        local randomWild=randomizer and
            type(randomizer.get)=="function"
            and randomizer.get(s,"random_encounter_tables")==true
        local randomTrainers=randomizer and
            type(randomizer.get)=="function"
            and randomizer.get(s,"random_trainers")==true
        return {
            untamed=locate(mod,"untamed_advanced"),
            shiny=provider and "EXTERNAL" or "NUZLOCKE",
            shinyOwner=provider,
            otherRandomizer=locate(mod,"pokemon_randomizer"),
            wildRandom=not not randomWild,
            trainerRandom=not not randomTrainers,
        }
    end
    return M
end
