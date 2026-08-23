# Nuzlocke API — 2.7.28

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

These provider capabilities are ownership/coexistence signals rather than permission to bypass Nuzlocke legality. A provider should advertise ownership only while it actually controls the overlapping mechanic. 2.6.90 adds `field_item_randomizer_provider`; it does not change Compatibility API 32 because the legacy `nuzlocke_compat` function surface is unchanged.

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
