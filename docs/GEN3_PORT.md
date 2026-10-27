# Gen 3 port — experimental foundation

This branch does **not** port Nuzlocke's full Gen 1/2 feature set. It introduces a separate Gen 3 implementation, selected by `entry.lua`, while the established `main.lua` remains the entry for Red, Blue, Yellow, Gold, Silver and Crystal.

## Implemented

- Opt in through the in-game Start menu (**NUZLOCKE: OFF / ON**).
- Mark the first wild battle on each **native map ID** as the area's attempt, even if the wild Pokémon flees or faints.
- Reject subsequent catch rolls on the same map through Gen1Recomp's Gen 3 `catch.rate` hook (Balls are still consumed by the native action).
- Record successful captures, and after each battle remove zero-HP Pokémon from the native party into a save-local Nuzlocke graveyard record.
- Mark the run failed when the party becomes empty.
- Keep the feature disabled by default and store data under `gen3_classic_v1`, separate from the Gen 1/2 save schema.

## Not yet implemented / known gaps

- The original mod's rule configuration, profiles, setup, encounter tracker UI, advanced death/forgiveness rules, randomiser, shiny clauses, gift/statics, species clauses, custom UIs and public compatibility API.
- The tracker currently treats each native **map ID** as a separate catch area. Canonical Nuzlocke locations (for example different floors of one cave) need a region/section mapping.
- Fainting followed by a revive **inside the same battle** can escape post-battle death detection; this requires a confirmed player-side Gen 3 faint event contract.
- The graveyard contains metadata, not a PC-stored recoverable Pokémon. Retirement changes the native session party; back up saves before testing.
- No game/ROM runtime certification yet. The mock test checks local hook and state logic only. FireRed, LeafGreen, Ruby, Sapphire and Emerald require independent boots/tests.

## Testing

Run from the repository root:

```sh
lua5.1 tests/gen3_foundation_smoke.lua
python3 tools/modkit.py gen3check /path/to/this/mod
```

The `modkit.py` command is part of **Gen1Recomp**, not this mod repository; the second command must be run in the engine checkout and pointed at the installed Nuzlocke mod folder.

After that: import a legitimate Gen 3 ROM into Gen1Recomp, enable the Nuzlocke mod, start a **new** game, switch NUZLOCKE ON as early as possible, catch or miss a wild Pokémon, test repeated Balls in the same map, test a second map, and test fainting with a backed-up save. Do **not** treat a passing mock test as runtime certification.

## Compatibility contract

The mod remains API 2 because the existing Gen 1/2 runtime is API 2. The manifest declares `gen3` so the engine may load it, while `entry.lua` dispatches to `gen3_runtime.lua` in Gen 3. This is intentionally a reduced experimental runtime, not an assertion that every Nuzlocke setting works on Gen 3.
