extends SceneTree

# Independent rules test for Midnight Pond. Every expectation is written from
# docs/MIDNIGHT_POND_SPEC.md section 6, not from what duel.gd happens to do. It drives real
# physics ticks and real key events, and only pokes state to set a scene up (positions, carried
# counts, the match clock).

const SURFACE := 0.60

var duel: LilyDuel
var passed := 0
var failures: Array[String] = []
var waited := 0
var swing_counts := [0, 0]
var impact_counts := [0, 0]
var normal_d15 := 0.0

func _initialize() -> void:
	run.call_deferred()

# --- helpers ------------------------------------------------------------------------------

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

# Runs physics ticks until the condition holds; `waited` is the number of ticks it took.
func until(condition: Callable, limit := 300) -> bool:
	waited = 0
	for i in limit:
		if condition.call():
			return true
		await physics_frame
		waited += 1
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

func release_all() -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_F, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_SLASH, KEY_ESCAPE, KEY_R]:
		key(code, false)

func pd(id: int) -> LilyDuelPad:
	return duel.arena.pads[id]

func pl(index: int) -> LilyDuelPlayer:
	return duel.players[index]

func surf(x: float, z: float) -> Vector3:
	return Vector3(x, SURFACE, z)

func stand(index: int, surface_point: Vector3, face := Vector3.RIGHT) -> void:
	duel.players[index].respawn(surface_point + Vector3(0, 0.08, 0), face)

func on_pad(index: int, pad_id: int, offset := Vector3.ZERO, face := Vector3.RIGHT) -> void:
	stand(index, pd(pad_id).surface_center() + offset, face)

func frog_on(pad_id: int) -> LilyDuelFrog:
	for frog in duel.frogs:
		if is_instance_valid(frog) and frog.pad == pd(pad_id):
			return frog
	return null

func standable_ids() -> Array:
	var ids := []
	for p in duel.arena.pads:
		if p.is_standable():
			ids.append(p.pad_id)
	return ids

func ids_except(gone: Array) -> Array:
	var ids := []
	for p in duel.arena.pads:
		if not gone.has(p.pad_id):
			ids.append(p.pad_id)
	return ids

# Spec section 2: inner ring id = 1 + angle / 45, outer ring id = 9 + angle / 30.
func outer_ids(angles: Array) -> Array:
	var ids := []
	for a in angles:
		ids.append(9 + int(a) / 30)
	return ids

func inner_ids(angles: Array) -> Array:
	var ids := []
	for a in angles:
		ids.append(1 + int(a) / 45)
	return ids

func over_standable_non_home(point: Vector3) -> bool:
	var p := duel.arena.pad_at(point)
	return p != null and p.kind != LilyDuelPad.Kind.HOME

func snap_hud() -> Dictionary:
	return duel.hud.debug_snapshot()

# Fresh match on the same duel, with the clock past the countdown and both players active.
func reset(spawning := false) -> void:
	duel.countdown_seconds = 0.1
	duel.spawn_interval = 1.6 if spawning else 1.0e9
	duel.flood_spawn_interval = 1.0 if spawning else 1.0e9
	duel.yellow_roll_override = -1
	release_all()
	duel.start_match()
	duel.rng.seed = 20260101
	await until(func(): return duel.phase == "dusk" and duel.players[0].active and duel.players[1].active, 120)
	await ticks(8)

func to_midnight() -> void:
	duel.set_elapsed(60.1)
	await ticks(4)

# Swing with the real key, wait for the bat impact, and report what the victim went through.
func do_hit(attacker_index: int, code: Key, track := 0) -> Dictionary:
	var attacker := duel.players[attacker_index]
	var victim := duel.players[1 - attacker_index]
	var carried_before := victim.carried
	var loose_before := duel.loose_fireflies.size()
	key(code)
	await ticks(1)
	key(code, false)
	var hit: bool = await until(func(): return victim.invulnerable_remaining > 0.0, 60)
	var result := {"hit": hit}
	if not hit:
		return result
	var origin := victim.global_position
	var gap_before := victim.global_position.distance_to(attacker.global_position)
	var aim := Vector3(attacker.attack_direction.x, 0, attacker.attack_direction.z).normalized()
	result["carried_before"] = carried_before
	result["carried_after"] = victim.carried
	result["loose_delta"] = duel.loose_fireflies.size() - loose_before
	var dropped_ok := true
	for fly in duel.loose_fireflies.slice(loose_before):
		dropped_ok = dropped_ok and over_standable_non_home(fly.global_position)
	result["dropped_ok"] = dropped_ok
	var pushed := 0.0
	var growth := 0.0
	var d15 := 0.0
	for i in track:
		await physics_frame
		var delta := victim.global_position - origin
		pushed = maxf(pushed, delta.dot(aim))
		growth = maxf(growth, victim.global_position.distance_to(attacker.global_position) - gap_before)
		if i == 14:
			d15 = Vector2(delta.x, delta.z).length()
	result["pushed"] = pushed
	result["growth"] = growth
	result["d15"] = d15
	return result

# P1 on its own home pad, P2 one and a half metres towards the centre.
func bat_setup(victim_carried: int) -> void:
	await reset()
	stand(0, surf(-16.0, 0.0), Vector3.RIGHT)
	stand(1, surf(-14.5, 0.0), Vector3.LEFT)
	pl(1).set_carried(victim_carried)
	await ticks(6)

# --- scenarios -------------------------------------------------------------------------------

func test_collecting() -> void:
	await reset()
	stand(0, surf(-0.8, 0.0))
	var fly := duel.spawn_firefly(pd(0), Vector3(2.0, SURFACE + 0.9, 0.0))
	await ticks(4)
	check(fly != null and duel.loose_fireflies.has(fly), "A spawned firefly is loose")
	check(pl(0).carried == 0, "Standing 2.8 m away does not collect it")
	key(KEY_D)
	var got: bool = await until(func(): return duel.players[0].carried == 1, 120)
	key(KEY_D, false)
	await ticks(10)
	check(got and pl(0).carried == 1, "Walking to a firefly picks it up: carried goes up by one")
	check(duel.loose_fireflies.is_empty() and not is_instance_valid(fly), "The collected firefly leaves the loose list")
	check(duel.scores == [0, 0], "Collecting does not change the score")
	check(pl(1).carried == 0, "The other player carries nothing")

func test_banking() -> void:
	await reset()
	pl(0).set_carried(3)
	stand(0, pd(22).surface_center() + Vector3(0, 1.0, 0))
	await ticks(40)
	check(duel.scores == [0, 0] and pl(0).carried == 3, "Landing on the opponent's home pad banks nothing")
	stand(0, pd(21).surface_center() + Vector3(0, 1.0, 0))
	var banked: bool = await until(func(): return duel.scores[0] > 0, 90)
	check(banked and duel.scores == [3, 0] and pl(0).carried == 0, "Landing on your own home pad banks everything (3 -> score 3, carried 0)")
	await ticks(3)
	check(snap_hud()["banked"] == [3, 0] and snap_hud()["carried"] == [0, 0], "The HUD shows the banked score")
	pl(1).set_carried(2)
	await ticks(4)
	check(duel.scores == [3, 2], "Without the Queen, a bank of 2 scores 2")
	# With the Queen the bank is doubled.
	await to_midnight()
	stand(0, surf(0.0, 0.0))
	var took: bool = await until(func(): return duel.players[0].has_queen, 90)
	check(took, "Standing under the perch takes the Queen")
	pl(0).set_carried(2)
	stand(0, pd(21).surface_center() + Vector3(0, 1.0, 0))
	await until(func(): return duel.scores[0] > 3, 90)
	check(duel.scores[0] == 3 + 4 and pl(0).carried == 0, "With the Queen a bank of 2 scores 4")

func test_spawner() -> void:
	await reset(true)
	var dead := []
	for p in duel.arena.pads:
		if p.kind == LilyDuelPad.Kind.MIDDLE or (p.kind == LilyDuelPad.Kind.OUTER and p.pad_id <= 14):
			p.trigger_sink(0.0, 1.0e6)
			dead.append(p.pad_id)
	await ticks(70)
	check(duel.loose_fireflies.is_empty(), "No firefly appears before the first 1.6 s interval")
	await ticks(125)
	check(duel.loose_fireflies.size() == 2, "One firefly every 1.6 s: two after about 3.4 s (got %d)" % duel.loose_fireflies.size())
	duel.spawn_interval = 0.1
	var highest := 0
	var clean := true
	for i in 240:
		await physics_frame
		highest = maxi(highest, duel.loose_fireflies.size())
		for fly in duel.loose_fireflies:
			var p := duel.arena.pad_at(fly.global_position)
			clean = clean and p != null and p.kind != LilyDuelPad.Kind.HOME and not dead.has(p.pad_id)
	check(highest == duel.max_loose and duel.max_loose == 7, "The spawner fills up to 7 loose fireflies and never more (peak %d)" % highest)
	check(clean, "Spawned fireflies are never on a home pad or a pad that is not standable")
	var distinct := {}
	for fly in duel.loose_fireflies:
		distinct[duel.arena.pad_at(fly.global_position).pad_id] = true
	check(distinct.size() == duel.loose_fireflies.size(), "At most one spawned firefly per pad")
	# Flood spawns faster (1.0 s).
	await reset(true)
	duel.set_elapsed(120.05)
	await ticks(150)
	check(duel.phase == "flood" and duel.loose_fireflies.size() == 2, "During the flood one firefly every 1.0 s: two after 2.5 s (got %d)" % duel.loose_fireflies.size())

func test_spawner_weights() -> void:
	await reset(true)
	duel.spawn_interval = 0.01
	var kinds := {"middle": 0, "yellow": 0, "outer": 0, "center": 0, "home": 0}
	var total := 0
	for i in 300:
		await physics_frame
		for fly in duel.loose_fireflies.duplicate():
			var p := duel.arena.pad_at(fly.global_position)
			if p != null:
				kinds[String(LilyDuelPad.Kind.keys()[p.kind]).to_lower()] += 1
				total += 1
			duel.loose_fireflies.erase(fly)
			fly.free()
	check(total > 200, "The spawner produced enough samples (%d)" % total)
	var middle := float(kinds["middle"]) / maxf(total, 1)
	var outer := float(kinds["outer"]) / maxf(total, 1)
	var yellow := float(kinds["yellow"]) / maxf(total, 1)
	check(kinds["home"] == 0, "No firefly ever spawns on a home pad")
	# Weights: MIDDLE x3 (6 pads), YELLOW x2 (2), OUTER x1 (12), CENTER x1 -> 18/4/12/1 of 35.
	check(middle > 0.40 and middle < 0.63, "Middle pads get about 51%% of spawns (%.2f)" % middle)
	check(outer > 0.22 and outer < 0.45, "Outer pads get about 34%% of spawns (%.2f)" % outer)
	check(yellow > 0.04 and yellow < 0.20, "Yellow pads get about 11%% of spawns (%.2f)" % yellow)

func test_bat() -> void:
	# Hit with 5 carried: keeps 2, 3 loose.
	await bat_setup(5)
	var r: Dictionary = await do_hit(0, KEY_F, 30)
	check(r["hit"], "A real swing facing the other player within 1.5 m hits")
	if r["hit"]:
		check(r["carried_after"] == 2, "Carried 5 keeps 2 after a hit (got %d)" % r["carried_after"])
		check(r["loose_delta"] == 3, "Carried 5 puts 3 loose fireflies on the pond (got %d)" % r["loose_delta"])
		check(r["dropped_ok"], "Dropped fireflies are over standable non-home pads")
		check(r["pushed"] > 2.0 and r["growth"] > 2.0, "The victim is pushed away from the attacker by more than 2 m (%.2f / %.2f)" % [r["pushed"], r["growth"]])
		normal_d15 = r["d15"]
	# Carried 1: keeps 0, 1 loose.
	await bat_setup(1)
	r = await do_hit(0, KEY_F)
	check(r["hit"] and r["carried_after"] == 0 and r["loose_delta"] == 1, "Carried 1 drops its one firefly (ceil(1/2) = 1)")
	# Carried 0: nothing to drop, but still pushed and stunned.
	await bat_setup(0)
	r = await do_hit(0, KEY_F)
	check(r["hit"] and r["loose_delta"] == 0 and pl(1).stun_remaining > 0.0, "Carried 0 drops nothing but the victim is still stunned")
	# Invulnerability: a second swing right after a hit does nothing; once it ends, hits land again.
	await bat_setup(5)
	var victim := pl(1)
	var attacker := pl(0)
	r = await do_hit(0, KEY_F)
	victim.global_position = surf(-14.5, 0.0) + Vector3(0, 0.08, 0)
	victim.velocity = Vector3.ZERO
	var spot := victim.global_position
	var carried_mid := victim.carried
	var loose_mid := duel.loose_fireflies.size()
	await until(func(): return attacker.swing_remaining <= 0.0, 60)
	check(victim.invulnerable_remaining > 0.2, "Setup: the victim is still invulnerable for the second swing (%.2f s left)" % victim.invulnerable_remaining)
	var swings_before: int = swing_counts[0]
	var impacts_before: int = impact_counts[0]
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	await ticks(16)
	check(swing_counts[0] == swings_before + 1 and impact_counts[0] == impacts_before + 1, "The second swing really happened and reached its impact")
	check(victim.carried == carried_mid and duel.loose_fireflies.size() == loose_mid, "A swing during invulnerability drops nothing")
	check(victim.global_position.distance_to(spot) < 0.3 and absf(victim.velocity.x) < 1.0, "A swing during invulnerability does not push")
	await until(func(): return victim.invulnerable_remaining <= 0.0 and attacker.swing_remaining <= 0.0, 120)
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	await until(func(): return victim.invulnerable_remaining > 0.0, 60)
	check(victim.carried == 1 and duel.loose_fireflies.size() == loose_mid + 1, "After invulnerability ends the same swing hits again (carried 2 -> 1)")
	# Out of reach (3 m).
	await reset()
	stand(0, surf(-2.0, 0.0), Vector3.RIGHT)
	stand(1, surf(1.0, 0.0), Vector3.LEFT)
	pl(1).set_carried(4)
	await ticks(6)
	var impacts: int = impact_counts[0]
	var spot2 := pl(1).global_position
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	await ticks(24)
	check(impact_counts[0] == impacts + 1, "The 3 m swing reached its impact")
	check(pl(1).carried == 4 and pl(1).invulnerable_remaining == 0.0 and pl(1).stun_remaining == 0.0 and pl(1).global_position.distance_to(spot2) < 0.05 and duel.loose_fireflies.is_empty(), "A swing from 3 m away does nothing")
	# Facing away at 1.5 m.
	await reset()
	stand(0, surf(-1.0, 0.0), Vector3.LEFT)
	stand(1, surf(0.5, 0.0), Vector3.LEFT)
	pl(1).set_carried(4)
	await ticks(6)
	impacts = impact_counts[0]
	spot2 = pl(1).global_position
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	await ticks(24)
	check(impact_counts[0] == impacts + 1, "The facing-away swing reached its impact")
	check(pl(1).carried == 4 and pl(1).invulnerable_remaining == 0.0 and pl(1).global_position.distance_to(spot2) < 0.05 and duel.loose_fireflies.is_empty(), "A swing facing away from the victim does nothing")
	# P2's bat works the same way on P1.
	await reset()
	stand(1, surf(-16.0, 0.0) * Vector3(-1, 1, 1), Vector3.LEFT)
	stand(0, surf(14.5, 0.0), Vector3.RIGHT)
	pl(0).set_carried(2)
	await ticks(6)
	r = await do_hit(1, KEY_SLASH)
	check(r["hit"] and r["carried_after"] == 1 and r["loose_delta"] == 1, "Player 2's bat hits player 1 the same way")

func test_queen() -> void:
	await reset()
	duel.yellow_roll_override = 0
	check(duel.queen.state == "hidden" and snap_hud()["queen"] == -1, "The Queen is hidden before midnight")
	await to_midnight()
	check(duel.phase == "midnight" and duel.queen.state == "perched", "At midnight the Queen is perched")
	check(duel.queen.global_position.distance_to(Vector3(0, 2.3, 0)) < 0.6, "The perch is above the centre pad")
	check(duel.queen.holder == null and not pl(0).has_queen and not pl(1).has_queen, "Nobody holds her yet")
	stand(0, surf(-2.0, 0.0))
	await ticks(6)
	check(not pl(0).has_queen, "2 m away from the perch is too far to take her")
	key(KEY_D)
	var took: bool = await until(func(): return duel.players[0].has_queen, 90)
	key(KEY_D, false)
	await ticks(4)
	check(took and duel.queen.state == "held" and duel.queen.holder == pl(0), "Walking under the perch takes the Queen")
	check(is_equal_approx(pl(0).speed_scale, 0.85), "The holder moves at 0.85 speed")
	check(snap_hud()["queen"] == 0 and duel.debug_snapshot()["queen"]["holder"] == 0, "The HUD and snapshot name player 1 as holder")
	# Bat transfer.
	stand(0, surf(-1.5, 0.0), Vector3.RIGHT)
	stand(1, surf(0.0, 0.0), Vector3.LEFT)
	await ticks(6)
	var r: Dictionary = await do_hit(1, KEY_SLASH)
	await ticks(3)
	check(r["hit"], "Player 2 bats the Queen holder")
	check(pl(1).has_queen and not pl(0).has_queen and duel.queen.holder == pl(1), "A bat hit transfers the Queen to the attacker")
	check(is_equal_approx(pl(0).speed_scale, 1.0) and is_equal_approx(pl(1).speed_scale, 0.85), "The old holder's speed returns to 1.0, the new holder's is 0.85")
	check(snap_hud()["queen"] == 1, "The HUD now shows player 2 as holder")
	# Holder taken out: she returns to the perch.
	stand(1, Vector3(3.5, SURFACE, 0.0))
	var out: bool = await until(func(): return not duel.players[1].active, 120)
	check(out, "The holder dropped in the gap is taken out")
	await ticks(2)
	check(duel.queen.holder == null and not pl(1).has_queen and duel.queen.state in ["returning", "perched"], "The Queen leaves a holder who is taken out")
	check(snap_hud()["queen"] == -1 and duel.debug_snapshot()["queen"]["holder"] == -1, "Nobody is shown as holder")
	var home: bool = await until(func(): return duel.queen.state == "perched", 150)
	check(home and duel.queen.global_position.distance_to(Vector3(0, 2.3, 0)) < 0.6, "She is back on her perch within about a second")
	await until(func(): return duel.players[1].active, 120)
	check(is_equal_approx(pl(1).speed_scale, 1.0) and not pl(1).has_queen, "The respawned player is back to normal speed")

func test_middle_ring() -> void:
	await reset()
	var mid := pd(3)
	check(mid.kind == LilyDuelPad.Kind.MIDDLE, "Pad 3 is a middle pad")
	on_pad(0, 3)
	var warned: bool = await until(func(): return mid.state == "warning", 60)
	check(warned and mid.is_standable(), "Standing on a middle pad starts the warning; it is still standable")
	await ticks(30)
	check(mid.is_standable() and pl(0).active, "Half a second in, the pad still holds")
	var dropped: bool = await until(func(): return not mid.is_standable(), 90)
	var warn_ticks := 30 + waited
	check(dropped and warn_ticks >= 45 and warn_ticks <= 62, "The pad stops being standable about 0.9 s after the warning started (%d ticks in)" % warn_ticks)
	var fell: bool = await until(func(): return not duel.players[0].active, 120)
	check(fell, "The player standing on it falls into the water")
	await ticks(60)
	var back_early := mid.is_standable()
	# 4 s of down time, plus the sinking and rising animation, then solid again.
	var solid: bool = await until(func(): return mid.state == "solid", 400)
	var since_drop := 60 + waited
	check(not back_early and solid and mid.is_standable(), "The pad is not standable again after 1 s")
	check(since_drop >= 240 and since_drop <= 350, "It is solid again 4 to 5.8 s after it dropped (%.2f s)" % (since_drop / 60.0))
	# Other kinds never sink from being stood on.
	await reset()
	on_pad(0, 0)
	on_pad(1, 11)
	await ticks(100)
	check(pd(0).state == "solid" and pd(11).state == "solid", "CENTER and OUTER pads do not sink when stood on")
	stand(0, pd(21).surface_center())
	stand(1, pd(22).surface_center())
	await ticks(100)
	check(pd(21).state == "solid" and pd(22).state == "solid" and pl(0).active and pl(1).active, "HOME pads do not sink when stood on")
	check(pd(0).state == "solid" and pd(11).state == "solid", "...and the others are still solid")

func test_yellow() -> void:
	# Forced sink.
	await reset()
	duel.yellow_roll_override = 1
	var west := pd(5)
	check(west.kind == LilyDuelPad.Kind.YELLOW, "Pad 5 is yellow")
	on_pad(0, 5)
	var sank: bool = await until(func(): return not west.is_standable(), 40)
	check(sank and waited <= 10, "A forced-sink yellow pad sinks at once when landed on (%d ticks)" % waited)
	check(pl(0).falling_through, "The player on it is dropped through")
	var out: bool = await until(func(): return not duel.players[0].active, 120)
	check(out, "...and ends up in the water, taken out")
	var back: bool = await until(func(): return duel.players[0].active, 150)
	check(back and duel.arena.pad_at(pl(0).global_position) == pd(21) and pl(0).health == 100.0, "...then respawns on their home pad at full health")
	# Forced hold, then spent, then sink, then fresh.
	await reset()
	duel.yellow_roll_override = 0
	var east := pd(1)
	on_pad(0, 1)
	await ticks(60)
	check(east.state == "solid" and east.is_standable() and pl(0).active and pl(0).is_on_floor(), "A forced-hold yellow pad stays solid while the player stands on it")
	check(not east.spent, "...and is not spent while they are still on it")
	on_pad(0, 0)
	await ticks(36)
	check(east.spent and east.is_standable(), "After the player leaves, the pad is spent (and still solid)")
	check(duel.yellow_spent_by.get(1, -1) == 0, "...and it remembers it was spent by player 1")
	on_pad(1, 1)
	sank = await until(func(): return not east.is_standable(), 40)
	check(sank, "The next player to land on a spent pad sinks it, whatever the roll")
	out = await until(func(): return not duel.players[1].active, 120)
	check(out, "...and they are taken out")
	var rose: bool = await until(func(): return east.state == "solid", 600)
	check(rose and not east.spent, "When the pad rises it is fresh (spent is false)")
	on_pad(0, 1)
	await ticks(60)
	check(east.is_standable() and pl(0).active, "A fresh pad rolls again (hold) instead of sinking at once")

func test_yellow_rolls() -> void:
	await reset()
	duel.yellow_roll_override = -1
	duel.rng = RandomNumberGenerator.new()
	duel.rng.seed = 777
	var p := pl(0)
	var target := pd(5)
	var sinks := 0
	for i in 200:
		target.reset_pad()
		duel.yellow_holds.clear()
		p.falling_through = false
		duel.step_on_yellow(p, target)
		if target.state != "solid":
			sinks += 1
	target.reset_pad()
	duel.yellow_holds.clear()
	stand(0, pd(21).surface_center())
	duel.arena.clear_particles()
	check(sinks >= 70 and sinks <= 130, "200 fresh yellow rolls sink between 35%% and 65%% of the time (%d)" % sinks)

func test_water() -> void:
	await reset()
	pl(1).set_carried(4)
	pl(1).health = 55.0
	stand(1, Vector3(3.5, SURFACE, 0.0))
	var out: bool = await until(func(): return not duel.players[1].active, 120)
	check(out, "A player dropped into the gap is taken out")
	await ticks(1)
	check(pl(1).carried == 0 and duel.loose_fireflies.size() == 4, "All 4 carried fireflies become loose (got %d)" % duel.loose_fireflies.size())
	var ok := true
	for fly in duel.loose_fireflies:
		ok = ok and over_standable_non_home(fly.global_position)
	check(ok, "...on standable non-home pads")
	var back: bool = await until(func(): return duel.players[1].active, 150)
	var delay := waited + 1
	check(back and delay >= 66 and delay <= 82, "They are active again about 1.2 s later (%.2f s)" % (delay / 60.0))
	await ticks(4)
	check(duel.arena.pad_at(pl(1).global_position) == pd(22) and pl(1).health == 100.0 and pl(1).carried == 0 and pl(1).visible, "...on their own home pad, at 100 health")

func test_frogs() -> void:
	await reset()
	await to_midnight()
	var f12 := frog_on(12)
	var f18 := frog_on(18)
	check(duel.frogs.size() == 2 and f12 != null and f18 != null, "At midnight frogs sit on pads 12 and 18")
	check(f12 != null and f18 != null and f12.state == "sitting" and f18.state == "sitting", "Both frogs are sitting")
	# Poison.
	on_pad(0, 12)
	on_pad(1, 13)
	var poisoned: bool = await until(func(): return duel.players[0].poisoned, 60)
	check(poisoned, "Standing on a frog's pad poisons the player")
	check(not pl(1).poisoned, "...but not a player on a frog-free pad")
	var h0 := pl(0).health
	await ticks(60)
	var drained := h0 - pl(0).health
	check(absf(drained - 15.0) <= 3.0, "Poison costs about 15 health per second (%.1f)" % drained)
	pl(0).health = 8.0
	var out: bool = await until(func(): return not duel.players[0].active, 120)
	check(out and not pl(0).poisoned, "At 0 health the poisoned player is taken out (and poison is cleared)")
	var back: bool = await until(func(): return duel.players[0].active, 150)
	check(back and pl(0).health == 100.0 and not pl(0).poisoned and duel.arena.pad_at(pl(0).global_position) == pd(21), "...and respawns healthy on their home pad")
	# Batting a frog with no opponent in the way: a legal pad, the batter is cured.
	await reset()
	await to_midnight()
	f18 = frog_on(18)
	stand(0, surf(0.85, -12.05), Vector3(-1, 0, 1))
	await until(func(): return duel.players[0].poisoned, 60)
	pl(0).health = 40.0
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	var launched: bool = await until(func(): return f18.state != "sitting", 60)
	check(launched, "A real swing within reach, facing the frog, launches it")
	if launched:
		var target := f18.pad as LilyDuelPad
		check(target != pd(18) and target != pd(12), "The frog leaves its pad and does not take the other frog's")
		check(target.kind != LilyDuelPad.Kind.HOME and target.kind != LilyDuelPad.Kind.CENTER and target.is_standable(), "It heads for a standable pad that is not HOME or CENTER")
		check(not pl(0).poisoned and pl(0).health == 100.0, "The batter is cured and back to 100 health")
		await until(func(): return f18.state == "sitting", 150)
		check(f18.state == "sitting" and f18.pad.is_standable() and f18.pad != pd(12), "It lands on a standable pad with no other frog")
	# Batting a frog with the opponent standing on a legal pad in the cone, within 10 m.
	await reset()
	await to_midnight()
	var f12b := frog_on(12)
	stand(0, surf(-0.85, 12.05), Vector3(1, 0, -1))
	on_pad(1, 11)
	await until(func(): return duel.players[0].poisoned, 60)
	pl(0).health = 40.0
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	launched = await until(func(): return f12b.state != "sitting", 60)
	check(launched and f12b.pad == pd(11), "The frog is aimed at the pad the opponent stands on (pad 11), not the nearest pad in the cone")
	var landed: bool = await until(func(): return f12b.state == "sitting", 150)
	await ticks(3)
	check(landed and pl(1).poisoned, "The opponent is poisoned when the frog lands")
	check(not pl(0).poisoned, "The batter stays cured")
	# A frog whose pad sinks leaves it.
	await reset()
	await to_midnight()
	var herd := duel.frogs.duplicate()
	duel.set_elapsed(120.05)
	await ticks(170)
	var fine := herd.size() == 2
	var frog_states := []
	for frog in herd:
		var target := frog.pad as LilyDuelPad
		# Legal pads exist all over the pond, so a frog must not be dismissed: it sits on, or is
		# flying to, a standable pad that is not HOME, not CENTER and not one of the sunk pads.
		var ok: bool = is_instance_valid(frog) and frog.state in ["sitting", "flying"] and target != null and target.is_standable() \
				and target != pd(12) and target != pd(18) and target.kind != LilyDuelPad.Kind.HOME and target.kind != LilyDuelPad.Kind.CENTER
		fine = fine and ok
		describe_frog(frog_states, frog)
	check(fine, "A frog whose pad sinks hops to a standable legal pad; it is not dismissed while one exists (%s)" % str(frog_states))

func describe_frog(into: Array, frog: LilyDuelFrog) -> void:
	into.append("%s@%d" % [frog.state, (frog.pad as LilyDuelPad).pad_id if frog.pad != null else -1])

func test_flood() -> void:
	await reset()
	await to_midnight()
	for id in [12, 13, 10, 20, 3, 2, 1, 5, 9, 15, 14, 18, 11, 17]:
		duel.spawn_firefly(pd(id))
	duel.set_elapsed(119.9)
	await ticks(3)
	check(duel.phase == "midnight" and standable_ids() == ids_except([]), "Before the flood all 23 pads are standable")
	var steps := [
		[0.0, [12, 18]],
		[8.0, [11, 13, 17, 19]],
		[20.0, [3, 7]],
		[30.0, [2, 4, 6, 8]],
		[31.0, [10, 14, 16, 20]],
		[52.0, [1, 5, 9, 15]],
	]
	var gone := []
	for step in steps:
		if step[0] == 30.0:
			# Just before the 30 s step a route home with no gamble in it still exists, on both sides.
			duel.set_elapsed(120.0 + 29.5)
			await ticks(12)
			var before := standable_ids()
			var route := [2, 8, 10, 20, 9, 4, 6, 14, 16, 15]
			var route_ok := true
			for id in route:
				route_ok = route_ok and before.has(id)
			check(route_ok and before == ids_except(gone), "Just before +30 s a gamble-free route home is standable: pads 2/8, 10/20, 9 and 4/6, 14/16, 15 (standable: %s)" % str(before))
			check(not snap_hud()["toast"].contains("Last way home"), "...and the 'Last way home' toast has not been shown yet")
		gone.append_array(step[1])
		duel.set_elapsed(120.0 + step[0])
		await ticks(105)
		var now := standable_ids()
		var want := ids_except(gone)
		check(now == want, "Flood +%d s: exactly pads %s are gone (standable: %s)" % [int(step[0]), str(gone), str(now)])
		var under := true
		for fly in duel.loose_fireflies:
			under = under and duel.arena.pad_at(fly.global_position) != null
		check(under and not duel.loose_fireflies.is_empty(), "Flood +%d s: no loose firefly floats over a pad that is gone" % int(step[0]))
		if step[0] == 30.0:
			# The 31 s step lands one second later: its pads were still only warning at this point.
			check(snap_hud()["toast"].contains("Last way home") and duel.last_way_at == 31.0, "The 'Last way home' toast is shown at +31 s")
		if step[0] == 31.0:
			check(now == [0, 1, 5, 9, 15, 21, 22], "After +31 s only the centre, the homes, the yellow pads and the bridge pads remain")
		if step[0] == 52.0:
			check(now == [0, 21, 22], "After +52 s only the centre and the two homes remain")
	check(duel.phase == "flood", "The match is still in the flood")
	await ticks(90)
	var clear := true
	for frog in duel.frogs:
		clear = clear and (frog.state == "gone" or frog.pad.is_standable())
	check(clear, "No frog sits on a pad that is gone")

func test_end() -> void:
	await reset()
	await to_midnight()
	duel.spawn_firefly(pd(13))
	duel.spawn_firefly(pd(14))
	pl(0).set_carried(4)
	pl(1).set_carried(1)
	await ticks(5)
	check(duel.scores == [4, 1], "Setup: score is 4 - 1")
	pd(3).trigger_sink(0.0, 1.0e6)
	pd(2).trigger_sink(0.0, -1.0)
	pl(0).set_queen(false)
	duel.set_elapsed(179.99)
	var over: bool = await until(func(): return duel.phase == "over", 120)
	await ticks(3)
	var snap := snap_hud()
	check(over and duel.winner == 0, "The higher score wins at the end of the flood")
	check(snap["result_visible"] and snap["result_title"].contains("Ava"), "The result overlay is shown with the winner's name in the title (%s)" % snap["result_title"])
	check(not pl(0).active and not pl(1).active, "Both players are inactive when the match is over")
	# Rematch.
	duel.start_match()
	await ticks(3)
	var solid := true
	for p in duel.arena.pads:
		solid = solid and p.state == "solid" and p.is_standable() and not p.spent
	check(duel.scores == [0, 0] and pl(0).carried == 0 and pl(1).carried == 0 and duel.winner == -1, "Rematch: scores, carried and winner are cleared")
	check(duel.phase == "countdown" and duel.elapsed == 0.0, "Rematch: back to the countdown")
	check(solid and duel.arena.pads.size() == 23, "Rematch: all 23 pads are solid again")
	check(duel.frogs.is_empty() and duel.loose_fireflies.is_empty() and duel.queen.state == "hidden", "Rematch: no frogs, no loose fireflies, Queen hidden")
	check(not snap_hud()["result_visible"], "Rematch: the result overlay is hidden")
	# Player 2 can win too.
	await reset()
	pl(1).set_carried(2)
	await ticks(4)
	duel.set_elapsed(179.99)
	await until(func(): return duel.phase == "over", 120)
	check(duel.winner == 1 and snap_hud()["result_title"] == "P2 wins!", "Player 2 wins with the higher score")

func test_sudden_death() -> void:
	await reset()
	await to_midnight()
	duel.spawn_firefly(pd(13))
	duel.spawn_firefly(pd(14))
	stand(0, surf(-1.0, 0.0))
	stand(1, surf(1.0, 0.0))
	await ticks(6)
	pl(0).set_carried(3)
	pl(1).set_carried(2)
	duel.set_elapsed(179.99)
	var entered: bool = await until(func(): return duel.phase == "sudden_death", 60)
	await ticks(2)
	check(entered, "Equal scores go to sudden death")
	var a := pl(0).global_position
	var b := pl(1).global_position
	check(duel.arena.pad_at(a) == pd(0) and duel.arena.pad_at(b) == pd(0), "Both players are on the centre pad")
	check(absf(b.x - a.x - 2.6) < 0.15 and absf(a.z) < 0.2 and absf(b.z) < 0.2, "...about 2.6 m apart (%.2f)" % (b.x - a.x))
	check(pl(0).carried == 0 and pl(1).carried == 0, "Carried fireflies are cleared")
	check(duel.loose_fireflies.is_empty() and duel.frogs.is_empty() and duel.queen.state == "hidden", "No loose fireflies, no frogs, Queen hidden")
	await ticks(58)
	check(not pl(0).active and not pl(1).active, "Players are frozen for the first second")
	var free: bool = await until(func(): return duel.players[0].active and duel.players[1].active, 120)
	var freeze := 60 + waited
	check(free and freeze >= 110 and freeze <= 130, "...and released after about 2 s (%.2f s)" % (freeze / 60.0))
	stand(0, surf(-0.6, 0.0), Vector3.RIGHT)
	await ticks(6)
	var r: Dictionary = await do_hit(0, KEY_F, 15)
	check(r["hit"], "A swing in sudden death hits")
	check(normal_d15 > 0.0 and r["d15"] > 1.4 * normal_d15, "Sudden-death knockback is clearly stronger (%.2f m vs %.2f m in 0.25 s)" % [r["d15"], normal_d15])
	var over: bool = await until(func(): return duel.phase == "over", 200)
	await ticks(2)
	check(over and duel.winner == 0, "The first player taken out in sudden death loses")
	var snap := snap_hud()
	check(snap["result_visible"] and snap["result_title"].contains("Ava"), "The result names the survivor")
	# R on the result panel starts a new match.
	key(KEY_R)
	key(KEY_R, false)
	await ticks(3)
	check(duel.phase == "countdown" and duel.scores == [0, 0] and not snap_hud()["result_visible"], "R on the result panel restarts the match")

func test_pause() -> void:
	await reset()
	await to_midnight()
	on_pad(1, 18)
	on_pad(0, 3)
	await ticks(18)
	check(pd(3).state == "warning" and pl(1).poisoned, "Setup: a pad warning and a poisoning are in progress")
	duel.toggle_pause()
	check(duel.paused and snap_hud()["pause_visible"], "toggle_pause() pauses and shows the overlay")
	var e0 := duel.elapsed
	var pos0 := pl(0).global_position
	var pos1 := pl(1).global_position
	var warn0 := pd(3).warning_time
	var hp0 := pl(1).health
	key(KEY_D)
	key(KEY_LEFT)
	await ticks(60)
	key(KEY_D, false)
	key(KEY_LEFT, false)
	check(duel.elapsed == e0, "Pause freezes the match clock")
	check(pl(0).global_position.distance_to(pos0) < 0.001 and pl(1).global_position.distance_to(pos1) < 0.001, "...and the players, even with keys held")
	check(pd(3).warning_time == warn0 and pd(3).state == "warning", "...and pad timers")
	check(pl(1).health == hp0, "...and poison")
	duel.toggle_pause()
	check(not duel.paused and not snap_hud()["pause_visible"], "A second toggle resumes")
	await ticks(60)
	check(duel.elapsed > e0 + 0.5 and not pd(3).is_standable() and pl(1).health < hp0 - 5.0, "The clock, pad timers and poison run again")
	# Real Esc and R keys.
	await reset()
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await ticks(2)
	check(duel.paused, "Esc pauses")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await ticks(2)
	check(not duel.paused, "Esc again resumes")
	var t_before := duel.elapsed
	key(KEY_R)
	key(KEY_R, false)
	await ticks(2)
	check(duel.phase == "dusk" and duel.elapsed >= t_before and duel.elapsed > 0.0, "R during normal play does nothing")
	duel.set_elapsed(30.0)
	await ticks(3)
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await ticks(2)
	check(duel.paused, "Setup: paused at 30 s")
	key(KEY_R)
	key(KEY_R, false)
	await ticks(3)
	check(not duel.paused and duel.phase == "countdown" and duel.elapsed == 0.0 and duel.scores == [0, 0], "R while paused restarts the match")

func test_input_separation() -> void:
	await reset()
	var cases := [
		[0, KEY_W, Vector3(0, 0, -1)], [0, KEY_S, Vector3(0, 0, 1)], [0, KEY_A, Vector3(-1, 0, 0)], [0, KEY_D, Vector3(1, 0, 0)],
		[1, KEY_UP, Vector3(0, 0, -1)], [1, KEY_DOWN, Vector3(0, 0, 1)], [1, KEY_LEFT, Vector3(-1, 0, 0)], [1, KEY_RIGHT, Vector3(1, 0, 0)],
	]
	var good := true
	var quiet := true
	for entry in cases:
		var mover: int = entry[0]
		var other := 1 - mover
		stand(0, surf(0.0, 0.0))
		stand(1, surf(0.0, 0.0))
		await ticks(8)
		var m0 := pl(mover).global_position
		var o0 := pl(other).global_position
		key(entry[1])
		await ticks(15)
		key(entry[1], false)
		await ticks(20)
		var moved := pl(mover).global_position - m0
		var dir: Vector3 = entry[2]
		var ok := moved.dot(dir) > 0.5 and pl(other).global_position.distance_to(o0) < 0.05
		if not ok:
			print("  movement case failed: player ", mover + 1, " key ", entry[1], " moved ", moved, " other moved ", pl(other).global_position - o0)
		good = good and moved.dot(dir) > 0.5
		quiet = quiet and pl(other).global_position.distance_to(o0) < 0.05
	check(good, "P1 moves with W/A/S/D and P2 with the arrow keys, in screen-relative directions")
	check(quiet, "Each player's keys never move the other player")
	# Both at once.
	stand(0, surf(-1.0, 0.0))
	stand(1, surf(1.0, 0.0))
	await ticks(8)
	var s0 := pl(0).global_position
	var s1 := pl(1).global_position
	key(KEY_D)
	key(KEY_LEFT)
	await ticks(12)
	var mid0 := pl(0).global_position
	var mid1 := pl(1).global_position
	key(KEY_D, false)
	key(KEY_LEFT, false)
	await ticks(10)
	check(mid0.x > s0.x + 0.3 and mid1.x < s1.x - 0.3, "Both players move at the same time")
	# Jump keys.
	stand(0, surf(-1.0, 0.0))
	stand(1, surf(1.0, 0.0))
	await ticks(8)
	var j0 := pl(0).jump_count
	var j1 := pl(1).jump_count
	key(KEY_SPACE)
	await ticks(3)
	key(KEY_SPACE, false)
	await ticks(50)
	check(pl(0).jump_count == j0 + 1 and pl(1).jump_count == j1, "Space jumps player 1 only")
	key(KEY_ENTER)
	await ticks(3)
	key(KEY_ENTER, false)
	await ticks(50)
	check(pl(1).jump_count == j1 + 1 and pl(0).jump_count == j0 + 1, "Enter jumps player 2 only")
	# Swing keys, with the players 2.6 m apart so nothing is hit.
	stand(0, surf(-1.3, 0.0))
	stand(1, surf(1.3, 0.0))
	await ticks(8)
	var w0: int = swing_counts[0]
	var w1: int = swing_counts[1]
	key(KEY_F)
	await ticks(2)
	key(KEY_F, false)
	await ticks(40)
	check(swing_counts[0] == w0 + 1 and swing_counts[1] == w1, "F swings player 1's bat only")
	key(KEY_SLASH)
	await ticks(2)
	key(KEY_SLASH, false)
	await ticks(40)
	check(swing_counts[1] == w1 + 1 and swing_counts[0] == w0 + 1, "Slash swings player 2's bat only")

# --- regression tests for the review fixes ---------------------------------------------------

# Both players swing on the very same frame. Returns once both impacts have been resolved.
func swing_both() -> void:
	key(KEY_F)
	key(KEY_SLASH)
	await ticks(1)
	key(KEY_F, false)
	key(KEY_SLASH, false)

# Watches both players for `count` ticks and reports who was ever inactive (taken out).
func watch_out(count: int) -> Array:
	var seen := [false, false]
	for i in count:
		await physics_frame
		for k in 2:
			seen[k] = seen[k] or not pl(k).active
	return seen

func test_simultaneous_swings() -> void:
	await reset()
	stand(0, surf(-0.75, 0.0), Vector3.RIGHT)
	stand(1, surf(0.75, 0.0), Vector3.LEFT)
	pl(0).set_carried(4)
	pl(1).set_carried(4)
	await ticks(6)
	var impacts0: int = impact_counts[0]
	var impacts1: int = impact_counts[1]
	await swing_both()
	var both: bool = await until(func(): return pl(0).invulnerable_remaining > 0.0 and pl(1).invulnerable_remaining > 0.0, 60)
	check(impact_counts[0] == impacts0 + 1 and impact_counts[1] == impacts1 + 1, "Both swings reached their impact")
	check(both, "Two swings landing on the same tick hit BOTH players (each is invulnerable afterwards)")
	check(pl(0).carried == 2 and pl(1).carried == 2, "...and both drop half of what they carry (%d / %d left)" % [pl(0).carried, pl(1).carried])
	check(duel.loose_fireflies.size() == 4, "...four fireflies are loose in total (%d)" % duel.loose_fireflies.size())
	await ticks(3)
	check(pl(0).velocity.x < -1.0 and pl(1).velocity.x > 1.0 or pl(0).global_position.x < -0.75 and pl(1).global_position.x > 0.75, "...and they are knocked in opposite directions")
	# A victim already dropping through a pad cannot be hit by a real swing.
	await reset()
	stand(0, surf(2.0, 0.0), Vector3.RIGHT)
	stand(1, surf(3.5, 0.0), Vector3.LEFT)
	pl(1).set_carried(4)
	pl(1).drop_through()
	var seen := {"reach": false}
	var watcher := func(_p): seen["reach"] = pl(0).bat_reaches(pl(1).global_position)
	pl(0).bat_impact.connect(watcher)
	var impacts: int = impact_counts[0]
	key(KEY_F)
	await ticks(1)
	key(KEY_F, false)
	await until(func(): return impact_counts[0] == impacts + 1, 30)
	await ticks(2)
	pl(0).bat_impact.disconnect(watcher)
	check(seen["reach"], "Setup: the swing really reached the falling player (bat_reaches is true at impact)")
	check(pl(1).falling_through and pl(1).carried == 4 and pl(1).invulnerable_remaining == 0.0 and pl(1).stun_remaining == 0.0 and duel.loose_fireflies.is_empty(), "A victim with falling_through true is not hit by a real swing")

# `holder_point` is where the hitter already stands on a pad that holds for them (pad `yellow_id`);
# when it is Vector3.INF the pad is simply forced to sink under the victim instead.
func softlock_case(label: String, victim: int, hitter_point: Vector3, victim_point: Vector3, yellow_id: int, drop_height: float, swing_delay: int, hitter_holds := false, must_drop := true) -> void:
	await reset()
	var hitter := 1 - victim
	var hitter_key: Key = KEY_F if hitter == 0 else KEY_SLASH
	var move_key: Key = KEY_D if victim == 0 else KEY_LEFT
	var face_victim := Vector3.RIGHT if hitter_point.x < victim_point.x else Vector3.LEFT
	if hitter_holds:
		duel.yellow_roll_override = 0
		stand(hitter, hitter_point, face_victim)
		await ticks(30)
		check(duel.yellow_holds.has(yellow_id) and pd(yellow_id).is_standable(), "%s: setup, the pad holds for the hitter who is standing on it" % label)
	else:
		duel.yellow_roll_override = 1
		stand(hitter, hitter_point, face_victim)
	stand(victim, victim_point, -face_victim)
	pl(victim).global_position += Vector3(0, drop_height, 0)
	pl(victim).velocity = Vector3.ZERO
	await ticks(swing_delay)
	key(hitter_key)
	await ticks(1)
	key(hitter_key, false)
	var seen_stuck := false
	var seen_out := false
	var seen_dropped := false
	for i in 180:
		await physics_frame
		var p := pl(victim)
		seen_out = seen_out or not p.active
		seen_dropped = seen_dropped or p.falling_through
		seen_stuck = seen_stuck or (p.active and p.falling_through and p.is_on_floor())
	var p := pl(victim)
	if must_drop:
		check(seen_dropped, "%s: setup worked, the yellow pad dropped the victim" % label)
	check(not seen_stuck, "%s: the victim is never stuck (falling_through true while standing on a floor)" % label)
	var free := true
	if p.active:
		var before := p.global_position
		key(move_key)
		await ticks(15)
		key(move_key, false)
		free = Vector2(p.global_position.x - before.x, p.global_position.z - before.z).length() > 0.3
	check((seen_out or p.active) and free, "%s: after 3 s the victim was taken out / respawned or can move with real input" % label)

func test_soft_lock() -> void:
	# P1 lands on the east yellow pad (forced sink) while P2 swings at them from the centre pad.
	await softlock_case("Centre pad swinger", 0, Vector3(2.4, SURFACE, 0.0), Vector3(4.7, SURFACE, 0.0), 1, 0.0, 0)
	# P2 swinging from the bridge pad right next to the yellow pad.
	await softlock_case("Bridge pad swinger", 0, Vector3(8.9, SURFACE, 0.0), Vector3(7.1, SURFACE, 0.0), 1, 0.0, 0)
	# The hit lands while P1 is still in the air above the pad (so the pad may never drop them).
	await softlock_case("Mid-air hit", 0, Vector3(8.9, SURFACE, 0.0), Vector3(7.1, SURFACE, 0.0), 1, 1.5, 14, false, false)
	# P1 holds the east yellow pad; P2 lands on its west side, the pad gives way, and P1 bats the
	# falling P2 back towards the centre pad, which is exactly where they could be stood on a floor.
	await softlock_case("Holder bats the newcomer (east)", 1, Vector3(6.2, SURFACE, 0.0), Vector3(4.7, SURFACE, 0.0), 1, 0.0, 0, true)
	# The same on the west yellow pad with the roles swapped.
	await softlock_case("Holder bats the newcomer (west)", 0, Vector3(-6.2, SURFACE, 0.0), Vector3(-4.7, SURFACE, 0.0), 5, 0.0, 0, true)

func test_rim() -> void:
	await reset()
	# P1's home pad (radius 2.0) is built from 0.25 m cells; (1.2, 1.7) from its centre is on
	# the collision mesh but 2.08 m out, i.e. on the rim, not over the nominal disc.
	var home := pd(21)
	var spot := home.surface_center() + Vector3(1.2, 0.0, 1.7)
	stand(0, spot, Vector3.RIGHT)
	await ticks(4)
	var out_by := Vector2(pl(0).global_position.x - home.position.x, pl(0).global_position.z - home.position.z).length()
	check(pl(0).is_on_floor() and out_by > home.radius + 0.05 and duel.arena.pad_at(pl(0).global_position) == null, "Setup: the player stands on the collision rim of their home pad, %.2f m from its centre" % out_by)
	check(duel.scores == [0, 0], "Setup: nothing banked yet")
	pl(0).set_carried(3)
	var banked: bool = await until(func(): return duel.scores[0] > 0, 60)
	check(banked and duel.scores == [3, 0] and pl(0).carried == 0, "A carrier standing on the rim of their home pad banks (3 -> score 3)")
	# The other player's rim does not bank for you.
	await reset()
	var enemy := pd(22)
	stand(0, enemy.surface_center() + Vector3(-1.2, 0.0, 1.7), Vector3.RIGHT)
	pl(0).set_carried(2)
	await ticks(30)
	check(pl(0).is_on_floor() and duel.scores == [0, 0] and pl(0).carried == 2, "The rim of the opponent's home pad banks nothing")
	# A middle pad: (0.95, 1.2) from the centre of pad 3 is 1.53 m out (radius 1.45).
	await reset()
	var mid := pd(3)
	stand(0, mid.surface_center() + Vector3(0.95, 0.0, 1.2), Vector3.RIGHT)
	await ticks(3)
	var mid_out := Vector2(pl(0).global_position.x - mid.position.x, pl(0).global_position.z - mid.position.z).length()
	check(pl(0).is_on_floor() and mid_out > mid.radius + 0.04 and duel.arena.pad_at(pl(0).global_position) == null, "Setup: the player stands on the rim of middle pad 3, %.2f m from its centre" % mid_out)
	var warned: bool = await until(func(): return mid.state == "warning", 30)
	check(warned, "A player on the rim of a MIDDLE pad starts its warning")

func test_yellow_rerolls() -> void:
	var east := pd(1)
	# Hold for P1, P1 leaves, then lands again with a hold roll: still solid, not dropped.
	await reset()
	duel.yellow_roll_override = 0
	on_pad(0, 1)
	await ticks(30)
	check(duel.yellow_holds.has(1) and east.is_standable(), "Setup: the pad holds for player 1")
	on_pad(0, 0)
	await ticks(36)
	check(east.spent and duel.yellow_spent_by.get(1, -1) == 0, "Setup: player 1 left, the pad is spent by player 1")
	on_pad(0, 1)
	await ticks(60)
	check(east.state == "solid" and east.is_standable() and not pl(0).falling_through and pl(0).active and pl(0).is_on_floor(), "The player it held for lands again with roll 0: the pad is still solid and they are not dropped")
	check(duel.yellow_holds.has(1) and duel.yellow_holds[1]["player"] == 0, "...it holds for them again (a fresh roll)")
	# Same, but the fresh roll comes up 'sink'.
	await reset()
	duel.yellow_roll_override = 0
	on_pad(0, 1)
	await ticks(30)
	on_pad(0, 0)
	await ticks(36)
	check(east.spent, "Setup: spent again")
	duel.yellow_roll_override = 1
	on_pad(0, 1)
	var sank: bool = await until(func(): return not east.is_standable(), 40)
	check(sank and pl(0).falling_through, "The player it held for lands again with roll 1: the pad sinks and drops them")
	# The other player always sinks it, whatever the roll.
	await reset()
	duel.yellow_roll_override = 0
	on_pad(0, 1)
	await ticks(30)
	on_pad(0, 0)
	await ticks(36)
	check(east.spent and duel.yellow_spent_by.get(1, -1) == 0, "Setup: pad spent by player 1")
	on_pad(1, 1)
	sank = await until(func(): return not east.is_standable(), 40)
	check(sank and pl(1).falling_through, "Player 2 landing on a pad spent by player 1 sinks it, even with roll 0")
	# The other player lands while the holder is still on the pad: it gives way under both.
	await reset()
	duel.yellow_roll_override = 0
	on_pad(0, 1, Vector3(-0.8, 0, 0))
	await ticks(30)
	check(duel.yellow_holds.has(1) and east.is_standable() and pl(0).is_on_floor(), "Setup: the pad holds for player 1, who is standing on it")
	on_pad(1, 1, Vector3(0.8, 0, 0), Vector3.LEFT)
	sank = await until(func(): return not east.is_standable(), 40)
	check(sank, "Player 2 landing while player 1 still stands on a held pad (roll 0) makes it sink")
	var seen := await watch_out(100)
	check(seen[0] and seen[1], "...and both players end up in the water (%s)" % str(seen))

func test_scatter_range() -> void:
	await reset()
	await to_midnight()
	duel.set_elapsed(155.0)
	await ticks(130)
	check(standable_ids() == [0, 1, 5, 9, 15, 21, 22], "Setup: only the centre, homes, yellow and bridge pads remain at +35 s (%s)" % str(standable_ids()))
	for frog in duel.frogs:
		frog.dismiss()
	# Each case: where the player falls, and who is expected to be allowed to catch fireflies.
	var cases := [[0, -3.6], [1, 3.6], [0, -13.15], [1, 13.15]]
	for entry in cases:
		var who: int = entry[0]
		var x: float = entry[1]
		for fly in duel.loose_fireflies.duplicate():
			duel.loose_fireflies.erase(fly)
			fly.free()
		pl(who).set_carried(12)
		stand(who, Vector3(x, SURFACE, 0.0))
		var out: bool = await until(func(): return not pl(who).active, 120)
		var at := pl(who).global_position
		var flies := duel.loose_fireflies.size()
		# The rule, written independently: the nearest standable non-home pad, plus up to two more
		# whose edge is within 4.5 m of the drop point.
		var ranked := []
		for p in duel.arena.pads:
			if p.is_standable() and p.kind != LilyDuelPad.Kind.HOME:
				ranked.append([maxf(Vector2(at.x - p.position.x, at.z - p.position.z).length() - p.radius, 0.0), p.pad_id])
		ranked.sort()
		var allowed := [ranked[0][1]]
		for i in range(1, mini(3, ranked.size())):
			if ranked[i][0] <= 4.5:
				allowed.append(ranked[i][1])
		var good := true
		var used := {}
		for fly in duel.loose_fireflies:
			var over := duel.arena.pad_at(fly.global_position)
			good = good and over != null and allowed.has(over.pad_id)
			if over != null:
				used[over.pad_id] = true
		check(out and flies == 12, "Case x=%.2f (player %d): all 12 carried fireflies become loose (%d)" % [x, who + 1, flies])
		check(good, "Case x=%.2f: every dropped firefly is over the nearest pad or a pad within 4.5 m (allowed %s, used %s)" % [x, str(allowed), str(used.keys())])
		if absf(x) < 5.0:
			check(not used.has(15 if x < 0.0 else 9) and not used.has(1 if x < 0.0 else 5), "Case x=%.2f: nothing lands on the far pads across the pond" % x)
		else:
			check(used.keys() == [15 if x < 0.0 else 9], "Case x=%.2f: only one pad is in range, so all of them land on it (%s)" % [x, str(used.keys())])
		await until(func(): return pl(who).active, 150)
		await ticks(6)

func test_respawn_protection() -> void:
	await reset()
	stand(0, Vector3(-3.5, SURFACE, 0.0))
	var out: bool = await until(func(): return not pl(0).active, 120)
	check(out, "Setup: player 1 is taken out")
	var back: bool = await until(func(): return pl(0).active, 150)
	var inv := pl(0).invulnerable_remaining
	check(back and inv > 1.3 and inv <= 1.5, "A respawned player has about 1.5 s of invulnerability (%.2f)" % inv)
	stand(1, surf(-14.0, 0.0), Vector3.LEFT)
	await ticks(4)
	var spot := pl(0).global_position
	var impacts: int = impact_counts[1]
	key(KEY_SLASH)
	await ticks(1)
	key(KEY_SLASH, false)
	await until(func(): return impact_counts[1] == impacts + 1, 40)
	await ticks(3)
	check(pl(1).bat_reaches(pl(0).global_position), "Setup: player 1 was within reach of the swing")
	check(pl(0).stun_remaining == 0.0 and pl(0).global_position.distance_to(spot) < 0.1 and pl(0).velocity.length() < 1.0 and pl(0).invulnerable_remaining > 0.5, "A swing in reach during the respawn protection does nothing")
	await until(func(): return pl(0).invulnerable_remaining <= 0.0 and pl(1).swing_remaining <= 0.0, 200)
	var r: Dictionary = await do_hit(1, KEY_SLASH)
	check(r["hit"] and pl(0).stun_remaining > 0.0, "After the protection expires the same swing hits")
	# Protection also applies after a poison death.
	await reset()
	await to_midnight()
	pl(1).health = 5.0
	duel.poison(pl(1))
	var dead: bool = await until(func(): return not pl(1).active, 120)
	var up: bool = await until(func(): return pl(1).active, 150)
	check(dead and up and pl(1).invulnerable_remaining > 1.3, "Respawning after a poison death is protected too (%.2f)" % pl(1).invulnerable_remaining)

func test_sudden_death_together() -> void:
	await reset()
	await to_midnight()
	duel.set_elapsed(179.99)
	var entered: bool = await until(func(): return duel.phase == "sudden_death", 60)
	var free: bool = await until(func(): return duel.players[0].active and duel.players[1].active, 200)
	check(entered and free, "Setup: sudden death is running and both players are released")
	stand(0, Vector3(-3.5, SURFACE, 0.0))
	stand(1, Vector3(3.5, SURFACE, 0.0))
	var seen := await watch_out(40)
	check(seen[0] and seen[1], "Both players really went into the water together (%s)" % str(seen))
	check(duel.phase == "sudden_death" and duel.winner == -1, "Both in the water together: sudden death goes on and nobody wins (phase %s, winner %d)" % [duel.phase, duel.winner])
	await ticks(3)
	var a := pl(0).global_position
	var b := pl(1).global_position
	check(duel.arena.pad_at(a) == pd(0) and duel.arena.pad_at(b) == pd(0) and absf(a.x + 1.3) < 0.2 and absf(b.x - 1.3) < 0.2, "...and both are back on the centre pad at x = -1.3 / +1.3")
	check(not pl(0).active and not pl(1).active and not snap_hud()["result_visible"], "...frozen again, with no result shown")
	var free_again: bool = await until(func(): return duel.players[0].active and duel.players[1].active, 200)
	check(free_again and duel.phase == "sudden_death", "...and released again after the freeze")
	# One player alone: the other wins.
	stand(0, Vector3(-3.5, SURFACE, 0.0))
	var over: bool = await until(func(): return duel.phase == "over", 120)
	check(over and duel.winner == 1, "One player alone in the water: the other one wins")
	# Pause during the freeze, then resume: both still get released.
	await reset()
	await to_midnight()
	duel.set_elapsed(179.99)
	await until(func(): return duel.phase == "sudden_death", 60)
	await ticks(20)
	var freeze_before := duel.sudden_freeze_left
	check(freeze_before > 0.5 and not pl(0).active and not pl(1).active, "Setup: in the middle of the sudden-death freeze (%.2f s left)" % freeze_before)
	duel.toggle_pause()
	await ticks(180)
	check(duel.paused and absf(duel.sudden_freeze_left - freeze_before) < 0.001 and not pl(0).active and not pl(1).active, "The freeze does not run down while paused")
	duel.toggle_pause()
	var released: bool = await until(func(): return duel.players[0].active and duel.players[1].active, 200)
	check(released and not duel.paused and duel.phase == "sudden_death", "Resuming during the freeze still releases both players (after %d ticks)" % waited)
	var steer := pl(0).global_position
	key(KEY_A)
	await ticks(10)
	key(KEY_A, false)
	check(pl(0).global_position.x < steer.x - 0.2, "...and they respond to real input")

func test_flood_mid_cycle() -> void:
	await reset()
	await to_midnight()
	# Pad 2 is in its warning, pad 3 is sunk for a long time, pad 4 is rising: all are middle
	# pads that a flood step reaches (3 at +20 s, 2 and 4 at +30 s).
	pd(2).trigger_sink(5.0, 4.0)
	pd(3).trigger_sink(0.0, 100.0)
	pd(4).trigger_sink(0.0, 0.0)
	var rising: bool = await until(func(): return pd(4).state == "rising", 120)
	check(rising and pd(2).state == "warning" and pd(3).state == "sunk", "Setup: pad 2 warning, pad 3 sunk, pad 4 rising (%s / %s / %s)" % [pd(2).state, pd(3).state, pd(4).state])
	duel.set_elapsed(150.0)
	var came_back := false
	for i in 330:
		await physics_frame
		for id in [2, 3, 4]:
			if i > 2 and (pd(id).state == "solid" or pd(id).is_standable() and pd(id).state == "rising"):
				came_back = true
	for id in [2, 3, 4]:
		check(pd(id).state == "gone" and not pd(id).is_standable(), "A middle pad that was mid-cycle when the flood reached it ends gone: pad %d is %s" % [id, pd(id).state])
	check(not came_back, "...and it never becomes standable again")

func test_queen_tie_and_death() -> void:
	await reset()
	await to_midnight()
	# Both players under the perch when she appears: the winner of the tick is random.
	var firsts := [0, 0]
	for trial in 24:
		duel.queen.hide_queen()
		for p in [0, 1]:
			pl(p).set_queen(false)
			pl(p).speed_scale = 1.0
		stand(0, surf(-0.3, 0.0))
		stand(1, surf(0.3, 0.0))
		await ticks(3)
		duel.rng.seed = 4000 + trial
		duel.queen.appear(duel.arena.queen_perch())
		await ticks(1)
		var holder := -1
		for p in [0, 1]:
			if pl(p).has_queen:
				holder = p
		if holder >= 0:
			firsts[holder] += 1
	check(firsts[0] + firsts[1] == 24 and firsts[0] >= 3 and firsts[1] >= 3, "When both stand under the perch the Queen goes to either player at random (P1 %d, P2 %d of 24)" % [firsts[0], firsts[1]])
	# Taken out while poisoned and holding the Queen.
	await reset()
	await to_midnight()
	stand(0, surf(0.0, 0.0))
	var took: bool = await until(func(): return pl(0).has_queen, 90)
	check(took and is_equal_approx(pl(0).speed_scale, 0.85), "Setup: player 1 holds the Queen (speed 0.85)")
	duel.poison(pl(0))
	pl(0).health = 60.0
	pl(0).set_carried(3)
	check(pl(0).poisoned, "Setup: player 1 is poisoned")
	stand(0, Vector3(-3.5, SURFACE, 0.0))
	var out: bool = await until(func(): return not pl(0).active, 120)
	await ticks(2)
	check(out and not pl(0).has_queen and not pl(0).poisoned and duel.queen.holder == null and duel.queen.state in ["returning", "perched"], "Taken out while poisoned and holding the Queen: poison and Queen are gone at once")
	var back: bool = await until(func(): return pl(0).active, 150)
	await ticks(2)
	check(back and pl(0).health == 100.0 and not pl(0).poisoned and not pl(0).has_queen and is_equal_approx(pl(0).speed_scale, 1.0), "...and the respawned player is healthy, unpoisoned, without the Queen, at speed 1.0")
	var perched: bool = await until(func(): return duel.queen.state == "perched", 120)
	check(perched and duel.queen.holder == null and duel.queen.global_position.distance_to(Vector3(0, 2.3, 0)) < 0.6, "...and the Queen is perched again")
	check(snap_hud()["queen"] == -1, "...and the HUD shows no holder")

func test_snapshot_state() -> void:
	await reset()
	var snap := duel.debug_snapshot()
	check(snap.get("state", "") == "duel" and snap.get("mode", "") == "duel", "debug_snapshot() has state \"duel\" (and mode \"duel\")")

func test_game() -> void:
	duel.free()
	duel = null
	await ticks(3)
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_duel.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	for i in 4:
		await physics_frame
		await process_frame
	var base_children := game.get_child_count()
	check(game.state == "title", "The game starts on the title screen")
	for round in 2:
		game.start_duel()
		for i in 6:
			await physics_frame
			await process_frame
		check(game.state == "duel", "Round %d: start_duel() enters the duel state" % (round + 1))
		check(not game.world.is_inside_tree(), "Round %d: the single-player world is out of the tree" % (round + 1))
		var snapshot: Dictionary = game.debug_snapshot()
		check(snapshot.get("mode", "") == "duel" and snapshot.get("pads", []).size() == 23, "Round %d: debug_snapshot() returns the duel snapshot" % (round + 1))
		check(snapshot.get("state", "") == "duel" and game.state == "duel", "Round %d: the game's debug_snapshot() has state \"duel\" during a duel" % (round + 1))
		var ref: WeakRef = weakref(game.duel)
		game.duel.exit_requested.emit()
		for i in 6:
			await physics_frame
			await process_frame
		check(game.state == "title", "Round %d: exit_requested returns to the title" % (round + 1))
		check(ref.get_ref() == null and game.duel == null, "Round %d: the duel is freed" % (round + 1))
		check(game.world.is_inside_tree(), "Round %d: the world is back in the tree" % (round + 1))
		check(game.get_child_count() == base_children, "Round %d: nothing is left behind in the game node" % (round + 1))
	game.start_run()
	for i in 30:
		await physics_frame
		await process_frame
	check(game.state == "playing", "start_run() works after leaving the duel")
	check(game.player.is_on_floor() and Vector2(game.player.global_position.x - game.level.spawn.x, game.player.global_position.z - game.level.spawn.z).length() < 1.0, "The single-player character stands on the first pad")
	game.stop_sounds()
	game.queue_free()
	for i in 3:
		await physics_frame
		await process_frame
	DirAccess.remove_absolute("user://lily_qa_duel.cfg")

func run() -> void:
	duel = LilyDuel.new()
	root.add_child(duel)
	duel.begin(LilyAppearance.DEFAULTS.duplicate(), "Ava")
	for i in 2:
		var index := i
		duel.players[i].swung.connect(func(_p): swing_counts[index] += 1)
		duel.players[i].bat_impact.connect(func(_p): impact_counts[index] += 1)
	await ticks(3)
	await test_collecting()
	await test_banking()
	await test_spawner()
	await test_spawner_weights()
	await test_bat()
	await test_queen()
	await test_middle_ring()
	await test_yellow()
	await test_yellow_rolls()
	await test_water()
	await test_frogs()
	await test_flood()
	await test_end()
	await test_sudden_death()
	await test_pause()
	await test_input_separation()
	await test_simultaneous_swings()
	await test_soft_lock()
	await test_rim()
	await test_yellow_rerolls()
	await test_scatter_range()
	await test_respawn_protection()
	await test_sudden_death_together()
	await test_flood_mid_cycle()
	await test_queen_tie_and_death()
	await test_snapshot_state()
	await test_game()
	release_all()
	for message in failures:
		print("FAILED: ", message)
	print("DUEL RULES RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
