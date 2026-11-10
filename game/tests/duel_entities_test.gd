extends SceneTree

class FakePad extends Node3D:
	func surface_center() -> Vector3:
		return global_position + Vector3(0, 0.6, 0)

var passed := 0
var failures: Array[String] = []
var floor_body: StaticBody3D
var p0: LilyDuelPlayer
var p1: LilyDuelPlayer
var impacts := 0
var landed_count := 0
var jumps := 0
var swings := 0

func _initialize() -> void:
	run.call_deferred()

func phys(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func release_all() -> void:
	for n in ["left", "right", "up", "down", "jump", "swing"]:
		Input.action_release("duel_p1_" + n)
		Input.action_release("duel_p2_" + n)

func reset(a := Vector3(-8, 0.62, 0), b := Vector3(8, 0.62, 0)) -> void:
	release_all()
	p0.active = true
	p1.active = true
	p0.respawn(a, Vector3.RIGHT)
	p1.respawn(b, Vector3.LEFT)
	p0.speed_scale = 1.0
	p1.speed_scale = 1.0

func count_events(action: String) -> int:
	return InputMap.action_get_events(action).size()

func run() -> void:
	LilyDuelPlayer.configure_input()
	var before := {}
	for who in ["p1", "p2"]:
		for n in ["left", "right", "up", "down", "jump", "swing"]:
			before["duel_%s_%s" % [who, n]] = count_events("duel_%s_%s" % [who, n])
	LilyDuelPlayer.configure_input()
	var same := true
	for action in before:
		same = same and count_events(action) == before[action]
	check(same, "configure_input is idempotent")
	var keys := {}
	var clash := false
	for action in before:
		for e in InputMap.action_get_events(action):
			var code: int = e.physical_keycode
			if keys.has(code) and keys[code].begins_with(action.substr(0, 8)) == false:
				clash = true
			keys[code] = action
	check(not clash, "P1 and P2 actions do not share keys")
	check(before["duel_p2_jump"] == 2 and before["duel_p2_swing"] == 2 and before["duel_p1_jump"] == 1, "P2 jump and swing have two keys each")

	floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, 0.1, 0)
	root.add_child(floor_body)
	p0 = LilyDuelPlayer.new()
	p0.setup(0, {})
	p1 = LilyDuelPlayer.new()
	p1.setup(1, {})
	root.add_child(p0)
	root.add_child(p1)
	p0.bat_impact.connect(func(_p): impacts += 1)
	p0.global_position = Vector3(-8, 0.62, 0)
	p1.global_position = Vector3(8, 0.62, 0)
	p0.active = true
	p1.active = true
	await phys(12)
	check(p0.is_on_floor() and p1.is_on_floor(), "Players are grounded on the floor within 12 frames")
	check(p0.collision_layer == 2 and p0.collision_mask == 5, "Player uses layer 2 and mask 1|4")

	# Movement and axes.
	reset()
	await phys(6)
	var s0 := p0.global_position
	var s1 := p1.global_position
	Input.action_press("duel_p1_right")
	await phys(40)
	check(p0.global_position.x - s0.x > 2.0 and absf(p0.global_position.z - s0.z) < 0.01, "duel_p1_right moves player 0 toward +X")
	check(p1.global_position.distance_to(s1) < 0.01, "duel_p1_right does not move player 1")
	check(absf(Vector2(p0.velocity.x, p0.velocity.z).length() - 5.4) < 0.05, "Top ground speed is about 5.4")
	Input.action_release("duel_p1_right")
	reset()
	await phys(6)
	s0 = p0.global_position
	s1 = p1.global_position
	Input.action_press("duel_p2_up")
	await phys(30)
	check(p1.global_position.z - s1.z < -1.5 and absf(p1.global_position.x - s1.x) < 0.01, "duel_p2_up moves player 1 toward -Z")
	check(p0.global_position.distance_to(s0) < 0.01, "duel_p2_up does not move player 0")
	Input.action_release("duel_p2_up")
	reset()
	p0.speed_scale = 0.85
	await phys(6)
	Input.action_press("duel_p1_down")
	await phys(40)
	check(absf(p0.velocity.z - 5.4 * 0.85) < 0.05, "speed_scale 0.85 gives about 4.59 top speed and down is +Z")
	Input.action_release("duel_p1_down")

	# Jump.
	reset()
	await phys(8)
	var base_y := p0.global_position.y
	var peak := base_y
	jumps = 0
	p0.jumped.connect(func(_p): jumps += 1)
	key(KEY_SPACE)
	await physics_frame
	key(KEY_SPACE, false)
	for i in 80:
		await physics_frame
		peak = maxf(peak, p0.global_position.y)
	await process_frame
	check(absf((peak - base_y) - 1.6) < 0.15, "Jump peaks about 1.6 m (%.2f)" % (peak - base_y))
	check(p0.is_on_floor() and absf(p0.global_position.y - base_y) < 0.05 and jumps == 1, "Jump lands back on the floor and emits once")

	# Inactive player.
	reset()
	p1.respawn(Vector3(8, 6, 0), Vector3.LEFT)
	p1.active = false
	Input.action_press("duel_p2_left")
	await phys(30)
	check(absf(p1.global_position.y - 6.0) < 0.001 and absf(p1.global_position.x - 8.0) < 0.001, "Inactive player ignores input and gravity")
	Input.action_release("duel_p2_left")

	# Swing.
	reset()
	await phys(6)
	impacts = 0
	swings = 0
	p0.swung.connect(func(_p): swings += 1)
	key(KEY_F)
	await physics_frame
	key(KEY_F, false)
	var frames_to_impact := 0
	for i in 20:
		if impacts > 0:
			break
		await physics_frame
		frames_to_impact += 1
	check(impacts == 1 and absf(frames_to_impact - 7.0) <= 2.0, "bat_impact fires about 0.12 s after the swing (%d frames)" % frames_to_impact)
	check(p0.swing_remaining > 0.0 and p0.attack_direction.dot(Vector3.RIGHT) > 0.9, "Swing goes where the avatar faces")
	key(KEY_F)
	await physics_frame
	key(KEY_F, false)
	await phys(40)
	check(impacts == 1 and swings == 1, "Second request mid-swing is ignored and impact is emitted once")
	check(p0.swing_remaining == 0.0, "Swing ends after 0.48 s")

	# bat_reaches.
	reset()
	await phys(3)
	key(KEY_F)
	await physics_frame
	key(KEY_F, false)
	var origin := p0.global_position
	check(p0.bat_reaches(origin + Vector3(1.5, 0, 0)), "bat_reaches true 1.5 m in front")
	check(not p0.bat_reaches(origin + Vector3(-1.5, 0, 0)), "bat_reaches false behind")
	check(not p0.bat_reaches(origin + Vector3(3.0, 0, 0)), "bat_reaches false at 3 m")
	check(not p0.bat_reaches(origin + Vector3(1.5, 1.5, 0)), "bat_reaches false 1.5 m above")
	await phys(40)

	# Knockback.
	reset()
	await phys(8)
	Input.action_press("duel_p1_left")
	var kx := p0.global_position.x
	p0.knockback(Vector3(1, 3, 0))
	var inv_start := p0.invulnerable_remaining
	check(p0.stun_remaining == 0.45 and absf(inv_start - 0.8) < 0.001, "knockback sets stun 0.45 and invulnerable 0.8")
	var max_x := kx
	var steered := false
	for i in 20:
		await physics_frame
		max_x = maxf(max_x, p0.global_position.x)
		if p0.stun_remaining > 0.0 and p0.velocity.x < 8.9:
			steered = true
	check(not steered, "No steering or braking while stunned")
	for i in 40:
		await physics_frame
		max_x = maxf(max_x, p0.global_position.x)
	check(max_x - kx > 2.5, "Knockback moves the player %.2f m in +X against held input" % (max_x - kx))
	check(p0.invulnerable_remaining == 0.0, "Invulnerability counted down to 0")
	Input.action_release("duel_p1_left")
	reset()
	await phys(8)
	p0.knockback(Vector3.RIGHT)
	await phys(10)
	p0.avatar.visible = true
	await phys(1)
	check(p0.invulnerable_remaining < 0.8 and p0.invulnerable_remaining > 0.5, "invulnerable_remaining counts down")
	await phys(70)
	var rz := p0.global_position.z
	Input.action_press("duel_p1_up")
	await phys(15)
	check(p0.global_position.z < rz - 0.5, "Input works again after the stun")
	Input.action_release("duel_p1_up")
	reset()
	await phys(6)
	p0.knockback(Vector3.RIGHT)
	key(KEY_SPACE)
	await physics_frame
	key(KEY_SPACE, false)
	check(p0.buffered == 0.0, "Jump presses are ignored during stun")

	# drop_through, the way it happens in play: the pad under the player stops being solid.
	reset()
	await phys(6)
	p0.carried = 3
	p0.set_poisoned(true)
	# High above the floor so the fall outlasts the whole check.
	p0.respawn(Vector3(-8, 9.0, 0), Vector3.RIGHT)
	p0.drop_through()
	var jc := p0.jump_count
	key(KEY_SPACE)
	Input.action_press("duel_p1_right")
	await phys(20)
	key(KEY_SPACE, false)
	check(p0.falling_through and not p0.is_on_floor() and p0.jump_count == jc and absf(p0.velocity.x) < 0.5, "drop_through blocks input and jumping while falling")
	var stun_before := p0.carried
	p0.stun_remaining = 0.3
	p0.has_queen = true
	p0.respawn(Vector3(-8, 0.62, 0), Vector3.RIGHT)
	Input.action_release("duel_p1_right")
	check(not p0.falling_through and not p0.poisoned and p0.stun_remaining == 0.0 and p0.health == 100.0, "respawn clears falling, poison, stun")
	check(p0.carried == stun_before and p0.has_queen, "respawn leaves carried and has_queen unchanged")
	p0.has_queen = false
	await phys(8)
	key(KEY_SPACE)
	await physics_frame
	key(KEY_SPACE, false)
	await phys(3)
	check(p0.jump_count > jc, "Jumping works again after respawn")
	await phys(60)
	# Landing on solid floor after drop_through gives the controls back.
	reset()
	await phys(6)
	p0.drop_through()
	check(p0.falling_through, "Setup: drop_through() set falling_through")
	await phys(4)
	check(p0.is_on_floor() and not p0.falling_through, "A dropped player who is on solid floor gets falling_through cleared")
	var landed_x := p0.global_position.x
	Input.action_press("duel_p1_right")
	await phys(20)
	Input.action_release("duel_p1_right")
	check(p0.global_position.x - landed_x > 0.8, "...and can move again with real input (%.2f m)" % (p0.global_position.x - landed_x))
	await phys(20)
	jc = p0.jump_count
	key(KEY_SPACE)
	await physics_frame
	key(KEY_SPACE, false)
	await phys(3)
	check(p0.jump_count == jc + 1, "...and can jump again")
	await phys(60)
	# Drop through while a floor appears under the fall: mid-air drop, then solid floor takes over.
	reset()
	await phys(6)
	p0.respawn(Vector3(-8, 2.0, 0), Vector3.RIGHT)
	p0.drop_through()
	var was_blocked := false
	for i in 12:
		await physics_frame
		was_blocked = was_blocked or (p0.falling_through and not p0.is_on_floor())
	await phys(40)
	check(was_blocked and p0.is_on_floor() and not p0.falling_through, "Blocked while falling, free again once it lands on the floor")

	# Motes.
	reset()
	p0.set_carried(5)
	check(p0.visible_mote_count() == 5 and p0.carried == 5, "set_carried(5) shows 5 motes")
	p0.set_carried(30)
	check(p0.visible_mote_count() == 12 and p0.carried == 30, "set_carried(30) shows 12 motes")
	var e30 := p0.light.light_energy
	await phys(40)
	Input.action_press("duel_p1_right")
	await phys(30)
	var lead := p0.global_position
	var tail_gap := p0.motes[11].global_position.distance_to(lead)
	check(tail_gap > 1.0 and tail_gap < 8.0, "Moving player drags a tail (%.2f m)" % tail_gap)
	Input.action_release("duel_p1_right")
	p0.set_carried(0)
	await phys(60)
	check(p0.visible_mote_count() == 0 and p0.light.light_energy < e30, "set_carried(0) shows no motes and dims the light")

	# Pass-through.
	reset(Vector3(-1.5, 0.62, 0), Vector3(1.5, 0.62, 0))
	await phys(6)
	Input.action_press("duel_p1_right")
	Input.action_press("duel_p2_left")
	await phys(60)
	Input.action_release("duel_p1_right")
	Input.action_release("duel_p2_left")
	check(p0.global_position.x > 1.5 and p1.global_position.x < -1.5, "Players walk through each other")

	# Frog.
	var pad := FakePad.new()
	root.add_child(pad)
	pad.position = Vector3(10, 0, 0)
	var other := FakePad.new()
	root.add_child(other)
	other.position = Vector3(0, 0, -10)
	var frog := LilyDuelFrog.new()
	root.add_child(frog)
	landed_count = 0
	frog.landed.connect(func(_f): landed_count += 1)
	frog.place(pad)
	check(frog.state == "sitting" and frog.pad == pad, "Frog place sits on the pad")
	var off := frog.global_position - pad.surface_center()
	check(absf(Vector2(off.x, off.z).length() - 0.6) < 0.05 and off.x > 0.0, "Frog sits 0.6 m toward the outside of the pond")
	frog.launch_to(other, 0.6)
	check(frog.state == "flying" and frog.pad == other, "launch_to flies and retargets pad")
	var frog_peak := 0.0
	var ticks := 0
	for i in 20:
		frog.advance(1.0 / 60.0)
		ticks += 1
		frog_peak = maxf(frog_peak, frog.global_position.y)
	check(landed_count == 0 and frog.state == "flying", "Frog is still flying after 0.33 s")
	for i in 30:
		frog.advance(1.0 / 60.0)
		ticks += 1
		frog_peak = maxf(frog_peak, frog.global_position.y)
	check(landed_count == 1 and frog.state == "sitting" and ticks == 50, "landed fires once after about the duration")
	check(frog.global_position.distance_to(frog.sit_position(other)) < 0.01 and frog_peak > 2.5, "Frog lands at the target after a high arc (peak %.2f)" % frog_peak)
	for i in 30:
		frog.advance(1.0 / 60.0)
	check(landed_count == 1, "landed does not fire again")
	frog.dismiss()
	check(frog.state == "gone", "dismiss sets state gone")
	for i in 40:
		frog.advance(1.0 / 60.0)
	check(not frog.visible and frog.state == "gone", "Dismissed frog ends hidden")

	# Queen.
	var queen := LilyDuelQueen.new()
	root.add_child(queen)
	check(queen.state == "hidden" and not queen.visible, "Queen starts hidden")
	var perch := Vector3(0, 2.3, 0)
	queen.appear(perch)
	check(queen.state == "perched" and queen.visible, "appear perches the queen")
	reset(Vector3(0.3, 0.62, 0), Vector3(3, 0.62, 3))
	await phys(5)
	queen.advance(0.016)
	check(queen.can_be_taken_by(p0), "Player under the perch can take the queen")
	check(not queen.can_be_taken_by(p1), "Player 3 m away cannot")
	queen.give_to(p0)
	check(queen.state == "held" and queen.holder == p0, "give_to holds")
	Input.action_press("duel_p1_right")
	var max_gap := 0.0
	for i in 60:
		await physics_frame
		queen.advance(1.0 / 60.0)
		var d := queen.global_position - p0.global_position
		if i > 20:
			max_gap = maxf(max_gap, Vector2(d.x, d.z).length())
	Input.action_release("duel_p1_right")
	check(max_gap < 1.5, "Held queen stays near the moving holder (%.2f m horizontally)" % max_gap)
	check(queen.global_position.y > p0.global_position.y + 2.0, "Held queen circles above the head")
	queen.return_to_perch()
	check(queen.state == "returning" and queen.holder == null, "return_to_perch starts returning")
	for i in 50:
		queen.advance(1.0 / 60.0)
	check(queen.state == "returning", "Queen is still returning after about 0.8 s")
	for i in 40:
		queen.advance(1.0 / 60.0)
	check(queen.state == "perched" and queen.global_position.distance_to(perch) < 0.3, "Queen is perched again within 1.5 s")
	queen.give_to(p1)
	p1.queue_free()
	await phys(2)
	queen.advance(0.016)
	check(queen.state == "returning", "Freed holder makes the queen return")
	queen.hide_queen()
	check(queen.state == "hidden" and not queen.visible and queen.holder == null, "hide_queen hides")

	print("DUEL ENTITIES RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
