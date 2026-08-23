# Nuzlocke 2.7.25 — Release Notes

2.7.25 is the **release promotion of exact 2.7.24**. The promotion itself introduces no new gameplay semantics; it packages the completed 2.7.x hardening work, documentation audit, and Gen1Recomp 0.2.20 source-compatibility review into the release build.

## Release highlights since 2.7.0

### Reliability and persistence

- Hardened Gameplay Transactions across Rare Candy to Cap, Forgiveness, Gym rewards, and progression.
- Transaction receipts now require matching **ID + kind** and future-version journals fail closed across execute/recover/advance/checkpoint/clear.
- Rare Candy transactions use versioned monotonic attempt IDs and preserve real transaction failure reasons.
- League progression and required Run History evidence are committed as one recoverable semantic operation.
- Route Forgiveness death archival fails closed: a dead Pokémon is not physically deleted until its revival snapshot is durably archived.
- Run History reads preserve unsupported-future-schema errors instead of presenting unreadable history as empty.
- Run History repair/dedupe handling is authoritative, and malformed baseline catch/death counters now persist their normalized values.

### Compatibility and provider ownership

- Public acquisition commit handoff uses opaque, one-shot Nuzlocke-issued decision tokens; compatibility callers cannot manufacture an allowed acquisition result.
- `Registry.describe(game)` now consistently uses the explicitly requested game context for Randomizer ownership/delegation fields.
- Stadium provenance is protected from later heuristic gift/trade reclassification.
- Stadium compatibility diagnostics distinguish origin ambiguity from provider ambiguity and can retain the single detected importer provider.
- Release Safety now verifies the Stadium provenance API/module contract.
- Gen1Recomp **0.2.20** was source-audited against 0.2.19: **6 commits / 26 changed files**. Stronger in-process launcher/game/Save Editor teardown and Gold/Silver label-keyed ROM text require no Nuzlocke source migration or API bump.

### Randomizer hardening

- Disabled Encounter/Learnset Randomizers have an explicit healthy `disabled` lifecycle state rather than being misreported as failures.
- Release Safety and DEV diagnostics now share the Randomizer projection ownership audit.
- Learnset-only randomized runs correctly show the OPEN/BLIND information policy in NUZ STATUS.
- Encounter evolution profiling is built once per balanced apply/report pass and threaded through consumers instead of being rebuilt per encounter leaf; CHAOS retains the zero-build path.
- Randomizer algorithm version remains **1** and encounter policy version remains unchanged. Phase E remains intentionally not started.

### World Building / player feedback

- World Building remains presentation-only and independent of the Nuzlocke master switch.
- World Building OFF still suppresses optional flavor, but consequential feedback for external gift denial, external trade denial, and Failed Encounter area consumption uses plain Tier-1 wording rather than disappearing.
- Release Safety protects both sides of that contract.

### Release Safety / diagnostics

- Release Safety package scans use the authoritative shipped Lua inventory rather than fragile hardcoded subsets where applicable.
- Added/expanded regression checks for transaction identity, future-journal preservation, Randomizer ownership/state, Stadium provenance, World Building critical feedback, pass-scoped Randomizer profile construction, public-game-context consistency, and Run History normalization.
- Current package contract remains **30 files / 20 Lua** with **138 / 138 unique rule keys**.

## Engine / API contract

- Gen1Recomp Mod API: **2**
- Supported engine range: **`>=0.1.86 <2.0.0`**
- Latest source-audited Gen1Recomp release: **0.2.20**
- Save Schema: **4**
- Compatibility API: **32** (`compatible_from = 10`)
- Diagnostics API: **1**
- Run History API/storage: **1**
- Randomizer algorithm: **1**

## Runtime status

The 2.7.x line preserves historical exact-build runtime evidence, but **2.7.25 itself has not been newly runtime-certified by this promotion step**. Static/source/harness validation does not count as Runtime PASS. Exact Red/Blue/Yellow/Gold/Silver and third-party-provider combinations remain independent evidence targets.

## Scope of 2.7.25 itself

2.7.25 changes only release version/provenance and release-facing documentation from exact 2.7.24. No challenge-rule semantics, Randomizer mappings/algorithms, acquisition policy, Save Schema, public API version, or ordinary gameplay behavior were intentionally changed in the promotion.
