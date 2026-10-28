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
- [ ] **M03 — Partial/placeholder labels.** Inspect Whiteout Ends Run, Nickname, First Rival Mercy and PC Survivors. **Expected:** Whiteout, Nickname, First Rival Mercy and PC Survivors are all **[WIP]** and toggleable; the three new rules require actual gameplay certification.
- [ ] **M04 — Navigation.** Scroll through CORE, back to NUZ RULES, open some other categories, then back to NUZ MENU and the game. **Expected:** Scrolling, cursor, A/B and reopening all work; no clipped/unreadable menu entries or stuck overlays.
- [ ] **M05 — Master toggle.** Switch NUZLOCKE OFF → ON → OFF → ON. **Expected:** Label changes immediately; rule values in other rows do not reset.
- [ ] **M06 — Compact PLAYSTYLES.** Open NUZ RULES → PLAYSTYLES. **Expected:** Exactly four rows: SHINY NUZ toggle, its DETAILS directly below, HARDCORE toggle, its DETAILS directly below. No stray rule-description lines.
- [ ] **M07 — Details and return.** Open both DETAILS screens, scroll their explanations and press B. **Expected:** Complete rules are visible in the correct details screen and the selector returns to the same row. Each toggle changes only its corresponding playstyle.
- [ ] **M08 — Advanced Rules navigation.** Open NUZ RULES → ADVANCED RULES. **Expected:** Exactly nine categories in order: CATCH RULES, BATTLE CLAUSES, STATUS BANS, VARIANTS, BATTLE ITEMS, FIELD ITEMS, SERVICES & ECONOMY, POKEMON STATS, AREA SPLITS.
- [ ] **M09 — Advanced placeholder behaviour.** Open each ADVANCED RULES category and one rule inside; go back twice. **Expected:** The CATCH RULES page has six working controls; its other [Soon] entries and the other eight categories remain unavailable. B returns to the selected category, then to ADVANCED RULES in NUZ RULES.
- [ ] **M10 — Removed categories.** Look through NUZ RULES, including ADVANCED RULES. **Expected:** Neither WORLD nor UI appears; ALMANAC and MOD COMPAT remain separate [Soon] placeholders on NUZ MENU.
- [ ] **M11 — Working Catch Rules.** Open ADVANCED RULES → CATCH RULES, toggle No Legendaries, No Mythicals, No Pseudos, No Static Encounters and No Fishing, and cycle Maximum BST. **Expected:** All six show saved values; the other entries remain [Soon] and cannot be toggled. With CORE → NUZLOCKE ON, these four settings affect native wild captures only as described in [Advanced Rules](GEN3_ADVANCED_RULES.md).
- [ ] **M11a — Catch bans and encounter slots.** With FAILED ENCOUNTERS ON, attempt a prohibited wild capture on an unused route. **Expected:** No catch, accurate NUZ NOTICES message and no spent encounter slot. Catch an allowed wild Pokémon there; the slot is then consumed.
- [ ] **M11b — Save and master switch.** Save/reload the selected bans; then disable CORE → NUZLOCKE and try a prohibited capture. **Expected:** Settings persist but native capture is allowed while master enforcement is OFF.
- [ ] **M11c — Final species.** Try a randomised Pokémon and an Untamed overworld encounter. **Expected:** The bans inspect the species actually fought, and shiny exceptions cannot override a prohibited species.
- [ ] **M11d — No Fishing.** On a water route where fishing normally works, enable No Fishing and try Old/Good/Super Rod. **Expected:** Rod use is stopped before fishing begins, and NUZ NOTICES explains why; surf and ordinary wild battles are unchanged. Turn OFF and verify rod use resumes.
- [ ] **M11e — No Static Encounters.** At a scripted fixed wild Pokémon, enable No Static and attempt capture. **Expected:** Ball capture is refused without ending the story battle or spending the route slot. Roamers and normal random wilds remain legal. Restore the option afterwards.
- [ ] **M12 — Save persistence.** Enable Nuzlocke, change one rule, save **in game**, restart and reopen the menu. **Expected:** Master switch and saved rule values persist.

## A2. New CORE clauses (disposable saves; WIP)

- [ ] **N01 — Catch naming (mod-only).** With CORE → NUZLOCKE ON and NICKNAME ON, catch a wild Pokémon using the normal unmodified Gen1Recomp engine. **Expected:** No nickname Yes/No question is displayed; native naming opens immediately.
- [ ] **N01a — PC-bound capture.** Fill the party, catch a wild Pokémon, and attempt an empty/species-default nickname. **Expected:** Naming reopens; the catch cannot complete and the PC transfer message cannot finish until a custom nickname is confirmed.
- [ ] **N01b — No-bypass fallback.** If another UI mod still displays an unexpected Yes/No prompt, choose No. **Expected:** Nuzlocke still forces the naming path, never completing a catch unnamed. Record the other mod and game version for diagnosis.
- [ ] **N02 — Reject default.** Submit an empty name, whitespace-only name, cancelled name or exact species name. **Expected:** Native naming reopens; the Pokémon is not accepted unnamed. A custom name finishes normally.
- [ ] **N02a — Switch off enforcement.** Turn NICKNAME OFF and catch another wild Pokémon. **Expected:** The native Yes/No choice is offered again, and No is accepted.
- [ ] **N02b — Repeat after load.** Save/reload and catch another Pokémon with the rule ON. **Expected:** No Yes/No bypass after reopening the game.
- [ ] **N02c — Untamed compatibility.** Catch a wandering overworld Pokémon with NICKNAME ON. **Expected:** It uses the same mandatory naming flow.
- [ ] **N03 — Gift/trade/Egg.** Acquire each without a naming prompt, then open NUZ MENU → NICKNAME TASKS. **Expected:** Unnamed acquisitions appear, including those in a PC box. Rename them and confirm they disappear.
- [ ] **N04 — Persist.** Save and reload after naming a Pokémon and after leaving one name pending. **Expected:** Correct nicknames and pending entries remain consistent.
- [ ] **R01 — First rival, Kanto.** In a NEW FireRed or LeafGreen run, enable mercy before the Oak Lab rival battle and let your starter faint. **Expected:** No death/graveyard entry and no Nuzlocke failure; the native story proceeds.
- [ ] **R02 — Mercy consumed.** Win the opening rival battle, then revisit later rival battles. **Expected:** The opening fight consumes mercy on start, whether won or lost; later fainting is permanent.
- [ ] **R03 — Hoenn editions.** Repeat R01–R02 for Ruby, Sapphire and Emerald, changing starter matchups. **Expected:** Only Route 103's opening rival fight is exempt.
- [ ] **C01 — PC recovery.** With Whiteout Ends Run OFF and PC Survivors ON, box a healthy spare, then let the party wipe. **Expected:** One eligible living boxed Pokémon moves into the now-empty party; the run continues.
- [ ] **C02 — Whiteout priority.** Enable both Whiteout Ends Run and PC Survivors, then lose with a living reserve boxed. **Expected:** Run fails regardless; the reserve remains boxed.
- [ ] **C03 — No survivors.** Wipe with only Eggs, dead/fainted or ineligible boxed Pokémon. **Expected:** Run fails; no Pokémon is revived or cloned.
- [ ] **C04 — Recovery persistence.** Save and reload after C01. **Expected:** Rescued Pokémon exists exactly once, in the party, absent from its old box.

**Known WIP limitation:** Unresolved gift/trade/Egg nicknames are tracked and can
be renamed, but are not yet prevented from battling. All checks above need
real game testing; passing a mocked Lua smoke does not certify them.

## Rule feedback and Rare Candy regression\n\nFollow **F01–F11** in [GEN3_FEEDBACK.md](GEN3_FEEDBACK.md), especially a capped Rare Candy from the overworld bag, cancelled catch reasons, EXP edging messages, and viewing long messages through NUZ NOTICES.\n\n## RANDOMIZER smoke (disposable save)\n\nRun **R01–R14** in [GEN3_RANDOMIZER.md](GEN3_RANDOMIZER.md): deterministic wild/fishing/trainer teams, seed editor, configuration locking, pool legality and ROM/story progression.\n\n## LEVELS smoke (disposable save)

Run tests **L01–L10** in [GEN3_LEVELS.md](GEN3_LEVELS.md), including
scope transitions, the first Gym, bank persistence through PC/reload and
Rare Candy consumption. Mocked CI is not a replacement for ROM tests.

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
- [ ] **D04 — Graveyard details.** Open GRAVEYARD and NUZ STATUS. **Expected:** One death entry, a Pokémon name (nickname or species), readable species name and location (e.g. Pidgey / Route 1), correct level, no duplicates. Internal species/map IDs should not be the primary player-facing text.
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

## CLAUSES milestone — Dupes / Shiny exceptions

Run the separate **[Gen 3 CLAUSES test matrix](GEN3_CLAUSES.md)**, which has
14 detailed checks covering SPEC/FAM/SPLIT, shiny allowances, save
persistence, NUZ DEV resets and other editions.

- [ ] **L01 — Dupes SPEC:** catch an owned species on a new route; it must be
  blocked **without spending** that route's normal catch.
- [ ] **L02 — Dupes FAM/SPLIT:** verify Caterpie-line evolutions count as
  one family, while branching Eevee evolutions differ under SPLIT.
- [ ] **L03 — Shiny exception:** on a spent route, an eligible shiny may be
  caught using an available exception, but a normal Pokémon may not.
- [ ] **L04 — Allowance accounting:** failed Balls do not spend a Shiny Clause
  allowance; a successful exceptional capture does.
- [ ] **L05 — [Soon] handling:** Egg and Forgiveness remain inert, Shiny Rate and Roamer are [WIP] and can be configured. Native shiny palettes/intro effects remain unchanged.
- [ ] **L06 — Development reset:** NUZ DEV's RESET CLAUSE COUNTS requires
  confirmation and resets the shiny allowance count and captured-species log
  without altering party, boxes or graveyard.

## Roamer Clause (currently [WIP])

Requires an active roaming legendary, so use a disposable late-game save.
The Gen 3 engine emits `roamer.encountered` when supported, but the result
still needs confirmation in real FireRed / Hoenn gameplay. The full set of
six roamer-specific tests is [R01–R06](GEN3_CLAUSES_NEXT.md).

- [ ] **R01 — Flee without spending route.** ROAMER SLOT + Failed Encounters ON. Flee a native roaming encounter; the normal route remains open.
- [ ] **R02 — Catch later.** Encounter the same roamer on a second route and catch it. The roamer's species slot closes but the second route's grass slot remains available.
- [ ] **R03 — Stable results.** Save and load; the roamer claim remains closed. NUZ DEV clause reset clears the debug claim only, not the actual Pokémon.

## Shiny Rate & future Forgiveness archive

Use a **disposable save** and the new [Shiny Rate contract](GEN3_CLAUSES_NEXT.md)
for the scope and provider-ownership decisions. The 1/8192 native chance is
not something you can validate with a handful of normal encounters; use
**ALWAYS** to verify the enhancement path deterministically.

- [ ] **SR01 — Six-entry CLAUSES menu.** Open CLAUSES. **Expected:** Dupes,
  Shiny Clause, Shiny Rate, Roamer Clause, Egg Encounter and Route Forgiveness.
  Shiny Colours and Shiny Intro should **not** appear; original Gen 3
  shiny palettes/animations are unchanged.
- [ ] **SR02 — ALWAYS on a fresh wild encounter.** Set Shiny Rate ALWAYS.
  Enter a new normal wild battle. **Expected:** The Pokémon is visibly shiny
  even without any Shiny Clause catch allowance.
- [ ] **SR03 — Saved individual shiny.** Catch that enhanced shiny and save,
  then restart and view its summary/party sprite. **Expected:** It remains
  shiny, with the same personality, species and original IVs/stats.
- [ ] **SR04 — Master OFF doesn't suppress odds.** Switch Nuzlocke OFF but
  leave Shiny Rate ALWAYS; encounter a new wild Pokémon. **Expected:** Still
  shiny; the independent difficulty/visual configuration does not depend on
  hardcore enforcement.
- [ ] **SR05 — No trainer/tutorial boost.** Battle a trainer, and, if
  available, check a scripted tutorial battle. **Expected:** Shiny Rate
  doesn't artificially change the opponent's or tutorial Pokémon's identity.
- [ ] **SR06 — Roamer exclusion.** If available, test a persistent roaming
  Pokémon while Shiny Rate ALWAYS. **Expected:** The enhanced rate does not
  randomly change that same roamer's shiny identity between encounters.
- [ ] **SR07 — External ownership.** If a compatible external shiny provider
  is active, open Shiny Rate. **Expected:** EXTERNAL is displayed; selecting
  it doesn't alter that provider's rate or stack another roll.
- [ ] **SR08 — Native mode.** Set Shiny Rate back to NATIVE. **Expected:**
  No forced-shiny behaviour on normal non-shiny Pokémon.
- [ ] **AR01 — Death archives.** Let a new Pokémon faint and open the Graveyard.
  **Expected:** The existing readable memorial remains correct; archived
  Pokémon data is retained for future recovery but no revival option appears.
- [ ] **AR02 — Legacy deaths.** Reopen an older graveyard entry without the
  complete archive. **Expected:** It still shows species, level, nickname (if
  stored) and location, but does **not** offer approximate restoration.

**Egg Encounter and Route Forgiveness remain [Soon].** It is a known pending
feature—not a failure—that the UI cannot enable Egg counting or redeem
Forgiveness Tokens yet.

## Egg Encounter & Route Forgiveness

See [GEN3_EGGS_FORGIVENESS.md](GEN3_EGGS_FORGIVENESS.md) for the full
twelve-case checklist and exact [WIP] limitations.

- [ ] **EG01 — Receipt claim:** With RECEIVED selected, tag an Egg on Route A
  then hatch on Route B. The A encounter slot is spent *at hatch*.
- [ ] **EG02 — Hatch claim:** With HATCHED selected, the hatch location's
  encounter slot is spent when the Egg hatches.
- [ ] **EG03 — Occupied area:** Hatching into an already spent area records
  the Pokémon as INELIGIBLE without deleting it; using the Pokémon in battle
  is **not enforced yet**.
- [ ] **FG01 — Starting token:** START 1 grants a single token once; toggling
  it or restarting does not grant another.
- [ ] **FG02 — Badge reward:** A new Gym Badge after enabling grants one
  token, not multiple tokens on map transitions.
- [ ] **FG03 — Route redemption:** Spend one token to reopen a failed route.
  Test CANCEL first, then YES; caught routes and previously forgiven routes
  cannot be reopened again.
- [ ] **FG04 — Development testing:** NUZ DEV → ADD TEST TOKEN grants one
  test token after confirmation, leaving the test-run marker set.
- [ ] **FG05 — Recovery limitation:** The Pokémon-revival option remains
  [Soon] and must never spend a token.

## E. Compatibility & known pending features

- [ ] **C01 — Gen 1 regression.** If you have an original Red/Blue/Yellow setup, open the original Nuzlocke UI. **Expected:** Established Gen 1 menu and rules unchanged.
- [ ] **C02 — Gen 2 regression.** If you have Gold/Silver/Crystal configured, open its Nuzlocke UI. **Expected:** Established Gen 2 menu unaffected.
- [ ] **C03 — Second Gen 3 edition.** Repeat **M01, E01–E03 and D01–D03** in another edition (ideally Emerald after FireRed). **Expected:** Same basic results; record the exact edition.
- [ ] **C04 — Double battle stress test.** If convenient, faint one player Pokémon during a native double battle. **Expected:** Forced switching does not crash or shift the wrong party slot; death is recorded exactly once.
- [ ] **C05 — Unsupported rules remain inert.** Inspect Nickname, First Rival Mercy, PC Survivors, Gifts, shiny-rate controls, Randomiser and other [Soon] items. **Expected:** They are visibly labelled pending and cannot claim active enforcement.

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


## Shiny Nuzlocke playstyle (v3.0.0-BETA)

Follow tests **S01–S11** in [Gen 3 Playstyles](GEN3_PLAYSTYLES.md):
non-shiny Ball rejection and unused route slots, eligible shiny
encounters with Failed Encounters ON/OFF, Shiny Clause precedence,
shiny-rate independence, saves and Untamed wandering wild captures.

## Hardcore Nuzlocke playstyle (v3.0.0-BETA)

Use **H01–H11** in [Gen 3 Playstyles](GEN3_PLAYSTYLES.md). Verify
effective CORE overrides, native battle bag refusal (Poké Balls allowed),
forced SET response, boss EXP/Rare Candy caps, mode combinations and
instant restoration on Hardcore OFF. Use a disposable ROM save.
