# Gen 3 Randomiser — v3.0.0-BETA

The native Gen 3 Nuzlocke menu now exposes a deterministic species
randomiser for **starter choices, static encounters, scripted gifts,
NPC gift eggs, visible/hidden field items, ordinary Poké Marts,
wild step encounters, fishing and trainer parties**.
It does **not** require Nuzlocke Enabled to be ON.

All other Randomizer settings in the legacy catalogue are marked **[Soon]**.
They are not silently enabled: roaming Pokémon, non-scripted gifts,
scripted NPC item gifts, learnsets, TM moves, shops, evolution targets
and other systems
remain native until their own implementations are verified.

## Menu and configuration

Start > NUZ MENU > NUZ RULES > RANDOMIZER

| Setting | Values | Default |
| --- | --- | --- |
| Preset | CUSTOM / CHAOS / BALANCED | CUSTOM |
| Random Wild | OFF / ON | OFF |
| Random Trainers | OFF / ON | OFF |
| Random Starters | OFF / ON | OFF |
| Random Static | OFF / ON | OFF |
| Static Balance | CHAOS / SIM BST (when Static ON) | CHAOS |
| Random Gifts | OFF / ON | OFF |
| Random Eggs | OFF / ON | OFF |
| Gift Balance | CHAOS / SIM BST (when Gifts or Eggs ON) | CHAOS |
| Random Field Items | OFF / ON | OFF |
| Item Balance | CHAOS / SIM VALUE (when Field Items ON) | CHAOS |
| Item Variety | NORMAL / UNIQUE AREA (when Field Items ON) | NORMAL |
| Random Shops | OFF / ON | OFF |
| Shop Balance | CHAOS / SIM VALUE (when Shops ON) | CHAOS |
| Starter Balance | CHAOS / SIM BST (when Starters ON) | CHAOS |
| Wild Balance | CHAOS / SIM BST (when Wild ON) | CHAOS |
| Wild Variety | NORMAL / UNIQUE AREA (when Wild ON) | NORMAL |
| Trainer Balance | CHAOS / SIM BST (when Trainers ON) | CHAOS |
| Species Pool | ALL / KANTO / JOHTO / HOENN | ALL |
| Trainer Variety | NORMAL / UNIQUE TEAM | NORMAL |
| Seed | 8-digit FIXED or AUTO (00000000) | AUTO |
| Run Seed | Effective fixed/resolved seed (read-only) | NOT ROLLED |
| Config | EDITABLE / LOCKED | EDITABLE |

**CHAOS preset** enables both randomisers, all species and no BST band.
**BALANCED preset** enables both, all species and the similar-BST candidate
policy. Changes to individual options return the Preset row to CUSTOM.

In the **8-digit seed editor**, each digit can be incremented independently
with A, then APPLY SEED. USE AUTO restores AUTO mode. The run's actual
AUTO seed is resolved at its first successful randomisation and persisted
inside the Gen 3 save, so restarting/reloading continues the same mapping.
A fixed seed 1–99999999 reproduces mappings across equivalent versions of
the ROM species registry and equivalent randomiser settings.

**Random Starters** rolls three distinct eligible species using the same
run seed and installed Gen 3 species pool, with optional SIM BST balance.
In Ruby/Sapphire/Emerald the starter bag reads the replacement directly:
label, portrait, cry and the Pokémon added to the party all use the same
selection. In FireRed/LeafGreen the Oak-lab script's initial starter/rival
species variables are replaced *before* the scripted portrait, dialogue
and `givemon` actions. The `GetStarterSpecies` resolver uses the
same persisted three choices for subsequent queries. Native starter selection indices and VAR_STARTER_MON remain
unchanged for progression.

The rival's starter remains linked through its **entire native evolution
progression**, including larger multi-Pokémon parties and late-game rematches:
FireRed/LeafGreen rival and Champion battles, and Brendan/May's scripted
Ruby/Sapphire/Emerald story battles. Only known ROM story rival IDs and
the original starter evolutionary line are eligible; Wally and unrelated
trainer Pokémon remain untouched by this override. This works whether
Random Trainers is ON or OFF.

The rival replacement follows its own real evolution data. For example, a
two-stage replacement can evolve when the original rival starter reaches its
second form. A Pokémon with no further evolutions stays the same species;
the mod does **not** invent unrelated evolution stages. Branching evolution
choices are deterministic from the run seed and stored starter slot.
An unavailable or disallowed evolved form leaves the last valid form in
place. Other scripted gifts, static wilds and roaming Pokémon are unchanged.
All three selections are allocated together and saved, rather than rerolled
on screen navigation. A missing/unsafe candidate leaves the original starter
trio unchanged. As with other randomiser options, the first successful
generation locks configuration. Enable this on a fresh new-game setup.

**Wild Variety: UNIQUE AREA** allocates different replacements for different
native species within the same **map and encounter method** where possible.
Grass/step terrain, each fishing rod and Untamed's land/water wandering
sources use separate scopes: these do not silently reassign an existing
source. All levels of the same original Pokémon in one scope map to the same
replacement. Assignments are saved, so exiting/re-entering the route or
loading a save keeps that species. Once all legal candidates for a scope
have been allocated, repeats are permitted rather than introducing an
invalid species or cancelling an encounter. The saved source-to-species
assignments mean that **the first-discovery order can affect new mappings**
in UNIQUE AREA mode: a fixed seed alone does not reproduce every assignment
across fresh saves if sources were first encountered in a different order.
NORMAL retains the old stateless source-key mapping, fully unchanged.

**Trainer Variety: UNIQUE TEAM** chooses trainer replacements without repeating
species already assigned to earlier members of that same trainer party. It
preserves slot count, levels, items and moves. If a restricted pool has no
unused replacement for a slot, that slot falls back to ordinary deterministic
randomisation. NORMAL is the existing mapping behaviour. This setting only
affects trainers; wild and Untamed mappings are unchanged.

**Settings lock at the first successful randomised species result.** This
avoids mixing incompatible rules in a single run. To start a genuinely new
randomiser configuration, start a new disposable run/save; Nuz Dev must not
silently relabel already generated content.

## Ordinary Poké Mart inventory

**Random Shops** runs when the native `ShopMenu.show` receives a
regular mart's extracted ROM stock list. The original mart entry and
its pointers stay untouched. Each **map + mart pointer** gets a stable,
persistent list of replacements: revisiting, saving or reopening the
shop never changes its stock. Changing unrelated randomiser categories
does not perturb its `SHOPS` hash stream.

The default **CHAOS** mode draws from the valid positive-price
consumable/ball/berry pool. **SIM VALUE** prefers roughly comparable
native item prices, widening the price range when needed. Different
replaceable slots do not reuse an item in the same shop if there are
enough safe choices. Buy prices, money deductions, bag checks, in-bag
counts, selling and transaction records all remain native.

**Poké Ball (item ID 4)** is always kept if present in a mart's
original stock, so randomising shops cannot remove the primary early
Poké Ball supply. Key Items, TMs/HMs, zero-price/story entries and
missing item metadata remain native and are excluded as replacement
choices. Decoration shops are untouched: they have a different item
ID namespace. Shops with unidentified ROM pointers fail open rather
than claiming potentially unrelated inventories.

This option is independent from Random Field Items and the Nuzlocke
toggle, though existing Shop Restrictions still apply to buying and
selling. Item gifts, prizes, and other purchases outside ordinary
Poké Mart inventory do not pass through this hook.

## Visible item balls and hidden field items

**Random Field Items** uses the native `STD_FIND_ITEM` item-ball
transaction, plus the FRLG/RSE hidden-item pickup functions. It changes
the species-independent **item identifier**, not the map script, item ball
flag, bag contents after award, or displayed pickup text. Both visible
and hidden item names are supplied by the native item-award UI after the
replacement is chosen. Quantity, full-bag failures, pickup disappearance
and save persistence remain native.

Safe replacements are drawn from the active Gen 3 ROM item pack, limited
to real, positive-price regular items, Poké Balls and berries. Key Items,
TM/HMs, zero-price/important items, unknown IDs and required story
objects are neither replaced **nor eligible as replacements**.
`ITEM BALANCE: CHAOS` permits any other eligible item, and
`SIM VALUE` prefers replacements of approximately comparable shop price.

All pickups use a separate deterministic `FIELD_ITEMS` seed stream.
Their individual map/script or hidden-item flag is stored with the
run's assignment. `ITEM VARIETY: NORMAL` may repeat replacement items;
`UNIQUE AREA` prefers unused items across visible and hidden pickups
within the same map until the safe replacement pool is exhausted.
Story item scripts that use `STD_OBTAIN_ITEM`, shop purchases,
trainer rewards, and items generated in battle are not affected.

FRLG's Itemfinder underfoot hidden pickups are supported too. Pokémon
FireRed/LeafGreen and Ruby/Sapphire/Emerald use different hidden-item
native branches; both are intercepted before they enter the bag.
Unknown or unsafe map/script contexts fail open to the original item.
The setting defaults OFF and is independent of Nuzlocke Enabled.

## Scripted static encounters and gifts

**Random Static** replaces the species supplied by native `setwildbattle`
and `CreateEnemyEventMon`. The script continues to control its original
encounter level, battle transition, items, story flags and post-battle
progression. The Pokémon Tower Marowak ghost and first-battle/tutorial
sequences stay native. Static encounters use a deterministic, separate
`STATIC` seed stream keyed by map, script, original species and level.
Natural roamers remain untouched.

**Random Gifts** changes only the native scripted `givemon` opcode.
It includes scripted gift Pokémon (including NPC fossil rewards when they
use this opcode), not in-game trades, day-care breeding or mystery gift
delivery. Oak's and Birch's starters remain solely owned by **Random
Starters**. The native `pokemon.before_give` event and Nuzlocke gift
restrictions still run against the replacement species. The code retains
the original gift level, held item and party/PC delivery.

**Random Eggs** affects only NPC egg gifts using the scripted `giveegg`
opcode. Day Care and breeding egg generation are unchanged. Both gifts
and scripted eggs use the **Gift Balance** setting but separate `GIFTS`
and `EGG_GIFTS` seed namespaces. Scripted event dialogs rendered before
the award may still mention the original Pokémon; the actual received
species is consistent with later variable-backed text when the VM exposes
the relevant variable. No source save/ROM tables are rewritten.

All three options default **OFF** and operate independently from Random
Wild, Random Trainers, Random Starters and Nuzlocke Enabled. If the native
ROM species registry is missing or the legal pool is empty, the script
uses the original species.

## Native hooks and guarantees

- `encounter.species`: uses the native encountered species, map, terrain
  and level as a stable source key; replacements preserve rolled encounter
  rate, level, fields, held item and other metadata.
- `encounter.fishing`: independently covers Old/Good/Super Rod rolled
  encounters without changing odds, pool weights or levels.
- `trainer.party`: preserves trainer ID/class, number and ordering of team
  members, all authored member levels, held items and move slots. Replaces
  species on a copy after the native/other provider's party is obtained.

Existing trainer moves are preserved in this first slice. They may not
match the replacement species' natural learnset; move randomisation and
moveset regeneration are separate future features.

Roamers retain persistent identities. Scripted/static wild encounters
use separate native script-command hooks; ordinary step encounters never
change them when Random Static is OFF.

Candidate species are pulled from the **actual installed Gen 3 Pokémon
registry**, not an assumed contiguous National Pokédex. Candidates require
a valid national species number (1–386), nonempty native species name
and valid positive base stats. Invalid/glitch/empty internal slots are
excluded. Any missing original or empty legal candidate pool falls back to
the native species rather than risking a broken encounter.

SIM BST first looks for replacements within 15% of the original Pokémon's
base-stat total, widens to 25%, then 40%, before accepting the safe pool.
The native named stat fields `hp,atk,def,spe,spa,spd` are used.

The source namespaces `ENCOUNTERS`, `TRAINERS`, `STATIC`, `GIFTS`,
`EGG_GIFTS` and `FIELD_ITEMS` use independent
portable integer hashing (algorithm version 1), not `math.random`
per roll. Enabling Trainer Randomiser must not move wild mappings or vice
versa, and revisiting a source yields the same result. A mapping depends
on source key, original Pokémon, settings, seed, algorithm, and ROM data.

## Important current limitations

- This first stage randomises **rolled species**, not a visual edit of
  the entire ROM encounter table. Species sharing identical map/terrain/
  original-species/level source identity will share the replacement.
- UNIQUE AREA avoids repeats within a map/method when there are enough
  valid candidates, but it does not pre-randomise the entire ROM encounter
  table. Discovery order can affect freshly allocated replacements.
  Trainer Variety's UNIQUE TEAM policy applies only within one trainer party.
- Native fishing and trainer hooks are used; third-party randomiser
  ownership has not been arbitrated yet. Do not enable two mods that both
  rewrite the same sources until their precedence is tested.
- Randomised trainer teams keep their authored moves and items; abilities
  and stat creation stay under the engine's native construction.
- Scripted encounters created by other specials/engine-only pathways
  and mystery gift delivery may still be native. Rival starter evolution
  uses the actual ROM evolution graph, not species ID offsets.
- There is currently no safe mid-run configuration reset/migration.
- This is an experimental native-Gen 3 feature. Gen 1/2 paths are unchanged.

## Untamed-Advanced visible wild Pokémon

Untamed-Advanced's wandering Pokémon bypass the native Gen 3
`encounter.species` hook. The new optional `untamed.owe.species`
integration randomises these **before the visible sprite, cry, and battle
Pokémon are constructed**, so the species seen roaming matches the one
fought and caught. It uses existing **Random Wild**, run seed, Gen 3
species pool/generation filter and encounter balance; there is no
separate overworld toggle.

Mapping keys include an `OWE` discriminator, map ID, land/water
terrain and original wild species (not spawn coordinates). Thus the
same authored Pokémon on the same route retains the same random
appearance on subsequent spawns, without changing the existing random
step or fishing mappings.

Only normal generated wild OWEs are eligible. Untamed protects roamers,
Feebas, mass outbreaks and manually scripted wilds, and validates
sprite availability before using a replacement. Followers are not
randomised. Untamed's encounter-chain **name and count follow the actual visible
species defeated**, not the underlying authored encounter slot. For
example, defeating Feraligatr from a native Rattata slot shows
**Feraligatr chain x3**, not Rattata. Untamed retains the original
Rattata slot only for the weighted repeated-spawn source. This
corrected chaining behaviour requires the updated Untamed build.

**Both updated mods must be installed**. Updating Nuzlocke alone cannot
alter wandering species created internally by older Untamed builds.
The integration is safe when Untamed is absent (no hook caller).

### Untamed ROM regression checks

- [ ] **U01:** Enable Random Wild with a fixed seed. Ordinary wandering
      land/water Pokémon should change species.
- [ ] **U02:** Walk into a randomised sprite. The battle opponent (and a
      successful capture) must be the same species as the visible sprite.
- [ ] **U03:** Leave/re-enter a route and reload. For the same authored
      source, the same random species should appear regardless of tile.
- [ ] **U04:** On a fresh run, set Random Wild OFF. Wandering wild species
      should be the native authored Pokémon.
- [ ] **U05:** Verify Nuzlocke One Per Area, Failed Encounters, Dupes and
      Permadeath also work against wandering opponents.
- [ ] **U06:** Roamers, Feebas/outbreaks and player followers remain
      untouched. Test wandering encounter chaining.
- [ ] **U07:** Run without Untamed installed: ordinary grass/fishing
      randomisation still behaves as before.
- [ ] **U08:** Repeat representative checks on FRLG, Ruby/Sapphire and
      Emerald using disposable saves.

## Untamed-Advanced overworld shiny odds

**CLAUSES → SHINY RATE** also applies to Untamed's ordinary generated
wandering Pokémon, independently of the Random Wild toggle. The new
optional `untamed.owe.shiny` hook runs after Untamed's native personality
and encounter-chain checks but before assigning the world sprite.

Nuzlocke uses the same increased-odds calculation as ordinary Gen 3
wild battles and asks Untamed to turn a successful roll into a genuine
shiny personality. The overworld palette, sparkle, non-despawn setting,
wild battle and captured Pokémon then all agree on shininess. The
already-spawned Pokémon is remembered so Nuzlocke does **not** reroll
it again when battle starts. Untamed's native chain shiny boost is
preserved and can exceed the configured base shiny rate.

No shiny rate is added to special roamers, Feebas, outbreaks, scripted
actors or followers. Install both updated mods; the hook is optional and
the native overworld behaviour remains unchanged without a provider.
This also works with Random Wild OFF and Nuzlocke Enabled OFF.

**Test:** Set Shiny Rate ALWAYS on a disposable save and check that
wandering Pokémon are visibly shiny *before* interacting; they remain
shiny in battle and capture. At a lower rate, visible non-shinies stay
non-shiny in battle. Spawn a non-shiny at NATIVE, then change to ALWAYS
before touching it: the existing individual should not change.
Check Untamed's ordinary chain shinies still behave normally.

## ROM regression checklist (back-up/disposable save)

- [ ] **S01:** Start a *fresh* FRLG save with Random Starters ON.
      Oak's lab selection and the acquired starter must be the same
      replacement (including correct species, stats and starting moves).
- [ ] **S02:** On a fresh Ruby, Sapphire and Emerald save, the three
      bag labels, portraits, cries and actual starter must match.
      Reject a starter choice and reselect: it must not reroll.
- [ ] **S03:** Verify opening, middle and Champion/rematch rival battles
      track the same random starter line, even with Random Trainers OFF.
      Check a two-stage evolutionary line, a single-stage species and
      a branched evolution. Other party slots and Wally stay native.
- [ ] **S04:** Repeat with fixed seed, with STARTER BALANCE SIM BST,
      and with an empty/restricted pool. Other gifts must be unchanged.
- [ ] **S05:** With Random Starters OFF, verify all native starting
      Pokémon and rival teams remain unchanged. With both Random Starters
      and Random Trainers ON, the rival's starter retains its lineage
      while every other trainer team member still randomises normally.
- [ ] **M01:** On a new run, enable Random Shops. In an early
      Poké Mart check Poké Balls remain available if originally stocked,
      while other regular items may be replaced. Check replacement prices.
- [ ] **M02:** Revisit the same mart, reload, and repeat in Emerald.
      The stock list must remain identical for its saved map/pointer.
- [ ] **M03:** Check SIM VALUE, item uniqueness, and preserved Key
      Items/TMs/HMs. Decoration shops and mart data are unchanged.
- [ ] **M04:** Check native Shop Restrictions still deny purchases
      when configured. Sales, quantity, bag-full errors and money
      handling remain native.
- [ ] **F01:** On a fresh FRLG run, turn on Random Field Items.
      Pick up two visible item balls: the awarded/announced item names
      must match the inventory, and collection flags persist on reload.
- [ ] **F02:** Repeat with hidden items in FRLG and RSE, including an
      underfoot Itemfinder item. A full bag must not consume the item flag.
- [ ] **F03:** Verify Key Items, TM/HMs and special story pickups
      remain native, even if field item randomisation is ON.
- [ ] **F04:** Verify SIM VALUE and UNIQUE AREA independently; identical
      seeds/settings replay the same choices after save/load. Normal
      Wild/Trainer/Starter streams must be unaffected.
- [ ] **F05:** With Random Field Items OFF, all item pickups must be
      unchanged; NPC item gifts and shop purchases remain native.
- [ ] **G01:** With Nuzlocke OFF and Random Static ON, fight a scripted
      legendary; the battle should use the same species on every reload.
      Level, item, transition, and the associated story flag must remain.
- [ ] **G02:** With Random Static OFF, confirm ordinary wild randomisation
      does not change static encounters. The Tower ghost is always native.
- [ ] **G03:** With Random Gifts ON, collect an optional NPC Pokémon or
      resurrected fossil. Confirm level, held item, party/PC transfer,
      and Nuzlocke gift restrictions. Reload for seed consistency.
- [ ] **G04:** With Random Eggs ON, receive an NPC gift egg. Confirm it
      contains the randomised species and that Day Care breeding is
      unchanged. Check the ordinary gift toggle does not affect eggs.
- [ ] **G05:** With both Random Starters and Random Gifts ON, verify
      Oak/Birch selection remains tied to the starter trio, not a
      second randomised gift. Other story scripts must remain functional.
- [ ] **R01:** With Nuzlocke OFF but Random Wild ON and seed 12345678,
      encounter a wild Pokémon. Verify a safe replacement with original
      encounter level, ball/catch handling and item metadata.
- [ ] **R02:** Reload an unchanged save with the same seed/settings; on the
      same map/species source verify the same replacement.
- [ ] **R03:** Wild OFF restores ordinary species (on a fresh run/save).
- [ ] **R04:** Fish with Old/Good/Super Rod. Verify a random species at
      native levels, without changes to successful bite/rod probabilities.
- [ ] **R04a:** Wild Variety UNIQUE AREA: distinct original Pokémon on
      the same route/terrain should be different when the pool permits.
      Different levels of one original retain the same replacement.
      Reload the save and revisit: every allocated replacement persists.
      Verify fishing rods and Untamed land/water each have independent
      variety scopes. NORMAL should reproduce the old fixed-seed mapping.
- [ ] **R05:** Trainer ON: battle ordinary trainer, rival and Gym Leader.
      Check party size, trainer identity, levels, items, moves and defeat
      flags are preserved; no crash in single/double battles.
- [ ] **R06:** Trainer OFF and Wild ON: trainer teams native. Repeat with
      toggles reversed; wild replacements unaffected by Trainer ON.
- [ ] **R06a:** With Trainer Variety UNIQUE TEAM, a trainer with two or more
      Pokémon should have no duplicate replacements when its legal pool
      has enough candidates. Reload to confirm identical team composition.
      Test a tiny restricted pool for safe duplicate fallback.
- [ ] **R07:** Select CHAOS and BALANCED presets. SIM BST replacement
      should fall near original BST if valid candidates exist.
- [ ] **R08:** Species Pool KANTO, JOHTO, HOENN; no Pokémon outside the
      selected National Dex range should appear.
- [ ] **R09:** Edit every seed digit, APPLY, go back and verify the exact
      displayed value; set AUTO and confirm one saved resolved run seed
      after the first randomised encounter.
- [ ] **R10:** After first replacement, toggles/seed should not mutate;
      the menu should explain that configuration is locked.
- [ ] **R11:** Encounter a naturally roaming Pokémon and scripted static
      encounter. Their persistent identity must be preserved.
- [ ] **R12:** With Nuzlocke ON, random wild species should still obey
      One Per Area, Dupes and Shiny clauses; trainer IDs should still
      work with First Rival Mercy and League cap progression.
- [ ] **R13:** Check supported editions separately: FireRed, LeafGreen,
      Ruby, Sapphire and Emerald.
- [ ] **R14:** Keep other species-rewriting mods OFF until hook-order and
      ownership interactions are specifically validated.

Automated tests exercise deterministic streams, pool safety, configuration
locking, mocked native hook composition and the new menu. They cannot
validate actual ROM UI and story transitions.
