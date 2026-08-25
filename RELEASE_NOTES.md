# Nuzlocke 2.8.02 — Hotfix Release Notes

2.8.02 fixes dynamic Randomizer child-option visibility in Setup and NUZ RULES. In Crystal/Gen II, enabling **Random Trainers** now immediately exposes **Trainer Balance**, **Trainer Diversity**, and **Trainer Theme**. The same refresh correction is applied to the other Randomizer parent/child rows that use dynamic visibility. No Trainer Randomizer generation logic was changed.

The known Gen II party-target item-use defect remains unresolved.

# Nuzlocke 2.8.01 — Hotfix Release Notes

2.8.01 is a focused strict-child hotfix from exact published 2.8.00. It restores the missing Trainer Randomizer options in Gold/Silver/Crystal Setup and NUZ RULES, and fixes the Nuzlocke-side wipe decision for overworld poison deaths when the last usable party Pokémon faints but Gen1Recomp does not report `event.whiteout`.

**Known issue unchanged:** Gen II party-target healing items, vitamins, Rare Candy, and similar consumables can still return to the Pack after target selection without applying.

# Nuzlocke 2.8.00 — Release Notes

2.8.00 is the full-release package requested from the exact 2.7.106 parent. It carries forward the 2.7.x rule/UI/randomizer/compatibility work and adds one focused release repair for the outstanding Crystal party-item transaction plus a final navigation-feel adjustment.

For Gen2 field Pack party consumables, selecting a target now resolves the chosen slot back to the live save-party Pokémon and executes Gen1Recomp's own ItemEffects/consumption/message semantics directly at the Pack seam after Nuzlocke legality checks. This covers healing/status/revive items, vitamins and Rare Candy. PP items, evolution stones, TMs/HMs, battle items and non-party field items keep their specialized native paths. Rare Candy-to-cap remains available for finite caps.

Held UP/DOWN navigation in New Game Setup and NUZ RULES now accelerates more gently and reaches a slightly slower maximum rate: about 0.48 s initial delay, then 0.27 / 0.23 / 0.19 / 0.15 / 0.11 s repeat gates. SELECT+UP/DOWN still jumps sections. Runtime-PASS Profile Slot / Save Profile / Load Profile behavior and the default World Building T3 setting remain unchanged.

The package passes static/package verification; the new Gen2 party-item commit repair still requires exact Crystal runtime confirmation.

# Nuzlocke 2.7.106

Focused corrective child of exact 2.7.105. Crystal runtime confirms target selection now avoids the wrong Pokémon submenu, but Rare Candy, vitamins, and healing items still fail to apply and simply return to the Pack. 2.7.106 fixes that shared post-selection consumable execution path using Gen1Recomp's own Gen2 ItemEffects on the selected Pokémon, preserving specialized native PP/evolution-stone flows and Rare Candy-to-cap behavior. Held UP/DOWN scrolling is retuned to a slower five-stage acceleration curve; SELECT+UP/DOWN remains section navigation. TOOLS profile controls stay protected runtime PASS and World Building remains default T3. Runtime test required.

# Nuzlocke 2.7.105

Focused corrective child of exact 2.7.104. Crystal runtime identified the Gen2 party-item failure as a chooser-mode bug rather than a Pokémon record/item-effect failure: selecting a target from "Use on which Pokémon?" opened the normal Pokémon action submenu. 2.7.105 restores direct item-target chooser semantics for that screen only. It also adds held UP/DOWN rapid scrolling to New Game Setup and NUZ RULES while preserving SELECT+UP/DOWN section navigation. TOOLS profile controls remain protected runtime PASS; World Building remains default T3. Runtime test required.

# Nuzlocke 2.7.104

Corrective child of 2.7.103. Crystal runtime confirms the TOOLS Profile Slot / Save Profile / Load Profile behavior now works as intended; that code is unchanged. Party-target item use on the randomized Steelix is still failing. 2.7.104 removes the unsuccessful direct Pack-to-Game2 item routing and restores native Gen1Recomp dispatch. The tracked randomized Elm starter is rematerialized in place using Gen1Recomp's native Gen2 Pokémon builder contract, including native stats/DVs/stat-exp/type/move/happiness/pokerus structure while preserving live run state and Nuzlocke identity/provenance. Existing saves are repaired at the next party-item attempt. Runtime retest required.

# Nuzlocke 2.7.103

Focused corrective child of 2.7.102. Gen2 party-target consumables now bypass the fragile Pack/world classification seam and enter the engine-owned `Game2:usePartyItem` path directly after Nuzlocke legality checks. TOOLS profile controls are clarified: Profile Slot selects OFF/1/2/3, while Save Profile and Load Profile perform their named actions on that slot. World Building defaults to T3 in all games for fresh/default configurations. Existing explicit World Building choices are not overwritten. Runtime retest required.

# Nuzlocke 2.7.102

This focused corrective build continues directly from 2.7.101. Gen2 party-target item use now repairs owned Pokemon species-key representation immediately before native `Game2.usePartyItem` handling, covering Potion, vitamins, Rare Candy, and other native party-target effects without replacing native effect ownership.

TOOLS profile controls again expose a shared **OFF / 1 / 2 / 3** target. LEFT/RIGHT on Profile Slot, Save Profile, or Load Profile changes the target. A cycles Profile Slot; A on Save/Load performs the action when slots 1-3 are selected. OFF is a no-action state.

Runtime certification remains required on Gen2.

# Nuzlocke 2.7.101

Focused runtime repair after 2.7.100.

NUZ MENU activation and utility-page formatting are repaired. Gen2 randomized starter finalization now canonicalizes the concrete party record's species identity so Gen1Recomp's native party-target item effects can resolve the randomized species normally.

Runtime certification required before 2.8.0.

# Nuzlocke 2.7.101

Final 2.7.x UI-consolidation build before 2.8.0.

The ordinary in-game START menu now contains a single Nuzlocke-owned **NUZ MENU** entry. It opens NUZ RULES, ENC TRACKER, NUZ STATUS, MOD COMPAT, and—when enabled—DEV TOOLS. Pokemon/stat-page NUZ INFO is intentionally unchanged.

Runtime certification is required on Gen1 and Gen2 START-menu navigation.

# Nuzlocke 2.7.101

Focused Gen2 runtime repair. Runtime certification is required.

Primary targets: prospective full Gen2 ENC TRACKER MAP population in canonical progression order, and restoration of native party-target USE routing for Rare Candy and vitamins while Nuzlocke remains active.

# Nuzlocke 2.7.101

Focused child of 2.7.97. Save Setup is no longer exposed because it was only session staging; persistent reusable configuration is Save/Load Profile. Gen2 MOD COMPAT is rolled back to its known-safe renderer after the 2.7.97 Crystal crash. Gen2 native vitamin field-use metadata is normalized to Gen1Recomp 0.2.25's ITEMMENU_PARTY contract while Nuzlocke is active.

Runtime certification requested: Crystal MOD COMPAT open/close; Crystal PC vitamin USE; Setup TOOLS contents; 2.7.97 tracker and Quick Start nickname repairs.

# Nuzlocke 2.7.101

Focused Gen2 repair release. Runtime certification is required for the changed paths.

Key changes: explicit TOOLS subsection in Setup and Rules, full prospective Gen2 tracker MAP catalog with interior filtering, Crystal Quick Start nickname completion repair, and compact Gen2 MOD COMPAT presentation.

Crystal DST skip remains deferred. The Gen2 vitamin GIVE/TAKE symptom is intentionally not worked around until it reproduces with all mods disabled in Gen1Recomp 0.2.25.

# 2.7.101 — Gen2 services / in-run tools / 0.2.25 compatibility

Gen2 Center Heal and Shop Restrictions receive focused repairs; all editions gain a final in-run TOOLS section with Profile Slot, Save Profile, Load Profile, Save Rules, and Encounter Assignment. Crystal opening System Date/Time now starts DST suppression from semantic SetDayOfWeek. Gen1Recomp 0.2.25 is source/documentation-audited, including read-only imported dataset views and Gen2 VM/battle/save/world changes. Random Starter selection/award code is unchanged. Runtime retest required.

# 2.7.95 — Tracker / Setup / MOD COMPAT / Battle UI cleanup

Strict child of exact 2.7.94 (`3bcc5dddf6cf7143ed13746f1e49084252f5e5108f5562439ade15a746915e94`).

- Freezes the 2.7.94 Random Starter repair after runtime PASS on Red, Silver, and Crystal. Random Starter selection/grant code is unchanged.
- Gen-2 ENC TRACKER MAP now uses a player-facing canonical progression order: Johto progression first, then Kanto, then evidence-backed custom/unknown areas. It no longer treats raw ROM `mapOrder` as presentation order.
- Gen-2 MAP is now an encounter-area guide rather than a raw map browser: ordinary interiors such as cafes/shops are hidden unless they carry real tracker evidence; New Bark Town remains visible for starter provenance.
- Red/Blue/Yellow pre-game NUZLOCKE SETUP explicitly clears inherited title-screen palette tint so normal Setup rows, values, pager, arrows, help text, and chrome render black-on-white like live NUZLOCKE RULES.
- MOD COMPAT gives the title a dedicated row, moves the help-page selector safely above the bottom edge, changes it to `SEL n/n`, and gives the right-side down arrow a slow blink.
- Battle Menu UI ON keeps native input/action authority but replaces the 2.7.93 large translucent rounded rectangle with a compact native-pixel box in the battle-owned bottom-right command region.
- Existing `NUZLOCKE SETUP` / `NUZLOCKE RULES` slash-free titles remain.
- Crystal randomized starter portrait parity remains deliberately unresolved/ALPHA; 2.7.94 runtime confirmed randomized text/award without crash while native Chikorita portrait remains the safe preview.
- No Save Schema, Compatibility API, Diagnostics API, rule count, or Randomizer algorithm change.

# 2.7.94 — Random Starter regression repair

Strict child of exact 2.7.93 (`c7f626def623821e46487dc7f6ac612c4c4b2ed42cb62b62e3969a9e03ab5c00`).

- Runtime bisect established the Gen1 Random Starter regression boundary exactly: **2.7.44 Red PASS → 2.7.45 Red FAIL**. Later Red tests on 2.7.54, 2.7.70, and 2.7.93 also fail by presenting/awarding vanilla starters; published 2.7.28 Yellow is runtime PASS.
- The 2.7.45 delta first coupled Random Starter candidate construction and persisted-choice validation to the shared **Species Pool** generation filter. 2.7.94 surgically restores the last runtime-proven 2.7.44 starter contract: Random Starter uses its own hard-safe live species pool plus Starter Style and challenge legality, independent of Species Pool.
- Species Pool remains available to Random Encounters, Random Trainers, and Random Evolutions. Randomizer presets and every later Randomizer subsystem remain intact.
- This is a forward port into the exact 2.7.93 parent; no older source tree is restored wholesale.
- Changes the R/B/Y Nuzlocke-owned screen header wording from `NUZLOCKE / SETUP` / `NUZLOCKE / RULES` to **NUZLOCKE SETUP** / **NUZLOCKE RULES**.
- Gold 2.7.28's historical `No Glitch Pokemon` Elm symptom remains tracked separately as an older Gen2 provenance/transaction issue; this Gen1 bisect repair does not claim to solve it.
- Rule count remains 151 canonical unique rules across 21 sections. Save Schema remains 5; Compatibility API 34; Diagnostics API 1.
- Runtime certification required: Red New Game Random Starter is the primary acceptance test; Yellow and Gen2 remain independent targets.

# 2.7.93 — Battle Menu UI + Run / Surf consolidation

Strict child of exact 2.7.92 (`fb2ab4828f8c9afed48be01f7abf0f909f29d812287fbbfe5e72f26e5f2e57b9`).

- Adds **Battle Menu UI** under UI, default OFF. OFF leaves Gen1Recomp's native battle command presentation untouched. ON uses the shared public `battle.bottom_ui_visible` + draw-only `battle.overlay` seams to replace only the ordinary four-command battle menu with a centered Nuzlocke-owned 2x2 panel: FIGHT / POKEMON / BAG / RUN.
- Battle Menu UI is presentation-only: native `menuIndex`, input, action dispatch, move selection, party/item screens, HP/status HUD, link/battle mechanics, and challenge-rule enforcement remain authoritative. Safari, Bug Contest, and tutorial/demo command menus deliberately stay native.
- Merges **Running Shoes** and **Fast Surf** into one QOL rule: **Run / Surf** with OFF / HOLD B / ALWAYS. One authoritative mode now controls both player-controlled walking and Surf speed assists.
- Existing saves and old Setup presets migrate conservatively: when old Running Shoes and Fast Surf values disagree, the new Run / Surf value takes the more restrictive mode. Legacy save keys remain synchronized as compatibility mirrors.
- Fixes the intended No Catching dependency metadata for **Allow Glitches** by correcting the stale `allow_glitches` key to the canonical `allow_glitch_pokemon`.
- Rule taxonomy remains 21 sections and 151 canonical unique rules: Battle Menu UI adds one row while the two movement rows become one.
- Preserves 2.7.92 Setup/Rules visual treatment and 2.7.91 Random Starter crash hardening.
- Crystal Mom DST remains deliberately deferred.
- Save Schema remains 5; Compatibility API 34; Diagnostics API 1.

# 2.7.92 — Setup/Rules palette + bold chrome polish

Strict child of exact 2.7.91 (`148dc68fb49e9aa17cc14f2efd792c4f5f72d2b092abdd16850d3749679cd27f`).

- Implements the approved Setup/Rules presentation across R/B/Y and Gold/Silver/Crystal.
- `NUZLOCKE / SETUP` and `NUZLOCKE / RULES` use the bold Nuzlocke-owned title treatment.
- Normal rule names, values, selection/navigation glyphs, the bottom-centered `▲ current/total ▼` pager, and help text use one consistent black/dark treatment. Selection remains communicated by the cursor rather than changing row text color.
- WIP/delegated rows may still dim so their special state remains visible.
- Preserves 2.7.91's raised rule rows and bottom-centered pager geometry.
- Preserves 2.7.91's Random Starter crash containment and empty-pool hardening unchanged.
- Crystal Mom DST remains deliberately deferred.
- No rule-default, Save Schema, Compatibility API, Diagnostics API, Randomizer algorithm version, or package-inventory change.

# 2.7.91 — Random Starter crash hardening + Setup/Rules pager layout

Strict child of exact 2.7.90 (`ea7e42c5a9249090934f6b53a999397b5cf618e385624dcaecfdc2886cdf091f`).

- Protects the newly runtime-PASS Silver vanilla Elm starter path from Random Starter failures: canonical starter-slate materialization is now wrapped at the optional randomizer boundary. If a seed/slate/materialization fault occurs, the mandatory native starter transaction fails open to the selected vanilla starter instead of crashing.
- Fixes an explicit empty without-replacement fallback edge in atomic starter slate generation: when distinct assignment is already proven impossible and the remaining duplicate-safe pool is empty, the code now uses the first hard-safe candidate instead of ever calling `random(1, 0)`.
- Preserves the 2.7.90 same-script Elm provenance and duplicate-gate receipt-window repair unchanged.
- Setup/Rules UI on R/B/Y and Gold/Silver/Crystal now moves the three visible rule rows upward into the reclaimed subtitle space.
- The pager cluster is now centered at the bottom of the list panel as `▲ current/total ▼`, rather than living near the top/right.
- Crystal Mom DST remains deliberately deferred.
- No rule-default, Save Schema, Compatibility API, Diagnostics API, Randomizer algorithm version, or package-inventory change.

# 2.7.90 — mandatory starter provenance / duplicate-gate repair

Strict child of exact 2.7.89 (`a1674ce6b30b2bcc214c1e3cda1313fa9f5184be013d74171308ae4a16b4f8a9`).

- Replaces the remaining Silver/Crystal Elm starter guesswork with a same-script mandatory-starter provenance marker. A starter POKEPIC arms the marker for that exact VM script run; the following GIVEPOKE consumes it. Map-label spelling and species-registry shape are no longer allowed to downgrade the mandatory Elm transaction into an ordinary gift.
- Opens a one-transaction mandatory-starter receipt window around native Gen-2 givePoke so the post-transaction pokemon.received gate cannot re-run generic gift/glitch legality on the same starter before Tracker finalization.
- A declined starter ball cannot leak provenance into a later script because the marker is keyed by scriptKey and consumed/cleared only by the matching GIVEPOKE.
- Random Starter setup intent is seeded into the fresh save-backed mod.save bucket at save.created while the immutable New Game Setup profile is still authoritative. This applies to R/B/Y and Gen 2 and prevents the Random Starter toggle/style/seed from disappearing when Gen1Recomp adopts the new save before the starter transaction.
- Preserves the 2.7.89 Setup/Rules subtitle cleanup.
- Crystal Mom DST remains deliberately deferred.
- No rule-default, Save Schema, Compatibility API, Diagnostics API, Randomizer algorithm, or package-inventory change.

# 2.7.89 — runtime-known-good starter transaction recovery

Strict child of exact 2.7.88 (`60246223e257c476231527339f99f1d16db0a198de66e318e2da856518b6dd68`).

- Restores the recent runtime-proven starter ownership contract instead of adding another species-legality heuristic.
- Gold/Silver/Crystal: any GIVEPOKE reached from Elm Lab's starter-ball story context is treated as the mandatory starter transaction before optional gift/glitch legality. Species identity refines the selected ball/Random Starter choice but no longer decides whether Elm's mandatory story grant is an ordinary gift.
- Gen-2 preview state now carries the last exact Elm original + randomized choice forward to GIVEPOKE, preserving preview -> confirmation -> grant identity when early-runtime species representation is incomplete.
- R/B/Y Random Starter: restores the first-party canonical opening-starter transaction as authority and removes the brittle map-label prerequisite that could prevent the actual `pokemon.before_give` mutation.
- Removes the redundant edition / NEW RUN / LIVE second title line from Nuzlocke-owned Setup and Rules headers on all supported editions.
- Crystal Mom DST suppression is deliberately deferred to a later child per owner instruction.
- No rule-default, Save Schema, Compatibility API, Diagnostics API, Randomizer algorithm, or package-inventory change.

# 2.7.88 — complete starter transaction / clock summary / DEV code repair

Strict child of exact 2.7.87 (`3ffe5a2bcdd1f0111acaaa9f3f0e8ccf169134902c4efa2308ca8b0e6bf5193b`).

- Fixes the remaining Silver/Crystal false-glitch starter veto at the actual shared legality boundary: numeric Gen-2 species identities now resolve against each live Pokemon registry row's public `index` field, not just physical table keys or optional aliases.
- Hardens Elm starter recognition around the exact canonical cartridge GIVEPOKE operands (Chikorita 152, Cyndaquil 155, Totodile 158) plus Elm Lab context. These numeric constants identify the mandatory story transaction; they are not a glitch-rule whitelist.
- Gen-2 canonical-name <-> native-index conversion now prefers the public Pokemon registry `index` field, falls back to generated species order when available, and retains exact Elm operand fallback if early-load registry metadata is temporarily unavailable.
- Gen-2 Random Starter preview/grant paths use the same shared native-index resolver.
- R/B/Y Random Starter's `pokemon.before_give` seam now mutates the gift only when Random Starter is actually enabled, validates the selected species, and commits the exact same identity.
- Manual Time's NUZ RULES row now displays the live `HH:MM` value rather than `HH:--`.
- DEV TOOLS -> VIEW REPORT now explicitly generates the live NZR6 shareable code with `Dev.reportCode(...)`; the restored CODE page no longer depends on a `report.report_code` field that `selfTestText()` intentionally stopped populating in 2.7.82.
- The Crystal System Date/Time / Mom DST transaction repair from 2.7.87 is retained unchanged pending runtime retest.
- Crystal loadout PASS evidence is protected. No rule default, save-schema, Compatibility API, Diagnostics API, or package-inventory change.

# 2.7.87 — Gen-2 Elm identity / clock / DEV report runtime repair

Strict child of exact 2.7.86 (`ca592afd62cc46cb90823278733f225c53da6e3cc4a898da36bac23cbcac0ee0`).

- Fixes the real Silver/Crystal Elm starter identity defect by resolving Gen-2 numeric script species through Gen1Recomp's canonical `gen2Constants.speciesOrder` before starter recognition or legality checks. Ordinary Chikorita/Cyndaquil/Totodile must no longer become numeric-string pseudo-species and trigger the glitch rule.
- Adds the reverse canonical-name -> native Gen-2 species-index resolver and uses it for Random Starter preview/grant transactions, addressing the separately observed 2.7.85 Gen-2 Random Starter failure without adding a starter whitelist.
- Manual Time now edits both hour and minute: Up/Down selects the field, Left/Right changes it, A applies it. Applying still disables System Clock Sync and clears DST ownership.
- Crystal's initial Mom DST ladder is skipped by exact Players House 1F script transaction identity when System Date/Time is active. The bypass does not match English display text and does not touch Mom's later phone/banking prompts.
- Restores the long NZR report-code page as the first page after DEV TOOLS -> VIEW REPORT. The human-readable SUMMARY/PROBLEMS/HOOKS/RULES/RANDOM pages remain behind it; the old noisy RAW dump/error-code pages remain retired.
- Crystal remains ALPHA. Save Schema 5, Compatibility API 34, Diagnostics API 1, rule defaults, and package inventory are unchanged.
- Runtime retest required on Silver and Crystal vanilla/randomized Elm starters, Crystal Mom DST skip, Manual Time minutes, and DEV REPORT code-first navigation.

# 2.7.86 — Gen-2 starter grant + setup applicability runtime repair

Strict child of exact 2.7.85 (`fb8eb72e1f9292a99e047b697170b2b17b99dd0f6a241773e999ad67e4271a72`).

- Fixes the shared Gold/Silver/Crystal species resolver so canonical string species such as CYNDAQUIL/TOTODILE/CHIKORITA can resolve against Gen-2 registries keyed by numeric id or row metadata before glitch legality is evaluated. This prevents ordinary Elm starters from being rejected as malformed/glitch acquisitions.
- Restores `System Date/Time` and `System Clock Sync` to the maintained shared Gen-2 applicability allowlist, so the setup-only System Date/Time control can actually appear on Gold/Silver/Crystal configuration surfaces.
- Crystal remains ALPHA and keeps the 2.7.85 native POKEPIC/cry fail-open boundary.
- No rule defaults, save schema, Compatibility API, Randomizer algorithm, or package inventory changes.
- Runtime retest required on Silver and Crystal starter grants, Crystal setup clock bypass, and Red field-poison install health.

# Nuzlocke 2.7.86 — Release Notes


## What changed in 2.7.86

- Keeps Crystal as intentional **ALPHA** support.
- Prevents the 2.7.84 Elm starter-ball crash by leaving Crystal's native animated POKEPIC/cry presentation untouched until exact runtime certification; the shared Gen-2 GIVEPOKE transaction remains in place.
- Repairs stale DEV REPORT stored-state checks for the expanded Randomizer stream/source-map/projection/compatibility registries.
- Includes Crystal in staged-profile and Randomizer runtime-matrix diagnostics.
- No rule defaults, save schema, Compatibility API, Randomizer algorithm, or package inventory changes.


## What changed in 2.7.84

This release intentionally enables **Pokémon Crystal — ALPHA support** after a fresh Gen1Recomp compatibility/documentation review through the 0.2.24-era source line. Crystal is an explicit manifest target rather than an accidental `gen2` inheritance. Existing shared Gen-2 rule, tracking, clock, starter, PC, randomizer, and utility-screen owners are reused where their public/native contracts are common; Crystal keeps exact-edition identity and does not inherit Gold or Silver runtime PASS evidence. Nuzlocke-owned Crystal utility/configuration screens identify the runtime as **CRYSTAL ALPHA**.

Compatibility hardening updates the source-audited marker to 0.2.24, recognizes six upstream editions, adds Crystal to shared native rule applicability and the three-choice Elm starter surface, gives Crystal its own Random Field Item source namespace, and extends starter fallback/default-name handling conservatively. Release Safety now protects the exact six-edition target set and both documented Gen-2 compatibility traps: `src.ui.OptionRows` must not be used, while `src.script.Commands` must remain behind an explicit non-Gen-2 guard. `battle.field_residual` remains intentionally unused because upstream still documents it as Gen-1-only. No save-schema or public Nuzlocke API bump is included. The minimum Gen1Recomp version is intentionally raised to **0.2.24** because older API-2 loaders do not know the explicit `crystal` manifest token.

**Crystal is Alpha:** expect incomplete or unverified Crystal-specific progression, script-special, Battle Tower, static/gift encounter, and UI edge cases until they receive independent runtime evidence.


## What changed in 2.7.83

This release completes the planned Rules/Setup UI batch recorded after 2.7.82. Loadouts and Game Difficulty are now chosen directly rather than discovered one step at a time. Loadout application still uses the existing staged diff and confirmation screen; Difficulty shows concrete trainer/boss effects and warns about external-provider stacking before commit. The compact Rules position counter is kept in the top-right. Gold/Silver gain an in-run Manual Time control; choosing an hour turns System Clock Sync OFF and writes through the native Gen-2 clock while preserving minute and weekday. Setup now labels Starting Poke Ball delivery as deferred until capture unlock.

No Crystal support, encounter-overlay restoration, rule-default changes, Randomizer roadmap work, or public API/schema changes are included. Runtime UI validation remains required on representative R/B/Y plus Gold and Silver.


## Previous 2.7.82 notes

This build focuses on the exact Silver failures observed in 2.7.81. With System Date/Time enabled, Mom's initial DST question/branch is now handled automatically through semantic Gen-2 VM special resolution. Elm's randomized starter confirmation has a final native raw-text fallback tied only to the actually rendered one-shot preview, and a committed native Elm starter story event can complete the missing New Bark Tracker identity under a deliberately narrow proof. Gen-2 NUZ INFO registration now uses the exact lifecycle Game and live PartyMenu context. DEV REPORT now reports runtime health only: package/document Release Safety remains build-time, generated report/error codes and raw machine dumps are not rendered.

Starting Poké Balls remain intentionally deferred until the normal capture unlock. Crystal remains outside the manifest. Runtime validation is still required, especially on Silver.


## What changed

- Source-audited Gen1Recomp 0.2.21 while retaining Mod API 2 and the current engine range.
- Kept Nuzlocke targeted to Red, Blue, Yellow, Gold, and Silver; Crystal remains unsupported.
- Completed Gold/Silver automatic clock setup across both initial DST branches and prevents double-DST adjustment.
- Exposed the engine `mod.developer` signal in diagnostics without changing player Dev Mode or challenge behavior.
- Marked only the three genuine Nuzlocke settings screens as `isModOptions`.
- Added Release Safety tripwires for the 0.2.21 compatibility contract.

Static/source validation does not constitute Runtime PASS.
## 2.7.80 — Starter completion, system clock QoL, and cancellable TO CAP

2.7.80 completes the reviewed 2.6.80 recovery batch on top of exact 2.7.79. Gold/Silver Elm starter transactions can remain pending across the native GIVEPOKE timing gap and finalize on the next safe world step, converging the granted Pokémon, Random Starter commit, player stat rules, New Bark Tracker provenance, and native Elm story state. The rendered starter preview also has a one-shot native-text fallback so confirmation follows the randomized species and primary type without editing shared ROM script rows.

Gold/Silver gain setup-only `System Date/Time` and in-run `System Clock Sync`, both using the engine's native Gen-2 clock setters. Rare Candy `TO CAP` batches in both generations can now be stopped with B at the next completed-candy boundary, preserving remaining inventory and allowing the current native level-up/move/evolution sequence to finish normally. Later 2.6.81+ recovery work is intentionally excluded. Runtime validation is required.

## 2.7.79 — Gen-2 Elm starter authority / utility titles

2.7.79 unifies the shared Gold/Silver Elm starter transaction around live script context instead of an empty-party heuristic. Proven New Bark starters can reconcile native Elm story state, and the randomized starter actually rendered in Elm's Lab becomes one-shot authority for the immediately following confirmation text when edition text identifiers differ. The narrowly proven identity-less LEGACY cleanup is retained as a repair-only exception and never becomes general species-based dedupe.

Nuzlocke-owned Gen-2 utility screens also share a centered, pseudo-bold primary-title hierarchy with centered normal subtitles where applicable. Native Gold/Silver UI and the native Mod Manager are unchanged. This strict child of exact 2.7.78 deliberately excludes the later 2.6.80 pending-GIVEPOKE/runtime-finalizer and system-clock work. Runtime validation is required.

## 2.7.78 — Starter identity / recovery parity

2.7.78 repairs duplicate starter bookkeeping by treating one persistent Pokemon identity as one active encounter record. Existing starter rows are moved/normalized instead of copied, history is deduplicated by exact Pokemon ID, and the Gen-2 hometown migration no longer guesses by species. Gold and Silver now expose the same Recover Catches maintenance surface as R/B/Y, and manual recovery keeps a saved Pokemon identity even if the live mon cannot be attached.

This is a strict child of exact 2.7.77. Later 2.6.79+ recovery changes remain intentionally excluded. Runtime validation is required.

## 2.7.77 — Silver starter/randomizer usability recovery

Silver receives the reviewed follow-up fixes documented after 2.6.76 runtime testing: NUZ INFO targets the live Gen-2 PartyMenu class more directly, Elm confirmation text follows randomized starters, starter registration survives nil-returning native GIVEPOKE callbacks, ordinary interiors stay out of the Tracker MAP without encounter evidence, and seed recovery controls work both in Setup and in-run.

This is a strict child of exact 2.7.76. Later 2.6.78+ recovery changes remain intentionally excluded. Runtime validation is required.

## 2.7.76 — Gen-2 authority / Silver parity recovery

- Strict child of exact packaged 2.7.75.
- R/B/Y starter provenance remains Pallet Town; Gold/Silver starter provenance resolves to New Bark Town.
- A conservative migration repairs only provable early Gen-2 starters incorrectly recorded in Pallet Town.
- Gen-2 Tracker presentation treats the historical static Kanto route catalog as Gen-1 seed data and requires runtime evidence before showing those rows.
- Gift/starter, static, and Game Corner script adapters now trust the canonical live Gen-2 predicate instead of an additional legacy context generation field.
- Adds the reviewed class-level PartyMenu NUZ INFO fallback and Gen-2 adapter reachability diagnostics.
- Static/parse/integrity validation is required; Silver, Gold, and R/B/Y runtime acceptance remains edition-specific.

## 2.7.75 — Silver shared Gen-2 parity recovery

- Strict child of exact packaged 2.7.74.
- Recovers only the reviewed semantic delta from mistaken 2.6.74 -> 2.6.75.
- Exact GOLD/SILVER/CRYSTAL identities now force the shared Gen-2 runtime predicate when engine generation helpers fail to identify the title.
- This reconnects Silver to the existing shared Gen-2 adapter path instead of allowing accidental Gen-1 fallthrough.
- Gen-2 parity diagnostics now also verify the shared predicate plus gift-tracking and capture-gate installer success.
- No separate Silver clone was introduced.
- No Randomizer mapping, rule default, save schema, Compatibility API, native host UI, or package inventory change.

## 2.7.74 — Gold utility-screen visual normalization

- Strict child of exact runtime-observed 2.7.73.
- Recovers only the post-2.7.72 presentation delta from the mistaken 2.6.74 child.
- Gold Nuzlocke-owned DEV REPORT, CATCH INFO, STAT INFO, and MOVE INFO use centered emphasized primary titles.
- NUZ INFO Pokémon/subject subtitles are centered at normal weight.
- Gold STAT INFO uses compact fixed `STAT / VAL / DV / EXP` columns.
- Gold CATCH INFO uses denser label/value rows and the utility footer/body spacing is normalized.
- No gameplay rules, Randomizer mappings, Save Schema, Compatibility API, supported editions, or native Gen1Recomp UI are changed.

## 2.7.73 — Late Runtime dependency-order recovery

- Reconstructed strictly from exact packaged 2.7.72.
- Recovered the first post-2.7.72 fix only: Late Runtime rule-message dependencies use live resolver thunks rather than registration-time snapshots.
- This specifically prevents frozen-nil dependency failures on Gold/Silver while preserving R/B/Y behavior.
- No rule semantics/defaults, Randomizer mappings, Save Schema, or Compatibility API changed.
- Runtime smoke remains required before 2.7.74.

## 2.7.72 — Shared UI ownership hardening

- Explicit `wide` layout requests now fall back to the classic surface unless a usable wide-layout provider reports a real wider size; `applyLayout()` claims the resolved layout instead of the raw request.
- Shared Gen 1/Gen 2 row primitives now support caller-owned `preFitted` text.
- Both live R/B/Y Tracker tabs mark only their selected marquee row as pre-fitted, preventing the shared pixel fitter from adding a second ellipsis to an already-finalized scrolling slice.
- Non-selected Tracker rows retain the shared defensive pixel fit.
- Release Safety protects both contracts.

## 2.7.71 — T3 World Building dialogue cleanup

- Removes the generic T3 run-summary page that was appended after unrelated World Building/rule dialogue.
- Messages such as `1 teammate lost in this run.`, badge totals, catch totals, and the opening-chapter line are no longer injected globally by `worldFlavorText()`.
- T3 keeps its richer regional/flavor wording; only the unrelated recap page is removed.
- Consequential post-encounter failure feedback from 2.7.70 remains unchanged and still fires at every World Building tier.
- Release Safety now checks that generic T3 dialogue cannot regain the global run-context append.

## 2.7.70 — Encounter feedback contract cleanup

- Retires the obsolete player-facing `Encounter Indicator` rule and the dead built-in battle HUD installation path. The old always-on AREA:COUNT / AREA:SPENT overlay remains intentionally removed.
- Preserves the read-only `encounterSpendIndicator()` semantic projection for compatibility/information consumers; it no longer depends on a player toggle.
- Post-battle failed-encounter feedback is now routed through one dedicated helper and remains consequential feedback at every World Building tier.
- World Building OFF/T0 and T1 use the plain failed-encounter explanation; T2 adds challenge flavor; T3 uses the richer regional wording.
- Release Safety now verifies that the retired battle HUD cannot silently return and that failed-encounter feedback keeps its all-tier critical-feedback contract.

## 2.7.69 — Combined Shop Restrictions

- Replaces the two public `No Buying` / `No Selling` rows with one `Shop Restrictions` selector.
- Modes are `OFF`, `NO BUY`, `NO SELL`, and `NEITHER`.
- Existing saves migrate losslessly: the previous two booleans are converted into the matching four-state mode.
- Legacy `no_buying` / `no_selling` state remains synchronized internally so existing R/B/Y, Gold/Silver, Randomizer, world-building, compatibility-provider, and transaction-gate code keeps the same behavior.
- Presets, Difficulty profiles, and compatibility paths that still write the legacy booleans reverse-sync the combined selector, preventing UI/state disagreement.
- Game Corner restrictions remain a separate `No Gambling` rule.

## 2.7.68 — Rule applicability & dominance audit completion

- Completes the planned Battle Mechanics, Battle Clauses, Battle/Field Items, Services & Economy, World, and QoL applicability pass.
- The reviewed shared mechanics now carry an explicit Red/Blue/Yellow/Gold/Silver native-edition matrix instead of relying only on generation-wide assumptions.
- Gen-II content-specific `Radio Nuzlocke` and `Skip Cherrygrove Tour` remain native only where their content exists, but can become available elsewhere only through explicit `pokegear_radio` / `cherrygrove_tour` provider capabilities.
- `Evasion Clause` is now hidden and behaviorally dormant when `No Setup Moves = ALL`, because that stronger clause already blocks every positive evasion-stage boost on both sides. SELF/ENEMY setup scopes remain distinct, so Evasion Clause stays available there.
- No false dominance was added between healing-item, field-heal, PP-item, Center, Mom, buying/selling, gambling, or stat-drop rules because those retain independent legal effects.
- Release Safety now trips if this reviewed exact-edition matrix, provider gating, or battle-clause dominance wiring disappears.

## 2.7.67 — Difficulty profile review

- Changing Difficulty now opens a dedicated full-screen profile browser before anything is committed.
- Left/Right cycles every available Difficulty mode; each mode gets its own page showing its trainer changes versus VANILLA.
- Up/Down scrolls longer change lists. A confirms the displayed profile; B returns with no mutation.
- After A, the existing Difficulty interaction warning still appears when the transition affects other rule semantics; only confirming that warning applies the change.
- External Difficulty providers receive their own page and are identified as provider-owned rather than inventing unsupported internal details.

## 2.7.66 — Exact-game audit, pass 2

- Continues the rule-availability audit in a deliberately small pass.
- Yellow no longer exposes Random Starter `Trio Typing` as a native rule because Yellow does not natively use the three-choice starter slate; an explicit compatible `starter_trio` provider can make it available.
- Encounter-slot modifiers now depend on `One Per Area`: Failed Encounters, Dupes, Gen II roamer/egg/contest policies, Town Catches, and area/time/headbutt split controls become dormant while area encounter limits are OFF.
- Type Locke now exposes/effects only the lanes selected by its mode. Catch Draft is hidden while Type Locke is OFF; manual type lanes are hidden/inert during Catch Draft; DUO through HEXA progressively reveal only the required lanes.
- Stored values are preserved while dormant and return when their prerequisite becomes applicable again.
- Release Safety extends the exact-edition/dependency source tripwire for these relationships.

## 2.7.65 — Rule availability / suppression architecture

- Rules now have a shared exact-edition availability contract for Red, Blue, Yellow, Gold, and Silver.
- Mechanics that are not native to the running edition are hidden and behaviorally inert; compatible providers may expose explicitly capability-gated mechanics.
- Dependency and dominance suppression preserve stored choices while preventing hidden child rules from affecting gameplay.
- Randomizer subordinate rows collapse when their owning randomizer feature is OFF; No Catching and No Status Moves suppress redundant subordinate restrictions.
- Kanto-only route/Mt. Moon/Safari and R/B/Y Gym Guide controls no longer appear as native Gen II rules.
- Release Safety audits the availability graph, exact-edition metadata, dependency cycles, and UI/effective-state wiring.

# Nuzlocke 2.7.65 — Release Notes

2.7.65 makes the rule list context-aware. Settings that have no mechanic in the active edition are hidden and behaviorally inert; compatible providers may expose explicitly capability-gated mechanics. Dependent and superseded child settings keep their saved choice but become inactive until their prerequisite is meaningful again.

This pass also corrects native applicability for R/B/Y Gym Guide Rare Candy and Safari Clause, treats Overworld encounter policy as provider-enabled, and adds static dependency/edition validation. Randomizer Shops and TMs now consume the same effective-state contract when a stronger No Buying / No TMs rule suppresses them.

> **Lineage:** **2.7.65** is a strict child of exact **2.7.64** (`08502eca2f12802b816d8cd4b4e9358ba08ea25f5411200534f4da42bf7dda40`).

---

## 2.7.65 — exact-edition rule availability and rule suppression

- Audits rule applicability separately for Red, Blue, Yellow, Gold, and Silver instead of assuming every shared catalog row is meaningful everywhere.
- Rules for mechanics absent from the active game are hidden and behaviorally inert. A compatible provider may make an explicitly capability-gated mechanic available without changing Nuzlocke challenge-policy ownership.
- Centralizes parent/dependency and dominance suppression so subordinate settings keep their stored preference but disappear and have no effect while their parent is OFF or a stronger rule supersedes them.
- Randomizer subordinate controls now follow the same shared dependency contract, reducing inactive Randomizer clutter without deleting saved configuration.
- Corrects native applicability for R/B/Y Gym Guide Rare Candy and Safari Zone policy, and treats overworld-spawn encounter policy as provider-enabled rather than a native mechanic.
- Adds Release Safety validation for unknown dependencies, contradictory edition flags, and dependency cycles.

# Nuzlocke 2.7.64 — Release Notes

MOD COMPAT is now an interactive compatibility-ownership control for the rows that have a real provider contract. Left/Right cycles `AUTO`, the native Nuzlocke/Engine owner, and installed providers that actually advertise that capability. The screen never invents an owner for fixed-policy or presentation-only rows.

Gameplay-impacting ownership changes use the existing confirmation modal before the preference is committed. Cancel leaves ownership unchanged. If a pinned provider later disappears or stops advertising the capability, Nuzlocke fails open to `AUTO` rather than retaining a stale owner. Preferences are save-local.

Initial controllable capability rows are Species Data, Pokemon Identity, Encounters, Escape/Warps, and Movement when no dedicated composed QoL owner already owns the overlap. More rows can be made selectable later only after their actual enforcement/provider contract supports safe substitution.

> **Lineage:** **2.7.64** is a strict child of exact **2.7.63** (`807ee2f1e45fda6e0f472a86af6e49d7f0ce34c2e879c15b277f4511b18df7a1`).

---

# Nuzlocke 2.7.63 — Release Notes

Gold runtime testing confirmed the Encounter Tracker LOG correctly recorded Chikorita in New Bark Town, while the MAP page still showed Gen I seed areas such as Pallet Town / Route 2. 2.7.63 separates Gen II map presentation from the Gen I seed catalog: Gold/Silver discover the host Gen II map tables, order MAP rows by `gen2Constants.mapOrder`, keep New Bark as the starter hometown, and preserve towns that already contain encounter evidence even when Town Catches is later disabled.

Difficulty changes now use a pre-commit impact warning when the proposed profile changes trainer semantics. The warning lists affected trainer level, team expansion, species/BST pressure, move quality, AI, Stat EXP, DV floor, Gold held-item tier, and badge-boost behavior. Cancel leaves the current Difficulty unchanged.

> **Lineage:** **2.7.63** is a strict child of exact **2.7.62** (`f0dcd4550671d7adb67886b54a6fd801b19fbf510efba2781b1e3d75b68b27bd`).

Runtime retest is required for Gold/Silver Tracker MAP ordering and Difficulty confirmation. Gold No Buying / No Selling runtime PASS evidence from 2.7.61 remains protected; the 2.7.62 Gen II healing repair still requires retest.
