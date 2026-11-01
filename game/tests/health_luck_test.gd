extends SceneTree

var game: Node3D
var player: LilyPlayer
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error("FAIL: " + message + " " + str(game.debug_snapshot()))

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func stand_by(frog: LilyFrog) -> void:
	player.respawn(frog.global_position+Vector3(0,0.1,1.75))
	await frames(12)

func seed_for(sink: bool) -> int:
	var probe := RandomNumberGenerator.new()
	for value in 100:
		probe.seed = value
		if (probe.randf()<0.5) == sink:
			return value
	return 0

func land_chance(pad: LilyDecoyPad) -> void:
	player.respawn(pad.home_position+Vector3(0,0.95,0.3))
	for i in 30:
		await frames(1)
		if pad.resolved:
			return

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_health_luck.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	player = game.player
	game.start_run()
	await frames(20)
	check(game.health == 100 and not game.poisoned and not game.ui.health_box.visible,"Level 1 remains healthy without a combat meter")
	game.show_title()
	game.select_level(1)
	game.start_run()
	await frames(60)
	check(game.health == 100 and not game.poisoned and game.ui.health_box.visible,"Frog River starts at 100 percent and the practice pad is safe")
	var frog: LilyFrog = game.world.frogs[0]
	player.respawn(frog.position+Vector3(0,3,0))
	player.velocity.y = 8
	await frames(12)
	check(not game.poisoned and game.health == 100,"Flying over a frog pad without contact does not poison")
	await stand_by(frog)
	check(game.poisoned and game.poison_source_pad == 1 and game.health < 100,"Actual landing beside a living green frog begins poison damage")
	check(player.poison_cloud.visible,"Poison makes the character's purple effect visible")
	var health_before: float = game.health
	await frames(30)
	check(absf((health_before-game.health)-10.0)<0.05,"Poison drains 20 health points per second without stacking contact hits")
	game.pause()
	health_before = game.health
	var cloud_clock := player.poison_clock
	await frames(30)
	check(game.health == health_before and player.poison_clock == cloud_clock,"Pause freezes poison damage and its visual effect")
	game.resume()
	await frames(8)
	check(game.health < health_before,"Resume continues poison damage")
	player.avatar.rotation.y = PI
	health_before = game.health
	key(KEY_F)
	await frames(32)
	key(KEY_F,false)
	check(frog.alive and game.health < health_before,"A missed swing does not heal or cure poison")
	key(KEY_SPACE)
	await frames(10)
	key(KEY_SPACE,false)
	health_before = game.health
	check(not player.is_on_floor() and game.poisoned,"Jumping away does not remove an applied poison")
	player.respawn(game.level.spawn)
	await frames(12)
	check(game.health < health_before and game.poisoned,"Applied poison continues even after reaching an empty pad")
	await stand_by(frog)
	key(KEY_F)
	await frames(32)
	key(KEY_F,false)
	check(not frog.alive and game.health == 100 and not game.poisoned,"Defeating a green frog instantly restores exactly 100 percent and cures poison")
	check(not player.poison_cloud.visible and game.ui.health_bar.value == 100,"Healing clears the poison effect and fills the health bar")
	await frames(60)
	check(game.health == 100 and not game.poisoned,"A cleared pad cannot reapply poison")
	frog = game.world.frogs[1]
	player.respawn(frog.position+Vector3.UP*1.1)
	await frames(15)
	check(player.is_on_floor() and game.poisoned and game.poison_source_pad == 2,"Landing on the frog itself also applies its pad's poison")
	health_before = game.health
	var seconds_before: float = game.run_seconds
	for i in 310:
		await frames(1)
		if game.state == "poison_defeat":
			break
	check(game.state == "poison_defeat" and game.health == 0 and game.poison_deaths == 1,"Reaching zero health causes one poison defeat")
	check(absf(game.run_seconds-seconds_before-health_before/20.0)<0.04,"A full health bar lasts approximately five seconds of poison")
	check(game.falls == 0 and not player.active and game.ui.health_bar.value == 0,"Poison defeat is distinct from a water fall and stops control")
	key(KEY_F)
	await frames(8)
	key(KEY_F,false)
	check(game.poison_deaths == 1 and game.health == 0 and frog.alive,"Attacking after death cannot heal or create a second defeat")
	game.pause()
	var timer: float = game.retry_timer
	await frames(30)
	check(game.retry_timer == timer and game.health == 0,"Pause also freezes the poison-defeat retry")
	game.resume()
	await frames(85)
	check(game.state == "playing" and game.health == 100 and not game.poisoned and player.is_on_floor(),"Poison retry returns to the practice pad at full health")
	check(game.world.frogs_remaining() == 5 and game.hit_count == 1,"Poison retry preserves previously defeated green frogs")
	check(player.avatar.rotation.is_equal_approx(Vector3.ZERO),"Retry clears the poison-defeat pose")
	await stand_by(frog)
	key(KEY_R)
	await frames(8)
	key(KEY_R,false)
	check(game.health == 100 and not game.poisoned and game.poison_deaths == 0 and game.world.frogs_remaining() == 6,"R resets health, poison, death counters, and enemies")
	await stand_by(game.world.frogs[0])
	player.position = Vector3(9,-0.3,0)
	await frames(2)
	check(game.state == "splash" and game.poison_deaths == 0,"A water fall takes one failure path while poisoned")
	await frames(65)
	check(game.health == 100 and not game.poisoned,"Water retry also cures poison and restores health")
	player.respawn(game.world.decoys[0].home_position+Vector3(0,0.95,0))
	await frames(12)
	check(game.health == 100 and not game.poisoned,"Red decoys remain sinking hazards and do not apply green-frog poison")
	game.show_title()
	game.select_level(2)
	game.start_run()
	await frames(8)
	check(game.world.chance_pads.size() == 7 and game.world.frogs.is_empty() and not player.has_bat,"Level 3 starts with seven yellow chance markers and no combat enemies")
	check(not game.ui.health_box.visible and game.health == 100 and not game.poisoned,"Entering Level 3 clears poison and hides combat-only health UI")
	var pad: LilyDecoyPad = game.world.chance_pads[0]
	check(pad.marker.is_chance and pad.marker.collision_layer == 0,"Yellow frogs are visible chance markers without solid footholds")
	game.world.chance_rng.seed = seed_for(false)
	await land_chance(pad)
	check(pad.resolved and not pad.collapsed and game.chance_rolls == 1,"A real first landing can roll the solid outcome")
	var rng_state: int = game.world.chance_rng.state
	await frames(60)
	key(KEY_SPACE)
	await frames(55)
	key(KEY_SPACE,false)
	check(not pad.collapsed and game.chance_rolls == 1 and game.world.chance_rng.state == rng_state,"Standing and re-landing do not reroll a solid yellow pad")
	check(game.health == 100 and not game.poisoned,"A yellow frog never poisons the player")
	game.start_run()
	await frames(8)
	check(not pad.resolved and game.chance_rolls == 0,"Restart clears yellow-pad outcomes and counters")
	game.world.chance_rng.seed = seed_for(true)
	await land_chance(pad)
	check(pad.collapsed and player.falling_through and game.chance_sinks == 1,"A real first landing can instead sink the yellow pad")
	game.pause()
	var pad_position := pad.position
	await frames(20)
	check(pad.position.is_equal_approx(pad_position),"Pause freezes a sinking yellow pad")
	game.resume()
	await frames(80)
	check(game.state == "playing" and game.falls == 1 and not pad.resolved and not pad.collapsed,"An unlucky fall retries with a fresh unresolved yellow pad")
	game.world.chance_rng.seed = seed_for(false)
	await land_chance(pad)
	check(not pad.collapsed and game.chance_rolls == 2,"A new attempt can produce a different yellow-pad outcome")
	# Exercise the production roll function with a repeatable native-only sample.
	var probe := RandomNumberGenerator.new()
	probe.seed = 2026
	var sinks := 0
	for i in 1000:
		pad.reset_trap()
		if pad.resolve_chance(probe):
			sinks += 1
	check(sinks>450 and sinks<550,"A 1000-roll sample is consistent with the 50/50 threshold (%d sinks)" % sinks)
	game.start_run()
	await frames(8)
	game.win()
	check(game.state == "won" and not game.ui.next_button.visible,"Level 3 victory offers replay without a nonexistent fourth level")
	game.show_title()
	game.select_level(1)
	game.start_run()
	for enemy in game.world.frogs:
		enemy.defeat()
	game.win()
	game.next_level()
	await frames(8)
	check(game.level_index == 2 and game.state == "playing" and game.world.chance_pads.size() == 7,"Level 2 victory transitions into a fresh Level 3")
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	await frames(8)
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute("user://lily_qa_health_luck.cfg")
	quit(0 if failures.is_empty() else 1)
