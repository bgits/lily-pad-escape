# Verification report — version 0.4 — 28 October 2026

## Result
Three playable levels are exported, including the requested yellow-frog randomness and the preceding health/poison request. Native suites passed **132/132** checks (21 movement, 29 combat, 41 decoy, 41 health/chance). Final browser suites passed **119/119** checks (53 lagoon, 46 combat/health, 20 chance), with zero browser/engine errors.

All three courses were completed through ordinary mouse and keyboard inputs. The final Lucky Lagoon run took **2 actual random course attempts** and observed both sinking and solid outcomes. No browser seed override, teleport, or hidden game-state setter was used. Native tests use controlled positions and seeds to isolate edge cases.

## Level 3: Lucky Lagoon
- Third title choice and actual Level 2 → Level 3 button work. Level 3 has two yellow pads separated by ordinary rest pads across five gaps.
- A dedicated gameplay RNG is randomized independently of repeatable scenery. The production rule is `randf() < 0.5` for sinking.
- The first physical landing resolves a yellow pad. Flying above it does not count; a solid pad remains solid while standing and when re-landing. Contact cannot reroll it.
- An unlucky result removes support, sinks the pad, and enters one water retry. Pause freezes collapse; retry/restart resets both pad outcomes.
- Yellow frogs are non-solid markers, not poison enemies. Victory requires reaching the shore; it does not require defeating yellow frogs.
- Native actual-landings cover each outcome. A deterministic 1000-roll sample through the production function produced **518 sinks / 482 holds**, consistent with 50/50. The threshold defines the probability; the sample is a sanity check, not proof of exact long-run frequencies.
- Browser checks cover both real outcomes, retry, remaining solid after waiting/re-jumping, a full successful crossing, replay, and a smaller desktop title layout.

## Health and poison
- Frog River starts at 100%. A real landing on a living green frog's pad, including the frog's collision body, applies poison. Empty, cleared, red, and yellow pads do not.
- Damage drains 20 percentage points/second, once per physics step, without contact stacking. Poison persists after jumping or leaving the pad.
- A missed attack does not heal. Defeating a green frog cures poison and restores exactly 100%, including the meter and purple effect.
- Zero health triggers one distinct poison defeat, disables controls, shows a collapse/puff and 0% meter, then retries after 1.2 seconds. Late attacks cannot resurrect the character.
- Pause freezes damage, effects, and retry. Respawn cures poison and restores full health while retaining previously defeated green frogs. Restart restores all enemies and counters. Level transitions clear poison.
- The browser observed gradual damage, pause/resume, full healing, a second poisoning, zero-health death, healthy retry, and all six kills healing to 100% on a full safe crossing.

## Regression and presentation
All existing native movement, platform/camera collision, combat, red-decoy, and reset checks pass. The browser covers Level 1 and both Next level transitions, customization, sound/mute, focus/pointer lock, arrows for trap/Level 3 traversal, jumps, repeated water retry, and viewport fit. Red decoys still collapse and never count as green kills.

Reviewed actual game screenshots of the three-level menu, yellow frogs, held/sinking results, Level 3 victory, healthy/poisoned/zero-health meter, poison collapse, and 1024×640 layout. Controls and labels are readable without clipping.

Environment: Godot 4.6 stable, Compatibility, 60 Hz physics; Chrome 156 via Playwright 1.62.1 on Apple M2 Max / 32 GiB RAM, 1280×720, DPR 1. Settled lagoon and combat landing snapshots reported 60 FPS. These short samples are not broad hardware benchmarks.

## Limits and reproduction
Chrome is the tested browser. Safari, Firefox, mobile, controllers, low-end devices, and high-DPI layouts remain untested. Sound files and playback wiring were checked without a human speaker listening review. Progress remains session-only. Two independent yellow pads both staying has a 25% probability per attempt, assuming successful jumps; retries are an intended part of Level 3.

Run `./scripts/test-native.sh` and, with the local server running and Chrome installed, `npm run test:browser`. `npm run test:lucky` runs only the new course. Browser chance-test check counts vary with observed outcomes; it never forces a favorable draw.

Evidence: `native-test-results-v0.4.txt`, `browser-test-results.json`, `combat-browser-results.json`, and `lucky-browser-results.json`. Screenshots `23-poisoned.png` through `27-healthy-retry.png` cover health; `28-lucky-title.png` through `33-three-levels-small.png` cover Level 3. Earlier version reports/logs are retained as historical evidence. Current source, Web build, and `LilyPadEscape-v0.4.zip` include all changes.
