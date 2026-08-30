<!-- Current build: 2.9.72 -->
<!-- 2.9.7: DEV/diagnostics completeness + lifecycle-contract audit complete. -->

**2.9.59:** Shiny Pokemon 1.2.41 compatibility/lifecycle/voxel ownership hardening with cross-project audit freshness; no new runtime certification.
**2.9.58:** Focused Random Trainers, compatibility AUTO-provider, and Gen-II NUZ STATUS integrity fixes; Random Field Items remain unchanged pending runtime evidence.
**2.9.57:** Post-modularization integrity hotfix for future-schema Pokemon identity safety and owner-aware Release Safety source checks.
<!-- 2.9.7: final static Randomizer audit complete; Gen-II trainer/field-item runtime certification remains pending. -->
# Nuzlocke 2.9.72

**2.9.71:** Focused Random Field Items repair for R/B/Y. Visible item balls now compose through Gen1Recomp's public `world.talk` hook immediately before native pickup handling consumes the item payload. Yellow 2.9.70 supplied the Runtime FAIL that motivated this repair; 2.9.71 requires retest before Runtime PASS.

**2.9.56 adds `evolution_policy.lua` as the dedicated owner for Evolution Limits and Trade Evolution QoL over the shared `evolution.check` seam.** Randomizer evolution mappings, UI/config, Pokemon identity/provenance, and acquisition policy remain with their existing owners. The protected package inventory intentionally advances to **37 files / 27 Lua modules plus `mod.card`**. Further consolidation/relocation is paused after this build by user direction.

**2.9.54 adds `species_policy.lua` as the dedicated owner for configurable species-restriction policy.** Type/Color/Alphabet Locke selection and legality, glitch classification, Maximum BST/species-fact helpers, and legendary/mythical/pseudo challenge classification now consume the stable `pokemon_identity.lua` service through explicit dependencies. Pokémon instance identity/provenance, tracker state, shiny generation/presentation, Randomizer mappings, and acquisition enforcement remain outside this module. The protected package inventory intentionally advances to **35 files / 25 Lua modules plus `mod.card`**.

**2.9.53 adds `encounter_tracker.lua` as the dedicated owner for area catalogs, encounter-area projection, tracker persistence, legacy catch recovery, and save reconstruction.** It consumes the stable `pokemon_identity.lua` service established in 2.9.52 instead of duplicating identity/provenance logic. Challenge legality, shiny generation/presentation, and unrelated runtime enforcement remain outside the module. The protected package inventory intentionally advances to **34 files / 24 Lua modules plus `mod.card`**.

**2.9.52 adds `pokemon_identity.lua` as the dedicated owner for stable Pokemon instance identity, canonical species-definition/provider metadata lookup, current-mon enumeration, persistent ID allocation/repair, origin assignment, baseline migration, and Pokemon provenance initialization.** Locke selection/policy, shiny generation/presentation, tracker reconstruction, and challenge legality remain outside the module. Mutable game/save state is getter-backed. The protected package inventory intentionally advances to **33 files / 23 Lua modules plus `mod.card`**.

**2.9.51 begins the intentionally approved new-module phase with `compatibility_runtime.lua`.** Internal provider discovery, owner preference/resolution, compatibility evidence, engine/mod relationship projections, and the public Compatibility API construction now live behind this dedicated owner. Mutable/late-bound runtime dependencies (`currentGame`, rule activity/defaults, catch policy) are getter-backed rather than captured at module initialization. Public Compatibility API remains **37**; this is an ownership split, not a contract bump. The protected package inventory intentionally advances to **32 files / 22 Lua modules plus `mod.card`**.

**2.9.50 closes the currently reviewed existing-owner modularization phase.** The remaining R/B/Y Forgiveness Token shop filter now lives in `forgiveness.lua` verbatim, preserving semantic BUY/SELL detection, SELL-list rebuild filtering, wrapper-session ownership, and reinstall hooks. With the Dev diagnostics and Gen-II title SETUP moves completed in 2.9.48–2.9.49, further large reductions should use deliberately approved new first-class Lua owners rather than overloading existing modules. No gameplay, save schema, API, Randomizer, or Runtime PASS changes are intended.

**2.9.49 activates the existing `title_setup_compat.lua` as the semantic owner of the live Gen-II title SETUP adapter.** Gen-II `MainMenu:choose()` and final-list SETUP insertion/removal now live in that module, while setup-profile persistence/staging remains in `main.lua` behind explicit callbacks. The historical R/B/Y fallback inside the module remains dormant, preserving the protected public title-menu path. No gameplay, save schema, API, Randomizer, or Runtime PASS changes are intended.

**2.9.48 closes the remaining reviewed Dev-diagnostics ownership batch.** `Dev.hookHealth`, diagnostic snapshot/error/logging helpers, and self-test orchestration now live in `dev_diagnostics.lua`. Mutable game selection is resolved through the existing live getter on every call; rule/default/config helpers are injected explicitly. The small core instrumentation primitives used by runtime code remain in `main.lua`. No gameplay, save, Randomizer, compatibility ownership, public API version, or Runtime PASS changes are intended.

**2.9.47 completes the currently reviewed World Building ownership move.** Shared World Building text cleanup/wrapping, presentation transactions, tier selection, once-per-save flavor flags, `worldMessage`, `worldMechanic`, failed-encounter feedback, and their pure tier audits now live in `world_building.lua`. Challenge legality remains outside this presentation module.

**2.9.46 continues modularization by moving four dependency-clean read-only diagnostic surfaces into `dev_diagnostics.lua`: Rule Effectiveness, Randomizer Integrity, Gen-II Edition Parity, and Storage Context. `Dev.hookHealth`, snapshot/error capture, and self-test orchestration remain in `main.lua` pending a broader live-hook dependency review. No gameplay or runtime-certification behavior changes are intended.**

**2.9.45 consolidates the remaining low-risk static rule/configuration data into `rule_catalog.lua`.** Locke loadout definitions, the shared Gen-II beta rule/description surface, selective species-ban set normalization, and pure NEW GAME starting-resource resolution/audits now live with the authoritative catalog owner. Live save state, runtime application/classification, game-data species lookup, and all enforcement remain in `main.lua`. No gameplay behavior or public API version changes are intended.


**2.9.44 continues conservative modularization by moving the pure read-only save-schema descriptor presentation/structural-audit layer into `rule_catalog.lua`.** `SaveSchemaDescriptor.describe()` and structural/default-type `audit()` now live beside the already-built save-field snapshot they inspect, while live schema versioning, migrations, transactions, persistence, and save lifecycle remain in `main.lua`. Parity passes across 166 authoritative descriptor rows / 185 generated save fields, including role counts, fault detection, and deep-copy isolation. `main.lua` is now 31,462 lines / 1,568,827 bytes, down 60 lines / 3,118 bytes from 2.9.43. No gameplay, persistence semantics, Randomizer, compatibility ownership, or public API version changes are intended.

**2.9.43 continues conservative modularization by moving the pure read-only rule registry presentation/structural-audit layer into `rule_catalog.lua`.** `describe()`, `get()`, and structural/default-type `audit()` now live beside the descriptor snapshot they inspect, while live stored-save validation and enum/coercion certification remain in `main.lua`. Registry parity passes across all 166 authoritative descriptor rows with deep-copy isolation preserved. `main.lua` is now 31,522 lines / 1,571,945 bytes, down 39 lines / 1,282 bytes from 2.9.42. No gameplay, persistence, Randomizer, compatibility-ownership, or public API version changes are intended.

**2.9.42 continues conservative modularization after a split-safety review of the machine-readable rule/save descriptor subsystem.** Only deterministic descriptor construction moved into `rule_catalog.lua`; live save validation, schema/transaction ownership, enum/coercion auditing, and runtime descriptor exports remain in `main.lua`. A parity harness matched all 166 authoritative descriptor rows and the complete generated save-field map. No gameplay, persistence, Randomizer, compatibility-ownership, or public API version changes are intended.

**2.9.41 resumes the conservative modularization program.** The pure ordinary rule-value coercion implementation now lives in `rule_catalog.lua` beside the authoritative rule definitions, while the established `__beta26.coerceRuleValue` surface remains unchanged and passes a full catalog parity matrix. The live rule-definition index is supplied on every call so the split cannot freeze a stale registration-time snapshot. No gameplay, save, Randomizer, compatibility-ownership, or public API version changes are intended.

**2.9.40 completes the current Release Safety hardening sequence.** Compatibility metadata is now audited semantically where structured owners exist, compatibility confidence is reported as separate live-contract/source-reviewed/combined-runtime-required evidence, and document-role checks validate the first real heading instead of brittle line position. No gameplay, save, Randomizer, compatibility-ownership, or public API version changes are intended.

**2.9.38 continues the safety/reconciliation sequence with a generated, read-only save-key/reference consumer index.** It derives canonical described keys from the existing save-schema descriptor, maps bounded source consumers across shipped Lua modules, reports dynamic and undescribed literal references, and fails open when package source cannot be read. It does not read or write live save values, migrate state, alter enforcement, or promote Runtime PASS.

**2.9.37 continued the small certification/reconciliation hardening sequence.** Catch-denial reasons now have one read-only disposition catalog that explicitly records progression-PC override eligibility, and Release Safety verifies that catalog against the existing executable eligible set. Numeric rule descriptors also receive semantic enum/range completeness checks for valid bounds, in-range defaults, and canonical clamping. These are certification improvements only: catch legality, progression exceptions, rule defaults, saves, APIs, Randomizer behavior, and runtime evidence are unchanged.

**2.9.36 repaired Gen-II Colorlocke/Alphabetlocke configuration reachability** and added table-driven reachability certification for both mode and child-selector rows.


Nuzlocke is a configurable challenge-rules mod for Gen1Recomp. It supports **Red, Blue, and Yellow** as the mature baseline, **Gold and Silver** as beta targets, and **Crystal** as an explicit alpha target. Runtime evidence is edition-specific: support in one game is never treated as proof for another.

## Current release contract

- **Gen1Recomp:** `>=0.2.24 <2.0.0`; source/documentation compatibility audited through **0.2.40** (release commit `0cf543d597ce84e4d847b2aba782f1bf2799fde0`). Exact-edition 0.2.40 runtime smoke remains pending.
- **Mod API:** 2.
- **Nuzlocke Save Schema:** 5.
- **Compatibility API:** 37.
- **Diagnostics API:** 1.
- **Translation API:** 2.
- **Run History:** v2.
- **Randomizer algorithm:** v1.
- **Package:** 36 files / 26 Lua modules plus `mod.card`.
- **World Building default:** T3.
- **Battle Menu UI:** Gen I only; Gold/Silver/Crystal retain the native Gen-II battle command presentation.
- **Dev Mode:** observational/diagnostic unless a tool is explicitly described as mutating state.

2.9.18 adds an explicit END RUN / ABANDON RUN lifecycle surface under the NUZ MENU. Abandonment uses the existing durable Run History v2 event, defaults destructive confirmation to NO, commits history before disabling challenge enforcement, and opens the Almanac final recap. Natural completion remains progression-owned and cannot be manufactured by the lifecycle UI. No Save Schema or public API bump is required.

2.9.17 adds a translated, read-only Almanac / Run Recap under the NUZ MENU. It summarizes durable Run History v2 totals for catches, deaths, progression, failures, blackouts, forgiveness, completion state, rule-integrity evidence, and recorded Randomizer run metadata. Incomplete legacy or pruned detail is explicitly labeled PARTIAL rather than reconstructed. The 2.9.16 Graveyard Viewer remains unchanged. No Save Schema, Compatibility API, Randomizer algorithm, defaults, support-level, or Runtime PASS changes are claimed.

## Core challenge features

**2.9.25 adds Colorlocke and Alphabetlocke.** Each can be OFF, deterministically RANDOM for the run, or CHOOSE. Colorlocke uses canonical species-color metadata; Alphabetlocke uses the canonical species identity's first A-Z letter, never localized display text. Both apply prospectively to new acquisitions, compose with Type Locke/PKMN BAN/BST and other species rules, leave existing Pokemon and later evolutions untouched, and fail open when a custom species lacks the metadata needed for a safe classification.

The mod includes permanent death, One Per Area encounter enforcement, Failed Encounters, Dupes modes, Nickname Rule, Shiny Clause, level caps, species restrictions, battle/field item restrictions, escape restrictions, healing/service restrictions, economy restrictions, party/team limits, difficulty profiles, World Building, encounter tracking, Run History, translated Graveyard and Almanac viewers, Forgiveness/F. TOKEN support, and edition-specific setup/QoL controls. Availability is edition- and context-sensitive; unsupported or delegated rules are hidden, dimmed, or reported through the compatibility/diagnostic surfaces rather than silently assumed to work.

## Randomizer

The current ownership registry has **ten independently resolved subsystems**: **Starter, Encounters, Field Items, Learnsets, Trainers, Evolutions, Shops, TM Contents, TM Locations, and Gift Items**. Random TM contents and physical TM pickup locations are separate methods. Deterministic mappings use algorithm v1 and persisted source identities; diagnostics must not consume RNG or materialize unseen mappings.

Known runtime debt remains important: **Gen-II Random Trainers** and **Gen-II Random Field Items** have tester-reported Runtime FAIL evidence and remain unresolved. Source audits found the expected engine seams, so they are not represented as fixed until exact runtime testing proves the pipeline.

## Compatibility and ownership

Compatibility is based on the narrow mechanic being owned, not merely on whether another mod is installed or happened to load first. Presentation ownership does not grant gameplay ownership. Nuzlocke prefers public hooks/provider contracts, uses source-confirmed named adapters when needed, and treats private interposition as exceptional.

Current reviewed targets include the maintained Shiny Pokémon fork 1.2.20, Wilds of Kanto 2.2.0, PokéPC Followers 0.5.1, Followers EX 1.0.19, PotatoVoxel 1.9.6, Dramatic Shape 1.9.0, Battle Art Voxel Fork 1.10.0, Battle Cinematics 1.2.4, Pokémon Gen1 Randomizer 0.46.4, Gen2 Randomizer+ 2.9.0, Item Randomizer 1.1.1, Kanto Reforged 1.5.3, QoL Toggles 1.30.8, Delta Type 1.2.0, Wonder Trade 1.2.1, The World 6.54.15, VanillaPlus 0.3.0, G9 Battle Engine 1.2.3 / beta 2.0.2, Useful Bag 2.6.3, Modern Bag UI 0.4.5, Bag Sort 0.1.0, and the translation companions documented in `docs/COMPATIBILITY.md`.

Important boundaries:
- **Kanto Ascendant 6.5.17:** explicit upstream conflict; do not combine with standalone Nuzlocke.
- **Dex Overflow 0.1.1** and **Safari All 1.1.0:** legacy reviewed targets; no newer/current package is claimed without evidence.
- **Wonder Trade:** post-mutation observe/reconcile only; Wonderlocke remains disabled until a safe pre-transaction cooperation seam exists.
- **SHINY_POKEMON:** explicit provider target but intentionally not a reciprocal optional dependency, avoiding a loader dependency cycle.
- Replacement Bag/Party/UI mods keep their presentation/controller ownership; Nuzlocke rules operate on semantic actions/items rather than list positions or pocket indices.

See `docs/COMPATIBILITY.md` for the detailed target matrix and `docs/FEATURE_CONFIDENCE.md` for evidence labels.

## Credits and project lineage

- **bryanthaboi** — creator of the original Nuzlocke mod and project baseline.
- **masterwebx** — creator of the original Shiny Pokémon mod. That original project is part of the code/design lineage and technical foundation of this project’s shiny support and the maintained Shiny Pokémon compatibility work.
- **Stone696** — current Nuzlocke maintainer/developer and maintainer of the Shiny Pokémon fork, responsible for continued development, expansion, compatibility work, and current releases.

The current built-in Nuzlocke shiny subsystem has been substantially reworked around current Gen1Recomp APIs and single-owner compatibility architecture. This later divergence does not erase the attribution owed to the original Shiny Pokémon project.

## Shiny ownership

When no compatible external shiny provider owns the active edition, Nuzlocke may provide its built-in shiny rate/colors/intro behavior. When a healthy external provider owns shiny generation/presentation, Nuzlocke stands down those presentation/generation controls and consumes the resulting shiny identity. **Shiny Clause remains Nuzlocke challenge policy either way.** The protected standalone runtime evidence remains the Red test from 2.8.37; it is not generalized to other editions or combined-mod stacks.

## Localization

Nuzlocke exposes Translation API 2 and routes its authored text through the engine localization surface where migrated. Current companion targets and certification state are listed in the compatibility and confidence documents. Missing translations fall back safely; a companion being installed is not the same as its language being active or certified.

## Documentation

- `docs/USER_GUIDE.md` — current player-facing behavior and controls.
- `docs/COMPATIBILITY.md` — engine/mod ownership boundaries and reviewed targets.
- `docs/API.md` — public compatibility, translation, diagnostics, and provider contracts.
- `docs/FEATURE_CONFIDENCE.md` — Runtime/Static/Source evidence and known testing debt.
- `CHANGELOG.md` — chronological historical changes.
- `RELEASE_NOTES.md` — concise notes for the current release.

Historical release detail belongs in the changelog rather than being presented as current behavior in this README.


### Special Acquisition slot policy
Allowed gifts/fossils/prize Pokemon and NPC trades can independently use **AREA** (consume the ordinary One Per Area slot) or **BONUS** (retain provenance/history without consuming that slot). Allow/deny and species-legality rules remain independent. Gen-II Egg encounter policy remains separate.
