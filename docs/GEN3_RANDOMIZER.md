# Gen 3 Randomizer — Phase 1

The new **NUZ MENU → NUZ RULES → RANDOMIZER** page currently implements:

- **SEED**: eight editable decimal digits, fixed and shareable (0 = no randomization); press A on each digit to advance it. CLEAR SEED resets to 00000000.
- **WILD**: replaces species in native normal land/water encounters through `encounter.species`.
- **TRAINERS**: replaces party members through the native `trainer.party` composition hook.

Other existing Gen 1/2 settings remain visible as **Soon** so unsupported settings never pretend to be active.

## Determinism and compatibility

Mappings are keyed by a numeric seed and independent WILD / TRAINER stream labels, with no calls to global RNG. Revisiting an encounter source yields the same replacement for the same map / terrain / original species / level. Trainer replacements derive from exact trainer ID and party slot and are stable between replays. Different editions, engine registries or source trainer edits can produce different mappings for the same seed.

The Randomizer operates *independently of Nuzlocke Enabled*. Normal wild encounter rates/levels and native trainer levels, held items, slot order, and team sizes remain unchanged. Scripted, legendary-flagged and roaming encounters are not changed. Original encounter or trainer parties are not mutated by the mod. If the species registry is unavailable, the original is retained.

This is deliberately a first functional slice: fishing, starters, trainer balance and diversity, field items, shops, TMs, learnsets, gifts and evolutions are NOT implemented yet. It does not yet claim compatibility/ownership with other species-randomising mods; avoid running two randomisers on the same hook until arbitration is developed.

## Manual in-game testing

- [ ] R01: Set seed to 00000000, enable WILD and TRAINERS. No species changes (0 is disabled).
- [ ] R02: Set seed 12345678 and WILD ON. Repeated grass encounters on one map keep stable replacements for the same native slot.
- [ ] R03: Reload the same save with 12345678; the same encounter source maps to the same species.
- [ ] R04: Change seed to 12345679; encounter replacements should change on at least some maps.
- [ ] R05: WILD OFF immediately returns native encounters without modifying encounter slots / saved Pokémon.
- [ ] R06: TRAINERS ON changes ordinary opponent species but preserves levels, party size and held items.
- [ ] R07: Trainer rivals, Gyms and Elite Four retain game story progression, native moves and battle construction.
- [ ] R08: Roamers and scripted story wild encounters remain untouched.
- [ ] R09: Test FireRed / LeafGreen / Ruby / Sapphire / Emerald editions on disposable saves.
- [ ] R10: Confirm the Randomizer works with Nuzlocke Enabled OFF; no encounter restrictions should be imposed.
- [ ] R11: Confirm no crashes when native species metadata is unavailable or a party contains an unusual form.
- [ ] R12: Check compatibility with Difficulty and other mods altering trainer parties, **without** enabling a second randomizer.

Automated Lua tests cover deterministic policy and the Gen 3 native hook contracts. ROM, progression and other-mod integration still require manual testing.
