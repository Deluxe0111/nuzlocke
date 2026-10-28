# Gen 3 ADVANCED RULES — first playable implementation

**Version:** v3.0.0-BETA · **Menu:** START → NUZ MENU → NUZ RULES
→ ADVANCED RULES → CATCH RULES.

These are Gen 3-only rules. The Gen 1/2 options remain separate and
unchanged; Gen 3 uses the existing `gen3_classic_v1` save namespace.
The master **CORE → NUZLOCKE** must be ON for catch bans to apply.
Settings are saved and retained when the master switch is temporarily OFF.

## Working: CATCH RULES

| Rule | Default | Meaning |
| --- | --- | --- |
| **No Legendaries** | OFF | Bans Articuno, Zapdos, Moltres, Mewtwo, Raikou, Entei, Suicune, Lugia, Ho-Oh, Regirock, Regice, Registeel, Latias, Latios, Kyogre, Groudon and Rayquaza. Mythicals are separate. |
| **No Mythicals** | OFF | Bans Mew, Celebi, Jirachi and Deoxys. |
| **No Pseudos** | OFF | Bans the full Dragonite, Tyranitar, Salamence and Metagross evolutionary lines, including their first and second stages. |
| **Maximum BST** | OFF | The total of the six native base stats (HP / Attack / Defense / Speed / Special Attack / Special Defense) must be at most the chosen cap: 300, 350, 400, 450, 500, 550, 600, 650 or 700. Exact equality is allowed. OFF is unlimited. |

The classification checks **National Pokédex IDs via native
`Pokemon.national()`**, not direct Gen 3 internal species indices.
This matters particularly for Hoenn Pokémon. The BST limit reads
**native `Pokemon.stats()`** for the final species, including randomised
species. If the native base stats cannot be verified while a cap is ON,
the catch is denied rather than silently bypassing a hard maximum.

### Encounter slots and interactions

- These are **catch restrictions**, not encounter bans: you can still
  battle, faint, run from or observe a banned Pokémon.
- Banned Pokémon **do not claim an area's first encounter slot**, even
  when Failed Encounters Count is ON. The first eligible encounter on
  that route remains available.
- The existing `catch.rate` hook denies a prohibited capture **before**
  native ball capture, clone/storage delivery and any shiny-exception
  allowance. Native ball consumption/breakout presentation remains
  engine-owned, and NUZ NOTICES records the precise reason.
- The **Shiny Clause cannot override** these explicit bans.
  Shiny Nuzlocke and Hardcore apply alongside the restrictions.
- Randomised wild Pokémon and Untamed-Advanced's visible overworld
  wilds use the **final battled species**. Roamers are evaluated as
  species too; their existing roamer-slot treatment is preserved.
- If CORE → NUZLOCKE is OFF (or the run has failed), these four
  restrictions do not change native catch behaviour.
- No changes are made to caught or boxed Pokémon retroactively.
  This first batch is **wild/Poké Ball capture enforcement**; non-wild
  gifts, scripted static giveaways and NPC trades are not yet gated.

### Still [Soon]

Overworld encounters, Town Catches, No Static Encounters, No Fishing,
Gift Pokémon / Gift Slot Policy, In-Game Trades / Trade Slot Policy,
PKMN BAN, Colorlocke and its colour, Alphabetlocke and its letter,
Allow Glitches. All remaining ADVANCED RULES categories also remain
[Soon]. Their controls must not imply implementation until their
underlying native transactions have been validated.

## Manual verification

1. On a disposable save, enable CORE → NUZLOCKE. Enter CATCH RULES.
   Toggle each of the three species bans and cycle MAXIMUM BST.
   Save, restart, and confirm all four settings persist.
2. With FAILED ENCOUNTERS ON, find a prohibited Pokémon on an unused
   route, throw a ball, and inspect NUZ NOTICES and ENC TRACKER:
   the capture is refused, and the route remains open.
3. Encounter an allowed Pokémon on the same route; verify the native
   catch succeeds and the slot is spent normally.
4. At BST 500, test a 500-BST species (legal) and one above 500
   (refused); turn BST OFF and retest normal catches.
5. Repeat with a randomised wild and an Untamed wandering wild.
   Confirm the restrictions apply to the Pokémon actually visible.
6. Disable CORE → NUZLOCKE and repeat one banned species catch.
   Native catching must resume. Restore the master switch afterwards.
7. Test Shiny Clause exceptions: they must not bypass an explicit
   legendary/mythical/pseudo/BST prohibition.
8. Check other nine-category navigation and that unfinished rows
   still show [Soon] and cannot be toggled.

The automated smoke suite is not a substitute for exact-edition ROM
testing in FireRed, LeafGreen, Ruby, Sapphire and Emerald.
