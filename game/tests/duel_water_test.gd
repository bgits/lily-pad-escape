extends SceneTree

var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func run() -> void:
	var w := LilyDuelWater.new()
	root.add_child(w)
	w.build(350.0, 0.04)
	await process_frame
	var meshes: Array = []
	for c in w.get_children():
		if c is MeshInstance3D:
			meshes.append(c)
	check(meshes.size() == 1, "build creates exactly one plane")
	var mi: MeshInstance3D = meshes[0]
	check(mi.mesh is PlaneMesh and (mi.mesh as PlaneMesh).size == Vector2(350, 350), "plane has the given size")
	check(is_equal_approx(mi.position.y, 0.04), "plane sits at the given height")
	var mat := mi.material_override as ShaderMaterial
	check(mat != null and mat.shader.resource_path == "res://shaders/water_night.gdshader", "uses the night shader")
	var snap := w.debug_snapshot()
	check(snap.has("ripples") and snap.has("flashes") and snap.has("reflections") and snap.has("level"), "snapshot has contract keys")
	check(snap["ripples"] == 0 and snap["flashes"] == 0 and snap["reflections"] == 0, "starts empty")

	w.add_ripple(Vector3(1, 0, 2))
	w.add_ripple(Vector3(-3, 0, 2), 2.0)
	check(w.debug_snapshot()["ripples"] == 2, "add_ripple raises count")
	w.advance(0.8)
	check(w.debug_snapshot()["ripples"] == 2, "ripples live mid-lifetime")
	var rd = mat.get_shader_parameter("ripples")
	check(rd != null and rd.size() == 24 and rd[0].z > 0.4 and rd[0].z < 0.6, "ripple age pushed to the shader")
	w.advance(0.9)
	check(w.debug_snapshot()["ripples"] == 0, "ripples expire after their lifetime")
	for i in 30:
		w.add_ripple(Vector3(i, 0, 0))
		w.advance(0.01)
	check(w.debug_snapshot()["ripples"] == 24, "25th+ ripple replaces the oldest (count stays 24)")
	var oldest_gone := true
	var rdata = mat.get_shader_parameter("ripples")
	for i in rdata.size():
		if is_equal_approx(rdata[i].x, 0.0) and rdata[i].w > 0.0:
			oldest_gone = false
	check(oldest_gone, "oldest ripple was overwritten")
	w.advance(2.0)
	check(w.debug_snapshot()["ripples"] == 0, "all ripples expire")

	w.flash(Vector3(2, 0, 2), Color(0.4, 1, 0.8), 1.0)
	check(w.debug_snapshot()["flashes"] == 1, "flash appears")
	w.advance(0.6)
	check(w.debug_snapshot()["flashes"] == 1, "flash lives mid-lifetime")
	w.advance(0.7)
	check(w.debug_snapshot()["flashes"] == 0, "flash expires")

	var lights: Array = []
	for i in 20:
		lights.append({"position": Vector3(i, 2, 0), "color": Color.GOLD, "energy": 1.5})
	w.set_reflections(lights)
	check(w.debug_snapshot()["reflections"] == 16, "20 reflections keep 16")
	check(mat.get_shader_parameter("refl_pos").size() == 16, "reflection arrays are fixed size")
	w.set_reflections([])
	check(w.debug_snapshot()["reflections"] == 0, "empty clears reflections")
	w.advance(1.0 / 60.0)
	check(mat.get_shader_parameter("refl_pos")[0].z == 0.0, "cleared reflections reach the shader")

	# Unchanged reflections are not re-sent; a moved light or camera is.
	var steady := [{"position": Vector3(3, 2, -4), "color": Color.GOLD, "energy": 1.5}, {"position": Vector3(-5, 2, 1), "color": Color.CYAN, "energy": 0.7}]
	w.set_reflections(steady)
	w.advance(1.0 / 60.0)
	check(not w._dirty, "Setup: reflections pushed")
	w.set_reflections([{"position": Vector3(3, 2, -4), "color": Color.GOLD, "energy": 1.5}, {"position": Vector3(-5, 2, 1), "color": Color.CYAN, "energy": 0.7}])
	check(not w._dirty, "The same reflections again do not mark the water dirty")
	w.set_reflections([{"position": Vector3(3.0005, 2, -4), "color": Color.GOLD, "energy": 1.5}, {"position": Vector3(-5, 2, 1), "color": Color.CYAN, "energy": 0.7005}])
	check(not w._dirty, "...nor do changes under the epsilon")
	w.set_reflections([{"position": Vector3(3.5, 2, -4), "color": Color.GOLD, "energy": 1.5}, {"position": Vector3(-5, 2, 1), "color": Color.CYAN, "energy": 0.7}])
	check(w._dirty, "A moved light does")
	w.advance(1.0 / 60.0)
	w.set_reflections([{"position": Vector3(3.5, 2, -4), "color": Color.RED, "energy": 1.5}, {"position": Vector3(-5, 2, 1), "color": Color.CYAN, "energy": 0.7}])
	check(w._dirty, "...and so does a colour change")
	w.advance(1.0 / 60.0)
	w.set_reflections([{"position": Vector3(3.5, 2, -4), "color": Color.RED, "energy": 1.5}])
	check(w._dirty and w.debug_snapshot()["reflections"] == 1, "...and so does a shorter list")
	w.advance(1.0 / 60.0)
	var dirs: PackedVector2Array = mat.get_shader_parameter("refl_dir")
	var expect := Vector2(0 - 3.5, 19 - -4).normalized()
	check(dirs.size() == 16 and dirs[0].is_equal_approx(expect) and dirs[1] == Vector2.ZERO, "Each light's unit direction toward the camera is precomputed on the CPU")
	w.set_camera_position(Vector3(10, 24, 5))
	check(w._dirty, "Moving the camera marks the water dirty")
	w.advance(1.0 / 60.0)
	dirs = mat.get_shader_parameter("refl_dir")
	check(dirs[0].is_equal_approx(Vector2(10 - 3.5, 5 - -4).normalized()), "...and the directions follow the camera")
	w.set_camera_position(Vector3(1, 24, 19))
	w.set_reflections([])
	w.advance(1.0 / 60.0)

	w.set_level(0.25)
	check(is_equal_approx(mi.position.y, 0.25) and is_equal_approx(w.debug_snapshot()["level"], 0.25), "set_level moves the surface")
	w.set_palette(Color(0.1, 0.2, 0.3), Color(0.4, 0.5, 0.6), Color(0.7, 0.8, 0.9))
	var deep = mat.get_shader_parameter("deep_color")
	var glint = mat.get_shader_parameter("glint_color")
	check(deep is Color and is_equal_approx(deep.g, 0.2) and is_equal_approx(glint.b, 0.9), "palette reaches the shader as sRGB Colors (source_color converts them)")
	w.set_moon_direction(Vector3(1, -1, 0))
	var md: Vector3 = mat.get_shader_parameter("moon_dir")
	check(is_equal_approx(md.length(), 1.0) and md.x > 0.0, "moon direction reaches the shader (normalised)")
	w.set_camera_position(Vector3(1, 24, 19))
	check(mat.get_shader_parameter("cam_pos") == Vector3(1, 24, 19), "camera position reaches the shader")

	for f in 600:
		if f % 7 == 0:
			w.add_ripple(Vector3(randf_range(-10, 10), 0, randf_range(-5, 5)), randf_range(0.5, 2.0))
		if f % 41 == 0:
			w.flash(Vector3(randf_range(-10, 10), 0, 0), Color.CYAN, 1.5)
		if f % 90 == 0:
			w.set_reflections([{"position": Vector3(f * 0.01, 2, 0), "color": Color.WHITE, "energy": 2.0}])
		w.advance(1.0 / 60.0)
	check(w.debug_snapshot()["ripples"] <= 24, "600 frames of churn stay bounded")

	print("DUEL WATER RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
