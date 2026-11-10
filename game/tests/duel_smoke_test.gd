extends SceneTree

var duel: LilyDuel
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func until(condition: Callable, limit := 240) -> bool:
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
			detail = " phase=%s elapsed=%.2f scores=%s" % [duel.phase, duel.elapsed, str(duel.scores)]
		push_error("FAIL: " + message + detail)

func on_home(index: int) -> bool:
	return duel.arena.pad_at(duel.players[index].global_position) == duel.arena.home_pads[index]

func shorten() -> void:
	duel.countdown_seconds = 0.2
	duel.dusk_seconds = 2.0
	duel.midnight_seconds = 2.0
	duel.flood_seconds = 2.0
	duel.spawn_interval = 0.2
	duel.flood_spawn_interval = 0.2
	duel.flood_warning = 0.3
	duel.sudden_death_freeze = 0.2
	duel.respawn_delay = 0.2
	duel.flood_schedule = [
		{"at": 0.0, "ids": [12, 18]},
		{"at": 0.5, "ids": [1, 5, 9, 15, 3, 7]},
	]

func run() -> void:
	var baseline := root.get_child_count()
	duel = LilyDuel.new()
	root.add_child(duel)
	duel.begin(LilyAppearance.DEFAULTS.duplicate(), "Ava")
	shorten()
	duel.start_match()
	await frames(3)

	# Countdown.
	check(duel.phase == "countdown", "A new match starts in countdown")
	check(not duel.players[0].active and not duel.players[1].active, "Players are frozen during the countdown")
	check(on_home(0) and on_home(1), "Players wait on their own lantern pads")
	check(duel.hud.debug_snapshot()["countdown"] != "", "The HUD shows the countdown number")
	check(duel.hud.debug_snapshot()["names"] == ["Ava", "P2"], "HUD names are Ava and P2")
	check(duel.arena.camera.current, "The arena camera is current")

	# Dusk.
	await until(func(): return duel.phase == "dusk")
	await frames(6)
	check(duel.phase == "dusk" and duel.players[0].active and duel.players[1].active, "Dusk starts and both players are active")
	check(duel.players[0].is_on_floor() and duel.players[1].is_on_floor(), "Both players are grounded on their pads")
	check(await until(func(): return duel.loose_fireflies.size() > 0), "Fireflies spawn in dusk")
	check(duel.loose_fireflies.size() <= duel.max_loose, "Loose fireflies respect the cap")

	# Banking and hitting.
	duel.players[0].set_carried(3)
	await frames(3)
	check(duel.scores[0] == 3 and duel.players[0].carried == 0, "Landing on the home pad banks carried fireflies")
	var before := duel.loose_fireflies.size()
	duel.players[1].set_carried(5)
	duel.hit_player(duel.players[0], duel.players[1])
	check(duel.players[1].carried == 2 and duel.loose_fireflies.size() == before + 3, "A hit drops half the swarm as loose fireflies")
	check(duel.players[1].stun_remaining > 0.0, "A hit stuns the victim")
	duel.players[1].set_carried(0)
	await frames(30)

	# Real input drives only player 0.
	duel.players[0].respawn(duel.arena.spawn_point(0), Vector3.RIGHT)
	duel.players[1].respawn(duel.arena.spawn_point(1), Vector3.LEFT)
	await frames(6)
	var a0 := duel.players[0].global_position
	var a1 := duel.players[1].global_position
	Input.action_press("duel_p1_right")
	await frames(12)
	Input.action_release("duel_p1_right")
	check(duel.players[0].global_position.x > a0.x + 0.4, "duel_p1_right moves player 0")
	check(duel.players[1].global_position.distance_to(a1) < 0.05, "...and does not move player 1")

	# Pause freezes, resume continues.
	duel.players[0].respawn(duel.arena.spawn_point(0), Vector3.RIGHT)
	await frames(4)
	var t0 := duel.elapsed
	var pos0 := duel.players[0].global_position
	duel.toggle_pause()
	Input.action_press("duel_p1_right")
	await frames(20)
	Input.action_release("duel_p1_right")
	check(duel.paused and duel.elapsed == t0, "Pausing freezes the match clock")
	check(duel.players[0].global_position.distance_to(pos0) < 0.01, "Paused players do not move")
	check(not duel.players[0].active and duel.hud.debug_snapshot()["pause_visible"], "Paused players are inactive and the overlay is shown")
	duel.toggle_pause()
	await frames(10)
	check(not duel.paused and duel.elapsed > t0 and duel.players[0].active, "Resuming continues the clock and reactivates players")

	# Midnight.
	duel.set_elapsed(2.1)
	await frames(4)
	check(duel.phase == "midnight" and duel.arena.lotus_open, "Midnight opens the lotus")
	check(duel.queen.state == "perched", "The Queen is perched at midnight")
	check(duel.frogs.size() == 2 and duel.frogs[0].pad == duel.arena.pads[12] and duel.frogs[1].pad == duel.arena.pads[18], "Two frogs sit on pads 12 and 18")
	check(duel.frogs[0].state == "sitting" and duel.frogs[1].state == "sitting", "Both frogs are sitting")

	# Flood, with an unequal score.
	duel.scores[0] = 4
	duel.scores[1] = 1
	duel.set_elapsed(4.1)
	await frames(4)
	check(duel.phase == "flood", "The clock enters the flood")
	check(duel.arena.pads[12].state != "solid" and duel.arena.pads[18].state != "solid", "Pads 12 and 18 start sinking at flood +0")
	await frames(40)
	check(duel.frogs[0].pad != duel.arena.pads[12] or duel.frogs[0].state == "gone", "A frog leaves a sinking pad")
	await until(func(): return duel.phase == "over", 400)
	await frames(2)
	check(duel.phase == "over" and duel.winner == 0, "Higher score wins at the end of the flood")
	var snap := duel.hud.debug_snapshot()
	check(snap["result_visible"] and snap["result_title"] == "Ava wins!" and snap["result_detail"] == "4 – 1", "The HUD shows the result")
	check(not duel.players[0].active and not duel.players[1].active, "Players are inactive when the match is over")
	await until(func(): return duel.arena.pads[12].state == "gone" and duel.arena.pads[15].state == "gone", 400)
	var all_gone := true
	for pad_id in [12, 18, 1, 5, 9, 15, 3, 7]:
		all_gone = all_gone and duel.arena.pads[pad_id].state == "gone"
	check(all_gone, "Every scheduled pad is gone by the end of the flood")
	duel.toggle_pause()
	check(not duel.paused, "Pausing is ignored once the match is over")

	# Rematch resets everything.
	duel.start_match()
	await frames(3)
	var reset_ok := duel.phase == "countdown" and duel.scores == [0, 0] and duel.winner == -1 and duel.elapsed == 0.0
	check(reset_ok, "start_match resets phase, scores, winner and clock")
	var solid := true
	for pad in duel.arena.pads:
		solid = solid and pad.state == "solid"
	check(solid and not duel.arena.lotus_open, "start_match restores every pad and closes the lotus")
	check(duel.frogs.is_empty() and duel.loose_fireflies.is_empty() and duel.queen.state == "hidden", "start_match clears frogs, fireflies and the Queen")
	check(on_home(0) and on_home(1) and not duel.players[0].active, "Players are back on their home pads, frozen")
	check(not duel.hud.debug_snapshot()["result_visible"], "start_match hides the result panel")

	# Jumping from dusk straight into the flood still runs midnight setup.
	await until(func(): return duel.phase == "dusk")
	duel.set_elapsed(4.6)
	await frames(4)
	check(duel.phase == "flood" and duel.arena.lotus_open and duel.queen.state == "perched" and duel.frogs.size() == 2, "Skipping midnight still opens the lotus, places the Queen and wakes the frogs")
	check(duel.arena.pads[3].state != "solid" and duel.arena.pads[15].state != "solid", "...and applies every flood step that is already due")

	# Snapshot.
	var snapshot := duel.debug_snapshot()
	var parsed: Variant = JSON.parse_string(JSON.stringify(snapshot))
	check(parsed is Dictionary, "debug_snapshot round-trips through JSON")
	var keys_ok := true
	for key in ["mode", "phase", "elapsed", "time_left", "paused", "scores", "carried", "health", "poisoned", "winner", "queen", "players", "pads", "fireflies", "frogs", "hud"]:
		keys_ok = keys_ok and parsed is Dictionary and parsed.has(key)
	check(keys_ok, "debug_snapshot has every key in the spec")
	check(snapshot["mode"] == "duel" and snapshot["pads"].size() == 23 and snapshot["players"].size() == 2, "Snapshot has 23 pads and 2 players")
	check(snapshot["pads"][5]["kind"] == "yellow" and snapshot["pads"][0]["kind"] == "center", "Pad kinds are lowercase names")

	# Sudden death on a tie.
	duel.start_match()
	await until(func(): return duel.phase == "dusk")
	duel.set_elapsed(5.95)
	await until(func(): return duel.phase == "sudden_death", 120)
	await frames(2)
	check(duel.phase == "sudden_death", "Equal scores enter sudden death")
	var p0 := duel.players[0].global_position
	var p1 := duel.players[1].global_position
	check(absf(p0.x + 1.3) < 0.05 and absf(p1.x - 1.3) < 0.05, "Players start at x = -1.3 and +1.3")
	check(duel.arena.pad_at(p0) == duel.arena.center_pad and duel.arena.pad_at(p1) == duel.arena.center_pad, "Both players are on the centre pad")
	check(duel.frogs.is_empty() and duel.queen.state == "hidden" and duel.loose_fireflies.is_empty(), "Sudden death clears frogs, Queen and loose fireflies")
	await until(func(): return duel.players[0].active and duel.players[1].active, 120)
	check(duel.players[0].active and duel.players[1].active, "Players are released after the freeze")
	duel.take_out(duel.players[0], "water")
	duel.take_out(duel.players[0], "water")
	check(duel.phase == "over" and duel.winner == 1, "In sudden death the first player taken out loses")
	check(duel.hud.debug_snapshot()["result_title"] == "P2 wins!", "The result names the sudden-death winner")

	# Taking a player out in normal play respawns them.
	duel.start_match()
	await until(func(): return duel.phase == "dusk")
	await frames(6)
	duel.players[1].set_carried(2)
	duel.take_out(duel.players[1], "water")
	check(not duel.players[1].active and duel.players[1].carried == 0 and duel.loose_fireflies.size() >= 2, "Taken-out players drop their fireflies and go inactive")
	await frames(30)
	check(duel.players[1].active and duel.players[1].visible and on_home(1), "Taken-out players respawn on their home pad")

	# Freeing the duel mid-match leaves nothing behind.
	duel.free()
	await frames(3)
	check(root.get_child_count() == baseline, "Freeing the duel leaves nothing in the tree")

	print("DUEL SMOKE RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
