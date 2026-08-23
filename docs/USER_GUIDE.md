# Nuzlocke User Guide — 2.7.25

2.7.25 is a release promotion only. Player-facing rule behavior is unchanged from exact 2.7.24.
This guide describes **what the mod does now**. Historical changes belong in `CHANGELOG.md`.

World Building remains independent of the Nuzlocke master switch as a presentation feature. Encounter/Learnset Randomizer subsystems use explicit disabled/delegated/applied lifecycle states, and Randomizer information policy is shown whenever Nuzlocke owns at least one supported Randomizer surface, including learnset-only runs.

## Getting started

Use **NUZLOCKE SETUP** before a new game to choose a preset or configure rules individually. The in-game **NUZ RULES** screen edits the active save. Ordinary toggles use Left/Right and/or A; numeric/resource selectors use the dedicated numeric editing behavior.

Presets are shortcuts over the same rule catalog. They do not create a separate rules engine. Changing a preset can update only the rules owned by that preset; unrelated clauses, presentation settings, and starting resources remain independent.

## Rule menu organization

The current catalog is organized as: **CORE, CLAUSES, HARDCORE, GAME DIFFICULTY, BATTLE MECHANICS, RUN / PARTY, LEVELS, CATCH RULES, BATTLE CLAUSES, STATUS BANS, VARIANTS, BATTLE ITEMS, FIELD ITEMS, SERVICES & ECONOMY, POKEMON STATS, AREA SPLITS, RANDOMIZER, WORLD, QOL, QOL SETUP ONLY, UI**. This organization does not change rule keys or enforcement. The IRONMON preset keeps its existing name. Dev Mode is under UI. Save Rules and encounter recovery/assignment are maintenance actions outside the ordinary rule-category list.

## Core Nuzlocke rules

### Nuzlocke Enabled
Master switch for Nuzlocke enforcement. Turning it off should stop Nuzlocke mutations/enforcement without destroying existing Nuzlocke history.

### Permadeath
A Pokémon recorded as dead remains dead. External healing or scripted callbacks must not resurrect a `nuzlockeDead` Pokémon; battle-entry reconciliation reasserts HP 0 when needed.

### One Per Area / Failed Encounters
One Per Area limits legal catches by encounter area. Failed Encounters can consume the area's opportunity when the first eligible encounter is defeated, escaped from, or otherwise missed. Area splits can deliberately divide selected routes/dungeons into separate encounter slots.

### Nickname Rule
Supported acquisition paths require a non-default nickname. The rule is independent of player/rival automatic naming options.

### Dupes / Shiny
Dupes can be OFF, exact-species, or evolution-family based. Shiny Clause is a numeric exception policy rather than an ordinary boolean toggle; explicit stored values are preserved.

### First Rival Mercy
Applies only to the intended first Rival battle and is consumed when that battle begins. Later Rival battles are not exempt.

## Encounter and acquisition rules

### Gifts, trades, statics and scripted acquisitions
Nuzlocke distinguishes acquisition source kinds instead of assuming everything is a normal wild catch. Gifts/trades, fixed statics, provider-owned captures, theft-style captures, and progression-required catches can therefore receive different area/source policies while still sharing species legality where appropriate.

### No Catching
Blocks real capture attempts. Progression-required PC Catch exceptions are allowed only when a cooperative source explicitly declares both progression requirement and exception permission, and real Box storage has room.

### PC Catches
When enabled, a qualifying mandatory progression catch may be accepted only into real PC storage. Party room does not substitute for Box space. Full Box storage fails closed.

### Encounter Ball Limit
Restricts the number of legal Ball throws during an eligible encounter. OFF preserves normal unlimited throws.

### Encounter Tracker / Area Guide
Shows encounter state and catch results by area. Catch Info records provenance where available. Route/Mt. Moon/Safari split settings update the canonical area interpretation used by tracking and legality.

## Pokémon restrictions

### Type Locke
Supports Mono through Hexa type configurations plus the existing random/draft-oriented selectors. Catch legality is based on the current species metadata/provider view, not a hard-coded assumption that only native Gen1/Gen2 species exist.

### Maximum BST
Rejects acquisitions above the configured maximum BST when reliable metadata is available. Provider/merged species metadata is preferred for expanded species.

### Species bans
Legendary, Mythical, Pseudo-Legendary, glitch, and explicit PKMN BAN policies use the current species facts/metadata contract. Unknown provider metadata is treated conservatively on authoritative legality paths.

## Level caps and difficulty

Level caps follow the selected scope and may consume live trainer/provider information where compatible mods change boss teams. When another compatible cap system is also active, dedicated adapters may use the stricter live cap without rewriting the other mod's state.

EXP that would exceed an authoritative Nuzlocke cap is trimmed/blocked at the final Nuzlocke clamp. A blocked award remains zero even when downstream mods multiply EXP.

Difficulty options are separate from Smart-AI/content ownership in other mods. Nuzlocke should not silently replace an external trainer/AI system merely because a numeric difficulty rule is enabled.

## Party, battle and move rules

### Party Size / Gym Team Size
Party Size limits usable player-party admission/withdrawal paths. Provider-owned acquisitions such as theft/owned captures deliberately participate in party admission policy. Gym Team Size may follow the final composed trainer team where provider data is available.

### Physical / Special Split
When enabled, explicit live/provider move categories outrank Nuzlocke fallback knowledge. External expanded moves that already declare a correct category are not overwritten.

### Battle clauses
Sleep/OHKO/Evasion and related clause logic uses source/target semantics rather than move-name guessing. Reactive self/foe effects are distinguished so the opponent's reaction is not attributed to the attacker incorrectly.

### Healing / items / escape
Rules exist for battle healing, X items, PP items, TMs, Rare Candy, field healing, Centers, Mom healing, Repels, Escape Rope, buying/selling, and other challenge surfaces. Each rule should block only the action it owns and preserve unrelated vanilla recovery/progression behavior.

### No Held Items
Native Gold/Silver held-item behavior is supported. On R/B/Y the rule appears only when a compatible external held-item capability exists. Compatible Gen1 providers can have GIVE removed while TAKE remains available; existing player-held values can be suppressed during battle and restored afterward rather than deleted.

## Day Care / breeding

No Day Care blocks **new deposits**, not withdrawal/recovery of already deposited Pokémon. Vanilla R/B/Y, native Gen2, and compatible replacement Day Care paths use separate engine/provider seams so a content mod cannot bypass the rule merely by replacing the original talk script.

## World restrictions

Gym Lock-In and Dungeon Lock-In prevent backing out after entry until the run reaches a legitimate alternate exit/release condition. Lock logic is topology/content aware and should fail open when map ownership is genuinely uncertain rather than trapping the player permanently.

World Building tiers affect presentation/dialogue only; they do not change rule enforcement.

## Randomizer

Random Starter, Random Encounters, Random Field Items, and Random Learnsets use deterministic named randomizer streams where Nuzlocke owns the transformation. The global randomizer algorithm remains version 1; starter slates carry their own independent namespace version so starter-only improvements do not reshuffle encounter, field-item, or learnset results.

Random Starter currently exposes:

- **Starter Style** — `ANY`, `3-STAGE`, `BASE`, or `SIM BST`.
- **Starter Balance** — `INDEPENDENT` (default) or `BALANCED`. BALANCED prefers three-choice slates whose current strength plus evolutionary potential are reasonably comparable. It is a soft preference only.
- **Trio Typing** — `OFF` (default) or `AUTO`. AUTO prefers a three-way offensive type cycle across the three native Red/Blue or Gold/Silver starter positions and evaluates both types on dual-type species. Yellow's two-position Pikachu/Eevee starter/rival transaction does not apply this three-way preference.
- **Starter Rerolls** — `OFF` (default) or `ON`. When ON, a separate **Reroll Starter** action is available only before starter acceptance. It keeps the run seed fixed and advances only an isolated starter reroll index. Once the starter is accepted, rerolls are permanently closed for that save.

Hard starter legality always outranks Starter Style/Balance/Typing preferences. Active species bans, Type Locke, glitch safety, runtime construction safety, and acquisition restrictions are never relaxed. Multi-choice starter slates remain distinct whenever a complete legal distinct assignment exists. If a requested balance/type relationship cannot be produced, the preference relaxes to the normal legal distinct slate rather than blocking story progression.

The starter transaction is persisted by exact edition/position identity. Red/Blue store the three Oak positions; Gold/Silver store the three Elm positions; Yellow stores the Pikachu player position and Eevee rival position together. Canonical rival starter-family members derive from that same persisted slate rather than receiving an independent random roll.

**Randomizer Info** now also governs starter information. OPEN INFO can reveal the persisted starter slate to compatible information tools. BLIND INFO hides randomized starter species while still allowing read-only seed, algorithm/slate version, Starter Style/Balance/Typing, candidate-count, reroll-index and fallback diagnostics. Merely viewing this information consumes zero RNG and does not alter the run.

Yellow has one additional compatibility rule: if Random Starter replaces the opening Pikachu, the normal post-lab Pikachu-only follower/cry/text presentation is suppressed and the otherwise-orphaned Pikachu happiness field is raised only to the native Cerulean Bulbasaur gift threshold. This preserves that gift's progression availability without changing normal Pikachu runs.

Random Encounters use the same hard-safety/soft-preference architecture. `CHAOS` selects from the full hard-safe species pool. `SIM BST` tries the historical ~15% BST band, then ~25% and ~40%. `EVO` first prefers the same broad stage with similar family depth/remaining evolutions, then stage, then progression-adjusted strength. `BALANCED` combines progression shape with BST before relaxing through stage/progression and wider BST bands. Progression-aware strength uses the slot's native level, current BST, and a bounded contribution from reachable evolutionary ceiling; it never changes encounter levels or rates.

**Encounter Repeats** controls repetition within each encounter source group: `ALLOW` preserves independent slot rolls; `DIVERSE` softly lowers the weight of already-used species while keeping every legal species reachable; `UNIQUE` uses without-replacement selection until the group's legal pool is exhausted, then explicitly falls back. **Diversity Strength** appears only for DIVERSE: `LIGHT` uses 0.70-per-use weighting, `STANDARD` uses the 2.6.83/default 0.45 factor, and `STRONG` uses 0.25. No DIVERSE strength makes a legal candidate unreachable.

Encounter-table semantics are normalized explicitly. Land/grass, cave, Surf/water, fishing/rod, Headbutt/tree, Bug Contest, roamer, and provider-defined/other classes are tracked separately, and Gen 2 morning/day/night tables normalize to `MORN`, `DAY`, and `NITE`. Repeat grouping uses map + normalized class + time bucket + table id + structural parent path, so distinct methods/time blocks do not accidentally share repetition state.

Ordinary wild-table randomization also has a local protection gate before provider composition or candidate selection. Explicit non-randomizable, static, fixed, story, progression, quest, gift, trainer, roamer/roaming, or protected-policy records are preserved exactly rather than randomized as wild slots.

Each encounter source retains its canonical map/source/method/table/slot/path identity for persistence, while the historical Randomizer v1 encounter slot remains the RNG hash identity. The complete encounter source plan is sorted before replacements are generated, so map visit or table insertion order cannot determine results. `CHAOS + ALLOW` preserves the 2.6.82 mapping path; strengthened balance modes and active repetition policies use the encounter-only `ep2` namespace. `STANDARD` DIVERSE preserves 2.6.83's existing DIVERSE namespace; LIGHT/STRONG add only their diversity-strength suffix.


Area Splits do **not** become Random Encounter source keys. Route 2/10/20, Mt. Moon, Safari Zone, Gold Time Split, and Gold Headbutt Split change logical catch/tracker projection only. Changing one reprojects the encounter log/tracker view without deliberately rerolling or remapping the physical randomized wild table.

Randomizer Info exposes an encounter diagnostic view as well as the starter view. OPEN INFO may include live randomized species per encounter source. BLIND INFO removes species but still reports algorithm/policy version, seed, balance/repetition/diversity modes, normalized encounter class/time/group, canonical source identity, candidate counts, protected-source reasons, mapping counts, active split state, and fallback diagnostics. Information reads do not consume RNG or rewrite mappings.

Visible Field Items now use the same hard-safety candidate foundation. A permanent pickup identity is based on exact edition plus the existing map/object semantic source slot; the authored item is not part of that persistence key. Randomizer v1 still hashes the historical `<source slot>:<original item>` input so the identity migration itself does not intentionally reshuffle existing seeds.

Field-item safety is fail-closed. Explicit key-item flags/pockets, HMs, progression/story/quest/required metadata, provider opt-out/preservation policy, badges, missing definitions, and placeholder/unused records are protected. A protected authored pickup remains unchanged and protected items never enter the replacement pool.

Ordinary hard-safe items are now classified into semantic categories: BALL, HEAL, STATUS, REPEL, ESCAPE, BATTLE, PP, GROWTH, EVOLUTION, MACHINE, and GENERAL. **Field Item Balance** controls soft preference: `CHAOS` keeps the full hard-safe pool; `CATEGORY` prefers the original pickup's category; `BALANCED` prefers category + utility tier, then category, then utility tier. Providers/sources may additionally declare allowed or forbidden categories; those are hard constraints and cannot be relaxed by balance fallback.


**Field Item Repeats** controls duplicate pressure across physical visible pickup sources. `ALLOW` preserves independent rolls. `DIVERSE` usually follows a deterministic source-placement lane but periodically uses the independent lane, reducing repeat pressure without forbidding candidates. `UNIQUE` maps native numeric source/object ordinals into a seeded permutation of the shared semantic pool; distinct ordinals remain distinct until the pool wraps/exhausts. Provider sources with only nonnumeric ids degrade deterministically and are reported rather than silently claiming strict uniqueness.

Visible-vs-hidden ownership is explicit. Native item-ball adapters identify themselves as `VISIBLE`. Explicit `HIDDEN` / BG-event sources are not owned and remain unchanged. For backward compatibility, a legacy call that omits source-kind context is treated as the historical visible-item path. Hidden items, gifts, shops, fruit/apricorn trees, and scripted rewards remain outside this rule.


Field Item data also has an explicit generation model without creating a second registry. R/B/Y is treated as `GEN1_FLAT`: ball capability and TM/HM record/id semantics are normalized from the flat item table. Gold/Silver is treated as `GEN2_POCKETS`: BALL, KEY ITEM, and TM/HM pocket semantics are normalized explicitly. Both still use the engine's merged `game.data.items`.

Randomizer Info now covers visible Field Items. OPEN INFO may show persisted randomized item choices. BLIND INFO hides the randomized item/category/table class while still reporting exact edition/table model, Field Item modes, visible/hidden ownership, total/hard-safe/protected counts, category counts, persisted/legacy mapping counts, source keys, and fallback diagnostics. Reading this information consumes no RNG and does not rewrite mappings.



### External randomizer coexistence

Nuzlocke does not disable its randomizers merely because another randomizer mod is installed. Duplicate controls yield only to an active, source-confirmed owner or an explicit provider capability.

The current named ownership adapters cover PokemonRecompRandomizer, Gen 2 Randomizer+, Kanto Reforged encounter randomization, and Item Randomizer visible pickups. For Item Randomizer, only R/B/Y `overworld_items` or Gold/Silver `gold_ball_items` overlaps Nuzlocke's visible Field Item randomizer. Its hidden/shop/gift/berry/held/PC features remain separate.

Compatible mods can also advertise starter, encounter, visible field-item, or learnset ownership through the generic provider capabilities. DEV REPORT includes a compact ownership snapshot for those four mechanics.


### Randomizer roadmap pause point

As of 2.6.89, implementation work is complete through Phase A, Phase B items 1–11, Phase C items 1–11, and Phase D items 1–11. The remaining item 12 in Phases B/C/D is runtime/regression certification. Further randomizer implementation phases are intentionally paused; resume from the then-current strict descendant of 2.6.89 and carry that deferred runtime debt forward.

Provider ownership can explicitly say:

- `allow` — Nuzlocke may randomize.
- `deny` — preserve the provider/story result.
- `provider` — another provider owns randomization.

Aliases (`preserve`, `story`, `external`, `owned`) normalize to those canonical values. Provider-owned encounter tables are not double-randomized.

## Setup and QoL

Available setup/QoL surfaces include starting resources, Quick Nuzlocke Start, default player/rival names, Running Shoes, catch-tutorial skip, Instant Text, Unlimited Bag Space, intro-related skips, starting supplies and other edition-aware helpers. QoL features must not silently bypass an enabled challenge rule such as No Repels.

## Run History / Forgiveness

NUZ STATUS presents a live RUN STATUS summary, then groups ACTIVE RULES under the same catalog sections used by Setup/NUZ RULES and lists NEW GAME-only configuration under SETUP ONLY. CURRENT AREA / AREA SLOT describe the present encounter slot; LAST EVENT reports the latest Run History event known to this mod. Select RUN HISTORY and press A to open the chronological event viewer. Saves created before Run History producers existed can only show events recorded after those producers were introduced; the mod does not invent missing historical events.

Run History records chronological Nuzlocke events for later diagnostics/recap consumers. F. TOKEN / Route Forgiveness can reopen eligible failed encounter opportunities or restore an archived dead Pokémon only through the defined storage/party legality rules; full storage prevents unsafe revival placement.

## Gold / Silver

Gold and Silver share the Gen2 engine family but remain separate runtime-evidence targets. Gen2-specific adapters cover capture, nickname, mart/item, static, trade/gift, Whiteout, poison faint, Headbutt, Random Starter, title/setup and related paths without forcing Gen1 implementations onto Gen2 modules.

## Compatibility behavior

Nuzlocke composes with external mods through public semantic contracts where possible: trainer-party providers, battle roles, species/move metadata, encounter ownership, acquisition kinds, held-item capability, level-cap providers and content registrations. When an external mod owns a non-core feature and safe composition is not available, Nuzlocke should delegate/grey the overlapping control rather than double-apply it.

See `docs/COMPATIBILITY.md` for current named-mod notes and `docs/API.md` for provider contracts.

## Dev Mode and troubleshooting

Dev Mode includes self-test/report surfaces for build provenance, rule registry/schema checks, hook health, lifecycle duplication, safe-stop writes, randomizer integrity, provider composition and install health. A feature can be player-runtime healthy while a provider API remains unverified; these are tracked separately in `docs/FEATURE_CONFIDENCE.md`. Stadium/Crystal-251 coexistence is also reported separately: importing Stadium model assets does not change catch provenance, while an actual cooperating Stadium transfer/import can be recorded as `STADIUM PRIZE` with Stadium 1/2 origin and provider metadata.

## WIP / unavailable

Wonderlocke remains disabled until a safe pre-transaction Wonder Trade seam exists. Permanent Rule Seal remains WIP-disabled. Crystal is not currently a declared target.
## Reliability / interruption behavior

2.6.57 adds internal recovery infrastructure for future interruption-sensitive gameplay mutations. A pending supported transaction is reconciled on load before normal schema migration/enforcement resumes. If Nuzlocke cannot prove whether an interrupted mutation already happened, it fails closed rather than repeating the mutation blindly. This infrastructure does not change ordinary rule choices or claim that every existing gameplay path has already adopted transaction recovery.

Dev Mode can report Hook Registry, Feature Health, installer failures, and pending gameplay-transaction state. `ACTIVE` means the tracked feature/hook is present as expected; `DEGRADED` can include legitimate wrapper interposition that deserves inspection; `UNAVAILABLE` means an expected tracked surface is missing or failed.



## Rare Candy → Current Level Cap

When a finite Nuzlocke level cap is active, using a Rare Candy on a Pokémon can use the normal single-candy path or a **TO CAP** batch. TO CAP uses only real Rare Candies, never exceeds the live cap, and stops early if the bag runs out. The cap is re-read before every level, so compatible trainer/cap providers remain authoritative. Intermediate level-up moves and evolutions are still offered normally. **No Rare Candy** blocks both the single and batch paths. With no finite cap, Rare Candy use remains vanilla one-at-a-time behavior. Each TO CAP step is journaled independently: interrupted recovery only completes a missing inventory removal when that exact transaction durably recorded that its native Rare Candy effect returned; ambiguous partial state fails closed rather than replaying or guessing.


### World Building tiers and rule explanations

World Building changes presentation only; it does not decide legality. Optional flavor is suppressed when World Building is OFF. Consequential enforcement/state-change feedback must remain understandable at T0: the protected critical paths use their plain Tier-1 wording instead of disappearing. T2 adds personality, and T3 may use region-aware contextual dialogue. Some T3 messages have deterministic variety; this presentation selection does not consume or alter gameplay RNG.
