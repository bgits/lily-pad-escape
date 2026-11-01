# Verification report — version 0.6.1 — 28 October 2026

## Change
Frog River no longer explains the red/green color rules. Its legend and combat objective counter are hidden. The title gives only the crossing goal, the health meter reports current status, and notifications describe immediate outcomes without color-based advice. Attack misses, poison, sinking, healing, and the still-blocked finish no longer give the solution. Controls remain visible. Detailed README mechanics are in a collapsed spoiler section.

This is a presentation change: enemy behavior, poison/healing, decoy collapse, melee direction, and the victory requirements remain unchanged. Level 3's yellow chance information is retained.

## Verification
The existing combat and decoy native suites passed **70 checks** (29 combat, 41 decoy). Text-dependent assertions were updated to reflect neutral feedback. The existing Frog River browser suite passed **46 checks** with no browser or engine errors, including the complete six-frog crossing, poison/healing/death, red-pad collapse/retry, pause, replay, and the transition into Level 3.

Reviewed the actual exported title, spawn HUD, and poisoned HUD screenshots: no red/green key, frog objective counter, or strategy instructions are shown. Current evidence is in `native-test-results-v0.6.1.txt`, `combat-browser-v0.6.1.log`, `combat-browser-results.json`, and the refreshed Frog River screenshots (`12-frog-title.png`, `13-frog-spawn.png`, `23-poisoned.png`, plus the rest of the combat capture set).

The previous release's full native/browser run is retained in `TEST_REPORT-v0.6.md`. Unrelated wardrobe, chance, and secret suites were not repeated for this copy change. Environment: Godot 4.6 stable, Compatibility, 60 Hz physics, installed Chrome through Playwright 1.62.1 on Apple M2 Max. Other browsers were not tested for this patch.

Reproduce with the Godot `combat_test.gd` and `decoy_test.gd` scripts, then `npm run test:combat` with the local server running. The exported Web build and editable source are packaged in `LilyPadEscape-v0.6.1.zip`.
