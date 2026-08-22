# Nuzlocke Compatibility — 2.7.0
2.7.0 changes no compatibility ownership/provider semantics from 2.6.98; it promotes the runtime-confirmed head to release.
2.6.96 changes no compatibility ownership/provider semantics; it repairs current-build documentation header packaging only.
2.6.95 changes no compatibility ownership/provider semantics; it repairs the NUZ RULES Randomizer rival-sync diagnostic path.
2.6.94 changes no compatibility ownership/provider semantics; it expands the Lua unpack compatibility audit to the full shipped Lua inventory.

This file describes **current compatibility ownership and composition rules**. Historical compatibility work belongs in `CHANGELOG.md`.

2.6.93 changes no compatibility ownership or provider semantics; it repairs the World Building catalog startup golden only.

## Correctness hardening — 2.6.91

Learnset coexistence now compares only Nuzlocke-owned move-list fields (`level1Moves`, `learnset`, `levelMoves`). External providers may change unrelated Pokémon stats/types/metadata without accidentally transferring learnset ownership. No provider capability or Compatibility API version changes.

Rare Candy to Cap now uses transaction-specific durable recovery checkpoints and versioned monotonic attempt IDs. These are internal save-safety mechanisms and do not change public compatibility ownership.

## Stadium / Crystal 251 presentation and import compatibility — 2.6.91

The Stadium provenance surface is now version 2 and explicitly distinguishes **model/ROM import** from **Pokémon acquisition**. Nuzlocke recognizes loaded `STADIUM_OVERWORLD_MODELS`, `STADIUM_UI_MODEL_VIEWER`, `STADIUM2_OVERWORLD_MODELS`, and `CRYSTAL_251` presentation/importer surfaces for diagnostics while preserving the engine's exact running Red/Blue/Yellow/Gold/Silver edition identity. Crystal 251 is therefore treated as an overlay/content provider, not as permission to rewrite the underlying edition to "Crystal".

Importing Stadium model assets never relabels ordinary party Pokémon. A real Stadium transfer/prize/import path must explicitly call `nuzlocke_acquisition_provenance.mark()` / `markImported()` (or preserve equivalent provenance fields) for the Pokémon it actually creates. `markImported()` requires Stadium 1/2 origin unless the caller deliberately opts into the detected active Stadium origin. Optional provider/mod id and exact-edition metadata are preserved with that acquisition record.

`compatibilitySnapshot(game)` reports the exact edition plus detected Stadium/Crystal-251 presentation/importer rows. DEV REPORT exposes this as `stadium_compat=...`, making the Aghanim-3C Crystal-251-compatible Stadium fork and compatible upstream variants diagnosable without hard-coding gameplay ownership to one fork. The Aghanim-3C repository ships forked Stadium Overworld Models and Stadium UI Model Viewer packages and describes them as Crystal 251 compatible; combination runtime testing remains required.

## Randomizer coexistence hardening — 2.6.90

Nuzlocke yields duplicate randomizer controls only when an external mechanic is positively active, never merely because a mod is installed.

Source-confirmed named adapters currently include:

- `pokemon_randomizer` — active-run starter, wild encounter, and learnset ownership from its exported run contract.
- `gen_2_randomizer_plus` — starter, wild encounter, and learnset ownership from its live source-confirmed option bucket.
- `Kanto-Reforged` — encounter ownership only while its supported spawn-randomization modes are active.
- `item_randomizer` — visible Field Item ownership only while `overworld_items` is true in R/B/Y or `gold_ball_items` is true in Gold/Silver.

For `item_randomizer`, hidden finds, shops, gifts, berries, held-item, PC-item, and other non-visible-pickup features do not claim Nuzlocke's `Random Field Items` control.

Generic provider ownership is also supported through `starter_randomizer_provider`, `encounter_randomizer_provider`, `field_item_randomizer_provider`, and `learnset_randomizer_provider`. External mods without a stable active-run signal or provider capability are not guessed as owners.

The read-only randomizer compatibility snapshot reports current owner state for starters, encounters, visible field items, and learnsets. DEV REPORT includes this as a compact ownership line. Missing or inactive external mods are normal/N/A, not compatibility failures.


## Engine baseline

- Gen1Recomp Mod API: **2**
- Supported engine range: **`>=0.1.86 <2.0.0`**
- Latest source-audited release: **0.2.19**
- Declared exact editions: Red, Blue, Yellow, Gold, Silver

The complete 17-commit 0.2.18 → 0.2.19 upstream delta was reviewed. Material changes include Gen 2 battle/EXP, Bill's PC BoxMenu, Pack/Item-PC UI, SaveData resilience, Gen2Compat/Loader facades, overworld/transitions, Bag/Stats, and Gold/Silver import data. The protected Gold/Silver Bill's PC methods `doWithdraw`, `checkSpaceInDestination`, and `askRelease` retain compatible semantic roles, so Nuzlocke's Party Size and progression-catch wrappers require no migration. Gen 2 `battle.exp_award` now honors an explicit announce argument; Nuzlocke records that as a useful future EXP-policy capability but does not adopt ownership in this build. Mod API 2, Save Schema 4, and the `>=0.1.86 <2.0.0` engine range remain unchanged. Exact 0.2.19 runtime smoke testing is still required.

## Randomizer information compatibility

Compatibility API 30 adds spoiler-aware starter information to the public registry. Compatible tools should call `Registry.starterInformation(context)` rather than reading starter cache keys directly. OPEN INFO may reveal the persisted slate; BLIND INFO must not reveal randomized starter species. The returned diagnostic metadata is read-only and consumes no RNG.

Compatibility API 31 adds `Registry.encounterDiagnostics(context)` and augments `Registry.encounterInformation(context)` with read-only spoiler-aware encounter diagnostics. Compatible encounter/tracker tools should treat `encounter_identity` registry changes as logical-area invalidation: Area Split toggles can change Nuzlocke tracker ownership without changing the physical randomized encounter mapping. OPEN INFO may expose live randomized source species and the full registry; BLIND INFO must not return the whole randomized registry or source species. Source/class/time/group/candidate/protection/split/fallback metadata remains available under BLIND.

## Compatibility API 32 Field Item diagnostics

Compatible tools should use `Registry.fieldItemDiagnostics(context)` instead of reading `__nuzlocke_random_field_item_slots` directly. OPEN INFO may reveal canonical persisted randomized item choices. BLIND INFO retains exact edition/table model, ownership, item/category counts, mapping counts/source keys, and fallback diagnostics but must not reveal randomized item choices or their derived semantic category/table class.

The engine's effective item registry remains `game.data.items` in both generations. Nuzlocke normalizes R/B/Y as `GEN1_FLAT` and Gold/Silver as `GEN2_POCKETS`; providers should preserve normal merged item records rather than creating a parallel Nuzlocke-only registry.

## Field Item randomizer compatibility

Visible Field Item randomization remains acquisition-time and cooperative. Providers that expose item definitions may mark required content through key-item pocket/flags, progression/story/quest/required metadata, `randomizable=false`, `nuzlockeRandomizable=false`, or preserve/deny/provider/external/owned randomization policy. These signals are hard protection and cannot be relaxed by later item-pool preferences.

Field-item persistence uses permanent edition/source identity while Randomizer v1 continues hashing the historical semantic source plus authored item. Provider source/object identity should therefore remain stable across reloads when possible.


Phase D repetition-aware providers should supply a stable numeric `sourceId` / `objectId` or explicit `sourceOrdinal` when possible. `UNIQUE` can then use the native ordinal as a deterministic permutation lane; nonnumeric ids are supported deterministically but report degraded uniqueness. Providers should also set `sourceKind="HIDDEN"` for hidden/BG-event items they route through this helper, because visible Field Item ownership intentionally rejects those sources. Legacy calls that omit source-kind context preserve the historical visible-source assumption.

## Semantic enforcement coverage

2.6.55 added a machine-audited coverage map for high-risk cross-mod operations. Compatibility is no longer inferred merely from the presence of a historical hook: the map records the semantic operation, its rule family, enforcement seam, provider surface, and evidence class. The first behavior-level regression suite protects acquisition and randomizer public contracts on every Release Safety run.

STATIC/HARNESS evidence is not Runtime/Provider PASS. Replacement UI or transaction paths introduced by external mods still require exact combination testing when they bypass an engine-native operation.

## Ownership model

Nuzlocke owns its challenge legality and tracking. External content mods continue to own their maps, quests, weather, trainer design, abilities, economies and other systems unless they explicitly delegate a semantic capability.

Prefer this order:

1. explicit live/provider semantic metadata;
2. compatible public capability/provider contract;
3. Nuzlocke fallback knowledge;
4. conservative/unknown behavior when correctness cannot be established.

Do not double-apply a non-core feature when another mod already owns it.

## Canonical provider vocabularies

### Acquisition kinds

The authoritative kind vocabulary is `Acquisition.KINDS`; the enforcement meaning of every kind is `Acquisition.KIND_POLICY`. New kinds must be classified explicitly before they are usable. See `docs/API.md` for the matrix.

### Encounter / learnset randomizer ownership

Canonical values are `allow`, `deny`, and `provider`. Aliases normalize centrally (`preserve/story` → deny; `external/owned` → provider). Providers should not maintain their own shadow vocabulary.

### Battle roles

Use semantic roles such as `rival`, `gym_leader`, `elite_four`, `champion`, and `progression_boss` rather than arbitrary trainer-id substring matching.

## Kanto Reforged 1.3.0

Kanto Reforged is treated as a high-overlap content provider, not a replacement Nuzlocke ruleset.

- **Level caps:** Nuzlocke may compose with KR's live `level_caps_on`/`capFor` system and use the stricter live cap without mutating KR state.
- **Held items:** KR can provide held-item capability on R/B/Y. No Held Items removes player GIVE while preserving TAKE/recovery and does not delete held-item values.
- **Encounter randomization:** curated KR tables can compose with Nuzlocke. KR Full Spawn Mix / Pure Random are provider-owned so Nuzlocke does not double-randomize them.
- **Fixed statics:** source-confirmed KR fixed legendary/mythical encounters are marked static/non-randomizable; roamers are not treated as statics merely because of species identity.
- **Day Care:** KR's custom two-parent R/B/Y Day Care is covered by the custom-deposit guard; withdrawal/recovery remains available.
- **Gold restored content:** restored Viridian Forest uses the generic Dungeon Content API; Mt. Moon/Seafoam already match existing families. Safari remains an area-split concern; Cerulean Cave is not force-classified into a trapping lock.
- **Species/moves:** expanded Gen1–3 metadata/categories should flow through live/provider metadata rather than duplicated Nuzlocke tables.

Combination runtime testing remains required.

## The World 5.10.0

The World is handled capability-first. Nuzlocke does not read private The World save state merely to infer Dynamic Champion, Rocket Ball, WX, weather or simulation semantics.

- dynamic trainer parties/roles may compose through semantic trainer providers;
- expanded species/move data may compose through merged metadata;
- weather/living-world simulation remains externally owned;
- theft/owned-capture style acquisitions can use the public Acquisition API;
- Wonder Trade remains observe-only unless a safe pre-transaction provider seam exists.

Combination runtime testing remains required.

## VanillaPlus 0.3.0

VanillaPlus remains owner of its quests/maps/NPCs/rewards/story flags. The audited progression-required captures are identified by exact source context rather than broad species rules. PC Catches may apply only when the source explicitly marks a mandatory progression acquisition and permits the exception; ordinary catches remain subject to normal rules.

## Presentation / UI mods

Modern UI, Wide Menus-style layouts and other presentation mods should own their surfaces. Nuzlocke uses native/classic fallbacks where a shared expanded layout cannot be proven safe. Presentation compatibility is independent from gameplay enforcement confidence.

## Trainer / randomizer / metadata providers

- final trainer-party providers should expose the actual composed team;
- species providers should expose types/BST/classification where possible;
- move providers should expose explicit category metadata where possible;
- encounter providers should identify ownership/randomization policy rather than expecting order-dependent wrapper behavior;
- acquisition providers should call the canonical Acquisition API with a deliberate kind and `captureAttempt` truthfully set.

## Diagnostics / wrapper composition

2.6.57 centralizes the previous install-health recorder into SafeInstall, Hook Registry and Feature Health. Existing owner-aware wrapper/session composition remains authoritative; the registry observes those owners rather than replacing them. A live wrapper installed above Nuzlocke is represented as CHAINED/`DEGRADED`, not automatically as a fatal conflict, because legitimate mods may compose above the Nuzlocke wrapper. Missing required ownership can be represented as `UNAVAILABLE`.

Gen2 adapter installation still uses stable subsystem ids and is now routed through `safeInstall()` via the compatibility `attemptInstall()` alias. Explicit `false` returns no longer masquerade as successful installs merely because `pcall` itself succeeded.

Static/source compatibility claims never imply Runtime PASS. Red, Blue, Yellow, Gold and Silver evidence is tracked independently; provider-interop evidence is also tracked separately from ordinary player-runtime evidence.
