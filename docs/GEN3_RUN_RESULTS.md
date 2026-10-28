# Gen 3 — End Run, Hall of Fame & final results (v3.0.0-BETA)

This feature is isolated to Gen 3 (FireRed/LeafGreen and Ruby/Sapphire/
Emerald). It does **not** change the Gen 1/2 UI or the native Hall of Fame
progression.

## Finishing a run

From **Start → NUZ MENU → END RUN**, select **CONFIRM END RUN**.
An explicit confirmation states that the action cannot be reversed.
**KEEP PLAYING** or B returns to gameplay without changing the run.

Manual End Run finalises as a **FORFEIT** (loss). On confirmation the mod:
1. Builds a frozen results snapshot with the party, graveyard,
   encounters, catches, location, badge count, play time, trainer,
   Pokémon species/nicknames, levels and available saved stats.
2. Marks the Nuzlocke as failed, recording `finalResult` in the existing
   `gen3_classic_v1` mod save namespace.
3. Calls the **native Gen 3** `game:saveGame()` once. The raw
   `Game3` service exposed through `mod.game` does **not** implement
   the Gen 1/2 `writeSave()` method. The native Gen 3 writer persists
   script flags, the live party and normal mod-data fields using the
   standard save hooks and save pipeline.
4. Opens a dedicated full-screen Gen 3 results UI.

If a native battle ends with a whiteout/no usable survivors and the
configured rules fail the run, exactly the same snapshot/autosave flow
starts automatically **after battle party writeback and faint retirement**.
A whiteout rescued by an allowed living PC survivor does not automatically
end the run; the existing Hardcore/CORE survival policy stays authoritative.

A failed / forfeited save is **terminal**: using CONTINUE to load the native
save immediately reopens the results screen, not the ordinary Nuzlocke
menu. The terminal screen is kept above game UI layers after map enters
and world steps. Pressing B/START cannot dismiss its root page. Available
actions are reading statistics, reading the final roster/graveyard,
exporting memorial PNGs, retrying a failed save and **QUIT TO TITLE**.
There is no CONTINUE ADVENTURE for a loss.

The native save is **kept** and can be loaded to view and export the
records again. The feature never deletes native saves.

An unsuccessful auto-save is **not** reported as successful: the results
screen shows **AUTOSAVE FAILED**, and **RETRY / SAVE RUN** attempts the
native write again. Ensure that write is successful before exiting.

## Champion victory

When the engine's Hall of Fame screen **closes after genuine induction**
(`session.game_cleared` and at least one native HoF entry present), a
Nuzlocke run creates a permanent **VICTORY** snapshot and saves it through
`game:writeSave()`. Merely winning an ordinary trainer fight does not
count, and the engine keeps control over credits and normal HoF effects.

The victory results screen contains:
- **RUN STATISTICS** — time, trainer/region, badges, claimed areas,
  successful catches, used encounters, deaths, shiny exceptions, outcome.
- **FINAL PARTY** — the team remaining at HoF, by nickname/species,
  level, stats, and moves where available.
- **GRAVEYARD / IN MEMORIAM** — every recorded permanent death, with
  captured nickname/species/level, cause, location, and preserved
  pre-retirement archive stats where available.
- **SHARE PARTY PNG** — an exportable party image using the native
  game’s Pokémon front sprite assets where available.
- **CONTINUE ADVENTURE** — dismisses the results, leaving native credits/
  postgame progression intact.
- **QUIT TO TITLE** — returns to the game's title menu.

A victory does *not* set `failed`. The result is snapshotted once and
can be reopened from **END RUN** later without ending postgame play.
Starting a genuinely new game starts a fresh run record.

## PNG export

Choose **SHARE PARTY PNG** on victory, or **SHARE MEMORIAL PNG** after a
failed run. Each 960 × 540 PNG is a standalone share card with trainer,
outcome, time, badges, encounters/deaths, six Pokémon per page and native
front artwork, species, names, levels and selected stats/details.

Graveyards larger than six Pokémon expose a **PAGE N / M** control.
Select **SAVE PAGE AS PNG** to export each page independently.

PNG files are saved in the **root of the game’s LÖVE save folder**:

`<LÖVE save directory>/nuzlocke_<trainer>_<result>_<date>_<page>.png`

The game’s mod sandbox does **not** allow access to `love.filesystem`.
The PNG export therefore uses the sanctioned
`ImageData:encode("png", filename)` path, which saves directly into
the game’s writable LÖVE directory without creating folders.

The popup confirms the filename. Players can then attach that PNG to
Discord, forum posts or social media. The mod does **not** automatically
upload private player data or images to any external service. Export
requires an active LÖVE graphics/filesystem context and native ROM
sprite assets; when a sprite is unavailable, the textual record still
exports. In headless tests the graphics functionality is stubbed.

This is an independently generated results-card PNG, not a full-window
screenshot or a modification of the actual Hall of Fame ROM scene.

## Compatibility / caveats

- The Nuzlocke CORE rule must be enabled for End Run. Players without an
  active Nuzlocke do not accidentally forfeit a casual save.
- Full loss screens depend on the mod's existing whiteout/permadeath
  policy. If the policy allows continuing, the game does not force loss.
- The original graveyard is not discarded. Results copy small, bounded
  display snapshots; they are *not* revival sources or substitutes for
  the full existing graveyard archives.
- If an older save is already marked `failed` but has no final snapshot,
  a terminal results summary is created on load. Historic Pokémon stats
  not present in that older save remain unknown rather than invented.
- A result created once is never overwritten by later game progression
  or repeat Hall of Fame ceremonies.
- The PNG card reads the native `Pokemon.monFrontPic` art available
  in the running ROM. The output may differ between FRLG and RSE.

## Manual in-game checklist

- [ ] **ER01** FireRed: choose END RUN, cancel once, then confirm. No
  save/result may be written on cancel; confirmation writes a save
  and displays FORFEIT.
- [ ] **ER02** Quit to title, use CONTINUE, verify that results appear
  immediately and pressing B/START cannot resume movement, menus,
  battling or game actions.
- [ ] **ER03** Trigger a whiteout under CORE/HARDCORE run-failure
  conditions. Confirm all fallen Pokémon appear in the memorial,
  the native save is written, and reload remains terminal.
- [ ] **ER04** Trigger a whiteout with PC Survivor rescue enabled and
  an eligible living PC Pokémon. Verify no false finalisation.
- [ ] **ER05** Deny native `save.write` intentionally: failure is visible,
  retry is available, and no false 'saved' confirmation is shown.
- [ ] **ER06** Beat the FRLG Champion, complete HoF induction, inspect
  the final six-Pokémon team and continue through native postgame.
- [ ] **ER07** Repeat for Ruby/Sapphire/Emerald. Verify native credits,
  flags and Hall of Fame save state are not suppressed.
- [ ] **ER08** Export victory party PNG and failed memorial PNG, verify
  filename, full 960×540 dimensions, native sprites and readable text.
  Check multi-page memorials with more than six deaths.
- [ ] **ER09** Load an old `failed=true` save without `finalResult`;
  confirm a retrospective memorial appears without inventing metadata.
- [ ] **ER10** Save after victory, reload and use END RUN to inspect the
  stored Champion results without ending the continued adventure.

## Automated tests

- `tests/gen3_run_results_smoke.lua` exercises policy snapshots, loss
  lock, victory continuation, record navigation and PNG encoding.
- `tests/gen3_run_results_runtime_smoke.lua` exercises the actual
  Gen 3 runtime callback wiring: End Run confirmation, native
  `saveGame`, failed CONTINUE reload, battle whiteout and HoF close.
- Both run in `.github/workflows/gen3-smoke.yml` with Lua 5.1.
