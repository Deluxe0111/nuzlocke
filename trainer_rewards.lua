-- Trainer reward / economy compatibility module.
--
-- Explicitly approved as the second Lua split in 2.0.0-beta.30.0.0.16.
-- This module owns the cohesive trainer-reward subsystem:
--   * trainer wallet snapshot and Trainer Money multiplier
--   * Forgiveness Token counters, Gym-trainer rewards, and shop Bag bridge
--   * trainer identity normalization used by those rewards
--   * Gym / Elite Four / Champion progression bookkeeping
--
-- It does NOT own core battle rules, encounter legality, faint/death handling,
-- tracker state, randomizers, title setup, general provider policy, or Gold
-- gameplay systems.
--
-- It is loaded through Gen1Recomp's documented sandbox-safe
-- load(mod:read(...)) multi-file pattern.

local M = {}

local TRAINER_MONEY_PCTS = {
    [0]=0, [1]=25, [2]=50, [3]=75, [4]=100,
    [5]=150, [6]=200, [7]=300, [8]=500,
}
local trainerMoneyStart = setmetatable({}, { __mode = "k" })
local mod
local d

local function checkedSaveSet(key, value)
    local ok, result = pcall(mod.save.set, mod.save, key, value)
    if not ok then return false, tostring(result) end
    if result == false then return false, "store_rejected_write" end
    return true
end

local function runHistoryHasDedupe(game, dedupe)
    dedupe = tostring(dedupe or "")
    if dedupe == "" then return false end
    local history = d and d.runHistory
    if type(history) ~= "table" or type(history.hasDedupe) ~= "function" then
        return nil, "run_history_query_unavailable"
    end
    local ok, present, detail = pcall(history.hasDedupe, game, dedupe)
    if not ok then return nil, "run_history_query_error:" .. tostring(present) end
    if present == nil then return nil, tostring(detail or "run_history_unavailable") end
    return present == true, detail
end

-- 2.5.57: executable active()-guard contracts for gameplay-state mutation.
-- The recurring failure class was a new reward/progression mutator being added
-- without the master-rule enforcement guard. Keep the contract beside the
-- subsystem it protects, and make intentional OFF-state persistence explicit.
local ACTIVE_GUARD_CONTRACTS = {
    rememberWallet = { guard = "d.active(", mutation = "trainerMoneyStart[battle] =", policy = "enforcement" },
    scaleTrainerMoney = { guard = "d.active(", mutation = "setTrainerWalletValue(", policy = "enforcement" },
    awardGymLeaderForgiveness = { guard = "d.active(", mutation = "TX.execute(", policy = "enforcement" },
    recordLeagueProgression = {
        guard = "d.canWriteNuzlockeSave(",
        mutation = "commitLeagueProgression(",
        policy = "passive_progression",
        exception = "badge/E4/Champion sync is intentionally allowed while the master rule is off",
    },
    forgivenessTokens = {
        guard = "d.canWriteNuzlockeSave(",
        mutation = "mod.save:set(\"route_forgiveness_tokens\"",
        policy = "compatibility_mirror",
        exception = "inventory-to-save token mirror is maintenance, not a gameplay award",
    },
    setForgivenessTokens = {
        guard = "d.canWriteNuzlockeSave(",
        mutation = "mod.save:set(\"route_forgiveness_tokens\"",
        policy = "compatibility_mirror",
        exception = "shared token setter is also used by save/inventory reconciliation",
    },
    syncForgivenessTokenItem = {
        guard = "game and game.save",
        mutation = "M.ensureForgivenessTokenItem(game)",
        policy = "compatibility_mirror",
        exception = "save/inventory reconciliation must remain available while the master rule is off",
    },
}

local function contractFunctionSource(source, name)
    if type(source) ~= "string" then return nil end
    local needle = "function M." .. tostring(name) .. "("
    local first = source:find(needle, 1, true)
    if not first then return nil end
    local nextFn = source:find("\nfunction M.", first + #needle, true)
    return source:sub(first, nextFn and (nextFn - 1) or #source)
end

function M.activeGuardAudit(source)
    local report = { ok = true, checked = 0, failures = {}, contracts = {} }
    local blocks = {}
    if type(source) == "string" then
        for name in source:gmatch("function M%.([%w_]+)%s*%(") do
            blocks[name] = contractFunctionSource(source, name)
        end
    end

    -- Any exported trainer-reward function that directly writes Nuzlocke save
    -- state or the trainer wallet must have a contract. This is the piece that
    -- catches a newly-added mutation path even when the author forgets to add
    -- it to ACTIVE_GUARD_CONTRACTS.
    for name, body in pairs(blocks) do
        local mutates = name ~= "activeGuardAudit" and (
            body:find("mod.save:set(", 1, true)
            or body:find("setTrainerWalletValue(", 1, true)
            or body:find("save.inventory[", 1, true))
        if mutates and ACTIVE_GUARD_CONTRACTS[name] == nil then
            report.ok = false
            report.failures[#report.failures + 1] = name
                .. ":uncontracted player-state mutation"
        end
    end

    for name, contract in pairs(ACTIVE_GUARD_CONTRACTS) do
        local body = blocks[name] or contractFunctionSource(source, name)
        local present = body ~= nil
        local guardPos = present and body:find(contract.guard, 1, true) or nil
        local mutationPos = present and contract.mutation
            and body:find(contract.mutation, 1, true) or nil
        local guarded = guardPos ~= nil
            and (contract.mutation == nil or (mutationPos ~= nil and guardPos < mutationPos))
        local row = {
            name = name,
            policy = contract.policy,
            guard = contract.guard,
            mutation = contract.mutation,
            exception = contract.exception,
            present = present,
            guarded = guarded,
        }
        report.contracts[#report.contracts + 1] = row
        report.checked = report.checked + 1
        if not present or not guarded then
            report.ok = false
            local reason = not present and "function missing"
                or not guardPos and ("missing " .. contract.guard)
                or not mutationPos and ("mutation marker missing " .. tostring(contract.mutation))
                or "guard occurs after mutation"
            report.failures[#report.failures + 1] = name .. ":" .. reason
        end
    end
    table.sort(report.contracts, function(a, b) return a.name < b.name end)
    table.sort(report.failures)
    return report
end

local function trainerWalletValue(save)
    if type(save) ~= "table" then return nil end
    if tonumber(save.money) ~= nil then
        return math.floor(tonumber(save.money))
    end
    if type(save.player) == "table"
        and tonumber(save.player.money) ~= nil then
        return math.floor(tonumber(save.player.money))
    end
    return nil
end

local function trainerWalletCeiling(save)
    if type(save) ~= "table" then return 999999 end
    local player = type(save.player) == "table" and save.player or nil
    local candidates = {
        { save, "maxMoney" }, { save, "moneyMax" }, { save, "walletCap" },
        { player, "maxMoney" }, { player, "moneyMax" }, { player, "walletCap" },
    }
    for _, candidate in ipairs(candidates) do
        local owner, key = candidate[1], candidate[2]
        local cap = owner and tonumber(owner[key]) or nil
        if cap and cap == cap and cap ~= math.huge and cap ~= -math.huge
            and cap >= 0 then
            return math.floor(cap)
        end
    end
    return math.max(999999, trainerWalletValue(save) or 0)
end

local function setTrainerWalletValue(save, value)
    if type(save) ~= "table" then return false end
    value = math.max(0, math.min(trainerWalletCeiling(save),
        math.floor(tonumber(value) or 0)))
    if tonumber(save.money) ~= nil then
        save.money = value
        return true
    end
    if type(save.player) == "table"
        and tonumber(save.player.money) ~= nil then
        save.player.money = value
        return true
    end
    return false
end

local function compactTrainerIdentity(value)
    return tostring(value or ""):upper():gsub("[^A-Z0-9]", "")
end

-- 2.5.21: reward recognition and league progression must use the same
-- trainer identity surface. Gen 1 primarily exposes oppClass, while Gold and
-- compatibility providers may carry classId/class on battle.trainer instead.
-- Normalize each semantic field once so sibling systems cannot drift between
-- id/name-only and id/class/name matching.
local function trainerIdentityKeys(battle)
    local trainer = battle and battle.trainer
    local function firstKey(...)
        for i = 1, select("#", ...) do
            local key = compactTrainerIdentity(select(i, ...))
            if key ~= "" then return key end
        end
        return ""
    end
    return {
        id = firstKey(
            trainer and trainer.id,
            battle and battle.trainerId,
            battle and battle.opponentId),
        class = firstKey(
            battle and battle.oppClass,
            battle and battle.trainerClass,
            battle and battle.opponentClass,
            trainer and trainer.classId,
            trainer and trainer.class),
        name = firstKey(
            trainer and trainer.name,
            battle and battle.trainerName,
            battle and battle.opponentName),
    }
end

local function trainerIdentityContains(identity, target)
    local targetKey = compactTrainerIdentity(target)
    if targetKey == "" then return false end
    return identity.id:find(targetKey, 1, true) ~= nil
        or identity.class:find(targetKey, 1, true) ~= nil
        or identity.name:find(targetKey, 1, true) ~= nil
end

local function trainerIdentityEquals(identity, target)
    local targetKey = compactTrainerIdentity(target)
    if targetKey == "" then return false end
    return identity.id == targetKey
        or identity.class == targetKey
        or identity.name == targetKey
end

local function trainerIdentityForReward(battle)
    local identity = trainerIdentityKeys(battle)
    -- Normalize semantic fields independently, then join them. The reward
    -- ledger uses exact keys, so the boundaries must survive normalization.
    return identity.id .. ":" .. identity.class .. ":" .. identity.name
end

local function trainerMatchesLeader(battle, leader)
    return trainerIdentityContains(trainerIdentityKeys(battle), leader)
end

function M.forgivenessEnabled(game, battle)
    game = game or d.getCurrentGame()
    return d.shouldEnforceNuzlocke(game, battle)
        and math.floor(tonumber(
            mod.save:get("route_forgiveness", 0)) or 0) > 0
end

-- 2.5.40: Forgiveness Tokens are real inventory items, not synthetic Mart
-- stock. Keep the historical mod.save counter as a compatibility mirror so
-- existing API consumers and saves continue to work, but the carried item is
-- the player-facing source of truth whenever a live save exists.
function M.ensureForgivenessTokenItem(game)
    game = game or d.getCurrentGame()
    if not (game and game.data) then return false end
    game.data.items = game.data.items or {}
    local id = mod.exports.__beta26.forgivenessTokenItemId
    local def = game.data.items[id]
    if type(def) ~= "table" then
        def = {}
        game.data.items[id] = def
    end
    def.id = id
    def.name = d.Strings("F. TOKEN")
    def.price = 0
    def.description = d.Strings(
        "Spend to reroll a failed encounter or revive one fallen Pokemon.")
    -- R/B/Y respects keyItem for TOSS protection. Gold uses the shared flat
    -- inventory plus pocket metadata; ITEM keeps the quantity visible while
    -- canToss=false removes GIVE/TOSS from its submenu.
    def.keyItem = true
    def.tossable = false
    def.canToss = false
    def.canSelect = false
    def.pocket = "ITEM"
    def.fieldMenu = "ITEMMENU_NOUSE"
    def.battleMenu = "ITEMMENU_NOUSE"
    return true
end

function M.forgivenessTokens(game)
    game = game or d.getCurrentGame()
    local save = game and game.save
    local id = mod.exports.__beta26.forgivenessTokenItemId
    local inventory = save and save.inventory
    if type(inventory) == "table" and inventory[id] ~= nil then
        local raw = math.floor(tonumber(inventory[id]) or 0)
        local count = math.max(0, math.min(99, raw))
        local mirrored = math.max(0, math.min(99, math.floor(tonumber(
            mod.save:get("route_forgiveness_tokens", 0)) or 0)))
        if d.canWriteNuzlockeSave(game)
            and (raw ~= count or count ~= mirrored) then
            -- Normalize the authoritative inventory source as well as its
            -- compatibility mirror. This guarantees Gameplay Transaction
            -- payloads can never begin outside the engine's 99-stack ceiling.
            M.setForgivenessTokens(count)
        end
        return count
    end
    local rawMirror = math.floor(tonumber(
        mod.save:get("route_forgiveness_tokens", 0)) or 0)
    local count = math.max(0, math.min(99, rawMirror))
    if rawMirror ~= count and d.canWriteNuzlockeSave(game) then
        mod.save:set("route_forgiveness_tokens", count)
    end
    return count
end

function M.setForgivenessTokens(n)
    local game = d.getCurrentGame()
    if not d.canWriteNuzlockeSave(game) then return false end
    n = math.max(0, math.min(99, math.floor(tonumber(n) or 0)))
    mod.save:set("route_forgiveness_tokens", n)
    local save = game and game.save
    if not (save and type(save.inventory) == "table") then return true end
    M.ensureForgivenessTokenItem(game)
    local id = mod.exports.__beta26.forgivenessTokenItemId
    if n <= 0 then
        save.inventory[id] = nil
        local order = save.bagOrder
        if type(order) == "table" then
            for i = #order, 1, -1 do
                if order[i] == id then table.remove(order, i) end
            end
        end
        return true
    end
    -- Gym rewards are guaranteed challenge rewards. They must not disappear
    -- merely because the ordinary Bag/ITEM pocket is at its native slot cap.
    -- The item still obeys the engine's 99-stack ceiling above.
    save.inventory[id] = n
    local okBag, Bag = pcall(require, "src.inventory.Bag")
    if okBag and type(Bag) == "table" and type(Bag.order) == "function" then
        pcall(Bag.order, save, game and game.data)
    end
    return true
end

function M.syncForgivenessTokenItem(game)
    game = game or d.getCurrentGame()
    if not (game and game.save and type(game.save.inventory) == "table") then
        return false
    end
    M.ensureForgivenessTokenItem(game)
    local id = mod.exports.__beta26.forgivenessTokenItemId
    local inventoryCount = tonumber(game.save.inventory[id])
    local legacy = math.max(0, math.min(99, math.floor(tonumber(
        mod.save:get("route_forgiveness_tokens", 0)) or 0)))
    if inventoryCount == nil then
        if legacy > 0 then return M.setForgivenessTokens(legacy) end
        return true
    end
    inventoryCount = math.max(0, math.min(99, math.floor(inventoryCount)))
    if inventoryCount ~= legacy then
        mod.save:set("route_forgiveness_tokens", inventoryCount)
    end
    return true
end

function M.rememberWallet(game, battle)
    if not battle or not game or not game.save
        or not d.active(game, battle)
        or not d.isTrainerBattle(battle) then
        return false
    end
    local wallet = trainerWalletValue(game.save)
    if wallet == nil then return false end
    trainerMoneyStart[battle] = wallet
    return true
end

function M.scaleTrainerMoney(battle, result)
    local start = trainerMoneyStart[battle]
    trainerMoneyStart[battle] = nil
    if result ~= "win" or start == nil or not battle
        or not d.isTrainerBattle(battle) then
        return false
    end

    local game = battle.game or d.getCurrentGame()
    if not d.active(game, battle) then return false end
    local save = game and game.save
    if not save then return false end

    local now = trainerWalletValue(save)
    if now == nil then return false end
    local gained = math.max(0, now - start)
    if gained <= 0 then return false end

    -- If an active economy provider owns Trainer Money, its final payout is
    -- authoritative. Do not rewrite the wallet at all; this avoids stacking a
    -- stale Nuzlocke multiplier on top of the provider's economy result.
    if d.externalRuleDelegation
        and d.externalRuleDelegation("trainer_money_multiplier", game) then
        return false
    end

    local idx = math.max(0, math.min(8,
        math.floor(tonumber(mod.save:get(
            "trainer_money_multiplier", 4)) or 4)))
    local pct = TRAINER_MONEY_PCTS[idx] or 100
    local desired = d.scalePercentFloor(gained, pct)
    setTrainerWalletValue(save, start + desired)

    if idx ~= 4 and game then
        local t1, t2, t3 = d.worldRuleTriplet(
            game, "trainer_money_multiplier")
        d.worldMechanic(game,
            "trainer_money:" .. tostring(idx), t1, t2, t3)
    end
    return true
end

function M.awardGymLeaderForgiveness(battle, result)
    -- 2.4.6: permanent Gym rewards require a real active battle.
    local game = battle and (battle.game or d.getCurrentGame()) or d.getCurrentGame()
    if not d.active(game, battle) then return false end
    if result ~= "win" or not M.forgivenessEnabled(game, battle) or not battle
        or not d.isTrainerBattle(battle) then
        return false
    end

    local game = battle.game or d.getCurrentGame()
    local mapId = game and game.overworld and game.overworld.map
        and game.overworld.map.id
        or game and game.save and game.save.player
        and game.save.player.map
    local leader = d.gymLeaderForMap
        and d.gymLeaderForMap(mapId, game)

    -- A Gym reward belongs to the Leader only. Ordinary Gym Trainers never
    -- mint Forgiveness Tokens. Unknown/foreign Gym identity fails closed for
    -- the reward rather than accidentally paying a normal trainer.
    if not leader or not trainerMatchesLeader(battle, leader) then
        return false
    end

    -- One award per defeated Gym Leader, permanently. Use a semantic leader
    -- key instead of trainer party identity so rematches/providers cannot
    -- generate a second reward for the same Gym.
    local ledger = mod.save:get(
        "route_forgiveness_gym_leaders", {})
    if type(ledger) ~= "table" then ledger = {} end
    local key = compactTrainerIdentity(leader)
    if key == "" or ledger[key] then return false end

    local TX = d.GameplayTransactions
    if type(TX) ~= "table" or type(TX.nextSequence) ~= "function"
        or type(TX.execute) ~= "function" then
        return false
    end
    local beforeTokens = M.forgivenessTokens()
    local attempt, attemptErr = TX.nextSequence("forgiveness_gym_award_v1")
    if attempt == nil then return false end
    local txnId = table.concat({ "forgiveness_gym_award", "v1", key,
        tostring(attempt) }, ":")
    local committed = TX.execute(txnId, "forgiveness_gym_award_v1", {
        leader_key = key,
        leader = tostring(leader),
        map = mapId,
        before_tokens = beforeTokens,
        history_dedupe = "forgiveness:gym:" .. key,
    })
    if committed ~= true then return false end
    if game then
        pcall(d.pushWorldText, game,
            d.worldRuleText(game, "route_forgiveness_award"))
    end
    return true
end

local LEAGUE_PROGRESSION_TX_HANDLER = {
    probe = function(payload)
        local mode = tostring(payload and payload.storage_mode or "table")
        local key = tostring(payload and payload.entry_key or "")
        local storageKey = tostring(payload and payload.storage_key or "")
        if storageKey == "" then return "unknown", "missing_storage_key" end
        local progressed = false
        if mode == "boolean" then
            progressed = mod.save:get(storageKey, false) == true
        else
            local state = mod.save:get(storageKey, {})
            progressed = type(state) == "table" and key ~= "" and state[key] == true
        end
        local game = d.getCurrentGame() or mod.game
        local historyRequired = payload and payload.history_required == true
        local badgeOk, completionOk = true, true
        if historyRequired and payload.badge_dedupe then
            badgeOk = runHistoryHasDedupe(game, payload.badge_dedupe)
            if badgeOk == nil then return "unknown", "badge_history_unavailable" end
        end
        if historyRequired and payload.completion_dedupe then
            completionOk = runHistoryHasDedupe(game, payload.completion_dedupe)
            if completionOk == nil then return "unknown", "completion_history_unavailable" end
        end
        if progressed and badgeOk and completionOk then return "applied" end
        return "not_applied"
    end,
    perform = function(payload)
        local mode = tostring(payload and payload.storage_mode or "table")
        local key = tostring(payload and payload.entry_key or "")
        local storageKey = tostring(payload and payload.storage_key or "")
        if storageKey == "" then return false, "missing_storage_key" end
        if mode == "boolean" then
            if mod.save:get(storageKey, false) ~= true then
                local okWrite, writeErr = checkedSaveSet(storageKey, true)
                if not okWrite then return false, "progress_write:" .. tostring(writeErr) end
            end
        else
            if key == "" then return false, "missing_entry_key" end
            local state = mod.save:get(storageKey, {})
            if type(state) ~= "table" then state = {} end
            if state[key] ~= true then
                state[key] = true
                local okWrite, writeErr = checkedSaveSet(storageKey, state)
                if not okWrite then return false, "progress_write:" .. tostring(writeErr) end
            end
        end
        if payload and payload.history_required == true then
            local history = d.runHistory
            local game = d.getCurrentGame() or mod.game
            if type(history) ~= "table" then return false, "run_history_unavailable" end
            if payload.badge_dedupe then
                local present, presentErr = runHistoryHasDedupe(game, payload.badge_dedupe)
                if present == nil then return false, presentErr end
                if not present then
                    if type(history.recordBadge) ~= "function" then return false, "badge_history_unavailable" end
                    local ok, result, detail = pcall(history.recordBadge, game,
                        payload.badge_name or key, {
                            leader = payload.leader or key,
                            region = payload.region,
                            dedupe = payload.badge_dedupe,
                        })
                    if not ok then return false, "badge_history_error:" .. tostring(result) end
                    if result ~= true and tostring(detail or "") ~= "duplicate" then
                        return false, "badge_history_rejected:" .. tostring(detail or result)
                    end
                end
            end
            if payload.completion_dedupe then
                local present, presentErr = runHistoryHasDedupe(game, payload.completion_dedupe)
                if present == nil then return false, presentErr end
                if not present then
                    if type(history.recordCompleted) ~= "function" then return false, "completion_history_unavailable" end
                    local ok, result, detail = pcall(history.recordCompleted, game, {
                        target = payload.completion_target,
                        phase = payload.completion_phase,
                        dedupe = payload.completion_dedupe,
                    })
                    if not ok then return false, "completion_history_error:" .. tostring(result) end
                    if result ~= true and tostring(detail or "") ~= "duplicate" then
                        return false, "completion_history_rejected:" .. tostring(detail or result)
                    end
                end
            end
        end
        return true
    end,
}

local function commitLeagueProgression(txnId, payload)
    local TX = d.GameplayTransactions
    if type(TX) ~= "table" or type(TX.execute) ~= "function" then return false end
    local ok = TX.execute(txnId, "league_progression_v1", payload)
    return ok == true
end

function M.recordLeagueProgression(battle, result)
    if not battle or not d.isTrainerBattle(battle) or result ~= "win" then
        return false
    end
    local game = battle.game or d.getCurrentGame()
    if not d.canWriteNuzlockeSave(game) then return false end
    local save = game and game.save
    if not save then return false end
    local identity = trainerIdentityKeys(battle)
    local historyRequired = d.active(game, battle) == true

    local ver = d.getGameVersion and d.getGameVersion() or "RED"
    local profile = d.VersionCompat.profiles[ver]
    if profile and profile.family == "GSC" then
        for _, stage in ipairs(d.gscStages) do
            if trainerIdentityContains(identity, stage.name) then
                local badge = d.gscBadgeStages and d.gscBadgeStages[stage.name]
                return commitLeagueProgression(
                    "league_progression:gsc:" .. tostring(stage.name), {
                        storage_mode = "table",
                        storage_key = "nuzlocke_gsc_defeated",
                        entry_key = stage.name,
                        history_required = historyRequired,
                        badge_name = badge and (badge[2] or stage.name) or nil,
                        badge_dedupe = historyRequired and badge
                            and ("badge:gsc:" .. tostring(stage.name)) or nil,
                        leader = stage.name,
                        region = badge and (badge[1] == "kantoBadges" and "KANTO" or "JOHTO") or nil,
                        completion_dedupe = historyRequired and stage.name == "RED"
                            and "complete:gsc:red" or nil,
                        completion_target = stage.name == "RED" and "RED" or nil,
                        completion_phase = stage.name == "RED" and "POSTGAME" or nil,
                    })
            end
        end
        return false
    end

    for _, gymLeader in ipairs(d.levelCapGymLeaders) do
        if trainerIdentityContains(identity, gymLeader) then
            return commitLeagueProgression(
                "league_progression:rby:gym:" .. tostring(gymLeader), {
                    storage_mode = "table",
                    storage_key = d.gymProgressKey,
                    entry_key = gymLeader,
                    history_required = historyRequired,
                    badge_name = gymLeader,
                    badge_dedupe = historyRequired
                        and ("badge:rby:" .. tostring(gymLeader)) or nil,
                    leader = gymLeader,
                    region = "KANTO",
                })
        end
    end

    for _, entry in ipairs(d.eliteFourCaps) do
        if trainerIdentityEquals(identity, entry.id)
            or trainerIdentityEquals(identity, entry.name) then
            -- 2.9.12: Elite Four progression must use the same transactional
            -- progression/history path as R/B/Y Gym Leaders, the Champion,
            -- and GSC stages. The prior direct save write created a durable
            -- Run History hole for all four Elite Four victories.
            return commitLeagueProgression(
                "league_progression:rby:e4:" .. tostring(entry.id), {
                    storage_mode = "table",
                    storage_key = "nuzlocke_e4_defeated",
                    entry_key = entry.id,
                    history_required = historyRequired,
                    badge_name = entry.name,
                    badge_dedupe = historyRequired
                        and ("badge:rby:e4:" .. tostring(entry.id)) or nil,
                    leader = entry.name,
                    region = "KANTO",
                })
        end
    end

    if d.currentGymProgressCount(save) >= 8
        and not d.nextEliteFourCapInfo()
        and (trainerIdentityContains(identity, "RIVAL")
            or trainerIdentityContains(identity, "BLUE")
            or trainerIdentityContains(identity, "CHAMPION")) then
        return commitLeagueProgression("league_progression:rby:champion", {
            storage_mode = "boolean",
            storage_key = "nuzlocke_champion_defeated",
            history_required = historyRequired,
            completion_dedupe = historyRequired and "complete:rby:champion" or nil,
            completion_target = "CHAMPION",
            completion_phase = "CHAMPION",
        })
    end
    return false
end


local FORGIVENESS_GYM_AWARD_TX_HANDLER = {
    probe = function(payload)
        local key = tostring(payload and payload.leader_key or "")
        local before = math.max(0, math.floor(tonumber(
            payload and payload.before_tokens) or 0))
        local after = math.min(99, before + 1)
        local ledger = mod.save:get("route_forgiveness_gym_leaders", {})
        if type(ledger) ~= "table" then ledger = {} end
        local tokenCount = M.forgivenessTokens()
        local hasLedger = key ~= "" and ledger[key] == true
        local historyOk, historyErr = runHistoryHasDedupe(
            d.getCurrentGame() or mod.game, payload and payload.history_dedupe)
        if historyOk == nil then return "unknown", tostring(historyErr) end
        if hasLedger and tokenCount == after and historyOk then
            return "applied"
        end
        if (tokenCount == before or tokenCount == after) and key ~= "" then
            return "not_applied"
        end
        return "unknown", "forgiveness_award_state_ambiguous"
    end,
    perform = function(payload)
        local key = tostring(payload and payload.leader_key or "")
        if key == "" then return false, "missing_leader_key" end
        local before = math.max(0, math.floor(tonumber(
            payload and payload.before_tokens) or 0))
        local after = math.min(99, before + 1)
        local tokenCount = M.forgivenessTokens()
        if tokenCount == before then
            if M.setForgivenessTokens(after) ~= true then
                return false, "token_award_failed"
            end
        elseif tokenCount ~= after then
            return false, "token_state_changed"
        end
        local ledger = mod.save:get("route_forgiveness_gym_leaders", {})
        if type(ledger) ~= "table" then ledger = {} end
        if ledger[key] ~= true then
            ledger[key] = true
            local okLedger, ledgerErr =
                checkedSaveSet("route_forgiveness_gym_leaders", ledger)
            if not okLedger then
                return false, "leader_ledger_write:" .. tostring(ledgerErr)
            end
        end
        local dedupe = tostring(payload and payload.history_dedupe or "")
        if dedupe == "" then return false, "missing_history_dedupe" end
        local historyPresent, historyPresentErr =
            runHistoryHasDedupe(d.getCurrentGame() or mod.game, dedupe)
        if historyPresent == nil then return false, historyPresentErr end
        if not historyPresent then
            local runHistory = d.runHistory
            if type(runHistory) ~= "table"
                or type(runHistory.recordForgivenessAward) ~= "function" then
                return false, "run_history_unavailable"
            end
            local okHistory, result, detail = pcall(
                runHistory.recordForgivenessAward,
                d.getCurrentGame() or mod.game,
                "gym_leader", key, {
                    leader = tostring(payload and payload.leader or key),
                    map = payload and payload.map,
                    tokens = after,
                    dedupe = dedupe,
                })
            if not okHistory then
                return false, "run_history_error:" .. tostring(result)
            end
            if result ~= true and tostring(detail or "") ~= "duplicate" then
                return false, "run_history_rejected:" .. tostring(detail or result)
            end
            local persisted, persistedErr =
                runHistoryHasDedupe(d.getCurrentGame() or mod.game, dedupe)
            if persisted == nil then return false, persistedErr end
            if not persisted then return false, "run_history_not_persisted" end
        end
        return true
    end,
}

function M.install(ownerMod, supplied)
    mod = assert(ownerMod, "trainer rewards requires mod")
    d = supplied or {}

    local guardReport = M.activeGuardAudit(d.sourceText)
    assert(guardReport.ok, "trainer rewards active-guard contract failed: "
        .. table.concat(guardReport.failures, ", "))

    for _, key in ipairs({
        "Strings", "active", "canWriteNuzlockeSave", "shouldEnforceNuzlocke",
        "isTrainerBattle", "isSaveEditorSession",
        "worldMechanic", "worldRuleTriplet", "externalRuleDelegation",
        "pushWorldText",
        "worldRuleText", "getCurrentGame", "VersionCompat",
        "gscProgress", "gscStages", "gscBadgeStages", "levelCapGymLeaders",
        "gymProgress", "gymProgressKey", "eliteFourCaps", "eliteFourDefeated",
        "currentGymProgressCount", "nextEliteFourCapInfo", "runHistory",
        "scalePercentFloor", "GameplayTransactions",
    }) do
        assert(d[key] ~= nil, "trainer rewards missing dependency: " .. key)
    end

    mod.exports.__beta26.forgivenessTokenItemId =
        "NUZLOCKE_FORGIVENESS_TOKEN"
    mod.exports.__beta26.forgivenessTokens = M.forgivenessTokens
    mod.exports.__beta26.ensureForgivenessTokenItem = M.ensureForgivenessTokenItem
    mod.exports.__beta26.syncForgivenessTokenItem = M.syncForgivenessTokenItem

    local TX = d.GameplayTransactions
    if type(TX) == "table" and type(TX.register) == "function" then
        TX.register("forgiveness_gym_award_v1", FORGIVENESS_GYM_AWARD_TX_HANDLER)
        TX.register("league_progression_v1", LEAGUE_PROGRESSION_TX_HANDLER)
    end

    pcall(M.syncForgivenessTokenItem, d.getCurrentGame())
    mod.events:on("game.ready",
        function(ev) pcall(M.syncForgivenessTokenItem,
            (type(ev) == "table" and ev.game) or d.getCurrentGame()) end)
    mod.events:on("save.loaded",
        function(ev) pcall(M.syncForgivenessTokenItem,
            (type(ev) == "table" and ev.game) or d.getCurrentGame()) end)
    mod.events:on("save.created",
        function(ev) pcall(M.syncForgivenessTokenItem,
            (type(ev) == "table" and ev.game) or d.getCurrentGame()) end)
    return true
end

return M
