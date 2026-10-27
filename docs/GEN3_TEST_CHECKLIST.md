# Gen 3 Nuzlocke — Manual test checklist

**Branch:** `feature/gen3-foundation` · **Scope:** first eight CORE rules + menu / data persistence · **Updated:** 27 October 2026.

This is the human-in-the-loop test plan for [PR #1](https://github.com/Deluxe0111/nuzlocke/pull/1). The automated smoke test is necessary but cannot replace actual ROM/gameplay testing.

> **Safety:** Use backed-up **disposable** saves. These tests can permanently remove party Pokémon and mark the Nuzlocke run lost. Do not test on a valuable save. Start fresh test runs as indicated; a lost run cannot be reset with the menu.

**Reporting:** Tick a box **only after its expected behaviour passes**. For failures or blocked tests, leave the box unticked and add the test ID to the `Issues / results` section at the end. Include a screenshot, exact game edition and reproduction steps.

## Before starting

- [ ] **P01 — Install current branch.** Re-download `feature/gen3-foundation`, import into the Gen1Recomp MODS tab, and verify Nuzlocke is enabled for your game. **Expected:** Game launches without a mod-load error.
- [ ] **P02 — Prepare three disposable saves.** One for **A: catch rules**, one for **B: fainting**, one for **C: whiteouts**; separate save slots or independent backups are fine. Give yourself Master Balls, Poké Balls, Revives, and at least two Pokémon where useful. **Expected:** All tests can be restarted without risking progress.
- [ ] **P03 — Record environment.** Note the exact Gen1Recomp build/commit and game/version (FireRed, LeafGreen, Ruby, Sapphire or Emerald). **Expected:** Results can be reproduced.

## NUZ DEV test reset controls (optional, recommended)

Before repeating encounter tests on the same route, open **Start → NUZ MENU →
[WIP] NUZ DEV → ENABLE DEV MODE**, confirm, then use **RE-ARM CURRENT**.
See [GEN3_NUZ_DEV.md](GEN3_NUZ_DEV.md) for the complete menu and safety notes.

- [ ] **V01 — Enable dev tools.** Enable NUZ DEV and confirm. **Expected:** Available test controls; save marked as a development/test run.
- [ ] **V02 — Re-arm current.** After consuming an area's first encounter, select RE-ARM CURRENT and confirm. **Expected:** The area's catch slot is open again, without touching actual caught Pokémon.
- [ ] **V03 — Edit an area.** Use EDIT CURRENT AREA or EDIT ALL AREAS to mark one map OPEN, SPENT and CAUGHT. **Expected:** Area state and later catch decisions follow your edit.
- [ ] **V04 — Cancel/global reset.** Try CLEAR ALL AREAS, cancel, confirm entries remain; repeat and confirm. **Expected:** All encounter records clear **only** after explicit confirmation.
- [ ] **V05 — Inspect/export.** Open STATE INSPECTOR and PRINT DEBUG REPORT. **Expected:** Useful live values and `[NUZ DEV]` debug lines in the game console.
- [ ] **V06 — Reset guard.** Attempt to clear run failure with an empty or fully fainted party. **Expected:** Refused. With a living party, manual un-fail is permitted, but no Pokémon is restored.
- [ ] **V07 — Disable tools.** Disable NUZ DEV. **Expected:** Mutating features become inaccessible; permanent test-run marker remains.

**Important:** Re-arming does not reverse an actual catch or return a Ball. For example, after completing E05, use V02 before testing E07 on the same map; otherwise use a new, unused route.

## A. Menu & rule-state smoke tests (save A)

- [ ] **M01 — Open menu.** Press Start → NUZ MENU → NUZ RULES → CORE. **Expected:** No errors, readable labels, **exactly eight** CORE rules.
- [ ] **M02 — Supported labels.** Inspect Nuzlocke Enabled, Permadeath, One Per Area and Failed Encounters. **Expected:** Each shows an accurate ON/OFF state and can be changed independently.
- [ ] **M03 — Partial/placeholder labels.** Inspect Whiteout Ends Run, Nickname, First Rival Mercy and PC Survivors. **Expected:** Whiteout is **[WIP]** and toggleable; the latter three show **[Soon]** and cannot activate a nonexistent rule.
- [ ] **M04 — Navigation.** Scroll through CORE, back to NUZ RULES, open some other categories, then back to NUZ MENU and the game. **Expected:** Scrolling, cursor, A/B and reopening all work; no clipped/unreadable menu entries or stuck overlays.
- [ ] **M05 — Master toggle.** Switch NUZLOCKE OFF → ON → OFF → ON. **Expected:** Label changes immediately; rule values in other rows do not reset.
- [ ] **M06 — Save persistence.** Enable Nuzlocke, change one rule, save **in game**, restart and reopen the menu. **Expected:** Master switch and saved rule values persist.

## B. Encounter rules (save A, Nuzlocke ON)

**Important:** `One Per Area` is currently per **native map ID**, not yet an official combined location. Some cave floors or Safari sections can have separate slots. Test ordinary routes first; do not interpret different floors as a fixed map bug yet.

- [ ] **E01 — First encounter.** On unused Route A, encounter the first wild Pokémon and use a Master Ball. **Expected:** Capture succeeds; Encounter Tracker identifies Route A as caught.
- [ ] **E02 — Repeat encounter.** On that same map, encounter another wild Pokémon and throw a Master Ball. **Expected:** Capture fails despite Master Ball (Ball may still be consumed).
- [ ] **E03 — New map.** Walk to unused Route B and catch its first wild Pokémon. **Expected:** Capture allowed, independent of Route A.
- [ ] **E04 — Revisit a used map.** Return to Route A, including after leaving and re-entering. **Expected:** Additional wild captures remain blocked.
- [ ] **E05 — Failed Encounters ON, Pokémon KO'd.** On unused Route C, leave `ONE PER AREA: ON` and `FAILED ENC.: ON`; knock out its first eligible wild Pokémon. **Expected:** The next Pokémon on Route C cannot be caught.
- [ ] **E06 — Failed Encounters ON, fleeing.** On another unused Route D, run from the first eligible wild Pokémon. **Expected:** The next Pokémon on Route D cannot be caught.
- [ ] **E07 — Failed Encounters OFF.** On unused Route E, set `FAILED ENC.: OFF`; run from or KO the first eligible wild Pokémon, then try again. **Expected:** Another encounter can be caught; an unsuccessful encounter doesn't spend the catch slot.
- [ ] **E08 — Catch after a failed attempt.** Still on Route E with `FAILED ENC.: OFF`, make a successful first catch, then throw a Ball at a subsequent Pokémon. **Expected:** Successful capture consumes the slot; later capture fails.
- [ ] **E09 — One Per Area OFF.** On any route, switch `ONE PER AREA: OFF`. **Expected:** Multiple wild Pokémon can be caught; switching it back ON restores per-area restrictions.
- [ ] **E10 — Master switch OFF.** Switch `NUZLOCKE: OFF` and try catching on a normally locked route. **Expected:** Nuzlocke no longer blocks catching. Turn it back ON afterwards; prior run records should not be wiped.
- [ ] **E11 — Tracker reflects outcomes.** Visit ENC TRACKER and NUZ STATUS. **Expected:** Claimed areas and catches distinguish caught / spent / still-open areas, and totals do not reset when entering another map.
- [ ] **E12 — Persist encountered areas.** Save in-game, restart, revisit a previously spent map with Nuzlocke ON. **Expected:** Capture remains restricted; the tracker retains entries.
- [ ] **E13 — Trainer fights do not spend wild encounters.** Fight a trainer in a new area *before* any wild battle there. **Expected:** The area's first eligible wild catch is still available.

## C. Permadeath (save B; use at least two party Pokémon)

- [ ] **D01 — Permadeath ON, faint event.** Enable Nuzlocke and Permadeath. Let exactly one Pokémon faint during a trainer battle while another remains alive. **Expected:** It stays fainted and unavailable during the battle; no immediate party-array removal that breaks forced switching.
- [ ] **D02 — Revives denied in battle.** While that first Pokémon remains fainted and battle continues, try Revive (or Max Revive). **Expected:** Revival is refused.
- [ ] **D03 — Post-battle retirement.** Finish the battle. **Expected:** Only the fainted Pokémon disappears from the native party; the surviving Pokémon remains valid.
- [ ] **D04 — Graveyard count.** Open GRAVEYARD and NUZ STATUS. **Expected:** One death entry, correct Pokémon identity/details where available, no duplicates.
- [ ] **D05 — Permadeath OFF.** On a *fresh second faint*, disable Permadeath but keep Nuzlocke ON. **Expected:** Pokémon remains in the party after battle, isn't recorded as dead, and native revival items are usable.
- [ ] **D06 — Re-enable Permadeath.** Turn Permadeath back ON and faint another Pokémon. **Expected:** The next death is enforced normally; previous recorded deaths are retained.
- [ ] **D07 — Nuzlocke OFF.** Disable the master switch, faint a Pokémon in battle. **Expected:** Native Pokémon faint/revive behaviour; no Nuzlocke deletion or new graveyard record.
- [ ] **D08 — Restart after deaths.** Save/restart, inspect party, GRAVEYARD and NUZ STATUS. **Expected:** Removed party members stay removed, recorded deaths persist once, and enabled rule values persist.

## D. Whiteout & run failure (save C: intentionally destructive)

Do these on separate save copies. **PC Survivors Allowed is still [Soon]**; do not count lack of PC recovery as a newly introduced failure.

- [ ] **W01 — Whiteout ON with PC reserves.** Keep a healthy Pokémon in the PC and intentionally wipe the whole battling party with `WHITEOUT FAILS: ON`. **Expected:** Nuzlocke run is marked LOST **despite** living Pokémon in the PC; normal game save is *not* automatically deleted.
- [ ] **W02 — Lost run is locked.** After W01, revisit CORE. **Expected:** You cannot turn rule switches back on/off to reset the lost-run state.
- [ ] **W03 — Whiteout OFF, no PC rescue yet.** On another save, disable `WHITEOUT FAILS`, leave `PC SURVIVORS` unavailable, then lose all party Pokémon. **Expected for current WIP:** An empty party still fails the run. Turning whiteout failure OFF **alone does not make PC rescue work**.
- [ ] **W04 — PC box unchanged.** After a whiteout, inspect the PC/storage if the game permits it. **Expected:** Nuzlocke has not removed or marked otherwise healthy boxed Pokémon as dead.

## E. Compatibility & known pending features

- [ ] **C01 — Gen 1 regression.** If you have an original Red/Blue/Yellow setup, open the original Nuzlocke UI. **Expected:** Established Gen 1 menu and rules unchanged.
- [ ] **C02 — Gen 2 regression.** If you have Gold/Silver/Crystal configured, open its Nuzlocke UI. **Expected:** Established Gen 2 menu unaffected.
- [ ] **C03 — Second Gen 3 edition.** Repeat **M01, E01–E03 and D01–D03** in another edition (ideally Emerald after FireRed). **Expected:** Same basic results; record the exact edition.
- [ ] **C04 — Double battle stress test.** If convenient, faint one player Pokémon during a native double battle. **Expected:** Forced switching does not crash or shift the wrong party slot; death is recorded exactly once.
- [ ] **C05 — Unsupported rules remain inert.** Inspect Nickname, First Rival Mercy, PC Survivors, Gifts, Dupes/Shinies, Randomiser and other [Soon] items. **Expected:** They are visibly labelled pending and cannot claim active enforcement.

### Current known limitations (not automatic regressions)

- Native map IDs are not yet grouped into canonical named areas; different floors can count separately.
- Field revival routes and custom item-provider mods require separate review.
- Early rival exception, nickname prompt enforcement, PC resurrection/recovery, full gift/static encounter handling, duplicate/shiny clauses and most randomiser options are **not yet implemented**.
- Whiteout handling and Gen 3 special battle types (Safari, link/multi, scripted/tutor battles, Battle Frontier) need edition-specific certification.
- The source repository's general legacy CI has outdated manifest assertions; the dedicated Gen 3 Lua smoke is a separate check.

## Issues / results

**Tester:**  
**Date:**  
**Gen1Recomp build or commit:**  
**Nuzlocke branch commit:**  
**Game / edition:**  
**Other mods enabled:**  

| Test ID | PASS / FAIL / BLOCKED / SKIP | Notes / actual behaviour / screenshot |
| --- | --- | --- |
| | | |
| | | |
| | | |
| | | |
| | | |

**Crash/error log:**  
**Reproduction steps for any failure:**  
**Save backup available?** Yes / No

When reporting, send me the **test ID(s)** and observed result, e.g.:
`E07 FAIL — FireRed, Failed Encounters OFF, ran from Pidgey, next wild capture still blocked.`

