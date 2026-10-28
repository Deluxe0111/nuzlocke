-- EXPERIMENTAL Gen 3 runtime: CORE, encounter CLAUSES, independent shiny
-- odds, roamer slots and full-fidelity death archive for future recovery.
-- Deliberately independent of main.lua's Gen 1/2 save schema and UI.
return function(mod)
    local KEY = "gen3_classic_v1"
    -- Load mod-local modules without require-path assumptions. The mature
    -- Gen 1/2 runtime keeps its own API and its own save schema.
    local function readModule(path)
        local source, err = mod:read(path)
        assert(type(source) == "string",
            "Nuzlocke cannot read " .. path .. ": " .. tostring(err))
        local chunk, compileError = (loadstring or load)(
            source, "@mods/nuzlocke/" .. path)
        assert(type(chunk) == "function",
            "Nuzlocke cannot compile " .. path .. ": " .. tostring(compileError))
        return chunk()
    end
    local Core = readModule("gen3_core_rules.lua")()
    local Clauses = readModule("gen3_clauses.lua")()
    local ShinyRate = readModule("gen3_shiny_rate.lua")()
    local Archive = readModule("gen3_archive.lua")()
    local Eggs = readModule("gen3_eggs.lua")()
    local Forgiveness = readModule("gen3_forgiveness.lua")()
    local Display = readModule("gen3_display.lua")()
    local currentArea
    local activeBattle
    local pendingRoamer
    local battleInProgress = false
    local battleDeaths -- in-battle irrevocable faint records (not party-array removals)
    local setupDraft, pendingNewGameState

    local function loadState()
        local s = setupDraft or mod.save:get(KEY, {})
        return Clauses.normalise(Core.normalise(s))
    end

    local function writeState(s)
        if setupDraft then
            setupDraft = s
        else
            mod.save:set(KEY, s)
        end
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
        return Core.active(loadState())
    end

    -- Unlock the encounter ledger only once the player owns a usable Ball.
    -- This flag stays true after all Balls are spent or discarded.
    local function captureAvailable(s)
        if s.captureUnlocked == true then return true end
        local native = session()
        local bag = native and native.bag
        local pockets = bag and bag.pockets
        local balls = pockets and pockets.POKE_BALLS
        if type(balls) == "table" then
            for _, slot in pairs(balls) do
                if type(slot) == "table" and (tonumber(slot.qty) or 0) > 0 then
                    s.captureUnlocked = true
                    writeState(s)
                    return true
                end
            end
        end
        -- Legacy successful catches prove the unlock occurred; old spent
        -- records alone do not, since those may be pre-Ball false positives.
        for _, entry in pairs(s.areas or {}) do
            if type(entry) == "table" and entry.caught == true then
                s.captureUnlocked = true
                writeState(s)
                return true
            end
        end
        return false
    end

    -- Badge flags are saved in native script state; refresh when the player
    -- moves or opens Nuzlocke, not by polling each frame.
    local function refreshForgiveness()
        local saved = loadState()
        local mode = Clauses.get(saved, "route_forgiveness")
        if mode == 0 or not Core.active(saved) then return end
        local f = saved.forgiveness
        local before = f and f.tokens or 0
        local already = f and f.initialised
        local baselined = f and f.baselined
        local earned = Forgiveness.observe(saved, mode,
            Forgiveness.badges(session()))
        if earned > 0 or not already or
            (saved.forgiveness and saved.forgiveness.tokens ~= before)
            or (saved.forgiveness and
                saved.forgiveness.baselined ~= baselined) then
            writeState(saved)
        end
    end

    -- Shared after-change hook for the menu and versioned public API.
    local function onClauseChanged(saved, key)
        if key == "route_forgiveness" then
            Forgiveness.initialise(saved,
                Clauses.get(saved, key), Forgiveness.badges(session()))
        end
    end

    -- Game 3 battles operate on *copies* of session.party. Never table.remove
    -- from battle.playerParty while a fight is running: partyIndex values drive
    -- forced switches, two active battlers and end-of-battle writeback.
    local function samePokemon(a, b, indexMatches)
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        local pa, pb = a.personality, b.personality
        local sa, sb = a.species or a.speciesId, b.species or b.speciesId
        if pa ~= nil and pb ~= nil then
            return pa == pb and tostring(sa) == tostring(sb)
        end
        return indexMatches and tostring(sa) == tostring(sb)
            and tostring(a.nickname or a.name or "") == tostring(b.nickname or b.name or "")
    end

    local function retireFainted(outcome)
        local s = loadState()
        if not Core.active(s) then return end
        local native = session()
        local party = native and native.party
        if type(party) ~= "table" then return end
        local deathEnabled = Core.get(s, "permadeath")

        -- A faint event has already committed the death to mod.save. Match the
        -- event's battle-party copy back to its native session counterpart,
        -- including selected-party/subset battles where slot numbers differ.
        if battleDeaths and type(battleDeaths.pending) == "table" then
            local claimed = {}
            for _, death in ipairs(battleDeaths.pending) do
                for index, mon in ipairs(party) do
                    if not claimed[index] and samePokemon(death.mon, mon,
                        index == death.slot and not battleDeaths.partySubset) then
                        mon.nuzlockeDead = true
                        mon.nuzlockeDeathRecorded = true
                        mon.hp = 0
                        claimed[index] = true
                        break
                    end
                end
            end
        end

        local modified = false
        for i = #party, 1, -1 do
            local mon = party[i]
            if type(mon) == "table" and mon.isEgg ~= true
                and (mon.nuzlockeDead == true
                    or (deathEnabled and (tonumber(mon.hp) or 0) <= 0)) then
                if not mon.nuzlockeDeathRecorded then
                    local entry = Display.memorial(mon, areaNow(),
                        "Fainted in battle")
                    entry.archive, entry.archiveComplete = Archive.snapshot(mon)
                    s.graveyard[#s.graveyard + 1] = entry
                end
                table.remove(party, i)
                modified = true
            end
        end
        -- Whiteout ends the run even when reserve Pokémon remain in the PC.
        -- PC-survivor recovery stays [Soon] until a safe empty-party recovery
        -- path exists in both Kanto and Hoenn. Do not delete user saves.
        if Core.failedWhiteout(s, outcome) then s.failed = true end
        if #party == 0 then s.failed = true end
        if modified or s.failed then writeState(s) end
    end

    local function recordBattleFaint(ev)
        if not Core.enforced(loadState(), "permadeath")
            or type(ev) ~= "table" then return end
        local battler = ev.battler
        if type(battler) ~= "table" or
            (ev.sideName ~= "player" and battler.side ~= "player") then return end
        local battle = ev.battle
        local party = battle and battle.playerParty
        local slot = tonumber(battler.partyIndex)
        if type(party) ~= "table" or not slot or not party[slot] then return end
        if not battleDeaths or battleDeaths.battle ~= battle then
            battleDeaths = { battle = battle, pending = {}, seen = {} }
        end
        if battleDeaths.seen[slot] then return end
        local mon = party[slot]
        if mon.isEgg then return end
        local archived, complete = Archive.snapshot(mon)
        battleDeaths.seen[slot] = true
        battleDeaths.pending[#battleDeaths.pending + 1] = { mon = mon, slot = slot }
        -- Capture before the next forced-switch/revive decision. Existing
        -- battle/UI references remain intact; the mon is now irrevocably dead.
        mon.nuzlockeDead = true
        battler.mon.nuzlockeDead = true
        local s = loadState()
        local entry = Display.memorial(mon, areaNow(), "Fainted in battle")
        entry.archive = archived
        entry.archiveComplete = complete
        s.graveyard[#s.graveyard + 1] = entry
        writeState(s)
    end

    -- The native battle-item UI and the actual item transaction are distinct.
    -- Block revival at BOTH points; preventing the party menu option alone
    -- would allow another caller to bypass the rule.
    local function installReviveGuard()
        local okB, BattleItems = pcall(require, "src.core.game3.battle.items")
        local okD, ItemsData = pcall(require, "src.core.game3.items_data")
        local okU, ItemUse = pcall(require, "src.core.game3.item_use")
        if not (okB and okD and okU and type(BattleItems) == "table"
            and type(ItemsData) == "table" and type(ItemUse) == "table") then
            return false
        end
        if BattleItems.__nuzlockeGen3GuardOwner == mod then return true end
        if type(BattleItems.canUseOn) ~= "function"
            or type(BattleItems.use) ~= "function" then return false end
        local originalCanUse, originalUse = BattleItems.canUseOn, BattleItems.use

        local function isRevive(itemId, nativeSession)
            local okKind, kind = pcall(ItemsData.medicineKind, itemId)
            if okKind and kind == "revive" then return true end
            local okField, field = pcall(ItemUse.fieldUseKind,
                itemId, nativeSession, true)
            return okField and field == "revive"
        end

        BattleItems.canUseOn = function(st, itemId, partySlot, mon, moveSlot)
            if Core.enforced(loadState(), "permadeath")
                and isRevive(itemId, st and st.session) then
                return false, "Nuzlocke: No revives."
            end
            return originalCanUse(st, itemId, partySlot, mon, moveSlot)
        end

        BattleItems.use = function(st, adapter, bag, nativeSession, itemId, ...)
            if Core.enforced(loadState(), "permadeath")
                and isRevive(itemId, nativeSession) then
                local message = "Nuzlocke: No revives."
                if adapter and type(adapter.say) == "function" then
                    adapter:say(message)
                end
                return "error", { message }, false, false
            end
            return originalUse(st, adapter, bag, nativeSession, itemId, ...)
        end
        BattleItems.__nuzlockeGen3GuardOwner = mod
        return true
    end

    -- Gen 3's map.entered uses a native map ID, not a Gen 1 map name.
    mod.events:on("map.entered", function(ev)
        currentArea = type(ev) == "table" and areaKey(ev.mapId) or nil
        pendingRoamer = nil -- never match a roamer across unrelated maps
        refreshForgiveness()
    end)

    mod.events:on("breeding.egg_created", function(ev)
        local s = loadState()
        Eggs.created(s, ev, areaNow())
        -- Provenance attaches directly to the egg; save-local fields are not
        -- spent until the actual hatch event confirms an acquired Pokemon.
    end)
    mod.events:on("egg.hatched", function(ev)
        if not isActive() then return end
        local saved = loadState()
        local mode = Clauses.get(saved, "gen3_egg_encounter_mode")
        local valid, reason = Eggs.hatched(saved, ev, areaNow(), mode)
        if type(ev) == "table" and type(ev.mon) == "table" then
            saved.eggHistory = saved.eggHistory or {}
            saved.eggHistory[#saved.eggHistory + 1] = {
                species = ev.species, location = areaNow(),
                status = reason, origin = ev.egg and ev.egg.nuzEggOrigin,
            }
        end
        writeState(saved)
    end)

    -- Fires before the native Gen 3 wild battle is started. Useful even if
    -- the provider clones the roamer and loses its original roamer=true flag.
    mod.events:on("roamer.encountered", function(ev)
        if type(ev) ~= "table" then return end
        pendingRoamer = {
            speciesId = Clauses.speciesId(ev.species),
            mapId = areaKey(ev.mapId),
        }
    end)

    mod.events:on("save.loaded", function()
        setupDraft = nil
        pendingNewGameState = nil
        currentArea = nil
        activeBattle = nil
        pendingRoamer = nil
        battleInProgress = false
        battleDeaths = nil
    end)
    mod.events:on("save.created", function()
        -- Apply setup to the newly adopted save, not the old title save.
        if pendingNewGameState then
            pendingNewGameState._setup = nil
            mod.save:set(KEY, pendingNewGameState)
            pendingNewGameState = nil
        end
        setupDraft = nil
        currentArea = nil
        activeBattle = nil
        pendingRoamer = nil
        battleInProgress = false
        battleDeaths = nil
    end)

    -- Record the FIRST encounter even if it runs or faints; later Balls fail.
    -- Tutorial battles and scripted trainer battles do not claim an area.
    mod.events:on("battle.started", function(ev)
        activeBattle = nil
        battleInProgress = true
        battleDeaths = nil
        -- Install after the engine's battle modules exist, before any item turn.
        installReviveGuard()
        local announcedRoamer = pendingRoamer
        pendingRoamer = nil -- the next battle is the only possible match
        -- Shiny Rate is a gameplay-independent generation setting (like
        -- Game Difficulty), so it works even with Nuzlocke enforcement OFF.
        -- Apply once, BEFORE Shiny Clause checks encounter eligibility.
        local shinyMode = Clauses.get(loadState(), "shiny_rate_mode")
        ShinyRate.apply(mod, ev, shinyMode, function()
            if love and love.math and love.math.random then
                return love.math.random()
            end
            return math.random()
        end, function(mon)
            local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
            if not ok or not Pokemon or not Pokemon.isShiny then
                error("Gen 3 native shiny resolver unavailable")
            end
            return Pokemon.isShiny(mon)
        end)
        if not isActive() or type(ev) ~= "table" or ev.kind ~= "wild" then return end
        local key = areaNow()
        if not key then return end -- fail open rather than block unknown maps
        local s = loadState()
        if not captureAvailable(s) then return end
        local native = session()
        local enemy = ev.battle and ev.battle.enemy
        local wildMon = enemy and enemy.mon
        local species = ev.speciesId or ev.species
            or (wildMon and (wildMon.species or wildMon.speciesId))
        local spId = Clauses.speciesId(species)
        local edition = native and (native.edition or native.version
            or native.gameId) or "gen3"
        local markedRoamer = wildMon and wildMon.roamer == true
            or (ev.battle and ev.battle.roamer == true)
        local eventRoamer = announcedRoamer
            and announcedRoamer.speciesId ~= nil
            and announcedRoamer.speciesId == spId
            and (not announcedRoamer.mapId
                or announcedRoamer.mapId == key)
        local roamer = Clauses.roamerActive(s)
            and (markedRoamer or eventRoamer) and spId ~= nil
        local roamerOpen = not roamer or Clauses.roamerAvailable(s, spId)
        local areaEligible = roamer or Core.catchAllowed(s, key)
        -- The roamer's species slot replaces the map slot; a free roamer
        -- encounter never consumes this map, even if it flees or faints.
        local dupe = Clauses.isDuplicate(s, species, native, edition)
        local eligible = areaEligible and roamerOpen and not dupe
        local entry = s.areas[key]
        if eligible and not roamer then
            -- Failed encounters spend normal eligible encounters only.
            -- Skipped duplicate species never claim a route.
            if type(entry) ~= "table" then
                entry = { species = ev.species, speciesId = ev.speciesId,
                    caught = false, spent = false, attempts = 0 }
            end
            entry.attempts = (tonumber(entry.attempts) or 0) + 1
            if Core.shouldSpendOnStart(s) then entry.spent = true end
            s.areas[key] = entry
            writeState(s)
        end
        activeBattle = {
            battle = ev.battle, area = key, eligible = eligible,
            areaEligible = areaEligible, duplicate = dupe,
            shiny = Clauses.isShiny(wildMon),
            exception = false,
            roamer = roamer, roamerOpen = roamerOpen,
            roamerSpecies = spId,
        }
    end)

    -- Gen 3's catch.rate wraps vanilla and returns (caught, shakes).
    -- This does not modify normal encounters or trainer battles.
    mod.hooks:wrap("catch.rate", function(next, ball, mon, species, ctx)
        local battle = activeBattle
        if not isActive() or not battle or type(ctx) ~= "table"
            or ctx.battle ~= battle.battle then
            return next(ball, mon, species, ctx)
        end
        local s = loadState()
        local limited = Core.get(s, "encounter_limit")
        local blockedByArea = limited and not battle.areaEligible
        local blockedByDupe = battle.duplicate
        local blockedByRoamer = battle.roamer and not battle.roamerOpen
        local exception = not blockedByRoamer
            and (blockedByArea or blockedByDupe)
            and Clauses.canUseShinyException(s)
            and (Clauses.isShiny(mon) or battle.shiny)
        if blockedByRoamer
            or ((blockedByArea or blockedByDupe) and not exception) then
            return false, 0
        end
        local caught, shakes = next(ball, mon, species, ctx)
        -- A failed Ball never consumes a Shiny Clause allowance.
        if caught and exception then battle.exception = true end
        return caught, shakes
    end)

    mod.events:on("pokemon.caught", function(ev)
        if not isActive() or not activeBattle then return end
        if type(ev) ~= "table" or ev.battle ~= activeBattle.battle then return end
        local s = loadState()
        local caughtSpecies = ev.speciesId or ev.species
            or (ev.mon and (ev.mon.species or ev.mon.speciesId))
        -- If the battle mon was generated shiny by Nuzlocke, preserve that
        -- explicit identity on the just-cloned captured Pokémon as well.
        local battleMon = activeBattle.battle and activeBattle.battle.enemy
            and activeBattle.battle.enemy.mon
        if battleMon and battleMon.nuzlockeShinyRateBoosted
            and type(ev.mon) == "table" then
            ev.mon.isShiny = true
            ev.mon.nuzlockeShinyRateBoosted = true
        end
        Clauses.noteCaught(s, caughtSpecies, activeBattle.exception)
        -- A captured roamer closes its *species* slot, not the current route.
        -- Exceptional shiny captures never close the ordinary encounter slot.
        if activeBattle.roamer then
            Clauses.claimRoamer(s, activeBattle.roamerSpecies)
        elseif activeBattle.eligible and not activeBattle.exception then
            local area = s.areas[activeBattle.area]
            if type(area) == "table" then
                area.caught = true
                area.spent = true
                area.caughtSpeciesId = caughtSpecies
            end
        end
        writeState(s)
    end)

    -- The engine emits this while the faint is being announced, before the
    -- forced-switch UI. Death is immediate; array compaction is deferred.
    mod.events:on("battle.fainted", recordBattleFaint)

    -- The native battle bridge writes back party HP before battle.ended.
    -- Compact party arrays only then, after the engine no longer needs indices.
    mod.events:on("battle.ended", function(ev)
        retireFainted(type(ev) == "table" and ev.result or nil)
        activeBattle = nil
        battleInProgress = false
        battleDeaths = nil
    end)

    -- Gen 3 is API 2 in this fork, and API 3's mod.ui.push uses a different
    -- UI bridge. Keep API 2 for the mature Gen 1/2 code and use the native
    -- Game 3 stack in a mod-local isolated menu module instead.
    local Dev = readModule("gen3_dev.lua")({
        getState = loadState, setState = writeState,
        getCurrentArea = areaNow, getSession = session,
        inBattle = function() return battleInProgress end,
        areaSpent = Core.areaSpent,
    })
    local Gen3Menu = readModule("gen3_menu.lua")(mod, {
        getState = loadState, setState = writeState,
        core = Core, clauses = Clauses, shinyRate = ShinyRate,
        eggs = Eggs, forgiveness = Forgiveness,
        onClauseChanged = onClauseChanged,
        dev = Dev, display = Display,
    })

    -- Native Gen 3 boot flow: setup precedes new-game scene across editions.
    readModule("gen3_title_setup.lua")(mod, {
        menu = Gen3Menu,
        beginSetup = function(done)
            setupDraft = Clauses.normalise(Core.normalise({
                enabled = false, failed = false, areas = {}, graveyard = {},
                runSettingsLocked = false, captureUnlocked = false,
                _setup = true,
            }))
            pendingNewGameState = nil
            return Gen3Menu.openSetup(game(), function(accepted)
                if accepted then
                    setupDraft._setup = nil
                    pendingNewGameState = setupDraft
                end
                setupDraft = nil
                if type(done) == "function" then done(accepted) end
            end)
        end,
    })

    mod.hooks:wrap("ui.start_menu.items", function(next, g, items)
        local rows = next(g, items)
        if type(rows) ~= "table" or not (g and g.session) then return rows end
        -- Mirror the Gen 1/2 entry: one Start-menu destination.
        table.insert(rows, {
            id = "nuzlocke.gen3.menu",
            label = "NUZ MENU",
            onSelect = function()
                refreshForgiveness()
                Gen3Menu.open(g)
            end,
        })
        return rows
    end)

    mod.exports.gen3_menu = Gen3Menu
    -- Read-only diagnostic API. Mutators stay internal to the developer menu.
    mod.exports.gen3_clauses = {
        api = 1, schema = Clauses.schema,
        definitions = Clauses.descriptors,
        getMode = function(key)
            return Clauses.get(loadState(), key)
        end,
        shinyRateOwner = function()
            return ShinyRate.externalProvider(mod) or "Nuzlocke"
        end,
        setMode = function(key, value)
            if key == "shiny_rate_mode" and ShinyRate.externalProvider(mod) then
                return false, "external_provider"
            end
            local saved = loadState()
            local ok, reason = Clauses.set(saved, key, value)
            if ok then
                onClauseChanged(saved, key)
                writeState(saved)
            end
            return ok, reason
        end,
        summary = function()
            local saved = loadState()
            return { shinyExceptionsUsed = saved.shinyExceptionsUsed,
                forgivenessTokens = Forgiveness.balance(saved),
                eggsTracked = #(saved.eggHistory or {}),
                roamerClaims = (function()
                    local count = 0
                    for _, v in pairs(saved.roamerClaims or {}) do
                        if v then count = count + 1 end
                    end
                    return count
                end)(),
                speciesRecorded = (function()
                    local count = 0
                    for _ in pairs(saved.capturedSpecies) do count = count + 1 end
                    return count
                end)() }
        end,
    }
    mod.exports.gen3_dev_info = { api = 1, snapshot = Dev.inspect,
        status = Dev.status }

    -- Versioned integration contract: callers may inspect a COPY of state
    -- or ask whether a rule is enabled, but cannot bypass implementation gates.
    mod.exports.gen3_core = {
        api = 1,
        schema = Core.schema,
        definitions = Core.descriptors,
        getRule = function(key)
            return Core.get(loadState(), key)
        end,
        setRule = function(key, value)
            local state = loadState()
            local ok, err = Core.set(state, key, value)
            if ok then writeState(state) end
            return ok, err
        end,
    }

    -- Advertise supported scope without borrowing existing API-37 promises.
    mod.exports.gen3_classic = {
        api = 1,
        stage = "EXPERIMENTAL",
        features = { "first_wild_per_area", "optional_failed_encounters",
            "gen3_dupes_clause", "gen3_shiny_clause", "gen3_roamer_clause",
            "gen3_shiny_rate", "gen3_eggs_wip",
            "gen3_route_forgiveness_wip",
            "immediate_faint_death", "revive_denial", "post_battle_retirement",
            "whiteout_ends_run" },
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
