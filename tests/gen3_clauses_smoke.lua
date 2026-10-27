-- Standalone Gen 3 clauses policy tests: Lua 5.1, no ROM required.
local graph = {
    [133] = { { method = 7, param = 0, target = 134 },
              { method = 7, param = 0, target = 135 },
              { method = 7, param = 0, target = 136 } },
    [10] = { { method = 4, param = 7, target = 11 } },
    [11] = { { method = 4, param = 10, target = 12 } },
}
package.loaded["src.core.game3.pokemon"] = {
    evolutions = function(id) return graph[id] or {} end,
    speciesFromName = function(name)
        return ({ EEVEE = 133, JOLTEON = 135, VAPOREON = 134 })[name]
    end,
    isShiny = function(mon) return mon.isShiny == true end,
}
local Clauses = assert(loadfile("gen3_clauses.lua"))()()
local s = { areas = {}, graveyard = {}, capturedSpecies = {} }
assert(#Clauses.descriptors() == 8, "Gen 3 clauses should have eight items")
assert(Clauses.get(s, "dupes_mode") == 0, "new games default dupes OFF")
assert(Clauses.get(s, "shiny_clause") == 0, "new games default shiny OFF")
assert(Clauses.set(s, "gen3_egg_encounter_mode", 2) == false,
    "unimplemented egg policy must not be selectable")
assert(Clauses.set(s, "shiny_rate_mode", 1) == false,
    "unimplemented shiny rate cannot silently be enabled")
assert(Clauses.set(s, "dupes_mode", 42) == false,
    "invalid mode must be rejected")
Clauses.noteCaught(s, 134, false) -- previously caught Vaporeon
assert(Clauses.set(s, "dupes_mode", 1)) -- SPEC
assert(Clauses.isDuplicate(s, 134, nil, "firered"),
    "same species is a dupe")
assert(not Clauses.isDuplicate(s, 135, nil, "firered"),
    "SPEC permits Eevee sibling Jolteon")
assert(Clauses.set(s, "dupes_mode", 2)) -- FAM
assert(Clauses.isDuplicate(s, 135, nil, "firered"),
    "FAM includes Eevee sibling branches")
assert(Clauses.isDuplicate(s, 133, nil, "firered"),
    "FAM includes shared ancestors")
assert(not Clauses.isDuplicate(s, 25, nil, "firered"),
    "FAM doesn't block unrelated species")
assert(Clauses.set(s, "dupes_mode", 3)) -- SPLIT
assert(not Clauses.isDuplicate(s, 135, nil, "firered"),
    "SPLIT must allow Jolteon despite Vaporeon capture")
assert(Clauses.isDuplicate(s, 133, nil, "firered"),
    "SPLIT blocks ancestor Eevee after Vaporeon")
assert(Clauses.set(s, "dupes_mode", 2))
s.capturedSpecies = {}
-- A caught species continues to count after being permanently removed.
s.graveyard = { { species = 134 } }
assert(Clauses.isDuplicate(s, 135, nil, "firered"))
s.graveyard = {}
local session = { party = { { species = 133, hp = 30 } },
    storage = { boxes = { { mons = { { species = 10, hp = 20 } } } } } }
assert(Clauses.isDuplicate(s, 135, session, "firered"),
    "unrecorded starter in party must count")
assert(Clauses.isDuplicate(s, 12, session, "firered"),
    "boxed Caterpie counts after evolving into Butterfree")
session.party = {}
session.storage.boxes[1].mons = {}
s.areas = { ["FR_ROUTE_1"] = { caught = true, caughtSpeciesId = 134 } }
assert(Clauses.isDuplicate(s, 135, session, "firered"),
    "old catch records contribute to Dupes")
s.areas = {}
assert(Clauses.set(s, "shiny_clause", 1))
assert(Clauses.canUseShinyException(s))
assert(Clauses.isShiny({ isShiny = true }))
assert(not Clauses.isShiny({ isShiny = false }))
Clauses.noteCaught(s, 25, true)
assert(s.shinyExceptionsUsed == 1, "one exception consumed")
assert(not Clauses.canUseShinyException(s), "single shiny allowance spent")
assert(Clauses.set(s, "shiny_clause", 3))
assert(Clauses.canUseShinyException(s), "larger allowance uses spent count")
Clauses.noteCaught(s, 16, true)
Clauses.noteCaught(s, 19, true)
assert(not Clauses.canUseShinyException(s))
assert(Clauses.set(s, "shiny_clause", 4))
assert(Clauses.canUseShinyException(s), "unlimited ignores counter")
s.failed = true
assert(Clauses.set(s, "dupes_mode", 0) == false,
    "failed runs cannot alter clause settings")
print("Gen3 clauses policy smoke PASS")
