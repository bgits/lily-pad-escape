extends SceneTree

var passed := 0
var failures: Array[String] = []
var floor_body: StaticBody3D

func _initialize() -> void:
	run.call_deferred()

func phys(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func frames(count: int) -> void:
	for i in count:
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count_nodes(child)
	return total

func avatar_restored(player: LilyDuelPlayer) -> bool:
	for mat in player.flash_materials:
		if mat.emission_enabled:
			return false
	return true

# Emission is on (black) from the start; only its colour moves, so a first hit changes no shader.
func avatar_prepared(player: LilyDuelPlayer) -> bool:
	if player.emissive_materials.size() < 4:
		return false
	for mat in player.emissive_materials:
		if not mat.emission_enabled or mat.emission != Color.BLACK or mat.emission_energy_multiplier != 1.0:
			return false
	return true

func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b

func run() -> void:
	LilyDuelPlayer.configure_input()
	# Helpers.
	check(LilyDuelFx.glow_texture() == LilyDuelFx.glow_texture(), "glow_texture is cached")
	check(LilyDuelFx.ray_texture() == LilyDuelFx.ray_texture(), "ray_texture is cached")
	check(LilyDuelFx.unit_quad() == LilyDuelFx.unit_quad() and LilyDuelFx.ray_quad() == LilyDuelFx.ray_quad(), "quad meshes are cached")
	var m1 := LilyDuelFx.additive_material(Color("ffd75e"), true)
	check(m1 == LilyDuelFx.additive_material(Color("ffd75e"), true), "additive_material returns the same material for the same arguments")
	check(m1 != LilyDuelFx.additive_material(Color("6fd3ff"), true) and m1 != LilyDuelFx.additive_material(Color("ffd75e"), false), "different arguments give different materials")
	check(m1.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and m1.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "sprite material is additive and unshaded")
	check(LilyDuelFx.ribbon_material() == LilyDuelFx.ribbon_material(), "ribbon_material is cached")

	# Trail.
	var trail := LilyDuelFx.Trail.new(3, 8, 0.5, 0.2)
	root.add_child(trail)
	var size_before := trail.buffer_size()
	var kids_before := count_nodes(trail)
	for i in 500:
		trail.push(i % 3, Vector3(i * 0.1, 0, 0))
		if i % 7 == 0:
			trail.advance(0.016)
	check(trail.buffer_size() == size_before and size_before == 24, "Trail buffers keep a fixed size over 500 pushes")
	check(count_nodes(trail) == kids_before, "Trail node count is constant")
	check(trail.counts[0] <= 8 and trail.live_points() <= 24, "Trail point counts stay bounded")
	trail.advance(1.0)
	check(not trail.visible and trail.live_points() == 0, "Trail goes idle once every point has expired")
	trail.track(0, Vector3.ZERO)
	check(trail.visible and trail.live_count(0) == 1, "track revives an idle trail")
	trail.clear()
	check(not trail.visible and trail.live_points() == 0, "clear empties the trail")
	trail.queue_free()

	# Players.
	floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, 0.1, 0)
	root.add_child(floor_body)
	var p0 := LilyDuelPlayer.new()
	p0.setup(0, {})
	var p1 := LilyDuelPlayer.new()
	p1.setup(1, {})
	root.add_child(p0)
	root.add_child(p1)
	p0.global_position = Vector3(-8, 0.62, 0)
	p1.global_position = Vector3(8, 0.62, 0)
	p0.active = true
	p1.active = true
	await phys(12)

	p0.set_carried(0)
	check(p0.visible_mote_count() == 0, "visible_mote_count is 0 for carried 0")
	p0.set_carried(5)
	check(p0.visible_mote_count() == 5, "visible_mote_count is 5 for carried 5")
	p0.set_carried(30)
	check(p0.visible_mote_count() == 12, "visible_mote_count is 12 for carried 30")
	check(p0.motes[0].mesh is QuadMesh and p0.motes[0].material_override.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Motes are additive sparks")
	check(p0.halo != null and p0.back_glow != null and p0.swarm_trail != null, "Player has halo, back glow and swarm trail")

	# Flash.
	check(avatar_prepared(p0) and avatar_prepared(p1), "Avatar emission is enabled once at build time, still black")
	var energy_target := p0.light_base
	for i in 50:
		p0.flash_hit()
	check(p0.flash_glow.visible and p0.flash_remaining > 0.1, "flash_hit shows the overlay")
	check(p0.flash_materials.size() > 3 and p0.flash_materials[0].emission_enabled, "flash_hit lights the avatar materials")
	await create_timer(0.3).timeout
	await frames(30)
	check(not p0.flash_glow.visible and p0.flash_remaining == 0.0, "Flash overlay is hidden after the flash")
	check(avatar_restored(p0), "Avatar emission is restored after 50 flash_hit calls")
	check(avatar_prepared(p0), "...and emission stayed enabled the whole time (only its colour was animated)")
	check(absf(p0.light.light_energy - p0.light_base) < 0.001 and p0.light_base <= energy_target + 2.5, "Light energy is back on its target")
	p1.active = false
	p1.flash_hit()
	await create_timer(0.3).timeout
	await frames(3)
	check(avatar_restored(p1) and not p1.flash_glow.visible, "flash_hit works and restores on an inactive player")
	# A rebuilt avatar (apply_appearance) flashes too and ends up prepared again.
	var old_first := p1.emissive_materials[0]
	p1.avatar.apply_appearance(LilyAppearance.sanitize({"top_color": 3}, true))
	p1.flash_hit()
	check(p1.flash_materials.size() > 3 and p1.flash_materials[0] != old_first and p1.flash_materials[0].emission == Color.WHITE, "flash_hit works after apply_appearance rebuilt the avatar")
	await create_timer(0.3).timeout
	await frames(3)
	check(avatar_prepared(p1) and p1.flash_materials.is_empty(), "...and the rebuilt avatar is back to black emission")

	# Steady node count while moving with 12 carried.
	p0.set_carried(12)
	p0.global_position = Vector3(-8, 0.62, 0)
	Input.action_press("duel_p1_right")
	await phys(60)
	var n60 := count_nodes(p0)
	Input.action_release("duel_p1_right")
	Input.action_press("duel_p1_left")
	await phys(270)
	Input.action_release("duel_p1_left")
	Input.action_press("duel_p1_right")
	await phys(270)
	Input.action_release("duel_p1_right")
	check(count_nodes(p0) == n60, "Player node count is identical at frame 60 and frame 600 (%d)" % n60)
	check(p0.swarm_trail.buffer_size() == 12 * 10, "Swarm trail buffer is fixed size")

	# Knockback streak.
	p0.set_carried(0)
	p0.global_position = Vector3(0, 0.62, 0)
	await phys(6)
	p0.knockback(Vector3.RIGHT)
	await phys(10)
	check(p0.stun_remaining > 0.0 and p0.streak.visible and p0.streak.live_points() >= 2, "Knockback shows the streak during the stun")
	await create_timer(1.0).timeout
	await phys(3)
	check(not p0.streak.visible and p0.streak.live_points() == 0, "The streak is gone 1 s later")

	# Queen.
	var queen := LilyDuelQueen.new()
	root.add_child(queen)
	queen.appear(Vector3(0, 3, 0))
	queen.advance(0.016)
	var q_nodes := count_nodes(queen)
	check(queen.rays.size() >= 6 and queen.rays.size() <= 8, "Queen has 6 to 8 light rays")
	var q_ok := true
	var moved := false
	for i in 600:
		if i == 150:
			queen.give_to(p1)
		if i == 350:
			queen.return_to_perch()
		queen.advance(1.0 / 60.0)
		if i == 300 and queen.trail.live_points() >= 2:
			moved = true
		q_ok = q_ok and count_nodes(queen) == q_nodes
	check(q_ok, "Queen node count is constant over 600 advances (perched, held, returning)")
	check(moved, "Queen leaves a trail while held")
	for i in 120:
		queen.advance(1.0 / 60.0)
	check(queen.state == "perched" and not queen.trail.visible, "Trail fades once the Queen is perched again")
	queen.hide_queen()
	queen.advance(0.016)
	check(count_nodes(queen) == q_nodes, "Hidden Queen adds no nodes")
	queen.queue_free()

	# Pads.
	var middle := LilyDuelPad.new()
	middle.setup(3, LilyDuelPad.Kind.MIDDLE, 1.9, 0.0)
	root.add_child(middle)
	var outer := LilyDuelPad.new()
	outer.setup(4, LilyDuelPad.Kind.OUTER, 1.9, 0.0)
	outer.position = Vector3(10, 0, 0)
	root.add_child(outer)
	middle.advance(0.016)
	check(not middle.rim_glow.visible, "Solid pad has no rim glow")
	middle.trigger_sink(3.0, 4.0)
	outer.trigger_sink(3.0, -1.0)
	middle.advance(0.5)
	outer.advance(0.5)
	check(middle.rim_glow.visible and outer.rim_glow.visible, "Rim glow shows in warning")
	var warm: Color = middle.rim_material.albedo_color
	var red: Color = outer.rim_material.albedo_color
	check(warm.r > 0.2 and warm.g > warm.b and red.g < warm.g * 0.7 + 0.001, "Temporary rim is amber and permanent rim is red")
	middle.advance(2.4)
	# The pulse dims and brightens, so compare the dimmest moment early and late in the warning.
	var early_dim := 9.0
	var probe := LilyDuelPad.new()
	probe.setup(5, LilyDuelPad.Kind.MIDDLE, 1.9, 0.0)
	root.add_child(probe)
	probe.trigger_sink(3.0, 4.0)
	for i in 40:
		probe.advance(0.01)
		early_dim = minf(early_dim, probe.rim_material.albedo_color.r)
	probe.advance(1.9)
	var late_dim := 9.0
	for i in 60:
		probe.advance(0.01)
		late_dim = minf(late_dim, probe.rim_material.albedo_color.r)
	check(probe.state == "warning" and late_dim > early_dim + 0.1, "Rim is brighter near the sink (dimmest %.2f early, %.2f late)" % [early_dim, late_dim])
	check(middle.state == "warning" and middle.rim_material.albedo_color.r > 0.4, "...and stays lit right before the sink")
	probe.queue_free()
	middle.reset_pad()
	check(not middle.rim_glow.visible and middle.state == "solid", "reset_pad hides the rim glow")
	var pad_count := count_nodes(middle)
	middle.trigger_sink(0.3, 0.2)
	for i in 400:
		middle.advance(0.016)
	check(middle.state == "solid" and not middle.rim_glow.visible and count_nodes(middle) == pad_count, "Rim is hidden again after the sink cycle and no nodes are added")
	middle.was_moving = false
	var before_color := middle.material.albedo_color
	middle.rim_material.albedo_color = Color(0.123, 0.5, 0.5)
	middle.advance(0.016)
	check(middle.rim_material.albedo_color == Color(0.123, 0.5, 0.5) and middle.material.albedo_color == before_color, "A solid resting pad does no work per tick")


	# Pad states differ by brightness and shape as well as hue, whatever the ambient tint.
	var yellow := LilyDuelPad.new()
	yellow.setup(1, LilyDuelPad.Kind.YELLOW, 1.45, 0.0)
	root.add_child(yellow)
	var fresh_pal := yellow.palette(false)
	var spent_pal := yellow.palette(true)
	var fresh_top := luminance(fresh_pal["base"]) + luminance(LilyDuelPad.YELLOW_GLOW) * LilyDuelPad.YELLOW_GLOW_ENERGY
	var spent_top := luminance(spent_pal["base"])
	check(spent_top <= fresh_top * 0.55, "A spent pad's top is at most 55%% as bright as a fresh one (%.3f vs %.3f)" % [spent_top, fresh_top])
	check(luminance(spent_pal["crack"]) < spent_top * 0.5 and luminance(spent_pal["rim"]) > spent_top, "...with darker cracks and a lighter rim")
	check(spent_pal["base"].s <= 0.35 and fresh_pal["base"].s >= 0.7, "...and it is desaturated where the fresh pad is vivid")
	check(yellow.material.emission_enabled and luminance(yellow.material.emission) > 0.1, "A fresh yellow pad carries its own gold emission")
	check(fresh_pal["base"].h > 0.1 and fresh_pal["base"].h < 0.2, "...whose hue is yellow-gold")
	yellow.set_spent(true)
	check(yellow.material.emission_enabled and yellow.material.emission == Color.BLACK, "A spent pad has no emission (the shader variant never changes)")
	yellow.set_spent(false)
	check(luminance(yellow.material.emission) > 0.1, "...and a reset pad has its gold back")
	var amber := LilyDuelPad.RIM_TEMPORARY
	var crimson := LilyDuelPad.RIM_PERMANENT
	check(amber.h > 0.05 and amber.h < 0.10 and amber.s > 0.95, "The temporary rim is a saturated orange-amber (hue %.3f)" % amber.h)
	check((crimson.h < 0.01 or crimson.h > 0.99) and crimson.s > 0.95 and crimson.g < 0.05 and crimson.b < 0.05, "The permanent rim is a strong pure red")
	check(absf(amber.h - fresh_pal["base"].h) > 0.04, "...and the amber rim is not the colour of a fresh yellow pad")
	var hue_ok := true
	var temp_pad := LilyDuelPad.new()
	temp_pad.setup(6, LilyDuelPad.Kind.OUTER, 1.9, 0.0)
	root.add_child(temp_pad)
	var perm_pad := LilyDuelPad.new()
	perm_pad.setup(7, LilyDuelPad.Kind.OUTER, 1.9, 0.0)
	root.add_child(perm_pad)
	temp_pad.trigger_sink(3.0, 4.0)
	perm_pad.trigger_sink(3.0, -1.0)
	for i in 280:
		temp_pad.advance(0.01)
		perm_pad.advance(0.01)
		var tc: Color = temp_pad.rim_material.albedo_color
		var pc: Color = perm_pad.rim_material.albedo_color
		if tc.h < 0.05 or tc.h > 0.10 or pc.s < 0.95 or (pc.h > 0.01 and pc.h < 0.99):
			hue_ok = false
	check(hue_ok, "Rim hues stay put while the brightness pulses")
	check(perm_pad.rim_glow.mesh != temp_pad.rim_glow.mesh and (perm_pad.rim_glow.mesh as TorusMesh).inner_radius < (temp_pad.rim_glow.mesh as TorusMesh).inner_radius, "A permanent sink gets a wider rim band than a temporary one")
	check(temp_pad.rim_material.blend_mode == BaseMaterial3D.BLEND_MODE_MIX and temp_pad.rim_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Rims are opaque and unshaded so ambient light cannot recolour them")
	yellow.queue_free()
	temp_pad.queue_free()
	perm_pad.queue_free()

	# Pad outline rings follow the visual water level.
	var ringed := LilyDuelPad.new()
	ringed.setup(8, LilyDuelPad.Kind.OUTER, 1.9, 0.0)
	root.add_child(ringed)
	check(is_equal_approx(ringed.ripple.position.y, 0.09), "The outline ring sits at 0.09 over the resting water")
	ringed.set_water_level(0.30)
	check(is_equal_approx(ringed.ripple.position.y, 0.30 + LilyDuelPad.RING_OFFSET) and ringed.ripple.position.y > 0.30, "The ring rides above water raised to 0.30")
	ringed.set_water_level(0.04)
	check(is_equal_approx(ringed.ripple.position.y, 0.09), "...and comes back down")
	ringed.queue_free()

	print("DUEL FX RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
