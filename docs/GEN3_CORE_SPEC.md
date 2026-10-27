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
| `nickname_rule` | Nickname Requirement | ON | Soon | Newly acquired Pokémon must have a non-default nickname; gift/trade prompt integration pending |
| `first_rival_forgiveness` | First Rival Mercy | ON | Soon | Forgive death/wipe on *the actual opening rival battle*, once per run, without altering story results |
| `whiteout_ends_run` | Whiteout Ends Run | ON | WIP | Losing a qualifying battle marks run failed even if PC reserves exist; story/tutorial/link exceptions need certification |
| `pc_survivors_allowed` | PC Survivors Allowed | OFF | Soon | Empty party may recover from eligible PC reserves once safe post-blackout transport / party reconstruction is implemented |

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

`pc_survivors_allowed` must **remain read-only [Soon]** until implementation
can safely revive the *player's ability to reach a PC*, not their dead
Pokémon. A failed run is marked failed in mod state, but **the native save is
never deleted automatically**. Future manual retirement / history retention
should be a separate explicit rule or action.

Eligibility for PC recovery will exclude Eggs, dead Pokémon, progression-locked
captures and Pokémon forbidden by active party rules. The engine stores box
entries in `session.storage.boxes[boxId].mons`.

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

## Next implementation order

1. Verify the new four live switches and `[WIP]` whiteout rule in FireRed.
2. Implement reliable identity-based tracking across party and boxes, and a
   safe PC rescue/transport path; *only then* enable PC Survivors Allowed.
3. Detect exact opening-rival battle IDs for FRLG and all Hoenn editions;
   implement single-use mercy using a saved `consumed` flag.
4. Enforce pending nicknames across catch, gift, trade and egg acquisition.
5. Make encounters eligibility-driven, then add Dupes/Shiny and unified
   multi-map area grouping.
6. Continue the near-complete port in category order, with adapters and stable
   public API contracts rather than direct cross-mod mutations.

The automated smoke is `lua5.1 tests/gen3_foundation_smoke.lua`; passing a
mocked test does **not** establish in-game compatibility for every edition.
