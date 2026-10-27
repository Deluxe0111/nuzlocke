# Gen 3 Randomiser — first working slice

The native Gen 3 Nuzlocke menu now exposes a deterministic species
randomiser for **wild step encounters, fishing, and trainer parties**.
It does **not** require Nuzlocke Enabled to be ON.

All other Randomizer settings in the legacy catalogue are marked **[Soon]**.
They are not silently enabled: starter choices, static/gift/roaming Pokémon,
items, learnsets, TM moves, shops, evolution targets and other systems
remain native until their own implementations are verified.

## Menu and configuration

Start > NUZ MENU > NUZ RULES > RANDOMIZER

| Setting | Values | Default |
| --- | --- | --- |
| Preset | CUSTOM / CHAOS / BALANCED | CUSTOM |
| Random Wild | OFF / ON | OFF |
| Random Trainers | OFF / ON | OFF |
| Wild Balance | CHAOS / SIM BST (when Wild ON) | CHAOS |
| Trainer Balance | CHAOS / SIM BST (when Trainers ON) | CHAOS |
| Species Pool | ALL / KANTO / JOHTO / HOENN | ALL |
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

**Settings lock at the first successful randomised species result.** This
avoids mixing incompatible rules in a single run. To start a genuinely new
randomiser configuration, start a new disposable run/save; Nuz Dev must not
silently relabel already generated content.

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

Roamers retain persistent identities. Scripted/static wild encounters do
not pass through the ordinary step encounter hook, so remain native.

Candidate species are pulled from the **actual installed Gen 3 Pokémon
registry**, not an assumed contiguous National Pokédex. Candidates require
a valid national species number (1–386), nonempty native species name
and valid positive base stats. Invalid/glitch/empty internal slots are
excluded. Any missing original or empty legal candidate pool falls back to
the native species rather than risking a broken encounter.

SIM BST first looks for replacements within 15% of the original Pokémon's
base-stat total, widens to 25%, then 40%, before accepting the safe pool.
The native named stat fields `hp,atk,def,spe,spa,spd` are used.

The source namespaces `ENCOUNTERS` and `TRAINERS` use independent
portable integer hashing (algorithm version 1), not `math.random`
per roll. Enabling Trainer Randomiser must not move wild mappings or vice
versa, and revisiting a source yields the same result. A mapping depends
on source key, original Pokémon, settings, seed, algorithm, and ROM data.

## Important current limitations

- This first stage randomises **rolled species**, not a visual edit of
  the entire ROM encounter table. Species sharing identical map/terrain/
  original-species/level source identity will share the replacement.
- There is no DIVERSE/UNIQUE source-slot policy yet; those rows are
  intentionally [Soon].
- Native fishing and trainer hooks are used; third-party randomiser
  ownership has not been arbitrated yet. Do not enable two mods that both
  rewrite the same sources until their precedence is tested.
- Randomised trainer teams keep their authored moves and items; abilities
  and stat creation stay under the engine's native construction.
- Randomisation of scripted wilds, static legendaries, gifts, starter
  selection and rival-starter lineage requires further native integration.
- There is currently no safe mid-run configuration reset/migration.
- This is an experimental native-Gen 3 feature. Gen 1/2 paths are unchanged.

## ROM regression checklist (back-up/disposable save)

- [ ] **R01:** With Nuzlocke OFF but Random Wild ON and seed 12345678,
      encounter a wild Pokémon. Verify a safe replacement with original
      encounter level, ball/catch handling and item metadata.
- [ ] **R02:** Reload an unchanged save with the same seed/settings; on the
      same map/species source verify the same replacement.
- [ ] **R03:** Wild OFF restores ordinary species (on a fresh run/save).
- [ ] **R04:** Fish with Old/Good/Super Rod. Verify a random species at
      native levels, without changes to successful bite/rod probabilities.
- [ ] **R05:** Trainer ON: battle ordinary trainer, rival and Gym Leader.
      Check party size, trainer identity, levels, items, moves and defeat
      flags are preserved; no crash in single/double battles.
- [ ] **R06:** Trainer OFF and Wild ON: trainer teams native. Repeat with
      toggles reversed; wild replacements unaffected by Trainer ON.
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
