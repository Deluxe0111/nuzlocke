# Generation 3 beta — implementation overview

**Release:** Nuzlocke **v3.0.0-BETA** · **Mod API:** 2 · **Save namespace:** `gen3_classic_v1`

Nuzlocke runs a separate Generation 3 implementation through
[`entry.lua`](../entry.lua). The established `main.lua` continues to
serve Red, Blue, Yellow, Gold, Silver and Crystal. The beta targets
FireRed, LeafGreen, Ruby, Sapphire and Emerald.

**NEW GAME integration (restored from PR #20):** FRLG and RS/Emerald
open NEW RUN SETUP before entering the native intro. The player can
configure the same CORE/CLAUSES/ADVANCED RULES pages as in-game,
adjust the five QoL starting resources, and choose **LOCK FOR RUN**
before selecting START NEW GAME. Cancelling leaves the prior save
unchanged. The run lock is enforced by every working rule-category
setter for the duration of the new save; Dev tools remain separate.
The Gen 3 encounter ledger ignores pre-Ball wild fights entirely.
Once the player has physically carried a native Ball (or a previous
successful catch proves unlock), the encounter ledger stays unlocked
even if all Balls are later spent. Extra QoL starting Balls are not
available until that native capture boundary, and are delivered to
Player PC exactly once. No engine changes are required.

The Generation 3 menu is designed for a GBA-native 240×160 screen.
Unported options are shown as **[Soon]** and do not silently change
gameplay. NUZ RULES keeps CORE, CLAUSES, HARDCORE, GAME DIFFICULTY,
RUN / PARTY, LEVELS, PLAYSTYLES, RANDOMIZER, QOL and QOL SETUP ONLY at
the top level, plus **ADVANCED RULES** directly after PLAYSTYLES.
ADVANCED RULES contains Catch Rules, Battle Clauses, Status Bans,
Variants, Battle Items, Field Items, Services & Economy, Pokémon Stats
and Area Splits. **CATCH RULES now has seventeen working controls:**
Town Catches, No Legendaries, No Mythicals, No Pseudos, Maximum BST,
No Static Encounters, No Fishing, Alphabetlocke mode/letter,
Allow Glitches, Gift Pokémon/Gift Slot Policy, In-Game
Trades/Trade Slot Policy, PKMN BAN's National Dex picker, and
Colorlocke mode/colour. Native gift opcodes and NPC swaps are
guarded before mutation. The canonical National Dex ban list also
filters Nuzlocke's built-in randomiser replacement pools.
The redundant Gen 3 Overworld Encounters row was removed: Untamed-
Advanced's wandering wild Pokémon use normal Nuzlocke catch/area
logic without a separate switch. Six other advanced groups remain
placeholders.
See [Advanced Rules](GEN3_ADVANCED_RULES.md) for enforcement and tests.
**BATTLE CLAUSES** now exposes Flinch, Trap, No Setup Moves, Evasion
Clause, Accuracy Drops and Other Stat Drops as six working effect-level
restrictions (see [Battle Clauses](GEN3_BATTLE_CLAUSES.md)).
OHKO Clause remains [Soon].
**STATUS BANS** adds eight working controls (No Status Moves bulk parent,
six individual status scopes and a separate ON/OFF Sleep Clause). The
Sleep Clause tracks inflicted sleep across switches within the battle;
Rest/self-induced sleep is exempt.
**VARIANTS** now implements Type Locke OFF/MONO/DUO/TRI/QUAD/PENTA/HEXA
with six conditionally visible type selectors, saved deterministic RANDOM
types, and species eligibility checks for wilds (including Untamed),
optional gifts and NPC trades. **Catch Draft** is also implemented:
successful wild catches establish unique type lanes, drafts persist,
and optional gifts/trades must match already drafted types without
filling new lanes. Wonderlocke remains [Soon].
**BATTLE ITEMS** now has four working controls: No Healing Items,
No X Items, No Catching, and Ball Per Encounter (OFF/1/2/3/5/10).
Denials occur before native bag consumption; only eligible Ball
transactions count towards each wild battle's budget.
No Catching prevents wild battles from claiming an encounter slot.
**FIELD ITEMS** adds seven working restrictions: No Repels,
No Escape Rope, player-initiated Fly/Teleport Travel Restrictions,
No Field Heal, No PP Items (including battle), No TMs (HM exempt),
and No Rare Candy. Field bag, direct TM/PP/Rare Candy and native party
paths are intercepted before mutation. Three other advanced categories
remain [Soon]. See [Status Bans](GEN3_STATUS_BANS.md),
[Variants](GEN3_VARIANTS.md), [Battle Items](GEN3_BATTLE_ITEMS.md)
and [Field Items](GEN3_FIELD_ITEMS.md).
The unimplemented WORLD and UI planning categories have been removed
from Gen 3's catalog/menu only; Gen 1/2 are unchanged.

ALMANAC and MOD COMPAT are separate [Soon] placeholders on the Gen 3
NUZ MENU. The former was a read-only run recap in legacy Nuzlocke
(catches, deaths, progress, rule integrity, randomiser metadata);
the latter allowed compatible external mod capability ownership
selection where a safe integration contract existed. Neither screen
is implemented for Gen 3 yet.

Feature availability and runtime certification are separate:
a working toggle is not proof that every edition and edge case is tested.

## What works now

| Feature | Behaviour and reference |
| --- | --- |
| **CORE** | Nuzlocke Enabled, Permadeath, One Encounter Per Area, Failed Encounters, Nickname Requirement, First Rival Mercy, Whiteout Ends Run and PC Survivors Allowed. See [CORE specification](GEN3_CORE_SPEC.md). |
| **CLAUSES** | Dupes, Shiny Catch Exception, Shiny Rate, Roamer Clause, Egg Encounter and Route Forgiveness. See [Clauses](GEN3_CLAUSES.md) and [Eggs and Forgiveness](GEN3_EGGS_FORGIVENESS.md). |
| **PLAYSTYLES** | **Shiny Nuzlocke** restricts catches to shinies; **Hardcore Nuzlocke** forces strict encounter/death rules, SET style, no battle items except Balls, and Gym/League caps through Champion. Modes may combine. See [Playstyles](GEN3_PLAYSTYLES.md). |
| **LEVELS** | Gym/Elite Four/Champion/Postgame cap scopes, native EXP clamping and optional EXP banking (EXP Edging). Native Rare Candy checks. See [LEVELS](GEN3_LEVELS.md). |
| **RANDOMIZER** | Seeded normal wild step and fishing encounters and trainer species, with fixed/AUTO seed, presets, generation limits and BST balancing. See [Randomiser](GEN3_RANDOMIZER.md). |
| **Overworld wild compatibility** | Untamed-Advanced's generated wandering Pokémon use the same Random Wild setting/seed via `untamed.owe.species`, before the sprite and battle are constructed. |
| **Player feedback** | Rule explanations during relevant native battles plus a persistent NUZ NOTICES history. See [Feedback](GEN3_FEEDBACK.md). |
| **Player tools** | Native encounter tracker, graveyard, nickname tasks and Nuz Dev test utilities. See [Nuz Dev](GEN3_NUZ_DEV.md). |

### Encounter and death handling

The first eligible wild encounter is recorded against its **native map ID**.
With Failed Encounters enabled, that attempt spends the area even if the
Pokémon escapes or faints; when **Shiny Nuzlocke** is active, only an
eligible *shiny* attempt can spend the area. When Failed Encounters is
disabled, the first eligible successful
catch closes the area. Dupes and Shiny eligibility are resolved before
claiming the route. Native Balls still run through the normal catch
transaction, which explains denial reasons.

A player Pokémon that faints is recorded for Permadeath in the battle
and moved to the save-local graveyard after the native battle completes.
The mod does not delete the native save. Whiteout Ends Run takes priority
over rescuing a living eligible PC survivor. Gifts/trades/hatched Pokémon
without custom nicknames are listed under Nickname Tasks; some non-catch
naming and battle-eligibility edge cases still require testing.

### Random Wild + Untamed-Advanced

Untamed's generated overworld encounters do not use Gen 3's regular
`encounter.species` hook. The compatible Untamed branch exposes
`untamed.owe.species`, which Nuzlocke supplies with a seed-stable
replacement **before sprite rendering, cry, and the ensuing wild battle**.

- The visible species is the one battled and caught.
- Replacements use the same Random Wild settings and seeded candidate pool.
- The chain popup tracks the **visible, defeated species** (e.g.,
  Feraligatr instead of the original Rattata encounter slot). Untamed
  privately retains the original slot for repeated-spawn odds.
- Followers, roamers, outbreaks, Feebas specials and manually scripted
  actors are excluded from this hook.
- Untamed works without Nuzlocke; Nuzlocke's usual step encounters work
  without Untamed. Both compatible builds are needed for the integration.

[Untamed-Advanced](https://github.com/Deluxe0111/Untamed-Advanced) documents
its own follower, overworld-wild and encounter-chain features and credits
the Nuzlocke compatibility integration there.

## Known beta boundaries

- Not all Gen 1/2 modes, optional clauses, shops, items, starters, gifts,
  static species, evolutions or move randomisation have Gen 3 adapters.
- Route tracking currently uses **map IDs** rather than canonical
  multi-floor area groupings.
- Field/story revival, non-catch nickname eligibility, unusual trainer
  modes, special scripted losses, link/facility encounters and certain
  item-provider overlaps still need native-ROM validation.
- Randomiser seed/settings lock after first successful replacement to
  prevent contradictory mappings on the same save.
- Some UI/archive state displays additional detail but is not a PC-stored
  resurrectable Pokémon. Back up saves before testing death/whiteout paths.

## Testing and reference material

Run the isolated Gen 3 Lua checks under `.github/workflows/gen3-smoke.yml`
or follow [Gen 3 test checklist](GEN3_TEST_CHECKLIST.md). The
[Randomiser checklist](GEN3_RANDOMIZER.md) includes an Untamed-specific
visible-spawn, species-matching and chain test section.

**Passing mocked tests does not guarantee real-ROM behaviour.** Test
FireRed, LeafGreen, Ruby, Sapphire and Emerald separately on disposable
saves, and retest combinations of installed mods.
