# Generation 3 beta — implementation overview

**Release:** Nuzlocke **v3.0.0-BETA** · **Mod API:** 2 · **Save namespace:** `gen3_classic_v1`

Nuzlocke runs a separate Generation 3 implementation through
[`entry.lua`](../entry.lua). The established `main.lua` continues to
serve Red, Blue, Yellow, Gold, Silver and Crystal. The beta targets
FireRed, LeafGreen, Ruby, Sapphire and Emerald.

The Generation 3 menu is designed for a GBA-native 240×160 screen.
Unported options are shown as **[Soon]** and do not silently change
gameplay. Feature availability and runtime certification are separate:
a working toggle is not proof that every edition and edge case is tested.

## What works now

| Feature | Behaviour and reference |
| --- | --- |
| **CORE** | Nuzlocke Enabled, Permadeath, One Encounter Per Area, Failed Encounters, Nickname Requirement, First Rival Mercy, Whiteout Ends Run and PC Survivors Allowed. See [CORE specification](GEN3_CORE_SPEC.md). |
| **CLAUSES** | Dupes, Shiny Catch Exception, Shiny Rate, Roamer Clause, Egg Encounter and Route Forgiveness. See [Clauses](GEN3_CLAUSES.md) and [Eggs and Forgiveness](GEN3_EGGS_FORGIVENESS.md). |
| **LEVELS** | Gym/Elite Four/Champion/Postgame cap scopes, native EXP clamping and optional EXP banking (EXP Edging). Native Rare Candy checks. See [LEVELS](GEN3_LEVELS.md). |
| **RANDOMIZER** | Seeded normal wild step and fishing encounters and trainer species, with fixed/AUTO seed, presets, generation limits and BST balancing. See [Randomiser](GEN3_RANDOMIZER.md). |
| **Overworld wild compatibility** | Untamed-Advanced's generated wandering Pokémon use the same Random Wild setting/seed via `untamed.owe.species`, before the sprite and battle are constructed. |
| **Player feedback** | Rule explanations during relevant native battles plus a persistent NUZ NOTICES history. See [Feedback](GEN3_FEEDBACK.md). |
| **Player tools** | Native encounter tracker, graveyard, nickname tasks and Nuz Dev test utilities. See [Nuz Dev](GEN3_NUZ_DEV.md). |

### Encounter and death handling

The first eligible wild encounter is recorded against its **native map ID**.
With Failed Encounters enabled, that attempt spends the area even if the
Pokémon escapes or faints; when disabled, the first eligible successful
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
