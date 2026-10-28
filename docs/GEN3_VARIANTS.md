# Gen 3 ADVANCED RULES — Variants / Type Locke

**Version:** 3.0.0-BETA · **Menu:** START → NUZ MENU → NUZ RULES → ADVANCED RULES → VARIANTS.

**Requires:** CORE → NUZLOCKE enabled and a run that has not ended.
This is separate from Gen 1/2 rules; all settings live in the existing
Gen 3 save as `variantRules`. Switching the master OFF temporarily
suspends Type Locke without deleting its saved settings.

## Active rules

| Rule | Default | Behaviour |
| --- | --- | --- |
| **Type Locke** | OFF | OFF, MONO, DUO, TRI, QUAD, PENTA or HEXA. Number of allowed type lanes: 0–6. |
| **Type 1** | RANDOM | Available in MONO through HEXA; selects the first type. |
| **Type 2** | RANDOM | Available in DUO through HEXA; selects the second type. |
| **Type 3** | RANDOM | Available in TRI through HEXA. |
| **Type 4** | RANDOM | Available in QUAD through HEXA. |
| **Type 5** | RANDOM | Available in PENTA/HEXA. |
| **Type 6** | RANDOM | Available in HEXA. |
| **Catch Draft** | [Soon] | Drafts types through successful catches; **not currently implemented**. |
| **Wonderlocke** | [Soon] | Trade/replacement variant; **not currently implemented**. |

Each active Type selector cycles RANDOM, NORMAL, FIGHTING, FLYING,
POISON, GROUND, ROCK, BUG, GHOST, STEEL, FIRE, WATER, GRASS,
ELECTRIC, PSYCHIC, ICE, DRAGON and DARK.

**Gen 3 type IDs are used.** FIRE is native ID 10, WATER 11, and
GRASS 12. Internal ID 9 is TYPE_MYSTERY and is intentionally not
exposed as a selectable normal Pokémon type. This is independent of
the National Dex species IDs used for other catch bans.

## Catch behaviour

- A Pokémon is legal if **either** its primary or secondary type is
  in **any** active Type Locke lane. It need not match both types.
- Off-type Pokémon may still appear, be battled or fainted. Their Ball
  captures are blocked **before** native catch/storage processing.
- Off-type wild Pokémon do **not** consume the area's first encounter,
  including when Failed Encounters Count is ON. The next eligible
  encounter remains your first opportunity.
- Checks run at battle start AND at Ball use. They also run before
  optional scripted gifts and native NPC in-game trades. The
  mandatory opening starter remains progression-exempt.
- Shiny Clause does not bypass Type Locke; the two rules compose.
  Type Locke also composes with PKMN BAN, Colorlocke, Alphabetlocke,
  Legendary/Mythical/Pseudo and BST bans.
- Untamed-Advanced visible wandering wild Pokémon automatically use
  the same restrictions via the normal battle/catch path. No separate
  overworld enable rule is necessary.
- Existing party/PC Pokémon are not removed or retroactively changed.
  Pokémon types are tested at acquisition only; later evolution does
  not trigger a retrospective ban.
- Species with genuinely unavailable type metadata fail open rather
  than guessing. Types supplied by the live Gen1Recomp Pokémon
  registry remain authoritative for registered species.

## RANDOM lanes

RANDOM is not a constant reroll. On the first eligible encounter or
supported optional acquisition, the mod scans available native
National Dex species for represented types, selects distinct valid
types for RANDOM lanes, and saves them in
`variantRules.random_types`. Selection is deterministic for the
trainer identity/seed; reloading does not change the chosen types.
A manually selected type is excluded from other RANDOM lanes.
Explicit duplicate types selected by the player are permitted.
Changing Type Locke mode or a Type selector clears generated
allocations so the new configuration can resolve consistently.

RANDOM does **not** alter a Pokémon's species, actual types or
the native randomiser's encounter population: it only determines
which types the player is allowed to acquire.

## Manual test checklist

1. On a disposable Gen 3 save, enable Nuzlocke; open VARIANTS. Confirm
   Type Locke is initially OFF and Catch Draft / Wonderlocke say [Soon].
2. Choose MONO and set Type 1 = FIRE. A Fire Pokémon (e.g. Charmander)
   must be catchable, subject to other rules; a Water Pokémon (e.g.
   Squirtle) must be refused without spending the route.
3. Set DUO and Type 2 = WATER. Both Fire and Water become eligible;
   an unrelated Normal/Flying Pokémon remains ineligible.
4. Select POISON as one lane and encounter Bulbasaur (GRASS/POISON):
   either matching type must allow it.
5. Progress TRI → QUAD → PENTA → HEXA, verifying only the chosen number
   of Type rows appear; return to OFF to hide them all.
6. Set multiple lanes to RANDOM. After a first wild encounter, inspect
   RND:TYPE labels, save, restart and verify that every selection stays
   the same and no two RANDOM lanes duplicate a type.
7. Try a supported scripted gift and NPC trade with prohibited types:
   their native transaction must not mutate party/PC or spend an area.
   Try allowed types on a new map and verify AREA/BONUS policies.
8. Test a wandering Untamed wild and a randomised wild: the **final**
   battle species' actual types decide eligibility, not the original
   encounter slot's species.
9. Confirm Shiny Nuzlocke and Shiny Clause do not override a mismatch,
   and turning Nuzlocke OFF disables Type Locke without clearing it.

Automated Lua smoke tests are not a substitute for exact-edition
FireRed, LeafGreen, Ruby, Sapphire and Emerald in-game verification.
