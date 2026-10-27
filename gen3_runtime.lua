-- EXPERIMENTAL Gen 3 path: classic Nuzlocke foundation.
-- Deliberately independent of main.lua's Gen 1/2 internals and save schema.
-- Only first-wild-encounter-per-area and post-battle permadeath are implemented.
return function(mod)
    local KEY = "gen3_classic_v1"
    local currentArea
    local activeBattle

    local function loadState()
        local s = mod.save:get(KEY, {})
        if type(s) ~= "table" then s = {} end
        if type(s.areas) ~= "table" then s.areas = {} end
        if type(s.graveyard) ~= "table" then s.graveyard = {} end
        s.enabled = s.enabled == true
        s.failed = s.failed == true
        return s
    end

    local function writeState(s)
        mod.save:set(KEY, s)
    end

    local function areaKey(value)
        if type(value) == "string" and value ~= "" then return value end
        if type(value) == "number" then return tostring(value) end
        return nil -- unknown maps must never be silently merged
    end

    local function game()
        return mod.game
    end

    local function session()
        local g = game()
        return g and g.session
    end

    local function areaNow()
        local s = session()
        return areaKey(currentArea) or areaKey(s and s.map)
    end

    local function isActive()
        local s = loadState()
        return s.enabled and not s.failed
    end

    local function retireFainted()
        local s = loadState()
        if not s.enabled or s.failed then return end
        local native = session()
        local party = native and native.party
        if type(party) ~= "table" then return end
        local modified = false
        for i = #party, 1, -1 do
            local mon = party[i]
            if type(mon) == "table" and mon.isEgg ~= true
                and (tonumber(mon.hp) or 0) <= 0 then
                s.graveyard[#s.graveyard + 1] = {
                    species = mon.species or mon.speciesId,
                    nickname = mon.nickname or mon.name,
                    level = mon.level,
                    area = areaNow(),
                }
                table.remove(party, i)
                modified = true
            end
        end
        if modified then
            if #party == 0 then s.failed = true end
            writeState(s)
        end
    end

    -- Gen 3's map.entered uses a native map ID, not a Gen 1 map name.
    mod.events:on("map.entered", function(ev)
        currentArea = type(ev) == "table" and areaKey(ev.mapId) or nil
    end)

    mod.events:on("save.loaded", function()
        currentArea = nil
        activeBattle = nil
    end)
    mod.events:on("save.created", function()
        currentArea = nil
        activeBattle = nil
    end)

    -- Record the FIRST encounter even if it runs or faints; later Balls fail.
    -- Tutorial battles and scripted trainer battles do not claim an area.
    mod.events:on("battle.started", function(ev)
        activeBattle = nil
        if not isActive() or type(ev) ~= "table" or ev.kind ~= "wild" then return end
        local key = areaNow()
        if not key then return end -- fail open rather than block unknown maps
        local s = loadState()
        local first = s.areas[key] == nil
        if first then
            s.areas[key] = { species = ev.species, speciesId = ev.speciesId, caught = false }
            writeState(s)
        end
        activeBattle = { battle = ev.battle, area = key, eligible = first }
    end)

    -- Gen 3's catch.rate wraps vanilla and returns (caught, shakes).
    -- This does not modify normal encounters or trainer battles.
    mod.hooks:wrap("catch.rate", function(next, ball, mon, species, ctx)
        if isActive() and activeBattle and not activeBattle.eligible
            and type(ctx) == "table" and ctx.battle == activeBattle.battle then
            return false, 0
        end
        return next(ball, mon, species, ctx)
    end)

    mod.events:on("pokemon.caught", function(ev)
        if not isActive() or not activeBattle or not activeBattle.eligible then return end
        if type(ev) ~= "table" or ev.battle ~= activeBattle.battle then return end
        local s = loadState()
        local area = s.areas[activeBattle.area]
        if type(area) == "table" then
            area.caught = true
            writeState(s)
        end
    end)

    -- The native Gen 3 battle bridge writes party HP back before battle.ended.
    -- Remove zero-HP party members then, avoiding mid-battle state corruption.
    mod.events:on("battle.ended", function()
        retireFainted()
        activeBattle = nil
    end)

    -- This is a deliberately small in-game toggle; other Nuzlocke rule settings
    -- are NOT offered until they have their own Gen 3 implementation.
    mod.hooks:wrap("ui.start_menu.items", function(next, g, items)
        local rows = next(g, items)
        if type(rows) ~= "table" or not (g and g.session) then return rows end
        local function labelFor(state)
            -- The native GBA menu has a narrow label column.
            return state.failed and "NUZ: LOST"
                or (state.enabled and "NUZ: ON" or "NUZ: OFF")
        end
        local row = {
            id = "nuzlocke_gen3_classic",
            label = labelFor(loadState()),
        }
        row.onSelect = function()
            local s = loadState()
            if not s.failed then
                s.enabled = not s.enabled
                writeState(s)
            end
            -- StartMenu draws the same entry table until it closes; update
            -- the live label so a player gets instant ON/OFF feedback.
            row.label = labelFor(s)
        end
        rows[#rows + 1] = row
        return rows
    end)

    -- Advertise supported scope without borrowing existing API-37 promises.
    mod.exports.gen3_classic = {
        api = 1,
        stage = "EXPERIMENTAL",
        features = { "first_wild_per_area", "post_battle_permadeath" },
        state = function()
            local s = loadState()
            return { enabled = s.enabled, failed = s.failed,
                areaCount = (function()
                    local n = 0
                    for _ in pairs(s.areas) do n = n + 1 end
                    return n
                end)(), deaths = #s.graveyard }
        end,
    }
end
