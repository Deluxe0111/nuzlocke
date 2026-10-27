-- Mocked Gen 3 event/API smoke: no ROM or Gen1Recomp installation required.
local events, hooks, values = {}, {}, {}
local game = { generation = 3, session = { map = "FR_ROUTE_1", party = {
    { species = 25, hp = 21, level = 5, nickname = "Starter" },
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
local function toggle()
    local rows = hooks["ui.start_menu.items"](function(_, items) return items end, game, {})
    assert(rows[#rows].onSelect)
    rows[#rows].onSelect()
end
toggle()
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
game.session.party[1].hp = 0
fire("battle.ended")
assert(#game.session.party == 0, "fainted mon removed from native session")
assert(#values.gen3_classic_v1.graveyard == 1, "death recorded")
assert(mod.exports.gen3_classic.state().failed, "empty party loses run")
toggle()
assert(mod.exports.gen3_classic.state().failed, "failure cannot be cleared")
print("Gen3 experimental Nuzlocke smoke PASS")
