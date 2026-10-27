-- Gen 3 Nuzlocke menu: native 240x160 GBA menu stack.
-- Gen 1/2 screens are unchanged; this is an isolated, labelled feature tracker.
-- [WIP] = partially implemented; [Soon] = visible planning placeholder.
return function(mod, api)
    local MENU_ID = "nuzlocke.gen3.menu"
    local VISIBLE = 6
    local pages = {}
    local engineGame

    -- Mirrored from rule_catalog.lua in the established Gen 1/2 mod.
    -- A catalog row is not evidence of Gen 3 runtime support.
    local CATALOG = {
    { title = "CORE", rules = {{ "nuzlocke_enabled", "Nuzlocke" }, { "permadeath", "Permadeath" }, { "first_rival_forgiveness", "First Rival Mercy" }, { "encounter_limit", "One Per Area" }, { "failed_encounter", "Failed Encounters" }, { "nickname_rule", "Nickname" } } },
    { title = "CLAUSES", rules = {{ "dupes_mode", "Dupes Clause" }, { "shiny_clause", "Shiny Clause" }, { "shiny_rate_mode", "Shiny Rate" }, { "shiny_colors", "Shiny Colors" }, { "shiny_intro", "Shiny Intro" }, { "gold_roamer_clause", "Roamer Clause" }, { "gold_egg_encounter_mode", "Egg Encounter" }, { "gold_bug_contest_mode", "Bug Contest" }, { "route_forgiveness", "Route Forgiveness" } } },
    { title = "HARDCORE", rules = {{ "no_escape", "No Escape" }, { "whiteout_clause", "Whiteout" }, { "gym_lock_in", "Gym Lock-In" }, { "dungeon_lock_in", "Dungeon Lock-In" }, { "no_held_items", "No Held Items" } } },
    { title = "GAME DIFFICULTY", rules = {{ "difficulty_profile", "Game Difficulty" } } },
    { title = "BATTLE MECHANICS", rules = {{ "physical_special_split", "Phys/Spec Split" }, { "badge_boosts", "Badge Boosts" } } },
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

    local function present(title, rows)
        pages[#pages + 1] = page(title, rows)
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
            "CATCH: PER MAP",
            "DEATH: IMMEDIATE",
            "B: RETURN",
        })
    end

    local function showTracker()
        local s = state()
        local ids = {}
        for key in pairs(s.areas) do ids[#ids + 1] = tostring(key) end
        table.sort(ids)
        local rows = {}
        rows[#rows + 1] = row("AREA MAP: [WIP]", "wip", nil,
            "Uses native map IDs. Cave floors are not grouped yet.")
        for _, key in ipairs(ids) do
            local entry = s.areas[key]
            local didCatch = type(entry) == "table" and entry.caught
            local id = key
            rows[#rows + 1] = row((didCatch and "C " or "- ") .. key, nil,
                function() info("AREA DETAIL", {
                    "MAP: " .. id,
                    didCatch and "CAUGHT: YES" or "CAUGHT: NO",
                    "ATTEMPT USED",
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
        for i, entry in ipairs(s.graveyard) do
            local member = entry
            local name = tostring(entry.nickname or entry.species or "UNKNOWN")
            rows[#rows + 1] = row(name, nil, function()
                info("IN MEMORY", {
                    "SPECIES: " .. tostring(member.species or "?"),
                    "LEVEL: " .. tostring(member.level or "?"),
                    "MAP: " .. tostring(member.area or "?"),
                    "DEATH RECORDED",
                })
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

    local function coreRows()
        local s = state()
        return {
            row("NUZLOCKE: " .. (s.enabled and "ON" or "OFF"), nil, function()
                local v = state()
                if not v.failed then
                    v.enabled = not v.enabled
                    api.setState(v)
                end
                local p = current()
                -- Retain focus after refreshing the live rule label.
                p.rows = coreRows()
            end),
            row("PERMADEATH: ON", nil, function()
                info("PERMADEATH", { "WORKING IN GEN 3",
                    "DEATH AT FAINT", "REMOVED AFTER BATTLE",
                    "REVIVES BLOCKED" })
            end),
            row("ONE PER AREA: ON", nil, function()
                info("ENCOUNTERS", { "WORKING IN GEN 3",
                    "FIRST WILD BATTLE", "PER NATIVE MAP ID",
                    "REPEAT CATCH BLOCKED" })
            end),
            row("NO REVIVES: ON", nil, function()
                info("NO REVIVES", { "WORKING IN GEN 3",
                    "BLOCKS BATTLE REVIVES",
                    "FIELD USE: [WIP]" })
            end),
            row("FIRST RIVAL MERCY", "soon", function()
                disabledFeature("First Rival Mercy", "first_rival_forgiveness")
            end),
            row("FAILED ENCOUNTERS", "soon", function()
                disabledFeature("Failed Encounters", "failed_encounter")
            end),
            row("NICKNAME RULE", "soon", function()
                disabledFeature("Nickname", "nickname_rule")
            end),
        }
    end

    local function categoryRows(category)
        if category.title == "CORE" then return coreRows() end
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
            local kind = c.title == "CORE" and "wip" or "soon"
            rows[#rows + 1] = row(c.title, kind, function()
                present(c.title, categoryRows(c))
            end)
        end
        present("NUZ RULES", rows)
    end

    local function showDevTools()
        local s = state()
        info("DEV TOOLS", {
            "[WIP] LIVE COUNTERS",
            "AREAS: " .. count(s.areas),
            "DEATHS: " .. #s.graveyard,
            "MODE: " .. (s.enabled and "ON" or "OFF"),
            "SOURCE: GEN3",
        })
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
            row("DEV TOOLS", "wip", showDevTools),
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
            pages[#pages] = nil
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
