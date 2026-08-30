-- Module owner: RuleCatalog
-- Nuzlocke rule/settings catalog (extracted in 2.5.81)
-- Behavior-preserving extraction from main.lua.
return function(mod, deps)
  deps = deps or {}
  local Strings = assert(deps.Strings, "rule_catalog requires Strings")
  ---------------------------------------------------------------------
  -- RULE DEFINITIONS
  ---------------------------------------------------------------------
  local LEGENDARIES = {
      ARTICUNO = true,
      ZAPDOS   = true,
      MOLTRES  = true,
      MEWTWO   = true,
      -- Native Gen 2 canonical fallbacks. Merged species metadata remains
      -- authoritative when a provider supplies an explicit category flag.
      RAIKOU   = true,
      ENTEI    = true,
      SUICUNE  = true,
      LUGIA    = true,
      HO_OH    = true,
  }

  local MYTHICALS = {
      MEW = true,
      CELEBI = true,
  }

  -- Metadata remains authoritative for modded species. These canonical
  -- pseudo-legendary final evolutions are a conservative fallback for content
  -- mods that inject later-generation species without pseudo metadata. Keep
  -- this species-based rather than BST-based so Maximum BST remains independent.
  local PSEUDOS = {
      DRAGONITE = true,
      TYRANITAR = true,
      SALAMENCE = true,
      METAGROSS = true,
  }

  -- Stored as compact preset indices so active saves remain stable if the UI
  -- wording changes. 0 is literal vanilla creation (zero Stat EXP). 100% is
  -- defined as half the engine storage range so the requested 200% preset can
  -- reach, but never exceed, the native 65535-per-stat ceiling.
  mod.exports.__beta26.statExpPresetLabels = {
      [0] = Strings.source("0%"), [1] = Strings.source("25%"),
      [2] = Strings.source("50%"), [3] = Strings.source("75%"),
      [4] = Strings.source("100%"), [5] = Strings.source("200%"),
  }
  mod.exports.__beta26.statExpPresetValues = {
      [0] = 0, [1] = 8192, [2] = 16384, [3] = 24576,
      [4] = 32768, [5] = 65535,
  }

  -- Shared presentation labels keep percentage-based controls consistent
  -- across Setup, Nuz Rules, and status surfaces.
  mod.exports.__beta26.trainerMoneyPresetLabels = {
      [0] = Strings.source("0%"), [1] = Strings.source("25%"),
      [2] = Strings.source("50%"), [3] = Strings.source("75%"),
      [4] = Strings.source("100%"), [5] = Strings.source("150%"),
      [6] = Strings.source("200%"), [7] = Strings.source("300%"),
      [8] = Strings.source("500%"),
  }

  -- Maximum BST is a preset ladder rather than a free-form number.
  -- The actual thresholds remain stored as BST values so getMaximumBST() and
  -- compatibility consumers keep the same semantic contract.
  mod.exports.__beta26.maximumBstPresetValues = {
      [0] = 0,
      [1] = 300, [2] = 350, [3] = 400, [4] = 450, [5] = 500,
      [6] = 550, [7] = 600, [8] = 650, [9] = 700,
  }
  mod.exports.__beta26.maximumBstPresetLabels = {
      [0] = Strings.source("OFF"),
      [1] = Strings.source("300"), [2] = Strings.source("350"),
      [3] = Strings.source("400"), [4] = Strings.source("450"),
      [5] = Strings.source("500"), [6] = Strings.source("550"),
      [7] = Strings.source("600"), [8] = Strings.source("650"),
      [9] = Strings.source("700"),
  }
  mod.exports.__beta26.maximumBstPresetMaxIndex = 9
  mod.exports.__beta26.maximumBstPresetIndex = function(value)
      value = math.max(0, math.floor(tonumber(value) or 0))
      local values = mod.exports.__beta26.maximumBstPresetValues
      local maxIndex = mod.exports.__beta26.maximumBstPresetMaxIndex
      for index = 0, maxIndex do
          if values[index] == value then return index, true end
      end
      if value <= 0 then return 0, false end
      local bestIndex, bestDistance = 1, math.huge
      for index = 1, maxIndex do
          local distance = math.abs(value - values[index])
          if distance < bestDistance then
              bestIndex, bestDistance = index, distance
          end
      end
      return bestIndex, false
  end
  mod.exports.__beta26.maximumBstDisplayLabel = function(value)
      local index, exact = mod.exports.__beta26.maximumBstPresetIndex(value)
      if exact then
          return mod.exports.__beta26.maximumBstPresetLabels[index]
      end
      -- Older development saves may contain a free-form threshold. Preserve
      -- that exact enforcement value until the player changes the control,
      -- while making its legacy/custom status explicit in the UI.
      return Strings.source("CUSTOM")
  end

  local ruleCategories = {
      {
          title = Strings.source("CORE"),
          rules = {
              { key = "nuzlocke_enabled", default = true, name = Strings.source("Nuzlocke"), desc = Strings.source("Master switch for challenge enforcement and challenge rewards. OFF disables Nuzlocke rules such as encounters, Permadeath, Type Locke, lock-ins, Route Forgiveness rewards, and Trainer Money scaling. Independent QoL, World Building, UI options, and Game Difficulty remain available.") },
              { key = "permadeath", default = true,       name = Strings.source("Permadeath"), desc = Strings.source("Fainted Pokemon are considered dead and removed from the party.") },
              { key = "first_rival_forgiveness", default = true, name = Strings.source("First Rival Mercy"), shortName = Strings.source("1st Rival Mercy"), desc = Strings.source("Forgive faint and Whiteout consequences during only the opening Rival battle. The battle still plays and can still be lost normally. ON by default; the Hardcore preset turns it OFF. The exception is permanently consumed when that first Rival battle begins, even if no Pokemon faints.") },
              { key = "encounter_limit", default = true,  name = Strings.source("One Per Area"), shortName = Strings.source("1 Per Area"), desc = Strings.source("Only the first eligible catch per area can be caught.") },
              { key = "failed_encounter", default = true, name = Strings.source("Failed Encounters"), shortName = Strings.source("Failed Enc."), desc = Strings.source("If ON, the first eligible wild/overworld encounter consumes the area even if it is defeated, fled from, or not caught. Dupes and off-type Type Locke encounters remain free. Shiny Clause can bypass only the ordinary area/Dupes limit; it does not bypass No Catching, Type Locke, Static, species-ban, or BST rules.") },
              { key = "nickname_rule", default = true,   name = Strings.source("Nickname"), desc = Strings.source("Require a non-default nickname for newly acquired Pokemon on supported catch, gift, and trade paths. Existing Pokemon are not renamed retroactively; provider paths that cannot safely present a naming prompt are tracked for compatibility review rather than deleted.") },
          }
      },
      {
          title = Strings.source("CLAUSES"),
          rules = {
              { key = "dupes_mode", default = 2, readTrue = 2, readFalse = 0, name = Strings.source("Dupes Clause"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Choose duplicate handling. OFF = duplicates count normally. SPEC = only the exact species is a dupe. FAM = the whole evolution family is a dupe. SPLIT = ancestor/descendant lines are dupes, but sibling branches after a split remain eligible (for example Vaporeon does not block Jolteon). Rejected duplicates never consume the area or a Forgiveness Token. Shiny Clause can override only the Dupes/area limit.") },
              { key = "shiny_clause", default = 0, readTrue = 4, readFalse = 0, name = Strings.source("Shiny Clause"), shortName = Strings.source("Shiny Catch"), numeric = true, digits = 1, min = 0, max = 4, desc = Strings.source("CATCH EXCEPTIONS ONLY — this does not change shiny odds. Choose how many successful shiny catches may bypass the ordinary One Per Area/Failed Encounter state and Dupes Clause. OFF = no shiny exception. 1/2/3 = that many successful run-wide exceptions; each successful shiny exception consumes one allowance. UNLIMITED preserves the traditional clause. Shinies still must satisfy No Catching, Type Locke, Static, species-ban, BST, town/overworld, and other absolute eligibility rules. Changing the limit mid-run does not reset allowances already used.") },
              { key = "shiny_rate_mode", default = 0, name = Strings.source("Shiny Rate"), shortName = Strings.source("Shiny Rate"), numeric = true, digits = 1, min = 0, max = 6, desc = Strings.source("RARITY ONLY — this does not grant catch exceptions. Built-in shiny support is used when no compatible external shiny provider owns the active edition. NATIVE preserves the edition's normal shiny behavior (including R/B/Y virtual Gen-II DV shinies and Gen II's native 1/8192 roll). Higher modes are 1/4096, 1/1024, 1/512, 1/100, 1/10, and ALWAYS. On Gen I the fallback marks the wild Pokemon shiny without changing its DVs/stats; on Gen II it uses the engine's public shiny.roll seam. When a compatible external shiny provider owns the active edition, this row is dormant and displays EXTERNAL; Nuzlocke still consumes the resulting shiny identity for Shiny Clause and tracking.") },
              { key = "shiny_colors", default = true, name = Strings.source("Shiny Colors"), shortName = Strings.source("Shiny Colors"), desc = Strings.source("VISUALS ONLY. When Nuzlocke owns shinies, recolor shiny Pokemon through Gen1Recomp's live pokemon.sprite / pokemon.icon seams in battles, summaries, party icons, evolution/trade/Hall of Fame surfaces, and compatible overworld/follower sprite paths. OFF keeps shiny identity and rules but uses normal colors. If a compatible external shiny provider is active, this control is dormant and the external provider owns shiny presentation.") },
              { key = "shiny_intro", default = true, name = Strings.source("Shiny Intro"), shortName = Strings.source("Shiny Intro"), desc = Strings.source("VISUALS/AUDIO ONLY. When Nuzlocke owns shinies, show a one-shot sparkle burst and shiny sound when a shiny Pokemon first appears in battle, plus lightweight sparkle indicators on supported shiny overworld/follower entities. OFF leaves shiny colors and rule identity intact. If a compatible external shiny provider is active, this control is dormant and the provider owns the intro effects.") },
              { key = "gold_roamer_clause", default = false, name = Strings.source("Roamer Clause"), gen2Only = true, desc = Strings.source("GEN 2 only. Raikou and Entei use a persistent species-specific encounter slot instead of the route where they appear. Failed roamer encounters never consume the route or the roamer slot; a successful capture closes only that roamer's slot. OFF treats roamers like ordinary encounters on the current route.") },
              { key = "gold_egg_encounter_mode", default = 0, readTrue = 1, readFalse = 0, name = Strings.source("Egg Encounter"), shortName = Strings.source("Egg Rule"), gen2Only = true, numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("GEN 2 only. OFF = eggs are provenance-only. RECEIVED = the hatchling uses the area where its egg was created/received. HATCHED = it uses the area where it hatches. GIFT = story/gift eggs without a creation area use a separate Gift Egg slot; bred eggs still use their creation area.") },
              { key = "gold_bug_contest_mode", default = 0, readTrue = 1, readFalse = 0, name = Strings.source("Bug Contest"), gen2Only = true, numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("GEN 2 only. NORMAL = contest catches use ordinary National Park rules. EXEMPT = the final judged contest Pokemon is tracked but consumes no encounter. SLOT = the final judged contest Pokemon uses a dedicated National Park Contest slot separate from ordinary park grass.") },
              { key = "route_forgiveness", default = 0, name = Strings.source("Route Forgiveness"), shortName = Strings.source("Rt. Forgiveness"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("OFF disables F. TOKEN awards/use. 0 starts a NEW GAME with zero tokens; 1 starts with one. Changing the mode mid-run does not refill. Each defeated Gym Leader awards one actual F. TOKEN once while active. Tokens never appear in shops. Use the item manually outside battle to choose and reopen any eligible FAILED encounter area or revive one fallen Pokemon at half HP. Eligible failed areas can also be selected directly from ENC TRACKER. Revivals preserve the exact archived record and respect Party Size Limit/PC capacity.") },
          }
      },
      {
          title = Strings.source("HARDCORE"),
          rules = {
              { key = "no_escape", default = false, name = Strings.source("No Escape"), desc = Strings.source("You cannot run from ordinary wild Pokemon while Nuzlocke is active. The RUN command fails and the turn is spent; scripted/tutorial battles retain their native behavior.") },
              { key = "whiteout_clause", default = false,  name = Strings.source("Whiteout"), desc = Strings.source("ON: a total-party KO may survive and use the normal blackout return only when at least one usable Pokemon remains in the party or PC. Dead Pokemon, PC-locked progression catches, and Eggs do not count. If none remain, the run ends and the save is deleted. OFF: Blackout always ends the run and deletes the save. First Rival Mercy still overrides the opening Rival loss.") },
              { key = "gym_lock_in", default = false, name = Strings.source("Gym Lock-In"), desc = Strings.source("While Nuzlocke is ON, entering a supported Gym blocks ordinary exits until that Gym Leader is defeated. Already-cleared or unrecognized Gyms fail open. The rule never changes Gym story flags and can be toggled during the run unless challenge rules are sealed.") },
              { key = "dungeon_lock_in", default = false, name = Strings.source("Dungeon Lock-In"), shortName = Strings.source("Dng Lock-IN"), desc = Strings.source("While Nuzlocke is ON, a supported multi-exit dungeon seals the exact entrance warp used, not every exit leading to the same outside map. Reach a different legitimate exit to leave. Escape Rope/Dig/Teleport/Fly escape seams are blocked while active. Missing or legacy entry-side data fails open to avoid softlocks.") },
              { key = "no_held_items", default = false, name = Strings.source("No Held Items"), capabilityGate = "held_items", desc = Strings.source("Available when the active game or a compatible provider exposes held-item mechanics. Player Pokemon cannot receive or benefit from held items while Nuzlocke is active. Existing held items are preserved and may still be TAKEN; trainer-held items are unaffected.") },
          }
      },
      {
          title = Strings.source("GAME DIFFICULTY"), shortTitle = Strings.source("DIFFICULTY"),
          rules = {
              { key = "difficulty_profile", default = 0, name = Strings.source("Game Difficulty"), shortName = Strings.source("Difficulty"), numeric = true, digits = 2, min = 0, max = 15, desc = Strings.source("Independent trainer/game difficulty selector. VANILLA is OFF/unaltered. NUZ MEDIUM and the historical-inspired * profiles can scale trainer levels, strengthen/diversify same-type teams, optimize moves, raise native trainer AI, apply trainer Stat EXP/DV floors, and on Gold/Silver add held items when the live team has none. Deeper profiles may tune bosses separately from ordinary trainers. Rival species identity is preserved. External difficulty providers remain authoritative when selected. This never changes Nuzlocke rules such as Set Mode, battle-item bans, or level caps. Selection is saved by stable ID and applies to future battles.") },
          }
      },
      {
          title = Strings.source("BATTLE MECHANICS"), shortTitle = Strings.source("BATTLE MECH"),
          rules = {
              { key = "physical_special_split", default = false, name = Strings.source("Phys/Spec Split"), shortName = Strings.source("P/S Split"), desc = Strings.source("Use modern per-move Physical/Special categories instead of the Generation 1/2 type-based split. OFF preserves native mechanics. ON changes which offensive/defensive stats and Reflect/Light Screen category apply to damaging moves; Gold/Silver also keep Counter/Mirror Coat damage identity aligned. R/B/Y still has its native single Special stat, so Special moves use that stat rather than inventing separate Sp. Atk/Sp. Def values. This is independent of Nuzlocke enforcement and may be changed mid-run.") },
              { key = "badge_boosts", default = true, name = Strings.source("Badge Boosts"), desc = Strings.source("Keep the games' native badge-based battle boosts. ON is vanilla/default. OFF suppresses badge stat/type boosts in battle without removing earned badges or changing overworld progression. Difficulty profiles that already disable badge boosts remain authoritative, so boosts stay suppressed whenever either this rule is OFF or the selected difficulty profile disables them.") },
          }
      },
      {
          title = Strings.source("RUN / PARTY"), shortTitle = Strings.source("RUN/PARTY"),
          rules = {
              { key = "gym_team_size", default = false, name = Strings.source("Gym Team Size"), shortName = Strings.source("Gym Team Cap"), desc = Strings.source("When Nuzlocke is ON, the actual next Gym Leader battle cannot begin while your active party contains more Pokemon than that Leader's live composed team. Fewer Pokemon are allowed. The limit is read from the merged/composed trainer party so compatible Difficulty and trainer mods can change it; ordinary Gym Trainers are unaffected. Box extras and talk to the Leader again. OFF imposes no party-size limit.") },
              { key = "party_size_limit", default = 6, readFallback = 6, writeFallback = 6, name = Strings.source("Party Size Limit"), shortName = Strings.source("Party Limit"), numeric = true, digits = 1, min = 1, max = 6, desc = Strings.source("Maximum number of Pokemon allowed in the active party while Nuzlocke is ON. 6 preserves vanilla party capacity. Catches, gifts, trades, and PC withdrawals that would grow the active party above the selected limit are blocked; deposits and one-for-one PC swaps remain allowed. Set this to 1 for Solo runs. This is independent of Gym Team Size.") },
              { key = "evolution_limit", default = 0, writeFallback = 1, name = Strings.source("Evolution Limits"), shortName = Strings.source("Evo Limits"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Choose evolution restrictions. NORMAL = vanilla evolution behavior. NO FINAL = block an evolution only when its chosen target is a known terminal species with no further evolution in the live merged species data. NO EVOLUTION = block all normal evolution checks. Branching evolutions evaluate the selected target independently; missing or incomplete modded evolution metadata fails open rather than guessing.") },
          }
      },
      {
          title = Strings.source("LEVELS"),
          rules = {
              { key = "level_cap_scope", default = 0, name = Strings.source("Level Cap Scope"), shortName = Strings.source("Lvl Cap Scope"), numeric = true, digits = 1, min = 0, max = 4, desc = Strings.source("Choose how far level caps continue. NONE = no caps. GYMS = Gym caps only. E4 = continue through the Elite Four. CHAMP = also cap the Champion. POSTGAME = also accept an active post-game cap provider. Each option includes everything before it. This is a progression rule, not a Battle Item rule.") },
              { key = "exp_edging", default = false, name = Strings.source("EXP Edging"), desc = Strings.source("When level caps are active, EXP that would push a Pokemon past the current cap is banked on that Pokemon instead of discarded. Banked EXP is released through the normal EXP pipeline after the authoritative cap rises, never above the new cap. PC movement and saves preserve the bank.") },
          }
      },
      {
          title = Strings.source("CATCH RULES"), shortTitle = Strings.source("CATCH"),
          rules = {
              { key = "overworld_encounters", default = false, nativeEditions = {}, capabilityGate = "overworld_encounters", name = Strings.source("Overworld"), desc = Strings.source("Allow Pokemon caught from overworld spawns to count as area encounters.") },
              { key = "town_catches", default = false,         name = Strings.source("Town Catches"), shortName = Strings.source("Twn Catches"), desc = Strings.source("Allow Pokemon caught in towns/cities to count as encounters. Pallet Town starter slot is always tracked regardless.") },
              { key = "ban_legendaries", default = false,      name = Strings.source("No Legendaries"), shortName = Strings.source("No Lgndries"), desc = Strings.source("Legendary Pokemon cannot be caught, gifted, or received in trades while this rule is active. Existing Pokemon are not removed.") },
              { key = "ban_mythicals", default = false,        name = Strings.source("No Mythicals"), shortName = Strings.source("No Mythcs"), desc = Strings.source("Mythical Pokemon cannot be caught, gifted, or received in trades while this rule is active. Existing Pokemon are not removed.") },
              { key = "ban_pseudos", default = false,          name = Strings.source("No Pseudos"), desc = Strings.source("Pseudo-legendary Pokemon cannot be caught, gifted, or received in trades while this rule is active. Existing Pokemon are not removed. In the supported games this includes Dragonite and Tyranitar.") },
              { key = "no_static_encounters", default = false, name = Strings.source("No Static Enc"), desc = Strings.source("Fixed overworld and scripted wild Pokemon cannot be caught. The battle still occurs normally, gifts remain controlled by Gift Pokemon, and ordinary grass, cave, surf, fishing, and roaming encounters are unaffected.") },
              { key = "no_fishing", default = false, name = Strings.source("No Fishing"), desc = Strings.source("Blocks use of fishing rods in the field before a fishing attempt or encounter begins. Old Rod, Good Rod, Super Rod, and compatible rod items may still be obtained, stored, tossed, or sold. Surf, grass/cave encounters, Headbutt, and other encounter methods are unaffected.") },
              { key = "allow_gifts", default = true,      name = Strings.source("Gift Pokemon"), shortName = Strings.source("Gift Mon"), desc = Strings.source("Allow optional gifts, fossils, and Game Corner prize Pokemon. OFF rejects native optional gift transactions before mutation when a safe gate exists; post-mutation external acquisitions are preserved and marked invalid rather than deleted.") },
              { key = "gift_slot_policy", default = 0, name = Strings.source("Gift Slot Policy"), shortName = Strings.source("Gift Slots"), numeric = true, digits = 1, min = 0, max = 1, desc = Strings.source("Choose how allowed gifts, fossils, and prize Pokemon interact with One Per Area. AREA consumes the encounter slot where received. BONUS records provenance and history but does not consume the ordinary area slot. Species legality, party limits, and Gift Pokemon remain independently enforced.") },
              { key = "allow_trades", default = true,     name = Strings.source("In-Game Trades"), shortName = Strings.source("Ingame Trds"), desc = Strings.source("Allow NPC in-game trades. OFF rejects native trades before the outgoing Pokemon is removed when a safe gate exists; post-mutation external trades are preserved and marked invalid rather than destructively rolled back.") },
              { key = "trade_slot_policy", default = 0, name = Strings.source("Trade Slot Policy"), shortName = Strings.source("Trade Slots"), numeric = true, digits = 1, min = 0, max = 1, desc = Strings.source("Choose how allowed NPC trades interact with One Per Area. AREA consumes the encounter slot where the trade occurs. BONUS records the received Pokemon and provenance without consuming the ordinary area slot. Species legality and party limits remain independently enforced.") },
              { key = "maximum_bst", default = 0, name = Strings.source("Maximum BST"), shortName = Strings.source("Max. BST"), numeric = true, min = 0, max = 700, preset = true, desc = Strings.source("Choose a fixed Base Stat Total cap for new catches, gifts, and trades: OFF / 300 / 350 / 400 / 450 / 500 / 550 / 600 / 650 / 700. OFF disables the restriction. Mandatory starters are always exempt so story progression cannot be blocked. Older free-form values are preserved until this control is changed, then it snaps to the nearest preset before cycling. Pokemon with missing or incomplete modded stat data are allowed rather than guessed.") },
              { key = "pkmn_ban", default = false, name = Strings.source("PKMN BAN"), shortName = Strings.source("PKMN BAN"), desc = Strings.source("Open a scrollable National Dex list and selectively ban species from new catches, optional gifts, trades, and Nuzlocke-owned Randomizer candidate pools. R/B/Y expose #001-#151; Gold/Silver/Crystal expose #001-#251. The mandatory opening starter remains progression-safe; Random Starter candidates still honor the list. The hovered species uses the native menu cursor glyph. Existing Pokemon are never removed. The row shows how many species are currently banned; an empty list disables this restriction.") },
              { key = "colorlocke_mode", default = 0, name = Strings.source("Colorlocke"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Restrict NEW Pokemon acquisitions by canonical species color. OFF disables the rule. RANDOM deterministically resolves one color for the run. CHOOSE uses the Color child selector. Existing Pokemon and later evolutions remain legal; unknown custom-species color metadata fails open rather than guessing. This restriction composes with Type Locke, PKMN BAN, BST, and other species rules.") },
              { key = "colorlocke_color", default = 1, name = Strings.source("Color"), numeric = true, digits = 2, min = 1, max = 10, desc = Strings.source("Choose the canonical species color used by Colorlocke CHOOSE mode: BLACK, BLUE, BROWN, GRAY, GREEN, PINK, PURPLE, RED, WHITE, or YELLOW. Sprite replacements and shiny palettes never change legality.") },
              { key = "alphabetlocke_mode", default = 0, name = Strings.source("Alphabetlocke"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Restrict NEW Pokemon acquisitions by the first letter of the canonical species identity. OFF disables the rule. RANDOM deterministically resolves one currently represented A-Z initial for the run. CHOOSE uses the Letter child selector. Localized display names do not change legality; existing Pokemon and later evolutions remain legal.") },
              { key = "alphabetlocke_letter", default = 1, name = Strings.source("Letter"), numeric = true, digits = 2, min = 1, max = 26, desc = Strings.source("Choose A-Z for Alphabetlocke CHOOSE mode. RANDOM selects only from initials represented in the live species registry, so expanded species providers can contribute valid initials without changing canonical-name semantics.") },
              { key = "allow_glitch_pokemon", default = false, name = Strings.source("Allow Glitches"), shortName = Strings.source("Alw. Glitches"), desc = Strings.source("Allow MissingNo, registry-flagged glitch species, and malformed/unregistered species to be caught or received. OFF blocks new glitch acquisitions safely before mutation. Existing glitch Pokemon are never deleted and remain visible as GLITCH in tracking UI.") },
          }
      },
      {
          title = Strings.source("BATTLE CLAUSES"), shortTitle = Strings.source("BATTLE CL."),
          rules = {
              { key = "ohko_clause", default = false, name = Strings.source("OHKO Clause"), shortName = Strings.source("OHKO Cl."), desc = Strings.source("Block one-hit-KO move effects for both sides. The move is announced normally but its OHKO effect fails before damage is applied. OFF preserves normal battle behavior.") },
              { key = "flinch_clause_scope", default = 0, name = Strings.source("Flinch Clause"), shortName = Strings.source("Flinch Cl."), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Block flinch effects by side without cancelling the damaging move that caused them. OFF preserves flinching. SELF suppresses flinches caused by your side, ENEMY suppresses flinches caused by opposing Pokemon, and ALL suppresses both. In Gen 2 this also suppresses newly caused King's Rock flinches.") },
              { key = "trap_clause_scope", default = 0, name = Strings.source("Trap Clause"), shortName = Strings.source("Trap Cl."), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Block partial-trapping lock effects such as Wrap, Bind, Clamp, and Fire Spin while preserving the move's initial damaging hit. OFF preserves trapping. SELF blocks traps started by your side, ENEMY blocks traps started by opposing Pokemon, and ALL blocks both.") },
              { key = "setup_move_scope", default = 0, name = Strings.source("No Setup Moves"), shortName = Strings.source("No Setup"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Block positive in-battle stat-stage boosts caused by moves without banning the damaging part of a move. OFF preserves setup. SELF blocks setup boosts used by your side, ENEMY blocks setup boosts used by opposing Pokemon, and ALL blocks both. This includes Attack, Defense, Speed, Special/Sp. Atk/Sp. Def, Accuracy, and Evasion stage increases; Evasion Clause remains independently useful when you want only evasion boosts banned.") },
              { key = "evasion_clause", default = false, name = Strings.source("Evasion Clause"), shortName = Strings.source("Evasion Cl."), desc = Strings.source("Block positive evasion-stage boosts for both sides, including Double Team and Minimize-style effects. Accuracy-lowering moves and other stat drops are not changed. OFF preserves normal battle behavior.") },
              { key = "status_accuracy_scope", default = 0, name = Strings.source("Accuracy Drops"), shortName = Strings.source("Accuracy"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Independent stat-drop ban. OFF preserves accuracy-lowering effects. SELF blocks accuracy drops caused by your side, ENEMY blocks those caused by opposing Pokemon, and ALL blocks both. It is not synchronized by No Status Moves. Damaging moves still deal their normal damage when only a secondary accuracy drop is suppressed.") },
              { key = "other_stat_drop_scope", default = 0, name = Strings.source("Other Stat Drops"), shortName = Strings.source("Other Drops"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Block negative in-battle stat-stage effects caused by moves other than Accuracy. OFF preserves Attack, Defense, Speed, Special/Sp. Atk/Sp. Def, and Evasion drops. SELF blocks those drops caused by your side, ENEMY blocks those caused by opposing Pokemon, and ALL blocks both. Accuracy Drops is controlled separately. Damaging moves still deal their normal damage when only a secondary stat drop is suppressed.") },
          }
      },
      {
          title = Strings.source("STATUS BANS"), shortTitle = Strings.source("STATUS"),
          rules = {
              { key = "status_move_scope", default = 0, name = Strings.source("No Status Moves"), shortName = Strings.source("No Status"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Bulk control for the six outright status-effect bans listed below; this is not a blanket ban on every non-damaging move. OFF leaves those child bans independently configurable. SELF applies the same ban scope to effects caused by your side, ENEMY to opposing Pokemon, and ALL to both. Changing this parent immediately synchronizes Paralysis, Confusion, Sleep Ban, Poison/Toxic, Burn, and Freeze; those redundant rows are hidden while the parent is non-OFF. Sleep Clause stays independent and is never synchronized because it limits only additional opposing sleep rather than banning sleep outright.") },
              { key = "status_paralysis_scope", default = 0, name = Strings.source("Paralysis"), shortName = Strings.source("Paralysis"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Selective status-effect ban. OFF preserves paralysis. SELF blocks paralysis inflicted by your side, ENEMY blocks paralysis inflicted by opposing Pokemon, and ALL blocks both. Damaging moves still deal their normal damage when only a secondary paralysis effect is suppressed.") },
              { key = "status_confusion_scope", default = 0, name = Strings.source("Confusion"), shortName = Strings.source("Confusion"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Selective status-effect ban. OFF preserves confusion. SELF blocks confusion inflicted by your side, ENEMY blocks confusion inflicted by opposing Pokemon, and ALL blocks both. Damaging moves still deal their normal damage when only a secondary confusion effect is suppressed.") },
              { key = "status_sleep_scope", default = 0, name = Strings.source("Sleep Ban"), shortName = Strings.source("Sleep Ban"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Selective sleep-effect ban. OFF preserves ordinary sleep infliction. SELF blocks sleep inflicted by your side, ENEMY blocks sleep inflicted by opposing Pokemon, and ALL blocks both. Self-induced sleep such as Rest remains allowed. This is an outright side-scoped sleep ban; the separate Sleep Clause instead permits one opposing Pokemon to be asleep and blocks only additional opposing sleep.") },
              { key = "status_poison_scope", default = 0, name = Strings.source("Poison/Toxic"), shortName = Strings.source("Poison"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Selective poison-effect ban. OFF preserves ordinary poison and Toxic/bad poison. SELF blocks poison inflicted by your side, ENEMY blocks poison inflicted by opposing Pokemon, and ALL blocks both. Damaging moves still deal their normal damage when only a secondary poison effect is suppressed.") },
              { key = "status_burn_scope", default = 0, name = Strings.source("Burn Ban"), shortName = Strings.source("Burn"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Selective burn-effect ban. OFF preserves burn. SELF blocks burn inflicted by your side, ENEMY blocks burn inflicted by opposing Pokemon, and ALL blocks both. Damaging Fire moves still deal their normal damage when only a secondary burn effect is suppressed.") },
              { key = "status_freeze_scope", default = 0, name = Strings.source("Freeze"), shortName = Strings.source("Freeze"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Selective freeze-effect ban. OFF preserves freeze effects. SELF blocks freeze inflicted by your side, ENEMY blocks freeze inflicted by opposing Pokemon, and ALL blocks both. Damaging Ice moves still deal their normal damage when only their freeze side effect is suppressed.") },
              { key = "sleep_clause", default = false, name = Strings.source("Sleep Clause"), shortName = Strings.source("Sleep Cl."), desc = Strings.source("Prevent either side from putting a second opposing Pokemon to sleep while another living opposing Pokemon remains asleep from that side's move. Self-induced sleep such as Rest does not count. This rule is independent of No Status Moves and Sleep Ban. OFF preserves normal battle behavior.") },
          }
      },
      {
          title = Strings.source("VARIANTS"),
          rules = {
              { key = "type_lock_mode", default = 0, name = Strings.source("Type Locke"), numeric = true, digits = 1, min = 0, max = 6, desc = Strings.source("Controls NEW acquisition eligibility. OFF = unrestricted. MONO/DUO/TRI/QUAD/PENTA/HEXA allow 1-6 Type Locke lanes. A catch/gift/trade is legal when it matches any active lane. Dual-type Pokemon need only one matching type. Off-type wild encounters are free and cannot consume the area or a Forgiveness Token. Existing Pokemon are never deleted, and the mandatory story starter remains progression-safe. Unknown provider-owned type metadata fails open. Shiny Clause does not bypass Type Locke.") },
              { key = "type_lock_draft", default = false, name = Strings.source("Catch Draft"), desc = Strings.source("If ON, do not select Type Locke lanes up front. The opening catches are unrestricted while they fill the selected number of lanes from their actual types. Each catch contributes one type, preferring a type not already drafted when a dual-type Pokemon offers one. Once all lanes are filled, normal Type Locke enforcement begins. Gifts and trades do not draft lanes.") },
              { key = "type_lock_primary", default = 0, name = Strings.source("Type 1"), numeric = true, digits = 2, min = 0, max = 18, desc = Strings.source("First allowed lane when Catch Draft is OFF. RANDOM rolls once and persists.") },
              { key = "type_lock_secondary", default = 9, readFallback = 9, name = Strings.source("Type 2"), numeric = true, digits = 2, min = 0, max = 18, desc = Strings.source("Second allowed lane for Duolocke or higher when Catch Draft is OFF. RANDOM resolves once and persists.") },
              { key = "type_lock_tertiary", default = 10, readFallback = 10, name = Strings.source("Type 3"), numeric = true, digits = 2, min = 0, max = 18, desc = Strings.source("Third allowed lane for Trilocke or higher when Catch Draft is OFF. RANDOM resolves once and persists.") },
              { key = "type_lock_quaternary", default = 8, readFallback = 8, name = Strings.source("Type 4"), numeric = true, digits = 2, min = 0, max = 18, desc = Strings.source("Fourth allowed lane for Quadlocke or higher when Catch Draft is OFF. RANDOM resolves once and persists.") },
              { key = "type_lock_quinary", default = 11, readFallback = 11, name = Strings.source("Type 5"), numeric = true, digits = 2, min = 0, max = 18, desc = Strings.source("Fifth allowed lane for Pentalocke or Hexalocke when Catch Draft is OFF. RANDOM resolves once and persists.") },
              { key = "type_lock_senary", default = 2, readFallback = 2, name = Strings.source("Type 6"), numeric = true, digits = 2, min = 0, max = 18, desc = Strings.source("Sixth allowed lane for Hexalocke when Catch Draft is OFF. RANDOM resolves once and persists.") },
              { key = "wonderlocke", default = false, name = Strings.source("Wonderlocke WIP"), shortName = Strings.source("Wndrlocke"), desc = Strings.source("WIP: Wonderlocke is not currently selectable or active. It remains disabled while Wonder Trade compatibility is being completed and tested.") },
          }
      },
      {
          title = Strings.source("BATTLE ITEMS"),
          rules = {
              { key = "no_healing_items", default = false, name = Strings.source("No Healing Items"), shortName = Strings.source("No Heal Itms"), desc = Strings.source("Potions, Revives, and status-healing items cannot be used in battle.") },
              { key = "no_battle_items", default = false,  name = Strings.source("No X Items"), shortName = Strings.source("No X Itms"), desc = Strings.source("X Attack, X Defend, and similar non-healing battle items cannot be used in battle. Poke Balls are unaffected.") },
              { key = "no_catching", default = false, name = Strings.source("No Catching"), shortName = Strings.source("Catching"), desc = Strings.source("ON blocks every capture attempt with every recognized Ball, including custom Balls exposed through the engine/API. Gifts, trades, prizes, and other scripted non-capture acquisitions are governed by their own rules. This fully replaces the retired partial Poke Ball-ban selector; the old tier is hidden migration data only.") },
              { key = "encounter_ball_limit", default = 0, readTrue = 0, readFalse = 0, name = Strings.source("Ball Per Enc."), shortName = Strings.source("Ball/Enc"), numeric = true, digits = 1, min = 0, max = 5, desc = Strings.source("Limit legal Ball throws per catchable encounter. OFF = unlimited. Modes are 1, 2, 3, 5, or 10 throws. Blocked/illegal Ball attempts do not spend the budget, and the counter resets for each new battle. Gifts, trades, prizes, and non-capture acquisitions are unaffected.") },
          }
      },
      {
          title = Strings.source("FIELD ITEMS"),
          rules = {
              { key = "no_repels", default = false, name = Strings.source("No Repels"), desc = Strings.source("Repel, Super Repel, and Max Repel cannot be used in the field. They may still be obtained, stored, tossed, or sold.") },
              { key = "no_escape_rope", default = false, name = Strings.source("No Escape Rope"), shortName = Strings.source("No Esc. Rope"), desc = Strings.source("Escape Rope cannot be used. It may still be obtained, stored, tossed, or sold.") },
              { key = "travel_restrictions", default = 0, writeFallback = 1, name = Strings.source("Travel Restrictions"), shortName = Strings.source("Travel"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Choose player field-move travel restrictions while Nuzlocke is ON. NORMAL = native behavior. NO FLY blocks only player-initiated Fly. NO FLY+TELEPORT blocks player-initiated Fly and Teleport. Dig, Escape Rope, scripted/story transportation, warps, trains, ferries, and other travel remain unchanged.") },
              { key = "no_field_healing", default = false, name = Strings.source("No Field Heal"), desc = Strings.source("HP, status, and revival medicine cannot be used outside battle. PP recovery is controlled separately by No PP Items.") },
              { key = "no_pp_items", default = false, name = Strings.source("No PP Items"), shortName = Strings.source("No PP Itms"), desc = Strings.source("Ether/Elixir-family PP recovery and PP Up-style PP boosters cannot be used in or out of battle. This is independent of the battle-healing rule.") },
              { key = "no_tm_use", default = false, name = Strings.source("No TMs"), desc = Strings.source("Technical Machines cannot be used to teach moves. HMs remain usable. TMs may still be obtained, stored, tossed, bought, or sold when other rules permit.") },
              { key = "no_rare_candy_use", default = false, name = Strings.source("No Rare Candy"), shortName = Strings.source("No Rare Cndy"), desc = Strings.source("Rare Candy cannot be used. It may still be obtained, stored, tossed, bought, sold, or supplied by the Gym Guide when other rules permit.") },
          }
      },
      {
          title = Strings.source("SERVICES & ECONOMY"), shortTitle = Strings.source("SERVICES/ECON"),
          rules = {
              { key = "no_poke_center", default = false,  name = Strings.source("No Center Heal"), desc = Strings.source("Cannot heal at Pokemon Centers. Nurse Joy will turn you away.") },
              { key = "no_mom_heal", default = false,      name = Strings.source("No Mom Heal"), desc = Strings.source("Mom cannot heal your party when you visit home. She will remind you of your rules instead.") },
              { key = "no_day_care", default = false, name = Strings.source("No Day Care"), desc = Strings.source("Blocks only NEW Day Care deposits while Nuzlocke is active. Existing deposited Pokemon can always be withdrawn, even if the rule is enabled later. R/B/Y also guard compatible custom Day Care pick-only deposit flows; Gold/Silver preserve existing parents, compatibility state, and pending Egg state rather than deleting or trapping them.") },
              { key = "shop_restrictions", default = 0, name = Strings.source("Shop Restrictions"), shortName = Strings.source("Shop Rules"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Choose mart transaction restrictions. OFF = normal buying and selling. NO BUY blocks purchases only. NO SELL blocks sales only. NEITHER blocks both buying and selling. Other services and Game Corner wagering/prizes remain controlled separately.") },
              { key = "no_gambling", default = false, name = Strings.source("No Gambling"), shortName = Strings.source("No Gmblng"), desc = Strings.source("Blocks Game Corner wagering and prize redemption before coins or prizes change hands. Story movement, the Rocket Hideout path, coin gifts, and buying coins remain available.") },
              { key = "trainer_money_multiplier", default = 4, readFallback = 4, writeFallback = 4, name = Strings.source("Trainer Money"), shortName = Strings.source("Btl. ¥"), numeric = true, digits = 1, min = 0, max = 8, neutral = 4, desc = Strings.source("While Nuzlocke is ON, scale the final money actually awarded by defeated trainers: 0/25/50/75/100/150/200/300/500%. 100% is vanilla. Scaling happens after the underlying trainer/economy payout so compatible providers remain authoritative; OFF at the master switch leaves the vanilla/provider payout untouched.") },
          }
      },
      {
          title = Strings.source("POKEMON STATS"), shortTitle = Strings.source("PKMN STATS"),
          rules = {
              { key = "player_start_stat_exp", default = 0, name = Strings.source("Player Stat EXP"), shortName = Strings.source("Plyr Stat EXP"), numeric = true, digits = 1, min = 0, max = 5, desc = Strings.source("Starting Stat EXP for newly acquired player Pokemon. DEFAULT 0% is vanilla: newly created Pokemon begin with zero Stat EXP. This slider is a challenge preset scale, not a percent of vanilla: 100% = 32768 per stored stat and 200% = the native 65535 cap. Existing Pokemon are not changed.") },
              { key = "wild_start_stat_exp", default = 0, name = Strings.source("Wild Stat EXP"), shortName = Strings.source("Wld Stat EXP"), numeric = true, digits = 1, min = 0, max = 5, desc = Strings.source("Starting Stat EXP for newly generated wild Pokemon. DEFAULT 0% is vanilla in R/B/Y and Gold/Silver/Crystal. 100% means 32768 per stored stat and 200% means the native 65535 cap; higher presets strengthen the Pokemon immediately. Existing Pokemon are not changed.") },
              { key = "trainer_start_stat_exp", default = 0, name = Strings.source("Trainer Stat EXP"), shortName = Strings.source("Trnr Stat EXP"), numeric = true, digits = 1, min = 0, max = 5, desc = Strings.source("Starting Stat EXP for newly generated trainer Pokemon. DEFAULT 0% is vanilla in R/B/Y and Gold/Silver/Crystal; native Gen 2 trainer construction also starts with zero Stat EXP. 100% means 32768 per stored stat and 200% means the 65535 cap. Species, levels, and moves are unchanged.") },
              { key = "no_player_stat_exp_gain", default = false, name = Strings.source("No Stat EXP Gain"), shortName = Strings.source("No Stat EXP"), desc = Strings.source("Player Pokemon cannot accumulate additional native Stat EXP from battles or vitamins. Their existing Stat EXP is preserved, EXP and level gain still work normally, and enemy Pokemon are unaffected. If an external modern-stat provider owns EV growth, this native-only control is delegated rather than pretending to block that separate system.") },
              { key = "perfect_player_ivs", default = false, name = Strings.source("Perfect Player IVs"), shortName = Strings.source("Perfect Plyr IVs"), desc = Strings.source("Newly acquired player Pokemon receive perfect native Gen 1/2 DVs (15 in every DV, including derived HP). Existing Pokemon are not changed. Modern IVs from an external stat provider are a separate mechanic; native DVs can still remain meaningful for Gen 2 identity traits such as shiny/gender/Unown.") },
              { key = "perfect_wild_ivs", default = false, name = Strings.source("Perfect Wild IVs"), shortName = Strings.source("Perfect Wld IVs"), desc = Strings.source("Newly generated wild Pokemon receive perfect Gen 1/2 DVs. If caught, the Player IV rule may then apply independently to the caught Pokemon.") },
              { key = "perfect_trainer_ivs", default = false, name = Strings.source("Perfect Trainer IVs"), shortName = Strings.source("Perfect Trnr IVs"), desc = Strings.source("Newly generated trainer Pokemon receive perfect Gen 1/2 DVs instead of the vanilla trainer DV preset. Trainer species, levels, and moves are unchanged.") },
          }
      },
      {
          title = Strings.source("AREA SPLITS"), shortTitle = Strings.source("ROUTE SPLITS"),
          rules = {
              { key = "route_2_split", rbyOnly = true, default = false, name = Strings.source("Route 2"), shortName = Strings.source("Rt. 2"), desc = Strings.source("Treat Route 2 North and South as separate encounter areas. Viridian Forest physically separates the two sections and they are normally reached at different stages of Kanto progression. OFF keeps all of Route 2 as one encounter area.") },
              { key = "route_10_split", rbyOnly = true, default = false, name = Strings.source("Route 10"), shortName = Strings.source("Rt. 10"), desc = Strings.source("Treat Route 10 North and South as separate encounter areas. Rock Tunnel sits between the two sections, making this one of Kanto's most common progression-based route splits. OFF keeps all of Route 10 as one encounter area.") },
              { key = "route_20_split", rbyOnly = true, default = false, name = Strings.source("Route 20"), shortName = Strings.source("Rt. 20"), desc = Strings.source("Treat Route 20 West and East as separate encounter areas. Seafoam Islands divide the route into opposite-side sections during normal progression. OFF keeps all of Route 20 as one encounter area.") },
              { key = "mt_moon_splits", rbyOnly = true, default = 0, name = Strings.source("Mt. Moon"), numeric = true, digits = 1, min = 0, max = 1, desc = Strings.source("Choose Mt. Moon encounter areas. OFF = the whole dungeon shares one encounter. COMMON = 1F, B1F, and B2F each receive an encounter. Tracker rows, counts, and catch legality update immediately when changed.") },
              { key = "safari_zone_splits", default = 0, nativeEditions = { red=true, blue=true, yellow=true }, capabilityGate = "safari_zone", name = Strings.source("Safari Clause"), shortName = Strings.source("Safari"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Safari encounter policy. STANDARD = one slot for the whole Safari Zone with normal Failed Encounters. PER AREA = Center, East, North, and West each receive a slot. UNTIL CATCH = one whole-zone slot that is not consumed by Safari failures/flees until a successful catch. AREA+CATCH combines per-area slots with until-catch behavior. Existing OFF/COMMON saves retain their old behavior as STANDARD/PER AREA.") },
              { key = "gold_time_split", default = false, name = Strings.source("Time Split"), gen2Only = true, desc = Strings.source("GEN 2 only. Morning, day, and night GRASS encounters count as separate encounter opportunities on the same physical map. Water, fishing, Headbutt, static, gift, and other methods are not multiplied by time. OFF collapses the live projection back to the physical area without deleting history.") },
              { key = "gold_headbutt_split", default = false, name = Strings.source("Headbutt Split"), shortName = Strings.source("Headbutt"), gen2Only = true, desc = Strings.source("GEN 2 only. Headbutt-tree encounters use a separate encounter slot from ordinary grass, water, and fishing on the same physical map. The split is per map, not per individual tree.") },
          }
      },
      {
          title = Strings.source("RANDOMIZER"),
          rules = {
              { key = "randomizer_preset", default = 0, name = Strings.source("Rndm Preset"), shortName = Strings.source("Rndm Preset"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Unified Randomizer configuration. CUSTOM leaves every subsystem under individual control. CHAOS enables every Nuzlocke-owned randomizer with broad/unbalanced policies. BALANCED enables every Nuzlocke-owned randomizer with progression-aware balance defaults. Applying a preset never takes ownership from an external provider; changing an individual Randomizer setting returns this row to CUSTOM without rerolling the shared seed.") },
              { key = "randomizer_seed", default = 0, name = Strings.source("Rndm Seed"), shortName = Strings.source("Rndm Seed"), numeric = true, digits = 8, min = 0, max = 99999999, desc = Strings.source("Shareable deterministic randomizer seed. 00000000 means AUTO: each NEW GAME with a Nuzlocke-owned seed-driven randomizer enabled resolves a fresh 8-digit run seed while Setup stays AUTO. Enter any nonzero seed for a FIXED reproducible run, or use Reroll Seed in Setup to generate a new fixed seed instantly. Starter, encounter, field-item, learnset, and trainer systems use separate deterministic streams, so enabling one does not perturb another. The same game/content registry, randomizer settings, resolved seed, and RNG algorithm version reproduce the same generated choices. Edit all 8 digits directly with A/Left/Right and Up/Down. Upgraded runs with existing nonzero seeds remain fixed and preserve prior seeded behavior.") },
              { key = "random_starter", default = false, name = Strings.source("Rndm Strtr"), shortName = Strings.source("Rndm Strtr"), desc = Strings.source("Randomize only the Pokemon you receive as your starter in Red, Blue, Yellow, Gold, or Silver. Seeded runs are deterministic. Starter Style can require a base form, a true three-stage evolutionary line, or a species with BST similar to the original starter. The selected ball and normal story/rival choice remain intact. Invalid/glitch species and active challenge bans are excluded; if an over-restrictive style has no legal candidate, the required starter safely falls back to the broader legal pool.") },
              { key = "random_starter_style", default = 0, name = Strings.source("Strtr Style"), shortName = Strings.source("Strtr Style"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Shown and active only while Random Starter is ON. Random Starter candidate shape. ANY = any legal species. 3-STAGE = a base-form species with an evolution and a later evolution after that. BASE = any unevolved/base-form species, including single-stage species. SIM BST = species near the original starter's live merged Base Stat Total. If the selected style leaves no legal progression-safe candidate, Random Starter falls back to ANY rather than breaking the story.") },
              { key = "random_starter_balance", default = 0, name = Strings.source("Strtr Balance"), shortName = Strings.source("Strtr Bal."), numeric = true, digits = 1, min = 0, max = 1, desc = Strings.source("Shown and active only while Random Starter is ON. INDEPENDENT preserves ordinary deterministic starter-slate selection. BALANCED prefers choices with comparable current strength plus evolutionary potential and widens tolerance only when needed. Hard legality, Starter Style, and distinctness always outrank balance.") },
              { key = "random_starter_trio_typing", default = 0, nativeEditions = { red=true, blue=true, gold=true, silver=true, crystal=true }, capabilityGate = "starter_trio", name = Strings.source("Trio Typing"), shortName = Strings.source("Trio Type"), numeric = true, digits = 1, min = 0, max = 1, desc = Strings.source("Shown and active only while Random Starter is ON. OFF ignores type relationships. AUTO prefers a three-way offensive type cycle using each candidate's full dual typing, then falls back to the legal distinct slate when no cycle is available. Applies to the three-choice Red/Blue and Gold/Silver/Crystal starter transactions; Yellow's two-position starter/rival transaction was unchanged during build development.") },
              { key = "random_starter_rerolls", default = false, name = Strings.source("Starter Rerolls"), shortName = Strings.source("Strtr Reroll"), desc = Strings.source("Shown and active only while Random Starter is ON. OFF keeps the first deterministic starter slate. ON enables the separate Reroll Starter action only before a starter has actually been accepted. Each reroll uses the same run seed plus an isolated starter reroll index, never consumes encounter/item/learnset streams, and avoids repeating the immediately previous full slate when another legal slate exists.") },
              { key = "random_encounter_tables", default = false, name = Strings.source("Random Encounters"), shortName = Strings.source("Rndm Enc."), desc = Strings.source("Randomize wild encounter-table species while preserving each slot's native level, rate, time-of-day, fishing/tree method, and map structure. Seeded slot hashes make fresh 2.2.19+ worlds shareable and independent of traversal order. Encounter Balance controls whether replacements are pure chaos, similar BST, similar evolution stage, or both. Uses the live merged species registry and yields completely to an external encounter-randomizer provider when one owns the mechanic.") },
              { key = "random_field_items", default = false, name = Strings.source("Random Field Items"), shortName = Strings.source("Rndm Items"), desc = Strings.source("Randomize supported overworld field pickups when collected. Visible item-ball sources use their map/object identity, and native Gen II hidden/BG-event item sources are also supported when the adapter explicitly marks them as Nuzlocke-owned. Each source uses the deterministic FIELD_ITEMS stream under the shared randomizer seed, so enabling this does not change Starter, Encounter, or Learnset results. Progression-critical/key items and HMs are protected in place and are never selected as replacements. Arbitrary third-party hidden sources, fruit/apricorn trees, and unrelated scripted rewards are not claimed automatically; scripted gift items and shops use their own dedicated Randomizer subsystems.") },
              { key = "random_field_item_balance", default = 0, name = Strings.source("Field Item Balance"), shortName = Strings.source("Item Balance"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown and active only while Random Field Items is ON. CHAOS preserves the full hard-safe pool and exact legacy behavior. CATEGORY prefers replacements from the original pickup's semantic item category, then falls back to the full hard-safe pool. BALANCED first prefers the same semantic category and utility tier, then category, then utility tier, before the hard-safe pool. Progression/key/HM/provider protections are hard constraints and never relax.") },
              { key = "random_field_item_repetition", default = 0, name = Strings.source("Field Item Repeats"), shortName = Strings.source("Item Repeats"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown and active only while Random Field Items is ON. ALLOW preserves independent deterministic pickup rolls and exact 2.6.87 behavior. DIVERSE deterministically biases each physical source toward a different placement slot while retaining independent outcomes on some seeds. UNIQUE uses a stable source-ordinal permutation inside the same semantic candidate pool, avoiding duplicates whenever the native object/source ordinals fit within that pool. No mode can relax key/HM/progression/provider protection.") },
              { key = "random_encounter_balance", default = 0, name = Strings.source("Encounter Balance"), shortName = Strings.source("Enc. Balance"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Shown and active only while Random Encounters is ON. CHAOS = any hard-safe species in the selected pool. SIM BST prefers the historical ~15% BST band, then widens deterministically to ~25% and ~40% before using the hard-safe pool. EVO first matches evolution stage plus similar family depth/remaining evolutions, then stage alone, then progression-adjusted strength. BALANCED combines progression shape with BST, then progressively relaxes through stage/progression and wider BST bands. Encounter rates and slot levels never change.") },
              { key = "random_encounter_repetition", default = 0, name = Strings.source("Encounter Repeats"), shortName = Strings.source("Enc. Repeats"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown and active only while Random Encounters is ON. ALLOW preserves independent slot rolls. DIVERSE softly lowers the weight of species already used in the same encounter source group while keeping every legal candidate reachable. UNIQUE uses without-replacement selection inside that group whenever possible, and relaxes only when the legal candidate pool is exhausted. Encounter rates, levels, methods, and table structure never change.") },
              { key = "random_encounter_diversity_strength", default = 1, name = Strings.source("Diversity Strength"), shortName = Strings.source("Diversity"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown only while Random Encounters is ON and Encounter Repeats is DIVERSE. LIGHT, STANDARD, and STRONG control how sharply already-used species are de-weighted inside the same encounter source group. STANDARD preserves the 2.6.83 DIVERSE weighting. This is always a soft preference: every hard-safe candidate remains reachable.") },
              { key = "randomizer_info_policy", default = 0, name = Strings.source("Randomizer Info"), shortName = Strings.source("RNG Info"), numeric = true, digits = 1, min = 0, max = 1, desc = Strings.source("Shown while a supported Nuzlocke randomizer is ON. OPEN INFO lets compatible information tools reveal persisted starter slates, randomized encounter results, and visible field-item mappings. BLIND INFO hides randomized species/items while preserving read-only diagnostic metadata: algorithm/policy versions, seed, randomizer modes, edition/item-table model, encounter source/class/time/group identity, Field Item ownership/category/table-class counts, protected/mapping counts, reroll state, and fallback diagnostics. Reading this information consumes no RNG and does not rewrite randomizer mappings.") },
              { key = "random_species_generation", default = 0, name = Strings.source("Species Pool"), shortName = Strings.source("Species Pool"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Shared species source for Random Encounters, Random Trainers, and Random Evolutions. Hidden and inactive when all three are OFF. Random Starter deliberately uses its own hard-safe live pool plus Starter Style so mandatory starter selection cannot be disabled by a shared generation filter. AUTO uses the complete hard-safe live merged species registry. GEN1 selects indexed Generation 1 species, GEN2 selects indexed Generation 2 species, and BOTH selects Generation 1 + 2. Every subsystem still applies its own stronger legality, story, construction, and challenge constraints after this shared generation filter.") },
              { key = "random_learnsets", default = false, name = Strings.source("Random Learnsets"), shortName = Strings.source("Rndm Lrnset"), desc = Strings.source("Randomize species starting moves and level-up learnset moves while preserving the original number of move entries and every learn level. Fresh 2.2.19+ choices are deterministic from the displayed seed using a LEARNSETS stream separate from starters and encounters, so toggling one randomizer never perturbs another. Existing Pokemon keep moves they already know; future creation and level-up learning use the randomized registry.") },
              { key = "random_trainers", default = false, name = Strings.source("Random Trainers"), shortName = Strings.source("Rndm Trnrs"), desc = Strings.source("Deterministically randomize trainer-party species while preserving trainer/story identity, party size, member order, and every authored level. Exact-edition trainer/class/party/member source identities use an isolated TRAINERS RNG stream. Hard candidate safety rejects invalid/glitch/runtime-unsafe species and honors PKMN BAN; player-only catch restrictions do not rewrite opposing trainer pools. Trainer Balance can preserve evolutionary stage, similar BST, or both. Boss teams use ace-anchored TYPE cohesion and a soft anti-downgrade floor under non-CHAOS balance. Trainer Randomizer composes inside built-in Difficulty so Difficulty adapts its moves/items/stats to the randomized species; provider/base parties remain the immutable composition input.") },
              { key = "random_evolutions", default = false, name = Strings.source("Random Evolutions"), shortName = Strings.source("Rndm Evos"), desc = Strings.source("Deterministically randomize evolution targets while preserving each species as the authored source and preserving every native evolution row's method, level, item, and other trigger metadata. Projected topology rejects self-evolutions and newly-created cycles. Starter/rival lineage continues to read the immutable pre-randomization topology.") },
              { key = "random_evolution_balance", default = 0, name = Strings.source("Evolution Balance"), shortName = Strings.source("Evo Balance"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Shown only while Random Evolutions is ON. CHAOS chooses from the full hard-safe acyclic pool. DEPTH prefers targets matching the authored target's original chain depth and remaining evolution depth. SIM BST prefers targets near the authored target's Base Stat Total. BALANCED combines chain-depth and similar-strength preferences, then relaxes deterministically. Hard construction safety and cycle prevention are never relaxed.") },
              { key = "random_shops", default = false, name = Strings.source("Random Shops"), shortName = Strings.source("Rndm Shops"), desc = Strings.source("Deterministically randomize ordinary Mart BUY stock while preserving shop identity, stock-slot count/order, native quantities, and native item prices. Key/progression items and HMs stay protected; TMs are preserved for the dedicated TM phase. Uses an isolated SHOPS stream so existing randomizer streams do not move.") },
              { key = "random_shop_balance", default = 2, name = Strings.source("Shop Balance"), shortName = Strings.source("Shop Balance"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown only while Random Shops is ON. CHAOS uses any ordinary purchasable hard-safe item. PRICE TIER prefers replacements in the authored item's native price tier. BALANCED first prefers both semantic category and price tier, then safely relaxes. Native item prices are never rewritten, so buy/sell arithmetic remains engine-owned.") },
              { key = "random_tms", default = false, name = Strings.source("Random TMs"), shortName = Strings.source("Rndm TMs"), desc = Strings.source("Randomize the move taught by each TM while preserving TM item identity and every HM. Uses an isolated TMS stream. TM Compatibility controls whether eligibility follows the randomized move, the authored TM slot, or is universal.") },
              { key = "random_tm_compatibility", default = 0, name = Strings.source("TM Compatibility"), shortName = Strings.source("TM Compat"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown only while Random TMs is ON. MOVE keeps native move-based compatibility. SLOT preserves each species authored eligibility for that TM slot while teaching the randomized move. FULL allows every species to learn every randomized TM. HMs are never changed.") },
              { key = "random_tm_locations", default = false, name = Strings.source("Random TM Locations"), shortName = Strings.source("TM Locations"), desc = Strings.source("Randomize which TM item is obtained from supported physical TM pickup sources while preserving the source itself, quantity, collection flow, and every HM. Uses an isolated TM_LOCATIONS stream. This is separate from Random TMs, which changes the move taught by a TM. If Random Field Items is also ON, this TM-only method takes precedence for authored TM pickups; with TM Locations OFF, Random Field Items keeps its historical broader item-pool behavior.") },
              { key = "random_gift_items", default = false, name = Strings.source("Random Gift Items"), shortName = Strings.source("Rndm Gifts"), desc = Strings.source("Randomize ordinary scripted GIVEITEM gifts through an isolated deterministic stream while preserving quantity, script flags, inventory capacity, and transaction flow. Key/progression items, HMs, TMs, and provider-protected items remain authored. Dedicated NPC reward-item command surfaces are included when exposed by the active game/provider.") },
              { key = "random_trainer_balance", default = 0, name = Strings.source("Trainer Balance"), shortName = Strings.source("Trnr Balance"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Shown and active only while Random Trainers is ON. CHAOS preserves unrestricted hard-safe deterministic replacement. EVO prefers species at the authored Pokemon's original evolutionary stage and nearby lineage depth. SIM BST prefers species near the original live merged Base Stat Total. BALANCED combines evolutionary-stage and BST preferences, then widens deterministically if necessary. Hard trainer-pool safety and PKMN BAN are never relaxed.") },
              { key = "random_trainer_diversity", default = 0, name = Strings.source("Trainer Diversity"), shortName = Strings.source("Trnr Diverse"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown only while Random Trainers is ON. OFF preserves the established independent member mapping. DIVERSE prefers species not already selected for that trainer team and safely falls back if the candidate pool is exhausted. UNIQUE applies the same no-repeat requirement until no unused hard-safe candidate remains. Team policy uses its own deterministic namespace.") },
              { key = "random_trainer_theme", default = 0, name = Strings.source("Trainer Theme"), shortName = Strings.source("Trnr Theme"), numeric = true, digits = 1, min = 0, max = 1, desc = Strings.source("Shown only while Random Trainers is ON. OFF applies no team theme. TYPE softly prefers replacements sharing at least one type with the authored team's anchor member, after hard legality and Trainer Balance. If no themed candidate is available, the hard-safe balanced pool is used.") },
              { key = "random_learnset_generation", default = 0, name = Strings.source("Learnset Gen"), shortName = Strings.source("Lrnset Gen"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Move source used only by Random Learnsets. This row is hidden and has no effect while Random Learnsets is OFF. AUTO uses every valid move in the active merged move registry. GEN1 uses move indices 1-165. GEN2 uses indices 166-251; on a game/provider registry with no Gen 2 moves, that source safely leaves learnsets unchanged rather than inventing unavailable moves.") },
              { key = "random_learnset_stab", default = 1, name = Strings.source("Learnset STAB"), shortName = Strings.source("Lrnset STAB"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shown only while Random Learnsets is ON. OFF removes species-type preference. PREFER gives same-type moves a soft deterministic weight while every hard-safe move remains reachable. STRONG increases that soft weight; it never becomes a hard STAB requirement.") },
          }
      },
      {
          title = Strings.source("WORLD"),
          rules = {
              { key = "world_building_tier", default = 3, readFallback = 3, writeFallback = 3, name = Strings.source("World Building"), numeric = true, digits = 1, min = 0, max = 3, desc = Strings.source("Adds optional Nuzlocke flavor throughout Kanto and Johto. TIER 1 = clear rule feedback, TIER 2 = challenge personality, TIER 3 = region/NPC-aware story flavor. OFF disables optional flavor, while rule-enforcement rejections still show a plain explanation. DEFAULT: TIER 3. Cosmetic and always changeable, even after a Permanent Rule Seal.") },
              { key = "gold_radio_world_building", default = false, capabilityGate = "pokegear_radio", name = Strings.source("Radio Nuzlocke"), shortName = Strings.source("Radio Nuz"), gen2Only = true, desc = Strings.source("GEN 2 only. Adds compact Nuzlocke status/world-building lines to the Pokegear Radio while preserving native radio station ownership. Requires World Building T1-T3; OFF or World Building OFF leaves the radio vanilla.") },
          }
      },
      {
          title = Strings.source("QOL"),
          rules = {
              { key = "progression_pc_catches", default = false, name = Strings.source("PC-Only Catches"), shortName = Strings.source("PC Catches"), desc = Strings.source("Allow otherwise Nuzlocke-illegal captures for Pokedex/story progression and completion only. Eligible captures are immediately moved to PC storage, permanently marked PC LOCKED, do not consume an encounter slot, do not draft Type Locke lanes, and cannot be withdrawn, moved into the active party, or released. No Catching remains absolute for ordinary encounters unless a compatible source explicitly declares the capture progression-required; malformed/glitch safety is never bypassed, and Party Size Limit by itself never turns an otherwise legal catch into a PC-only catch. OFF preserves the normal catch rejection behavior.") },
              { key = "instant_text", default = false, name = Strings.source("Instant Text"), shortName = Strings.source("Instant Text"), desc = Strings.source("QoL for R/B/Y and Gold/Silver/Crystal. ON removes the per-character typewriter delay from ordinary dialogue while preserving native page breaks, CONT prompts, A/B waits, scrolling, cries/fanfare waits, choice boxes, and scripted text timing. OFF uses the live game text-speed option normally.") },
              { key = "skip_cherrygrove_tour", default = false, capabilityGate = "cherrygrove_tour", name = Strings.source("Skip Cherrygrove Tour"), gen2Only = true, desc = Strings.source("GEN 2 only. Before the Guide Gent tour is completed, accepting his offer skips the long walking lesson and resumes at the MAP CARD reward. The native reward flag, final dialogue, object cleanup, story state, and Pokegear progression still run normally. OFF keeps the full vanilla tour.") },
              { key = "run_surf", default = 0, preGameReadCoerce = true, readTrue = 1, readFalse = 0, writeTrue = 1, writeFalse = 0, name = Strings.source("Run / Surf"), shortName = Strings.source("Run / Surf"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shared movement assist for R/B/Y and Gold/Silver/Crystal: OFF preserves vanilla walking and surfing, HOLD B applies 2x speed to player-controlled walking or Surf only while B is held, and ALWAYS applies the same 2x speed continuously. Biking, scripted movement, Surf initiation, Waterfall, fishing, menus, and cutscenes remain native.") },
              { key = "unlimited_bag_space", default = false, name = Strings.source("Unlimited Bag Space"), shortName = Strings.source("Unlimited Bag"), desc = Strings.source("QoL for R/B/Y and Gold/Silver/Crystal. ON removes the distinct-item slot limit from R/B/Y's normal Bag and from Gen 2's ordinary ITEM and BALL pockets. Per-item stacks still cap at the engine's native 99, and Gen 2 KEY ITEM/TM-HM pocket limits plus PC item storage remain native. OFF restores the live engine/provider capacity without deleting items already carried.") },
              { key = "trade_evolutions", default = false, name = Strings.source("Trade Evolutions"), shortName = Strings.source("Trade Evos"), desc = Strings.source("QoL for R/B/Y and Gold/Silver/Crystal. ON lets ordinary trade evolutions occur on the next level-up at level 40 or higher. In Gold/Silver/Crystal, trade-with-held-item evolutions also require their original held item and consume it when the evolution succeeds; holding that item preserves branches such as Slowpoke -> Slowking instead of forcing the normal level evolution first. Real link trades still work at their native timing, and Everstone still blocks Gen 2 level-triggered trade evolutions.") },
              { key = "system_clock_sync", default = false, name = Strings.source("System Clock Sync"), shortName = Strings.source("Clock Sync"), gen2Only = true, desc = Strings.source("GEN 2 QoL. While ON, Gold/Silver/Crystal re-anchor the game clock and weekday to the platform local clock when the host minute changes. Turning it OFF stops Nuzlocke re-syncing and leaves the current engine clock offset intact.") },
              { key = "infinite_rare_candies", default = false, rbyOnly = true, capabilityGate = "gym_guide_rare_candy", name = Strings.source("Gym Guide Rare Candy"), shortName = Strings.source("Gym Guide Cndy"), desc = Strings.source("R/B/Y QoL: Gym Guides keep their normal dialogue, then offer repeatable Rare Candies in batches of 1, 10, 25, 50, or 99.") },
          }
      },
      {
          title = Strings.source("QOL SETUP ONLY"), shortTitle = Strings.source("QOL SETUP"),
          rules = {
              { key = "system_date_time", default = false, name = Strings.source("System Date/Time"), shortName = Strings.source("System Date/Time"), gen2Only = true, setupOnly = true, desc = Strings.source("GEN 2 NEW GAME QoL. Initializes Gold/Silver/Crystal time and weekday from the platform local clock, skips the opening manual clock selection, and auto-resolves Mom's initial weekday/DST setup while preserving surrounding story progression." ) },
              { key = "automatic_default_names", default = false, name = Strings.source("Default Names"), shortName = Strings.source("Deflt Names"), setupOnly = true, desc = Strings.source("Skip only the new-game player and Rival naming menus and choose each game's first canonical preset. R/B/Y keep Oak's confirmation dialogue. Gold uses GOLD for the player and later SILVER for the Rival; Silver uses SILVER for the player and later GOLD for the Rival. Pokemon nickname prompts are unaffected. NEW GAME only.") },
              { key = "skip_opening_intro", default = false, name = Strings.source("Skip Opening Intro"), shortName = Strings.source("Skip Oak Intro"), setupOnly = true, desc = Strings.source("NEW GAME only. Skips Oak's opening speech/movie and naming presentation, then continues through the engine's normal fresh-game transition. R/B/Y assign the first canonical player and Rival names and begin at the normal Pallet bedroom start. Gold/Silver/Crystal preserve the required clock setup, assign the edition-appropriate first player-name preset, then begin at the normal Johto fresh-game start; the later Rival naming story remains untouched.") },
              { key = "quick_nuzlocke_start", default = false, name = Strings.source("Quick Nuzlocke Start"), shortName = Strings.source("Quick Start"), setupOnly = true, desc = Strings.source("NEW GAME only. Skips the mandatory pre-capture opening and starts at the first safe hometown checkpoint with a level-5 starter, Pokedex progression, and Poke Balls ready. R/B/Y begin outside in Pallet after Oak's Pokedex transition; bedroom-PC items can still be collected by walking back inside, and the optional Route 22 rival remains available. Gold/Silver preserve clock setup, advance through the Mystery Egg return and first Cherrygrove rival, then begin in New Bark with the Route 29 catch tutorial still available. Random Starter and Nickname remains respected.") },
              { key = "skip_catch_tutorial", default = false, name = Strings.source("Skip Catch Demo"), setupOnly = true, desc = Strings.source("NEW GAME only and version-specific: skips only the catch demonstrations (Viridian Old Man in Red/Blue, Professor Oak in Pallet plus the later Viridian Old Man in Yellow, Dude on Route 29 in Gold/Silver) while preserving surrounding story progression. TEST REQUIRED separately in each game.") },
              { key = "starting_pokeballs", default = 0, name = Strings.source("Starting Poke Balls"), shortName = Strings.source("Start Balls"), rbyOnly = true, setupOnly = true, numeric = true, digits = 2, min = 0, max = 99, desc = Strings.source("R/B/Y NEW GAME QoL: starting Poke Balls. DEFERRED DELIVERY: released only at Oak's Pokedex/capture unlock, unlike immediate PC loadouts, so encounter rules do not arm early.") },
              { key = "starting_rare_candies", default = 0, readTrue = 99, readFalse = 0, name = Strings.source("Starting Rare Candy"), shortName = Strings.source("Start Candy"), rbyOnly = true, setupOnly = true, numeric = true, digits = 2, min = 0, max = 99, desc = Strings.source("R/B/Y NEW GAME QoL: starting Rare Candies placed in the bedroom PC.") },
              { key = "starting_money", default = 3000, name = Strings.source("Starting Money"), shortName = Strings.source("Start ¥"), rbyOnly = true, setupOnly = true, numeric = true, digits = 4, min = 0, max = 9999, desc = Strings.source("R/B/Y NEW GAME QoL: starting money for the new save.") },
              { key = "gold_starting_pokeballs", default = 0, name = Strings.source("Starting Poke Balls"), shortName = Strings.source("Start Balls"), gen2Only = true, setupOnly = true, numeric = true, digits = 2, min = 0, max = 99, desc = Strings.source("GEN 2 NEW GAME QoL: extra starting Poke Balls. DEFERRED DELIVERY: they reach the bedroom PC only after the Mystery Egg is returned to Elm/capture unlock, unlike immediate PC Candy/heal/vitamin loadouts. The native 5-Ball story reward remains untouched.") },
              { key = "gold_starting_rare_candies", default = 0, name = Strings.source("Starting Rare Candy"), shortName = Strings.source("Start Candy"), gen2Only = true, setupOnly = true, numeric = true, digits = 2, min = 0, max = 99, desc = Strings.source("GEN 2 NEW GAME QoL: starting Rare Candies placed in the bedroom PC on the fresh save.") },
              { key = "gold_starting_money", default = 3000, name = Strings.source("Starting Money"), shortName = Strings.source("Start ¥"), gen2Only = true, setupOnly = true, numeric = true, digits = 6, min = 0, max = 999999, desc = Strings.source("GEN 2 NEW GAME QoL: starting money for the fresh Gen 2 save. The range follows the Gen 2 native 0-999999 wallet.") },
              { key = "pc_starting_heal_items", default = false, name = Strings.source("Heal Loadout"), shortName = Strings.source("Heal Loadout"), setupOnly = true, desc = Strings.source("NEW GAME QoL: place 10 each of Potion, Super Potion, Max Potion, Antidote, Burn Heal, Ice Heal, Awakening, Parlyz Heal, and Full Heal in the bedroom PC. The kit is granted once on a fresh save and never bypasses item-use restrictions.") },
              { key = "pc_starting_vitamins", default = false, name = Strings.source("PC Vitamins"), shortName = Strings.source("PC Vtmn"), setupOnly = true, desc = Strings.source("NEW GAME QoL: place 10 of each native vitamin in the bedroom PC. R/B/Y and Gold/Silver receive HP Up, Protein, Iron, Carbos, and Calcium. The grant happens only at fresh-save creation and does not bypass rules that restrict vitamin use.") },
          }
      },
      {
          title = Strings.source("UI"),
          rules = {
              { key = "catch_info", default = true, name = Strings.source("Catch Page"), desc = Strings.source("Include the CATCH page in Nuz Info for owned Pokemon: encounter area/type, provenance, shiny/lost state, and recovery origin. If every Nuz Info page is OFF, the party-menu Nuz Info entry is hidden.") },
              { key = "stat_info", default = true, name = Strings.source("Stat Page"), desc = Strings.source("Include the STAT page in Nuz Info. Shows current battle stats, DVs/IV-style values, and raw Stat EXP for the selected Pokemon. Gold/Silver correctly treat Special DV and Special Stat EXP as shared by Special Attack and Special Defense.") },
              { key = "move_info", default = true, name = Strings.source("Move Page"), desc = Strings.source("Include the MOVE page in Nuz Info. Shows each known move with type, power, accuracy, and current/max PP using the active merged move registry, so compatible move-data mods are reflected automatically.") },
              { key = "area_guide_enabled", default = true, name = Strings.source("Area Guide"), desc = Strings.source("Show the second Encounter Tracker page with all catchable areas. Turn OFF to restrict the tracker to your catches only.") },
              { key = "battle_menu_ui", default = false, nativeEditions = { red=true, blue=true, yellow=true }, name = Strings.source("Battle Menu UI"), shortName = Strings.source("Battle Menu UI"), desc = Strings.source("GEN 1 only. Presentation only. OFF keeps Gen1Recomp's native battle command menu. ON replaces only the ordinary FIGHT / POKEMON / BAG / RUN command presentation with Nuzlocke's centered bottom battle panel while preserving native battle state and actions. Gen II always uses its native battle menu.") },
              { key = "dev_mode", default = false, name = Strings.source("Dev Mode"), shortName = Strings.source("Dev Mode"), desc = Strings.source("Developer diagnostics for runtime validation. OFF has no gameplay effect. ON records a bounded breadcrumb trail for major Nuzlocke lifecycle events, logs compact state snapshots and invariant warnings, and exposes read-only diagnostic helpers through mod.exports.nuzlocke_dev. It never changes challenge legality, catches, battle outcomes, RNG, or save schema. Leave OFF for normal play unless testing or collecting crash context.") },
          }
      },
  }


  ---------------------------------------------------------------------
  -- 2.7.65 RULE AVAILABILITY / DEPENDENCY CONTRACT
  --
  -- These annotations are declarative. UI visibility and effective gameplay
  -- state consume the same metadata so a hidden child cannot remain active.
  -- Stored choices are preserved dormant and return when the prerequisite does.
  ---------------------------------------------------------------------
  local byKey = {}
  for _, category in ipairs(ruleCategories) do
      for _, rule in ipairs(category.rules or {}) do byKey[rule.key] = rule end
  end

  local requiresTrue = {
      random_starter_style="random_starter",
      random_starter_balance="random_starter",
      random_starter_trio_typing="random_starter",
      random_starter_rerolls="random_starter",
      random_field_item_balance="random_field_items",
      random_field_item_repetition="random_field_items",
      random_encounter_balance="random_encounter_tables",
      random_encounter_repetition="random_encounter_tables",
      random_evolution_balance="random_evolutions",
      random_shop_balance="random_shops",
      random_tm_compatibility="random_tms",
      random_trainer_balance="random_trainers",
      random_trainer_diversity="random_trainers",
      random_trainer_theme="random_trainers",
      random_learnset_generation="random_learnsets",
      random_learnset_stab="random_learnsets",
  }
  for child, parent in pairs(requiresTrue) do
      if byKey[child] then byKey[child].requiresRule = { key=parent, op="true" } end
  end
  if byKey.random_encounter_diversity_strength then
      byKey.random_encounter_diversity_strength.requiresAll = {
          { key="random_encounter_tables", op="true" },
          { key="random_encounter_repetition", op="eq", value=1 },
      }
  end
  if byKey.gold_radio_world_building then
      byKey.gold_radio_world_building.requiresRule =
          { key="world_building_tier", op="gt", value=0 }
  end

  -- Encounter-slot modifiers are meaningless when One Per Area is disabled.
  local encounterSlotChildren = {
      "failed_encounter", "dupes_mode",
      "gold_roamer_clause", "gold_egg_encounter_mode", "gold_bug_contest_mode",
      "town_catches", "route_2_split", "route_10_split", "route_20_split",
      "mt_moon_splits", "safari_zone_splits", "gold_time_split",
      "gold_headbutt_split",
  }
  for _, key in ipairs(encounterSlotChildren) do
      if byKey[key] then
          byKey[key].requiresRule = { key="encounter_limit", op="true" }
      end
  end

  -- Type Locke configuration is progressive. Keep dormant lane choices, but
  -- expose/effect only the lanes the selected mode can actually consume.
  if byKey.type_lock_draft then
      byKey.type_lock_draft.requiresRule = { key="type_lock_mode", op="gt", value=0 }
      byKey.colorlocke_color.requiresRule = { key="colorlocke_mode", op="eq", value=2 }
      byKey.alphabetlocke_letter.requiresRule = { key="alphabetlocke_mode", op="eq", value=2 }
  end
  local typeLaneMinimum = {
      type_lock_primary=1, type_lock_secondary=2, type_lock_tertiary=3,
      type_lock_quaternary=4, type_lock_quinary=5, type_lock_senary=6,
  }
  for key, minimum in pairs(typeLaneMinimum) do
      if byKey[key] then
          byKey[key].requiresAll = {
              { key="type_lock_mode", op="gte", value=minimum },
              { key="type_lock_draft", op="false" },
          }
      end
  end
  -- 2.7.68 exact-edition audit: these reviewed surfaces are native in all
  -- five currently supported editions unless a narrower declaration already
  -- exists on the rule itself. Keeping the matrix explicit prevents a later
  -- Gen1/Gen2 implementation shortcut from silently changing UI applicability.
  local nativeAllSix = { red=true, blue=true, yellow=true, gold=true, silver=true, crystal=true }
  local auditedAllSix = {
      -- Battle Mechanics / Clauses
      "physical_special_split", "badge_boosts", "ohko_clause",
      "flinch_clause_scope", "trap_clause_scope", "setup_move_scope",
      "evasion_clause", "status_accuracy_scope", "other_stat_drop_scope",
      -- Battle / Field Items
      "no_healing_items", "no_battle_items", "no_catching",
      "encounter_ball_limit", "no_repels", "no_escape_rope",
      "travel_restrictions", "no_field_healing", "no_pp_items",
      "no_tm_use", "no_rare_candy_use",
      -- Services / Economy
      "no_poke_center", "no_mom_heal", "no_day_care", "shop_restrictions",
      "no_gambling", "trainer_money_multiplier",
      -- World / QOL shared surfaces
      "world_building_tier", "progression_pc_catches", "instant_text",
      "run_surf", "unlimited_bag_space",
      "trade_evolutions", "automatic_default_names", "skip_opening_intro",
      "quick_nuzlocke_start", "skip_catch_tutorial",
      "pc_starting_heal_items", "pc_starting_vitamins",
  }
  for _, key in ipairs(auditedAllSix) do
      if byKey[key] and byKey[key].nativeEditions == nil
          and byKey[key].rbyOnly ~= true
          and byKey[key].gen2Only ~= true
          and byKey[key].goldOnly ~= true then
          byKey[key].nativeEditions = nativeAllSix
      end
  end

  -- ALL-side No Setup Moves already suppresses every positive evasion-stage
  -- boost that Evasion Clause could suppress. SELF/ENEMY remain distinct, so
  -- Evasion Clause stays available for those narrower modes.
  if byKey.evasion_clause then
      byKey.evasion_clause.suppressedBy =
          { key="setup_move_scope", op="eq", value=3 }
  end

  local noCatchingChildren = {
      "encounter_ball_limit", "maximum_bst", "ban_legendaries",
      "ban_mythicals", "ban_pseudos", "allow_glitch_pokemon",
  }
  for _, key in ipairs(noCatchingChildren) do
      if byKey[key] then
          byKey[key].suppressedBy = { key="no_catching", op="true" }
      end
  end
  if byKey.type_lock_draft then
      byKey.type_lock_draft.requiresRule = { key="type_lock_mode", op="gt", value=0 }
      byKey.colorlocke_color.requiresRule = { key="colorlocke_mode", op="eq", value=2 }
      byKey.alphabetlocke_letter.requiresRule = { key="alphabetlocke_mode", op="eq", value=2 }
  end
  local typeSlots = {
      type_lock_primary=1, type_lock_secondary=2, type_lock_tertiary=3,
      type_lock_quaternary=4, type_lock_quinary=5, type_lock_senary=6,
  }
  for key, minimum in pairs(typeSlots) do
      if byKey[key] then
          byKey[key].requiresAll = {
              { key="type_lock_mode", op="gte", value=minimum },
              { key="type_lock_draft", op="false" },
          }
      end
  end

  local statusChildren = {
      "status_paralysis_scope", "status_confusion_scope", "status_sleep_scope",
      "status_poison_scope", "status_burn_scope", "status_freeze_scope",
  }
  for _, key in ipairs(statusChildren) do
      if byKey[key] then
          byKey[key].suppressedBy = { key="status_move_scope", op="gt", value=0 }
      end
  end

  local speciesParents = {
      "random_encounter_tables", "random_trainers", "random_evolutions",
  }
  if byKey.random_species_generation then
      byKey.random_species_generation.requiresAnyTrue = speciesParents
  end
  if byKey.randomizer_info_policy then
      byKey.randomizer_info_policy.requiresAnyTrue = {
          "random_starter", "random_encounter_tables", "random_field_items",
          "random_learnsets", "random_trainers", "random_evolutions",
          "random_shops", "random_tms", "random_tm_locations", "random_gift_items",
      }
  end
  if byKey.randomizer_seed then
      byKey.randomizer_seed.requiresAnyTrue = {
          "random_starter", "random_encounter_tables", "random_field_items",
          "random_learnsets", "random_trainers", "random_evolutions",
          "random_shops", "random_tms", "random_tm_locations", "random_gift_items",
      }
      byKey.randomizer_seed.keepVisiblePreGame = true
  end


  -- 2.9.32: rule-description interaction annotations are presentation/catalog
  -- policy, not gameplay enforcement. Keep them beside the rule definitions.
  -- All mutable/late-bound dependencies are supplied as live getters.
  local function makeDescriptionHelpers(runtimeDeps)
      runtimeDeps = runtimeDeps or {}
      local defaultRuleValue = assert(runtimeDeps.defaultRuleValue, "rule descriptions require defaultRuleValue")
      local getPendingNewGameRules = assert(runtimeDeps.getPendingNewGameRules, "rule descriptions require pending-rules getter")
      local getCurrentGame = assert(runtimeDeps.getCurrentGame, "rule descriptions require current-game getter")
      local externalRuleDelegation = runtimeDeps.externalRuleDelegation
    local ruleMasterGated = {
        permadeath=true, first_rival_forgiveness=true, encounter_limit=true,
        failed_encounter=true, nickname_rule=true,
        dupes_mode=true, shiny_clause=true, status_move_scope=true,
        status_accuracy_scope=true, status_paralysis_scope=true,
        status_confusion_scope=true, status_sleep_scope=true,
        status_poison_scope=true, status_burn_scope=true, status_freeze_scope=true,
        setup_move_scope=true, other_stat_drop_scope=true,
        sleep_clause=true, ohko_clause=true,
        flinch_clause_scope=true, trap_clause_scope=true,
        evasion_clause=true, gold_roamer_clause=true, gold_egg_encounter_mode=true,
        gold_bug_contest_mode=true,
        type_lock_mode=true, type_lock_draft=true, type_lock_primary=true,
        type_lock_secondary=true, type_lock_tertiary=true,
        type_lock_quaternary=true, type_lock_quinary=true, type_lock_senary=true,
        evolution_limit=true,
        overworld_encounters=true, town_catches=true, no_escape=true,
        route_forgiveness=true, ban_legendaries=true, ban_mythicals=true,
        ban_pseudos=true, pkmn_ban=true, no_static_encounters=true, no_fishing=true,
        no_player_stat_exp_gain=true, no_held_items=true, no_gambling=true,
        no_day_care=true, trainer_money_multiplier=true, maximum_bst=true,
        allow_glitch_pokemon=true, allow_gifts=true, allow_trades=true,
        level_cap_scope=true, exp_edging=true,
        no_catching=true, encounter_ball_limit=true, no_healing_items=true,
        no_battle_items=true,
        no_repels=true, no_escape_rope=true, travel_restrictions=true,
        no_field_healing=true, no_pp_items=true, no_tm_use=true,
        no_rare_candy_use=true,
        no_buying=true, no_selling=true, no_poke_center=true, no_mom_heal=true,
        whiteout_clause=true, party_size_limit=true, gym_team_size=true,
        gym_lock_in=true, dungeon_lock_in=true,
    }

    local areaIdentityRules = {
        route_2_split=true, route_10_split=true, route_20_split=true,
        mt_moon_splits=true, safari_zone_splits=true,
        gold_time_split=true, gold_headbutt_split=true,
    }

    local function ruleDescriptionAnnotation(rule, preGame)
        if not (rule and rule.key) then return nil end
        local function value(key)
            if preGame and type(getPendingNewGameRules()) == "table"
                and getPendingNewGameRules()[key] ~= nil then
                return getPendingNewGameRules()[key]
            end
            return mod.save:get(key, defaultRuleValue(key))
        end
        local function on(key) return value(key) == true end
        local function number(key, fallback)
            local n = tonumber(value(key))
            if n == nil then return fallback or 0 end
            return n
        end
        local key = rule.key

        -- WIP/availability is the highest-priority explanation because the row
        -- is intentionally immutable regardless of every other rule value.
        if key == "wonderlocke" then
            return Strings("N/A: Wonderlocke is not currently available.")
        end

        -- Challenge-owned rows stop enforcing when the master switch is OFF.
        -- Independent Randomizer, Game Difficulty, Battle Mechanics, Area Split,
        -- World Building, QoL, UI, and setup-only tuning rows are intentionally
        -- not included in this table.
        if key ~= "nuzlocke_enabled" and ruleMasterGated[key]
            and not on("nuzlocke_enabled") then
            return Strings("N/A: Nuzlocke is OFF, so this challenge rule is inactive.")
        end

        -- Encounter-rule dependencies and absolute-vs-exception relationships.
        if on("no_catching") then
            if key == "encounter_limit" or key == "failed_encounter"
                or key == "dupes_mode" or key == "shiny_clause" then
                return Strings("N/A: No Catching is ON, so this catch-limit rule cannot currently permit or spend a catch.")
            end
            if key == "no_static_encounters" then
                return Strings("REDUNDANT (ordinary catches): No Catching already blocks them. No Static Enc can still matter if an explicitly progression-required PC Catches source is static.")
            end
            if key == "overworld_encounters" or key == "town_catches" then
                return Strings("N/A: No Catching is ON, so this encounter-source setting cannot currently create a legal catch.")
            end
            if key == "progression_pc_catches" then
                return Strings("INTERACTION: No Catching stays absolute for ordinary encounters. PC Catches can still apply only to a source explicitly marked progression-required.")
            end
            if key == "no_fishing" then
                return Strings("INTERACTION: No Catching already prevents capture; No Fishing additionally prevents rod encounters from starting.")
            end
        end

        if key == "failed_encounter" and not on("encounter_limit") then
            return Strings("N/A: One Per Area is OFF, so failed encounters do not consume an area slot.")
        end
        if key == "shiny_clause" and not on("encounter_limit")
            and number("dupes_mode", 0) == 0 then
            return Strings("N/A: One Per Area and Dupes Clause are both OFF, so there is no ordinary catch limit for Shiny Clause to bypass.")
        end
        if key == "gold_roamer_clause" and not on("encounter_limit") then
            return Strings("N/A: One Per Area is OFF, so a separate roamer encounter slot does not restrict catches.")
        end
        if key == "gold_bug_contest_mode" and not on("encounter_limit") then
            return Strings("INTERACTION: One Per Area is OFF. Contest mode can still classify/track the judged catch, but it does not create an additional catch restriction.")
        end
        if key == "gold_egg_encounter_mode" and not on("encounter_limit") then
            return Strings("INTERACTION: One Per Area is OFF. Egg mode still records encounter provenance, but its selected area/slot does not limit another catch.")
        end
        if areaIdentityRules[key] and not on("encounter_limit") then
            return Strings("INTERACTION: One Per Area is OFF. This split still changes encounter identity/tracker grouping, but it does not create extra catch slots.")
        end
        if (key == "overworld_encounters" or key == "town_catches")
            and not on("encounter_limit") then
            return Strings("INTERACTION: One Per Area is OFF. This setting still changes encounter classification/tracking, but it does not spend a catch slot.")
        end

        -- Type Locke lane ownership.
        local slotIndex = ({
            type_lock_primary=1, type_lock_secondary=2, type_lock_tertiary=3,
            type_lock_quaternary=4, type_lock_quinary=5, type_lock_senary=6,
        })[key]
        local typeMode = math.max(0, math.min(6,
            math.floor(number("type_lock_mode", 0))))
        if key == "type_lock_draft" and typeMode <= 0 then
            return Strings("N/A: Type Locke is OFF.")
        end
        if slotIndex then
            if on("type_lock_draft") then
                return Strings("N/A: Catch Draft is ON, so catches draft the active Type Locke lanes instead of this selector.")
            elseif slotIndex > typeMode then
                return Strings("N/A: The selected Type Locke mode does not use this lane.")
            end
        end

        -- Randomizer child controls. Most are normally hidden with their parent,
        -- but keeping the explanation here protects alternate/provider UIs too.
        if (key == "random_encounter_tables" or key == "physical_special_split") then
            local tw = mod.exports.__beta26.findTheWorld and mod.exports.__beta26.findTheWorld()
            if tw then
                if key == "random_encounter_tables" and on("random_encounter_tables") then
                    return Strings("COMPAT: The World 6.54.15 can own regional/weather/WX encounter construction. Nuzlocke randomizes only sources that remain transformable; provider-owned/variant encounters should opt out through the Content API. TEST REQUIRED.")
                elseif key == "physical_special_split" and on("physical_special_split") then
                    return Strings("COMPAT: The World 6.54.15 can add expanded moves, WX forms, weather and regional mechanics. Explicit live/provider move categories outrank Nuzlocke's Gen 1/2 fallback map. TEST REQUIRED.")
                end
            end
        end
        if key == "random_starter" and on("random_starter") then
            local okVp, vp = pcall(mod.find, "vanilla-plus")
            if okVp and type(vp) == "table" then
                return Strings("COMPAT: VanillaPlus 0.3.0 starter-story branches read vanilla EVENT_CHOSE_* flags. Random Starter can make that choice differ from the species actually received; its Charmander route can wait for a Charmander you were not given. TEST REQUIRED.")
            end
        end
        if key == "randomizer_seed"
            and not on("random_starter") and not on("random_encounter_tables")
            and not on("random_field_items") and not on("random_learnsets")
            and not on("random_trainers") and not on("random_evolutions") and not on("random_shops")
            and not on("random_tms") and not on("random_tm_locations")
            and not on("random_gift_items") then
            return Strings("N/A: All seed-driven randomizers are OFF, so the displayed seed is not currently consumed.")
        end
        if (key == "random_starter_style" or key == "random_starter_balance"
            or key == "random_starter_trio_typing" or key == "random_starter_rerolls")
            and not on("random_starter") then
            return Strings("N/A: Random Starter is OFF.")
        end
        if key == "random_evolution_balance" and not on("random_evolutions") then
            return Strings("N/A: Random Evolutions is OFF.")
        end
        if key == "random_shop_balance" and not on("random_shops") then
            return Strings("N/A: Random Shops is OFF.")
        end
        if key == "random_tm_compatibility" and not on("random_tms") then
            return Strings("N/A: Random TMs is OFF.")
        end
        if (key == "random_trainer_balance" or key == "random_trainer_diversity"
            or key == "random_trainer_theme") and not on("random_trainers") then
            return Strings("N/A: Random Trainers is OFF.")
        end
        if (key == "random_encounter_balance" or key == "random_encounter_repetition"
            or key == "random_encounter_diversity_strength")
            and not on("random_encounter_tables") then
            return Strings("N/A: Random Encounters is OFF.")
        end
        if key == "random_species_generation"
            and not on("random_encounter_tables")
            and not on("random_trainers") and not on("random_evolutions") then
            return Strings("N/A: Species-pool randomizers are OFF.")
        end
        if key == "random_encounter_diversity_strength"
            and tonumber(mod.save:get("random_encounter_repetition", 0)) ~= 1 then
            return Strings("N/A: Encounter Repeats is not DIVERSE.")
        end
        if key == "random_field_item_balance"
            and not on("random_field_items") then
            return Strings("N/A: Random Field Items is OFF.")
        end
        if key == "random_field_item_repetition"
            and not on("random_field_items") then
            return Strings("N/A: Random Field Items is OFF.")
        end
        if key == "randomizer_info_policy"
            and not on("random_encounter_tables") and not on("random_starter")
            and not on("random_field_items") and not on("random_learnsets")
            and not on("random_trainers") and not on("random_evolutions") and not on("random_shops")
            and not on("random_tms") and not on("random_tm_locations")
            and not on("random_gift_items") then
            return Strings("N/A: All Randomizer subsystems are OFF.")
        end
        if (key == "random_learnset_generation" or key == "random_learnset_stab") and not on("random_learnsets") then
            return Strings("N/A: Random Learnsets is OFF.")
        end

        -- Progression/resource relationships.
        if key == "route_forgiveness" then
            local canReopen = on("encounter_limit") and not on("no_catching")
            local canRevive = on("permadeath")
            if not canReopen and not canRevive then
                return Strings("N/A: Permadeath cannot create a revival target and current catch rules cannot create a usable failed-area reopen target.")
            end
            if not canReopen then
                return Strings("INTERACTION: F. TOKEN area reopening is currently unavailable, but tokens can still revive eligible fallen Pokemon.")
            end
            if not canRevive then
                return Strings("INTERACTION: Permadeath is OFF, so F. TOKEN revival has no target; failed-area reopening still works.")
            end
        end
        if key == "exp_edging" and number("level_cap_scope", 0) <= 0 then
            return Strings("N/A: Level Cap Scope is NONE, so there is no cap for EXP Edging to bank against.")
        end
        if key == "no_player_stat_exp_gain" and number("player_start_stat_exp", 0) > 0 then
            return Strings("INTERACTION: Starting player Stat EXP still applies. This rule blocks only new Stat EXP gained afterward.")
        end

        -- Item/service restrictions that overlap without being identical.
        if key == "no_healing_items" and on("no_field_healing") then
            return Strings("INTERACTION: No Field Heal is also ON. Together they block healing medicine both in battle and from the field.")
        end
        if key == "no_field_healing" and on("no_healing_items") then
            return Strings("INTERACTION: No Healing Items is also ON. Together they block healing medicine both in battle and from the field.")
        end
        if key == "no_escape_rope" and on("dungeon_lock_in") then
            return Strings("INTERACTION: Dungeon Lock-In already blocks Escape Rope during a supported lock-in. No Escape Rope extends that ban everywhere else.")
        end
        if key == "travel_restrictions" and on("dungeon_lock_in") then
            return Strings("INTERACTION: Dungeon Lock-In independently blocks escape travel while locked; Travel Restrictions also apply outside those dungeons.")
        end
        if key == "dungeon_lock_in"
            and (on("no_escape_rope") or number("travel_restrictions", 0) > 0) then
            return Strings("INTERACTION: Some escape methods are already restricted globally, but Dungeon Lock-In still seals the entry side and its remaining escape seams.")
        end
        if key == "no_gambling"
            and (number("shop_restrictions", 0) == 1
                or number("shop_restrictions", 0) == 3) then
            return Strings("INTERACTION: Shop Restrictions also blocks purchases; No Gambling separately blocks wagering and prize redemption.")
        end
        if key == "party_size_limit" and on("gym_team_size") then
            return Strings("INTERACTION: Gym Team Size also applies at Gym Leaders. The lower applicable party limit controls there.")
        end
        if key == "gym_team_size" and number("party_size_limit", 6) < 6 then
            return Strings("INTERACTION: Party Size Limit also applies. At a Gym Leader, the lower of the configured party cap and the live Leader team size controls.")
        end

        -- QoL sources never bypass challenge item/catch restrictions.
        if (key == "infinite_rare_candies" or key == "starting_rare_candies"
            or key == "gold_starting_rare_candies") and on("no_rare_candy_use") then
            return Strings("INTERACTION: Rare Candies may still be supplied or stored, but No Rare Candy prevents using them while that rule is ON.")
        end
        if key == "pc_starting_heal_items"
            and (on("no_healing_items") or on("no_field_healing")) then
            return Strings("INTERACTION: The heal loadout can still be stored. Active healing-item rules continue to block using those items in their restricted context.")
        end
        if (key == "starting_pokeballs" or key == "gold_starting_pokeballs")
            and on("no_catching") then
            return Strings("INTERACTION: Starting Poke Balls can still be supplied, but No Catching prevents ordinary capture attempts while active.")
        end
        if key == "no_rare_candy_use"
            and (on("infinite_rare_candies") or number("starting_rare_candies", 0) > 0
                or number("gold_starting_rare_candies", 0) > 0) then
            return Strings("INTERACTION: Candy sources may still supply/store Rare Candies; this rule blocks their use.")
        end

        -- World/UI dependencies.
        if key == "gold_radio_world_building"
            and number("world_building_tier", 0) <= 0 then
            return Strings("N/A: World Building is OFF, so Radio Nuzlocke leaves the radio vanilla.")
        end

        return nil
    end

    local function ruleDescriptionForDisplay(rule, preGame)
        local base = tostring(Strings(rule and rule.desc or ""))
        if rule and rule.key == "difficulty_profile" then
            local selectedId = preGame and getPendingNewGameRules()
                and getPendingNewGameRules().difficulty_provider_id
                or mod.save:get("difficulty_provider_id", "vanilla")
            local prefix = {}
            local summaryFn = mod.exports.__beta26
                and mod.exports.__beta26.difficultyProfileSummary
            if type(summaryFn) == "function" then
                local ok, summary = pcall(summaryFn, selectedId)
                if ok and type(summary) == "string" and summary ~= "" then
                    prefix[#prefix + 1] = summary
                end
            end
            local warningFn = mod.exports.__beta26
                and mod.exports.__beta26.difficultyStackWarning
            if type(warningFn) == "function" then
                local ok, warning = pcall(warningFn, selectedId)
                if ok and type(warning) == "string" and warning ~= "" then
                    prefix[#prefix + 1] = warning
                end
            end
            if #prefix > 0 then
                return table.concat(prefix, "\n") .. "\n" .. base
            end
        end
        if rule and rule.key == "no_catching"
            and mod.save:get("no_catching_legacy_ambiguous_29313", false) == true then
            return base .. "\n" .. tostring(Strings(
                "LEGACY SAVE REVIEW: an older partial Ball-ban migration may have enabled this. Confirm the setting you actually want; this beta did not guess and overwrite it."))
        end
        if rule and externalRuleDelegation then
            local delegated = externalRuleDelegation(rule.key, getCurrentGame())
            if delegated then
                local provider = tostring(delegated.name or delegated.id or "EXTERNAL MOD")
                local version = delegated.version and (" " .. tostring(delegated.version)) or ""
                local cap = tostring(delegated.capability or "provider")
                return tostring(Strings(
                    "LOCKED: %s%s owns %s. Your saved Nuzlocke choice is preserved and will return when that provider is disabled or removed.",
                    provider, version, cap)) .. "\n" .. base
            end
        end
        local annotation = ruleDescriptionAnnotation(rule, preGame)
        if annotation and tostring(annotation) ~= "" then
            return tostring(annotation) .. "\n" .. base
        end
        return base
    end
      return { annotation = ruleDescriptionAnnotation, forDisplay = ruleDescriptionForDisplay }
  end



  -- 2.9.34: pure/static UI vocabulary belongs with the authoritative rule/UI
  -- catalog rather than main.lua. These tables contain no runtime state and
  -- are consumed by existing helpers without changing their public contracts.
  local MOVEMENT_ASSIST_LABELS = {
      [0] = Strings.source("OFF"),
      [1] = Strings.source("HOLD B"),
      [2] = Strings.source("ALWAYS"),
  }

  local BATTLE_SCOPE_LABELS = {
      [0] = Strings.source("OFF"), [1] = Strings.source("SELF"),
      [2] = Strings.source("ENEMY"), [3] = Strings.source("ALL"),
  }

  local TRANSLATION_UI_SOURCES = {
      { source="RUN STATUS", kind="ui_status" },
      { source="CAUGHT", kind="ui_status" },
      { source="LOST ENC.", kind="ui_status" },
      { source="DEATHS", kind="ui_status" },
      { source="CAUGHT A.", kind="ui_status" },
      { source="VISITED A.", kind="ui_status" },
      { source="NEXT CAP", kind="ui_status" },
      { source="F. TOKEN", kind="ui_status" },
      { source="AREA", kind="ui_status" },
      { source="SLOT", kind="ui_status" },
      { source="LAST EVENT", kind="ui_status" },
      { source="NONE", kind="ui_common" },
      { source="UNKNOWN", kind="ui_common" },
      { source="OPEN", kind="tracker" },
      { source="FAILED", kind="tracker" },
      { source="DIED", kind="history" },
      { source="ENCOUNTER LOG", kind="tracker" },
      { source="AREA GUIDE", kind="tracker" },
      { source="NO ENTRIES YET", kind="tracker" },
      { source="A: REROLL", kind="ui_footer" },
      { source="LEFT/RIGHT: PAGE", kind="ui_footer" },
      { source="A/LEFT/RIGHT: PAGE", kind="ui_footer" },
      { source="B: BACK", kind="ui_footer" },
      { source="NEXT CAP: MAX", kind="tracker_summary" },
      { source="NEXT CAP: %d", kind="tracker_summary" },
      { source="OPEN %d / CAUGHT %d / FAILED %d", kind="tracker_summary" },
      { source="%d entries", kind="tracker_summary" },
      { source="RNG: %s", kind="tracker_summary" },
      { source="TYPE: %s", kind="tracker_summary" },
      { source="%s\nDEATHS: %d", kind="world_summary" },
      { source="NUZLOCKE OVER\nBADGES: %d\nCAUGHT: %d  DEATHS: %d\nLAST DEATH: %s\n%s",
        kind="world_summary" },

      -- Randomizer active-status and setup/value labels that are authored by
      -- Nuzlocke rather than supplied by the engine's base game catalog.
      { source="RNG Preset %s", kind="randomizer_ui" },
      { source="RNG %08d v%d", kind="randomizer_ui" },
      { source="Starter %s", kind="randomizer_ui" },
      { source="Starter BALANCED", kind="randomizer_ui" },
      { source="Starter INDEPENDENT", kind="randomizer_ui" },
      { source="Trio AUTO", kind="randomizer_ui" },
      { source="Trio OFF", kind="randomizer_ui" },
      { source="Items %s", kind="randomizer_ui" },
      { source="ItemRep %s", kind="randomizer_ui" },
      { source="Enc %s", kind="randomizer_ui" },
      { source="Repeats %s", kind="randomizer_ui" },
      { source="Diversity %s", kind="randomizer_ui" },
      { source="Evos %s", kind="randomizer_ui" },
      { source="Shops %s", kind="randomizer_ui" },
      { source="TM Compat %s", kind="randomizer_ui" },
      { source="Trainers %s", kind="randomizer_ui" },
      { source="Theme %s", kind="randomizer_ui" },
      { source="RNG BLIND", kind="randomizer_ui" },
      { source="RNG OPEN", kind="randomizer_ui" },
      { source="CUSTOM", kind="randomizer_value" },
      { source="CHAOS", kind="randomizer_value" },
      { source="BALANCED", kind="randomizer_value" },
      { source="ANY", kind="randomizer_value" },
      { source="3-STAGE", kind="randomizer_value" },
      { source="BASE", kind="randomizer_value" },
      { source="SIM BST", kind="randomizer_value" },
      { source="INDEPENDENT", kind="randomizer_value" },
      { source="AUTO", kind="randomizer_value" },
      { source="OFF", kind="randomizer_value" },
      { source="CATEGORY", kind="randomizer_value" },
      { source="ALLOW", kind="randomizer_value" },
      { source="DIVERSE", kind="randomizer_value" },
      { source="UNIQUE", kind="randomizer_value" },
      { source="EVO", kind="randomizer_value" },
      { source="LIGHT", kind="randomizer_value" },
      { source="STANDARD", kind="randomizer_value" },
      { source="STRONG", kind="randomizer_value" },
      { source="DEPTH", kind="randomizer_value" },
      { source="PRICE", kind="randomizer_value" },
      { source="MOVE", kind="randomizer_value" },
      { source="SLOT", kind="randomizer_value" },
      { source="FULL", kind="randomizer_value" },
      { source="TYPE", kind="randomizer_value" },
      { source="OPEN INFO", kind="randomizer_value" },
      { source="BLIND INFO", kind="randomizer_value" },
      { source="GEN1", kind="randomizer_value" },
      { source="GEN2", kind="randomizer_value" },
      { source="BOTH", kind="randomizer_value" },
      { source="PREFER", kind="randomizer_value" },

      -- Dynamic rejection details authored in world_building.lua.
      { source="%s\nAllowed: %s", kind="world_building_dynamic" },
      { source="%s\nBST: %s / Limit: %s", kind="world_building_dynamic" },
      { source="That catch is not allowed by your Nuzlocke rules.",
        kind="world_building_dynamic" },

      -- Forgiveness/F. TOKEN player-facing surfaces. These already resolve
      -- through Strings() in forgiveness.lua; source discovery lets language
      -- packs cover the complete flow without parsing implementation code.
      { source="INFO", kind="forgiveness_ui" },
      { source="REVIVE", kind="forgiveness_ui" },
      { source="REROLL AREA", kind="forgiveness_ui" },
      { source="REVIVE POKEMON", kind="forgiveness_ui" },
      { source="REROLL ENCOUNTER", kind="forgiveness_ui" },
      { source="REVIVE WHO?", kind="forgiveness_ui" },
      { source="Choose how to", kind="forgiveness_ui" },
      { source="Choose how to spend it.", kind="forgiveness_ui" },
      { source="TOKENS %d", kind="forgiveness_ui" },
      { source="A:SELECT B:BACK", kind="forgiveness_ui" },
      { source="A:OK B:CANCEL", kind="forgiveness_ui" },
      { source="MOVE:CHOOSE", kind="forgiveness_ui" },
      { source="MOVE:CHOOSE A:OK", kind="forgiveness_ui" },
      { source="You have no F. TOKEN.", kind="forgiveness_message" },
      { source="The save is unavailable.", kind="forgiveness_message" },
      { source="No PC storage is available.", kind="forgiveness_message" },
      { source="No reroll area is selected.", kind="forgiveness_message" },
      { source="Route Forgiveness is not active.", kind="forgiveness_message" },
      { source="F. TOKEN transaction unavailable.", kind="forgiveness_message" },
      { source="The PC is full. No token was spent.", kind="forgiveness_message" },
      { source="F. TOKEN state changed during recovery.", kind="forgiveness_message" },
      { source="That fallen Pokemon cannot be restored.", kind="forgiveness_message" },
      { source="No fallen Pokemon are available to revive.", kind="forgiveness_message" },
      { source="The F. TOKEN could not be committed safely.",
        kind="forgiveness_message" },
      { source="There is no encounter slot to reroll there.",
        kind="forgiveness_message" },
      { source="No failed encounter areas are available to reroll.",
        kind="forgiveness_message" },
      { source="This area's catch is already complete.", kind="forgiveness_message" },
      { source="This area's encounter is already open.", kind="forgiveness_message" },
      { source="F. TOKEN used.\n%s was revived!", kind="forgiveness_message" },
      { source="F. TOKEN used.\n%s is open again.", kind="forgiveness_message" },
      { source="F. TOKEN could not be used safely: %s", kind="forgiveness_message" },
      { source="Are you sure? This will spend your F. TOKEN on %s.",
        kind="forgiveness_message" },

      -- Battle Clause authored denials. Policy remains keyed by semantic rule
      -- identifiers; only the player-facing explanation is translated.
      { source="OHKO Clause blocked the move.", kind="battle_clause_message" },
      { source="Sleep Clause blocked the move.", kind="battle_clause_message" },
      { source="Evasion Clause blocked the boost.", kind="battle_clause_message" },
      { source="Flinch Clause blocked the effect.", kind="battle_clause_message" },
      { source="Trap Clause blocked the trapping effect.", kind="battle_clause_message" },
      { source="No Setup Moves blocked the boost.", kind="battle_clause_message" },
      { source="Accuracy Drops blocked the drop.", kind="battle_clause_message" },
      { source="Other Stat Drops blocked the drop.", kind="battle_clause_message" },
      { source="Sleep ban blocked the effect.", kind="battle_clause_message" },
      { source="Freeze ban blocked the effect.", kind="battle_clause_message" },
      { source="Paralysis ban blocked the effect.", kind="battle_clause_message" },
      { source="Burn ban blocked the effect.", kind="battle_clause_message" },
      { source="Poison ban blocked the effect.", kind="battle_clause_message" },
      { source="Confusion ban blocked the effect.", kind="battle_clause_message" },

      -- Common Nuzlocke-authored runtime/status labels still outside the first
      -- status catalog batches.
      { source="NUZ INFO", kind="ui_common" },
      { source="NUZ MENU", kind="ui_common" },
      { source="NUZLOCKE STATUS", kind="ui_status" },
      { source="NO RULES ACTIVE", kind="ui_status" },
      { source="No rules active", kind="ui_status" },
      { source="LAST CAUGHT", kind="ui_status" },
      { source="MOD COMPAT", kind="compat_ui" },
      { source="PROVIDER", kind="compat_ui" },
      { source="EXTERNAL", kind="compat_ui" },
      { source="LEGALITY", kind="compat_ui" },
      { source="RECOVERY", kind="compat_ui" },
      { source="RULES SEALED", kind="ui_status" },
      { source="Rules are LOCKED.", kind="ui_status" },
      { source="Buying is disabled.", kind="runtime_message" },
      { source="Selling is disabled.", kind="runtime_message" },
      { source="Item use is blocked!", kind="runtime_message" },
      { source="Held items are banned by your Nuzlocke rules.",
        kind="runtime_message" },
      { source="The level cap blocks that RARE CANDY.", kind="runtime_message" },
      { source="Rare Candy batch stopped safely.", kind="runtime_message" },

      -- Pokegear Cards integration authored labels. The adapter uses its
      -- injected translate callback and glyph-safe cell fitting.
      { source="NUZ %d/4", kind="pokegear_ui" },
      { source="RUN ACTIVE", kind="pokegear_ui" },
      { source="RUN OFF", kind="pokegear_ui" },
      { source="CAUGHT %d", kind="pokegear_ui" },
      { source="DEATHS %d", kind="pokegear_ui" },
      { source="TOKENS %d", kind="pokegear_ui" },
      { source="LOAD %s", kind="pokegear_ui" },
      { source="ENCOUNTERS", kind="pokegear_ui" },
      { source="CAUGHT A %d", kind="pokegear_ui" },
      { source="VISITED %d", kind="pokegear_ui" },
      { source="LOST %d", kind="pokegear_ui" },
      { source="TOTAL C %d", kind="pokegear_ui" },
      { source="RULES %d/%d", kind="pokegear_ui" },
      { source="NEXT CAP %d", kind="pokegear_ui" },
      { source="CAPS & DIFF", kind="pokegear_ui" },
      { source="BOSS %s", kind="pokegear_ui" },
      { source="DIFF %s", kind="pokegear_ui" },
      { source="A:MORE U/D:PG B:X", kind="pokegear_ui" },
      { source="UP/DN PAGE B:BACK", kind="pokegear_ui" },

      -- Gen-II compact status templates.
      { source="CAUGHT %d   LOST %d", kind="gen2_status" },
      { source="DEATHS %d   TOKENS %d", kind="gen2_status" },
      { source="CAP MAX", kind="gen2_status" },
      { source="CAP LV%d", kind="gen2_status" },

      -- Dev localization certification surface.
      { source="LOCAL CERT", kind="localization_cert_ui" },
      { source="SESSION ONLY / MANUAL", kind="localization_cert_ui" },
      { source="SETUP / NUZ RULES", kind="localization_cert_check" },
      { source="NUZ STATUS / ENC TRACKER", kind="localization_cert_check" },
      { source="BATTLE DENIAL", kind="localization_cert_check" },
      { source="MART BUY / SELL", kind="localization_cert_check" },
      { source="PARTY / NUZ INFO", kind="localization_cert_check" },
      { source="MOVE LEARN / RARE CANDY", kind="localization_cert_check" },
      { source="F. TOKEN / FORGIVENESS", kind="localization_cert_check" },
      { source="RANDOMIZER LABELS", kind="localization_cert_check" },
      { source="WORLD BUILDING TEXT", kind="localization_cert_check" },
      { source="DEV REPORT / LOCALIZATION", kind="localization_cert_check" },
      { source="A:MARK  U/D:CHECK", kind="localization_cert_ui" },
      { source="L/R:SECTION  B:BACK", kind="localization_cert_ui" },
  }


  -- 2.9.34: catalog-owned pure metadata indexing. Keeping collision/default-type
  -- normalization beside the authoritative rows prevents main.lua from
  -- maintaining a second handwritten traversal of the same static catalog.
  local function buildDefinitionIndex()
      local byKey, collisions = {}, {}
      for _, category in ipairs(ruleCategories or {}) do
          for _, rule in ipairs(category.rules or {}) do
              if type(rule) == "table" and type(rule.key) == "string"
                  and rule.key ~= "" then
                  if byKey[rule.key] then
                      collisions[#collisions + 1] = rule.key
                  else
                      if rule.value_type == nil then
                          rule.value_type = rule.numeric == true and "number"
                              or type(rule.default)
                      end
                      if rule.value_type == "nil" then rule.value_type = "boolean" end
                      byKey[rule.key] = rule
                  end
              end
          end
      end
      return byKey, collisions
  end

  -- 2.9.35: pure rule/value vocabulary helpers consolidated beside the
  -- authoritative rule catalog. These functions have no save/game lifecycle
  -- dependencies and preserve the existing __beta26 call surfaces.
  local STATUS_MOVE_CHILD_KEYS = {
      "status_paralysis_scope", "status_confusion_scope",
      "status_sleep_scope", "status_poison_scope",
      "status_burn_scope", "status_freeze_scope",
  }

  local BATTLE_SCOPE_RULE_KEYS = {
      status_move_scope = true, setup_move_scope = true,
      status_accuracy_scope = true, other_stat_drop_scope = true,
      status_paralysis_scope = true, status_confusion_scope = true,
      status_sleep_scope = true, status_poison_scope = true,
      status_burn_scope = true, status_freeze_scope = true,
      flinch_clause_scope = true, trap_clause_scope = true,
  }

  local function finiteNumber(value, fallback)
      local number = tonumber(value)
      if number == nil or number ~= number
          or number == math.huge or number == -math.huge then
          return fallback
      end
      return number
  end

  local function normalizeMovementAssistMode(value)
      if type(value) == "boolean" then return value and 1 or 0 end
      return math.max(0, math.min(2, math.floor(tonumber(value) or 0)))
  end

  local function cycleIntegerRange(value, minValue, maxValue, step)
      minValue = math.floor(tonumber(minValue) or 0)
      maxValue = math.floor(tonumber(maxValue) or minValue)
      if maxValue < minValue then minValue, maxValue = maxValue, minValue end
      local count = maxValue - minValue + 1
      if count <= 0 then return minValue end
      local current = math.floor(tonumber(value) or minValue)
      current = math.max(minValue, math.min(maxValue, current))
      local offset = (current - minValue + math.floor(tonumber(step) or 1)) % count
      return minValue + offset
  end

  local function scalePercentFloor(amount, percent)
      local base = finiteNumber(amount, 0) or 0
      local pct = finiteNumber(percent, 0) or 0
      return math.floor(math.max(0, base) * math.max(0, pct) / 100)
  end

  local function normalizeItemPolicyKey(item)
      local value = type(item) == "table"
          and (item.id or item.key or item.value or item.name) or item
      return tostring(value or ""):upper():gsub("[%s%-]+", "_")
  end

  local function battleScopeLabel(value)
      value = math.max(0, math.min(3, math.floor(tonumber(value) or 0)))
      return BATTLE_SCOPE_LABELS[value] or BATTLE_SCOPE_LABELS[0]
  end

  local function statusMoveChildKeys()
      local out = {}
      for i, key in ipairs(STATUS_MOVE_CHILD_KEYS) do out[i] = key end
      return out
  end

  local function isStatusMoveChildKey(key)
      key = tostring(key or "")
      for _, childKey in ipairs(STATUS_MOVE_CHILD_KEYS) do
          if key == childKey then return true end
      end
      return false
  end

  local function isBattleScopeRuleKey(key)
      return BATTLE_SCOPE_RULE_KEYS[tostring(key or "")] == true
  end

  -- 2.9.41: ordinary rule-value coercion is pure catalog behavior. The caller
  -- supplies the live authoritative definition index so this helper never
  -- captures a stale snapshot across setup/profile or module initialization.
  local function coerceRuleValue(definitionByKey, key, value, mode)
      local rule = type(definitionByKey) == "table"
          and definitionByKey[tostring(key or "")] or nil
      if not rule then return value == true end
      if rule.value_type ~= "number" and rule.numeric ~= true then
          return value == true
      end
      mode = mode == "write" and "write" or "read"
      if type(value) == "boolean" then
          local mapped = value and rule[mode .. "True"] or rule[mode .. "False"]
          if mapped ~= nil then value = mapped end
      end
      local fallback = rule[mode .. "Fallback"]
      if fallback == nil then fallback = rule.min end
      if fallback == nil then fallback = rule.default end
      local number = math.floor(tonumber(value) or tonumber(fallback) or 0)
      if rule.min ~= nil then
          number = math.max(tonumber(rule.min) or number, number)
      end
      if rule.max ~= nil then
          number = math.min(tonumber(rule.max) or number, number)
      end
      return number
  end


  -- 2.9.42: pure machine-readable descriptor construction lives beside the
  -- authoritative rule catalog. Callers provide live/default-resolver inputs;
  -- this layer never reads mod.save or captures transaction/runtime owners.
  local function copyDescriptorValue(value)
      if type(value) ~= "table" then return value end
      local out = {}
      for key, item in pairs(value) do
          out[key] = copyDescriptorValue(item)
      end
      return out
  end

  local function buildRuleDescriptorSnapshot(categories, defaultResolver, profileMeta)
      categories = categories or ruleCategories or {}
      defaultResolver = type(defaultResolver) == "function"
          and defaultResolver or function() return nil end
      local rows, byKey, collisions = {}, {}, {}
      local function addDescriptor(rule, category, source)
          if type(rule) ~= "table" or type(rule.key) ~= "string"
              or rule.key == "" then return end
          if byKey[rule.key] then
              collisions[#collisions + 1] = {
                  key = rule.key,
                  first_source = byKey[rule.key].source,
                  duplicate_source = tostring(source or "ruleCategories"),
              }
              return
          end
          local default = rule.default
          if default == nil then default = defaultResolver(rule.key) end
          local valueType = rule.value_type
              or (rule.numeric == true and "number" or type(default))
          if valueType == "nil" then valueType = "boolean" end
          local generation = "both"
          local gen2Only = rule.gen2Only == true or rule.goldOnly == true
          if gen2Only then generation = "gen2"
          elseif rule.rbyOnly == true then generation = "rby" end
          local row = {
              key = rule.key,
              category = tostring(category or "SYSTEM"),
              value_type = valueType,
              default = default,
              generation = generation,
              gen2_only = gen2Only,
              legacy_generation = gen2Only and "gold" or nil,
              persisted = rule.persisted ~= false,
              setup_only = rule.setupOnly == true,
              numeric = rule.numeric == true,
              min = rule.min,
              max = rule.max,
              allowed_values = copyDescriptorValue(rule.allowedValues or rule.allowed_values),
              read_fallback = rule.readFallback,
              write_fallback = rule.writeFallback,
              legacy_read_true = rule.readTrue,
              legacy_read_false = rule.readFalse,
              legacy_write_true = rule.writeTrue,
              legacy_write_false = rule.writeFalse,
              pregame_read_coerce = rule.preGameReadCoerce == true,
              source = tostring(source or "ruleCategories"),
          }
          rows[#rows + 1] = row
          byKey[row.key] = row
      end

      for _, category in ipairs(categories) do
          for _, rule in ipairs(category.rules or {}) do
              addDescriptor(rule, category.title, "ruleCategories")
          end
      end
      for _, meta in ipairs(profileMeta or {}) do
          addDescriptor(meta, "SYSTEM", "profile_metadata")
      end
      table.sort(rows, function(a, b) return a.key < b.key end)
      return rows, byKey, collisions
  end

  -- 2.9.43: pure read-only registry presentation/structural auditing over an
  -- already-built descriptor snapshot. This layer never reads mod.save and does
  -- not own enum coercion, schema lifecycle, or persisted-value validation.
  local function buildRuleRegistry(rows, byKey, collisions)
      rows = rows or {}
      byKey = byKey or {}
      collisions = collisions or {}
      local registry = { version = 1, count = #rows }
      function registry.describe()
          return {
              api = 1,
              count = #rows,
              collision_count = #collisions,
              collisions = copyDescriptorValue(collisions),
              rows = copyDescriptorValue(rows),
          }
      end
      function registry.get(key)
          local row = byKey[tostring(key or "")]
          return row and copyDescriptorValue(row) or nil
      end
      function registry.audit()
          local errors = {}
          for _, collision in ipairs(collisions) do
              errors[#errors + 1] = "duplicate:" .. tostring(collision.key)
          end
          local seen = {}
          for _, row in ipairs(rows) do
              if seen[row.key] then
                  errors[#errors + 1] = "duplicate:" .. row.key
              end
              seen[row.key] = true
              if row.value_type == "number" and type(row.default) ~= "number" then
                  errors[#errors + 1] = "default_type:" .. row.key
              elseif row.value_type == "boolean"
                  and type(row.default) ~= "boolean" then
                  errors[#errors + 1] = "default_type:" .. row.key
              elseif row.value_type == "string"
                  and type(row.default) ~= "string" then
                  errors[#errors + 1] = "default_type:" .. row.key
              end
          end
          return { ok = #errors == 0, count = #rows, errors = errors }
      end
      return registry
  end

  local function buildSaveSchemaFields(rows, spec)
      spec = spec or {}
      local fields = {}
      local function addSystem(key, valueType, required, role, source)
          if type(key) ~= "string" or key == "" then return end
          fields[key] = {
              key = key, value_type = valueType, required = required == true,
              role = role, source = source,
          }
      end
      addSystem(spec.schema_key, "number", true, "schema_version")
      if fields[spec.schema_key] then fields[spec.schema_key].default = spec.current_schema end
      addSystem(spec.migration_key, "string", false, "migration_checkpoint")
      addSystem(spec.schema_transaction_key, "table", false,
          "migration_transaction", "schema_transaction_v1")
      addSystem(spec.gameplay_transaction_key, "table", false,
          "gameplay_transaction", "gameplay_transaction_v1")
      addSystem(spec.transaction_receipts_key, "table", false,
          "transaction_receipts", "gameplay_transaction_v1")

      for _, row in ipairs(rows or {}) do
          fields[row.key] = {
              key = row.key, value_type = row.value_type, default = row.default,
              required = false, role = "configuration",
              generation = row.generation, source = row.source,
          }
      end
      fields.hardcore_mode = {
          key = "hardcore_mode", value_type = "boolean", default = false,
          required = false, role = "compatibility_mirror",
          canonical = "level_cap_scope", source = "level_cap_scope_mirror",
      }
      fields.elite_four_caps = {
          key = "elite_four_caps", value_type = "boolean", default = false,
          required = false, role = "compatibility_mirror",
          canonical = "level_cap_scope", source = "level_cap_scope_mirror",
      }
      for key, row in pairs({
          solo_active = { value_type = "boolean", canonical = "party_size_limit" },
          no_shopping = { value_type = "boolean", canonical = "no_buying/no_selling" },
          ball_use_ban_tier = { value_type = "number", canonical = "no_catching", migration = "retired_ball_ban_no_catching" },
          route_splits = { value_type = "number", canonical = "route_2_split/route_10_split/route_20_split", migration = "legacy_route_split_selectors" },
      }) do
          fields[key] = {
              key = key, value_type = row.value_type, required = false,
              role = "legacy_migration_input", canonical = row.canonical,
              migration = row.migration, source = "schema_migration",
          }
      end
      for key, row in pairs({
          nuzlocke_rule_revision = { value_type = "number", source = "rule_edit_revision" },
          no_catching_migrated_2934 = { value_type = "boolean", source = "retired_ball_ban_no_catching" },
          no_catching_migration_reviewed_29313 = { value_type = "boolean", source = "retired_ball_ban_review" },
          route_split_rules_migrated = { value_type = "boolean", source = "legacy_route_split_selectors" },
          route_forgiveness_initialized = { value_type = "boolean", source = "route_forgiveness_initialization" },
          nuzlocke_provenance_initialized = { value_type = "boolean", source = "pokemon_provenance_reconstruction" },
          whiteout_semantics_restored_2531 = { value_type = "boolean", source = "whiteout_semantics_restored_2531" },
          movement_assist_modes_2533 = { value_type = "boolean", source = "movement_assist_modes_2533" },
      }) do
          fields[key] = {
              key = key, value_type = row.value_type, required = false,
              role = "migration_bookkeeping", source = row.source,
          }
      end
      return fields
  end


  -- 2.9.44: pure read-only save-schema descriptor presentation and structural
  -- auditing over an already-built field snapshot. The caller supplies the
  -- current schema value; this layer never reads mod.save, owns migrations, or
  -- resolves transaction/storage keys.
  local function buildSaveSchemaDescriptor(fields, rows, currentSchema)
      fields = fields or {}
      rows = rows or {}
      currentSchema = math.floor(tonumber(currentSchema) or 0)
      local descriptor = {
          version = currentSchema,
          descriptor_api = 1,
          coverage = "configuration_and_schema_control",
          complete_gameplay_state = false,
      }
      function descriptor.describe()
          return {
              descriptor_api = descriptor.descriptor_api,
              save_schema = currentSchema,
              coverage = descriptor.coverage,
              complete_gameplay_state = false,
              fields = copyDescriptorValue(fields),
          }
      end
      function descriptor.audit()
          local errors = {}
          local configCount, mirrorCount, legacyCount, bookkeepingCount = 0, 0, 0, 0
          local migrationTransactionCount, gameplayTransactionCount, receiptCount = 0, 0, 0
          for key, field in pairs(fields) do
              if field.role == "configuration" then configCount = configCount + 1
              elseif field.role == "compatibility_mirror" then mirrorCount = mirrorCount + 1
              elseif field.role == "legacy_migration_input" then legacyCount = legacyCount + 1
              elseif field.role == "migration_bookkeeping" then bookkeepingCount = bookkeepingCount + 1
              elseif field.role == "migration_transaction" then
                  migrationTransactionCount = migrationTransactionCount + 1
              elseif field.role == "gameplay_transaction" then
                  gameplayTransactionCount = gameplayTransactionCount + 1
              elseif field.role == "transaction_receipts" then
                  receiptCount = receiptCount + 1
              end
              local default = field.default
              if default ~= nil and field.value_type == "number"
                  and type(default) ~= "number" then
                  errors[#errors + 1] = "default_type:" .. tostring(key)
              elseif default ~= nil and field.value_type == "boolean"
                  and type(default) ~= "boolean" then
                  errors[#errors + 1] = "default_type:" .. tostring(key)
              elseif default ~= nil and field.value_type == "string"
                  and type(default) ~= "string" then
                  errors[#errors + 1] = "default_type:" .. tostring(key)
              elseif default ~= nil and field.value_type == "table"
                  and type(default) ~= "table" then
                  errors[#errors + 1] = "default_type:" .. tostring(key)
              end
          end
          for _, row in ipairs(rows) do
              if not fields[row.key] then
                  errors[#errors + 1] = "missing_field:" .. row.key
              end
          end
          return {
              ok = #errors == 0,
              save_schema = currentSchema,
              total_field_count = configCount + mirrorCount + legacyCount + bookkeepingCount
                  + migrationTransactionCount + gameplayTransactionCount + receiptCount + 2,
              configuration_count = configCount,
              compatibility_mirror_count = mirrorCount,
              legacy_input_count = legacyCount,
              migration_bookkeeping_count = bookkeepingCount,
              migration_transaction_count = migrationTransactionCount,
              gameplay_transaction_count = gameplayTransactionCount,
              transaction_receipt_count = receiptCount,
              errors = errors,
          }
      end
      return descriptor
  end


  -- 2.9.45: pure/static configuration ownership moved from main.lua.
  -- These helpers never read mod.save or runtime game state.
  local function normalizePkmnBanSet(value, maxDex)
      local out = {}
      maxDex = math.max(1, math.min(251, math.floor(tonumber(maxDex) or 251)))
      if type(value) ~= "table" then return out end
      for key, enabled in pairs(value) do
          if enabled == true then
              local index = math.floor(tonumber(key) or 0)
              if index >= 1 and index <= maxDex then out[tostring(index)] = true end
          end
      end
      return out
  end

  local function pkmnBanCountFromSet(value, maxDex)
      local count = 0
      for _, enabled in pairs(normalizePkmnBanSet(value, maxDex)) do
          if enabled == true then count = count + 1 end
      end
      return count
  end

  local function pkmnBanSetsEqual(a, b)
      a, b = normalizePkmnBanSet(a), normalizePkmnBanSet(b)
      for key in pairs(a) do if b[key] ~= true then return false end end
      for key in pairs(b) do if a[key] ~= true then return false end end
      return true
  end

  local function boundedStartingResource(value, fallback, maximum)
      local n = tonumber(value)
      if n == nil or n ~= n or n == math.huge or n == -math.huge then n = fallback end
      return math.max(0, math.min(maximum, math.floor(n)))
  end

  local function resolveNewGameStartingResources(profile)
      profile = type(profile) == "table" and profile or {}
      local candies
      if type(profile.starting_rare_candies) == "boolean" then
          candies = profile.starting_rare_candies and 99 or 0
      else
          candies = boundedStartingResource(profile.starting_rare_candies, 0, 99)
      end
      return {
          money = boundedStartingResource(profile.starting_money, 3000, 9999),
          balls = boundedStartingResource(profile.starting_pokeballs, 0, 99),
          candies = candies,
      }
  end

  local function resolveGoldNewGameStartingResources(profile)
      profile = type(profile) == "table" and profile or {}
      return {
          money = boundedStartingResource(profile.gold_starting_money, 3000, 999999),
          balls = boundedStartingResource(profile.gold_starting_pokeballs, 0, 99),
          candies = boundedStartingResource(profile.gold_starting_rare_candies, 0, 99),
      }
  end

  local function auditGoldStartingResourceProfiles()
      local cases = {
          { {}, 3000, 0, 0 }, { { gold_starting_money = 0 }, 0, 0, 0 },
          { { gold_starting_money = 3000, gold_starting_pokeballs = 5, gold_starting_rare_candies = 10 }, 3000, 5, 10 },
          { { gold_starting_money = "bad", gold_starting_pokeballs = -4, gold_starting_rare_candies = 999 }, 3000, 0, 99 },
          { { gold_starting_money = 9999999, gold_starting_pokeballs = 999 }, 999999, 99, 0 },
      }
      for _, row in ipairs(cases) do
          local got = resolveGoldNewGameStartingResources(row[1])
          if got.money ~= row[2] or got.balls ~= row[3] or got.candies ~= row[4] then return false, row end
      end
      return true
  end

  local function auditStartingResourceProfiles()
      local cases = {
          { {}, 3000, 0, 0 }, { { starting_money = 0 }, 0, 0, 0 },
          { { starting_money = 3000, starting_pokeballs = 5, starting_rare_candies = 10 }, 3000, 5, 10 },
          { { starting_money = "bad", starting_pokeballs = -4, starting_rare_candies = 999 }, 3000, 0, 99 },
          { { starting_money = 999999, starting_pokeballs = 999 }, 9999, 99, 0 },
      }
      for _, row in ipairs(cases) do
          local got = resolveNewGameStartingResources(row[1])
          if got.money ~= row[2] or got.balls ~= row[3] or got.candies ~= row[4] then return false, row end
      end
      return true
  end

  local function buildLockePreset()
      return {
      -- Saved numeric IDs 1-5 are preserved for compatibility. RECOMMENDED is
      -- additive as ID 6; cycleOrder controls presentation without renumbering
      -- historical loadouts.
      labels = {
          [0] = Strings.source("CUSTOM"),
          [1] = Strings.source("NUZ"),
          [2] = Strings.source("HARD"),
          [3] = Strings.source("SOLO"),
          [4] = Strings.source("IRON"),
          [5] = Strings.source("VANILLA"),
          [6] = Strings.source("REC"),
      },
      names = {
          [0] = Strings.source("CUSTOM"),
          [1] = Strings.source("NUZLOCKE"),
          [2] = Strings.source("HARDCORE"),
          [3] = Strings.source("SOLO"),
          [4] = Strings.source("IRONMON"),
          [5] = Strings.source("VANILLA"),
          [6] = Strings.source("RECOMMENDED"),
      },
      cycleOrder = { 0, 5, 6, 1, 2, 3, 4 },
      -- Only these rules are owned by Nuzlocke Loadouts. Optional clauses,
      -- encounter variants, Type Locke, BST limits, Badge Boosts, Randomizer,
      -- Difficulty, World Building, QoL, UI and area splits remain independent.
      managed = {
          nuzlocke_enabled = true,
          permadeath = true,
          first_rival_forgiveness = true,
          encounter_limit = true,
          failed_encounter = true,
          nickname_rule = true,
          level_cap_scope = true,
          no_healing_items = true,
          no_battle_items = true,
          no_escape = true,
          no_repels = true,
          no_escape_rope = true,
          no_field_healing = true,
          no_pp_items = true,
          no_tm_use = true,
          no_rare_candy_use = true,
          no_buying = true,
          no_selling = true,
          no_poke_center = true,
          no_mom_heal = true,
          whiteout_clause = true,
          party_size_limit = true,
          gym_team_size = true,
      },
      presets = {
          -- Exact neutral values for every loadout-owned challenge rule. This
          -- intentionally does NOT reset independent mod features such as QoL,
          -- Difficulty or Randomizer; VANILLA here means vanilla challenge rules.
          [5] = {
              nuzlocke_enabled = false,
              permadeath = false,
              first_rival_forgiveness = false,
              encounter_limit = false,
              failed_encounter = false,
              nickname_rule = false,
              level_cap_scope = 0,
              no_healing_items = false,
              no_battle_items = false,
              no_escape = false,
              no_repels = false,
              no_escape_rope = false,
              no_field_healing = false,
              no_pp_items = false,
              no_tm_use = false,
              no_rare_candy_use = false,
              no_buying = false,
              no_selling = false,
              no_poke_center = false,
              no_mom_heal = false,
              whiteout_clause = false,
              party_size_limit = 6,
              gym_team_size = false,
          },
          [6] = {
              -- Recommended keeps the classic Nuzlocke core while adding
              -- Gym-level caps as a gentle guardrail. Battle-item, healing,
              -- field-item, shop and service restrictions remain optional.
              nuzlocke_enabled = true,
              permadeath = true,
              first_rival_forgiveness = true,
              encounter_limit = true,
              failed_encounter = true,
              nickname_rule = true,
              level_cap_scope = 1,
              no_healing_items = false,
              no_battle_items = false,
              no_escape = false,
              no_repels = false,
              no_escape_rope = false,
              no_field_healing = false,
              no_pp_items = false,
              no_tm_use = false,
              no_rare_candy_use = false,
              no_buying = false,
              no_selling = false,
              no_poke_center = false,
              no_mom_heal = false,
              whiteout_clause = false,
              party_size_limit = 6,
              gym_team_size = false,
          },
          [1] = {
              nuzlocke_enabled = true,
              permadeath = true,
              first_rival_forgiveness = true,
              encounter_limit = true,
              failed_encounter = true,
              nickname_rule = true,
              level_cap_scope = 0,
              no_healing_items = false,
              no_battle_items = false,
              no_escape = false,
              no_repels = false,
              no_escape_rope = false,
              no_field_healing = false,
              no_pp_items = false,
              no_tm_use = false,
              no_rare_candy_use = false,
              no_buying = false,
              no_selling = false,
              no_poke_center = false,
              no_mom_heal = false,
              whiteout_clause = false,
              party_size_limit = 6,
              gym_team_size = false,
          },
          [2] = {
              nuzlocke_enabled = true,
              permadeath = true,
              first_rival_forgiveness = false,
              encounter_limit = true,
              failed_encounter = true,
              nickname_rule = true,
              level_cap_scope = 3,
              no_healing_items = true,
              no_battle_items = true,
              no_escape = false,
              no_repels = false,
              no_escape_rope = false,
              no_field_healing = false,
              no_pp_items = false,
              no_tm_use = false,
              no_rare_candy_use = false,
              no_buying = false,
              no_selling = false,
              no_poke_center = false,
              no_mom_heal = false,
              whiteout_clause = false,
              party_size_limit = 6,
              gym_team_size = true,
          },
          [3] = {
              nuzlocke_enabled = true,
              permadeath = true,
              first_rival_forgiveness = true,
              encounter_limit = true,
              failed_encounter = true,
              nickname_rule = true,
              level_cap_scope = 0,
              no_healing_items = false,
              no_battle_items = false,
              no_escape = false,
              no_repels = false,
              no_escape_rope = false,
              no_field_healing = false,
              no_pp_items = false,
              no_tm_use = false,
              no_rare_candy_use = false,
              no_buying = false,
              no_selling = false,
              no_poke_center = false,
              no_mom_heal = false,
              whiteout_clause = false,
              party_size_limit = 1,
              gym_team_size = false,
          },
          [4] = {
              nuzlocke_enabled = true,
              permadeath = true,
              first_rival_forgiveness = false,
              encounter_limit = true,
              failed_encounter = true,
              nickname_rule = true,
              level_cap_scope = 0,
              no_healing_items = true,
              no_battle_items = true,
              no_escape = true,
              no_repels = true,
              no_escape_rope = true,
              no_field_healing = true,
              no_pp_items = true,
              no_tm_use = true,
              no_rare_candy_use = true,
              no_buying = true,
              no_selling = true,
              no_poke_center = true,
              no_mom_heal = true,
              whiteout_clause = false,
              party_size_limit = 1,
              gym_team_size = true,
          },
      },
      applying = false,
  }
  end

  local function buildGen2BetaSurface()
      return { rules = {
      nuzlocke_enabled = true,
      permadeath = true,
      first_rival_forgiveness = true,
      encounter_limit = true,
      failed_encounter = true,
      nickname_rule = true,
      dupes_mode = true,
      -- 2.9.36: Colorlocke/Alphabetlocke enforcement is generation-neutral,
      -- so all four parent/child configuration rows must be reachable on the
      -- Gen-II Config surface as well as Gen I.
      colorlocke_mode = true,
      colorlocke_color = true,
      alphabetlocke_mode = true,
      alphabetlocke_letter = true,
      shiny_clause = true,
      status_move_scope = true,
      status_paralysis_scope = true,
      status_confusion_scope = true,
      status_sleep_scope = true,
      status_poison_scope = true,
      status_burn_scope = true,
      status_freeze_scope = true,
      sleep_clause = true,
      setup_move_scope = true,
      evasion_clause = true,
      status_accuracy_scope = true,
      other_stat_drop_scope = true,
      ohko_clause = true,
      flinch_clause_scope = true,
      trap_clause_scope = true,
      route_forgiveness = true,
      gold_roamer_clause = true,
      gold_egg_encounter_mode = true,
      gold_bug_contest_mode = true,
      gold_time_split = true,
      gold_headbutt_split = true,
      gold_radio_world_building = true,
      allow_gifts = true,
      allow_trades = true,
      type_lock_mode = true,
      type_lock_draft = true,
      type_lock_primary = true,
      type_lock_secondary = true,
      type_lock_tertiary = true,
      type_lock_quaternary = true,
      type_lock_quinary = true,
      type_lock_senary = true,
      no_day_care = true,
      maximum_bst = true,
      player_start_stat_exp = true,
      wild_start_stat_exp = true,
      trainer_start_stat_exp = true,
      no_player_stat_exp_gain = true,
      no_held_items = true,
      perfect_player_ivs = true,
      perfect_wild_ivs = true,
      perfect_trainer_ivs = true,
      allow_glitch_pokemon = true,
      no_static_encounters = true,
      overworld_encounters = true,
      town_catches = true,
      ban_legendaries = true,
      ban_mythicals = true,
      ban_pseudos = true,
      pkmn_ban = true,
      no_gambling = true,
      level_cap_scope = true,
      difficulty_profile = true,
      exp_edging = true,
      no_escape = true,
      no_catching = true,
      encounter_ball_limit = true,
      shiny_rate_mode = true,
      shiny_colors = true,
      shiny_intro = true,
      progression_pc_catches = true,
      no_tm_use = true,
      no_rare_candy_use = true,
      no_healing_items = true,
      no_battle_items = true,
      no_buying = true,
      no_selling = true,
      shop_restrictions = true,
      no_poke_center = true,
      no_mom_heal = true,
      whiteout_clause = true,
      gym_lock_in = true,
      dungeon_lock_in = true,
      area_guide_enabled = true,
      dev_mode = true,
      catch_info = true,
      stat_info = true,
      move_info = true,
      run_surf = true,
      unlimited_bag_space = true,
      trade_evolutions = true,
      system_clock_sync = true,
      system_date_time = true,
      automatic_default_names = true,
      skip_opening_intro = true,
      quick_nuzlocke_start = true,
      skip_catch_tutorial = true,
      skip_cherrygrove_tour = true,
      pc_starting_vitamins = true,
      pc_starting_heal_items = true,
      gold_starting_money = true,
      gold_starting_pokeballs = true,
      gold_starting_rare_candies = true,
      randomizer_preset = true,
      randomizer_seed = true,
      random_starter = true,
      random_starter_style = true,
      random_starter_balance = true,
      random_starter_trio_typing = true,
      random_starter_rerolls = true,
      random_encounter_tables = true,
      random_field_items = true,
      random_field_item_balance = true,
      random_field_item_repetition = true,
      random_encounter_balance = true,
      random_encounter_repetition = true,
      random_encounter_diversity_strength = true,
      randomizer_info_policy = true,
      random_species_generation = true,
      random_learnsets = true,
      random_trainers = true,
      random_trainer_balance = true,
      random_trainer_diversity = true,
      random_trainer_theme = true,
      random_evolutions = true,
      random_evolution_balance = true,
      random_shops = true,
      random_shop_balance = true,
      random_tms = true,
      random_tm_compatibility = true,
      random_tm_locations = true,
      random_gift_items = true,
      random_learnset_generation = true,
      random_learnset_stab = true,
      physical_special_split = true,
      badge_boosts = true,
      evolution_limit = true,
      party_size_limit = true,
      travel_restrictions = true,
      gym_team_size = true,
      trainer_money_multiplier = true,
      no_repels = true,
      no_fishing = true,
      no_escape_rope = true,
      no_field_healing = true,
      no_pp_items = true,
      world_building_tier = true,
  }, descriptions = {
      nuzlocke_enabled = Strings.source("GEN 2 BETA: experimental master switch. Only the reduced Gen 2 rule surface shown here is exposed; every gameplay adapter remains runtime-test-required."),
      permadeath = Strings.source("GEN 2 BETA / TEST REQUIRED: fainted party Pokemon use Gen 2's battle-faint path. Keep a backup while validating this adapter."),
      first_rival_forgiveness = Strings.source("GEN 2 BETA / TEST REQUIRED: forgives faint and Whiteout consequences only during the opening level-5 Rival battle. The exception is consumed when that battle begins; Hardcore defaults it OFF."),
      encounter_limit = Strings.source("GEN 2 BETA / TEST REQUIRED: one encounter per discovered Gen 2 area through the shared capture policy."),
      failed_encounter = Strings.source("GEN 2 BETA / TEST REQUIRED: a failed first eligible encounter may consume the area after Soft Start is armed."),
      nickname_rule = Strings.source("GEN 2 BETA / TEST REQUIRED: catches and scripted gifts must receive a non-empty nickname through Gen 2's native naming screen."),
      dupes_mode = Strings.source("GEN 2 BETA / TEST REQUIRED: duplicate handling through Gen 2's capture gate. OFF = normal, SPEC = species, FAM = whole evolution family, SPLIT = only the same ancestor/descendant branch."),
      shiny_clause = Strings.source("GEN 2 BETA / TEST REQUIRED — CATCH EXCEPTIONS ONLY; this does not change shiny odds. OFF disables shiny exceptions; 1/2/3 grant that many successful run-wide shiny exceptions; UNLIMITED preserves the traditional clause. Successful shiny exceptions consume exactly one allowance. Shiny Clause does not bypass Type Locke, No Catching, Static, or species/BST bans."),
      shiny_rate_mode = Strings.source("GEN 2 / TEST REQUIRED — RARITY ONLY; this does not grant catch exceptions. NATIVE preserves the engine's 1/8192 shiny roll. Higher modes use the public shiny.roll seam without replacing Gen II battle or Pokemon constructors. If a compatible shiny provider is active for this edition, Nuzlocke stands down and displays EXTERNAL."),
      shiny_colors = Strings.source("GEN 2 / TEST REQUIRED — VISUALS ONLY. When Nuzlocke owns shinies, live shiny Pokemon use the engine's sanctioned pokemon.sprite / pokemon.icon presentation seams. External shiny ownership disables Nuzlocke recoloring immediately."),
      shiny_intro = Strings.source("GEN 2 / TEST REQUIRED — VISUALS/AUDIO ONLY. When Nuzlocke owns shinies, battle.overlay supplies a one-shot sparkle cue without taking BattleState ownership. External shiny ownership disables Nuzlocke sparkle/audio presentation immediately."),
      status_move_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: bulk side-scope for the six outright status bans: Paralysis, Confusion, Sleep Ban, Poison/Toxic, Burn, and Freeze. OFF leaves them independent; SELF/ENEMY/ALL synchronize those six. Sleep Clause is separate and is never synchronized."),
      status_paralysis_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped paralysis ban. Secondary paralysis is suppressed without cancelling the damaging hit."),
      status_confusion_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped confusion ban. Secondary confusion is suppressed without cancelling the damaging hit."),
      status_sleep_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped outright sleep-infliction ban. Self-induced sleep remains allowed; Sleep Clause is independent."),
      status_poison_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped poison/Toxic ban. Secondary poison is suppressed without cancelling the damaging hit."),
      status_burn_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped burn ban. Secondary burn is suppressed without cancelling the damaging hit."),
      status_freeze_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped freeze ban. Secondary freeze is suppressed without cancelling the damaging hit."),
      sleep_clause = Strings.source("GEN 2 BETA / TEST REQUIRED: symmetric Sleep Clause. A side may not put an additional living opposing Pokemon to sleep while another remains asleep from that side's move. This stays independent of No Status Moves and Sleep Ban."),
      setup_move_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped ban on move-caused positive in-battle stat-stage setup. X Items and passive/item boosts remain separate. Damaging moves keep their damage when only a boost is suppressed."),
      evasion_clause = Strings.source("GEN 2 BETA / TEST REQUIRED: symmetric Evasion Clause blocks positive evasion-stage boosts for both sides while leaving accuracy drops unchanged."),
      status_accuracy_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: independent side-scoped Accuracy Drops ban. It is not synchronized by No Status Moves; damaging moves keep their damage when only a secondary accuracy drop is suppressed."),
      other_stat_drop_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: independent side-scoped ban on move-caused negative stat stages other than Accuracy, including self drops such as Curse Speed and Attack/Defense/Speed/Sp. Atk/Sp. Def/Evasion drops. Damaging moves keep their damage when only a secondary drop is suppressed."),
      ohko_clause = Strings.source("GEN 2 BETA / TEST REQUIRED: symmetric OHKO Clause blocks one-hit-KO effects for both sides before damage."),
      flinch_clause_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped Flinch Clause suppresses move and King's Rock flinches without cancelling the damaging hit."),
      trap_clause_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: side-scoped Trap Clause suppresses partial-trapping lock effects while preserving the initial damaging hit."),
      route_forgiveness = Strings.source("GEN 2 BETA / TEST REQUIRED: Gym Leader victories award a real F. TOKEN item using the Johto/Kanto leader progression map. The token never appears in Marts. Use it manually outside battle to choose any eligible FAILED encounter area or revive an archived fallen Pokemon at half HP; ENC TRACKER can also start a reroll; Party Size Limit and PC capacity remain authoritative."),
      allow_gifts = Strings.source("GEN 2 BETA / TEST REQUIRED: controls scripted givepoke acquisitions before party/PC mutation. OFF refuses optional gifts without burning their transaction; the mandatory Johto starter remains progression-safe."),
      allow_trades = Strings.source("GEN 2 BETA / TEST REQUIRED: controls native NPC trades before Gen 2 marks the one-shot trade flag or removes the offered Pokemon. Successful trades are tracked at their live map location."),
      type_lock_mode = Strings.source("GEN 2 BETA / TEST REQUIRED: Mono through Hexalocke eligibility reads Gen 2's live species types."),
      type_lock_draft = Strings.source("GEN 2 BETA / TEST REQUIRED: Catch Draft lets opening catches populate 1-6 Type Locke lanes."),
      type_lock_primary = Strings.source("GEN 2 BETA / TEST REQUIRED: Type Locke lane 1."),
      type_lock_secondary = Strings.source("GEN 2 BETA / TEST REQUIRED: Type Locke lane 2."),
      type_lock_tertiary = Strings.source("GEN 2 BETA / TEST REQUIRED: Type Locke lane 3."),
      type_lock_quaternary = Strings.source("GEN 2 BETA / TEST REQUIRED: Type Locke lane 4."),
      type_lock_quinary = Strings.source("GEN 2 BETA / TEST REQUIRED: Type Locke lane 5."),
      type_lock_senary = Strings.source("GEN 2 BETA / TEST REQUIRED: Type Locke lane 6."),
      no_day_care = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks new deposits in Gen 2's breeding model while preserving withdrawal and existing parents/Egg state."),
      maximum_bst = Strings.source("GEN 2 BETA / TEST REQUIRED: choose OFF / 300 / 350 / 400 / 450 / 500 / 550 / 600 / 650 / 700. New catches, ordinary gifts, and trades above that merged six-stat BST are blocked. The mandatory Johto starter remains exempt; unknown modded stat schemas fail open."),
      player_start_stat_exp = Strings.source("GEN 2 BETA / TEST REQUIRED: newly acquired player Pokemon use the Player Stat EXP preset, including catches, starters, gifts, and supported trades. 100% = 32768 per stored stat; 200% = 65535. Existing Pokemon are untouched."),
      wild_start_stat_exp = Strings.source("GEN 2 BETA / TEST REQUIRED: newly generated wild opponents default to vanilla 0 Stat EXP. Higher challenge presets apply before battle stats are used; if caught, Player Stat EXP then applies independently when the Pokemon joins you."),
      trainer_start_stat_exp = Strings.source("GEN 2 BETA / TEST REQUIRED: trainer Pokemon default to vanilla 0 Stat EXP. Gen 2's native trainer builder creates them with no starting Stat EXP; higher challenge presets are applied when the battle party is constructed."),
      no_player_stat_exp_gain = Strings.source("GEN 2 BETA / TEST REQUIRED: preserves each player Pokemon's existing Stat EXP across battle awards and blocks vitamin Stat EXP increases. Normal EXP and levels remain enabled."),
      no_held_items = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks GIVE paths for player-held items and suppresses existing player-held item battle effects without deleting the item. TAKE remains available so held items can be removed normally. Enemy/trainer held items remain native."),
      perfect_player_ivs = Strings.source("GEN 2 BETA / TEST REQUIRED: newly acquired player Pokemon receive perfect Gen 1/2 DVs; existing Pokemon are untouched."),
      perfect_wild_ivs = Strings.source("GEN 2 BETA / TEST REQUIRED: newly generated wild Pokemon receive perfect Gen 1/2 DVs before battle."),
      perfect_trainer_ivs = Strings.source("GEN 2 BETA / TEST REQUIRED: newly generated trainer Pokemon receive perfect Gen 1/2 DVs instead of the native trainer preset."),
      allow_glitch_pokemon = Strings.source("GEN 2 BETA / TEST REQUIRED: allow explicitly flagged or malformed glitch species. OFF rejects new glitch acquisitions before mutation; existing glitch Pokemon are preserved and labeled safely."),
      no_static_encounters = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks Ball use against scripted fixed wild Pokemon while preserving the battle and its story result. Random, roaming, gift, and trade encounters use their own rules."),
      overworld_encounters = Strings.source("GEN 2 BETA / TEST REQUIRED: allows compatible visible/overworld wild Pokemon providers to count catches against the physical Gen 2 map encounter slot. OFF rejects those alternate overworld captures without changing ordinary battle encounters."),
      town_catches = Strings.source("GEN 2 BETA / TEST REQUIRED: allows catches in Johto/Kanto towns and cities to consume their own encounter area. OFF leaves town/city captures ineligible while ordinary route/dungeon encounters remain unchanged."),
      ban_legendaries = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks new Legendary catches, gifts, and trades. Native Gen 2 fallbacks include Raikou, Entei, Suicune, Lugia, and Ho-Oh; merged provider metadata remains authoritative for custom species."),
      ban_mythicals = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks new Mythical catches, gifts, and trades. Celebi is recognized as the native Gen 2 fallback alongside Mew; merged provider metadata remains authoritative."),
      ban_pseudos = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks new pseudo-legendary acquisitions. Tyranitar and Dragonite are recognized natively; compatible provider metadata can classify additional species."),
      pkmn_ban = Strings.source("GEN 2 BETA / TEST REQUIRED: open the 251-species National Dex picker and selectively reject new catches, optional gifts, trades, and Nuzlocke-owned Random Starter/Random Encounter candidates. Existing Pokemon remain untouched; the mandatory opening starter keeps its progression-safety exemption."),
      no_gambling = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks Game Corner slot and card games plus prize-counter redemption before coins or prizes change hands. Coin vendors and unrelated Game Corner dialogue remain available."),
      level_cap_scope = Strings.source("GEN 2 BETA / TEST REQUIRED: Johto Gyms -> League -> Kanto -> Red progression model. Full progression validation is still open."),
      no_escape = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks the supported Gen 2 RUN action path."),
      no_catching = Strings.source("GEN 2 BETA / TEST REQUIRED: ON blocks capture attempts regardless of Ball type. Gifts, trades, and scripted non-capture acquisitions remain governed by their own rules."),
      encounter_ball_limit = Strings.source("GEN 2 BETA / TEST REQUIRED: limits legal Ball throws per catchable encounter to OFF / 1 / 2 / 3 / 5 / 10. Gen 2's existing battle Pack adapter owns the counter/refusal path; this row exposes that mechanic in Gen 2 Setup/NUZ RULES. Illegal/blocked throws do not spend the budget."),
      progression_pc_catches = Strings.source("GEN 2 BETA / TEST REQUIRED: allows otherwise rule-illegal captures for progression/completion only, then immediately sends them to permanent PC-only storage. These catches do not consume encounter slots or Type Locke draft lanes and cannot be withdrawn, moved to the party, or released. Ordinary No Catching remains absolute unless a compatible source explicitly marks the capture progression-required."),
      no_fishing = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks Old Rod, Good Rod, Super Rod, and compatible fishing-rod item use before Gen 2 begins its fishing attempt. Other wild encounter methods are unchanged."),
      no_tm_use = Strings.source("Blocks Gen 2 TM use before the Pack opens party selection or teaches a move. HMs remain usable, and TMs may still be obtained, held, given, or sold when other rules permit."),
      no_rare_candy_use = Strings.source("Blocks Gen 2 Rare Candy use before party selection, level changes, stat recalculation, or item consumption. The candy remains in the Pack."),
      no_healing_items = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks Potions, Revives, and status-healing medicine from Gen 2's battle Pack before the item effect can mutate the active Pokemon. Poke Balls remain governed by capture rules."),
      no_battle_items = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks X Attack, X Defend, Dire Hit, Guard Spec., and compatible battle-stat items from Gen 2's battle Pack. Healing items and Poke Balls remain governed by their own rules."),
      no_buying = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks entry into Gen 2's native BUY flow and rechecks at the money-changing transaction seam. The Mart remains usable for SELL/QUIT when those actions are otherwise allowed, and World Building supplies the rejection text."),
      no_selling = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks entry into Gen 2's native SELL flow and rechecks before money/items can change. BUY/QUIT remain available when otherwise allowed, and World Building supplies the rejection text."),
      no_poke_center = Strings.source("GEN 2 ALPHA/RETEST REQUIRED: Gold/Silver/Crystal gate the native special HealParty transaction only inside Pokemon Centers, leaving building access and unrelated services available."),
      no_mom_heal = Strings.source("GEN 2 ALPHA/TEST REQUIRED: Gold/Silver/Crystal gate the native special HealParty transaction only in the player home, preserving unrelated Mom/story behavior."),
      whiteout_clause = Strings.source("GEN 2 BETA / TEST REQUIRED: ON survives a full wipe only when a usable party/PC reserve remains; dead, PC-locked, and Egg storage does not count. OFF is run-ending Blackout."),
      gym_lock_in = Strings.source("GEN 2 BETA / TEST REQUIRED: once you enter a supported Johto or Kanto Gym, ordinary exits are blocked until that Gym Leader is defeated. Already-cleared Gyms remain open."),
      dungeon_lock_in = Strings.source("GEN 2 BETA / TEST REQUIRED: seals the entrance used to enter a supported multi-exit dungeon until you reach a different legitimate exit. Escape Rope and escape-style field moves are blocked while active; older saves without entry-side state fail open."),
      catch_info = Strings.source("GEN 2 BETA: include the native Gen 2-styled CATCH page in party-menu NUZ INFO."),
      stat_info = Strings.source("GEN 2 BETA: include the native Gen 2-styled STAT page in NUZ INFO, including DVs and the five stored Stat EXP words. Special Attack/Defense share Gen 2's Special DV and Stat EXP word."),
      move_info = Strings.source("GEN 2 BETA: include the native Gen 2-styled MOVE page in NUZ INFO, reading names/type/power/accuracy/PP from the active merged move data."),
      area_guide_enabled = Strings.source("GEN 2 BETA: toggles Gen 2's discovery-driven Tracker map page instead of preloading the Gen1 area list."),
      dev_mode = Strings.source("GEN 2 BETA diagnostics only: records bounded lifecycle breadcrumbs, compact state snapshots, and read-only invariant warnings to the mod log. It never changes battle, encounter, RNG, legality, or save-schema behavior."),
      run_surf = Strings.source("GEN 2 / TEST REQUIRED: shared walking/Surf assist. OFF preserves native movement; HOLD B applies 2x speed to player-controlled walking or Surf only while B is held; ALWAYS applies the same 2x speed continuously. Biking, scripted movement, Surf start, Waterfall, fishing, menus, and cutscenes remain native."),
      unlimited_bag_space = Strings.source("GEN 2 / TEST REQUIRED: ON removes distinct-item slot pressure from the ordinary ITEM and BALL pockets while preserving the native 99-per-item stack cap. KEY ITEM and TM/HM pocket limits, PC item storage, item legality, and story acquisition rules remain native. OFF restores the live engine/provider capacities without deleting carried items."),
      trade_evolutions = Strings.source("GEN 2 / TEST REQUIRED: ON lets EVOLVE_TRADE species evolve on level-up at level 40+. Trade-with-item branches still require the original held item, consume it on success, and suppress a competing ordinary level evolution while that item is held so branches such as Slowking remain reachable. Native link-trade evolution and Everstone behavior stay intact in Gold and Silver."),
      automatic_default_names = Strings.source("NEW GAME only: skips the Gen 2 player-name menu using the running edition's first canonical preset (GOLD or SILVER), then skips only the later police-report Rival naming screen using the counterpart edition name. The first Rival battle still correctly displays ???, and Pokemon nickname prompts are unaffected."),
      skip_opening_intro = Strings.source("GEN 2 NEW GAME only: skips Oak's visible introduction after preserving the required InitClock step. The player name resolves to the running edition's first canonical preset, the normal fresh-game continuation still runs, and the later ???/counterpart-edition Rival naming story is not skipped."),
      quick_nuzlocke_start = Strings.source("GEN 2 NEW GAME only / TEST REQUIRED: after the required clock setup, reconciles the mandatory Elm starter, Mr. Pokemon/Pokedex, Cherrygrove Rival, police naming, Mystery Egg return, Potion, and 5-Poke-Ball milestones, then begins in New Bark. Route 29's catch tutorial remains armed unless Skip Catch Demo is also selected in Gold or Silver."),
      skip_catch_tutorial = Strings.source("GEN 2 NEW GAME only: skips the Dude's Route 29 demonstration battle through its normal completion callback. His movement/dialogue and the script's map reload, scene clear, and learned-to-catch event still run in Gold and Silver."),
      skip_cherrygrove_tour = Strings.source("GEN 2 only / TEST REQUIRED: if the Guide Gent tour has not happened yet, accepting it skips the long follow/movement/explanation segment and resumes at the MAP CARD gift. The native MAP CARD flag, final dialogue, object cleanup, and script ending still execute in Gold and Silver."),
      pc_starting_vitamins = Strings.source("GEN 2 NEW GAME QoL: adds 10 HP Up, Protein, Iron, Carbos, and Calcium to the fresh save's PC item storage. Existing saves are never backfilled, and challenge rules can still block vitamin use."),
      pc_starting_heal_items = Strings.source("GEN 2 NEW GAME QoL: adds 10 each of Potion, Super Potion, Max Potion, Antidote, Burn Heal, Ice Heal, Awakening, Parlyz Heal, and Full Heal to the fresh save's PC storage. Existing saves are never backfilled; normal item-use rules still apply."),
      gold_starting_money = Strings.source("GEN 2 NEW GAME QoL / TEST REQUIRED: sets the fresh Gold/Silver/Crystal wallet to 0-999999 using Gen 2's native player.money field. Default 3000 preserves vanilla."),
      gold_starting_pokeballs = Strings.source("GEN 2 NEW GAME QoL / TEST REQUIRED: DEFERRED DELIVERY. Places 0-99 extra Poke Balls in the bedroom PC only after the Mystery Egg is returned to Elm/capture unlock, unlike immediate Candy/heal/vitamin PC loadouts. The native 5-Ball story reward remains untouched."),
      gold_starting_rare_candies = Strings.source("GEN 2 NEW GAME QoL / TEST REQUIRED: places 0-99 Rare Candies in the bedroom PC on the fresh Gold/Silver/Crystal save. Default 0 preserves vanilla."),
      randomizer_preset = Strings.source("GEN 2: unified Randomizer preset. CUSTOM preserves individual controls. CHAOS enables every Nuzlocke-owned subsystem with broad policies; BALANCED enables them with progression-aware defaults. Provider-delegated subsystems remain externally owned, and manual child edits return the preset to CUSTOM."),
      randomizer_seed = Strings.source("GEN 2: shareable 8-digit deterministic seed for all Nuzlocke-owned seed-driven randomizer subsystems in Gold/Silver/Crystal. AUTO resolves a fresh run seed at each NEW GAME while Setup stays AUTO; nonzero seeds are FIXED/replayable. Reroll Seed creates a new fixed seed. Each system uses an independent versioned RNG stream."),
      system_date_time = Strings.source("GEN 2 NEW GAME only: initializes the native Gold/Silver/Crystal clock and weekday from the platform local clock, skips the opening InitClock selection, and auto-resolves Mom's initial weekday/DST setup while preserving surrounding story progression."),
      system_clock_sync = Strings.source("GEN 2 QoL: while ON, re-anchors the native Gold/Silver/Crystal clock and weekday to current platform local time when the host minute changes. OFF stops Nuzlocke re-syncing and preserves the engine's current clock offset."),
      random_starter = Strings.source("Randomize only the starter received from Elm's selected Poke Ball. The chosen ball, starter event flags, rival team path, and story progression remain intact. Other encounters, gifts, trainers, and items are unchanged. Only applies before the starter is received."),
      random_starter_style = Strings.source("GEN 2: ANY / 3-STAGE / BASE / SIM BST filtering for Elm's randomized starter in Gold/Silver/Crystal while preserving progression-safe fallback and the chosen-ball story branch."),
      random_starter_balance = Strings.source("GEN 2: INDEPENDENT / BALANCED starter-slate shaping for Gold/Silver/Crystal. BALANCED prefers comparable current strength plus evolutionary potential without overriding hard legality, Starter Style, or distinctness."),
      random_starter_trio_typing = Strings.source("GEN 2: OFF / AUTO trio typing for Elm's three starter positions. AUTO prefers a three-way offensive type cycle using full dual typing, then falls back to the legal distinct slate if needed."),
      random_starter_rerolls = Strings.source("GEN 2: OFF / ON deterministic pre-selection starter rerolls. Each reroll advances only the starter reroll index; encounter, field-item, and learnset streams are unchanged. The action closes permanently after a starter is accepted."),
      random_encounter_tables = Strings.source("GEN 2 BETA / TEST REQUIRED: randomizes Gen 2's live grass, water, fishing, tree, time-of-day, and other encounter-table species while preserving the native slot structure and levels. Results persist by table slot."),
      random_field_items = Strings.source("GEN 2 BETA / TEST REQUIRED: randomizes native visible item-ball pickups and explicitly Nuzlocke-owned hidden/BG-event finds at collection time through the deterministic FIELD_ITEMS stream. Key/progression items and HMs remain protected. External owners can claim visible and hidden source methods independently; NPC gifts, shops, fruit/apricorn trees, and unrelated scripted rewards use separate ownership."),
      random_tm_locations = Strings.source("GEN 2 BETA / TEST REQUIRED: separately randomizes which TM item is obtained from supported physical TM pickup sources through the isolated TM_LOCATIONS stream. HMs never move. This is independent from Random TMs, which changes TM contents."),
      random_field_item_balance = Strings.source("GEN 2 / TEST REQUIRED: CHAOS preserves the full hard-safe item pool. CATEGORY prefers the authored pickup's semantic category. BALANCED first matches category + utility tier, then category, then tier, before hard-safe fallback. Key/HM/progression/provider protections never relax."),
      random_field_item_repetition = Strings.source("GEN 2 / TEST REQUIRED: ALLOW preserves independent deterministic item-ball rolls. DIVERSE biases native physical source ordinals toward different placement lanes. UNIQUE uses a stable source-ordinal permutation within the same hard-safe semantic pool; nonnumeric provider sources degrade deterministically and report diagnostics. Hidden BG-event items remain outside visible Field Item ownership."),
      random_encounter_balance = Strings.source("GEN 2: CHAOS / SIM BST / EVO / BALANCED encounter replacement in Gold/Silver/Crystal. SIM BST widens deterministic BST bands when needed; EVO/BALANCED also consider family depth, remaining evolutions, encounter level, and evolutionary ceiling before relaxing. Native levels, rates, time blocks, fishing/tree structures, and map tables remain unchanged."),
      random_encounter_repetition = Strings.source("GEN 2: ALLOW / DIVERSE / UNIQUE repetition policy within each encounter source group. DIVERSE softly favors less-used legal species; UNIQUE avoids repeats until the legal pool is exhausted. Native rates, levels, methods, time blocks, and table structure remain unchanged."),
      random_encounter_diversity_strength = Strings.source("GEN 2: LIGHT / STANDARD / STRONG DIVERSE weighting. STANDARD preserves the 2.6.83 factor; LIGHT and STRONG alter only the soft repeat penalty. Fishing, Surf/water, grass/cave, Headbutt/tree, contest, and time buckets retain separate group identity."),
      randomizer_info_policy = Strings.source("GEN 2: OPEN INFO exposes persisted randomized starter/encounter/item-system results to compatible information tools. BLIND INFO hides randomized species/items while still exposing safe seed/version/mode, edition/table model, source/ownership identity, semantic category counts, protected/mapping counts, and fallback diagnostics. Information reads consume no RNG and do not rewrite mappings."),
      random_species_generation = Strings.source("Shared species source for Gen 2 Random Encounters, Random Trainers, and Random Evolutions. Hidden while all three are OFF. Random Starter uses its own hard-safe live pool plus Starter Style. AUTO keeps the hard-safe live merged registry; GEN1 selects Kanto species, GEN2 selects Johto species, and BOTH selects Gen 1+2 species. Each participating subsystem applies its own stronger legality and story constraints afterward."),
      random_learnsets = Strings.source("GEN 2 BETA / TEST REQUIRED: randomizes Gen 2 species starting/level-up move entries through the live levelMoves data while preserving every learn level and entry count. Existing Pokemon keep already-known moves; future creation/level-up learning uses the randomized registry."),
      random_learnset_generation = Strings.source("GEN 2: move source used only by Random Learnsets in Gold/Silver/Crystal. AUTO uses the merged move registry; GEN1 selects move indices 1-165 and GEN2 selects 166-251. An empty requested pool fails open instead of inventing unavailable moves."),
      physical_special_split = Strings.source("GEN 2 BETA / TEST REQUIRED: gives each damaging Gen 1/2 move its modern Physical/Special category. Damage stats, Reflect/Light Screen, and Counter/Mirror Coat identity are kept aligned. OFF preserves native type-based Gen 2 categories."),
      badge_boosts = Strings.source("GEN 2 BETA / TEST REQUIRED: ON keeps Gen 2's native badge stat/type boosts. OFF suppresses those battle-only boosts without changing badge ownership or progression. A selected difficulty profile that disables badge boosts also keeps them suppressed."),
      evolution_limit = Strings.source("GEN 2 BETA / TEST REQUIRED: NORMAL keeps native evolution behavior. NO FINAL blocks evolution into a target that the live merged Gen 2 species data confirms has no further evolution. NO EVOLUTION blocks all ordinary evolution checks. Unknown/incomplete modded evolution data fails open."),
      party_size_limit = Strings.source("GEN 2 BETA / TEST REQUIRED: limits the active party to 1-6 Pokemon. Catches, gifts, trades, and PC withdrawals that would exceed the selected cap are blocked; deposits and one-for-one moves remain legal. 6 preserves native party capacity."),
      travel_restrictions = Strings.source("GEN 2 BETA / TEST REQUIRED: NORMAL preserves native field travel. NO FLY blocks player-initiated Fly only. NO FLY+TELEPORT blocks player-initiated Fly and Teleport. Dig and scripted/story transportation remain unchanged."),
      gym_team_size = Strings.source("GEN 2 BETA / TEST REQUIRED: blocks only the actual next Gym Leader battle when the active party exceeds that Leader's live composed team size. Ordinary Gym Trainers are unaffected. The limit follows merged/composed trainer data, including compatible Difficulty or trainer-party providers; box extras and challenge the Leader again."),
      trainer_money_multiplier = Strings.source("GEN 2 BETA / TEST REQUIRED: scales the final trainer prize after the native Gen 2/provider payout using 0/25/50/75/100/150/200/300/500%. External economy providers remain authoritative and prevent double-scaling."),
      no_repels = Strings.source("Blocks Repel, Super Repel, and Max Repel from Gen 2's field Pack before the encounter counter or inventory changes."),
      no_escape_rope = Strings.source("Blocks Escape Rope from Gen 2's field Pack before warping or consuming the item."),
      no_field_healing = Strings.source("Blocks Gen 2 field use of medicine, status cures, revival items, drinks, herbs, and healing Berries before party or inventory mutation."),
      no_pp_items = Strings.source("Blocks Gen 2 Ether/Elixer items, PP Up/PP Max, and MysteryBerry before PP or inventory mutation, including the supported battle-item path."),
      world_building_tier = Strings.source("GEN 2 BETA / TEST REQUIRED: controls the same OFF/T1/T2/T3 cosmetic rule feedback used in Kanto, with Johto-specific Tier 3 lines where a safe presentation seam exists. Rule enforcement remains unchanged when flavor is OFF."),
  } }
  end

  return {
      LEGENDARIES = LEGENDARIES,
      MYTHICALS = MYTHICALS,
      PSEUDOS = PSEUDOS,
      ruleCategories = ruleCategories,
      MOVEMENT_ASSIST_LABELS = MOVEMENT_ASSIST_LABELS,
      BATTLE_SCOPE_LABELS = BATTLE_SCOPE_LABELS,
      TRANSLATION_UI_SOURCES = TRANSLATION_UI_SOURCES,
      buildDefinitionIndex = buildDefinitionIndex,
      makeDescriptionHelpers = makeDescriptionHelpers,
      finiteNumber = finiteNumber,
      normalizeMovementAssistMode = normalizeMovementAssistMode,
      cycleIntegerRange = cycleIntegerRange,
      scalePercentFloor = scalePercentFloor,
      normalizeItemPolicyKey = normalizeItemPolicyKey,
      battleScopeLabel = battleScopeLabel,
      statusMoveChildKeys = statusMoveChildKeys,
      isStatusMoveChildKey = isStatusMoveChildKey,
      isBattleScopeRuleKey = isBattleScopeRuleKey,
      coerceRuleValue = coerceRuleValue,
      copyDescriptorValue = copyDescriptorValue,
      buildRuleDescriptorSnapshot = buildRuleDescriptorSnapshot,
      buildRuleRegistry = buildRuleRegistry,
      buildSaveSchemaFields = buildSaveSchemaFields,
      buildSaveSchemaDescriptor = buildSaveSchemaDescriptor,
      normalizePkmnBanSet = normalizePkmnBanSet,
      pkmnBanCountFromSet = pkmnBanCountFromSet,
      pkmnBanSetsEqual = pkmnBanSetsEqual,
      resolveNewGameStartingResources = resolveNewGameStartingResources,
      resolveGoldNewGameStartingResources = resolveGoldNewGameStartingResources,
      auditStartingResourceProfiles = auditStartingResourceProfiles,
      auditGoldStartingResourceProfiles = auditGoldStartingResourceProfiles,
      buildLockePreset = buildLockePreset,
      buildGen2BetaSurface = buildGen2BetaSurface,
  }
end
