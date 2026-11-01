# Verification report — version 0.5.1 — 28 October 2026

## Fix
Swinging previously copied the camera yaw into the character and used the same camera direction for damage. A character turned backwards would therefore snap forward and miss the frog. The swing now snapshots the avatar’s existing heading for the hit check and leaves its rotation unchanged. The existing swing locks facing through recovery; camera orbit does not redirect it, and movement can turn normally afterward.

## Verification
The focused native regression reproduced the old bug: **15 checks failed** before the fix. All **20 checks pass** after it. Coverage includes backward/left/right movement, keyboard and mouse attacks, facing and hit-direction consistency, camera orbit during wind-up, recovery, an actual backward frog defeat, full healing, and normal movement after the swing.

The full native suite passed **177 checks**: 21 movement, 29 combat, 20 swing-facing, 41 decoy, 41 health/chance, and 25 secret. Existing directional fixtures now set the character’s facing explicitly; camera yaw is no longer treated as attack aim.

The focused browser suite passed **15 checks** using ordinary input. It verifies backward F swings and sideways mouse swings without rotation, then lands on a frog pad, walks around the living frog, turns backwards with Arrow Down, and defeats it while the camera remains forward. The character retains its heading through impact and recovery, and the kill restores 100% health. The browser bridge is read-only; there are no teleports or game-state setters.

The full Frog River browser suite passed **46 checks**, including all six frog defeats, a complete crossing, poison/healing/death, red traps, pause/resume, and the next-level transition. Both browser suites finished without engine or browser errors. Screenshots `40-backward-facing-frog.png` and `41-backward-bat-hit.png` show the actual reproduction and successful hit.

## Scope and evidence
Godot 4.6 stable, Compatibility renderer, 60 Hz physics; Chrome 156 via Playwright 1.62.1 on Apple M2 Max. This patch reran every native suite and the combat/facing browser suites. Unrelated complete Level 1/3 browser playthroughs and wardrobe persistence were not repeated; the prior release’s evidence is preserved in `TEST_REPORT-v0.5.md` and its archive. Other browsers remain untested.

Reproduce with `./scripts/test-native.sh`, `npm run test:facing`, and `npm run test:combat` while the local server is running. Evidence: `native-test-results-v0.5.1.txt`, `swing-facing-browser-results.json`, `swing-facing-browser-v0.5.1.log`, `combat-browser-results.json`, and `combat-browser-v0.5.1.log`.

The Web export and editable source are packaged in `LilyPadEscape-v0.5.1.zip`.
