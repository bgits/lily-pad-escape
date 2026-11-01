# Verification report — version 0.7 — 28 October 2026

## Change
Lucky Lagoon now has six small, permanently solid pads forming two winding branches around the original yellow-frog pads. The full solid route takes nine jumps. The two broad 50/50 pads remain optional shortcuts, preserving the original five-jump route. Both routes meet at the ordinary rest pads, allowing a different choice at each branch. No yellow landing, favorable roll, or yellow-pad counter is required to finish.

Small pads reward accurate aiming and braking with the existing controller. Bypass geometry and collision use the same mesh, just as the original pads do. The original jump physics, random thresholds, once-per-attempt rolls, retry behavior, poison system, and other two courses are unchanged. Bypasses are generated after scenery so the existing stone pillars retain their positions. Title/HUD/victory copy now describes a choice of routes rather than required luck. The red/green rules remain undisclosed in Frog River.

## Verification
**62 native checks passed:** 21 new skill-route checks and 41 existing health/chance checks. The new test removes both yellow supports before the first jump, then continuously controls the player from spawn through all nine jumps to a real flag victory. No teleporting between pads, RNG draws, restored supports, falls, or retries occur. It also checks pause support on a small pad, restart, and that the other levels do not gain bypass pads. The existing suite checks both random outcomes, repeated contacts, sinking/pause/retry, a 1,000-roll distribution sample, poison, healing, and the Level 2 → 3 transition.

**38 browser checks passed** in the exported game. A complete normal-input solid-route crossing finished on the first attempt with zero rolls and zero falls. A separate five-jump shortcut crossing succeeded with both naturally rolled solid results. A fresh attempt produced a sinking result and reset correctly. Replay, pause/resume on a small pad, non-poisonous landings, and the smaller viewport also passed. No browser or engine errors were observed. Browser tests use ordinary mouse/keyboard input and read-only telemetry; they do not force outcomes or move the character directly.

The browser driver was updated to track its cursor after UI clicks and release movement to brake on narrow pads. Its older constant-duration jump overran a narrow landing; no controller physics were changed to accommodate the test. The native worst-case test separately establishes that the route works with both yellow pads absent.

Reviewed actual exported screenshots of the title, both solid branches, and victory, including `28-lucky-title.png` and `49-skill-route-small-pads.png` through `51-skill-route-victory.png`. The branches and wide shortcuts are visible together, and the HUD no longer shows a yellow completion objective or a misleading linear pad count.

Evidence: `native-test-results-v0.7.txt`, `lucky-browser-v0.7.log`, and `lucky-browser-results.json` (including every solid-route landing snapshot). Prior full-suite evidence remains in `TEST_REPORT-v0.6.md`; unrelated wardrobe, combat, and secret browser suites were not repeated for this level change. Environment: Godot 4.6 stable, Compatibility, 60 Hz physics, installed Chrome through Playwright 1.62.1 on Apple M2 Max. Other browsers were not tested for this release.

Reproduce with the Godot `skill_route_test.gd` and `health_luck_test.gd` scripts, then `npm run test:lucky` with the local server running. `scripts/test-native.sh` now includes the skill-route regression. Editable source and the exported Web build are in `LilyPadEscape-v0.7.zip`.
