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
    local CatchRules = readModule("gen3_catch_rules.lua")()
    local BattleItemRules = readModule("gen3_battle_items.lua")()
    local FieldRules = readModule("gen3_field_items.lua")()
    local Variants = readModule("gen3_variants.lua")()
    local BattleClauses = readModule("gen3_battle_clauses.lua")()
    local StatusBans = readModule("gen3_status_bans.lua")()
    local Playstyles = readModule("gen3_playstyles.lua")()
    local ShinyRate = readModule("gen3_shiny_rate.lua")()
    local Archive = readModule("gen3_archive.lua")()
    local Eggs = readModule("gen3_eggs.lua")()
    local Forgiveness = readModule("gen3_forgiveness.lua")()
    local Display = readModule("gen3_display.lua")()
    local Extra = readModule("gen3_extra_core.lua")()
    local Levels = readModule("gen3_levels.lua")()
    local Notices = readModule("gen3_notices.lua")()
    local Randomizer = readModule("gen3_randomizer.lua")()
    local currentArea
    local activeBattle
    local pendingRoamer
    local battleInProgress = false
    local currentBattleState
    local battleDeaths -- in-battle irrevocable faint records (not party-array removals)
    local mercyBattle
    local expReports = setmetatable({}, { __mode = "k" })
    local function loadState()
        local s = Core.normalise(mod.save:get(KEY, {}))
        return Clauses.normalise(s)
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

    -- Untamed builds OWE personalities before there is a wild battle. Keep
    -- a small bounded cache of those exact individuals so the ordinary
    -- battle-start shiny-rate handler never rerolls a visible non-shiny.
    local oweShinySeen, oweShinyOrder = {}, {}
    local function oweShinyIdentity(species, personality)
        if type(personality) ~= "number"
            or type(species) ~= "number"
            or personality < 0 or personality ~= math.floor(personality) then
            return nil
        end
        return tostring(species) .. ":" .. tostring(personality)
    end
    local function noteOWEShiny(species, personality)
        local key = oweShinyIdentity(species, personality)
        if not key or oweShinySeen[key] then return end
        oweShinySeen[key] = true
        oweShinyOrder[#oweShinyOrder + 1] = key
        if #oweShinyOrder > 256 then
            oweShinySeen[table.remove(oweShinyOrder, 1)] = nil
        end
    end
    local function resetOWEShinies()
        oweShinySeen, oweShinyOrder = {}, {}
    end
    local function shinyRandomUnit()
        if love and love.math and love.math.random then
            return love.math.random()
        end
        return math.random()
    end

    -- Gen 3 RANDOMIZER deliberately runs even if Nuzlocke rules are OFF.
    local function randomSpecies(source, key, original)
        local saved = loadState()
        local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
        if not ok then return nil end
        local usedBefore = Randomizer.locked(saved)
        local result, name = Randomizer.replace(saved, Pokemon, source,
            key, original, function()
                -- AUTO consumes engine entropy once per game save and stores
                -- the resolved seed; all subsequent selections are pure.
                return math.random(1, 99999999)
            end,function(national)
                return Core.active(saved)
                    and CatchRules.isBannedNational(saved,national)
            end)
        if result then
            if not usedBefore then
                Notices.add(saved, "RANDOMIZER_LOCK",
                    "Randomiser seed and settings locked after first result.")
            end
            writeState(saved)
        end
        return result, name
    end

    mod.hooks:wrap("encounter.species", function(next, encounter, ctx)
        local base = next(encounter, ctx)
        if type(base) ~= "table" or not ctx
            or ctx.mapId == nil or base.roamer == true then return base end
        local original = base.speciesId or base.species
        -- Do not serialize a table's pointer address into the source key.
        -- Only stable scalar terrain identifiers are reproducible on reload.
        local terrain = (type(ctx.terrain) == "string"
            or type(ctx.terrain) == "number") and ctx.terrain or ""
        local key = table.concat({ tostring(ctx.mapId),
            tostring(terrain), tostring(original),
            tostring(base.level or "") }, ":")
        local id, name = randomSpecies("ENCOUNTERS", key, original)
        if not id then return base end
        local copy = {}
        for k, v in pairs(base) do copy[k] = v end
        copy.species = name
        copy.speciesId = id
        return copy
    end)
    -- Untamed-Advanced's wandering overworld Pokemon are authored and
    -- spawned independently of encounter.species. Its opt-in hook fires
    -- BEFORE building the world sprite and before creating the battle foe.
    -- Same Wild toggle, Gen 3 pool, fixed/AUTO seed, and balance policy.
    mod.hooks:wrap("untamed.owe.species", function(next, encounter, ctx)
        local base = next(encounter, ctx)
        if type(base) ~= "table" or type(ctx) ~= "table"
            or ctx.source ~= "untamed_advanced" or ctx.mapId == nil
            or (ctx.terrain ~= "land" and ctx.terrain ~= "water")
            or base.roamer == true or base.scripted == true then
            return base
        end
        local original = tonumber(base.species)
        local level = tonumber(base.level)
        if not original or original % 1 ~= 0 or original <= 0
            or not level or level % 1 ~= 0
            or level < 1 or level > 100 then return base end
        -- Keep this separate from native step/rod mapping: an OWE's
        -- unique source is the visible spawn, not a vanilla step roll.
        -- Coords are intentionally excluded, so the same original wild
        -- species on a route retains its identity across spawn locations.
        local key = table.concat({ "OWE", tostring(ctx.mapId),
            ctx.terrain, tostring(original) }, ":")
        local id = randomSpecies("ENCOUNTERS", key, original)
        if not id then return base end
        local copy = {}
        for k, v in pairs(base) do copy[k] = v end
        copy.species = id -- Untamed expects an internal numeric species ID.
        return copy
    end)

    -- The same CLAUSES -> SHINY RATE applies to generated Untamed OWEs,
    -- irrespective of Random Wild and whether Nuzlocke playstyle is ON.
    -- Untamed owns final native personality conversion and visual checks.
    mod.hooks:wrap("untamed.owe.shiny", function(next, source, ctx)
        local base = next(source, ctx)
        if type(base) ~= "table" or type(ctx) ~= "table"
            or ctx.source ~= "untamed_advanced" or ctx.mapId == nil
            or (ctx.terrain ~= "land" and ctx.terrain ~= "water")
            or type(base.species) ~= "number"
            or type(base.level) ~= "number"
            or type(base.personality) ~= "number"
            or type(base.shiny) ~= "boolean" then return base end

        local final = base
        local mode = Clauses.get(loadState(), "shiny_rate_mode")
        local extra = ShinyRate.extraProbability(mode)
        if not base.shiny and extra > 0
            and not ShinyRate.externalProvider(mod)
            and type(ctx.makeShiny) == "function"
            and (extra >= 1 or shinyRandomUnit() < extra) then
            local ok, pid = pcall(ctx.makeShiny, base.personality)
            if ok and type(pid) == "number" and pid ~= base.personality
                and pid == math.floor(pid) and pid >= 0
                and pid < 4294967296
                and pid % 65536 == base.personality % 65536 then
                final = {}
                for k, v in pairs(base) do final[k] = v end
                final.personality, final.shiny = pid, true
            end
        end
        -- Record even native/unchanged results. If rate settings are
        -- changed while a sprite is already standing on the map, that
        -- individual still keeps the shiny status it was spawned with.
        noteOWEShiny(final.species, final.personality)
        return final
    end)

    -- Fishing has an independent engine hook, NOT encounter.species.
    mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, pool)
        local base = next(rod, mapId, pool)
        if type(base) ~= "table" or mapId == nil or base.roamer then
            return base end
        local original = base.speciesId or base.species
        local key = table.concat({ tostring(mapId), tostring(rod),
            tostring(original), tostring(base.level or "") }, ":")
        local id, name = randomSpecies("ENCOUNTERS", "FISH:" .. key, original)
        if not id then return base end
        local copy = {}
        for k, v in pairs(base) do copy[k] = v end
        copy.species, copy.speciesId = name, id
        return copy
    end)
    mod.hooks:wrap("trainer.party", function(next, trainerClass,
            trainerId, party)
        local original = next(trainerClass, trainerId, party)
        if type(original) ~= "table" or #original == 0
            or tonumber(trainerId) == nil or tonumber(trainerId) <= 0 then
            return original
        end
        local result, changed = {}, false
        for i, member in ipairs(original) do
            local newMember = {}
            for k, v in pairs(member) do newMember[k] = v end
            local key = tostring(trainerClass or "") .. ":"
                .. tostring(trainerId) .. ":" .. tostring(i)
                .. ":" .. tostring(member.speciesId or member.species or "")
            local id, name = randomSpecies("TRAINERS", key,
                member.speciesId or member.species)
            if id then
                newMember.species, newMember.speciesId = name, id
                changed = true
            end
            result[i] = newMember
        end
        return changed and result or original
    end)

    local function isActive()
        return Core.active(loadState())
    end

    local function nicknameTasks()
        local saved = loadState()
        if not Core.enforced(saved, "nickname_rule") then return {} end
        local previous = saved.nicknamePending or {}
        local tasks = Extra.auditNicknames(saved, session(), Display)
        local newlyPending = 0
        for _, item in ipairs(tasks) do
            if not previous[item.id] then newlyPending = newlyPending + 1 end
        end
        if newlyPending > 0 then
            Notices.add(saved, "NICKNAME_TASKS",
                tostring(newlyPending) .. " Pokemon need a nickname. "
                .. "Open NUZ MENU > NICKNAME TASKS.")
        end
        writeState(saved)
        return tasks
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
        if earned > 0 then
            Notices.add(saved, "FORGIVENESS_EARNED",
                "Route Forgiveness: earned " .. tostring(earned)
                .. " token(s) from new Gym badges.")
        end
        if earned > 0 or not already or
            (saved.forgiveness and saved.forgiveness.tokens ~= before)
            or (saved.forgiveness and
                saved.forgiveness.baselined ~= baselined) then
            writeState(saved)
        end
    end

    local function levelCap(saved)
        saved = saved or loadState()
        -- Hardcore requires every main-story gym/league boss cap through
        -- Champion, without modifying the user's own LEVELS scope.
        local scope = Playstyles.hardcoreActive(saved, Core) and 3 or nil
        return Levels.cap(saved, session(),
            Forgiveness.badges(session()), scope)
    end
    local function notify(code, message, inBattle)
        local saved = loadState()
        if Notices.add(saved, code, message) then writeState(saved) end
        if inBattle then Notices.battle(message) end
    end
    -- Gen 3 scripted gifts have a pre-mutation script.command seam.
    -- The gift opcode returns code 0/1 on success and 2 on failure.
    -- Block the opcode itself rather than deleting an already-owned mon.
    local function giftStarterExempt(mapId)
        local party=session() and session().party
        if type(party)~="table" or #party~=0 then return false end
        return mapId=="FR_OAKS_LAB"
            or mapId=="RU_ROUTE_101" or mapId=="SA_ROUTE_101"
            or mapId=="EM_ROUTE_101"
    end
    local function scriptVar(ctx,id)
        local vm=type(ctx)=="table" and (ctx.runner or ctx.vm)
        local raw=type(vm)=="table" and vm.ctx
        if type(raw)~="table" then return nil end
        local ok,F=pcall(require,"src.core.game3.scripting.flags")
        if not ok or type(F)~="table" or type(F.getVar)~="function" then
            return nil
        end
        -- package.loaded is unavailable to sandboxed Gen1Recomp mods.
        local okSpace,space=pcall(require,
            "src.core.game3.scripting.space")
        local store=okSpace and space and space.store
            or (session() and session().store)
        local success,v=pcall(F.getVar,store,raw,id)
        return success and v or nil
    end
    local function setScriptVar(ctx,id,value)
        local vm=type(ctx)=="table" and (ctx.runner or ctx.vm)
        local raw=type(vm)=="table" and vm.ctx
        if type(raw)~="table" then return false end
        local ok,F=pcall(require,"src.core.game3.scripting.flags")
        if not ok or type(F)~="table" or type(F.setVar)~="function" then
            return false
        end
        -- package.loaded is unavailable to sandboxed Gen1Recomp mods.
        local okSpace,space=pcall(require,
            "src.core.game3.scripting.space")
        local store=okSpace and space and space.store
            or (session() and session().store)
        return pcall(F.setVar,store,raw,id,value)
    end
    local function pokemonResolver()
        local ok,P=pcall(require,"src.core.game3.pokemon")
        return ok and P or nil
    end
    local function acquisitionEligible(kind,species,location,options)
        local saved=loadState()
        options=options or {}
        local native=session()
        local seed=tostring(native and native.trainerId or "")
            ..":"..tostring(native and native.trainerSecretId or "")
            ..":"..tostring(native and native.name or "")
        local resolver=pokemonResolver()
        if Core.active(saved) and not options.mandatoryStarter then
            local a=CatchRules.prepareAlphabet(saved,resolver,seed)
            local b=CatchRules.prepareColor(saved,resolver,seed)
            local c=Variants.prepare(saved,resolver,seed)
            if a or b or c then writeState(saved) end
        end
        options.seed=seed
        local allowed,why=CatchRules.canAcquire(saved,kind,species,
            location,resolver,Core,options)
        if not allowed or options.mandatoryStarter then return allowed,why end
        return Variants.check(saved,species,resolver,Core,seed,kind)
    end
    local function scriptGiftSpecies(ctx,row)
        local id=type(row)=="table" and (row[1] or row.species)
        local n=tonumber(id)
        if n and n>=0x4000 then return scriptVar(ctx,n) end
        return n or id
    end
    local function acquisitionReceipt(kind,species,location)
        local saved=loadState()
        if not CatchRules.noteAcquired(saved,kind,species,location,Core)
            then return end
        Clauses.noteCaught(saved,species,false)
        writeState(saved)
        notify("ACQUISITION", (kind=="gift" and "Gift Pokemon" or
            "In-Game Trade")..": received Pokemon ("..
            tostring(CatchRules.get(saved,kind=="gift"
                and "gift_slot_policy" or "trade_slot_policy")==0
                and "AREA" or "BONUS").." slot).")
    end
    mod.hooks:wrap("script.command",function(next,ctx,op,row)
        if not Core.active(loadState()) or type(row)~="table" then
            return next(ctx,op,row)
        end
        if op=="givemon" then
            local species=scriptGiftSpecies(ctx,row)
            local location=areaNow()
            local mandatoryStarter=giftStarterExempt(location)
            local permitted,why=acquisitionEligible("gift",species,
                location,{mandatoryStarter=mandatoryStarter})
            if not permitted and setScriptVar(ctx,0x800D,2) then
                notify("GIFT_DENIED",why)
                return false
            end
            local result=next(ctx,op,row)
            local code=scriptVar(ctx,0x800D)
            if permitted and (code==0 or code==1)
                and not mandatoryStarter then
                acquisitionReceipt("gift",species,location)
            end
            return result
        end
        if op=="special" or op=="specialvar" then
            local ok,Natives=pcall(require,
                "src.core.game3.scripting.natives")
            if ok and type(Natives)=="table"
                and type(Natives.specialName)=="function" then
                local id=op=="specialvar" and row[2]
                    or (row.id or row[1])
                local resolved,name=pcall(Natives.specialName,id)
                if resolved and name=="GetInGameTradeSpeciesInfo" then
                    local okTrade,Trade=pcall(require,
                        "src.core.game3.scripting.natives_trade")
                    local index=scriptVar(ctx,0x8004)
                    local okEntry,entry=false,nil
                    if okTrade and Trade and Trade.entry then
                        okEntry,entry=pcall(Trade.entry,index)
                    end
                    if okEntry and type(entry)=="table" then
                        local permitted,why=acquisitionEligible(
                            "trade",entry.species,areaNow())
                        -- This native special only supplies the requested
                        -- species for the NPC dialogue. Run it first so its
                        -- display strings are still populated, then force
                        -- a species mismatch BEFORE any exchange can start.
                        if not permitted then
                            local output=next(ctx,op,row)
                            local dest=op=="specialvar" and row[1]
                                or 0x800D
                            if setScriptVar(ctx,dest,0) then
                                notify("TRADE_DENIED",why)
                            end
                            return output
                        end
                    end
                end
            end
        end
        return next(ctx,op,row)
    end)

    -- The common FRLG/RSE NPC exchange writes the outgoing party slot in
    -- Trade.tradeMons. Record only a completed swap; do not mistake the
    -- preview/create-offered-Pokemon scratch party for a real acquisition.
    local function installAcquisitionGuards()
        local ok,Trade=pcall(require,
            "src.core.game3.scripting.natives_trade")
        if not ok or type(Trade)~="table"
            or type(Trade.tradeMons)~="function" then return end
        if Trade.__nuzAcquisitionOwner==mod
            and Trade.tradeMons==Trade.__nuzAcquisitionWrap then return end
        local previous=Trade.tradeMons
        local function guarded(sess,slot,offered)
            local species=type(offered)=="table"
                and (offered.species or offered.speciesId)
            local location=areaNow()
            local permitted,why=acquisitionEligible(
                "trade",species,location)
            if not permitted then
                notify("TRADE_DENIED",why)
                return nil
            end
            local sent=previous(sess,slot,offered)
            if sent then acquisitionReceipt("trade",species,location) end
            return sent
        end
        Trade.tradeMons=guarded
        Trade.__nuzAcquisitionOwner=mod
        Trade.__nuzAcquisitionWrap=guarded
    end

    local function refreshCapNotice()
        local saved = loadState()
        if not Core.active(saved)
            or ((Levels.get(saved, "level_cap_scope") or 0) == 0
                and not Playstyles.hardcoreActive(saved, Core)) then return end
        local cap, stage = levelCap(saved)
        local levels = saved.levels
        local marker = tostring(cap or "-") .. ":" .. tostring(stage or "")
        if levels.lastObservedCap ~= marker then
            if levels.lastObservedCap ~= nil then
                local text = cap
                    and ("Level Cap: next boss allows Lv " .. cap
                        .. " (" .. tostring(stage) .. ").")
                    or "Level Cap: current scope is complete; cap lifted."
                Notices.add(saved, "LEVEL_CAP_CHANGED", text)
            end
            levels.lastObservedCap = marker
            writeState(saved)
        end
    end
    local function isCandyCapped(native, mon)
        local saved = loadState()
        if not Core.active(saved) or type(mon) ~= "table" then return false end
        local cap = levelCap(saved)
        return cap ~= nil and (tonumber(mon.level) or 1) >= cap, cap
    end
    local function candyMessage(cap)
        return "Nuzlocke: Level cap Lv " .. tostring(cap)
            .. " reached. RARE CANDY cannot be used."
    end

    local function fieldDenial(itemId,native)
        local okI,ItemUse=pcall(require,"src.core.game3.item_use")
        local okD,ItemsData=pcall(require,"src.core.game3.items_data")
        return FieldRules.fieldDenial(loadState(),Core,itemId,
            native or session(),okI and ItemUse or nil,
            okD and ItemsData or nil)
    end

    -- The authoritative overworld path is ItemUse.useField -> item.use.
    -- Guard before native consumption. A direct useRareCandy wrapper alone
    -- cannot intercept all Gen 3 bag / RSE item paths.
    mod.hooks:wrap("item.use", function(next, game, unused, itemId,
            partySlot, bag)
        local native = session()
        local fieldReason=fieldDenial(itemId,native)
        if fieldReason then
            notify("FIELD_ITEM_DENIED",fieldReason,false)
            return false,"noeffect",fieldReason
        end
        local ok, ItemUse = pcall(require, "src.core.game3.item_use")
        if ok and type(ItemUse) == "table"
            and type(ItemUse.fieldUseKind) == "function"
            and ItemUse.fieldUseKind(itemId, native) == "level" then
            local mon = native and native.party and native.party[partySlot]
            local denied, cap = isCandyCapped(native, mon)
            if denied then
                local message = candyMessage(cap)
                notify("LEVEL_CAP_ITEM", message, false)
                return false, "noeffect", message
            end
        end
        return next(game, unused, itemId, partySlot, bag)
    end)
    -- The native Game3 PartyMenu has a separate "use" branch which
    -- directly removes Rare Candy from the bag and mutates mon.level.
    -- It NEVER calls ItemUse.useRareCandy or ItemUse.useField. Cancel the
    -- actual A-press before that branch can consume anything.
    local function installPartyCandyGuard()
        local okP, PartyMenu = pcall(require, "src.ui.game3.party_menu")
        local okI, ItemUse = pcall(require, "src.core.game3.item_use")
        if not okP or not okI or type(PartyMenu) ~= "table"
            or type(ItemUse) ~= "table"
            or type(PartyMenu.handleInput) ~= "function"
            or type(PartyMenu.showMessage) ~= "function"
            or type(ItemUse.fieldUseKind) ~= "function" then return false end
        if PartyMenu.__nuzGen3CandyOwner == mod then return true end
        local original = PartyMenu.handleInput
        PartyMenu.handleInput = function(input, ...)
            if PartyMenu.open and PartyMenu.mode == "use"
                and not PartyMenu._onSelect and input
                and type(input.wasPressed) == "function"
                and input:wasPressed("a") then
                local slot = tonumber(PartyMenu.cursor)
                local mon = slot and PartyMenu._party
                    and PartyMenu._party[slot]
                if mon and not mon.isEgg then
                    local reason=fieldDenial(PartyMenu._item,
                        PartyMenu._session)
                    if reason then
                        notify("FIELD_ITEM_DENIED",reason,false)
                        PartyMenu.showMessage(reason,function()
                            PartyMenu.mode="use"
                        end)
                        return
                    end
                end
                if mon and not mon.isEgg
                    and ItemUse.fieldUseKind(PartyMenu._item,
                        PartyMenu._session) == "level" then
                    local denied, cap = isCandyCapped(PartyMenu._session, mon)
                    if denied then
                        local message = candyMessage(cap)
                        notify("LEVEL_CAP_ITEM", message, false)
                        PartyMenu.showMessage(message, function()
                            PartyMenu.mode = "use"
                        end)
                        return
                    end
                end
            end
            return original(input, ...)
        end
        PartyMenu.__nuzGen3CandyOwner = mod
        return true
    end
    local function installCandyGuard()
        installPartyCandyGuard()
        local ok, ItemUse = pcall(require, "src.core.game3.item_use")
        if not ok or type(ItemUse) ~= "table"
            or type(ItemUse.useRareCandy) ~= "function" then return false end
        if ItemUse.__nuzGen3CandyOwner == mod then return true end
        local original = ItemUse.useRareCandy
        ItemUse.useRareCandy = function(native, mon, ...)
            local reason=fieldDenial("RARE_CANDY",native)
            if reason then
                notify("FIELD_ITEM_DENIED",reason,false)
                return false,"no_effect",reason
            end
            local denied, cap = isCandyCapped(native, mon)
            if denied then
                local message = candyMessage(cap)
                notify("LEVEL_CAP_ITEM", message, false)
                return false, "no_effect", message
            end
            return original(native, mon, ...)
        end
        ItemUse.__nuzGen3CandyOwner = mod
        return true
    end

    -- Direct native item calls used by the TM Case / medicine UI do
    -- not necessarily reach item.use. Wrap their mutation boundaries;
    -- the PartyMenu A-press guard catches its own direct TM/Candy branch.
    local function installFieldItemGuards()
        local okI,ItemUse=pcall(require,"src.core.game3.item_use")
        if okI and type(ItemUse)=="table" then
            local function protect(key,idAt,sessionAt)
                local marker="__nuzFieldWrap_"..key
                if type(ItemUse[key])~="function" then return end
                if ItemUse[marker]==ItemUse[key]
                    and ItemUse.__nuzFieldOwner==mod then return end
                local previous=ItemUse[key]
                local function guard(...)
                    local args={...}
                    local item=idAt(args)
                    local native=sessionAt(args)
                    local why=fieldDenial(item,native)
                    if why then
                        notify("FIELD_ITEM_DENIED",why,false)
                        return false,"noeffect",why
                    end
                    return previous(...)
                end
                ItemUse[key]=guard
                ItemUse[marker]=guard
            end
            protect("useTm",function(a)return a[3] end,
                function(a)return a[1] end)
            protect("useEscapeRope",function(a)return a[3] end,
                function(a)return a[1] end)
            protect("applyPpItem",function(a)return a[2] end,
                function(a)return a[5] end)
            ItemUse.__nuzFieldOwner=mod
        end
        -- The menu dispatch table captures handlers when field_moves.lua
        -- loads; replacing flyFromMenu alone would leave the old entry live.
        local okM,Moves=pcall(require,"src.core.game3.field_moves")
        if okM and type(Moves)=="table" then
            local function guardMove(name,method)
                local marker="__nuzFieldTravel_"..name
                local dispatch=Moves.MENU_HANDLERS
                local moveId=Moves.MOVES and Moves.MOVES[name]
                if type(Moves[method])~="function" then return end
                if Moves[marker]==Moves[method]
                    and (not dispatch or not moveId
                        or dispatch[moveId]==Moves[method]) then return end
                local previous=Moves[method]
                local function guarded(ctx)
                    local why=FieldRules.travelDenial(loadState(),Core,name)
                    if why then
                        notify("FIELD_TRAVEL_DENIED",why,false)
                        return {ok=false,text=why}
                    end
                    return previous(ctx)
                end
                Moves[method]=guarded
                Moves[marker]=guarded
                if type(dispatch)=="table" and moveId then
                    dispatch[moveId]=guarded
                end
            end
            guardMove("FLY","flyFromMenu")
            guardMove("TELEPORT","teleportFromMenu")
        end
        return true
    end

    -- Unlike a capture-only ban, No Fishing must refuse a rod BEFORE the
    -- field starts its fishing minigame. The engine's Field.startFishing
    -- is the native rod-use boundary. Keep an additional guard on direct
    -- tryFishingEncounter calls so other paths cannot bypass this rule.
    local function installFishingGuard()
        local ok, Field = pcall(require, "src.core.game3.field")
        if not ok or type(Field) ~= "table" then return false end
        local function protected(method)
            local marker = "__nuzGen3FishingWrap_" .. method
            if type(Field[method]) ~= "function" then return end
            if Field[marker] == Field[method]
                and Field.__nuzGen3FishingOwner == mod then return end
            local original = Field[method]
            local function guarded(...)
                if CatchRules.fishingBlocked(loadState(), Core) then
                    notify("NO_FISHING",
                        "No Fishing: fishing rods cannot be used.", false)
                    return false
                end
                return original(...)
            end
            Field[method] = guarded
            Field[marker] = guarded
        end
        protected("startFishing")
        protected("tryFishingEncounter")
        Field.__nuzGen3FishingOwner = mod
        return true
    end

    -- Nuzlocke-only effect-level guards. These functions are shared by
    -- primary moves, secondary effects and King's Rock. We never rewrite
    -- native move definitions or damage, and only restrict sources proven
    -- to be battle moves (not natural abilities/item stat changes).
    local battleClauseSource
    local reportedBattleClauses = {}
    local function battleClauseNotice(key, message)
        if reportedBattleClauses[key] then return end
        reportedBattleClauses[key] = true
        notify("BATTLE_CLAUSE", message, false)
    end
    local function installBattleClauseGuards()
        local okS, Secondary = pcall(require,
            "src.core.game3.battle.effects.secondary")
        local okC, EffectCtx = pcall(require,
            "src.core.game3.battle.effect_ctx")
        if not okS or type(Secondary)~="table"
            or not okC or type(EffectCtx)~="table" then return false end

        if type(Secondary.set)=="function"
            and (Secondary.__nuzGen3SetOwner~=mod
                or (Secondary.__nuzGen3SetWrap~=Secondary.set
                    and not (Secondary.__nuzStatusOwner==mod
                        and Secondary.__nuzStatusWrap==Secondary.set))) then
            local original = Secondary.set
            local function guarded(M, effect, ...)
                local source = type(M)=="table" and M.user or nil
                local saved = loadState()
                if source and BattleClauses.denyEffect(saved,
                    effect, source, Core) then
                    battleClauseNotice(effect, effect=="FLINCH"
                        and "Flinch Clause: move flinch prevented."
                        or "Trap Clause: partial trapping prevented.")
                    return false
                end
                local previous = battleClauseSource
                if source then battleClauseSource=source end
                local ok, result, extra, more = pcall(original,
                    M, effect, ...)
                battleClauseSource=previous
                if not ok then error(result,0) end
                return result, extra, more
            end
            Secondary.set=guarded
            Secondary.__nuzGen3SetWrap=guarded
            Secondary.__nuzGen3SetOwner=mod
        end

        if type(Secondary.changeStat)=="function"
            and (Secondary.__nuzGen3StatOwner~=mod
                or Secondary.__nuzGen3StatWrap~=Secondary.changeStat) then
            local original=Secondary.changeStat
            local function guarded(adapter,target,stat,delta,flags)
                local ctx=EffectCtx.current and EffectCtx.current()
                local source=(ctx and ctx.user) or battleClauseSource
                if source and BattleClauses.denyStat(loadState(),
                    stat, delta, source, Core) then
                    battleClauseNotice("stat:"..tostring(stat)..":"
                        ..(delta>0 and "+" or "-"),
                        "Battle Clause: move-caused "..tostring(stat)
                        .." change prevented.")
                    return "blocked"
                end
                return original(adapter,target,stat,delta,flags)
            end
            Secondary.changeStat=guarded
            Secondary.__nuzGen3StatWrap=guarded
            Secondary.__nuzGen3StatOwner=mod
        end

        -- Minimize has a second volatile flag besides its evasion stage.
        -- Suppress that special state entirely when the Evasion Clause
        -- prevents the move's stage boost.
        local okE, Effects=pcall(require,
            "src.core.game3.battle.effects.init")
        if okE and type(Effects)=="table"
            and type(Effects.run)=="function"
            and (Effects.__nuzGen3RunOwner~=mod
                or (Effects.__nuzGen3RunWrap~=Effects.run
                    and not (Effects.__nuzStatusRunOwner==mod
                        and Effects.__nuzStatusRunWrap==Effects.run))) then
            local original=Effects.run
            Effects.run=function(id,adapter,user,target,...)
                if id=="EXP_MINIMIZE_EFFECT" and user
                    and BattleClauses.denyStat(loadState(),
                        "evasion",1,user,Core) then
                    battleClauseNotice("minimize",
                        "Evasion Clause: Minimize was prevented.")
                    if adapter and type(adapter.sayFail)=="function" then
                        adapter:sayFail()
                    end
                    return true
                end
                return original(id,adapter,user,target,...)
            end
            Effects.__nuzGen3RunWrap=Effects.run
            Effects.__nuzGen3RunOwner=mod
        end
        return true
    end

    -- STATUS BANS: prevent the native status mutation, not the damaging
    -- move. Shared Secondary.set handles primary and secondary move effects;
    -- Adapter.new covers direct status transactions (abilities and Yawn).
    local function installStatusBanGuards()
        local okS, Secondary=pcall(require,
            "src.core.game3.battle.effects.secondary")
        if okS and type(Secondary)=="table"
            and type(Secondary.set)=="function"
            and (Secondary.__nuzStatusOwner~=mod
                or Secondary.__nuzStatusWrap~=Secondary.set) then
            local original=Secondary.set
            local function guarded(M,effect,...)
                local user=type(M)=="table" and M.user
                local target=type(M)=="table" and M.target
                local affectsUser=select(3,...)
                if affectsUser==true then target=user end
                local saved=loadState()
                if user and StatusBans.deny(saved,effect,
                    user,target,Core) then
                    battleClauseNotice("status:"..tostring(effect),
                        "Status Ban: "..tostring(effect)..
                        " from this side was prevented.")
                    return false
                end
                if user and (effect=="SLEEP" or effect=="SLP")
                    and StatusBans.denySleepClause(saved,user,target,
                        type(M)=="table" and M.adapter and M.adapter._st,
                        Core) then
                    battleClauseNotice("sleep:clause",
                        "Sleep Clause: another opposing Pokemon is asleep.")
                    return false
                end
                return original(M,effect,...)
            end
            Secondary.set=guarded
            Secondary.__nuzStatusWrap=guarded
            Secondary.__nuzStatusOwner=mod
        end

        -- Yawn only applies sleep after an end-of-turn delay and uses the
        -- victim as its direct native status source. Reject Yawn before
        -- drowsiness is scheduled, rather than undoing a later sleep.
        local okT, Status=pcall(require,
            "src.core.game3.battle.effects.status")
        if okT and type(Status)=="table"
            and type(Status.yawn)=="function"
            and (Status.__nuzYawnOwner~=mod
                or Status.__nuzYawnWrap~=Status.yawn) then
            local original=Status.yawn
            local function guarded(ctx,...)
                if type(ctx)=="table" and ctx.user
                    and (StatusBans.deny(loadState(),"SLEEP",
                        ctx.user,ctx.target,Core)
                        or StatusBans.denySleepClause(loadState(),
                            ctx.user,ctx.target,
                            ctx.adapter and ctx.adapter._st,Core)) then
                    battleClauseNotice("status:yawn",
                        "Sleep rule: Yawn was prevented.")
                    if ctx.adapter and type(ctx.adapter.sayFail)=="function"
                        then ctx.adapter:sayFail() end
                    return nil
                end
                local result=original(ctx,...)
                if type(ctx)=="table" and type(ctx.target)=="table"
                    and ctx.target.expYawnTurns
                    and ctx.user and ctx.user.side then
                    ctx.target._nuzYawnSource=ctx.user.side
                end
                return result
            end
            Status.yawn=guarded
            Status.__nuzYawnWrap=guarded
            Status.__nuzYawnOwner=mod
        end

        -- Effects.init captures Status.yawn when registering its handler,
        -- so wrapping the Status module alone is insufficient. Guard the
        -- live effect dispatcher as well (including ROM move aliases).
        local okE, Effects=pcall(require,
            "src.core.game3.battle.effects.init")
        if okE and type(Effects)=="table"
            and type(Effects.run)=="function"
            and (Effects.__nuzStatusRunOwner~=mod
                or Effects.__nuzStatusRunWrap~=Effects.run) then
            local original=Effects.run
            local function guarded(id,adapter,user,target,...)
                if id=="EXP_YAWN_EFFECT" and user
                    and (StatusBans.deny(loadState(),"SLEEP",
                        user,target,Core)
                        or StatusBans.denySleepClause(loadState(),
                            user,target,adapter and adapter._st,Core)) then
                    battleClauseNotice("status:yawn",
                        "Sleep rule: Yawn was prevented.")
                    if adapter and type(adapter.sayFail)=="function" then
                        adapter:sayFail()
                    end
                    return true
                end
                local result=original(id,adapter,user,target,...)
                if id=="EXP_YAWN_EFFECT" and type(target)=="table"
                    and target.expYawnTurns and user then
                    target._nuzYawnSource=user.side
                end
                return result
            end
            Effects.run=guarded
            Effects.__nuzStatusRunWrap=guarded
            Effects.__nuzStatusRunOwner=mod
        end

        local okA, Adapter=pcall(require,
            "src.core.game3.battle.adapter")
        if okA and type(Adapter)=="table"
            and type(Adapter.new)=="function"
            and (Adapter.__nuzStatusOwner~=mod
                or Adapter.__nuzStatusWrap~=Adapter.new) then
            local original=Adapter.new
            local function guarded(...)
                local ad=original(...)
                if type(ad)~="table" then return ad end
                if type(ad.applyStatus)=="function" then
                    local native=ad.applyStatus
                    ad.applyStatus=function(self,target,status,source,opts)
                        local sleep=status=="SLP" or status=="SLEEP"
                        -- Rest can happen while Yawn is pending; its
                        -- explicit three-turn sleep must stay self-induced.
                        local delayedYawn=sleep and source==target
                            and type(target)=="table"
                            and target._nuzYawnSource~=nil
                            and (type(opts)~="table" or opts.turns==nil)
                            -- Rest specifies a turn count. The deferred
                            -- Yawn path may omit its optional opts table in
                            -- compatible adapters, so don't require one.
                        local actualSource=delayedYawn
                            and target._nuzYawnSource or source
                        local saved=loadState()
                        if StatusBans.deny(saved,status,
                            actualSource,target,Core) then
                            battleClauseNotice("direct:"..tostring(status),
                                "Status Ban: "..tostring(status)..
                                " was prevented.")
                            if delayedYawn then
                                target._nuzYawnSleepBlocked=true
                                target._nuzYawnSource=nil
                            end
                            return false
                        end
                        if sleep and StatusBans.denySleepClause(saved,
                            actualSource,target,self._st,Core) then
                            battleClauseNotice("sleep:clause",
                                "Sleep Clause: another opposing Pokemon is asleep.")
                            if delayedYawn then
                                target._nuzYawnSleepBlocked=true
                                target._nuzYawnSource=nil
                            end
                            return false
                        end
                        local result=native(self,target,status,source,opts)
                        if sleep then
                            if result then
                                StatusBans.recordSleep(self._st,target,
                                    actualSource)
                            end
                            if type(target)=="table" then
                                target._nuzYawnSource=nil
                            end
                        end
                        return result
                    end
                    -- The native delayed-Yawn handler announces sleep even
                    -- when applyStatus returned false. Suppress ONLY that
                    -- misleading animation and message.
                    if type(ad.statusAnim)=="function" then
                        local statusAnim=ad.statusAnim
                        ad.statusAnim=function(self,target,status,...)
                            if type(target)=="table"
                                and target._nuzYawnSleepBlocked
                                and (status=="SLP" or status=="SLEEP") then
                                return
                            end
                            return statusAnim(self,target,status,...)
                        end
                    end
                    if type(ad.sayText)=="function" then
                        local sayText=ad.sayText
                        ad.sayText=function(self,id,fill,...)
                            local target=type(fill)=="table" and fill.eff
                            if id=="STRINGID_PKMNFELLASLEEP"
                                and type(target)=="table"
                                and target._nuzYawnSleepBlocked then
                                target._nuzYawnSleepBlocked=nil
                                return
                            end
                            return sayText(self,id,fill,...)
                        end
                    end
                end
                if type(ad.applyConfusion)=="function" then
                    local native=ad.applyConfusion
                    ad.applyConfusion=function(self,target,turns,source)
                        if StatusBans.deny(loadState(),"CONFUSION",
                            source,target,Core) then
                            battleClauseNotice("direct:CONFUSION",
                                "Status Ban: confusion was prevented.")
                            return false
                        end
                        return native(self,target,turns,source)
                    end
                end
                return ad
            end
            Adapter.new=guarded
            Adapter.__nuzStatusWrap=guarded
            Adapter.__nuzStatusOwner=mod
        end
        return true
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

    local function retireFainted(outcome, endedBattle)
        local s = loadState()
        if not Core.active(s) then return end
        if mercyBattle ~= nil and endedBattle == mercyBattle then return end
        local native = session()
        local party = native and native.party
        if type(party) ~= "table" then return end
        local deathEnabled = Core.enforced(s, "permadeath")

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

        local modified, rescued = false, false
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
        -- A whiteout failure outranks PC rescue. Never revive the dead:
        -- move one existing living resident into an empty native party only
        -- after battle writeback and faint retirement are finished.
        if Core.failedWhiteout(s, outcome) then
            s.failed = true
        elseif #party == 0 then
            if Core.enforced(s, "pc_survivors_allowed")
                and Extra.rescueFromPc(s, native) then
                modified = true
                rescued = true
            else
                s.failed = true
            end
        end
        if modified or s.failed then writeState(s) end
        if s.failed then
            notify("RUN_FAILED", "Nuzlocke run ended. See NUZ STATUS.", false)
        elseif rescued then
            notify("PC_SURVIVOR",
                "Party empty: a living PC survivor joined your team.", false)
        end
    end

    local function recordBattleFaint(ev)
        if not Core.enforced(loadState(), "permadeath")
            or type(ev) ~= "table" then return end
        if mercyBattle ~= nil and ev.battle == mercyBattle then return end
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
        notify("PERMADEATH", Notices.name(mon, Display)
            .. " fainted. Permadeath: added to the Graveyard.", true)
    end

    -- The battle engine asks Options.battleStyle() when an enemy trainer
    -- prepares a replacement after fainting. Override the *answer*, never
    -- the session's actual SHIFT/SET preference, so switching Hardcore OFF
    -- restores it immediately. Forced switches after fainting remain legal.
    local function installHardcoreSetGuard()
        local ok, Options = pcall(require, "src.core.game3.options")
        if not ok or type(Options) ~= "table"
            or type(Options.battleStyle) ~= "function" then return false end
        if Options.__nuzGen3HardcoreOwner == mod then return true end
        local original = Options.battleStyle
        Options.battleStyle = function(native, ...)
            if battleInProgress
                and Playstyles.hardcoreActive(loadState(), Core)
                and native == session() then return "set" end
            return original(native, ...)
        end
        Options.__nuzGen3HardcoreOwner = mod
        return true
    end

    -- The native battle-item UI and the actual item transaction are distinct.
    -- Block revival and Hardcore item usage at BOTH points. Balls remain
    -- legal; catch restrictions are handled by the existing catch.rate hook.
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
        local originalIsBattleUsable = BattleItems.isBattleUsable

        local function itemDenial(st,itemId)
            st=st or currentBattleState
            local current=activeBattle
            return BattleItemRules.itemDenial(loadState(),Core,Playstyles,
                itemId,BattleItems,ItemsData,ItemUse,{
                    battle=st,
                    wild=current~=nil and current.battle==st,
                    throws=current and current.ballThrows or 0,
                })
        end
        -- Suppress non-Ball choices in the battle bag where supported.
        if type(originalIsBattleUsable) == "function" then
            BattleItems.isBattleUsable = function(itemId, ...)
                if battleInProgress and
                    (itemDenial(nil,itemId) or
                    FieldRules.battleDenial(loadState(),Core,itemId,
                        session(),ItemUse,ItemsData)) then return false end
                return originalIsBattleUsable(itemId, ...)
            end
        end

        local function isRevive(itemId, nativeSession)
            local okKind, kind = pcall(ItemsData.medicineKind, itemId)
            if okKind and kind == "revive" then return true end
            local okField, field = pcall(ItemUse.fieldUseKind,
                itemId, nativeSession, true)
            return okField and field == "revive"
        end

        BattleItems.canUseOn = function(st, itemId, partySlot, mon, moveSlot)
            local denial=itemDenial(st,itemId)
            if not denial then
                denial=FieldRules.battleDenial(loadState(),Core,
                    itemId,st and st.session,ItemUse,ItemsData)
            end
            if denial then return false,denial end
            if Core.enforced(loadState(), "permadeath")
                and isRevive(itemId, st and st.session) then
                return false, "Nuzlocke: No revives."
            end
            return originalCanUse(st, itemId, partySlot, mon, moveSlot)
        end

        BattleItems.use = function(st, adapter, bag, nativeSession, itemId, ...)
            local message=itemDenial(st,itemId)
            if not message then
                message=FieldRules.battleDenial(loadState(),Core,
                    itemId,nativeSession,ItemUse,ItemsData)
            end
            if message then
                if adapter and type(adapter.say)=="function" then
                    adapter:say(message)
                end
                return "error",{message},false,false
            end
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

    -- Native Gen 3 builds with the post-catch hook consult Nuzlocke at
    -- the *actual* capture decision, before ever drawing the YES/NO prompt.
    -- Engine builds without the hook keep the guarded UI compatibility path.
    mod.hooks:wrap("battle.catch.nickname_required", function(next, ctx)
        if type(ctx) == "table" and ctx.source == "gen3"
            and Core.enforced(loadState(), "nickname_rule") then
            notify("NICKNAME_FORCED",
                "Nickname Rule: a custom nickname is required.", false)
            return true
        end
        return next(ctx)
    end)

    -- IMPORTANT: Gen1Recomp runs mod callbacks in a restricted sandbox:
    -- 'package' is deliberately absent. Direct package.loaded access here
    -- caused the old capture guard to fail in-game, despite unsandboxed
    -- mock tests passing. Use the permitted require facade instead.
    local function nativeCatchNicknamePrompt()
        local ok, battle = pcall(require, "src.core.game3.battle.init")
        if not ok or type(battle) ~= "table" then
            ok, battle = pcall(require, "src.core.game3.battle")
        end
        return ok and type(battle) == "table"
            and battle._phase == "catch_nickname_prompt"
    end

    -- Native catch prompts cannot be skipped when Nickname Rule is ON.
    -- The guarded naming screen repeats until a non-default name is given.
    -- The safe overworld task list handles gifts, trades and hatches.
    local function installNicknameGuard()
        local okU, Ui = pcall(require, "src.core.game3.battle.ui")
        local okN, Naming = pcall(require, "src.ui.game3.naming")
        if not okU or type(Ui) ~= "table"
            or type(Ui.askYesNo) ~= "function" then return false end
        -- Install the prompt hook even if the naming UI has not loaded yet.
        -- The old all-or-nothing pcall(require, Naming) silently skipped BOTH
        -- hooks when native naming assets were unavailable at battle start.
        -- The native captured-mon prompt is emitted in battle/init.lua,
        -- which may be loaded under its .init path instead of the .lua alias.
        -- Both aliases must be checked: otherwise the player's No choice
        -- is left available on some module-loading paths.
        --
        -- Reinstall if a later integration replaces askYesNo. The owner
        -- marker alone used to incorrectly claim our hook was still active.
        if Ui.__nuzGen3NicknameOwner ~= mod
            or Ui.__nuzGen3NicknameWrap ~= Ui.askYesNo then
            local ask = Ui.askYesNo
            local function guardedAsk(prompt, callback, ...)
                local nativeCatchPrompt = nativeCatchNicknamePrompt()
                    and type(callback) == "function"
                if Core.enforced(loadState(), "nickname_rule")
                    and nativeCatchPrompt then
                    -- Ensure the native naming screen has its validator
                    -- before following the YES path. Do not display a
                    -- YES/NO prompt when No would violate the rule.
                    installNicknameGuard()
                    notify("NICKNAME_FORCED",
                        "Nickname Rule: give your new Pokemon a nickname.", false)
                    return callback(true)
                end
                return ask(prompt, callback, ...)
            end
            Ui.askYesNo = guardedAsk
            Ui.__nuzGen3NicknameWrap = guardedAsk
            Ui.__nuzGen3NicknameOwner = mod
        end
        -- Compatibility fail-safe for existing Gen1Recomp builds: when
        -- another UI wrapper draws the old YES/NO prompt, intercept the
        -- confirmation callback at the lower native Choice layer too.
        -- This cannot be declined; no other Yes/No screens are affected.
        local okC, Choice = pcall(require, "src.ui.game3.choice")
        if okC and type(Choice) == "table"
            and type(Choice.yesNo) == "function"
            and (Choice.__nuzGen3NicknameOwner ~= mod
                or Choice.__nuzGen3NicknameWrap ~= Choice.yesNo) then
            local originalChoice = Choice.yesNo
            local function guardedChoice(callback, ...)
                if nativeCatchNicknamePrompt()
                    and Core.enforced(loadState(), "nickname_rule")
                    and type(callback) == "function" then
                    notify("NICKNAME_FORCED",
                        "Nickname Rule: choose a custom nickname.", false)
                    return callback(true)
                end
                return originalChoice(callback, ...)
            end
            Choice.yesNo = guardedChoice
            Choice.__nuzGen3NicknameOwner = mod
            Choice.__nuzGen3NicknameWrap = guardedChoice
        end
        if not okN or type(Naming) ~= "table"
            or type(Naming.open) ~= "function" then return true end
        if Naming.__nuzGen3NicknameOwner == mod
            and Naming.__nuzGen3NicknameWrap == Naming.open then
            return true
        end
        local open = Naming.open
        local function guardedOpen(opts)
            if type(opts) ~= "table" or opts.template ~= "CAUGHT_MON"
                or not Core.enforced(loadState(), "nickname_rule")
                or type(opts.onDone) ~= "function" then
                return open(opts)
            end
            local speciesName = Display.speciesName({ species = opts.species })
            local wrapped = {}
            for k, v in pairs(opts) do wrapped[k] = v end
            local function validated(nick)
                if not Extra.customName(nick, speciesName) then
                    notify("NICKNAME_REQUIRED",
                        "Nickname Rule: enter a name different from the species.", false)
                    return open(wrapped)
                end
                return opts.onDone(nick)
            end
            wrapped.onDone = validated
            return open(wrapped)
        end
        Naming.open = guardedOpen
        Naming.__nuzGen3NicknameWrap = guardedOpen
        Naming.__nuzGen3NicknameOwner = mod
        return true
    end

    -- Gen 3's map.entered uses a native map ID, not a Gen 1 map name.
    mod.events:on("map.entered", function(ev)
        currentArea = type(ev) == "table" and areaKey(ev.mapId) or nil
        pendingRoamer = nil -- never match a roamer across unrelated maps
        refreshForgiveness()
        refreshCapNotice()
        nicknameTasks()
        installCandyGuard()
        installFieldItemGuards()
        installNicknameGuard()
        installFishingGuard()
        installBattleClauseGuards()
        installStatusBanGuards()
        installAcquisitionGuards()
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
        if Core.enforced(saved, "nickname_rule") then
            Extra.auditNicknames(saved, session(), Display)
        end
        writeState(saved)
        if mode ~= 0 then
            local name = type(ev) == "table"
                and type(ev.mon) == "table"
                and Notices.name(ev.mon, Display) or "The hatched Pokemon"
            notify("EGG_ENCOUNTER", name .. " hatched. Egg Encounter: "
                .. tostring(reason or (valid and "accepted" or "not eligible")) .. ".", false)
        end
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
        Randomizer.clearCache()
        resetOWEShinies()
        currentArea = nil
        activeBattle = nil
        pendingRoamer = nil
        battleInProgress = false
        battleDeaths = nil
        mercyBattle = nil
        installCandyGuard()
        installFieldItemGuards()
        installNicknameGuard()
        installFishingGuard()
        installBattleClauseGuards()
        installStatusBanGuards()
        installAcquisitionGuards()
    end)
    mod.events:on("save.created", function()
        Randomizer.clearCache()
        resetOWEShinies()
        currentArea = nil
        activeBattle = nil
        pendingRoamer = nil
        battleInProgress = false
        battleDeaths = nil
        mercyBattle = nil
        installCandyGuard()
        installFieldItemGuards()
        installNicknameGuard()
        installFishingGuard()
        installBattleClauseGuards()
        installStatusBanGuards()
        installAcquisitionGuards()
    end)

    -- Record the FIRST encounter even if it runs or faints; later Balls fail.
    -- Tutorial battles and scripted trainer battles do not claim an area.
    mod.events:on("battle.started", function(ev)
        activeBattle = nil
        battleInProgress = true
        currentBattleState = ev and ev.battle
        battleDeaths = nil
        mercyBattle = nil
        -- Install after the engine's battle modules exist, before any item turn.
        installReviveGuard()
        installHardcoreSetGuard()
        installNicknameGuard()
        installCandyGuard()
        installFieldItemGuards()
        installBattleClauseGuards()
        installStatusBanGuards()
        installAcquisitionGuards()
        reportedBattleClauses={}
        local starting = loadState()
        if Core.enforced(starting, "first_rival_forgiveness")
            and not starting.firstRivalMercyConsumed
            and Extra.openingRival(ev, session()) then
            starting.firstRivalMercyConsumed = true
            mercyBattle = ev.battle
            writeState(starting)
            notify("RIVAL_MERCY",
                "First Rival Mercy: fainting here will not count as a death.", true)
        end
        local announcedRoamer = pendingRoamer
        pendingRoamer = nil -- the next battle is the only possible match
        -- Shiny Rate is a gameplay-independent generation setting (like
        -- Game Difficulty), so it works even with Nuzlocke enforcement OFF.
        -- Apply once, BEFORE Shiny Clause checks encounter eligibility.
        local shinyMode = Clauses.get(loadState(), "shiny_rate_mode")
        if type(ev) == "table" and ev.kind == "wild" then
            local mon = ev.battle and ev.battle.enemy
                and ev.battle.enemy.mon
            if type(mon) == "table" then
                local key = oweShinyIdentity(
                    tonumber(mon.speciesId or mon.species or ev.speciesId),
                    tonumber(mon.personality))
                if key and oweShinySeen[key] then
                    -- OWE's spawn PID is authoritative: never improve it
                    -- again after its visible shiny sprite is chosen.
                    mon.nuzlockeShinyRateChecked = true
                end
            end
        end
        ShinyRate.apply(mod, ev, shinyMode, shinyRandomUnit, function(mon)
            local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
            if not ok or not Pokemon or not Pokemon.isShiny then
                error("Gen 3 native shiny resolver unavailable")
            end
            return Pokemon.isShiny(mon)
        end)
        if not isActive() or type(ev) ~= "table" or ev.kind ~= "wild" then return end
        local s = loadState()
        local shinyOnly = Playstyles.active(s, Core)
        local key = areaNow()
        -- Unknown maps cannot claim a route; still enforce shiny-only
        -- catches rather than silently disabling the playstyle.
        -- Every wild catch must run the default glitch eligibility gate,
        -- including provider maps which have no vanilla area identity.
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
        local areaEligible = roamer or not key or Core.catchAllowed(s, key)
        -- The roamer's species slot replaces the map slot; a free roamer
        -- encounter never consumes this map, even if it flees or faints.
        local dupe = Clauses.isDuplicate(s, species, native, edition)
        local okPokemon, Pokemon = pcall(require, "src.core.game3.pokemon")
        local catchSeed=tostring(native and native.trainerId or "")
            ..":"..tostring(native and native.trainerSecretId or "")
            ..":"..tostring(native and native.name or "")
        local alphabetSet=CatchRules.prepareAlphabet(s,
            okPokemon and Pokemon or nil,catchSeed)
        local colorSet=CatchRules.prepareColor(s,
            okPokemon and Pokemon or nil,catchSeed)
        local typeSet=Variants.prepare(s,
            okPokemon and Pokemon or nil,catchSeed)
        if alphabetSet or colorSet or typeSet then writeState(s) end
        local catchPermitted, bannedReason = CatchRules.check(s, species,
            okPokemon and Pokemon or nil, Core,catchSeed)
        -- No Catching makes every wild ineligible, rather than letting
        -- Failed Encounters spend a route that could never be caught.
        local noCatchReason=BattleItemRules.catchDenial(s,Core,0)
        if noCatchReason then
            catchPermitted=false
            bannedReason=noCatchReason
        end
        local typePermitted,typeReason=Variants.check(s,species,
            okPokemon and Pokemon or nil,Core,catchSeed)
        if not typePermitted then
            catchPermitted=false
            bannedReason=typeReason
        end
        local sourcePermitted, sourceReason = CatchRules.checkBattle(s,
            ev.battle, Core,key)
        if not sourcePermitted then
            catchPermitted = false
            bannedReason = sourceReason
        end
        local shiny = Clauses.isShiny(wildMon)
        -- Ordinary wild Pokémon are NEVER eligible encounters in this
        -- playstyle: Failed Encounters must not spend a route on them.
        local eligible = areaEligible and roamerOpen and not dupe
            and catchPermitted and Playstyles.qualifies(s, Core, shiny)
        local entry = key and s.areas[key] or nil
        if eligible and key and not roamer then
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
            ballThrows = 0,
            areaEligible = areaEligible, duplicate = dupe,
            shiny = shiny, shinyOnly = shinyOnly,
            exception = false,
            roamer = roamer, roamerOpen = roamerOpen,
            roamerSpecies = spId, prohibitedReason = bannedReason,
        }
        if shinyOnly and eligible then
            notify("SHINY_ENCOUNTER",
                "Shiny Nuzlocke: shiny found! This is a valid catch"
                .. (key and (" on " .. Display.areaName(key)) or "")
                .. ".", true)
        elseif eligible and not roamer and Core.enforced(s, "encounter_limit") then
            if Core.shouldSpendOnStart(s) then
                notify("FIRST_ENCOUNTER",
                    "First encounter on " .. Display.areaName(key)
                    .. "! Catch it now: fleeing or fainting uses your chance.", true)
            else
                notify("CATCH_OPPORTUNITY",
                    "Catch opportunity on " .. Display.areaName(key)
                    .. "! You may try again if it escapes or faints.", true)
            end
        end
    end)

    -- Gen 3's catch.rate wraps vanilla and returns (caught, shakes).
    -- This does not modify normal encounters or trainer battles.
    -- Compose EXP once, then cap it before native Experience.apply.
    mod.hooks:wrap("exp.gain", function(next, ctx)
        local awarded = next(ctx)
        local saved = loadState()
        if not Core.active(saved) or type(ctx) ~= "table"
            or type(ctx.mon) ~= "table" then return awarded end
        local ok, Experience = pcall(require, "src.core.game3.battle.experience")
        if not ok or type(Experience) ~= "table"
            or type(Experience.expForLevel) ~= "function" then
            return awarded
        end
        local cap = levelCap(saved)
        local beforeBank = Levels.banked(saved, ctx.mon)
        local applied = Levels.adjust(saved, ctx.mon, awarded,
            cap, Experience.expForLevel)
        expReports[ctx.mon] = {
            awarded = tonumber(awarded) or 0, applied = applied,
            bankBefore = beforeBank,
            edging = Levels.get(saved, "exp_edging") == true,
            cap = cap,
        }
        writeState(saved)
        return applied
    end)

    -- Native randomiser hooks are registered once at module startup
    -- above, with the current seeded replace() API. Do not re-register
    -- the obsolete Randomizer.wild()/trainers() adapters here.

    mod.hooks:wrap("catch.rate", function(next, ball, mon, species, ctx)
        local battle = activeBattle
        if not isActive() or not battle or type(ctx) ~= "table"
            or ctx.battle ~= battle.battle then
            return next(ball, mon, species, ctx)
        end
        local s = loadState()
        local itemReason=BattleItemRules.catchDenial(s,Core,
            battle.ballThrows)
        if itemReason then
            battle.pendingCatchReason=itemReason
            return false,0
        end
        -- Check at BOTH battle start (encounter-slot policy) and the Ball
        -- transaction (final legality), before Shiny Clause exceptions.
        local sourceAllowed, sourceReason = CatchRules.checkBattle(
            s, ctx.battle, Core,battle.area)
        if not sourceAllowed then
            battle.pendingCatchReason = sourceReason
            return false, 0
        end
        local okPokemon, Pokemon = pcall(require, "src.core.game3.pokemon")
        local native=session()
        local catchSeed=tostring(native and native.trainerId or "")
            ..":"..tostring(native and native.trainerSecretId or "")
            ..":"..tostring(native and native.name or "")
        local alphabetSet=CatchRules.prepareAlphabet(s,
            okPokemon and Pokemon or nil,catchSeed)
        local colorSet=CatchRules.prepareColor(s,
            okPokemon and Pokemon or nil,catchSeed)
        local typeSet=Variants.prepare(s,
            okPokemon and Pokemon or nil,catchSeed)
        if alphabetSet or colorSet or typeSet then writeState(s) end
        local allowed, reason = CatchRules.check(s,
            (type(ctx) == "table" and ctx.speciesId)
                or Clauses.speciesId(species)
                or (type(mon) == "table" and (mon.speciesId or mon.species)),
            okPokemon and Pokemon or nil, Core,catchSeed)
        if allowed then
            allowed,reason=Variants.check(s,
                (type(ctx)=="table" and ctx.speciesId)
                    or Clauses.speciesId(species)
                    or (type(mon)=="table"
                        and (mon.speciesId or mon.species)),
                okPokemon and Pokemon or nil,Core,catchSeed)
        end
        if not allowed then
            -- No shake/clone/PC writeback or Shiny Clause exception.
            -- The matching battle-start check does not spend a route.
            battle.pendingCatchReason = reason
            return false, 0
        end
        local shinyOnly = Playstyles.active(s, Core)
        local shiny = battle.shiny or Clauses.isShiny(mon)
        if shinyOnly and not shiny then
            local suffix = battle.areaEligible
                and " Non-shinies do not use your route chance."
                or " This route is already used."
            battle.pendingCatchReason = "Shiny Nuzlocke: only shiny Pokemon"
                .. " can be caught." .. suffix
            return false, 0
        end
        -- Recover from native wilds whose enemy is not populated until
        -- ball use: the target's shiny identity is authoritative.
        if shinyOnly and shiny and not battle.shiny then
            battle.shiny = true
            battle.eligible = battle.areaEligible and battle.roamerOpen
                and not battle.duplicate
            if battle.eligible and battle.area and not battle.roamer then
                local entry = s.areas[battle.area]
                if type(entry) ~= "table" then
                    entry = { species = species, caught = false,
                        spent = false, attempts = 0 }
                end
                entry.attempts = (tonumber(entry.attempts) or 0) + 1
                if Core.shouldSpendOnStart(s) then entry.spent = true end
                s.areas[battle.area] = entry
                writeState(s)
            end
        end
        local limited = Core.enforced(s, "encounter_limit")
        local blockedByArea = limited and not battle.areaEligible
        local blockedByDupe = battle.duplicate
        local blockedByRoamer = battle.roamer and not battle.roamerOpen
        local exception = not blockedByRoamer
            and (blockedByArea or blockedByDupe)
            and Playstyles.allowShinyException(s, Core)
            and Clauses.canUseShinyException(s)
            and shiny
        if blockedByRoamer
            or ((blockedByArea or blockedByDupe) and not exception) then
            battle.pendingCatchReason = Notices.catchReason({
                roamer = blockedByRoamer, roamerOpen = battle.roamerOpen,
                duplicate = blockedByDupe, areaEligible = not blockedByArea,
            })
            if blockedByArea and not blockedByDupe and not blockedByRoamer then
                battle.pendingCatchReason = "One Per Area: " ..
                    Display.areaName(battle.area) .. " encounter already used."
            end
            return false, 0
        end
        -- Count only approved Ball transactions. Denied attempts (bans,
        -- duplicate/area rules, and exhausted budgets) never spend a throw.
        local counted=BattleItemRules.countThrow(s,Core,battle.ballThrows)
        if counted then battle.ballThrows=counted end
        local caught, shakes = next(ball, mon, species, ctx)
        -- A failed Ball never consumes a Shiny Clause allowance.
        if caught and exception then battle.exception = true end
        return caught, shakes
    end)

    -- The ball roll runs before native throw/breakout presentation. Tell the
    -- player the rule reason after the ball-thrown event, not on each RNG call.
    mod.events:on("battle.ball_thrown", function(ev)
        local battle = activeBattle
        if not battle or type(ev) ~= "table"
            or ev.battle ~= battle.battle then return end
        local reason = battle.pendingCatchReason
        battle.pendingCatchReason = nil
        if reason then notify("CATCH_DENIED", reason, true) end
    end)

    mod.events:on("battle.exp_gained", function(ev)
        if type(ev) ~= "table" or type(ev.mon) ~= "table" then return end
        local report = expReports[ev.mon]
        expReports[ev.mon] = nil
        if report and report.cap then
            local msg = Notices.expText(
                Notices.name(ev.mon, Display), report, report.cap)
            if msg then notify("EXP_CAP", msg, true) end
        elseif report and report.bankBefore > 0
            and report.applied > report.awarded then
            local msg = Notices.expText(
                Notices.name(ev.mon, Display), report, "NONE")
            if msg then notify("EXP_RELEASE", msg, true) end
        end
    end)

    mod.events:on("pokemon.caught", function(ev)
        -- Capture may have loaded or replaced the native UI after battle
        -- start. Reassert both hooks before the nickname prompt appears.
        installNicknameGuard()
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
        local drafted, draftedType, draftedCount, draftTarget
        if not activeBattle.draftRecorded then
            -- Native pokemon.caught is emitted only for a successful wild
            -- capture. Do not infer a draft from Battle started, Ball
            -- thrown, the mandatory starter, optional gifts or NPC swaps.
            activeBattle.draftRecorded=true
            drafted,draftedType,draftedCount,draftTarget=Variants.noteCatch(
                s,caughtSpecies,pokemonResolver(),Core)
        end
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
        if drafted then
            notify("CATCH_DRAFT","Catch Draft: "..draftedType
                .." selected ("..draftedCount.."/"..draftTarget
                .." types).",true)
        end
        if activeBattle.eligible and not activeBattle.roamer
            and not activeBattle.exception and Core.enforced(s, "encounter_limit") then
            notify("ENCOUNTER_CAUGHT", "One Per Area: "
                .. Display.areaName(activeBattle.area)
                .. " capture recorded. This area's slot is now used.", true)
        end
        if Playstyles.active(s, Core) and activeBattle.eligible
            and not activeBattle.exception then
            notify("SHINY_CATCH",
                "Shiny Nuzlocke: shiny Pokemon caught"
                .. (activeBattle.area
                    and (" on " .. Display.areaName(activeBattle.area)) or "")
                .. ".", true)
        end
        if activeBattle.exception then
            notify("SHINY_EXCEPTION",
                "Shiny Clause: an extra catch was allowed.", true)
        elseif activeBattle.roamer then
            notify("ROAMER_CAUGHT",
                "Roamer Clause: this Pokemon's roaming slot is used.", true)
        end
    end)

    -- The engine emits this while the faint is being announced, before the
    -- forced-switch UI. Death is immediate; array compaction is deferred.
    mod.events:on("battle.fainted", recordBattleFaint)

    -- The native battle bridge writes back party HP before battle.ended.
    -- Compact party arrays only then, after the engine no longer needs indices.
    mod.events:on("battle.ended", function(ev)
        retireFainted(type(ev) == "table" and ev.result or nil,
            type(ev) == "table" and ev.battle or nil)
        if type(ev) == "table" and ev.result == "win" then
            local saved = loadState()
            if Levels.noteWin(saved, session(), ev.battle) then
                writeState(saved)
            end
        end
        activeBattle = nil
        battleInProgress = false
        currentBattleState = nil
        battleDeaths = nil
        mercyBattle = nil
        refreshCapNotice()
        nicknameTasks()
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
        randomizer = {
            get = function(key)
                return Randomizer.get(loadState(), key)
            end,
            set = function(key, value)
                local saved = loadState()
                local ok, reason = Randomizer.set(saved, key, value)
                if ok then writeState(saved) end
                return ok, reason
            end,
            seed = function()
                return Randomizer.seed(loadState())
            end,
            locked = function()
                return Randomizer.locked(loadState())
            end,
        },

        variants = Variants,
        battleItemRules = BattleItemRules,
        fieldItemRules = FieldRules,
        notices = function() return Notices.history(loadState()) end,
        notify = notify,
        getState = loadState, setState = writeState,
        core = Core, clauses = Clauses, catchRules = CatchRules,
        battleClauses = BattleClauses, statusBans = StatusBans,
        shinyRate = ShinyRate,
        playstyles = Playstyles,
        eggs = Eggs, forgiveness = Forgiveness,
        onClauseChanged = onClauseChanged,
        dev = Dev, display = Display,
        levels = {
            get = function(key) return Levels.get(loadState(), key) end,
            set = function(key, value)
                local saved = loadState()
                local ok, reason = Levels.set(saved, key, value)
                if ok then writeState(saved) end
                return ok, reason
            end,
            cap = function() return levelCap() end,
            banked = function(mon) return Levels.banked(loadState(), mon) end,
            currentParty = function()
                return (session() and session().party) or {}
            end,
        },
        nickname = {
            pending = nicknameTasks,
            rename = function(mon, name)
                if not Core.enforced(loadState(), "nickname_rule")
                    or type(mon) ~= "table"
                    or not Extra.customName(name, Display.speciesName(mon)) then
                    return false
                end
                mon.nickname = name
                nicknameTasks()
                notify("NICKNAME_SET", "Nickname Rule: "
                    .. Notices.name(mon, Display) .. " has been named.", false)
                return true
            end,
        },
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
                installCandyGuard()
                installFishingGuard()
                installBattleClauseGuards()
                installStatusBanGuards()
        installAcquisitionGuards()
                Gen3Menu.open(g)
            end,
        })
        return rows
    end)

    mod.exports.gen3_menu = Gen3Menu
    mod.exports.gen3_randomizer = {
        api = Randomizer.api, algorithm = Randomizer.algorithm,
        get = function(key) return Randomizer.get(loadState(), key) end,
        set = function(key, value)
            local saved = loadState()
            local ok, reason = Randomizer.set(saved, key, value)
            if ok then writeState(saved) end
            return ok, reason
        end,
        effectiveSeed = function() return Randomizer.seed(loadState()) end,
        locked = function() return Randomizer.locked(loadState()) end,
    }
    mod.exports.gen3_playstyles = {
        api = Playstyles.api, schema = Playstyles.schema,
        definitions = Playstyles.descriptors,
        getRule = function(key)
            return Playstyles.get(loadState(), key)
        end,
        setRule = function(key, value)
            local saved = loadState()
            local ok, reason = Playstyles.set(saved, key, value)
            if ok then
                writeState(saved)
                if key == "hardcore_nuzlocke" then
                    notify("PLAYSTYLE_CHANGED", value
                        and "Hardcore ON: forced SET, no battle items except "
                            .. "Poke Balls, Champion level caps and strict "
                            .. "Nuzlocke rules."
                        or "Hardcore OFF: previous CORE, LEVELS and battle "
                            .. "style preferences restored.", false)
                    refreshCapNotice()
                else
                    notify("PLAYSTYLE_CHANGED",
                        "Shiny Nuzlocke " .. (value and "enabled: only shinies"
                            or "disabled: ordinary catch rules")
                        .. (value and " may be caught." or " restored."), false)
                end
            end
            return ok, reason
        end,
    }
    mod.exports.gen3_notices = {
        api = Notices.api,
        history = function() return Notices.history(loadState()) end,
    }
    mod.exports.gen3_levels = {
        api = Levels.api, schema = Levels.schema,
        scopes = Levels.scopes,
        getRule = function(key) return Levels.get(loadState(), key) end,
        getCurrentCap = function() return levelCap() end,
        getBank = function(mon) return Levels.banked(loadState(), mon) end,
        setRule = function(key, value)
            local saved = loadState()
            local ok, reason = Levels.set(saved, key, value)
            if ok then writeState(saved) end
            return ok, reason
        end,
        setPostgameCap = function(value)
            local saved = loadState()
            local ok, reason = Levels.setPostgameCap(saved, value)
            if ok then writeState(saved) end
            return ok, reason
        end,
    }
    -- Read-only diagnostic API. Mutators stay internal to the developer menu.
    mod.exports.gen3_status_bans = {
        api=StatusBans.api,schema=StatusBans.schema,
        definitions=StatusBans.descriptors,
        getRule=function(key) return StatusBans.get(loadState(),key) end,
        setRule=function(key,value)
            local saved=loadState()
            local ok,reason=StatusBans.set(saved,key,value)
            if ok then writeState(saved) end
            return ok,reason
        end,
    }
    mod.exports.gen3_battle_clauses = {
        api=BattleClauses.api, schema=BattleClauses.schema,
        definitions=BattleClauses.descriptors,
        getRule=function(key) return BattleClauses.get(loadState(),key) end,
        setRule=function(key,value)
            local s=loadState()
            local ok,reason=BattleClauses.set(s,key,value)
            if ok then writeState(s) end
            return ok,reason
        end,
    }
    mod.exports.gen3_field_items = {
        api=FieldRules.api,schema=FieldRules.schema,
        definitions=FieldRules.descriptors,
        getRule=function(key) return FieldRules.get(loadState(),key) end,
        setRule=function(key,value)
            local saved=loadState()
            local ok,reason=FieldRules.set(saved,key,value)
            if ok then writeState(saved) end
            return ok,reason
        end,
    }
    mod.exports.gen3_battle_items = {
        api=BattleItemRules.api,schema=BattleItemRules.schema,
        definitions=BattleItemRules.descriptors,
        getRule=function(key) return BattleItemRules.get(loadState(),key) end,
        setRule=function(key,value)
            local saved=loadState()
            local ok,reason=BattleItemRules.set(saved,key,value)
            if ok then writeState(saved) end
            return ok,reason
        end,
        throws=function()
            return activeBattle and activeBattle.ballThrows or 0
        end,
    }
    mod.exports.gen3_variants = {
        api=Variants.api,schema=Variants.schema,
        definitions=Variants.descriptors,
        getRule=function(key) return Variants.get(loadState(),key) end,
        setRule=function(key,value)
            local saved=loadState()
            local ok,reason=Variants.set(saved,key,value)
            if ok then writeState(saved) end
            return ok,reason
        end,
        check=function(species)
            local ok,Pokemon=pcall(require,"src.core.game3.pokemon")
            return Variants.check(loadState(),species,
                ok and Pokemon or nil,Core)
        end,
    }
    mod.exports.gen3_catch_rules = {
        api = CatchRules.api, schema = CatchRules.schema,
        definitions = CatchRules.descriptors,
        getRule = function(key) return CatchRules.get(loadState(), key) end,
        setRule = function(key, value)
            local s = loadState()
            local ok, reason = CatchRules.set(s, key, value)
            if ok then writeState(s) end
            return ok, reason
        end,
        check = function(species)
            local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
            return CatchRules.check(loadState(), species,
                ok and Pokemon or nil, Core)
        end,
    }
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
            if ok then
                writeState(state)
                if key == "nickname_rule" and value then nicknameTasks() end
            end
            return ok, err
        end,
    }

    -- Advertise supported scope without borrowing existing API-37 promises.
    mod.exports.gen3_classic = {
        api = 1,
        stage = "EXPERIMENTAL",
        features = { "first_wild_per_area", "optional_failed_encounters",
            "gen3_dupes_clause", "gen3_shiny_clause", "gen3_roamer_clause",
            "gen3_shiny_rate", "gen3_shiny_nuzlocke",
            "gen3_hardcore_nuzlocke", "gen3_eggs_wip",
            "gen3_route_forgiveness_wip",
            "gen3_catch_species_bans", "gen3_catch_maximum_bst",
            "gen3_no_static_encounters", "gen3_no_fishing",
            "gen3_effect_battle_clauses",
            "gen3_status_bans",
            "immediate_faint_death", "revive_denial", "post_battle_retirement",
            "whiteout_ends_run", "first_rival_mercy_wip",
            "pc_survivors_wip", "nickname_requirement_wip",
            "gym_league_level_caps", "exp_edging",
            "random_wild_and_fishing_species", "random_trainer_parties",
            "randomizer_seed_v1" },
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
