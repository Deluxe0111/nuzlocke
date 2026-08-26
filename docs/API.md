# Nuzlocke API — 2.8.31

No public API, Compatibility API, Diagnostics API, or save-schema version change. Internal Random Starter diagnostics now expose style-aware persisted-choice validation; Gen II starter lineage reads native evolution `into` targets.

# Nuzlocke API — 2.8.29

No public API or save-schema change. Gen II no longer registers Nuzlocke Battle Menu UI presentation hooks, and the retired Gen II battle-rule pager no longer wraps `BattleState.update`. Battle denials remain internal policy enforcement presented through native BattleState message handling.

# Nuzlocke API — 2.8.29

No public API or save-schema change. Battle Menu UI registers `battle.bottom_ui_visible` and `battle.overlay` composition only on Gen I. Gen II installs neither presentation wrapper. Gen II rule denials also no longer wrap `BattleState.update` or create a custom Nuzlocke battle phase.

## Historical current note: Nuzlocke API — 2.8.27

No public API or save-schema change. Gen II PartyMenu methods are no longer
wrapped by Nuzlocke. Field NUZ INFO continues through `ui.party.submenu`, with
`ctx.battle=true` returned unchanged.

## 2.8.01 API note
No public API version changes. This hotfix changes only Gen II rule visibility and Nuzlocke-owned field-poison wipe reconciliation.


## 2.8.00 API note

No public compatibility API version bump. The Gen2 party-consumable repair is internal: Nuzlocke's Pack legality seam now resolves a selected `useItem` party index back to the live save-party record before invoking Gen1Recomp's merged Gen2 ItemEffects. Existing public item-legality/provider surfaces remain unchanged.

## 2.7.106 API note

No public Compatibility API, Diagnostics API, Save Schema, or Randomizer algorithm version changes. The Gen2 repair is internal runtime ownership for simple party consumables and uses Gen1Recomp's existing `src.core.gen2.ItemEffects` and Game2 services. PP items and evolution stones remain native specialized paths. Five-stage Setup/Rules hold acceleration is screen-local input behavior.

## 2.7.105 API note

No public Compatibility API, Diagnostics API, Save Schema, or Randomizer algorithm version changes. The Gen2 repair is an internal PartyMenu constructor contract guard for the native `useItem` chooser. The read-only `gen2PartyRecordHealth` probe remains internal; the 2.7.104 automatic full-record materializer/repair snapshots are retired. Setup/Rules held navigation is screen-local input behavior and does not add an API surface.

## 2.7.104 API note

No public Compatibility API, Diagnostics API, Save Schema, or Randomizer algorithm version changes. A private/read-only `gen2PartyRecordHealth` diagnostic and last-repair snapshot are added under the existing internal beta export namespace for runtime diagnosis only.

## 2.7.103 API note

No public compatibility API contract changes. The Gen2 repair is an internal engine-ownership routing correction at the native Pack/Game2 boundary.

## 2.7.102 API note

No public Compatibility API, Diagnostics API, Save Schema, or Randomizer algorithm version changes. The Gen2 party-item repair is an internal representation-normalization seam; Saved Setup Preset persistence continues to use the existing installation-scoped cache contract.

## 2.7.101 API note

Nuzlocke public API numbers are unchanged. The engine source/documentation compatibility marker advances to **0.2.25** while the minimum remains `>=0.2.24 <2.0.0`. Gen1Recomp 0.2.25 adds read-only imported-version dataset views; this build records that capability but does not use it to replace active-game transaction authority.

# Nuzlocke API — 2.7.85

## 2.7.85 API / ownership notes

No public API or schema version changes. Compatibility API remains 34, Diagnostics API remains 1, and Save Schema remains 5. Crystal's starter presentation now explicitly fails open to the engine-owned native POKEPIC/cry callbacks; Nuzlocke retains transaction ownership only at the existing shared GIVEPOKE/tracker seam. DEV stored-state validation derives expected Randomizer registry sizes from exported live registries rather than hardcoded historical counts.



## 2.7.84 API / ownership notes

No Nuzlocke public API number changes: Compatibility API remains 34 and Diagnostics API remains 1. The engine compatibility marker advances to **0.2.24**, the minimum engine becomes `>=0.2.24 <2.0.0`, and the explicit manifest target set becomes Red/Blue/Yellow/Gold/Silver/Crystal. Crystal is tagged internally as `stage = "ALPHA"`; exact edition remains `crystal`, generation remains 2, and shared Gen-2 providers/adapters are reused only where the underlying engine contract is common.

Upstream `mod.developer` remains the engine-owned developer signal. `mod.world:activeBlockAt()` and `map.occupancy_allowed` are recorded as useful Gen-1 map-safety seams but are not new Nuzlocke API surfaces. `battle.field_residual` remains intentionally unused until Gen-2 parity exists. `src.ui.OptionRows` remains forbidden on Gen-2 Nuzlocke UI, and direct `src.script.Commands` use remains a Gen-1-only compatibility boundary.


## 2.7.83 API / ownership notes

No public API version changes. Compatibility API remains 34 and Diagnostics API remains 1. The new loadout and Difficulty selectors consume existing internal `LockePreset.preview/apply`, `difficultyProfileSummary()`, `difficultyImpactChanges()`, and `difficultyStackWarning()` ownership rather than adding a parallel configuration API. Manual Gen-2 time is a Nuzlocke-owned UI action over the engine's native `src.core.gen2.Clock`; it does not introduce a new clock provider contract.


## 2.7.82 API / ownership notes

No public API version changes in 2.7.82: Compatibility API remains 34 and Diagnostics API remains 1. `releaseSafetyAudit()` is retained as an internal/build-process capability but is no longer executed or inserted into player-facing `Dev.selfTest()` results. Internal report-code/fingerprint helpers are retained for compatibility/testing but normal/exported Dev text no longer depends on or renders them. Gen-2 adapter installation now accepts the exact lifecycle Game through `G2.installAll(game)` internally; this is an ownership/lifecycle repair, not a new public provider surface.


## Gen1Recomp 0.2.21 compatibility surface

The source-audited engine profile is 0.2.21. Mod API remains 2. `mod.developer` is recorded as engine-owned diagnostic metadata and is intentionally separate from Nuzlocke's `dev_mode`. Gen2 clock integration prefers native `Clock.hostMinutes()` / `hostWeekday()` and writes only through `Clock.setTime()` / `setWeekday()`. `battle.field_residual` is noted as available on Gen1 but is not adopted by Nuzlocke in this build.

## 2.7.80 internal transaction/clock behavior

No public API or save-schema version changes. 2.7.80 adds internal Gen-2 pending Elm transaction finalization, native clock integration, and Rare Candy batch-cancellation state only. Compatibility API remains 34 and Diagnostics API remains 1.

## 2.7.79 internal Gen-2 starter authority

No public API/schema version changes. 2.7.79 changes internal shared Gen-2 Elm transaction classification, proven-starter story reconciliation, reachability diagnostics, and presentation helpers only; Compatibility API remains 34 and Diagnostics API remains 1.


No public API/schema version changes. 2.7.77 changes internal Gen-2 UI/script/randomizer integration only; Compatibility API remains 34 and Diagnostics API remains 1.


## 2.7.78 internal recovery behavior

No public API/schema version changes. 2.7.78 changes internal starter identity normalization and cross-edition Recover Catches availability only; Compatibility API remains 34 and Diagnostics API remains 1.
## 2.7.76 internal Gen-2 diagnostics

No public API/schema version changes. 2.7.76 adds internal Gen-2 adapter reachability diagnostics only.

## 2.7.66 rule-availability audit, pass 2

- Continues the rule-availability audit in a deliberately small pass.
- Yellow no longer exposes Random Starter `Trio Typing` as a native rule because Yellow does not natively use the three-choice starter slate; an explicit compatible `starter_trio` provider can make it available.
- Encounter-slot modifiers now depend on `One Per Area`: Failed Encounters, Dupes, Gen II roamer/egg/contest policies, Town Catches, and area/time/headbutt split controls become dormant while area encounter limits are OFF.
- Type Locke now exposes/effects only the lanes selected by its mode. Catch Draft is hidden while Type Locke is OFF; manual type lanes are hidden/inert during Catch Draft; DUO through HEXA progressively reveal only the required lanes.
- Stored values are preserved while dormant and return when their prerequisite becomes applicable again.
- Release Safety extends the exact-edition/dependency source tripwire for these relationships.


# Nuzlocke API — 2.7.65

## Rule availability contract — Compatibility API 34 / 2.7.65

`ruleNativeAvailableForEdition(rule, edition)`, `ruleAvailableForGame(rule, game)`, and `ruleOperationalState(key, preGame, game)` expose the shared availability/dependency decision used by configuration UI and effective gameplay reads. Hidden dependent/superseded values remain stored but resolve neutral while inactive.

## Compatibility owner preferences — API 33 / 2.7.64

The compatibility surface exposes live owner-choice helpers used by MOD COMPAT: `compatOwnerPreference(capability)`, `setCompatOwnerPreference(capability, value)`, and `compatOwnerChoices(capability, nativeOwner)`. Choices are derived only from the native owner plus providers discovered through advertised capability contracts. Preferences are save-local and default to `auto`.

Provider consumers continue to resolve through the normal live compatibility resolver; selecting a provider is therefore functional rather than display-only. Missing or inactive pinned providers fail open to `auto`.

## 2.7.57 presentation API addendum

`mod.exports.nuzlocke_ui_system` / `mod.exports.__beta26.UiSystem` is an experimental presentation-only API (v3). It exposes provider-neutral logical-surface policies plus live-font typography helpers for measured fit, wrapping, right-edge alignment, semantic rows, and notice models. These APIs carry no gameplay authority and remains internal and may evolve without public-API stability guarantees.

# Nuzlocke API — 2.7.57

This build does not change Compatibility API, Diagnostics API, Run History API/storage, Randomizer public API/algorithm, or Save Schema versions. It adds an internal/exported experimental `nuzlocke_ui_system` presentation object for Nuzlocke-owned screens; it is not yet a stable third-party compatibility API and must not be treated as one until explicitly versioned/promoted.

2.7.27 adds internal Learnset Randomizer hard-safety and soft semantic weighting only. Public API versions remain unchanged; providers can opt moves out through existing randomizable/protection metadata and should expose usable move records with a non-empty name and positive PP.
2.7.25 is a release promotion only. Public API versions and the provider/developer contract are unchanged from exact 2.7.24.
This document describes the **current provider/developer contract**. Historical API changes belong in `CHANGELOG.md`.

2.7.24 changes no public API version. The documentation audit reconciles the current transaction, Randomizer-ownership, Stadium provenance, Run History, and exact-game-context contracts with the shipped implementation. `Registry.describe(game)` uses one resolved game context for all returned registry and Randomizer-ownership fields.

## Versions

- Compatibility API: **32**
- Compatible from: **10**
- Diagnostics API: **1**
- Run History API/storage: **1**
- Randomizer public API/algorithm: **1**
- Save Schema: **4**

The canonical namespace is `mod.exports.nuzlocke`; the long-lived `__beta26` alias remains for compatibility.

### Randomizer ownership providers

The public interop capability resolver recognizes explicit ownership providers for overlapping randomizer mechanics:

- `starter_randomizer_provider`
- `encounter_randomizer_provider`
- `field_item_randomizer_provider`
- `learnset_randomizer_provider`

These provider capabilities are ownership/coexistence signals rather than permission to bypass Nuzlocke legality. A provider should advertise ownership only while it actually controls the overlapping mechanic. 2.6.90 adds `field_item_randomizer_provider`; it does not change Compatibility API 32 because the legacy `nuzlocke_compat` function surface was unchanged during build development.

### Compatibility API 32 — Field Item information

Compatibility API 32 adds spoiler-aware Field Item diagnostics:

- `Registry.fieldItemInformationPolicy(game)` — returns OPEN/BLIND policy and whether persisted randomized Field Item mappings may be revealed.
- `Registry.fieldItemDiagnostics(context)` — returns the read-only Field Item diagnostic payload. OPEN may include persisted randomized item choices; BLIND omits randomized item/category/table-class values while retaining safe edition/source/count/ownership/fallback metadata.
- `Registry.describe(game)` now includes `randomFieldItems` and `fieldItemInformation`.

Field Item diagnostic reads do not request a writable/AUTO seed, consume randomizer RNG, or intentionally mutate the FIELD_ITEMS mapping/constraint ledger.

### Field Item randomizer helper contracts

The internal compatibility namespace exposes read-only Field Item foundation helpers for diagnostics/integration:

- `randomFieldItemClassification(itemId, def)` — returns the authoritative protection category/reason.
- `randomFieldItemSourceIdentity(game, semanticSlot, context)` — returns permanent edition/source identity; authored item contents are not part of the canonical persistence key.
- `randomFieldItemOwnership(context)` — reports whether the source belongs to visible Field Item randomization. Explicit hidden/BG-event kinds are not owned.
- `randomFieldItemEditionProfile(game)` — reports exact edition/generation, `GEN1_FLAT` vs `GEN2_POCKETS`, merged `data.items` ownership, native visible pickup seam, and hidden-item ownership state.
- `randomFieldItemEditionTableClass(game, itemId, def)` — normalizes the live item definition to an edition-specific item-table class.
- `randomizerFieldItemInfo(game, reveal)` — internal read-only diagnostic payload used by Compatibility API 32.

These internal helpers did not themselves bump the public API. The current public Compatibility API is **32**; public Field Item information is exposed through the Registry methods above.

### Randomizer information registry additions

Compatibility API 30 added read-only starter-information access through the public registry:

- `Registry.starterInformationPolicy(game)` — returns OPEN/BLIND starter reveal policy and whether Random Starter is active.
- `Registry.starterInformation(context)` — returns the policy plus read-only starter diagnostics. OPEN INFO may include the persisted positional starter slate; BLIND INFO suppresses species while retaining version/seed/settings/candidate/fallback metadata.

These calls consume no randomizer RNG and do not materialize or rewrite starter mappings.


Compatibility API 31 adds encounter diagnostics:

- `Registry.encounterDiagnostics(context)` — returns spoiler-aware, read-only encounter randomizer metadata. OPEN INFO may include live randomized source species; BLIND INFO excludes species while retaining source identity, class/time/group, candidate/protection/split/mapping/fallback metadata.
- `Registry.encounterInformation(context)` — now includes the same `diagnostics` payload. API 31 also hardens BLIND behavior: a discovered/owned context may be individually allowed, but BLIND never returns the whole randomized registry; OPEN retains full-registry reveal.
- Area Split changes may emit `registry_changed` with kind `encounter_identity`; this invalidates logical tracker/information views only and does not imply that the physical randomized encounter registry was regenerated.

Encounter diagnostic reads consume no RNG and do not intentionally mutate encounter mappings or the constraint ledger.

## Acquisition API

`Acquisition.evaluate(context)` is the canonical public legality entry point for non-native/provider acquisitions. The acquisition vocabulary is defined by `Acquisition.KINDS`; semantic enforcement is defined by `Acquisition.KIND_POLICY`. Adding a kind without a complete policy row is an initialization error.

### Acquisition kind semantics

| Kind | Capture rule | Species legality | Area legality | Party admission | Source rule |
| --- | ---: | ---: | ---: | ---: | --- |
| `wild` | yes when `captureAttempt=true` | native catch path | native catch path | native catch path | normal encounter |
| `gift` | no | yes | yes | yes | gift policy |
| `trade` | no | yes | yes | yes | trade policy |
| `trainer_capture` | yes when capture attempt | yes | no | yes | provider-owned capture |
| `theft` | yes when capture attempt | yes | no | yes | provider-owned capture |
| `owned_capture` | yes when capture attempt | yes | no | yes | provider-owned capture |
| `quest` | deliberate provider/source semantics | policy-defined | policy-defined | policy-defined | content/provider |
| `summon` | deliberate provider/source semantics | policy-defined | policy-defined | policy-defined | content/provider |
| `scripted` | neutral unless caller supplies specific policy | no automatic sweep | no | no | scripted owner |
| `forced` | neutral unless caller supplies specific policy | no automatic sweep | no | no | scripted owner |
| `editor` | neutral | no | no | no | tooling/editor |
| `wonder_trade` | observe-only | no transaction veto | no | provider transaction | external owner |

For the current matrix, `trainer_capture`, `theft`, and `owned_capture` deliberately receive No Catching on true capture attempts, species legality (Type Locke, species bans, Maximum BST, glitch policy, etc.), and Party Size admission without pretending they are ordinary area encounters.

### Species legality

Species legality may consult merged/provider metadata for types, BST/base stats, generation, Legendary/Mythical/Pseudo flags and other classification facts. Authoritative legality paths fail closed on provider/classifier exceptions rather than silently allowing an acquisition.

## Semantic enforcement coverage and regression contract

`mod.exports.__beta26.semanticEnforcementCoverage()` returns a defensive copy of the high-risk operation coverage matrix. Each row identifies rule keys, edition/capability scope, authoritative enforcement seam, provider surface, and evidence class. It is a review/test map from behavioral promises to enforcement owners, not another source of rule defaults.

`mod.exports.__beta26.semanticBehaviorRegressionAudit()` is the non-mutating behavior-level regression suite. Release Safety executes it on every full gate. The initial 2.6.55 suite exhaustively checks acquisition-kind policy shape, critical acquisition semantics, classifier precedence, the complete randomizer policy/alias vocabulary, and required semantic-coverage rows. A failed assertion fails the release gate.

## Stadium acquisition provenance API v2

`mod.exports.nuzlocke_acquisition_provenance` is the cooperative Stadium provenance surface. Model/render imports and Pokémon acquisitions are intentionally separate.

- `mark(mon, origin, context?)` marks one actual Pokémon as `STADIUM PRIZE`; `origin` accepts Stadium 1/2 forms. Optional `provider_id`/`mod_id` and exact-edition metadata are retained.
- `markImported(mon, context)` is the explicit transfer/import helper. `context.origin` is required unless `use_detected_origin=true` is deliberately supplied.
- `describe(mon)` returns saved Stadium acquisition source/origin/provider/edition metadata when present.
- `compatibilitySnapshot(game)` is read-only and reports the exact running edition plus detected Stadium Overworld/UI, Stadium 2, and Crystal 251 presentation/importer surfaces. Its `acquisition_policy` is `explicit_only`: simply loading or importing Stadium models never marks a Pokémon as Stadium-derived.

Compatible transfer/import mods should mark only the Pokémon they actually create. Presentation-only Stadium mods should not call the acquisition marker.

## Content / encounter API

Content providers may register areas, dungeons, bosses, gifts and encounters. Encounter metadata can include source id, map/area id, species, static/fixed provenance, progression requirement, randomizability, provider ownership and variant/form identity.

### Randomizer policy vocabulary

One canonical normalizer is used across encounter registration, encounter policy setters, inline encounter contexts, learnset policy setters and readers.

Canonical values:

| Value | Meaning |
| --- | --- |
| `allow` | Nuzlocke may perform its randomizer transform. |
| `deny` | Preserve this encounter/learnset; Nuzlocke does not transform it. |
| `provider` | Another provider owns randomization; Nuzlocke steps aside. |

Aliases:

- `true` → `allow`
- `false` → `deny`
- `preserve` / `story` → `deny`
- `external` / `owned` → `provider`

Unknown values are rejected rather than silently interpreted.

## Battle-role API

Dynamic trainer providers should publish semantic roles instead of relying on trainer-name substring matching. Supported roles include:

- `rival`
- `gym_leader`
- `elite_four`
- `champion`
- `progression_boss`
- ordinary trainer/default

Live trainer-party providers may also supply the final composed team so level-cap/team-size diagnostics follow actual battle content.

## Species / move metadata

Live merged/provider species metadata is first-class evidence. Nuzlocke prefers explicit provider/live move-category metadata over fallback Physical/Special mappings. External moves that explicitly declare a correct category are not rewritten merely because they belong to an older type family.

## Level-cap / EXP composition

Authoritative Nuzlocke EXP clamps run outside ordinary EXP multipliers. A blocked cap award remains zero. Cooperative contexts may expose `nuzlockeExpBlocked`, block reason and cap metadata.

## Held-item capability

Gold/Silver use the native held-item engine. R/B/Y can expose No Held Items only when a compatible external held-item capability is present. Providers should keep GIVE/TAKE semantics distinguishable so Nuzlocke can block GIVE while preserving safe removal/recovery.

## Gameplay transaction contract

`mod.exports.__beta26.GameplayTransactions` is the v1 interruption-recovery coordinator. It owns one durable pending journal (`__nuzlocke_gameplay_txn_v1`) plus bounded committed receipts (`__nuzlocke_gameplay_txn_receipts_v1`). A transaction kind is registered with `register(kind, { probe=..., perform=... })`; `probe` must return applied/not-applied/unknown semantics and `perform` owns all externally visible mutation. The durable COMMIT state is a journal marker, not a second arbitrary side-effect callback.

`execute(id, kind, payload)` provides exactly-once replay protection for a stable logical transaction identity. Durable receipt authority is **ID + kind**; an ID collision with another kind fails closed. `recover()` resumes a pending transaction after load. Unknown/ambiguous reconciliation fails closed. Unsupported future transaction journals are preserved: execute/recover and journal-mutating helpers (`advance`, `checkpoint`, targeted `clear`, and broad `clear`) reject them with `newer_transaction` rather than rewriting or deleting them. `setExact(id, key, value)` is the initial generic recovery-safe save-value primitive.

The coordinator is infrastructure, not a blanket claim that every historical gameplay action is atomic. Feature owners adopt it only when they can prove a stable id and a deterministic reconciliation probe.

## Install / diagnostics contract

`mod.exports.__beta26.safeInstall(spec, fn, ...)` is the central fail-soft installer entry point. `spec` may provide stable `id`, `feature`, `required`, `priority`, and `mode` metadata. `attemptInstall(name, fn, ...)` remains a compatibility alias. An explicit installer `false` is a diagnostic failure rather than a successful `pcall`.

`mod.exports.__beta26.hookRegistry` records hook ids with owner, prior/wrapper references where available, priority, mode, feature and source metadata. `describe()` returns a defensive diagnostic view; `audit()` treats malformed ownership/metadata as failure while legitimate top-level interposition is reported as a warning rather than automatically breaking release safety.

`mod.exports.__beta26.featureHealth` summarizes supported feature/install state as `ACTIVE`, `DEGRADED`, or `UNAVAILABLE`. Existing detailed Dev Hook Health remains the engine-facing diagnostic source and feeds this stable summary. Install failures are retained with standardized `[Nuzlocke:Subsystem]` diagnostic prefixes.

## Stability rules for providers

- Treat public tables as read-only unless a setter/register function explicitly owns mutation.
- Prefer semantic capabilities over mod-name checks.
- Preserve explicit caller values; provider/default metadata should fill only absent values.
- Do not rely on accidental `_ENV` lookup or private Nuzlocke locals.
- Provider/API correctness has its own confidence status; player-facing Runtime PASS does not imply provider-interop PASS.


## Gen1Recomp 0.2.20 source-compatibility audit

The 0.2.19 → 0.2.20 delta changes no public Nuzlocke provider API requirement and no Gen1Recomp Mod API version. The main compatibility-relevant engine change is stronger launcher/session teardown: generated Data, mod Runtime state, Assets loader state, LegacyCompat state, and generation-specific Game instance fields are reset before a later in-process Edit/Play session. Gold/Silver also gain extracted label-keyed engine text through `data.text`. These changes require no Nuzlocke API migration; runtime validation remains separate from source compatibility.

## Gen1Recomp 0.2.19 mod-options persistence audit

Gen1Recomp's `modOptions` store is installation/options state rather than Pokémon save progress. Engine tests explicitly round-trip `modOptions.nuzlocke` through the flat `options.lua` store and verify Gold reads/writes the same flat store as Gen 1.

For Nuzlocke preset design, however, the public API boundary matters: `mod.options` exposes `define(schema)` and `get(key)`, but no runtime `set` method. The in-game/launcher option manager owns writes and persistence. Supported schema row types are toggle, choice, number, and text. Therefore a future named Saved Setup Presets feature should not reach behind the public facade or mutate engine internals merely to write arbitrary preset blobs. Keep the existing working setup-profile persistence until a supported writable installation-scoped API is available, or represent a deliberately bounded preset surface as normal engine-owned option rows.

## Experimental presentation API

`nuzlocke_ui_system` apiVersion 2 is test-only. It adds screen policies and logical layout contexts. It is not yet a stable public compatibility API.
