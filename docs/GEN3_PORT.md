# Gen 3 port — experimental foundation

This branch does **not** port Nuzlocke's full Gen 1/2 feature set. It introduces a separate Gen 3 implementation, selected by `entry.lua`, while the established `main.lua` remains the entry for Red, Blue, Yellow, Gold, Silver and Crystal. See [DEVELOPER_GEN3.md](DEVELOPER_GEN3.md) for the Windows VS Code walkthrough and code map.

## Implemented

- Open **NUZ MENU** from the in-game Start menu (mirrors the Gen 1/2 Nuzlocke top-level structure) and toggle **NUZLOCKE: OFF / ON** in **NUZ RULES → CORE**.
- The Gen 3 menu includes 21 rule categories plus the approved eight-rule **CORE** menu. Other original rule entries are visible as [Soon] placeholders. Implemented features have no prefix; partial items show **[WIP]**. See [GEN3_CORE_SPEC.md](GEN3_CORE_SPEC.md) for the agreed behaviour and PC/whiteout precedence.
- Nuzlocke, Permadeath, One Per Area and Failed Encounters are independent live CORE switches. Whiteout Ends Run has preliminary enforcement and remains **[WIP]**. Nickname, First Rival Mercy and PC Survivors Allowed remain **[Soon]** and cannot be changed.
- The CLAUSES menu now includes implemented [WIP] **Dupes Clause** (OFF/SPEC/FAM/SPLIT) and **Shiny Catch Exception** (OFF/1/2/3/UNLIMITED). Their settings and counts persist; the other six Gen 3 clause rows remain inert [Soon]. See [GEN3_CLAUSES.md](GEN3_CLAUSES.md).
- Track the first eligible wild battle on each **native map ID**. With Failed Encounters ON it consumes the slot immediately, even if the Pokémon flees or faints; with that setting OFF, only a successful eligible catch consumes the slot.
- Reject subsequent catch rolls on the same map through Gen1Recomp's Gen 3 `catch.rate` hook (Balls are still consumed by the native action).
- Record successful captures. As soon as the Gen 3 `battle.fainted` event fires for a player battler, irreversibly record death in the save-local graveyard and mark the battle-party Pokémon as dead. Compaction of the native party array still happens after `battle.ended`, when forced switching and battle writeback are finished.
- Deny revival-item usage in the Gen 3 battle party UI and item execution transaction, while leaving other medicine paths unchanged.
- Mark the run failed when the party becomes empty. Whiteout Ends Run can also fail the challenge immediately on a lost battle, even if boxed Pokémon remain; the safe PC-survivor recovery path is **not** implemented and cannot be enabled.
- Keep the master feature disabled by default and store settings, history and deaths under the backwards-compatible `gen3_classic_v1` key, separate from the Gen 1/2 save schema. Legacy captured/missed areas with no `spent` flag remain spent after upgrading.

## Not yet implemented / known gaps

- Most of the original mod's configuration, profiles, setup, complete encounter-tracker UI, advanced death/forgiveness rules, randomiser, shiny clauses, gift/statics and species clauses are not yet ported. These remain inert **[Soon]** rows. The limited **versioned** `mod.exports.gen3_core` rule API is now available.
- First Rival Mercy and Nickname Requirement are approved but not active. The native whiteout / story-battle exceptions need runtime verification.
- Gen 3's menu is implemented with its native 240x160 screen stack, rather than Gen 1/2's screens system. This keeps the fork's Mod API at version 2, but game testing is needed to confirm drawing and navigation for every GBA edition.
- The tracker currently treats each native **map ID** as a separate catch area. Canonical Nuzlocke locations (for example different floors of one cave) need a region/section mapping.
- Gen 3 does provide a player-side `battle.fainted` event; it now records death immediately. **The actual party entry stays visible as fainted until battle ends**, because removing it mid-battle can invalidate the engine's `partyIndex` references, especially in double battles. Special modes (scripted, link, multi, battle facilities) need separate certification.
- Revival blocking currently covers native in-battle revival items; interactions with third-party item providers, scripted healing, and the battle restart/whiteout flow remain to be tested.
- The graveyard contains metadata, not a PC-stored recoverable Pokémon. Retirement changes the native session party; back up saves before testing. `gen3_display.lua` now uses native Pokémon and map-section name resolvers and humanises older records on read without rewriting their saved IDs.
- No game/ROM runtime certification yet. The mock test checks local hook and state logic only. FireRed, LeafGreen, Ruby, Sapphire and Emerald require independent boots/tests.

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
