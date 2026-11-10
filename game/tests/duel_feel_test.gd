extends SceneTree

# Match feel (spec section 8): arena shake / water level / look, phase looks, flood creep,
# reflections, ripples and hit-stop. Real physics frames; scenes are set up by placing players.

const SURFACE := 0.60

var duel: LilyDuel
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func until(condition: Callable, limit := 300) -> bool:
	for i in limit:
		if condition.call():
			return true
		await physics_frame
	return condition.call()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		var detail := ""
		if duel != null and is_instance_valid(duel) and duel.begun:
			detail = " [phase=%s elapsed=%.2f scores=%s]" % [duel.phase, duel.elapsed, str(duel.scores)]
		print("FAIL: ", message, detail)
		push_error("FAIL: " + message + detail)

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func pl(index: int) -> LilyDuelPlayer:
	return duel.players[index]

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count_nodes(child)
	return total

# Hit-stop holds a player by switching off physics and idle processing; input keeps arriving.
func held(player: LilyDuelPlayer) -> bool:
	return not player.is_physics_processing() and not player.is_processing()

func running(player: LilyDuelPlayer) -> bool:
	return player.is_physics_processing() and player.is_processing()

func make_duel() -> LilyDuel:
	var made := LilyDuel.new()
	root.add_child(made)
	made.begin(LilyAppearance.DEFAULTS.duplicate(), "Ava")
	made.countdown_seconds = 0.2
	return made

func settle_dusk() -> void:
	duel.max_loose = 0
	duel.start_match()
	await until(func(): return duel.phase == "dusk")
	await ticks(4)

func face_off() -> void:
	pl(0).respawn(Vector3(-0.75, SURFACE + 0.08, 0), Vector3.RIGHT)
	pl(1).respawn(Vector3(0.75, SURFACE + 0.08, 0), Vector3.LEFT)
	await ticks(6)

func look() -> String:
	return duel.arena.atmosphere.debug_snapshot()["phase"]

# Swings player 0 at player 1 with a real key press and measures the aftermath.
func measure_hit(stop: float) -> Dictionary:
	duel.hit_stop_seconds = stop
	await settle_dusk()
	await face_off()
	var result := {"frozen_ticks": 0, "elapsed_constant": true, "positions_constant": true, "velocity_kept": true, "active_during": true}
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	var hit := await until(func(): return pl(1).invulnerable_remaining > 0.0, 60)
	result["hit"] = hit
	result["shaking"] = duel.arena.shake_left > 0.0
	var elapsed_at_hit := duel.elapsed
	var p0 := pl(0).global_position
	var p1 := pl(1).global_position
	var v1 := pl(1).velocity
	while duel.freeze_left > 0.0 and result["frozen_ticks"] < 30:
		result["frozen_ticks"] += 1
		if duel.elapsed != elapsed_at_hit:
			result["elapsed_constant"] = false
		if pl(0).global_position != p0 or pl(1).global_position != p1:
			result["positions_constant"] = false
		if pl(1).velocity != v1:
			result["velocity_kept"] = false
		result["active_during"] = result["active_during"] and held(pl(0)) and held(pl(1))
		await physics_frame
	result["both_active_after"] = pl(0).active and pl(1).active and running(pl(0)) and running(pl(1))
	var sync_elapsed := duel.elapsed
	var start_x := pl(1).global_position.x
	await ticks(15)
	result["distance"] = pl(1).global_position.x - start_x
	result["elapsed_span"] = duel.elapsed - sync_elapsed
	result["invulnerable"] = pl(1).invulnerable_remaining
	result["stun"] = pl(1).stun_remaining
	result["velocity_after"] = v1
	return result

# The attacker presses jump 1 and 3 ticks into a hit-stop (real key events).
func jump_probe(stop: float) -> Dictionary:
	duel.hit_stop_seconds = stop
	await settle_dusk()
	await face_off()
	var a := pl(0)
	var jumps := a.jump_count
	var start_y := a.global_position.y
	duel.hit_player(a, pl(1))
	var result := {"frozen": duel.freeze_left > 0.0}
	await ticks(1)
	key(KEY_SPACE)
	key(KEY_SPACE, false)
	result["buffer_1"] = a.buffered
	await ticks(1)
	result["buffer_2"] = a.buffered
	result["still_frozen_2"] = duel.freeze_left > 0.0 or stop <= 0.0
	await ticks(1)
	key(KEY_SPACE)
	key(KEY_SPACE, false)
	result["buffer_3"] = a.buffered
	if stop > 0.0:
		result["jumps_while_frozen"] = a.jump_count - jumps
		await until(func(): return duel.freeze_left == 0.0, 30)
	await ticks(4)
	result["jumps"] = a.jump_count - jumps
	result["rose"] = a.global_position.y - start_y
	await ticks(30)
	result["jumps_later"] = a.jump_count - jumps
	return result

func run() -> void:
	var baseline := root.get_child_count()
	duel = make_duel()
	await ticks(3)

	# --- arena -----------------------------------------------------------------------
	var arena := duel.arena
	check(arena.water is LilyDuelWater and arena.atmosphere is LilyDuelAtmosphere, "The arena has a water and an atmosphere")
	check(duel.find_children("*", "WorldEnvironment", true, false).size() == 1, "Exactly one WorldEnvironment in the duel")
	check(duel.find_children("*", "DirectionalLight3D", true, false).size() == 1, "Exactly one DirectionalLight3D in the duel")
	check(arena.find_child("NightWater", true, false) != null and arena.water.position == Vector3.ZERO, "The water node sits at the origin")
	check(is_equal_approx(arena.water.level, LilyDuelArena.WATER_HEIGHT), "The water starts at WATER_HEIGHT")

	var base := arena.camera_base
	check(arena.camera.transform == base, "The camera starts on its base transform")
	arena.shake(1.0)
	arena.animate(0.016)
	check(arena.camera.transform != base, "shake() moves the camera")
	var widest := 0.0
	for i in 30:
		arena.shake(1.0)
		arena.animate(0.004)
		widest = maxf(widest, arena.camera.transform.origin.distance_to(base.origin))
	check(widest > 0.02 and widest <= 0.25, "Repeated shakes stay under the cap (%.3f m)" % widest)
	for i in 63:
		arena.animate(0.016)
	check(arena.camera.transform == base, "After 1 s the camera transform equals the base exactly")
	arena.shake(0.0)
	arena.animate(0.016)
	check(arena.camera.transform == base, "A zero-strength shake does nothing")

	arena.set_water_level(5.0)
	check(is_equal_approx(arena.water_level_target, 0.30), "set_water_level(5.0) clamps to 0.30")
	arena.animate(0.016)
	check(arena.water_level > LilyDuelArena.WATER_HEIGHT and arena.water_level < 0.30, "The water level eases toward its target")
	check(is_equal_approx(arena.water.level, arena.water_level), "...and the water surface follows")
	for i in 400:
		arena.animate(0.016)
	check(is_equal_approx(arena.water_level, 0.30) and is_equal_approx(arena.water.surface.position.y, 0.30), "...and arrives at 0.30")
	var rings_at := arena.pads[3].ripple.position.y
	check(is_equal_approx(rings_at, arena.water_level + LilyDuelPad.RING_OFFSET) and rings_at > 0.30, "The pad outline rings ride above the raised water (%.3f)" % rings_at)
	var splash_first := arena.particles.size()
	arena.splash(Vector3(2, 0.6, 2))
	var splash_low := INF
	for i in range(splash_first, arena.particles.size()):
		splash_low = minf(splash_low, arena.particles[i]["node"].position.y)
	check(arena.particles.size() > splash_first and splash_low >= 0.30, "Splash pieces start above the raised water (%.3f)" % splash_low)
	arena.clear_particles()
	arena.set_water_level(-3.0)
	check(is_equal_approx(arena.water_level_target, LilyDuelArena.WATER_HEIGHT), "set_water_level clamps below at WATER_HEIGHT")
	arena.animate(0.001)
	check(is_equal_approx(arena.pads[3].ripple.position.y, rings_at), "The rings wait for the water to move about a centimetre")
	for i in 400:
		arena.animate(0.016)
	check(is_equal_approx(arena.pads[3].ripple.position.y, 0.09) and is_equal_approx(arena.pads[10].ripple.position.y, 0.09), "...and settle back to 0.09 with the water")
	arena.set_phase_look("flood", true)
	check(look() == "flood", "set_phase_look forwards to the atmosphere")
	arena.shake(1.0)
	arena.animate(0.016)
	arena.reset_arena()
	check(is_equal_approx(arena.water_level, LilyDuelArena.WATER_HEIGHT) and is_equal_approx(arena.water_level_target, LilyDuelArena.WATER_HEIGHT), "reset_arena restores the water level")
	check(look() == "dusk" and arena.atmosphere.blend == 1.0, "reset_arena returns to the dusk look instantly")
	check(arena.camera.transform == base and arena.shake_left == 0.0, "reset_arena clears the shake")
	var splash_before: int = arena.water.debug_snapshot()["ripples"]
	arena.splash(Vector3(3, 0.6, 3))
	var water_info: Dictionary = arena.water.debug_snapshot()
	check(water_info["ripples"] == splash_before + 1 and water_info["flashes"] >= 1, "splash() adds a ripple and a flash to the water")
	var lights := arena.lantern_reflections()
	check(lights.size() == 2 and lights[0]["energy"] >= 1.2 and lights[0]["energy"] <= 2.4, "Two lantern reflection entries with energy 1.2-2.4")
	check(lights[0]["color"] == LilyDuelPlayer.PLAYER_COLORS[0] and lights[1]["color"] == LilyDuelPlayer.PLAYER_COLORS[1], "...in the player colours")
	arena.set_lantern_score(0, 10)
	check(arena.lantern_reflections()[0]["energy"] > lights[1]["energy"], "...with energy growing with the lantern score")
	arena.set_lantern_score(0, 0)

	# --- phase looks, flood creep -------------------------------------------------------------
	duel.countdown_seconds = 0.2
	duel.dusk_seconds = 1.5
	duel.midnight_seconds = 1.5
	duel.flood_seconds = 6.0
	duel.flood_schedule = [{"at": 0.0, "ids": [12, 18]}]
	duel.spawn_interval = 0.3
	duel.start_match()
	duel.scores = [3, 1]
	check(look() == "dusk", "A new match starts with the dusk look")
	await until(func(): return duel.phase == "dusk")
	await ticks(5)
	check(look() == "dusk" and is_equal_approx(duel.arena.water_level, LilyDuelArena.WATER_HEIGHT), "Dusk: dusk look, water at rest")
	await until(func(): return duel.phase == "midnight", 200)
	await ticks(5)
	check(look() == "midnight", "Midnight: the midnight look")
	await until(func(): return duel.phase == "flood", 200)
	await ticks(5)
	check(look() == "flood", "Flood: the flood look")
	var last_level := duel.arena.water_level
	var monotonic := true
	var peak := 0.0
	var halfway := 0.0
	while duel.phase == "flood":
		await physics_frame
		await process_frame
		var level := duel.arena.water_level
		if level < last_level - 0.0001:
			monotonic = false
		last_level = level
		peak = maxf(peak, level)
		if duel.elapsed - duel.flood_start() > 3.0 and halfway == 0.0:
			halfway = level
	check(monotonic and halfway > LilyDuelArena.WATER_HEIGHT + 0.03, "The water creeps up during the flood (%.3f halfway)" % halfway)
	check(peak <= 0.30 + 0.0001 and peak > 0.2, "...never above 0.30 (peak %.3f)" % peak)
	check(duel.phase == "over" and look() == "over", "Match over: the calm look")
	check(not duel.out[0] and not duel.out[1], "Players on pads are not taken out when the flood ends")
	# Rules still use WATER_HEIGHT, not the visual level.
	duel.start_match()
	await until(func(): return duel.phase == "dusk")
	await ticks(3)
	check(is_equal_approx(duel.arena.water_level, LilyDuelArena.WATER_HEIGHT) and look() == "dusk", "A rematch brings the water level and look back")
	duel.arena.set_water_level(0.30)
	for i in 400:
		duel.arena.animate(0.016)
	var p := pl(1)
	p.global_position = Vector3(0, 0.10, -30)
	duel.on_player_stepped(p, 0.016)
	check(not duel.out[1], "A player at y 0.10 (under the raised visual water) is not taken out")
	p.global_position = Vector3(0, LilyDuelArena.WATER_HEIGHT - 0.18 - 0.02, -30)
	duel.on_player_stepped(p, 0.016)
	check(duel.out[1], "A player below WATER_HEIGHT - 0.18 is taken out")

	# --- reflections ---------------------------------------------------------------------------
	duel.dusk_seconds = 60.0
	duel.midnight_seconds = 60.0
	duel.flood_seconds = 60.0
	duel.max_loose = 40
	duel.start_match()
	await until(func(): return duel.phase == "dusk")
	await ticks(3)
	pl(0).respawn(Vector3(0, SURFACE + 0.08, 0), Vector3.RIGHT)
	pl(0).set_carried(4)
	for i in 24:
		duel.spawn_firefly(duel.arena.pads[1 + i % 8], Vector3(-18.0 + i * 1.5, 1.5, 0))
	await ticks(2)
	await process_frame
	var refl := duel.reflection_lights
	check(refl.size() == LilyDuelWater.MAX_REFLECTIONS, "Reflections are capped at 16 (%d)" % refl.size())
	var near_lantern := [false, false]
	for entry in refl:
		for i in 2:
			if entry["position"].distance_to(duel.arena.home_pads[i].lantern.global_position) < 0.01:
				near_lantern[i] = true
	check(near_lantern[0] and near_lantern[1], "...and include both lanterns")
	check(duel.arena.water.debug_snapshot()["reflections"] == 16, "...and reach the water")
	var carry_lit := false
	for entry in refl:
		if is_equal_approx(entry["energy"], 0.4 + 0.06 * pl(0).carried):
			carry_lit = true
	check(carry_lit, "A player carrying fireflies reflects 0.4 + 0.06 * carried")
	var furthest_in := 0.0
	var nearest_out := INF
	var shown: Array = []
	for entry in refl:
		if is_equal_approx(entry["energy"], 0.3):
			shown.append(entry["position"])
	for fly in duel.loose_fireflies:
		var d := Vector2(fly.global_position.x, fly.global_position.z).length()
		var is_shown := false
		for point in shown:
			if point.distance_to(fly.global_position) < 0.001:
				is_shown = true
		if is_shown:
			furthest_in = maxf(furthest_in, d)
		else:
			nearest_out = minf(nearest_out, d)
	check(shown.size() == 13 and furthest_in <= nearest_out, "The fireflies nearest the centre fill the remaining slots")
	duel.set_elapsed(60.5)
	await ticks(4)
	await process_frame
	var gold := false
	for entry in duel.reflection_lights:
		if is_equal_approx(entry["energy"], 2.0):
			gold = true
	check(duel.queen.state != "hidden" and gold and duel.reflection_lights.size() <= 16, "The visible Queen is a gold reflection")
	for fly in duel.loose_fireflies:
		fly.free()
	duel.loose_fireflies.clear()
	duel.max_loose = 0

	# --- landing ripples ----------------------------------------------------------------------------
	duel.start_match()
	await until(func(): return duel.phase == "dusk")
	await ticks(3)
	pl(0).respawn(Vector3(0.0, SURFACE + 1.2, 0.0), Vector3.RIGHT)
	await ticks(2)
	var ripples_before: int = duel.arena.water.debug_snapshot()["ripples"]
	var landed := await until(func(): return pl(0).is_on_floor(), 60)
	await ticks(2)
	check(landed and duel.arena.water.debug_snapshot()["ripples"] > ripples_before, "A player landing on a pad adds a ripple")

	# --- hit-stop --------------------------------------------------------------------------------------
	var plain := await measure_hit(0.0)
	var stopped := await measure_hit(0.07)
	check(plain["hit"] and stopped["hit"], "A real bat swing hits in both runs")
	check(plain["frozen_ticks"] == 0, "hit_stop_seconds = 0 never freezes")
	check(stopped["frozen_ticks"] >= 3 and stopped["frozen_ticks"] <= 6, "The default hit-stop lasts a few physics frames (%d)" % stopped["frozen_ticks"])
	check(stopped["elapsed_constant"], "The match clock does not move during the freeze")
	check(stopped["positions_constant"], "Neither player moves during the freeze")
	check(stopped["velocity_kept"] and stopped["active_during"], "...knockback velocity is intact and both players are held")
	check(stopped["both_active_after"], "Both players are active again when the freeze ends")
	var ratio: float = stopped["distance"] / maxf(plain["distance"], 0.001)
	check(plain["distance"] > 1.0 and ratio > 0.95 and ratio < 1.05, "The victim travels the same knockback distance (%.2f m vs %.2f m)" % [stopped["distance"], plain["distance"]])
	check(absf(stopped["elapsed_span"] - plain["elapsed_span"]) < 0.0005, "Match time after the freeze runs the same (%.4f vs %.4f s)" % [stopped["elapsed_span"], plain["elapsed_span"]])
	check(absf(stopped["invulnerable"] - plain["invulnerable"]) < 0.0005 and absf(stopped["stun"] - plain["stun"]) < 0.0005, "Stun and invulnerability timers are unchanged")
	duel.hit_stop_seconds = 0.07
	check(stopped["shaking"] and plain["shaking"], "A bat hit shakes the camera")

	# Hit during pause: no freeze is queued and resume leaves everyone active.
	await settle_dusk()
	await face_off()
	duel.toggle_pause()
	duel.hit_player(pl(0), pl(1))
	check(duel.freeze_left == 0.0, "A hit while paused starts no freeze")
	duel.toggle_pause()
	await ticks(8)
	check(pl(0).active and pl(1).active and not duel.paused and running(pl(0)), "...and resuming leaves both players active")

	# Pause during a freeze.
	await settle_dusk()
	await face_off()
	duel.hit_player(pl(0), pl(1))
	var knock_velocity := pl(1).velocity
	check(duel.freeze_left > 0.0 and held(pl(0)) and held(pl(1)), "hit_player starts the freeze")
	duel.toggle_pause()
	await ticks(10)
	check(duel.paused and not pl(0).active and held(pl(1)) and pl(1).velocity == knock_velocity, "Paused mid-freeze: still held, velocity intact")
	duel.toggle_pause()
	await until(func(): return duel.freeze_left == 0.0, 30)
	await ticks(1)
	check(pl(0).active and pl(1).active and running(pl(0)) and running(pl(1)), "Resuming mid-freeze finishes the freeze and frees both players")

	# Second hit during a freeze.
	await settle_dusk()
	await face_off()
	duel.hit_player(pl(0), pl(1))
	await ticks(2)
	var first_left := duel.freeze_left
	duel.hit_player(pl(1), pl(0))
	check(duel.freeze_left > first_left and duel.freeze_left <= duel.hit_stop_seconds + 0.0001, "A second hit extends the freeze but never stacks beyond one hit-stop")
	await until(func(): return duel.freeze_left == 0.0, 60)
	await ticks(1)
	check(pl(0).active and pl(1).active, "...and both players are active afterwards")
	check(pl(0).velocity.length() > 1.0 and pl(1).velocity.length() > 1.0 or pl(0).stun_remaining > 0.0, "...with knockback intact on both")

	# Input during the freeze is not lost: a jump pressed 1 and 3 ticks in jumps afterwards.
	var jump_plain := await jump_probe(0.0)
	var jump_stopped := await jump_probe(0.07)
	check(jump_stopped["frozen"] and not jump_plain["frozen"], "Setup: only the second run freezes")
	check(is_equal_approx(jump_stopped["buffer_1"], 0.12) and is_equal_approx(jump_stopped["buffer_2"], 0.12), "A jump pressed in the freeze is buffered and the buffer does not count down while frozen")
	check(jump_stopped["jumps_while_frozen"] == 0, "...the jump itself waits for the freeze to end")
	check(jump_plain["jumps"] == 1 and jump_plain["jumps_later"] == 1 and jump_plain["rose"] > 0.1, "Without hit-stop the same two presses give exactly one jump")
	check(jump_stopped["jumps"] == 1 and jump_stopped["jumps_later"] == 1 and jump_stopped["rose"] > 0.1, "With hit-stop the same two presses also give exactly one jump after the freeze")

	# A swing requested during the freeze starts at once, but its timers wait for the freeze to end.
	await settle_dusk()
	await face_off()
	var swings := [0]
	var count_swing := func(_who): swings[0] += 1
	pl(0).swung.connect(count_swing)
	duel.hit_player(pl(0), pl(1))
	await ticks(1)
	key(KEY_F)
	key(KEY_F, false)
	var swing_now := pl(0).swing_remaining
	await ticks(1)
	check(duel.freeze_left > 0.0 and swings[0] == 1 and is_equal_approx(swing_now, LilyDuelPlayer.SWING_TIME) and is_equal_approx(pl(0).swing_remaining, LilyDuelPlayer.SWING_TIME), "A swing pressed in the freeze starts but does not advance while frozen")
	await until(func(): return duel.freeze_left == 0.0, 30)
	await ticks(2)
	check(pl(0).swing_remaining < LilyDuelPlayer.SWING_TIME - 0.01 and pl(0).swing_remaining > 0.0, "...and runs normally once the freeze ends")
	pl(0).swung.disconnect(count_swing)

	# Take-out during a freeze.
	await settle_dusk()
	await face_off()
	duel.hit_player(pl(0), pl(1))
	duel.take_out(pl(1), "water")
	await until(func(): return duel.freeze_left == 0.0, 60)
	await ticks(1)
	check(pl(0).active and not pl(1).active and duel.out[1] and running(pl(1)), "A player taken out mid-freeze stays out; the other is released")
	await until(func(): return not duel.out[1], 120)
	await ticks(1)
	check(pl(1).active and pl(1).visible, "...and respawns active")

	# Rematch during a freeze.
	await settle_dusk()
	await face_off()
	duel.hit_player(pl(0), pl(1))
	duel.start_match()
	check(duel.freeze_left == 0.0 and duel.phase == "countdown", "A rematch cancels the freeze")
	await until(func(): return duel.phase == "dusk", 120)
	await ticks(3)
	check(pl(0).active and pl(1).active, "...and both players are active once the new match starts")

	# Match end during a freeze.
	await settle_dusk()
	await face_off()
	duel.hit_player(pl(0), pl(1))
	duel.scores = [2, 0]
	duel.end_match(0, false)
	await ticks(10)
	check(duel.phase == "over" and duel.freeze_left == 0.0 and not pl(0).active and not pl(1).active, "Match end during a freeze leaves players inactive and no freeze pending")
	duel.start_match()
	await until(func(): return duel.phase == "dusk", 120)
	await ticks(3)
	check(pl(0).active and pl(1).active, "...and the next match plays normally")

	# Sudden death: the visual water comes back down to (nearly) the level the rule counts.
	duel.arena.set_water_level(0.30)
	for i in 400:
		duel.arena.animate(0.016)
	check(duel.arena.pads[3].ripple.position.y > 0.30, "Setup: raised water, raised rings")
	duel.enter_sudden_death()
	await process_frame
	await process_frame
	check(duel.arena.water_level_target <= 0.12 + 0.0001, "Sudden death aims the visual water at %.2f or lower" % duel.arena.water_level_target)
	for i in 400:
		duel.arena.animate(0.016)
	check(duel.arena.water_level <= 0.12 + 0.0001 and duel.arena.pads[3].ripple.position.y <= 0.12 + LilyDuelPad.RING_OFFSET + 0.0001, "...and the water and pad rings settle there (%.3f)" % duel.arena.water_level)
	check(duel.arena.pads[3].ripple.position.y > duel.arena.water_level, "...with the rings still above the surface")

	# --- steady state ------------------------------------------------------------------------------------
	duel.hit_stop_seconds = 0.07
	duel.max_loose = 0
	duel.dusk_seconds = 60.0
	duel.start_match()
	await ticks(120)
	var nodes_early := count_nodes(duel)
	await ticks(780)
	var nodes_late := count_nodes(duel)
	check(nodes_early == nodes_late, "An idle dusk creates no nodes (%d at frame 120, %d at frame 900)" % [nodes_early, nodes_late])

	# Fireflies spawning and being collected leave no nodes behind.
	duel.max_loose = 7
	duel.spawn_interval = 0.1
	await ticks(150)
	var spawned := duel.loose_fireflies.size()
	var peak_nodes := count_nodes(duel)
	check(spawned >= 3 and peak_nodes > nodes_late, "Setup: fireflies spawn (%d loose)" % spawned)
	duel.max_loose = 0
	var gathered := 0
	while not duel.loose_fireflies.is_empty() and gathered < 20:
		var fly := duel.loose_fireflies[0]
		pl(0).global_position = fly.global_position - Vector3.UP * 0.9
		duel.collect_fireflies(pl(0))
		gathered += 1
	pl(0).set_carried(0)
	await ticks(150)
	check(duel.loose_fireflies.is_empty() and gathered == spawned, "...and all of them can be collected")
	check(count_nodes(duel) == nodes_late, "Spawning and collecting fireflies returns the node count to its baseline (%d vs %d)" % [count_nodes(duel), nodes_late])

	# --- freeing mid-freeze --------------------------------------------------------------------------------
	var other := make_duel()
	other.max_loose = 0
	other.start_match()
	await until(func(): return other.phase == "dusk")
	await ticks(3)
	other.players[0].respawn(Vector3(-0.75, SURFACE + 0.08, 0), Vector3.RIGHT)
	other.players[1].respawn(Vector3(0.75, SURFACE + 0.08, 0), Vector3.LEFT)
	await ticks(4)
	other.hit_player(other.players[0], other.players[1])
	check(other.freeze_left > 0.0, "Setup: a freeze is running")
	other.free()
	await ticks(3)
	check(not is_instance_valid(other), "Freeing the duel mid-freeze works")
	duel.free()
	await ticks(3)
	await process_frame
	check(root.get_child_count() == baseline, "Nothing is left in the tree afterwards (%d vs %d)" % [root.get_child_count(), baseline])

	print("DUEL FEEL RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
