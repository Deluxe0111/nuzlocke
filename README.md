# Nuzlocke v3.0.0-BETA

A configurable Pokémon challenge-rules mod for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp). Supports **Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire and Emerald**.

**Version:** `v3.0.0-BETA` · **Mod API:** 2 · **Gen 3 save key:** `gen3_classic_v1`

Version 3 introduces the native **Generation 3 beta** alongside the established Gen 1/2 implementation. Not every historical Gen 1/2 feature has been ported to Gen 3, and beta status does not imply every supported ROM has completed runtime certification.

## Getting started

1. Install Gen1Recomp and import your own supported game ROM.
2. Install this mod through the game's mod manager (or put the unpacked mod folder under your mods directory).
3. In Generation 3, open **Start → NUZ MENU → NUZ RULES → CORE** and enable **Nuzlocke Enabled**. Other CORE rules can be configured independently.
4. Back up a save before testing changes to Permadeath, Whiteout, PC Survivors, or the Randomiser.

The Generation 3 randomiser works independently of the master Nuzlocke challenge toggle. Configure its seed and settings **before the first randomised result**; its settings then lock for that run.

## Generation 3 beta

| Section | Current features |
| --- | --- |
| **CORE** | Nuzlocke Enabled, Permadeath, One Encounter Per Area, Failed Encounters, Nickname Requirement, First Rival Mercy, Whiteout Ends Run, PC Survivors |
| **CLAUSES** | Dupes, Shiny Catch Exception, Shiny Rate, Roamer, Egg Encounter, Route Forgiveness |
| **PLAYSTYLES** | **Shiny Nuzlocke:** catch only shinies; **Hardcore Nuzlocke:** strict encounters/permadeath, SET style, no battle bag items except Balls, and Champion-level caps. Both modes can be combined. |
| **LEVELS** | Gym / Elite Four / Champion / Postgame level-cap scopes; optional banked EXP Edging |
| **RANDOMIZER** | Seeded wild Pokémon (grass, water and fishing) and trainer teams; presets, species-generation filters and optional BST balancing |
| **ADVANCED RULES** | Nine legacy rule categories live in one submenu. **CATCH RULES** now has four working controls: No Legendaries, No Mythicals, No Pseudos and Maximum BST. Other options remain **[Soon]**. |
| **Player tools** | Encounter Tracker, Graveyard, Nickname Tasks, Nuz Dev testing tools and a persistent NUZ NOTICES history |

Unavailable Gen 1/2 rules are shown as **[Soon]** in Generation 3 rather than silently enabled. The obsolete Gen 3 **WORLD** and **UI** planning categories are hidden; Generation 1/2 menus are unaffected. Some implemented features still require edition-specific game testing; for example, acquiring an unnamed gift Pokémon is tracked but is not necessarily blocked from battle.

### Untamed-Advanced compatibility

With [Untamed Advanced](https://github.com/Deluxe0111/Untamed-Advanced) installed, enabling **Random Wild** also randomises the ordinary Pokémon **wandering visibly in the overworld**. Nuzlocke uses Untamed's optional `untamed.owe.species` hook *before* the overworld sprite and battle opponent are constructed, so the species you see matches what you fight.

- Uses the **same seed, species pool, generation limits and wild balance** as the regular randomiser.
- Keeps each route/terrain/original-species mapping stable across wandering spawn positions.
- Does **not** randomise the player's follower, special roamers, Feebas, outbreaks or scripted overworld encounters.
- Needs a compatible version of **both mods**. Untamed operates normally without Nuzlocke.

See [Gen 3 Randomiser documentation](docs/GEN3_RANDOMIZER.md) for the exact behaviour and test checklist. See [Untamed Advanced's README](https://github.com/Deluxe0111/Untamed-Advanced#readme) for its own features and setup.

## Documentation

| Looking for… | Read |
| --- | --- |
| Generation 3 architecture, implemented scope and remaining gaps | [Gen 3 overview](docs/GEN3_PORT.md) |
| CORE rules and precedence | [CORE specification](docs/GEN3_CORE_SPEC.md) |
| Shiny and Hardcore Nuzlocke rules, tests and compatibility | [PLAYSTYLES](docs/GEN3_PLAYSTYLES.md) |
| Encounter clauses, Eggs and Forgiveness | [Clauses](docs/GEN3_CLAUSES.md) · [Eggs and Forgiveness](docs/GEN3_EGGS_FORGIVENESS.md) |
| Level caps and EXP Edging | [LEVELS](docs/GEN3_LEVELS.md) |
| Randomiser including Untamed overworld integration | [RANDOMIZER](docs/GEN3_RANDOMIZER.md) |
| Notifications and Rare Candy/nickname tests | [Player feedback](docs/GEN3_FEEDBACK.md) |
| In-game regression steps | [Gen 3 test checklist](docs/GEN3_TEST_CHECKLIST.md) |
| Existing Generation 1/2 features and compatibility | [Legacy user guide (2.9.x)](docs/USER_GUIDE.md) · [Compatibility reference](docs/COMPATIBILITY.md) |
| Release history | [Changelog](CHANGELOG.md) · [Release notes](RELEASE_NOTES.md) |
| Mod APIs and developer integration | [API](docs/API.md) · [Gen 3 developer guide](docs/DEVELOPER_GEN3.md) |

## Status and safety

Generation 1/2 and Generation 3 use separate runtime implementations and save structures. **Upgrading to v3.0.0-BETA does not reset existing Nuzlocke records or update the Gen 1/2 save schema.** The package continues to use Mod API 2.

Automated smoke tests check policies and hook contracts. They are **not proof of complete ROM compatibility**; verify each edition and other installed mods on a backed-up save before committing to a run.
