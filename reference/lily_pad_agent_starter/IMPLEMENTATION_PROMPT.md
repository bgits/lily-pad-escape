# Build the first playable version of Lily Pad Escape

You are implementing a small, real, playable game—not a concept image, static website, or design document. Work in the provided repository, inspect its existing structure first, and preserve unrelated files and changes. Use “Lily Pad Escape” as a temporary title.

## 1. Goal and scope

Build a single-player, third-person 3D platformer. A small character is stranded on a lily pad, jumps across a short route of lily pads, and reaches a grassy island with a yellow flag. Falling into the water causes a quick retry.

The purpose of this build is to test whether movement, jumping, camera control, and landing feel good. One complete, attractive, reliable level is the deliverable. Do not build the larger game yet.

## 2. Reference artwork and priority

Inspect `reference/01_chosen_gameplay.png` before building. This is the chosen visual direction: a camera behind and slightly above the character, chunky 3D forms, pixel-like surface detail, turquoise water, bright green lily pads, and a cheerful island setting.

The character is an anonymous, childlike adventurer with brown hair, a yellow hoodie, navy shorts, and red shoes. Approximate that silhouette and palette with simple editable geometry. It is not a portrait of a real person.

The PNG is concept art, not a supplied 3D model, texture atlas, or playable background. Construct an actual navigable 3D scene. Do not put controls over the reference image and call it a game.

Priority: this prompt defines gameplay and scope; the chosen PNG defines visual direction; `original-notes/` provides background only. The original notes contain future ideas that are not requirements for this milestone. Ignore the mockup’s arrow buttons, “A” button, energy meter, and dashed jump arc. Do not implement mechanics just because those decorations appear in the image.

## 3. Platform and implementation

For this prototype, assume a desktop/laptop browser with keyboard and mouse. Touch and controller support are out of scope.

Use a stable Godot 4.x release, GDScript, and the Compatibility renderer. Record the exact engine version and use matching export templates. Configure a single-threaded Web export. Keep the project runnable in the Godot editor as well.

Do not silently substitute a different engine. If the workspace or tooling genuinely prevents this setup, explain the specific blocker and provide whatever verifiable implementation is possible without pretending the build runs.

Use a script-controlled character body with collision handling, a third-person camera rig with obstacle avoidance, and simple scene/resource organization. Keep movement parameters and level layout editable without changing core game logic. Avoid unnecessary plugins and frameworks.

## 4. Player controls and movement

WASD: move relative to the camera’s horizontal facing direction.
Mouse: orbit the camera around the character.
Space: one ordinary, fixed-strength jump per press.
R: restart the level.
Escape: pause and release the mouse.

The character should turn toward movement. Normalize diagonal movement so it is not faster. Use physics-timestep movement, deliberate acceleration/deceleration, and a little controllable steering in the air. Do not add sprinting, charged jumps, double jumps, stamina, or equipment.

Add a small grace period for jumping just after leaving an edge, and a short input buffer for a jump pressed just before landing. Start around 0.10 seconds and 0.12 seconds respectively, expose them for tuning, and ensure they cannot create unintended extra jumps. Holding Space must not cause repeated automatic jumps.

Tune a reliable jump before finalizing platform spacing. A miss should be understandable, not caused by slippery controls or misleading collision shapes.

## 5. Camera and browser input

Start behind and slightly above the character, looking toward the first platforms and the finish. Allow mouse orbit, clamp vertical rotation, and keep the next landing area visible. Avoid excessive camera lag, head bob, and camera shake.

Use SpringArm3D or equivalent collision-aware camera behavior. Exclude the player from the camera’s obstacle checks. Prevent the camera from going through scenery or below the water during normal play.

Capture the mouse only after a deliberate click on Play or Resume. Pause when focus or pointer lock is lost; do not leave movement keys stuck. Make pause, resume, restart, and victory UI usable with the mouse. Resume must reacquire input correctly. Snap the camera safely to its starting pose on respawn rather than sweeping across the level.

## 6. One handcrafted level

Create one large starting lily pad, approximately eight intermediate pads, and a finish island. All platforms are stationary and the required landing surfaces are at roughly the same height.

The starting pad must have enough room to practice moving and jumping. The first two gaps are short and forgiving. Later pads introduce gentle changes of direction and slightly longer gaps. Keep a clear route and a visible goal. Do not add tiny precision platforms, blind jumps, enemies, moving pads, or sinking pads.

Store spawn, pad positions/sizes, and goal placement as editable level data or scene properties. Make all required jumps comfortably achievable with the actual controller. Check edge-to-edge gaps and safe landing areas, not only center-to-center distances. Confirm reachability by playing the route; a theoretical distance calculation alone is not sufficient.

Use colliders that reasonably match visible platforms. Do not create invisible bridges or large invisible landing areas. Decorative scenery must not obstruct the route or offer a way to walk around the water challenge.

## 7. Failure, success, and interface

Entering the water triggers one splash/failure event, followed by a return to the starting pad in about one second. Reset velocity, jump buffers, failure timers, and camera state. Provide unlimited retries, with no lives, penalties, or restart confirmation dialog. Add a fallback reset for falling outside the level.

Reaching the flag while on the finish island triggers victory once. Freeze gameplay, release the mouse, and show “Level complete!” with Play Again. Restarting must fully reset the session’s level state.

Provide a small start screen, a readable Level 1 HUD, brief control hints, a working pause menu, and a victory panel. No fake meters, disabled buttons, inventory placeholders, or on-screen mobile controls.

After the core loop works, add a small optional character-name field and three hoodie-color choices to the start screen. These are session-local only. Use the yellow hoodie by default. Do not build a wardrobe, accounts, or persistence system.

## 8. Art and sound implementation

Create or include every runtime asset needed for the prototype. Simple original meshes assembled from primitives or generated geometry are acceptable. The delivered character must have a recognizable head, body, arms, legs, and basic idle/run/jump/landing motion—not just a capsule.

Create recognizable notched lily pads, simple water, sky, a grassy goal island, and a restrained amount of rocks, reeds, or distant trees. Keep the reference’s bright colors and chunky style. Use crisp small textures where useful, but keep UI text sharp. Prefer lightweight water and lighting over elaborate reflections or expensive effects. No voxel destruction or fluid simulation.

Use a simple shadow or landing-position cue to help judge depth. Do not add a predicted jump arc in this milestone.

Add short jump, splash, and victory sounds plus mute. Use bundled audio files; original sounds generated offline and saved to files are acceptable. No network-dependent runtime assets, paid assets, or unlicensed downloads. Record provenance and license information for third-party assets. Do not redistribute system font files.

## 9. Build order and limits

First make movement, camera, platforms, failure, and victory work with basic geometry. Then apply the visual style, simple animation, interface, and sound. Export and test in the browser early rather than leaving export until the end.

Do not build multiplayer, user-created levels, level sharing, procedural levels, a level editor, upgrades, equipment, leaderboards, shops, analytics, a backend, or public deployment. Do not scaffold unused systems for these future features.

Make reasonable small implementation choices and document them. Do not stop at a plan or ask a long list of design questions. Prioritize a functioning game over decorative scope.

## 10. Verification and deliverables

Run import/parse checks and available automated checks. Test actual gameplay with ordinary controls where your environment supports it: complete the course, deliberately fall repeatedly, restart, pause while airborne, resume, lose/regain focus, and replay after winning. Check diagonal speed, held-jump behavior, platform edges, and camera collisions. Do not count teleporting to the goal as a successful playthrough.

Verify the browser export through a local HTTP server. Check its console for errors. Target smooth 60 fps at 1280×720, but report the actual browser, hardware/environment, and measurements rather than claiming an unmeasured performance result.

Deliver:
- The complete editable Godot source project, all runtime assets, and Web export configuration.
- A runnable Web export with all companion files when export tooling is available.
- A README with the engine version, exact run/export/serve commands, controls, editable tuning parameters, and asset credits.
- Screenshots captured from the running implementation, not copies of the reference image.
- A concise report of what works, tests actually performed, known limitations, and anything not verified.

Keep export dependencies version-matched. If graphical testing or export is unavailable, say exactly what was and was not tested, and give the specific remaining setup steps. Do not claim completion based solely on code inspection or fabricate screenshots, test results, or a working URL.

Begin by inspecting the workspace and reference image, then implement the game.
