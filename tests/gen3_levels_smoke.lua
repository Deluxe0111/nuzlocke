-- Gen 3 LEVELS policy and native adapter smoke tests.
local Levels = assert(loadfile("gen3_levels.lua"))()()
local function mon(nick, exp, level)
    return { species = 25, personality = 17, otId = 3, nickname = nick,
        hp = 12, maxHp = 20, level = level or 5, exp = exp or 500 }
end
local function flags(n)
    local b = {}
    for i = 1, (n or 0) do b[i] = true end
    for i = (n or 0) + 1, 8 do b[i] = false end
    return b
end
local r = { levels = {} }
local fr = { version = "firered" }
assert(Levels.get(r, "level_cap_scope") == 0)
assert(Levels.get(r, "exp_edging") == false)
assert(Levels.set(r, "level_cap_scope", 1))
assert(Levels.set(r, "exp_edging", true))
assert(not Levels.set(r, "level_cap_scope", 5))
assert(select(1, Levels.cap(r, fr, nil)) == nil, "unknown badges fail open")
assert(select(1, Levels.cap(r, fr, flags(0))) == 14)
assert(select(1, Levels.cap(r, fr, flags(1))) == 21)
assert(select(1, Levels.cap(r, fr, flags(8))) == nil,
    "GYMS ends after eighth badge")

local emerald = { version = "emerald" }
local ruby = { version = "ruby" }
assert(select(1, Levels.cap(r, ruby, flags(0))) == 15)
assert(select(1, Levels.cap(r, emerald, flags(1))) == 19)
assert(select(1, Levels.cap(r, ruby, flags(7))) == 43)
assert(select(1, Levels.cap(r, emerald, flags(7))) == 46)
assert(Levels.set(r, "level_cap_scope", 2))
assert(select(1, Levels.cap(r, fr, flags(8))) == 54)
local recovered = { levels = {scope=3} }
assert(select(1, Levels.cap(recovered, {
    version="emerald", flags = {[0x4FB]=true, [0x4FC]=true}
}, flags(8))) == 53, "native E4 flags restore prior progress")
assert(select(1, Levels.cap(recovered, {
    version="firered", flags = {[0x82C]=true}
}, flags(8))) == nil, "native game-clear flag removes Champion cap")
assert(Levels.setPostgameCap(recovered, 75))
assert(Levels.set(recovered, "level_cap_scope", 4))
assert(select(1, Levels.cap(recovered, {
    version="ruby", flags = {[0x804]=true}
}, flags(8))) == 75, "completed save honours postgame provider")
assert(not Levels.noteWin(r, fr, {trainerId=411}),
    "cannot skip Lorelei")
assert(Levels.noteWin(r, fr, { trainerId = 410 }))
assert(select(1, Levels.cap(r, fr, flags(8))) == 56)
assert(not Levels.noteWin(r, fr, { trainerId = 410 }),
    "same boss is not awarded twice")
assert(Levels.noteWin(r, fr, { trainerId = 411 }))
assert(Levels.noteWin(r, fr, { trainerId = 412 }))
assert(Levels.noteWin(r, fr, { trainerId = 413 }))
assert(select(1, Levels.cap(r, fr, flags(8))) == nil,
    "ELITE FOUR scope stops before Champion")
assert(Levels.set(r, "level_cap_scope", 3))
assert(select(1, Levels.cap(r, fr, flags(8))) == 63)
assert(Levels.noteWin(r, fr, { trainerId = 438 }))
assert(select(1, Levels.cap(r, fr, flags(8))) == nil)
assert(Levels.set(r, "level_cap_scope", 4))
assert(select(1, Levels.cap(r, fr, flags(8))) == nil)
assert(Levels.setPostgameCap(r, 70))
assert(select(1, Levels.cap(r, fr, flags(8))) == 70)
assert(Levels.setPostgameCap(r, nil))
assert(select(1, Levels.cap(r, fr, flags(8))) == nil)

local edging = { levels = {} }
assert(Levels.set(edging, "level_cap_scope", 1))
assert(Levels.set(edging, "exp_edging", true))
local lead = mon("Spark", 550, 5)
local threshold = function(_, lv) return lv * 100 end
assert(Levels.adjust(edging, lead, 100, 5, threshold) == 49,
    "cap means one EXP short of next level")
assert(Levels.banked(edging, lead) == 51)
lead.exp = lead.exp + 49
assert(Levels.adjust(edging, lead, 20, 8, threshold) == 71,
    "bank released after cap increases")
assert(Levels.banked(edging, lead) == 0)
local boxed = { species = lead.species, personality = lead.personality,
    otId = lead.otId, exp = lead.exp, level = lead.level }
assert(Levels.adjust(edging, lead, 500, 5, threshold) == 0)
assert(Levels.banked(edging, boxed) == 500,
    "bank is identity based across PC movement")
assert(Levels.set(edging, "exp_edging", false))
assert(Levels.adjust(edging, lead, 40, 5, threshold) == 0)
assert(Levels.banked(edging, lead) == 500, "OFF preserves dormant bank")
assert(Levels.set(edging, "exp_edging", true))
assert(Levels.adjust(edging, lead, 0, nil, threshold) == 500,
    "uncapped next award releases saved EXP")
assert(Levels.banked(edging, lead) == 0)
edging.failed = true
assert(not Levels.set(edging, "level_cap_scope", 0),
    "failed run cannot alter level rule")

-- Native mod integration: hook invocation, Candy blocking, live UI.
local events, hooks, values = {}, {}, {}
package.loaded["src.core.game3.battle.experience"] = {
    expForLevel = threshold,
}
local candies = 0
package.loaded["src.core.game3.item_use"] = {
    useRareCandy = function() candies = candies + 1; return true end,
}
package.loaded["src.core.game3.pokemon"] = {
    speciesOf = function(m) return m.species end,
    name = function() return "PIKACHU" end,
    isShiny = function() return false end,
}
local stack = { top = nil }
package.loaded["src.ui.game3.stack"] = {
    push = function(id, module) stack.top = {id = id, module = module} end,
    pop = function(id)
        assert(stack.top and stack.top.id == id)
        stack.top = nil
    end,
}
local session = { version = "firered", map = "FR_ROUTE_1",
    party = {mon("Spark", 1450, 14)}, flags = {} }
local game = { generation = 3, session = session }
local mod = { game = game, exports = {},
    save = {
        get = function(_, key, default) return values[key] or default end,
        set = function(_, key, value) values[key] = value end,
    },
    events = { on = function(_, name, fn) events[name] = fn end },
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    read = function(_, path)
        local f = assert(io.open(path, "rb"))
        local text = f:read("*a"); f:close()
        return text
    end,
}
assert(loadfile("gen3_runtime.lua")()(mod) == nil)
assert(mod.exports.gen3_core.setRule("nuzlocke_enabled", true))
local api = mod.exports.gen3_levels
assert(api.setRule("level_cap_scope", 1))
assert(api.setRule("exp_edging", true))
local original = session.party[1]
local battle = { playerParty = { original } }
events["battle.started"]({ battle = battle, kind = "trainer" })
local composed = 0
local exp = hooks["exp.gain"](function()
    composed = composed + 1; return 200
end, { mon = original, battle = battle })
assert(exp == 49 and composed == 1, "native EXP clamps to Brock cap")
assert(api.getBank(original) == 151)
assert(package.loaded["src.core.game3.item_use"].useRareCandy(session, original) == false,
    "Rare Candy blocked at cap")
assert(candies == 0)
events["battle.ended"]({ battle = battle, result = "win" })
session.flags[0x820] = true
original.level, original.exp = 15, 1500
assert(package.loaded["src.core.game3.item_use"].useRareCandy(session, original) == true)
assert(candies == 1, "Candy delegates below next cap")
local after = hooks["exp.gain"](function() return 25 end,
    { mon = original })
assert(after == 176 and api.getBank(original) == 0,
    "next award releases bank without bypassing composed amount")

assert(mod.exports.gen3_menu.open(game))
local menu = mod.exports.gen3_menu
local catalog = menu.catalog()
for _, category in ipairs(catalog) do
    assert(category.title ~= "BATTLE MECHANICS")
end
local function key(value)
    stack.top.module.handleInput({
        wasPressed = function(_, name) return value == name end
    })
end
key("a") -- Rules
assert(menu.model().rows[1] == "CORE"
    and menu.model().rows[2] == "CLAUSES",
    "CORE/CLAUSES category WIP labels removed")
for _ = 1, 5 do key("down") end -- LEVELS is sixth category
assert(menu.model().rows[6] == "LEVELS")
key("a")
assert(menu.model().title == "LEVELS"
    and menu.model().rows[1] == "CAP SCOPE: GYMS"
    and menu.model().rows[2] == "EXP EDGING: ON")
key("a")
assert(menu.model().rows[1] == "CAP SCOPE: ELITE FOUR")
key("down"); key("a")
assert(menu.model().rows[2] == "EXP EDGING: OFF")
key("b"); key("b"); key("b")
assert(stack.top == nil)
print("Gen3 LEVELS caps, edging, native hook, Rare Candy and menu: PASS")
