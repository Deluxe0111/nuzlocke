# Gen 3 CORE rules — agreed contract

This document records the approved design for the eight CORE rules. **Do not
equate a stored setting with an implemented mechanic.** The menu exposes
completed mechanics, labels partial work `[WIP]`, and keeps unsupported settings
`[Soon]` and read-only.

## CORE rule matrix

| ID | Label | Default | Gen 3 stage | Behaviour |
| --- | --- | --- | --- | --- |
| `nuzlocke_enabled` | Nuzlocke Enabled | OFF (opt-in) | Working | Master rule enforcement switch; retains progress when switched off |
| `permadeath` | Permadeath | ON | Working (battle) | Record death on `battle.fainted`, deny battle revivals, retire after writeback; field revival seam still needs certification |
| `encounter_limit` | One Encounter Per Area | ON | Working (map ID) | Only one consumed eligible encounter per map; multi-floor area grouping is pending |
| `failed_encounter` | Failed Encounters Count | ON | Working (ordinary wild) | With area limit ON, first eligible wild attempt consumes the area even if missed; OFF means the first successful eligible catch closes it |
| `nickname_rule` | Nickname Requirement | ON | WIP | Native catch naming is mandatory; unnamed party/PC Pokémon appear in Nickname Tasks |
| `first_rival_forgiveness` | First Rival Mercy | ON | WIP | Opening rival battle consumes one-time mercy at start and protects Pokémon from Nuzlocke deaths |
| `whiteout_ends_run` | Whiteout Ends Run | ON | WIP | Losing a qualifying battle marks run failed even if PC reserves exist; story/tutorial/link exceptions need certification |
| `pc_survivors_allowed` | PC Survivors Allowed | OFF | WIP | Empty party can receive one eligible living boxed Pokémon after battle writeback; whiteout failure takes precedence |

Defaults of the last two rules were not specified by the original discussion.
For now, use conservative defaults (whiteout fails run / PC rescue OFF).
**The existing Gen 3 save schema remains `gen3_classic_v1`**, so previously
recorded attempts and deaths remain available after upgrading.

## Encounter decision table

| One Per Area | Failed Encounters | Expected consequence |
| --- | --- | --- |
| ON | ON | First eligible wild battle immediately spends area |
| ON | OFF | Wild attempts remain open until successful eligible catch |
| OFF | either | No per-area catch denial; catches are still tracked to preserve history |

Legacy `gen3_classic_v1.areas[map]` entries with no `spent` property are
considered **already consumed**. This avoids reopening previously used
encounters on upgrade. New entries contain `spent` and `attempts`.
Existing entries that recorded a successful catch remain consumed if the user
later disables/re-enables an enforcement rule.

The future Dupes/Shiny/Gifts/Statics policy engine must determine eligibility
**before** claiming an area. This is not yet implemented. Current tracking is
ordinary wild encounters by native map ID, not full canonical Nuzlocke areas.

## Whiteout / PC precedence (agreed)

| Whiteout Ends Run | PC Survivors Allowed | Expected result |
| --- | --- | --- |
| ON | ON | Lost battle ends run regardless of PC survivors |
| ON | OFF | Lost battle ends run; an empty party also ends it |
| OFF | ON | Can continue after party wipe only if eligible boxed Pokémon survive |
| OFF | OFF | Empty party ends run regardless of PC |

PC Survivors is **[WIP] opt-in**. After native battle writeback and permadeath
retirement, the first eligible living boxed Pokémon is **moved**, not copied
or revived, into an empty party. This avoids the native empty-party softlock
while letting the engine handle normal post-loss relocation. Whiteout Ends
Run still takes precedence. A failed run only marks mod state; the native
save is never deleted.

Recovery excludes Eggs, Bad Eggs, fainted/death-marked Pokémon and creatures
matching an archived death. Explicit progression/ineligibility flags are also
honoured; compatibility with future party restrictions remains unfinished.
Native boxes are in `session.storage.boxes[boxId].mons`.

Nickname Tasks scans party and boxes for unnamed acquisitions, including
gifts, trades and hatched Eggs. Unresolved tasks are visible to the player
but **do not yet prevent use in battle**. The capture prompt now bypasses the native optional Yes/No choice
entirely while CORE → NUZLOCKE and NICKNAME are ON. Captured Pokémon must
enter a non-empty, non-species-default nickname before the native
catch flow can complete. Empty, cancelled or default names return to
the native naming screen; with the nickname rule OFF, native Yes/No is
restored. This applies to ordinary Gen 3 catches, including Untamed
wandering wild encounters, which use the same native battle flow.
The capture naming guard is also reinstalled if another integration
replaces the UI method after a battle starts.

Opening rival mercy is consumed at battle start, restricted to the three
Oak Lab matchups in FRLG or Route 103 first matchups in R/S/E. Native battle
results, healing and story scripts are not overridden. Real ROM tests for
every starter and edition remain mandatory.

## API / compatibility

- `gen3_core_rules.lua` is the single source for the eight CORE rule IDs,
  implementation status and defaults, separate from the legacy 161-rule list.
- The mod entry remains API **2** to avoid changing Gen 1/2 compatibility.
- `mod.exports.gen3_core` exposes `api`, `schema`, `definitions()`,
  `getRule(key)` and `setRule(key, bool)`. Unsupported rules are rejected
  rather than silently accepted.
- The existing `mod.exports.gen3_classic` experimental statistics interface
  remains available; don't replace it without an explicit API migration.
- `gen3_menu.lua` consumes the shared CORE descriptors; it does not define a
  second set of rule statuses/defaults. The **other** Gen 1/2 rules are still a
  navigable WIP mirror and should be migrated to a unified registry in later
  milestones.

## Next validation order

1. Verify native name-screen layering and re-prompting on a FireRed catch.
2. Verify Nickname Tasks with a gift, trade, Egg hatch and boxed Pokémon.
3. Verify the one-time opening rival exception for every edition and starter.
4. Verify PC survivor transfer after a native blackout and verify Whiteout
   Ends Run priority on a disposable save.
5. Add battle-use restrictions for pending nicknames and integrate future
   progression/party eligibility clauses.

The automated smokes include `lua5.1 tests/gen3_foundation_smoke.lua` and `lua5.1 tests/gen3_new_core_smoke.lua`; passing a
mocked test does **not** establish in-game compatibility for every edition.
