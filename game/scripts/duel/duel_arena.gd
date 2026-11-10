class_name LilyDuelArena
extends Node3D

const WATER_HEIGHT := 0.04
const SURFACE_HEIGHT := 0.60
const HOME_X := 15.8
const LOTUS_PETALS := 8
const LOTUS_OPEN_TIME := 1.0

var pads: Array[LilyDuelPad] = []
var center_pad: LilyDuelPad
var middle_pads: Array[LilyDuelPad] = []
var yellow_pads: Array[LilyDuelPad] = []
var outer_pads: Array[LilyDuelPad] = []
var home_pads: Array[LilyDuelPad] = []
var camera: Camera3D
var lotus_open := false
var piece_mesh: BoxMesh

var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var glow_materials: Dictionary = {}
var lotus: Node3D
var lotus_petals: Array[Node3D] = []
var lotus_core: MeshInstance3D
var lotus_progress := 0.0
var built := false

# Graphics pass (spec section 8).
const MAX_WATER_LEVEL := 0.30
# In sudden death the visual water stays close to the level the rule actually counts.
const SUDDEN_DEATH_WATER_LEVEL := 0.12
# Pad outline rings are only moved when the visual level has moved by more than this.
const RING_STEP := 0.01
# Splash pieces start this far above the visual surface (0.12 at the resting level).
const SPLASH_LIFT := 0.08
const SHAKE_TIME := 0.25
const SHAKE_MAX_POWER := 1.5
const SHAKE_OFFSET := 0.16
const SHAKE_ROLL := 0.012
const LANTERN_ENERGY_MIN := 1.2
const LANTERN_ENERGY_MAX := 2.4
var atmosphere: LilyDuelAtmosphere
var water: LilyDuelWater
var water_level := WATER_HEIGHT
var water_level_target := WATER_HEIGHT
var ring_level := WATER_HEIGHT
var camera_base := Transform3D.IDENTITY
var shake_left := 0.0
var shake_power := 0.0
var palette_pending := true
var last_camera_position := Vector3.INF
var last_moon_direction := Vector3.ZERO
var lantern_lights: Array = []

func build() -> void:
	if built:
		return
	built = true
	rng.seed = 90210
	build_atmosphere()
	build_water()
	build_pads()
	build_lotus()
	build_camera()

func build_atmosphere() -> void:
	atmosphere = LilyDuelAtmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.build()
	atmosphere.set_phase("dusk", true)

func build_water() -> void:
	water = LilyDuelWater.new()
	water.name = "Water"
	water.position = Vector3.ZERO
	add_child(water)
	water.build(350.0, WATER_HEIGHT)
	water.set_reflections([])
	apply_water_look()

func apply_water_look() -> void:
	var palette := atmosphere.water_palette()
	water.set_palette(palette["deep"], palette["light"], palette["glint"])
	var moon := atmosphere.moon_direction()
	if moon != last_moon_direction:
		last_moon_direction = moon
		water.set_moon_direction(moon)

func add_pad(id: int, kind: LilyDuelPad.Kind, pos: Vector3, radius: float, angle: float, owner := -1) -> LilyDuelPad:
	var pad := LilyDuelPad.new()
	pad.setup(id, kind, radius, angle, owner)
	pad.position = pos
	add_child(pad)
	pads.append(pad)
	return pad

func build_pads() -> void:
	center_pad = add_pad(0, LilyDuelPad.Kind.CENTER, Vector3.ZERO, 2.6, 0.0)
	for i in 8:
		var angle := i * 45.0
		var pos := Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * 6.0
		var yellow := i == 0 or i == 4
		var pad := add_pad(1 + i, LilyDuelPad.Kind.YELLOW if yellow else LilyDuelPad.Kind.MIDDLE, pos, 1.45, angle)
		if not yellow:
			middle_pads.append(pad)
	# Spec order: [id 5 (west), id 1 (east)].
	yellow_pads = [pads[5], pads[1]]
	for i in 12:
		var angle := i * 30.0
		var pos := Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * 10.6
		outer_pads.append(add_pad(9 + i, LilyDuelPad.Kind.OUTER, pos, 1.9, angle))
	home_pads.append(add_pad(21, LilyDuelPad.Kind.HOME, Vector3(-HOME_X, 0, 0), 2.0, 0.0, 0))
	home_pads.append(add_pad(22, LilyDuelPad.Kind.HOME, Vector3(HOME_X, 0, 0), 2.0, 0.0, 1))
	for pad in home_pads:
		# The lantern cube sits just under the glow threshold; push it over so it blooms.
		var tint: Color = pad.lantern_material.albedo_color
		pad.lantern_material.albedo_color = Color(tint.r * 1.7, tint.g * 1.7, tint.b * 1.7, 1.0)
	for pad in pads:
		pad.sank.connect(on_pad_sank)
		pad.rose.connect(on_pad_rose)

func on_pad_sank(pad: LilyDuelPad) -> void:
	splash(pad.surface_center())

func on_pad_rose(pad: LilyDuelPad) -> void:
	ripple(pad.surface_center(), 0.8)

func build_lotus() -> void:
	lotus = Node3D.new()
	lotus.name = "LotusBud"
	lotus.position = Vector3(0, SURFACE_HEIGHT, 0)
	add_child(lotus)
	var petal_mat := LilyAvatar.material(Color("f2a7c8"))
	petal_mat.emission_enabled = true
	petal_mat.emission = Color("c0507f")
	petal_mat.emission_energy_multiplier = 0.35
	var tip_mat := LilyAvatar.material(Color("ffd2e6"))
	var core_mat := LilyAvatar.material(Color("ffe27a"))
	core_mat.emission_enabled = true
	core_mat.emission = Color("ffd75e")
	core_mat.emission_energy_multiplier = 1.5
	lotus_core = LilyAvatar.box(lotus, Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.3), core_mat)
	lotus_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in LOTUS_PETALS:
		var pivot := Node3D.new()
		var a := i * TAU / LOTUS_PETALS
		pivot.rotation.y = a
		pivot.position = Vector3(sin(a), 0, cos(a)) * 0.25
		lotus.add_child(pivot)
		LilyAvatar.box(pivot, Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.07), petal_mat)
		LilyAvatar.box(pivot, Vector3(0, 1.08, 0), Vector3(0.3, 0.2, 0.08), tip_mat)
		lotus_petals.append(pivot)
	apply_lotus()

func apply_lotus() -> void:
	var t := lotus_progress * lotus_progress * (3.0 - 2.0 * lotus_progress)
	var tilt := lerpf(-0.22, 1.25, t)
	for pivot in lotus_petals:
		pivot.rotation.x = tilt
	lotus_core.scale = Vector3.ONE * lerpf(0.6, 1.5, t)
	lotus.scale = Vector3.ONE * lerpf(1.0, 1.15, t)

func open_lotus() -> void:
	lotus_open = true
	atmosphere.pulse()

func build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ArenaCamera"
	camera.fov = 50.0
	camera.near = 0.5
	camera.far = 400.0
	camera.position = Vector3(0, 24, 19)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 1.5), Vector3.UP)
	camera_base = camera.transform

func advance(delta: float) -> void:
	for pad in pads:
		pad.advance(delta)

func animate(delta: float) -> void:
	elapsed += delta
	atmosphere.animate(delta)
	if atmosphere.blend < 1.0 or palette_pending:
		palette_pending = atmosphere.blend < 1.0
		apply_water_look()
	tick_water_level(delta)
	tick_shake(delta)
	if camera.global_position != last_camera_position:
		last_camera_position = camera.global_position
		water.set_camera_position(last_camera_position)
	water.advance(delta)
	if lotus_open and lotus_progress < 1.0:
		lotus_progress = minf(lotus_progress + delta / LOTUS_OPEN_TIME, 1.0)
		apply_lotus()
	for pad in home_pads:
		pad.animate(delta)
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.life -= delta
		p.velocity.y -= delta * float(p.get("gravity", 10.0))
		p.node.position += p.velocity * delta
		if not p.node is Label3D:
			p.node.rotation += Vector3(delta, delta * 2, delta)
		if p.life <= 0:
			p.node.queue_free()
			particles.remove_at(i)

func tick_water_level(delta: float) -> void:
	if water_level == water_level_target:
		return
	water_level = lerpf(water_level, water_level_target, 1.0 - exp(-2.5 * delta))
	if absf(water_level - water_level_target) < 0.0005:
		water_level = water_level_target
	water.set_level(water_level)
	# The pad outline rings follow in steps of about a centimetre (and land exactly on arrival).
	if water_level != ring_level and (absf(water_level - ring_level) > RING_STEP or water_level == water_level_target):
		sync_pad_rings()

func sync_pad_rings() -> void:
	ring_level = water_level
	for pad in pads:
		pad.set_water_level(water_level)

func tick_shake(delta: float) -> void:
	if shake_left <= 0.0:
		return
	shake_left -= delta
	if shake_left <= 0.0:
		shake_left = 0.0
		shake_power = 0.0
		camera.transform = camera_base
		return
	var k := shake_left / SHAKE_TIME
	var amount := shake_power * k * k
	var t := elapsed * 63.0
	var offset := Vector3(sin(t * 1.31 + 0.7), sin(t * 1.77 + 2.1), sin(t * 1.13 + 4.2)) * (SHAKE_OFFSET * amount * 0.57735)
	var roll := Vector3(sin(t * 1.51 + 1.9), sin(t * 1.23 + 3.3), sin(t * 1.93)) * (SHAKE_ROLL * amount)
	camera.transform = Transform3D(camera_base.basis * Basis.from_euler(roll), camera_base.origin + offset)

func shake(strength := 1.0) -> void:
	if strength <= 0.0 or camera == null:
		return
	shake_power = minf(shake_power * (shake_left / SHAKE_TIME) + strength, SHAKE_MAX_POWER)
	shake_left = SHAKE_TIME

func set_phase_look(phase: String, instant := false) -> void:
	atmosphere.set_phase(phase, instant)
	palette_pending = true
	if instant:
		apply_water_look()

func set_water_level(height: float) -> void:
	water_level_target = clampf(height, WATER_HEIGHT, MAX_WATER_LEVEL)

func ripple(pos: Vector3, strength := 1.0) -> void:
	water.add_ripple(Vector3(pos.x, water_level, pos.z), strength)

func pulse(strength := 1.0) -> void:
	atmosphere.pulse(strength)

func set_reflection_lights(lights: Array) -> void:
	water.set_reflections(lights)

# The two lantern entries for the water reflections. The array and its dictionaries are
# reused, so calling this every frame allocates nothing.
func lantern_reflections() -> Array:
	if lantern_lights.is_empty():
		for i in 2:
			lantern_lights.append({"position": Vector3.ZERO, "color": LilyDuelPlayer.PLAYER_COLORS[i], "energy": 1.2})
	for i in 2:
		var pad := home_pads[i]
		var entry: Dictionary = lantern_lights[i]
		entry["position"] = pad.lantern.global_position if pad.lantern != null else pad.surface_center()
		entry["energy"] = lerpf(LANTERN_ENERGY_MIN, LANTERN_ENERGY_MAX, minf(pad.lantern_score, 10) / 10.0)
	return lantern_lights

func reset_arena() -> void:
	for pad in pads:
		pad.reset_pad()
	for pad in home_pads:
		pad.reset_lantern()
	lotus_open = false
	lotus_progress = 0.0
	apply_lotus()
	clear_particles()
	water_level = WATER_HEIGHT
	water_level_target = WATER_HEIGHT
	water.set_level(WATER_HEIGHT)
	sync_pad_rings()
	shake_left = 0.0
	shake_power = 0.0
	camera.transform = camera_base
	atmosphere.set_phase("dusk", true)
	apply_water_look()
	palette_pending = false

func spawn_point(player_index: int) -> Vector3:
	var pad := home_pads[clampi(player_index, 0, 1)]
	var inward := 0.3 if player_index == 0 else -0.3
	return pad.surface_center() + Vector3(inward, 0.08, 0)

func pad_at(point: Vector3) -> LilyDuelPad:
	for pad in pads:
		if pad.is_standable() and pad.contains_xz(point):
			return pad
	return null

func nearest_standable(point: Vector3, count: int, allow_home := false, allow_center := true) -> Array[LilyDuelPad]:
	# Ordered by distance from the point to the pad's edge (0 when the point is over the pad).
	var candidates: Array[LilyDuelPad] = []
	for pad in pads:
		if not pad.is_standable():
			continue
		if pad.kind == LilyDuelPad.Kind.HOME and not allow_home:
			continue
		if pad.kind == LilyDuelPad.Kind.CENTER and not allow_center:
			continue
		candidates.append(pad)
	var flat := Vector2(point.x, point.z)
	candidates.sort_custom(func(a: LilyDuelPad, b: LilyDuelPad) -> bool:
		var da := maxf(flat.distance_to(Vector2(a.position.x, a.position.z)) - a.radius, 0.0)
		var db := maxf(flat.distance_to(Vector2(b.position.x, b.position.z)) - b.radius, 0.0)
		return da < db)
	if candidates.size() > count:
		candidates.resize(count)
	return candidates

func queen_perch() -> Vector3:
	return center_pad.surface_center() + Vector3(0, 1.7, 0)

func set_lantern_score(player_index: int, score: int) -> void:
	home_pads[clampi(player_index, 0, 1)].set_lantern_score(score)

func glow_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not glow_materials.has(key):
		var mat := StandardMaterial3D.new()
		# LDR renderer: glow only catches pixels that clamp near white, so over-drive the albedo.
		mat.albedo_color = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 1.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_materials[key] = mat
	return glow_materials[key]

func add_piece(pos: Vector3, size: float, color: Color, velocity: Vector3, life: float, gravity := 10.0) -> void:
	# One shared unit cube, scaled per piece: effects must not build a mesh per particle.
	if piece_mesh == null:
		piece_mesh = BoxMesh.new()
	var piece := MeshInstance3D.new()
	piece.mesh = piece_mesh
	piece.material_override = glow_material(color)
	piece.position = pos
	piece.scale = Vector3.ONE * size
	add_child(piece)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.append({"node": piece, "velocity": velocity, "life": life, "gravity": gravity})

func splash(pos: Vector3) -> void:
	ripple(pos, 1.3)
	water.flash(Vector3(pos.x, water_level, pos.z), Color("a8f5d8"), 0.9)
	for i in 24:
		var angle := rng.randf_range(0, TAU)
		add_piece(Vector3(pos.x, water_level + SPLASH_LIFT, pos.z), rng.randf_range(0.08, 0.16), Color("b8f2de"),
			Vector3(cos(angle) * rng.randf_range(1, 3), rng.randf_range(2, 5), sin(angle) * rng.randf_range(1, 3)), 0.8)

func firefly_puff(pos: Vector3) -> void:
	for i in 12:
		var angle := i * TAU / 12
		add_piece(pos, 0.07, Color("ffe775"), Vector3(cos(angle) * 1.2, 1.0, sin(angle) * 1.2), 0.5, 0.0)

func burst(pos: Vector3, color: Color, count := 16) -> void:
	for i in count:
		var angle := rng.randf_range(0, TAU)
		var up := rng.randf_range(0.8, 3.0)
		var out := rng.randf_range(0.8, 2.6)
		add_piece(pos, rng.randf_range(0.07, 0.15), color, Vector3(cos(angle) * out, up, sin(angle) * out), rng.randf_range(0.5, 0.9))

func bonk(pos: Vector3) -> void:
	var impact := Label3D.new()
	impact.text = "BONK!"
	impact.font_size = 48
	impact.outline_size = 10
	impact.pixel_size = 0.008
	impact.modulate = Color("fff0a5")
	impact.outline_modulate = Color("183f3b")
	impact.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact.no_depth_test = true
	impact.position = pos + Vector3.UP * 2.2
	add_child(impact)
	particles.append({"node": impact, "velocity": Vector3.UP * 0.8, "life": 0.55, "gravity": 0.0})
	var colors := [Color("fff1b5"), Color("dbe6b3"), Color("faf4dc")]
	for i in 18:
		add_piece(pos + Vector3.UP * 0.6, rng.randf_range(0.08, 0.18), colors[i % 3],
			Vector3(rng.randf_range(-2, 2), rng.randf_range(1, 3), rng.randf_range(-2, 2)), 0.45)

func celebrate(pos: Vector3) -> void:
	var colors := [Color("f6cc48"), Color("e98165"), Color("c4e673")]
	for i in 50:
		add_piece(pos + Vector3.UP * 2, 0.12, colors[i % 3],
			Vector3(rng.randf_range(-3, 3), rng.randf_range(2, 6), rng.randf_range(-3, 3)), 2.5)

func clear_particles() -> void:
	for p in particles:
		if is_instance_valid(p.node):
			p.node.queue_free()
	particles.clear()
