## 2.8.03 corrective build

2.8.03 retries the two major Gen II defects still under investigation: party-target item use after selecting a Pokémon, and last-usable-party overworld poison whiteout timing. The item path now intercepts the actual target-selection A press before compatibility callbacks; the poison path pre-arms Nuzlocke wipe state before any synchronous native warp.

The Gen II Randomizer configuration surface is also fully audited: all current Randomizer toggles and dependent sub-options are eligible to appear in Setup/NUZ RULES, and every declarative Randomizer parent has an immediate live refresh trigger. Runtime confirmation is still required for the two Gen II gameplay repairs.

## 2.8.01 hotfix

2.8.01 is a strict child of exact published 2.8.00. It restores the four Trainer Randomizer controls to the Gen II Setup/NUZ RULES surface (`Random Trainers`, `Trainer Balance`, `Trainer Diversity`, `Trainer Theme`) and hardens Gold/Silver/Crystal overworld poison-faint handling so Nuzlocke independently detects a wipe after poison deaths are recorded/pruned instead of trusting `event.whiteout` alone. The known Gen II party-target item-use defect remains unresolved and is not changed by this hotfix.

## 2.8.00 full release

2.8.00 is a strict child of exact 2.7.106 and is packaged as the requested full release. The remaining Crystal party-item defect is attacked at the Pack commit boundary rather than by another Pokémon-structure or Game2 callback patch: simple party consumables now target the authoritative live party slot and execute Gen1Recomp's own Gen2 ItemEffects after Nuzlocke legality checks. Healing/status/revive items, vitamins, and Rare Candy use this path; PP items, stones, TMs/HMs and non-party field items retain their specialized owners. The Setup/NUZ RULES held-scroll curve is also slowed slightly with a gentler five-stage ramp. Profile Save/Load behavior remains protected runtime PASS and World Building still defaults to T3.

## 2.7.106 focused Gen2 consumable execution + progressive navigation

2.7.106 is a strict child of exact 2.7.105. Crystal runtime proved 2.7.105 fixed the incorrect field Pokémon submenu, but healing items, vitamins, and Rare Candy still returned to the Pack without applying. This build repairs the common post-selection execution seam by running Gen1Recomp's native Gen2 `ItemEffects` implementation directly on the selected party Pokémon for simple consumable families, while keeping PP items and evolution stones on their specialized native paths. Rare Candy-to-cap batching remains available; an ordinary no-cap Rare Candy no longer re-enters a closed chooser. Held UP/DOWN navigation now ramps gradually through five speed gates instead of jumping immediately to a fast repeat. The runtime-PASS TOOLS profile behavior and World Building T3 default are unchanged.

## 2.7.105 focused Gen2 chooser + navigation repair

2.7.105 is a strict child of exact 2.7.104. Crystal runtime showed the Gen2 party-item failure is a PartyMenu mode regression: the correct "Use on which Pokémon?" chooser opens, but selecting a Pokémon incorrectly opens the ordinary field Pokémon submenu. This build forces only native Gen2 `useItem` PartyMenu screens back to direct chooser semantics, retires the disproven full-record Steelix mutation, and preserves native ItemEffects/consumption ownership. Nuzlocke Setup and NUZ RULES now support held UP/DOWN auto-repeat; SELECT+UP/DOWN remains the section-jump command. Runtime-PASS TOOLS profile behavior and the World Building T3 default are unchanged.

## 2.7.104 focused Gen2 native-record repair

2.7.104 is a strict child of exact 2.7.103. The 2.7.103 TOOLS profile behavior is protected runtime PASS. Gen2 party-item use is still runtime FAIL on the randomized Crystal Steelix, so this build stops intercepting native Pack routing and instead repairs the randomized starter's concrete party record against Gen1Recomp's own Gen2 `Mon.new` structure. Existing tracked starters are repaired in place before native party-item use; party identity, current HP/status/EXP/moves, held item, OT, and Nuzlocke provenance remain intact. World Building remains default T3.

## 2.7.103 focused corrective build

2.7.103 is a strict child of exact 2.7.102. It replaces the unsuccessful Gen2 item-use hypothesis with direct routing of recognized native party consumables into Gen1Recomp's own `Game2:usePartyItem` owner after Nuzlocke legality checks, restores distinct Profile Slot / Save Profile / Load Profile behavior, and restores the World Building default to T3 across all supported games.

## 2.7.102 focused repair

2.7.102 is a strict child of exact 2.7.101. It broadens the Gen2 party-item species-key repair to the native party-item boundary so ordinary party-target consumables no longer depend on Elm-finalizer timing, and restores the TOOLS profile target as a shared OFF/1/2/3 selector usable from Profile Slot, Save Profile, and Load Profile. Runtime certification is still required.

## 2.7.101 service/tools compatibility update

2.7.101 is a strict child of exact 2.7.95. It repairs Gen2 Center Heal gating, exposes Shop Restrictions on Gen2, adds an in-run TOOLS section with profile save/load and Encounter Assignment, hardens Crystal DST skip, and advances the Gen1Recomp compatibility audit through 0.2.25. The runtime-PASS 2.7.94 Random Starter selection/award logic remains untouched.

# Nuzlocke 2.7.94

## 2.7.95 UI cleanup

2.7.95 is a strict presentation-only child of runtime-tested 2.7.94. It preserves the recovered Random Starter behavior while fixing Gen-2 Encounter Tracker MAP order/filtering, Setup monochrome presentation, MOD COMPAT spacing/navigation, and the optional Battle Menu UI command panel. Crystal remains **ALPHA**; its randomized starter award works, but starter-ball portrait substitution remains deliberately native for crash safety.


## 2.7.94 Random Starter regression repair

2.7.94 is a strict child of 2.7.93. Runtime bisect proved Red Random Starter worked in 2.7.44 and first failed in 2.7.45, when Random Starter was coupled to the shared Species Pool generation filter. 2.7.94 restores the last-known-good starter eligibility contract without reverting later Randomizer work: starters use their own hard-safe live pool plus Starter Style, while Species Pool continues to govern Random Encounters, Random Trainers, and Random Evolutions. R/B/Y Nuzlocke-owned Setup/Rules headers also drop the slash. Runtime retest is required.


## 2.7.93 Battle Menu UI + Run / Surf

2.7.93 adds an optional presentation-only **Battle Menu UI** toggle and consolidates the two movement assists into **Run / Surf** (`OFF / HOLD B / ALWAYS`). Existing saves migrate to the more restrictive historical walking/Surf value when those settings disagree. It also repairs the intended **No Catching → Allow Glitches** suppression metadata. The 21-section taxonomy remains at 151 canonical unique rules. Crystal remains **ALPHA**.


## 2.7.92 Setup / Rules visual polish

2.7.92 is a strict child of 2.7.91. Setup and Rules now use a bold Nuzlocke title with consistent black normal rule/value/pager/help text, while keeping the raised rule rows and bottom-centered pager. Random Starter crash hardening from 2.7.91 is preserved unchanged. Crystal remains **ALPHA**.


## 2.7.91 Random Starter crash hardening

2.7.91 is a strict child of 2.7.90. It preserves the now-working vanilla Silver Elm transaction, prevents optional Random Starter slate faults from crashing that mandatory story grant, hardens an empty fallback-pool edge, and moves the Setup/Rules pager to the bottom-center while moving rule rows upward. Crystal remains **ALPHA**.


## 2.7.90 starter provenance repair

2.7.90 makes the Elm starter a single mandatory transaction across every Nuzlocke acquisition gate and persists New Game Random Starter intent into the fresh save before any starter grant. Crystal remains **ALPHA**; its remaining Mom DST prompt is still deferred.


## 2.7.89 starter transaction recovery

2.7.89 restores the recent runtime-proven R/B/Y and Gen-2 starter transaction ownership while preserving all later 2.7.88 work. Crystal remains **ALPHA**. The redundant edition / NEW RUN subtitle has also been removed from Nuzlocke Setup/Rules screens.


## 2.7.88 runtime repair

2.7.88 is a strict child of 2.7.87. It repairs the remaining Gold/Silver/Crystal numeric species legality boundary using the Gen1Recomp Pokemon registry's public `index` field, hardens both Gen-2 and R/B/Y Random Starter transaction ownership, shows minutes on the Manual Time rules row, and restores actual NZR6 code generation on the first DEV REPORT page. Crystal remains **ALPHA**.


## 2.7.87 runtime repair

2.7.87 is a strict child of 2.7.86. It repairs the shared Gold/Silver/Crystal Elm species identity bridge using Gen1Recomp's canonical Gen-2 `speciesOrder`, applies the same bridge to Random Starter grants, adds minute editing to Manual Time, completes Crystal's initial Mom DST skip, and restores the long DEV REPORT code as the first View Report page. Crystal support remains **ALPHA**.


## 2.7.86 runtime repair

Strict child of exact 2.7.85 (`fb8eb72e1f9292a99e047b697170b2b17b99dd0f6a241773e999ad67e4271a72`).

- Fixes the shared Gold/Silver/Crystal species resolver so canonical string species such as CYNDAQUIL/TOTODILE/CHIKORITA can resolve against Gen-2 registries keyed by numeric id or row metadata before glitch legality is evaluated. This prevents ordinary Elm starters from being rejected as malformed/glitch acquisitions.
- Restores `System Date/Time` and `System Clock Sync` to the maintained shared Gen-2 applicability allowlist, so the setup-only System Date/Time control can actually appear on Gold/Silver/Crystal configuration surfaces.
- Crystal remains ALPHA and keeps the 2.7.85 native POKEPIC/cry fail-open boundary.
- No rule defaults, save schema, Compatibility API, Randomizer algorithm, or package inventory changes.
- Runtime retest required on Silver and Crystal starter grants, Crystal setup clock bypass, and Red field-poison install health.



## 2.7.86 Crystal starter crash + DEV REPORT validation repair

2.7.86 is a strict child of exact 2.7.84. Crystal runtime evidence from 2.7.84 proved boot, bedroom/world traversal, and Elm Lab access, then reproduced a process crash on the first Elm starter-ball interaction. Until Crystal's animated front-pic callback is independently certified for Nuzlocke substitution, Crystal now fails the POKEPIC/cry presentation layer open to the native engine path while preserving the shared Gen-2 GIVEPOKE transaction and all Crystal Alpha targeting. The same child repairs stale player-facing stored-state Randomizer diagnostics by validating stream/source-map/projection counts against live exported registries instead of historical literals; external compatibility snapshots are treated as extensible rather than frozen at four mechanics.


## 2.7.84 Gen1Recomp 0.2.24-era compatibility + Crystal Alpha

2.7.84 is a strict child of exact 2.7.83. It advances the source/documentation compatibility profile through the Gen1Recomp 0.2.24-era line and intentionally adds **Pokémon Crystal as an ALPHA Nuzlocke target**. The manifest now names Red, Blue, Yellow, Gold, Silver, and Crystal explicitly. Crystal reuses the shared Gen-2 implementation where the engine exposes the same contract, while exact Crystal identity and runtime evidence remain independent from Gold/Silver. Nuzlocke-owned Gen-2 screens display **CRYSTAL ALPHA** so the support stage is visible in-game.

The compatibility audit records upstream Crystal support, `mod.developer`, expanded Gen-2 translation/session lifecycle work, Custom Carts, the Gen-1 `activeBlockAt` / `map.occupancy_allowed` map seams, and `battle.field_residual`. Nuzlocke does not adopt Gen-1-only field residual behavior and does not migrate working map rules wholesale. Release Safety protects the six-edition manifest, Crystal Alpha declaration, the Gen-2 `src.ui.OptionRows` trap, and the requirement that `src.script.Commands` remain Gen-1-only. Save Schema 5, Compatibility API 34, Diagnostics API 1, and rule defaults are unchanged. Because API-2 manifests reject unknown game tokens, the engine floor is intentionally raised to `>=0.2.24 <2.0.0` when Crystal becomes an explicit target. Crystal runtime certification is required before any Crystal feature is promoted beyond Alpha.


## 2.7.83 planned Rules / Setup UI pass

2.7.83 is a strict child of exact 2.7.82 and implements the deferred configuration batch recorded in that handoff. The compact current/total rule counter now lives at the top-right of the toggleable Rules area. Nuzlocke Loadout opens a direct chooser for VANILLA, RECOMMENDED, NUZLOCKE, HARDCORE, SOLO, IRONMON, and CUSTOM instead of forcing sequential stepping; selecting a named loadout still previews and confirms its exact owned-rule changes before mutation. Game Difficulty now opens a direct profile selector showing concrete ordinary-trainer/boss effects and preserves provider-stacking warnings before commit. Gold/Silver in-run Rules adds Manual Time, which writes through the native Gen-2 Clock and disables System Clock Sync when applied. Starting Poke Ball Setup wording now explicitly says delivery is deferred until capture unlock, unlike immediate PC Candy/heal/vitamin loadouts. No Crystal support or encounter-overlay redesign is included. Runtime UI validation remains required.


## 2.7.82 Silver / Gen-2 runtime hardening

2.7.82 is a strict child of exact 2.7.81. It keeps the 0.2.21 compatibility profile, Mod API 2, Save Schema 5, engine range `>=0.1.86 <2.0.0`, and exact Red/Blue/Yellow/Gold/Silver target set. This build repairs the Silver runtime failures observed on 2.7.81: System Date/Time now owns Mom's complete DST ladder, Elm confirmation gains a final one-shot native raw-text fallback, a committed native Elm story event can finish starter Tracker provenance under a narrow zero-badge/one-party-mon proof, Gen-2 NUZ INFO installation uses the exact lifecycle Game, and DEV REPORT no longer treats package/document Release Safety or opaque report codes as player runtime health. Crystal remains unsupported.


## 2.7.81 compatibility update

2.7.81 is a strict child of 2.7.80 and source-audits Gen1Recomp 0.2.21. It keeps Mod API 2, Save Schema 5, engine range `>=0.1.86 <2.0.0`, and the exact supported editions Red, Blue, Yellow, Gold, and Silver. Crystal is now part of upstream `gen2`, but is not a Nuzlocke target. Gold/Silver System Date/Time now covers both native initial DST branches and clears the cartridge DST bit while host-local time owns the clock. Runtime validation remains required.
## 2.7.80 — Gen-2 starter completion, system clock QoL, and candy cancellation

- Strict child of exact packaged 2.7.79.
- Gold/Silver randomized Elm starters can now finish their exact pending GIVEPOKE transaction on the next safe world step when native party mutation is not visible immediately.
- The rendered randomized starter preview also has a deeper one-shot native text fallback, keeping Elm's confirmation on the same species and primary type without mutating generated story rows.
- Proven legacy New Bark starters can reconcile Tracker/native Elm state under the narrow old-save proof contract; species equality is still not general identity evidence.
- New Gen-2 setup-only `System Date/Time` initializes the native clock/weekday from platform local time and bypasses manual opening clock setup where supported.
- New Gen-2 QoL `System Clock Sync` re-anchors the native clock when the platform minute changes and stops doing so when disabled.
- Multi-candy `TO CAP` batches now accept B as a stop request; the current candy fully completes before the batch stops, preserving remaining candies and native level-up/move/evolution flow.
- Runtime validation remains required independently on Gold, Silver, and representative R/B/Y Rare Candy paths.

## 2.7.79 — Gen-2 Elm starter authority and utility titles

- Strict child of exact packaged 2.7.78.
- Gold/Silver now classify Elm's starter transaction from live Gen-2 + Elm Lab + a canonical Elm starter GIVEPOKE operand instead of party size.
- A concrete Pokémon already proven as the New Bark starter can reconcile Elm's native starter story flags without guessing starter identity.
- The actually rendered randomized starter preview can own the immediately following Elm confirmation species/type when text identifiers differ between Gold and Silver.
- The legacy species fallback remains repair-only: exactly one proven live starter plus exactly one identity-less/fingerprint-less LEGACY row of that species. Fresh registration never uses it.
- Nuzlocke-owned Gen-2 utility pages use a shared centered/pseudo-bold primary-title hierarchy while native game UI remains untouched.
- Runtime validation remains required, especially the legacy Gold starter save and fresh Silver randomized starter flow.

## 2.7.78 — Starter identity and Recover Catches parity

- Strict child of exact packaged 2.7.77.
- Recovers only the reviewed mistaken 2.6.77 -> 2.6.78 delta.
- Starter registration is identity-idempotent: one persistent Pokemon identity owns one active starter encounter row; fingerprint is fallback only for old rows without IDs, never species.
- Starter history is normalized by exact Pokemon ID and existing-save repair reuses the same transaction for proven hometown starter/gift Pokemon.
- The older Gen-2 Pallet -> New Bark migration now requires exact ID or stored fingerprint evidence instead of species matching.
- Recover Catches is available on Gold and Silver as well as R/B/Y. Manual recovery preserves a saved `pokemonId` even when no live Pokemon object is attached.
- Runtime validation remains required, with the reported Gold duplicate-starter save as the priority case.

## 2.7.77 — Silver starter/randomizer usability recovery

- Strict child of exact packaged 2.7.76.
- Recovers only the reviewed mistaken 2.6.76 -> 2.6.77 delta.
- Silver/Gen-2 NUZ INFO fallback now targets `src.ui.gen2.PartyMenu` directly before the compatibility facade.
- Randomized Elm starter confirmation text follows the randomized species/type; native yes/no, flags, movement, and GIVEPOKE remain host-owned.
- GIVEPOKE starter registration can recover the newly granted Pokémon when the native callback mutates ownership but returns nil.
- Gen-2 Tracker MAP suppresses ordinary interiors unless actual encounter/log/catch state exists.
- Reroll Seed is available during a run and Auto Seed returns the configured seed to AUTO; live changes rebuild active Nuzlocke-owned randomizer projections.
- Runtime validation remains required on Silver first, then Gold and R/B/Y regression controls.

## 2.7.76 — Gen-2 starter/tracker authority recovery

- Strict child of exact packaged 2.7.75.
- Recovers only the reviewed mistaken 2.6.75 -> 2.6.76 Gen-2 authority/Silver-parity delta.
- Starter provenance is now edition-correct: R/B/Y use Pallet Town; Gold/Silver use New Bark Town.
- Gold/Silver Tracker MAP no longer exposes the authored Gen-1 seed catalog without real runtime evidence.
- Shared Gen-2 script adapters use the live family predicate instead of also requiring `ctx.generation == 2`.
- Adds the reviewed Gen-2 PartyMenu NUZ INFO safety net and runtime reachability counters.
- No later 2.6.77 random-starter dialogue, seed controls, interior filtering, or direct Gen-2 PartyMenu targeting is included.

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

Reconstruction child of exact 2.7.72. Late Runtime now receives live resolver thunks for rule-message helpers that may be published after the dependency bundle is staged, preventing registration-time nil snapshots on editions where the owning R/B/Y installer is not applicable. No rule semantics, defaults, Randomizer mappings, save schema, or compatibility API changed.

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

# Nuzlocke 2.7.65

> **Lineage:** **2.7.65** is a strict child of exact **2.7.64** (`08502eca2f12802b816d8cd4b4e9358ba08ea25f5411200534f4da42bf7dda40`).


**Promoted UI geometry-hardening build in the canonical forward lineage.** TEST.7 is a strict child of 2.7.60. This pass repairs runtime-observed layout collisions, fixes a Randomizer diagnostics crash, and hardens compatibility with Gen1Recomp's documented UI/widget contracts. No new gameplay rule semantics are introduced.


## 2.7.64

MOD COMPAT can now cycle ownership for capability-backed rows. `AUTO` remains the default; eligible rows can be pinned to the native Nuzlocke/Engine owner or to an installed provider that actually advertises that capability. Gameplay-impacting ownership changes are confirmed before mutation, unavailable pinned providers fall back to AUTO, and read-only/fixed-policy rows cannot be falsely reassigned.

## 2.7.63

- Gold/Silver Encounter Tracker MAP now uses the active Gen II map catalog/order instead of the seeded Gen I Kanto route list.
- New Bark Town is treated as the Gen II starter hometown, and existing town encounter evidence remains visible if Town Catches is later disabled.
- Difficulty changes that alter trainer semantics now show a loadout-style confirmation before mutation.


## UI compatibility hardening

- Custom Nuzlocke screens now reserve explicit header, body, optional detail, and footer regions instead of allowing independently positioned content to collide.
- Ordinary label/value rows use active font metrics and measured right alignment.
- Tracker, Rules/Setup, Dev Tools, status rows, and loadout confirmation received focused geometry repairs from Yellow/Gold runtime evidence.
- Native/external Bag, PC, Party, Pokédex, battle, Mod Manager, and other host-owned presentation remains outside Nuzlocke ownership.
- Existing compatibility adapters remain optional; no UI compatibility mod is required.


**Promoted UI build in the canonical forward lineage.** TEST.6 is a strict child of 2.7.59 and adds pre-test startup hardening only. Presentation/source audit drift is diagnostic and promotion-blocking rather than a startup brick; gameplay-critical invariants still fail closed.

# Nuzlocke 2.7.59

## Startup recovery delta

This UI build is a strict child of exact 2.7.58. It repairs the runtime-blocking stale World Building catalog golden (`926265119` -> live semantic checksum `513036232`) and changes that presentation-only startup audit from fatal to diagnostic/Release-Safety enforcement. No World Building dialogue, gameplay rule, save, Randomizer, or encounter semantics are changed. Canonical 2.7.54 was the original fallback during development.

# Nuzlocke 2.7.58

## 2.7.58 controlled-pass delta

- Shared semantic rows and notices now have Gen I and Gen II render paths.
- F. TOKEN selection/revive/reroll notices and Dev Tools action rows use the shared primitives without changing rule or diagnostic authority.
- Variable-width font compatibility is handled by live authoritative font metrics; the build does not install its own kerning tables/hooks.
- Wide-menu surface policy remains isolated behind the Nuzlocke layout-context adapter.
- DEV REPORT internals and Randomizer presentation remain intentionally unmigrated pending runtime review.


## 2.7.57 build scope

- Replaces Nuzlocke-owned Gen 1 kerning overrides with provider-neutral live font metrics; compatible typography mods remain authoritative.
- Adds shared measured typography primitives for fit, wrap, right-aligned values, and row rendering.
- Adds semantic focus/status row primitives and a standardized notice model/render fixture.
- Expands the Dev UI Gallery to five pages with variable-width typography and notice/wrapping stress cases.
- Corrects forward-lineage executable provenance so the immediate parent is exact 2.7.56; canonical 2.7.54 was the fallback/root during development only.

This build adds a Nuzlocke-owned logical-surface contract, responsive Gen 1 Rules/Setup and Encounter Tracker presentation, centered child-flow policy, and a read-only Dev UI Gallery. Gold/Silver keep native Gen 2 Chrome where a separate wide path is not yet validated. The build does not change gameplay authority or replace native/external Bag, PC, Party, Pokédex, battle, Mart, or Trainer Card presentation.

2.7.65 is the canonical forward head. Exact-edition runtime evidence remains tracked independently.

Forward-lineage UI build from exact canonical 2.7.54. This build begins the Nuzlocke-owned UI architecture overhaul with a shared semantic presentation system for Setup/NUZ RULES and ENC TRACKER across Red, Blue, Yellow, Gold, and Silver. Gameplay rules, Randomizer seeded contracts, save schema, and native Bag/PC/Party/Pokédex/battle ownership are unchanged. This build is part of the promoted canonical forward lineage.

Compatibility work in this build is presentation-boundary hardening: Nuzlocke-owned screens are being separated from gameplay authority so alternative Start/menu, storage, inventory, party, Pokédex, battle, and compositor UIs can coexist without becoming rule-enforcement dependencies. Runtime coexistence remains TEST REQUIRED.

Current development build. Adds external-save reconciliation regression coverage and forward-local-reference Release Safety linting. Randomizer Phase J certification/stabilization remains complete through #11; final exact-edition runtime certification (#12) remains deferred.

<!-- 2.7.51: Phase J #7-9 non-runtime certification -->
## 2.7.50 Randomizer certification — Phase J #1–3

Phase J #1–3 adds read-only static determinism, save/reload persistence, and cross-edition determinism audits. It also resolves the deferred Silver Random Field Item ALLOW namespace debt: Gold keeps its historical `gold:<map>:obj:<id>` seeded slot, while fresh Silver ALLOW placements use `silver:<map>:obj:<id>`. Existing persisted mappings remain authoritative and are not rerolled. Exact-edition runtime certification remains deferred.


Phase I is implemented through #12. Existing randomized source mappings are not silently rewritten by mid-run setting edits; new sources use the current settings, while the immutable run-start snapshot records drift. Read-only reproducibility and whole-Randomizer audit surfaces are available for certification work.

**Current development build: 2.7.47** — Phase I #7–9 integration hardening.

# Nuzlocke 2.7.46 — Randomizer Phase I #4–6

Strict child of exact 2.7.45 (`9cfc18508b24cafce9bc3205b5c47784873c199ac8bb5f34d17db776eb10dfe9`). Continues Randomizer Integration & Presets with a read-only cross-randomizer compatibility matrix/audit, an eight-digit seed share/import presentation contract, and deterministic subsystem version reporting. These additions consume no RNG and do not rename existing streams or rewrite persisted mappings. Phase I #7–12 remain.

# Nuzlocke 2.7.45 — Randomizer Phase I #1–3

Strict child of exact 2.7.44 (`c435d2f4247bb4a9d4a72a44695121f657f0aa9fb84dcd74864b4dfadbeff254`). Begins Randomizer Integration & Presets. Adds a unified CUSTOM/CHAOS/BALANCED Randomizer preset layer, a read-only subsystem ownership registry that preserves external-provider delegation, and shared Species Pool semantics for Starter/Encounter/Trainer/Evolution randomizers. Presets are deterministic convenience configuration only: they do not change the shared seed or existing RNG stream names/versions, and manual child edits return the preset to CUSTOM. Phase I #4–12 remain.

# Nuzlocke 2.7.44

Randomizer Phase H #1–12 is implemented. Phase H #10–12 hardens Gold/Silver Pack/item-PC ownership, extends Randomizer Info to Shops/TMs/Gift Items, and adds the economy/progression regression audit. Runtime exact-edition certification remains required.

# Nuzlocke 2.7.43

## Randomizer Phase H #4–6

Random TMs deterministically replaces TM contents while preserving TM item identity and every HM. TM Compatibility supports MOVE (native compatibility follows the randomized move), SLOT (authored TM-slot eligibility is projected onto the randomized move), and FULL. Random Gift Items covers ordinary scripted GIVEITEM grants through a separate deterministic stream while preserving native quantity, capacity, flags, and transaction ownership; key/progression items, HMs, TMs, and provider-protected items stay authored. Dedicated NPC reward-item surfaces are included when exposed by the active game/provider.

2.7.43 is a strict development child of exact 2.7.42. Phase H #1–9 are implemented; #10–12 remain later work.

See `RELEASE_NOTES.md`, `CHANGELOG.md`, and `docs/USER_GUIDE.md` for current behavior and confidence status.

### Rule availability

Nuzlocke filters configuration by the exact active edition and live compatibility capabilities. A rule whose mechanic does not exist in that game is not shown and is behaviorally inert; compatible providers can opt a declared mechanic into availability. Dependent or superseded child rules retain their saved preference but are hidden and inactive until meaningful again.
