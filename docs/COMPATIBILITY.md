# Nuzlocke Compatibility — 2.8.00

## 2.8.00 Gen2 party-item compatibility

Crystal runtime showed the 2.7.106 Game2 post-selection wrappers could still lose the item transaction. 2.8.00 moves simple field party-consumable ownership to the Pack USE seam after Nuzlocke legality checks and uses the authoritative `game.save.party[index]` target. Specialized PP, stone, TM/HM, battle and non-party field-item flows remain delegated to their existing owners.

## 2.7.106 Gen2 party-consumable compatibility

Crystal runtime established that the `useItem` party chooser can now select a Pokémon correctly, but the downstream effect handoff still fails for healing items, vitamins, and Rare Candy. Nuzlocke now owns only that narrow post-selection seam for simple Gen2 consumables and calls Gen1Recomp's merged `ItemEffects` record directly on the selected party member. Native Game2 consumption/messages and Rare Candy follow-up remain authoritative; PP items and evolution stones are not redirected. This avoids additional Pokémon-record mutation and does not alter ordinary field-party or battle-party menus.

## 2.7.105 Gen2 party-item chooser ownership

Runtime evidence shows native item selection reaches Gen1Recomp's Gen2 PartyMenu correctly, but the target screen can be contaminated into ordinary field-submenu mode. Nuzlocke now guards only PartyMenu instances opened with the native `useItem` prompt: `submenu`/`battleSubmenu` are forced false and the screen remains a direct `onChoose` chooser. Ordinary field Pokémon menus still own field moves, STATS/SWITCH/MOVE/ITEM and NUZ INFO; battle and TM/HM chooser contracts are unchanged. Permitted items remain owned by Gen1Recomp's native Game2/ItemEffects/consumption flow. The 2.7.104 full-record materialization experiment is retired.

## 2.7.104 Gen2 native party-record contract

Gen1Recomp's Gen2 `Mon.new` record—not only `mon.species`—is now treated as the native structural authority for a randomized Elm starter. The repair keeps the existing owned table reference and persistent Nuzlocke identity, but refreshes native structural fields from the engine builder while preserving live HP/status/EXP/moves/held item/OT. The 2.7.103 direct Pack→Game2 routing experiment is retired; native Pack→World→Game2 dispatch is restored after Nuzlocke legality checks.

## 2.7.103 Gen2 party-item routing

Crystal runtime evidence showed that species canonicalization at `Game2.usePartyItem` was not sufficient. 2.7.103 instead recognizes Gen1Recomp's native Gen2 party-effect records at the field Pack USE seam and, after Nuzlocke item-policy approval, dispatches them directly to the live game's native `Game2:usePartyItem`. This deliberately bypasses Pack/world field-item classification while preserving native party selection, item effects, item consumption, Rare Candy/evolution handling, and messages. Runtime certification remains required.

## 2.7.102 Gen2 party-item representation compatibility

Gen1Recomp Gen2 party-item effects resolve Pokemon definitions by semantic `mon.species` key. 2.7.102 repairs compatible numeric owned-Pokemon species representations at `Game2.usePartyItem` dispatch rather than relying only on randomized Elm-starter finalization. Native item-effect and inventory ownership are preserved. Runtime certification remains required.

## 2.7.101 / Gen1Recomp 0.2.25

The source/documentation audit advances through 0.2.25. The new read-only `mod.datasets` API can inspect already-imported version registries without switching the active game; Nuzlocke records it for future compatibility/randomizer metadata but does not move protected active-game transactions to it in this build. Gen2 service and Crystal opening-clock gates are hardened around semantic script/map identity. Runtime certification remains required.

## 2.7.95 presentation ownership

Gen-2 tracker MAP ordering is display-only. It does not rewrite area IDs, encounter state, provenance, catch history, provider ownership, or physical map identity. Encounter-registry membership plus concrete tracker evidence determines ordinary MAP visibility; raw host `mapOrder` is no longer treated as a player-facing sort contract.

Battle Menu UI continues to compose only through the public battle presentation seams and does not own action dispatch. The 2.7.95 visual changes only replace the Nuzlocke-owned command panel geometry.

## 2.7.94 Random Starter / Species Pool ownership boundary

Random Starter no longer consumes `random_species_generation`. Its candidate eligibility is owned by starter hard safety, Starter Style, Type Locke, acquisition legality, and exact-edition runtime safety. The shared Species Pool remains authoritative for Random Encounters, Random Trainers, and Random Evolutions only. This restores the exact behavioral boundary present in runtime-PASS 2.7.44 while keeping all later provider/delegation and Randomizer subsystem architecture.

## 2.7.93 battle UI / movement contracts

Battle Menu UI composes through Gen1Recomp's public `battle.bottom_ui_visible` and draw-only `battle.overlay` hooks. It does not replace battle update/input/action code, HP/status HUD rendering, move selection, party/PACK/Bag screens, or special Safari/Contest/tutorial menus. The toggle defaults OFF.

Run / Surf continues to use the shared `movement.speed` hook and preserves the existing monotonic composition rule: Nuzlocke does not stack another 2x acceleration on a downstream provider that has already accelerated the same player-controlled step. The old `automatic_running_shoes` and `fast_surf` save fields are legacy compatibility mirrors; `run_surf` is authoritative after migration.

## 2.7.92 UI palette contract

The Nuzlocke-owned Setup/Rules chrome now has a semantic palette contract: title = emphasized/bold chrome; normal interactive content = black/dark; WIP/delegated = dimmed exceptional state. Selection is expressed by the native cursor glyph, not by changing normal row text color. This applies to R/B/Y and Gold/Silver/Crystal Nuzlocke-owned surfaces only and does not recolor protected native game menus.

## 2.7.91 mandatory-story fail-open boundary

Random Starter is optional transformation work around a mandatory native starter transaction. Errors while materializing a canonical starter slate must not abort the native story grant. For supported canonical starter transactions, the safe fallback is the selected vanilla starter. This boundary composes with the 2.7.90 mandatory-starter provenance/receipt contract rather than replacing it.

## 2.7.90 duplicate acquisition-gate contract

A mandatory starter must have one transaction owner across pre-command, native mutation, and post-receipt layers. Gen-2 POKEPIC -> GIVEPOKE uses a VM scriptKey-scoped marker; native givePoke opens a matching receipt window so pokemon.received cannot reinterpret the same object as a generic gift. New Game setup state must be transferred into the fresh save-backed mod bucket at save.created before any starter hook depends on it.

## 2.7.89 starter ownership compatibility

Starter transaction identity is story/context authority, not a speculative data-shape classifier. Gen-2 Elm Lab GIVEPOKE is mandatory starter flow; R/B/Y `pokemon.before_give` is restricted by first party acquisition plus canonical native opening-starter species. Representation helpers may refine species identity but may not downgrade the mandatory starter into an optional gift.

## 2.7.88 Gen1Recomp Pokemon identity boundary

For Gen 2, the public `pokemon` registry remains semantically string-keyed and each record exposes the cartridge species byte as `index`. Nuzlocke must resolve numeric script identities by `row.index`; physical table-key shape is not semantic identity. Elm's native GIVEPOKE operands are 152/155/158 for Chikorita/Cyndaquil/Totodile and are used only to identify the mandatory Elm Lab transaction when early-load metadata is unavailable. Gold, Silver, and Crystal share this boundary; Crystal remains ALPHA.

## 2.7.87 Gen1Recomp Gen-2 species identity contract

Gen1Recomp's Gen-2 VM supplies numeric species IDs to GIVEPOKE, while the public canonical name ordering is `game.data.gen2Constants.speciesOrder`. Nuzlocke must use that ordering for numeric <-> canonical translation rather than infer identity from the physical key shape of `game.data.pokemon`. This contract applies to Gold, Silver, and Crystal (ALPHA).

## 2.7.86 Gen-2 registry/applicability compatibility

Gen1Recomp Gen-2 species data may be indexed numerically while script transactions carry canonical species strings. Nuzlocke now resolves row aliases before treating an unregistered identity as glitch-shaped. Gold/Silver/Crystal also share the System Date/Time and System Clock Sync configuration applicability contract. Crystal remains independently runtime-certified as ALPHA.

# Nuzlocke Compatibility — 2.7.85

## 2.7.85 Crystal starter presentation compatibility

Crystal's current engine uses an edition-specific animated front-pic path. Runtime testing of 2.7.84 crashed when the first Elm starter ball entered the shared Nuzlocke preview-substitution layer. 2.7.85 therefore does not replace Crystal's native POKEPIC or cry operand. This is a deliberate Alpha fail-open boundary, not a rollback of Crystal support: Crystal remains an explicit manifest target, and the shared Gen-2 GIVEPOKE transaction/tracker path remains installed. Gold/Silver preview substitution is unchanged.



## 2.7.84 Gen1Recomp 0.2.24-era compatibility / Crystal Alpha

Nuzlocke now intentionally targets all six upstream editions: **Red, Blue, Yellow, Gold, Silver, and Crystal**. Crystal is explicitly **ALPHA**. It may use the shared Gen-2 implementation only where the engine exposes the same semantic contract; Crystal-specific story, script-special, progression, Battle Tower, encounter, and presentation differences require their own evidence. Gold PASS or Silver PASS never certifies Crystal.

The aggregate source/documentation audit through the 0.2.24-era line preserves Mod API 2, engine save format 4, and Nuzlocke Save Schema 5. The engine floor intentionally advances to `>=0.2.24 <2.0.0`: under API 2 an older loader that does not recognize the explicit `crystal` game token can reject the manifest instead of safely ignoring that edition. New/expanded upstream surfaces reviewed include Crystal engine support; `mod.developer`; Gen-2 translation improvements; centralized session teardown; Custom Carts; Gen-1 `mod.world:activeBlockAt()`; `map.occupancy_allowed`; and Gen-1 `battle.field_residual`. `activeBlockAt` is a useful future fail-closed map-signature seam but working Nuzlocke map rules are not mass-migrated. `battle.field_residual` is intentionally unused because upstream documents no Gold/Silver/Crystal parity yet.

Two upstream compatibility traps are explicit: `src.ui.OptionRows` has no Gen-2 adapter and must not drive Nuzlocke Gen-2 configuration UI; `src.script.Commands` is a valid R/B/Y dependency but must never be required/used as a Gen-2 command runner. Release Safety protects both boundaries.

### Crystal Alpha runtime policy

- Exact edition id is `crystal`; Nuzlocke-owned Gen-2 screens display `CRYSTAL ALPHA`.
- Crystal has its own runtime-evidence ledger; no Gold/Silver inheritance.
- Shared Gen-2 rules are available when their semantic owner is genuinely common.
- Missing Crystal-specific evidence must fail closed or remain explicitly TEST REQUIRED rather than silently claiming enforcement.
- Crystal-specific progression/static/gift/Battle Tower behavior is a priority certification backlog.


## 2.7.83 configuration compatibility

The direct Difficulty chooser continues to respect external trainer/difficulty providers. Selecting a built-in or VANILLA profile cannot disable another mod's own trainer hooks, so `difficultyStackWarning()` is shown before commit whenever stacking may remain. Manual Gen-2 time writes only through the upstream Clock API and disables Nuzlocke System Clock Sync to avoid competing authorities. Exact manifest targets remain Red, Blue, Yellow, Gold, and Silver; Crystal remains outside this build.


## 2.7.82 Gen1Recomp 0.2.21 runtime hardening

The audited engine target remains Gen1Recomp 0.2.21. The Gen-2 script VM can carry numeric `special` operands, so Nuzlocke now resolves Mom clock/DST specials through the live VM's `specialName()` before ownership decisions. Lifecycle-sensitive Gen-2 installation uses the exact Game supplied by `game.ready`, `save.loaded`, or `save.created`, while the PartyMenu NUZ INFO wrapper gates on its live `self.game`. The explicit manifest set remains Red, Blue, Yellow, Gold, Silver; Crystal is not inferred from upstream generation aliases.


## Gen1Recomp 0.2.21 source audit

2.7.81 source-audits Gen1Recomp 0.2.21. Mod API 2, Save Format 4, and Nuzlocke's `>=0.1.86 <2.0.0` engine envelope remain compatible. Upstream `gen2` now includes Crystal, but Nuzlocke intentionally keeps the exact manifest set Red/Blue/Yellow/Gold/Silver. Gold and Silver remain independent runtime-evidence targets.

0.2.21 also provides `mod.developer`, `isModOptions` propagation, expanded Gen2 ROM-text/translation coverage, stronger session teardown, Custom Carts, and new map/world/link seams. Nuzlocke adopts only the reviewed compatibility metadata and clock/DST integration needed here. `src.ui.OptionRows` remains unsuitable for Gen2 Nuzlocke UI, and `trainer.before_battle` is not assumed to have full Gold/Silver parity. Runtime smoke on 0.2.21 remains required.

## 2.7.80 Gen-2 native clock and Elm timing integration

Gold/Silver continue sharing one Gen-2 implementation while retaining independent runtime evidence. System Date/Time and System Clock Sync write through `src.core.gen2.Clock` rather than creating a parallel Nuzlocke clock. Elm completion tolerates the native GIVEPOKE visibility delay by carrying one exact pending transaction to the next safe world step. Generated/shared ROM script rows remain immutable, and native/non-Nuzlocke UI ownership is unchanged. Compatibility API remains 34.

## 2.7.79 shared Gold/Silver Elm authority

Gold and Silver use the same live Gen-2/Elm/GIVEPOKE starter-transaction contract and the same rendered-preview confirmation authority. The repair does not create Silver-only gameplay ownership or transfer provider authority. Native game UI and the Mod Manager are not restyled. Compatibility API remains 34.


2.7.77 hardens exact Silver reachability without creating a Silver-only implementation: the shared Gen-2 PartyMenu fallback prefers `src.ui.gen2.PartyMenu`, Elm text substitution stays inside Elm's Lab and Random Starter ownership, and Gold remains the shared regression control. No provider-ownership or compatibility API version changes.


## 2.7.78 identity/recovery parity

Gold/Silver now share the existing Recover Catches maintenance surface with R/B/Y. Starter dedupe is based on Nuzlocke Pokemon identity, not species, and does not transfer compatibility/provider ownership. No compatibility API version changes.
## 2.7.76 Gen-2 authority recovery

2.7.76 consolidates Gold/Silver shared runtime authority and keeps exact-edition evidence independent. No compatibility ownership/API version changes.

## 2.7.66 rule-availability audit, pass 2

- Continues the rule-availability audit in a deliberately small pass.
- Yellow no longer exposes Random Starter `Trio Typing` as a native rule because Yellow does not natively use the three-choice starter slate; an explicit compatible `starter_trio` provider can make it available.
- Encounter-slot modifiers now depend on `One Per Area`: Failed Encounters, Dupes, Gen II roamer/egg/contest policies, Town Catches, and area/time/headbutt split controls become dormant while area encounter limits are OFF.
- Type Locke now exposes/effects only the lanes selected by its mode. Catch Draft is hidden while Type Locke is OFF; manual type lanes are hidden/inert during Catch Draft; DUO through HEXA progressively reveal only the required lanes.
- Stored values are preserved while dormant and return when their prerequisite becomes applicable again.
- Release Safety extends the exact-edition/dependency source tripwire for these relationships.


# Nuzlocke Compatibility — 2.7.65

## Exact-edition mechanic availability (2.7.65)

Rule availability is evaluated independently for Red, Blue, Yellow, Gold, and Silver. `rbyOnly`, `gen2Only`, exact `nativeEditions`, and optional `capabilityGate` metadata determine whether a rule is meaningful. Capability gates are presence contracts only: they can expose a rule for a mechanic added by another mod, but they do not transfer Nuzlocke challenge-policy ownership.

The first optional mechanic-presence capability is `overworld_encounters`; other N/A mechanics remain hidden until a real semantic provider contract exists.

## MOD COMPAT ownership preferences (2.7.64)

For capability-backed rows, MOD COMPAT can cycle the Nuzlocke resolver preference with Left/Right through `AUTO`, the native Nuzlocke/Engine path, and installed providers that actually advertise that capability. `AUTO` remains the default. A pinned provider that disappears or becomes inactive falls back to `AUTO`. Fixed Nuzlocke policy and presentation-only rows remain read-only.

This preference controls **Nuzlocke's provider resolver**. It does not disable another mod or guarantee that an external mod will stop independently changing game behavior outside the advertised compatibility contract. Gameplay-impacting preference changes require confirmation before mutation.

## 2.7.58 presentation compatibility audit

The UI architecture includes compatibility hardening for Wide Menus logical-surface changes and Variable-Width Kerning font-metric changes. Nuzlocke-owned screens consume active layout/font metrics without taking ownership of third-party rendering, kerning, native Bag/PC/Party/Pokédex, or battle presentation. Runtime verification is still required.

## 2.7.57 typography/layout compatibility addendum

The UI architecture build does not patch glyph advances or own kerning. Nuzlocke-owned screens consume the active host font metrics, allowing compatible variable-width/kerning and font-replacement providers to remain authoritative. Alternative width providers are consumed only through documented public layout contracts; absence of either provider class must leave Nuzlocke functional. Runtime coexistence remains TEST REQUIRED.

# Nuzlocke Compatibility — 2.7.57

## Experimental UI compatibility boundary

The UI build deliberately modernizes only Nuzlocke-owned surfaces. Native or externally presented Bag, PC, Party, Pokédex, battle, Mart, Trainer Card, and other host surfaces remain outside Nuzlocke presentation ownership. Nuzlocke legality and state must continue to operate on semantic game actions/identities rather than menu rows, displayed labels, visual pockets, or renderer coordinates.

The current compatibility audit track covers alternative Pokédex, PC/storage, Bag/inventory, Party/Summary, Start-menu, broad Gen 1/Gen 2 UI overhaul, translucent/compositor, and battle presentation mods. This build does not claim Runtime PASS with any combination yet. Combination tests must verify both functional enforcement and clean presentation return/stack behavior.

2.7.27 keeps provider ownership semantics unchanged. Provider-added moves remain eligible only when the live move record is usable and not explicitly protected/non-randomizable; type/category weighting is soft and never overrides provider hard safety.
2.7.25 is a release promotion only. Compatibility ownership/composition rules are unchanged from exact 2.7.24.
This file describes **current compatibility ownership and composition rules**. Historical compatibility work belongs in `CHANGELOG.md`.

Explicit game/context arguments are authoritative. A compatibility function may resolve a missing game through the current runtime once, but it must not mix registries from the requested game with ownership/delegation state from another current/global game. Randomizer ownership is provider-agnostic and Nuzlocke relinquishes local projection ownership while an external provider is active.

## Randomizer / transaction coexistence

Learnset coexistence now compares only Nuzlocke-owned move-list fields (`level1Moves`, `learnset`, `levelMoves`). External providers may change unrelated Pokémon stats/types/metadata without accidentally transferring learnset ownership. No provider capability or Compatibility API version changes.

Rare Candy to Cap now uses transaction-specific durable recovery checkpoints and versioned monotonic attempt IDs. These are internal save-safety mechanisms and do not change public compatibility ownership.

## Stadium / Crystal 251 presentation and import compatibility

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
- Latest source-audited release: **0.2.24**
- Declared exact editions: Red, Blue, Yellow, Gold, Silver

The complete 0.2.19 → 0.2.20 upstream delta was reviewed: **6 commits / 26 changed files**. The compatibility-relevant change is stronger in-process session teardown. Returning from a game or embedded Save Editor now unmounts the active cache, unloads generated Data, resets the mod Runtime, Assets loader, and LegacyCompat state, and calls generation-specific `Game:reset()` / `Game2:reset()` cleanup before another launcher session. Upstream also added a regression test for opening a second mod-aware Save Editor session in the same process. This is favorable for Nuzlocke's lifecycle assumptions: stale mod loaders/provider state should be less likely to leak across Edit/Play or game-switch sessions.

Gold/Silver now import a label-keyed `rom_text.lua` table and load it into `Game2.data.text`, allowing shared `RomText` readers to use extracted Gen 2 engine strings rather than Lua fallbacks. The remaining 0.2.20 changes are concentrated in ROM/cache hygiene, palette/tile rendering, trade animation, Magnet Train presentation, Yellow title palette tests, and generated Gold/Silver manifest data. No `src/mods` hook/runtime contract file, Bill's PC wrapper seam, battle-clause seam, or public Mod API contract changed in this delta. Nuzlocke therefore requires **no source migration** for 0.2.20. Mod API 2, Save Schema 4, and the `>=0.1.86 <2.0.0` engine range remain unchanged. Exact-edition 0.2.20 runtime smoke testing is still required.

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

## Rule-feedback language contract

Nuzlocke-owned player-facing feedback should use one consistent voice even when the underlying enforcement seam differs.

- **Mechanical block:** identify the rule first and state the prevented action/effect plainly: `[Rule] blocked/prevented [action or effect].`
- **State explanation:** when an action is unavailable because of run state, say what is unavailable and why: `[Action] is unavailable because [rule/state].`
- **World Building:** flavor may lead, but the actual restriction must remain unambiguous. Higher flavor tiers may add personality; they must not obscure whether the action was allowed, blocked, or redirected.
- **Critical / T0:** keep the message short, direct, and mechanically unmistakable. Flavor must never replace the essential rule result.
- **Configuration descriptions:** explain what the rule does first, then its scope/exceptions, then notable interactions. Avoid requiring the player to infer core behavior from flavor text.
- **Provider/delegated feedback:** a provider may own its own presentation, but Nuzlocke-owned fallback messages should follow this same vocabulary rather than inventing a separate tone for each subsystem.

This is a consistency contract, not a requirement that every historical sentence be rewritten at once. New or materially edited feedback should follow it, and future audits may migrate older outliers when doing so does not alter gameplay flow.

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

## 2.7.56 layout compatibility

Nuzlocke-owned screens now declare an explicit classic, centered, or adaptive layout policy. A public width-provider contract may supply a 304x144 logical surface, but Nuzlocke remains functional without it. Small child flows stay centered; Gen 2 screens remain on native Chrome unless a dedicated wider composition is independently validated.
