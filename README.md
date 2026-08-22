# Nuzlocke 2.7.0
2.7.0 is the release promotion of runtime-confirmed 2.6.98 and contains the completed 2.6.x development line. See `RELEASE_NOTES.md` for the release delta since 2.6.0. Behavior is unchanged from 2.6.98.
# Nuzlocke 2.6.96

2.6.96 is a strict child of 2.6.95 and repairs the documentation-header packaging drift caught by Release Safety when opening NUZ RULES. It changes no gameplay, Randomizer mappings, rule semantics, or compatibility ownership. Runtime retest is required.

## 2.6.95 — NUZ RULES diagnostic runtime repair

2.6.95 is a strict child of 2.6.94. It fixes the Randomizer rival-sync diagnostic closure/order defect that caused NUZ RULES to report Release Safety failure at runtime. No gameplay or Randomizer mapping behavior is changed. Runtime retest is required.

## 2.6.94 — Lua unpack audit scope hardening

Strict child of exact 2.6.93 (`8aeafd1f10c236f19164a1abf24a7c8d6de96c2f1a34b630a1d1e8af22fb6ddb`). Fixes the confirmed Release Safety coverage defect where `luaUnpackCompatibilityAudit()` scanned only four historical files even though the player package ships 20 Lua modules. The audit now iterates the authoritative `packagePaths` inventory, filters every shipped `.lua` module, and includes self-tests for direct `table.unpack(...)`, bare `unpack(...)`, and the allowed `table.unpack or unpack` compatibility fallback. No gameplay rule, save schema, compatibility provider, randomizer mapping, or package inventory changes. Runtime confirmation remains required.

## 2.6.93 — World Building catalog snapshot repair

Strict child of exact 2.6.92 (`0d33e210ab13f921fd972284c75fd9d577283c51007e5cfa73f636b1b497f128`). Repairs the runtime-blocking MOD MANAGER startup assertion caused by a stale World Building semantic golden snapshot. The live catalog intentionally contains 104 presentation keys; seven Randomizer presentation rows added after the former 97-key golden were legitimate but the protected snapshot had not been refreshed. The corrected golden is **104 keys / 1560 exact-edition-tier surfaces / checksum 926265119**.

The audit is also hardened: the approved key identities are now explicit, key-count and resolved-surface totals derive from that set, and future drift reports the specific missing/unexpected key before the checksum check. No rule defaults, enforcement, Randomizer algorithm/mappings, Save Schema, Compatibility API, Diagnostics API, or package inventory change. The reported 2.6.92 MOD MANAGER failure is Runtime FAIL evidence; 2.6.93 startup/runtime confirmation remains required.

## 2.6.92 — Legacy mod_Compat Beta_26 interoperability

- Publishes an explicit read-only `mod.exports.mod_Compat.Beta_26` alias and `nuzlocke_compat.legacy_compat` metadata for older cooperating mods that identify the historical `mod_Compat Beta_26` wording/namespace.
- Keeps `nuzlocke_compat` API 32 and explicit capability/provider contracts authoritative for modern integrations; the alias does not grant ownership or delegate mechanics merely because another mod is installed.
- Runtime interoperability confirmation remains TEST REQUIRED.
# Nuzlocke 2.6.94

A configurable Nuzlocke ruleset for Gen1Recomp with exact-edition support for **Pokémon Red, Blue, Yellow, Gold, and Silver**.

## Highlights

- Core Nuzlocke rules: Permadeath, One Per Area, Failed Encounters, Nickname Rule, Dupes modes, Shiny Clause, First Rival Mercy, Whiteout policy, gifts/trades/statics, and species restrictions.
- Difficulty tools: live level caps, Gym/Dungeon Lock-In, Party Size/Gym Team Size, Badge Boost control, Maximum BST, Stat EXP/DV controls, and multiple battle/field restrictions.
- Type Locke from Mono through Hexa, Random Starter, Random Encounters, Random Field Items, Random Learnsets, seeded deterministic randomizer helpers, and encounter information policy.
- Encounter Tracker / Area Guide, Catch Info, Trainer/Nuz Status surfaces, Run History infrastructure, Forgiveness Tokens, and configurable World Building dialogue.
- Setup/QoL options including starting resources, Quick Nuzlocke Start, default names, Running Shoes, tutorial skips, Instant Text, Unlimited Bag Space, and other guarded assists.
- Public compatibility/provider APIs for trainer parties, species metadata, encounter ownership, acquisition legality, battle roles, external held-item systems, and content mods.
- Dev Mode with self-test, compatibility diagnostics, lifecycle/hook health, central SafeInstall/Feature Health reporting, gameplay-transaction status, Release Safety checks, storage diagnostics, and NZR report codes.

## Supported games

| Edition | Declared support | Evidence rule |
| --- | --- | --- |
| Red | Yes | Red runtime evidence is tracked independently. |
| Blue | Yes | Blue runtime evidence is tracked independently. |
| Yellow | Yes | Yellow runtime evidence is tracked independently. |
| Gold | Yes | Gen 2 support; exact Gold runtime evidence required. |
| Silver | Yes | Shares Gen 2 architecture but requires independent Silver evidence. |

Crystal is not currently a declared target.

## Engine / package contract

- Gen1Recomp Mod API: **2**
- Engine range: **`>=0.1.86 <2.0.0`**
- Latest source-audited Gen1Recomp release: **0.2.19**
- Save Schema: **4**
- Compatibility API: **32** (`compatible_from = 10`)
- Player package: **30 files / 20 Lua files**

## Installation / update

Install the ZIP through Gen1Recomp's normal mod workflow. Updating over an older supported Nuzlocke build keeps the ordered Save Schema 4 migration path. If a save was written by a newer unsupported schema, Nuzlocke pauses its own mutations rather than interpreting unknown data.

For a new run, open **NUZLOCKE SETUP**, choose a preset or configure individual rules, review the staged values, and start the game. The in-game **NUZ RULES** screen edits the active save unless the rules are locked/sealed by the relevant rule.

## Current release

2.6.91 is a strict correctness child of exact 2.6.90. It fixes three confirmed defects without resuming Randomizer feature development: learnset ownership now snapshots/compares only the three move-list fields Nuzlocke actually owns, Rare Candy recovery requires a durable transaction-specific native-effect checkpoint before inventory-only reconciliation, and Rare Candy transaction IDs use a durable monotonic v2 attempt sequence so revisiting the same Pokémon level cannot collide with an old committed receipt. Randomizer algorithm v1, Save Schema 4, Compatibility API 32, Diagnostics API 1, the 138-rule catalog, and the 30-file player package remain unchanged. Runtime confirmation is still required for the touched gameplay paths.

See **RELEASE_NOTES.md** for the concise current-release summary and **CHANGELOG.md** for the complete historical version record.

## Compatibility summary

Nuzlocke prefers semantic provider contracts over mod-name guesses. Where another mod owns trainer teams, species/move metadata, encounters, held items, weather, or content, Nuzlocke composes through the public capability/Content/Acquisition surfaces where available and otherwise reports uncertainty rather than inventing ownership.

Current dedicated compatibility work includes Kanto Reforged, The World, VanillaPlus, Modern UI/Wide Menu-style presentation mods, trainer-party providers, randomizer/content providers, and exact Gen1Recomp engine audits. See **docs/COMPATIBILITY.md** for the current contract.

## Runtime confidence

Static/source/harness validation never counts as Runtime PASS. Red, Blue, Yellow, Gold, and Silver are independent evidence targets. A compatibility path can also be player-runtime healthy while still requiring separate third-party-provider testing.

See **docs/FEATURE_CONFIDENCE.md** for the current player/runtime and provider-interop confidence matrix.

## Known / intentionally unfinished

- Wonderlocke remains disabled until a safe pre-transaction Wonder Trade contract exists.
- Permanent Rule Seal remains WIP-disabled.
- Some exact-edition and third-party combination paths remain runtime-test debt even when source/static validation passes.
- The feature backlog is maintained separately from the bug/validation ledger; completed work is retired rather than left as “planned.”

## Documentation

- **docs/USER_GUIDE.md** — how the current mod behaves, organized by topic.
- **docs/API.md** — current public provider/developer API contract.
- **docs/COMPATIBILITY.md** — current engine/mod ownership and composition rules.
- **docs/FEATURE_CONFIDENCE.md** — current evidence state.
- **CHANGELOG.md** — complete release history.
- **docs/DOCUMENTATION_CHANGELOG.md** — documentation-structure/history notes.

## Credits

Original mod by **bryanthaboi**. Continued development and release maintenance by **Stone696**.
