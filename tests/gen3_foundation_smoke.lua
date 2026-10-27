-- Mocked Gen 3 event/API smoke: no ROM or Gen1Recomp installation required.
local events, hooks, values = {}, {}, {}
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
local function toggle(expectBefore, expectAfter)
    local rows = hooks["ui.start_menu.items"](function(_, items) return items end, game, {})
    local row = rows[#rows]
    assert(row.label == expectBefore, "incorrect initial menu label: " .. tostring(row.label))
    assert(row.onSelect)
    row.onSelect()
    assert(row.label == expectAfter, "menu status should update without reopening")
end
toggle("NUZ: OFF", "NUZ: ON")
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
toggle("NUZ: LOST", "NUZ: LOST")
assert(mod.exports.gen3_classic.state().failed, "failure cannot be cleared")
print("Gen3 experimental Nuzlocke smoke PASS")
