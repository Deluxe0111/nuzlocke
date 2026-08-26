> Standalone Gen-I shiny fallback now accepts both Gen1Recomp `battle.started` payload shapes (`payload.battle` and a direct BattleState), fixing Shiny Rate ALWAYS doing nothing in Red/Blue/Yellow when Nuzlocke is the only shiny owner.

2.8.36 standalone shiny regression fix: external shiny ownership now requires a live separate provider handle before registry/API claims are trusted, preventing Nuzlocke-only runs from falsely standing down their built-in shiny system.
# Nuzlocke 2.8.37 — Release Notes

## Release status

2.8.37 is the full-release promotion of the latest corrected 2.8.36 candidate. The code path that runtime-passed Red standalone shiny testing is unchanged.

### Runtime-confirmed in Red

- Nuzlocke-only shiny ownership is active when no external shiny provider is installed.
- `Shiny Rate = ALWAYS` produces shiny wild encounters.
- Gen I shiny species recoloring is visible in battle.
- Shiny intro presentation fires for the wild encounter.
- Confirmed across multiple species in runtime testing (Rattata and Kakuna).

### Included compatibility work

- Gen1Recomp 0.2.27 `catch.nickname` migration with older-engine fallback.
- Palette-aware Gen II Nuzlocke utility screens.
- 0.2.27 compatibility diagnostics and Release Safety coverage.
- Shiny Pokémon 1.2.7 explicit provider compatibility and single-owner failover.
- Gen II native shiny ownership architecture and narrow Crystal shiny-presentation safety boundary remain intact pending exact-edition certification.


## Shiny Pokémon 1.2.7 compatibility

- **Shiny Pokémon 1.2.7** is now the explicit audited companion target for Gen1Recomp 0.2.27 across **Gen I and Gen II**.
- Nuzlocke now prefers its public provider registry (`SHINY_IDENTITY` + `SHINY_PRESENTATION`) and Shiny Pokémon's generation-neutral `exports.shiny_pokemon` / `exports.shiny_compat` API when deciding external shiny ownership. The inherited top-level `isShiny` / `rollShiny` probe remains only as a fallback for older builds.
- This fixes a real Gen-II coexistence gap: Shiny Pokémon 1.2.x intentionally does not execute the inherited Gen-I `main.lua` on Gold/Silver/Crystal, so its maintained Gen-II path may not expose the old top-level functions even though it correctly owns shinies.
- When Shiny Pokémon 1.2.7 is active, Nuzlocke immediately hides/stands down **Shiny Rate / Shiny Colors / Shiny Intro**, performs no second shiny roll or presentation, and retains only Nuzlocke-owned **Shiny Clause** plus read-only shiny identity consumption.
- Gen1Recomp remains the sole owner of Renderer/Assets invalidation during Gen-I COLORS/custom-ramp transitions. Nuzlocke does not reset engine caches. For custom/unknown species whose fallback shiny palette depends on PaletteFX, the relevant mode/custom-ramp signature is now part of Nuzlocke's **private** derived-image cache key, so a new private artifact is selected without touching engine resources.
- The Gen-II native `shiny.roll` path and narrow Crystal `shiny-flash` safety shim remain Nuzlocke-owned only when no external shiny provider is active.

## Gen1Recomp 0.2.27 compatibility

- **R/B/Y Nickname Rule** now uses Gen1Recomp 0.2.27's public `catch.nickname` decision hook at the cart's catch-nickname boundary. The existing `askNicknameUI` enforcement remains to prevent a required nickname from being declined/confirmed empty, and the older `battle.nickname` path remains only as a 0.2.24-0.2.26 compatibility fallback.
- **Gen II Nuzlocke utility UI** now follows the engine's palette-aware `src.ui.gen2.Chrome` primitives on the shared NUZ STATUS and Recover Catches surfaces. Custom 0.2.27 GB/COLOR palettes therefore apply to Nuzlocke paper, ink, boxes, cursors, and wrapped text instead of dropping back to literal white/black.
- The live Gen II Setup/NUZ RULES Chrome path no longer forces raw black/white draw state after Chrome has selected the active palette.
- Added Release Safety coverage protecting the new public nickname seam, old-engine fallback, nickname enforcement layer, and the palette-aware Gen II utility surfaces.
- **Gen II shiny send-out safety was source-revalidated against 0.2.27.** The engine still contains the queued `shiny-flash` event, so Nuzlocke retains its narrow Crystal safety interception while it owns shinies: consume only that event, restore both battler picture latches, and continue the native queue. Nuzlocke still does not own Gen II `draw` or `update`.
- The global source/documentation-audited engine marker is now **0.2.27**. MOD COMPAT therefore reports 0.2.27 as the active audited profile while exact-edition runtime certification remains separate.
- Added explicit 0.2.26 and 0.2.27 compatibility profile rows so diagnostics never point at an audited version with no profile entry.
- Expanded Release Safety to require the 0.2.27 profile/marker and the Gen II shiny event guard, both picture-latch restores, and continued non-ownership of Gen II `draw`/`update`.


## Corrective shiny ownership + Gen II safety

- Nuzlocke-alone keeps **Shiny Rate**, **Shiny Colors**, and **Shiny Intro** visible and configurable.
- When a compatible external shiny provider is active, Nuzlocke hides those three controls and immediately delegates shiny generation/presentation to that provider. **Shiny Clause** remains in Nuzlocke because it is a challenge-rule/catch-exception control.
- Added the Crystal-certified Gen II shiny send-out safety behavior used by the maintained Shiny Pokémon 1.2.x line: when Nuzlocke owns Gen II shinies, the unsafe queued `shiny-flash` event is consumed, both battler picture-hidden latches are restored, and the native battle queue continues immediately.
- Nuzlocke still does not replace Gen II `BattleState.draw` or `BattleState.update`; the existing `battle.overlay` hook owns the optional sparkle/SFX cue.
- With an external shiny provider installed, that provider's own Gen II presentation workaround is left untouched.

**Corrective rebuild:** the first 2.8.36 package failed Lua compilation after the shiny pass pushed the entry function over Lua's active-local limit. This package scopes provider aliases inside the resolver; shiny behavior is unchanged.

## Full built-in shiny support

- Nuzlocke can now provide the complete shiny experience itself when no compatible shiny mod owns the active edition.
- **Shiny Rate** controls rarity.
- **Shiny Colors** controls shiny recoloring without changing shiny identity.
- **Shiny Intro** controls the one-shot battle sparkle/audio cue without changing colors or catch rules.
- **Shiny Clause** remains catch exceptions only and is still independent of all three presentation/rate controls.

## Current-engine integration

- Shiny art uses Gen1Recomp's live `pokemon.sprite` and `pokemon.icon` hooks, allowing battle, Summary, evolution/trade/Hall-of-Fame, and other live-mon consumers to receive the shiny variant without replacing their screens.
- Sparkles use `battle.overlay`, the engine seam explicitly intended for shiny indicators/HUD chrome.
- Nuzlocke does not replace `Pokemon.new`, `BattleState.newWild`, `BattleState.draw`, Gen-II battle screens, or renderer composition.
- Derived shiny art is cached after the first bake.

## External shiny-provider failover

- A compatible active shiny provider immediately owns **both generation and presentation** for its edition.
- While externally owned, Nuzlocke performs no second shiny roll, recolor, sparkle, or shiny sound.
- Nuzlocke still recognizes the provider's shiny identity for Shiny Clause, catch legality, Catch Info, tracker history, and run state.
- `SHINY_POKEMON` remains an explicit optional compatibility target, but ownership is capability-based so future compatible shiny providers can use the same contract.

## Runtime focus

Test one Gen-I edition first with **Shiny Rate = ALWAYS**, **Shiny Colors = ON**, and **Shiny Intro = ON**. Confirm the wild Pokemon is visibly recolored, receives the one-shot sparkle/audio cue, remains shiny after capture, and is shown as shiny on Summary/Catch Info. Then enable a compatible external shiny provider and confirm Nuzlocke immediately stands down on its own roll/visual effects while Shiny Clause/tracking still recognize the provider-owned shiny. Gen-II testing remains exact-edition.

### Corrective standalone shiny fix
The corrected 2.8.36 establishes shiny identity before Gen I battle art is resolved, uses official species-specific Crystal shiny colors for Gen I, and preserves Gen II's native shiny palette pipeline. `ALWAYS` should now be visibly testable with Nuzlocke alone in Red/Blue/Yellow and through native shiny state in Gold/Silver/Crystal.