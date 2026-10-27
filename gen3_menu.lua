-- Gen 3 Nuzlocke menu: native 240x160 GBA menu stack.
-- Gen 1/2 screens are unchanged; this is an isolated, labelled feature tracker.
-- [WIP] = partially implemented; [Soon] = visible planning placeholder.
return function(mod, api)
    local MENU_ID = "nuzlocke.gen3.menu"
    local VISIBLE = 6
    local pages = {}
    local engineGame
    local Core = assert(api.core, "Gen 3 menu needs CORE rule contract")
    local Clauses = assert(api.clauses, "Gen 3 menu needs CLAUSES policy")
    local ShinyRate = assert(api.shinyRate, "Gen 3 menu needs shiny rate service")
    local Forgiveness = assert(api.forgiveness, "Gen 3 menu needs token policy")
    local Dev = assert(api.dev, "Gen 3 menu needs developer tools")
    local Levels = assert(api.levels, "Gen 3 menu needs LEVELS contract")
    local Display = assert(api.display, "Gen 3 menu needs species and location labels")

    -- Mirrored from rule_catalog.lua in the established Gen 1/2 mod.
    -- A catalog row is not evidence of Gen 3 runtime support.
    local CATALOG = {
    { title = "CORE", rules = {{ "nuzlocke_enabled", "Nuzlocke" }, { "permadeath", "Permadeath" }, { "first_rival_forgiveness", "First Rival Mercy" }, { "encounter_limit", "One Per Area" }, { "failed_encounter", "Failed Encounters" }, { "nickname_rule", "Nickname" } } },
    { title = "CLAUSES", rules = {{ "dupes_mode", "Dupes Clause" }, { "shiny_clause", "Shiny Clause" }, { "shiny_rate_mode", "Shiny Rate" }, { "gen3_roamer_clause", "Roamer Clause" }, { "gen3_egg_encounter_mode", "Egg Encounter" }, { "route_forgiveness", "Route Forgiveness" } } },
    { title = "HARDCORE", rules = {{ "no_escape", "No Escape" }, { "whiteout_clause", "Whiteout" }, { "gym_lock_in", "Gym Lock-In" }, { "dungeon_lock_in", "Dungeon Lock-In" }, { "no_held_items", "No Held Items" } } },
    { title = "GAME DIFFICULTY", rules = {{ "difficulty_profile", "Game Difficulty" } } },
    { title = "RUN / PARTY", rules = {{ "gym_team_size", "Gym Team Size" }, { "party_size_limit", "Party Size Limit" }, { "evolution_limit", "Evolution Limits" } } },
    { title = "LEVELS", rules = {{ "level_cap_scope", "Level Cap Scope" }, { "exp_edging", "EXP Edging" } } },
    { title = "CATCH RULES", rules = {{ "overworld_encounters", "Overworld" }, { "town_catches", "Town Catches" }, { "ban_legendaries", "No Legendaries" }, { "ban_mythicals", "No Mythicals" }, { "ban_pseudos", "No Pseudos" }, { "no_static_encounters", "No Static Enc" }, { "no_fishing", "No Fishing" }, { "allow_gifts", "Gift Pokemon" }, { "gift_slot_policy", "Gift Slot Policy" }, { "allow_trades", "In-Game Trades" }, { "trade_slot_policy", "Trade Slot Policy" }, { "maximum_bst", "Maximum BST" }, { "pkmn_ban", "PKMN BAN" }, { "colorlocke_mode", "Colorlocke" }, { "colorlocke_color", "Color" }, { "alphabetlocke_mode", "Alphabetlocke" }, { "alphabetlocke_letter", "Letter" }, { "allow_glitch_pokemon", "Allow Glitches" } } },
    { title = "BATTLE CLAUSES", rules = {{ "ohko_clause", "OHKO Clause" }, { "flinch_clause_scope", "Flinch Clause" }, { "trap_clause_scope", "Trap Clause" }, { "setup_move_scope", "No Setup Moves" }, { "evasion_clause", "Evasion Clause" }, { "status_accuracy_scope", "Accuracy Drops" }, { "other_stat_drop_scope", "Other Stat Drops" } } },
    { title = "STATUS BANS", rules = {{ "status_move_scope", "No Status Moves" }, { "status_paralysis_scope", "Paralysis" }, { "status_confusion_scope", "Confusion" }, { "status_sleep_scope", "Sleep Ban" }, { "status_poison_scope", "Poison/Toxic" }, { "status_burn_scope", "Burn Ban" }, { "status_freeze_scope", "Freeze" }, { "sleep_clause", "Sleep Clause" } } },
    { title = "VARIANTS", rules = {{ "type_lock_mode", "Type Locke" }, { "type_lock_draft", "Catch Draft" }, { "type_lock_primary", "Type 1" }, { "type_lock_secondary", "Type 2" }, { "type_lock_tertiary", "Type 3" }, { "type_lock_quaternary", "Type 4" }, { "type_lock_quinary", "Type 5" }, { "type_lock_senary", "Type 6" }, { "wonderlocke", "Wonderlocke WIP" } } },
    { title = "BATTLE ITEMS", rules = {{ "no_healing_items", "No Healing Items" }, { "no_battle_items", "No X Items" }, { "no_catching", "No Catching" }, { "encounter_ball_limit", "Ball Per Enc." } } },
    { title = "FIELD ITEMS", rules = {{ "no_repels", "No Repels" }, { "no_escape_rope", "No Escape Rope" }, { "travel_restrictions", "Travel Restrictions" }, { "no_field_healing", "No Field Heal" }, { "no_pp_items", "No PP Items" }, { "no_tm_use", "No TMs" }, { "no_rare_candy_use", "No Rare Candy" } } },
    { title = "SERVICES & ECONOMY", rules = {{ "no_poke_center", "No Center Heal" }, { "no_mom_heal", "No Mom Heal" }, { "no_day_care", "No Day Care" }, { "shop_restrictions", "Shop Restrictions" }, { "no_gambling", "No Gambling" }, { "trainer_money_multiplier", "Trainer Money" } } },
    { title = "POKEMON STATS", rules = {{ "player_start_stat_exp", "Player Stat EXP" }, { "wild_start_stat_exp", "Wild Stat EXP" }, { "trainer_start_stat_exp", "Trainer Stat EXP" }, { "no_player_stat_exp_gain", "No Stat EXP Gain" }, { "perfect_player_ivs", "Perfect Player IVs" }, { "perfect_wild_ivs", "Perfect Wild IVs" }, { "perfect_trainer_ivs", "Perfect Trainer IVs" } } },
    { title = "AREA SPLITS", rules = {{ "route_2_split", "Route 2" }, { "route_10_split", "Route 10" }, { "route_20_split", "Route 20" }, { "mt_moon_splits", "Mt. Moon" }, { "safari_zone_splits", "Safari Clause" }, { "gold_time_split", "Time Split" }, { "gold_headbutt_split", "Headbutt Split" } } },
    { title = "RANDOMIZER", rules = {{ "randomizer_preset", "Rndm Preset" }, { "randomizer_seed", "Rndm Seed" }, { "random_starter", "Rndm Strtr" }, { "random_starter_style", "Strtr Style" }, { "random_starter_balance", "Strtr Balance" }, { "random_starter_trio_typing", "Trio Typing" }, { "random_starter_rerolls", "Starter Rerolls" }, { "random_encounter_tables", "Random Encounters" }, { "random_field_items", "Random Field Items" }, { "random_field_item_balance", "Field Item Balance" }, { "random_field_item_repetition", "Field Item Repeats" }, { "random_encounter_balance", "Encounter Balance" }, { "random_encounter_repetition", "Encounter Repeats" }, { "random_encounter_diversity_strength", "Diversity Strength" }, { "randomizer_info_policy", "Randomizer Info" }, { "random_species_generation", "Species Pool" }, { "random_learnsets", "Random Learnsets" }, { "random_trainers", "Random Trainers" }, { "random_evolutions", "Random Evolutions" }, { "random_evolution_balance", "Evolution Balance" }, { "random_shops", "Random Shops" }, { "random_shop_balance", "Shop Balance" }, { "random_tms", "Random TMs" }, { "random_tm_compatibility", "TM Compatibility" }, { "random_tm_locations", "Random TM Locations" }, { "random_gift_items", "Random Gift Items" }, { "random_trainer_balance", "Trainer Balance" }, { "random_trainer_diversity", "Trainer Diversity" }, { "random_trainer_theme", "Trainer Theme" }, { "random_learnset_generation", "Learnset Gen" }, { "random_learnset_stab", "Learnset STAB" } } },
    { title = "WORLD", rules = {{ "world_building_tier", "World Building" }, { "gold_radio_world_building", "Radio Nuzlocke" } } },
    { title = "QOL", rules = {{ "progression_pc_catches", "PC-Only Catches" }, { "instant_text", "Instant Text" }, { "skip_cherrygrove_tour", "Skip Cherrygrove Tour" }, { "run_surf", "Run / Surf" }, { "unlimited_bag_space", "Unlimited Bag Space" }, { "trade_evolutions", "Trade Evolutions" }, { "system_clock_sync", "System Clock Sync" }, { "infinite_rare_candies", "Gym Guide Rare Candy" } } },
    { title = "QOL SETUP ONLY", rules = {{ "system_date_time", "System Date/Time" }, { "automatic_default_names", "Default Names" }, { "skip_opening_intro", "Skip Opening Intro" }, { "quick_nuzlocke_start", "Quick Nuzlocke Start" }, { "skip_catch_tutorial", "Skip Catch Demo" }, { "starting_pokeballs", "Starting Poke Balls" }, { "starting_rare_candies", "Starting Rare Candy" }, { "starting_money", "Starting Money" }, { "gold_starting_pokeballs", "Starting Poke Balls" }, { "gold_starting_rare_candies", "Starting Rare Candy" }, { "gold_starting_money", "Starting Money" }, { "pc_starting_heal_items", "Heal Loadout" }, { "pc_starting_vitamins", "PC Vitamins" } } },
    { title = "UI", rules = {{ "catch_info", "Catch Page" }, { "stat_info", "Stat Page" }, { "move_info", "Move Page" }, { "area_guide_enabled", "Area Guide" }, { "battle_menu_ui", "Battle Menu UI" }, { "dev_mode", "Dev Mode" } } },
    }

    local function state()
        return api.getState()
    end

    local function prefix(kind)
        if kind == "soon" then return "[Soon] " end
        if kind == "wip" then return "[WIP] " end
        return ""
    end

    local function row(label, kind, action, detail)
        return {
            label = prefix(kind) .. tostring(label or ""),
            kind = kind or "working",
            action = action,
            detail = detail,
        }
    end

    local function page(title, rows)
        return { title = tostring(title), rows = rows or {}, index = 1, scroll = 0 }
    end

    local function present(title, rows, refresh)
        local p = page(title, rows)
        p.refresh = refresh
        pages[#pages + 1] = p
    end

    local function popPage()
        if #pages <= 1 then return end
        pages[#pages] = nil
        local p = pages[#pages]
        if p and p.refresh then
            p.rows = p.refresh()
            p.index = math.max(1, math.min(p.index, #p.rows))
            p.scroll = math.min(p.scroll, math.max(0, #p.rows - VISIBLE))
        end
    end

    local function info(title, lines)
        local rows = {}
        for _, label in ipairs(lines or {}) do
            rows[#rows + 1] = row(label, nil)
        end
        present(title, rows)
    end

    local function count(t)
        local n = 0
        for _ in pairs(t or {}) do n = n + 1 end
        return n
    end

    local function current()
        return pages[#pages]
    end

    local function showStatus()
        local s = state()
        info("NUZ STATUS", {
            s.failed and "RUN: LOST" or "RUN: ACTIVE",
            "MODE: " .. (s.enabled and "ON" or "OFF"),
            "AREAS: " .. count(s.areas),
            "DEATHS: " .. #s.graveyard,
            "CATCH: " .. (Core.get(s, "encounter_limit")
                and "PER MAP" or "UNLIMITED"),
            "DEATH: " .. (Core.get(s, "permadeath")
                and "IMMEDIATE" or "OFF"),
            "DUPES: " .. Clauses.label(s, "dupes_mode"),
            "SHINY: " .. Clauses.label(s, "shiny_clause"),
            "SHINY USED: " .. tostring(s.shinyExceptionsUsed or 0),
            "B: RETURN",
        })
    end

    local function showTracker()
        local s = state()
        local ids = {}
        for key in pairs(s.areas) do ids[#ids + 1] = tostring(key) end
        table.sort(ids)
        local rows = {}
        rows[#rows + 1] = row("AREA MAP", "wip", nil,
            "Uses native map IDs. Cave floors are not grouped yet.")
        for _, key in ipairs(ids) do
            local entry = s.areas[key]
            local didCatch = type(entry) == "table" and entry.caught
            local spent = Core.areaSpent(entry)
            local id = key
            local place = Display.areaName(id)
            rows[#rows + 1] = row((didCatch and "C " or
                (spent and "- " or "* ")) .. place, nil,
                function() info("AREA DETAIL", {
                    "LOCATION: " .. place,
                    didCatch and "CAUGHT: YES" or "CAUGHT: NO",
                    spent and "ENCOUNTER USED" or "CATCH STILL OPEN",
                    "ATTEMPTS: " .. tostring(entry.attempts or 1),
                }) end)
        end
        if #ids == 0 then
            rows[#rows + 1] = row("NO AREAS CLAIMED")
        end
        present("ENC TRACKER", rows)
    end

    local function showGraveyard()
        local s = state()
        local rows = {}
        for _, entry in ipairs(s.graveyard) do
            local member = entry
            local species = Display.speciesName(member)
            local name = Display.pokemonName(member)
            local location = Display.areaName(member.area)
            if location == "Unknown location"
                and type(member.areaName) == "string"
                and member.areaName ~= "" then
                location = member.areaName
            end
            local level = tonumber(member.level)
            local summary = name
            if level then summary = summary .. " Lv" .. tostring(level) end
            rows[#rows + 1] = row(summary, nil, function()
                local details = {
                    "POKEMON: " .. name,
                }
                if name ~= species then
                    -- Don't repeat species/name unless there is a nickname.
                    details[#details + 1] = "SPECIES: " .. species
                end
                details[#details + 1] =
                    "LEVEL: " .. (level and tostring(level) or "Unknown")
                details[#details + 1] = "LOST AT: " .. location
                details[#details + 1] =
                    "CAUSE: " .. tostring(member.cause or "Fainted")
                info("IN MEMORY", details)
            end)
        end
        if #rows == 0 then rows[1] = row("NO FALLEN POKEMON") end
        present("GRAVEYARD", rows)
    end

    local function disabledFeature(title, key)
        info("COMING SOON", {
            "[Soon] " .. title,
            "NOT ACTIVE IN GEN 3",
            "NO SETTINGS CHANGED",
            key and ("ID: " .. key) or "PLANNED FEATURE",
        })
    end

    -- Display and edit from one source of truth, never a duplicated list.
    -- A [Soon] row is intentionally read-only even if a default is stored.
    local function coreRows()
        local s = state()
        local rows = {}
        local labels = {
            nuzlocke_enabled = "NUZLOCKE",
            permadeath = "PERMADEATH",
            encounter_limit = "ONE PER AREA",
            failed_encounter = "FAILED ENC.",
            nickname_rule = "NICKNAME",
            first_rival_forgiveness = "RIVAL MERCY",
            whiteout_ends_run = "WHITEOUT FAILS",
            pc_survivors_allowed = "PC SURVIVORS",
        }
        for _, desc in ipairs(Core.descriptors()) do
            local key = desc.key
            local label = labels[key] or desc.label
            local status = desc.status
            if status == "soon" then
                rows[#rows + 1] = row(label, "soon", function()
                    disabledFeature(label, key)
                end)
            else
                local function updateLabel()
                    return label .. ": " ..
                        (Core.get(state(), key) and "ON" or "OFF")
                end
                rows[#rows + 1] = row(updateLabel(), status == "wip" and "wip" or nil,
                    function()
                        local fresh = state()
                        local ok, reason = Core.set(fresh, key,
                            not Core.get(fresh, key))
                        if ok then
                            api.setState(fresh)
                            -- Update the displayed label at the same cursor
                            -- without pushing a second screen.
                            current().rows = coreRows()
                        elseif reason == "run_failed" then
                            -- Stay on the same page; the visible value cannot
                            -- be changed on a failed run.
                            return
                        else
                            disabledFeature(label, key)
                        end
                    end)
            end
        end
        return rows
    end

    local function eggHistory()
        local rows, history = {}, state().eggHistory or {}
        for i = #history, math.max(1, #history - 19), -1 do
            local item = history[i]
            local species = Display.speciesName({ species = item.species })
            rows[#rows + 1] = row(species .. " " .. tostring(item.status), nil,
                function() info("EGG DETAIL", {
                    "POKEMON: " .. species,
                    "HATCH: " .. Display.areaName(item.location),
                    "STATUS: " .. tostring(item.status),
                }) end)
        end
        if #rows == 0 then rows[1] = row("NO EGGS TRACKED") end
        present("EGG HISTORY", rows)
    end

    local function forgivenessRows()
        local saved = state()
        local rows = { row("TOKENS: " .. Forgiveness.balance(saved)) }
        if Clauses.get(saved, "route_forgiveness") == 0 then
            rows[#rows + 1] = row("CLAUSE OFF")
            return rows
        end
        local ids = {}
        for id in pairs(saved.areas or {}) do
            if Forgiveness.canReopen(saved, id) then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local target = id
            rows[#rows + 1] = row(Display.areaName(id), nil, function()
                present("CONFIRM TOKEN", {
                    row("YES: REOPEN", nil, function()
                        local latest = state()
                        if Forgiveness.reopen(latest, target) then
                            api.setState(latest)
                        end
                        popPage()
                    end),
                    row("CANCEL", nil, popPage),
                    row("COST: 1 TOKEN"),
                })
            end)
        end
        if #ids == 0 then rows[#rows + 1] = row("NO FAILED ROUTES") end
        rows[#rows + 1] = row("REVIVE POKEMON", "soon",
            function() info("RECOVERY PENDING", {
                "ARCHIVE SUPPORTED", "PC RECOVERY NOT READY",
                "NO TOKEN SPENT",
            }) end)
        return rows
    end

    local function openForgiveness()
        present("FORGIVENESS", forgivenessRows(), forgivenessRows)
    end

    local function clausesRows()
        local rows = {}
        for _, descriptor in ipairs(Clauses.descriptors()) do
            local d = descriptor
            if d.status == "soon" then
                rows[#rows + 1] = row(d.label, "soon", function()
                    disabledFeature(d.label, d.key)
                end)
            else
                local external = d.key == "shiny_rate_mode"
                    and ShinyRate.externalProvider(mod) or nil
                rows[#rows + 1] = row(d.label .. ": " ..
                    (external and "EXTERNAL" or Clauses.label(state(), d.key)),
                    "wip", function()
                    if external then
                        info("SHINY PROVIDER", {
                            "EXTERNAL SHINY MOD",
                            "CONTROLS SHINY ODDS",
                            "NUZ WILL NOT OVERRIDE",
                        })
                        return
                    end
                    local currentState = state()
                    local value = Clauses.get(currentState, d.key)
                    local nextValue = (value + 1) % #d.options
                    local ok, reason = Clauses.set(currentState, d.key, nextValue)
                    if ok then
                        if api.onClauseChanged then api.onClauseChanged(currentState, d.key) end
                        api.setState(currentState)
                        current().rows = clausesRows()
                    elseif reason == "run_failed" then
                        return
                    else
                        info("RULE UNAVAILABLE", { tostring(reason) })
                    end
                end)
            end
        end
        rows[#rows + 1] = row("EGG HISTORY", "wip", eggHistory)
        rows[#rows + 1] = row("REDEEM TOKEN", "wip", openForgiveness)
        return rows
    end

    local function levelRows()
        local scope = Levels.get("level_cap_scope") or 0
        local edging = Levels.get("exp_edging") == true
        local cap, stage = Levels.cap()
        local banked, pending = 0, 0
        for _, mon in ipairs(Levels.currentParty()) do
            local amount = Levels.banked(mon)
            banked = banked + amount
            if amount > 0 then pending = pending + 1 end
        end
        return {
            row("CAP SCOPE: " .. ({
                "NONE", "GYMS", "ELITE FOUR", "CHAMPION", "POSTGAME"
            })[scope + 1], nil, function()
                if Levels.set("level_cap_scope", (scope + 1) % 5) then
                    current().rows = levelRows()
                end
            end),
            row("EXP EDGING: " .. (edging and "ON" or "OFF"), nil,
                function()
                    if Levels.set("exp_edging", not edging) then
                        current().rows = levelRows()
                    end
                end),
            row("CURRENT CAP: " .. (cap and ("LV " .. cap) or "NONE")),
            row("STAGE: " .. (stage or "UNKNOWN")),
            row("PARTY BANK: " .. tostring(banked) .. " EXP"),
            row("BANKED MEMBERS: " .. tostring(pending)),
        }
    end

    local function categoryRows(category)
        if category.title == "CORE" then return coreRows() end
        if category.title == "CLAUSES" then return clausesRows() end
        if category.title == "LEVELS" then return levelRows() end
        local rows = {}
        for _, rule in ipairs(category.rules) do
            local key, label = rule[1], rule[2]
            -- Not yet ported: do not allow touching the Gen 1/2 rule store.
            rows[#rows + 1] = row(label, "soon", function()
                disabledFeature(label, key)
            end)
        end
        return rows
    end

    local function showRules()
        local rows = {}
        for _, cat in ipairs(CATALOG) do
            local c = cat
            -- CORE and CLAUSES are active categories; their individual
            -- policy rows still distinguish unsupported mechanics.
            local active = c.title == "CORE" or c.title == "CLAUSES"
                or c.title == "LEVELS"
            rows[#rows + 1] = row(c.title, active and "working" or "soon", function()
                present(c.title, categoryRows(c),
                    active and function() return categoryRows(c) end or nil)
            end)
        end
        present("NUZ RULES", rows)
    end

    -- Nuz Dev is intentionally independent from gameplay rules. It edits
    -- *Nuzlocke records only*, not party/PC Pokémon, and leaves an audit trail.
    local function confirmDev(label, description, apply)
        present("CONFIRM EDIT", {
            row("YES: " .. label, nil, function()
                local ok, reason = apply()
                popPage()
                if not ok then
                    info("EDIT BLOCKED", {
                        tostring(reason or "UNKNOWN ERROR"),
                        "NO DATA CHANGED",
                    })
                end
            end),
            row("CANCEL", nil, popPage),
            row(description or "TEST SAVE ONLY"),
            row("SAVE FLAGGED AS DEV"),
        })
    end

    local function showDevInspector()
        local d = Dev.inspect()
        info("NUZ DEV STATUS", {
            "AREA: " .. tostring(d.map or "UNKNOWN"),
            "PARTY: " .. tostring(d.party),
            "USED: " .. tostring(d.areasSpent),
            "OPEN: " .. tostring(d.areasOpen),
            "CAUGHT: " .. tostring(d.areasCaught),
            "DEATHS: " .. tostring(d.deaths),
            "RUN: " .. (d.failed and "LOST" or "ACTIVE"),
            "MOD: " .. (d.enabled and "ON" or "OFF"),
            "EDITS: " .. tostring(d.edits),
            d.tainted and "DEV RUN: YES" or "DEV RUN: NO",
        })
    end

    local function showDevRules()
        local items = {}
        local currentState = state()
        for _, descriptor in ipairs(Core.descriptors()) do
            local desc = descriptor
            items[#items + 1] = row(desc.label, desc.status == "soon" and "soon" or nil,
                function()
                    info("RULE DETAIL", {
                        desc.key,
                        "VALUE: " .. (Core.get(currentState, desc.key) and "ON" or "OFF"),
                        "STATE: " .. desc.status:upper(),
                    })
                end)
        end
        present("RULE INSPECT", items)
    end

    local function areaRows(key)
        local entry = state().areas[key]
        local status = entry == nil and "UNRECORDED"
            or (entry.caught and "CAUGHT")
            or (Core.areaSpent(entry) and "SPENT" or "OPEN")
        return {
            row("MAP: " .. key),
            row("STATE: " .. status),
            row("MARK OPEN", nil, function()
                confirmDev("OPEN", "RE-ARM CATCH", function()
                    return Dev.setArea(key, "open")
                end)
            end),
            row("MARK SPENT", nil, function()
                confirmDev("SPENT", "BLOCK CATCH", function()
                    return Dev.setArea(key, "spent")
                end)
            end),
            row("MARK CAUGHT", nil, function()
                confirmDev("CAUGHT", "FAKE CLAIM", function()
                    return Dev.setArea(key, "caught")
                end)
            end),
            row("CLEAR ENTRY", nil, function()
                confirmDev("CLEAR", "REMOVE RECORD", function()
                    return Dev.setArea(key, "clear")
                end)
            end),
        }
    end

    local function openAreaEditor(key)
        if not key then
            return info("NO CURRENT MAP", {
                "ENTER AN OVERWORLD MAP",
                "AND REOPEN NUZ DEV",
            })
        end
        present("EDIT AREA", areaRows(key), function() return areaRows(key) end)
    end

    local function listAreaRows()
        local out = {}
        for _, entry in ipairs(Dev.areas()) do
            local key = entry.key
            local marker = entry.caught and "C" or (entry.spent and "X" or "O")
            out[#out + 1] = row(marker .. " " .. key, nil, function()
                openAreaEditor(key)
            end)
        end
        if #out == 0 then out[1] = row("NO RECORDED AREAS") end
        return out
    end

    local function showDevAreas()
        present("EDIT ALL AREAS", listAreaRows(), listAreaRows)
    end

    local function devRows()
        local d = Dev.status()
        if not d.enabled then
            return {
                row("ENABLE DEV MODE", nil, function()
                    confirmDev("ENABLE", "TEST MODE ONLY", Dev.enable)
                end),
                row("MODIFIES NUZ RECORDS"),
                row("NOT THE POKEMON PARTY"),
                row(d.tainted and "SAVE ALREADY FLAGGED" or "SAVE WILL BE FLAGGED"),
            }
        end
        return {
            row("RE-ARM CURRENT", nil, function()
                local key = Dev.currentArea()
                if not key then
                    info("NO CURRENT MAP", { "ENTER AN OVERWORLD MAP" })
                    return
                end
                confirmDev("RE-ARM", "SLOT OPEN AGAIN", function()
                    return Dev.setArea(key, "open")
                end)
            end),
            row("EDIT CURRENT AREA", nil, function()
                openAreaEditor(Dev.currentArea())
            end),
            row("EDIT ALL AREAS", nil, showDevAreas),
            row("CLEAR ALL AREAS", nil, function()
                confirmDev("CLEAR ALL", "ALL CATCH RECORDS", Dev.clearAllAreas)
            end),
            row("STATE INSPECTOR", nil, showDevInspector),
            row("RULE INSPECTOR", nil, showDevRules),
            row("RESET CLAUSE COUNTS", nil, function()
                confirmDev("RESET CLAUSES", "KEEP REAL POKEMON",
                    Dev.clearClauseHistory)
            end),
            row("PRINT DEBUG REPORT", nil, function()
                local ok, err = Dev.printReport()
                if ok then
                    info("REPORT PRINTED", {
                        "SEE GAME CONSOLE",
                        "SEARCH FOR [NUZ DEV]",
                    })
                else
                    info("REPORT BLOCKED", { tostring(err) })
                end
            end),
            row("CLEAR GRAVEYARD", nil, function()
                confirmDev("CLEAR DEAD", "NO POKEMON RESTORED", Dev.clearGraveyard)
            end),
            row("CLEAR RUN FAILURE", nil, function()
                confirmDev("CLEAR LOSS", "NEEDS LIVING PARTY", Dev.clearFailed)
            end),
            row("DISABLE DEV MODE", nil, function()
                confirmDev("DISABLE", "SAVE STAYS FLAGGED", Dev.disable)
            end),
            row("ADD TEST TOKEN", nil, function()
                confirmDev("GRANT TOKEN", "DEV RUN ONLY", Dev.grantTestToken)
            end),
        }
    end

    local function showDevTools()
        present("NUZ DEV", devRows(), devRows)
    end

    local function showNicknameTasks()
        local naming = api.nickname
        if not naming then return end
        local function tasksRows()
            local rows = {}
            if not Core.enforced(state(), "nickname_rule") then
                rows[1] = row("NICKNAME RULE IS OFF")
                return rows
            end
            local tasks = naming.pending()
            for _, item in ipairs(tasks) do
                local mon = item.mon
                local label = (item.where == "party"
                    and ("PARTY " .. tostring(item.slot))
                    or ("BOX " .. tostring(item.box) .. "/" .. tostring(item.slot)))
                    .. ": " .. item.name
                rows[#rows + 1] = row(label, nil, function()
                    local Naming = require("src.ui.game3.naming")
                    Naming.open({
                        template = "CAUGHT_MON", maxLen = 10,
                        species = mon.species or mon.speciesId,
                        personality = mon.personality,
                        gender = mon.gender,
                        seed = item.name,
                        sentToPc = item.where == "box",
                        title = Naming.monTitle(item.name),
                        onDone = function(value)
                            if naming.rename(mon, value) and current() then
                                current().rows = tasksRows()
                            end
                        end,
                    })
                end)
            end
            if #rows == 0 then rows[1] = row("ALL POKEMON NAMED") end
            return rows
        end
        present("NICKNAME TASKS", tasksRows(), tasksRows)
    end

    local function home()
        present("NUZ MENU", {
            row("NUZ RULES", "wip", showRules),
            row("ENC TRACKER", "wip", showTracker),
            row("NUZ STATUS", nil, showStatus),
            row("GRAVEYARD", "wip", showGraveyard),
            row("ALMANAC", "soon", function()
                disabledFeature("ALMANAC", "almanac")
            end),
            row("MOD COMPAT", "soon", function()
                disabledFeature("MOD COMPAT", "compat")
            end),
            row("NUZ DEV", "wip", showDevTools),
            row("NICKNAME TASKS", "wip", showNicknameTasks),
            row("END RUN", "soon", function()
                disabledFeature("END RUN", "end_run")
            end),
        })
    end

    local M = { isMenu = true }

    function M.open(game)
        if not (game and game.session) then return false end
        engineGame = game
        pages = {}
        home()
        local Stack = require("src.ui.game3.stack")
        Stack.push(MENU_ID, M, { isMenu = true, hideBelow = true, fullscreen = true })
        return true
    end

    local function move(delta)
        local p = current()
        if not p or #p.rows == 0 then return end
        p.index = ((p.index - 1 + delta) % #p.rows) + 1
        if p.index <= p.scroll then p.scroll = p.index - 1 end
        if p.index > p.scroll + VISIBLE then p.scroll = p.index - VISIBLE end
    end

    local function back()
        if #pages > 1 then
            popPage()
        else
            pages = {}
            engineGame = nil
            require("src.ui.game3.stack").pop(MENU_ID)
        end
    end

    function M.handleInput(input)
        if not input or not current() then return end
        if input:wasPressed("up") then move(-1)
        elseif input:wasPressed("down") then move(1)
        elseif input:wasPressed("a") then
            local p = current()
            local picked = p and p.rows[p.index]
            if picked and picked.action then picked.action() end
        elseif input:wasPressed("b") or input:wasPressed("start") then
            back()
        end
    end

    function M.update() end

    function M.draw()
        local p = current()
        if not p then return end
        local Window = require("src.ui.game3.window")
        local Chrome = require("src.ui.game3.chrome")
        local Font = require("src.ui.game3.frlg_font")
        -- Preserve the 240x160 GBA native display; don't use the 160x144
        -- Game Boy canvas/chrome from Gen 1/2.
        Window.fill(Window.template(0, 0, 30, 20), 1, 1, 1, 1)
        Chrome.fixedStdFrame(1, 1, 28, 18)
        Window.printPx(p.title, 24, 13, { maxWidth = 190 })
        Window.printPx(tostring(p.index) .. "/" .. tostring(#p.rows),
            186, 13, { maxWidth = 35, small = true })
        for slot = 1, VISIBLE do
            local index = p.scroll + slot
            local item = p.rows[index]
            if item then
                local y = 31 + (slot - 1) * 17
                if index == p.index then Window.cursorPx(18, y) end
                Window.printPx(item.label, 32, y,
                    { maxWidth = 181, small = true })
            end
        end
        if p.scroll > 0 then
            Window.printPx("UP", 200, 23, { small = true })
        end
        if p.scroll + VISIBLE < #p.rows then
            Window.printPx("MORE", 187, 125, { small = true })
        end
        Window.printPx("A: OPEN   B: BACK", 28, 138,
            { maxWidth = 185, small = true })
    end

    -- Small, side-effect-free state inspection for automated testing.
    function M.model()
        local p = current()
        if not p then return nil end
        local labels = {}
        for i, value in ipairs(p.rows) do labels[i] = value.label end
        return { title = p.title, rows = labels, index = p.index,
            scroll = p.scroll, depth = #pages }
    end

    function M.catalog()
        return CATALOG
    end

    return M
end
