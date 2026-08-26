# Nuzlocke User Guide — 2.8.37

2.8.37 is the full-release promotion of the corrected 2.8.36 line. The standalone Gen I shiny path has a Red runtime PASS with `Shiny Rate = ALWAYS`, Shiny Colors ON, and Shiny Intro ON.

### Gen1Recomp 0.2.27 UI / nickname compatibility

On current 0.2.27 engines, R/B/Y catch nickname enforcement uses the engine's public catch-nickname decision seam. Gold/Silver/Crystal Nuzlocke utility screens use the engine's palette-aware Chrome drawing path, so custom GB/COLOR palettes continue through NUZ STATUS and Recover Catches. The Gen II shiny send-out workaround has also been source-revalidated for 0.2.27 and remains narrowly scoped to the queued `shiny-flash` presentation event. Older supported engine builds retain compatibility fallbacks.


## Shiny support

The shiny controls are separate on purpose. **Shiny Clause** controls catch exceptions. **Shiny Rate** controls rarity. **Shiny Colors** controls recoloring. **Shiny Intro** controls the battle sparkle/audio cue. Turning visuals off never makes a shiny non-shiny, and changing the rate never grants a catch exception.

When Nuzlocke owns shinies, Red/Blue/Yellow use the virtual Gen-II DV pattern for natural shinies plus the selected enhanced-rate layer; an enhanced shiny is marked on the live mon without rewriting its DVs or stats. Gold/Silver/Crystal use Gen1Recomp's native shiny field and public `shiny.roll` seam. Nuzlocke also verifies that the exact Gen II roll result reaches the created wild mon before battle presentation; this does not add a second roll.

Nuzlocke's visual layer uses Gen1Recomp's live Pokemon sprite/icon hooks, so screens that present a specific live shiny Pokemon can request its cached shiny art without Nuzlocke replacing the screen. The battle intro cue uses `battle.overlay` and therefore does not take ownership of the battle state machine.

If a compatible external shiny provider is active, **the external provider owns everything shiny-facing for that edition**: roll/generation, recolor, sparkle, and shiny SFX. Nuzlocke immediately stops doing those jobs and only consumes the resulting shiny identity for Shiny Clause, legality, tracker/Catch Info, and run history.

# Nuzlocke User Guide — 2.8.33

## Optional Renderer Companion: PotatoVoxel

Nuzlocke 2.8.33 explicitly supports coexistence with **PotatoVoxel 1.9.6**. PotatoVoxel may render the overworld and optional staged battle scene in 3D; Nuzlocke continues to enforce the challenge rules underneath. No PotatoVoxel installation is required to use Nuzlocke.

For combined testing, use only one voxel-world mod at a time. With PotatoVoxel enabled, normal Nuzlocke encounters, catches, rule denials, switching, item targeting, tracker state, NUZ INFO, and lock-ins should behave the same as in the native 2D presentation. Building or rebuilding PotatoVoxel's cache is graphics preparation and should not consume encounters or advance Nuzlocke progression.

On Gold, Silver, and Crystal the battle command/menu state remains native Gen II-owned. Nuzlocke does not add a competing battle renderer. Runtime support claims remain edition-specific.

# Nuzlocke User Guide — 2.8.32

## Recommended Companion: STEEL/FAIRY AND TYPING CHARTS

Nuzlocke 2.8.32 explicitly supports the optional `steel_typing` companion. When it adds Fairy or changes Steel/Dark/type-chart relationships, Nuzlocke's typing-aware systems consume the merged runtime data. Random Starter **Trio Typing: AUTO** now uses the live battle type chart as well. The companion is recommended, not required; changes to that mod require its documented save/restart cycle.

# Nuzlocke User Guide — 2.8.31

## Gold / Gen II Random Starter

With **Random Starter = ON** and **Starter Style = 3-STAGE**, each Elm ball now resolves to the **base form** of a genuine three-stage evolution line. A stale choice from an older build that no longer satisfies the selected Starter Style is discarded and regenerated from the same deterministic seed/style namespace.

When inspecting an Elm starter ball, the randomized portrait/cry transaction and confirmation text use the same persisted choice. The confirmation textbox should name the randomized Pokémon rather than showing `...`. Choosing YES must grant that same species.

2.8.29's native Gold/Silver/Crystal battle menu and blocked-item denial behavior remain unchanged.

# Nuzlocke User Guide — 2.8.29

In Gold, Silver, and Crystal, the battle command menu is always the game's native FIGHT / PKMN / PACK / RUN screen. The Nuzlocke Battle Menu UI option is Gen I-only and is not shown in Gen II Setup or NUZ RULES.

When a Gen II battle item or capture attempt is blocked by a Nuzlocke rule, the refusal is shown through the native battle message box. Press A or B to page/close the message; control should return to the native battle command flow without an empty textbox or frozen battle.

# Nuzlocke User Guide — 2.8.29

**Battle Menu UI is Red/Blue/Yellow-only.** Gold, Silver, and Crystal always use the native battle command menu, including the native PKMN glyph and Gen II command-box layout. A saved Battle Menu UI value from an older build has no effect on Gen II and the option is no longer shown there. Blocked Gen II battle items use the native battle refusal state; Nuzlocke no longer creates a custom battle-message phase.

## Historical current note: Nuzlocke User Guide — 2.8.27

In Gold, Silver, and Crystal, the battle POKéMON command and its B/cancel path
are native. NUZ INFO remains field-only. Party-target items continue to use the
native direct target list rather than the ordinary field action submenu.

## 2.8.01 hotfix note
Gold/Silver/Crystal Setup and NUZ RULES again expose Random Trainers plus Trainer Balance, Trainer Diversity, and Trainer Theme. When an overworld poison tick kills the final usable party Pokémon, Nuzlocke now independently evaluates Whiteout/Blackout instead of relying only on the engine's whiteout flag. The known Gen II party-item-use issue remains open.


## 2.8.00 runtime note

In Gold/Silver/Crystal, field Pack healing items, status cures, revives, vitamins and Rare Candy should open the normal “Use on which Pokémon?” chooser; selecting a Pokémon should then apply the effect, consume one item on success, and show the result message. Rare Candy-to-cap remains available when a finite cap exists. Setup/NUZ RULES held navigation now starts after about 0.48 s and ramps through five progressively faster—but slightly slower than 2.7.106—repeat stages.

## 2.7.106 runtime note

In New Game Setup and NUZ RULES, tapping UP/DOWN moves one row. Holding a direction pauses briefly, then accelerates through five repeat speeds. Holding SELECT while using UP/DOWN keeps the existing section-jump behavior and follows the same progressive repeat cadence. On Gen2, simple party consumables (healing/status/revive items, vitamins, Rare Candy) now execute directly on the Pokémon selected from the native item chooser; PP items and evolution stones retain their specialized flows.

## 2.7.105 party-item and list navigation note

On Gen2, choosing **USE** on a party-target item should open "Use on which Pokémon?" and selecting the target should immediately run the item action; it should **not** open the normal WATERFALL/STATS/SWITCH/MOVE/ITEM/NUZ INFO submenu. 2.7.105 repairs that chooser distinction.

In **NUZLOCKE SETUP** and **NUZ RULES**, tap UP/DOWN to move one row or hold UP/DOWN to rapidly repeat after a short delay. Hold **SELECT** while navigating to keep the existing whole-section jump behavior. Numeric digit-entry rows keep their deliberate tap/edge editing behavior.

## 2.7.104 runtime note

TOOLS profile controls keep the 2.7.103 behavior: Profile Slot selects OFF/1/2/3; Save Profile and Load Profile act on that selection. For Gen2 randomized starters, 2.7.104 may repair the tracked starter's internal native party-record shape automatically on the next party-item attempt. This is a compatibility repair and does not intentionally change the Pokémon's species, current HP/status, moves, held item, OT, or Nuzlocke provenance.

## 2.7.103 TOOLS + World Building defaults

TOOLS uses one selector and two actions: **Profile Slot** cycles OFF/1/2/3; **Save Profile** saves the current configuration into the selected numbered slot; **Load Profile** previews and loads the selected saved configuration. LEFT/RIGHT on Save/Load does not change the slot. World Building now defaults to **T3** in every game on fresh/default configurations. Existing saves retain an explicitly stored tier.

## 2.7.102 TOOLS profiles and Gen2 party items

In Setup and in-run Rules, TOOLS uses one shared profile target with `OFF / 1 / 2 / 3`. LEFT/RIGHT on Profile Slot, Save Profile, or Load Profile changes that target. A cycles Profile Slot. A on Save Profile saves the current configuration to the selected numbered slot; A on Load Profile previews and, after confirmation, applies the selected numbered slot. OFF performs no save/load action. Profiles remain configuration-only.

Gen2 party-target consumables retain native Gen1Recomp item-effect ownership. Before native party-item dispatch, Nuzlocke normalizes any compatible numeric owned-Pokemon species representation to the semantic species key expected by Gen2 Pokemon data. Runtime certification is required.

## 2.7.101 in-run tools

The bottom of NUZLOCKE RULES now contains **TOOLS**: Save Rules, Profile Slot, Save Profile, Load Profile, and Encounter Assignment. Profiles store configuration only. Loading previews rule changes before applying them. Encounter Assignment is the player-assisted provenance recovery tool for Pokemon whose encounter area could not be recovered automatically. Gen2 Services & Economy now exposes Shop Restrictions with OFF / NO BUY / NO SELL / NEITHER.

## 2.7.95 presentation update

The Gen-2 ENC TRACKER MAP is ordered for players rather than ROM internals: normal Johto progression appears first, followed by Kanto and then evidence-backed custom/unknown encounter areas. Ordinary non-encounter interiors are not listed merely because they exist in the ROM map catalog. New Bark remains visible because it owns opening-starter provenance.

R/B/Y pre-game **NUZLOCKE SETUP** now uses the same black-on-white normal-content treatment as live **NUZLOCKE RULES**. MOD COMPAT keeps its two-column ownership information but uses safer title/help-selector spacing and a slow-blinking down indicator when more rows exist. Battle Menu UI remains optional and presentation-only; ON uses compact pixel-box command chrome while native battle input/actions remain authoritative.

## 2.7.94 Random Starter

Random Starter chooses from the hard-safe live species pool for the running edition/content registry and then applies Starter Style and active challenge legality. **Species Pool does not restrict Random Starter.** Species Pool applies to Random Encounters, Random Trainers, and Random Evolutions. This separation restores the last runtime-proven Gen1 starter behavior while keeping the shared Randomizer configuration system.

## 2.7.93 UI / movement consolidation

**Battle Menu UI** is available under UI in Red/Blue/Yellow and defaults OFF. OFF uses the normal Gen1Recomp battle command menu. ON replaces only the ordinary Gen I command presentation with Nuzlocke's centered bottom 2x2 panel while the native battle state still owns selection and actions. Gold/Silver/Crystal always use their native battle command menu; Safari and tutorial/demo menus remain native.

QOL now has one **Run / Surf** selector instead of separate Running Shoes and Fast Surf rows: `OFF`, `HOLD B`, or `ALWAYS`. It applies the same selected mode to player-controlled walking and Surf. Biking, scripted movement, Surf initiation, Waterfall, fishing, menus, and cutscenes stay native. Existing saves/presets choose the more restrictive old movement setting when the two historical values disagree.

## 2.7.92 Setup / Rules appearance

Nuzlocke-owned Setup and Rules screens use one emphasized bold title and a consistent black normal-content treatment. Normal rule names, values, cursor/navigation glyphs, the bottom-centered pager, and help text no longer use mixed normal-row colors. WIP/delegated rows may still dim. The three visible rows remain moved upward and the pager remains centered at the bottom of the list panel.

## 2.7.91 Random Starter crash / Rules pager update

Silver 2.7.90 runtime testing confirmed the vanilla Elm starter path now works without the false glitch warning. 2.7.91 protects that path by treating starter-slate materialization as optional: a randomizer materialization fault falls back to the selected vanilla starter rather than crashing Elm's mandatory grant. The Setup/Rules layout also moves the visible rules upward and centers the ▲ current/total ▼ pager at the bottom of the list panel on both Gen-1 and Gen-2 surfaces. Crystal Mom DST remains deferred.

## 2.7.90 starter provenance repair

Gold/Silver/Crystal Elm starter flow now carries one same-script mandatory-starter marker from POKEPIC through GIVEPOKE, plus a one-transaction receipt window while the native party mutation emits pokemon.received. Generic gift/glitch gates must not re-evaluate that same mandatory starter. New Game Random Starter settings are also copied into the fresh save-backed mod state at save.created so R/B/Y and Gen 2 do not lose the setup choice before the starter transaction. Crystal remains ALPHA; Mom DST cleanup is deferred.

## 2.7.89 starter transaction recovery

Setup/Rules no longer show the redundant edition / NEW RUN/LIVE subtitle beneath the title. Random Starter recovery now follows the recently runtime-proven ownership model: R/B/Y uses the first canonical opening starter gift, while Gold/Silver/Crystal treats Elm Lab GIVEPOKE as the mandatory starter story transaction before optional gift/glitch policy. Crystal remains ALPHA; its remaining Mom DST prompt is deferred.

## 2.7.88 starter / clock / DEV report runtime repair

Silver and Crystal runtime testing through 2.7.87 showed that the Elm transaction could still reach Nuzlocke as a numeric Gen-2 species identity and be rejected as glitch-shaped. 2.7.88 resolves numeric species against the live Pokemon registry's public `index` field before acquisition legality, and Elm's mandatory transaction additionally recognizes the three canonical cartridge GIVEPOKE operands in Elm Lab. Gen-2 Random Starter uses the same canonical/native conversion; R/B/Y Random Starter now mutates the gift only when the rule is enabled. Manual Time's rules-row summary displays `HH:MM`. VIEW REPORT generates and displays the live NZR6 code first. Crystal remains ALPHA.

## 2.7.87 Gen-2 Elm / Manual Time / DEV report repair

Gold/Silver/Crystal script GIVEPOKE uses numeric Gen-2 species IDs. Nuzlocke now resolves those IDs through Gen1Recomp's canonical Gen-2 species order before starter recognition and legality. Random Starter uses the same authority in reverse when converting a selected canonical species back to the native grant index. Manual Time supports both hour and minute editing. On Crystal, System Date/Time now also owns Mom's initial DST confirmation ladder. DEV TOOLS -> VIEW REPORT opens on the long shareable report code first; Left/Right reaches the human-readable report sections. Crystal remains ALPHA.

## 2.7.86 Gen-2 starter/setup repair

Silver and Crystal runtime testing of 2.7.85 showed vanilla Elm starters being rejected as glitch Pokemon, leaving the story advanced with an empty party. 2.7.86 resolves canonical Gen-2 species names through numeric/row-indexed registries before glitch classification. It also restores System Date/Time and System Clock Sync to shared Gen-2 setup applicability. Crystal remains ALPHA.

# Nuzlocke User Guide — 2.7.85

## 2.7.85 Crystal Alpha runtime note

Crystal remains intentionally supported in Alpha. 2.7.84 runtime testing reached Elm Lab but crashed on the first starter-ball interaction. 2.7.85 leaves Crystal's native animated starter portrait/cry presentation untouched while retaining Nuzlocke's shared Gen-2 starter grant/tracking transaction. Retest the starter flow before treating Random Starter presentation as certified on Crystal.



## 2.7.84 Crystal Alpha support

**Pokémon Crystal is now an intentional Nuzlocke target, currently in ALPHA.** Nuzlocke-owned Crystal rules/status/configuration screens identify the game as **CRYSTAL ALPHA**. Core shared Gen-2 systems are enabled where the engine uses the same contract as Gold/Silver, including the 251-species rule pool, Gen-2 clock controls, shared encounter/rule surfaces, and Elm-style starter handling.

Alpha means runtime coverage is incomplete. Crystal-specific story events, script specials, static/gift encounters, Battle Tower behavior, progression details, and edition-specific UI paths may still be unverified or incomplete. A feature working on Gold or Silver does **not** count as Crystal proof. Report Crystal failures with the exact rule, location/story state, and whether the run is NEW GAME or an existing save.

The Gen1Recomp compatibility profile is now source/documentation-audited through **0.2.27**, and **Gen1Recomp 0.2.24 or newer is required** for this build because Crystal is an explicit manifest target. No Nuzlocke save migration is required for this support change.


## 2.7.83 Rules / Setup controls

- **Nuzlocke Loadout:** select the row to open the complete loadout chooser. Move directly to any available choice. The screen shows a short description and how many loadout-owned rules differ; choosing a named loadout still opens the safety confirmation before anything changes. CUSTOM keeps the current hand-built challenge rules.
- **Game Difficulty:** select the row to open the direct profile chooser. The highlighted profile shows concrete ordinary-trainer/boss level, team, BST, move, AI, Stat EXP/DV, and Gold held-item effects where applicable. If another trainer/difficulty mod is active, Nuzlocke warns before committing because that mod's own hooks may still compose.
- **Manual Time (Gold/Silver, in-run):** choose a game hour and press A to apply it. The current minute and weekday stay unchanged. Applying manual time automatically turns **System Clock Sync OFF** so platform time cannot immediately overwrite the manual choice.
- **Starting Poke Balls:** the Setup description now explicitly says these are **deferred**. They are delivered only at the normal capture unlock (Oak Pokedex transition in R/B/Y; after the Mystery Egg return to Elm in Gold/Silver), unlike immediate PC Candy/healing/vitamin loadouts.
- **Rules position:** the compact current/total counter remains visible with the existing native scroll arrows, now placed at the top-right of the toggleable Rules area instead of consuming its own row.


## 2.7.82 Silver / Gold notes

- **System Date/Time:** on a new Gold/Silver game, Nuzlocke initializes the native clock/weekday from platform-local time and now automatically handles Mom's complete initial DST ladder. The host clock already reflects local DST, so the cartridge DST bit stays clear.
- **Random Starter at Elm:** the rendered randomized starter preview is the authority for the immediately following confirmation, and the received starter can be registered from Elm's committed native story event if earlier grant callbacks miss the delayed party construction.
- **NUZ INFO:** the field Pokémon submenu uses the shared Gen-2 PartyMenu path and should appear on both Gold and Silver when Catch/Stat/Move info is enabled.
- **Starting Poké Balls:** unlike bedroom-PC Rare Candy/healing/vitamin loadouts, selected extra Balls remain deferred until normal capture unlock (Oak Pokédex transition in R/B/Y; after Mystery Egg return to Elm in Gold/Silver). This is intentional.
- **DEV REPORT:** package/document Release Safety and generated machine codes are build-process data, not in-game runtime health, and are no longer shown in the player Dev UI.


## 2.7.81 engine compatibility notes

On Gen1Recomp 0.2.21, **System Date/Time** remains a Gen2 NEW GAME option and **System Clock Sync** remains an in-run Gen2 QoL option. Automatic setup uses platform-local time/day and now covers either initial Daylight Saving Time branch without applying the cartridge DST adjustment a second time. Gold and Silver should still be tested independently. Crystal is not a supported Nuzlocke edition.
## 2.7.80 — Gold/Silver clock options and safer TO CAP batches

Gold/Silver NEW GAME setup now includes `System Date/Time`. When enabled, Nuzlocke uses the engine's native Gen-2 clock to initialize time and weekday from the platform local clock and bypass the manual opening clock flow where the engine path allows it. The regular QoL option `System Clock Sync` keeps that native clock aligned while enabled; turning it OFF stops further re-anchoring and leaves the current game-clock offset alone.

Randomized Elm starters now have an additional completion fallback when the granted Pokémon appears in the party only after GIVEPOKE returns. The exact pending transaction finalizes on the next safe world step so the actual starter, New Bark Tracker record, Random Starter state, and Elm story state can converge. Very old starter saves remain repairable only under narrow proven evidence; same-species Pokémon are not generally treated as the same identity.

For Rare Candy `TO CAP`, press B during a multi-candy batch to request a stop. The current candy's complete native level-up, stat, move-learning, and evolution sequence finishes first; the batch then stops before another candy is consumed and shows `Candy batch stopped.`

## 2.7.79 — Gold/Silver starter consistency

Gold and Silver now identify Elm's starter transaction from Elm Lab story context rather than requiring an empty party. When Random Starter is enabled, the species visibly shown in the starter preview can also drive the immediately following Elm confirmation text, keeping preview and dialogue on one choice. A Pokémon already proven as the New Bark starter can repair missing native Elm starter-state flags so older saves are not forced toward a second starter selection.

Older identity-less LEGACY starter rows are cleaned up only in a uniquely provable repair case; same-species Pokémon remain separate identities. Nuzlocke-owned Gen-2 utility screens also use a more consistent centered title/subtitle hierarchy.

## 2.7.78 — Starter identity and Recover Catches

A physical starter is now tracked once by its persistent Nuzlocke Pokemon identity. If an older save contains the same starter in LEGACY and in its hometown row, the proven identity is normalized into the correct Pallet Town (R/B/Y) or New Bark Town (Gold/Silver) record instead of duplicated. Gold and Silver now also expose `Recover Catches` in NUZ RULES for unresolved LEGACY/EDITED records. Manual assignment preserves the saved Pokemon identity even when a live party/box object cannot be attached.

## 2.7.77 — Silver starter and seed controls

On Gold/Silver, Random Starter now also updates Elm's starter confirmation text. NUZ INFO keeps the shared party-submenu path and has a direct Gen-2 PartyMenu fallback. Tracker MAP hides ordinary interiors such as houses, labs, marts, centers, gyms, gates, bedrooms, rooms, and offices unless a real encounter/log/catch state belongs there. `Reroll Seed` can be used during a run; `Auto Seed` returns the configured seed to AUTO and live randomizer projections rebuild immediately.

## 2.7.76 — Gen-2 starter and Tracker parity

Gold and Silver now use New Bark Town as the authoritative starter provenance location, while Red/Blue/Yellow retain Pallet Town. On Gen 2, authored Gen-1 Tracker seed rows appear only after real visit/encounter/catch evidence. DEV REPORT also exposes reachability counters for the shared Gen-2 script, starter, party-menu, and Tracker paths.

## 2.7.75 — Silver shared Gen-2 parity recovery

Silver now uses the same shared Gen-2 runtime path as Gold whenever exact edition detection identifies the game as Silver, even if lower-level generation helpers fail to do so. This is intended to prevent Gen-1 fallback behavior such as Pallet Town appearing on the tracker or Gen-2 party/gift integrations failing to install.

## 2.7.74 — Gold Nuzlocke info-page normalization

Gold's Nuzlocke-owned DEV REPORT and Pokémon CATCH/STAT/MOVE INFO pages now use the same clearer title hierarchy: emphasized centered page title, centered normal Pokémon/subject subtitle, compact body rows, and stable footer spacing. This is presentation-only and does not change Pokémon data or rule behavior.

## 2.7.73 — Reconstruction checkpoint

This build preserves the complete 2.7.72 feature/rule surface and repairs an internal Late Runtime dependency-order issue. Player-facing rule behavior is intentionally unchanged. Runtime smoke is required before reconstruction advances.

## 2.7.72 — Shared UI ownership hardening

- Explicit `wide` layout requests now fall back to the classic surface unless a usable wide-layout provider reports a real wider size; `applyLayout()` claims the resolved layout instead of the raw request.
- Shared Gen 1/Gen 2 row primitives now support caller-owned `preFitted` text.
- Both live R/B/Y Tracker tabs mark only their selected marquee row as pre-fitted, preventing the shared pixel fitter from adding a second ellipsis to an already-finalized scrolling slice.
- Non-selected Tracker rows retain the shared defensive pixel fit.
- Release Safety protects both contracts.

## 2.7.66 rule-availability audit, pass 2

- Continues the rule-availability audit in a deliberately small pass.
- Yellow no longer exposes Random Starter `Trio Typing` as a native rule because Yellow does not natively use the three-choice starter slate; an explicit compatible `starter_trio` provider can make it available.
- Encounter-slot modifiers now depend on `One Per Area`: Failed Encounters, Dupes, Gen II roamer/egg/contest policies, Town Catches, and area/time/headbutt split controls become dormant while area encounter limits are OFF.
- Type Locke now exposes/effects only the lanes selected by its mode. Catch Draft is hidden while Type Locke is OFF; manual type lanes are hidden/inert during Catch Draft; DUO through HEXA progressively reveal only the required lanes.
- Stored values are preserved while dormant and return when their prerequisite becomes applicable again.
- Release Safety extends the exact-edition/dependency source tripwire for these relationships.


# Nuzlocke User Guide — 2.7.65


## 2.7.64 MOD COMPAT ownership controls

On selectable MOD COMPAT rows, use Left/Right to cycle the preferred owner. `AUTO` is recommended and chooses the live compatible provider normally. A row may also offer the native `Nuzlocke`/`Engine` owner and any installed provider that actually advertises the matching capability. Rows without a safe substitutable provider contract remain read-only. Gameplay-impacting changes show an OWNER WARNING before applying; Cancel leaves the preference unchanged.

> **Current build:** 2.7.84. The shared Nuzlocke architecture remains canonical; this build advances the Gen1Recomp compatibility audit through 0.2.24-era source and intentionally adds Crystal as an ALPHA target with independent runtime evidence.

## 2.7.63 build note

Gold/Silver Encounter Tracker MAP rows now come from the active Gen II map catalog/order rather than the Gen I seed list. Difficulty selection is pre-confirmed whenever the proposed profile changes trainer semantics; the warning uses the same APPLY/CANCEL pattern as loadout changes and Cancel leaves the current selection untouched.


## 2.7.62 build note

Build **2.7.62** is a strict child of exact 2.7.61. Gold runtime testing confirmed No Buying and No Selling while exposing No Center Heal as unenforced. Gold/Silver Center and Mom healing now gate the native Gen II `HealParty` special only in the appropriate service context; story heals elsewhere remain native. Runtime retest is required.

## 2.7.60 build note

Build **2.7.60** is a UI build. It descends from exact 2.7.54 through the promoted forward lineage. This pass changes startup diagnostics only; gameplay rules and save behavior are unchanged.

> **2.7.57 only:** This build includes a Dev-only UI Gallery (DEV TOOLS -> SELECT) with five synthetic pages for hierarchy, encounter state, diagnostics, typography stress, and notice/wrapping stress. The Gallery is read-only and does not constitute gameplay Runtime PASS.

# Nuzlocke User Guide — 2.7.57

## UI architecture build

This build changes presentation only. Setup/NUZ RULES and ENC TRACKER begin using a shared Nuzlocke visual vocabulary that keeps exact-edition context visible while preserving the same controls and challenge semantics. The build is intentionally development-stage; 2.7.54 was retained as the fallback during development.

The intended control grammar remains Up/Down for vertical navigation, Left/Right for value/page movement where applicable, A for the primary action, and B for back/cancel. Existing special numeric/resource editing behavior is retained.

2.7.54 adds internal regression coverage for external-save reconciliation and Release Safety forward-reference linting; these do not change player-facing rule semantics.

## Safari Clause

- **STANDARD** — the whole Safari Zone shares one encounter slot; normal Failed Encounters applies.
- **PER AREA** — Center, East, North, and West each receive an encounter slot; normal Failed Encounters applies.
- **UNTIL CATCH** — the whole Safari Zone shares one slot, but failed/fled/defeated eligible Safari encounters do not consume it; the first successful catch consumes it.
- **AREA+CATCH** — Center, East, North, and West each receive a slot, and each stays open through Safari failures until a successful catch in that section.

Existing saves keep their old behavior: old OFF (0) is STANDARD and old COMMON (1) is PER AREA.

Randomizer certification now includes non-runtime seed reproducibility and release/documentation audits. These diagnostics are read-only and do not consume Randomizer choices or rewrite mappings. Exact-edition runtime certification remains pending.

<!-- 2.7.51 Phase J #7-9 certification; no player-facing Randomizer option changes. -->
# 2.7.46 Randomizer Phase I #4–6

Randomizer integration now exposes a read-only compatibility matrix for established cross-system ownership seams, an 8-digit seed sharing/import contract, and one deterministic subsystem-version report. Importing a seed changes only the configured seed and does not clear mappings or consume RNG. Existing stream names and algorithm-v1 behavior remain unchanged.

Randomizer Preset integrates the mature subsystem controls without replacing them. CUSTOM leaves every child setting alone. CHAOS enables all Nuzlocke-owned randomizers with broad policies; BALANCED enables them with progression-aware balance defaults. Provider-delegated subsystems remain externally owned and are not seized by a preset. Any manual Randomizer child edit returns the preset label to CUSTOM.

Species Pool is now shared by Random Starter, Random Encounters, Random Trainers, and Random Evolutions: AUTO uses the hard-safe live merged registry; GEN1/GEN2/BOTH apply the same generation-source filter before each subsystem's stronger legality/story constraints. This is an integration policy change, not an RNG algorithm-version change.

# 2.7.44 Randomizer Phase H completion

Gold/Silver Pack and item-PC transfers do not reroll randomized items: randomization occurs at acquisition/content projection, while native storage moves preserve item identity and quantity. Randomizer Info now reports Shop/TM/Gift mapping counts and policies; OPEN may reveal persisted choices while BLIND suppresses them. Phase H includes an executable economy/progression regression audit, but exact-edition runtime certification remains required.

# Nuzlocke User Guide — 2.7.43

### Broader Item / Shop / TM Randomization Phase H #7–9 (2.7.43)
Random Gift Items now also covers dedicated NPC reward-item command surfaces when exposed by the active game/provider. All broader item randomizers share fail-closed key/story/quest/progression exclusions. Random Shops never bypasses No Buying or No Selling, and Random TMs never bypasses No TMs: randomization projects content first while the existing authoritative transaction/use gates remain in control.

2.7.28 repairs Gold/Silver startup/title setup integration. On a fresh Gen2 game, SETUP belongs immediately before NEW GAME; when a valid save exposes CONTINUE, SETUP is intentionally hidden. Randomizer Phase E items 1–6 remain unchanged.
2.7.27 is a development build. Random Learnsets now exclude unusable/broken/invalid live move records and apply deterministic soft type-affinity plus authored damaging/status-shape weighting. These are soft preferences only; every hard-safe move remains reachable. Explicit STAB controls are reserved for Phase E #8.
Gold rules/setup help panes use **Select alone** to advance long descriptions one wrapped line at a time. A `^` cue means text exists above; the native down-arrow means text remains below. The footer shows the exact scroll position, such as **SEL:MORE 2/5**, and changes to **SEL:TOP 5/5** at the final position; another Select then returns to the beginning. The counter is a scroll-position counter, not a page number. **Select+Up/Down** remains the section-jump shortcut and does not page help text.

This guide describes **what the mod does now**. Historical changes belong in `CHANGELOG.md`.

World Building remains independent of the Nuzlocke master switch as a presentation feature. Encounter/Learnset Randomizer subsystems use explicit disabled/delegated/applied lifecycle states, and Randomizer information policy is shown whenever Nuzlocke owns at least one supported Randomizer surface, including learnset-only runs.


### Broader Item / Shop / TM Randomization Phase H #4–6 (2.7.43)

**Random TMs** changes the move taught by each TM without changing the TM item itself. HMs are never randomized. **TM Compatibility** has three policies: MOVE keeps native compatibility with the randomized move; SLOT preserves each species' authored eligibility for that TM slot; FULL allows every species to learn every randomized TM. **Random Gift Items** randomizes ordinary scripted GIVEITEM grants while leaving quantities, inventory capacity, script flags, and transaction completion native. Key/progression items, HMs, TMs, and provider-protected items are preserved. Dedicated NPC reward-item paths are included when exposed by the active game/provider.

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

Random Starter, Random Encounters, Random Field Items, Random Learnsets, Random Trainers, Random Evolutions, and Random Shops use deterministic named randomizer streams where Nuzlocke owns the transformation. The global randomizer algorithm remains version 1; starter slates carry their own independent namespace version so starter-only improvements do not reshuffle encounter, field-item, or learnset results.

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




Random Trainers preserves trainer/story identity, party size, member order, and authored levels while replacing only each member's species. Each exact-edition trainer/class/party/member position has a stable source identity on the isolated `TRAINERS` RNG stream. Hard trainer-pool legality excludes reserved, missing, glitch, runtime-unsafe, and PKMN-BAN species. Player-only catch/acquisition restrictions are not projected onto opposing trainer teams.

**Trainer Balance** controls Phase F strength shaping: `CHAOS` keeps the full hard-safe pool and preserves the 2.7.33 deterministic mapping path; `EVO` prefers the original evolutionary stage and nearby lineage depth; `SIM BST` prefers live merged BST bands around the authored species; `BALANCED` combines stage and BST before widening deterministically. These are soft preferences only. Party levels are still authored/native, so no trainer-level scaling is introduced by this phase.

**Trainer Diversity** adds OFF / DIVERSE / UNIQUE team-level duplicate control. **Trainer Theme** adds OFF / TYPE soft cohesion using the authored team anchor type. Both operate only after hard legality and Trainer Balance and use a separate deterministic team-policy namespace. When Random Starter and Random Trainers are both enabled, canonical rival starter-family members remain synchronized to the persisted randomized starter lineage instead of receiving an independent Trainer-stream roll.

### External randomizer coexistence

Nuzlocke does not disable its randomizers merely because another randomizer mod is installed. Duplicate controls yield only to an active, source-confirmed owner or an explicit provider capability.

The current named ownership adapters cover PokemonRecompRandomizer, Gen 2 Randomizer+, Kanto Reforged encounter randomization, and Item Randomizer visible pickups. For Item Randomizer, only R/B/Y `overworld_items` or Gold/Silver `gold_ball_items` overlaps Nuzlocke's visible Field Item randomizer. Its hidden/shop/gift/berry/held/PC features remain separate.

Compatible mods can also advertise starter, encounter, visible field-item, or learnset ownership through the generic provider capabilities. DEV REPORT includes a compact ownership snapshot for those four mechanics.


### Randomizer roadmap

Implementation is complete through Phase A; Phase B #1–11; Phase C #1–11; Phase D #1–11; Phase E #1–11; Phase F #1–11; Phase G #1–11; Phase H #1–12; and Phase I #1–6. Earlier deferred #12 exact-edition/runtime certification debt remains tracked where not already completed. Phase I #7–12 remain, followed by Phase J Certification/Stabilization.

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

World Building changes presentation only; it does not decide legality. Optional flavor is suppressed when World Building is OFF. Consequential enforcement/state-change feedback must remain understandable at T0: the protected critical paths use their plain Tier-1 wording instead of disappearing. T2 adds personality, and T3 may use region-aware contextual dialogue. Generic T3 rule/world messages do not append run-summary pages such as loss, badge, or catch totals; recap context belongs only on explicitly recap-oriented surfaces. Some T3 messages have deterministic variety; this presentation selection does not consume or alter gameplay RNG.


### Evolution Randomizer Phase G #4–6 (2.7.38)
Random Evolutions now rejects targets that would create a cycle in the projected evolution graph. `Evolution Balance` offers CHAOS, DEPTH, SIM BST, and BALANCED. DEPTH uses the immutable authored topology; SIM BST compares against the authored target strength; BALANCED combines both. These are deterministic preferences only: hard species construction safety and cycle prevention always win. Evolution trigger metadata remains authored.


### Evolution Randomizer Phase G #7–9 (2.7.39)
Split evolutions prefer different randomized targets for each authored branch whenever the legal acyclic pool permits. Random Evolutions changes only the target species: level, stone/item, trade, friendship, and other method metadata remain authored. Gold/Silver day/night/stat-specific evolution conditions are likewise preserved exactly; if a projection ever changes non-target trigger metadata, that row fails safely back to its authored form.

### Broader Item / Shop / TM Randomization Phase H #1–3 (2.7.41)
Random Shops randomizes ordinary Mart BUY stock on the isolated `SHOPS` stream while preserving stock-slot count/order and native transaction behavior. Shop Balance supports CHAOS, PRICE TIER, and BALANCED. PRICE TIER groups purchasable items by native price bands; BALANCED first prefers both semantic item category and price tier before deterministic relaxation. Key/progression items, HMs, TMs, and Gen2 Bargain Shop custom-price rows remain authored. Replacement items retain their own native item-definition price, so quantity selection, affordability checks, buy deductions, sell values, Bag capacity, and money clamps remain engine-owned.


### Randomizer integration (2.7.47)
OPEN/BLIND is one authoritative spoiler policy across Randomizer information surfaces. Randomizer presets work in NEW GAME Setup and live NUZ RULES through the same provider-aware ownership path; externally delegated subsystems remain externally owned.


## Randomizer mid-run policy (2.7.48)
Changing Randomizer settings during a run does not retroactively reroll already materialized semantic source mappings. Existing mappings remain authoritative; previously unseen sources use the current settings. The run-start Randomizer snapshot remains immutable so diagnostics can report configuration drift and preserve reproducibility evidence.


## Randomizer certification (2.7.50)

Phase J has begun. The mod now exposes read-only static determinism, save/reload persistence, and cross-edition determinism audits. These diagnostics do not consume Randomizer RNG or create mappings. Gold keeps the established field-item ALLOW namespace; fresh Silver field-item ALLOW placements use an edition-specific namespace. Existing saved mappings remain authoritative. Exact-edition gameplay certification is still required.

## UI architecture

2.7.57 is a development-stage preview. Dev Tools SELECT opens the read-only UI Gallery. On compatible Gen 1 wide-menu hosts, Rules/Setup and Encounter Tracker may use additional logical width; Gold/Silver retain their native Gen 2 presentation.

### Why some rules disappear

The Rules and Setup lists show only settings that can currently matter. Edition-specific mechanics are omitted when the active game does not have them. Child settings disappear while their parent feature is OFF, and redundant settings disappear while a stronger rule already controls the same behavior. Their saved choices are preserved and return if they become meaningful again. Compatible mods can expose specifically declared missing mechanics through Nuzlocke's compatibility capability contracts.

## Gen II Nuzlocke utility-screen layout (2.8.04)

Nuzlocke-owned Gold/Silver/Crystal utility screens use the shared Gen II Chrome layout. NUZ STATUS, MOD COMPAT, ENC TRACKER, and DEV REPORT reserve a centered emphasized title band, bounded body text inside the native 20x18 tile frame, and a dedicated footer row. Long labels/values are fitted to their assigned lane instead of being allowed to cross the border. DEV REPORT opens on its semantic SUMMARY view; machine-oriented report codes remain diagnostic data rather than the default player-facing page.
