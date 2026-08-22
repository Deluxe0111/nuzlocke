# Feature Confidence — 2.7.0
- **2.7.0 release promotion / 2.6.98 Setup + NUZ RULES repair:** RUNTIME PASS for the user-reported affected flow. 2.6.97 Release Safety is also Runtime PASS.
- **2.6.96 documentation/header packaging repair:** STATIC/SEMANTIC PASS — RUNTIME RETEST REQUIRED. Release Safety header expectations are restored without changing gameplay.
- **2.6.95 NUZ RULES diagnostic repair:** STATIC/SEMANTIC PASS — RUNTIME RETEST REQUIRED. The rival-sync audit now closes over its intended local helper.
- **2.6.94 Lua unpack audit scope:** STATIC/SEMANTIC PASS — RUNTIME REQUIRED. All shipped Lua modules are now scanned through the authoritative package inventory.


- **Stadium / Crystal 251 compatibility snapshot + explicit Stadium-import provenance v2:** Static/Semantic PASS; combination runtime smoke TEST REQUIRED. Presentation/model imports do not auto-mark Pokémon acquisitions.
- **2.6.92 MOD MANAGER / World Building catalog startup:** RUNTIME FAIL — stale 97-key golden rejected the legitimate 104-key live catalog.
- **2.6.93 catalog repair:** STATIC/SEMANTIC PASS — RUNTIME REQUIRED. Golden refreshed to 104 / 1560 / 926265119 with explicit key-identity drift reporting.

Confidence is tracked on two independent axes:

- **Player/runtime confidence** — does the feature work for normal play on the exact edition/build tested?
- **Provider/API interoperability confidence** — do third-party callers/providers receive the documented semantic contract?

A feature can be strong on one axis and still require testing on the other.

2.6.91 learnset/Rare Candy correctness hardening is **STATIC/HARNESS PASS — RUNTIME REQUIRED**. Learnset drift is now scoped to the three owned move-list fields; Rare Candy partial recovery requires a durable native-effect checkpoint; and Rare Candy attempt IDs use a durable versioned sequence with same-state uniqueness self-test. The 2.6.90 external-randomizer ownership hardening remains **STATIC/HARNESS PASS — RUNTIME REQUIRED**. Named active-feature detection now covers Item Randomizer visible pickups in addition to the existing PokemonRecompRandomizer, Gen 2 Randomizer+, and Kanto Reforged adapters; generic visible Field Item ownership is available through `field_item_randomizer_provider`. Randomizer feature phases remain paused and no algorithm/mapping behavior changed. Exact-edition runtime testing remains deferred. Static/harness evidence covers shared hard-safe candidate resolution, permanent edition/source persistence identity independent of authored item contents, preserved historical Randomizer-v1 field-item seed input, adoption of valid pre-D mappings, authoritative key/HM/progression/story/quest/provider protection, and a seven-case field-item foundation audit. Phase C implementation remains complete through item 11 with its item 12 runtime certification deferred.

## Evidence labels

- **RUNTIME PASS** — observed on the exact build/edition/environment.
- **RUNTIME FAIL** — observed failure on the exact build/edition/environment.
- **STATIC/HARNESS PASS — RUNTIME REQUIRED** — source/compiler/focused harness passes, but no exact runtime claim.
- **PROVIDER PASS** — provider/API behavior exercised through a representative external/public-call path.
- **PROVIDER TEST REQUIRED** — player behavior may be healthy, but public provider semantics are not yet runtime-confirmed.
- **DELEGATED / NOT APPLICABLE** — another owner is authoritative or the feature does not apply.

## Current 2.6.93 touched surfaces

| Surface | Player/runtime | Provider/API interop | Notes |
| --- | --- | --- | --- |
| Random Starter Balance / Trio Typing | STATIC/HARNESS PASS — RUNTIME REQUIRED | N/A | Defaults preserve the v2 starter namespace; BALANCED/AUTO use the v3 starter-only namespace. Exact R/B/Y/G/S starter/rival runtime checks remain required. |
| Starter Rerolls / Starter Info / Yellow dependencies | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Reroll indices are starter-only; public starter information is Compatibility API 30; Yellow non-Pikachu starters receive the narrow Cerulean happiness-gate repair. |
| Random Encounter candidate engine / source identity / order independence | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Canonical source storage is separate from the preserved v1 RNG slot; live encounter work plans are sorted before generation. |
| Encounter repeats / progression-aware balance | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | ALLOW/DIVERSE/UNIQUE are group-local; EVO/BALANCED use bounded family-depth/ceiling data and native encounter level without changing table structure. |
| Diversity strength / encounter classes / protected sources | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | DIVERSE strength is configurable; Gen 2 methods/time buckets are normalized; explicit static/story/progression-like records are never ordinary wild-table randomization targets. |
| Area Splits × Random Encounters / Encounter Info | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Logical split projection is separated from physical randomizer mapping; Compatibility API 31 exposes spoiler-aware encounter diagnostics without consuming RNG or rewriting mappings. |
| Field Item candidate engine / permanent source identity / progression classification | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Visible pickup candidates use shared hard safety; persistence identity excludes authored item; key/HM/progression/provider-protected items fail closed. |
| Field Item repeats / deterministic placement / visible-hidden ownership | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | ALLOW preserves legacy behavior; UNIQUE uses stable native source ordinals within a shared pool; hidden/BG-event sources are not owned. |
| Field Item Gen1/Gen2 normalization / Randomizer Info | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Shared `data.items` is normalized as GEN1_FLAT or GEN2_POCKETS; Compatibility API 32 exposes spoiler-aware read-only diagnostics. |
| External randomizer ownership hardening | STATIC/HARNESS PASS — RUNTIME REQUIRED | COEXISTENCE TEST REQUIRED | Item Randomizer visible-pickup ownership is active-option gated; generic field-item provider delegation and DEV ownership reporting are wired. |
| Random Learnset ownership projection | STATIC/HARNESS PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Snapshot, applied-state capture, and drift comparison share the same `level1Moves`/`learnset`/`levelMoves` projection; unrelated Pokémon metadata is outside learnset ownership. |
| Rare Candy transaction recovery / attempt identity | STATIC/HARNESS PASS — RUNTIME REQUIRED | N/A | Inventory-only recovery requires a transaction-specific native-effect checkpoint; v2 IDs use a durable monotonic attempt sequence so identical revisited Pokémon state cannot reuse retained receipts. |
| Gameplay transaction coordinator v1 | STATIC/HARNESS PASS — RUNTIME REQUIRED | N/A | In-memory interruption harness proves applied-before-journal, receipt-before-clear, replay suppression, busy-journal semantics, durable payload checkpoints, and monotonic sequence allocation. Exact-engine save/reload interruption testing remains required. |
| SafeInstall v2 | STATIC/SOURCE PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Existing Gen2 installer calls route through the compatibility alias; explicit false returns now produce diagnostic failure. |
| Hook Registry v1 | STATIC/SOURCE PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Existing owner-aware wrappers feed owner/previous/wrapper/priority/mode metadata where available. Legitimate interposition remains non-fatal. |
| Feature Health v1 | STATIC/SOURCE PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | Stable ACTIVE/DEGRADED/UNAVAILABLE summary exposed through Dev snapshots/API. |
| Gen1Recomp 0.2.19 engine profile | STATIC/SOURCE PASS — RUNTIME REQUIRED | PROVIDER TEST REQUIRED | 2.6.56 source audit remains inherited; 2.6.57 does not alter the audited engine profile. |

## Protected historical runtime evidence

Previously recorded exact-build/edition Runtime PASS evidence remains historical evidence. 2.6.57 adds **transaction/diagnostic harness evidence**, not new runtime evidence. The inherited 2.6.56 engine-source compatibility audit remains source evidence only. The inherited 2.6.55 semantic regression suite remains STATIC/HARNESS evidence: its acquisition/randomizer contract regression suite is STATIC/HARNESS PASS when Release Safety succeeds, while exact-edition gameplay paths still require runtime confirmation before 2.6.55 itself can inherit a fresh Runtime PASS claim.

Important historical protected classes include R/B/Y rule input behavior, selected Yellow/Blue enforcement paths, Silver exact-edition diagnostics, Encounter Tracker reassignment, Gold/Silver Random Starter award behavior, F. TOKEN/UI repairs, exact-edition detection, and previously confirmed battle/item/shop/healing paths.

## Current provider-interop test debt

Highest-value provider tests:

- Kanto Reforged 1.3.0: custom Day Care, held items, fixed statics, Full/Pure spawn ownership, Gold restored content and dual-cap composition.
- The World 5.10.0: dynamic trainers/roles, expanded species/moves, acquisition kinds, weather/status composition and Wonder Trader stability.
- public randomizer policy calls using every canonical value and alias through registration, inline encounter context and learnset policy setters.
- provider acquisitions using `trainer_capture`, `theft`, `owned_capture`, and deliberate neutral/scripted kinds.

## Exact-edition rule

Red, Blue, Yellow, Gold and Silver are five independent runtime-evidence targets. Shared architecture does not automatically transfer Runtime PASS from one exact edition to another.


### 2.6.66 Rare Candy → current cap
- **Status:** Static/Integrity PASS; Runtime Required.
- R/B/Y and Gold/Silver batch paths use the canonical live level-cap resolver and real inventory.
- Every candy is a separate `rare_candy_step` exactly-once transaction; intermediate move/evolution flows are preserved.
- Runtime evidence is still required for finite-cap, insufficient-candy, move-learning, evolution, No Rare Candy, provider-cap, and interruption/reload cases.
