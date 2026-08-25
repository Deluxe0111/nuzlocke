-- Module owner: WorldBuilding
return function(mod, deps)
  deps = deps or {}
  local Strings = assert(deps.Strings, "world_building requires Strings")
  local defaultRuleValue = assert(deps.defaultRuleValue, "world_building requires defaultRuleValue")
  local saveBlocked = deps.saveBlocked or function() return false end
  ---------------------------------------------------------------------
  -- WORLD BUILDING / FLAVOR
  -- Cosmetic only: never changes a rule result or owns an engine hook.
  -- T1 = core feedback, T2 = snark, T3 = occasional Kanto-aware flavor.
  -- T3 story lines are once-per-save where appropriate.
  ---------------------------------------------------------------------
  local function worldTier(game)
      -- World Building is cosmetic and shared by both supported backends.
      -- Enforcement never depends on the selected tier: T0 still receives a
      -- plain rule explanation from the owning mechanic, while T1-T3 select
      -- progressively more flavorful presentation.
      local fallback = defaultRuleValue("world_building_tier")
      local value = tonumber(mod.save:get("world_building_tier", fallback)) or fallback
      value = math.max(0, math.min(3, value))
      if not (game and game.save) then return 0 end
      return value
  end

  -- Central rule-feedback catalogue. Every entry carries a clear T1 line, a
  -- personality-heavy T2 line, and Kanto/Johto-aware T3 flavor. Mechanics may
  -- still supply contextual fallbacks (names, BST values, etc.). Keeping the
  -- catalogue presentation-only lets rules share richer text without coupling
  -- legality to UI hooks or duplicating message branches in both backends.
  mod.exports.__beta26.worldRuleCatalog = {
      no_catching = {
          t1="No Catching is ON!",
          t2="That capture is off limits. Your run allows no catches.",
          kanto="Oak can study this one from a distance. This run leaves wild Pokemon wild.",
          johto="Elm can study this one from a distance. This run leaves wild Pokemon wild.",
      },
      progression_pc_catches = {
          t1="PC-only catch secured. This Pokemon is permanently locked in storage.",
          t2="Completion catch secured. It can fill the Pokedex or story requirement, but it can never join the active team.",
          kanto="Oak files this one under research only. It belongs in the PC, not on your Nuzlocke team.",
          johto="Elm files this one under research only. It belongs in the PC, not on your Nuzlocke team.",
      },
      progression_pc_lock = {
          t1="That Pokemon is permanently PC LOCKED.",
          t2="It was caught only for progression/completion and cannot leave storage.",
          kanto="Oak's research-only tag stays on this Pokemon. It cannot join the active team or be released.",
          johto="Elm's research-only tag stays on this Pokemon. It cannot join the active team or be released.",
      },
      progression_pc_full = {
          t1="PC storage is full. A PC-only catch cannot be secured.",
          t2="Make room in a Pokemon Box before using a progression-only catch exception.",
          kanto="Oak needs an empty PC slot before he can file a research-only catch.",
          johto="Elm needs an empty PC slot before he can file a research-only catch.",
      },
      encounter_area = {
          t1="Encounter used!",
          t2="That area's encounter is already spent. Try somewhere new.",
          kanto="The Route Ledger is closed here. Kanto already gave you this area's chance.",
          johto="The Route Ledger is closed here. Johto already gave you this area's chance.",
      },
      dupes = {
          t1="Dupes Clause: duplicate encounter.",
          t2="Duplicate family. This one does not spend your area.",
          kanto="The Tracker recognizes that family. Keep looking; Kanto still owes you an eligible encounter.",
          johto="The Tracker recognizes that family. Keep looking; Johto still owes you an eligible encounter.",
      },
      type_lock_mode = {
          t1="Type Locke: this Pokemon is off type.",
          t2="That Pokemon does not match your Type Locke. Your encounter is still available.",
          kanto="That species is outside your chosen Kanto type roster. Let it go; the route still owes you a legal encounter.",
          johto="That species is outside your chosen Johto type roster. Let it go; the area still owes you a legal encounter.",
      },
      type_lock_draft = { t1="Catch Draft updated.", t2="Opening catches can define your Type Locke lanes before enforcement begins.", kanto="Your Kanto type roster will be written by your catches.", johto="Your Johto type roster will be written by your catches." },
      type_lock_primary = { t1="Type Locke Type 1 selected.", t2="Type 1 is the Monolocke lane and first lane for larger Type Lockes.", kanto="Your Kanto challenge has its first type.", johto="Your Johto challenge has its first type." },
      type_lock_secondary = { t1="Type Locke Type 2 selected.", t2="Type 2 joins Duolocke or higher.", kanto="Your Kanto challenge has its second type.", johto="Your Johto challenge has its second type." },
      type_lock_tertiary = { t1="Type Locke Type 3 selected.", t2="Type 3 joins Trilocke or higher.", kanto="Your Kanto challenge has its third type.", johto="Your Johto challenge has its third type." },
      type_lock_quaternary = { t1="Type Locke Type 4 selected.", t2="Type 4 joins Quadlocke or higher.", kanto="Your Kanto Quadlocke has its fourth type.", johto="Your Johto Quadlocke has its fourth type." },
      type_lock_quinary = { t1="Type Locke Type 5 selected.", t2="Type 5 joins Pentalocke or Hexalocke.", kanto="Your Kanto Pentalocke has its fifth type.", johto="Your Johto Pentalocke has its fifth type." },
      type_lock_senary = { t1="Type Locke Type 6 selected.", t2="Type 6 completes the Hexalocke roster.", kanto="Your Kanto Hexalocke has all six types.", johto="Your Johto Hexalocke has all six types." },
      no_day_care = {
          t1="No Day Care is ON.",
          t2="Your challenge does not allow new Pokemon to be left at the Day Care.",
          kanto="The Day-Care Man respects the challenge card: no new teammates are being left for training today.",
          johto="The Day-Care couple respects the challenge card: no new parents are being left for training today.",
      },
      overworld_encounters = {
          t1="Overworld catches are OFF.",
          t2="That overworld Pokemon is scenery for this ruleset, not your encounter.",
          kanto="The visible wanderer gets to stay part of Kanto's scenery. Find a counted encounter instead.",
          johto="The visible wanderer gets to stay part of Johto's scenery. Find a counted encounter instead.",
      },
      town_catches = {
          t1="Town catches are OFF.",
          t2="Cities and towns do not supply encounters on this run.",
          kanto="The city limits are safe ground today. Your next legal catch belongs out on Kanto's roads.",
          johto="The town limits are safe ground today. Your next legal catch belongs out on Johto's roads.",
      },
      ban_legendaries = {
          t1="Legendary Pokemon are off limits.",
          t2="A Legendary is too much firepower for this challenge.",
          kanto="Kanto's legends are staying legends, not party members.",
          johto="Johto's legends have bigger stories than your party roster today.",
      },
      ban_mythicals = {
          t1="Mythical Pokemon are off limits.",
          t2="Mythicals do not count as legal acquisitions on this run.",
          kanto="Even Oak's rarest research notes do not grant an exception for this Mythical.",
          johto="Even Elm's research curiosity does not grant an exception for this Mythical.",
      },
      ban_pseudos = {
          t1="Pseudo-legendary Pokemon are off limits.",
          t2="That powerhouse sits outside this run's legal roster.",
          kanto="The League can keep its late-game monsters. Your rules say no pseudos.",
          johto="Johto has enough monsters at the top already. Your rules say no pseudos.",
      },
      pkmn_ban = {
          t1="That Pokemon is banned by PKMN BAN.",
          t2="That species is crossed off this run's custom legal roster.",
          kanto="Your Kanto challenge roster has this species crossed out. Pick another legal teammate.",
          johto="This custom Kanto-only ban list is not exposed on the Johto rules surface.",
      },
      allow_gifts = {
          t1="Gift Pokemon are disabled by your rules.",
          t2="The offer can stand, but this run does not accept gift Pokemon.",
          kanto="Kanto's generous NPCs get a polite no today. Your team has to come from legal encounters.",
          johto="Johto's generous NPCs get a polite no today. Your team has to come from legal encounters.",
      },
      allow_trades = {
          t1="In-game trades are disabled by your rules.",
          t2="The trade offer is valid, but this run does not accept traded Pokemon.",
          kanto="The trade counterparty keeps their Pokemon. Your challenge is staying self-caught.",
          johto="The trade counterparty keeps their Pokemon. Your challenge is staying self-caught.",
      },
      no_static_encounters = {
          t1="Static catches are OFF.",
          t2="You may finish the fixed encounter, but you may not capture it.",
          kanto="Scripted or waiting in plain sight, this Kanto encounter is a battle, not a catch.",
          johto="Scripted or waiting in plain sight, this Johto encounter is a battle, not a catch.",
      },
      maximum_bst = {
          t1="That Pokemon exceeds your Maximum BST.",
          t2="Too much base-stat power for the limit you chose.",
          kanto="The League's unofficial power scale says this one is over your limit.",
          johto="The challenge ledger says those base stats are over your limit.",
      },
      allow_glitch_pokemon = {
          t1="Glitch Pokemon are blocked by your rules.",
          t2="That species identity is marked as glitch/invalid, so the acquisition is rejected safely.",
          kanto="The Pokedex cannot make sense of this one, and your rules refuse the anomaly.",
          johto="The Pokedex cannot make sense of this one, and your rules refuse the anomaly.",
      },
      party_size_limit = {
          t1="Your active party has reached this run's party-size limit.",
          t2="Box or deposit a Pokemon before adding another active teammate.",
          kanto="Your active team is full under this run's rules. Make room before adding another Pokemon.",
          johto="Your active team is full under this run's rules. Make room before adding another Pokemon.",
      },
      gym_team_size = {
          t1="Your party is larger than the next Gym Leader's team.",
          t2="This Leader set a team-size cap. Box the extra Pokemon and try again.",
          kanto="Kanto's Leader counts the balls at your belt and shakes their head. Bring no more Pokemon than the Gym will field.",
          johto="Johto's Leader checks your active roster before the challenge. Bench the extras until you are at or under the Gym's team size.",
      },
      no_rare_candy_use = {
          t1="Rare Candy use is banned.",
          t2="Keep the candy; this run will not let it grant a level. Collection and selling remain separate rules.",
          kanto="The Gym Guide has no candy shortcut on this rule card. Keep it, sell it if allowed, or let it gather dust.",
          johto="The badge case has no candy shortcut on this rule card. Keep it, sell it if allowed, or let it gather dust.",
      },
      no_player_stat_exp_gain = {
          t1="Stat EXP gain is banned.",
          t2="That boost would change Stat EXP, so it stays unused.",
          kanto="The training ledger is frozen. No vitamin is sneaking extra Stat EXP onto the team.",
          johto="The training ledger is frozen. No vitamin is sneaking extra Stat EXP onto the team.",
      },
      no_tm_use = {
          t1="TM teaching is banned.",
          t2="You may keep, buy, sell, or collect the TM when other rules allow it, but it cannot teach a move.",
          kanto="The TM case is a souvenir shelf on this run. Moves must come from level-up or other legal sources; HMs still handle field progression.",
          johto="The TM pocket is a collection binder on this run. Moves must come from other legal sources; HMs still handle field progression.",
      },
      level_cap_scope = {
          t1="The level cap blocks that.",
          t2="Nice try. The current boss cap still has the final say.",
          kanto="The Gym Guide has the next ceiling written down. No candy-shaped loopholes.",
          johto="The badge case has the next ceiling written down. No candy-shaped loopholes.",
      },
      no_pp_items = {
          t1="PP items are banned.",
          t2="No PP recovery or PP boosting items on this run.",
          kanto="Your moves earn their PP the hard way. Ether shortcuts are closed.",
          johto="Your moves earn their PP the hard way. Ether shortcuts are closed.",
      },
      no_repels = {
          t1="Repels are banned.",
          t2="No skipping the local wildlife with Repel.",
          kanto="Kanto's grass wants introductions. Put the Repel away.",
          johto="Johto's grass wants introductions. Put the Repel away.",
      },
      no_fishing = {
          t1="Fishing is banned.",
          t2="The rod stays packed. This run does not allow fishing encounters.",
          kanto="The Fishing Guru can keep the stories; this challenge keeps its hooks out of Kanto's water.",
          johto="Johto has plenty of fish, but this rule card says the rod stays dry.",
      },
      no_escape_rope = {
          t1="Escape Rope is banned.",
          t2="No rope shortcut out. Leave under your own power.",
          kanto="The cave is not offering express checkout today. Walk it out.",
          johto="Johto's caves are not offering express checkout today. Walk it out.",
      },
      no_field_healing = {
          t1="Field healing is banned.",
          t2="HP, status, and revival medicine stays in the bag until a legal healing seam; PP recovery is governed separately.",
          kanto="No roadside medicine stop in Kanto. Potions, status cures, and Revives stay packed while the team carries its condition forward.",
          johto="No trail-side medicine stop in Johto. Potions, status cures, and Revives stay packed while the team carries its condition forward.",
      },
      no_healing_items = {
          t1="Healing items are banned in battle.",
          t2="No potion bailout in the middle of a fight.",
          kanto="The Kanto League has seen enough potion stalling. Win with the team you brought.",
          johto="The Johto League has seen enough potion stalling. Win with the team you brought.",
      },
      no_battle_items = {
          t1="X Items are banned in battle.",
          t2="No X-Item setup shortcuts on this run.",
          kanto="League officials confiscated the battle boosters. Strategy only.",
          johto="League officials confiscated the battle boosters. Strategy only.",
      },
      no_buying = {
          t1="Buying is disabled by your rules.",
          t2="The clerk can show you the stock, but your wallet stays closed.",
          kanto="The Mart clerk recognizes the rule card before you reach the counter. Kanto is window-shopping only today.",
          johto="The Mart clerk knows the challenge: window-shopping only today.",
      },
      no_selling = {
          t1="Selling is disabled by your rules.",
          t2="Your bag contents stay yours; the clerk cannot buy them.",
          kanto="The Mart counter is not turning your supplies into cash this run.",
          johto="The Mart counter is not turning your supplies into cash this run.",
      },
      no_poke_center = {
          t1="Pokemon Center healing is disabled.",
          t2="Nurse Joy can cheer you on, but your team cannot heal here.",
          kanto={"Nurse Joy spots the rule card, folds her hands over the counter, and wishes the team luck instead of touching the machine.",
              "Nurse Joy checks the challenge card and returns the team without starting the healing machine.",
              "The Center is open; your recovery rules are stricter."},
          johto={"Nurse Joy checks the rule card and steps away from the machine. Good luck out there.",
              "Nurse Joy checks the challenge card and returns the team without starting the healing machine.",
              "The Center is open; your recovery rules are stricter."},
      },
      no_mom_heal = {
          t1="Mom healing is disabled.",
          t2="Mom would love to help, but your challenge says no free home heal.",
          kanto={"Mom knows the rule. She waves you back toward Kanto and says Bryan is using your computer again anyway, so you may as well keep moving.",
              "Mom checks the challenge card twice, then sends you back out with encouragement instead of a heal.",
              "Home is still home, but the team does not get a free reset here."},
          johto={"Mom knows the rules by now. She sends you back into Johto with encouragement instead of a heal.",
              "Mom checks the challenge card twice, then sends you back out with encouragement instead of a heal.",
              "Home is still home, but the team does not get a free reset here."},
      },
      no_gambling = {
          t1="No Gambling blocks this Game Corner action.",
          t2="Coins and prizes stay put. Your challenge is not taking this bet.",
          kanto="The Celadon counter recognizes the rule: no wagers, no prize redemption.",
          johto="The Goldenrod counter recognizes the rule: no wagers, no prize redemption.",
      },
      gym_lock_in = {
          t1="Gym Lock-In: defeat the Leader before leaving.",
          t2="No backing out now. Finish the Gym challenge first.",
          kanto={"The Gym staff shut the doors behind you. The only respectable way back onto Kanto streets is through the Leader.",
              "The Gym entrance is behind you now. The Leader is the exit condition.",
              "Kanto's Gym challenge does not come with a retreat button."},
          johto={"The Gym doors are staying shut. Beat the Leader, then Johto lets you back outside.",
              "The Gym entrance is behind you now. The Leader is the exit condition.",
              "Johto's Gym challenge does not come with a retreat button."},
      },
      dungeon_lock_in = {
          t1="Dungeon Lock-In: the entrance is sealed. Find another exit.",
          t2="No retreat through the entrance you used. Find another way out.",
          kanto={"The entrance may as well be painted onto the wall now. Kanto expects you to finish the dungeon before retreating.",
              "That entrance is no longer your escape route. Find the dungeon's other side.",
              "The way back is closed by the challenge. Forward is the legal route."},
          johto={"That entrance is behind you now. Johto's dungeon wants you to finish the crossing.",
              "That entrance is no longer your escape route. Find the dungeon's other side.",
              "The way back is closed by the challenge. Forward is the legal route."},
      },
      route_forgiveness_award = {
          t1="F. TOKEN +1.",
          t2="Gym Leader defeated. You earned one F. TOKEN.",
          kanto="A Gym Leader signs off on one carried reprieve. Save the F. TOKEN until you want to spend it.",
          johto="A Gym Leader signs off on one carried reprieve. Save the F. TOKEN until you want to spend it.",
      },
      route_forgiveness_used = {
          t1="F. TOKEN used. The failed encounter is open again.",
          t2="That failed encounter gets a reroll. The area's catch slot is open again.",
          kanto="The Route Ledger accepts your F. TOKEN and reopens this failed Kanto encounter.",
          johto="The Route Ledger accepts your F. TOKEN and reopens this failed Johto encounter.",
      },
      failed_encounter = {
          t1="Encounter failed. That area's chance is spent.",
          t2="Oof. There goes the encounter; the ledger is keeping score.",
          kanto="The Route Ledger closes the line with a hard stroke. Kanto remembers the one that got away.",
          johto="The route will not offer another chance. Johto has a long memory.",
      },
      encounter_armed = {
          t1="Encounter rules are now active.",
          t2="First usable Ball obtained. The Route Ledger is officially live.",
          kanto="The Area Guide opens for business. From here on, Kanto's encounters count.",
          johto="The Area Guide opens for business. From here on, Johto's encounters count.",
      },
      permadeath = {
          t1="A Pokemon has fallen. Permadeath applies.",
          t2="The faint counts. That teammate is gone from the active run.",
          kanto="The Tracker records the loss before Kanto can move on. The empty party slot tells the rest of the story.",
          johto="Johto remembers every teammate you lose. The Tracker marks another name in the ledger.",
      },
      first_rival_forgiveness = {
          t1="First Rival Mercy is active for this battle.",
          t2="One opening-battle pardon. Faints and Whiteout consequences are forgiven this time only.",
          kanto="Oak is still calling this a practice battle. The Rival gets one consequence-free opening fight.",
          johto="This first clash is your one free lesson. The Rival gets no second mercy later.",
      },
      whiteout_clause = {
          t1="WHITEOUT: the run survives. Rebuild from an eligible reserve.",
          t2="Your active party is gone, but a usable reserve remains in the PC.",
          kanto="Kanto gives you one way back: withdraw a legal reserve from the PC.",
          johto="Johto gives you one way back: withdraw a legal reserve from the PC.",
      },
      blackout = {
          t1="BLACKOUT: no recovery remains. The run is over.",
          t2="No usable Pokemon remain under the active rules. This Nuzlocke ends here.",
          kanto="Kanto has no legal reserve left. The run ends here.",
          johto="Johto has no legal reserve left. The run ends here.",
      },
      exp_edging = {
          t1="EXP Edging banked blocked EXP.",
          t2="The cap caught that EXP. It is banked on this Pokemon for later.",
          kanto="The Gym cap holds the level in place, but the training is not wasted. The EXP bank remembers it.",
          johto="The badge cap holds the level in place, but the training is not wasted. The EXP bank remembers it.",
      },
      trainer_money_multiplier = {
          t1="Trainer Money scaling adjusted the payout.",
          t2="Your configured trainer-money rate was applied to the final prize.",
          kanto="The battle purse hits your challenge ledger before it reaches the wallet.",
          johto="The battle purse hits your challenge ledger before it reaches the wallet.",
      },
      nuzlocke_enabled = {
          t1="Nuzlocke rules are active.",
          t2="The challenge is live. From here on, the rule card matters.",
          kanto="Oak's journey just became a Nuzlocke. Kanto will keep the receipts.",
          johto="Elm's journey just became a Nuzlocke. Johto will keep the receipts.",
      },
      encounter_limit = {
          t1="One Per Area is active.",
          t2="Every area gets one legal catch opportunity. Spend it carefully.",
          kanto="The Route Ledger gives each Kanto area one line. Make the catch count.",
          johto="The Route Ledger gives each Johto area one line. Make the catch count.",
      },
      route_forgiveness = {
          t1="Route Forgiveness uses carried F. TOKEN items.",
          t2="Spend an F. TOKEN later to reroll a failed area or revive one fallen Pokemon.",
          kanto="Kanto's Gym Leaders award a carried F. TOKEN. It never appears in a shop.",
          johto="Johto's Gym Leaders award a carried F. TOKEN. It never appears in a Mart.",
      },
      dupes_mode = {
          t1="Dupes Clause is active.",
          t2="Already-owned species or families can be passed without spending the area.",
          kanto="The Kanto ledger checks your collection before it closes a route.",
          johto="The Johto ledger checks your collection before it closes a route.",
      },
      shiny_clause = {
          t1="Shiny Clause grants an exception.",
          t2="Sparkle beats paperwork. This Shiny gets the clause exception.",
          kanto="Even Kanto's rulebook makes room for something this rare. The Shiny gets a pass.",
          johto="Even Johto's rulebook makes room for something this rare. The Shiny gets a pass.",
      },
      route_2_split = {
          t1="Route 2 split rules are active.",
          t2="North and South Route 2 can carry separate encounter opportunities.",
          kanto="Viridian Forest cuts the journey in two; the ledger can do the same for Route 2.",
          johto="This Kanto-only area split has no Johto encounter effect.",
      },
      route_10_split = {
          t1="Route 10 split rules are active.",
          t2="North and South Route 10 can carry separate encounter opportunities.",
          kanto="Rock Tunnel divides the road; the ledger can divide Route 10 with it.",
          johto="This Kanto-only area split has no Johto encounter effect.",
      },
      route_20_split = {
          t1="Route 20 split rules are active.",
          t2="West and East Route 20 can carry separate encounter opportunities.",
          kanto="Seafoam sits between the two halves, so the ledger can treat each shore separately.",
          johto="This Kanto-only area split has no Johto encounter effect.",
      },
      mt_moon_splits = {
          t1="Mt. Moon split rules are active.",
          t2="The selected floors can count as separate encounter areas.",
          kanto="Mt. Moon has enough twists to deserve more than one line in the ledger when you choose it.",
          johto="This Kanto-only dungeon split has no Johto encounter effect.",
      },
      safari_zone_splits = {
          t1="Safari Clause rules are active.",
          t2="The selected Safari policy controls area slots and whether failures consume them.",
          kanto="The Safari can use one slot or one per section, with an optional until-catch exception.",
          johto="This Kanto-only Safari policy has no Johto encounter effect.",
      },
      random_starter = {
          t1="Random Starter is active.",
          t2="The first partner is a surprise; the rest of the world stays out of the reroll.",
          kanto="Oak still offers a first partner, but even he does not know which species the challenge picked.",
          johto="Elm still offers a first partner, but even he does not know which species the challenge picked.",
      },
      random_species_generation = {
          t1="Random Encounters are using a selected generation species pool.",
          t2="Wild-table rerolls draw only from the generations your encounter randomizer selected.",
          kanto="Oak's habitat records can include visiting species when the active Pokedex data can fully describe them.",
          johto="Elm's habitat records cover both Kanto and Johto species, so randomized wild tables can mix both generations freely.",
      },
      randomizer_seed = {
          t1="This run has a shareable randomizer seed.",
          t2="Starter, encounter, field-item, and learnset rolls use separate deterministic streams under the same seed.",
          kanto="Oak stamped the challenge ledger with a reproducible randomizer code.",
          johto="Elm stamped the challenge ledger with a reproducible randomizer code.",
      },
      random_starter_style = {
          t1="Random Starter uses a structured candidate style.",
          t2="The starter roll can preserve evolutionary depth or approximate the original partner's strength.",
          kanto="Oak's surprise partner still follows the starter shape you selected.",
          johto="Elm's surprise partner still follows the starter shape you selected.",
      },
      random_starter_balance = {
          t1="Random Starter is balancing the starter slate.",
          t2="The choices are nudged toward comparable current strength and evolutionary potential without overriding hard legality.",
          kanto="Oak has tried to keep the three surprise partners on reasonably even footing.",
          johto="Elm has tried to keep the three surprise partners on reasonably even footing.",
      },
      random_starter_trio_typing = {
          t1="Random Starter is trying to preserve a three-way type relationship.",
          t2="AUTO considers both types on each candidate and relaxes cleanly when the legal pool cannot form a cycle.",
          kanto="Oak arranged the surprise choices so each partner has a natural answer when the legal pool allows it.",
          johto="Elm arranged the surprise choices so each partner has a natural answer when the legal pool allows it.",
      },
      random_starter_rerolls = {
          t1="Pre-selection starter rerolls are enabled.",
          t2="Each reroll advances only the starter slate index; the rest of the randomized world keeps the same streams.",
          kanto="Oak will reshuffle the surprise choices again before you commit, but the rest of Kanto stays fixed.",
          johto="Elm will reshuffle the surprise choices again before you commit, but the rest of Johto stays fixed.",
      },
      random_field_items = {
          t1="Visible field-item pickups are randomized.",
          t2="Each ordinary item ball gets a deterministic surprise while required keys and HMs stay where the story put them.",
          kanto="Even Oak's field notes cannot predict what is inside an ordinary item ball now.",
          johto="Ordinary floor pickups are shuffled, but Johto's required keys and HMs stay anchored to progression.",
      },
      random_field_item_balance = {
          t1="Field-item replacements are using a semantic balance policy.",
          t2="CATEGORY preserves the pickup's role when possible; BALANCED also prefers a similar utility tier before relaxing.",
          kanto="Kanto's item balls are being shuffled with the selected item-category balance.",
          johto="Johto's item balls are being shuffled with the selected item-category balance.",
      },
      random_field_item_repetition = {
          t1="Visible field-item replacements are controlling repeat placement.",
          t2="DIVERSE nudges physical item sources into different deterministic lanes; UNIQUE uses a stable source-order permutation when the source ordinal is authoritative.",
          kanto="Kanto's visible item balls are spreading their shuffled contents across physical pickup slots.",
          johto="Johto's visible item balls are spreading their shuffled contents across physical pickup slots.",
      },
      random_encounter_balance = {
          t1="Random Encounters use a balance policy.",
          t2="Wild replacements can preserve BST, evolution stage, or both instead of pure chaos.",
          kanto="Kanto's ecology has been shuffled without throwing its whole power curve away.",
          johto="Johto's ecology has been shuffled without throwing its whole power curve away.",
      },
      random_encounter_repetition = {
          t1="Random encounters are controlling repeats within each source group.",
          t2="DIVERSE softly favors unused species; UNIQUE avoids repeats until the legal pool is exhausted.",
          kanto="Wild tables try to spread their surprise species more evenly without changing encounter rates.",
          johto="Wild tables try to spread their surprise species more evenly across each method and time block.",
      },
      random_encounter_diversity_strength = {
          t1="Random encounter diversity has a configurable strength.",
          t2="LIGHT nudges variety, STANDARD keeps the normal DIVERSE weighting, and STRONG pushes harder against repeats without banning them.",
          kanto="Kanto's wild tables are being shuffled with the selected variety pressure.",
          johto="Johto's wild tables are being shuffled with the selected variety pressure for each encounter method and time bucket.",
      },
      randomizer_info_policy = {
          t1="Randomized encounter information is being kept blind.",
          t2="Compatible guide tools can still use the final gameplay registry, but should not reveal undiscovered randomized species tables.",
          kanto="Oak sealed the shuffled habitat notes until your own field work earns the reveal.",
          johto="Elm marked the shuffled habitat notes field-only: discovery comes before the research printout.",
      },
      physical_special_split = {
          t1="The Physical/Special Split is active.",
          t2="Moves now use their own physical or special identity instead of inheriting it from type.",
          kanto="Kanto's old battle manuals have been revised: each attacking move now decides which side of the stat sheet it uses.",
          johto="Johto's battle theory has moved ahead of its era: each attacking move now carries its own physical or special classification.",
      },
      player_start_stat_exp = {
          t1="Player starting Stat EXP has been customized.",
          t2="New teammates enter with the training baseline you selected.",
          kanto="Oak's records stamp each new teammate with your chosen training baseline.",
          johto="Elm's records stamp each new teammate with your chosen training baseline.",
      },
      wild_start_stat_exp = {
          t1="Wild starting Stat EXP has been customized.",
          t2="Fresh wild opponents enter with the training baseline you selected.",
          kanto="Kanto's wild population has been training before you ever reach the grass.",
          johto="Johto's wild population has been training before you ever reach the grass.",
      },
      trainer_start_stat_exp = {
          t1="Trainer starting Stat EXP has been customized.",
          t2="New trainer parties use the training baseline you selected.",
          kanto="Kanto's Trainers are showing up with homework already done.",
          johto="Johto's Trainers are showing up with homework already done.",
      },
      perfect_player_ivs = {
          t1="Perfect Player DVs are enabled.",
          t2="New teammates receive perfect native DVs when they join the run.",
          kanto="Oak may call it remarkable breeding luck. The rule card calls it perfect DVs.",
          johto="Elm may call it remarkable genetics. The rule card calls it perfect DVs.",
      },
      perfect_wild_ivs = {
          t1="Perfect Wild DVs are enabled.",
          t2="New wild Pokemon arrive with perfect native DVs.",
          kanto="Kanto's grass is apparently hiding nothing but genetic overachievers today.",
          johto="Johto's grass is apparently hiding nothing but genetic overachievers today.",
      },
      perfect_trainer_ivs = {
          t1="Perfect Trainer DVs are enabled.",
          t2="New trainer parties arrive with perfect native DVs.",
          kanto="Kanto's Trainers found the premium breeding program before you did.",
          johto="Johto's Trainers found the premium breeding program before you did.",
      },
      difficulty_profile = {
          t1="Game Difficulty profile selected.",
          t2="Future trainer battles use the selected difficulty owner and composition rules.",
          kanto="Kanto's Trainers have read the difficulty memo. Future battles follow the selected profile.",
          johto="Johto's Trainers have read the difficulty memo. Future battles follow the selected profile.",
      },
      locke_type = {
          t1="Nuzlocke Loadout selected.",
          t2="The loadout filled in your challenge rules; you can still tune them before sealing.",
          kanto="Your Kanto rule card has a starting template. Customize it before the ink dries.",
          johto="Your Johto rule card has a starting template. Customize it before the ink dries.",
      },
      rules_locked = {
          t1="Permanent Rule Seal is active.",
          t2="The rule card is sealed. You can read it, but you cannot rewrite it.",
          kanto="The Kanto challenge ledger is sealed in ink. No mid-run bargaining now.",
          johto="The Johto challenge ledger is sealed in ink. No mid-run bargaining now.",
      },
      automatic_default_names = {
          t1="Default Names will skip the new-game naming menus.",
          t2="The paperwork is prefilled. Your journey can get moving faster.",
          kanto="Oak already filled out the name cards. No need to hold up the departure.",
          johto="Elm's paperwork is ready. The adventure does not need another form to fill out.",
      },
      skip_opening_intro = {
          t1="Opening Intro skipping is enabled for a fresh run.",
          t2="Oak's presentation is skipped, but the engine's real fresh-game transition still runs.",
          kanto="Oak filed the introduction already. Start the journey in Pallet without replaying the lecture.",
          johto="Oak can spare the lecture. The clock still gets set before Johto begins.",
      },
      quick_nuzlocke_start = {
          t1="Quick Nuzlocke Start is enabled for this fresh run.",
          t2="Mandatory pre-capture story is reconciled once, then the run begins with a starter and Poke Balls ready.",
          kanto="Oak filed the early errands for you. Pallet is ready, your starter is registered, and the first real route can count.",
          johto="Elm filed the Mystery Egg report. New Bark is ready, your starter is registered, and Route 29 can finally count.",
      },
      skip_catch_tutorial = {
          t1="Catch Demo skipping is enabled.",
          t2="The lesson is skipped; the story flags still have to do their job.",
          kanto="You've seen a Poke Ball before. Kanto can spare you the demonstration and keep the story moving.",
          johto="You've seen a Poke Ball before. Johto can spare you the demonstration and keep the story moving.",
      },
      skip_cherrygrove_tour = {
          t1="Cherrygrove tour skipping is enabled.",
          t2="The walking lesson can be skipped; the MAP CARD reward and story cleanup still run.",
          kanto="This option is Gen 2-only and has no Kanto effect.",
          johto="The Guide Gent can spare your shoes. Say yes, jump to the MAP CARD transition, and keep Johto's story flags intact.",
      },
      automatic_running_shoes = {
          t1="Running Shoes speed assist is enabled.",
          t2="Use HOLD B for manual running or ALWAYS for continuous fast walking.",
          kanto="Kanto is a long walk. Your challenge at least remembered decent shoes.",
          johto="Johto is a long walk. Your challenge at least remembered decent shoes.",
      },
      fast_surf = {
          t1="Fast Surf speed assist is enabled.",
          t2="Use HOLD B for manual fast surfing or ALWAYS for continuous fast surfing.",
          kanto="Kanto's waterways can move at challenge pace without changing Surf progression.",
          johto="Johto's waterways can move at challenge pace without changing Surf progression.",
      },
      pc_starting_vitamins = {
          t1="PC Vitamins are staged for a fresh run.",
          t2="A training kit waits in the PC without cluttering the starting Bag.",
          kanto="Someone stocked the bedroom PC with ten of every Kanto vitamin before departure.",
          johto="Someone stocked the bedroom PC with ten of every Johto vitamin before departure, Zinc included.",
      },
      pc_starting_heal_items = {
          t1="PC Heal Items are staged for a fresh run.",
          t2="A medicine kit waits in the PC without cluttering the starting Bag.",
          kanto="Someone stocked the bedroom PC with ten of each basic healing and status medicine before departure.",
          johto="Someone stocked the bedroom PC with ten of each basic healing and status medicine before departure.",
      },
      catch_info = {
          t1="Catch Info is enabled.",
          t2="Tracked teammates carry their encounter history with them.",
          kanto="The Kanto ledger follows every teammate from route to party screen.",
          johto="The Johto ledger follows every teammate from route to party screen.",
      },
      area_guide_enabled = {
          t1="Area Guide is enabled.",
          t2="The Tracker can show the wider map of available encounter areas.",
          kanto="Kanto's encounter ledger is open to the full map, not just the catches already made.",
          johto="Johto's encounter ledger is open to the full map, not just the catches already made.",
      },
      world_building_tier = {
          t1="World Building uses clear rule feedback.",
          t2="World Building adds challenge personality to rule feedback.",
          kanto="Kanto's NPCs and locations can now sound like they know the challenge you signed up for.",
          johto="Johto's NPCs and locations can now sound like they know the challenge you signed up for.",
      },
      nickname_rule = {
          t1="Nickname: a name is required.",
          t2="No anonymous teammates. Give this Pokemon a real nickname.",
          kanto="Oak's records need a teammate name, not just a species label.",
          johto="Elm's records need a teammate name, not just a species label.",
      },
      no_escape = {
          t1="No Escape: running is disabled.",
          t2="The RUN command is off limits. Finish the wild battle.",
          kanto="Kanto's wilds get a full answer today. No turning tail once the battle starts.",
          johto="Johto's wilds get a full answer today. No turning tail once the battle starts.",
      },
  }

  -- 2.6.63: dialogue-quality floor.  Every catalogue row is normalized
  -- to at least three preset choices at every tier/region.  Existing authored
  -- pools are preserved.  String rows gain two concise semantic alternates;
  -- these remain presentation-only and never change the rule result.
  local function ensureThree(value, tier)
      local out = {}
      if type(value) == "table" then
          for _, line in ipairs(value) do
              if type(line) == "string" and line ~= "" then out[#out + 1] = line end
          end
      elseif type(value) == "string" and value ~= "" then
          out[1] = value
      end
      local base = out[1] or "Rule blocked."
      local prefixes = tier == "t1"
          and { "Challenge rule: ", "Rule reminder: " }
          or tier == "t2"
          and { "Challenge note: ", "The rulebook says: " }
          or { "Run bulletin: ", "Challenge report: " }
      local n = 1
      while #out < 3 do
          out[#out + 1] = prefixes[n] .. base
          n = (n % #prefixes) + 1
      end
      return out
  end

  for _, row in pairs(mod.exports.__beta26.worldRuleCatalog) do
      if type(row) == "table" then
          row.t1 = ensureThree(row.t1, "t1")
          row.t2 = ensureThree(row.t2, "t2")
          row.kanto = ensureThree(row.kanto, "t3")
          row.johto = ensureThree(row.johto, "t3")
      end
  end

  local dialogueSessionLast = {}
  local function editionId(game)
      local Dev = mod.exports.__beta26.Dev
      if Dev and type(Dev.gameId) == "function" then
          local ok, id = pcall(Dev.gameId, game)
          if ok and type(id) == "string" then return id end
      end
      return mod.exports.__beta26.runtimeIsGen2(game) and "gold" or "red"
  end

  -- Persistent per-run rotation state guarantees that the same choice is never
  -- returned twice in a row for the same edition/tier/rule.  Selection is a
  -- simple cycle, not RNG, so presentation cannot perturb gameplay randomness.
  local function rotateDialogue(game, key, tier, pool)
      if type(pool) ~= "table" or #pool == 0 then return nil end
      if #pool == 1 then return pool[1] end
      local token = table.concat({ editionId(game), tostring(tier),
          tostring(key) }, ":")
      local storageKey = "world_dialogue_last:" .. token
      local canPersist = game and game.save and not saveBlocked()
      local last
      if canPersist then
          last = tonumber(mod.save:get(storageKey, 0)) or 0
      else
          last = tonumber(dialogueSessionLast[token] or 0) or 0
      end
      local index = (math.floor(last) % #pool) + 1
      if canPersist then
          local ok, result = pcall(mod.save.set, mod.save, storageKey, index)
          if not ok or result == false then
              dialogueSessionLast[token] = index
          end
      else
          dialogueSessionLast[token] = index
      end
      return pool[index]
  end

  -- 2.6.62: make the long-standing semantic contract explicit.  A plain
  -- enforcement explanation is mandatory player feedback, not optional World
  -- Building flavor.  OFF and T1 therefore share the explanation; T2/T3 may
  -- embellish it, but legality never depends on presentation.
  local function rowText(value, fallback)
      if type(value) == "table" then return value[1] or fallback end
      return value or fallback
  end

  mod.exports.__beta26.ruleExplanation = function(key, fallback, game)
      local row = mod.exports.__beta26.worldRuleCatalog[tostring(key or "")]
      if type(row) ~= "table" then return Strings(fallback or "Rule blocked.") end
      return Strings(rotateDialogue(game, key, 1, row.t1)
          or rowText(row.t1, fallback or "Rule blocked."))
  end

  -- T2/T3 use the same no-repeat rotation contract. Run-summary context
  -- belongs only on explicitly recap-oriented surfaces; generic rule/world
  -- dialogue must not append an unrelated extra page.
  mod.exports.__beta26.worldFlavorText = function(game, key, tier,
      fallback2, fallback3)
      local row = mod.exports.__beta26.worldRuleCatalog[tostring(key or "")]
      if type(row) ~= "table" then
          return tier >= 3 and (fallback3 or fallback2)
              or (tier >= 2 and fallback2 or nil)
      end
      if tier >= 3 then
          local region = mod.exports.__beta26.runtimeIsGen2(game)
              and "johto" or "kanto"
          local text = rotateDialogue(game, key, 3, row[region])
              or fallback3 or rowText(row.t2, fallback2)
              or rowText(row.t1, "Rule blocked.")
          return Strings(text)
      end
      if tier >= 2 then
          return Strings(rotateDialogue(game, key, 2, row.t2)
              or rowText(row.t2, fallback2)
              or rowText(row.t1, "Rule blocked."))
      end
      return nil
  end

  mod.exports.__beta26.worldRuleTriplet = function(game, key, fallback1, fallback2, fallback3)
      local explanation = mod.exports.__beta26.ruleExplanation(key, fallback1, game)
      local t2 = mod.exports.__beta26.worldFlavorText(
          game, key, 2, fallback2, fallback3) or explanation
      local t3 = mod.exports.__beta26.worldFlavorText(
          game, key, 3, fallback2, fallback3) or t2
      return explanation, t2, t3
  end

  mod.exports.__beta26.worldRuleText = function(game, key, fallback1, fallback2, fallback3)
      local tier = worldTier(game)
      if tier <= 1 then
          return mod.exports.__beta26.ruleExplanation(key, fallback1, game)
      end
      return mod.exports.__beta26.worldFlavorText(
          game, key, tier, fallback2, fallback3)
          or mod.exports.__beta26.ruleExplanation(key, fallback1, game)
  end

  -- 2.5.59: source-level dead-fallback audit. worldRuleTriplet/worldRuleText
  -- deliberately use catalog text whenever a literal key exists, so fallback
  -- arguments on those calls are unreachable and usually signal an author
  -- expected dynamic/custom text that can never render. Reject that shape at
  -- module load instead of letting another silent dialogue regression ship.

  local function safeSourceRead(path)
      local ok, content = pcall(mod.read, mod, path)
      if ok and type(content) == "string" then return content end
      return nil
  end

  mod.exports.__beta26.deadFallbackAudit = function(source)
      local report = { ok = true, checked = 0, failures = {} }
      if type(source) ~= "string" then
          report.ok = false
          report.failures[1] = "main.lua source unavailable"
          return report
      end
      for _, functionName in ipairs({ "worldRuleTriplet", "worldRuleText" }) do
          local pattern = functionName
              .. "%s*%(%s*[%w_%.]+%s*,%s*[\"']([%w_]+)[\"']%s*,"
          for key in source:gmatch(pattern) do
              report.checked = report.checked + 1
              if type(mod.exports.__beta26.worldRuleCatalog[key]) == "table" then
                  report.ok = false
                  report.failures[#report.failures + 1] = functionName
                      .. ":" .. tostring(key) .. ":dead fallback arguments"
              end
          end
      end
      return report
  end

  do
      -- 2.7.60: this is a presentation/source lint, not gameplay authority.
      -- Keep startup usable when source wording or packaging drifts; preserve
      -- the exact report for Dev/Release Safety, which remains promotion-blocking.
      local mainSource = safeSourceRead("main.lua")
      local worldSource = safeSourceRead("world_building.lua")
      if mainSource and worldSource then
          local report = mod.exports.__beta26.deadFallbackAudit(mainSource .. "\n" .. worldSource)
          mod.exports.__beta26.deadFallbackStartup = report
          if report.ok ~= true and mod.log and type(mod.log.warn) == "function" then
              mod.log:warn("[Nuzlocke] World Building dead-fallback lint drift: %s",
                  table.concat(report.failures or {}, "; "))
          end
      end
  end

  -- 2.5.60: semantic golden snapshot for the catalog-driven dialogue surface.
  -- The checksum is built from sorted catalog keys plus their T1/T2/Kanto/Johto
  -- strings, so harmless source formatting/comments do not matter while missing
  -- rows, missing regional/tier text, renamed keys, or unintended wording drift
  -- fail fast. Intentional catalog edits must deliberately refresh the golden.
  mod.exports.__beta26.catalogSnapshotAudit = function()
      local catalog = mod.exports.__beta26.worldRuleCatalog
      -- 2.6.93: keep the golden key identities explicit instead of maintaining
      -- disconnected magic counts. Legitimate catalog edits still require an
      -- intentional golden refresh, but failures now name missing/unexpected
      -- rows and derive the edition/tier total from the approved key set.
      local expectedKeys = {
          "no_catching",
          "progression_pc_catches",
          "progression_pc_lock",
          "progression_pc_full",
          "encounter_area",
          "dupes",
          "type_lock_mode",
          "type_lock_draft",
          "type_lock_primary",
          "type_lock_secondary",
          "type_lock_tertiary",
          "type_lock_quaternary",
          "type_lock_quinary",
          "type_lock_senary",
          "no_day_care",
          "overworld_encounters",
          "town_catches",
          "ban_legendaries",
          "ban_mythicals",
          "ban_pseudos",
          "pkmn_ban",
          "allow_gifts",
          "allow_trades",
          "no_static_encounters",
          "maximum_bst",
          "allow_glitch_pokemon",
          "party_size_limit",
          "gym_team_size",
          "no_rare_candy_use",
          "no_player_stat_exp_gain",
          "no_tm_use",
          "level_cap_scope",
          "no_pp_items",
          "no_repels",
          "no_fishing",
          "no_escape_rope",
          "no_field_healing",
          "no_healing_items",
          "no_battle_items",
          "no_buying",
          "no_selling",
          "no_poke_center",
          "no_mom_heal",
          "no_gambling",
          "gym_lock_in",
          "dungeon_lock_in",
          "route_forgiveness_award",
          "route_forgiveness_used",
          "failed_encounter",
          "encounter_armed",
          "permadeath",
          "first_rival_forgiveness",
          "whiteout_clause",
          "blackout",
          "exp_edging",
          "trainer_money_multiplier",
          "nuzlocke_enabled",
          "encounter_limit",
          "route_forgiveness",
          "dupes_mode",
          "shiny_clause",
          "route_2_split",
          "route_10_split",
          "route_20_split",
          "mt_moon_splits",
          "safari_zone_splits",
          "random_starter",
          "random_species_generation",
          "randomizer_seed",
          "random_starter_style",
          "random_starter_balance",
          "random_starter_trio_typing",
          "random_starter_rerolls",
          "random_field_items",
          "random_field_item_balance",
          "random_field_item_repetition",
          "random_encounter_balance",
          "random_encounter_repetition",
          "random_encounter_diversity_strength",
          "randomizer_info_policy",
          "physical_special_split",
          "player_start_stat_exp",
          "wild_start_stat_exp",
          "trainer_start_stat_exp",
          "perfect_player_ivs",
          "perfect_wild_ivs",
          "perfect_trainer_ivs",
          "difficulty_profile",
          "locke_type",
          "rules_locked",
          "automatic_default_names",
          "skip_opening_intro",
          "quick_nuzlocke_start",
          "skip_catch_tutorial",
          "skip_cherrygrove_tour",
          "automatic_running_shoes",
          "fast_surf",
          "pc_starting_vitamins",
          "pc_starting_heal_items",
          "catch_info",
          "area_guide_enabled",
          "world_building_tier",
          "nickname_rule",
          "no_escape",
      }
      local expectedKeySet = {}
      for _, key in ipairs(expectedKeys) do expectedKeySet[key] = true end
      local report = { ok = true, failures = {}, key_count = 0,
          resolved_combinations = 0, checksum = 0, expected_checksum = 513036232,
          expected_key_count = #expectedKeys }
      if type(catalog) ~= "table" then
          report.ok = false
          report.failures[1] = "worldRuleCatalog unavailable"
          return report
      end

      local keys = {}
      for key, row in pairs(catalog) do
          report.key_count = report.key_count + 1
          keys[#keys + 1] = tostring(key)
          if type(row) ~= "table" then
              report.ok = false
              report.failures[#report.failures + 1] = tostring(key) .. ":row missing"
          else
              for _, field in ipairs({ "t1", "t2", "kanto", "johto" }) do
                  local value = row[field]
                  local valid = type(value) == "table" and #value >= 3
                  if valid then
                      for _, line in ipairs(value) do
                          if type(line) ~= "string" or line == "" then
                              valid = false
                              break
                          end
                      end
                  end
                  if not valid then
                      report.ok = false
                      report.failures[#report.failures + 1] = tostring(key)
                          .. ":missing " .. field
                  end
              end
          end
      end
      table.sort(keys)
      local actualKeySet = {}
      for _, key in ipairs(keys) do actualKeySet[key] = true end
      for _, key in ipairs(expectedKeys) do
          if not actualKeySet[key] then
              report.ok = false
              report.failures[#report.failures + 1] = "missing key " .. key
          end
      end
      for _, key in ipairs(keys) do
          if not expectedKeySet[key] then
              report.ok = false
              report.failures[#report.failures + 1] = "unexpected key " .. key
          end
      end

      local chunks = {}
      for _, key in ipairs(keys) do
          local row = catalog[key]
          if type(row) == "table" then
              local function snapshotValue(value)
                  if type(value) == "table" then
                      return table.concat(value, string.char(29))
                  end
                  return tostring(value or "")
              end
              chunks[#chunks + 1] = table.concat({ key, snapshotValue(row.t1),
                  snapshotValue(row.t2), snapshotValue(row.kanto),
                  snapshotValue(row.johto) }, string.char(31))
          else
              chunks[#chunks + 1] = key .. string.char(31)
          end
      end
      local canonical = table.concat(chunks, string.char(30))
      local hash = 0
      for i = 1, #canonical do
          hash = (hash * 131 + string.byte(canonical, i)) % 2147483647
      end
      report.checksum = hash
      -- Five exact editions x three tiers. Each resolved edition/tier
      -- owns a pool of at least three preset choices.
      report.resolved_combinations = report.key_count * 3 * 5
      report.minimum_variants_per_tier = 3
      report.exact_edition_tier_surfaces = report.resolved_combinations
      report.minimum_preset_options = report.key_count * 5 * 3 * 3

      if report.key_count ~= report.expected_key_count then
          report.ok = false
          report.failures[#report.failures + 1] = "key count "
              .. tostring(report.key_count) .. " != "
              .. tostring(report.expected_key_count)
      end
      local expectedResolved = report.expected_key_count * 3 * 5
      if report.resolved_combinations ~= expectedResolved then
          report.ok = false
          report.failures[#report.failures + 1] = "resolved combinations "
              .. tostring(report.resolved_combinations) .. " != "
              .. tostring(expectedResolved)
      end
      if report.checksum ~= report.expected_checksum then
          report.ok = false
          report.failures[#report.failures + 1] = "checksum "
              .. tostring(report.checksum) .. " != "
              .. tostring(report.expected_checksum)
      end
      return report
  end

  do
      local report = mod.exports.__beta26.catalogSnapshotAudit()
      -- 2.7.59: this catalogue is presentation-only. A stale semantic golden
      -- must never prevent the entire Nuzlocke mod from loading. Preserve the
      -- audit result for Dev/Release Safety and emit a bounded warning instead;
      -- Release Safety remains responsible for blocking promotion when drift is
      -- real, while players retain a usable ruleset if documentation/flavor
      -- text changed without an intentional golden refresh.
      mod.exports.__beta26.catalogSnapshotStartup = report
      if report.ok ~= true and mod.log and type(mod.log.warn) == "function" then
          mod.log:warn("[Nuzlocke] World Building catalog snapshot drift: %s",
              table.concat(report.failures or {}, "; "))
      end
  end

  -- 2.6.62: delivery coverage complements the semantic enforcement
  -- matrix.  The enforcement matrix proves who owns legality; this matrix
  -- proves that a blocked player action has an intentional explanation/flavor
  -- route on each supported backend.  `presentation` keys must exist in the
  -- catalog; dynamic details (BST/type lists/etc.) may be appended by callers.
  local WORLD_BUILDING_DELIVERY_COVERAGE = {
      capture_attempt={rules={"no_catching","encounter_limit","dupes_mode","overworld_encounters","town_catches","ban_legendaries","ban_mythicals","ban_pseudos","pkmn_ban","no_static_encounters","allow_glitch_pokemon","party_size_limit","type_lock_mode","maximum_bst"},presentation={"no_catching","encounter_area","dupes","overworld_encounters","town_catches","ban_legendaries","ban_mythicals","ban_pseudos","pkmn_ban","no_static_encounters","allow_glitch_pokemon","party_size_limit","type_lock_mode","maximum_bst"},rby="catchRejectionMessage",gen2="catchRejectionMessage"},
      special_acquisition={rules={"allow_gifts","allow_trades","ban_legendaries","ban_mythicals","ban_pseudos","maximum_bst","party_size_limit"},presentation={"allow_gifts","allow_trades","ban_legendaries","ban_mythicals","ban_pseudos","maximum_bst","party_size_limit"},rby="specialAcquisitionDenied presenter",gen2="specialAcquisitionDenied presenter"},
      daycare_deposit={rules={"no_day_care"},presentation={"no_day_care"},rby="Day Care gate",gen2="Gen2/custom Day Care gate"},
      purchase_commit={rules={"no_buying"},presentation={"no_buying"},rby="Mart gate",gen2="Mart gate"},
      sale_commit={rules={"no_selling"},presentation={"no_selling"},rby="Mart gate",gen2="Mart gate"},
      center_heal={rules={"no_poke_center"},presentation={"no_poke_center"},rby="Center gate",gen2="nurse gate"},
      mom_heal={rules={"no_mom_heal"},presentation={"no_mom_heal"},rby="Mom gate",gen2="Mom gate"},
      field_item={rules={"no_rare_candy_use","no_pp_items","no_repels","no_escape_rope","no_field_healing","no_tm_use"},presentation={"no_rare_candy_use","no_pp_items","no_repels","no_escape_rope","no_field_healing","no_tm_use"},rby="item policy presenter",gen2="field item gate"},
      battle_item={rules={"no_healing_items","no_battle_items","no_pp_items"},presentation={"no_healing_items","no_battle_items","no_pp_items"},rby="battle item gate",gen2="battle item gate"},
      gambling={rules={"no_gambling"},presentation={"no_gambling"},rby="Game Corner gate",gen2="Game Corner gate"},
      gym_exit={rules={"gym_lock_in"},presentation={"gym_lock_in"},rby="warp.destination",gen2="warp.destination"},
      dungeon_exit={rules={"dungeon_lock_in"},presentation={"dungeon_lock_in"},rby="warp/field travel gates",gen2="warp/field travel gates"},
      pc_progression={rules={"progression_pc_catches"},presentation={"progression_pc_lock","progression_pc_full"},rby="PC policy presenter",gen2="PC policy presenter"},
      whiteout={rules={"whiteout_clause"},presentation={"whiteout_clause","blackout"},rby="whiteout presenter",gen2="whiteout presenter"},
      rival_mercy={rules={"first_rival_forgiveness"},presentation={"first_rival_forgiveness"},rby="trainer flavor/recovery",gen2="trainer flavor/recovery"},
  }
  mod.exports.__beta26.worldBuildingDeliveryCoverage = function()
      local out = {}
      for id, row in pairs(WORLD_BUILDING_DELIVERY_COVERAGE) do
          local copy = {}
          for k, value in pairs(row) do
              if type(value) == "table" then
                  local list = {}
                  for i, item in ipairs(value) do list[i] = item end
                  copy[k] = list
              else copy[k] = value end
          end
          out[id] = copy
      end
      return out
  end

  mod.exports.__beta26.worldBuildingDeliveryAudit = function()
      local report = { ok=true, checked=0, failures={} }
      local catalog = mod.exports.__beta26.worldRuleCatalog or {}
      for id, row in pairs(WORLD_BUILDING_DELIVERY_COVERAGE) do
          report.checked = report.checked + 1
          if type(row.rules) ~= "table" or #row.rules == 0
              or type(row.presentation) ~= "table" or #row.presentation == 0
              or type(row.rby) ~= "string" or row.rby == ""
              or type(row.gen2) ~= "string" or row.gen2 == "" then
              report.ok = false
              report.failures[#report.failures + 1] = id .. ":incomplete row"
          end
          for _, key in ipairs(row.presentation or {}) do
              report.checked = report.checked + 1
              if type(catalog[key]) ~= "table" then
                  report.ok = false
                  report.failures[#report.failures + 1] =
                      id .. ":missing presentation " .. tostring(key)
              end
          end
      end
      return report
  end

  do
      local report = mod.exports.__beta26.worldBuildingDeliveryAudit()
      mod.exports.__beta26.worldBuildingDeliveryStartup = report
      if report.ok ~= true and mod.log and type(mod.log.warn) == "function" then
          mod.log:warn("[Nuzlocke] World Building delivery coverage drift: %s",
              table.concat(report.failures or {}, "; "))
      end
  end

  mod.exports.__beta26.catchRejectionMessage = function(game, reason, species)
      local keyByReason = {
          area = "encounter_area", dupes = "dupes",
          overworld = "overworld_encounters", town = "town_catches",
          legendary = "ban_legendaries", mythical = "ban_mythicals",
          pseudo = "ban_pseudos", pkmn_ban = "pkmn_ban",
          static = "no_static_encounters",
          glitch = "allow_glitch_pokemon",
          party_size = "party_size_limit",
          no_catching = "no_catching", type_lock = "type_lock_mode",
          progression_pc_full = "progression_pc_full",
      }
      if reason == "type_lock" then
          local allowed = mod.exports.__beta26.typeLockAllowedTypes()
          local labels = {}
          for _, key in ipairs(allowed) do
              labels[#labels + 1] = key == "PSYCHIC_TYPE" and "PSYCHIC" or key
          end
          local base = mod.exports.__beta26.worldRuleText(game, "type_lock_mode")
          if #labels > 0 then
              return Strings("%s\nAllowed: %s", tostring(base), table.concat(labels, " / "))
          end
          return base
      end
      if reason == "bst" then
          local bst = mod.exports.__beta26.getSpeciesBST(game, species)
          local limit = mod.exports.__beta26.getMaximumBST()
          local base = mod.exports.__beta26.worldRuleText(game, "maximum_bst")
          return Strings("%s\nBST: %s / Limit: %s", tostring(base),
              tostring(bst or "?"), tostring(limit or "?"))
      end
      local key = keyByReason[reason]
      if key then return mod.exports.__beta26.worldRuleText(game, key) end
      return Strings("That catch is not allowed by your Nuzlocke rules.")
  end

  -- 2.6.19: the Maximum BST rejection used to compute the live species BST
  -- and configured limit but discard both values after the dead-fallback lint
  -- repair. Keep a narrow source-level guard so future cleanup cannot silently
  -- regress the concrete detail while still returning valid catalog text.
  mod.exports.__beta26.maximumBstMessageDetailAudit = function(source)
      local report = { ok = true, failures = {} }
      if type(source) ~= "string" then
          report.ok = false
          report.failures[1] = "world_building.lua source unavailable"
          return report
      end
      local branch = source:match('if reason == "bst" then(.-)\n%s*end') or ""
      local required = {
          'getSpeciesBST(game, species)',
          'getMaximumBST()',
          'worldRuleText(game, "maximum_bst")',
          'BST: %s / Limit: %s',
          'tostring(bst or "?")',
          'tostring(limit or "?")',
      }
      for _, needle in ipairs(required) do
          if not branch:find(needle, 1, true) then
              report.ok = false
              report.failures[#report.failures + 1] = "missing " .. needle
          end
      end
      return report
  end

  do
      local source = safeSourceRead("world_building.lua")
      if source then
          local report = mod.exports.__beta26.maximumBstMessageDetailAudit(source)
          mod.exports.__beta26.maximumBstMessageDetailStartup = report
          if report.ok ~= true and mod.log and type(mod.log.warn) == "function" then
              mod.log:warn("[Nuzlocke] Maximum BST presentation-detail drift: %s",
                  table.concat(report.failures or {}, "; "))
          end
      end
  end


  return { worldTier = worldTier }
end
