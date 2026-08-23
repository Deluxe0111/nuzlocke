# Nuzlocke 2.7.25

A configurable Nuzlocke ruleset for Gen1Recomp with exact-edition support for **Pokémon Red, Blue, Yellow, Gold, and Silver**.

2.7.25 is the release promotion of exact 2.7.24. It carries forward the completed documentation/code audit, Gen1Recomp 0.2.20 source-compatibility review, and the small Run History baseline-normalization persistence repair without adding new gameplay semantics.

## Highlights

- Core rules: Permadeath, One Per Area, Failed Encounters, Nickname Rule, Dupes modes, Shiny Clause, First Rival Mercy, Whiteout policy, gifts/trades/statics, species bans, and progression-catch handling.
- Difficulty tools: live level caps, Gym/Dungeon Lock-In, Party Size/Gym Team Size, Maximum BST, Stat EXP/DV controls, battle clauses, field restrictions, services/economy limits, and other configurable challenge mechanics.
- Variants: Mono-through-Hexa Type Locke, Catch Draft, seeded Random Starter, Random Encounters, Random Field Items, and Random Learnsets.
- Information/UI: ENC TRACKER / Area Guide, Catch Info, NUZ STATUS, Run History, Forgiveness Tokens, World Building, MOD COMPAT, and DEV REPORT.
- Setup/QoL: starting resources, Quick Nuzlocke Start, default names, Running Shoes, tutorial skips, Instant Text, Unlimited Bag Space, and guarded setup assists.
- Compatibility: public provider/capability APIs for trainer parties, species/move metadata, encounters, acquisition legality, battle roles, external Randomizer ownership, held-item systems, content mods, Stadium provenance, and exact-game context.
- Safety/diagnostics: Save Schema migration guards, Gameplay Transactions, SafeInstall/Feature Health, hook audits, Release Safety, and exact-edition diagnostics.

## Supported games

| Edition | Declared support | Evidence rule |
| --- | --- | --- |
| Red | Yes | Exact Red runtime evidence is tracked independently. |
| Blue | Yes | Exact Blue runtime evidence is tracked independently. |
| Yellow | Yes | Exact Yellow runtime evidence is tracked independently. |
| Gold | Yes (beta) | Exact Gold runtime evidence is required. |
| Silver | Yes (beta) | Shared Gen 2 architecture does not substitute for exact Silver evidence. |

**Crystal is not a declared target.** Crystal-251/Stadium overlays may be detected for compatibility without changing the exact running Red/Blue/Yellow/Gold/Silver edition.

## Engine / package contract

- Gen1Recomp Mod API: **2**
- Engine range: **`>=0.1.86 <2.0.0`**
- Latest source-audited Gen1Recomp release recorded by this project: **0.2.20**
- Save Schema: **4**
- Compatibility API: **32** (`compatible_from = 10`)
- Diagnostics API: **1**
- Run History API/storage: **1**
- Randomizer algorithm: **1**
- Rule Catalog: **138 unique rule keys**
- Player package: **30 files / 20 Lua files**

## Installation / update

Install the ZIP through Gen1Recomp's normal mod workflow. Updating over an older supported Nuzlocke build keeps the ordered Save Schema 4 migration path. If a save was written by a newer unsupported schema, Nuzlocke pauses its own mutations rather than interpreting unknown data.

For a new run, open **NUZLOCKE SETUP**, choose a preset or configure individual rules, review the staged values, and start the game. The in-game **NUZ RULES** screen edits the active save unless an applicable lock prevents changes.

Ordinary toggles use Left/Right and/or A. Numeric/resource selectors use their dedicated numeric editing behavior.

## Current maintenance state

The 2.7.x hardening line has completed broad second-pass review and targeted third-pass review of the highest-risk persistence, Randomizer, compatibility, UI, and transaction seams. **2.7.25 is the current 2.7.x release build.**

Randomizer feature development remains intentionally paused after Phase D. Phase E is **not started**. Maintenance fixes must not change Randomizer algorithms or mappings unless a concrete bug requires it.

Static/source/harness validation never counts as Runtime PASS. Red, Blue, Yellow, Gold, and Silver are independent evidence targets, and provider interoperability is tracked separately from ordinary player-runtime evidence.

## Compatibility summary

Nuzlocke prefers semantic provider contracts over mod-name guesses. Where another mod owns trainer teams, species/move metadata, encounters, randomization, held items, weather, provenance, or content, Nuzlocke composes through public capability/Content/Acquisition surfaces where available and otherwise reports uncertainty rather than inventing ownership.

Stadium renderer/model assets never imply Pokémon acquisition. Actual cooperating Stadium imports/transfers must carry explicit acquisition provenance. Crystal-251 presentation/importer overlays do not rewrite exact edition identity.

See **docs/COMPATIBILITY.md** for current composition rules and **docs/API.md** for the provider/developer contract.

## Runtime confidence

Previously recorded Runtime PASS evidence applies only to the exact build/edition/environment tested. Maintenance builds after those checkpoints remain TEST REQUIRED unless separately exercised.

See **docs/FEATURE_CONFIDENCE.md** for the evidence ledger.

## Known / intentionally unfinished

- Wonderlocke remains disabled until a safe pre-transaction Wonder Trade contract exists.
- Permanent Rule Seal remains WIP-disabled.
- Randomizer Phase E remains intentionally paused/not started.
- Some exact-edition and third-party combination paths remain runtime-test debt even when static/semantic validation passes.

## Documentation

- **RELEASE_NOTES.md** — concise current-build summary only.
- **CHANGELOG.md** — complete version history.
- **docs/USER_GUIDE.md** — current player-facing behavior by topic.
- **docs/API.md** — current provider/developer contract.
- **docs/COMPATIBILITY.md** — current ownership/composition rules.
- **docs/FEATURE_CONFIDENCE.md** — current evidence state and historical protected evidence.
- **docs/DOCUMENTATION_CHANGELOG.md** — documentation-structure/content history.

## Credits

Original mod by **bryanthaboi**. Continued development and release maintenance by **Stone696**.
