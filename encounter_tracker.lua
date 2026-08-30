-- Module owner: EncounterTracker
-- Area catalogs, encounter-area projection, tracker persistence, and save reconstruction.
return function(mod, deps)
  deps = type(deps) == "table" and deps or {}
  local Strings = assert(deps.Strings, "EncounterTracker requires Strings")
  local H = assert(deps.H, "EncounterTracker requires H")
  local Identity = assert(deps.Identity, "EncounterTracker requires PokemonIdentity")
  local activeCompatProvider = assert(deps.activeCompatProvider, "EncounterTracker requires activeCompatProvider")
  local getCurrentGame = assert(deps.getCurrentGame, "EncounterTracker requires getCurrentGame")
  local setCurrentSave = assert(deps.setCurrentSave, "EncounterTracker requires setCurrentSave")
  local getDisplayRoutesProvider = assert(deps.getDisplayRoutes, "EncounterTracker requires getDisplayRoutes")
  local getGameVersionProvider = assert(deps.getGameVersion, "EncounterTracker requires getGameVersion")
  local function currentGameValue() return getCurrentGame() end
  local function getDisplayRoutesLive(game) return getDisplayRoutesProvider(game) end
  local function getGameVersionLive() return getGameVersionProvider() end

---------------------------------------------------------------------
-- ALL GEN 1 CATCHABLE ROUTES / LOCATIONS
--
-- These IDs intentionally match the engine's actual map IDs.
---------------------------------------------------------------------
local ALL_ROUTES = {
    -- Ordered in the normal Gen 1 discovery/progression order.
    -- Optional side areas are placed where a player would naturally
    -- first encounter them rather than grouping cities, routes, or caves.
    { id = "PALLET_TOWN",      name = Strings.source("Pallet Town")    },
    { id = "ROUTE_1",          name = Strings.source("Route 1")        },
    { id = "VIRIDIAN_CITY",    name = Strings.source("Viridian City")  },
    { id = "ROUTE_22",         name = Strings.source("Route 22")       },
    { id = "ROUTE_2",          name = Strings.source("Route 2")        },
    { id = "VIRIDIAN_FOREST",  name = Strings.source("Virid. Forest")  },
    { id = "PEWTER_CITY",      name = Strings.source("Pewter City")    },
    { id = "ROUTE_3",          name = Strings.source("Route 3")        },
    { id = "MT_MOON",          name = Strings.source("Mt. Moon Splits"), shortName = Strings.source("Mt. Moon")       },
    { id = "MT_MOON_1F",       name = Strings.source("Mt. Moon 1F")    },
    { id = "MT_MOON_B1F",      name = Strings.source("Mt. Moon B1F")   },
    { id = "MT_MOON_B2F",      name = Strings.source("Mt. Moon B2F")   },
    { id = "ROUTE_4",          name = Strings.source("Route 4")        },
    { id = "CERULEAN_CITY",    name = Strings.source("Cerulean City")  },
    { id = "CERULEAN_GYM",     name = Strings.source("Cerulean Gym")   },
    { id = "ROUTE_24",         name = Strings.source("Route 24")       },
    { id = "ROUTE_25",         name = Strings.source("Route 25")       },
    { id = "ROUTE_5",          name = Strings.source("Route 5")        },
    { id = "ROUTE_6",          name = Strings.source("Route 6")        },
    { id = "VERMILION_CITY",   name = Strings.source("Vermilion City") },
    { id = "VERMILION_HARBOR", name = Strings.source("Vermilion Harbor") },
    { id = "ROUTE_11",         name = Strings.source("Route 11")       },
    { id = "DIGLETT_CAVE",     name = Strings.source("Diglett Cave")   },
    { id = "ROUTE_9",          name = Strings.source("Route 9")        },
    { id = "ROUTE_10",         name = Strings.source("Route 10")       },
    { id = "ROCK_TUNNEL",      name = Strings.source("Rock Tunnel")    },
    { id = "POWER_PLANT",      name = Strings.source("Power Plant")    },
    { id = "LAVENDER_TOWN",    name = Strings.source("Lavender Town")  },
    { id = "POKEMON_TOWER",    name = Strings.source("Pkmn Tower")     },
    { id = "ROUTE_12",         name = Strings.source("Route 12")       },
    { id = "ROUTE_13",         name = Strings.source("Route 13")       },
    { id = "ROUTE_14",         name = Strings.source("Route 14")       },
    { id = "ROUTE_15",         name = Strings.source("Route 15")       },
    { id = "FUCHSIA_CITY",     name = Strings.source("Fuchsia City")   },
    { id = "SAFARI_ZONE",      name = Strings.source("Safari Zone")    },
    { id = "SAFARI_ZONE_CENTER", name = Strings.source("Safari Center") },
    { id = "SAFARI_ZONE_EAST",   name = Strings.source("Safari East")   },
    { id = "SAFARI_ZONE_NORTH",  name = Strings.source("Safari North")  },
    { id = "SAFARI_ZONE_WEST",   name = Strings.source("Safari West")   },
    { id = "CELADON_CITY",     name = Strings.source("Celadon City")   },
    { id = "ROUTE_16",         name = Strings.source("Route 16")       },
    { id = "ROUTE_17",         name = Strings.source("Route 17")       },
    { id = "ROUTE_18",         name = Strings.source("Route 18")       },
    { id = "ROUTE_7",          name = Strings.source("Route 7")        },
    { id = "ROUTE_8",          name = Strings.source("Route 8")        },
    { id = "SAFFRON_CITY",     name = Strings.source("Saffron City")   },
    { id = "SILPH_CO",         name = Strings.source("Silph Co.")      },
    { id = "ROUTE_19",         name = Strings.source("Route 19")       },
    { id = "ROUTE_20",         name = Strings.source("Route 20")       },
    { id = "SEAFOAM_ISLANDS",  name = Strings.source("Seafoam Isls.")  },
    { id = "CINNABAR_ISLAND",  name = Strings.source("Cinnabar Isl.")  },
    { id = "POKEMON_MANSION",  name = Strings.source("Pkmn Mansion")   },
    { id = "ROUTE_21",         name = Strings.source("Route 21")       },
    { id = "ROUTE_23",         name = Strings.source("Route 23")       },
    { id = "VICTORY_ROAD",     name = Strings.source("Victory Road")   },
    { id = "CERULEAN_CAVE",    name = Strings.source("Cerulean Cave")  },
}

-- Physical cardinal provenance is retained for every numbered Kanto route
-- so older saves created under the retired blanket Route Splits rule can be
-- collapsed deterministically without losing tracker rows. New gameplay only
-- exposes Route 2, Route 10, and Route 20 as independently selectable splits.
mod.exports.__beta26.routeCardinalAxes = {
    ROUTE_1 = "NS",  ROUTE_2 = "NS",  ROUTE_3 = "EW",
    ROUTE_4 = "EW",  ROUTE_5 = "NS",  ROUTE_6 = "NS",
    ROUTE_7 = "EW",  ROUTE_8 = "EW",  ROUTE_9 = "EW",
    ROUTE_10 = "NS", ROUTE_11 = "EW", ROUTE_12 = "NS",
    ROUTE_13 = "EW", ROUTE_14 = "NS", ROUTE_15 = "EW",
    ROUTE_16 = "EW", ROUTE_17 = "NS", ROUTE_18 = "EW",
    ROUTE_19 = "NS", ROUTE_20 = "EW", ROUTE_21 = "NS",
    ROUTE_22 = "EW", ROUTE_23 = "NS", ROUTE_24 = "NS",
    ROUTE_25 = "EW",
}

do
    local baseRoutes = ALL_ROUTES
    ALL_ROUTES = {}
    for _, route in ipairs(baseRoutes) do
        ALL_ROUTES[#ALL_ROUTES + 1] = route
        local axis = mod.exports.__beta26.routeCardinalAxes[route.id]
        if axis == "NS" then
            ALL_ROUTES[#ALL_ROUTES + 1] = {
                id = route.id .. "_NORTH", name = route.name .. " North" }
            ALL_ROUTES[#ALL_ROUTES + 1] = {
                id = route.id .. "_SOUTH", name = route.name .. " South" }
        elseif axis == "EW" then
            ALL_ROUTES[#ALL_ROUTES + 1] = {
                id = route.id .. "_WEST", name = route.name .. " West" }
            ALL_ROUTES[#ALL_ROUTES + 1] = {
                id = route.id .. "_EAST", name = route.name .. " East" }
        end
    end
end

local ROUTE_IDS = {}
local ROUTE_NAMES = {}
local ROUTE_ORDER = {}

for index, route in ipairs(ALL_ROUTES) do
    ROUTE_IDS[route.id] = true
    ROUTE_NAMES[route.id] = route.name
    ROUTE_ORDER[route.id] = index
end

-- 2.7.76 reconstruction: ALL_ROUTES/ROUTE_ORDER began as the authored
-- R/B/Y tracker catalog. Preserve that original seed identity so Gen 2
-- presentation can require real runtime evidence before exposing a Kanto
-- seed row, while dynamically discovered Johto/custom areas remain eligible.
local GEN1_SEED_IDS = {}
for id in pairs(ROUTE_ORDER) do GEN1_SEED_IDS[id] = true end

---------------------------------------------------------------------
-- LEGACY MAP ALIASES
--
-- Older versions of this mod could have stored a raw engine/text
-- namespace identifier. Keep aliases here so upgrading a save does
-- not throw away existing tracker information.
---------------------------------------------------------------------
local MAP_ALIASES = {
    -- Text-pointer style names
    PalletTown       = "PALLET_TOWN",
    ViridianCity     = "VIRIDIAN_CITY",
    ViridianForest   = "VIRIDIAN_FOREST",
    PewterCity       = "PEWTER_CITY",
    MtMoon           = "MT_MOON",
    MtMoon1F         = "MT_MOON_1F",
    MtMoonB1F        = "MT_MOON_B1F",
    MtMoonB2F        = "MT_MOON_B2F",
    CeruleanCity     = "CERULEAN_CITY",
    VermilionCity    = "VERMILION_CITY",
    DiglettsCave     = "DIGLETT_CAVE",
    DiglettCave      = "DIGLETT_CAVE",
    LavenderTown     = "LAVENDER_TOWN",
    PokemonTower     = "POKEMON_TOWER",
    CeladonCity      = "CELADON_CITY",
    SafariZone       = "SAFARI_ZONE",
    SafariZoneCenter = "SAFARI_ZONE_CENTER",
    SafariZoneEast   = "SAFARI_ZONE_EAST",
    SafariZoneNorth  = "SAFARI_ZONE_NORTH",
    SafariZoneWest   = "SAFARI_ZONE_WEST",
    FuchsiaCity      = "FUCHSIA_CITY",
    SaffronCity      = "SAFFRON_CITY",
    SilphCo          = "SILPH_CO",
    CinnabarIsland   = "CINNABAR_ISLAND",
    VictoryRoad      = "VICTORY_ROAD",
    PowerPlant       = "POWER_PLANT",
    SeafoamIslands   = "SEAFOAM_ISLANDS",
    RockTunnel       = "ROCK_TUNNEL",
    MtEmber          = "MT_EMBER",
    PokemonMansion   = "POKEMON_MANSION",
    CeruleanCave     = "CERULEAN_CAVE",
    CeruleanGym      = "CERULEAN_GYM",
    VermilionHarbor  = "VERMILION_HARBOR",

    Route1           = "ROUTE_1",
    Route2           = "ROUTE_2",
    Route3           = "ROUTE_3",
    Route4           = "ROUTE_4",
    Route5           = "ROUTE_5",
    Route6           = "ROUTE_6",
    Route7           = "ROUTE_7",
    Route8           = "ROUTE_8",
    Route9           = "ROUTE_9",
    Route10          = "ROUTE_10",
    Route11          = "ROUTE_11",
    Route12          = "ROUTE_12",
    Route13          = "ROUTE_13",
    Route14          = "ROUTE_14",
    Route15          = "ROUTE_15",
    Route16          = "ROUTE_16",
    Route17          = "ROUTE_17",
    Route18          = "ROUTE_18",
    Route19          = "ROUTE_19",
    Route20          = "ROUTE_20",
    Route21          = "ROUTE_21",
    Route22          = "ROUTE_22",
    Route23          = "ROUTE_23",
    Route24          = "ROUTE_24",
    Route25          = "ROUTE_25",
}

---------------------------------------------------------------------
-- NORMALIZE A MAP ID
--
-- Current engine map IDs already match ALL_ROUTES.
-- Aliases are only for compatibility with older mod tracker data.
---------------------------------------------------------------------
local function routeKey(mapId)
    if mapId == nil then
        return nil
    end

    mapId = tostring(mapId)

    -- Gen I and Gold disagree on the historical map spelling (DIGLETT_CAVE
    -- vs DIGLETTS_CAVE), and providers may preserve CamelCase. Treat only
    -- exact compact spellings as the same physical cave; do not wildcard
    -- custom maps that merely contain the words.
    local diglettCompact = mapId:upper():gsub("[^A-Z0-9]", "")
    if diglettCompact == "DIGLETTCAVE" or diglettCompact == "DIGLETTSCAVE" then
        return "DIGLETT_CAVE"
    end

    if ROUTE_IDS[mapId] then
        return mapId
    end

    local alias = MAP_ALIASES[mapId]
    if alias then
        return alias
    end

    -- Unknown map IDs are intentionally accepted. This makes the tracker
    -- compatible with map/overworld mods instead of silently rejecting a
    -- perfectly valid new area just because vanilla Gen 1 never had it.
    if mapId:match("^[%w_%-%:]+$") then
        return mapId
    end

    return nil
end

---------------------------------------------------------------------
-- RESOLVE DISPLAY-NAME CATCH LOCATIONS
--
-- Some existing save/UI mods preserve a Pokemon's catchLocation as the
-- human-readable name (for example "Route 22" or "Pallet Town") rather
-- than the internal map id (ROUTE_22 / PALLET_TOWN).  routeKey intentionally
-- rejects strings containing spaces, so those values previously survived
-- in Catch Info but could not be restored into the encounter tracker.
-- Match against every known area's display name before falling back to the
-- raw id. This is recovery-only and never guesses from species.
---------------------------------------------------------------------
local function resolveCatchLocation(raw)
    if raw == nil then return nil end
    local direct = routeKey(raw)
    if direct then return direct end

    local target = tostring(raw):lower()
    target = target:gsub("[^%w]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    for _, route in ipairs(ALL_ROUTES) do
        local id = route and route.id
        if id then
            local display = ROUTE_NAMES[id] or id
            local normalized = tostring(display):lower()
            normalized = normalized:gsub("[^%w]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if normalized == target then
                return id
            end

            local idNormalized = tostring(id):lower():gsub("[^%w]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if idNormalized == target then
                return id
            end
        end
    end

    -- Common vanilla display forms are useful even before dynamic area
    -- discovery has populated ALL_ROUTES.
    local compact = target:gsub(" ", "_"):upper()
    local routeNumber = compact:match("^ROUTE_(%d+)$")
    if routeNumber then return "ROUTE_" .. routeNumber end
    local town = {
        ["PALLET_TOWN"] = "PALLET_TOWN", ["VIRIDIAN_CITY"] = "VIRIDIAN_CITY",
        ["PEWTER_CITY"] = "PEWTER_CITY", ["CERULEAN_CITY"] = "CERULEAN_CITY",
        ["VERMILION_CITY"] = "VERMILION_CITY", ["LAVENDER_TOWN"] = "LAVENDER_TOWN",
        ["CELADON_CITY"] = "CELADON_CITY", ["FUCHSIA_CITY"] = "FUCHSIA_CITY",
        ["SAFFRON_CITY"] = "SAFFRON_CITY", ["CINNABAR_ISLAND"] = "CINNABAR_ISLAND",
        ["INDIGO_PLATEAU"] = "INDIGO_PLATEAU",
    }
    return town[compact]
end

---------------------------------------------------------------------
-- LOOKUP / DYNAMIC AREA HELPERS
---------------------------------------------------------------------
H.prettyAreaName = function(id)
    local text = tostring(id or "")
    text = text:gsub("_+", " ")
    text = text:gsub("([a-z])([A-Z])", "%1 %2")
    text = text:gsub("([A-Z]+)([A-Z][a-z])", "%1 %2")
    text = text:gsub("(%a)(%d)", "%1 %2")
    text = text:gsub("(%d)(%a)", "%1 %2")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("(%w)([%w]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return text
end

-- Explicit display overrides for map IDs whose internal names are not
-- reliably word-separable. IDs remain unchanged for save/mod compatibility.
local DISPLAY_NAME_OVERRIDES = {
    CERULEANMART4 = "Cerulean Mart 4",
    CeruleanMart4 = "Cerulean Mart 4",
    CERULEANMART = "Cerulean Mart",
    CERULEANHOTEL = "Cerulean Hotel",
    CeruleanHotel = "Cerulean Hotel",
    CERULEANCITYHOTEL = "Cerulean City Hotel",
    CeruleanCityHotel = "Cerulean City Hotel",
    VERMILIONMART4 = "Vermilion Mart 4",
    VermilionMart4 = "Vermilion Mart 4",
    CELADONMART4 = "Celadon Mart 4",
    CeladonMart4 = "Celadon Mart 4",
    CELADONDEPTSTORE = "Celadon Dept Store",
    CeladonDeptStore = "Celadon Dept Store",

    VIRIDIANMART = "Viridian Mart",
    ViridianMart = "Viridian Mart",
    PEWTERMART = "Pewter Mart",
    PewterMart = "Pewter Mart",
    LAVENDERMART = "Lavender Mart",
    LavenderMart = "Lavender Mart",
    FUCHSIAMART = "Fuchsia Mart",
    FuchsiaMart = "Fuchsia Mart",
    SAFFRONMART = "Saffron Mart",
    SaffronMart = "Saffron Mart",
    CINNABARMART = "Cinnabar Mart",
    CinnabarMart = "Cinnabar Mart",
    CELADONMART = "Celadon Mart",
    CeladonMart = "Celadon Mart",
    VIRIDIANCENTER = "Viridian Center",
    ViridianCenter = "Viridian Center",
    PEWTERCENTER = "Pewter Center",
    PewterCenter = "Pewter Center",
    CERULEANCENTER = "Cerulean Center",
    CeruleanCenter = "Cerulean Center",
    VERMILIONCENTER = "Vermilion Center",
    VermilionCenter = "Vermilion Center",
    LAVENDERCENTER = "Lavender Center",
    LavenderCenter = "Lavender Center",
    FUCHSIACENTER = "Fuchsia Center",
    FuchsiaCenter = "Fuchsia Center",
    CELADONCENTER = "Celadon Center",
    CeladonCenter = "Celadon Center",
    SAFFRONCENTER = "Saffron Center",
    SaffronCenter = "Saffron Center",
    CINNABARCENTER = "Cinnabar Center",
    CinnabarCenter = "Cinnabar Center",
}

local function formatAreaDisplayName(name, id)
    local override = DISPLAY_NAME_OVERRIDES[tostring(id or "")]
    if override then return override end
    local text = tostring(name or "")
    if text == "" then
        return H.prettyAreaName(id)
    end
    text = text:gsub("_+", " ")
    text = text:gsub("([a-z])([A-Z])", "%1 %2")
    text = text:gsub("([A-Z]+)([A-Z][a-z])", "%1 %2")
    text = text:gsub("(%a)(%d)", "%1 %2")
    text = text:gsub("(%d)(%a)", "%1 %2")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    -- Common concatenated map-name components (CeruleanMart4, etc.).
    local tokens = {
        "Department Store", "Dept Store", "Pokemon Center", "Pokemon Mart",
        "Pkmn Center", "Pkmn Mart", "PokeMart", "Poke Mart",
        "Game Corner", "GameCorner", "Silph Co", "Bike Shop", "Fishing Guru",
        "Name Rater", "Safari Zone", "Pokemon Mansion", "Pokemon Tower",
        "Cerulean Cave", "Viridian Forest", "Diglett Cave", "Rock Tunnel",
        "Power Plant", "Seafoam Islands", "Victory Road", "Mart", "Hotel",
        "Gym", "House", "Lab", "Center", "Gate", "Museum", "Shop",
        "Office", "Floor", "Cave", "Tower", "Mansion", "Harbor", "Port"
    }
    for _, token in ipairs(tokens) do
        local compact = text:gsub("%s+", ""):lower()
        local tl = token:gsub("%s+", ""):lower()
        local pos = compact:find(tl, 1, true)
        if pos and pos > 1 then
            local before = compact:sub(1, pos - 1)
            local after = compact:sub(pos + #tl)
            if after ~= "" then
                text = before .. " " .. token .. " " .. after
            else
                text = before .. " " .. token
            end
        end
    end
    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > 0 then
        text = text:sub(1, 1):upper() .. text:sub(2)
    end
    return text
end

local function registerArea(id, name)
    if not id or id == "__LEGACY__" then
        return nil
    end

    id = routeKey(id)
    if not id then
        return nil
    end

    if not ROUTE_IDS[id] then
        ROUTE_IDS[id] = true
        ROUTE_NAMES[id] = formatAreaDisplayName(name, id)
        table.insert(ALL_ROUTES, {
            id = id,
            name = ROUTE_NAMES[id]
        })
    elseif name then
        ROUTE_NAMES[id] = formatAreaDisplayName(name, id)
        for _, route in ipairs(ALL_ROUTES) do
            if route.id == id then
                route.name = ROUTE_NAMES[id]
                break
            end
        end
    end

    return id
end

local function isTrackedArea(id)
    id = routeKey(id)
    return id ~= nil and ROUTE_IDS[id] == true
end

local function routeName(id)
    return Strings(formatAreaDisplayName(ROUTE_NAMES[id], id))
end

local function discoverAreasFromTable(tbl)
    if type(tbl) ~= "table" then
        return
    end

    for rawId, def in pairs(tbl) do
        local id = rawId
        local name = nil

        if type(def) == "table" then
            id = def.id or def.mapId or def.key or rawId
            name = def.name or def.label or def.displayName or def.title
        elseif type(def) == "string" then
            id = rawId
            name = def
        end

        if type(id) == "string" then
            registerArea(id, name)
        end
    end
end

local function discoverAllKnownAreas(game)
    if not game then
        return
    end

    -- These are deliberately guarded: different recomp/mod builds may
    -- expose map definitions through different data containers.
    local data = game.data
    if type(data) == "table" then
        discoverAreasFromTable(data.maps)
        discoverAreasFromTable(data.mapsById)
        discoverAreasFromTable(data.mapData)
        -- Gen II keeps its authoritative map tables beside the shared Gen I
        -- names. The Encounter Tracker must discover those tables directly;
        -- otherwise Gold/Silver LOG rows can be correct while MAP remains
        -- seeded from the Gen I Kanto catalog.
        discoverAreasFromTable(data.gen2Maps)
        discoverAreasFromTable(data.gen2MapsById)
        discoverAreasFromTable(data.gen2MapData)
        -- Content-only mods can patch encounters for an existing or newly
        -- authored map without exposing a separate maps registry entry.
        -- Treat encounter-registry keys as discoverable physical areas too;
        -- this only affects tracker presentation/lookup and never mutates the
        -- provider's encounter table.
        discoverAreasFromTable(data.encounters)
        discoverAreasFromTable(data.encountersByMap)
        discoverAreasFromTable(data.wildEncounters)
    end

    discoverAreasFromTable(game.maps)
    discoverAreasFromTable(game.mapsById)
    discoverAreasFromTable(game.mapData)

    if game.save then
        if type(game.save.visited) == "table" then
            for rawId, wasVisited in pairs(game.save.visited) do
                if wasVisited then
                    registerArea(rawId)
                end
            end
        end
        if game.save.player and game.save.player.map then
            registerArea(game.save.player.map)
        end
    end
end

---------------------------------------------------------------------
-- SAVE STATE HELPERS
---------------------------------------------------------------------
local function caughtAreas()
    local areas = mod.save:get("caught_areas")

    if type(areas) ~= "table" then
        areas = {}
        mod.save:set("caught_areas", areas)
    end

    return areas
end

local function trackerLog()
    local log = mod.save:get("tracker_log")

    if type(log) ~= "table" then
        log = {}
        mod.save:set("tracker_log", log)
    end

    return log
end

-- COMMON encounter splitting keeps the physical map as immutable
-- provenance and projects it into the currently selected rule layout.
-- Persisted catches are never identified by species or guessed from a
-- display name, so switching OFF <-> COMMON is reversible and randomizer
-- safe. Unknown legacy catches remain on the unsplit parent area.
mod.exports.__beta26.encounterSplitAreas = {
    mt_moon = {
        parent = "MT_MOON",
        members = {
            MT_MOON_1F = true,
            MT_MOON_B1F = true,
            MT_MOON_B2F = true,
        },
    },
    safari = {
        parent = "SAFARI_ZONE",
        members = {
            SAFARI_ZONE_CENTER = true,
            SAFARI_ZONE_EAST = true,
            SAFARI_ZONE_NORTH = true,
            SAFARI_ZONE_WEST = true,
        },
    },
}

for parent, axis in pairs(mod.exports.__beta26.routeCardinalAxes) do
    local members = {}
    if axis == "NS" then
        members[parent .. "_NORTH"] = true
        members[parent .. "_SOUTH"] = true
    else
        members[parent .. "_WEST"] = true
        members[parent .. "_EAST"] = true
    end
    local routeNumber = parent:match("ROUTE_(%d+)")
    local selector = ({
        ["2"] = "route_2_split",
        ["10"] = "route_10_split",
        ["20"] = "route_20_split",
    })[routeNumber]
    mod.exports.__beta26.encounterSplitAreas["route_" .. routeNumber] = {
        parent = parent,
        members = members,
        -- nil means legacy-only physical provenance: those routes always
        -- project back to the parent in current rules.
        selector = selector,
    }
end

-- The retired blanket Route Splits option is a semantic migration, not a
-- schema-shape migration. Register it with the central save-upgrade plan so
-- it runs before reconstruction/projection and cannot be forgotten as an
-- isolated side effect inside reprojectEncounterAreas().
mod.exports.__beta26.registerSaveUpgradeStep("semantic",
    "legacy_route_split_selectors", function()
        if mod.save:get("route_split_rules_migrated", false) ~= true then
            local legacyOn = tonumber(mod.save:get("route_splits", 0)) == 1
            for _, key in ipairs({ "route_2_split", "route_10_split",
                "route_20_split" }) do
                if mod.save:get(key, nil) == nil then
                    mod.save:set(key, legacyOn)
                end
            end
            mod.save:set("route_split_rules_migrated", true)
        end
        return true
    end)

-- New route selectors are booleans. Before the one-time save migration
-- runs, a missing selector inherits the retired blanket route_splits value
-- so early listeners/providers cannot briefly see an old CARDINAL save as OFF.
mod.exports.__beta26.routeSplitActive = function(selector)
    local raw = mod.save:get(selector, nil)
    if raw ~= nil then return raw == true or tonumber(raw) == 1 end
    if mod.save:get("route_split_rules_migrated", false) ~= true then
        return tonumber(mod.save:get("route_splits", 0)) == 1
    end
    return false
end

mod.exports.__beta26.splitFamilyFor = function(key)
    for _, family in pairs(mod.exports.__beta26.encounterSplitAreas) do
        if family.members[key] then return family end
    end
    return nil
end

mod.exports.__beta26.cardinalPhysicalArea = function(mapId, x, y, width, height)
    local key = routeKey(mapId)
    if not key then return nil end
    if mod.exports.__beta26.splitFamilyFor(key) then return key end
    local axis = mod.exports.__beta26.routeCardinalAxes[key]
    if not axis then return key end
    x, y, width, height = tonumber(x), tonumber(y), tonumber(width), tonumber(height)
    if axis == "NS" and y and height and height > 0 then
        return key .. (y < height / 2 and "_NORTH" or "_SOUTH")
    elseif axis == "EW" and x and width and width > 0 then
        return key .. (x < width / 2 and "_WEST" or "_EAST")
    end
    -- Old catches without position provenance stay on the parent. Never
    -- guess a side, because doing so could silently spend the wrong slot.
    return key
end

-- 2.7.53: Safari Clause replaces the old binary Safari Splits selector while
-- preserving its persisted key for save compatibility. Modes 0/1 retain the
-- exact old STANDARD/PER AREA behavior; modes 2/3 add the community-style
-- Safari flee/failure exception without changing ordinary Failed Encounters.
mod.exports.__beta26.safariClauseMode = function()
    if type(mod.exports.__beta26.ruleOperationalState) == "function" then
        local ok = mod.exports.__beta26.ruleOperationalState(
            "safari_zone_splits", false, currentGameValue() or mod.game)
        if ok ~= true then return 0 end
    end
    return math.max(0, math.min(3, math.floor(tonumber(
        mod.save:get("safari_zone_splits", 0)) or 0)))
end

mod.exports.__beta26.safariClausePerArea = function()
    local mode = mod.exports.__beta26.safariClauseMode()
    return mode == 1 or mode == 3
end

mod.exports.__beta26.safariClauseUntilCatch = function()
    return mod.exports.__beta26.safariClauseMode() >= 2
end

mod.exports.__beta26.isSafariEncounterArea = function(key, physical)
    local zone = mod.exports.__beta26.encounterSplitAreas.safari
    key = routeKey(key) or key
    physical = routeKey(physical) or physical
    return key == zone.parent or zone.members[key] == true
        or physical == zone.parent or zone.members[physical] == true
end

mod.exports.__beta26.projectEncounterArea = function(mapId, safari, x, y,
    width, height)
    local key = routeKey(mapId)
    if safari == true and not key then key = "SAFARI_ZONE" end
    if not key then return nil end

    key = mod.exports.__beta26.cardinalPhysicalArea(
        key, x, y, width, height)

    local routeFamily = mod.exports.__beta26.splitFamilyFor(key)
    if routeFamily and routeFamily.parent:match("^ROUTE_%d+$") then
        local selector = routeFamily.selector
        return selector and mod.exports.__beta26.routeSplitActive(selector)
            and key or routeFamily.parent
    end

    local moon = mod.exports.__beta26.encounterSplitAreas.mt_moon
    if moon.members[key] then
        local mode = math.max(0, math.min(1,
            math.floor(tonumber(mod.save:get("mt_moon_splits", 0)) or 0)))
        return mode == 1 and key or moon.parent
    end

    local zone = mod.exports.__beta26.encounterSplitAreas.safari
    if zone.members[key] then
        return mod.exports.__beta26.safariClausePerArea() and key or zone.parent
    end
    if safari == true then return zone.parent end
    return key
end

H.encounterProviderHistory = function()
    local history = mod.save:get("encounter_provider_history")
    if type(history) ~= "table" then
        history = {}
        mod.save:set("encounter_provider_history", history)
    end
    return history
end

local function rememberEncounterProvider(providerId, providerVersion)
    if not providerId then return end
    local history = H.encounterProviderHistory()
    history[tostring(providerId)] = { version = providerVersion }
    mod.save:set("encounter_provider_history", history)
end

local function syncCaughtAreasFromLog()
    local areas = caughtAreas()
    local log = trackerLog()
    local changed = false

    for key, catches in pairs(log) do
        if key ~= "__LEGACY__" and areas[key] == nil and type(catches) == "table" then
            for _, entry in ipairs(catches) do
                if type(entry) == "table" and entry.species
                    and entry.consumedArea ~= false then
                    areas[key] = entry.species
                    changed = true
                    break
                end
            end
        end
    end

    if changed then
        mod.save:set("caught_areas", areas)
    end
    return areas
end

local function visitedAreas()
    local v = mod.save:get("visited_areas")

    if type(v) ~= "table" then
        v = {}
        mod.save:set("visited_areas", v)
    end

    return v
end

---------------------------------------------------------------------
-- AREA KEY
---------------------------------------------------------------------
mod.exports.__beta26.encounterPosition = function(game)
    local ow = game and game.overworld
    if not (ow and ow.map) and game and game.world and game.world.map then
        ow = game.world
    end
    if not (ow and ow.map) and game and game.stack
        and type(game.stack.states) == "table" then
        for i = #game.stack.states, 1, -1 do
            local state = game.stack.states[i]
            if state and state.isOverworld and state.map then
                ow = state
                break
            end
        end
    end
    local map = ow and ow.map
    local player = ow and ow.player
    local x = player and player.cellX
    local y = player and player.cellY
    if x == nil and game and game.save and game.save.player then
        x = game.save.player.x
        y = game.save.player.y
    end
    return x, y, map and map.widthCells, map and map.heightCells
end

mod.exports.__beta26.currentPhysicalArea = function(game, mapId)
    local x, y, width, height =
        mod.exports.__beta26.encounterPosition(game)
    return mod.exports.__beta26.cardinalPhysicalArea(
        mapId, x, y, width, height)
end

-- Gold encounter variants project from immutable method/time provenance so
-- toggling splits can safely regroup old catches without inventing history.
mod.exports.__beta26.goldTimeBucket = function(game)
    if not mod.exports.__beta26.runtimeIsGen2(game) then return nil end
    local world = game and game.world
    local daytime = tostring(world and world.daytime or ""):upper()
    if daytime == "MORN" or daytime == "MORNING" then return "MORN" end
    if daytime == "NITE" or daytime == "NIGHT" or daytime == "DARK" then
        return "NITE"
    end
    if daytime == "DAY" then return "DAY" end
    if world and type(world.hour) == "function" then
        local ok, hour = pcall(world.hour, world)
        hour = ok and tonumber(hour) or nil
        if hour then
            if hour >= 4 and hour < 10 then return "MORN" end
            if hour >= 18 or hour < 4 then return "NITE" end
            return "DAY"
        end
    end
    return "DAY"
end

mod.exports.__beta26.goldEncounterMethod = function(record)
    if type(record) ~= "table" then return "wild" end
    local method = tostring(record.encounterMethod
        or record.nuzlockeEncounterMethod or ""):lower()
    if method == "surf" then return "water" end
    if method ~= "" then return method end
    local encounterType = tostring(record.encounterType or ""):lower()
    if record.nuzlockeRoamerEncounter or encounterType == "roamer" then
        return "roamer"
    end
    if record.nuzlockeBugContest or encounterType == "bug_contest" then
        return "bug_contest"
    end
    if record.nuzlockeHeadbuttEncounter or encounterType == "headbutt" then
        return "headbutt"
    end
    if record.nuzlockeStaticEncounter or encounterType == "static" then
        return "static"
    end
    if encounterType == "fishing" then return "fishing" end
    if encounterType == "water" or encounterType == "surf" then return "water" end
    if encounterType == "grass" then return "grass" end
    return "wild" -- legacy records before explicit Gold method provenance
end

mod.exports.__beta26.projectGoldEncounterArea = function(game, base, record)
    base = routeKey(base) or base
    if not base or not mod.exports.__beta26.runtimeIsGen2(game) then return base end
    local method = mod.exports.__beta26.goldEncounterMethod(record)
    if method == "roamer" and mod.save:get("gold_roamer_clause", false) == true then
        local species = tostring(record and (record.roamerSpecies
            or record.nuzlockeRoamerSpecies or record.species) or "ROAMER"):upper()
        return "ROAMER_" .. species:gsub("[^A-Z0-9_%-]", "_")
    end
    if method == "bug_contest"
        and math.max(0, math.min(2, math.floor(tonumber(
            mod.save:get("gold_bug_contest_mode", 0)) or 0))) > 0 then
        return "NATIONAL_PARK_CONTEST"
    end
    if method == "headbutt"
        and mod.save:get("gold_headbutt_split", false) == true then
        return tostring(base) .. "_HEADBUTT"
    end
    if (method == "grass" or method == "wild")
        and mod.save:get("gold_time_split", false) == true then
        local bucket = record and (record.encounterTime
            or record.nuzlockeEncounterTime) or nil
        -- Legacy records that predate time provenance stay on their parent.
        if type(record) == "table" and bucket == nil then return base end
        bucket = bucket or mod.exports.__beta26.goldTimeBucket(game)
        bucket = tostring(bucket or "DAY"):upper()
        if bucket == "DARK" or bucket == "NIGHT" then bucket = "NITE" end
        if bucket ~= "MORN" and bucket ~= "NITE" then bucket = "DAY" end
        return tostring(base) .. "_" .. bucket
    end
    return base
end

mod.exports.__beta26.goldEncounterLedgerKey = function(game, physical, record)
    physical = routeKey(physical) or physical
    if not physical or not mod.exports.__beta26.runtimeIsGen2(game) then
        return physical
    end
    local method = mod.exports.__beta26.goldEncounterMethod(record)
    local suffix = method
    if method == "grass" or method == "wild" then
        local bucket = record and (record.encounterTime
            or record.nuzlockeEncounterTime) or nil
        if bucket == nil then return physical end
        suffix = tostring(method) .. "_" .. tostring(bucket):upper()
    elseif method == "roamer" then
        suffix = "roamer_" .. tostring(record and (record.roamerSpecies
            or record.nuzlockeRoamerSpecies or record.species) or "ROAMER"):upper()
    end
    return tostring(physical) .. "::"
        .. tostring(suffix):gsub("[^A-Z0-9_:%-]", "_"):upper()
end

local function areaKey(game, battle)
    if type(mod.exports.__beta26.ensureEncounterProjection) == "function" then
        pcall(mod.exports.__beta26.ensureEncounterProjection)
    end

    -- 2.4.58: battle encounter provenance is pin-once. Later catch,
    -- failure, and Ball-legality callbacks must not reinterpret the area
    -- from live overworld map/position/cardinal/time state.
    if battle and type(battle) == "table"
        and battle.nuzlockeEncounterAreaKey ~= nil then
        registerArea(battle.nuzlockeEncounterAreaKey)
        return battle.nuzlockeEncounterAreaKey
    end

    local mapId
    local x, y, width, height
    local physical

    if battle and type(battle) == "table"
        and battle.nuzlockeEncounterMapId ~= nil then
        physical = battle.nuzlockeEncounterMapId
        x = battle.nuzlockeEncounterX
        y = battle.nuzlockeEncounterY
    else
        if game and game.overworld and game.overworld.map then
            mapId = game.overworld.map.id
        end
        if not mapId and game and game.world and game.world.map then
            mapId = game.world.map.id
        end
        if not mapId and game and game.save and game.save.player then
            mapId = game.save.player.map
        end

        x, y, width, height =
            mod.exports.__beta26.encounterPosition(game)
        physical = mod.exports.__beta26.cardinalPhysicalArea(
            mapId, x, y, width, height)

        if battle and type(battle) == "table" then
            battle.nuzlockeEncounterMapId =
                battle.nuzlockeEncounterMapId or physical
            battle.nuzlockeEncounterX =
                battle.nuzlockeEncounterX or x
            battle.nuzlockeEncounterY =
                battle.nuzlockeEncounterY or y
        end
    end

    if battle and type(battle) == "table"
        and mod.exports.__beta26.runtimeIsGen2(game) then
        battle.nuzlockeEncounterTime = battle.nuzlockeEncounterTime
            or mod.exports.__beta26.goldTimeBucket(game)
        battle.nuzlockeEncounterMethod =
            battle.nuzlockeEncounterMethod
            or mod.exports.__beta26.goldEncounterMethod(battle)
    end

    local base = mod.exports.__beta26.projectEncounterArea(
        physical, battle and battle.safari == true)
    local target = battle and mod.exports.__beta26.projectGoldEncounterArea(
        game, base, battle) or base

    if battle and type(battle) == "table" and target then
        battle.nuzlockeEncounterAreaKey =
            battle.nuzlockeEncounterAreaKey or target
        target = battle.nuzlockeEncounterAreaKey
    end

    if target then registerArea(target) end
    return target
end

---------------------------------------------------------------------
-- MARK AREA VISITED
---------------------------------------------------------------------
local function markVisited(key, x, y, width, height)
    local physical = mod.exports.__beta26.cardinalPhysicalArea(
        key, x, y, width, height)
    key = registerArea(mod.exports.__beta26.projectEncounterArea(physical))

    if not isTrackedArea(key) then
        return false
    end

    if physical then
        local ledger = mod.save:get("encounter_visited_map_ids", {})
        if type(ledger) ~= "table" then ledger = {} end
        ledger[physical] = true
        mod.save:set("encounter_visited_map_ids", ledger)
    end

    local v = visitedAreas()

    if not v[key] then
        v[key] = true
        mod.save:set("visited_areas", v)
    end

    return true
end

---------------------------------------------------------------------
-- MARK AREA CAUGHT
---------------------------------------------------------------------
local function markCaught(key, species)
    key = registerArea(key)

    if not isTrackedArea(key) then
        return
    end

    local areas = caughtAreas()

    if areas[key] == nil then
        areas[key] = species
        mod.save:set("caught_areas", areas)
    end
end

---------------------------------------------------------------------
-- NORMALIZE AN OLD TABLE OF MAP KEYS
--
-- Converts old:
--     PalletTown = true
--
-- into:
--     PALLET_TOWN = true
---------------------------------------------------------------------
local function normalizeMapTable(tbl)
    if type(tbl) ~= "table" then
        return {}, true
    end

    local normalized = {}
    local changed = false

    for rawKey, value in pairs(tbl) do
        local key = routeKey(rawKey)

        if key then
            registerArea(key)
            normalized[key] = value
            if tostring(rawKey) ~= key then
                changed = true
            end
        else
            -- Preserve unknown data rather than silently deleting it.
            normalized[rawKey] = value
        end
    end

    return normalized, changed
end

---------------------------------------------------------------------
-- NORMALIZE TRACKER LOG
---------------------------------------------------------------------
local function normalizeTrackerLog(log)
    if type(log) ~= "table" then
        return {}, true
    end

    local normalized = {}
    local changed = false

    for rawKey, catches in pairs(log) do
        local key = routeKey(rawKey)

        if key then
            registerArea(key)
            normalized[key] = normalized[key] or {}

            if type(catches) == "table" then
                for _, catch in ipairs(catches) do
                    if type(catch) == "table" then
                        table.insert(normalized[key], {
                            species = catch.species,
                            pokemonId = catch.pokemonId,
                            fingerprint = catch.fingerprint,
                            isShiny = catch.isShiny == true,
                            consumedArea = catch.consumedArea,
                            encounterType = catch.encounterType,
                            encounterMapId = catch.encounterMapId,
                            encounterSource = catch.encounterSource,
                            encounterProvider = catch.encounterProvider,
                            encounterProviderVersion = catch.encounterProviderVersion,
                            encounterContext = catch.encounterContext,
                            retroactive = catch.retroactive == true,
                            legacy = catch.legacy == true,
                            provenance = catch.provenance or (catch.legacy == true and "LEGACY" or nil),
                            recoveryStatus = catch.recoveryStatus,
                            possibleAreas = (function()
                                if type(catch.possibleAreas) ~= "table" then return nil end
                                local ids = {}
                                for _, area in ipairs(catch.possibleAreas) do
                                    if type(area) == "table" then
                                        area = area.id or area.mapId or area.key
                                    end
                                    if area then
                                        local key = routeKey(area)
                                        if key then ids[#ids + 1] = key end
                                    end
                                end
                                return #ids > 0 and ids or nil
                            end)()
                        })
                    end
                end
            end

            if tostring(rawKey) ~= key then
                changed = true
            end
        else
            -- Keep legacy/unknown tracker entries.
            normalized[rawKey] = catches
        end
    end

    return normalized, changed
end

---------------------------------------------------------------------
-- RETROACTIVE SAVE RECONSTRUCTION
--
-- This is deliberately best-effort.
--
-- The vanilla save has:
--   save.visited       -> vanilla town/fly visitation history
--   save.player.map    -> current location
--   save.party         -> current party
--   save.boxes         -> PC Pokemon
--
-- The engine does NOT store a historical route-travel log or a native
-- catch-location on Pokemon. Therefore we cannot truthfully recreate
-- every route ever walked or exact locations of old Pokemon.
--
-- We do, however:
--   1. import vanilla visited-area information
--   2. mark the current location visited
--   3. preserve/normalize old mod tracker data
--   4. display pre-mod Pokemon under LEGACY
---------------------------------------------------------------------


local function restoreKnownCatchMetadata(save, log)
    -- Imported/old Gen 1 saves do not serialize our transient Pokemon fields.
    -- Rebuild those fields from the Nuzlocke tracker data when the tracker
    -- already knows the species/location. This is stronger evidence than
    -- vanilla encounter inference and prevents legitimate old catches from
    -- being demoted to LEGACY merely because the Pokemon object lost its
    -- runtime metadata during save conversion.
    local assignments = {}
    local assignmentsById = {}

    local function addEvidence(area, entry)
        if area == "__LEGACY__" or type(entry) ~= "table" or not entry.species then
            return
        end
        local sp = tostring(entry.species):upper()
        local evidence = {
            area = area,
            pokemonId = entry.pokemonId,
            fingerprint = entry.fingerprint,
            provenance = entry.provenance,
            encounterType = entry.encounterType,
            encounterSource = entry.encounterSource,
            encounterProvider = entry.encounterProvider,
            encounterProviderVersion = entry.encounterProviderVersion,
            encounterContext = entry.encounterContext,
        }
        assignments[sp] = assignments[sp] or {}
        assignments[sp][#assignments[sp] + 1] = evidence
        if entry.pokemonId then assignmentsById[tostring(entry.pokemonId)] = evidence end
    end

    for area, entries in pairs(log or {}) do
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                addEvidence(area, entry)
            end
        end
    end

    -- Older versions also kept one authoritative species per area in
    -- caught_areas. Use it as recovery evidence if the detailed tracker log
    -- was not present, or if an imported Pokemon lost its transient fields.
    local areaTable = caughtAreas()
    for area, species in pairs(areaTable) do
        if area ~= "__LEGACY__" and species then
            local sp = tostring(species):upper()
            assignments[sp] = assignments[sp] or {}
            local already = false
            for _, ev in ipairs(assignments[sp]) do
                if ev.area == area then already = true; break end
            end
            if not already then
                assignments[sp][#assignments[sp] + 1] = { area = area }
            end
        end
    end

    local used = {}
    for _, mon in ipairs(Identity.collectLegacyMons(save)) do
        if type(mon) == "table" and mon.species and not mon.catchLocation then
            local sp = tostring(mon.species):upper()
            local monId = Identity.pokemonIdentity(mon)
            local evidence = monId and assignmentsById[monId] or nil
            local usedKey

            if evidence then
                usedKey = "ID:" .. monId
            else
                local list = assignments[sp]
                local slot = list and 1 or nil
                while slot and used[sp .. ":" .. tostring(slot)] do
                    slot = slot + 1
                    if not list[slot] then slot = nil end
                end
                evidence = slot and list[slot] or nil
                usedKey = slot and (sp .. ":" .. tostring(slot)) or nil
            end

            if evidence and evidence.area and not (usedKey and used[usedKey]) then
                if usedKey then used[usedKey] = true end
                if not mon.nuzlockeId and evidence.pokemonId then
                    mon.nuzlockeId = tostring(evidence.pokemonId)
                end
                if evidence.provenance and not mon.nuzlockeOrigin then
                    mon.nuzlockeOrigin = evidence.provenance
                end
                mon.catchLocation = evidence.area
                mon.encounterType = evidence.encounterType or mon.encounterType or "wild"
                mon.nuzlockeEncounterSource = evidence.encounterSource or mon.nuzlockeEncounterSource
                mon.nuzlockeEncounterProvider = evidence.encounterProvider or mon.nuzlockeEncounterProvider
                mon.nuzlockeEncounterProviderVersion = evidence.encounterProviderVersion or mon.nuzlockeEncounterProviderVersion
                if evidence.encounterContext then
                    mon.nuzlockeEncounterContext = evidence.encounterContext
                end
                mon.nuzlockeTrackerRegistered = true
                Identity.ensurePokemonIdentity(mon, save, mon.nuzlockeOrigin or evidence.provenance or "NORMAL")
            end
        end
    end
end

-- Rebuild tracker entries from catch-location metadata that survived
-- mod removal/reinstallation.  Catch Info can still know a Pokemon was
-- caught on (for example) Route 1 even when tracker_log/caught_areas were
-- lost with an older mod install.  That metadata is stronger evidence than
-- species-only encounter inference, so restore it directly.
local function importStoredCatchLocations(save, log, areas)
    local changed = false

    for _, mon in ipairs(Identity.collectLegacyMons(save)) do
        if type(mon) == "table" and mon.species and mon.catchLocation then
            local area = resolveCatchLocation(mon.catchLocation)
            if area then
                area = registerArea(area)
            end

            if area and isTrackedArea(area) then
                log[area] = log[area] or {}
                local sp = tostring(mon.species):upper()
                local found = false
                local monId = Identity.ensurePokemonIdentity(mon, save, mon.nuzlockeOrigin or "LEGACY")
                for _, entry in ipairs(log[area]) do
                    if type(entry) == "table"
                        and ((monId and entry.pokemonId == monId)
                            or tostring(entry.species or ""):upper() == sp) then
                        found = true
                        entry.pokemonId = entry.pokemonId or monId
                        entry.fingerprint = entry.fingerprint or Identity.fingerprint(mon)
                        break
                    end
                end

                -- Respect the one-catch-per-area rule when the area already
                -- contains a different species.  We only restore missing
                -- historical evidence; we never overwrite an established
                -- catch.
                if not found and #log[area] == 0 then
                    table.insert(log[area], {
                        species = sp,
                        pokemonId = Identity.ensurePokemonIdentity(mon, save, mon.nuzlockeOrigin or "LEGACY"),
                        fingerprint = Identity.fingerprint(mon),
                        isShiny = Identity.isShiny(mon),
                        encounterType = mon.encounterType or "wild",
                        encounterSource = mon.nuzlockeEncounterSource or "stored",
                        encounterProvider = mon.nuzlockeEncounterProvider,
                        encounterProviderVersion = mon.nuzlockeEncounterProviderVersion,
                        encounterContext = mon.nuzlockeEncounterContext,
                        retroactive = true,
                        recoveryStatus = "STORED_LOCATION",
                    })
                    areas[area] = sp
                    markVisited(area)
                    changed = true
                    mon.nuzlockeTrackerRegistered = true
                elseif found then
                    if areas[area] == nil then
                        areas[area] = sp
                        markVisited(area)
                        changed = true
                    end
                    mon.nuzlockeTrackerRegistered = true
                else
                    -- A different catch is already established for this area.
                    -- Do not falsely claim this mon as recovered. Clearing
                    -- the stale location keeps it eligible for Legacy Recovery
                    -- instead of orphaning it from every recovery path.
                    mon.catchLocation = nil
                    mon.nuzlockeTrackerRegistered = nil
                    changed = true
                end
            end
        end
    end

    if changed then
        mod.save:set("tracker_log", log)
        mod.save:set("caught_areas", areas)
    end
    return changed
end

local function addLegacyMonsToLog(save)
    local log = trackerLog()
    restoreKnownCatchMetadata(save, log)
    local legacy = log.__LEGACY__

    if type(legacy) ~= "table" then
        legacy = {}
    end

    local existing = {}
    local existingIds = {}

    for _, entry in ipairs(legacy) do
        if type(entry) == "table" then
            local species = tostring(entry.species or "")
            existing[species] = (existing[species] or 0) + 1
            if entry.pokemonId then existingIds[tostring(entry.pokemonId)] = true end
        end
    end

    local currentCounts = {}
    local provenanceInitialized =
        mod.save:get("nuzlocke_provenance_initialized", false) == true

    -- A Pokemon with catchLocation was caught after the tracker was active.
    -- It must never be copied into LEGACY just because it is present in the
    -- current save's party/boxes.
    for _, mon in ipairs(Identity.collectLegacyMons(save)) do
        if not mon.catchLocation then
            local species = tostring(mon.species or "")
            local monId = Identity.existingPokemonIdentity(mon)
            local registryEntry = monId and Identity.identityRegistry()[monId] or nil
            local knownOrigin = type(registryEntry) == "table" and registryEntry.origin
                or mon.nuzlockeOrigin

            -- Once provenance has been initialized, a brand-new unregistered
            -- Pokemon belongs to the EDITED classifier, not the legacy bucket.
            local mayBeLegacy = not provenanceInitialized
                or knownOrigin == "LEGACY"

            if mayBeLegacy then
                monId = monId or Identity.ensurePokemonIdentity(mon, save, nil)
                currentCounts[species] = (currentCounts[species] or 0) + 1

                if not (monId and existingIds[monId])
                    and currentCounts[species] > (existing[species] or 0) then
                    table.insert(legacy, {
                        species = species,
                        pokemonId = monId,
                        fingerprint = Identity.fingerprint(mon),
                        isShiny = Identity.isShiny(mon),
                        legacy = true,
                        provenance = "LEGACY",
                    })
                    if monId then existingIds[monId] = true end
                end
            end
        end
    end

    -- Remove accidental legacy entries for Pokemon that the tracker already
    -- knows were caught in a real area.  This repairs saves that were loaded
    -- by an earlier version which incorrectly added current Pokemon to
    -- LEGACY.
    local knownCaught = {}
    local knownCaughtIds = {}
    for area, catches in pairs(log) do
        if area ~= "__LEGACY__" and type(catches) == "table" then
            for _, catch in ipairs(catches) do
                if type(catch) == "table" and catch.species then
                    knownCaught[tostring(catch.species)] = true
                    if catch.pokemonId then
                        knownCaughtIds[tostring(catch.pokemonId)] = true
                    end
                end
            end
        end
    end

    local cleanedLegacy = {}
    for _, entry in ipairs(legacy) do
        if type(entry) == "table" and entry.species then
            local duplicate
            if entry.pokemonId then
                duplicate = knownCaughtIds[tostring(entry.pokemonId)] == true
            else
                -- Pre-beta.19 rows have no persistent Pokemon identity;
                -- retain species-only cleanup strictly as a migration fallback.
                duplicate = knownCaught[tostring(entry.species)] == true
            end
            if not duplicate then table.insert(cleanedLegacy, entry) end
        end
    end

    if #cleanedLegacy > 0 then
        log.__LEGACY__ = cleanedLegacy
    else
        log.__LEGACY__ = nil
    end

    mod.save:set("tracker_log", log)
end

---------------------------------------------------------------------
-- LEGACY CATCH RECOVERY
--
-- Existing Gen 1 saves do not contain a native catch-location field.
-- We therefore recover only information that is provable from current
-- game data:
--
--   EXACT      = known gift/trade/starter location
--   UNIQUE     = species occurs in exactly one wild area in the loaded
--                encounter data
--   AMBIGUOUS  = multiple possible wild areas; player chooses
--   UNKNOWN    = no safe location can be inferred
--
-- Never guess between multiple routes.
---------------------------------------------------------------------
local function encounterSpeciesByArea(game)
    local result = {}
    local data = game and game.data
    local encounters = data and data.encounters

    if type(encounters) ~= "table" then
        return result
    end

    for rawArea, def in pairs(encounters) do
        local area = registerArea(rawArea)
        if area and type(def) == "table" then
            local speciesSet = {}
            local function scan(node)
                if type(node) ~= "table" then return end
                if type(node.species) == "string" then
                    speciesSet[tostring(node.species):upper()] = true
                end
                for k, v in pairs(node) do
                    if k ~= "species" and type(v) == "table" then
                        scan(v)
                    end
                end
            end
            scan(def)

            if next(speciesSet) then
                result[area] = speciesSet
            end
        end
    end
    return result
end

local function legacyCandidates(game, species)
    species = tostring(species or ""):upper()
    if species == "" then return {} end

    local encounterAreas = encounterSpeciesByArea(game)
    local candidates = {}
    for area, speciesSet in pairs(encounterAreas) do
        if speciesSet[species] then
            candidates[#candidates + 1] = area
        end
    end

    table.sort(candidates, function(a, b)
        return (ROUTE_ORDER[a] or 999999) < (ROUTE_ORDER[b] or 999999)
    end)
    return candidates
end

local function recoverUniqueLegacyCatches(game, log, areas, gameVersion)
    local legacy = log["__LEGACY__"]
    if type(legacy) ~= "table" then return false end

    -- Never infer historical locations from vanilla encounter data when an
    -- external encounter provider is active or has been observed earlier in
    -- this save. The provider's historical context is authoritative.
    local providerHistory = mod.save:get("encounter_provider_history")
    if type(providerHistory) == "table" and next(providerHistory) ~= nil then
        return false
    end
    if activeCompatProvider("encounters", currentGameValue(), nil) then
        return false
    end

    local changed = false
    local remaining = {}

    -- Only use a static acquisition source when the CURRENT species is
    -- genuinely provenance-deterministic in that version. Species that can
    -- also be caught wild, obtained as a static encounter, or reached by
    -- evolution must remain candidates for player-assisted recovery instead
    -- of being force-labeled as a gift/trade. This table intentionally stays
    -- smaller than the live gift/trade catalog.
    local known = {
        HITMONCHAN = { area = "SAFFRON_CITY", type = "gift" },
        HITMONLEE = { area = "SAFFRON_CITY", type = "gift" },
        LAPRAS = { area = "SILPH_CO", type = "gift" },
        EEVEE = { area = "CELADON_CITY", type = "gift" },
        OMANYTE = { area = "CINNABAR_ISLAND", type = "gift" },
        KABUTO = { area = "CINNABAR_ISLAND", type = "gift" },
        AERODACTYL = { area = "CINNABAR_ISLAND", type = "gift" },
        PORYGON = { area = "CELADON_CITY", type = "gift" },
    }

    local legacyVersion = tostring(gameVersion or ""):upper()
    -- Species with a valid special source but another plausible origin must
    -- never be auto-resolved from a single current-species wild table. Some
    -- can also be caught wild; others can be evolved from a Pokemon obtained
    -- elsewhere. Give these to player-assisted UNKNOWN recovery instead.
    local needsPlayerRecovery = { MAGIKARP = true }
    if legacyVersion == "YELLOW" then
        known.BULBASAUR = { area = "CERULEAN_CITY", type = "gift" }
        known.CHARMANDER = { area = "ROUTE_24", type = "gift" }
        known.SQUIRTLE = { area = "VERMILION_CITY", type = "gift" }
        known.MR_MIME = { area = "ROUTE_2", type = "trade" }
        for _, species in ipairs({
            "SCYTHER", "PINSIR", "DUGTRIO", "MUK", "PARASECT",
            "RHYDON", "DEWGONG", "MACHOKE",
        }) do needsPlayerRecovery[species] = true end
    elseif legacyVersion == "RED" or legacyVersion == "BLUE" then
        known.JYNX = { area = "CERULEAN_CITY", type = "trade" }
        known.FARFETCHD = { area = "VERMILION_CITY", type = "trade" }
        known.MR_MIME = { area = "ROUTE_2", type = "trade" }
        known.LICKITUNG = { area = "ROUTE_18", type = "trade" }
        for _, species in ipairs({
            "NIDORINA", "SEEL", "ELECTRODE", "TANGELA", "NIDORAN_F",
            "DRATINI",
        }) do needsPlayerRecovery[species] = true end
        if legacyVersion == "RED" then
            needsPlayerRecovery.SCYTHER = true
        else
            needsPlayerRecovery.PINSIR = true
        end
    else
        -- The legacy source catalog below is Gen-I-specific. Gold and any
        -- future generation must not inherit Kanto gift/trade assumptions.
        return false
    end

    for _, entry in ipairs(legacy) do
        local sp = tostring(entry and entry.species or ""):upper()
        local candidates = legacyCandidates(game, sp)
        local knownSource = known[sp]

        if knownSource then
            -- Static gifts/trades are exact historical sources. Do not let
            -- the one-catch-per-area runtime rule prevent migration from
            -- restoring a legitimate additional gift/trade on an area.
            candidates = { knownSource.area }
        elseif needsPlayerRecovery[sp] then
            -- A single wild-table hit is not proof when another special or
            -- pre-evolution origin is possible. Empty candidates intentionally
            -- route to UNKNOWN below, whose UI offers the full area list.
            candidates = {}
        end

        if #candidates == 1 then
            local area = candidates[1]
            log[area] = log[area] or {}
            local exists = false
            for _, existing in ipairs(log[area]) do
                if tostring(existing.species or ""):upper() == sp then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(log[area], {
                    species = sp,
                    pokemonId = entry.pokemonId,
                    fingerprint = entry.fingerprint,
                    isShiny = entry.isShiny == true,
                    encounterType = knownSource and knownSource.type or "wild",
                    encounterSource = "vanilla",
                    recoveryStatus = "DETERMINED",
                    retroactive = true,
                })
            end
            if areas[area] == nil then
                areas[area] = sp
            end
            markVisited(area)
            changed = true
        else
            entry.recoveryStatus = (#candidates > 1) and "AMBIGUOUS"
                or "UNKNOWN"
            entry.possibleAreas = candidates
            if #candidates == 0 then
                -- A save-editor/imported Pokemon (for example BLASTOISE) may
                -- not exist in any wild encounter table. It is still valid to
                -- ask the player where it belongs; recovery must never depend
                -- on the species being a wild encounter.
                entry.possibleAreas = {}
                for _, areaDef in ipairs(getDisplayRoutesLive(game)) do
                    entry.possibleAreas[#entry.possibleAreas + 1] = areaDef.id
                end
                entry.recoveryStatus = "UNKNOWN"
            end
            table.insert(remaining, entry)
        end
    end

    if #remaining > 0 then
        log["__LEGACY__"] = remaining
    else
        log["__LEGACY__"] = nil
    end

    return changed
end

local function recoverLegacyEntriesFromProvider(save, log)
    local provider = activeCompatProvider("encounters", currentGameValue(), nil)
    if not provider then return log end
    local legacy = log["__LEGACY__"] or {}
    local remaining = {}
    for _, entry in ipairs(legacy) do
        local recovered = H.providerRecover(provider, save, { species = entry.species, dvs = entry.dvs })
        if recovered and recovered.location then
            local area = registerArea(recovered.location, recovered.areaName)
            local areas = caughtAreas()
            if area and not areas[area] then
                log[area] = log[area] or {}
                table.insert(log[area], {
                    species = tostring(entry.species):upper(),
                    pokemonId = entry.pokemonId,
                    fingerprint = entry.fingerprint,
                    isShiny = entry.isShiny == true,
                    encounterType = recovered.encounterType or "wild",
                    encounterSource = "provider",
                    encounterProvider = provider.id,
                    encounterProviderVersion = provider.version,
                    encounterContext = recovered.context,
                    retroactive = true,
                    recoveryStatus = "PROVIDER",
                })
                areas[area] = tostring(entry.species):upper()
                mod.save:set("caught_areas", areas)
                markVisited(area)
            else
                table.insert(remaining, entry)
            end
        else
            entry.recoveryStatus = entry.recoveryStatus or "UNKNOWN"
            entry.encounterSource = entry.encounterSource or "unknown"
            table.insert(remaining, entry)
        end
    end
    if #remaining > 0 then log["__LEGACY__"] = remaining else log["__LEGACY__"] = nil end
    mod.save:set("tracker_log", log)
    return log
end

---------------------------------------------------------------------
-- REBUILD TRACKER FROM AN EXISTING SAVE
---------------------------------------------------------------------
local function rebuildTrackerFromSave(save)
    if type(save) ~= "table" then
        return
    end

    if type(mod.save:get("encounter_provider_history")) ~= "table" then
        mod.save:set("encounter_provider_history", {})
    end

    -------------------------------------------------------------------
    -- 1. Normalize anything already stored by older versions.
    -------------------------------------------------------------------
    local oldVisited = mod.save:get("visited_areas")

    if type(oldVisited) == "table" then
        local normalizedVisited, changed =
            normalizeMapTable(oldVisited)

        if changed then
            mod.save:set("visited_areas", normalizedVisited)
        end
    else
        mod.save:set("visited_areas", {})
    end

    local oldCaught = mod.save:get("caught_areas")

    if type(oldCaught) == "table" then
        local normalizedCaught, changed =
            normalizeMapTable(oldCaught)

        if changed then
            mod.save:set("caught_areas", normalizedCaught)
        end
    else
        mod.save:set("caught_areas", {})
    end

    local oldLog = mod.save:get("tracker_log")

    if type(oldLog) == "table" then
        local normalizedLog, changed =
            normalizeTrackerLog(oldLog)

        if changed then
            mod.save:set("tracker_log", normalizedLog)
        end
    else
        mod.save:set("tracker_log", {})
    end

    syncCaughtAreasFromLog()
    if type(mod.save:get("nuzlocke_losses")) ~= "number" then
        mod.save:set("nuzlocke_losses", 0)
    end

    -- beta.29.2.0: legacy nuzlocke_history used status="LOST" for owned
    -- Pokemon deaths. Encounter opportunities have always lived in
    -- encounter_states as status="FAILED". Migrate only rows that carry
    -- death evidence so older saves gain unambiguous DEAD semantics without
    -- rewriting unrelated or partially recovered history.
    local oldHistory = mod.save:get("nuzlocke_history")
    if type(oldHistory) == "table" then
        local historyChanged = false
        for _, row in ipairs(oldHistory) do
            if type(row) == "table" and row.status == "LOST"
                and (row.deathLocation ~= nil or row.deathCause ~= nil
                    or row.deathOpponentSpecies ~= nil) then
                row.status = "DEAD"
                historyChanged = true
            end
        end
        if historyChanged then mod.save:set("nuzlocke_history", oldHistory) end
    end

    -------------------------------------------------------------------
    -- 2. Discover every map definition exposed by the current build.
    -------------------------------------------------------------------
    discoverAllKnownAreas({ data = nil, save = save })

    -------------------------------------------------------------------
    -- 3. Import the vanilla save's visited table.
    --
    -- The engine itself stores vanilla town visitation in save.visited.
    -------------------------------------------------------------------
    if type(save.visited) == "table" then
        for mapId, wasVisited in pairs(save.visited) do
            if wasVisited then
                registerArea(mapId)
                markVisited(mapId)
            end
        end
    end

    -------------------------------------------------------------------
    -- 3. Always mark the player's current map.
    --
    -- This fixes old saves even when they have never been seen by the
    -- Nuzlocke mod before.
    -------------------------------------------------------------------
    if save.player and save.player.map then
        markVisited(save.player.map)
    end

    -------------------------------------------------------------------
    -- 4. Also use lastOutdoor/lastHeal when they refer to a tracked map.
    --
    -- These aren't a complete travel history, but they are reliable
    -- save-state evidence that the map was relevant to the playthrough.
    -------------------------------------------------------------------
    if type(save.lastOutdoor) == "table" then
        markVisited(save.lastOutdoor.id)
    end

    if type(save.lastHeal) == "table" then
        markVisited(save.lastHeal.map)
    end

    -------------------------------------------------------------------
    -- 5. Preserve any old mod catch log.
    --
    -- We intentionally DO NOT fabricate locations for old Pokemon.
    -------------------------------------------------------------------
    addLegacyMonsToLog(save)

    -- Restore tracker rows from persistent Pokemon catch locations before
    -- attempting any species-based legacy inference.
    importStoredCatchLocations(save, trackerLog(), caughtAreas())

    -------------------------------------------------------------------
    -- 6. Retroactive save compatibility.
    --
    -- If PALLET_TOWN has no caught entry yet, but the party/boxes
    -- contain a starter species, assign it now.  This handles saves
    -- that existed before starter tracking was added.
    --
    -- Similarly, any LEGACY-tagged Pokemon whose species exactly
    -- matches a known gift location is moved to that area's slot,
    -- provided that slot is still empty.
    -------------------------------------------------------------------
    local areas = caughtAreas()
    local log   = trackerLog()

    -- Let an active encounter provider recover its own historical data first.
    log = recoverLegacyEntriesFromProvider(save, log)

    -- Use the same defensive version detector everywhere. Keeping version
    -- logic centralized prevents another recovery-only scope/detection drift.
    local rebuildVersion = getGameVersionLive() or "RED"

    -- 6a. Starter → PALLET_TOWN
    if not areas["PALLET_TOWN"] then
        local starterSets = {}
        if rebuildVersion == "YELLOW" then
            starterSets.PIKACHU = true
        else
            starterSets.BULBASAUR = true
            starterSets.CHARMANDER = true
            starterSets.SQUIRTLE = true
        end
        local function findStarterInList(list)
            for _, mon in ipairs(list or {}) do
                if mon and starterSets[tostring(mon.species or ""):upper()] then
                    return mon
                end
            end
            return nil
        end

        local starterMon = findStarterInList(save.party)
        if not starterMon then
            mod.exports.__beta26.forEachExistingSaveBox(save, function(box)
                starterMon = findStarterInList(box)
                if starterMon then return false end
            end)
        end

        if starterMon then
            local sp = tostring(starterMon.species or ""):upper()
            registerArea("PALLET_TOWN")
            log["PALLET_TOWN"] = log["PALLET_TOWN"] or {}

            -- Only insert if not already in the log for this area.
            local alreadyLogged = false
            for _, entry in ipairs(log["PALLET_TOWN"]) do
                if tostring(entry.species or ""):upper() == sp then
                    alreadyLogged = true; break
                end
            end
            if not alreadyLogged then
                table.insert(log["PALLET_TOWN"], {
                    species       = sp,
                    pokemonId     = Identity.ensurePokemonIdentity(starterMon, save, starterMon.nuzlockeOrigin or "LEGACY"),
                    fingerprint   = Identity.fingerprint(starterMon),
                    isShiny       = Identity.isShiny(starterMon),
                    encounterType = "gift",
                    retroactive   = true,
                })
            end

            areas["PALLET_TOWN"] = sp
            markVisited("PALLET_TOWN")

            -- Tag the mon so future loads don't re-assign it.
            if not starterMon.catchLocation then
                starterMon.catchLocation = "PALLET_TOWN"
                starterMon.encounterType = "gift"
            end

            -- The old-save scan may have placed this starter in LEGACY
            -- before we recognized it. Remove exactly one matching legacy
            -- entry so it cannot later be mistaken for a second catch.
            local legacyEntries = log["__LEGACY__"]
            if type(legacyEntries) == "table" then
                local removed = false
                local keptLegacy = {}
                for _, entry in ipairs(legacyEntries) do
                    if not removed
                        and tostring(entry.species or ""):upper() == sp then
                        removed = true
                    else
                        table.insert(keptLegacy, entry)
                    end
                end
                if #keptLegacy > 0 then
                    log["__LEGACY__"] = keptLegacy
                else
                    log["__LEGACY__"] = nil
                end
            end
        end
    end

    -- 6b. Recover provable legacy catches from static sources and the
    -- current encounter tables. Ambiguous catches remain in LEGACY for
    -- player-assisted recovery.
    recoverUniqueLegacyCatches(currentGameValue()
        or { data = require("src.core.Data"), save = save },
        log, areas, rebuildVersion)

    -- Repair old bad migration data only. Red/Blue do not have a Route 24
    -- Charmander gift. Older builds could create one during migration, and
    -- older normalization could strip the retroactive marker.
    if rebuildVersion ~= "YELLOW" then
        local entries = log["ROUTE_24"]
        if type(entries) == "table" then
            local kept = {}
            for _, entry in ipairs(entries) do
                local species = tostring(entry and entry.species or ""):upper()
                local encounterType = tostring(entry and entry.encounterType or ""):lower()
                local migratedCharmander =
                    species == "CHARMANDER"
                    and (entry.retroactive == true or encounterType == "gift")
                if not migratedCharmander then
                    kept[#kept + 1] = entry
                end
            end
            if #kept > 0 then
                log["ROUTE_24"] = kept
            else
                log["ROUTE_24"] = nil
                areas["ROUTE_24"] = nil
            end
        end

        -- Red/Blue never have a Charmander gift on Route 24. Older
        -- migration code could nevertheless manufacture one. Remove every
        -- non-Pallet Charmander so the starter remains the single Charmander
        -- encounter shown by the log.
        for areaKeyValue, entries in pairs(log) do
            if areaKeyValue ~= "PALLET_TOWN" and type(entries) == "table" then
                local kept = {}
                for _, entry in ipairs(entries) do
                    if tostring(entry and entry.species or ""):upper() ~= "CHARMANDER" then
                        kept[#kept + 1] = entry
                    end
                end
                if #kept > 0 then
                    log[areaKeyValue] = kept
                else
                    log[areaKeyValue] = nil
                    areas[areaKeyValue] = nil
                end
            end
        end
    end

    -- De-duplicate identical species entries inside a single area. This is
    -- deliberately per-area: legitimate gift/trade species can coexist in
    -- the same city, but the same species must never be logged twice for the
    -- same encounter area.
    for areaKeyValue, entries in pairs(log) do
        if type(entries) == "table" then
            local seenSpecies = {}
            local kept = {}
            for _, entry in ipairs(entries) do
                if type(entry) == "table" and entry.species then
                    local speciesKey = tostring(entry.species):upper()
                    if not seenSpecies[speciesKey] then
                        seenSpecies[speciesKey] = true
                        kept[#kept + 1] = entry
                    end
                end
            end
            if #kept > 0 then
                log[areaKeyValue] = kept
            elseif areaKeyValue ~= "__LEGACY__" then
                log[areaKeyValue] = nil
                areas[areaKeyValue] = nil
            end
        end
    end

    -------------------------------------------------------------------
    -- RECONCILE EXISTING POKEMON CATCH METADATA
    --
    -- Older/vanilla saves can retain catchLocation directly on the
    -- Pokemon even when this mod never saw the original catch.  The old
    -- migration only copied those Pokemon into __LEGACY__, which meant
    -- Catch Info could show ROUTE 1 while the encounter map/list showed
    -- nothing and encounter type remained UNKNOWN.
    --
    -- Treat an existing catchLocation as authoritative historical evidence.
    -- Do not infer a location from species here; use only data actually
    -- stored on the Pokemon.  This also keeps imported/edited Pokemon with
    -- no catchLocation available for player-assisted recovery.
    -------------------------------------------------------------------
    local function reconcilePokemonCatchLocations()
        local changed = false
        local mons = Identity.collectLegacyMons(save)

        local function normalizeType(mon)
            local value = mon and (mon.nuzlockeEncounterType or mon.encounterType)
            if value == nil or tostring(value) == "" then
                return "wild"
            end
            return tostring(value):lower()
        end

        local function samePokemonEntry(entry, mon)
            return Identity.samePokemonIdentity(entry, mon)
        end

        for _, mon in ipairs(mons) do
            if type(mon) == "table" and mon.species and mon.catchLocation then
                local area = resolveCatchLocation(mon.catchLocation)
                if area and area ~= "" and area ~= "__LEGACY__" then
                    area = registerArea(area)
                    if area then
                        log[area] = log[area] or {}

                    local exists = false
                    for _, entry in ipairs(log[area]) do
                        if samePokemonEntry(entry, mon) then
                            exists = true
                            -- Fill missing historical metadata without
                            -- overwriting richer data already recorded.
                            entry.encounterType = entry.encounterType
                                or mon.nuzlockeEncounterType
                                or mon.encounterType
                                or "wild"
                            entry.isShiny = entry.isShiny == true
                                or (Identity.isShiny(mon))
                            entry.pokemonId = entry.pokemonId
                                or Identity.ensurePokemonIdentity(mon, save, mon.nuzlockeOrigin or "LEGACY")
                            entry.fingerprint = entry.fingerprint or Identity.fingerprint(mon)
                            entry.retroactive = entry.retroactive or true
                            entry.recoveryStatus = entry.recoveryStatus or "LEGACY_METADATA"
                            break
                        end
                    end

                    if not exists then
                        table.insert(log[area], {
                            species = tostring(mon.species):upper(),
                            pokemonId = Identity.ensurePokemonIdentity(mon, save, mon.nuzlockeOrigin or "LEGACY"),
                            isShiny = Identity.isShiny(mon),
                            encounterType = normalizeType(mon),
                            encounterSource = mon.nuzlockeEncounterSource or "legacy_save",
                            encounterProvider = mon.nuzlockeEncounterProvider,
                            encounterProviderVersion = mon.nuzlockeEncounterProviderVersion,
                            encounterContext = mon.nuzlockeEncounterContext,
                            fingerprint = Identity.fingerprint(mon),
                            provenance = mon.nuzlockeOrigin or "LEGACY",
                            recoveryStatus = "LEGACY_METADATA",
                            retroactive = true,
                        })
                        changed = true
                    end

                    -- A catchLocation surviving from the original save is
                    -- evidence of a historical catch.  Unless this Pokemon
                    -- was already registered by the Nuzlocke tracker, keep
                    -- it classified as LEGACY rather than EDITED.
                    if mon.nuzlockeTrackerRegistered ~= true
                        and not mon.nuzlockeOrigin then
                        Identity.setPokemonOrigin(mon, "LEGACY")
                    end
                    mon.encounterType = mon.encounterType or "wild"
                    mon.nuzlockeTrackerRegistered = true
                    Identity.baselineAdd(mon, mon.nuzlockeOrigin or "LEGACY")
                    markVisited(area)

                    -- Remove one matching entry from __LEGACY__ if an older
                    -- migration placed this same Pokemon there.
                    local legacy = log.__LEGACY__
                    if type(legacy) == "table" then
                        local fp = Identity.fingerprint(mon)
                        local removed = false
                        local kept = {}
                        for _, entry in ipairs(legacy) do
                            local match = false
                            if not removed and type(entry) == "table"
                                and tostring(entry.species or ""):upper()
                                    == tostring(mon.species or ""):upper() then
                                if fp and entry.fingerprint then
                                    match = fp == entry.fingerprint
                                else
                                    match = true
                                end
                            end
                            if match then
                                removed = true
                            else
                                kept[#kept + 1] = entry
                            end
                        end
                        if #kept > 0 then log.__LEGACY__ = kept else log.__LEGACY__ = nil end
                        if removed then changed = true end
                    end
                end
                end
            end
        end

        return changed
    end

    reconcilePokemonCatchLocations()

    -- Reconcile actual party/box Pokémon one final time after all migration
    -- cleanup. Earlier passes can add authoritative entries only later in the
    -- migration (starter/gift/provider recovery), so this final pass ensures
    -- those locations are stamped back onto the actual Pokémon objects too.
    restoreKnownCatchMetadata(save, log)
    Identity.initializePokemonProvenance(save)
    mod.exports.__beta26.annotateGlitchData(currentGameValue(), save)

    -- Re-sync the area map after the migration cleanup so a deleted bad log
    -- entry cannot leave a phantom catch on the tracker MAP.
    local normalizedAreas, areasChanged = normalizeMapTable(areas)
    if areasChanged then
        areas = normalizedAreas
    end

    mod.save:set("tracker_log",   log)
    mod.save:set("caught_areas",  areas)
end

---------------------------------------------------------------------
-- INITIAL SAVE-LOAD RECONSTRUCTION
--
-- Tracker recovery and lazy Pokemon identity assignment are now a named
-- reconstruction phase in the central save-upgrade coordinator. This keeps
-- the old behavior but removes listener-order as an implicit dependency.
---------------------------------------------------------------------
mod.exports.__beta26.registerSaveUpgradeStep("reconstruction",
    "tracker_identity_reconstruction", function(ctx)
        local save = type(ctx) == "table" and ctx.save or nil
        if save then
            setCurrentSave(save)
            rebuildTrackerFromSave(save)
        end
        return true
    end)


  return {
    ALL_ROUTES = ALL_ROUTES,
    ROUTE_IDS = ROUTE_IDS,
    ROUTE_NAMES = ROUTE_NAMES,
    ROUTE_ORDER = ROUTE_ORDER,
    GEN1_SEED_IDS = GEN1_SEED_IDS,
    legacyCandidates = legacyCandidates,
    routeKey = routeKey,
    resolveCatchLocation = resolveCatchLocation,
    registerArea = registerArea,
    isTrackedArea = isTrackedArea,
    routeName = routeName,
    discoverAllKnownAreas = discoverAllKnownAreas,
    caughtAreas = caughtAreas,
    trackerLog = trackerLog,
    rememberEncounterProvider = rememberEncounterProvider,
    syncCaughtAreasFromLog = syncCaughtAreasFromLog,
    visitedAreas = visitedAreas,
    areaKey = areaKey,
    markVisited = markVisited,
    markCaught = markCaught,
    normalizeMapTable = normalizeMapTable,
    normalizeTrackerLog = normalizeTrackerLog,
    rebuildTrackerFromSave = rebuildTrackerFromSave,
  }
end
