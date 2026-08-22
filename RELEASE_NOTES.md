# Nuzlocke 2.7.0 — Release Notes

2.7.0 promotes the runtime-confirmed 2.6.98 head to release. These notes intentionally cover **changes since the previous release build, 2.6.0**, rather than only the final development repair.

## Highlights since 2.6.0

- **Randomizer:** built deterministic run snapshots and isolated streams; persistent source mappings; candidate, uniqueness, and projection ownership rules; balanced/distinct starter slates, trio typing, rival synchronization and rerolls; encounter repetition/diversity/balance controls with protected-source isolation; and field-item semantic pools, balancing, repeat control, deterministic placement, progression safety, and explicit ownership.
- **Rules and battle clauses:** expanded optional Sleep, OHKO, Evasion, Poison/Toxic, Freeze, Flinch, and trapping restrictions; added the PKMN BAN picker for R/B/Y and then Gold/Silver; and expanded N/A, redundancy, interaction, lock, and rule-help guidance.
- **Setup / NUZ RULES UX:** added collapsed-section change summaries, current/total list position, saved Setup Presets, clearer CUSTOM/preset transitions, true AUTO and fixed Randomizer seed controls, section reset/help improvements, and extensive classic/Gen 2 navigation/readability cleanup.
- **QOL and presentation:** added Instant Text, Rare Candy → current level cap, World Building dialogue rotation/variety, stronger ENC TRACKER summaries/hardening, and expanded Dev Tools / DEV REPORT surfaces.
- **Gold/Silver:** continued exact-edition identity/parity diagnostics, shared Gen 2 ownership cleanup, National Dex PKMN BAN support, and protected the rule that Gold evidence never substitutes for Silver evidence.
- **Compatibility:** hardened provider ownership and wrapper interposition; added randomizer coexistence/provider seams for starters, encounters, field items, and learnsets; added legacy `mod_Compat Beta_26` interoperability; expanded Stadium/Crystal-251 presentation/import provenance support; and retained audited Gen1Recomp 0.2.19 compatibility.
- **Save and transaction safety:** strengthened Save Schema 4 initialization/migration, migration/safe-stop transactions, Rare Candy transaction causality and attempt identity, package/document hygiene, full shipped-Lua compatibility auditing, and lineage/provenance Release Safety checks.
- **Architecture and diagnostics:** continued guarded modularization with explicit dependency ownership while expanding read-only diagnostics, installer health, compatibility health, Known Issues, and release-gate coverage.
- **Final stabilization:** 2.6.93–2.6.98 repaired the World Building catalog golden, full-package unpack audit, Randomizer rival-sync diagnostic ordering, documentation packaging, build provenance, and the shared Setup/NUZ RULES constructor typo. The user runtime-confirmed that the previously failing menu path works in 2.6.98.

## Release status

- Canonical parent: **2.6.98**
- Parent SHA-256: `4b5834bb54ff2cc4564ed62057210185c7619ceea1735ff50f1aa4cb97419cd0`
- 2.6.97 Release Safety runtime evidence: `NO ACTIONABLE PROBLEMS / ALL ACTIONABLE CHECKS PASS`
- 2.6.98 Setup / NUZ RULES constructor repair: **Runtime PASS**
- 2.7.0 changes no gameplay semantics, rule defaults, Randomizer mappings, Save Schema, compatibility ownership, or package inventory from 2.6.98.
