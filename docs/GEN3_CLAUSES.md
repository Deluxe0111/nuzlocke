# Gen 3 Nuzlocke — CLAUSES milestone

The CLAUSES screen uses the original Gen 1/2 **option meanings** where safe,
but is scoped to Generation 3. The original Johto **Bug Catching Contest**
setting is intentionally omitted. Dupes and Shiny Catch Exceptions were
confirmed in live FireRed testing; Roamer Clause is the next [WIP] implementation.
Other clauses remain honest [Soon] placeholders.

## Implemented policy and status

| Menu item | Modes / description | Status |
| --- | --- | --- |
| **DUPES CLAUSE** | `OFF`, `SPEC`, `FAM`, `SPLIT` | **[WIP]** (implemented in Lua; native evolution and edition tests needed) |
| **SHINY CLAUSE** | `OFF`, `1`, `2`, `3`, `UNLIMITED` | **[WIP]** (implemented in Lua; in-game shiny validation needed) |
| **SHINY RATE** | Planned NATIVE and increased-odds policies | **[Soon]**, inert |
| **SHINY COLOURS** | Planned options for the mod's own shiny presentation | **[Soon]**, inert |
| **SHINY INTRO** | Planned presentation override | **[Soon]**, inert |
| **ROAMER CLAUSE** | OFF / SLOT; roaming species get independent catch slots without spending grass routes | **[WIP]** (mock tests pass; native game unverified) |
| **EGG ENCOUNTER** | Planned received / hatched / gift-egg provenance | **[Soon]**, inert |
| **ROUTE FORGIVENESS** | Planned Gym reward token and reopening/reviving behaviour | **[Soon]**, inert |

The vanilla game may already have shiny colours/animations independent of
Nuzlocke. **[Soon] refers to Nuzlocke-specific configurable controls**,
not the existence of native shiny presentation.

**Existing saves:** Both new CLAUSES settings default to OFF in Gen 3 to avoid
retroactively blocking captures on earlier test saves. In contrast, the
original mature Gen 1/2 rules have different defaults; this is deliberate
until a Gen 3 new-game setup/preset UI is implemented.

## Dupes Clause

- **OFF**: previously obtained Pokémon do not affect future encounters.
- **SPEC**: the exact same species is ineligible.
- **FAM**: Pokémon anywhere in the same connected evolution family are
  ineligible. Example: Vaporeon and Jolteon are both in Eevee's family.
- **SPLIT**: only ancestors or descendants of the exact line count as
  duplicates. Vaporeon does **not** exclude its sibling Jolteon, but either
  excludes Eevee.

Eligibility is checked **before consuming an encounter**. A duplicate does
not spend the location, even with **Failed Encounters ON**. Trying to capture
the duplicate is rejected at `catch.rate`; an eligible species encountered
later in that location can consume the slot normally.

Previous acquisitions are inferred from the existing captured-species log,
caught encounter records, living party, boxed Pokémon and the graveyard.
Evolution relationships are read from the native ROM-backed
`Pokemon.evolutions()` graph. Internal species IDs are normalised through the
engine's `Pokemon.speciesOf()` where available.

**Known gaps:** Encounter qualification currently covers ordinary wild battles
by native map ID, not canonical multi-floor areas, story gifts, trades or
static encounters. ROM/provider transformations of the evolution graph need
additional testing; if the evolution graph is unavailable, FAM/SPLIT fail open
rather than blocking an unrelated Pokémon. That is why these modes remain
[WIP], not certified Working.

## Shiny Catch Exception

- **OFF**: no extra catches outside regular area and Dupes restrictions.
- **1/2/3**: that many successful *exceptional shiny captures* per run.
- **UNLIMITED**: traditional Shiny Clause, unrestricted allowance.

The clause does **not alter shiny odds**. It reads
`Pokemon.isShiny(mon)`, which respects native Gen 3 identity and the engine's
`shiny.roll` seam, including results from compatible shiny providers.

A shiny on an **already spent route** or a **duplicate shiny** may be caught
using an available exception. A failed Ball does not spend allowance;
successful capture does. Exceptional shiny captures do not consume/rewrite a
separate normal encounter slot. A shiny that was already eligible for a
normal encounter simply uses that normal encounter.

Counters persist under `gen3_classic_v1.shinyExceptionsUsed`. Changing the
allowance mid-run does not refund any previously used exception.

The clause cannot bypass other mods' catch-rate denial or future absolute
rules such as No Catching, species bans or Type Locke. The policy calls
`next(...)` for permitted catches rather than forcing a capture.

## API / compatibility

- `gen3_clauses.lua` is separate from `gen3_core_rules.lua`: menus must
  never implement their own catch decisions.
- `mod.exports.gen3_clauses` (API 1) exposes:
  `definitions()`, `getMode(key)`, `setMode(key, value)`, and `summary()`.
- Unsupported CLAUSES settings are rejected by `setMode`, not silently
  enabled. Failed runs cannot change clause configuration.
- `capturedSpecies`, `shinyExceptionsUsed` and `clauses` are added to the
  same backwards-compatible `gen3_classic_v1` save bucket; old records stay
  readable.
- No `shiny.roll` override is installed. We should only modify shiny odds
  after agreeing on ownership/interoperability with other shiny providers.
- Roamer Clause listens for native `roamer.encountered` and native `roamer=true`,
  recording captures in `roamerClaims` rather than consuming `areas`. See
  [GEN3_CLAUSES_NEXT.md](GEN3_CLAUSES_NEXT.md) for proposed remaining clauses.
- The mature Gen 1/2 runtime, menu and save schema remain unchanged.

## Recommended in-game test matrix

Use a disposable save and **NUZ DEV → RE-ARM CURRENT** between tests. Remember:
re-arming an area doesn't remove Pokémon from party/PC or graveyard, which
can themselves continue triggering Dupes Clause.

- [ ] **CL01** — Set Dupes OFF. Capture two Pokémon of the same species in
  two unused locations (or with One Per Area OFF). Both should be permitted.
- [ ] **CL02** — Set Dupes SPEC. With a Pidgey in your party/PC, encounter a
  Pidgey on an unused route. Capture blocked; route remains free.
- [ ] **CL03** — Still on that route, encounter a species you don't own.
  Capture allowed; now the route is consumed.
- [ ] **CL04** — Set Dupes FAM. With Caterpie in party/PC, encounter
  Metapod or Butterfree. It should count as a duplicate.
- [ ] **CL05** — Set Dupes SPLIT. With Vaporeon owned, Jolteon should not
  count as a duplicate; Eevee should. (Use a randomiser or DEV save if needed.)
- [ ] **CL06** — Set Shiny Clause OFF. A shiny duplicate/used-route encounter
  should still be denied.
- [ ] **CL07** — Set Shiny Clause 1. A shiny duplicate or shiny found on a
  spent route should be catchable once; a second exceptional shiny should be
  denied. Non-shiny repeats remain denied.
- [ ] **CL08** — Miss several Balls on an eligible exceptional shiny, then
  catch it. The allowance should increment **once**, only on success.
- [ ] **CL09** — Toggle Shiny Clause 1→2 after using the first allowance.
  One more exceptional catch should be available; usage must not reset.
- [ ] **CL10** — A normally eligible shiny on a fresh route should **not**
  consume a Shiny Clause exception.
- [ ] **CL11** — Save and reload after captures. Dupes history, selected
  modes and exceptional shiny usage should persist.
- [ ] **CL12** — Verify Shiny Rate/Colours/Intro, Egg and Forgiveness remain
  [Soon]. Roamer Clause is [WIP] and can switch OFF/SLOT; see R01–R06 in the
  [next milestone notes](GEN3_CLAUSES_NEXT.md).
- [ ] **CL13** — In NUZ DEV, confirm **RESET CLAUSE COUNTS** clears the
  shiny exception counter and capture log, but does not erase actual party/PC
  Pokémon or legacy graveyard evidence. Cancellation must change nothing.
- [ ] **CL14** — Repeat basic SPEC and Shiny Clause behaviour on another Gen 3
  edition (Emerald recommended) and note any other enabled mods.

## Unit and engine testing

```bash
lua5.1 tests/gen3_foundation_smoke.lua
lua5.1 tests/gen3_clauses_smoke.lua
```

The dedicated Gen 3 GitHub Actions workflow runs both tests. They confirm
Lua-level behaviour with mocks; they **do not** certify every vanilla/modified
species in FireRed, LeafGreen, Ruby, Sapphire or Emerald. Please report the
exact edition, other enabled mods and test ID when something fails.
