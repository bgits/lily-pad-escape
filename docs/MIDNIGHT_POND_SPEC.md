# Midnight Pond — two-player duel: design and code contract

Midnight Pond is a local, same-keyboard, two-player competitive level for Lily Pad Escape
(Godot 4.6, GDScript, Compatibility renderer, single-threaded web export, no backend).
It is a self-contained mode under `game/scripts/duel/`. The three single-player levels and
their scripts must keep working unchanged.

This file is the contract between the pieces. Class names, member names, signatures and
numbers here are binding unless marked "tunable" (keep the default, expose it as a `var`).

## 1. The game in one paragraph

A three-minute night-time match on one circular pond, seen from one fixed camera. Fireflies
appear on the pads. A player who touches one **carries** it (a glowing swarm trails behind
them). Carried fireflies only score when the player lands on their own **lantern pad**
(**banking**). A bat hit knocks the other player back and makes them drop half their swarm.
Most banked fireflies when the timer ends wins; a tie becomes sudden death.

Phases by match clock (all durations tunable vars on `LilyDuel`):

| Phase | Clock | What changes |
|---|---|---|
| `countdown` | 3 s before 0:00 | Players frozen on their lantern pads, "3 2 1 Hop!" |
| `dusk` | 0:00–1:00 | Fireflies spawn. Middle-ring pads sink when stepped on. |
| `midnight` | 1:00–2:00 | Lotus opens, the Firefly Queen appears, two poison frogs wake. |
| `flood` | 2:00–3:00 | Pads sink for good on a schedule (section 6). |
| `sudden_death` | only on a tie | Both players on the centre lotus; first in the water loses. |
| `over` | | Result panel: Rematch / Back to title. |

## 2. Coordinates, arena layout, camera

Y is up. Water surface `WATER_HEIGHT = 0.04`. Every pad's standing surface is at
`SURFACE_HEIGHT = 0.60`. Arena centre is the world origin. A pad at ring radius `r` and
angle `a` degrees sits at `x = r*cos(a)`, `z = r*sin(a)`.

| id | Kind | Position | Pad radius | Behaviour |
|---|---|---|---|---|
| 0 | `CENTER` | origin | 2.6 | Always solid. Lotus bud in the middle (no collision). |
| 1–8 | inner ring, r = 6.0, a = 0,45,…,315 | | 1.45 | ids 1 (a=0) and 5 (a=180) are `YELLOW`; the other six are `MIDDLE` |
| 9–20 | `OUTER`, r = 10.6, a = 0,30,…,330 | | 1.9 | Solid until the flood. ids 9 (a=0) and 15 (a=180) are the "bridge" pads next to the lanterns. |
| 21 | `HOME` player 0 | (-15.8, 0) | 2.0 | Always solid. Gold lantern. |
| 22 | `HOME` player 1 | (+15.8, 0) | 2.0 | Always solid. Cyan lantern. |

Player 0 is "P1" (left/west, gold `ffd75e`), player 1 is "P2" (right/east, cyan `6fd3ff`).

Camera: one fixed `Camera3D`, roughly `position (0, 24, 19)` looking at `(0, 0, 1.5)`, fov ≈ 50,
tuned so all 23 pads are fully on screen at 16:9 with room for a HUD band along the top.
Screen-up is world −Z, screen-right is world +X. There is no mouse look and no split screen.

Movement numbers match the single-player controller (`game/scripts/player.gd`): speed 5.4,
acceleration 32, braking 42, air steering 16, jump speed 8.4, gravity 22, coyote 0.10 s,
jump buffer 0.12 s. A full-speed jump covers about 4.1 m, so edge-to-edge gaps above ~2.6 m
are not reliably jumpable. The layout above keeps every neighbouring gap under 2.3 m.

## 3. Controls (one keyboard)

| | Move | Jump | Swing bat |
|---|---|---|---|
| P1 | W A S D | Space | F |
| P2 | Arrow keys | Enter (also keypad Enter) | `/` (also Shift) |

Esc pauses/resumes. R restarts the match while paused or on the result panel.

Input actions (created at runtime with `physical_keycode`, only if missing):
`duel_p1_left`, `duel_p1_right`, `duel_p1_up`, `duel_p1_down`, `duel_p1_jump`, `duel_p1_swing`
and the same with `duel_p2_`. Never reuse the single-player actions (`move_left`, `jump`, …).

UI rule: no `Button` in duel mode may take keyboard focus (`focus_mode = Control.FOCUS_NONE`),
because Space and Enter are jump keys and would "press" a focused button.

## 4. Night look

Dark blue sky, low bluish ambient light, a dim moon `DirectionalLight3D` with shadows, deep
teal water (`res://shaders/water_night.gdshader`, a darker copy of `water.gdshader`; do not
edit the original). Pads are a darker, cooler green than the daytime levels. Light sources
are the point: fireflies, the two lanterns, the Queen, and the glow around each player.
**Readability beats darkness**: both avatars, every pad edge and every pad state must be
easy to read at a glance from the fixed camera. Geometry is built procedurally in GDScript
like the rest of the game (`LilyAvatar.box`, `LilyAvatar.material`, `LilyWorld.block`,
`LilyWorld.quad`, `LilyWorld.vertex_material` are reusable static helpers).

## 5. Code layout and contracts

All new scripts live in `game/scripts/duel/`. Physics layers follow the existing game:
pads/scenery layer 1, players layer 2 with mask `1 | 4`. Players do not collide with each other.

### `duel_pad.gd` — `class_name LilyDuelPad extends StaticBody3D`

```gdscript
enum Kind { CENTER, MIDDLE, OUTER, YELLOW, HOME }
signal sank(pad: LilyDuelPad)   # emitted on the physics frame its collision is removed
signal rose(pad: LilyDuelPad)   # emitted when it is solid again
var pad_id: int
var kind: Kind
var radius: float
var angle_degrees: float        # ring angle; 0 for centre and homes
var owner_index := -1           # 0 or 1 for HOME pads
var state := "solid"            # "solid" | "warning" | "sunk" | "rising" | "gone"
var spent := false              # YELLOW only, see section 7
func is_standable() -> bool                     # collision present: state is solid or warning
func trigger_sink(warning: float, down_time: float) -> bool
    # Starts warning (visible wobble / tint) for `warning` seconds, then removes collision,
    # sinks the visual over ~0.55 s, stays down `down_time` seconds, rises over ~0.6 s and
    # becomes solid again. down_time < 0 means permanent: final state "gone".
    # Returns false (no-op) unless state is "solid"; a permanent request also overrides
    # "warning"/"sunk"/"rising" so the flood always wins.
func set_spent(value: bool) -> void             # YELLOW visual tell (cracked / dimmed)
func advance(delta: float) -> void              # all timing runs here, never on its own
func reset_pad() -> void                        # back to solid, timers and spent cleared
func surface_center() -> Vector3                # global, y = SURFACE_HEIGHT
func contains_xz(point: Vector3, margin := 0.0) -> bool
func random_point(rng: RandomNumberGenerator, fraction := 0.6) -> Vector3  # on the surface
```

### `duel_arena.gd` — `class_name LilyDuelArena extends Node3D`

```gdscript
const WATER_HEIGHT := 0.04
const SURFACE_HEIGHT := 0.60
var pads: Array[LilyDuelPad]            # index == pad_id, 23 entries
var center_pad: LilyDuelPad
var middle_pads: Array[LilyDuelPad]     # the six MIDDLE pads
var yellow_pads: Array[LilyDuelPad]     # [id 5 (west), id 1 (east)]
var outer_pads: Array[LilyDuelPad]
var home_pads: Array[LilyDuelPad]       # [player 0, player 1]
var camera: Camera3D
var lotus_open := false
func build() -> void                    # call once after add_child
func advance(delta: float) -> void      # physics-rate: advances every pad
func animate(delta: float) -> void      # frame-rate: particles, lotus, lantern flicker, ripples
func reset_arena() -> void              # all pads reset, lotus closed, particles cleared, lanterns at score 0
func spawn_point(player_index: int) -> Vector3      # on that player's home pad, y = SURFACE_HEIGHT + 0.08
func pad_at(point: Vector3) -> LilyDuelPad          # standable pad whose disc contains the XZ point, else null
func nearest_standable(point: Vector3, count: int, allow_home := false, allow_center := true) -> Array[LilyDuelPad]
func open_lotus() -> void               # animated; sets lotus_open
func queen_perch() -> Vector3           # global point ~1.7 m above the centre pad surface
func set_lantern_score(player_index: int, score: int) -> void   # lantern light/glow grows with score
func splash(pos: Vector3) -> void
func firefly_puff(pos: Vector3) -> void
func burst(pos: Vector3, color: Color, count := 16) -> void
func bonk(pos: Vector3) -> void         # "BONK!" label + puff, like LilyWorld.frog_puff
func celebrate(pos: Vector3) -> void
func clear_particles() -> void
```

The arena owns the `WorldEnvironment`, moon, water, pads, lanterns, lotus, distant scenery
and the camera. It must not reference `LilyDuel`, players, frogs or the HUD.

### `duel_player.gd` — `class_name LilyDuelPlayer extends CharacterBody3D`

```gdscript
signal jumped(player: LilyDuelPlayer)
signal swung(player: LilyDuelPlayer)
signal bat_impact(player: LilyDuelPlayer)   # 0.12 s into the 0.48 s swing
signal stepped(player: LilyDuelPlayer, delta: float)  # end of every active physics tick
var index := 0                  # 0 = P1, 1 = P2
var active := false             # false: no movement, no input, no gravity
var avatar: LilyAvatar
var carried := 0
var has_queen := false
var health := 100.0
var poisoned := false
var speed_scale := 1.0          # LilyDuel sets 0.85 while holding the Queen
var stun_remaining := 0.0
var invulnerable_remaining := 0.0
var swing_remaining := 0.0
var attack_direction := Vector3.FORWARD
var falling_through := false
static func configure_input() -> void          # creates the actions in section 3
func setup(player_index: int, outfit: Dictionary) -> void   # call before add_child
func respawn(spawn: Vector3, face_direction: Vector3) -> void   # also clears stun, poison visuals, velocity
func request_swing() -> void
func bat_reaches(target: Vector3) -> bool      # range 2.3 m, facing dot >= 0.20, vertical 1.1 m
func knockback(direction: Vector3, horizontal_speed := 9.0, up_speed := 5.0, stun := 0.45) -> void
    # Sets velocity, ignores input and braking for `stun` seconds, invulnerable for 0.8 s.
func drop_through() -> void                    # like LilyPlayer.drop_through: no input/jump until respawn
func set_carried(count: int) -> void           # updates the trailing swarm (show up to 12 motes) and glow
func set_poisoned(value: bool) -> void         # purple cloud like LilyPlayer
func set_queen(value: bool) -> void            # stores has_queen only; the Queen node draws itself
func clear_input() -> void
```

Each player always holds the bat, has a coloured ring on the ground under them and a small
"P1"/"P2" `Label3D` above the head (player colours from section 2), and a soft `OmniLight3D`
whose energy grows with `carried`. Movement is screen-relative (section 2), the avatar faces
its movement direction, swings go where the avatar faces.

### `duel_frog.gd` — `class_name LilyDuelFrog extends Node3D`

```gdscript
signal landed(frog: LilyDuelFrog)
var pad: LilyDuelPad            # the pad it sits on, or is flying to
var state := "sitting"          # "sitting" | "flying" | "gone"
func place(target: LilyDuelPad) -> void                 # instantly sit on a pad
func launch_to(target: LilyDuelPad, duration := 0.6) -> void   # arc flight, then `landed`
func dismiss() -> void                                  # puff away, state "gone", hidden
func advance(delta: float) -> void
```

Looks like the existing green frog (`game/scripts/frog.gd`); no collision with players.
It sits off-centre on its pad and faces the nearest player-agnostic direction (centre is fine).

### `duel_queen.gd` — `class_name LilyDuelQueen extends Node3D`

```gdscript
var state := "hidden"           # "hidden" | "perched" | "held" | "returning"
var holder: LilyDuelPlayer
func appear(perch: Vector3) -> void             # perched above the lotus
func give_to(player: LilyDuelPlayer) -> void    # orbits above that player's head
func return_to_perch() -> void                  # flies back over ~1 s, then perched
func hide_queen() -> void
func can_be_taken_by(player: LilyDuelPlayer) -> bool   # perched and within 1.2 m horizontally, 2.5 m vertically
func advance(delta: float) -> void
```

A large golden firefly with a small crown and its own `OmniLight3D`.

### `duel_hud.gd` — `class_name LilyDuelHud extends CanvasLayer`

Pure presentation; it never reads game objects.

```gdscript
signal resume_requested
signal rematch_requested
signal exit_requested
func set_names(p1: String, p2: String) -> void
func set_time(seconds_left: float, phase: String) -> void    # "1:42" plus phase name
func set_scores(banked: Array, carried: Array) -> void       # two ints each
func set_health(player_index: int, health: float, poisoned: bool) -> void  # bar shown only while poisoned
func set_queen(holder_index: int) -> void                    # -1 nobody; crown marker on that side
func show_toast(text: String, seconds := 2.0) -> void
func show_countdown(text: String) -> void                    # big centre text; "" hides it
func show_pause(visible_now: bool) -> void                   # overlay: Resume / Rematch / Back to title
func show_result(title: String, detail: String) -> void      # overlay: Rematch / Back to title
func hide_result() -> void
func advance(delta: float) -> void                           # toast timers
func debug_snapshot() -> Dictionary
```

### `duel.gd` — `class_name LilyDuel extends Node3D` (match rules)

```gdscript
signal exit_requested
var arena: LilyDuelArena
var players: Array[LilyDuelPlayer]
var hud: LilyDuelHud
var queen: LilyDuelQueen
var frogs: Array[LilyDuelFrog]
var loose_fireflies: Array[LilyFirefly]
var phase := "countdown"
var elapsed := 0.0              # match clock, starts after the countdown
var paused := false
var scores: Array[int] = [0, 0]
var winner := -1
func begin(outfit: Dictionary, p1_name: String) -> void   # builds everything and starts a match
func start_match() -> void                                # also used for Rematch
func toggle_pause() -> void
func set_elapsed(seconds: float) -> void                  # tests: jump the clock; transitions apply next tick
func spawn_firefly(pad: LilyDuelPad, at := Vector3.INF) -> LilyFirefly
func hit_player(attacker: LilyDuelPlayer, victim: LilyDuelPlayer) -> void
func take_out(player: LilyDuelPlayer, cause: String) -> void   # "water" | "poison"
func debug_snapshot() -> Dictionary
```

`game/scripts/game.gd` only does: `duel = LilyDuel.new(); add_child(duel);
duel.exit_requested.connect(...); duel.begin(profile.outfit, name)` and frees it on exit.
`LilyDuel` handles its own Esc/R input, pause on focus loss (skip when headless), sounds
(its own `AudioStreamPlayer`s from `res://assets/audio/*.wav` at −12 dB) and camera.

## 6. Rules and numbers (all tunable `var`s on `LilyDuel`)

**Fireflies.** Reuse `LilyFirefly` (`game/scripts/firefly.gd`). A spawner adds one loose
firefly every 1.6 s (1.0 s during `flood`) while fewer than 7 are loose, on a random
solid (not warning) non-home pad with no firefly on it, weighted MIDDLE ×3, YELLOW ×2, others ×1,
hovering 0.9 m above the surface. A player whose position satisfies `fly.can_collect(pos)`
picks it up: `carried += 1`. No carry cap.

**Banking.** A player grounded on their own home pad with `carried > 0` banks everything at
once: `scores[i] += carried * (2 if has_queen else 1)`, `carried = 0`, lantern grows.

**Bat on a player.** Impacts are queued and resolved together at the start of the next
physics tick, so two swings that land on the same tick both count. For each impact, if the
other player is active, not invulnerable, not already dropping through a pad, and
`bat_reaches` them: knock them back along the attacker's `attack_direction`; they drop
`ceil(carried / 2)` fireflies; if they hold the Queen she goes to the attacker. In
`sudden_death` knockback speed is ×1.6.

**Dropped fireflies** become loose fireflies scattered at random points on the nearest
standable non-home pad plus up to two more whose edge is within 4.5 m of the drop point
(ignore the 7 cap).

**Middle ring.** When a player is grounded on a solid MIDDLE pad: `trigger_sink(0.9, 4.0)`.

**Yellow pads.** A fresh yellow pad rolls 50/50 the first time a player is grounded on it:
*sink* → `trigger_sink(0.0, 5.0)` and `player.drop_through()`; *hold* → it stays solid, and
when that player leaves it becomes **spent** (`set_spent(true)`). A spent pad always sinks
under the *other* player. The player it held for rolls a fresh 50/50 each time they land on
it again (so a round trip over your own yellow pad is two gambles, never a certainty). If
the other player lands on a pad while its holder is still standing on it, it sinks under
both. When a yellow pad rises again it is fresh. The roll uses an RNG that tests can replace.

**Water and respawn.** A player below `WATER_HEIGHT - 0.18` is taken out: splash, drop all
carried fireflies (scattered as above, near where they fell), Queen returns to her perch,
poison cleared, respawn on their home pad after 1.2 s with full health and 1.5 s of
invulnerability to bat hits. Same for poison death (cause `"poison"`).

**Standing on a pad** includes its rim: a grounded player up to 0.35 m past a pad's nominal
radius counts as on that pad. A player who is dropping through a pad but ends up back on
solid footing regains control.

**Midnight.** `arena.open_lotus()`, Queen `appear`s. A player for whom `can_be_taken_by` is
true takes her: `has_queen`, `speed_scale = 0.85`, banks count double. Two frogs are placed
on outer pads 12 (a=90) and 18 (a=270).

**Frogs and poison.** A player grounded on a pad with a sitting frog, or on the pad a frog
lands on, becomes poisoned: health drains 15 per second; at 0 they are taken out. A bat
impact that reaches a sitting frog (frog position) launches it: target = the pad the
opponent stands on if it is a legal target within a cone (dot ≥ 0.5 with `attack_direction`)
and 10 m; else the nearest legal pad in that cone; else the nearest legal pad. Legal = standable,
not HOME, not CENTER, no frog, not its current pad. Batting a frog cures the batter's
poison and restores 100 health. If a frog's pad sinks, the frog hops to the nearest legal
pad, or is dismissed if none exists.

**Flood** (seconds after the flood starts; every sink is `trigger_sink(1.5, -1)`):
0 s outer pads at a=90,270 · 8 s outer a=60,120,240,300 · 20 s middle a=90,270 ·
30 s middle a=45,135,225,315 · 31 s outer a=30,150,210,330 · 52 s both yellow pads and both
bridge pads (ids 9, 15). Until the 30 s and 31 s steps land there is a gamble-free route
home (centre → middle a=45… → outer a=30… → bridge); after them the only way home is a
yellow pad, announced with a toast at 31 s. Loose fireflies on a pad
that is gone move to the nearest standable pad.

**End.** At the end of the flood: higher score wins. Equal scores → `sudden_death`: clear
carried fireflies, loose fireflies, frogs and Queen; put both players on the centre pad at
x = ∓1.3 facing each other; 2 s freeze; then the first player taken out loses. If both go
into the water together, sudden death restarts.

**`debug_snapshot()` keys:** `mode:"duel"`, `state:"duel"`, `phase`, `elapsed`, `time_left`, `paused`, `scores`,
`carried`, `health`, `poisoned`, `winner`, `queen:{state, holder}`, `players:[{position,
velocity, grounded, stunned, active}]`, `pads:[{id, kind, state, spent}]`,
`fireflies:[[x,y,z],…]` (loose only), `frogs:[{pad, state}]`, `hud` (the HUD snapshot).

## 7. Tooling

- Engine: `GODOT="$PWD/.tools/Godot.app/Contents/MacOS/Godot"` from the repository root.
- Register new `class_name`s: `"$GODOT" --headless --path game --editor --import --quit`
  (other agents may run this at the same time; if you see stale-class errors, run it again).
- Run a native test: `"$GODOT" --headless --path game --script res://tests/<name>.gd`
- Native tests follow `game/tests/decoy_test.gd`: `extends SceneTree`, `check(cond, message)`
  printing `PASS:` / pushing `FAIL:`, a final `<NAME> RESULT: N passed, M failed` line and
  `quit(1 if failures else 0)`. They drive real physics frames, not mocked state.
- GDScript style: tabs, typed where the existing code is typed, no new addons or assets
  beyond what the spec names. Godot generates `.uid` files next to new scripts; keep them.

## 8. Graphics pass

Goal: make the night pond look striking while keeping the blocky style, every rule, and a
steady frame rate in the single-threaded web build (Compatibility renderer: no volumetric
fog, no screen-space reflections, no SDFGI). Effects add light and motion; they never change
collision, timing or any number in section 6. Every existing native suite must keep passing
unchanged. No per-frame node creation, mesh creation or material creation in steady state:
pool and reuse. No image or audio assets: textures are generated in code
(`GradientTexture2D`, `NoiseTexture2D`, `ImageTexture`).

### `duel_water.gd` — `class_name LilyDuelWater extends Node3D`

Replaces the plain water plane. Uses `res://shaders/water_night.gdshader` (rewritten).

```gdscript
const MAX_RIPPLES := 24
const MAX_REFLECTIONS := 16
func build(size := 350.0, height := 0.04) -> void
func add_ripple(point: Vector3, strength := 1.0) -> void
    # An expanding, fading ring on the surface (~1.6 s, reaching ~3 m × strength).
    # More than MAX_RIPPLES at once replaces the oldest.
func flash(point: Vector3, color: Color, strength := 1.0) -> void
    # Bioluminescent bloom in the water around a point, fading over ~1.2 s.
func set_reflections(lights: Array) -> void
    # Each entry {"position": Vector3, "color": Color, "energy": float}. Up to
    # MAX_REFLECTIONS (extra entries ignored). Each is drawn on the water as a soft,
    # wobbling streak of that colour stretching from below the light toward the camera.
func set_camera_position(point: Vector3) -> void
func set_moon_direction(direction: Vector3) -> void   # direction the moonlight travels; draws a shimmering moon path
func set_palette(deep: Color, light: Color, glint: Color) -> void
func set_level(height: float) -> void                 # visual surface height only
func advance(delta: float) -> void
func debug_snapshot() -> Dictionary                   # ripples (count), flashes, reflections, level
```

### `duel_atmosphere.gd` — `class_name LilyDuelAtmosphere extends Node3D`

Owns the `WorldEnvironment` (with glow/bloom if the Compatibility renderer supports it in
this engine version; `glow_supported` says so), sky with stars and a visible moon, the moon
`DirectionalLight3D` (shadows on), low mist drifting over the water, swaying reeds and dark
island silhouettes beyond the play area, and tiny distant fireflies for depth. Nothing may
cover any pad from the fixed camera at `(0, 24, 19)` looking at `(0, 0, 1.5)`, fov 50, and
nothing has collision.

```gdscript
var environment: Environment
var moon: DirectionalLight3D
var glow_supported := false
func build() -> void
func set_phase(phase: String, instant := false) -> void
    # Looks: "countdown"/"dusk" warm purple twilight · "midnight" deep blue ·
    # "flood" cold and urgent · "sudden_death" stark, high contrast · "over" calm.
    # Changes blend over ~2.5 s inside animate(). Unknown names behave like "dusk".
func water_palette() -> Dictionary      # current blended {"deep": Color, "light": Color, "glint": Color}
func moon_direction() -> Vector3
func pulse(strength := 1.0) -> void     # a brief swell of light (lotus opening), ~0.8 s
func animate(delta: float) -> void
func debug_snapshot() -> Dictionary     # phase, blend (0..1), glow_supported
```

Readability still beats mood in every phase: both avatars, every pad edge and pad state
must stay easy to read.

### Entity effects (same classes, same public API as section 5, plus:)

- `LilyDuelPlayer`: a player-coloured rim light or outline so the silhouette pops against the
  dark; the carried swarm drawn as soft additive sparks with ribbon trails (a comet tail at
  12); a short streak behind a knocked-back player; `func flash_hit() -> void` (brief white
  flash). `visible_mote_count()` keeps working.
- `LilyDuelQueen`: golden trail while moving and slowly turning light rays.
- `LilyDuelPad`: the rim pulses with light before a pad sinks (warm for a stepped-on pad,
  red when `permanent`), in addition to the wobble.
- Shared helpers may live in `duel_fx.gd` (`class_name LilyDuelFx`).

### Match feel (wired in `duel_arena.gd` / `duel.gd`)

- `LilyDuelArena`: builds `LilyDuelWater` and `LilyDuelAtmosphere` instead of its own
  environment and water; new `func shake(strength := 1.0) -> void` (decaying camera shake that
  always returns the camera exactly to its base transform), `var water: LilyDuelWater`,
  `var atmosphere: LilyDuelAtmosphere`.
- Ripples when a player lands or a pad sinks or rises; a flash where a player falls in.
- Reflections fed each frame from the lanterns, the Queen, players carrying fireflies and
  the nearest loose fireflies.
- Phase looks follow the match phase; the lotus opening pulses the light; during the flood
  the visual water level creeps up (never above y = 0.30; rules keep using `WATER_HEIGHT`).
- Bat hit on a player: a few frames of hit-stop (tunable `hit_stop_seconds`, default 0.07,
  must not change any rule timing measured in match time), camera shake, `flash_hit()`,
  and a burst of light where fireflies scatter.
