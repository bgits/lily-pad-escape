class_name LilyDuelAtmosphere
extends Node3D

# Sky, lighting, glow, mist, reeds, islands and distant fireflies for Midnight Pond.
# Nothing here has collision and nothing sits inside the play-area keep-out rectangle.
# Steady state: animate() rewrites the firefly MultiMesh transforms in place and re-applies the
# look (environment, light, sky, mist) only while a phase blend or a pulse is running; mist drift
# is driven by TIME inside its shader. Stars are static (sky shaders cannot read TIME in the
# Compatibility renderer, and per-frame sky parameter writes were the cost to remove). No node,
# mesh or material creation.

const BLEND_TIME := 2.5
const PULSE_TIME := 0.8
const KEEP_MIN := Vector2(-22.0, -17.0)
const KEEP_MAX := Vector2(22.0, 16.0)
const FIREFLY_COUNT := 48
const WATER_Y := 0.04
# Direction the moonlight travels: from the far side, up high, toward the camera and down.
const MOON_TRAVEL := Vector3(0.28, -0.62, 0.74)

const LOOK_KEYS := ["ambient_color", "ambient_energy", "moon_color", "moon_energy", "fog_color",
	"fog_density", "sky_top", "sky_horizon", "sky_ground", "glow", "mist_alpha", "star_strength",
	"contrast", "saturation", "deep", "light", "glint"]

var environment: Environment
var moon: DirectionalLight3D
var glow_supported := false

# Glow tuning: Compatibility renders 3D in LDR, so the threshold must be <= 1.0. Only pixels
# that clamp to (almost) full white glow: unshaded emissive things, lanterns, fireflies.
var glow_threshold := 0.92
var glow_strength := 1.3
var glow_bloom := 0.0

var phase := "dusk"
var blend := 1.0

var looks: Dictionary = {}
var from_look: Dictionary = {}
var to_look: Dictionary = {}
var current: Dictionary = {}
var elapsed := 0.0
var pulse_left := 0.0
var pulse_strength := 0.0
var built := false

var world_environment: WorldEnvironment
var sky_material: ShaderMaterial
var mist_materials: Array[ShaderMaterial] = []
# How many times the look was written to the environment, light, sky and mist (for tests).
var apply_count := 0
var firefly_mesh: MultiMesh
var firefly_data: Array[Dictionary] = []
var scenery_node: MeshInstance3D
var reeds_node: MeshInstance3D
var rng := RandomNumberGenerator.new()

# Water colours are plain Colors: LilyDuelWater passes them on as Colors, which the shader's
# source_color hint expects (the Compatibility renderer shows them as authored here).
static func make_looks() -> Dictionary:
	return {
		"dusk": {
			"ambient_color": Color("b498e0"), "ambient_energy": 1.0,
			"moon_color": Color("e2c9ff"), "moon_energy": 1.0,
			"fog_color": Color("3b2a5e"), "fog_density": 0.006,
			"sky_top": Color("1b1444"), "sky_horizon": Color("744080"), "sky_ground": Color("231a44"),
			"glow": 1.2, "mist_alpha": 0.30, "star_strength": 0.55, "contrast": 1.0, "saturation": 1.12,
			"deep": Color(0.07, 0.09, 0.22), "light": Color(0.15, 0.18, 0.36), "glint": Color(0.62, 0.48, 0.80)},
		"midnight": {
			"ambient_color": Color("86a6e6"), "ambient_energy": 0.84,
			"moon_color": Color("bcd2ff"), "moon_energy": 1.3,
			"fog_color": Color("0b1838"), "fog_density": 0.007,
			"sky_top": Color("040a22"), "sky_horizon": Color("14306a"), "sky_ground": Color("07102a"),
			"glow": 1.5, "mist_alpha": 0.26, "star_strength": 1.0, "contrast": 1.1, "saturation": 1.0,
			"deep": Color(0.015, 0.08, 0.16), "light": Color(0.04, 0.18, 0.29), "glint": Color(0.45, 0.66, 0.88)},
		"flood": {
			"ambient_color": Color("86c4d0"), "ambient_energy": 0.9,
			"moon_color": Color("a8f0e0"), "moon_energy": 1.25,
			"fog_color": Color("0f3340"), "fog_density": 0.013,
			"sky_top": Color("04141c"), "sky_horizon": Color("1a5560"), "sky_ground": Color("062029"),
			"glow": 1.6, "mist_alpha": 0.38, "star_strength": 0.7, "contrast": 1.05, "saturation": 0.78,
			"deep": Color(0.02, 0.13, 0.15), "light": Color(0.06, 0.27, 0.30), "glint": Color(0.52, 0.88, 0.82)},
		"sudden_death": {
			"ambient_color": Color("a888d8"), "ambient_energy": 0.8,
			"moon_color": Color("ffc8ec"), "moon_energy": 1.6,
			"fog_color": Color("2c0c32"), "fog_density": 0.009,
			"sky_top": Color("160418"), "sky_horizon": Color("6a1850"), "sky_ground": Color("1a0618"),
			"glow": 1.9, "mist_alpha": 0.30, "star_strength": 0.9, "contrast": 1.28, "saturation": 1.15,
			"deep": Color(0.11, 0.04, 0.17), "light": Color(0.24, 0.07, 0.26), "glint": Color(1.0, 0.45, 0.62)},
		"over": {
			"ambient_color": Color("98b0e0"), "ambient_energy": 0.95,
			"moon_color": Color("d0e0ff"), "moon_energy": 1.0,
			"fog_color": Color("17305a"), "fog_density": 0.005,
			"sky_top": Color("0a1a40"), "sky_horizon": Color("2a4a82"), "sky_ground": Color("0c1c3a"),
			"glow": 1.1, "mist_alpha": 0.22, "star_strength": 0.9, "contrast": 1.0, "saturation": 1.0,
			"deep": Color(0.03, 0.10, 0.18), "light": Color(0.07, 0.21, 0.32), "glint": Color(0.55, 0.72, 0.90)},
	}

static func canonical_phase(name: String) -> String:
	match name:
		"midnight", "flood", "sudden_death", "over":
			return name
	return "dusk"

func build() -> void:
	if built:
		return
	built = true
	rng.seed = 424242
	looks = make_looks()
	to_look = looks["dusk"].duplicate()
	from_look = to_look.duplicate()
	current = to_look.duplicate()
	build_environment()
	build_moon()
	build_mist()
	build_scenery()
	build_reeds()
	build_fireflies()
	apply_look(0.0)

func build_environment() -> void:
	var method := RenderingServer.get_current_rendering_method()
	# Verified in a windowed run on Godot 4.6 (gl_compatibility): glow renders there.
	glow_supported = method == "gl_compatibility" or method == "mobile" or method == "forward_plus"
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/duel_sky.gdshader")
	sky_material.set_shader_parameter("moon_dir", -MOON_TRAVEL.normalized())
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Nothing here is shiny, so the sky is never sampled for reflections or ambient light.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	# Fog would otherwise repaint the whole sky one flat colour.
	environment.fog_sky_affect = 0.0
	environment.adjustment_enabled = true
	if glow_supported:
		environment.glow_enabled = true
		environment.glow_hdr_threshold = glow_threshold
		environment.glow_strength = glow_strength
		environment.glow_bloom = glow_bloom
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		# Mid-sized blur levels only: a tight halo, no screen-wide wash.
		for level in 7:
			environment.set_glow_level(level, 1.0 if level >= 1 and level <= 4 else 0.0)
	world_environment = WorldEnvironment.new()
	world_environment.name = "NightEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

func build_moon() -> void:
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.basis = Basis.looking_at(MOON_TRAVEL.normalized(), Vector3.UP)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 55.0
	add_child(moon)

func make_noise_texture(seed_value: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.seed = seed_value
	return ImageTexture.create_from_image(noise.get_seamless_image(128, 128))

func build_mist() -> void:
	var holder := Node3D.new()
	holder.name = "Mist"
	add_child(holder)
	var tex := make_noise_texture(7)
	# centre, size (x, z), height, tiling, drift speed. All sheets sit beyond the keep-out rectangle.
	var sheets := [
		[Vector3(0, 0.55, -25.0), Vector2(96, 14), Vector2(5, 1), Vector2(0.006, 0.0015)],
		[Vector3(-6, 1.5, -29.0), Vector2(110, 12), Vector2(6, 1), Vector2(-0.004, 0.001)],
		[Vector3(-37.0, 0.45, -2.0), Vector2(28, 48), Vector2(1, 3), Vector2(0.002, 0.005)],
		[Vector3(37.0, 0.45, -2.0), Vector2(28, 48), Vector2(1, 3), Vector2(-0.002, -0.004)],
	]
	for i in sheets.size():
		var sheet: Array = sheets[i]
		var mesh := PlaneMesh.new()
		mesh.size = sheet[1]
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/duel_mist.gdshader")
		mat.set_shader_parameter("noise_tex", tex)
		mat.set_shader_parameter("tiling", sheet[2])
		mat.set_shader_parameter("drift_start", Vector2(rng.randf(), rng.randf()))
		mat.set_shader_parameter("drift_speed", sheet[3])
		var node := MeshInstance3D.new()
		node.name = "MistSheet%d" % i
		node.mesh = mesh
		node.material_override = mat
		node.position = sheet[0]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)
		mist_materials.append(mat)

func build_scenery() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Side islands (x beyond +-23, centres never closer than 27) and a small back row.
	for side in [-1, 1]:
		for z in [-17.0, -8.0, 0.0, 9.0]:
			make_island(st, Vector3(side * rng.randf_range(27.5, 35.0), 0, z + rng.randf_range(-1.5, 1.5)),
				rng.randf_range(2.2, 3.8), rng.randf_range(0.9, 1.6), 3)
	for x in range(-40, 41, 10):
		make_island(st, Vector3(x + rng.randf_range(-2.5, 2.5), 0, -22.0 - rng.randf_range(0, 2.5)),
			rng.randf_range(1.8, 2.6), rng.randf_range(0.9, 1.5), 2)
	scenery_node = MeshInstance3D.new()
	scenery_node.name = "IslandSilhouettes"
	scenery_node.mesh = st.commit()
	scenery_node.material_override = LilyWorld.vertex_material()
	scenery_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scenery_node)

func make_island(st: SurfaceTool, center: Vector3, size: float, height: float, trees: int) -> void:
	for x in range(-ceili(size), ceili(size)):
		for z in range(-ceili(size), ceili(size)):
			if Vector2(x + 0.5, z + 0.5).length() > size:
				continue
			var h := height + rng.randf_range(-0.25, 0.3)
			var p := center + Vector3(x + 0.5, h * 0.5 - 0.3, z + 0.5)
			LilyWorld.block(st, p, Vector3(1, h, 1), Color("1a2638").lightened(rng.randf_range(-0.04, 0.08)))
	for i in trees:
		var base := center + Vector3(rng.randf_range(-size, size) * 0.5, 0, rng.randf_range(-size, size) * 0.5)
		var trunk := rng.randf_range(2.0, 3.6)
		var top := height + 0.2
		LilyWorld.block(st, base + Vector3(0, top + trunk * 0.5, 0), Vector3(0.28, trunk, 0.28), Color("2a2230"))
		var spread := rng.randf_range(1.5, 2.3)
		var leaf := Color("15332e").lightened(rng.randf_range(-0.03, 0.05))
		LilyWorld.block(st, base + Vector3(0, top + trunk + 0.2, 0), Vector3(spread, 0.8, spread), leaf)
		LilyWorld.block(st, base + Vector3(0, top + trunk + 0.9, 0), Vector3(spread * 0.7, 0.7, spread * 0.7), leaf.lightened(0.05))
		LilyWorld.block(st, base + Vector3(0, top + trunk + 1.5, 0), Vector3(spread * 0.4, 0.6, spread * 0.4), leaf.lightened(0.1))

func build_reeds() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clumps := 0
	while clumps < 26:
		var center := Vector3.ZERO
		if clumps < 20:
			center = Vector3((1 if clumps % 2 == 0 else -1) * rng.randf_range(24.5, 31.0), 0, rng.randf_range(-19.0, 12.0))
		else:
			center = Vector3(rng.randf_range(-30.0, 30.0), 0, rng.randf_range(-21.0, -19.0))
		clumps += 1
		var stems := rng.randi_range(6, 10)
		for s in stems:
			var pos := center + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
			var h := rng.randf_range(1.4, 2.6)
			var green := Color("1d4a3a").lightened(rng.randf_range(-0.05, 0.08))
			LilyWorld.block(st, pos + Vector3(0, h * 0.5 - 0.1, 0), Vector3(0.07, h, 0.07), green)
			if s % 3 == 0:
				LilyWorld.block(st, pos + Vector3(0, h + 0.15, 0), Vector3(0.14, 0.4, 0.14), Color("4a3a2a"))
	reeds_node = MeshInstance3D.new()
	reeds_node.name = "Reeds"
	reeds_node.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/duel_reeds.gdshader")
	reeds_node.material_override = mat
	reeds_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(reeds_node)

func build_fireflies() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.16
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.6, 1.6, 1.6)
	mat.disable_fog = true
	firefly_mesh = MultiMesh.new()
	firefly_mesh.transform_format = MultiMesh.TRANSFORM_3D
	firefly_mesh.use_colors = true
	firefly_mesh.mesh = box
	firefly_mesh.instance_count = FIREFLY_COUNT
	for i in FIREFLY_COUNT:
		var anchor := Vector3.ZERO
		if i % 3 == 0:
			anchor = Vector3(rng.randf_range(-42, 42), rng.randf_range(0.8, 3.8), rng.randf_range(-33, -20.5))
		else:
			anchor = Vector3((1 if i % 2 == 0 else -1) * rng.randf_range(25.5, 44), rng.randf_range(0.8, 3.8), rng.randf_range(-30, 13))
		var warm := rng.randf() < 0.8
		firefly_data.append({
			"anchor": anchor,
			"radius": rng.randf_range(0.8, 2.2),
			"speed": rng.randf_range(0.25, 0.7),
			"phase": rng.randf_range(0, TAU),
			"blink": rng.randf_range(0.6, 1.8),
			"size": rng.randf_range(0.6, 1.3),
			"color": Color(1.0, 0.92, 0.45) if warm else Color(0.6, 1.0, 0.85),
		})
	var node := MultiMeshInstance3D.new()
	node.name = "DistantFireflies"
	node.multimesh = firefly_mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-60, -2, -45), Vector3(120, 12, 70))
	add_child(node)
	update_fireflies()

func firefly_position(data: Dictionary, t: float) -> Vector3:
	var a: float = t * data.speed + data.phase
	var anchor: Vector3 = data.anchor
	var r: float = data.radius
	return anchor + Vector3(cos(a) * r, sin(a * 1.3) * 0.4, sin(a * 0.8 + data.phase) * r)

func update_fireflies() -> void:
	for i in FIREFLY_COUNT:
		var data := firefly_data[i]
		var wave := sin(elapsed * data.blink + data.phase * 3.0)
		var glow := smoothstep(-0.3, 0.7, wave)
		var s: float = data.size * (0.25 + 0.75 * glow)
		var color: Color = data.color
		firefly_mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), firefly_position(data, elapsed)))
		firefly_mesh.set_instance_color(i, Color(color.r * glow, color.g * glow, color.b * glow, 1.0))

func set_phase(new_phase: String, instant := false) -> void:
	if not built:
		build()
	phase = canonical_phase(new_phase)
	from_look = current.duplicate()
	to_look = looks[phase].duplicate()
	if instant:
		blend = 1.0
		from_look = to_look.duplicate()
		current = to_look.duplicate()
		apply_look(0.0)
	else:
		blend = 0.0

func water_palette() -> Dictionary:
	return {"deep": current["deep"], "light": current["light"], "glint": current["glint"]}

func moon_direction() -> Vector3:
	return MOON_TRAVEL.normalized()

func pulse(strength := 1.0) -> void:
	pulse_left = PULSE_TIME
	pulse_strength = strength

func pulse_bump() -> float:
	if pulse_left <= 0.0:
		return 0.0
	return pulse_strength * sin(PI * (1.0 - pulse_left / PULSE_TIME))

func animate(delta: float) -> void:
	if not built:
		return
	elapsed += delta
	var changing := false
	if blend < 1.0:
		blend = minf(blend + delta / BLEND_TIME, 1.0)
		var w := blend * blend * (3.0 - 2.0 * blend)
		for key in LOOK_KEYS:
			var a: Variant = from_look[key]
			var b: Variant = to_look[key]
			current[key] = a.lerp(b, w) if a is Color else lerpf(a, b, w)
		changing = true
	if pulse_left > 0.0:
		# The step that ends the pulse is applied too, so the look settles on its plain values.
		pulse_left = maxf(pulse_left - delta, 0.0)
		changing = true
	if changing:
		apply_look(pulse_bump())
	update_fireflies()

func apply_look(bump: float) -> void:
	apply_count += 1
	environment.ambient_light_color = current["ambient_color"]
	environment.ambient_light_energy = current["ambient_energy"] + 0.3 * bump
	moon.light_color = current["moon_color"]
	moon.light_energy = current["moon_energy"] + 0.2 * bump
	environment.fog_light_color = current["fog_color"]
	environment.fog_density = current["fog_density"]
	environment.adjustment_contrast = current["contrast"]
	environment.adjustment_saturation = current["saturation"]
	if glow_supported:
		environment.glow_intensity = current["glow"] + 0.8 * bump
	sky_material.set_shader_parameter("top_color", current["sky_top"])
	sky_material.set_shader_parameter("horizon_color", current["sky_horizon"])
	sky_material.set_shader_parameter("ground_color", current["sky_ground"])
	sky_material.set_shader_parameter("moon_color", current["moon_color"])
	sky_material.set_shader_parameter("star_strength", current["star_strength"])
	var mist_color: Color = current["fog_color"].lerp(current["moon_color"], 0.3).lightened(0.15)
	for mat in mist_materials:
		mat.set_shader_parameter("mist_color", mist_color)
		mat.set_shader_parameter("density", current["mist_alpha"])

func debug_snapshot() -> Dictionary:
	return {"phase": phase, "blend": blend, "glow_supported": glow_supported}
