class_name LilyDuelPad
extends StaticBody3D

enum Kind { CENTER, MIDDLE, OUTER, YELLOW, HOME }

signal sank(pad: LilyDuelPad)
signal rose(pad: LilyDuelPad)

const SURFACE_HEIGHT := 0.60
const SINK_TIME := 0.55
const RISE_TIME := 0.6
const SINK_DEPTH := 2.4
const THICKNESS := 0.3
const CELL := 0.25
# The pale outline ring rides just above the visual water (0.09 at the resting level 0.04).
const RING_OFFSET := 0.05
# Fresh yellow pads carry their own gold so ambient tint cannot turn them orange; the spent
# pad is dark and grey-brown. They differ in brightness first and hue second.
const YELLOW_GLOW := Color("e0b020")
const YELLOW_GLOW_ENERGY := 0.8
# Warning rims: orange-amber for a pad that comes back, pure red for one that is gone for good.
const RIM_TEMPORARY := Color(1.0, 0.46, 0.0)
const RIM_PERMANENT := Color(1.0, 0.0, 0.0)

var pad_id := -1
var kind: Kind = Kind.OUTER
var radius := 1.9
var angle_degrees := 0.0
var owner_index := -1
var state := "solid"
var spent := false
var was_moving := true

var visual_pivot: Node3D
var mesh_node: MeshInstance3D
var collider: CollisionShape3D
var ripple: MeshInstance3D
var rim_glow: MeshInstance3D
var rim_material: StandardMaterial3D
var rim_mesh_thin: TorusMesh
var rim_mesh_wide: TorusMesh
var ring_level := 0.04
var material: StandardMaterial3D
var normal_mesh: ArrayMesh
var spent_mesh: ArrayMesh
var lantern: Node3D
var lantern_light: OmniLight3D
var lantern_glow: MeshInstance3D
var lantern_material: StandardMaterial3D
var lantern_score := 0
var lantern_energy := 0.0
var lantern_range := 0.0

var warning_length := 0.0
var warning_time := 0.0
var down_time := 0.0
var hold_time := 0.0
var permanent := false
var depth := 0.0
var clock := 0.0

func setup(id: int, pad_kind: Kind, pad_radius: float, angle: float, owner := -1) -> void:
	pad_id = id
	kind = pad_kind
	radius = pad_radius
	angle_degrees = angle
	owner_index = owner
	name = "DuelPad%02d" % id
	collision_layer = 1
	collision_mask = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + id
	normal_mesh = build_mesh(false, rng)
	if kind == Kind.YELLOW:
		spent_mesh = build_mesh(true, rng)
	visual_pivot = Node3D.new()
	visual_pivot.position = Vector3(0, SURFACE_HEIGHT, 0)
	add_child(visual_pivot)
	mesh_node = MeshInstance3D.new()
	mesh_node.mesh = normal_mesh
	material = LilyWorld.vertex_material()
	mesh_node.material_override = material
	visual_pivot.add_child(mesh_node)
	# Warning rim: an opaque unshaded ring along the pad edge, visible only in "warning". A pad
	# that is gone for good gets a wider band than one that will come back.
	rim_glow = MeshInstance3D.new()
	rim_mesh_thin = make_rim_mesh(0.34)
	rim_mesh_wide = make_rim_mesh(0.62)
	rim_glow.mesh = rim_mesh_thin
	rim_glow.position = Vector3(0, 0.05, 0)
	rim_glow.scale = Vector3(1, 0.3, 1)
	rim_material = LilyAvatar.material(RIM_TEMPORARY)
	rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_material.disable_fog = true
	rim_glow.material_override = rim_material
	rim_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim_glow.visible = false
	visual_pivot.add_child(rim_glow)
	collider = CollisionShape3D.new()
	var shape := normal_mesh.create_trimesh_shape()
	shape.backface_collision = true
	collider.shape = shape
	collider.position = Vector3(0, SURFACE_HEIGHT, 0)
	add_child(collider)
	ripple = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.12
	torus.outer_radius = radius + 0.26
	torus.rings = 48
	torus.ring_segments = 4
	ripple.mesh = torus
	ripple.position = Vector3(0, 0.09, 0)
	ripple.scale.y = 0.25
	var ripple_mat := LilyAvatar.material(Color(0.55, 0.85, 0.95, 0.5))
	ripple_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ripple.material_override = ripple_mat
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ripple)
	if kind == Kind.HOME:
		build_lantern()
	if kind == Kind.YELLOW:
		# Emission is switched on once and only its colour changes afterwards (no shader swap).
		material.emission_enabled = true
		material.emission_energy_multiplier = YELLOW_GLOW_ENERGY
		update_glow(1.0)
	apply_visual()

func make_rim_mesh(width: float) -> TorusMesh:
	var rim_torus := TorusMesh.new()
	rim_torus.inner_radius = maxf(radius - width, 0.1)
	rim_torus.outer_radius = radius + 0.06
	rim_torus.rings = 40
	rim_torus.ring_segments = 4
	return rim_torus

# Follows the arena's visual water so the outline ring never hides under a raised surface.
func set_water_level(level: float) -> void:
	if ripple == null or is_equal_approx(level, ring_level):
		return
	ring_level = level
	ripple.position.y = level + RING_OFFSET

# Fresh yellow pads keep a steady gold of their own; a spent one has none.
func update_glow(amount: float) -> void:
	if kind != Kind.YELLOW or material == null:
		return
	var c := Color.BLACK if spent else YELLOW_GLOW
	material.emission = Color(c.r * amount, c.g * amount, c.b * amount, 1.0)

func palette(is_spent: bool) -> Dictionary:
	match kind:
		Kind.CENTER:
			return {"base": Color("2f8f78"), "vein": Color("25705f"), "rim": Color("7fe0b8"), "edge": Color("1b4e46")}
		Kind.MIDDLE:
			return {"base": Color("63b583"), "vein": Color("4f9a6e"), "rim": Color("d2f0c4"), "edge": Color("2f6e55")}
		Kind.YELLOW:
			if is_spent:
				return {"base": Color("6e5a54"), "vein": Color("5e4b46"), "rim": Color("a89086"), "edge": Color("2e211e"), "crack": Color("1a100e")}
			return {"base": Color("e8bc30"), "vein": Color("cc9c1e"), "rim": Color("fff1a0"), "edge": Color("8a6a16")}
		Kind.HOME:
			var tint := Color("ffd75e") if owner_index == 0 else Color("6fd3ff")
			return {"base": Color("2f7f5c"), "vein": Color("266a4c"), "rim": tint, "edge": Color("1c4a38")}
		_:
			return {"base": Color("38874f"), "vein": Color("2c7044"), "rim": Color("4aa468"), "edge": Color("1f5233")}

func build_mesh(is_spent: bool, rng: RandomNumberGenerator) -> ArrayMesh:
	var colors := palette(is_spent)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := ceili(radius / CELL)
	var cells: Dictionary = {}
	for x in range(-count, count):
		for z in range(-count, count):
			var v := Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
			if v.length() < radius:
				cells[Vector2i(x, z)] = true
	var top := 0.0
	var bottom := -THICKNESS
	for key: Vector2i in cells:
		var x := key.x * CELL
		var z := key.y * CELL
		var rim := not (cells.has(key + Vector2i(1, 0)) and cells.has(key + Vector2i(-1, 0)) and cells.has(key + Vector2i(0, 1)) and cells.has(key + Vector2i(0, -1)))
		var color: Color = colors["base"]
		if absf(z) < CELL * 0.7 or absf(z - x * 0.6) < CELL * 0.5 or absf(z + x * 0.6) < CELL * 0.5:
			color = colors["vein"]
		color = color.lightened(rng.randf_range(-0.06, 0.07))
		if rim:
			color = colors["rim"]
		elif is_spent and (absf(z - x * 0.9) < CELL * 0.4 or absf(z + x * 1.6 - 0.4) < CELL * 0.35):
			color = colors["crack"]
		LilyWorld.quad(st, Vector3(x, top, z), Vector3(x, top, z + CELL), Vector3(x + CELL, top, z + CELL), Vector3(x + CELL, top, z), Vector3.UP, color)
		var edge: Color = colors["edge"]
		edge = edge.lightened(rng.randf_range(-0.08, 0.08))
		if not cells.has(key + Vector2i(1, 0)):
			LilyWorld.quad(st, Vector3(x + CELL, bottom, z + CELL), Vector3(x + CELL, bottom, z), Vector3(x + CELL, top, z), Vector3(x + CELL, top, z + CELL), Vector3.RIGHT, edge)
		if not cells.has(key + Vector2i(-1, 0)):
			LilyWorld.quad(st, Vector3(x, bottom, z), Vector3(x, bottom, z + CELL), Vector3(x, top, z + CELL), Vector3(x, top, z), Vector3.LEFT, edge)
		if not cells.has(key + Vector2i(0, 1)):
			LilyWorld.quad(st, Vector3(x, bottom, z + CELL), Vector3(x + CELL, bottom, z + CELL), Vector3(x + CELL, top, z + CELL), Vector3(x, top, z + CELL), Vector3.BACK, edge)
		if not cells.has(key + Vector2i(0, -1)):
			LilyWorld.quad(st, Vector3(x + CELL, bottom, z), Vector3(x, bottom, z), Vector3(x, top, z), Vector3(x + CELL, top, z), Vector3.FORWARD, edge)
	return st.commit()

func build_lantern() -> void:
	var outward := Vector3(-1, 0, 0) if owner_index == 0 else Vector3(1, 0, 0)
	var tint := Color("ffd75e") if owner_index == 0 else Color("6fd3ff")
	lantern = Node3D.new()
	lantern.name = "Lantern"
	# On the far edge, 0.45 m inside the rim, clear of the landing area.
	lantern.position = outward * (radius - 0.45) + Vector3(0, SURFACE_HEIGHT, 0)
	add_child(lantern)
	var wood := LilyAvatar.material(Color("5a4630"))
	LilyAvatar.box(lantern, Vector3(0, 0.75, 0), Vector3(0.18, 1.5, 0.18), wood)
	LilyAvatar.box(lantern, Vector3(0, 1.55, 0), Vector3(0.8, 0.08, 0.8), wood)
	lantern_material = LilyAvatar.material(tint)
	lantern_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lantern_material.emission_enabled = true
	lantern_material.emission = tint
	lantern_material.emission_energy_multiplier = 1.6
	lantern_glow = LilyAvatar.box(lantern, Vector3(0, 1.9, 0), Vector3(0.62, 0.62, 0.62), lantern_material)
	lantern_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	LilyAvatar.box(lantern, Vector3(0, 2.27, 0), Vector3(0.8, 0.08, 0.8), wood)
	lantern_light = OmniLight3D.new()
	lantern_light.position = Vector3(0, 1.9, 0)
	lantern_light.light_color = tint
	lantern_light.shadow_enabled = false
	lantern.add_child(lantern_light)
	set_lantern_score(0)
	lantern_energy = lantern_target_energy()
	lantern_range = lantern_target_range()
	apply_lantern()

func lantern_target_energy() -> float:
	return 1.3 + 0.35 * minf(lantern_score, 10)

func lantern_target_range() -> float:
	return 6.0 + 0.55 * minf(lantern_score, 10)

func set_lantern_score(score: int) -> void:
	lantern_score = maxi(score, 0)

func apply_lantern() -> void:
	if lantern_light == null:
		return
	var flicker := 1.0 + 0.07 * sin(clock * 7.0 + pad_id) + 0.04 * sin(clock * 13.3)
	lantern_light.light_energy = lantern_energy * flicker
	lantern_light.omni_range = lantern_range
	var grow := 1.0 + 0.05 * minf(lantern_score, 10)
	lantern_glow.scale = Vector3.ONE * grow
	lantern_material.emission_energy_multiplier = 1.4 + 0.12 * minf(lantern_score, 10)

func animate(delta: float) -> void:
	clock += delta
	if lantern_light != null:
		lantern_energy = move_toward(lantern_energy, lantern_target_energy(), delta * 2.5)
		lantern_range = move_toward(lantern_range, lantern_target_range(), delta * 3.0)
		apply_lantern()

func reset_lantern() -> void:
	lantern_score = 0
	if lantern_light != null:
		lantern_energy = lantern_target_energy()
		lantern_range = lantern_target_range()
		apply_lantern()

func is_standable() -> bool:
	return state == "solid" or state == "warning"

func set_collision(on: bool) -> void:
	collision_layer = 1 if on else 0
	collider.set_deferred("disabled", not on)

func set_spent(value: bool) -> void:
	spent = value
	if kind == Kind.YELLOW and mesh_node != null:
		mesh_node.mesh = spent_mesh if spent else normal_mesh
		update_glow(1.0 - clampf(depth, 0.0, 1.0))

func trigger_sink(warning: float, sink_down_time: float) -> bool:
	var wants_permanent := sink_down_time < 0.0
	if state == "solid":
		permanent = wants_permanent
		down_time = sink_down_time
		hold_time = 0.0
		if warning <= 0.0:
			drop()
		else:
			state = "warning"
			warning_length = warning
			warning_time = 0.0
		return true
	if wants_permanent and state != "gone":
		permanent = true
		if state == "warning":
			warning_length = warning
			warning_time = 0.0
			if warning <= 0.0:
				drop()
		elif state == "rising":
			# Never restore collision: turn around and sink for good.
			state = "sunk"
		return true
	return false

func drop() -> void:
	# Contact frame: support disappears now, the visual then sinks.
	state = "sunk"
	hold_time = 0.0
	set_collision(false)
	sank.emit(self)

func advance(delta: float) -> void:
	match state:
		"warning":
			warning_time += delta
			if warning_time >= warning_length:
				drop()
		"sunk":
			if depth < 1.0:
				depth = minf(depth + delta / SINK_TIME, 1.0)
			elif permanent:
				state = "gone"
			else:
				hold_time += delta
				if hold_time >= down_time:
					state = "rising"
		"rising":
			depth = maxf(depth - delta / RISE_TIME, 0.0)
			if depth <= 0.0:
				state = "solid"
				set_collision(true)
				if kind == Kind.YELLOW:
					set_spent(false)
				rose.emit(self)
	# A resting pad keeps its last pose: only touch the material and transform while it moves.
	if state != "solid" or was_moving:
		apply_visual()
	was_moving = state != "solid"

func apply_visual() -> void:
	if visual_pivot == null:
		return
	var tint := Color.WHITE
	var wobble := Vector3.ZERO
	var lift := 0.0
	if state == "warning":
		var t := warning_time
		var pulse := 0.5 + 0.5 * sin(t * 22.0)
		tint = Color.WHITE.lerp(Color(1.7, 0.65, 0.45), 0.55 + 0.4 * pulse)
		var amp := 0.05 + 0.05 * clampf(t / maxf(warning_length, 0.01), 0.0, 1.0)
		wobble = Vector3(sin(t * 31.0) * amp, 0.0, cos(t * 27.0) * amp)
		lift = -0.04 - 0.04 * pulse
	elif state == "sunk" or state == "rising" or state == "gone":
		var e := depth * depth * (3.0 - 2.0 * depth)
		lift = -e * SINK_DEPTH
		wobble = Vector3(sin(e * PI) * 0.22, 0.0, sin(e * PI) * -0.16)
		tint = Color.WHITE.lerp(Color(0.7, 0.8, 0.9), e)
		visual_pivot.scale = Vector3.ONE * (1.0 - 0.12 * e)
	if state != "sunk" and state != "rising" and state != "gone":
		visual_pivot.scale = Vector3.ONE
	visual_pivot.position = Vector3(0, SURFACE_HEIGHT + lift, 0)
	visual_pivot.rotation = wobble
	material.albedo_color = tint
	update_glow(1.0 - clampf(depth, 0.0, 1.0) if state != "warning" else 1.0)
	if rim_glow != null:
		rim_glow.visible = state == "warning"
		if state == "warning":
			# Pulse speeds up as the sink approaches (a chirp: phase = integral of frequency).
			var p := clampf(warning_time / maxf(warning_length, 0.01), 0.0, 1.0)
			var phase := warning_time * 5.0 + 9.0 * warning_time * p * 0.5
			var beat := 0.5 + 0.5 * sin(phase * TAU)
			# Brightness pulses between a dim and a full level; the hue never moves.
			var level := lerpf(0.5 + 0.3 * p, 1.0, beat)
			var base := RIM_PERMANENT if permanent else RIM_TEMPORARY
			var wanted := rim_mesh_wide if permanent else rim_mesh_thin
			if rim_glow.mesh != wanted:
				rim_glow.mesh = wanted
			rim_material.albedo_color = Color(base.r * level, base.g * level, base.b * level, 1.0)
	var show := state != "gone" and not (state == "sunk" and depth >= 1.0)
	visual_pivot.visible = show
	if ripple != null:
		ripple.visible = state != "gone" and depth < 0.5

func reset_pad() -> void:
	state = "solid"
	permanent = false
	depth = 0.0
	warning_time = 0.0
	hold_time = 0.0
	down_time = 0.0
	set_collision(true)
	set_spent(false)
	apply_visual()

func surface_center() -> Vector3:
	var origin := global_position if is_inside_tree() else position
	return Vector3(origin.x, SURFACE_HEIGHT, origin.z)

func contains_xz(point: Vector3, margin := 0.0) -> bool:
	var origin := global_position if is_inside_tree() else position
	return Vector2(point.x - origin.x, point.z - origin.z).length() <= radius + margin

func random_point(rng: RandomNumberGenerator, fraction := 0.6) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var distance := radius * fraction * sqrt(rng.randf())
	var center := surface_center()
	return center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
