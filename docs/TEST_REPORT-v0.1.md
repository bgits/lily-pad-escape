# Verification report — 27 October 2026

## Result
The first playable version is implemented and exported. The final native suite passed **21/21** checks; the final browser suite passed **51/51** checks with **zero browser console errors**. The final course was completed with **nine normal-input jumps and zero falls**, followed by a successful Play again reset.

## Environment and performance
- Engine: Godot 4.6.stable.official.89cea1439, GDScript, Compatibility, 60 Hz physics.
- Machine: Apple M2 Max, 32 GiB RAM, macOS.
- Final browser: installed Chrome 156, automated in headless mode through Playwright 1.62.1, 1280×720, device pixel ratio 1.
- Renderer reported by WebGL: `ANGLE (Apple, ANGLE Metal Renderer: Apple M2 Max, Unspecified Version)`.
- Eight settled FPS samples, 250 ms apart: [60, 60, 60, 60, 60, 60, 60, 60]; mean **60.0 FPS**.
- FPS snapshots at the nine course landings: [60, 60, 60, 60, 60, 60, 60, 60, 60].
- This is a short local measurement, not a broad hardware benchmark or a frame-time percentile analysis.

## What was exercised
- Actual browser Play and mouse capture; typed name; all three hoodie colors; HUD progress.
- Normal WASD movement; diagonal and straight speeds both approximately 5.4 m/s; one jump while Space is held.
- Full course using only ordinary mouse movement, W, and Space. The test uses read-only position telemetry to choose inputs. **No teleportation, position mutation, or hidden movement API** was used for the playthrough.
- Left-click pause, Escape pause while airborne, resume, mute/unmute, restart, return to title, victory freeze, and replay.
- Focus loss while a movement key was held, pointer-lock loss, and return without stuck movement.
- Three deliberate browser falls, one splash per fall, and return to the start in about one second.
- Native tests additionally exercise coyote time before/after its deadline, pre-landing input buffering, autorepeat rejection, actual notched-mesh collision, a camera obstruction, and session reset. These isolated physics tests deliberately set up positions; they are distinct from the normal-input course playthrough.
- Godot import, headless startup, export, shell syntax, browser-test syntax, source-archive hashes, and WAV headers.

## Visual review
Reviewed running screenshots of title, all main gameplay elements, a first landing, mid-course, customization, pause, splash, victory, and the smaller 1024×640 desktop view. No clipped controls, page overflow, missing glyphs, or obstructed primary actions were found. The smaller desktop view uses letterboxing to retain the game's aspect ratio. The geometry is intentionally simple and editable; it is an approximation of the supplied art direction.

## Limits and known behavior
- Browser acceptance was completed in Chrome. Firefox, Safari, mobile, controllers, low-end hardware, and high-DPI layouts were not tested.
- An earlier reused, headed Chrome automation session intermittently rejected pointer lock with `WrongDocumentError`; the game paused safely. A fresh final Chrome session passed Play, Resume, focus-loss, pointer-loss, and replay without errors. If capture is declined, focus the game window and click Resume. The automated result does not replace a human feel/playability review.
- Audio files, playback wiring, and mute state were checked. Speaker output was not evaluated by a human listening test.
- The Godot source was imported and exercised headlessly. An interactive Godot editor session was not manually play-tested.
- Procedural scenery, simple lighting, and a flat animated water shader keep this version small. No moving platforms, touch controls, progression system, multiplayer, or persistence.

## Evidence
`native-test-results.txt`, `browser-test-results.json`, and `playthrough.json` contain the detailed results. `01-title.png` through `10-small-desktop.png` are screenshots of the exported, running game. The screenshot files are not copies of the concept image.
