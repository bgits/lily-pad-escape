extends SceneTree

var passed := 0
var failures: Array[String] = []
var atmo: LilyDuelAtmosphere

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message + " " + str(atmo.debug_snapshot() if atmo else {}))

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count_nodes(child)
	return total

func find_all(node: Node, type_name: String, out: Array) -> void:
	if node.is_class(type_name):
		out.append(node)
	for child in node.get_children():
		find_all(child, type_name, out)

func inside_keep_out(p: Vector3, margin := 0.0) -> bool:
	return p.x > LilyDuelAtmosphere.KEEP_MIN.x - margin and p.x < LilyDuelAtmosphere.KEEP_MAX.x + margin \
		and p.z > LilyDuelAtmosphere.KEEP_MIN.y - margin and p.z < LilyDuelAtmosphere.KEEP_MAX.y + margin

func mesh_outside(node: Node) -> bool:
	var ok := true
	var instances: Array = []
	find_all(node, "MeshInstance3D", instances)
	for instance in instances:
		var mi: MeshInstance3D = instance
		for v in mi.mesh.get_faces():
			if inside_keep_out(mi.global_transform * v):
				ok = false
				break
	return ok

func fireflies_outside() -> bool:
	# The headless dummy renderer does not store MultiMesh buffers, so check the same
	# positions the atmosphere writes into them (over a full drift cycle).
	for data in atmo.firefly_data:
		for k in 24:
			if inside_keep_out(atmo.firefly_position(data, k * 2.0)):
				return false
	return true

func run() -> void:
	atmo = LilyDuelAtmosphere.new()
	root.add_child(atmo)
	atmo.build()
	var envs: Array = []
	var lights: Array = []
	find_all(atmo, "WorldEnvironment", envs)
	find_all(atmo, "DirectionalLight3D", lights)
	check(envs.size() == 1, "exactly one WorldEnvironment")
	check(lights.size() == 1 and (lights[0] as DirectionalLight3D).shadow_enabled, "exactly one DirectionalLight3D with shadows on")
	check(atmo.environment != null and atmo.moon != null, "environment and moon are set")
	check(atmo.environment == (envs[0] as WorldEnvironment).environment and atmo.moon == lights[0], "members are the built nodes")

	atmo.set_phase("dusk", true)
	var dusk_ambient := atmo.environment.ambient_light_color
	atmo.set_phase("midnight", true)
	check(is_equal_approx(float(atmo.debug_snapshot()["blend"]), 1.0), "instant phase has blend 1.0")
	check(atmo.debug_snapshot()["phase"] == "midnight", "snapshot phase midnight")
	check(not atmo.environment.ambient_light_color.is_equal_approx(dusk_ambient), "midnight ambient differs from dusk")
	atmo.set_phase("not_a_phase", true)
	check(atmo.environment.ambient_light_color.is_equal_approx(dusk_ambient), "unknown phase behaves like dusk")
	atmo.set_phase("countdown", true)
	check(atmo.environment.ambient_light_color.is_equal_approx(dusk_ambient), "countdown looks like dusk")

	var dusk_water := atmo.water_palette()
	atmo.set_phase("flood")
	var monotonic := true
	var last := float(atmo.debug_snapshot()["blend"])
	check(last < 0.01, "non-instant phase starts at blend 0")
	var mid_ok := false
	for i in 160:
		atmo.animate(1.0 / 60.0)
		var b := float(atmo.debug_snapshot()["blend"])
		if b < last - 0.0001:
			monotonic = false
		last = b
		if i == 70:
			mid_ok = b > 0.2 and b < 0.8
	check(monotonic, "blend is monotonic")
	check(mid_ok, "blend is part-way after ~1.2 s")
	check(is_equal_approx(last, 1.0), "flood reaches blend 1.0 after ~2.5 s")
	var flood_water := atmo.water_palette()
	for key in ["deep", "light", "glint"]:
		check(dusk_water.has(key) and flood_water.has(key), "water palette has " + key)
	check(not (dusk_water["deep"] as Color).is_equal_approx(flood_water["deep"]), "water palette changes dusk to flood")

	for phase_name in ["dusk", "countdown", "midnight", "flood", "sudden_death", "over", "bogus"]:
		atmo.set_phase(phase_name, true)
		check(atmo.environment.ambient_light_energy >= 0.75, "ambient energy >= 0.75 in " + phase_name)
		check(atmo.moon.light_energy > 0.5, "moon energy readable in " + phase_name)

	atmo.set_phase("midnight", true)
	var base := atmo.environment.ambient_light_energy
	atmo.pulse(1.0)
	var peak := base
	for i in 24:
		atmo.animate(1.0 / 60.0)
		peak = maxf(peak, atmo.environment.ambient_light_energy)
	check(peak > base + 0.05, "pulse raises ambient energy")
	for i in 45:
		atmo.animate(1.0 / 60.0)
	check(is_equal_approx(atmo.environment.ambient_light_energy, base), "pulse returns to the look value within ~1 s")

	# Settled look, no pulse: animate() writes nothing to the environment, light, sky or mist.
	atmo.set_phase("midnight", true)
	check(atmo.environment.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED, "The sky is not sampled for reflections")
	var applied := atmo.apply_count
	for i in 120:
		atmo.animate(1.0 / 60.0)
	check(atmo.apply_count == applied, "120 settled animate calls perform no environment or sky writes (%d)" % (atmo.apply_count - applied))
	atmo.pulse(0.5)
	for i in 60:
		atmo.animate(1.0 / 60.0)
	var after_pulse := atmo.apply_count
	check(after_pulse > applied and after_pulse - applied <= 52, "A pulse applies the look only while it runs (%d writes)" % (after_pulse - applied))
	for i in 120:
		atmo.animate(1.0 / 60.0)
	check(atmo.apply_count == after_pulse, "...and goes quiet again once it is over")
	atmo.set_phase("flood")
	for i in 200:
		atmo.animate(1.0 / 60.0)
	var after_blend := atmo.apply_count
	check(after_blend > after_pulse and atmo.blend == 1.0, "A phase blend applies the look until it finishes")
	for i in 60:
		atmo.animate(1.0 / 60.0)
	check(atmo.apply_count == after_blend, "...then stops writing")
	check(is_equal_approx(atmo.environment.fog_density, atmo.looks["flood"]["fog_density"]), "...with the look settled exactly on the target values")
	atmo.set_phase("midnight", true)

	var dir := atmo.moon_direction()
	check(is_equal_approx(dir.length(), 1.0), "moon direction is normalised")
	check(dir.y < -0.3, "moon direction points downward")

	var bodies: Array = []
	find_all(atmo, "CollisionObject3D", bodies)
	var shapes: Array = []
	find_all(atmo, "CollisionShape3D", shapes)
	check(bodies.is_empty() and shapes.is_empty(), "no collision objects under the atmosphere")

	var scenery := atmo.get_node("IslandSilhouettes")
	var reeds := atmo.get_node("Reeds")
	var mist := atmo.get_node("Mist")
	check(mesh_outside(scenery), "island silhouettes outside the keep-out rectangle")
	check(mesh_outside(reeds), "reeds outside the keep-out rectangle")
	check(mesh_outside(mist), "mist sheets outside the keep-out rectangle")
	check(fireflies_outside(), "fireflies outside the keep-out rectangle")

	var nodes_before := count_nodes(atmo)
	var firefly_ok := true
	var transparent := 0
	for child in mist.get_children():
		transparent += 1
	for i in 600:
		atmo.animate(1.0 / 60.0)
		if i % 60 == 0 and not fireflies_outside():
			firefly_ok = false
	check(count_nodes(atmo) == nodes_before, "600 animate calls keep the node count")
	check(firefly_ok, "fireflies stay outside the keep-out rectangle while drifting")
	check(transparent <= 4, "at most 4 transparent mist sheets")
	check(mesh_outside(mist) and fireflies_outside(), "still outside after animation")

	var snap := atmo.debug_snapshot()
	check(snap.has("phase") and snap.has("blend") and snap.has("glow_supported"), "debug_snapshot has the contract keys")

	print("DUEL ATMOSPHERE RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
