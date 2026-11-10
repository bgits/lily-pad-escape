class_name LilyDuel
extends Node3D

# Midnight Pond match rules: owns the arena, both players, the Queen, the frogs, the loose
# fireflies, the HUD and the sounds, and advances all of them from its own physics tick.

signal exit_requested

const STAGES := ["countdown", "dusk", "midnight", "flood"]
const ACTIVE_PHASES := ["dusk", "midnight", "flood", "sudden_death"]
const CLOCK_PHASES := ["dusk", "midnight", "flood"]
const SOUND_NAMES := ["jump", "splash", "victory", "swing", "bonk", "poison", "firefly"]
const FIREFLY_HOVER := 0.9

# --- tunables (spec section 6) -----------------------------------------------
var countdown_seconds := 3.0
var dusk_seconds := 60.0
var midnight_seconds := 60.0
var flood_seconds := 60.0
var spawn_interval := 1.6
var flood_spawn_interval := 1.0
var max_loose := 7
var poison_per_second := 15.0
var respawn_delay := 1.2
var middle_warning := 0.9
var middle_down := 4.0
var yellow_down := 5.0
var flood_warning := 1.5
var knockback_speed := 9.0
var sudden_death_knockback_scale := 1.6
var queen_speed_scale := 0.85
var sudden_death_freeze := 2.0
var yellow_leave_grace := 0.25
var frog_cone_dot := 0.5
var frog_range := 10.0
var last_way_at := 31.0
var hop_seconds := 0.6
var water_kill_margin := 0.18
var respawn_protection := 1.5
# Graphics pass: how long the match freezes on a bat hit (match time does not advance).
var hit_stop_seconds := 0.07
# The collision rim of a pad reaches a little past its nominal radius.
var rim_margin := 0.35
# Dropped fireflies stay near where they fell (edge distance to a pad), never across the pond.
var scatter_range := 4.5
var firefly_scale := 1.6
# Seconds after the flood starts; every entry sinks its pads with trigger_sink(flood_warning, -1).
var flood_schedule: Array[Dictionary] = [
	{"at": 0.0, "ids": [12, 18]},
	{"at": 8.0, "ids": [11, 13, 17, 19]},
	{"at": 20.0, "ids": [3, 7]},
	{"at": 30.0, "ids": [2, 4, 6, 8]},
	{"at": 31.0, "ids": [10, 14, 16, 20]},
	{"at": 52.0, "ids": [1, 5, 9, 15]},
]
var rng := RandomNumberGenerator.new()
# -1: roll with rng, 0: a fresh yellow pad always holds, 1: it always sinks.
var yellow_roll_override := -1

# --- state -----------------------------------------------------------------------
var arena: LilyDuelArena
var players: Array[LilyDuelPlayer] = []
var hud: LilyDuelHud
var queen: LilyDuelQueen
var frogs: Array[LilyDuelFrog] = []
var loose_fireflies: Array[LilyFirefly] = []
var phase := "countdown"
var elapsed := 0.0
var paused := false
var scores: Array[int] = [0, 0]
var winner := -1
var time_left: float:
	get:
		return total_seconds() - elapsed

var names: Array[String] = ["P1", "P2"]
var sounds: Dictionary = {}
var stage := 0
var countdown_clock := 0.0
var hop_left := 0.0
var spawn_clock := 0.0
var fly_counter := 0
var sudden_freeze_left := 0.0
var flood_applied: Dictionary = {}
var flooded_pads: Dictionary = {}
var last_way_shown := false
var yellow_holds: Dictionary = {}
# pad id -> index of the player it held for; a spent pad only sinks under the other player.
var yellow_spent_by: Dictionary = {}
var pending_impacts: Array[LilyDuelPlayer] = []
var out: Array[bool] = [false, false]
var respawn_left: Array[float] = [0.0, 0.0]
var paused_active: Array[bool] = [false, false]
var closing := false
var begun := false
var hud_time_key := -1
var hud_phase_key := ""
var hud_count_key := ""
var hud_scores_key := ""
var hud_health_key := ["", ""]
var hud_queen_key := -2
# Hit-stop: while freeze_left > 0 the duel's own tick is skipped and the players that were
# active are held inactive (their velocity and timers stay exactly as the hit left them).
var freeze_left := 0.0
var freeze_held: Array[bool] = [false, false]
# A hit resolved inside a tick holds each player once they have finished that tick.
var hold_pending: Array[bool] = [false, false]
# True during resolve_impacts() inside a physics tick (the players' own tick is still to come).
var resolving := false
var look_phase := ""
var was_grounded: Array[bool] = [false, false]
var land_cooldown: Array[float] = [0.0, 0.0]
var reflection_lights: Array = []
var reflection_pool: Array[Dictionary] = []
var near_dist := PackedFloat32Array()
var near_index := PackedInt32Array()

func total_seconds() -> float:
	return dusk_seconds + midnight_seconds + flood_seconds

func flood_start() -> float:
	return dusk_seconds + midnight_seconds

# --- construction --------------------------------------------------------------------

func begin(outfit: Dictionary, p1_name: String) -> void:
	rng.randomize()
	arena = LilyDuelArena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()
	arena.camera.make_current()
	LilyDuelPlayer.configure_input()
	var cleaned := p1_name.strip_edges()
	names = [cleaned if cleaned != "" else "P1", "P2"]
	var second := outfit.duplicate()
	second["top_color"] = 1 if int(outfit.get("top_color", 0)) == 2 else 2
	for i in 2:
		var player := LilyDuelPlayer.new()
		player.name = "Player%d" % (i + 1)
		player.setup(i, outfit if i == 0 else second)
		add_child(player)
		player.jumped.connect(on_player_jumped)
		player.swung.connect(on_player_swung)
		player.bat_impact.connect(on_bat_impact)
		player.stepped.connect(on_player_stepped)
		players.append(player)
	queen = LilyDuelQueen.new()
	queen.name = "Queen"
	add_child(queen)
	hud = LilyDuelHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.set_names(names[0], names[1])
	hud.resume_requested.connect(resume)
	hud.rematch_requested.connect(start_match)
	hud.exit_requested.connect(func(): exit_requested.emit())
	for sound_name in SOUND_NAMES:
		var sound := AudioStreamPlayer.new()
		sound.name = "Sound_" + sound_name
		sound.stream = load("res://assets/audio/%s.wav" % sound_name)
		sound.volume_db = -12.0
		add_child(sound)
		sounds[sound_name] = sound
	for pad in arena.pads:
		pad.sank.connect(on_pad_sank)
		pad.rose.connect(on_pad_rose)
	for i in LilyDuelWater.MAX_REFLECTIONS:
		reflection_pool.append({"position": Vector3.ZERO, "color": Color.WHITE, "energy": 1.0})
	near_dist.resize(LilyDuelWater.MAX_REFLECTIONS)
	near_index.resize(LilyDuelWater.MAX_REFLECTIONS)
	begun = true
	start_match()

func _exit_tree() -> void:
	closing = true
	for player in players:
		if is_instance_valid(player):
			player.clear_input()

func start_match() -> void:
	if not begun or closing:
		return
	cancel_hit_stop()
	for frog in frogs:
		if is_instance_valid(frog):
			frog.free()
	frogs.clear()
	for fly in loose_fireflies:
		if is_instance_valid(fly):
			fly.free()
	loose_fireflies.clear()
	queen.hide_queen()
	arena.reset_arena()
	scores = [0, 0]
	winner = -1
	elapsed = 0.0
	phase = "countdown"
	stage = 0
	paused = false
	countdown_clock = 0.0
	hop_left = 0.0
	spawn_clock = 0.0
	sudden_freeze_left = 0.0
	flood_applied.clear()
	flooded_pads.clear()
	yellow_holds.clear()
	yellow_spent_by.clear()
	pending_impacts.clear()
	last_way_shown = false
	out = [false, false]
	respawn_left = [0.0, 0.0]
	paused_active = [false, false]
	was_grounded = [false, false]
	land_cooldown = [0.0, 0.0]
	look_phase = phase
	arena.set_phase_look(phase, true)
	for i in 2:
		var player := players[i]
		player.visible = true
		player.active = false
		player.clear_input()
		player.set_carried(0)
		player.set_queen(false)
		player.speed_scale = 1.0
		player.respawn(arena.spawn_point(i), toward_centre(i))
		arena.set_lantern_score(i, 0)
	hud.hide_result()
	hud.show_pause(false)
	hud.show_toast("")
	hud.show_countdown("")
	hud_time_key = -1
	hud_phase_key = ""
	hud_count_key = ""
	hud_scores_key = ""
	hud_health_key = ["", ""]
	hud_queen_key = -2
	refresh_hud()

func toward_centre(index: int) -> Vector3:
	return Vector3.RIGHT if index == 0 else Vector3.LEFT

# --- input, pause --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not begun or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_R and (paused or phase == "over"):
		start_match()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and begun and not closing:
		if DisplayServer.get_name() != "headless" and not paused and phase != "over":
			toggle_pause()

func toggle_pause() -> void:
	if not begun or phase == "over":
		return
	if paused:
		paused = false
		for i in 2:
			players[i].active = paused_active[i]
		hud.show_pause(false)
	else:
		paused = true
		for i in 2:
			paused_active[i] = players[i].active
			players[i].active = false
			players[i].clear_input()
		hud.show_pause(true)

func resume() -> void:
	if paused:
		toggle_pause()

func set_elapsed(seconds: float) -> void:
	elapsed = clampf(seconds, 0.0, total_seconds())

# --- main loop -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not begun or paused:
		return
	sync_look()
	update_water_level()
	update_reflections()
	arena.animate(delta)
	hud.advance(delta)

func _physics_process(delta: float) -> void:
	if not begun or paused:
		return
	if freeze_left > 0.0:
		freeze_left -= delta
		hold_waiting_players()
		if freeze_left > 0.0:
			refresh_hud()
			return
		end_hit_stop()
	resolving = true
	resolve_impacts()
	resolving = false
	if freeze_left > 0.0:
		# A bat hit landed on this tick: the rest of it belongs to the freeze.
		refresh_hud()
		return
	arena.advance(delta)
	for frog in frogs:
		if is_instance_valid(frog):
			frog.advance(delta)
	queen.advance(delta)
	for fly in loose_fireflies:
		if is_instance_valid(fly):
			fly.advance(delta)
	tick_respawns(delta)
	tick_clock(delta)
	tick_hold_and_queen(delta)
	refresh_hud()

func tick_respawns(delta: float) -> void:
	for i in 2:
		if out[i]:
			respawn_left[i] -= delta
			if respawn_left[i] <= 0.0 and phase != "over":
				respawn_player(i)

func respawn_player(index: int) -> void:
	var player := players[index]
	out[index] = false
	release_player(index)
	was_grounded[index] = false
	player.visible = true
	player.respawn(arena.spawn_point(index), toward_centre(index))
	player.speed_scale = 1.0
	# Brief protection so nobody can be batted off their lantern pad as they reappear.
	player.invulnerable_remaining = respawn_protection
	player.active = phase in ACTIVE_PHASES and sudden_freeze_left <= 0.0

func tick_clock(delta: float) -> void:
	if hop_left > 0.0:
		hop_left -= delta
		if hop_left <= 0.0:
			hop_left = 0.0
			set_countdown_text("")
	match phase:
		"countdown":
			countdown_clock += delta
			if elapsed > 0.0 or countdown_clock >= countdown_seconds:
				finish_countdown()
			else:
				set_countdown_text(str(maxi(1, ceili(countdown_seconds - countdown_clock))))
		"dusk", "midnight", "flood":
			elapsed = minf(elapsed + delta, total_seconds())
			sync_stages()
			apply_flood_steps()
			tick_spawner(delta)
			if stage >= 3 and elapsed >= total_seconds():
				finish_regulation()
		"sudden_death":
			if sudden_freeze_left > 0.0:
				sudden_freeze_left -= delta
				if sudden_freeze_left <= 0.0:
					sudden_freeze_left = 0.0
					for i in 2:
						if not out[i]:
							players[i].active = true
					hop_left = hop_seconds
					set_countdown_text("Hop!")

func set_countdown_text(text: String) -> void:
	if text != hud_count_key:
		hud_count_key = text
		hud.show_countdown(text)

func finish_countdown() -> void:
	for i in 2:
		if not out[i]:
			players[i].active = true
	hop_left = hop_seconds
	set_countdown_text("Hop!")
	stage = 0
	sync_stages()

func sync_stages() -> void:
	var target := 1
	if elapsed >= flood_start():
		target = 3
	elif elapsed >= dusk_seconds:
		target = 2
	while stage < target:
		stage += 1
		enter_stage(stage)
	phase = STAGES[target]

func enter_stage(which: int) -> void:
	phase = STAGES[which]
	match which:
		1:
			spawn_clock = 0.0
			hud.show_toast("Gather fireflies. Bank them at your lantern!", 3.5)
		2:
			arena.open_lotus()
			queen.appear(arena.queen_perch())
			for pad_id in [12, 18]:
				var frog := LilyDuelFrog.new()
				frog.name = "Frog%d" % pad_id
				add_child(frog)
				frog.landed.connect(on_frog_landed)
				frog.place(arena.pads[pad_id])
				frogs.append(frog)
			hud.show_toast("Midnight. The Queen wakes and the frogs stir.", 3.5)
		3:
			spawn_clock = 0.0
			hud.show_toast("The pond is flooding!", 3.0)

func apply_flood_steps() -> void:
	if stage < 3:
		return
	var into_flood := elapsed - flood_start()
	for i in flood_schedule.size():
		if flood_applied.has(i):
			continue
		var step: Dictionary = flood_schedule[i]
		if float(step.get("at", 0.0)) > into_flood:
			continue
		flood_applied[i] = true
		for pad_id in step.get("ids", []):
			if int(pad_id) < 0 or int(pad_id) >= arena.pads.size():
				continue
			var pad := arena.pads[int(pad_id)]
			if pad.trigger_sink(flood_warning, -1.0):
				flooded_pads[pad.pad_id] = true
				if pad.state in ["sunk", "rising", "gone"]:
					relocate_fireflies(pad)
					hop_frogs_off(pad)
	if not last_way_shown and into_flood >= last_way_at:
		last_way_shown = true
		hud.show_toast("Last way home: the yellow pads!", 3.5)

func finish_regulation() -> void:
	if scores[0] != scores[1]:
		end_match(0 if scores[0] > scores[1] else 1, false)
	else:
		enter_sudden_death()

func enter_sudden_death() -> void:
	phase = "sudden_death"
	cancel_hit_stop()
	sync_look()
	for fly in loose_fireflies:
		if is_instance_valid(fly):
			fly.free()
	loose_fireflies.clear()
	for frog in frogs:
		if is_instance_valid(frog):
			frog.free()
	frogs.clear()
	queen.hide_queen()
	yellow_holds.clear()
	pending_impacts.clear()
	for i in 2:
		var player := players[i]
		out[i] = false
		player.visible = true
		player.set_queen(false)
		player.speed_scale = 1.0
		player.active = false
		player.clear_input()
		player.set_carried(0)
		var x := -1.3 if i == 0 else 1.3
		player.respawn(Vector3(x, LilyDuelArena.SURFACE_HEIGHT + 0.08, 0.0), toward_centre(i))
	sudden_freeze_left = maxf(sudden_death_freeze, 0.001)
	hud.show_toast("Sudden death! First one in the water loses.", 3.0)

func end_match(winner_index: int, tie_break: bool) -> void:
	phase = "over"
	cancel_hit_stop()
	winner = winner_index
	paused = false
	for player in players:
		player.active = false
		player.clear_input()
	var score_text := "%d – %d" % [scores[0], scores[1]]
	var detail := ("Sudden death · " + score_text) if tie_break else score_text
	hud.show_pause(false)
	hud.show_toast("")
	set_countdown_text("")
	refresh_hud()
	sync_look()
	hud.show_result("%s wins!" % names[winner_index], detail)
	var at := players[winner_index].global_position
	arena.celebrate(at)
	play_sound("victory")

# --- fireflies -----------------------------------------------------------------------------

func pad_of_point(point: Vector3) -> LilyDuelPad:
	var pad := arena.pad_at(point)
	if pad != null:
		return pad
	var near := arena.nearest_standable(point, 1, true, true)
	return near[0] if not near.is_empty() else null

func tick_spawner(delta: float) -> void:
	if not phase in CLOCK_PHASES:
		return
	spawn_clock += delta
	var interval := flood_spawn_interval if phase == "flood" else spawn_interval
	if spawn_clock < interval:
		return
	spawn_clock = 0.0
	if loose_fireflies.size() >= max_loose:
		return
	var occupied: Dictionary = {}
	for fly in loose_fireflies:
		if is_instance_valid(fly):
			var pad := pad_of_point(fly.global_position)
			if pad != null:
				occupied[pad.pad_id] = true
	var choices: Array[LilyDuelPad] = []
	var weights: Array[float] = []
	var total := 0.0
	for pad in arena.pads:
		if pad.state != "solid" or pad.kind == LilyDuelPad.Kind.HOME or occupied.has(pad.pad_id):
			continue
		var weight := 1.0
		if pad.kind == LilyDuelPad.Kind.MIDDLE:
			weight = 3.0
		elif pad.kind == LilyDuelPad.Kind.YELLOW:
			weight = 2.0
		choices.append(pad)
		weights.append(weight)
		total += weight
	if choices.is_empty():
		return
	var roll := rng.randf() * total
	for i in choices.size():
		roll -= weights[i]
		if roll <= 0.0 or i == choices.size() - 1:
			spawn_firefly(choices[i])
			return

func spawn_firefly(pad: LilyDuelPad, at := Vector3.INF) -> LilyFirefly:
	if not begun or closing:
		return null
	var point := at
	if not at.is_finite():
		if pad == null:
			return null
		point = pad.random_point(rng, 0.6) + Vector3.UP * FIREFLY_HOVER
	var fly := LilyFirefly.new()
	fly.index = fly_counter
	fly_counter += 1
	add_child(fly)
	# Larger than in the single-player levels: they must read from the far camera.
	fly.scale = Vector3.ONE * firefly_scale
	# Over-drive the body colour so it clamps to white in the LDR renderer and blooms.
	if fly.visual != null and fly.visual.get_child_count() > 0:
		var body := fly.visual.get_child(0) as MeshInstance3D
		if body != null and body.material_override is StandardMaterial3D:
			var c: Color = (body.material_override as StandardMaterial3D).albedo_color
			(body.material_override as StandardMaterial3D).albedo_color = Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 1.0)
	fly.global_position = point
	loose_fireflies.append(fly)
	return fly

func scatter_fireflies(origin: Vector3, count: int) -> void:
	if count <= 0:
		return
	var near := arena.nearest_standable(origin, 3, false, true)
	if near.is_empty():
		near = arena.nearest_standable(origin, 1, true, true)
	if near.is_empty():
		return
	var close: Array[LilyDuelPad] = [near[0]]
	for i in range(1, near.size()):
		if edge_distance(near[i], origin) <= scatter_range:
			close.append(near[i])
	for i in count:
		spawn_firefly(close[rng.randi() % close.size()])

func edge_distance(pad: LilyDuelPad, point: Vector3) -> float:
	return maxf(0.0, Vector2(point.x - pad.position.x, point.z - pad.position.z).length() - pad.radius)

func relocate_fireflies(pad: LilyDuelPad) -> void:
	for fly in loose_fireflies:
		if not is_instance_valid(fly) or not pad.contains_xz(fly.global_position):
			continue
		var near := arena.nearest_standable(fly.global_position, 1, false, true)
		if near.is_empty():
			near = arena.nearest_standable(fly.global_position, 1, true, true)
		if not near.is_empty():
			fly.global_position = near[0].random_point(rng, 0.6) + Vector3.UP * FIREFLY_HOVER

func collect_fireflies(player: LilyDuelPlayer) -> void:
	var i := loose_fireflies.size() - 1
	while i >= 0:
		var fly := loose_fireflies[i]
		if not is_instance_valid(fly):
			loose_fireflies.remove_at(i)
		elif fly.can_collect(player.global_position):
			loose_fireflies.remove_at(i)
			arena.firefly_puff(fly.global_position)
			fly.set_collected(true)
			fly.free()
			player.set_carried(player.carried + 1)
			play_sound("firefly")
		i -= 1

# --- stepping rules -------------------------------------------------------------------------

func grounded_pad(player: LilyDuelPlayer) -> LilyDuelPad:
	if not player.is_on_floor() or player.falling_through:
		return null
	var point := player.global_position
	var pad := arena.pad_at(point)
	if pad != null:
		return pad
	# Standing on the rim, just past the nominal radius, still counts as standing on the pad.
	var best: LilyDuelPad = null
	var best_over := rim_margin
	for candidate in arena.pads:
		if not candidate.is_standable():
			continue
		var over := Vector2(point.x - candidate.position.x, point.z - candidate.position.z).length() - candidate.radius
		if over <= best_over:
			best = candidate
			best_over = over
	return best

func on_player_stepped(player: LilyDuelPlayer, delta: float) -> void:
	if is_instance_valid(player) and hold_pending[player.index]:
		hold_player(player.index)
	if closing or not is_instance_valid(player) or not player.active or phase == "over":
		return
	track_landing(player, delta)
	if player.global_position.y < LilyDuelArena.WATER_HEIGHT - water_kill_margin:
		take_out(player, "water")
		return
	if player.poisoned:
		player.health = maxf(0.0, player.health - poison_per_second * delta)
		if player.health <= 0.0:
			take_out(player, "poison")
			return
	collect_fireflies(player)
	var pad := grounded_pad(player)
	if pad == null:
		return
	if pad.kind == LilyDuelPad.Kind.HOME and pad.owner_index == player.index and player.carried > 0:
		bank(player)
	if pad.kind == LilyDuelPad.Kind.MIDDLE and pad.state == "solid" and phase != "sudden_death":
		pad.trigger_sink(middle_warning, middle_down)
	elif pad.kind == LilyDuelPad.Kind.YELLOW and pad.state == "solid" and phase != "sudden_death":
		step_on_yellow(player, pad)
	if not player.poisoned:
		for frog in frogs:
			if is_instance_valid(frog) and frog.state == "sitting" and frog.pad == pad:
				poison(player)
				break

func bank(player: LilyDuelPlayer) -> void:
	var amount := player.carried
	var doubled := player.has_queen
	var points := amount * (2 if doubled else 1)
	scores[player.index] += points
	player.set_carried(0)
	arena.set_lantern_score(player.index, scores[player.index])
	var lantern := arena.home_pads[player.index]
	var at := lantern.surface_center() + Vector3(-1.2 if player.index == 0 else 1.2, 1.5, 0)
	arena.firefly_puff(at)
	arena.shake(0.4)
	if amount >= 5:
		arena.celebrate(at)
		arena.pulse(0.5)
	play_sound("victory" if amount >= 5 else "firefly")
	var suffix := " ×2" if doubled else ""
	hud.show_toast("%s banks %d%s!" % [names[player.index], amount, suffix], 2.2)

func step_on_yellow(player: LilyDuelPlayer, pad: LilyDuelPad) -> void:
	if yellow_holds.has(pad.pad_id):
		if yellow_holds[pad.pad_id]["player"] == player.index:
			yellow_holds[pad.pad_id]["off"] = 0.0
		else:
			# It held for the player still standing here, so it gives way for the newcomer.
			sink_yellow(player, pad, "The yellow pad gives way under %s!" % names[player.index])
		return
	# A spent pad sinks for the next player, not for the one it held for: they roll again.
	if pad.spent and int(yellow_spent_by.get(pad.pad_id, -1)) != player.index:
		sink_yellow(player, pad, "The cracked yellow pad gives way under %s!" % names[player.index])
		return
	var roll := yellow_roll_override
	if roll < 0:
		roll = rng.randi() % 2
	if roll >= 1:
		sink_yellow(player, pad, "The yellow pad sinks under %s!" % names[player.index])
	else:
		yellow_holds[pad.pad_id] = {"player": player.index, "off": 0.0}
		hud.show_toast("The yellow pad holds %s. This time." % names[player.index], 2.2)

func sink_yellow(player: LilyDuelPlayer, pad: LilyDuelPad, text: String) -> void:
	yellow_holds.erase(pad.pad_id)
	yellow_spent_by.erase(pad.pad_id)
	pad.trigger_sink(0.0, yellow_down)
	player.drop_through()
	hud.show_toast(text, 2.2)

func tick_hold_and_queen(delta: float) -> void:
	for pad_id in yellow_holds.keys():
		var record: Dictionary = yellow_holds[pad_id]
		var pad := arena.pads[pad_id]
		if not pad.is_standable():
			yellow_holds.erase(pad_id)
			continue
		var holder := players[record["player"]]
		var on_it := false
		if is_instance_valid(holder) and not out[holder.index]:
			var point := holder.global_position
			var top := pad.surface_center().y
			on_it = pad.contains_xz(point, rim_margin + 0.05) and point.y > top - 0.4 and point.y < top + 4.0
		record["off"] = 0.0 if on_it else float(record["off"]) + delta
		if float(record["off"]) >= yellow_leave_grace:
			pad.set_spent(true)
			yellow_spent_by[pad_id] = int(record["player"])
			yellow_holds.erase(pad_id)
	if phase == "midnight" or phase == "flood":
		if queen.state == "perched":
			# Random order, so neither side wins a same-tick grab by default.
			var order: Array[LilyDuelPlayer] = [players[0], players[1]]
			if rng.randi() % 2 == 1:
				order.reverse()
			for player in order:
				if player.active and not out[player.index] and queen.can_be_taken_by(player):
					give_queen(player)
					break

func on_pad_sank(pad: LilyDuelPad) -> void:
	if closing:
		return
	yellow_holds.erase(pad.pad_id)
	yellow_spent_by.erase(pad.pad_id)
	hop_frogs_off(pad)
	if flooded_pads.has(pad.pad_id):
		relocate_fireflies(pad)

func on_pad_rose(pad: LilyDuelPad) -> void:
	if closing:
		return
	yellow_holds.erase(pad.pad_id)
	yellow_spent_by.erase(pad.pad_id)

# --- queen ----------------------------------------------------------------------------------

func give_queen(player: LilyDuelPlayer) -> void:
	var old: LilyDuelPlayer = queen.holder if is_instance_valid(queen.holder) else null
	if old != null and old != player:
		old.set_queen(false)
		old.speed_scale = 1.0
	player.set_queen(true)
	player.speed_scale = queen_speed_scale
	queen.give_to(player)
	arena.pulse(0.35)
	hud.show_toast("%s caught the Queen! Banks count double." % names[player.index], 2.6)
	play_sound("firefly")

func release_queen(player: LilyDuelPlayer) -> void:
	player.set_queen(false)
	player.speed_scale = 1.0
	queen.return_to_perch()

# --- combat ---------------------------------------------------------------------------------

func on_bat_impact(attacker: LilyDuelPlayer) -> void:
	if closing or not is_instance_valid(attacker) or not attacker.active or not phase in ACTIVE_PHASES:
		return
	# Resolved together on the next tick so two swings landing on the same tick both count,
	# whichever player's node happens to be processed first.
	if not pending_impacts.has(attacker):
		pending_impacts.append(attacker)

func resolve_impacts() -> void:
	if pending_impacts.is_empty():
		return
	var attackers := pending_impacts.duplicate()
	pending_impacts.clear()
	if not phase in ACTIVE_PHASES:
		return
	var hits: Array = []
	for attacker: LilyDuelPlayer in attackers:
		if not is_instance_valid(attacker) or out[attacker.index]:
			continue
		var victim := players[1 - attacker.index]
		# A player already dropping through a pad is on their way into the water.
		if victim.active and not out[victim.index] and not victim.falling_through \
				and victim.invulnerable_remaining <= 0.0 and attacker.bat_reaches(victim.global_position):
			hits.append([attacker, victim])
	for hit in hits:
		hit_player(hit[0], hit[1])
	for attacker: LilyDuelPlayer in attackers:
		if is_instance_valid(attacker) and not out[attacker.index]:
			hit_frogs(attacker)

func hit_player(attacker: LilyDuelPlayer, victim: LilyDuelPlayer) -> void:
	if closing or not is_instance_valid(attacker) or not is_instance_valid(victim):
		return
	var speed := knockback_speed
	if phase == "sudden_death":
		speed *= sudden_death_knockback_scale
	victim.knockback(attacker.attack_direction, speed)
	var dropped := ceili(victim.carried / 2.0)
	if dropped > 0:
		victim.set_carried(victim.carried - dropped)
		scatter_fireflies(victim.global_position, dropped)
	var text := "%s bonks %s!" % [names[attacker.index], names[victim.index]]
	if dropped > 0:
		text = "%s bonks %s, who drops %d!" % [names[attacker.index], names[victim.index], dropped]
	if victim.has_queen:
		victim.set_queen(false)
		victim.speed_scale = 1.0
		attacker.set_queen(true)
		attacker.speed_scale = queen_speed_scale
		queen.give_to(attacker)
		arena.pulse(0.35)
		text = "%s steals the Queen from %s!" % [names[attacker.index], names[victim.index]]
	hud.show_toast(text, 2.4)
	arena.bonk(victim.global_position)
	play_sound("bonk")
	victim.flash_hit()
	arena.shake(1.5 if phase == "sudden_death" else 1.0)
	var spark_at := victim.global_position + Vector3.UP * 0.9
	arena.burst(spark_at, Color("fff3c0"), 14)
	if dropped > 0:
		arena.firefly_puff(spark_at)
		arena.burst(spark_at + Vector3.UP * 0.3, Color("ffd75e"), 10)
	start_hit_stop()

func hit_frogs(attacker: LilyDuelPlayer) -> void:
	var batted := false
	for frog in frogs:
		if not is_instance_valid(frog) or frog.state != "sitting":
			continue
		if not attacker.bat_reaches(frog.global_position):
			continue
		batted = true
		var target := choose_frog_target(frog, attacker)
		arena.bonk(frog.global_position)
		play_sound("bonk")
		if target == null:
			frog.dismiss()
		else:
			var dist := Vector2(target.position.x - frog.global_position.x, target.position.z - frog.global_position.z).length()
			frog.launch_to(target, 0.6 + dist * 0.03)
	if batted:
		arena.shake(0.4)
		attacker.set_poisoned(false)
		attacker.health = 100.0
		hud.show_toast("%s bats a frog away. Cured!" % names[attacker.index], 2.4)

func frog_claims(pad: LilyDuelPad) -> bool:
	for frog in frogs:
		if is_instance_valid(frog) and frog.state != "gone" and frog.pad == pad:
			return true
	return false

func legal_frog_pads(frog: LilyDuelFrog, origin: Vector3) -> Array[LilyDuelPad]:
	var result: Array[LilyDuelPad] = []
	for pad in arena.pads:
		if not pad.is_standable() or pad.kind == LilyDuelPad.Kind.HOME or pad.kind == LilyDuelPad.Kind.CENTER:
			continue
		if pad == frog.pad or frog_claims(pad):
			continue
		result.append(pad)
	var flat := Vector2(origin.x, origin.z)
	result.sort_custom(func(a: LilyDuelPad, b: LilyDuelPad) -> bool:
		return flat.distance_to(Vector2(a.position.x, a.position.z)) < flat.distance_to(Vector2(b.position.x, b.position.z)))
	return result

func choose_frog_target(frog: LilyDuelFrog, attacker: LilyDuelPlayer) -> LilyDuelPad:
	var origin := frog.global_position
	var legal := legal_frog_pads(frog, origin)
	if legal.is_empty():
		return null
	var aim := Vector3(attacker.attack_direction.x, 0, attacker.attack_direction.z).normalized()
	var flat := Vector2(origin.x, origin.z)
	var in_cone: Array[LilyDuelPad] = []
	for pad in legal:
		var offset := Vector3(pad.position.x - origin.x, 0, pad.position.z - origin.z)
		if offset.length() > 0.01 and aim.dot(offset.normalized()) >= frog_cone_dot:
			in_cone.append(pad)
	var opponent := players[1 - attacker.index]
	var standing := arena.pad_at(opponent.global_position)
	if standing != null and in_cone.has(standing) \
			and flat.distance_to(Vector2(standing.position.x, standing.position.z)) <= frog_range:
		return standing
	if not in_cone.is_empty():
		return in_cone[0]
	return legal[0]

func hop_frogs_off(pad: LilyDuelPad) -> void:
	if not pad.kind in [LilyDuelPad.Kind.MIDDLE, LilyDuelPad.Kind.YELLOW, LilyDuelPad.Kind.OUTER]:
		return
	for frog in frogs:
		if is_instance_valid(frog) and frog.state == "sitting" and frog.pad == pad:
			rehome_frog(frog, pad)

func rehome_frog(frog: LilyDuelFrog, from_pad: LilyDuelPad) -> void:
	var legal := legal_frog_pads(frog, from_pad.surface_center())
	if legal.is_empty():
		frog.dismiss()
	else:
		frog.launch_to(legal[0], 0.7)

func on_frog_landed(frog: LilyDuelFrog) -> void:
	if closing or not is_instance_valid(frog):
		return
	var pad := frog.pad as LilyDuelPad
	if pad == null:
		return
	arena.ripple(pad.surface_center(), 0.9)
	if not pad.is_standable():
		rehome_frog(frog, pad)
		return
	for player in players:
		if player.active and not player.poisoned and grounded_pad(player) == pad:
			poison(player)

func poison(player: LilyDuelPlayer) -> void:
	if player.poisoned:
		return
	player.set_poisoned(true)
	play_sound("poison")
	hud.show_toast("%s is poisoned! Bat a frog to cure it." % names[player.index], 2.6)

# --- taken out -------------------------------------------------------------------------------

func take_out(player: LilyDuelPlayer, cause: String) -> void:
	if closing or not is_instance_valid(player) or phase == "over":
		return
	var index := player.index
	if out[index]:
		return
	out[index] = true
	release_player(index)
	respawn_left[index] = respawn_delay
	var at := player.global_position
	player.active = false
	player.clear_input()
	player.visible = false
	if cause == "poison":
		arena.burst(at + Vector3.UP * 0.8, Color("ae79c5"), 14)
		play_sound("poison")
	else:
		arena.splash(Vector3(at.x, LilyDuelArena.WATER_HEIGHT, at.z))
		play_sound("splash")
	var dropped := player.carried
	player.set_carried(0)
	if phase != "sudden_death":
		scatter_fireflies(at, dropped)
	if player.has_queen:
		release_queen(player)
	player.set_poisoned(false)
	if phase == "sudden_death":
		var other := players[1 - index]
		var line := LilyDuelArena.WATER_HEIGHT - water_kill_margin
		if not out[1 - index] and other.active and other.velocity.y < 0.0 and other.global_position.y < line + 0.25:
			# Both went in together: nobody wins on processing order. Go again.
			enter_sudden_death()
			hud.show_toast("Both in the water! Sudden death again.", 3.0)
			return
		end_match(1 - index, true)
		return
	if cause == "poison":
		hud.show_toast("%s succumbed to the poison!" % names[index], 2.4)
	else:
		hud.show_toast("%s fell in the water!" % names[index], 2.4)

# --- hit-stop --------------------------------------------------------------------------------

func start_hit_stop() -> void:
	# While paused the whole match is already still; a freeze queued now would outlive the pause.
	if hit_stop_seconds <= 0.0 or closing or paused or phase == "over":
		return
	# A second hit during a freeze restarts it at one full hit-stop; it never stacks.
	freeze_left = maxf(freeze_left, hit_stop_seconds)
	for i in 2:
		if not out[i] and not freeze_held[i]:
			freeze_held[i] = true
			# A hit resolved inside a tick lets the players finish that tick (as they would
			# without hit-stop); anywhere else they are held at once.
			if resolving:
				hold_pending[i] = true
			else:
				hold_player(i)

# The player stops stepping (physics, timers, trails) but keeps `active`, velocity and every
# timer, so the match continues where it was. Their input still arrives: a jump pressed now is
# buffered and its 0.12 s only counts down once they move again.
func hold_player(index: int) -> void:
	hold_pending[index] = false
	if freeze_held[index] and is_instance_valid(players[index]):
		players[index].set_physics_process(false)
		players[index].set_process(false)

func hold_waiting_players() -> void:
	for i in 2:
		if hold_pending[i]:
			hold_player(i)

func release_player(index: int) -> void:
	hold_pending[index] = false
	if freeze_held[index]:
		freeze_held[index] = false
		if is_instance_valid(players[index]):
			players[index].set_physics_process(true)
			players[index].set_process(true)

func end_hit_stop() -> void:
	freeze_left = 0.0
	for i in 2:
		release_player(i)

# Drops the freeze; callers reset the players themselves.
func cancel_hit_stop() -> void:
	end_hit_stop()

# --- water and light feel ----------------------------------------------------------------------

func track_landing(player: LilyDuelPlayer, delta: float) -> void:
	var i := player.index
	land_cooldown[i] = maxf(0.0, land_cooldown[i] - delta)
	var on_floor := player.is_on_floor() and not player.falling_through
	if on_floor and not was_grounded[i] and land_cooldown[i] <= 0.0:
		var pad := grounded_pad(player)
		if pad != null:
			land_cooldown[i] = 0.25
			var away := Vector3(player.global_position.x - pad.position.x, 0, player.global_position.z - pad.position.z)
			away = away.normalized() if away.length() > 0.05 else Vector3.RIGHT
			arena.ripple(Vector3(pad.position.x, 0, pad.position.z) + away * pad.radius, 0.45)
	was_grounded[i] = on_floor

func sync_look() -> void:
	if phase != look_phase:
		look_phase = phase
		arena.set_phase_look(phase)

func update_water_level() -> void:
	match phase:
		"flood":
			var t := clampf((elapsed - flood_start()) / maxf(flood_seconds, 0.001), 0.0, 1.0)
			arena.set_water_level(lerpf(LilyDuelArena.WATER_HEIGHT, LilyDuelArena.MAX_WATER_LEVEL, t))
		"sudden_death":
			arena.set_water_level(LilyDuelArena.SUDDEN_DEATH_WATER_LEVEL)
		"countdown", "dusk", "midnight":
			arena.set_water_level(LilyDuelArena.WATER_HEIGHT)

func push_light(used: int, point: Vector3, color: Color, energy: float) -> int:
	if used >= LilyDuelWater.MAX_REFLECTIONS:
		return used
	var entry := reflection_pool[used]
	entry["position"] = point
	entry["color"] = color
	entry["energy"] = energy
	reflection_lights.append(entry)
	return used + 1

func update_reflections() -> void:
	reflection_lights.clear()
	var used := 0
	for lantern in arena.lantern_reflections():
		used = push_light(used, lantern["position"], lantern["color"], lantern["energy"])
	if queen.state != "hidden":
		used = push_light(used, queen.current_position(), Color("ffd75e"), 2.0)
	for player in players:
		if player.carried > 0 and player.visible and not out[player.index]:
			used = push_light(used, player.global_position, Color("ffc766"), minf(0.4 + 0.06 * player.carried, 1.2))
	var room := LilyDuelWater.MAX_REFLECTIONS - used
	var count := 0
	if room > 0:
		for k in loose_fireflies.size():
			var fly := loose_fireflies[k]
			if not is_instance_valid(fly):
				continue
			var p := fly.global_position
			var d := p.x * p.x + p.z * p.z
			if count >= room and d >= near_dist[count - 1]:
				continue
			var at := mini(count, room - 1)
			while at > 0 and near_dist[at - 1] > d:
				if at < room:
					near_dist[at] = near_dist[at - 1]
					near_index[at] = near_index[at - 1]
				at -= 1
			near_dist[at] = d
			near_index[at] = k
			count = mini(count + 1, room)
		for k in count:
			used = push_light(used, loose_fireflies[near_index[k]].global_position, Color("ffe775"), 0.3)
	arena.set_reflection_lights(reflection_lights)

# --- presentation -------------------------------------------------------------------------------

func play_sound(sound_name: String) -> void:
	if sounds.has(sound_name) and is_inside_tree():
		(sounds[sound_name] as AudioStreamPlayer).play()

func on_player_jumped(_player: LilyDuelPlayer) -> void:
	play_sound("jump")

func on_player_swung(_player: LilyDuelPlayer) -> void:
	play_sound("swing")

func refresh_hud() -> void:
	var left := maxf(time_left, 0.0)
	var whole := ceili(left)
	if whole != hud_time_key or phase != hud_phase_key:
		hud_time_key = whole
		hud_phase_key = phase
		hud.set_time(left, phase)
	var carried := [players[0].carried, players[1].carried]
	var scores_key := "%d,%d,%d,%d" % [scores[0], scores[1], carried[0], carried[1]]
	if scores_key != hud_scores_key:
		hud_scores_key = scores_key
		hud.set_scores([scores[0], scores[1]], carried)
	for i in 2:
		var key := "%d,%s" % [ceili(players[i].health), str(players[i].poisoned)]
		if key != hud_health_key[i]:
			hud_health_key[i] = key
			hud.set_health(i, players[i].health, players[i].poisoned)
	var holder := -1
	for player in players:
		if player.has_queen:
			holder = player.index
	if holder != hud_queen_key:
		hud_queen_key = holder
		hud.set_queen(holder)

func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func debug_snapshot() -> Dictionary:
	var holder_index := -1
	if is_instance_valid(queen.holder):
		holder_index = queen.holder.index
	var player_data: Array = []
	for player in players:
		player_data.append({
			"position": vec(player.global_position),
			"velocity": vec(player.velocity),
			"grounded": player.is_on_floor(),
			"stunned": player.stun_remaining > 0.0,
			"active": player.active,
		})
	var pad_data: Array = []
	for pad in arena.pads:
		pad_data.append({
			"id": pad.pad_id,
			"kind": String(LilyDuelPad.Kind.keys()[pad.kind]).to_lower(),
			"state": pad.state,
			"spent": pad.spent,
		})
	var fly_data: Array = []
	for fly in loose_fireflies:
		if is_instance_valid(fly):
			fly_data.append(vec(fly.global_position))
	var frog_data: Array = []
	for frog in frogs:
		if is_instance_valid(frog):
			var on_pad := frog.pad as LilyDuelPad
			frog_data.append({"pad": on_pad.pad_id if on_pad != null else -1, "state": frog.state})
	return {
		"mode": "duel",
		"state": "duel",
		"phase": phase,
		"elapsed": elapsed,
		"time_left": time_left,
		"paused": paused,
		"scores": [scores[0], scores[1]],
		"carried": [players[0].carried, players[1].carried],
		"health": [players[0].health, players[1].health],
		"poisoned": [players[0].poisoned, players[1].poisoned],
		"winner": winner,
		"queen": {"state": queen.state, "holder": holder_index},
		"players": player_data,
		"pads": pad_data,
		"fireflies": fly_data,
		"frogs": frog_data,
		"hud": hud.debug_snapshot(),
	}
