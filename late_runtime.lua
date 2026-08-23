-- Module owner: LateRuntime
return function(mod, deps)
  local unpackValues = table.unpack or unpack
  assert(type(unpackValues) == "function", "Nuzlocke requires Lua unpack support")
  deps = deps or {}
  local Strings = assert(deps.Strings, "late_runtime requires Strings")
  local getCurrentGame = assert(deps.getCurrentGame, "late_runtime requires getCurrentGame")
  local getCurrentSave = assert(deps.getCurrentSave, "late_runtime requires getCurrentSave")
  local saveBlocked = assert(deps.saveBlocked, "late_runtime requires saveBlocked")
  local catchDeniedReason = deps.catchDeniedReason
  local getGameVersion = assert(deps.getGameVersion, "late_runtime requires getGameVersion")
  local getDisplayRoutes = assert(deps.getDisplayRoutes, "late_runtime requires getDisplayRoutes")
  local getEncounterState = assert(deps.getEncounterState, "late_runtime requires getEncounterState")
  local evaluateItemUsePolicy = assert(deps.evaluateItemUsePolicy, "late_runtime requires evaluateItemUsePolicy")
  local externalRuleDelegation = deps.externalRuleDelegation
  local specialAcquisitionDenied = assert(deps.specialAcquisitionDenied, "late_runtime requires specialAcquisitionDenied")
  local active = assert(deps.active, "late_runtime requires active")
  local activeCompatProvider = assert(deps.activeCompatProvider, "late_runtime requires activeCompatProvider")
  local wrapText = assert(deps.wrapText, "late_runtime requires wrapText")
  local ALL_ROUTES = assert(deps.ALL_ROUTES, "late_runtime requires ALL_ROUTES")
  local registerArea = assert(deps.registerArea, "late_runtime requires registerArea")
  local routeName = assert(deps.routeName, "late_runtime requires routeName")
  local caughtAreas = assert(deps.caughtAreas, "late_runtime requires caughtAreas")
  local trackerLog = assert(deps.trackerLog, "late_runtime requires trackerLog")
  local visitedAreas = assert(deps.visitedAreas, "late_runtime requires visitedAreas")
  local areaKey = assert(deps.areaKey, "late_runtime requires areaKey")
  local markVisited = assert(deps.markVisited, "late_runtime requires markVisited")
  local Identity = assert(deps.Identity, "late_runtime requires Identity")
  local speciesDefinition = assert(deps.speciesDefinition, "late_runtime requires speciesDefinition")
  local providerSpeciesMetadata = assert(deps.providerSpeciesMetadata, "late_runtime requires providerSpeciesMetadata")
  local isLegendarySpecies = assert(deps.isLegendarySpecies, "late_runtime requires isLegendarySpecies")
  local isMythicalSpecies = assert(deps.isMythicalSpecies, "late_runtime requires isMythicalSpecies")
  local isPseudoSpecies = assert(deps.isPseudoSpecies, "late_runtime requires isPseudoSpecies")
  local allCurrentMons = assert(deps.allCurrentMons, "late_runtime requires allCurrentMons")
  local ensurePokemonIdentity = assert(deps.ensurePokemonIdentity, "late_runtime requires ensurePokemonIdentity")
  local pokemonIdentity = assert(deps.pokemonIdentity, "late_runtime requires pokemonIdentity")
  local setPokemonOrigin = assert(deps.setPokemonOrigin, "late_runtime requires setPokemonOrigin")
  local baselineAdd = assert(deps.baselineAdd, "late_runtime requires baselineAdd")
  local ruleCategories = assert(deps.ruleCategories, "late_runtime requires ruleCategories")
  local LockePreset = assert(deps.LockePreset, "late_runtime requires LockePreset")
  local defaultRuleValue = assert(deps.defaultRuleValue, "late_runtime requires defaultRuleValue")
  local legacyLevelCapScope = assert(deps.legacyLevelCapScope, "late_runtime requires legacyLevelCapScope")
  local randomStarterChoiceValid = assert(deps.randomStarterChoiceValid, "late_runtime requires randomStarterChoiceValid")
  local randomStarterRuleEnabled = assert(deps.randomStarterRuleEnabled, "late_runtime requires randomStarterRuleEnabled")
  local worldTier = assert(deps.worldTier, "late_runtime requires worldTier")
  local installOwnedMethodWrapper = assert(deps.installOwnedMethodWrapper, "late_runtime requires installOwnedMethodWrapper")
  local worldMechanic = assert(deps.worldMechanic, "late_runtime requires worldMechanic")
  local currentBadgeCount = assert(deps.currentBadgeCount, "late_runtime requires currentBadgeCount")
  local nextLevelCap = assert(deps.nextLevelCap, "late_runtime requires nextLevelCap")
  local Difficulty = assert(deps.Difficulty, "late_runtime requires Difficulty")
  local countTrackerCatches = assert(deps.countTrackerCatches, "late_runtime requires countTrackerCatches")
  local providerDisplay = assert(deps.providerDisplay, "late_runtime requires providerDisplay")
  local getConfigValue = assert(deps.getConfigValue, "late_runtime requires getConfigValue")
  local uiRememberedScreen = assert(deps.uiRememberedScreen, "late_runtime requires uiRememberedScreen")
  local syncCurrentArea = assert(deps.syncCurrentArea, "late_runtime requires syncCurrentArea")
  local areaAllowedByConfig = assert(deps.areaAllowedByConfig, "late_runtime requires areaAllowedByConfig")
  local nuzStatusEncounterSnapshot = assert(deps.nuzStatusEncounterSnapshot, "late_runtime requires nuzStatusEncounterSnapshot")
  local nuzStatusLastHistoryEvent = assert(deps.nuzStatusLastHistoryEvent, "late_runtime requires nuzStatusLastHistoryEvent")
  local nuzStatusTokenBalance = assert(deps.nuzStatusTokenBalance, "late_runtime requires nuzStatusTokenBalance")
  local nuzCompatIdentityLine = assert(deps.nuzCompatIdentityLine, "late_runtime requires nuzCompatIdentityLine")
  local pushNuzlockeRunHistoryViewer = assert(deps.pushNuzlockeRunHistoryViewer, "late_runtime requires pushNuzlockeRunHistoryViewer")
  local recordRunBlackout = assert(deps.recordRunBlackout, "late_runtime requires recordRunBlackout")
  local ItemPolicy = assert(deps.ItemPolicy, "late_runtime requires ItemPolicy")
  local showRuleMessage = assert(deps.showRuleMessage,
      "late_runtime requires showRuleMessage")
  local acquisitionDeniedMessage = assert(deps.acquisitionDeniedMessage,
      "late_runtime requires acquisitionDeniedMessage")
  local STARTERS_BY_VERSION = assert(deps.STARTERS_BY_VERSION, "late_runtime requires STARTERS_BY_VERSION")
  local hasHealthyParty = assert(deps.hasHealthyParty, "late_runtime requires hasHealthyParty")

    -- GEN 2 CORE-RULE ADAPTERS
    --
    -- Gen 2 has a separate battle UI, script VM, naming screen and mart UI.
    -- Keep the established R/B/Y paths above untouched and bridge the same
    -- Nuzlocke policy into the live Gen 2 modules here.
    ---------------------------------------------------------------------
    do
        local G2 = {}
  
        function G2.isGen2(game)
            return mod.exports.__beta26.runtimeIsGen2(
                game or getCurrentGame() or mod.game)
        end
  
        function G2.catchMessage(game, reason, species)
            return mod.exports.__beta26.catchRejectionMessage(game, reason, species)
        end

        -- 2.5.42: own Nuzlocke-authored Gold battle-rule pagination instead of
        -- depending on BattleState.messageTimer semantics. Current Gen1Recomp
        -- already holds prompt text for A/B, but older supported builds used
        -- different timing behavior and a direct self.message assignment never
        -- guaranteed multiple pages. Keep every Nuzlocke denial at two native
        -- 18-column lines per page and require A/B between pages.
        function G2.showBattleRuleText(self, message)
            if type(self) ~= "table" then return false end
            local lines = wrapText(
                mod.exports.__beta26.cleanWorldText(message), 18)
            local pages = {}
            for i = 1, #lines, 2 do
                local page = tostring(lines[i] or "")
                if lines[i + 1] then page = page .. "\n" .. tostring(lines[i + 1]) end
                pages[#pages + 1] = page
            end
            if #pages == 0 then pages[1] = Strings("Nuzlocke rule blocked that action.") end
            -- 2.5.43: this pager is an overlay on the current battle state, not
            -- a native queue row. Preserve the exact fields we temporarily own
            -- and never clear/advance BattleState.queue: doing so can discard
            -- vanilla or other-mod messages/actions that were already pending.
            if type(self.__nuzlockeRuleReturn) ~= "table" then
                self.__nuzlockeRuleReturn = {
                    phase = self.phase,
                    message = self.message,
                    messageTimer = self.messageTimer,
                }
            end
            self.__nuzlockeRulePages = pages
            self.__nuzlockeRulePage = 1
            self.message = pages[1]
            self.messageTimer = 0
            self.phase = "nuzlocke-rule-text"
            return true
        end

        function G2.installBattleRulePager()
            if not G2.isGen2() then return false end
            local ok, BS = pcall(require, "src.ui.gen2.BattleState")
            if not ok or type(BS) ~= "table" or type(BS.update) ~= "function" then
                return false
            end
            local session = BS.__nuzlockeRulePagerSession
            if type(session) == "table" and session.owner ~= mod
                and BS.update == session.wrapper
                and type(session.previous) == "function" then
                BS.update = session.previous
                session = nil
            end
            if type(session) == "table" and session.owner == mod
                and BS.update == session.wrapper then
                return true
            end
            local vanilla = BS.update
            local updateWrapper
            updateWrapper = function(self, dt)
                local pages = self and self.__nuzlockeRulePages
                if type(pages) == "table" then
                    local input = (self.game and self.game.input)
                        or (getCurrentGame() and getCurrentGame().input)
                        or (mod.game and mod.game.input)
                    if not input or type(input.wasPressed) ~= "function" then
                        -- Never auto-advance a rule page. A missing input object
                        -- can be transient during compatibility/lifecycle churn;
                        -- keep the page owned until a valid input source returns.
                        return
                    end
                    if input:wasPressed("a") or input:wasPressed("b") then
                        local nextPage = (tonumber(self.__nuzlockeRulePage) or 1) + 1
                        if pages[nextPage] ~= nil then
                            self.__nuzlockeRulePage = nextPage
                            self.message = pages[nextPage]
                        else
                            local returnState = self.__nuzlockeRuleReturn
                            self.__nuzlockeRulePages = nil
                            self.__nuzlockeRulePage = nil
                            self.__nuzlockeRuleReturn = nil
                            if type(returnState) == "table" then
                                self.phase = returnState.phase
                                self.message = returnState.message
                                self.messageTimer = returnState.messageTimer
                            else
                                -- Defensive compatibility fallback for a pager
                                -- session created by an older wrapper instance.
                                self.phase = "menu"
                                self.message = nil
                                self.messageTimer = 0
                            end
                        end
                    end
                    return
                end
                return vanilla(self, dt)
            end
            BS.update = updateWrapper
            BS.__nuzlockeRulePagerSession = {
                owner = mod, previous = vanilla, wrapper = updateWrapper,
            }
            return true
        end
  
        function G2.installCaptureGate()
            if not G2.isGen2() then return false end
            local ok, BS = pcall(require, "src.ui.gen2.BattleState")
            if not ok or type(BS) ~= "table" or type(BS.useItem) ~= "function" then return false end

            local session = BS.__nuzlockeCaptureGateSession
            if type(session) == "table" and session.owner ~= mod
                and BS.useItem == session.wrapper
                and type(session.previous) == "function" then
                BS.useItem = session.previous
                session = nil
            end
            if type(session) == "table" and session.owner == mod
                and BS.useItem == session.wrapper then
                return true
            end

            local vanilla = BS.useItem
            local captureWrapper
            captureWrapper = function(self, itemId)
                local data = self and self.game and self.game.data or {}
                local def = data.items and data.items[itemId]
                if self and self.battle and not self.tutorial
                    and not (def and def.pocket == "BALL") then
                    local allowed, decision = evaluateItemUsePolicy(
                        self.game, data, self.game and self.game.save, itemId, nil,
                        { battle = self.battle, inBattle = true,
                          generation = 2,
                          isBall = def and def.pocket == "BALL" })
                    -- 0.1.98's Gold battle Pack now routes healing/status/revive,
                    -- PP recovery, stat/X items, and balls through this one
                    -- semantic useItem path. Any authoritative Nuzlocke item
                    -- denial must stop here; do not whitelist only two codes.
                    if allowed == false then
                        local tier = worldTier(self.game)
                        local message = decision and decision.message
                            or Strings("Item use is blocked!")
                        if tier >= 3 and decision and decision.tier3 then
                            message = decision.tier3
                        elseif tier >= 2 and decision and decision.tier2 then
                            message = decision.tier2
                        end
                        G2.showBattleRuleText(self, message)
                        return
                    end
                end
                -- Native Gold uses battle.wild for every non-trainer battle,
                -- including loadwildmon-driven static encounters. Also accept
                -- explicit static provenance for compatibility with mods that
                -- construct a fixed battle without the native opts.wild shape.
                local catchableBattle = self and self.battle
                    and (self.battle.wild
                        or mod.exports.__beta26.isStaticEncounter(
                            self.game, self.battle))
                if def and def.pocket == "BALL" and self and self.battle
                    and catchableBattle and not self.tutorial then
                    local allowed, decision = evaluateItemUsePolicy(
                        self.game, data, self.game and self.game.save, itemId, nil,
                        { battle = self.battle, inBattle = true, isBall = true })
                    if allowed == false and decision
                        and (decision.key == "no_catching"
                            or decision.code == "no_catching"
                            or decision.rule == "no_catching") then
                        local override = mod.exports.__beta26.tryProgressionCatchOverride
                        if type(override) == "function" then
                            local okOverride, bypass, refusal = pcall(override,
                                self.game, self.battle, "no_catching", self.battle)
                            if okOverride and bypass == true then
                                allowed = true
                            elseif okOverride and refusal == "progression_pc_full" then
                                decision = decision or {}
                                decision.message = mod.exports.__beta26.worldRuleText(
                                    self.game, "progression_pc_full")
                                decision.tier2 = decision.message
                                decision.tier3 = decision.message
                            end
                        end
                    end
                    if allowed == false then
                        local tier = worldTier(self.game)
                        local message = decision and decision.message
                            or Strings("No Catching is ON!")
                        if tier >= 3 and decision and decision.tier3 then
                            message = decision.tier3
                        elseif tier >= 2 and decision and decision.tier2 then
                            message = decision.tier2
                        end
                        G2.showBattleRuleText(self, message)
                        return
                    end
                    local enemy = self.battle.enemy
                    local species = enemy and enemy.species
                    local okReason, reason = pcall(catchDeniedReason,
                        self.game, self.battle, species)
                    if not okReason then
                        mod.exports.__beta26.lastAcquisitionPolicyError =
                            "gen2_capture: " .. tostring(reason)
                        G2.showBattleRuleText(self, Strings(
                            "Nuzlocke capture policy error. Catch blocked safely."))
                        return
                    end
                    if reason then
                        G2.showBattleRuleText(self,
                            G2.catchMessage(self.game, reason, species)
                                or Strings("That catch is not allowed by your Nuzlocke rules."))
                        return
                    end
                    local ballAllowed, ballLimit =
                        mod.exports.__beta26.encounterBallThrowAvailable(
                            self.game, self.battle)
                    if not ballAllowed then
                        G2.showBattleRuleText(self,
                            mod.exports.__beta26.encounterBallLimitMessage(ballLimit))
                        return
                    end
                    mod.exports.__beta26.consumeEncounterBallThrow(
                        self.game, self.battle)
                end
                return vanilla(self, itemId)
            end
            BS.useItem = captureWrapper
            BS.__nuzlockeCaptureGateSession = {
                owner = mod, previous = vanilla, wrapper = captureWrapper,
            }
            BS.__nuzlockeBeta22CaptureGate = true -- historical marker only
            return true
        end
  
        function G2.noteDamage(ev)
            if not G2.isGen2() or not ev or not ev.battle then return end
            if mod.save:get("physical_special_split", false) == true
                and ev.target and ev.move then
                local category = mod.exports.__beta26.modernMoveCategory(
                    ev.move, ev.moveId)
                if category == "physical" or category == "special" then
                    ev.kind = category
                    if type(ev.battle.volatile) == "function" then
                        ev.battle:volatile(ev.target).tookKind = category
                    end
                end
            end
            if ev.target == ev.battle.player then
                ev.battle.nuzlockeG2LastDamage = {
                    move = ev.moveId or (ev.move and ev.move.id),
                    attacker = ev.user,
                    damage = ev.damage,
                    critical = ev.crit == true,
                }
            end
        end
  
        function G2.recordDeath(game, battle, mon)
            if not (game and battle and mon) or mon.nuzlockeDead then return end
            local key = areaKey(game, nil)
            local enemy = battle.enemy
            local enemySpecies = enemy and (enemy.nickname or enemy.name or enemy.species) or "BATTLE"
            local damage = battle.nuzlockeG2LastDamage
            local glitch = mod.exports.__beta26.getGlitchSpeciesInfo(game, mon.species)
            local monLabel = tostring(mon.nickname or glitch.label or "Pokemon")
            local cause = monLabel
                .. " died in battle against " .. tostring(enemySpecies) .. "."
            if damage and damage.move then
                cause = monLabel
                    .. " died to " .. tostring(enemySpecies) .. " after "
                    .. (damage.critical and "a critical " or "") .. tostring(damage.move) .. "."
            elseif mon.status then
                cause = monLabel
                    .. " died in battle while affected by " .. tostring(mon.status) .. "."
            end
  
            mon.nuzlockeDead = true
            mon.nuzlockeDeathSequence = math.max(0,
                math.floor(tonumber(mon.nuzlockeDeathSequence) or 0)) + 1
            mon.deathLocation = key
            mon.deathCause = cause
            mon.deathCauseText = cause
            mon.deathEncounterType = battle.trainer and "trainer" or "wild"
            mon.deathOpponentSpecies = enemySpecies
            mon.deathMove = damage and damage.move or nil
            mon.deathCritical = damage and damage.critical == true or false
            pcall(mod.exports.__beta26.archiveForgivenessDeath, game, mon)
  
            local history = mod.save:get("nuzlocke_history", {})
            if type(history) ~= "table" then history = {} end
            table.insert(history, {
                name = mon.nickname or glitch.label,
                species = glitch.key,
                rawSpecies = glitch.isGlitch and mon.species or nil,
                glitch = glitch.isGlitch or nil,
                missingNo = glitch.missingNo or nil,
                pokemonId = Identity.ensurePokemonIdentity(mon, getCurrentSave(),
                    mon.nuzlockeOrigin or "NORMAL"),
                catchLocation = mon.catchLocation,
                encounterType = mon.encounterType,
                status = "DEAD",
                deathLocation = key,
                deathCause = cause,
                deathOpponentSpecies = enemySpecies,
                deathMove = mon.deathMove,
                deathCritical = mon.deathCritical,
            })
            mod.save:set("nuzlocke_history", history)
            pcall(mod.exports.__beta26.RunHistory.recordDeath, game, mon, {
                species = glitch.key, rawSpecies = glitch.isGlitch and mon.species or nil,
                pokemonId = Identity.pokemonIdentity(mon), area = key, cause = cause,
                opponentSpecies = enemySpecies, move = mon.deathMove,
                critical = mon.deathCritical, source = "battle",
            })
            if type(mod.exports.__beta26.syncTrackerDeathProjection) == "function" then
                pcall(mod.exports.__beta26.syncTrackerDeathProjection)
            end
            mod.save:set("nuzlocke_losses",
                (tonumber(mod.save:get("nuzlocke_losses", 0)) or 0) + 1)
            mod.save:set("last_loss", {
                name = mon.nickname or glitch.label,
                species = glitch.key,
                rawSpecies = glitch.isGlitch and mon.species or nil,
                glitch = glitch.isGlitch or nil,
                missingNo = glitch.missingNo or nil,
                pokemonId = Identity.pokemonIdentity(mon),
                location = key,
                cause = cause,
            })
  
            worldMechanic(game,
                "death:g2:" .. monLabel .. ":" .. tostring(key),
                Strings("%s has fallen.\nPermadeath applies.", monLabel),
                Strings("%s is gone from the run.\nThe Tracker marks the loss.", monLabel),
                Strings("Johto remembers %s.\nAnother name enters the Nuzlocke ledger.", monLabel))
  
            local party = game.save and game.save.party
            if type(party) == "table"
                and mon.nuzlockeForgivenessArchivePending ~= true then
                for i = #party, 1, -1 do
                    if party[i] == mon then
                        table.remove(party, i)
                        break
                    end
                end
            end
        end
  
        function G2.onFaint(ev)
            if not G2.isGen2() or not ev or not ev.battle or not ev.battler then return end
            local battle = ev.battle
            if battle.player ~= ev.battler then return end
            local game = getCurrentGame() or mod.game
            if not active(game, battle) then return end
            if mod.exports.__beta26.isFirstRivalForgivenessActive(game, battle) then
                -- 2.5.9 / Gen1Recomp 0.2.7 source audit: Gold's first
                -- Cherrygrove Rival battle is BATTLETYPE_CANLOSE. A loss
                -- intentionally leaves the starter at 0 HP while the script
                -- continues at the battle site; its .FinishRival path owns the
                -- later `special HealParty`. Do NOT mirror R/B/Y's temporary
                -- 1-HP bridge here: suppressing Nuzlocke death/Whiteout and
                -- preserving the native 0-HP intermediate state is correct.
                if ev.battler.mon then
                    ev.battler.mon.nuzlockeRivalForgiven = true
                elseif type(ev.battler) == "table" then
                    ev.battler.nuzlockeRivalForgiven = true
                end
                battle.nuzlockeRivalForgivenessTriggered = true
                return
            end
            if mod.save:get("permadeath", true) then
                G2.recordDeath(game, battle, ev.battler)
            end
            if not hasHealthyParty(game) then
                local decision, counts =
                    mod.exports.__beta26.whiteoutDecision(game)
                if decision == "survive" then
                    battle.nuzlockeWhiteoutSurvives = true
                    battle.nuzlockeWhiteoutRecoveryCounts = counts
                    battle.nuzlockeGameOver = nil
                else
                    battle.nuzlockeWhiteoutSurvives = nil
                    battle.nuzlockeWhiteoutRecoveryCounts = nil
                    battle.nuzlockeGameOver = true
                end
            end
        end
  
        function G2.installNicknameGate()
            if not G2.isGen2() then return false end
            local okBS, BS = pcall(require, "src.ui.gen2.BattleState")
            local okNS, NS = pcall(require, "src.ui.gen2.NamingScreen")
  
            -- Module tables survive mod-loader sessions in some engine builds.
            -- Own each replacement explicitly so a reload can remove our exact
            -- old wrapper without disturbing a later wrapper from another mod.
            if okBS and type(BS) == "table"
                and type(BS.answerNickname) == "function" then
                local session = BS.__nuzlockeNicknameAnswerSession
                if type(session) == "table" and session.owner ~= mod
                    and BS.answerNickname == session.wrapper then
                    BS.answerNickname = session.previous
                    session = nil
                end
                if not (type(session) == "table" and session.owner == mod
                    and BS.answerNickname == session.wrapper) then
                    local vanillaAnswer = BS.answerNickname
                    local wrapper = function(self, yes)
                        if active(self and self.game, self and self.battle)
                            and mod.save:get("nickname_rule", defaultRuleValue("nickname_rule")) then
                            yes = true
                        end
                        return vanillaAnswer(self, yes)
                    end
                    BS.answerNickname = wrapper
                    BS.__nuzlockeNicknameAnswerSession = {
                        owner = mod,
                        previous = vanillaAnswer,
                        wrapper = wrapper,
                    }
                    -- Retain the historical marker for mods that inspect it.
                    BS.__nuzlockeBeta22ForceNickname = true
                end
            end
            if okNS and type(NS) == "table" and type(NS.accept) == "function" then
                local session = NS.__nuzlockeNicknameAcceptSession
                if type(session) == "table" and session.owner ~= mod
                    and NS.accept == session.wrapper then
                    NS.accept = session.previous
                    session = nil
                end
                if not (type(session) == "table" and session.owner == mod
                    and NS.accept == session.wrapper) then
                    local vanillaAccept = NS.accept
                    local wrapper = function(self)
                        local blank = not tostring(self and self.text or ""):find("%S")
                        if G2.isGen2() and self and self.kind == NS.TYPES.nickname
                            and active(self.game, nil)
                            and mod.save:get("nickname_rule", defaultRuleValue("nickname_rule"))
                            and blank then
                            return
                        end
                        return vanillaAccept(self)
                    end
                    NS.accept = wrapper
                    NS.__nuzlockeNicknameAcceptSession = {
                        owner = mod,
                        previous = vanillaAccept,
                        wrapper = wrapper,
                    }
                    NS.__nuzlockeBeta22NonEmptyNickname = true
                end
            end
            return true
        end
  
        -- Scripted gifts do not pass through BattleState:answerNickname. Use the
        -- VM's blocking rename seam so the story remains parked until Gold's
        -- native naming screen closes, then resumes at the exact next command.
        function G2.requireGiftNickname(game, mon, vm)
            if not (mon and active(game, nil)
                and mod.save:get("nickname_rule", defaultRuleValue("nickname_rule"))) then
                return false
            end
            local existing = tostring(mon.nickname or "")
            local species = tostring(mon.species or mon.name or "")
            if existing:find("%S") and existing:upper() ~= species:upper() then
                mon.nuzlockeNeedsNickname = nil
                mon.nuzlockeNicknameRequired = nil
                return true
            end
  
            mon.nuzlockeNeedsNickname = true
            mon.nuzlockeNicknameRequired = true
            local rename = vm and vm.specials and vm.specials.renameMon
            local okSpecials, Specials = pcall(require, "src.script.gen2.Specials")
            if not (type(rename) == "function" and okSpecials
                and type(Specials) == "table"
                and type(Specials.block) == "function") then
                return false
            end
  
            local name = Specials.block(vm, function(done)
                rename(mon, done, { blank = true })
            end)
            name = tostring(name or "")
            if not name:find("%S") then return false end
            mon.nickname = name
            mon.nuzlockeNeedsNickname = nil
            mon.nuzlockeNicknameRequired = nil
            return true
        end
  
        function G2.installMartGate()
            local runtimeGame = getCurrentGame() or mod.game
            if not G2.isGen2(runtimeGame) then return false end
            local ok, Mart = pcall(require, "src.ui.gen2.MartMenu")
            if not ok or type(Mart) ~= "table" then return false end
  
            -- Gold's native Mart owns BUY/SELL as methods on one screen. The old
            -- beta.22 bridge wrapped only offerToBuy/offerToSell, which was both
            -- too late (the player could enter the forbidden menu) and fragile
            -- across loader/save-editor sessions. Gate the semantic entry points
            -- and transaction endpoints instead, and track wrapper ownership so a
            -- fresh ModLoader never keeps a stale mod.save closure.
            local session = Mart.__nuzlockeMartGateSession29314
            local sessionLive = type(session) == "table" and session.owner == mod
                and type(session.methods) == "table"
                and next(session.methods) ~= nil
            if sessionLive then
                for name, row in pairs(session.methods or {}) do
                    if type(row) ~= "table" or Mart[name] ~= row.wrapper then
                        sessionLive = false
                        break
                    end
                end
            end
            if type(session) == "table" and not sessionLive then
                for name, row in pairs(session.methods or {}) do
                    if type(row) == "table" and Mart[name] == row.wrapper
                        and type(row.previous) == "function" then
                        Mart[name] = row.previous
                    end
                end
                session = nil
            end
  
            local function denialPages(self, key)
                local text = mod.exports.__beta26.worldRuleText(
                    self and self.game or runtimeGame, key)
                local lines = wrapText(
                    mod.exports.__beta26.cleanWorldText(text), 18)
                local pages = {}
                for i = 1, #lines, 2 do
                    pages[#pages + 1] = { lines[i], lines[i + 1] }
                end
                if #pages == 0 then
                    pages[1] = { key == "no_buying"
                        and Strings("Buying is disabled.")
                        or Strings("Selling is disabled.") }
                end
                return pages
            end
  
            local function denied(self, key)
                local game = self and self.game or runtimeGame
                if key == "no_buying" then
                    return mod.exports.nuzlocke_compat.canPurchase(
                        game, { kind = "item_shop", generation = 2 }) == false
                end
                return mod.exports.nuzlocke_compat.canSell(
                    game, { kind = "item_shop", generation = 2 }) == false
            end
  
            local function hideForgivenessFromSell(self)
                local pack = self and self.pack
                local rows = pack and pack.rows
                local tokenId = tostring(
                    mod.exports.__beta26.forgivenessTokenItemId or "")
                if type(rows) ~= "table" or tokenId == "" then return end
                for i = #rows, 1, -1 do
                    if tostring(rows[i] and rows[i].id or "") == tokenId then
                        table.remove(rows, i)
                    end
                end
                if pack.index and pack.index > #rows + 1 then
                    pack.index = math.max(1, #rows + 1)
                end
            end
  
            if not sessionLive then
                session = { owner = mod, methods = {} }
  
                local function wrapMethod(name, factory)
                    local previous = Mart[name]
                    if type(previous) ~= "function" then return end
                    local wrapper = factory(previous)
                    Mart[name] = wrapper
                    session.methods[name] = {
                        previous = previous, wrapper = wrapper,
                    }
                end
  
                wrapMethod("enterBuy", function(previous)
                    return function(self, ...)
                        if denied(self, "no_buying") then
                            if self and type(self.say) == "function" then
                                self:say(denialPages(self, "no_buying"), function()
                                    if self.martType == "STANDARD"
                                        and type(self.enterTop) == "function" then
                                        self:enterTop(self.text and self.text.askMore)
                                    elseif type(self.quit) == "function" then
                                        self:quit()
                                    end
                                end)
                            end
                            return
                        end
                        return previous(self, ...)
                    end
                end)
  
                wrapMethod("enterSell", function(previous)
                    return function(self, ...)
                        if denied(self, "no_selling") then
                            if self and type(self.say) == "function" then
                                self:say(denialPages(self, "no_selling"), function()
                                    if type(self.enterTop) == "function" then
                                        self:enterTop(self.text and self.text.askMore)
                                    end
                                end)
                            end
                            return
                        end
                        local result = previous(self, ...)
                        hideForgivenessFromSell(self)
                        return result
                    end
                end)
  
                -- Safety nets at the money-changing seams. These matter if a
                -- rule is toggled while a quantity/confirmation screen is open
                -- or another mod jumps directly to a transaction method.
                wrapMethod("completePurchase", function(previous)
                    return function(self, ...)
                        if denied(self, "no_buying") then
                            if self then self.phase = "buy" end
                            if self and type(self.say) == "function" then
                                self:say(denialPages(self, "no_buying"))
                            end
                            return
                        end
                        return previous(self, ...)
                    end
                end)
  
                wrapMethod("completeSale", function(previous)
                    return function(self, ...)
                        if denied(self, "no_selling") then
                            if self then self.phase = "sell" end
                            if self and type(self.say) == "function" then
                                self:say(denialPages(self, "no_selling"))
                            end
                            return
                        end
                        local result = previous(self, ...)
                        hideForgivenessFromSell(self)
                        return result
                    end
                end)
  
                Mart.__nuzlockeMartGateSession29314 = session
                Mart.__nuzlockeBeta22MartGate = true
            end
  
            return true
        end
  
        function G2.installHeldItemGate()
            if not G2.isGen2() then return false end
            local ok, HeldItemMenu = pcall(require, "src.ui.gen2.HeldItemMenu")
            if not ok or type(HeldItemMenu) ~= "table"
                or type(HeldItemMenu.giveItem) ~= "function" then
                return false
            end

            local session = HeldItemMenu.__nuzlockeNoHeldItemsSession
            if type(session) == "table" and session.owner == mod
                and HeldItemMenu.giveItem == session.wrapper then
                return true
            end
            if type(session) == "table" and session.owner ~= mod
                and HeldItemMenu.giveItem == session.wrapper
                and type(session.previous) == "function" then
                HeldItemMenu.giveItem = session.previous
            end

            local previous = HeldItemMenu.giveItem
            local wrapper
            wrapper = function(self, itemId, ...)
                local game = self and self.game or getCurrentGame() or mod.game
                if active(game, nil) and mod.save:get("no_held_items", false) == true then
                    -- Never destroy or forcibly remove an existing item. GIVE
                    -- is refused before Bag.remove / mon.item assignment, while
                    -- TAKE remains the untouched native escape hatch.
                    if self and type(self.say) == "function" then
                        local message = Strings("Held items are banned by your Nuzlocke rules.")
                        self:say({ { message } })
                        return
                    end
                    return
                end
                return previous(self, itemId, ...)
            end

            HeldItemMenu.giveItem = wrapper
            HeldItemMenu.__nuzlockeNoHeldItemsSession = {
                owner = mod,
                previous = previous,
                wrapper = wrapper,
            }
            return true
        end

        function G2.installFieldItemGate()
            if not G2.isGen2() then return false end
            local ok, PackMenu = pcall(require, "src.ui.gen2.PackMenu")
            if not ok or type(PackMenu) ~= "table"
                or type(PackMenu.useSelected) ~= "function" then return false end
  
            local session = PackMenu.__nuzlockeFieldItemGateSession
            if type(session) == "table" and session.owner == mod
                and PackMenu.useSelected == session.wrapper then return true end
            if type(session) == "table" and session.owner ~= mod
                and PackMenu.useSelected == session.wrapper
                and type(session.previous) == "function" then
                PackMenu.useSelected = session.previous
            end
  
            local previous = PackMenu.useSelected
            local wrapper
            wrapper = function(self, ...)
                local row = self and self.rows and self.rows[self.index]
                local inBattle = self and type(self.inBattle) == "function"
                    and self:inBattle() or false
                if row and not self.give
                    and tostring(row.id or "") == tostring(
                        mod.exports.__beta26.forgivenessTokenItemId or "") then
                    local game = self.game or (self.world and self.world.game)
                        or getCurrentGame() or mod.game
                    if inBattle then
                        self.message = { Strings("Use the F. TOKEN"),
                            Strings("outside battle.") }
                        return
                    end
                    mod.ui.push(game, "NuzlockeForgivenessItem", {
                        onSpent = function()
                            if type(self.rebuild) == "function" then self:rebuild() end
                        end,
                    })
                    return
                end
                if row and not inBattle and not self.give then
                    local game = self.game or (self.world and self.world.game)
                        or getCurrentGame() or mod.game
                    local data = game and game.data or { items = self.items }
                    local allowed, decision = evaluateItemUsePolicy(
                        game, data, game and game.save, row.id, nil,
                        { inBattle = false,
                          overworld = self.world,
                          generation = 2 })
                    local code = decision and decision.code
                    if allowed == false and (code == "no_tm_use"
                        or code == "no_rare_candy_use"
                        or code == "no_repels"
                        or code == "no_fishing"
                        or code == "no_escape_rope"
                        or code == "no_field_healing"
                        or code == "no_pp_items") then
                        local _, messages = ItemPolicy.present(game, decision)
                        self.message = messages or { Strings("Item use is blocked!") }
                        self.nuzlockeItemUseBlocked = code
                        return
                    end
                end
                return previous(self, ...)
            end
            PackMenu.useSelected = wrapper
            PackMenu.__nuzlockeFieldItemGateSession = {
                owner = mod, previous = previous, wrapper = wrapper,
            }
            return true
        end
  
        -- 2.6.59: Gen 2 Rare Candy -> current live level cap.
        -- Game2 owns Gen 2's party-item flow rather than the Gen 1 item.use
        -- hook, so wrap that exact owner.  The mutation itself is delegated to
        -- the shared RareCandyToCap transaction controller in main.lua.
        function G2.installRareCandyToCap()
            if not G2.isGen2() then return false end
            local ok, Game2 = pcall(require, "src.core.Game2")
            if not ok or type(Game2) ~= "table"
                or type(Game2.usePartyItem) ~= "function" then return false end
            local session = Game2.__nuzlockeRareCandyToCapSession
            if type(session) == "table" and session.owner == mod
                and Game2.usePartyItem == session.wrapper then return true end
            if type(session) == "table" and session.owner ~= mod
                and Game2.usePartyItem == session.wrapper
                and type(session.previous) == "function" then
                Game2.usePartyItem = session.previous
            end

            local previous = Game2.usePartyItem
            local wrapper
            wrapper = function(self, itemId, ...)
                local extraArgs = { ... }
                if tostring(itemId or "") ~= "RARE_CANDY" then
                    return previous(self, itemId,
                        unpackValues(extraArgs))
                end
                if mod.save:get("no_rare_candy_use", false) == true then
                    return previous(self, itemId,
                        unpackValues(extraArgs))
                end
                local RC = mod.exports.__beta26.RareCandyToCap
                if type(RC) ~= "table" or type(RC.plan) ~= "function"
                    or type(RC.step) ~= "function" then
                    return previous(self, itemId, ...)
                end
                local party = self.save and self.save.party or {}
                if #party == 0 then return previous(self, itemId, ...) end
                local Screens = require("src.ui.Screens")
                local TextBox = require("src.render.TextBox")
                Screens.push(self, "Gen2PartyMenu", {
                    prompt = "useItem",
                    onCancel = function() self.stack:pop() end,
                    onChoose = function(_, mon)
                        self.stack:pop()
                        local count, cap = RC.plan(self.save, mon)
                        if not cap then
                            -- No finite Nuzlocke cap: preserve vanilla one-candy
                            -- behavior by re-entering the untouched owner.
                            return previous(self, itemId,
                                unpackValues(extraArgs))
                        end
                        if count <= 0 then
                            self:say(Strings("The level cap blocks that RARE CANDY."))
                            return
                        end

                        local function nativeResultForLevel(level)
                            local def = self.data and self.data.pokemon
                                and self.data.pokemon[mon.species]
                            local learned = {}
                            for _, entry in ipairs(def and def.levelMoves or {}) do
                                if tonumber(entry.level) == tonumber(level) then
                                    learned[#learned + 1] = entry.move
                                end
                            end
                            local name = mon.nickname or mon.name
                                or (def and def.name) or mon.species or "POKEMON"
                            return {
                                used = true, level = level, learned = learned,
                                sfx = "Sfx_DexFanfare5079",
                                text = ("%s grew to\nlevel %d!"):format(name, level),
                            }
                        end

                        local function useOne(onDone)
                            local okStep, result = RC.step(self, mon, 2)
                            if not okStep then
                                self:say(Strings("Rare Candy batch stopped safely."))
                                return
                            end
                            result = type(result) == "table" and result
                                or nativeResultForLevel(mon.level)
                            self:say(result.text, function()
                                self:afterRareCandy(mon, result, onDone)
                            end, result.sfx and TextBox.soundOpts(
                                self, result.sfx) or nil)
                        end

                        local function continueBatch()
                            local remaining = RC.plan(self.save, mon)
                            if remaining <= 0 then return end
                            useOne(continueBatch)
                        end

                        if count <= 1 then
                            return useOne()
                        end
                        self.stack:push(TextBox.new(self,
                            Strings("Use %d RARE CANDIES?\nTarget: Lv.%d",
                                count, cap),
                            nil, { choice = function(yes)
                                if yes then continueBatch()
                                else useOne() end
                            end }))
                    end,
                })
            end
            Game2.usePartyItem = wrapper
            Game2.__nuzlockeRareCandyToCapSession = {
                owner = mod, previous = previous, wrapper = wrapper,
            }
            return true
        end

        function G2.installCatchTutorialSkip()
            if not G2.isGen2() then return false end
            local ok, World = pcall(require, "src.world.gen2.World")
            if not ok or type(World) ~= "table"
                or type(World.startCatchTutorial) ~= "function" then
                return false
            end
  
            local session = World.__nuzlockeCatchTutorialSkipSession
            if type(session) == "table" and session.owner == mod
                and World.startCatchTutorial == session.wrapper then return true end
            if type(session) == "table" and session.owner ~= mod
                and World.startCatchTutorial == session.wrapper
                and type(session.previous) == "function" then
                World.startCatchTutorial = session.previous
            end
  
            local previous = World.startCatchTutorial
            local wrapper = function(self, wild, battleType, onDone)
                local save = self and self.game and self.game.save
                if mod.exports.__beta26.skipCatchTutorialRequested(save) then
                    -- Vm's catchtutorial opcode performs StopAutoInput and the
                    -- mandatory map reload after this callback. The surrounding
                    -- Route 29 script then clears its scene and sets
                    -- EVENT_LEARNED_TO_CATCH_POKEMON exactly as vanilla does.
                    if onDone then onDone() end
                    return true
                end
                return previous(self, wild, battleType, onDone)
            end
            World.startCatchTutorial = wrapper
            World.__nuzlockeCatchTutorialSkipSession = {
                owner = mod, previous = previous, wrapper = wrapper,
            }
            return true
        end
  
        function G2.findNewPartyMon(before, party)
            for _, mon in ipairs(party or {}) do
                if not before[mon] then return mon end
            end
        end
  
        -- REVIEWED: Gold givepoke may place a successful acquisition directly
        -- into PC storage when the party is full. Treat party and boxes as the
        -- owned-Pokemon pool, while preferring party detection to preserve the
        -- established party-delivered path exactly.
        function G2.snapshotOwnedPokemon(save)
            local before = {}
            for _, mon in ipairs(save and save.party or {}) do before[mon] = true end
            mod.exports.__beta26.forEachExistingSaveBox(save, function(box)
                for _, mon in ipairs(box or {}) do before[mon] = true end
            end)
            return before
        end
  
        function G2.findNewOwnedPokemon(before, save)
            local mon = G2.findNewPartyMon(before, save and save.party)
            if mon then return mon, "party" end
            local found
            mod.exports.__beta26.forEachExistingSaveBox(save, function(box)
                for _, boxed in ipairs(box or {}) do
                    if not before[boxed] then
                        found = boxed
                        return false
                    end
                end
            end)
            if found then return found, "box" end
        end
  
        function G2.speciesKey(game, value)
            if value == nil then return "" end
            local raw = tostring(value):upper()
            if tonumber(value) and game and game.data
                and type(game.data.pokemon) == "table" then
                for id, def in pairs(game.data.pokemon) do
                    if type(def) == "table"
                        and tonumber(def.index) == tonumber(value) then
                        return tostring(id):upper()
                    end
                end
            end
            return raw
        end
  
        function G2.contextMapId(ctx, game)
            return tostring(
                (ctx and ctx.overworld and ctx.overworld.map
                    and ctx.overworld.map.id)
                or (ctx and (ctx.mapId or ctx.map))
                or (game and game.world and game.world.map and game.world.map.id)
                or (game and game.overworld and game.overworld.map
                    and game.overworld.map.id)
                or (game and game.save and game.save.player
                    and game.save.player.map)
                or ""):upper()
        end
  
        function G2.isElmLabContext(ctx, game)
            local mapId = G2.contextMapId(ctx, game)
            return mapId == "ELMS_LAB"
                or (mapId:find("ELM", 1, true) ~= nil
                    and mapId:find("LAB", 1, true) ~= nil)
        end
  
        -- Elm's three Poke Balls preview their vanilla species with POKEPIC and
        -- CRY before the eventual GIVEPOKE. 2.5.71 attempted to rewrite the
        -- script row itself, but runtime proved the visible Gen1Recomp 0.2.11
        -- presentation could still remain vanilla even while the native grant
        -- randomized correctly. The script layer therefore owns ONLY context:
        -- it resolves the deterministic choice and arms a one-command native
        -- presentation intent. Vm.new's copied hooks.showPic / hooks.cry wrappers
        -- below own the actual rendered portrait/cry and acknowledge what really
        -- reached the presentation callback. Generated script data stays immutable.
        function G2.rewriteRandomStarterPresentation(game, ctx, name, args, cmd)
            if not game or not randomStarterRuleEnabled(game) then return false end
            if name ~= "pokepic" and name ~= "cry" then return false end
            if not G2.isElmLabContext(ctx, game) then return false end
            local party = game.save and game.save.party or {}
            if #party ~= 0 then return false end

            local rawSpecies = (cmd and (cmd.species or cmd.id))
                or (type(args) == "table" and args[1])
            local original = G2.speciesKey(game, rawSpecies)
            if original ~= "CHIKORITA" and original ~= "CYNDAQUIL"
                and original ~= "TOTODILE" then return false end

            local choice = mod.exports.__beta26.selectRandomStarter(game, original)
            local def = game.data and game.data.pokemon
                and game.data.pokemon[choice]
            local index = type(def) == "table" and tonumber(def.index) or nil
            if not index then return false end

            local vmState = ctx and ctx.vm and G2._randomStarterVmStates
                and G2._randomStarterVmStates[ctx.vm] or nil
            if type(vmState) ~= "table" then return false end
            vmState.previewChoices = vmState.previewChoices or {}
            vmState.previewChoices[original] = choice
            vmState.pendingPresentation = {
                op = name, original = original, choice = choice,
                index = index, game = game,
            }
            return true
        end

        -- Gen 2-only NEW GAME QoL. Once the player says YES to the Guide Gent,
        -- the first .Yes text is GuideGentTourText1. Swallow the linear walking
        -- lesson from there through the command immediately before
        -- GuideGentGiftText, then resume the original script. That leaves the
        -- MAP CARD grant, ENGINE_MAP_CARD flag, final dialogue, object cleanup,
        -- and script ending fully vanilla-owned.
        G2._skipCherrygroveTourActive = false
        function G2.skipCherrygroveTourCommand(game, ctx, name, args, cmd)
            if not game or (externalRuleDelegation and externalRuleDelegation("skip_cherrygrove_tour", getCurrentGame() or mod.game)) or mod.save:get("skip_cherrygrove_tour", false) ~= true then
                G2._skipCherrygroveTourActive = false
                return false
            end
            local mapId = G2.contextMapId(ctx, game)
            if mapId ~= "CHERRYGROVE_CITY" then
                G2._skipCherrygroveTourActive = false
                return false
            end
  
            local textKey = tostring((cmd and cmd.text)
                or (type(args) == "table" and args[1]) or "")
            if not G2._skipCherrygroveTourActive then
                if name == "writetext"
                    and textKey:find("GuideGentTourText1", 1, true) then
                    G2._skipCherrygroveTourActive = true
                    return true
                end
                return false
            end
  
            if name == "writetext"
                and textKey:find("GuideGentGiftText", 1, true) then
                G2._skipCherrygroveTourActive = false
                return false
            end
  
            -- Fail open at the reward boundary even if a future extractor
            -- renames the GiftText key. None of these commands occurs during the
            -- walking lecture itself; promptbutton/getstring/scall/setflag begin
            -- the gift transaction. Never risk swallowing MAP CARD progression
            -- just because presentation metadata changed upstream.
            if name == "promptbutton" or name == "getstring"
                or name == "scall" or name == "setflag"
                or name == "end" or name == "endall" or name == "reloadend" then
                G2._skipCherrygroveTourActive = false
                return false
            end
            return true
        end
  
        -----------------------------------------------------------------
        -- 2.5.30 GOLD RANDOM STARTER TRANSACTION REPAIR
        --
        -- Runtime evidence from 2.5.22 shows Elm's starter remained vanilla
        -- with Random Starter ON even though the later nickname path worked.
        -- The old adapter tried to rewrite the script.command row before
        -- `givepoke`; keep that presentation/tracking layer, but no longer make
        -- the actual species grant depend on it. Gen1Recomp's Gen 2 VM calls
        -- the `hooks.givePoke` transaction for `givepoke`, so wrap Vm.new and
        -- replace only the first-party canonical Elm starter operand there.
        -- Native GivePoke still owns construction, OT/#DEX mutation, held item,
        -- and the built-in nickname flow.
        -----------------------------------------------------------------
        -- 2.5.51: keep the transaction-safe givePoke owner from 2.5.30,
        -- but restore the old adapter's strongest property: the script layer
        -- knows exactly which GIVEPOKE row is Elm's selected starter.  Each VM
        -- gets a private one-shot intent record; script.command arms it just
        -- before the native GIVEPOKE executes, and hooks.givePoke consumes it.
        -- No generated script row or shared operand table is mutated.
        G2._randomStarterVmStates = G2._randomStarterVmStates
            or setmetatable({}, { __mode = "k" })

        function G2.installRandomStarterTransaction()
            if not G2.isGen2() then return false end
            local okVm, Vm = pcall(require, "src.script.gen2.Vm")
            if not okVm or type(Vm) ~= "table"
                or type(Vm.new) ~= "function" then return false end

            return installOwnedMethodWrapper(
                Vm, "__nuzlockeRandomStarterTransactionSession2530", "new",
                function(previousNew)
                    return function(scripts, text, events, hooks, ...)
                        if type(hooks) ~= "table"
                            or type(hooks.givePoke) ~= "function" then
                            return previousNew(scripts, text, events, hooks, ...)
                        end

                        -- Do not mutate the World's shared hook table. Each VM
                        -- receives a shallow copy. The script hook below detects
                        -- Elm's exact preview/givepoke rows; these native callbacks
                        -- own what is actually rendered/granted.
                        local patched = {}
                        for key, value in pairs(hooks) do patched[key] = value end
                        local previousGive = hooks.givePoke
                        local previousShowPic = hooks.showPic
                        local previousCry = hooks.cry
                        local vmState = {
                            pendingElmStarter = nil,
                            pendingPresentation = nil,
                            previewChoices = {},
                            renderedPreviewChoices = {},
                            renderedCryChoices = {},
                        }
                        -- 2.5.79: native-callback fallback for Elm's three
                        -- starter previews. The preferred path remains the
                        -- script.command intent above, but runtime proved that
                        -- a missed/foreign wrapper in that seam could leave the
                        -- visible POKEPIC vanilla while the independent GIVEPOKE
                        -- transaction still randomized correctly. The native
                        -- callbacks have enough authoritative context to recover:
                        -- live Gen 2 game, Elm Lab map, empty party, and one of
                        -- the three canonical starter species. Resolve the same
                        -- deterministic choice directly here without mutating
                        -- generated script rows or consuming a second RNG result.
                        local function nativePreviewReplacement(speciesIndex, op)
                            local game = getCurrentGame() or mod.game
                            if not game or not randomStarterRuleEnabled(game) then
                                return nil
                            end
                            local mapId = ""
                            if type(hooks.mapId) == "function" then
                                local okMap, value = pcall(hooks.mapId)
                                if okMap then mapId = tostring(value or ""):upper() end
                            end
                            if mapId == "" then
                                mapId = G2.contextMapId(nil, game)
                            end
                            if mapId ~= "ELMS_LAB"
                                and not (mapId:find("ELM", 1, true)
                                    and mapId:find("LAB", 1, true)) then
                                return nil
                            end
                            local party = game.save and game.save.party or {}
                            if #party ~= 0 then return nil end
                            local original = G2.speciesKey(game, speciesIndex)
                            if original ~= "CHIKORITA" and original ~= "CYNDAQUIL"
                                and original ~= "TOTODILE" then return nil end
                            local choice = vmState.previewChoices[original]
                            if not randomStarterChoiceValid(game, choice) then
                                choice = mod.exports.__beta26.selectRandomStarter(
                                    game, original)
                            end
                            local def = game.data and game.data.pokemon
                                and game.data.pokemon[choice]
                            local index = type(def) == "table"
                                and tonumber(def.index) or nil
                            if not index then return nil end
                            vmState.previewChoices[original] = choice
                            vmState.lastPreviewSource = "native_fallback_" .. tostring(op)
                            return {
                                op = op, original = original, choice = choice,
                                index = index, game = game,
                            }
                        end

                        if type(previousShowPic) == "function" then
                            patched.showPic = function(speciesIndex, ...)
                                local pending = vmState.pendingPresentation
                                vmState.pendingPresentation = nil
                                if not (type(pending) == "table"
                                    and pending.op == "pokepic"
                                    and tonumber(pending.index)) then
                                    pending = nativePreviewReplacement(
                                        speciesIndex, "pokepic")
                                else
                                    vmState.lastPreviewSource = "script_intent_pokepic"
                                end
                                if type(pending) == "table"
                                    and tonumber(pending.index) then
                                    local result = previousShowPic(pending.index, ...)
                                    vmState.renderedPreviewChoices[pending.original] = pending.choice
                                    return result
                                end
                                vmState.lastPreviewSource = "vanilla_pokepic"
                                return previousShowPic(speciesIndex, ...)
                            end
                        end
                        if type(previousCry) == "function" then
                            patched.cry = function(speciesIndex, ...)
                                local pending = vmState.pendingPresentation
                                vmState.pendingPresentation = nil
                                if not (type(pending) == "table"
                                    and pending.op == "cry"
                                    and tonumber(pending.index)) then
                                    pending = nativePreviewReplacement(speciesIndex, "cry")
                                else
                                    vmState.lastPreviewSource = "script_intent_cry"
                                end
                                if type(pending) == "table"
                                    and tonumber(pending.index) then
                                    local result = previousCry(pending.index, ...)
                                    vmState.renderedCryChoices[pending.original] = pending.choice
                                    return result
                                end
                                vmState.lastPreviewSource = "vanilla_cry"
                                return previousCry(speciesIndex, ...)
                            end
                        end
                        patched.givePoke = function(speciesIndex, level, item, ...)
                            local pending = vmState.pendingElmStarter
                            -- The script.command seam already owns the exact
                            -- live Gen 2 game for this Elm transaction. Carry
                            -- that object through the one-shot intent instead
                            -- of rediscovering it from getCurrentGame() during early
                            -- NEW GAME, where the global can still be nil/stale.
                            local game = type(pending) == "table" and pending.game
                                or getCurrentGame() or mod.game
                            local save = game and game.save
                            local observedOriginal = G2.speciesKey(game, speciesIndex)
                            local starters = STARTERS_BY_VERSION.GOLD or {}
                            -- One GIVEPOKE consumes one intent even when another
                            -- mod has rewritten the concrete species operand.
                            vmState.pendingElmStarter = nil

                            local original = observedOriginal
                            local choice
                            local isElmStarter = false
                            if type(pending) == "table"
                                and pending.armed == true
                                and starters[tostring(pending.original or ""):upper()] == true then
                                original = tostring(pending.original):upper()
                                choice = tostring(pending.choice or ""):upper()
                                isElmStarter = true
                            else
                                -- Compatibility fallback for VMs/script hooks
                                -- created before the script-layer state map was
                                -- available. This preserves 2.5.30 behavior.
                                isElmStarter = G2.isGen2() and save
                                    and #(save.party or {}) == 0
                                    and starters[observedOriginal] == true
                            end

                            local grantIndex = speciesIndex
                            if isElmStarter and randomStarterRuleEnabled(game) then
                                -- A script-armed intent already owns the selected
                                -- species. Never reroll it here: preview -> intent ->
                                -- grant must remain one identity. Compatibility VMs
                                -- without an armed intent may still resolve once.
                                if not randomStarterChoiceValid(game, choice)
                                    and type(pending) ~= "table" then
                                    choice = mod.exports.__beta26.selectRandomStarter(
                                        game, original)
                                end
                                local def = game and game.data and game.data.pokemon
                                    and game.data.pokemon[choice]
                                local index = type(def) == "table"
                                    and tonumber(def.index) or nil
                                if index then grantIndex = index end
                            end

                            local mon = previousGive(grantIndex, level, item, ...)
                            if mon and isElmStarter
                                and randomStarterRuleEnabled(game) then
                                local actual = G2.speciesKey(
                                    game, mon.species or grantIndex)
                                if actual ~= "" then
                                    local expected = tostring(choice or ""):upper()
                                    mod.save:set("__nuzlocke_random_starter_preview_mismatch",
                                        expected ~= "" and actual ~= expected)
                                    mod.exports.__beta26.commitRandomStarter(
                                        game, original, actual)
                                    mod.exports.__beta26.StatRules.applyPlayer(
                                        game, mon)
                                    mod.exports.__beta26.registerStarterCatch(
                                        actual, mon)
                                end
                            end
                            return mon
                        end

                        local vm = previousNew(scripts, text, events, patched, ...)
                        if type(vm) == "table" then
                            G2._randomStarterVmStates[vm] = vmState
                        end
                        return vm
                    end
                end)
        end

        function G2.randomStarterTransactionHealth(game)
            game = game or getCurrentGame() or mod.game
            if not G2.isGen2(game) then
                return { state = "N/A", detail = "not Gen 2" }
            end
            local okVm, Vm = pcall(require, "src.script.gen2.Vm")
            local session = okVm and type(Vm) == "table"
                and Vm.__nuzlockeRandomStarterTransactionSession2530 or nil
            local healthy = type(session) == "table"
                and session.owner == mod
                and type(session.wrapper) == "function"
                and Vm.new == session.wrapper
            local previewSource = "none"
            if G2._randomStarterVmStates then
                for _, state in pairs(G2._randomStarterVmStates) do
                    if type(state) == "table" and state.lastPreviewSource then
                        previewSource = tostring(state.lastPreviewSource)
                    end
                end
            end
            local identity = mod.exports.__beta26.Dev
                and mod.exports.__beta26.Dev.editionContext
                and mod.exports.__beta26.Dev.editionContext(game) or nil
            return {
                state = healthy and "HEALTHY" or "MISSING",
                live = healthy == true,
                preview_source = previewSource,
                edition = identity and identity.edition or tostring(getGameVersion() or "unknown"):lower(),
                generation = 2,
                engine_family = "gen2",
                profile_scope = identity and identity.profile_scope or nil,
                adapter_id = "random_starter_transaction_gen2",
                detail = "Vm.new/givePoke/showPic/cry=" .. tostring(healthy == true)
                    .. " preview=" .. previewSource,
            }
        end
        mod.exports.__beta26.gen2RandomStarterTransactionHealth =
            G2.randomStarterTransactionHealth
        -- Historical private export retained for older diagnostics/tests.
        mod.exports.__beta26.goldRandomStarterTransactionHealth =
            mod.exports.__beta26.gen2RandomStarterTransactionHealth

        function G2.installGiftTracking()
            if G2._giftHook then return true end
            G2._giftHook = true
            mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
                if not (ctx and ctx.generation == 2 and G2.isGen2()) then
                    return next(ctx, name, args, cmd)
                end
  
                local game = (ctx and ctx.game) or getCurrentGame() or mod.game
                -- Presentation substitution is owned by the native VM callbacks
                -- installed above. This call only arms their one-command intent;
                -- the original generated script row is deliberately passed down.
                G2.rewriteRandomStarterPresentation(game, ctx, name, args, cmd)
                if G2.skipCherrygroveTourCommand(game, ctx, name, args, cmd) then
                    return nil
                end
                if name ~= "givepoke" then
                    return next(ctx, name, args, cmd)
                end
                local party = game and game.save and game.save.party or {}
                local beforeCount = #party
                local scriptedSpecies = (cmd and cmd.species)
                    or (type(args) == "table" and args[1]) or nil
                local upper = G2.speciesKey(game, scriptedSpecies)
                local isStarter = beforeCount == 0
                    and G2.isElmLabContext(ctx, game)
                    and (upper == "CHIKORITA" or upper == "CYNDAQUIL"
                        or upper == "TOTODILE")

                -- 2.5.51: arm the private VM transaction state from the exact
                -- Elm GIVEPOKE row. This ports the reliable identification from
                -- the older working adapter without reviving its shared-row
                -- mutation. The givePoke wrapper consumes this record once.
                local starterVmState = ctx and ctx.vm
                    and G2._randomStarterVmStates
                    and G2._randomStarterVmStates[ctx.vm] or nil
                local armedIntent
                if isStarter and randomStarterRuleEnabled(game)
                    and type(starterVmState) == "table" then
                    -- 2.5.71: once Elm has displayed a randomized species for
                    -- this exact ball, that preview is the immutable transaction
                    -- choice. Do not ask the randomizer for a second answer after
                    -- NEW GAME may have swapped mod.save backings. Only fall back
                    -- to selection when a compatibility path skipped presentation.
                    local rendered = starterVmState.renderedPreviewChoices
                        and starterVmState.renderedPreviewChoices[upper] or nil
                    local intended = starterVmState.previewChoices
                        and starterVmState.previewChoices[upper] or nil
                    local choice = randomStarterChoiceValid(game, rendered)
                        and tostring(rendered):upper()
                        or (randomStarterChoiceValid(game, intended)
                            and tostring(intended):upper()
                            or mod.exports.__beta26.selectRandomStarter(game, upper))
                    if randomStarterChoiceValid(game, choice) then
                        armedIntent = {
                            armed = true, original = upper, choice = choice,
                            previewChoice = rendered and tostring(rendered):upper() or nil,
                            game = game,
                        }
                        -- Diagnostics record ONLY a species acknowledged by the
                        -- native hooks.showPic callback. An intended-but-unrendered
                        -- preview must never be allowed to produce a false PASS.
                        mod.save:set("__nuzlocke_random_starter_selected_preview",
                            rendered and tostring(rendered):upper() or nil)
                        mod.save:set("__nuzlocke_random_starter_preview_mismatch",
                            rendered == nil)
                        starterVmState.pendingElmStarter = armedIntent
                    end
                end

                -- 2.5.35: do NOT rewrite GIVEPOKE's shared VM row here.
                -- Elm's presentation has its own copied-row rewrite above,
                -- while the 2.5.30 Vm.new/hooks.givePoke wrapper is the sole
                -- owner of the concrete starter species transaction. Mutating
                -- cmd/args here contaminated generated script data across later
                -- New Games in the same process and could stop a future vanilla
                -- starter row from being recognized as an Elm transaction.
                local area = areaKey(game, nil)
                    or (ctx and (ctx.mapId or ctx.map)) or "UNKNOWN"
  
                -- Gold's givepoke command is transactional just like Gen 1's
                -- give_pokemon seam. Enforce legality BEFORE the script mutates
                -- party/story state. Starters remain their own mandatory path.
                if not isStarter then
                    local denied = specialAcquisitionDenied(
                        game, upper, area, "gift")
                    if denied then
                        ctx.lastCheck = false
                        showRuleMessage(ctx,
                            acquisitionDeniedMessage("gift", denied, area))
                        return
                    end
                end
  
                local before = G2.snapshotOwnedPokemon(game and game.save)
                local result = next(ctx, name, args, cmd)
                -- If another hook swallowed/replaced GIVEPOKE without reaching
                -- the native transaction, do not let this intent leak into a
                -- later unrelated gift. A real givePoke call already consumed
                -- it before returning here.
                if armedIntent and type(starterVmState) == "table"
                    and starterVmState.pendingElmStarter == armedIntent then
                    starterVmState.pendingElmStarter = nil
                end
                local mon = G2.findNewOwnedPokemon(before, game and game.save)
                if not mon then return result end
  
                mod.exports.__beta26.StatRules.applyPlayer(game, mon)
                local species = mon.species or scriptedSpecies
                -- Gold can expose species as its numeric Gen 2 index. Resolve
                -- it before registration so Catch Info/Tracker always get the
                -- symbolic species id used by the rest of Nuzlocke state.
                local actualUpper = G2.speciesKey(game, species)
                if isStarter then
                    mod.exports.__beta26.commitRandomStarter(
                        game, upper, actualUpper)
                    mod.exports.__beta26.registerStarterCatch(actualUpper, mon)
                else
                    mod.exports.__beta26.registerSpecialCatch(actualUpper, area, "gift", mon)
                end
                G2.requireGiftNickname(game, mon, ctx and ctx.vm)
                mod.exports.__beta26.syncHistoryNickname(mon)
                return result
            end)
            return true
        end
  
        -- Gold native NPC trades run through Gen2 TradeMenu/NpcTrade rather
        -- than script.command. Gate the selection before TradeMenu marks the
        -- one-shot trade flag, then register the received mon at the transaction
        -- seam after NpcTrade.perform succeeds. Both patches compose around the
        -- currently installed method and are idempotent/load-order tolerant.
        function G2.installTradeGate()
            if not G2.isGen2() then return false end
            local okMenu, TradeMenu = pcall(require, "src.ui.gen2.TradeMenu")
            local okTrade, NpcTrade = pcall(require, "src.core.gen2.NpcTrade")
            if not okMenu or not okTrade or type(TradeMenu) ~= "table"
                or type(TradeMenu.chose) ~= "function"
                or type(NpcTrade) ~= "table" or type(NpcTrade.perform) ~= "function" then
                return false
            end
  
            local menuSession = TradeMenu.__nuzlockeTradeGateSession
            if not (type(menuSession) == "table" and menuSession.owner == mod
                and TradeMenu.chose == menuSession.wrapper) then
                if type(menuSession) == "table" and menuSession.owner ~= mod
                    and TradeMenu.chose == menuSession.wrapper
                    and type(menuSession.previous) == "function" then
                    TradeMenu.chose = menuSession.previous
                end
                local previous = TradeMenu.chose
                local wrapper
                wrapper = function(self, index)
                    local game = self and self.game or getCurrentGame() or mod.game
                    local row = self and self.row
                    if active(game, nil) and type(row) == "table" then
                        local species = tostring(row.get or ""):upper()
                        local area = areaKey(game, nil) or "UNKNOWN"
                        local denied = specialAcquisitionDenied(
                            game, species, area, "trade")
                        if denied then
                            local message = acquisitionDeniedMessage(
                                "trade", denied, area)
                            if type(self.sayRaw) == "function" then
                                self:sayRaw(message, nil, function() self:close() end)
                            else
                                -- A future TradeMenu without sayRaw should fail
                                -- closed for this transaction, but never mark the
                                -- native one-shot flag or remove the outgoing mon.
                                self.message = {
                                    pages = { { tostring(message) } }, page = 1,
                                    onDone = function() if self.close then self:close() end end,
                                }
                            end
                            return
                        end
                    end
                    return previous(self, index)
                end
                TradeMenu.chose = wrapper
                TradeMenu.__nuzlockeTradeGateSession = {
                    owner = mod, previous = previous, wrapper = wrapper,
                }
            end
  
            local performSession = NpcTrade.__nuzlockeTradeTrackingSession
            if not (type(performSession) == "table" and performSession.owner == mod
                and NpcTrade.perform == performSession.wrapper) then
                if type(performSession) == "table" and performSession.owner ~= mod
                    and NpcTrade.perform == performSession.wrapper
                    and type(performSession.previous) == "function" then
                    NpcTrade.perform = performSession.previous
                end
                local previous = NpcTrade.perform
                local wrapper
                wrapper = function(data, save, row, index)
                    local given, received = previous(data, save, row, index)
                    local game = getCurrentGame() or mod.game
                    if received and active(game, nil) then
                        mod.exports.__beta26.StatRules.applyPlayer(game, received)
                        local species = tostring(received.species
                            or (type(row) == "table" and row.get) or ""):upper()
                        local area = areaKey(game, nil) or "UNKNOWN"
                        mod.exports.__beta26.registerSpecialCatch(species, area, "trade", received)
                        mod.exports.__beta26.syncHistoryNickname(received)
                    end
                    return given, received
                end
                NpcTrade.perform = wrapper
                NpcTrade.__nuzlockeTradeTrackingSession = {
                    owner = mod, previous = previous, wrapper = wrapper,
                }
            end
            return true
        end
  
        function G2.installStaticTracking()
            if G2._staticHook then return true end
            G2._staticHook = true
            mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
                if ctx and ctx.generation == 2 and G2.isGen2() then
                    if name == "loadwildmon" then
                        mod.exports.__beta26.pendingStaticEncounter = {
                            generation = 2,
                            species = (cmd and cmd.species)
                                or (type(args) == "table" and args[1]),
                        }
                    elseif name == "randomwildmon" or name == "loadtrainer"
                        or name == "loadtemptrainer" then
                        mod.exports.__beta26.pendingStaticEncounter = nil
                    end
                end
                return next(ctx, name, args, cmd)
            end)
            return true
        end
  
        function G2.installGamblingGate()
            if not G2.isGen2() then return false end
            local ok, Specials = pcall(require, "src.script.gen2.Specials")
            if not ok or type(Specials) ~= "table"
                or type(Specials.HANDLERS) ~= "table"
                or type(Specials.ALL) ~= "table" then return false end
            local session = Specials.__nuzlockeGamblingSession
            local sessionLive = type(session) == "table" and session.owner == mod
                and type(session.methods) == "table"
                and next(session.methods) ~= nil
            if sessionLive then
                for name, rec in pairs(session.methods or {}) do
                    if type(rec) ~= "table"
                        or (rec.wrapperHandlers and Specials.HANDLERS[name]
                            ~= rec.wrapperHandlers)
                        or (rec.wrapperAll and Specials.ALL[name] ~= rec.wrapperAll) then
                        sessionLive = false
                        break
                    end
                end
            end
            if sessionLive then return true end
            if type(session) == "table" then
                for name, rec in pairs(session.methods or {}) do
                    if type(rec) == "table" then
                        -- beta.27.15 stored one shared wrapper/previous pair.
                        -- Accept that legacy session shape during an in-process
                        -- upgrade, then record independent slots below.
                        local oldHandlersWrapper = rec.wrapperHandlers or rec.wrapper
                        local oldHandlersPrevious = rec.previousHandlers or rec.previous
                        local oldAllWrapper = rec.wrapperAll or rec.wrapper
                        local oldAllPrevious = rec.previousAll or rec.previous
                        if Specials.HANDLERS[name] == oldHandlersWrapper
                            and type(oldHandlersPrevious) == "function" then
                            Specials.HANDLERS[name] = oldHandlersPrevious
                        end
                        if Specials.ALL[name] == oldAllWrapper
                            and type(oldAllPrevious) == "function" then
                            Specials.ALL[name] = oldAllPrevious
                        end
                    end
                end
            end
  
            -- Gold and post-game Kanto prize vendors announce their coin-case
            -- balance immediately before opening the prize menu. The coin clerk
            -- uses DisplayMoneyAndCoinBalance instead, so ending only this exact
            -- map/special combination blocks redemption without blocking coin
            -- purchases or unrelated Game Corner dialogue.
            if not G2._gamblingScriptHook then
                G2._gamblingScriptHook = true
                mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
                    if ctx and ctx.generation == 2 and name == "special"
                        and mod.exports.__beta26.ruleActive(
                            getCurrentGame() or mod.game, "no_gambling") then
                        local vm = ctx.vm
                        local specialId = cmd and (cmd.special or cmd.id)
                            or (type(args) == "table" and args[1])
                        local specialName = vm and type(vm.specialName) == "function"
                            and vm:specialName(specialId) or nil
                        local mapId = tostring(ctx.mapId or ""):upper()
                        if specialName == "DisplayCoinCaseBalance"
                            and (mapId == mod.exports.__beta26.gameCornerMapIds.gscGoldenrod
                                or mapId == mod.exports.__beta26.gameCornerMapIds.gscCeladonPrizeRoom) then
                            if vm and type(vm.showRaw) == "function" then
                                vm:showRaw(mod.exports.__beta26.worldRuleText(
                                    getCurrentGame() or mod.game, "no_gambling"))
                            end
                            return "end"
                        end
                    end
                    return next(ctx, name, args, cmd)
                end)
            end
  
            local methods = {}
            for _, name in ipairs({ "SlotMachine", "CardFlip" }) do
                local previousHandlers = Specials.HANDLERS[name]
                local previousAll = Specials.ALL[name]
                local function wrap(previous)
                    if type(previous) ~= "function" then return nil end
                    return function(vm)
                        local game = getCurrentGame() or mod.game
                        if mod.exports.__beta26.ruleActive(game, "no_gambling") then
                            if vm and type(vm.showRaw) == "function" then
                                vm:showRaw(mod.exports.__beta26.worldRuleText(
                                    game, "no_gambling"))
                            end
                            return
                        end
                        return previous(vm)
                    end
                end
                local wrapperHandlers = wrap(previousHandlers)
                local wrapperAll = wrap(previousAll)
                if wrapperHandlers then Specials.HANDLERS[name] = wrapperHandlers end
                if wrapperAll then Specials.ALL[name] = wrapperAll end
                if wrapperHandlers or wrapperAll then
                    methods[name] = {
                        previousHandlers = previousHandlers,
                        wrapperHandlers = wrapperHandlers,
                        previousAll = previousAll,
                        wrapperAll = wrapperAll,
                    }
                end
            end
            Specials.__nuzlockeGamblingSession = { owner = mod, methods = methods }
            return true
        end
  
        -----------------------------------------------------------------
        -- GOLD WHITEOUT / BLACKOUT CONSEQUENCE
        --
        -- G2.onFaint classifies the full wipe. Survivable Whiteout keeps Gold's
        -- native finish/onDone blackout warp; destructive Blackout suppresses only
        -- that overworld callback while retaining native screen cleanup, then owns
        -- the Nuzlocke run-ending flow.
        -----------------------------------------------------------------
        function G2.installWhiteoutGate()
            if not G2.isGen2() then return false end
            local okBS, BS = pcall(require, "src.ui.gen2.BattleState")
            if not okBS or type(BS) ~= "table"
                or type(BS.finishBattle) ~= "function" then
                return false
            end
            local installed = installOwnedMethodWrapper(
                BS, "__nuzlockeGoldWhiteoutSession29315",
                "finishBattle", function(vanillaFinishBattle)
                    return function(self, ...)
                local battle = self and self.battle
                if battle and battle.nuzlockeWhiteoutSurvives == true
                    and not battle.nuzlockeGameOver then
                    local counts = battle.nuzlockeWhiteoutRecoveryCounts
                    battle.nuzlockeWhiteoutSurvives = nil
                    battle.nuzlockeWhiteoutRecoveryCounts = nil
                    local results = { vanillaFinishBattle(self, ...) }
                    recordRunBlackout(self and self.game, "battle")
                    pcall(mod.exports.__beta26.showWhiteoutRecoveryMessage,
                        self and self.game, counts)
                    return unpackValues(results)
                end
                if not (battle and battle.nuzlockeGameOver) then
                    return vanillaFinishBattle(self, ...)
                end
  
                battle.nuzlockeGameOver = nil
                battle.nuzlockeRunEnded = true
                battle.outcome = "lose"
                if self then self.nuzlockeRunEnded = true end
  
                -- The native World onDone("lose") heals, halves money and warps
                -- home. Suppress only that callback while retaining Gen 2's own
                -- finishBattle cleanup: stopAlarm, cursor cleanup and volatile
                -- teardown.
                local savedOnDone = self.onDone
                self.onDone = nil
                local finishOk, finishErr = pcall(vanillaFinishBattle, self, ...)
                self.onDone = savedOnDone
  
                local game = self and self.game
                local world = game and game.world
                if world then
                    world.battleActive = nil
                    world.lastBattleResult = 1
                end
  
                -- With onDone suppressed the battle screen is still on the
                -- stack. Pop exactly this screen; never pop an unrelated one.
              if game and game.stack and game.stack.top
                  and game.stack:top() == self then
                  pcall(function() game.stack:pop() end)
              end

  
              local function showCreditsAndTitle()
                    local okScreens, Screens = pcall(require, "src.ui.Screens")
                    if okScreens and Screens and game and game.stack then
                        local ending = Screens.push(game, "Gen2Credits", function()
                            local musicOk, Music = pcall(require, "src.core.Music")
                            if musicOk and Music then Music.stop() end
                            while game.stack:top() do game.stack:pop() end
                            if game.makeTitleState then
                                game.stack:push(game:makeTitleState())
                            end
                        end)
                        if ending then ending.phase, ending.timer = "end_wait", 0 end
                    end
                end
  
                local function deleteCurrentRunSave()
                    local okSave, SaveData = pcall(require, "src.core.SaveData")
                    if not okSave or not SaveData then
                        return false, "SaveData unavailable"
                    end
  
                    local version = game and game.save and game.save.version or nil
                    local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
                    if okVersion and GameVersion
                        and type(GameVersion.get) == "function" then
                        local okGet, detected = pcall(GameVersion.get)
                        if okGet and detected ~= nil then version = detected end
                    end
                    if version == nil then
                        return false, "game version unavailable"
                    end
  
                    local mainName
                    if type(SaveData.saveFilename) == "function" then
                        local okName, value = pcall(SaveData.saveFilename, version)
                        if okName and type(value) == "string" and value ~= "" then
                            mainName = value
                        end
                    end
  
                    local slot
                    if type(SaveData.activeSlot) == "function" then
                        local okSlot, value = pcall(SaveData.activeSlot, version)
                        if okSlot then slot = value end
                    end
  
                    local deleted = false
                    local detail
                    if slot and type(SaveData.deleteSlot) == "function" then
                        local okDelete, result, err =
                            pcall(SaveData.deleteSlot, version, slot)
                        if okDelete and result == true then
                            deleted = true
                        else
                            detail = tostring(err or result or "slot delete failed")
                        end
                    end
  
                    if mainName and type(SaveData.persistenceFs) == "function" then
                        local okFs, fs = pcall(SaveData.persistenceFs)
                        if okFs and fs and type(fs.remove) == "function" then
                            pcall(fs.remove, mainName)
                            pcall(fs.remove, mainName .. ".bak")
                            pcall(fs.remove, mainName .. ".tmp")
                            if type(fs.getInfo) == "function" then
                                local okInfo, info = pcall(fs.getInfo, mainName)
                                if okInfo and info == nil then deleted = true end
                            elseif not slot then
                                deleted = true
                            end
                        end
                    end
                    return deleted, detail
                end
  
                local function deleteSaveAndShowTitle()
                    local deleted, deleteError = deleteCurrentRunSave()
                    if not deleted then
                        local okText, TextBox = pcall(require, "src.render.TextBox")
                        if okText and TextBox and game and game.stack then
                            local message = Strings("SAVE DELETE FAILED.\nThis Nuzlocke run is over.\nDelete the save manually.")
                            if deleteError and deleteError ~= "" then
                                message = message .. "\n" .. tostring(deleteError)
                            end
                            game.stack:push(TextBox.new(game, message,
                                function() showCreditsAndTitle() end))
                            return
                        end
                    end
                    showCreditsAndTitle()
                end
  
                if not finishOk then
                    -- We still own the run-ending consequence if Gen 2 cleanup
                    -- changes under us; surface the cleanup failure only through
                    -- the diagnostic save-delete failure path rather than
                    -- invoking Gold's normal heal/warp callback.
                    battle.nuzlockeWhiteoutFinishError = tostring(finishErr or "finishBattle failed")
                end
  
                if worldTier(game) < 3 then
                    local okText, TextBox = pcall(require, "src.render.TextBox")
                    if okText and TextBox and game and game.stack then
                        game.stack:push(TextBox.new(game,
                            mod.exports.__beta26.worldRuleText(
                                game, "blackout"),
                            function() deleteSaveAndShowTitle() end))
                        return
                    end
                end
  
                if worldTier(game) >= 3 then
                    local losses = tonumber(mod.save:get("nuzlocke_losses", 0)) or 0
                    local catches = countTrackerCatches()
                    local badges = game and game.save and currentBadgeCount(game.save) or 0
                    local last = mod.save:get("last_loss", {}) or {}
                    local lastName = tostring(last.name or "NONE")
                    local lastLoc = routeName(last.location or "UNKNOWN")
                    local summary = Strings("NUZLOCKE OVER\nBADGES: %d\nCAUGHT: %d  DEATHS: %d\nLAST DEATH: %s\n%s",
                        badges, catches, losses, lastName, lastLoc)
                    if mod.exports.__beta26.pushWorldText(game, summary,
                        function() deleteSaveAndShowTitle() end) then
                        return
                    end
                end
  
                deleteSaveAndShowTitle()
                    end
                end)
            BS.__nuzlockeBeta266Whiteout = true -- historical marker only
            return installed
        end
  
        -- Gold's starter family. The actual acquisition hook above deliberately
        -- identifies the first party member instead of trusting Elm's Lab map id.
        STARTERS_BY_VERSION.GOLD = {
            CHIKORITA = true, CYNDAQUIL = true, TOTODILE = true,
        }
        -- Silver uses the same Johto starter trio. Keep the edition key
        -- explicit so generic starter provenance/diagnostics never fall back
        -- to Red simply because the mechanics are shared with Gold.
        STARTERS_BY_VERSION.SILVER = STARTERS_BY_VERSION.GOLD
  
        -- Keep the starter slot region-correct. R/B/Y retain PALLET_TOWN exactly.
        local beta21RegisterStarterCatch = mod.exports.__beta26.registerStarterCatch
        mod.exports.__beta26.registerStarterCatch = function(species, mon)
            if not G2.isGen2() then return beta21RegisterStarterCatch(species, mon) end
            if not species then return false end
            local game = getCurrentGame() or mod.game
            species = G2.speciesKey(game, species)
            local area = "NEW_BARK_TOWN"
            registerArea(area, "New Bark Town")
            markVisited(area)
  
            -- Do not use caughtAreas()[NEW_BARK_TOWN] as an early return.
            -- 29.3.12 runtime proved the area ledger and concrete Tracker/Catch
            -- Info provenance can become desynchronised. The identity-aware
            -- registration path is idempotent and also hydrates the concrete mon.
            local ok = mod.exports.__beta26.registerSpecialCatch(species, area, "starter", mon)
            if mon then
                mon.catchLocation = area
                mon.encounterType = "starter"
                mon.nuzlockeTrackerRegistered = true
                Identity.setPokemonOrigin(mon, "NORMAL")
                Identity.baselineAdd(mon, "NORMAL")
                local monId = Identity.ensurePokemonIdentity(
                    mon, game and game.save or getCurrentSave(), "NORMAL")
                if monId ~= nil then
                    mod.save:set("__nuzlocke_starter_pokemon_id", monId)
                end
                mod.save:set("__nuzlocke_starter_species", species)
            end
            return ok
        end
  
        -----------------------------------------------------------------
        -- 2.2.21 QUICK NUZLOCKE START
        --
        -- This is intentionally a one-shot fresh-save reconciliation, not a
        -- permanent story override. It waits for the native world to exist so
        -- Gold's InitializeEventsScript can seed its event bitfield first, then
        -- advances only the mandatory pre-capture milestones. Optional catches,
        -- Route 22, Guide Gent, Route 29 tutorial, Mom banking, etc. remain live.
        -- R/B/Y runtime testing confirms the transition may land outside the house
        -- before bedroom-PC pickup; the house remains accessible, so those items
        -- are intentionally recoverable by walking back inside rather than being
        -- force-granted or moving the checkpoint deeper into fragile intro code.
        -----------------------------------------------------------------
        mod.exports.__beta26.applyQuickNuzlockeStart = function(game)
            if saveBlocked() then return false end
            game = game or getCurrentGame() or mod.game
            local save = game and game.save
            if not (game and save and save.nuzlockeQuickStartPending == true) then
                return false
            end

            local delegated = externalRuleDelegation
                and externalRuleDelegation("quick_nuzlocke_start", game)
            if delegated then
                -- The provider owns the whole transaction. Do not leave a local
                -- one-shot marker that could fire later if that provider unloads.
                save.nuzlockeQuickStartPending = nil
                save.nuzlockeQuickStartBallCount = nil
                save.nuzlockeQuickStartDelegated = delegated.id
                    or delegated.name or true
                return false
            end

            -- Do not reconcile while Oak/InitClock/player naming is still on
            -- top of the world. Quick Start's intro adapter/default-name path
            -- finishes those semantic writes first.
            local player = save.player or {}
            local gold = G2.isGen2(game)
            if not tostring(player.name or ""):find("%S") then return false end
            if not gold and not tostring(player.rival or ""):find("%S") then
                return false
            end

            local world = game.world
            if gold then
                if not (world and world.events and world.mapScenes) then return false end
                local okFlags, FlagNames = pcall(require, "src.core.gen2.FlagNames")
                if not okFlags or type(FlagNames) ~= "table"
                    or type(FlagNames.events) ~= "table"
                    or type(FlagNames.engine) ~= "table" then
                    save.nuzlockeQuickStartError = "Gold flag registry unavailable"
                    return false
                end
                local initialized = FlagNames.events.EVENT_INITIALIZED_EVENTS
                if initialized and type(world.events.get) == "function"
                    and world.events:get(initialized) ~= true then
                    -- Preserve Gold's native first-map event initialization.
                    return false
                end
            elseif not (save.flags and type(save.flags) == "table") then
                return false
            end

            local function canonicalAnchor()
                local list
                if gold then
                    list = { "CHIKORITA", "CYNDAQUIL", "TOTODILE" }
                elseif getGameVersion() == "YELLOW" then
                    list = { "PIKACHU" }
                else
                    list = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" }
                end
                -- When our Random Starter owns the mechanic, the selected
                -- canonical ball is only the story anchor; the seeded selector
                -- below supplies the actual species and already enforces rules.
                local randomOwned = mod.save:get("random_starter", false) == true
                    and not (externalRuleDelegation
                        and externalRuleDelegation("random_starter", game))
                if randomOwned then return list[1] end
                for _, candidate in ipairs(list) do
                    local typeOk = not mod.exports.__beta26.typeLockAllowsSpecies
                        or mod.exports.__beta26.typeLockAllowsSpecies(game, candidate)
                    local denied = type(specialAcquisitionDenied) == "function"
                        and specialAcquisitionDenied(game, candidate, nil, "starter")
                        or nil
                    if typeOk and denied == nil then return candidate end
                end
                return list[1]
            end

            local function makeStarter(anchor)
                local party = save.party or {}
                save.party = party
                if type(party[1]) == "table" then
                    return party[1], tostring(party[1].species or anchor):upper()
                end
                local actual = mod.exports.__beta26.selectRandomStarter(game, anchor)
                actual = tostring(actual or anchor):upper()
                local mon
                if gold then
                    local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
                    if not okMon or type(Mon) ~= "table"
                        or type(Mon.new) ~= "function" then
                        return nil, nil, "Gold Pokemon constructor unavailable"
                    end
                    mon = Mon.new(game.data, actual, 5, {
                        item = "BERRY", happiness = 120,
                    })
                    if mon and type(Mon.stampOT) == "function" then
                        Mon.stampOT(save, mon)
                    end
                else
                    local okPokemon, Pokemon = pcall(require, "src.pokemon.Pokemon")
                    if not okPokemon or type(Pokemon) ~= "table"
                        or type(Pokemon.new) ~= "function" then
                        return nil, nil, "Gen1 Pokemon constructor unavailable"
                    end
                    local okNew, built = pcall(Pokemon.new, game.data, actual, 5)
                    if okNew then mon = built end
                end
                if not mon then return nil, nil, "starter construction failed" end
                if mod.exports.__beta26.StatRules
                    and type(mod.exports.__beta26.StatRules.applyPlayer) == "function" then
                    pcall(mod.exports.__beta26.StatRules.applyPlayer, game, mon)
                end
                party[1] = mon
                mod.exports.__beta26.commitRandomStarter(game, anchor, actual)
                return mon, actual
            end

            local function addBagItem(itemId, amount)
                amount = math.max(0, math.floor(tonumber(amount) or 0))
                if amount <= 0 then return true end
                local okBag, Bag = pcall(require, "src.inventory.Bag")
                if okBag and type(Bag) == "table" and type(Bag.add) == "function" then
                    local ok, added = pcall(Bag.add, save, itemId, amount, game.data)
                    if ok and added ~= false then return true end
                end
                -- Fresh-save fallback for compatibility harnesses that expose
                -- a reduced Bag model. Runtime engine builds should use Bag.add.
                save.inventory = save.inventory or {}
                save.inventory[itemId] = math.max(0,
                    math.floor(tonumber(save.inventory[itemId]) or 0)) + amount
                return true
            end

            local function setObject(mapId, objectId, visible)
                save.objectToggles = save.objectToggles or {}
                save.objectToggles[mapId] = save.objectToggles[mapId] or {}
                save.objectToggles[mapId][objectId] = visible and true or false
            end

            local function registerDex(mon, species)
                save.pokedex = save.pokedex or {}
                save.pokedex.seen = save.pokedex.seen or {}
                save.pokedex.seen[species] = true
                if gold then
                    save.pokedex.caught = save.pokedex.caught or {}
                    save.pokedex.caught[species] = true
                else
                    save.pokedex.owned = save.pokedex.owned or {}
                    save.pokedex.owned[species] = true
                end
                mod.exports.__beta26.registerStarterCatch(species, mon)
                if mod.exports.__beta26.cleanupStarterDuplicate then
                    pcall(mod.exports.__beta26.cleanupStarterDuplicate)
                end
            end

            if save.nuzlockeQuickStartCoreApplied ~= true then
                local anchor = canonicalAnchor()
                local mon, actual, createErr = makeStarter(anchor)
                if not mon then
                    save.nuzlockeQuickStartError = tostring(createErr or "starter unavailable")
                    return false
                end
                save.nuzlockeQuickStartStarterAnchor = anchor
                save.nuzlockeQuickStartStarterSpecies = actual
                registerDex(mon, actual)

                if not gold then
                    local f = save.flags
                    for _, flag in ipairs({
                        "EVENT_FOLLOWED_OAK_INTO_LAB",
                        "EVENT_FOLLOWED_OAK_INTO_LAB_2",
                        "EVENT_OAK_ASKED_TO_CHOOSE_MON",
                        "EVENT_GOT_STARTER",
                        "EVENT_BATTLED_RIVAL_IN_OAKS_LAB",
                        "EVENT_GOT_POKEDEX",
                        "EVENT_OAK_GOT_PARCEL",
                        "EVENT_1ST_ROUTE22_RIVAL_BATTLE",
                        "EVENT_ROUTE22_RIVAL_WANTS_BATTLE",
                        "EVENT_GOT_POKEBALLS_FROM_OAK",
                    }) do f[flag] = true end
                    f.EVENT_2ND_ROUTE22_RIVAL_BATTLE = false
                    f["EVENT_CHOSE_" .. anchor] = true

                    -- Mirror the object changes made by Oak's escort/starter/
                    -- Pokedex scripts so revisiting the skipped maps looks like
                    -- the story point the flags represent.
                    setObject("PALLET_TOWN", "PALLETTOWN_OAK", false)
                    setObject("OAKS_LAB", "OAKSLAB_OAK2", false)
                    setObject("OAKS_LAB", "OAKSLAB_OAK1", true)
                    setObject("OAKS_LAB", "OAKSLAB_RIVAL", false)
                    setObject("OAKS_LAB", "OAKSLAB_POKEDEX1", false)
                    setObject("OAKS_LAB", "OAKSLAB_POKEDEX2", false)
                    if getGameVersion() == "YELLOW" then
                        setObject("OAKS_LAB", "OAKSLAB_EEVEE_POKE_BALL", false)
                        save.rivalStarter = tonumber(save.rivalStarter) or 1
                        save.pikachuInBall = false
                        save.pikachuHappiness = tonumber(save.pikachuHappiness) or 90
                        save.pikachuMood = tonumber(save.pikachuMood) or 128
                        setObject("VIRIDIAN_CITY", "VIRIDIANCITY_OLD_MAN_SLEEPY", false)
                        setObject("VIRIDIAN_CITY", "VIRIDIANCITY_OLD_MAN2", true)
                    else
                        local rivalBall = {
                            BULBASAUR = "OAKSLAB_CHARMANDER_POKE_BALL",
                            CHARMANDER = "OAKSLAB_SQUIRTLE_POKE_BALL",
                            SQUIRTLE = "OAKSLAB_BULBASAUR_POKE_BALL",
                        }
                        setObject("OAKS_LAB", "OAKSLAB_" .. anchor .. "_POKE_BALL", false)
                        if rivalBall[anchor] then
                            setObject("OAKS_LAB", rivalBall[anchor], false)
                        end
                        setObject("VIRIDIAN_CITY", "VIRIDIANCITY_OLD_MAN_SLEEPY", false)
                        setObject("VIRIDIAN_CITY", "VIRIDIANCITY_OLD_MAN", true)
                    end
                    setObject("ROUTE_22", "ROUTE22_RIVAL1", true)
                    if save.inventory then save.inventory.OAKS_PARCEL = nil end

                    local balls = math.max(5, math.min(99,
                        math.floor(tonumber(save.nuzlockeQuickStartBallCount) or 5)))
                    addBagItem("POKE_BALL", balls)
                    -- This transaction supersedes Soft Start's delayed PC grant;
                    -- never pay the same configured starting Balls twice.
                    save.nuzlockeDeferredStartingBalls = nil
                else
                    local FlagNames = require("src.core.gen2.FlagNames")
                    local function event(name, value)
                        local id = FlagNames.events[name]
                        if not id then error("missing Gold event flag " .. tostring(name)) end
                        world.events:set(id, value ~= false)
                    end
                    local function engine(name, value)
                        local id = FlagNames.engine[name]
                        if not id then error("missing Gold engine flag " .. tostring(name)) end
                        if type(world.setEngineFlag) == "function" then
                            world:setEngineFlag(id, value ~= false)
                        else
                            save.engineFlags = save.engineFlags or {}
                            save.engineFlags[id] = value ~= false
                        end
                    end
                    local function scene(mapId, value)
                        world.mapScenes[mapId] = value
                        save.mapScenes = save.mapScenes or {}
                        save.mapScenes[mapId] = value
                    end

                    -- Mom / Pokegear mandatory opening state.
                    engine("ENGINE_POKEGEAR", true)
                    engine("ENGINE_PHONE_CARD", true)
                    engine("ENGINE_POKEDEX", true)
                    event("EVENT_PLAYERS_HOUSE_MOM_1", true)
                    event("EVENT_PLAYERS_HOUSE_MOM_2", false)

                    local okPhone, Phone = pcall(require, "src.core.gen2.Phone")
                    if okPhone and type(Phone) == "table"
                        and type(Phone.addContact) == "function" then
                        pcall(Phone.addContact, save, Phone.PHONECONTACT_MOM or 1)
                        pcall(Phone.addContact, save, Phone.PHONECONTACT_ELM or 4)
                    end
                    -- Mom normally asks for the weekday during the mandatory
                    -- opening. Quick Start removes that prompt, so anchor it to
                    -- the host's current weekday instead of leaving a half-set
                    -- clock after Oak's retained hour/minute setup.
                    local okClock, Clock = pcall(require, "src.core.gen2.Clock")
                    if okClock and type(Clock) == "table"
                        and type(Clock.setWeekday) == "function" then
                        local day = type(Clock.hostWeekday) == "function"
                            and Clock.hostWeekday() or 0
                        pcall(Clock.setWeekday, save, day)
                    end

                    -- Elm starter transaction. The chosen canonical ball remains
                    -- the story anchor even if our seeded Random Starter changes
                    -- the concrete Pokemon received from it.
                    event("EVENT_GOT_A_POKEMON_FROM_ELM", true)
                    event("EVENT_GOT_" .. anchor .. "_FROM_ELM", true)
                    event("EVENT_" .. anchor .. "_POKEBALL_IN_ELMS_LAB", true)
                    local stolen = {
                        CHIKORITA = "CYNDAQUIL",
                        CYNDAQUIL = "TOTODILE",
                        TOTODILE = "CHIKORITA",
                    }
                    event("EVENT_" .. stolen[anchor] .. "_POKEBALL_IN_ELMS_LAB", true)

                    -- Mr. Pokemon / Oak / theft call / can-lose Cherrygrove rival.
                    event("EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON", true)
                    event("EVENT_MR_POKEMONS_HOUSE_OAK", true)
                    event("EVENT_RIVAL_NEW_BARK_TOWN", true)
                    event("EVENT_ELM_CALLED_ABOUT_STOLEN_POKEMON", true)
                    event("EVENT_COP_IN_ELMS_LAB", true)
                    event("EVENT_RIVAL_CHERRYGROVE_CITY", true)

                    -- Returning the egg to Elm is the native Poke Ball unlock.
                    event("EVENT_GAVE_MYSTERY_EGG_TO_ELM", true)
                    event("EVENT_ROUTE_30_BATTLE", true)
                    event("EVENT_ROUTE_30_YOUNGSTER_JOEY", false)
                    scene("PLAYERS_HOUSE_1F", 1)
                    scene("NEW_BARK_TOWN", 1)
                    scene("MR_POKEMONS_HOUSE", 1)
                    scene("CHERRYGROVE_CITY", 0)
                    scene("ELMS_LAB", 2)
                    scene("ROUTE_29", 1) -- SCENE_ROUTE29_CATCH_TUTORIAL

                    -- The aide Potion is unavoidable on the first Elm-lab exit;
                    -- the 5 Balls are the precise post-egg-return unlock point.
                    addBagItem("POTION", 1)
                    addBagItem("POKE_BALL", 5)
                    if save.inventory then save.inventory.MYSTERY_EGG = nil end
                    save.rival = save.rival or {}
                    if type(save.rival) == "table" then
                        save.rival.name = getGameVersion() == "SILVER" and "GOLD" or "SILVER"
                    end
                    -- Mr. Pokemon's house executes `blackoutmod
                    -- CHERRYGROVE_CITY` before this native checkpoint. Preserve
                    -- that whiteout destination until the player later enters a
                    -- Pokemon Center, where Gen1Recomp updates it normally.
                    save.blackoutMap = "CHERRYGROVE_CITY"
                end

                if mod.exports.__beta26.armEncounterRulesNow then
                    mod.exports.__beta26.armEncounterRulesNow(game)
                end
                save.nuzlockeQuickStartCoreApplied = true
                save.nuzlockeQuickStartError = nil
            end

            local starter = save.party and save.party[1]
            local nicknameRequired = mod.save:get("nickname_rule", defaultRuleValue("nickname_rule")) == true
                and type(starter) == "table"
                and (not tostring(starter.nickname or ""):find("%S")
                    or tostring(starter.nickname or ""):upper()
                        == tostring(starter.species or ""):upper())
            if nicknameRequired then
                starter.nuzlockeNeedsNickname = true
                starter.nuzlockeNicknameRequired = true
                if save.nuzlockeQuickStartNicknamePrompt ~= true then
                    local okScreens, Screens = pcall(require, "src.ui.Screens")
                    if not okScreens or type(Screens) ~= "table"
                        or type(Screens.push) ~= "function" then
                        save.nuzlockeQuickStartError = "nickname screen unavailable"
                        return false
                    end
                    save.nuzlockeQuickStartNicknamePrompt = true
                    local function done(name)
                        save.nuzlockeQuickStartNicknamePrompt = nil
                        name = tostring(name or "")
                        if name:find("%S") then
                            starter.nickname = name
                            starter.nuzlockeNeedsNickname = nil
                            starter.nuzlockeNicknameRequired = nil
                            if mod.exports.__beta26.syncHistoryNickname then
                                pcall(mod.exports.__beta26.syncHistoryNickname, starter)
                            end
                        end
                    end
                    if gold then
                        Screens.push(game, "Gen2NamingScreen", {
                            type = "nickname",
                            prompt = Strings("NICKNAME?"),
                            monName = (game.data.pokemon[starter.species] or {}).name
                                or starter.species,
                            onDone = done,
                            onCancel = function()
                                save.nuzlockeQuickStartNicknamePrompt = nil
                            end,
                        })
                    else
                        Screens.push(game, "NamingScreen", {
                            title = Strings("NICKNAME?"), maxLen = 10,
                            onDone = done,
                        })
                    end
                end
                return false
            end

            save.nuzlockeQuickStartNicknamePrompt = nil

            -- The target is the hometown exit immediately before the first
            -- capture-enabled route. Do not clear the one-shot request until
            -- the supported World API actually accepts the warp; if a future
            -- engine/map rename rejects it, the reconciled save remains
            -- retryable instead of being silently stranded at the bedroom.
            if not (mod.world and type(mod.world.warpTo) == "function") then
                save.nuzlockeQuickStartError = "world warp API unavailable"
                return false
            end
            local okWarp, warped, warpErr
            if gold then
                okWarp, warped, warpErr = pcall(
                    mod.world.warpTo, mod.world, "NEW_BARK_TOWN", 13, 6, "left")
            else
                okWarp, warped, warpErr = pcall(
                    mod.world.warpTo, mod.world, "PALLET_TOWN", 5, 6, "down")
            end
            if not okWarp or warped ~= true then
                save.nuzlockeQuickStartError = tostring(warpErr
                    or (okWarp and "quick-start warp rejected" or warped))
                return false
            end

            save.nuzlockeQuickStartPending = nil
            save.nuzlockeQuickStartBallCount = nil
            save.nuzlockeQuickStartApplied = true
            save.nuzlockeQuickStartError = nil
            return true
        end

        mod.events:on("world.stepped", function()
            local game = getCurrentGame() or mod.game
            local save = game and game.save
            if save and save.nuzlockeQuickStartPending == true then
                local ok, err = pcall(mod.exports.__beta26.applyQuickNuzlockeStart, game)
                if not ok then
                    save.nuzlockeQuickStartError = tostring(err)
                end
            end
        end)

        -- Narrow repair for the 29.3.12/29.3.13 Gold runtime failure: a
        -- randomized starter could be granted successfully while New Bark had no
        -- tracker row and the mon still displayed UNKNOWN. Repair only when the
        -- persisted random roll identifies exactly one owned candidate and the
        -- run still has zero tracked catches, so a later naturally-caught match
        -- can never be guessed into the starter slot.
        function G2.reconcileRandomStarterProvenance(game)
            if saveBlocked() then return false end
            game = game or getCurrentGame() or mod.game
            if not (game and G2.isGen2() and game.save) then return false end
            local choice = tostring(mod.save:get(
                "__nuzlocke_random_starter_choice", "") or ""):upper()
            if choice == "" then return false end
  
            local area = "NEW_BARK_TOWN"
            local existing = trackerLog()[area]
            if type(existing) == "table" and #existing > 0 then
                local matches = {}
                for _, owned in ipairs(Identity.allCurrentMons(game.save)) do
                    if type(owned) == "table"
                        and G2.speciesKey(game, owned.species) == choice then
                        matches[#matches + 1] = owned
                    end
                end
                if #matches == 1 then
                    mod.exports.__beta26.registerSpecialCatch(choice, area, "starter", matches[1])
                    return true
                end
                return false
            end
  
            if countTrackerCatches() ~= 0 then return false end
            local candidates = {}
            for _, owned in ipairs(Identity.allCurrentMons(game.save)) do
                if type(owned) == "table"
                    and G2.speciesKey(game, owned.species) == choice then
                    local where = tostring(owned.catchLocation or ""):upper()
                    if where == "" or where == "UNKNOWN" then
                        candidates[#candidates + 1] = owned
                    end
                end
            end
            if #candidates ~= 1 then return false end
            return mod.exports.__beta26.registerStarterCatch(choice, candidates[1]) == true
        end
  
        -- Gold's tracker is discovery-driven. Do not preload the Gen 1 Kanto
        -- checklist into a Johto run; show only areas the Gold save has actually
        -- visited or registered through encounters/gifts.
        local beta21DisplayRoutes = getDisplayRoutes
        getDisplayRoutes = function(game)
            if not G2.isGen2() then return beta21DisplayRoutes(game) end
            syncCurrentArea(game)
            local seen = visitedAreas()
            local caught = caughtAreas()
            local log = trackerLog()
            local list = {}
            for _, r in ipairs(ALL_ROUTES) do
                if (seen[r.id] or caught[r.id] ~= nil or (type(log[r.id]) == "table" and #log[r.id] > 0))
                    and areaAllowedByConfig(r) then
                    list[#list + 1] = r
                end
            end
            table.sort(list, function(a, b)
                return tostring(a.name or a.id) < tostring(b.name or b.id)
            end)
            return list
        end
  
  
        -----------------------------------------------------------------
        -- GOLD TRAINER CARD STATUS PAGE
        --
        -- Preserve Gold's native three-page card and expose the Nuzlocke status
        -- page behind SELECT. A/left/right remain owned by the native card.
        -----------------------------------------------------------------
        function G2.clipStatusLabel(textValue, pixelBudget)
            local textOut = tostring(textValue or "")
            local okFont, Font = pcall(require, "src.render.Font")
            if not okFont or type(Font) ~= "table"
                or type(Font.width) ~= "function"
                or Font.width(textOut) <= pixelBudget then
                return textOut
            end
            if type(Font.split) == "function"
                and type(Font.spansFitting) == "function" then
                local spans = Font.split(textOut)
                local count = Font.spansFitting(spans, pixelBudget)
                local span = count and count > 0 and spans[count] or nil
                if span and span.to then return textOut:sub(1, span.to) end
            end
            -- Failing open is safer than splitting a translated UTF-8 glyph.
            return textOut
        end

        function G2.ruleNames()
            local names = {}
            if mod.save:get("nuzlocke_enabled", true) ~= true then
                return { Strings("Nuzlocke OFF") }
            end
            local lockeType = math.max(0, math.min(6,
                math.floor(tonumber(mod.save:get("locke_type",
                    defaultRuleValue("locke_type")))
                    or defaultRuleValue("locke_type"))))
            if lockeType > 0 then
                names[#names + 1] = Strings("Loadout %s",
                    Strings(LockePreset.names[lockeType] or "CUSTOM"))
            end
  
            local function truthy(value)
                if value == true then return true end
                if type(value) == "number" then return value ~= 0 end
                if type(value) == "string" then
                    local v = value:lower()
                    return v == "true" or v == "on" or v == "yes" or tonumber(v) == 1
                end
                return false
            end
  
            for _, cat in ipairs(ruleCategories) do
                for _, rule in ipairs(cat.rules) do
                    -- NUZ STATUS mirrors the reduced, enforceable Gen 2 rule
                    -- surface. Setup-only values and utility/service controls
                    -- belong in Setup/NUZ RULES, not on the live challenge card.
                    -- Never display stale Gen 1-only values from a shared profile.
                    local value = (rule.setupOnly ~= true
                        and rule.key ~= "infinite_rare_candies"
                        and mod.exports.__beta26.gen2BetaRules[rule.key])
                        and getConfigValue(rule.key, false) or nil
                    local label
                    if value == nil then
                        label = nil
                    elseif rule.key == "nuzlocke_enabled" then
                        label = nil
                    elseif rule.key == "encounter_spend_indicator"
                          or rule.key == "dev_mode" or rule.key == "catch_info"
                        or rule.key == "stat_info" or rule.key == "move_info"
                        or rule.key == "area_guide_enabled" then
                        label = nil
                    elseif rule.key == "world_building_tier" then
                        local tier = tonumber(value) or 0
                        if tier > 0 then
                            label = Strings("World %s", Strings(
                                ({ [1]="TIER 1", [2]="TIER 2", [3]="TIER 3" })[tier]))
                        end
                    elseif rule.key == "level_cap_scope" then
                        local rawScope = mod.save:get("level_cap_scope", nil)
                        local scope = rawScope == nil and legacyLevelCapScope()
                            or (tonumber(rawScope) or 0)
                        if scope > 0 then
                            label = Strings("Level Caps %s", Strings(
                                ({ [1]="GYMS", [2]="E4", [3]="CHAMP", [4]="POST" })[scope]))
                        end
                    elseif rule.key == "dupes_mode" then
                        local mode = tonumber(value) or 0
                        if mode == 1 then label = Strings("Dupes SPEC")
                        elseif mode == 2 then label = Strings("Dupes FAM") end
                    elseif rule.key == "evolution_limit" then
                        local mode = tonumber(value) or 0
                        if mode == 1 then label = Strings("No Final Evo")
                        elseif mode == 2 then label = Strings("No Evolution") end
                    elseif rule.key == "party_size_limit" then
                        local limit = tonumber(value) or 6
                        if limit < 6 then label = Strings("Party Limit %d", limit) end
                    elseif rule.key == "travel_restrictions" then
                        local mode = tonumber(value) or 0
                        if mode == 1 then label = Strings("No Fly")
                        elseif mode == 2 then label = Strings("No Fly+Teleport") end
                    elseif rule.key == "automatic_running_shoes" then
                        local mode = mod.exports.__beta26.movementAssistMode(value)
                        if mode > 0 then label = Strings("Run %s", Strings(
                            mod.exports.__beta26.movementAssistLabel(mode))) end
                    elseif rule.key == "fast_surf" then
                        local mode = mod.exports.__beta26.movementAssistMode(value)
                        if mode > 0 then label = Strings("Surf %s", Strings(
                            mod.exports.__beta26.movementAssistLabel(mode))) end
                    elseif rule.key == "shiny_clause" then
                        local mode = tonumber(value) or 0
                        if mode == 4 then
                            label = Strings("Shiny UNLIMITED")
                        elseif mode > 0 then
                            local used = math.max(0, math.floor(tonumber(mod.save:get("shiny_clause_used", 0)) or 0))
                            label = Strings("Shiny %d/%d", math.max(0, mode - used), mode)
                        end
                    elseif rule.key == "encounter_ball_limit" then
                        local limit = mod.exports.__beta26.encounterBallLimitValues[
                            tonumber(value) or 0] or 0
                        if limit > 0 then label = Strings("Ball Limit %d", limit) end
                    elseif rule.key == "type_lock_mode" then
                        local mode = math.max(0, math.min(6, tonumber(value) or 0))
                        if mode > 0 then
                            if getConfigValue("type_lock_draft", false) == true then
                                local filled, needed, complete = mod.exports.__beta26.typeLockDraftStatus()
                                label = complete and Strings("%s %d Types", mod.exports.__beta26.typeLockModeLabel(mode), mode) or Strings("%s Draft %d/%d", mod.exports.__beta26.typeLockModeLabel(mode), filled, needed)
                            else
                                local names={}
                                for i=1,mode do names[#names+1]=Strings(mod.exports.__beta26.typeLockTypeLabel(getConfigValue(mod.exports.__beta26.typeLockSlotKey(i), false))) end
                                label = mode <= 3 and Strings("%s %s", mod.exports.__beta26.typeLockModeLabel(mode), table.concat(names,"/")) or Strings("%s %d Types", mod.exports.__beta26.typeLockModeLabel(mode), mode)
                            end
                        end
                    elseif rule.key == "type_lock_draft" or rule.key == "type_lock_primary" or rule.key == "type_lock_secondary" or rule.key == "type_lock_tertiary" or rule.key == "type_lock_quaternary" or rule.key == "type_lock_quinary" or rule.key == "type_lock_senary" then
                        label = nil
                    elseif rule.key == "difficulty_profile" then
                        local selectedId = tostring(mod.save:get("difficulty_provider_id", "vanilla") or "vanilla")
                        local selected
                        for _, option in ipairs(mod.exports.__beta26.difficultyOptions() or {}) do
                            if tostring(option.id or "") == selectedId then selected = option; break end
                        end
                        if selected and tostring(selected.id or "vanilla") ~= "vanilla" then
                            label = Strings("Difficulty %s", Strings(selected.name or selected.id or "CUSTOM"))
                        end
                    elseif rule.key == "route_forgiveness" then
                        if (tonumber(value) or 0) > 0 then
                            label = Strings("Forgive Tokens %d",
                                mod.exports.__beta26.TrainerRewards.forgivenessTokens())
                        end
                    elseif rule.key == "no_catching" then
                        if value == true then label = Strings("No Catching") end
                    elseif rule.key == "player_start_stat_exp" or rule.key == "wild_start_stat_exp"
                        or rule.key == "trainer_start_stat_exp" then
                        local mode = tonumber(value) or 0
                        if mode > 0 then
                            label = Strings("%s %s", Strings(rule.name), Strings(
                                mod.exports.__beta26.statExpPresetLabels[mode] or "0%"))
                        end
                    elseif rule.key == "trainer_money_multiplier" then
                        local mode = tonumber(value) or 4
                        if mode ~= 4 then
                            label = Strings("Trainer Money %s", Strings(
                                mod.exports.__beta26.trainerMoneyPresetLabels[mode]
                                    or Strings.source("100%")))
                        end
                    elseif rule.key == "maximum_bst" then
                        local limit = tonumber(value) or 0
                        if limit > 0 then label = Strings("Max BST %d", limit) end
                    elseif rule.key == "randomizer_seed" then
                        local starterOwned = mod.save:get("random_starter", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game))
                        local encountersOwned = mod.save:get("random_encounter_tables", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", getCurrentGame() or mod.game))
                        local fieldItemsOwned = mod.save:get("random_field_items", false) == true
                        local learnsetsOwned = mod.save:get("random_learnsets", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_learnsets", getCurrentGame() or mod.game))
                        local seed = type(mod.exports.__beta26.randomizerSeed) == "function"
                            and tonumber(mod.exports.__beta26.randomizerSeed(nil, false))
                            or tonumber(value) or 0
                        if (starterOwned or encountersOwned or fieldItemsOwned or learnsetsOwned) and seed > 0 then
                            label = Strings("RNG %08d v%d", seed, mod.exports.__beta26.randomizerAlgorithmVersion())
                        end
                    elseif rule.key == "random_starter_style" then
                        if mod.save:get("random_starter", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) then
                            label = Strings("Starter %s", ({ [0]="ANY", [1]="3-STAGE", [2]="BASE", [3]="SIM BST" })[tonumber(value) or 0] or "ANY")
                        end
                    elseif rule.key == "random_starter_balance" then
                        if mod.save:get("random_starter", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) then
                            label = tonumber(value) == 1 and Strings("Starter BALANCED") or Strings("Starter INDEPENDENT")
                        end
                    elseif rule.key == "random_starter_trio_typing" then
                        if mod.save:get("random_starter", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_starter", getCurrentGame() or mod.game)) then
                            label = tonumber(value) == 1 and Strings("Trio AUTO") or Strings("Trio OFF")
                        end
                    elseif rule.key == "random_field_item_balance" then
                        if mod.save:get("random_field_items", false) == true then
                            label = Strings("Items %s", ({ [0]="CHAOS", [1]="CATEGORY", [2]="BALANCED" })[tonumber(value) or 0] or "CHAOS")
                        end
                    elseif rule.key == "random_field_item_repetition" then
                        if mod.save:get("random_field_items", false) == true then
                            label = Strings("ItemRep %s", ({ [0]="ALLOW", [1]="DIVERSE", [2]="UNIQUE" })[tonumber(value) or 0] or "ALLOW")
                        end
                    elseif rule.key == "random_encounter_balance" then
                        if mod.save:get("random_encounter_tables", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", getCurrentGame() or mod.game)) then
                            label = Strings("Enc %s", ({ [0]="CHAOS", [1]="SIM BST", [2]="EVO", [3]="BALANCED" })[tonumber(value) or 0] or "CHAOS")
                        end
                    elseif rule.key == "random_encounter_repetition" then
                        if mod.save:get("random_encounter_tables", false) == true
                            and not (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", getCurrentGame() or mod.game)) then
                            label = Strings("Repeats %s", ({ [0]="ALLOW", [1]="DIVERSE", [2]="UNIQUE" })[tonumber(value) or 0] or "ALLOW")
                        end
                    elseif rule.key == "random_encounter_diversity_strength" then
                        if mod.save:get("random_encounter_tables", false) == true
                            and tonumber(mod.save:get("random_encounter_repetition", 0)) == 1
                            and not (externalRuleDelegation and externalRuleDelegation("random_encounter_tables", getCurrentGame() or mod.game)) then
                            label = Strings("Diversity %s", ({ [0]="LIGHT", [1]="STANDARD", [2]="STRONG" })[tonumber(value) or 1] or "STANDARD")
                        end
                    elseif rule.key == "randomizer_info_policy" then
                        if mod.save:get("random_encounter_tables", false) == true
                            or mod.save:get("random_starter", false) == true then
                            label = tonumber(value) == 1 and Strings("RNG BLIND") or Strings("RNG OPEN")
                        end
                    elseif rule.key == "gold_egg_encounter_mode" then
                        local mode = tonumber(value) or 0
                        if mode > 0 then
                            label = Strings("Egg %s",
                                ({ [1]="RECEIVED", [2]="HATCHED", [3]="GIFT" })[mode]
                                    or "RECEIVED")
                        end
                    elseif rule.key == "gold_bug_contest_mode" then
                        local mode = tonumber(value) or 0
                        if mode > 0 then
                            label = Strings("Contest %s",
                                ({ [1]="EXEMPT", [2]="SLOT" })[mode]
                                    or "EXEMPT")
                        end
                    elseif rule.numeric then
                        if (tonumber(value) or 0) > 0 then
                            label = Strings(rule.shortName or rule.name)
                        end
                    elseif truthy(value) then
                        label = Strings(rule.shortName or rule.name)
                    end
                    if label then names[#names + 1] = label end
                end
            end
            return names
        end
  
        -----------------------------------------------------------------
        -- GEN 2 NUZ STATUS SCREEN
        --
        -- Gold/Silver's native Trainer Card has its own multi-page lifecycle. Instead
        -- of replacing/patching that engine screen, use the shared START-menu
        -- hook plus the shared screens registry. This is both more compatible
        -- with other mods and visible on the current Gen 2 UI.
        -----------------------------------------------------------------
        mod.content.screens:register("NuzlockeGoldStatusScreen", {
            new = function(game, ctx)
                local self = {
                    game = game,
                    isOpaque = true,
                    ruleScroll = 0,
                }
  
                function self:update(dt)
                    local input = self.game and self.game.input
                    if not input then return end
                    local names = G2.ruleNames()
                    local visible = 3
                    local maxScroll = math.max(0, #names - visible)
                    if input:wasPressed("down") then
                        self.ruleScroll = math.min(maxScroll, (self.ruleScroll or 0) + 1)
                    elseif input:wasPressed("up") then
                        self.ruleScroll = math.max(0, (self.ruleScroll or 0) - 1)
                    elseif input:wasPressed("a") then
                        pushNuzlockeRunHistoryViewer(self.game)
                    elseif input:wasPressed("b") or input:wasPressed("start") then
                        if self.game and self.game.stack then self.game.stack:pop() end
                    end
                end
  
                function self:draw()
                    local Chrome = require("src.ui.gen2.Chrome")
                    Chrome.clear()
                    Chrome.box(0, 0, 20, 18)
                    Chrome.print(Strings("NUZ STATUS "
                        .. mod.exports.__beta26.Dev.gameLabel(self.game)), 2, 1)
  
                    local caught = countTrackerCatches()
                    local deaths = tonumber(mod.save:get("nuzlocke_losses", 0)) or 0
                    local lost = 0
                    local states = mod.save:get("encounter_states", {})
                    if type(states) == "table" then
                        for key, state in pairs(states) do
                            if key ~= "__LEGACY__" and type(state) == "table"
                                and state.status == "FAILED" then
                                lost = lost + 1
                            end
                        end
                    end
                    local cap = nextLevelCap(self.game and self.game.save)
                    local tokens = nuzStatusTokenBalance()
                    local areaLabel, areaStatus = nuzStatusEncounterSnapshot(self.game)
                    local lastEvent = nuzStatusLastHistoryEvent(self.game)
                    local function clip18(text)
                        text = tostring(text or "")
                        return #text > 18 and text:sub(1, 18) or text
                    end
  
                    Chrome.print(clip18(("C%d L%d D%d T%d"):format(
                        caught, lost, deaths, tokens)), 2, 3)
                    Chrome.print(clip18(cap >= 100 and "CAP MAX"
                        or ("CAP LV%d"):format(cap)), 2, 4)
                    Chrome.print(clip18("AREA " .. tostring(areaLabel)), 2, 5)
                    Chrome.print(clip18("STATE " .. tostring(areaStatus)), 2, 6)
                    Chrome.print(clip18("LAST " .. tostring(lastEvent)), 2, 7)
                    Chrome.print(Strings("RULES"), 2, 9)
  
                    local names = G2.ruleNames()
                    local visible = 3
                    local maxScroll = math.max(0, #names - visible)
                    self.ruleScroll = math.max(0, math.min(self.ruleScroll or 0, maxScroll))
                    if #names == 0 then
                        Chrome.print(Strings("No rules active"), 2, 13)
                    else
                        for row = 1, visible do
                            local label = names[self.ruleScroll + row]
                            if not label then break end
                            label = tostring(label)
                            label = G2.clipStatusLabel(label, 16 * 8)
                            Chrome.print(label, 2, 9 + row * 1)
                        end
                    end
                    if self.ruleScroll > 0 then Chrome.cursor(18, 10, true) end
                    if self.ruleScroll + visible < #names then
                        local Font = require("src.render.Font")
                        Font.drawCode(Chrome.DOWN_ARROW, 18 * 8, 13 * 8)
                    end
                    Chrome.print(Strings("A:HIST B:EXIT"), 2, 16)
                end

                -- 2.5.66: Silver uses the same Gen 2 status screen as Gold, but
                -- edition-specific save/provider shapes are still beta surfaces.
                -- Contain the entire screen so a status-only calculation can never
                -- take down the launcher. The first failure is retained in Dev
                -- diagnostics and rendered on this same native Gen 2 surface.
                do
                    local rawUpdate, rawDraw = self.update, self.draw
                    local failure = nil
                    local function remember(phase, err)
                        if failure then return end
                        local detail = tostring(err or "unknown status error")
                        local Dev = mod.exports.__beta26.Dev
                        local code = Dev and type(Dev.errorCode) == "function"
                            and Dev.errorCode("g2_status_" .. tostring(phase), detail) or nil
                        failure = { phase = tostring(phase), detail = detail, code = code }
                        mod.exports.__beta26.lastStatusScreenError =
                            failure.phase .. ": " .. detail
                        if Dev and type(Dev.recordError) == "function" then
                            pcall(Dev.recordError, "g2_status_" .. failure.phase,
                                detail, self.game)
                        end
                    end
                    self.update = function(...)
                        if failure then
                            local input = self.game and self.game.input
                            if input and (input:wasPressed("a") or input:wasPressed("b")
                                or input:wasPressed("start")) then
                                if self.game and self.game.stack then
                                    pcall(function() self.game.stack:pop() end)
                                end
                            end
                            return
                        end
                        local args = { ... }
                        local ok, result = xpcall(function()
                            return rawUpdate(unpackValues(args))
                        end, debug and debug.traceback or tostring)
                        if not ok then remember("update", result); return end
                        return result
                    end
                    self.draw = function(...)
                        if not failure then
                            local args = { ... }
                            local ok, result = xpcall(function()
                                return rawDraw(unpackValues(args))
                            end, debug and debug.traceback or tostring)
                            if ok then return result end
                            remember("draw", result)
                        end
                        pcall(function()
                            local Chrome = require("src.ui.gen2.Chrome")
                            Chrome.clear(); Chrome.box(0, 0, 20, 18)
                            Chrome.print(Strings("NUZ STATUS ERROR"), 2, 1)
                            local detail = tostring(failure and failure.detail or "unknown")
                            detail = detail:gsub("^.-:%s*", "")
                            if #detail > 72 then detail = detail:sub(1, 72) .. "..." end
                            Chrome.printWrapped(detail, 2, 4, 16, 6)
                            if failure and failure.code then
                                Chrome.printWrapped(tostring(failure.code), 2, 11, 16, 3)
                            end
                            Chrome.print(Strings("A/B:BACK"), 5, 16)
                        end)
                    end
                end
  
                return self
            end,
        })
  
        -- Read-only Gold rule-label surface for optional presentation providers.
        mod.exports.__beta26.goldPokegearRuleNames = function()
            return G2.ruleNames()
        end

        -- Historical Trainer Card adapter retained for source comparison only.
        -- beta.27.5 no longer installs it; Gold status now uses the public START
        -- menu hook and dedicated screen above.
        function G2.installTrainerCard()
            if not G2.isGen2() then return false end
            local okCard, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")
            local okChrome, Chrome = pcall(require, "src.ui.gen2.Chrome")
            if not okCard or not okChrome or type(TrainerCard) ~= "table"
                or type(TrainerCard.new) ~= "function"
                or type(TrainerCard.update) ~= "function"
                or type(TrainerCard.drawPanel) ~= "function" then
                return false
            end
            if TrainerCard.__nuzlockeGoldStatusInstalled then return true end
            TrainerCard.__nuzlockeGoldStatusInstalled = true
  
            local vanillaNew = TrainerCard.new
            local vanillaUpdate = TrainerCard.update
            local vanillaDrawPanel = TrainerCard.drawPanel
  
            TrainerCard.new = function(game, opts)
                local self = vanillaNew(game, opts)
                self.nuzlockeStatusPage = false
                self.nuzlockeRuleScroll = 0
                return self
            end
  
            TrainerCard.update = function(self, dt)
                local input = self and self.game and self.game.input
                if input and input:wasPressed("select") then
                    self.nuzlockeStatusPage = not self.nuzlockeStatusPage
                    self.nuzlockeRuleScroll = 0
                    return
                end
                if self and self.nuzlockeStatusPage then
                    local names = G2.ruleNames()
                    local visible = 6
                    local maxScroll = math.max(0, #names - visible)
                    if input and input:wasPressed("down") then
                        self.nuzlockeRuleScroll = math.min(maxScroll,
                            (self.nuzlockeRuleScroll or 0) + 1)
                    elseif input and input:wasPressed("up") then
                        self.nuzlockeRuleScroll = math.max(0,
                            (self.nuzlockeRuleScroll or 0) - 1)
                    elseif input and (input:wasPressed("b") or input:wasPressed("start")) then
                        return vanillaUpdate(self, dt)
                    end
                    return
                end
                return vanillaUpdate(self, dt)
            end
  
            TrainerCard.drawPanel = function(self)
                if not (self and self.nuzlockeStatusPage) then
                    return vanillaDrawPanel(self)
                end
                Chrome.clear()
                Chrome.box(0, 0, 20, 18)
                Chrome.print(Strings("NUZLOCKE STATUS"), 2, 1)
                local profile = mod.exports.__beta26.getGameProfile()
                Chrome.print(Strings((profile and profile.region) or "JOHTO"), 2, 3)
  
                local names = G2.ruleNames()
                local visible = 6
                local scroll = math.max(0, math.min(
                    self.nuzlockeRuleScroll or 0, math.max(0, #names - visible)))
                if #names == 0 then
                    Chrome.print(Strings("No rules active"), 2, 6)
                else
                    for row = 1, visible do
                        local name = names[scroll + row]
                        if not name then break end
                        local label = tostring(name)
                        label = G2.clipStatusLabel(label, 16 * 8)
                        Chrome.print(label, 2, 4 + row * 2)
                    end
                end
                if scroll > 0 then Chrome.print(Strings("^"), 18, 5) end
                if scroll + visible < #names then Chrome.print(Strings("v"), 18, 15) end
                Chrome.print(Strings("SEL:CARD"), 2, 16)
                Chrome.print(Strings("B:EXIT"), 12, 16)
            end
            return true
        end
  
        -----------------------------------------------------------------
        -- GEN 2 BREEDING / EGG PROVENANCE
        --
        -- These events record where an egg was created and hatched without
        -- inventing a new Egg Clause or consuming an encounter slot by itself.
        -----------------------------------------------------------------
        function G2.onEggCreated(ev)
            if not G2.isGen2() or not ev or not ev.egg then return end
            local game = getCurrentGame() or mod.game
            local resolvedArea = areaKey(game, nil)
            local area = resolvedArea or "UNKNOWN"
            if resolvedArea then
                registerArea(resolvedArea)
                markVisited(resolvedArea)
            end
  
            ev.egg.nuzlockeOrigin = "EGG"
            ev.egg.eggCreatedLocation = area
            ev.egg.eggCompatibility = ev.compatibility
  
            local records = mod.save:get("g2_egg_provenance", {})
            if type(records) ~= "table" then records = {} end
            records[#records + 1] = {
                status = "CREATED",
                area = area,
                mother = ev.mother and ev.mother.species or nil,
                father = ev.father and ev.father.species or nil,
                compatibility = ev.compatibility,
                stepsToEgg = ev.stepsToEgg,
            }
            mod.save:set("g2_egg_provenance", records)
        end
  
        function G2.onEggHatched(ev)
            if not G2.isGen2() or not ev or not ev.mon then return end
            local game = getCurrentGame() or mod.game
            local resolvedArea = areaKey(game, nil)
            local area = resolvedArea or "UNKNOWN"
            if resolvedArea then
                registerArea(resolvedArea)
                markVisited(resolvedArea)
            end
  
            local mon = ev.mon
            local glitch = mod.exports.__beta26.getGlitchSpeciesInfo(
                game, ev.species or mon.species)
            mon.nuzlockeOrigin = "EGG"
            mon.encounterType = "egg"
            mon.eggHatchLocation = area
            mon.nuzlockeGlitch = glitch.isGlitch or nil
            mon.nuzlockeMissingNo = glitch.missingNo or nil
            mon.nuzlockeRawSpecies = glitch.isGlitch
                and (ev.species or mon.species) or nil
            if ev.egg and ev.egg.eggCreatedLocation then
                mon.eggCreatedLocation = ev.egg.eggCreatedLocation
            end
            Identity.ensurePokemonIdentity(mon, game and game.save, "EGG")
            Identity.setPokemonOrigin(mon, "EGG")
            Identity.baselineAdd(mon, "EGG")

            local eggMode = math.max(0, math.min(3, math.floor(tonumber(
                mod.save:get("gold_egg_encounter_mode", 0)) or 0)))
            if eggMode > 0 and active(game, nil) then
                local target
                if eggMode == 1 then
                    target = mon.eggCreatedLocation or area
                elseif eggMode == 2 then
                    target = area
                elseif mon.eggCreatedLocation then
                    -- Bred eggs are still anchored to where they were created;
                    -- GIFT mode's special slot is reserved for story/gift eggs.
                    target = mon.eggCreatedLocation
                else
                    target = "GIFT_EGG"
                end
                target = registerArea(target, target == "GIFT_EGG"
                    and "Gift Egg" or nil) or target
                local occupied = mod.exports.__beta26.encounterSlotConflict(
                    game, target, false) ~= nil
                if occupied then
                    mon.nuzlockeInvalidAcquisition = "area"
                    worldMechanic(game, "egg_area_used:" .. tostring(target),
                        "EGG HATCHED. That encounter slot was already used.",
                        "The Egg hatched, but this area's Nuzlocke slot was already claimed.",
                        "The shell cracked too late for the rulebook. This Egg's encounter slot was already spent.")
                else
                    local consume = mod.save:get("encounter_limit", defaultRuleValue("encounter_limit")) == true
                    mod.exports.__beta26.registerSpecialCatch(glitch.key, target, "egg", mon, {
                        consume = consume, origin = "EGG", encounterMethod = "egg",
                        encounterMapId = target, eggCreatedLocation = mon.eggCreatedLocation,
                        eggHatchLocation = area,
                    })
                    mod.exports.__beta26.markEncounterCaught(target, glitch.key, "egg", target,
                        consume, { encounterMethod="egg",
                            eggCreatedLocation=mon.eggCreatedLocation,
                            eggHatchLocation=area })
                end
            end
  
            local records = mod.save:get("g2_egg_provenance", {})
            if type(records) ~= "table" then records = {} end
            records[#records + 1] = {
                status = "HATCHED",
                species = glitch.key,
                rawSpecies = glitch.isGlitch and (ev.species or mon.species) or nil,
                glitch = glitch.isGlitch or nil,
                missingNo = glitch.missingNo or nil,
                nickname = ev.nickname or mon.nickname,
                area = area,
                createdArea = mon.eggCreatedLocation,
                pokemonId = Identity.pokemonIdentity(mon),
            }
            mod.save:set("g2_egg_provenance", records)
        end
  
        -----------------------------------------------------------------
        -- GEN 2 ROAMER PROVENANCE
        --
        -- A roaming encounter is still judged by the normal catch policy at the
        -- map where the Ball is thrown. These events preserve the roaming
        -- identity and map history so tracker/debug data does not treat each move
        -- as an unrelated static encounter.
        -----------------------------------------------------------------
        function G2.onRoamerMoved(ev)
            if not G2.isGen2() or not ev then return end
            local state = mod.save:get("g2_roamers", {})
            if type(state) ~= "table" then state = {} end
            local key = tostring(ev.index or ev.slot or ev.species or "?")
            state[key] = state[key] or {}
            state[key].species = ev.species or state[key].species
            state[key].map = ev.to
            state[key].previous = ev.from
            state[key].reason = ev.reason
            mod.save:set("g2_roamers", state)
        end
  
        function G2.onRoamerEncountered(ev)
            if not G2.isGen2() or not ev then return end
            local mapId = ev.mapId
            if mapId then
                registerArea(mapId)
                markVisited(mapId)
            end
            local state = mod.save:get("g2_roamers", {})
            if type(state) ~= "table" then state = {} end
            local key = tostring(ev.index or ev.slot or ev.species or "?")
            state[key] = state[key] or {}
            state[key].species = ev.species or state[key].species
            state[key].level = ev.level or state[key].level
            state[key].lastEncounter = mapId
            state[key].encounters = (tonumber(state[key].encounters) or 0) + 1
            mod.save:set("g2_roamers", state)
            -- Upstream emits this before the ordinary encounter hooks. Arm
            -- exactly the next non-trainer battle and consume the marker there.
            mod.exports.__beta26.pendingGoldRoamer = {
                index = ev.index, slot = ev.slot, species = ev.species,
                level = ev.level, mapId = mapId,
            }
        end
  
        function G2.onBugContestScored(ev)
            if not G2.isGen2() or not ev or not ev.mon then return end
            local mode = math.max(0, math.min(2, math.floor(tonumber(
                mod.save:get("gold_bug_contest_mode", 0)) or 0)))
            if mode <= 0 then return end
            local game = getCurrentGame() or mod.game
            if not active(game, nil) then return end
            local species = G2.speciesKey(game, ev.mon.species)
            local area = registerArea("NATIONAL_PARK_CONTEST", "National Park Contest")
            local consume = mode == 2
                and mod.save:get("encounter_limit", defaultRuleValue("encounter_limit")) == true
            local occupied = consume and mod.exports.__beta26.encounterSlotConflict(
                game, area, false) ~= nil
            if occupied then
                ev.mon.nuzlockeInvalidAcquisition = "area"
                Identity.ensurePokemonIdentity(ev.mon, game and game.save, "NORMAL")
                Identity.setPokemonOrigin(ev.mon, "NORMAL")
                Identity.baselineAdd(ev.mon, "NORMAL")
                worldMechanic(game, "bug_contest_area_used:" .. tostring(area),
                    "CONTEST ENDED. That Contest encounter slot was already used.",
                    "The judges accepted your entry, but its Nuzlocke Contest slot was already claimed.",
                    "Official score, invalid slot: the Contest encounter was already spent.")
                return
            end
            mod.exports.__beta26.registerSpecialCatch(species, area, "bug_contest", ev.mon, {
                consume = consume, origin = "NORMAL",
                encounterMethod = "bug_contest", encounterMapId = "NATIONAL_PARK",
            })
            mod.exports.__beta26.markEncounterCaught(area, species, "bug_contest", "NATIONAL_PARK",
                consume, { encounterMethod = "bug_contest" })
            worldMechanic(game, "bug_contest_entry:" .. tostring(species),
                consume and "Contest entry logged. Its encounter slot is now used."
                    or "Contest entry logged. Contest catches are exempt from area use.",
                consume and "The judges have your final entry. That Contest slot belongs to it now."
                    or "The judges logged your entry without spending a route encounter.",
                consume and "The judges made it official: this is your Contest encounter."
                    or "Official result, unofficial loophole: the Contest entry stays free.")
        end

        function G2.installHeadbuttTracking()
            if not G2.isGen2() then return false end
            local ok, World = pcall(require, "src.world.gen2.World")
            if not ok or type(World) ~= "table"
                or type(World.tryHeadbutt) ~= "function" then return false end
            local installed = installOwnedMethodWrapper(
                World, "__nuzlockeHeadbuttTrackingSession29315",
                "tryHeadbutt", function(vanilla)
                    return function(self, x, y, ...)
                        mod.exports.__beta26.pendingGoldEncounterMethod = {
                            kind = "headbutt",
                            mapId = self and self.map and self.map.id,
                            x = x, y = y,
                        }
                        local result = vanilla(self, x, y, ...)
                        if result ~= "battle" then
                            mod.exports.__beta26.pendingGoldEncounterMethod = nil
                        end
                        return result
                    end
                end)
            World.__nuzlockeHeadbuttTracking = true -- historical marker only
            return installed
        end

        function G2.radioLine(game)
            game = game or getCurrentGame() or mod.game
            if not G2.isGen2(game)
                or mod.save:get("gold_radio_world_building", false) ~= true
                or worldTier(game) <= 0 then return nil end
            local area = areaKey(game, nil)
            local status = "OPEN"
            if area and caughtAreas()[area] ~= nil then status = "CAUGHT"
            else
                local state = area and getEncounterState(area)
                if type(state) == "table" and state.status == "FAILED" then
                    status = "LOST"
                end
            end
            local catches = countTrackerCatches()
            local losses = math.max(0, math.floor(tonumber(
                mod.save:get("nuzlocke_losses", 0)) or 0))
            local tier = worldTier(game)
            if tier == 1 then return "NUZ: SLOT " .. status end
            if tier == 2 then
                return ("NUZ: C%d D%d %s"):format(catches, losses, status)
            end
            local lines = {
                ("JOHTO NUZ: %s"):format(status),
                ("NUZ CATCHES:%d"):format(catches),
                ("NUZ LOSSES:%d"):format(losses),
            }
            local index = ((catches + losses) % #lines) + 1
            return lines[index]
        end
        mod.exports.__beta26.goldRadioLine = G2.radioLine


        mod.events:on("battle.damage_dealt", G2.noteDamage)
        mod.events:on("battle.fainted", G2.onFaint)
        mod.events:on("breeding.egg_created", G2.onEggCreated)
        mod.events:on("egg.hatched", G2.onEggHatched)
        mod.events:on("roamer.moved", G2.onRoamerMoved)
        mod.events:on("roamer.encountered", G2.onRoamerEncountered)
        mod.events:on("bug_contest.scored", G2.onBugContestScored)
  
        function G2.installFieldPoisonPermadeathGate()
            if not G2.isGen2() then return false end
            local okWorld, World = pcall(require, "src.world.gen2.World")
            if not okWorld or type(World) ~= "table"
                or type(World.poisonFaintScript) ~= "function" then
                return false
            end

            local poisonInstalled = installOwnedMethodWrapper(
                World, "__nuzlockeFieldPoisonPermadeathSession",
                "poisonFaintScript", function(previous)
                    return function(self, event, ...)
                        local game = (self and self.game) or getCurrentGame() or mod.game
                        local party = game and game.save and game.save.party
                        local fainted = {}
                        if type(party) == "table" and type(event) == "table"
                            and active(game, nil)
                            and mod.save:get("permadeath", true) == true then
                            for _, index in ipairs(event.fainted or {}) do
                                local mon = party[index]
                                if type(mon) == "table" then
                                    fainted[#fainted + 1] = mon
                                end
                            end
                        end

                        -- Gold's native handler synchronously sets up the
                        -- poison-faint happiness/text chain. Prune afterward so
                        -- that presentation still names the real fainted slots.
                        local result = previous(self, event, ...)

                        if #fainted > 0 then
                            local deaths = {}
                            for _, mon in ipairs(fainted) do
                                local recorded =
                                    mod.exports.__beta26.recordFieldPoisonDeath(
                                        game, mon)
                                if recorded or mon.nuzlockeDead == true then
                                    deaths[mon] = true
                                end
                            end
                            mod.exports.__beta26.pruneFieldPoisonDeaths(
                                party, deaths)
                        end

                        -- StepEvents already decided whether this exact poison
                        -- step is a whole-party wipe. Keep Whiteout independent
                        -- from Permadeath and intercept only the later spawn warp
                        -- after Gold's native poison-faint/whiteout text runs.
                        if self and type(event) == "table"
                            and event.whiteout == true and active(game, nil) then
                            local decision, counts =
                                mod.exports.__beta26.whiteoutDecision(game)
                            self.__nuzlockeFieldPoisonWhiteoutPending = decision
                            self.__nuzlockeFieldPoisonWhiteoutCounts = counts
                        end
                        return result
                    end
                end)

            local warpInstalled = false
            if type(World.warpToSpawn) == "function" then
                warpInstalled = installOwnedMethodWrapper(
                    World, "__nuzlockeFieldPoisonWarpSession29315",
                    "warpToSpawn", function(previousWarp)
                        return function(self, ...)
                            local game = (self and self.game) or getCurrentGame() or mod.game
                            local pending = self
                                and self.__nuzlockeFieldPoisonWhiteoutPending or nil
                            local counts = self
                                and self.__nuzlockeFieldPoisonWhiteoutCounts or nil
                            if self then
                                self.__nuzlockeFieldPoisonWhiteoutPending = nil
                                self.__nuzlockeFieldPoisonWhiteoutCounts = nil
                            end
                            if pending == "blackout" and active(game, nil)
                                and mod.exports.__beta26.finishFieldWhiteoutRun(
                                    game) then
                                return true
                            end
                            local results = { previousWarp(self, ...) }
                            if pending == "survive" and active(game, nil) then
                                recordRunBlackout(game, "field_poison")
                                pcall(mod.exports.__beta26.showWhiteoutRecoveryMessage,
                                    game, counts)
                            end
                            return unpackValues(results)
                        end
                    end)
            end
            return poisonInstalled and warpInstalled
        end

        function G2.installAll()
            if mod.exports.__beta26.isSaveEditorSession() then
                return false, "not_applicable", "save-editor session"
            end
            if not G2.isGen2() then
                return false, "not_applicable", "non-Gen2 edition"
            end
            local attempt = mod.exports.__beta26.attemptInstall
            local allOk = true
            local function checked(name, fn)
                local ok = attempt(name, fn)
                if ok ~= true then allOk = false end
            end
            checked("gen2.battle_rule_pager", G2.installBattleRulePager)
            checked("gen2.capture_gate", G2.installCaptureGate)
            checked("gen2.nickname_gate", G2.installNicknameGate)
            checked("gen2.mart_gate", G2.installMartGate)
            checked("gen2.held_item_gate", G2.installHeldItemGate)
            checked("gen2.field_item_gate", G2.installFieldItemGate)
            checked("gen2.rare_candy_to_cap", G2.installRareCandyToCap)
            checked("gen2.catch_tutorial_skip", G2.installCatchTutorialSkip)
            checked("gen2.headbutt_tracking", G2.installHeadbuttTracking)
            checked("gen2.random_starter_transaction", G2.installRandomStarterTransaction)
            checked("gen2.gift_tracking", G2.installGiftTracking)
            checked("gen2.trade_gate", G2.installTradeGate)
            checked("gen2.static_tracking", G2.installStaticTracking)
            checked("gen2.gambling_gate", G2.installGamblingGate)
            checked("gen2.whiteout_gate", G2.installWhiteoutGate)
            checked("gen2.field_poison_permadeath", G2.installFieldPoisonPermadeathGate)
            checked("gen2.whiteout_recovery_pc", mod.exports.__beta26.installWhiteoutRecoveryPcGate)
            -- Gen 2 NUZ STATUS is provided by ui.start_menu.items + screens registry.
            -- Do not install the legacy TrainerCard monkey patch.
            return allOk
        end
  
        -- 2.3.10: Gen 2 adapters install at game.ready/save.loaded.
      
    -----------------------------------------------------------------
    -- OPTIONAL POKEGEAR CARDS INTEGRATION
    --
    -- Gen 2-only presentation provider. No hard dependency, no PHONE fork,
    -- and no rule enforcement lives in this module.
    -----------------------------------------------------------------
    local function loadOptionalPresentationModule(healthName, path, deps)
        return mod.exports.__beta26.attemptInstall(healthName, function()
            local okRead, source = pcall(mod.read, mod, path)
            if not okRead or type(source) ~= "string" or source == "" then
                return false, "pending", "package source unavailable: " .. tostring(path)
            end
            local chunk, loadErr = load(source, "@mods/nuzlocke/" .. tostring(path))
            if type(chunk) ~= "function" then
                return false, tostring(loadErr or "module_load_failed")
            end
            local okRun, result = pcall(chunk, mod, deps)
            if not okRun then return false, tostring(result) end
            if result == false then return false, "module_returned_false" end
            return true
        end)
    end

    loadOptionalPresentationModule("integration.pokegear_module",
        "pokegear_integration.lua", {
            translate = function(text, ...)
                return Strings(text, ...)
            end,
            ruleDefault = defaultRuleValue,
        })

    -----------------------------------------------------------------
    -- OPTIONAL GEN1 MODERN UI PRESENTATION
    --
    -- Presentation only. Nuzlocke remains the state/action owner and
    -- native custom screens remain the fallback if no compatible UI
    -- presenter is active.
    -----------------------------------------------------------------
    loadOptionalPresentationModule("integration.modern_ui_module",
        "modern_ui_integration.lua", {
            translate = function(text, ...)
                return Strings(text, ...)
            end,
            isGen2 = mod.exports.__beta26.runtimeIsGen2,
            getCurrentGame = function()
                return getCurrentGame()
            end,
        })

    -----------------------------------------------------------------
    -- beta.30.1.21: MOD COMPAT / TRACKER CONTEXT / ADAPTIVE PRESENTATION
    --
    -- This stays on the existing export table to avoid increasing main.lua's
    -- top-level local pressure. It is diagnostic/presentation infrastructure;
    -- Nuzlocke remains the challenge-policy owner.
    -----------------------------------------------------------------
    mod.exports.__beta26.compat21 = mod.exports.__beta26.compat21 or {}

    mod.exports.__beta26.compat21.randomizerTrackerContext = function(game)
        if mod.exports.__beta26.runtimeIsGen2(game) then return nil end
        local owner = mod.exports.__beta26.pokemonRandomizerOwnership(
            "random_encounter_tables", game)
        if not owner then
            owner = mod.exports.__beta26.externalRuleDelegation(
                "random_encounter_tables", game)
        end
        if not owner then return nil end
        return {
            provider = owner.name or owner.id or "External Randomizer",
            providerId = owner.id,
            randomized = true,
            -- Never expose future mappings here. The tracker remains spoiler-safe:
            -- it only labels ownership/provenance around already-known outcomes.
            spoilerSafe = true,
        }
    end

    mod.exports.__beta26.compat21.trackerCatchContext = function(game, catch, area)
        if type(catch) ~= "table" then
            return { tag = "OPEN", status = "AVAILABLE", provider = nil }
        end
        local kind = tostring(catch.encounterType
            or catch.nuzlockeEncounterType or "wild"):lower()
        local labels = {
            gift = "GIFT", starter = "START", static = "STATIC",
            trade = "TRADE", wonder_trade = "WONDER",
            fishing = "FISH", old_rod = "FISH", good_rod = "FISH",
            super_rod = "FISH", surf = "SURF", safari = "SAFARI",
            grass = "GRASS", wild = "WILD", overworld = "WILD",
            town = "TOWN",
        }
        local provider = catch.nuzlockeEncounterProvider
            or catch.nuzlockeIdentityProvider
        local rng = mod.exports.__beta26.compat21.randomizerTrackerContext(game)
        local externallyRandomized = provider ~= nil
            or (rng ~= nil and (kind == "wild" or kind == "grass"
                or kind == "surf" or kind == "overworld"))
        local status = (catch.dead == true or catch.status == "DEAD") and "DEAD"
            or (catch.failed and "FAILED"
            or (catch.isShiny and "SHINY" or "CAUGHT"))
        return {
            tag = externallyRandomized and "RNG" or (labels[kind] or kind:upper()),
            status = status,
            provider = provider or (externallyRandomized and rng and rng.provider or nil),
            encounterType = kind,
            area = area,
            spoilerSafe = true,
        }
    end

    mod.exports.__beta26.compat21.pokemonLegality = function(game, mon)
        if type(mon) ~= "table" or not mon.species then
            return { legal = nil, status = "UNKNOWN", reasons = {} }
        end
        local reasons = {}
        if mon.nuzlockeDead == true then
            reasons[#reasons + 1] = "LOST"
        end
        if mon.nuzlockePcLocked == true then
            reasons[#reasons + 1] = "PC LOCKED"
        end
        local invalidAcquisition = mon.nuzlockeInvalidAcquisition
        if type(invalidAcquisition) == "string"
            and invalidAcquisition ~= "" then
            reasons[#reasons + 1] = "INVALID ACQUISITION"
        end
        local okType, typeAllowed = pcall(
            mod.exports.__beta26.typeLockAllowsPokemon, game, mon)
        if okType and typeAllowed == false then
            reasons[#reasons + 1] = "TYPE LOCK"
        end
        local bstLimit = mod.exports.__beta26.getMaximumBST()
        local bst = mod.exports.__beta26.getSpeciesBST(game, mon.species)
        if tonumber(bstLimit) and tonumber(bstLimit) > 0
            and tonumber(bst) and tonumber(bst) > tonumber(bstLimit) then
            reasons[#reasons + 1] = "MAX BST"
        end
        if mod.save:get("ban_legendaries", false) == true
            and isLegendarySpecies(game, mon.species) then
            reasons[#reasons + 1] = "LEGENDARY"
        end
        if mod.save:get("ban_mythicals", false) == true
            and isMythicalSpecies(game, mon.species) then
            reasons[#reasons + 1] = "MYTHICAL"
        end
        if mod.save:get("ban_pseudos", false) == true
            and isPseudoSpecies(game, mon.species) then
            reasons[#reasons + 1] = "PSEUDO"
        end
        local glitch = mod.exports.__beta26.getGlitchSpeciesInfo(game, mon.species)
        if mod.save:get("allow_glitch_pokemon", false) ~= true
            and type(glitch) == "table" and glitch.isGlitch == true then
            reasons[#reasons + 1] = "GLITCH"
        end
        local onlyLost = #reasons == 1 and reasons[1] == "LOST"
        return {
            legal = #reasons == 0,
            status = #reasons == 0 and "LEGAL"
                or (onlyLost and "LOST" or "RESTRICTED"),
            reasons = reasons,
            invalidAcquisitionReason =
                type(invalidAcquisition) == "string"
                    and invalidAcquisition ~= "" and invalidAcquisition or nil,
            bst = bst,
            maximumBST = bstLimit,
        }
    end

    mod.exports.__beta26.compat21.pokemonProvenance = function(game, mon)
        if type(mon) ~= "table" then return {} end
        local provider = mon.nuzlockeEncounterProvider
            or mon.nuzlockeIdentityProvider
        local source = mon.nuzlockeEncounterSource
            or mon.nuzlockeEncounterContext
        local randomizer = mod.exports.__beta26.compat21.randomizerTrackerContext(game)
        if not provider and randomizer
            and tostring(mon.encounterType or mon.nuzlockeEncounterType or "wild"):lower()
                ~= "gift" then
            provider = randomizer.provider
        end
        return {
            provider = provider,
            source = source,
            origin = mon.nuzlockeOrigin,
            location = mon.catchLocation or mon.nuzlockeProgressionCatchLocation,
            encounterType = mon.encounterType or mon.nuzlockeEncounterType,
            pcLocked = mon.nuzlockePcLocked == true or nil,
            pcLockReason = mon.nuzlockePcLockReason,
            identityProvider = mon.nuzlockeIdentityProvider,
            externalIdentity = mon.nuzlockeExternalIdentity,
        }
    end

    mod.exports.__beta26.compat21.surfaceRows = function(game)
        local rows = {}
        local function add(label, owner, detail)
            rows[#rows + 1] = {
                label = label, owner = owner or "Nuzlocke", detail = detail,
            }
        end
        local function delegated(key)
            local ok, value = pcall(mod.exports.__beta26.externalRuleDelegation,
                key, game)
            return ok and type(value) == "table" and value or nil
        end
        local starter = delegated("random_starter")
        local encounters = delegated("random_encounter_tables")
        local learnsets = delegated("random_learnsets")
        local money = delegated("trainer_money_multiplier")
        local caps = delegated("level_cap_scope")
        local running = mod.exports.__beta26.qolTogglesOwnership(
            "automatic_running_shoes", game)
        local difficultyName = "Nuzlocke"
        local okDifficulty, options = pcall(mod.exports.__beta26.difficultyOptions)
        if okDifficulty and type(options) == "table" then
            local selectedId = tostring(mod.save:get("difficulty_provider_id", "vanilla"))
            for _, row in ipairs(options) do
                if type(row) == "table" and tostring(row.id or "") == selectedId then
                    difficultyName = tostring(row.name or row.id or "Nuzlocke")
                    break
                end
            end
        end
        local function compatOwner(capability)
            local ok, provider = pcall(activeCompatProvider, capability, game, nil)
            if not ok or type(provider) ~= "table" then return nil end
            local display = providerDisplay(provider)
            return display and (display.name or display.id) or provider.id
        end
        local function interopOwner(capability)
            local interop = mod.exports.nuzlocke and mod.exports.nuzlocke.interop
            if not (interop and type(interop.resolveCapability) == "function") then
                return nil
            end
            local ok, resolved = pcall(interop.resolveCapability, capability)
            if not ok or type(resolved) ~= "table"
                or resolved.supplied ~= true
                or type(resolved.preferred) ~= "table" then
                return nil
            end
            local provider = resolved.preferred
            return tostring(provider.name or provider.id or "External Mod")
        end
        add("STARTER RNG", starter and (starter.name or starter.id) or "Nuzlocke",
            starter and "EXTERNAL OWNER" or "NATIVE")
        add("ENCOUNTER RNG",
            encounters and (encounters.name or encounters.id) or "Nuzlocke",
            encounters and "EXTERNAL OWNER" or "NATIVE")
        add("LEARNSET RNG",
            learnsets and (learnsets.name or learnsets.id) or "Nuzlocke",
            learnsets and "EXTERNAL OWNER" or "NATIVE")
        add("TRAINER MONEY", money and (money.name or money.id) or "Nuzlocke",
            money and "EXTERNAL OWNER" or "NATIVE")
        add("LEVEL CAPS", caps and (caps.name or caps.id) or "Nuzlocke",
            caps and "EXTERNAL OWNER" or "NATIVE")

        local bagUiOwner = interopOwner("item_presentation")
        add("BAG UI", bagUiOwner or "Engine",
            bagUiOwner and "ITEM PRESENTATION" or "NATIVE")

        local itemUseOwner = interopOwner("item_use_entrypoint")
        add("ITEM USE", itemUseOwner or "Engine",
            itemUseOwner and "ITEM ENTRYPOINT" or "NATIVE")

        local machineOwner = interopOwner("machine_mechanics")
        add("MACHINES", machineOwner or "Engine",
            machineOwner and "MACHINE MECHANICS" or "NATIVE")

        add("ITEM RULES", "Nuzlocke", "NUZLOCKE POLICY")

        local selectorOwner = interopOwner("encounter_selector")
        add("ENC SELECT", selectorOwner or "Engine",
            selectorOwner and "ENCOUNTER SELECTOR" or "NATIVE")

        local captureOwner = interopOwner("capture_mechanics")
        add("CATCH ODDS", captureOwner or "Engine",
            captureOwner and "CAPTURE MECHANICS" or "NATIVE")
        add("CATCH RULES", "Nuzlocke", "NUZLOCKE POLICY")

        local questFrameworkOwner = interopOwner("quest_framework")
        add("QUEST UI", questFrameworkOwner or "Engine",
            questFrameworkOwner and "QUEST FRAMEWORK" or "NATIVE")
        local questContentOwner = interopOwner("quest_content_provider")
        add("QUEST DATA", questContentOwner or "Source Mods",
            questContentOwner and "QUEST CONTENT" or "SOURCE OWNED")

        local expOwner = interopOwner("exp_distribution")
        add("EXP DIST.", expOwner or "Engine",
            expOwner and "EXTERNAL DISTRIBUTION" or "NATIVE")
        add("EXP CAP", caps and (caps.name or caps.id) or "Nuzlocke",
            caps and "EXTERNAL OWNER" or "NUZLOCKE POLICY")

        add("DIFFICULTY", difficultyName,
            difficultyName == "VANILLA" and "VANILLA" or "ACTIVE PROFILE")
        add("SPECIES DATA", compatOwner("species_metadata") or "Merged Registry",
            compatOwner("species_metadata") and "EXTERNAL METADATA" or "NATIVE/MERGED")
        add("POKEMON ID", compatOwner("pokemon_identity") or "Nuzlocke",
            compatOwner("pokemon_identity") and "EXTERNAL IDENTITY" or "NATIVE")
        add("ENCOUNTERS", compatOwner("encounters") or "Nuzlocke",
            compatOwner("encounters") and "SHARED PROVIDER" or "NATIVE")
        add("ESCAPE/WARPS", compatOwner("escape") or "Nuzlocke",
            compatOwner("escape") and "SHARED PROVIDER" or "NATIVE")
        add("MOVEMENT", running and ("Nuzlocke + " .. tostring(
                running.name or running.id or "QoL Toggles"))
                or compatOwner("movement_speed") or "Nuzlocke",
            running and "COMPOSED HOLD-B OVERLAP"
                or (compatOwner("movement_speed") and "SHARED PROVIDER" or "NATIVE"))
        local okModern, modern = pcall(mod.find, "gen1_modern_ui")
        add("PRESENTATION",
            okModern and modern and not mod.exports.__beta26.runtimeIsGen2(game)
                and (modern.name or "Gen1 Modern UI") or "Nuzlocke",
            mod.exports.__beta26.runtimeIsGen2(game)
                and (mod.exports.__beta26.Dev.gameLabel(game) .. " NATIVE")
                or (okModern and modern and "OPTIONAL BRIDGE" or "NATIVE"))
        local okKerning, Font = pcall(require, "src.render.Font")
        local kern = okKerning and type(Font) == "table"
            and Font._nuzlockeAdvanceOf ~= nil
        add("TEXT LAYOUT", kern and "Nuzlocke" or "Engine",
            kern and "GEN1 ADAPTIVE" or "NATIVE")
        local externalOverCap = mod.save:get("nuzlocke_external_party_over_cap", false) == true
        if externalOverCap then
            local count = tonumber(mod.save:get("nuzlocke_external_party_count", 0)) or 0
            local limit = tonumber(mod.save:get("nuzlocke_external_party_limit", 6)) or 6
            add("SAVE STATE", ("PARTY %d/%d"):format(count, limit), "EXTERNAL STATE")
        else
            add("SAVE STATE", "Nuzlocke", "STATE OK")
        end

        local translationRows = mod.exports.nuzlocke_translation
            and mod.exports.nuzlocke_translation.detect
            and mod.exports.nuzlocke_translation.detect() or {}
        if #translationRows > 0 then
            local names, notes = {}, {}
            for _, row in ipairs(translationRows) do
                names[#names + 1] = tostring(row.name or row.id or "LANG")
                if row.inventoryLineBreakEnabled then
                    notes[#notes + 1] = "LIST LAYOUT ON"
                end
                if row.trainerCardOverrideEnabled then
                    notes[#notes + 1] = "CARD LAYOUT ON"
                end
            end
            add("TRANSLATION", table.concat(names, "+"),
                #notes > 0 and table.concat(notes, "+") or "SEMANTIC TEXT")
        end
        return rows
    end

    -- Public merged species metadata surface. Providers may contribute partial
    -- semantic facts; live merged species data fills the remainder. Unknown
    -- fields remain nil rather than being guessed.
    mod.exports.__beta26.compat21.speciesMetadata = function(game, species)
        local def = speciesDefinition(game, species)
        local external = providerSpeciesMetadata(game, species) or {}
        local out = {}
        for k, v in pairs(external) do out[k] = v end
        out.species = out.species or species
        if out.types == nil and type(def) == "table" then
            out.types = def.types or def.type
        end
        if out.baseStats == nil and type(def) == "table" then
            out.baseStats = def.baseStats or def.base_stats or def.stats
        end
        if out.bst == nil then
            local ok, bst = pcall(mod.exports.__beta26.getSpeciesBST, game, species)
            if ok then out.bst = bst end
        end
        return out
    end
    mod.exports.nuzlocke_compat.species_metadata.get = function(game, species)
        return mod.exports.__beta26.compat21.speciesMetadata(game, species)
    end
    mod.exports.nuzlocke_compat.species_metadata.api = 2
    mod.exports.nuzlocke_compat.species_metadata.merged = true

    -- Translation-safe semantic matcher for UI rows. Prefer ids/actions/values;
    -- translated visible strings are fallback only.
    mod.exports.__beta26.compat21.semanticLabelMatches =
        function(item, semantic, translated)
            if type(item) ~= "table" then return false end
            local target = tostring(semantic or ""):upper()
            for _, value in ipairs({
                item.id, item.action, item.value, item.kind, item.command,
            }) do
                if tostring(value or ""):upper() == target then return true end
            end
            local label = tostring(item.label or "")
            return label:upper() == target
                or (translated ~= nil and label == tostring(translated))
        end

    -- Context-sensitive guidance is World Building, not enforcement. It returns
    -- a tiered hint for a known rule context and never changes challenge state.
    mod.exports.__beta26.compat21.guidance = function(game, context)
        if worldTier(game) <= 0 or type(context) ~= "table" then return nil end
        local kind = context.kind
        if kind == "randomized_area" then
            local provider = tostring(context.provider or "another mod")
            return worldTier(game) >= 3
                and ("The encounter table here is being handled by " .. provider
                    .. ". The Nuzlocke still judges the encounter after it appears.")
                or "This area's encounters are externally randomized."
        elseif kind == "consumed_area" then
            return worldTier(game) >= 3
                and "Your encounter for this area is already written in the log. Another wild Pokemon cannot replace it."
                or "This area's Nuzlocke encounter is already used."
        elseif kind == "lock_in" then
            return worldTier(game) >= 3
                and "The challenge marks this entrance behind you. Finish the locked area before trying to leave."
                or "Lock-In is active here."
        elseif kind == "level_cap" then
            local cap = tonumber(context.cap)
            return cap and (worldTier(game) >= 3
                and ("Your next cap is " .. tostring(cap)
                    .. ". EXP Edging can bank overflow without letting the team cross it.")
                or ("Next level cap: " .. tostring(cap) .. "."))
                or nil
        elseif kind == "forgiveness_token" then
            return worldTier(game) >= 3
                and "An F. TOKEN can reopen the current failed encounter area or revive one archived fallen Pokemon. Spending it is permanent."
                or "You have an F. TOKEN available."
        elseif kind == "progression_catch" then
            return worldTier(game) >= 3
                and "This catch is required for progression. The exception may secure it without turning it into a legal battle Pokemon."
                or "A progression-required catch exception applies."
        end
        return nil
    end

    -----------------------------------------------------------------
    -- MOD COMPAT SCREEN
    -----------------------------------------------------------------
    mod.content.screens:register("NuzlockeModCompatScreen", {
        new = function(game)
            -- 2.1.22: R/B/Y uses the host's stable ListMenu for compatibility
            -- reporting. Yellow runtime showed the hand-drawn custom state
            -- could hard-crash. Keep Gold on its generation-native Chrome path.
            if not mod.exports.__beta26.runtimeIsGen2(game) then
                local okRows, rows = pcall(
                    mod.exports.__beta26.compat21.surfaceRows, game)
                if not okRows or type(rows) ~= "table" then
                    rows = { { label = "COMPAT", owner = "READ ERROR" } }
                end
                local items = {}
                local modernState = mod.exports.__beta26.ModernUiIntegration
                local modernActive = type(modernState) == "table"
                    and modernState.active == true
                local shortLabels = {
                    ["STARTER RNG"] = "START RNG", ["ENCOUNTER RNG"] = "ENC RNG",
                    ["LEARNSET RNG"] = "LEARN RNG", ["TRAINER MONEY"] = "TRNR MONEY",
                    ["LEVEL CAPS"] = "LV CAPS", ["DIFFICULTY"] = "DIFFICULTY",
                    ["SPECIES DATA"] = "SPECIES", ["POKEMON ID"] = "PKMN ID",
                    ["ENCOUNTERS"] = "ENCOUNTER", ["ESCAPE/WARPS"] = "ESC/WARP",
                    ["MOVEMENT"] = "MOVEMENT", ["PRESENTATION"] = "UI",
                    ["TEXT LAYOUT"] = "TEXT",
                }
                local function nativeFit(text, budget)
                    text = Strings(tostring(text or ""))
                    local okFont, Font = pcall(require, "src.render.Font")
                    if not okFont or type(Font) ~= "table" or type(Font.width) ~= "function"
                        or Font.width(text) <= budget then return text end
                    if type(Font.split) == "function" and type(Font.spansFitting) == "function" then
                        local spans = Font.split(text)
                        local count = math.max(1, Font.spansFitting(spans, budget))
                        local span = spans[count]
                        if span and span.to then return text:sub(1, span.to) end
                    end
                    -- Font span helpers are the only safe truncation seam
                    -- for translated text; without them, fail open rather than
                    -- split a UTF-8 codepoint by raw byte index.
                    return text
                end
                for _, row in ipairs(rows) do
                    if type(row) == "table" then
                        local rawLabel = tostring(row.label or "COMPAT")
                        local rawOwner = tostring(row.owner or row.status or "")
                        local translatedFull = Strings(rawLabel)
                        -- Preserve a real translation of the full semantic label.
                        -- Compact English aliases are only a fallback when the
                        -- localization layer did not translate the full label.
                        local label = translatedFull
                        if not modernActive and translatedFull == rawLabel then
                            label = shortLabels[rawLabel:upper()] or rawLabel
                        end
                        local owner = rawOwner
                        if not modernActive then
                            if rawOwner == "Nuzlocke" then owner = "NUZLOCKE"
                            elseif rawOwner == "Merged Registry" then owner = "MERGED"
                            elseif rawOwner == "Gen1 Modern UI" then owner = "MODERN UI"
                            end
                        end
                        items[#items + 1] = {
                            label = label,
                            right = owner,
                            nuzlockeCompatRow = row,
                        }
                    end
                end

                local rememberedCompat = uiRememberedScreen(game, "mod_compat")
                local menu = mod.ui.ListMenu.new(game, Strings("MOD COMPAT"), items, {
                    kind = "nuzlocke_mod_compat",
                    pageJump = true,
                    wrap = false,
                })
                if type(menu) ~= "table" then return menu end

                -- 2.3.28: keep the proven host ListMenu as the actual state and
                -- input owner, but give MOD COMPAT a purpose-built presentation.
                -- This avoids reviving the old custom-state crash path while
                -- making ownership readable and discoverable.
                menu.screenId = "NuzlockeModCompatScreen"
                menu.index = math.max(1, math.min(#items,
                    math.floor(tonumber(rememberedCompat.index) or 1)))
                menu.scroll = math.max(0, math.min(
                    math.floor(tonumber(rememberedCompat.scroll) or 0),
                    math.max(0, #items - 5)))
                menu.nuzlockeUi = mod.exports.nuzlocke_ui.describeScreen(menu)
                menu.presentationRole = "compatibility_status"
                menu.presentationStateOwner = "nuzlocke"
                menu.presentationNativeFallback = true
                menu.uiModLayout = "classic"
                menu.keepClassicUi = true
                -- Use the host ListMenu's own index/scroll state so input
                -- and presentation cannot drift. Native 160x144 avoids the
                -- viewport shrink caused by the former 304px logical surface.
                menu.rows = 5

                local function compatRelationshipHelp(row)
                    row = type(row) == "table" and row or {}
                    local label = tostring(row.label or "THIS SYSTEM")
                    local owner = tostring(row.owner or row.status or "UNKNOWN")
                    local detail = tostring(row.detail or ""):upper()
                    local ownerUpper = owner:upper()

                    if detail == "EXTERNAL OWNER" then
                        return owner .. " controls " .. label
                            .. ". Nuzlocke follows its result instead of applying the same rule twice."
                    elseif detail == "ITEM PRESENTATION" then
                        return owner .. " organizes or draws the Bag. Nuzlocke still owns item legality, so banned item use remains blocked."
                    elseif detail == "ITEM ENTRYPOINT" then
                        return owner .. " can launch item use outside the normal Bag screen. The action still passes through Nuzlocke item legality before the engine effect."
                    elseif detail == "MACHINE MECHANICS" then
                        return owner .. " changes TM/HM behavior such as consumption or forgetting. Nuzlocke still decides whether TM teaching is legal."
                    elseif detail == "ENCOUNTER SELECTOR" then
                        return owner .. " can choose a target from the live encounter table. Nuzlocke still owns catch/area rules; BLIND randomized info asks compatible selectors not to target undiscovered species."
                    elseif detail == "CAPTURE MECHANICS" then
                        return owner .. " changes or displays catch probability. Nuzlocke still decides whether the capture itself is legal."
                    elseif detail == "QUEST FRAMEWORK" then
                        return owner .. " provides the quest journal, persistence, markers and registration API. Individual quest mods still own gameplay and rewards."
                    elseif detail == "QUEST CONTENT" then
                        return owner .. " provides quest content or progression. Reward legality still follows the source action and Nuzlocke acquisition/item rules."
                    elseif detail == "SOURCE OWNED" then
                        return "Quest gameplay and rewards belong to individual source mods; the quest journal only presents and tracks them."
                    elseif detail == "EXTERNAL DISTRIBUTION" then
                        return owner .. " decides who receives EXP and how it is split. Nuzlocke still applies the active level cap to each canonical EXP award."
                    elseif detail == "NUZLOCKE POLICY" then
                        return "Nuzlocke owns " .. label
                            .. ". Other mods may present or distribute the action, but the challenge limit is still enforced here."
                    elseif detail == "SHARED PROVIDER" then
                        return owner .. " shares " .. label
                            .. " with Nuzlocke. Each provider keeps its own job and the final result is combined."
                    elseif detail == "EXTERNAL METADATA" then
                        return owner .. " supplies " .. label
                            .. " facts. Nuzlocke reads that provider data instead of guessing species information."
                    elseif detail == "EXTERNAL IDENTITY" then
                        return owner .. " supplies Pokemon identity for this surface. Nuzlocke uses that identity when judging rules."
                    elseif detail == "ACTIVE PROFILE" then
                        return owner .. " is the selected difficulty profile. Its difficulty settings are used where that profile owns them."
                    elseif detail == "OPTIONAL BRIDGE" then
                        return owner .. " draws this presentation. Nuzlocke still owns challenge state, rules, and actions underneath it."
                    elseif detail == "NATIVE/MERGED" or ownerUpper == "MERGED REGISTRY"
                        or ownerUpper == "MERGED" then
                        return label .. " comes from the final merged game registry. Vanilla data and compatible mod additions are combined."
                    elseif detail == "GOLD NATIVE" or detail == "SILVER NATIVE"
                        or detail == "CRYSTAL NATIVE" then
                        local edition = detail:match("^(%S+)") or "GEN 2"
                        edition = edition:sub(1, 1) .. edition:sub(2):lower()
                        return edition .. "'s native engine owns " .. label
                            .. ". Nuzlocke cooperates with it rather than replacing that presentation."
                    elseif detail == "GEN1 ADAPTIVE" then
                        return "Nuzlocke adapts " .. label
                            .. " for Gen 1 readability while leaving the underlying game data unchanged."
                    elseif detail == "EXTERNAL STATE" then
                        return "This save currently exceeds the selected Nuzlocke party-size limit. No Pokemon were deleted or moved; deposit extras until the party is within the limit."
                    elseif detail == "STATE OK" then
                        return "The loaded save is within the selected Nuzlocke party-size limit. External save edits are reconciled conservatively without deleting Pokemon."
                    elseif detail == "SEMANTIC TEXT" then
                        return owner .. " supplies translated text. Nuzlocke exposes semantic source strings so translations do not need gameplay ownership."
                    elseif detail == "VANILLA" then
                        return "Vanilla game behavior owns " .. label
                            .. ". Nuzlocke is not replacing this surface with a difficulty provider."
                    elseif ownerUpper == "ENGINE" then
                        return "The game engine owns " .. label
                            .. ". Nuzlocke only observes or consumes the engine's final result."
                    elseif ownerUpper == "NUZLOCKE" or detail == "NATIVE" then
                        return "Nuzlocke controls " .. label
                            .. ". Other compatible mods may read or present the result, but Nuzlocke applies the challenge rule."
                    end

                    return owner .. " currently owns or contributes to " .. label
                        .. ". Nuzlocke uses the final compatible result instead of assuming exclusive control."
                end

                local function compatFitMarquee(value, budget, selected)
                    local Font = require("src.render.Font")
                    local raw = Strings(tostring(value or ""))
                    if type(Font.width) ~= "function" or Font.width(raw) <= budget then
                        return raw
                    end
                    if type(Font.split) ~= "function"
                        or type(Font.spansFitting) ~= "function" then
                        return raw
                    end
                    local spans = Font.split(raw)
                    if type(spans) ~= "table" or #spans == 0 then return raw end
                    local visible = math.max(1, Font.spansFitting(spans, budget))
                    if not selected then
                        local last = spans[math.min(#spans, visible)]
                        return last and last.to and raw:sub(1, last.to) or raw
                    end
                    local elapsed = (love.timer and love.timer.getTime
                        and love.timer.getTime()) or 0
                    if elapsed < 2.0 then
                        local last = spans[math.min(#spans, visible)]
                        return last and last.to and raw:sub(1, last.to) or raw
                    end
                    local maxOffset = math.max(0, #spans - visible)
                    if maxOffset <= 0 then return raw end
                    local step = math.floor((elapsed - 2.0) / 0.35)
                    local cycle = math.max(1, maxOffset * 2)
                    local phase = step % cycle
                    local offset = phase <= maxOffset and phase or (cycle - phase)
                    local first = offset + 1
                    local last = math.min(#spans, first + visible - 1)
                    return raw:sub(spans[first].from, spans[last].to)
                end

                local function compatWrapAll(value, pixelBudget)
                    local Font = require("src.render.Font")
                    local raw = Strings(tostring(value or ""))
                    local words = {}
                    for word in raw:gmatch("%S+") do words[#words + 1] = word end
                    local lines, current = {}, ""
                    for _, word in ipairs(words) do
                        local candidate = current == "" and word
                            or (current .. " " .. word)
                        local fits = type(Font.width) ~= "function"
                            or Font.width(candidate) <= pixelBudget
                        if fits then
                            current = candidate
                        else
                            if current ~= "" then lines[#lines + 1] = current end
                            current = word
                        end
                    end
                    if current ~= "" then lines[#lines + 1] = current end
                    return lines
                end

                menu.__nuzCompatHelpPage = math.max(1,
                    math.floor(tonumber(rememberedCompat.helpPage) or 1))
                menu.__nuzCompatHelpIndex = menu.index or 1
                local baseUpdate = menu.update
                menu.update = function(self, dt)
                    local before = self.index or 1
                    -- Select is the engine action mapped to keyboard Tab on
                    -- the default desktop bindings. It is safe to consume here
                    -- because MOD COMPAT rows are informational, not actions.
                    if self.game.input:wasPressed("select") then
                        local selected = items[self.index or 1]
                        local row = selected and selected.nuzlockeCompatRow
                        local help = compatRelationshipHelp(row)
                        local lines = compatWrapAll(help, 144)
                        local pages = math.max(1, math.ceil(#lines / 2))
                        self.__nuzCompatHelpPage =
                            ((self.__nuzCompatHelpPage or 1) % pages) + 1
                        rememberedCompat.index = self.index or 1
                        rememberedCompat.scroll = self.scroll or 0
                        rememberedCompat.helpPage = self.__nuzCompatHelpPage
                        return
                    end
                    local result = baseUpdate(self, dt)
                    local after = self.index or 1
                    if after ~= before then
                        self.__nuzCompatHelpPage = 1
                        self.__nuzCompatHelpIndex = after
                    end
                    rememberedCompat.index = self.index or 1
                    rememberedCompat.scroll = self.scroll or 0
                    rememberedCompat.helpPage = self.__nuzCompatHelpPage or 1
                    return result
                end

                menu.draw = function(self)
                    local Font = require("src.render.Font")
                    local Theme = require("src.ui.Theme")
                    Font.drawBox(0, 0, 20, 18)

                    local title = Strings("MOD COMPAT")
                    local titleWidth = type(Font.width) == "function"
                        and Font.width(title) or (#tostring(title) * 8)
                    local titleX = math.max(8, math.floor((160 - titleWidth) / 2))
                    Font.draw(title, titleX, 8)
                    Font.draw(title, titleX + 1, 8)

                    Font.draw(Strings("RULE"), 20, 24)
                    Font.draw(Strings("OWNER"), 94, 24)

                    local scroll = self.scroll or 0
                    local cursor = self.index or 1
                    local pageSize = self.rows or 4
                    for slot = 1, pageSize do
                        local index = scroll + slot
                        local item = items[index]
                        if not item then break end
                        local y = 32 + (slot - 1) * 13
                        local selected = index == cursor
                        if selected then
                            Font.drawCode(Theme.cursor, 8, y)
                        end
                        local label = compatFitMarquee(item.label, 66, selected)
                        local owner = compatFitMarquee(item.right, 58, selected)
                        Font.draw(label, 20, y)
                        Font.draw(owner, 94, y)
                    end

                    if scroll > 0 then
                        Font.draw(Strings("^"), 148, 30)
                    end
                    if scroll + pageSize < #items then
                        Font.drawCode(Theme.moreArrow or 0xEE, 148, 86)
                    end

                    Font.drawBox(0, 12, 20, 6)
                    local selectedItem = items[cursor]
                    local selectedRow = selectedItem
                        and selectedItem.nuzlockeCompatRow or nil
                    local help = compatRelationshipHelp(selectedRow)
                    local lines = compatWrapAll(help, 144)
                    local pages = math.max(1, math.ceil(#lines / 2))
                    local helpPage = math.max(1,
                        math.min(pages, self.__nuzCompatHelpPage or 1))
                    local first = (helpPage - 1) * 2 + 1
                    for i = 0, 1 do
                        local line = lines[first + i]
                        if not line then break end
                        Font.draw(line, 8, 104 + i * 10)
                    end
                    if pages > 1 then
                        Font.draw(Strings("SEL:%d/%d", helpPage, pages),
                            96, 132)
                    else
                        Font.draw(Strings("SELECT:INFO"), 72, 132)
                    end
                end

                menu.nuzlockeModernUiModel = function(self)
                    local cursor = self.index or 1
                    local modelRows = {}
                    for i, item in ipairs(items) do
                        modelRows[#modelRows + 1] = {
                            label = tostring(item.label or ""),
                            right = tostring(item.right or ""),
                            selected = i == cursor,
                        }
                    end
                    local selected = items[cursor]
                    return {
                        title = Strings("MOD COMPAT"),
                        columns = { Strings("RULE"), Strings("OWNER") },
                        rows = modelRows,
                        index = cursor,
                        scroll = self.scroll or 0,
                        details = (function()
                            local help = selected and compatRelationshipHelp(
                                selected.nuzlockeCompatRow) or ""
                            return tostring(help)
                        end)(),
                        detailPage = self.__nuzCompatHelpPage or 1,
                        footer = { Strings("SELECT/TAB: DETAIL PAGE"),
                            Strings("B: BACK") },
                    }
                end

                return menu
            end

            local rememberedCompat = uiRememberedScreen(game, "mod_compat")
            local self = {
                game = game, screenId = "NuzlockeModCompatScreen",
                isOpaque = true, scroll = math.max(0,
                    math.floor(tonumber(rememberedCompat.scroll) or 0)),
            }
            function self:update()
                if self.game.input:wasPressed("b") then
                    rememberedCompat.scroll = self.scroll or 0
                    self.game.stack:pop()
                    return
                end
                local rows = mod.exports.__beta26.compat21.surfaceRows(self.game)
                local maxScroll = math.max(0, #rows - 5)
                self.scroll = math.max(0, math.min(maxScroll, self.scroll or 0))
                if self.game.input:wasPressed("up") then
                    self.scroll = math.max(0, self.scroll - 1)
                elseif self.game.input:wasPressed("down") then
                    self.scroll = math.min(maxScroll, self.scroll + 1)
                end
                rememberedCompat.scroll = self.scroll or 0
            end
            function self:draw()
                local rows = mod.exports.__beta26.compat21.surfaceRows(self.game)
                if mod.exports.__beta26.runtimeIsGen2(self.game) then
                    local Chrome = require("src.ui.gen2.Chrome")
                    Chrome.clear()
                    Chrome.box(0, 0, 20, 18)
                    Chrome.print(Strings("MOD COMPAT"), 2, 1)
                    for slot = 1, 5 do
                        local row = rows[self.scroll + slot]
                        if not row then break end
                        local y = 3 + (slot - 1) * 2
                        Chrome.print(Strings(row.label), 2, y)
                        Chrome.print(Strings(row.owner), 2, y + 1)
                    end
                    Chrome.print(Strings("B:BACK"), 13, 16)
                    return
                end
                local Font = require("src.render.Font")
                local function compatFit(text, budget)
                    text = Strings(tostring(text or ""))
                    if type(Font.width) ~= "function"
                        or type(Font.split) ~= "function"
                        or type(Font.spansFitting) ~= "function"
                        or Font.width(text) <= budget then
                        return text
                    end
                    local spans = Font.split(text)
                    local visible = math.max(1,
                        Font.spansFitting(spans, budget))
                    local elapsed = (love.timer and love.timer.getTime
                        and love.timer.getTime()) or 0
                    local maxOffset = math.max(0, #spans - visible)
                    if maxOffset <= 0 then return text end
                    if elapsed < 3.0 then
                        return text:sub(1, spans[visible].to)
                    end
                    local step = math.floor((elapsed - 3.0) / 2.4)
                    local cycle = math.max(1, maxOffset * 2)
                    local phase = step % cycle
                    local offset = phase <= maxOffset and phase
                        or (cycle - phase)
                    local first = offset + 1
                    local last = math.min(#spans, first + visible - 1)
                    while last > first
                        and Font.width(text:sub(spans[first].from,
                            spans[last].to)) > budget do
                        last = last - 1
                    end
                    return text:sub(spans[first].from, spans[last].to)
                end
                Font.drawBox(0, 0, 20, 18)
                Font.draw(Strings("MOD COMPAT"), 16, 16)
                local labelX, ownerX = 16, 88
                local labelBudget, ownerBudget = 66, 56
                for slot = 1, 5 do
                    local row = rows[self.scroll + slot]
                    if not row then break end
                    local y = 28 + (slot - 1) * 16
                    Font.draw(compatFit(row.label, labelBudget), labelX, y)
                    Font.draw(compatFit(row.owner, ownerBudget), ownerX, y)
                end
                Font.draw(Strings("B:BACK"), 104, 120)
            end
            return self
        end,
    })

    -- Permanent Rule Seal is monotonic. Configuration UI can still be viewed,
    -- but no lifecycle/default pass may clear a lock once committed.
    local function permanentRuleLockSaveSet(key, value)
        local ok, result = pcall(mod.save.set, mod.save, key, value)
        if not ok then return false, "write_error:" .. tostring(result) end
        if result == false then return false, "store_rejected_write:" .. tostring(key) end
        return true
    end

    local function enforcePermanentRuleLock(payload)
        if saveBlocked() then return false, "save_blocked" end
        if mod.exports.__beta26.permanentRuleSealWip then
            -- Restore the historical reversible Rule Lock when an older save
            -- has rules_locked but no irreversible seal marker. Then clear the
            -- dormant Permanent Rule Seal's old effective key as before.
            if mod.save:get("rules_locked", false) == true
                and mod.save:get("rules_permanently_locked", false) ~= true then
                local okRule, ruleErr =
                    permanentRuleLockSaveSet("rule_lock", true)
                if not okRule then return false, ruleErr end
            end
            local okLocked, lockedErr =
                permanentRuleLockSaveSet("rules_locked", false)
            if not okLocked then return false, lockedErr end
            return true
        end
        local game = type(payload) == "table" and payload.game
            or getCurrentGame() or mod.game
        local sealed = mod.exports.__beta26.readPermanentRuleSeal(game)
        if sealed == true then
            -- Heal/migrate older saves that only had the mod.save marker by
            -- ensuring the durable playthrough mirror exists too. Persistence
            -- must be acknowledged before the semantic upgrade may succeed.
            local okPersist, persistErr =
                mod.exports.__beta26.persistPermanentRuleSeal(game)
            if okPersist ~= true then
                return false, "seal_persist:" .. tostring(persistErr)
            end
            local okLocked, lockedErr =
                permanentRuleLockSaveSet("rules_locked", true)
            if not okLocked then return false, lockedErr end
            local okPermanent, permanentErr =
                permanentRuleLockSaveSet("rules_permanently_locked", true)
            if not okPermanent then return false, permanentErr end
        end
        return true
    end
    mod.exports.__beta26.registerSaveUpgradeStep("semantic",
        "permanent_rule_lock_reconciliation", function(ctx)
            return enforcePermanentRuleLock(ctx)
        end)
    mod.events:on("game.ready", function(payload)
        local ok, detail = enforcePermanentRuleLock(payload)
        if ok == false and detail ~= "save_blocked"
            and type(mod.exports.__beta26.noteFeatureHealth) == "function" then
            mod.exports.__beta26.noteFeatureHealth(
                "permanent_rule_lock_reconciliation", "DEGRADED",
                tostring(detail), "permanent_rule_lock_reconciliation")
        end
    end)
  
    -- Forgiveness Token shop metadata is published beside the shop bridge above.
    mod.events:on("game.ready", function(payload)
        mod.exports.__beta26.attemptInstall("gen2.install_all", G2.installAll)
        pcall(G2.reconcileRandomStarterProvenance,
            type(payload) == "table" and payload.game or getCurrentGame() or mod.game)
    end)
    mod.events:on("save.loaded", function(payload)
        mod.exports.__beta26.attemptInstall("gen2.install_all", G2.installAll)
        pcall(G2.reconcileRandomStarterProvenance,
            type(payload) == "table" and payload.game or getCurrentGame() or mod.game)
    end)
    mod.events:on("save.created", function()
        -- Gold NEW GAME replaces the mod.save backing before Oak/Elm scripts
        -- run. Revalidate the native starter transaction wrapper at that exact
        -- lifecycle boundary instead of waiting for a later save.loaded.
        mod.exports.__beta26.attemptInstall("gen2.install_all", G2.installAll)
    end)
    end

  return true
end
