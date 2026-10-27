# Gen 3 CLAUSES — next milestone decisions

Status: **proposed**, except the Roamer Clause prototype, which is now implemented
as an opt-in **[WIP]** feature and needs live-game verification.

The design goal is a near-complete port of the existing Gen 1/2 Nuzlocke mod
without taking ownership from other active mods. The current Gen 3 runtime
keeps **mod API 2** to preserve the mature mod entry/legacy games.

## 1. Roamer Clause — already implemented [WIP]

*Option:* `OFF` or `SLOT` (defaults to OFF for old saves).

- **OFF:** roaming encounters use the normal area encounter rules.
- **SLOT:** roaming legendary Pokémon have one **species-specific persistent
  catch slot**, independent of the grass route currently occupied.
- Fleeing / fainting / missing the first roamer battle **does not consume**
  either the route slot or the roamer species slot.
- Capturing a roaming Pokémon closes **only** that roaming species slot.
- Dupes Clause still applies; Shiny Clause may bypass Dupes/area rules but
  cannot reopen a species-specific roamer slot already claimed.
- The adapter uses the Gen 3 engine's dedicated `roamer.encountered` event,
  or the native roaming Pokémon's `roamer=true` flag. Unsupported providers
  without either identification channel fall back to ordinary encounter rules.
- The saved `gen3_classic_v1.roamerClaims` map is persisted separately from
  `areas`. Nuz Dev's **RESET CLAUSE COUNTS** clears those test claims.

**Manual checks:**
- [ ] **R01:** Encounter and flee from a roaming legendary on Route A with
  Roamer SLOT + Failed Encounters ON. Route A stays open.
- [ ] **R02:** Catch an ordinary Pokémon later on Route A. Its normal slot
  is still available.
- [ ] **R03:** Encounter the same roamer later on Route B. It can be caught
  despite fleeing from the first one.
- [ ] **R04:** After catching it, the roamer slot closes without spending
  Route B's normal grass encounter.
- [ ] **R05:** Change Roamer SLOT -> OFF -> SLOT. Claimed species remain claimed.
- [ ] **R06:** Verify a second roaming species gets its own slot. On FireRed
  this may require a disposable altered save or a different edition.

## 2. Shiny Rate — suggested contract; NOT implemented

Original modes from Gen 1/2: `NATIVE`, `1/4096`, `1/1024`,
`1/512`, `1/100`, `1/10`, `ALWAYS`.

**Decisions for Gen 3:**

- **Scope:** only newly generated *wild* encounters (safest), or also
  starters, gifts, Eggs and generated trainer Pokémon? Recommended: wild
  encounters + statics, and separately selectable breeding/gifts later.
- **Identity stability:** Gen 3's `Pokemon.isShiny()` can be called repeatedly
  by battles, icons, and UI. A simple random `shiny.roll` result on each call
  would cause shiny identity to flicker or change when a screen redraws.
  We must bind the result to a stable individual identity, without changing
  the actual Pokémon's stats, and retain it across save/load and PC transfers.
- **Provider ownership:** when a separate shiny mod owns generation, Nuzlocke
  should show `EXTERNAL` and leave the hook alone (but still recognise the
  generated shiny for Shiny Clause). Never stack probability boosters.

## 3. Shiny Colours and Shiny Intro — suggested; NOT implemented

Gen 3 already has native shiny palettes and introduction effects.

Recommended: **ON** preserves normal game presentation plus any future
Nuzlocke-owned extra cosmetic effects. **OFF** suppresses only the *additional
Nuzlocke-owned effects*; it does not try to remove native GBA shininess.
An external presentation provider always takes precedence.

If players want ON/OFF to hide *native* shiny palettes/sparkles as well,
that requires explicit separate renderer integration and must not change the
underlying shiny identity used by gameplay clauses.

## 4. Egg Encounter — suggested; NOT implemented

Keep original Gen 2 semantics but adapt provenance for Gen 3 daycare and
gift-story Eggs:

- **OFF:** no route consumed; retain acquisition provenance.
- **RECEIVED:** egg claims the map where it was received, not where hatched.
- **HATCHED:** egg claims the map on which it hatches.
- **GIFT:** story gift Eggs use a separate one-off gift slot; bred Eggs
  still use their received/generated location.

**Decisions:**

1. Should regular player-bred Eggs be unrestricted (quality-of-life breeding)
   unless Egg Encounter is explicitly enabled? **Recommend yes**.
2. What happens if an Egg is received/hatched in an already spent area?
   **Recommend record a pending, ineligible acquisition; do not silently
   remove an Egg or corrupt story scripts.** Mark it as invalid for
   Nuzlocke eligibility when hatch identity is available, and track that
   separately from the normal party.
3. Should an Egg's ownership count for Dupes immediately or only after
   hatching? **Recommend after hatching**, when species becomes authoritative.
4. Where should an Egg from daycare count if the receipt source isn't exposed?
   **Recommend fail open with [WIP] diagnostic provenance**, never make up
   a route based on the player's current location.

## 5. Route Forgiveness — suggested; NOT implemented

Original modes: OFF / EARN / START 1. A Gym Leader earns one token once, which
can be spent to reopen a **failed** route or restore a fallen Pokémon.

**Decisions:**

- **Token presentation:** add a dedicated in-game menu action first, then
  integrate an actual item when the Gen 3 item-ownership API supports it
  safely; or wait until item inventory integration exists. Recommend menu
  action with explicit confirmation and a mirrored future inventory item.
- **Pokémon restoration:** old Gen 3 Graveyard entries contain *metadata*,
  not all battle/Pokémon fields. Revival can only be enabled for **future
  full-fidelity archived records** (personality, EVs, IVs, moves, OT and
  other fields). Never recreate an approximate Pokémon from an ID.
- **Where it goes:** restore to the party if space, otherwise to PC if
  available. If neither is possible, retain the token; do not erase the
  record.
- **HP:** restore at half health, matching Gen 1/2 semantics.
- **Lost run:** forgiveness cannot reverse `failed=true` except through
  explicit Nuz Dev testing reset.
- **Gym identity:** rewards are keyed by a stable game/leader ID; defeating
  rematches or replaying a Gym cannot mint more tokens.

## 6. API evolution

- Save schema stays `gen3_classic_v1` for backwards-compatible migration
  from existing FireRed tests.
- Future event consumers should use a **single acquisition provenance
  model** shared by eggs, gifts, trades, statics, roamers and normal catches.
- Expose safe, versioned query methods for provenance, spent locations,
  shiny ownership and token balances. No other mod should mutate raw tables.
- Other mods retain ownership of randomisers, shiny generation, gift scripts,
  UI rendering and PC storage unless a documented compatibility interface
  explicitly grants shared control.

## Remaining manual certification

The Roamer Clause code and isolated tests are complete, but native
FireRed/LeafGreen and Hoenn testing is required. The shiny-rate, egg and
forgiveness settings deliberately remain **[Soon]** in the player menu until
their decisions and engine hooks are validated.
