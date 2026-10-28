# Gen 3 Nuzlocke — QOL

**Version:** v3.0.0-BETA  
**Menu:** NUZ MENU → NUZ RULES → QOL.  
**Save state:** \`gen3_classic_v1.qolRules\`.  
**Master switch:** These are convenience changes and work independently
of CORE Nuzlocke, except where existing separate evolution/battle rules
already impose restrictions.

The original eight-option Gen 1/2 QOL catalogue has been brought into
the Gen 3 menu. Four options use real Gen 3 engine paths and are
editable; the others remain visibly unavailable until a safe
implementation exists or because their events do not exist in Gen 3.

## Current menu

| Option | Status | Default |
| --- | --- | --- |
| PC-Only Catches | WIP, read-only | Unavailable |
| Instant Text | Working | OFF |
| Skip Cherrygrove Tour | Gen 2 only, read-only | Unavailable |
| Run / Surf | Working | OFF |
| Unlimited Bag Space | Working | OFF |
| Trade Evolutions | Working | OFF |
| System Clock Sync | Gen 2 only, read-only | Unavailable |
| Gym Guide Rare Candy | Gen 1 only, read-only | Unavailable |

Disabled rows show an explanation rather than silently storing settings
that have no effect on the game.

### Instant Text

Bypasses ordinary Gen 3 field-dialogue typewriter reveal by passing the
native Message.show printer a copy of its options with speed 0.
The underlying Message.show still owns text paging, A/B to continue,
choices and other surrounding scripts. This option does **not** set
the game's saved Options text speed or advance pages automatically.

**Compatibility note:** FRLG and RSE have partly distinct text-printer
paths. CI validates the Message.show adapter and the option copy,
but real gameplay testing must verify the RSE auto-scroll printer and
nonstandard message boxes remain appropriately paced.

### Run / Surf

Cycles \`OFF → HOLD B → ALWAYS → OFF\`.

- **OFF:** Original native frames.
- **HOLD B:** 2× speed while B is held.
- **ALWAYS:** 2× movement speed for supported player walking/surfing.
- Implemented using the native \`movement.speed\` mod hook and step
  duration (a reduction in frames, never a teleport).
- Biking, slopes, underwater movement, ledges, jumps, field-move
  actions and forced/scripted movement remain native.
- Minimum one movement frame; cannot produce a zero-duration step.

**Compatibility note:** Another movement mod can also adjust
\`movement.speed\`. The QOL layer composes with the next-hook result,
so the effective speed may stack. This needs testing with movement
mods and Untamed overworld movement.

### Unlimited Bag Space

When ON, the Gen 3 Bag checks and writes temporarily relax **only**
the distinct-slot capacities of ordinary \`ITEMS\` and
\`POKE_BALLS\` pockets.

- Does **not** change item legality, PC item storage, containers,
  Key Items, TMs/HMs or Berry-pocket limits.
- **Preserves native per-stack limits** (e.g. Ruby/Sapphire/Emerald's
  99-item stacks for normal items and Balls). An item can occupy
  additional native-sized stacks if the game requires them.
- No permanent mutation of \`ItemsData.CAPACITY\`. The policy
  temporarily raises the two supported capacities for one native
  \`Bag.canAdd\` or \`Bag.add\` call, then restores them, including
  when the native operation raises an error.
- OFF restores ordinary capacity rules without deleting items that
  were already stored in the Bag.

**Compatibility note:** Serialized Bag readers and custom pocket UI
providers may assume native maximum slot counts. Test a Bag with
more than its native capacity through save, quit, reload, sorting and
item use before using this on an important run.

### Trade Evolutions

When ON, a Pokémon that normally needs a link trade may evolve
during a normal **level-up from level 40 onwards**.

- Native \`Evolution.targetSpecies\` remains responsible for other
  level/item/trade evolution mechanics.
- Ordinary \`EVO_TRADE\` branches gain a level-40 alternative.
- \`EVO_TRADE_ITEM\` branches gain a level-40 alternative **only
  while holding their original required item**; the matching branch
  takes priority over a competing plain level evolution.
- The required held item is consumed **only after a successful**
  item-trade evolution (not on cancelled scene or failed attempt).
- Everstone blocks the shortcut; native FRLG National Dex evolution
  gating is still respected.
- Real link trades retain their native evolution timing.
- **RUN / PARTY → Evolution Limits** is applied after the shortcut,
  so No Final and No Evolution still govern the result.
- A known target is selected from the live merged evolution table,
  not from hard-coded Kadabra/Machoke/Graveler/Haunter IDs.

**Compatibility note:** This does not affect species with no native
or merged trade-evolution record. Trade-evolution mods that replace
native records need manual verification.

### PC-Only Catches — not yet implemented

The legacy rule permits otherwise illegal captures **for
story/Pokédex progression only**, but they must go straight into
permanent, non-releasable, non-withdrawable PC storage without
spending an ordinary encounter or Type Locke draft slot.

Gen 3 \`Catching.storeCaught\` currently registers the Pokédex
capture and emits the caught event during its own party/PC storage
transaction. Simply allowing an illegal Ball and moving the Pokémon
after the event is **not atomic**: other code may already have seen a
normal party catch or awarded challenge progress.

Until an atomic capture-to-PC path, persistence marker, PC-operation
guards and capture-event test are all present, this row remains
explicitly WIP. It does not turn on any silent capture exception.

### Gen 1/2-only settings

Skip Cherrygrove Tour, System Clock Sync and Gym Guide Rare Candy
depend on Gold/Silver/Crystal or Red/Blue/Yellow script mechanisms.
They are read-only in Gen 3; no false game flags or cross-generation
save keys are introduced.

## Suggested in-game checks

1. **Q01 — Defaults:** Check four working options default OFF;
   the other four display read-only explanations.
2. **Q02 — Text:** Toggle Instant Text in FRLG and RSE, open
   ordinary dialogues, multi-page stories, choices and forced
   NPC scripts. Verify text reveals immediately without skipping
   button prompts or animation waits.
3. **Q03 — Run:** Toggle HOLD B/ALWAYS; compare walking and
   surfing speed. Confirm bike, jump, cutscene, slope and
   underwater movement are unchanged.
4. **Q04 — Bag:** Fill the native ITEM pocket to maximum distinct
   stacks; enable Unlimited Bag Space and pick up a *new item type*.
   Repeat for Poké Balls, then verify 99-stack limits in RSE.
5. **Q05 — Bag save:** Save, quit, reload, sort and use items
   while carrying more slots than native capacity. Disable the
   rule: existing items stay intact; further over-cap additions
   should fail normally.
6. **Q06 — Trade:** Level Kadabra/Machoke/Graveler/Haunter past
   40 with the toggle OFF/ON; verify native evolution restrictions.
7. **Q07 — Trade item:** Test Slowpoke with King's Rock and
   Onix/Scyther/Seadra/Porygon with their matching held items.
   The item disappears only after a completed evolution.
8. **Q08 — Evolution clauses:** With Trade Evolutions ON and
   No Evolution ON, ensure no shortcut bypasses the restriction.
   Test Everstone and FRLG National Dex evolution gates.
9. **Q09 — Compatibility:** Test supported randomiser,
   Untamed movement and custom item-pocket providers separately.
10. **Q10 — Save state:** Confirm four QOL settings persist and
    GEN 1/2 save behaviour is untouched.

The CI suite covers rule validation, persistence, the native hook
integration, movement exclusions, instant text option copying,
Bag capacity restoration on failure and level-40 evolution policy.
These are isolated Lua smoke checks, not a replacement for manual
FRLG/RSE gameplay testing.
