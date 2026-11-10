extends SceneTree

var arena: LilyDuelArena
var passed := 0
var failures: Array[String] = []
var sank_count := 0
var rose_count := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		arena.advance(1.0 / 60.0)
		await physics_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func near(a: Vector3, b: Vector3, tolerance := 0.01) -> bool:
	return a.distance_to(b) <= tolerance

func ray_down(x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 5, z), Vector3(x, -3, z), 1)
	return arena.get_world_3d().direct_space_state.intersect_ray(query)

func gap(a: LilyDuelPad, b: LilyDuelPad) -> float:
	return a.position.distance_to(b.position) - a.radius - b.radius

func run() -> void:
	arena = LilyDuelArena.new()
	root.add_child(arena)
	arena.build()
	await physics_frame
	await physics_frame
	var pads := arena.pads
	check(pads.size() == 23, "Arena builds 23 pads")
	var ids_ok := true
	for i in pads.size():
		ids_ok = ids_ok and pads[i].pad_id == i
	check(ids_ok, "Pad ids match their index")
	var counts := {}
	for pad in pads:
		counts[pad.kind] = int(counts.get(pad.kind, 0)) + 1
	check(counts.get(LilyDuelPad.Kind.CENTER) == 1 and counts.get(LilyDuelPad.Kind.MIDDLE) == 6 and counts.get(LilyDuelPad.Kind.YELLOW) == 2 and counts.get(LilyDuelPad.Kind.OUTER) == 12 and counts.get(LilyDuelPad.Kind.HOME) == 2, "Kind counts are 1/6/2/12/2")
	check(arena.middle_pads.size() == 6 and arena.outer_pads.size() == 12 and arena.home_pads.size() == 2 and arena.yellow_pads.size() == 2, "Kind lists are filled")
	check(arena.yellow_pads[0].pad_id == 5 and arena.yellow_pads[1].pad_id == 1, "Yellow list is [west 5, east 1]")
	check(near(pads[0].position, Vector3.ZERO) and is_equal_approx(pads[0].radius, 2.6), "Pad 0 is the centre, radius 2.6")
	check(near(pads[1].position, Vector3(6, 0, 0)) and is_equal_approx(pads[1].radius, 1.45) and pads[1].kind == LilyDuelPad.Kind.YELLOW, "Pad 1 is yellow at (6,0,0)")
	check(near(pads[5].position, Vector3(-6, 0, 0)) and pads[5].kind == LilyDuelPad.Kind.YELLOW, "Pad 5 is yellow at (-6,0,0)")
	check(near(pads[9].position, Vector3(10.6, 0, 0)) and is_equal_approx(pads[9].radius, 1.9) and pads[9].kind == LilyDuelPad.Kind.OUTER, "Pad 9 is outer at (10.6,0,0)")
	check(near(pads[15].position, Vector3(-10.6, 0, 0)), "Pad 15 is outer at (-10.6,0,0)")
	check(near(pads[21].position, Vector3(-15.8, 0, 0)) and is_equal_approx(pads[21].radius, 2.0) and pads[21].owner_index == 0, "Pad 21 is home 0 at (-15.8,0,0)")
	check(near(pads[22].position, Vector3(15.8, 0, 0)) and pads[22].owner_index == 1, "Pad 22 is home 1 at (15.8,0,0)")
	var overlap := false
	var min_gap := 99.0
	var worst_gap := 0.0
	var linked := true
	for a in pads:
		var best := 99.0
		for b in pads:
			if a == b:
				continue
			var g := gap(a, b)
			best = minf(best, g)
			if g <= 0.05:
				overlap = true
		min_gap = minf(min_gap, best)
		worst_gap = maxf(worst_gap, best)
		linked = linked and best <= 2.3
	check(not overlap, "No two pads overlap")
	check(linked, "Every pad has a neighbour within 2.3 m (worst nearest gap %.2f)" % worst_gap)
	var seen := {21: true}
	var queue := [21]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for b in pads:
			if not seen.has(b.pad_id) and gap(pads[current], b) <= 2.3:
				seen[b.pad_id] = true
				queue.append(b.pad_id)
	check(seen.has(22) and seen.size() == 23, "Pad graph is connected from home 21 to home 22")
	# Camera framing.
	var cam := arena.camera
	check(cam != null and is_equal_approx(cam.fov, 50.0), "Camera exists with fov 50")
	cam.current = true
	var size := Vector2(1280, 720)
	var inside := true
	var lowest := 1.0e9
	for pad in pads:
		for k in 16:
			var a := k * TAU / 16
			var p := pad.surface_center() + Vector3(cos(a), 0, sin(a)) * pad.radius
			if cam.is_position_behind(p):
				inside = false
				continue
			var s := cam.unproject_position(p)
			lowest = minf(lowest, s.y)
			if s.x < 0 or s.x > size.x or s.y > size.y:
				inside = false
	check(inside and lowest >= size.y * 0.12, "All pads fit the 16:9 view below a 12%% HUD band (top edge at %.0f px)" % lowest)

	# Sink cycle.
	var mid := arena.middle_pads[0]
	mid.sank.connect(func(_p): sank_count += 1)
	mid.rose.connect(func(_p): rose_count += 1)
	check(mid.state == "solid" and mid.is_standable(), "Middle pad starts solid")
	check(ray_down(mid.position.x, mid.position.z).has("position"), "Ray hits a solid pad")
	check(absf(ray_down(mid.position.x, mid.position.z).get("position", Vector3.ZERO).y - 0.6) < 0.02, "Ray hit height is about 0.60")
	check(mid.trigger_sink(0.3, 0.5), "trigger_sink on a solid pad returns true")
	check(mid.state == "warning" and mid.is_standable(), "Pad warns and is still standable")
	check(not mid.trigger_sink(0.3, 0.5), "Second trigger_sink during warning returns false")
	var saw_rising := false
	var saw_sunk := false
	var sank_frame := -1
	for i in 150:
		await frames(1)
		if mid.state == "sunk":
			saw_sunk = true
			if sank_frame < 0:
				sank_frame = i
				check(sank_count == 1 and not mid.is_standable(), "sank fired with the state change; not standable")
				check(mid.collision_layer == 0, "Collision layer removed when sank fires")
				await physics_frame
				check(not ray_down(mid.position.x, mid.position.z).has("position"), "Ray misses a sunk pad")
				check(arena.pad_at(mid.surface_center()) == null, "pad_at is null for a sunk pad")
				check(not arena.nearest_standable(mid.surface_center(), 30, true, true).has(mid), "nearest_standable skips sunk pads")
		if mid.state == "rising":
			saw_rising = true
			pass
		if mid.state == "solid" and sank_frame >= 0:
			break
	check(saw_sunk and saw_rising, "Pad passed through sunk and rising")
	check(mid.state == "solid" and rose_count == 1 and mid.is_standable(), "Pad is solid again and rose fired once")
	await physics_frame
	check(ray_down(mid.position.x, mid.position.z).has("position"), "Ray hits again after the pad rose")

	# Permanent sink and override.
	var outer := arena.outer_pads[2]
	check(outer.trigger_sink(0.2, -1.0), "Permanent sink accepted")
	for i in 120:
		await frames(1)
	check(outer.state == "gone" and not outer.visual_pivot.visible, "Permanent pad ends gone and hidden")
	await frames(60)
	check(outer.state == "gone", "Gone pads stay gone")
	check(not outer.trigger_sink(0.1, 1.0), "Gone pad refuses ordinary sinking")
	var cycle := arena.outer_pads[5]
	cycle.trigger_sink(1.0, 3.0)
	await frames(30)
	check(cycle.state == "warning", "Cycle pad is still warning after 0.5 s")
	check(cycle.trigger_sink(0.2, -1.0), "Permanent request overrides a warning")
	for i in 120:
		await frames(1)
	check(cycle.state == "gone", "Overridden warning ends gone")
	var cycle2 := arena.outer_pads[6]
	cycle2.trigger_sink(0.1, 1.0)
	for i in 50:
		await frames(1)
	check(cycle2.state == "sunk", "Pad is sunk mid-cycle")
	check(cycle2.trigger_sink(0.1, -1.0), "Permanent request overrides a sunk pad")
	for i in 60:
		await frames(1)
	check(cycle2.state == "gone", "Overridden sunk pad ends gone")
	var cycle3 := arena.outer_pads[7]
	cycle3.trigger_sink(0.1, 0.1)
	for i in 80:
		await frames(1)
		if cycle3.state == "rising":
			break
	check(cycle3.state == "rising" and not cycle3.is_standable(), "Pad reached rising")
	check(cycle3.trigger_sink(0.1, -1.0), "Permanent request overrides a rising pad")
	var restored := false
	for i in 120:
		await frames(1)
		restored = restored or cycle3.state == "solid"
	check(cycle3.state == "gone" and not restored, "Overridden rising pad never turns solid and ends gone")

	# Yellow spent visual.
	var yellow := arena.yellow_pads[0]
	var fresh_mesh := yellow.mesh_node.mesh
	yellow.set_spent(true)
	check(yellow.spent and yellow.mesh_node.mesh != fresh_mesh, "Spent yellow pad swaps to the cracked mesh")

	# Reset.
	arena.reset_arena()
	await physics_frame
	var all_solid := true
	for pad in arena.pads:
		all_solid = all_solid and pad.state == "solid" and pad.is_standable() and not pad.spent and pad.collision_layer == 1
	check(all_solid, "reset_arena restores every pad to solid")
	check(ray_down(outer.position.x, outer.position.z).has("position"), "Reset gone pad is solid to physics again")

	# Lookup.
	var on_pad := arena.pad_at(Vector3(10.6, 0.6, 0.5))
	check(on_pad != null and on_pad.pad_id == 9, "pad_at finds pad 9")
	check(arena.pad_at(Vector3(0, 0.6, 0)).pad_id == 0, "pad_at finds the centre")
	check(arena.pad_at(Vector3(8.3, 0.6, 0)) == null, "pad_at is null over water")
	var near_home := arena.nearest_standable(Vector3(-14.5, 0.6, 0), 3, false, true)
	check(near_home.size() == 3 and not near_home.any(func(p): return p.kind == LilyDuelPad.Kind.HOME), "nearest_standable excludes homes by default")
	var with_home := arena.nearest_standable(Vector3(-14.5, 0.6, 0), 3, true, true)
	check(with_home[0].pad_id == 21, "nearest_standable includes homes when allowed")
	var no_center := arena.nearest_standable(Vector3(0.5, 0.6, 0), 5, false, false)
	check(no_center.size() == 5 and not no_center.any(func(p): return p.kind == LilyDuelPad.Kind.CENTER), "nearest_standable can exclude the centre")
	var with_center := arena.nearest_standable(Vector3(0.5, 0.6, 0), 1, false, true)
	check(with_center[0].pad_id == 0, "nearest_standable includes the centre by default")
	check(arena.nearest_standable(Vector3.ZERO, 100, true, true).size() == 23, "nearest_standable caps at available pads")

	# Spawn points.
	var s0 := arena.spawn_point(0)
	var s1 := arena.spawn_point(1)
	check(arena.pad_at(s0) == pads[21] and absf(s0.y - 0.68) < 0.001, "spawn_point(0) is on pad 21")
	check(arena.pad_at(s1) == pads[22] and absf(s1.y - 0.68) < 0.001, "spawn_point(1) is on pad 22")
	check(near(arena.queen_perch(), Vector3(0, 2.3, 0)), "Queen perch is 1.7 m above the centre surface")

	# Lantern.
	var light: OmniLight3D = pads[21].lantern_light
	var e0 := light.light_energy
	check(light != null and e0 > 0.5, "Lantern glows at score 0")
	arena.set_lantern_score(0, 6)
	for i in 240:
		arena.animate(0.016)
	check(pads[21].lantern_light.light_energy > e0 * 1.5 and pads[21].lantern_light.omni_range > pads[22].lantern_light.omni_range, "Lantern grows with score")
	arena.set_lantern_score(0, 500)
	for i in 600:
		arena.animate(0.016)
	check(pads[21].lantern_light.light_energy < 6.0, "Lantern energy is clamped")
	check(pads[21].lantern.get_child_count() > 0 and pads[22].lantern.position.x > 0.0 and pads[21].lantern.position.x < 0.0, "Lanterns sit on the outer edges")
	arena.reset_arena()
	check(pads[21].lantern_score == 0, "reset_arena returns lanterns to score 0")

	# Lotus.
	check(not arena.lotus_open, "Lotus starts closed")
	var closed_tilt: float = arena.lotus_petals[0].rotation.x
	arena.open_lotus()
	check(arena.lotus_open, "open_lotus sets lotus_open")
	for i in 80:
		arena.animate(0.016)
	check(arena.lotus_petals[0].rotation.x > closed_tilt + 1.0, "Petals fold outward after about a second")
	arena.reset_arena()
	check(not arena.lotus_open and is_equal_approx(arena.lotus_petals[0].rotation.x, closed_tilt), "reset_arena closes the lotus instantly")

	# Particles.
	var p := Vector3(1, 1, 1)
	arena.splash(p)
	arena.firefly_puff(p)
	arena.burst(p, Color.CYAN, 20)
	arena.bonk(p)
	arena.celebrate(p)
	check(arena.particles.size() > 100, "Particle effects spawn")
	for i in 200:
		arena.animate(0.016)
	check(arena.particles.is_empty(), "Particles expire on their own")
	arena.splash(p)
	arena.bonk(p)
	arena.celebrate(p)
	for i in 5:
		arena.animate(0.016)
	arena.clear_particles()
	check(arena.particles.is_empty(), "clear_particles empties them")

	print("DUEL ARENA RESULT: %d passed, %d failed" % [passed, failures.size()])
	arena.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
