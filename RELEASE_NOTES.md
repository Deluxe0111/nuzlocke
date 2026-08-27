# Nuzlocke 2.8.72 — Release Notes

2.8.72 completes the Difficulty UI follow-up from the Red runtime test.

## Clear APPLY / CANCEL selection

The confirmation dialog now uses the native Gen1 cursor glyph beside the active choice instead of relying on a textual `>` character that does not render reliably. CANCEL remains the safe initial choice.

## Useful in-game profile explanations

The Difficulty chooser no longer dumps raw internal values like unexplained AI tiers or percent-formatted level fields.

It now gives compact decision information:
- concrete regular/boss level gains at trainer levels 25 and 50;
- team-upgrade frequency as `N OF 100`;
- whether stronger same-type species substitutions are active;
- move quality in plain terms;
- AI quality in plain terms;
- DV minimums or PERFECT;
- Gen-II held-item quality;
- Badge Boost ownership.

No percent glyph is required.

If the explanation exceeds the visible three-line detail area, SELECT pages through every detail line and the screen shows the current detail position.

## Silver and Crystal

Silver and Crystal now have exact edition routing and their own built-in profile catalogs rather than falling through to Red profiles.

Silver:
- SILVER POLISHED*
- SILVER LEGACY*

Crystal:
- CRYSTAL POLISHED*
- CRYSTAL LEGACY*

These are Nuzlocke-built edition-focused profiles inspired by stronger Gen-II play, not exact copies of external hacks.

## Full documentation rule

The in-game selector is intentionally concise. The User Guide now contains the complete mechanical definition of every built-in profile and the common Difficulty engine.

Any future built-in profile change must update that full documentation; Release Safety checks for the reference.

## Versioning

- Nuzlocke: 2.8.72
- Save Schema: 5
- Compatibility API: 35
- Diagnostics API: 1
- Translation API: 2
- Run History: 2
