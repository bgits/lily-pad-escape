extends Node3D

const LevelScript = preload("res://scripts/level_data.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/ui.gd")
const ProfileScript = preload("res://scripts/profile.gd")
const LEVELS := ["res://levels/sunlit_lagoon.tres","res://levels/frog_river.tres","res://levels/lucky_lagoon.tres"]
var tide: ChasingWater
var tide_enabled := true
var level_index := 0
var level: LilyLevel
var world: LilyWorld
var player: LilyPlayer
var ui: LilyUI
var title_camera: Camera3D
var state := "title"
var previous_state := "playing"
var retry_timer := 0.0
var lock_grace := 0.0
var telemetry_timer := 0.0
var furthest_pad := 0
var falls := 0
var victories := 0
var sounds: Dictionary = {}
var level_music: AudioStreamPlayer
var level_music_tracks: Array[AudioStreamMP3] = []
var ready_to_pause := false
var run_seconds := 0.0
var telemetry_enabled := false
var hit_count := 0
var notice_time := 0.0
var decoy_trips := 0
var health := 100.0
var poisoned := false
var poison_source_pad := -1
var poison_deaths := 0
var chance_rolls := 0
var chance_sinks := 0
var profile := ProfileScript.new()
var secret_unlock_count := 0
var secret_notice_time := 0.0
var secret_saved := true
var customization_return := "title"
var outfit_saved := true
var fireflies_saved := true

func sync_fireflies() -> void:
	for fly in world.fireflies:
		fly.set_collected(profile.has_firefly(level_index,fly.index))
	ui.set_fireflies(profile,level_index,fireflies_saved)

func collect_nearby_fireflies() -> void:
	if state != "playing":
		return
	for fly in world.fireflies:
		if not fly.can_collect(player.global_position):
			continue
		fireflies_saved = profile.collect_firefly(level_index,fly.index)
		fly.set_collected(true)
		world.firefly_puff(fly.global_position)
		play_sound("firefly")
		ui.set_fireflies(profile,level_index,fireflies_saved)
		var count := profile.firefly_count(level_index)
		show_notice(("All three fireflies found!" if count == 3 else "Firefly found! %d / 3" % count) if fireflies_saved else "Firefly found! Saving unavailable.")

func reset_health() -> void:
	health = 100.0
	poisoned = false
	poison_source_pad = -1
	player.set_poisoned(false)
	ui.set_health(health,poisoned)

func poison_from_pad(index: int) -> void:
	if poisoned or state != "playing":
		return
	for frog in world.frogs:
		if frog.pad_index == index and frog.alive:
			poisoned = true
			poison_source_pad = index
			player.set_poisoned(true)
			show_notice("Poisoned!")
			return

func tick_poison(delta: float) -> void:
	if state != "playing" or not poisoned:
		return
	health = maxf(0,health-level.poison_damage_per_second*delta)
	ui.set_health(health,true)
	if health <= 0:
		poison_defeat()

func poison_defeat() -> void:
	if state != "playing" or health > 0:
		return
	state = "poison_defeat"
	poison_deaths += 1
	player.active = false
	player.clear_input()
	player.cancel_swing()
	player.velocity = Vector3.ZERO
	player.avatar.rotation.z = -0.95
	retry_timer = 1.2
	notice_time = 0.0
	world.poison_burst(player.global_position)
	play_sound("poison")
	ui.show_state(state)

func _ready() -> void:
	configure_input()
	level = load(LEVELS[level_index])
	world = WorldScript.new()
	add_child(world)
	world.build(level)
	player = PlayerScript.new()
	add_child(player)
	player.respawn(level.spawn)
	player.jumped.connect(func(): play_sound("jump"))
	player.stepped.connect(_on_player_stepped)
	player.swung.connect(func(): play_sound("swing"))
	player.bat_impact.connect(resolve_bat_hit)
	title_camera = Camera3D.new()
	add_child(title_camera)
	title_camera.position = Vector3(8,7,11)
	title_camera.look_at(Vector3(0,0.4,-7))
	title_camera.fov = 62
	title_camera.far = 220
	title_camera.current = true
	ui = UIScript.new()
	add_child(ui)
	ui.play_requested.connect(start_run)
	ui.resume_requested.connect(resume)
	ui.restart_requested.connect(start_run)
	ui.pause_requested.connect(pause)
	ui.home_requested.connect(show_title)
	ui.level_selected.connect(select_level)
	ui.next_requested.connect(next_level)
	ui.color_changed.connect(quick_color)
	ui.customize_requested.connect(open_customization)
	ui.wardrobe.saved.connect(save_outfit)
	ui.wardrobe.canceled.connect(close_customization)
	ui.mute_changed.connect(func(muted: bool): AudioServer.set_bus_mute(0,muted))
	ui.configure_level(level_index,level)
	profile.load_progress()
	sync_fireflies()
	ui.set_secret_unlocked(profile.secret_perch)
	player.avatar.apply_appearance(profile.outfit)
	ui.sync_outfit(profile.outfit)
	ui.name_input.text = profile.player_name
	for sound_name in ["jump","splash","victory","swing","bonk","poison","firefly"]:
		var sound := AudioStreamPlayer.new()
		sound.stream = load("res://assets/audio/%s.wav" % sound_name)
		sound.volume_db = -12.0
		add_child(sound)
		sounds[sound_name] = sound
	level_music = AudioStreamPlayer.new()
	for music_path in ["res://assets/audio/platformer_rush.mp3", "res://assets/audio/bouncing_beat_pt2.mp3", "res://assets/audio/lily_pad_rush.mp3"]:
		var music_stream: AudioStreamMP3 = load(music_path).duplicate()
		music_stream.loop = true
		level_music_tracks.append(music_stream)
	level_music.stream = level_music_tracks[0]
	level_music.volume_db = -12.0
	add_child(level_music)
	if OS.has_feature("web"):
		telemetry_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa')"))
	tide = ChasingWater.new()
	add_child(tide)
	tide.make_rear_view(ui.hud)
	tide.visible = false
	ready_to_pause = DisplayServer.get_name() != "headless"

func quick_color(color: Color) -> void:
	var index := LilyAppearance.COLORS.top_color.find(color.to_html(false))
	if index < 0 or (index == 3 and not profile.secret_perch):
		return
	profile.outfit.top_color = index
	if index == 3:
		profile.outfit.top_style = 0
	player.avatar.apply_appearance(profile.outfit)
	profile.player_name = ui.name_input.text
	outfit_saved = profile.save_customization()

func open_customization() -> void:
	if state not in ["title","paused"]:
		return
	customization_return = state
	world.set_motion_paused(true)
	state = "customizing"
	player.active = false
	player.clear_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_state(state)
	ui.wardrobe.open_editor(profile.outfit,ui.name_input.text,profile.secret_perch)

func save_outfit(outfit: Dictionary, player_name: String) -> void:
	if state != "customizing":
		return
	profile.outfit = LilyAppearance.sanitize(outfit,profile.secret_perch)
	profile.player_name = LilyProfile.clean_name(player_name)
	outfit_saved = profile.save_customization()
	player.avatar.apply_appearance(profile.outfit)
	ui.sync_outfit(profile.outfit)
	ui.name_input.text = profile.player_name
	ui.show_profile_saved(outfit_saved)
	close_customization()

func close_customization() -> void:
	if state != "customizing":
		return
	ui.wardrobe.close_editor()
	state = customization_return
	world.set_motion_paused(state == "paused")
	ui.show_state(state,player.falling_through)
	get_viewport().gui_release_focus()
	if state == "title":
		ui.customize_button.grab_focus()
	else:
		ui.pause_customize_button.grab_focus()

func configure_input() -> void:
	var map := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_forward":[KEY_W,KEY_UP],"move_back":[KEY_S,KEY_DOWN],"jump":[KEY_SPACE],"restart":[KEY_R],"pause":[KEY_ESCAPE],"attack":[KEY_F]}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack",click)

func select_level(index: int) -> void:
	if state != "title" or index < 0 or index >= LEVELS.size():
		return
	load_level(index)
	show_title()

func load_level(index: int) -> void:
	player.active = false
	level_index = index
	level = load(LEVELS[index])
	remove_child(world)
	world.queue_free()
	world = WorldScript.new()
	add_child(world)
	world.build(level)
	player.has_bat = level.has_bat
	player.avatar.equip_bat(level.has_bat)
	ui.configure_level(level_index,level)
	sync_fireflies()

func next_level() -> void:
	if state != "won" or level_index >= LEVELS.size()-1:
		return
	load_level(level_index+1)
	start_run()

func start_run() -> void:
	profile.player_name = ui.name_input.text
	outfit_saved = profile.save_customization()
	stop_sounds()
	tide.reset()
	tide.speed = 1.35 if level_index == 1 else 1.8
	tide.visible = tide_enabled
	level_music.stop()
	level_music.stream_paused = false
	if level_index < level_music_tracks.size():
		level_music.stream = level_music_tracks[level_index]
		level_music.play()
	player.respawn(level.spawn)
	player.jump_count = 0
	player.swing_count = 0
	hit_count = 0
	decoy_trips = 0
	poison_deaths = 0
	chance_rolls = 0
	chance_sinks = 0
	furthest_pad = 0
	falls = 0
	victories = 0
	run_seconds = 0.0
	retry_timer = 0.0
	notice_time = 0.0
	secret_notice_time = 0.0
	reset_health()
	world.clear_particles()
	world.reset_frogs()
	world.reset_decoys()
	world.reset_motion()
	sync_fireflies()
	ui.set_progress(0)
	update_combat_hud()
	state = "playing"
	player.active = true
	player.visible = true
	player.camera.current = true
	ui.show_state(state)
	capture_mouse()

func capture_mouse() -> void:
	lock_grace = 0.45
	player.look_delay = 0.2
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().gui_release_focus()

func show_title() -> void:
	tide.visible = false
	stop_sounds()
	level_music.stop()
	state = "title"
	world.set_motion_paused(false)
	player.active = false
	player.visible = true
	player.respawn(level.spawn)
	reset_health()
	world.clear_particles()
	world.reset_decoys()
	title_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_state(state)

func pause() -> void:
	if state not in ["playing","splash","poison_defeat"]:
		return
	previous_state = state
	state = "paused"
	level_music.stream_paused = true
	world.set_motion_paused(true)
	player.active = false
	player.clear_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_state(state)

func resume() -> void:
	if state != "paused":
		return
	state = previous_state
	level_music.stream_paused = false
	world.set_motion_paused(false)
	player.active = state == "playing"
	player.clear_input()
	ui.show_state(state,player.falling_through)
	capture_mouse()

func fail() -> void:
	if state != "playing":
		return
	state = "splash"
	falls += 1
	player.active = false
	player.visible = false
	player.shadow.visible = false
	player.clear_input()
	player.cancel_swing()
	retry_timer = 0.9
	world.splash(player.global_position)
	play_sound("splash")
	ui.show_state(state,player.falling_through)

func win() -> void:
	if state != "playing" or world.frogs_remaining() > 0:
		return
	state = "won"
	tide.visible = false
	level_music.stop()
	world.set_motion_paused(true)
	victories += 1
	player.active = false
	player.clear_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.celebrate(level.flag_position)
	play_sound("victory")
	var next_title: String = load(LEVELS[level_index+1]).title if level_index < LEVELS.size()-1 else ""
	ui.set_victory(ui.name_input.text.strip_edges(),next_title)
	ui.show_state(state)

func _unhandled_input(event: InputEvent) -> void:
	if state == "customizing":
		if event.is_action_pressed("pause"):
			close_customization()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and state == "playing" and not level.has_bat:
		pause()
	if event.is_action_pressed("pause") and not event.is_echo():
		pause()
	if event.is_action_pressed("restart") and not event.is_echo() and state in ["playing","splash","poison_defeat"]:
		start_run()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and ready_to_pause:
		pause()

func _on_player_stepped(delta: float) -> void:
	if state != "playing":
		return
	run_seconds += delta
	if tide_enabled:
		tide.advance(delta,player.position)
		tide.update_rear_view(player.position)
		ui.tide_label.text = "Water moves in %d…" % ceili(tide.grace) if tide.grace > 0 else "Chasing water  ·  %d m behind" % maxi(0,ceili(tide.front_z-player.position.z))
		if tide.has_caught(player.position):
			fail()
			ui.toast.text = "The water caught you! Keep moving."
			return
	if player.global_position.y < level.water_height - 0.18 or player.global_position.y < -10 or Vector2(player.position.x,player.position.z).length() > 120:
		fail()
		return
	if player.is_on_floor():
		for i in player.get_slide_collision_count():
			var collision := player.get_slide_collision(i)
			var body := collision.get_collider()
			if not is_instance_valid(body) or collision.get_normal().y < 0.7:
				continue
			if body.has_meta("secret_perch"):
				unlock_secret_perch()
			if body is LilyDecoyPad:
				if body.is_chance:
					if not body.resolved:
						chance_rolls += 1
						if body.resolve_chance(world.chance_rng):
							chance_sinks += 1
							player.drop_through()
							show_notice("Unlucky! This yellow pad sinks.")
						else:
							show_notice("Lucky! This pad stays solid.")
						ui.set_chance_progress(chance_pads_held(),world.chance_pads.size())
					if body.collapsed:
						return
				else:
					if body.collapse():
						decoy_trips += 1
						player.drop_through()
						show_notice("The pad is sinking!")
					return
			if body.has_meta("pad_index"):
				var pad_index := int(body.get_meta("pad_index"))
				furthest_pad = maxi(furthest_pad,pad_index)
				ui.set_progress(furthest_pad)
				poison_from_pad(pad_index)
			elif body is LilyFrog and body.alive and not body.is_decoy and not body.is_chance:
				poison_from_pad(body.pad_index)
			if body.has_meta("finish") and player.global_position.distance_to(level.flag_position) < 1.65:
				if world.frogs_remaining() == 0:
					win()
				else:
					show_notice("The crossing isn't clear yet.")
	collect_nearby_fireflies()
	tick_poison(delta)

func unlock_secret_perch() -> void:
	if profile.secret_perch or state != "playing":
		return
	secret_saved = profile.unlock_secret()
	secret_unlock_count += 1
	secret_notice_time = 5.0
	ui.set_secret_unlocked(true)
	ui.select_color(3)
	ui.show_secret_reward(secret_saved)
	world.celebrate(player.global_position)
	play_sound("victory")

func show_notice(message: String) -> void:
	notice_time = 1.6
	ui.toast.text = message

func update_combat_hud() -> void:
	ui.set_frogs(level.frog_pads.size()-world.frogs_remaining(),level.frog_pads.size())
	if not world.chance_pads.is_empty():
		ui.set_chance_progress(chance_pads_held(),world.chance_pads.size())

func chance_pads_held() -> int:
	var count := 0
	for pad in world.chance_pads:
		if pad.resolved and not pad.collapsed:
			count += 1
	return count

func bat_reaches(target: Vector3) -> bool:
	var offset := target - player.global_position
	var horizontal := Vector3(offset.x,0,offset.z)
	if horizontal.length() > 2.3 or absf(offset.y) > 1.1:
		return false
	return horizontal.length() <= 0.1 or player.attack_direction.dot(horizontal.normalized()) >= 0.20

func resolve_bat_hit() -> void:
	if state != "playing" or player.position.y < level.water_height or not player.has_bat:
		return
	var hit := false
	for frog in world.frogs:
		if not frog.alive or not bat_reaches(frog.global_position):
			continue
		frog.defeat()
		world.frog_puff(frog.global_position)
		hit_count += 1
		hit = true
	if hit:
		reset_health()
		play_sound("bonk")
		update_combat_hud()
		world.update_goal()
		if world.frogs_remaining() == 0:
			show_notice("100% health! The crossing is clear.")
		else:
			show_notice("Frog defeated! Health restored to 100%.")
	else:
		show_notice("Miss!")
func _physics_process(delta: float) -> void:
	if state in ["playing","splash","poison_defeat","title"]:
		world.advance_exploration(delta)
	if state in ["playing","splash","poison_defeat"]:
		world.advance_decoys(delta)
	if state == "playing":
		secret_notice_time = maxf(0,secret_notice_time-delta)
		world.animate_frogs(delta,player.global_position)
		if notice_time > 0:
			notice_time = maxf(0,notice_time-delta)
			if notice_time == 0:
				ui.toast.text = ""
	elif state == "title":
		world.animate_frogs(delta,level.spawn)
	if state in ["splash","poison_defeat"]:
		retry_timer -= delta
		if retry_timer <= 0:
			world.reset_frogs()
			hit_count = 0
			tide.reset()
			world.reset_decoys()
			world.reset_motion()
			player.respawn(level.spawn)
			reset_health()
			player.visible = true
			player.active = true
			furthest_pad = 0
			ui.set_progress(0)
			update_combat_hud()
			state = "playing"
			ui.show_state(state)

func _process(delta: float) -> void:
	ui.secret_popup.visible = state == "playing" and secret_notice_time > 0
	if state not in ["paused","customizing"]:
		world.animate(delta)
	if state == "title":
		player.avatar.animate(delta,0,true,0)
	lock_grace = maxf(0,lock_grace-delta)
	telemetry_timer += delta
	if telemetry_timer > 0.10:
		telemetry_timer = 0.0
		if OS.has_feature("web"):
			if state in ["playing","splash","poison_defeat"] and lock_grace <= 0:
				var locked: bool = bool(JavaScriptBridge.eval("document.pointerLockElement !== null && document.hasFocus()"))
				if not locked:
					pause()
			if telemetry_enabled:
				JavaScriptBridge.eval("window.lilyPadState = " + JSON.stringify(debug_snapshot()) + ";")
		elif DisplayServer.get_name() != "headless" and state in ["playing","splash","poison_defeat"] and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and lock_grace <= 0:
			pause()

func play_sound(sound_name: String) -> void:
	if sounds.has(sound_name):
		sounds[sound_name].play()

func stop_sounds() -> void:
	for sound in sounds.values():
		sound.stop()

func debug_snapshot() -> Dictionary:
	var firefly_data: Array[Dictionary] = []
	for fly in world.fireflies:
		firefly_data.append({"id":fly.index,"collected":fly.collected,"position":[fly.global_position.x,fly.global_position.y,fly.global_position.z]})
	var drift_data: Array[Dictionary] = []
	for pad in world.drifting_pads:
		drift_data.append({"position":[pad.position.x,pad.position.y,pad.position.z],"home":[pad.home.x,pad.home.y,pad.home.z],"travel":[pad.travel.x,pad.travel.y,pad.travel.z],"clock":pad.clock})
	var bypass_data: Array[Dictionary] = []
	for pad in world.bypass_pads:
		bypass_data.append({"position":[pad.position.x,level.surface_height,pad.position.z],"solid":pad.collision_layer == 1})
	var perch_data: Array[Dictionary] = []
	for perch in world.secret_perches:
		perch_data.append({"position":[perch.position.x,perch.get_meta("top"),perch.position.z]})
	var frog_data: Array[Dictionary] = []
	var decoy_data: Array[Dictionary] = []
	var chance_data: Array[Dictionary] = []
	for pad in world.chance_pads:
		chance_data.append({"pad":pad.get_meta("pad_index"),"resolved":pad.resolved,"collapsed":pad.collapsed,"position":[pad.position.x,pad.position.y,pad.position.z]})
	for pad in world.decoys:
		decoy_data.append({"position":[pad.position.x,pad.position.y,pad.position.z],"collapsed":pad.collapsed,"red_frog":pad.marker.is_decoy})
	for frog in world.frogs:
		frog_data.append({"pad":frog.pad_index,"alive":frog.alive,"behavior":frog.behavior,"clock":frog.clock,"telegraph":is_instance_valid(frog.landing_marker) and frog.landing_marker.visible,"position":[frog.position.x,frog.position.y,frog.position.z]})
	return {"tide_front":tide.front_z,"tide_grace":tide.grace,"fireflies":firefly_data,"firefly_masks":profile.firefly_masks,"fireflies_saved":fireflies_saved,"drifting_pads":drift_data,"bypass_pads":bypass_data,"outfit":profile.outfit,"outfit_saved":outfit_saved,"wardrobe":ui.wardrobe.debug_snapshot(),"secret_unlocked":profile.secret_perch,"secret_unlock_count":secret_unlock_count,"secret_saved":secret_saved,"secret_notice_time":secret_notice_time,"secret_perches":perch_data,"state":state,"chance_pads":chance_data,"chance_rolls":chance_rolls,"chance_sinks":chance_sinks,"health":health,"poisoned":poisoned,"poison_source_pad":poison_source_pad,"poison_deaths":poison_deaths,"level":level_index+1,"has_bat":player.has_bat,"swings":player.swing_count,"hits":hit_count,"frogs_remaining":world.frogs_remaining(),"frogs":frog_data,"decoys":decoy_data,"decoy_trips":decoy_trips,"falling_through":player.falling_through,"swing_remaining":player.swing_remaining,"position":[player.position.x,player.position.y,player.position.z],"velocity":[player.velocity.x,player.velocity.y,player.velocity.z],"grounded":player.is_on_floor(),"pad":furthest_pad,"falls":falls,"victories":victories,"jumps":player.jump_count,"yaw":player.yaw,"avatar_yaw":player.avatar.rotation.y,"attack_direction":[player.attack_direction.x,player.attack_direction.y,player.attack_direction.z],"pitch":player.pitch,"camera":[player.camera.global_position.x,player.camera.global_position.y,player.camera.global_position.z],"arm_length":player.arm.get_hit_length(),"fps":Engine.get_frames_per_second(),"seconds":run_seconds,"muted":AudioServer.is_bus_mute(0),"player_name":ui.name_input.text,"name_focused":ui.name_input.has_focus(),"hoodie":player.avatar.hoodie.albedo_color.to_html(false)}
