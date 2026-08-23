-- Module owner: BattleClauses
return function(mod, deps)
  deps = deps or {}
  local Strings = assert(deps.Strings, "battle_clauses requires Strings")
  local getCurrentGame = assert(deps.getCurrentGame, "battle_clauses requires getCurrentGame")
  local installOwnedMethodWrapper = assert(deps.installOwnedMethodWrapper,
      "battle_clauses requires installOwnedMethodWrapper")
  local unpackValues = table.unpack or unpack
  assert(type(unpackValues) == "function", "Nuzlocke requires Lua unpack support")
  local function packValues(...)
      return { n = select("#", ...), ... }
  end

  -- 2.6.35: retire an older Nuzlocke-owned direct wrapper before replacing
  -- its rule semantics. This is intentionally narrower than the installer:
  -- only unwrap when that exact recorded wrapper is still the live top-level
  -- method. The caller may retire multiple generations newest-to-oldest, which
  -- safely peels a 2.6.34 wrapper off a retained 2.6.33 wrapper without ever
  -- touching a different mod's live top-level function.
  local function retireOwnedMethodWrapper(container, sessionKey, method)
      if type(container) ~= "table" or type(sessionKey) ~= "string"
          or type(method) ~= "string" then return false end
      local session = container[sessionKey]
      if type(session) ~= "table" then return false end
      if container[method] == session.wrapper and type(session.previous) == "function" then
          container[method] = session.previous
      end
      container[sessionKey] = nil
      return true
  end

    ---------------------------------------------------------------------
    -- COMPETITIVE / STATUS BATTLE CLAUSES (2.6.15, expanded through 2.6.35)
    --
    -- These compose at the engine's existing effect/status/stat-stage seams
    -- rather than replacing turn resolution. Sleep/OHKO/Evasion retain their
    -- original symmetric clause semantics. Scoped status bans cover paralysis,
    -- confusion, sleep, poison/Toxic, burn, and freeze. Accuracy Drops and
    -- Other Stat Drops are independent stat-stage restrictions, while No Setup
    -- Moves covers positive stages. Flinch/Trap remain standalone scoped
    -- clauses. SELF means the player's side, ENEMY the opposing side, ALL both.
    -- Damaging moves keep their normal damage when only a secondary effect is
    -- suppressed.
    ---------------------------------------------------------------------
    mod.exports.__beta26.installBattleClauses = function()
        if mod.exports.__beta26.isSaveEditorSession() then
            return false, "not_applicable", "save-editor session"
        end

        local function clauseOn(key, game)
            game = game or getCurrentGame() or mod.game
            return mod.exports.__beta26.ruleActive(game, key) == true
        end

        local function scopeValue(key)
            local game = getCurrentGame() or mod.game
            if type(mod.exports.__beta26.shouldEnforceNuzlocke) == "function"
                and mod.exports.__beta26.shouldEnforceNuzlocke(game) ~= true then
                return 0
            end
            if mod.save:get("nuzlocke_enabled", true) ~= true then return 0 end
            return math.max(0, math.min(3,
                math.floor(tonumber(mod.save:get(key, 0)) or 0)))
        end

        local function effectiveStatusScope(childKey)
            local parent = scopeValue("status_move_scope")
            if parent ~= 0 then return parent end
            return scopeValue(childKey)
        end

        local function scopeBlocks(scope, side)
            return scope == 3
                or (scope == 1 and side == "player")
                or (scope == 2 and side == "enemy")
        end

        local function statusBlocks(childKey, side)
            return side ~= nil and scopeBlocks(effectiveStatusScope(childKey), side)
        end

        local function setupBlocks(side)
            return side ~= nil and scopeBlocks(scopeValue("setup_move_scope"), side)
        end

        local function scopedRuleBlocks(key, side)
            return side ~= nil and scopeBlocks(scopeValue(key), side)
        end

        local function sideTagFromRbyBattler(b)
            if not b then return nil end
            return b.isPlayer and "player" or "enemy"
        end

        local function rbyPartyForSide(battle, side)
            if type(battle) ~= "table" then return {} end
            if side == "player" then
                return (battle.game and battle.game.save and battle.game.save.party)
                    or battle.party or {}
            end
            return battle.enemyParty or {}
        end

        local function hasOtherClauseSleepRby(battle, attackerSide, targetMon)
            local targetSide = attackerSide == "player" and "enemy" or "player"
            for _, mon in ipairs(rbyPartyForSide(battle, targetSide) or {}) do
                if type(mon) == "table" and mon.status ~= "SLP" then
                    -- 2.6.38: provenance belongs to one sleep episode only.
                    -- Clear stale attribution as soon as an awake mon is seen.
                    mon.nuzlockeSleepClauseBy = nil
                end
                if mon ~= targetMon and type(mon) == "table"
                    and (tonumber(mon.hp) or 0) > 0
                    and mon.status == "SLP"
                    and mon.nuzlockeSleepClauseBy == attackerSide then
                    return true
                end
            end
            return false
        end

        local installed = false
        local healthMissing = {}
        local function requireSession(container, key, label)
            local session = type(container) == "table" and container[key] or nil
            if type(session) ~= "table" or type(session.wrapper) ~= "function" then
                healthMissing[#healthMissing + 1] = label
            end
        end
        do
            local ok, MoveEffects = pcall(require, "src.battle.MoveEffects")
            if ok and type(MoveEffects) == "table"
                and type(MoveEffects.RECORDS) == "table" then
                local sleep = MoveEffects.RECORDS.SLEEP_EFFECT
                if type(sleep) == "table" and type(sleep.run) == "function" then
                    installed = installOwnedMethodWrapper(
                        sleep, "__nuzlockeSleepClauseSession2615", "run",
                        function(previous)
                            return function(ctx, ...)
                                local game = getCurrentGame() or mod.game
                                if clauseOn("sleep_clause", game)
                                    and ctx and ctx.user and ctx.target
                                    and sideTagFromRbyBattler(ctx.user)
                                        ~= sideTagFromRbyBattler(ctx.target)
                                    and hasOtherClauseSleepRby(ctx.battle,
                                        sideTagFromRbyBattler(ctx.user),
                                        ctx.target.mon) then
                                    return { Strings("Sleep Clause blocked the move.") }
                                end
                                local beforeStatus = ctx and ctx.target
                                    and ctx.target.mon and ctx.target.mon.status or nil
                                local result = previous(ctx, ...)
                                if clauseOn("sleep_clause", game)
                                    and ctx and ctx.user and ctx.target
                                    and ctx.target.mon
                                    and beforeStatus ~= "SLP"
                                    and ctx.target.mon.status == "SLP" then
                                    ctx.target.mon.nuzlockeSleepClauseBy =
                                        sideTagFromRbyBattler(ctx.user)
                                end
                                return result
                            end
                        end) or installed
                end

                local heal = MoveEffects.RECORDS.HEAL_EFFECT
                if type(heal) == "table" and type(heal.run) == "function" then
                    installed = installOwnedMethodWrapper(
                        heal, "__nuzlockeSleepClauseRestSession2638", "run",
                        function(previous)
                            return function(ctx, ...)
                                if ctx and ctx.move and ctx.move.id == "REST"
                                    and ctx.user and ctx.user.mon then
                                    -- REST creates a new self-induced sleep episode
                                    -- and must never inherit opponent provenance.
                                    ctx.user.mon.nuzlockeSleepClauseBy = nil
                                end
                                return previous(ctx, ...)
                            end
                        end) or installed
                end

                local evasion = MoveEffects.RECORDS.EVASION_UP1_EFFECT
                if type(evasion) == "table" and type(evasion.run) == "function" then
                    installed = installOwnedMethodWrapper(
                        evasion, "__nuzlockeEvasionClauseSession2615", "run",
                        function(previous)
                            return function(ctx, ...)
                                if clauseOn("evasion_clause", getCurrentGame() or mod.game) then
                                    return { Strings("Evasion Clause blocked the boost.") }
                                end
                                return previous(ctx, ...)
                            end
                        end) or installed
                end

                local ohko = MoveEffects.RECORDS.OHKO_EFFECT
                if type(ohko) == "table" and type(ohko.gate) == "function" then
                    installed = installOwnedMethodWrapper(
                        ohko, "__nuzlockeOhkoClauseSession2615", "gate",
                        function(previous)
                            return function(ctx, ...)
                                if clauseOn("ohko_clause", getCurrentGame() or mod.game) then
                                    return false, Strings("OHKO Clause blocked the move.")
                                end
                                return previous(ctx, ...)
                            end
                        end) or installed
                end

                local function setupEffectId(id)
                    return id:match("^ATTACK_UP") ~= nil
                        or id:match("^DEFENSE_UP") ~= nil
                        or id:match("^SPEED_UP") ~= nil
                        or id:match("^SPECIAL_UP") ~= nil
                        or id:match("^ACCURACY_UP") ~= nil
                        or id:match("^EVASION_UP") ~= nil
                end

                local function otherStatDropEffectId(id)
                    return id:match("^ATTACK_DOWN") ~= nil
                        or id:match("^DEFENSE_DOWN") ~= nil
                        or id:match("^SPEED_DOWN") ~= nil
                        or id:match("^SPECIAL_DOWN") ~= nil
                        or id:match("^EVASION_DOWN") ~= nil
                end

                for id, record in pairs(MoveEffects.RECORDS) do
                    if type(id) == "string" and type(record) == "table"
                        and type(record.run) == "function" then
                        local childKey, message
                        if id:find("PARALYZE", 1, true) then
                            childKey = "status_paralysis_scope"
                            message = "Paralysis ban blocked the effect."
                        elseif id:find("CONFUSION", 1, true) then
                            childKey = "status_confusion_scope"
                            message = "Confusion ban blocked the effect."
                        elseif id == "SLEEP_EFFECT" then
                            childKey = "status_sleep_scope"
                            message = "Sleep ban blocked the effect."
                        elseif id:find("POISON", 1, true) or id == "TWINEEDLE_EFFECT" then
                            childKey = "status_poison_scope"
                            message = "Poison ban blocked the effect."
                        elseif id:find("BURN", 1, true) then
                            childKey = "status_burn_scope"
                            message = "Burn ban blocked the effect."
                        elseif id:find("FREEZE", 1, true) then
                            childKey = "status_freeze_scope"
                            message = "Freeze ban blocked the effect."
                        end
                        if childKey then
                            local scopedKey, scopedMessage = childKey, message
                            local owner = "__nuzlockeStatusScope2624_" .. id
                            if scopedKey == "status_burn_scope" then
                                -- 2.6.37: the Gen 1 burn-side-effect handler also owns
                                -- Fire-vs-Freeze defrost. Retire the old whole-record
                                -- blocker and suppress only actual burn application;
                                -- a Fire hit on a frozen target must still reach vanilla
                                -- so it can thaw before the burn roll.
                                retireOwnedMethodWrapper(record, owner, "run")
                                owner = "__nuzlockeBurnScope2637_" .. id
                            end
                            installed = installOwnedMethodWrapper(record, owner, "run",
                                function(previous)
                                    return function(ctx, ...)
                                        local side = ctx and sideTagFromRbyBattler(ctx.user)
                                        if statusBlocks(scopedKey, side) then
                                            if scopedKey == "status_burn_scope"
                                                and ctx and ctx.move and ctx.move.type == "FIRE"
                                                and ctx.target and ctx.target.mon
                                                and ctx.target.mon.status == "FRZ" then
                                                return previous(ctx, ...)
                                            end
                                            return { Strings(scopedMessage) }
                                        end
                                        return previous(ctx, ...)
                                    end
                                end) or installed
                        end
                        if id:find("ACCURACY_DOWN", 1, true) then
                            -- 2.6.35: Accuracy moved out of No Status Moves in 2.6.34.
                            -- On a module-table-preserving reload, 2.6.34 may have
                            -- wrapped the old 2.6.33 status-owned Accuracy closure.
                            -- Peel both known prior owners newest-to-oldest before
                            -- installing the clean independent owner.
                            retireOwnedMethodWrapper(record,
                                "__nuzlockeAccuracyScope2634_" .. id, "run")
                            retireOwnedMethodWrapper(record,
                                "__nuzlockeStatusScope2624_" .. id, "run")
                            local owner = "__nuzlockeAccuracyScope2635_" .. id
                            installed = installOwnedMethodWrapper(record, owner, "run",
                                function(previous)
                                    return function(ctx, ...)
                                        local side = ctx and sideTagFromRbyBattler(ctx.user)
                                        if scopedRuleBlocks("status_accuracy_scope", side) then
                                            return { Strings("Accuracy Drops blocked the drop.") }
                                        end
                                        return previous(ctx, ...)
                                    end
                                end) or installed
                        elseif otherStatDropEffectId(id) then
                            local owner = "__nuzlockeOtherStatDropScope2634_" .. id
                            installed = installOwnedMethodWrapper(record, owner, "run",
                                function(previous)
                                    return function(ctx, ...)
                                        local side = ctx and sideTagFromRbyBattler(ctx.user)
                                        if scopedRuleBlocks("other_stat_drop_scope", side) then
                                            return { Strings("Other Stat Drops blocked the drop.") }
                                        end
                                        return previous(ctx, ...)
                                    end
                                end) or installed
                        end
                        if id:find("FLINCH_SIDE_EFFECT", 1, true) then
                            local owner = "__nuzlockeFlinchScope2628_" .. id
                            installed = installOwnedMethodWrapper(record, owner, "run",
                                function(previous)
                                    return function(ctx, ...)
                                        local side = ctx and sideTagFromRbyBattler(ctx.user)
                                        local target = ctx and ctx.target
                                        local before = target and target.flinched == true
                                        local result = previous(ctx, ...)
                                        if scopedRuleBlocks("flinch_clause_scope", side)
                                            and target and before ~= true
                                            and target.flinched == true then
                                            target.flinched = nil
                                            return { Strings("Flinch Clause blocked the effect.") }
                                        end
                                        return result
                                    end
                                end) or installed
                        end
                        if setupEffectId(id) then
                            local owner = "__nuzlockeSetupScope2624_" .. id
                            installed = installOwnedMethodWrapper(record, owner, "run",
                                function(previous)
                                    return function(ctx, ...)
                                        local side = ctx and sideTagFromRbyBattler(ctx.user)
                                        if setupBlocks(side) then
                                            return { Strings("No Setup Moves blocked the boost.") }
                                        end
                                        return previous(ctx, ...)
                                    end
                                end) or installed
                        end
                    end
                end

                local trapping = MoveEffects.RECORDS.TRAPPING_EFFECT
                if type(trapping) == "table" then
                    if type(trapping.beforeAccuracy) == "function" then
                        installed = installOwnedMethodWrapper(
                            trapping, "__nuzlockeTrapScope2628Before", "beforeAccuracy",
                            function(previous)
                                return function(ctx, ...)
                                    local side = ctx and sideTagFromRbyBattler(ctx.user)
                                    if scopedRuleBlocks("trap_clause_scope", side) then
                                        return nil
                                    end
                                    return previous(ctx, ...)
                                end
                            end) or installed
                    end
                    if type(trapping.afterDamage) == "function" then
                        installed = installOwnedMethodWrapper(
                            trapping, "__nuzlockeTrapScope2628After", "afterDamage",
                            function(previous)
                                return function(ctx, ...)
                                    local side = ctx and sideTagFromRbyBattler(ctx.user)
                                    if scopedRuleBlocks("trap_clause_scope", side) then
                                        if ctx and type(ctx.say) == "function" then
                                            ctx.say(Strings("Trap Clause blocked the trapping effect."))
                                        end
                                        return nil
                                    end
                                    return previous(ctx, ...)
                                end
                            end) or installed
                    end
                end
                requireSession(sleep, "__nuzlockeSleepClauseSession2615", "rby.sleep")
                requireSession(heal, "__nuzlockeSleepClauseRestSession2638", "rby.rest")
                requireSession(evasion, "__nuzlockeEvasionClauseSession2615", "rby.evasion")
                requireSession(ohko, "__nuzlockeOhkoClauseSession2615", "rby.ohko")
            end
        end

        do
            local ok, Battle = pcall(require, "src.battle.gen2.Battle")
            if ok and type(Battle) == "table" then
                if type(Battle.applyStatus) == "function" then
                    installed = installOwnedMethodWrapper(
                        Battle, "__nuzlockeSleepClauseSession2615", "applyStatus",
                        function(previous)
                            return function(self, mon, status, source, ...)
                                local game = getCurrentGame() or mod.game
                                if status == "sleep" and source and mon
                                    and clauseOn("sleep_clause", game) then
                                    local sourceSide = type(self.sideOf) == "function"
                                        and self:sideOf(source) or nil
                                    local targetSide = type(self.sideOf) == "function"
                                        and self:sideOf(mon) or nil
                                    if sourceSide and targetSide
                                        and sourceSide ~= targetSide then
                                        local party = targetSide == "player"
                                            and (self.party or {}) or (self.enemyParty or {})
                                        for _, other in ipairs(party) do
                                            if type(other) == "table" and other.status ~= "sleep" then
                                                other.nuzlockeSleepClauseBy = nil
                                            end
                                            if other ~= mon and type(other) == "table"
                                                and (tonumber(other.hp) or 0) > 0
                                                and other.status == "sleep"
                                                and other.nuzlockeSleepClauseBy == sourceSide then
                                                if type(self.emit) == "function" then
                                                    self:emit({ kind = "message",
                                                        text = "Sleep Clause blocked the move." })
                                                end
                                                return false
                                            end
                                        end
                                    end
                                end
                                local applied = previous(self, mon, status, source, ...)
                                if applied and status == "sleep" and source and mon
                                    and clauseOn("sleep_clause", game) then
                                    local sourceSide = type(self.sideOf) == "function"
                                        and self:sideOf(source) or nil
                                    local targetSide = type(self.sideOf) == "function"
                                        and self:sideOf(mon) or nil
                                    if sourceSide and targetSide and sourceSide ~= targetSide then
                                        mon.nuzlockeSleepClauseBy = sourceSide
                                    elseif sourceSide and targetSide and sourceSide == targetSide then
                                        mon.nuzlockeSleepClauseBy = nil
                                    end
                                end
                                return applied
                            end
                        end) or installed

                    installed = installOwnedMethodWrapper(
                        Battle, "__nuzlockeStatusScopeSession2624", "applyStatus",
                        function(previous)
                            return function(self, mon, status, source, ...)
                                local childKey, message
                                if status == "paralyze" then
                                    childKey = "status_paralysis_scope"
                                    message = "Paralysis ban blocked the effect."
                                elseif status == "confuse" then
                                    childKey = "status_confusion_scope"
                                    message = "Confusion ban blocked the effect."
                                elseif status == "sleep" then
                                    childKey = "status_sleep_scope"
                                    message = "Sleep ban blocked the effect."
                                elseif status == "poison" or status == "toxic" then
                                    childKey = "status_poison_scope"
                                    message = "Poison ban blocked the effect."
                                elseif status == "burn" then
                                    childKey = "status_burn_scope"
                                    message = "Burn ban blocked the effect."
                                elseif status == "freeze" then
                                    childKey = "status_freeze_scope"
                                    message = "Freeze ban blocked the effect."
                                end
                                local sourceSide = source and type(self.sideOf) == "function"
                                    and self:sideOf(source) or nil
                                if childKey and statusBlocks(childKey, sourceSide) then
                                    if type(self.emit) == "function" then
                                        self:emit({ kind = "message", text = message })
                                    end
                                    return false
                                end
                                return previous(self, mon, status, source, ...)
                            end
                        end) or installed
                end

                -- 2.6.37: carry move-origin context through the generic Gen 2
                -- stat-stage seam. changeStage is also used by X Items, Berserk
                -- Gene, Rage, and other non-move mechanics, so rule code must not
                -- infer "setup move" merely from seeing a positive delta.
                if type(Battle.useMove) == "function" then
                    -- The older flinch/trap owner is installed above the 2.6.37
                    -- move-context owner. Peel it first, then retire the old
                    -- context; the flinch/trap owner is reinstalled later below.
                    retireOwnedMethodWrapper(Battle,
                        "__nuzlockeFlinchTrapScopesSession2628", "useMove")
                    retireOwnedMethodWrapper(Battle,
                        "__nuzlockeMoveStageContextSession2637", "useMove")
                    installed = installOwnedMethodWrapper(
                        Battle, "__nuzlockeMoveStageContextSession2638", "useMove",
                        function(previous)
                            return function(self, attacker, defender, moveId, ...)
                                if moveId == "REST" and type(attacker) == "table" then
                                    -- Gen 2 REST writes sleep directly rather than
                                    -- routing through applyStatus(). New self-sleep
                                    -- must not inherit an older opponent marker.
                                    attacker.nuzlockeSleepClauseBy = nil
                                end
                                local prior = self.__nuzlockeMoveStageContext
                                self.__nuzlockeMoveStageContext = {
                                    source = attacker,
                                    target = defender,
                                    moveId = moveId,
                                }
                                local packed = packValues(pcall(previous,
                                    self, attacker, defender, moveId, ...))
                                self.__nuzlockeMoveStageContext = prior
                                if not packed[1] then error(packed[2], 0) end
                                return unpackValues(packed, 2, packed.n)
                            end
                        end) or installed
                end

                if type(Battle.changeStage) == "function" then
                    -- Retire 2.6.36's generic positive-stage wrapper BEFORE
                    -- composing any current changeStage wrappers. On a retained
                    -- module table, installing Evasion Clause first would place a
                    -- new wrapper above the stale owner and make it impossible to
                    -- peel safely by identity.
                    retireOwnedMethodWrapper(Battle,
                        "__nuzlockeSetupScopeSession2624", "changeStage")
                    retireOwnedMethodWrapper(Battle,
                        "__nuzlockeMoveStageScopesSession2637", "changeStage")
                    installed = installOwnedMethodWrapper(
                        Battle, "__nuzlockeEvasionClauseSession2615", "changeStage",
                        function(previous)
                            return function(self, target, stat, stages, ...)
                                if stat == "evasion" and (tonumber(stages) or 0) > 0
                                    and clauseOn("evasion_clause", getCurrentGame() or mod.game) then
                                    if type(self.emit) == "function" then
                                        self:emit({ kind = "message",
                                            text = "Evasion Clause blocked the boost." })
                                    end
                                    return nil
                                end
                                return previous(self, target, stat, stages, ...)
                            end
                        end) or installed

                    installed = installOwnedMethodWrapper(
                        Battle, "__nuzlockeMoveStageScopesSession2638", "changeStage",
                        function(previous)
                            return function(self, target, stat, stages, ...)
                                local delta = tonumber(stages) or 0
                                local context = self.__nuzlockeMoveStageContext
                                local source = context and context.source or nil
                                local sourceSide = source and type(self.sideOf) == "function"
                                    and self:sideOf(source) or nil
                                if context and source == target and delta > 0
                                    and setupBlocks(sourceSide) then
                                    if type(self.emit) == "function" then
                                        self:emit({ kind = "message",
                                            text = "No Setup Moves blocked the boost." })
                                    end
                                    return nil
                                end
                                -- Ordinary foe-directed drops use
                                -- changeStageAgainstMist below. This catches the
                                -- move-origin self-drop family (notably non-Ghost
                                -- Curse's Speed -1) without treating passive/item
                                -- penalties as Other Stat Drops.
                                if context and source == target and delta < 0
                                    and stat ~= "accuracy"
                                    and scopedRuleBlocks("other_stat_drop_scope",
                                        sourceSide) then
                                    if type(self.emit) == "function" then
                                        self:emit({ kind = "message",
                                            text = "Other Stat Drops blocked the drop." })
                                    end
                                    return nil
                                end
                                return previous(self, target, stat, stages, ...)
                            end
                        end) or installed
                end

                if type(Battle.changeStageAgainstMist) == "function" then
                    -- 2.6.35: the 2.6.34 combined stat-drop wrapper can itself
                    -- sit above 2.6.33's Accuracy-as-status wrapper after a hot
                    -- reload. Remove both historical owners in stack order, then
                    -- install one clean 2.6.35 combined stat-drop wrapper.
                    retireOwnedMethodWrapper(Battle,
                        "__nuzlockeStatDropScopesSession2634",
                        "changeStageAgainstMist")
                    retireOwnedMethodWrapper(Battle,
                        "__nuzlockeAccuracyScopeSession2624",
                        "changeStageAgainstMist")
                    installed = installOwnedMethodWrapper(
                        Battle, "__nuzlockeStatDropScopesSession2635",
                        "changeStageAgainstMist",
                        function(previous)
                            return function(self, attacker, target, stat, stages, ...)
                                local side = attacker and type(self.sideOf) == "function"
                                    and self:sideOf(attacker) or nil
                                if (tonumber(stages) or 0) < 0 then
                                    if stat == "accuracy"
                                        and scopedRuleBlocks("status_accuracy_scope", side) then
                                        if type(self.emit) == "function" then
                                            self:emit({ kind = "message",
                                                text = "Accuracy Drops blocked the drop." })
                                        end
                                        return false
                                    elseif stat ~= "accuracy"
                                        and scopedRuleBlocks("other_stat_drop_scope", side) then
                                        if type(self.emit) == "function" then
                                            self:emit({ kind = "message",
                                                text = "Other Stat Drops blocked the drop." })
                                        end
                                        return false
                                    end
                                end
                                return previous(self, attacker, target, stat, stages, ...)
                            end
                        end) or installed
                end

                if type(Battle.useMove) == "function" then
                    installed = installOwnedMethodWrapper(
                        Battle, "__nuzlockeFlinchTrapScopesSession2628", "useMove",
                        function(previous)
                            return function(self, attacker, defender, moveId, ...)
                                local side = attacker and type(self.sideOf) == "function"
                                    and self:sideOf(attacker) or nil
                                local state = defender and type(self.volatile) == "function"
                                    and self:volatile(defender) or nil
                                local beforeFlinch = state and state.flinched == true
                                local beforeWrapCount = state and state.wrapCount or nil
                                local beforeWrapMove = state and state.wrapMove or nil
                                local beforeWrapMoveId = state and state.wrapMoveId or nil
                                local eventStart = type(self.events) == "table"
                                    and #self.events or 0
                                local result = previous(self, attacker, defender, moveId, ...)
                                state = defender and type(self.volatile) == "function"
                                    and self:volatile(defender) or state

                                if state and scopedRuleBlocks("flinch_clause_scope", side)
                                    and beforeFlinch ~= true and state.flinched == true then
                                    state.flinched = nil
                                    if type(self.emit) == "function" then
                                        self:emit({ kind = "message",
                                            text = "Flinch Clause blocked the effect." })
                                    end
                                end

                                if state and scopedRuleBlocks("trap_clause_scope", side)
                                    and beforeWrapCount == nil and state.wrapCount ~= nil then
                                    state.wrapCount = beforeWrapCount
                                    state.wrapMove = beforeWrapMove
                                    state.wrapMoveId = beforeWrapMoveId
                                    -- EFFECT_TRAP_TARGET emits its trap line after the
                                    -- connected hit. Remove only that newly-added terminal
                                    -- message before replacing it with the clause line.
                                    if type(self.events) == "table" then
                                        for i = #self.events, eventStart + 1, -1 do
                                            local ev = self.events[i]
                                            if type(ev) == "table" and ev.kind == "message" then
                                                local text = tostring(ev.text or ""):lower()
                                                if text:find("trapped", 1, true)
                                                    or text:find("wrapped", 1, true)
                                                    or text:find("squeezed", 1, true)
                                                    or text:find("clamped", 1, true)
                                                    or text:find("bound", 1, true) then
                                                    table.remove(self.events, i)
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    if type(self.emit) == "function" then
                                        self:emit({ kind = "message",
                                            text = "Trap Clause blocked the trapping effect." })
                                    end
                                end
                                return result
                            end
                        end) or installed
                end

                local ohko = type(Battle.MOVE_EFFECT_RECORDS) == "table"
                    and Battle.MOVE_EFFECT_RECORDS.EFFECT_OHKO or nil
                if type(ohko) == "table" and type(ohko.run) == "function" then
                    installed = installOwnedMethodWrapper(
                        ohko, "__nuzlockeOhkoClauseSession2615", "run",
                        function(previous)
                            return function(self, attacker, defender, def, ...)
                                if clauseOn("ohko_clause", getCurrentGame() or mod.game) then
                                    if type(self.markMissed) == "function" then self:markMissed() end
                                    if type(self.emit) == "function" then
                                        self:emit({ kind = "message",
                                            text = "OHKO Clause blocked the move." })
                                    end
                                    return nil
                                end
                                return previous(self, attacker, defender, def, ...)
                            end
                        end) or installed
                end
                requireSession(Battle, "__nuzlockeSleepClauseSession2615", "gen2.sleep")
                requireSession(Battle, "__nuzlockeStatusScopeSession2624", "gen2.status")
                requireSession(Battle, "__nuzlockeMoveStageContextSession2638", "gen2.move_context")
                requireSession(Battle, "__nuzlockeEvasionClauseSession2615", "gen2.evasion")
                requireSession(Battle, "__nuzlockeMoveStageScopesSession2638", "gen2.setup")
                requireSession(Battle, "__nuzlockeStatDropScopesSession2635", "gen2.stat_drops")
                requireSession(Battle, "__nuzlockeFlinchTrapScopesSession2628", "gen2.flinch_trap")
                requireSession(ohko, "__nuzlockeOhkoClauseSession2615", "gen2.ohko")
            end
        end
        if #healthMissing > 0 then
            return false, "missing_clause_hooks:" .. table.concat(healthMissing, ",")
        end
        return installed
    end

    mod.exports.__beta26.attemptInstall("battle.clauses", mod.exports.__beta26.installBattleClauses)
    mod.events:on("game.ready", function()
        mod.exports.__beta26.attemptInstall("battle.clauses", mod.exports.__beta26.installBattleClauses)
    end)
    mod.events:on("save.loaded", function()
        mod.exports.__beta26.attemptInstall("battle.clauses", mod.exports.__beta26.installBattleClauses)
    end)
    mod.events:on("mods.loaded", function()
        mod.exports.__beta26.attemptInstall("battle.clauses", mod.exports.__beta26.installBattleClauses)
    end)

    ---------------------------------------------------------------------

  return true
end
