# Nuzlocke 2.7.28 — Gen2 boot and title SETUP repair

2.7.28 is a strict child of exact 2.7.27 and retains Randomizer Phase E items 1–6 unchanged.

## Confirmed runtime failures addressed

External Gen1Recomp 0.2.20 evidence showed the inherited 2.7.25 code aborting Gen2 initialization because `late_runtime.lua` required `showRuleMessage`, but that dependency was only created inside the R/B/Y field-command installer. Gold correctly skips that Gen1 installer.

A separate direct runtime test confirmed:
- Yellow fresh NEW GAME: SETUP appears — PASS.
- Gold fresh NEW GAME: SETUP missing — FAIL.

## Repairs

- Hoists `showRuleMessage` and `acquisitionDeniedMessage` out of the Gen1-only installer so late runtime receives them on both generations.
- Gen1 keeps its native script-command text path; Gen2 uses the shared game-stack TextBox fallback and does not require Gen1 `src.script.Commands`.
- Adds a Gen2-only `MainMenu.buildList` final-list fallback because Gen1Recomp 0.2.20 can bypass the shared `ui.title_menu.items` result for Gold.
- Fresh Gold/Silver title lists insert SETUP immediately before NEW GAME.
- Continued games fail closed: `self.hasSave == true` or an actual CONTINUE row suppresses SETUP and removes any stale Nuzlocke-owned SETUP row.
- Existing `MainMenu:choose()` handling remains responsible for SETUP/NEW GAME/CONTINUE dispatch and staged-profile cleanup.
- Adds wrapper-contract and Release Safety coverage for the new Gen2 title-list seam and late-runtime dependencies.

## Runtime status

The Yellow PASS and Gold fresh-game FAIL above describe the parent behavior that motivated this repair. The repaired 2.7.28 Gold/Silver fresh-game and continued-game paths are **TEST REQUIRED**.
