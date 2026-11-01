# Lily Pad Escape — first playable

## Review and scope
The supplied ZIP contains a written implementation proposal, one chosen concept image, and three original note images. It has no runtime models, textures, animations, or audio. The reference is inspiration for a real navigable scene. The note images describe a stranded adventurer, pixel-like characters, customization, increasing difficulty, upgrades, and shared levels.

For this first version, adopt the proposal's narrow milestone: one desktop-browser, third-person 3D platforming course with a large starting pad, eight intermediate pads, a flag island, unlimited quick retries, and name/hoodie choices. Future notes do not add requirements for this version. Keep the project local.

## Direction
- Visual thesis: a bright, miniature voxel lagoon with turquoise water, lime-green leaves, warm sunlight, and a friendly yellow-hoodie explorer.
- Content plan: a quiet start menu over the live world; a minimal Level 1 HUD while playing; focused pause and victory panels.
- Interaction thesis: responsive camera-relative movement and readable jump arcs; small limb and landing animation; gently moving water and flag.

## Implementation
1. Pin Godot 4.6 stable and matching Web templates; use GDScript, Compatibility, and single-thread Web export.
2. Implement fixed-timestep controller, coyote time, jump buffer, camera orbit/collision, and a data-driven route.
3. Implement start, play, pause, splash/respawn, restart, and victory states. Handle focus and mouse lock explicitly.
4. Build original geometry, voxel surface colors, avatar animation, environment, UI, and offline generated sounds.
5. Export early, test actual browser input, tune the course, and verify state transitions and edge cases.
6. Deliver editable source, Web build, reproducible commands, screenshots, and an honest test report.

## QA inventory
- Start: name field, three hoodie colors, Play, mute; only deliberate Play/Resume captures mouse.
- Movement: WASD camera-relative, normalized diagonal, acceleration/braking, fixed jump, no held autojump, grace/buffer, air steering.
- Camera: orbit, pitch limits, obstacle avoidance, reset on respawn; no water penetration during play.
- Course: complete all nine gaps with normal movement and jump controls; inspect visible/collision edges.
- Failure: repeated falls, one splash per fall, about one-second retry, no stale velocity or input.
- Pause: Escape, HUD button, focus loss and pointer lock loss; pause airborne, resume, no stuck keys.
- Victory: goal requires island grounding, occurs once, mouse released, replay and restart reset progression.
- Presentation: real running screenshots of title, gameplay, pause, victory; 1280×720 and smaller desktop fit.
- Audio/performance: mute behavior, local bundled files, browser console, sampled FPS and environment recorded.

## Outcome
Implemented the one-level milestone with original procedural artwork and synthesized audio. Kept the proposed desktop/Godot architecture and session-only customization. The first pad gap was widened after collision testing showed that a character could occasionally stride across the original spacing. Progress tracking now consumes the current physics step, preventing stale landing information after restart. Mouse capture ignores its initial cursor warp, and both left click and Escape can pause.

The final source and browser build are local. Test evidence and limitations are recorded separately in TEST_REPORT.md. Larger-game ideas remain future work.

## Version 0.2 — Frog river

User-requested second level: start with a baseball bat and defeat frogs along the path to cross the river.

- Visual thesis: keep the sunny miniature river, add chunky olive-green frogs with bright eyes and a warm wooden bat; defeats use a flip, shrink, and cream-colored puff.
- Content plan: title-screen crossing selection, a Next level action after the lagoon, minimal bat/control hints and a six-frog counter, and a clear finish condition at the flag.
- Interaction thesis: a readable bat wind-up/sweep/recovery, idle frog hops, and immediate hit sound/puff feedback.
- Implementation: separate level resource, reusable frog actors, directional timed melee, solid frog collision, level transitions and resets. Defeated frogs stay cleared after a water fall; restarting restores them all. No health system or additional weapons in this increment.
- Verification: native range/facing/cooldown/vertical/pause/reset/goal checks; normal-input browser crossing with all six defeats; Level 1 regression and visual review.

## Version 0.3 — Red-frog decoys

Add four optional false branches to Frog River. Each fake pad has a red warning frog; the existing six green combat frogs stay on the safe route. Red markers are not enemies or footholds and cannot be removed with the bat. A real landing on a fake pad removes support immediately, sinks the pad and its red marker, and drops the player into the existing water-retry flow. A flyover does not trigger a pad. Pause freezes the collapse. Retry restores decoys but preserves defeated green frogs; restart resets both. The HUD and title explain the colors. Verify actual contact, buffered-jump escape prevention, marker immunity, progress counts, pause/retry/reset, every trap, and a complete normal-input safe crossing.

## Version 0.4 — Frog poison and health

Landing on a pad with a living green frog applies poison. It drains 20 percentage points of health per second, persists after jumping away, and does not stack. A successful green-frog defeat cures poison and restores exactly 100% health. Empty/cleared pads and red decoy markers do not apply poison. At zero, a distinct poison defeat freezes the character, shows the empty meter and a short collapse/puff, then retries after 1.2 seconds at full health. Pause/focus loss freeze both damage and retry. Water/decoy retries also reset health; cleared green frogs remain cleared until restart. Add percentage/bar/status feedback and subtle purple particles. Validate actual pad and frog-top contact, damage rate, airborne persistence, heal-on-kill only, zero-health death once, recovery, pause, reset, and full-route playability.

The same release adds user-requested Level 3, Lucky Lagoon: a short five-gap route with two yellow-frog pads and two ordinary rest pads. Each yellow pad uses one independent random draw on first contact, with a strict 0.5 sink threshold. A held pad remains solid until retry/restart; standing or hopping on it does not reroll. Gameplay randomness has its own freshly seeded RNG, separate from deterministic scenery. Yellow markers are not poison enemies and cannot be used as footholds. Show the odds and outcome, add a third title option and Level 2 → Level 3 transition, and check both outcomes, one-roll behavior, reset, and a normal-input successful crossing without forcing browser randomness.


## Version 0.5 — Secret Perch

Turn the discovered stone pillars to the left of the starting pad into an optional secret achievement. Preserve their geometry and random placement while separating the five stone colliders from the surrounding scenery. Award only on a grounded top contact; passing above or hitting the side does not count. Keep the pillar usable as a perch.

Award Secret Perch once, with a gold/purple badge, brief confetti and the existing celebration sound. Unlock and immediately equip a purple Moonflower hoodie. Keep the three original swatches and place the reward in a title-screen badge card. Persist only the achievement flag locally (browser localStorage or a native ConfigFile); retain the reward for the visit if saving is blocked. Course progress and outfit selections remain session-local.

Verify actual top/side/airborne contact, stable support, one-time awarding, pause behavior, restart/water retry/level transitions, local save/reload, original and reward wardrobe choices, and denied storage. Complete a normal-input browser jump onto the existing pillar, check the actual rendered badge and outfit, then rerun the three-course browser regression suite.


## Version 0.5.1 — Preserve facing when swinging

Fix the reported 180-degree snap when attacking after turning backwards. `request_swing` previously copied camera yaw into the avatar and used that camera direction for damage. Remove the rotation assignment and snapshot the avatar’s current yaw for the attack. Keep that heading through the existing swing/recovery, independently of camera orbit. Movement can turn the character again after recovery.

Add native regression checks for backward/left/right movement, F and mouse swings, camera orbit during wind-up, a real backward frog hit, healing, and post-swing movement. Reproduce the failure before the fix. Update pre-existing directional test fixtures to set character facing explicitly. Check normal-input backward and sideways swings in the Web build, then complete Frog River with all six kills to verify existing combat.


## Version 0.6 — Character wardrobe

- Visual thesis: keep the sunny voxel character and warm paper palette, with a large turnable 3D preview as the center of a spacious dressing screen.
- Content plan: a Customize action on the title and pause screens; Character, Hair, Tops, Pants, and Shoes categories; a small set of named styles and colors; explicit Save outfit and Cancel actions. Keep existing quick colors and the Secret Perch shortcut.
- Interaction thesis: immediate preview changes, a gentle idle/ponytail animation, and smooth button/drag rotation. Preview edits are separate from the actual character until saved.

Implement independent Boy/Girl/Neutral character options, six skin tones, six hairstyles and colors, three top/pants/shoe styles and six colors for each. Any style can be combined with any character option. Preserve the character root, animation clocks, bat state, and physics capsule when rebuilding appearance. Editing from pause keeps poison, movement, and combat frozen and returns to pause on save or cancel.

Persist validated outfit indices and the optional name locally, retaining the existing achievement key and native file. Locked Moonflower data cannot equip the reward. Missing or malformed data falls back to defaults. A failed write keeps the outfit active for this visit. Native tests isolate their profile files to avoid changing the player's outfit.

Verify preview-only editing, cancel/Escape, all categories and colors, rotation, saved names with quotes, refresh, old achievement migration, corrupt data, unavailable storage, the earned Moonflower option, small-window controls, and changing clothes during a paused swing. Recheck movement, combat/facing, poison, traps, chance pads, and the secret achievement with the modular avatar.


## Version 0.6.1 — Discover Frog River

Remove the red/green legend and duplicate instructions from the title, health meter, attack/splash notices, and completion messaging. Hide the combat objective counter, which otherwise still tells players which frogs to defeat. Keep controls, the reach-the-flag goal, health percentage/status, and immediate feedback such as poison, sinking, misses, and healing. The blocked finish gives a neutral status instead of a solution. Frog behavior and level requirements remain unchanged. The Level 3 chance information is outside this red/green-key change. Keep detailed developer mechanics in a collapsed spoiler section of the README. Verify the exported screens and reuse the existing combat/decoy checks and full Frog River browser playthrough.


## Version 0.7 — Skill can beat Lucky Lagoon

The existing five-gap route requires both yellow pads to hold. Keep those two independent 50/50 pads as broad, short-route options, and add six permanent smaller pads in two winding branches. Each branch bypasses one yellow pad and rejoins an ordinary rest pad. A player can choose either route independently at each branch; reaching the flag never requires a random result.

- Visual thesis: two readable arcs of small green leaves frame the wide yellow-frog shortcuts in the existing sunny voxel lagoon.
- Content plan: keep the crossing goal and controls; replace the mandatory-looking yellow-pad completion counter with neutral route selection copy. Keep the existing yellow odds and immediate outcomes.
- Interaction thesis: narrow landings reward aiming, braking, and camera control; wide rest pads allow planning the next branch; chance pads retain their existing hold/sink motion and feedback.

Implement bypass platforms as data-driven, permanently solid mesh colliders. Preserve the original shortcut positions, controller physics, 50/50 roll behavior, other levels, and existing scenery/pillar positions. Verify a continuous input-driven crossing with both yellow supports removed before spawn, then verify the safe route and ordinary random shortcut behavior in the exported browser build. Both routes rejoin at the same rest pads, so each branch can be chosen independently.


## Version 0.8 — Fireflies, drifting pads, readable frogs

Add the three requested engagement features: exactly three hidden collectible fireflies in each crossing, moving lily pads with fixed repeating patterns, and green frogs with telegraphed movement.

- Visual thesis: small golden winged lights draw attention to quiet side paths while the existing sunny voxel lagoon remains the dominant scene.
- Content plan: a compact firefly count in the HUD and counts on the level-selection buttons; brief pickup feedback; keep route and frog-color solutions out of the UI.
- Interaction thesis: fireflies bob and flutter, drifting pads ease between endpoints and dwell before reversing, and green frogs squash before a marked hop and recover after landing.

Keep all existing stable crossing routes, including Level 3's solid bypasses. Add an optional drifting pad to each level with a collectible onboard, plus a small fixed exploration pad and a final tucked-away firefly. Place all collectibles on routes reachable without favorable random results. Use fixed-step physical moving platforms that carry standing players. Freeze motion, pickups, and frog phases during pause/customization; restart resets predictable motion.

Persist each unique firefly immediately per level in the local profile, preserving wardrobe and Secret Perch data. Validate malformed saves, prevent duplicate awards, and retain session progress with honest feedback if saving is unavailable. Do not add medals, currency, or new cosmetic rewards in this increment.

Green enemies retain poison, one-hit bat defeats, and healing. Their short hops move the actual body within their own pad, with a crouch and landing marker before each jump and a long grounded recovery window. Red and yellow markers keep their existing behavior. Check collection identity/persistence, all nine locations, platform carry/pause/jump-off/repetition, telegraph ordering/reset/defeat, the complete three courses, and Level 3 with both chance supports absent.
