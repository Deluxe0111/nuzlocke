-- Mocked Gen 3 event/API smoke: no ROM or Gen1Recomp installation required.
local events, hooks, values = {}, {}, {}
local uiStack = { top = nil }
package.loaded["src.ui.game3.stack"] = {
    push = function(id, module) uiStack.top = { id = id, module = module } end,
    pop = function(id)
        assert(uiStack.top and uiStack.top.id == id, "wrong menu popped")
        uiStack.top = nil
    end,
}
local fakeBattleItems = {
    canUseOn = function() return true end,
    use = function() return "heal", {}, true, false end,
}
-- The actual engine uses these internal modules to resolve battle items.
-- The test supplies their narrow contracts without loading a GBA ROM.
package.loaded["src.core.game3.battle.items"] = fakeBattleItems
package.loaded["src.core.game3.items_data"] = {
    medicineKind = function(id) return id == "REVIVE" and "revive" or "heal" end,
}
package.loaded["src.core.game3.item_use"] = {
    fieldUseKind = function(id)
        return id == "REVIVE" and "revive" or "heal"
    end,
}
local game = { generation = 3, session = { map = "FR_ROUTE_1", party = {
    { species = 25, personality = 7421, hp = 21, level = 5, nickname = "Starter" },
} } }
local mod = {
    game = game,
    save = {
        get = function(_, k, default) return values[k] or default end,
        set = function(_, k, v) values[k] = v end,
    },
    events = { on = function(_, n, f) events[n] = f end },
    hooks = { wrap = function(_, n, f) hooks[n] = f end },
    exports = {},
    read = function(_, path)
        local handle = io.open(path, "rb")
        if not handle then return nil, "file missing: " .. path end
        local text = handle:read("*a")
        handle:close()
        return text
    end,
}
assert(loadfile("gen3_runtime.lua")()(mod) == nil)
local function fire(n, v) assert(events[n], n)(v) end
local function throw(battle)
    local invoked = false
    local caught, shakes = hooks["catch.rate"](function()
        invoked = true
        return true, 4
    end, "POKE_BALL", {}, {}, { battle = battle })
    return caught, shakes, invoked
end
assert(not mod.exports.gen3_classic.state().enabled, "opt in is required")
local function press(key)
    assert(uiStack.top, "menu stack empty")
    uiStack.top.module.handleInput({
        wasPressed = function(_, button) return key == button end
    })
end
local function openMenu()
    local rows = hooks["ui.start_menu.items"](function(_, items) return items end, game, {})
    assert(rows[#rows].label == "NUZ MENU", "one unified Gen 3 Start entry")
    rows[#rows].onSelect()
    local model = mod.exports.gen3_menu.model()
    assert(model.title == "NUZ MENU", "menu opens home")
    assert(model.rows[1] == "[WIP] NUZ RULES", "rules marked WIP")
    assert(model.rows[3] == "NUZ STATUS", "functional status unflagged")
    assert(model.rows[5] == "[Soon] ALMANAC", "absent feature marked Soon")
end
local function toggle(expectBefore, expectAfter)
    openMenu()
    press("a") -- NUZ RULES
    assert(mod.exports.gen3_menu.model().title == "NUZ RULES")
    press("a") -- CORE category
    local core = mod.exports.gen3_menu.model()
    assert(core.title == "CORE" and core.rows[1] == expectBefore,
        "unexpected Gen 3 CORE rule state")
    press("a") -- toggle Nuzlocke
    assert(mod.exports.gen3_menu.model().rows[1] == expectAfter,
        "Gen 3 menu toggle must update immediately")
    press("b") -- CORE -> RULES
    press("b") -- RULES -> HOME
    press("b") -- HOME -> START
    assert(uiStack.top == nil, "menu should close cleanly")
end
toggle("NUZLOCKE: OFF", "NUZLOCKE: ON")
assert(mod.exports.gen3_classic.state().enabled)
local first = {}
fire("battle.started", { battle = first, kind = "wild", species = "PIDGEY", speciesId = 16 })
local caught, shakes, invoked = throw(first)
assert(caught and shakes == 4 and invoked, "first battle may catch")
fire("pokemon.caught", { battle = first })
assert(values.gen3_classic_v1.areas.FR_ROUTE_1.caught == true)
fire("battle.ended")
local repeatBattle = {}
fire("battle.started", { battle = repeatBattle, kind = "wild" })
caught, shakes, invoked = throw(repeatBattle)
assert(caught == false and shakes == 0 and not invoked, "repeat catch denied")
fire("battle.ended")
game.session.map = "FR_ROUTE_2"
fire("map.entered", { mapId = "FR_ROUTE_2" })
local newAreaBattle = {}
fire("battle.started", { battle = newAreaBattle, kind = "wild" })
assert(select(1, throw(newAreaBattle)) == true, "new area allowed")
fire("battle.ended")

-- Failed Encounters OFF: a failed attempt does not claim the route; after a
-- successful catch, the route becomes committed even with failure mode OFF.
local core = mod.exports.gen3_core
assert(core.schema == 1 and #core.definitions() == 8, "eight approved CORE rules")
assert(core.setRule("failed_encounter", false))
game.session.map = "FR_ROUTE_3"
fire("map.entered", { mapId = "FR_ROUTE_3" })
local try1 = {}
fire("battle.started", { battle = try1, kind = "wild" })
assert(select(1, throw(try1)) == true, "first attempt allowed")
fire("battle.ended")
assert(values.gen3_classic_v1.areas.FR_ROUTE_3.spent == false,
    "failed catch must not consume the area")
local try2 = {}
fire("battle.started", { battle = try2, kind = "wild" })
assert(select(1, throw(try2)) == true, "second attempt allowed when failures OFF")
fire("pokemon.caught", { battle = try2 })
fire("battle.ended")
local try3 = {}
fire("battle.started", { battle = try3, kind = "wild" })
assert(select(1, throw(try3)) == false, "successful catch closes area")
fire("battle.ended")
assert(core.setRule("encounter_limit", false))
local noLimit = {}
fire("battle.started", { battle = noLimit, kind = "wild" })
assert(select(1, throw(noLimit)) == true, "one-per-area OFF disables catch block")
fire("battle.ended")
assert(core.setRule("encounter_limit", true))
assert(core.setRule("failed_encounter", true))
assert(core.setRule("nickname_rule", false) == false,
    "unimplemented CORE rule must be read-only")
assert(core.setRule("pc_survivors_allowed", true) == false,
    "unsafe PC recovery must not be advertised as working")

-- Permadeath OFF must restore normal revives and allow ordinary fainting.
assert(core.setRule("permadeath", false))
local safeMon = { species = 25, personality = 7421, hp = 0, level = 5 }
local safeBattle = { playerParty = { safeMon } }
fire("battle.started", { battle = safeBattle, kind = "trainer" })
fire("battle.fainted", { battle = safeBattle, sideName = "player",
    battler = { side = "player", partyIndex = 1, mon = safeMon } })
assert(#values.gen3_classic_v1.graveyard == 0 and not safeMon.nuzlockeDead,
    "permadeath OFF does not mark death")
fire("battle.ended")
assert(#game.session.party == 1, "permadeath OFF preserves party")
assert(fakeBattleItems.canUseOn({}, "REVIVE", 1, safeMon),
    "revive item becomes usable with permadeath OFF")
assert(core.setRule("permadeath", true))

assert(fakeBattleItems.canUseOn({}, "REVIVE", 1, game.session.party[1]) == false,
    "revival should be denied by target-selection UI")
local dummyAdapter = { say = function(_, text) assert(text:find("No revives")) end }
assert(select(1, fakeBattleItems.use({}, dummyAdapter, {}, game.session,
    "REVIVE", 1)) == "error", "native revival action must also be blocked")
assert(select(1, fakeBattleItems.use({}, dummyAdapter, {}, game.session,
    "POTION", 1)) == "heal", "ordinary healing still delegates to engine")

-- Player faint in a trainer battle: immediate death even if an external
-- battle effect later restores HP on the copied party mon.
local battleMon = {
    species = 25, personality = 7421, hp = 0, level = 5,
    nickname = "Starter",
}
local trainerBattle = { playerParty = { battleMon } }
fire("battle.started", { battle = trainerBattle, kind = "trainer" })
local faint = { battle = trainerBattle, sideName = "player",
    battler = { side = "player", partyIndex = 1, mon = battleMon } }
fire("battle.fainted", faint)
assert(battleMon.nuzlockeDead, "death is recorded during battle")
assert(#values.gen3_classic_v1.graveyard == 1, "instant graveyard entry")
fire("battle.fainted", faint)
assert(#values.gen3_classic_v1.graveyard == 1, "duplicate faint not recorded")
battleMon.hp = 13
game.session.party[1].hp = 13 -- simulate a mid-battle revive / heal bypass
fire("battle.ended")
assert(#game.session.party == 0, "fainted mon removed despite later HP gain")
assert(#values.gen3_classic_v1.graveyard == 1, "death not duplicated at cleanup")
assert(mod.exports.gen3_classic.state().failed, "empty party loses run")
toggle("NUZLOCKE: ON", "NUZLOCKE: ON")
assert(mod.exports.gen3_classic.state().failed, "failure cannot be cleared")
assert(core.setRule("nuzlocke_enabled", false) == false,
    "failed-run config remains sealed")

-- Whiteout has higher priority than healthy reserve Pokémon in the PC;
-- switching it OFF allows the native loss outcome when the party survives.
values.gen3_classic_v1 = {
    enabled = true, failed = false, areas = {}, graveyard = {},
    rules = { whiteout_ends_run = true, permadeath = true }
}
game.session.party = {
    { species = 1, personality = 77, hp = 12, level = 5 },
}
game.session.storage = {
    boxes = { { mons = { { species = 4, hp = 11, level = 5 } } } },
}
local losing = {}
fire("battle.started", { battle = losing, kind = "trainer" })
fire("battle.ended", { result = "lose" })
assert(values.gen3_classic_v1.failed, "whiteout ends run despite PC reserves")

values.gen3_classic_v1.failed = false
assert(core.setRule("whiteout_ends_run", false))
local forgivenLoss = {}
fire("battle.started", { battle = forgivenLoss, kind = "trainer" })
fire("battle.ended", { result = "lose" })
assert(not values.gen3_classic_v1.failed,
    "whiteout OFF does not by itself end a surviving-party run")

print("Gen3 experimental Nuzlocke smoke PASS")
