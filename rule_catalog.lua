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
              { key = "dupes_mode", default = 2, readTrue = 2, readFalse = 0, name = Strings.source("Dupes Clause"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Choose duplicate handling. OFF = duplicates count normally. SPEC = only the exact species is a dupe. FAM = the evolution family is a dupe. Rejected duplicates never consume the area or a Forgiveness Token. Shiny Clause can override only the Dupes/area limit.") },
              { key = "shiny_clause", default = 0, readTrue = 4, readFalse = 0, name = Strings.source("Shiny Clause"), shortName = Strings.source("Shiny Catch"), numeric = true, digits = 1, min = 0, max = 4, desc = Strings.source("CATCH EXCEPTIONS ONLY — this does not change shiny odds. Choose how many successful shiny catches may bypass the ordinary One Per Area/Failed Encounter state and Dupes Clause. OFF = no shiny exception. 1/2/3 = that many successful run-wide exceptions; each successful shiny exception consumes one allowance. UNLIMITED preserves the traditional clause. Shinies still must satisfy No Catching, Type Locke, Static, species-ban, BST, town/overworld, and other absolute eligibility rules. Changing the limit mid-run does not reset allowances already used.") },
              { key = "shiny_rate_mode", default = 0, name = Strings.source("Shiny Rate"), shortName = Strings.source("Shiny Rate"), numeric = true, digits = 1, min = 0, max = 6, desc = Strings.source("RARITY ONLY — this does not grant catch exceptions. Built-in shiny support is used when no compatible external shiny provider owns the active edition. NATIVE preserves the edition's normal shiny behavior (including R/B/Y virtual Gen-II DV shinies and Gen II's native 1/8192 roll). Higher modes are 1/4096, 1/1024, 1/512, 1/100, 1/10, and ALWAYS. On Gen I the fallback marks the wild Pokemon shiny without changing its DVs/stats; on Gen II it uses the engine's public shiny.roll seam. When SHINY_POKEMON owns Gen I, this row is dormant and displays EXTERNAL; Nuzlocke still consumes the resulting shiny identity for Shiny Clause and tracking.") },
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
              { key = "allow_gifts", default = true,      name = Strings.source("Gift Pokemon"), shortName = Strings.source("Gift Mon"), desc = Strings.source("Allow gifts, fossils, and Game Corner prize Pokemon. They consume the encounter slot for the area where received. Native sources are version-aware. Source-less compatibility events require a matching location; if location is missing, only species with a genuinely deterministic gift source are inferred.") },
              { key = "allow_trades", default = true,     name = Strings.source("In-Game Trades"), shortName = Strings.source("Ingame Trds"), desc = Strings.source("Allow NPC in-game trades. The received Pokemon consumes the encounter slot where that trade occurs. Version-specific sources are tracked. Source-less compatibility events require a matching location; if location is missing, only species with a genuinely deterministic trade source are inferred.") },
              { key = "maximum_bst", default = 0, name = Strings.source("Maximum BST"), shortName = Strings.source("Max. BST"), numeric = true, min = 0, max = 700, preset = true, desc = Strings.source("Choose a fixed Base Stat Total cap for new catches, gifts, and trades: OFF / 300 / 350 / 400 / 450 / 500 / 550 / 600 / 650 / 700. OFF disables the restriction. Mandatory starters are always exempt so story progression cannot be blocked. Older free-form values are preserved until this control is changed, then it snaps to the nearest preset before cycling. Pokemon with missing or incomplete modded stat data are allowed rather than guessed.") },
              { key = "pkmn_ban", default = false, name = Strings.source("PKMN BAN"), shortName = Strings.source("PKMN BAN"), desc = Strings.source("Open a scrollable National Dex list and selectively ban species from new catches, optional gifts, trades, and Nuzlocke-owned Randomizer candidate pools. R/B/Y expose #001-#151; Gold/Silver expose #001-#251. The mandatory opening starter remains progression-safe; Random Starter candidates still honor the list. The hovered species uses the native menu cursor glyph. Existing Pokemon are never removed. The row shows how many species are currently banned; an empty list disables this restriction.") },
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
              { key = "wild_start_stat_exp", default = 0, name = Strings.source("Wild Stat EXP"), shortName = Strings.source("Wld Stat EXP"), numeric = true, digits = 1, min = 0, max = 5, desc = Strings.source("Starting Stat EXP for newly generated wild Pokemon. DEFAULT 0% is vanilla in R/B/Y and Gold/Silver. 100% means 32768 per stored stat and 200% means the native 65535 cap; higher presets strengthen the Pokemon immediately. Existing Pokemon are not changed.") },
              { key = "trainer_start_stat_exp", default = 0, name = Strings.source("Trainer Stat EXP"), shortName = Strings.source("Trnr Stat EXP"), numeric = true, digits = 1, min = 0, max = 5, desc = Strings.source("Starting Stat EXP for newly generated trainer Pokemon. DEFAULT 0% is vanilla in R/B/Y and Gold/Silver; native Gen 2 trainer construction also starts with zero Stat EXP. 100% means 32768 per stored stat and 200% means the 65535 cap. Species, levels, and moves are unchanged.") },
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
              { key = "random_field_items", default = false, name = Strings.source("Random Field Items"), shortName = Strings.source("Rndm Items"), desc = Strings.source("Randomize visible overworld field/item-ball pickups when collected. Each map/object slot uses its own deterministic FIELD_ITEMS stream under the shared randomizer seed, so enabling this does not change Random Starter, Random Encounters, or Random Learnsets results. Progression-critical/key items and HMs are protected in place and are never selected as replacements. This first implementation does not randomize hidden items, NPC gifts, shops, fruit/apricorn trees, or other scripted rewards.") },
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
              { key = "instant_text", default = false, name = Strings.source("Instant Text"), shortName = Strings.source("Instant Text"), desc = Strings.source("QoL for R/B/Y and Gold/Silver. ON removes the per-character typewriter delay from ordinary dialogue while preserving native page breaks, CONT prompts, A/B waits, scrolling, cries/fanfare waits, choice boxes, and scripted text timing. OFF uses the live game text-speed option normally.") },
              { key = "skip_cherrygrove_tour", default = false, capabilityGate = "cherrygrove_tour", name = Strings.source("Skip Cherrygrove Tour"), gen2Only = true, desc = Strings.source("GEN 2 only. Before the Guide Gent tour is completed, accepting his offer skips the long walking lesson and resumes at the MAP CARD reward. The native reward flag, final dialogue, object cleanup, story state, and Pokegear progression still run normally. OFF keeps the full vanilla tour.") },
              { key = "run_surf", default = 0, preGameReadCoerce = true, readTrue = 1, readFalse = 0, writeTrue = 1, writeFalse = 0, name = Strings.source("Run / Surf"), shortName = Strings.source("Run / Surf"), numeric = true, digits = 1, min = 0, max = 2, desc = Strings.source("Shared movement assist for R/B/Y and Gold/Silver/Crystal: OFF preserves vanilla walking and surfing, HOLD B applies 2x speed to player-controlled walking or Surf only while B is held, and ALWAYS applies the same 2x speed continuously. Biking, scripted movement, Surf initiation, Waterfall, fishing, menus, and cutscenes remain native.") },
              { key = "unlimited_bag_space", default = false, name = Strings.source("Unlimited Bag Space"), shortName = Strings.source("Unlimited Bag"), desc = Strings.source("QoL for R/B/Y and Gold/Silver. ON removes the distinct-item slot limit from R/B/Y's normal Bag and from Gen 2's ordinary ITEM and BALL pockets. Per-item stacks still cap at the engine's native 99, and Gen 2 KEY ITEM/TM-HM pocket limits plus PC item storage remain native. OFF restores the live engine/provider capacity without deleting items already carried.") },
              { key = "trade_evolutions", default = false, name = Strings.source("Trade Evolutions"), shortName = Strings.source("Trade Evos"), desc = Strings.source("QoL for R/B/Y and Gold/Silver. ON lets ordinary trade evolutions occur on the next level-up at level 40 or higher. In Gold/Silver, trade-with-held-item evolutions also require their original held item and consume it when the evolution succeeds; holding that item preserves branches such as Slowpoke -> Slowking instead of forcing the normal level evolution first. Real link trades still work at their native timing, and Everstone still blocks Gen 2 level-triggered trade evolutions.") },
              { key = "system_clock_sync", default = false, name = Strings.source("System Clock Sync"), shortName = Strings.source("Clock Sync"), gen2Only = true, desc = Strings.source("GEN 2 QoL. While ON, Gold/Silver re-anchor the game clock and weekday to the platform local clock when the host minute changes. Turning it OFF stops Nuzlocke re-syncing and leaves the current engine clock offset intact.") },
              { key = "infinite_rare_candies", default = false, rbyOnly = true, capabilityGate = "gym_guide_rare_candy", name = Strings.source("Gym Guide Rare Candy"), shortName = Strings.source("Gym Guide Cndy"), desc = Strings.source("R/B/Y QoL: Gym Guides keep their normal dialogue, then offer repeatable Rare Candies in batches of 1, 10, 25, 50, or 99.") },
          }
      },
      {
          title = Strings.source("QOL SETUP ONLY"), shortTitle = Strings.source("QOL SETUP"),
          rules = {
              { key = "system_date_time", default = false, name = Strings.source("System Date/Time"), shortName = Strings.source("System Date/Time"), gen2Only = true, setupOnly = true, desc = Strings.source("GEN 2 NEW GAME QoL. Initializes Gold/Silver time and weekday from the platform local clock, skips the opening manual clock selection, and auto-resolves Mom's initial weekday/DST setup while preserving surrounding story progression." ) },
              { key = "automatic_default_names", default = false, name = Strings.source("Default Names"), shortName = Strings.source("Deflt Names"), setupOnly = true, desc = Strings.source("Skip only the new-game player and Rival naming menus and choose each game's first canonical preset. R/B/Y keep Oak's confirmation dialogue. Gold uses GOLD for the player and later SILVER for the Rival; Silver uses SILVER for the player and later GOLD for the Rival. Pokemon nickname prompts are unaffected. NEW GAME only.") },
              { key = "skip_opening_intro", default = false, name = Strings.source("Skip Opening Intro"), shortName = Strings.source("Skip Oak Intro"), setupOnly = true, desc = Strings.source("NEW GAME only. Skips Oak's opening speech/movie and naming presentation, then continues through the engine's normal fresh-game transition. R/B/Y assign the first canonical player and Rival names and begin at the normal Pallet bedroom start. Gold/Silver preserve the required clock setup, assign the edition-appropriate first player-name preset, then begin at the normal Johto fresh-game start; the later Rival naming story remains untouched.") },
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
          "random_shops", "random_tms", "random_gift_items",
      }
  end
  if byKey.randomizer_seed then
      byKey.randomizer_seed.requiresAnyTrue = {
          "random_starter", "random_encounter_tables", "random_field_items",
          "random_learnsets", "random_trainers", "random_evolutions",
          "random_shops", "random_tms", "random_gift_items",
      }
      byKey.randomizer_seed.keepVisiblePreGame = true
  end



  return {
      LEGENDARIES = LEGENDARIES,
      MYTHICALS = MYTHICALS,
      PSEUDOS = PSEUDOS,
      ruleCategories = ruleCategories,
  }
end
