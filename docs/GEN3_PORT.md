# Gen 3 port — experimental foundation

This branch does **not** port Nuzlocke's full Gen 1/2 feature set. It introduces a separate Gen 3 implementation, selected by `entry.lua`, while the established `main.lua` remains the entry for Red, Blue, Yellow, Gold, Silver and Crystal. See [DEVELOPER_GEN3.md](DEVELOPER_GEN3.md) for the Windows VS Code walkthrough and code map.

## Implemented

- Open **NUZ MENU** from the in-game Start menu (mirrors the Gen 1/2 Nuzlocke top-level structure) and toggle **NUZLOCKE: OFF / ON** in **NUZ RULES → CORE**.
- The Gen 3 menu includes 21 rule categories plus the approved eight-rule **CORE** menu. Other original rule entries are visible as [Soon] placeholders. Implemented features have no prefix; partial items show **[WIP]**. See [GEN3_CORE_SPEC.md](GEN3_CORE_SPEC.md) for the agreed behaviour and PC/whiteout precedence.
- Nuzlocke, Permadeath, One Per Area and Failed Encounters are independent live CORE switches. Whiteout Ends Run remains **[WIP]**. Nickname Requirement, First Rival Mercy and PC Survivors Allowed now have testable **[WIP]** toggles; edition-specific gameplay certification is outstanding.
- The CLAUSES menu includes **Dupes**, **Shiny Catch Exception**, **Shiny Rate**, **Roamer Clause**, **Egg Encounter** and **Route Forgiveness** ([WIP], opt-in). Shiny Colours/Intro are not duplicated in Gen 3. Egg receipt/hatch tracking and missed-route token redemption are implemented; unsupported story-gift provenance, eligibility enforcement and Pokémon revival remain pending. See [GEN3_CLAUSES.md](GEN3_CLAUSES.md) and [GEN3_EGGS_FORGIVENESS.md](GEN3_EGGS_FORGIVENESS.md).
- Track the first eligible wild battle on each **native map ID**. With Failed Encounters ON it consumes the slot immediately, even if the Pokémon flees or faints; with that setting OFF, only a successful eligible catch consumes the slot.
- Reject subsequent catch rolls on the same map through Gen1Recomp's Gen 3 `catch.rate` hook (Balls are still consumed by the native action).
- Record successful captures. As soon as the Gen 3 `battle.fainted` event fires for a player battler, irreversibly record death in the save-local graveyard and mark the battle-party Pokémon as dead. Compaction of the native party array still happens after `battle.ended`, when forced switching and battle writeback are finished.
- Deny revival-item usage in the Gen 3 battle party UI and item execution transaction, while leaving other medicine paths unchanged.
- After post-battle death retirement, an empty party fails the run unless PC Survivors is ON, Whiteout has not already failed the run, and a living eligible boxed Pokémon can be moved (not copied) into the party. The first available qualifying boxed Pokémon is selected; Eggs, fainted/dead and marked-ineligible entries are excluded. Whiteout Ends Run always outranks PC rescue.
- Keep the master feature disabled by default and store settings, history and deaths under the backwards-compatible `gen3_classic_v1` key, separate from the Gen 1/2 save schema. Legacy captured/missed areas with no `spent` flag remain spent after upgrading.

- **LEVELS:** Five cap scopes (None, Gyms, Elite Four, Champion and Postgame), independently toggleable EXP Edging with a per-Pokémon saved bank, native EXP transaction clamping, and a Rare Candy guard. See [GEN3_LEVELS.md](GEN3_LEVELS.md) for level tables, limitations and testing. The Gen 3 BATTLE MECHANICS category has been removed; CORE/CLAUSES category and active rule entries no longer carry WIP prefixes.\n\n- **Player feedback and Candy fix:** Native battle dialogue now explains denied catches, encounter rules, capped/banked/released EXP, deaths and exceptions. The persistent NUZ NOTICES page covers field events, tokens, eggs, mercy, and run status. Field Rare Candy is blocked at the `item.use` transaction before consumption. See [GEN3_FEEDBACK.md](GEN3_FEEDBACK.md).\n\n## Not yet implemented / known gaps

- Most of the original mod's configuration, profiles, setup, complete encounter-tracker UI, advanced death/forgiveness rules, randomiser, shiny clauses, gift/statics and species clauses are not yet ported. These remain inert **[Soon]** rows. The limited **versioned** `mod.exports.gen3_core` rule API is now available.
- First Rival Mercy is consumed when the opening Oak Lab rival (FRLG, IDs 326–328 with the early-rival marker) or Route 103 rival (R/S/E first-match IDs) actually starts. Only that battle is exempt from Nuzlocke death/whiteout failure; the native result and story script remain untouched. Verify edition and starter combinations in-game.\n- Nickname Requirement forces the native naming screen on ordinary wild catches and refuses blank/species-default submissions. Unnamed gifts, trades and hatches are surfaced under **NUZ MENU → NICKNAME TASKS**, where players can rename them. These non-catch acquisitions are tracked, but their use is not yet blocked in battle; treat this as a **[WIP]** compliance aid.
- Gen 3's menu is implemented with its native 240x160 screen stack, rather than Gen 1/2's screens system. This keeps the fork's Mod API at version 2, but game testing is needed to confirm drawing and navigation for every GBA edition.
- The tracker currently treats each native **map ID** as a separate catch area. Canonical Nuzlocke locations (for example different floors of one cave) need a region/section mapping.
- Gen 3 does provide a player-side `battle.fainted` event; it now records death immediately. **The actual party entry stays visible as fainted until battle ends**, because removing it mid-battle can invalidate the engine's `partyIndex` references, especially in double battles. Special modes (scripted, link, multi, battle facilities) need separate certification.
- Revival blocking currently covers native in-battle revival items; interactions with third-party item providers, scripted healing, and the battle restart/whiteout flow remain to be tested.
- The graveyard contains metadata, not a PC-stored recoverable Pokémon. Retirement changes the native session party; back up saves before testing. `gen3_display.lua` now uses native Pokémon and map-section name resolvers and humanises older records on read without rewriting their saved IDs.
- No game/ROM runtime certification yet. Mock tests cover the three new rules but cannot certify the naming-screen stack, script-loss handling, RSE trainer mappings or save/PC transitions. FireRed, LeafGreen, Ruby, Sapphire and Emerald require independent boots/tests.

## Testing

Run from the repository root:

```sh
lua5.1 tests/gen3_foundation_smoke.lua
python3 tools/modkit.py gen3check /path/to/this/mod
```

The `modkit.py` command is part of **Gen1Recomp**, not this mod repository; the second command must be run in the engine checkout and pointed at the installed Nuzlocke mod folder.

After that: import a legitimate Gen 3 ROM into Gen1Recomp, enable the Nuzlocke mod, start a **new** game, open NUZ MENU and switch NUZLOCKE ON under NUZ RULES -> CORE as early as possible, catch or miss a wild Pokémon, test repeated Balls in the same map, test a second map, and test fainting with a backed-up save. In a two-Pokémon trainer fight, faint one Pokémon and open the party/bag before ending the battle: it should be fainted, unusable, and revival items should fail. After the battle, the Pokémon should be removed and its graveyard record should appear once. Do **not** treat a passing mock test as runtime certification.

## Compatibility contract

The mod remains API 2 because the existing Gen 1/2 runtime is API 2. The manifest declares `gen3` so the engine may load it, while `entry.lua` dispatches to `gen3_runtime.lua` in Gen 3. This is intentionally a reduced experimental runtime, not an assertion that every Nuzlocke setting works on Gen 3.
