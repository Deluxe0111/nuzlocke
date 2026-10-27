# Gen 3 — player feedback and Rare Candy regression

The player's immediate actions should explain *why* a Nuzlocke rule affected
them. Battle notices use the native Gen 3 battle dialogue queue. Events are
also saved to the latest **30 NUZ NOTICES** (Start > NUZ MENU > NUZ NOTICES).
Long descriptions are split into readable GBA-sized rows.

The notice history is stored under `gen3_classic_v1.notices` and does not
change any old Gen 1 / Gen 2 saves. Selecting a notice shows its full text.

## Feedback added

| Action | Feedback |
|---|---|
| First eligible wild encounter | Indicates whether Failed Encounters has consumed the area immediately or capture is still pending |
| Blocked Poke Ball | One Per Area (including route name), Dupes Clause or claimed Roamer slot |
| Successful area catch | Records that the area's encounter slot has been used |
| Successful Shiny Clause exception | States that the extra encounter was allowed |
| Captured roamer | Explains the species-specific roamer slot |
| EXP at level cap | Shows how much EXP was banked, or lost when edging is OFF |
| Banked EXP released | States how much saved EXP is paid out on the next native award |
| Rare Candy at level cap | Item refuses use with a reason before consumption |
| Permadeath | Identifies the fainted Pokémon and its Graveyard entry |
| First Rival Mercy | Explains why that opening rival fight exempts faint deaths |
| Whiteout/run failed | Adds run-ending notice |
| PC survivor rescue | Explains why a boxed Pokémon was moved into the team |
| Egg Encounter, nicknames | Reports hatch status or pending naming tasks |
| Forgiveness tokens | Reports earned badges/tokens and route redemption |
| Level cap progression | Logs the newly active Gym/League cap when progression advances |

Game3 battle notices are queued instead of forcing an immediate overworld
textbox, which could overwrite scripted dialogue, or native battle
animations. Overworld outcomes are always in the Notice history. Item use
errors use the native field menu's existing error-text return contract.

## Why Rare Candy was getting through

Previously, the guard only wrapped `ItemUse.useRareCandy`, and it installed
lazily at game events/menu open. The actual overworld bag transaction enters
through `ItemUse.useField` and the `item.use` mod hook. The new outer guard
checks the active cap **before** calling the native item operation, then
returns `false, "noeffect", explanatoryText`. This also handles the
out-of-battle use path independently of the direct native Rare Candy guard.

## Disposable-ROM testing checklist

- [ ] **F01:** FireRed, GYMS cap 14; use Rare Candy on Lv14 Pokémon.
      It **must not become Lv15**, consume Candy or play a success animation.
      It should explain the cap.
- [ ] **F02:** Use the same item at Lv13. It should work normally and consume
      one Candy, as before.
- [ ] **F03:** Repeat F01–F02 with an RSE edition and with any level-up Enigma
      Berry effect supported by that ROM.
- [ ] **F04:** Throw a ball after an area was spent; see the One Per Area
      reason in *battle dialogue* and in NUZ NOTICES (ordinary failed catch
      randomness should remain normal).
- [ ] **F05:** Repeat F04 with Dupes and claimed Roamer clauses, checking
      the correct reason (and Shiny Clause override, if enabled).
- [ ] **F06:** At Lv14 cap, battle with EXP Edging ON. Read the banked EXP
      message. Turn edging OFF and confirm EXP-loss wording; repeat after
      gaining Boulder Badge and confirm the stored EXP release message.
- [ ] **F07:** Let a party Pokémon faint: permadeath notice and Graveyard
      entry; opening rival exemption should show mercy instead.
- [ ] **F08:** Complete a badge and a League battle: watch cap stage change;
      NUZ NOTICES should preserve both updates.
- [ ] **F09:** Claim a Route Forgiveness token, hatch an Egg, and leave an
      unnamed Pokémon in PC. Each event should be traceable through notices.
- [ ] **F10:** Whiteout / PC rescue on a disposable save. Confirm the correct
      outcome notification and that native party/PC data is consistent.
- [ ] **F11:** Open NUZ NOTICES, inspect several long messages, and verify
      text is *fully readable* instead of cut off.

CI smoke tests cover the field item-hook cancellation and battle notice
contracts, but **real-ROM testing is still necessary**, especially for native
bag messages, battle animation timing and RSE item differences.
