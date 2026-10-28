# Gen 3 ADVANCED RULES — expanded Catch Rules

**Version:** v3.0.0-BETA · **Menu:** START → NUZ MENU → NUZ RULES
→ ADVANCED RULES → CATCH RULES.

These are Gen 3-only rules. The Gen 1/2 options remain separate and
unchanged; Gen 3 uses the existing `gen3_classic_v1` save namespace.
The master **CORE → NUZLOCKE** must be ON for catch bans to apply.
Settings are saved and retained when the master switch is temporarily OFF.

## Working: CATCH RULES

| Rule | Default | Meaning |
| --- | --- | --- |
| **Town Catches** | OFF | When OFF, refuses ordinary wild catches on native outdoor town/city maps (including the seven Sevii island settlements). ON allows them to use their own physical map's encounter slot. This does not classify unrelated interior or route maps as towns. |
| **No Legendaries** | OFF | Bans Articuno, Zapdos, Moltres, Mewtwo, Raikou, Entei, Suicune, Lugia, Ho-Oh, Regirock, Regice, Registeel, Latias, Latios, Kyogre, Groudon and Rayquaza. Mythicals are separate. |
| **No Mythicals** | OFF | Bans Mew, Celebi, Jirachi and Deoxys. |
| **No Pseudos** | OFF | Bans the full Dragonite, Tyranitar, Salamence and Metagross evolutionary lines, including their first and second stages. |
| **No Static Encounters** | OFF | Blocks Ball captures of native scripted wild encounters, including fixed legendary battles and Marowak; the battle itself continues normally. Roaming legendary Pokémon are excluded. |
| **No Fishing** | OFF | Blocks rod use at the native field-entry point before the fishing minigame and prevents direct fishing encounter attempts. Rod items remain in the bag; surf and other encounter methods work normally. |
| **Gift Pokémon** | ON | OFF refuses optional scripted `givemon` gifts before party/PC mutation, using the native failure result. The compulsory first starter remains exempt. |
| **Gift Slot Policy** | AREA | AREA makes successful optional gifts consume the encounter slot on the receipt map when One Per Area is enabled. BONUS records the gift without spending that slot. |
| **In-Game Trades** | ON | OFF rejects native NPC in-game trades at the requested-species preview, before the player gives up their Pokémon. This does not block linked player trades. |
| **Trade Slot Policy** | AREA | AREA makes successful NPC exchanges consume the encounter slot on their map when One Per Area is enabled. BONUS records the exchange without using the ordinary slot. |
| **Alphabetlocke** | OFF | OFF / RANDOM / CHOOSE. Restricts new wild catches by the first letter of the species' canonical ROM identity (not nickname or translated text). RANDOM chooses an available initial deterministically for the save and stores it; CHOOSE uses the Letter selector. |
| **Letter** | A | A–Z selector, only shown when Alphabetlocke is CHOOSE; irrelevant in OFF and RANDOM modes. |
| **Allow Glitches** | OFF | OFF refuses wild catches with invalid/unregistered or explicitly glitch-marked species IDs when the native registry can verify them. ON allows them through this check; all other catch bans still apply. Valid provider-registered custom species are not classified as glitches merely for lacking a National Dex number. |
| **Maximum BST** | OFF | The total of the six native base stats (HP / Attack / Defense / Speed / Special Attack / Special Defense) must be at most the chosen cap: 300, 350, 400, 450, 500, 550, 600, 650 or 700. Exact equality is allowed. OFF is unlimited. |

The classification checks **National Pokédex IDs via native
`Pokemon.national()`**, not direct Gen 3 internal species indices.
This matters particularly for Hoenn Pokémon. The BST limit reads
**native `Pokemon.stats()`** for the final species, including randomised
species. If the native base stats cannot be verified while a cap is ON,
the catch is denied rather than silently bypassing a hard maximum.

### Encounter slots and interactions

- Species and static rules are **catch restrictions**, not encounter bans:
  you can still battle, faint, run from or observe a banned Pokémon.
  No Fishing is instead a **field-use restriction**: rod use is refused
  before the fishing attempt starts. No fish battle is generated.
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
- If CORE → NUZLOCKE is OFF (or the run has failed), these catch
  restrictions do not change native catch or rod behaviour.
- No Static reads the native battle's `wildScripted` / `legendary`
  flags and exempts `roamer`. It does not ban ordinary wilds based
  merely on a species name; Shiny Clause cannot override it.
- No Fishing guards native `Field.startFishing` and the fallback
  `Field.tryFishingEncounter` call. It does not remove fishing rods,
  block unrelated water encounters or modify the engine's fishing data.
- Town Catches is checked before an encounter can claim a route's first
  attempt, and rechecked at the Poké Ball transaction. Town catches are
  therefore ineligible while OFF, including with Failed Encounters ON.
- RANDOM Alphabetlocke chooses from initials represented in the active
  native National Dex registry (1–386) and persists the chosen letter in
  `statusBans`-independent `catchRules.alphabetlocke_random_letter`.
  Changing Alphabetlocke mode resets that stored choice. The selector
  is visible in the menu after resolution as `RND:X`.
- **Scripted gifts** are checked in the Gen 3 `script.command` pre-transaction
  hook. On denial, the normal `givemon` opcode does not run and the VM
  receives its native unsuccessful delivery result (`VAR_RESULT = 2`).
  Native scripts still own their own dialogue, flags and retry handling.
  The mandatory opening starter at Oak's Lab / the Route 101 rescue
  remains obtainable even when optional gifts are disabled.
- **NPC in-game trades** use the native
  `GetInGameTradeSpeciesInfo` script special for early rejection: its
  dialogue strings are left available but the requested species is
  replaced with 0, so an ordinary party Pokémon cannot match.
  The actual `Trade.tradeMons` mutation is also guarded; a completed
  swap is the only event counted as a received trade. Linked trades
  are not handled by this NPC-only rule.
- **AREA vs BONUS:** AREA applies the same physical-map key as wild
  encounters, and only commits a spent map entry following a successful
  gift or exchange; an unsuccessful / prohibited transaction does not
  spend a slot. BONUS logs the receipt without consuming the wild slot.
  Both modes retain successful `acquisitionHistory` provenance and
  mark the received species for Dupes Clause. With One Per Area OFF,
  AREA cannot block a transaction based on old route slots.
- Existing species restrictions (Legendary, Mythical, pseudo, BST and
  Alphabetlocke where a canonical name is available) also gate these
  supported new acquisitions. Gifts/trades produced by external mods
  through unrelated transaction APIs are **not** intercepted.
  Since the Gen 3 `pokemon.before_give` event does not honour veto,
  a different mod changing the species after our preflight needs
  separate compatibility testing; no destructive rollback is attempted.
- No changes are made to already-owned Pokémon retroactively.
  Gift/Trade scripts and PC-capacity handling remain native.

### Still [Soon]

Overworld encounters, PKMN BAN, Colorlocke and its colour.
All remaining ADVANCED RULES categories remain [Soon]; unsupported
rows are not editable.

## Manual verification

1. On a disposable save, enable CORE → NUZLOCKE. Enter CATCH RULES.
   Toggle each of the three species bans, No Static Encounters and
   No Fishing, then cycle MAXIMUM BST. Save, restart, and confirm all
   settings persist.
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
8. With No Fishing ON, use each rod in a valid fishing location.
   Confirm the rod attempt never begins and NUZ NOTICES explains why.
   Turn the rule OFF and confirm the native fishing minigame returns.
9. With No Static ON, attempt a scripted encounter (e.g. a legendary
   encounter on an unused route) and throw a Ball. The battle still
   proceeds normally, but capture is blocked and the route slot stays
   available. A roamer and an ordinary wild must remain unaffected.
10. Test Town Catches OFF and ON with a wild encounter on a town/city
    map and a route. OFF must prevent the town catch without using the
    area slot; ON must permit it subject to normal One Per Area rules.
    Check a Sevii settlement and an interior separately.
11. Test Alphabetlocke CHOOSE with e.g. L: Latias should be eligible
    (unless another catch ban forbids it), Salamence should be rejected.
    Switch to RANDOM; confirm a stored letter is shown after first wild
    encounter and remains fixed across reload. Changing mode resets it.
12. With Allow Glitches OFF, test a deliberately invalid/unregistered
    species from a developer/provider fixture; it must be rejected.
    ON permits it unless another rule blocks it. Ordinary Hoenn IDs
    must remain legal.
13. Set **Gift Pokémon = OFF** on a disposable save, attempt an
    optional scripted gift (e.g. the Celadon Eevee). No new Pokémon
    should enter party/PC and the game should remain playable. Then
    re-enable gifts, obtain it, and confirm exactly one receipt.
    Confirm the compulsory opening starter still works with gifts OFF.
14. Check Gift Slot **AREA**: receive a gift on an unused map, then
    verify a wild catch there is blocked by One Per Area. On a fresh
    map, select **BONUS** and verify the gift does not consume its
    encounter slot. Check unsuccessful full-PC delivery does not claim it.
15. In a native NPC trade, set **In-Game Trades = OFF** and confirm
    the exchange never takes your offered Pokémon. Enable it, set
    Trade Slot **AREA**, complete an NPC trade and confirm the source
    map slot is spent. Repeat on a fresh map with **BONUS** and
    confirm the map's normal slot remains available. Test FRLG and RSE.
16. Verify prohibitions from Legendary/Mythical/pseudo/BST/Alphabetlocke
    apply to supported optional gifts and received NPC trade Pokémon.
17. Verify unported Catch Rules, including Colorlocke, species picker
    and Overworld, remain [Soon].

The automated smoke suite is not a substitute for exact-edition ROM
testing in FireRed, LeafGreen, Ruby, Sapphire and Emerald.
