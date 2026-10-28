# Generation 3 playstyles — Shiny Nuzlocke

**Version:** v3.0.0-BETA · **Menu:** Start → NUZ MENU → NUZ RULES → PLAYSTYLES

**SHINY NUZ** is an optional challenge variant. Default **OFF**. It is
enforced only while **CORE → NUZLOCKE** is ON and the run is active.

## Catch rules

1. **Only shiny wild Pokémon can be caught.** Throwing a Ball at a
   non-shiny always fails and shows **“Shiny Nuzlocke: only shiny Pokémon
   can be caught. Your route chance remains open.”** The normal native Ball
   use still occurs. The denial is also saved under NUZ NOTICES.
2. **Non-shiny encounters never use a route opportunity**, even with
   Failed Encounters Count ON. You can keep searching until you encounter
   an eligible shiny.
3. **An eligible shiny becomes that area's encounter.** If One Per Area
   and Failed Encounters Count are both ON, meeting an eligible shiny uses
   the route immediately, whether you catch it, KO it or flee.
4. With **Failed Encounters OFF**, a shiny encounter doesn't close its
   route unless it's successfully caught; you may search for another.
5. With **One Per Area OFF**, any number of eligible shinies may be caught,
   but non-shinies remain prohibited.
6. **Dupes and Roamer Clause still apply.** A shiny already excluded by
   Dupes is not an eligible route encounter. Roamer Clause retains the
   roamer's species-specific slot.
7. **Shiny Clause does not grant extra catches** while Shiny Nuzlocke
   is enabled, even when Shiny Clause is set to UNLIMITED. Otherwise the
   variant would effectively disable One Per Area. The Shiny Clause
   setting remains saved and becomes effective again when the playstyle
   is OFF.

### Important: Shininess versus shiny odds

Shiny Nuzlocke decides *what is legal to catch*. It does **not** change
shiny odds or automatically turn everything shiny. The optional
**CLAUSES → SHINY RATE** setting is separate (NATIVE, increased odds,
or ALWAYS). External shiny providers still own their effects where
supported; the playstyle checks the wild Pokémon's final native shiny
identity.

### Untamed Advanced and Random Wild

The challenge applies to **wild battles initiated by visible wandering
Pokémon** as well as normal step/fishing battles, provided the engine
emits a native Gen 3 wild battle and uses its ordinary `catch.rate`
transaction. Untamed still owns overworld rendering and chaining,
while Nuzlocke enforces the capture rule. Random Wild may remap species
without changing whether the individual is shiny.

The playstyle does not restrict starters, gifts, Eggs, in-game trades
or scripted non-ball acquisition. Restricting those to shiny Pokémon
would be an additional challenge rule requiring a separate acquisition
hook; this version is specifically **shiny-only catching**.

## Save and compatibility

Playstyle state is stored at
`gen3_classic_v1.playstyles.shiny_nuzlocke` (default OFF).
It does not migrate or overwrite historical Gen 1/2 saves.

The switch is configurable during an active run, like other CORE
toggles, but switching it does **not** undo previously spent encounters
or un-catch non-shinies obtained before it was enabled. Changes are
refused once the Nuzlocke run is marked failed.

## Disposable ROM checks

- [ ] **S01:** CORE Nuzlocke ON, Shiny Nuz ON. See three ordinary wilds
      in the same route. Balls are denied with reason, and the route
      remains available even if Failed Encounters is ON.
- [ ] **S02:** Encounter a shiny in that route. With Failed Encounters ON
      the route is spent at battle start, even if you run/KO/miss it.
- [ ] **S03:** With Failed Encounters OFF, failing to catch a shiny does
      not spend the area; capturing one does.
- [ ] **S04:** After catching a shiny, another shiny in the same area
      cannot be caught, even if Shiny Clause is set to UNLIMITED.
- [ ] **S05:** Dupes Clause excludes shiny duplicates without consuming
      an unclaimed area.
- [ ] **S06:** One Per Area OFF permits multiple different shinies, but
      still denies non-shinies.
- [ ] **S07:** Turn off Shiny Nuz; ordinary catches behave as before.
      Turn off the CORE master; even a saved Shiny Nuz ON is inactive.
- [ ] **S08:** Set Shiny Rate to ALWAYS on a disposable save. Encounters
      are eligible if native shiny identification agrees. Turn it back
      to NATIVE on a new run for real shiny hunting.
- [ ] **S09:** With compatible Untamed-Advanced installed, shiny
      overworld wandering encounters can be captured and non-shiny
      wandering encounters cannot. Their sprites/battles match, and
      encounter chaining shows the actual species.
- [ ] **S10:** Confirm save/reload preserves the toggle and its
      encounter history, and NUZ NOTICES shows denied-catch reasons.
- [ ] **S11:** Test FRLG, Ruby, Sapphire and Emerald separately, including
      an actual naturally shiny wild Pokémon.

Automated Lua smoke tests cover menu/state/hook policy. Native ROM,
battle animation, special encounters and external shiny-provider
interactions require in-game validation.
