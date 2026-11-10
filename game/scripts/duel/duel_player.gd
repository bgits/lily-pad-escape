class_name LilyDuelPlayer
extends CharacterBody3D

signal jumped(player: LilyDuelPlayer)
signal swung(player: LilyDuelPlayer)
signal bat_impact(player: LilyDuelPlayer)
signal stepped(player: LilyDuelPlayer, delta: float)

const PLAYER_COLORS := [Color("ffd75e"), Color("6fd3ff")]
const MAX_MOTES := 12
const AVATAR_SCALE := 1.3
const SWING_TIME := 0.48
const IMPACT_AT := 0.36
const FLASH_TIME := 0.12
const HALO_SIZE := 4.4

@export var move_speed := 5.4
@export var acceleration := 32.0
@export var braking := 42.0
@export var air_acceleration := 16.0
@export var jump_speed := 8.4
@export var gravity := 22.0
@export var coyote_duration := 0.10
@export var buffer_duration := 0.12

var index := 0
var active := false
var avatar: LilyAvatar
var carried := 0
var has_queen := false
var health := 100.0
var poisoned := false
var speed_scale := 1.0
var stun_remaining := 0.0
var invulnerable_remaining := 0.0
var swing_remaining := 0.0
var attack_direction := Vector3.FORWARD
var falling_through := false

var outfit: Dictionary = {}
var coyote := 0.0
var buffered := 0.0
var jump_consumed := false
var impact_pending := false
var jump_count := 0
var shadow: MeshInstance3D
var ring: MeshInstance3D
var label: Label3D
var light: OmniLight3D
var swarm: Node3D
var motes: Array[MeshInstance3D] = []
var mote_clock := 0.0
var poison_cloud: Node3D
var poison_clock := 0.0
# Visual effects (section 8).
var halo: MeshInstance3D
var back_glow: MeshInstance3D
var flash_glow: MeshInstance3D
var flash_material: StandardMaterial3D
var swarm_trail: LilyDuelFx.Trail
var streak: LilyDuelFx.Trail
var light_base := 0.0
var flash_remaining := 0.0
# Every avatar material has emission switched on once (black), so the first hit changes only
# the emission colour and never the shader variant. flash_materials is the subset lit right now.
var emissive_materials: Array[StandardMaterial3D] = []
var flash_materials: Array[StandardMaterial3D] = []

static func action_name(player_index: int, what: String) -> String:
	return "duel_p%d_%s" % [player_index + 1, what]

static func configure_input() -> void:
	var layout := {
		0: {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S], "jump": [KEY_SPACE], "swing": [KEY_F]},
		1: {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN], "jump": [KEY_ENTER, KEY_KP_ENTER], "swing": [KEY_SLASH, KEY_SHIFT]},
	}
	for player_index in [0, 1]:
		for what in layout[player_index]:
			var action := action_name(player_index, what)
			if not InputMap.has_action(action):
				InputMap.add_action(action, 0.2)
			for code in layout[player_index][what]:
				var present := false
				for existing in InputMap.action_get_events(action):
					if existing is InputEventKey and existing.physical_keycode == code:
						present = true
				if not present:
					var event := InputEventKey.new()
					event.physical_keycode = code
					InputMap.action_add_event(action, event)

func setup(player_index: int, player_outfit: Dictionary) -> void:
	index = player_index
	outfit = player_outfit

func player_color() -> Color:
	return PLAYER_COLORS[clampi(index, 0, 1)]

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.15
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.65
	collider.shape = capsule
	collider.position.y = 0.825
	add_child(collider)
	# Drawn larger than the collision capsule so both players read clearly from the far,
	# fixed camera. LilyAvatar animates its own scale, so the enlargement lives on a holder.
	var avatar_holder := Node3D.new()
	avatar_holder.scale = Vector3.ONE * AVATAR_SCALE
	add_child(avatar_holder)
	avatar = LilyAvatar.new()
	avatar_holder.add_child(avatar)
	avatar.apply_appearance(LilyAppearance.sanitize(outfit, true))
	avatar.equip_bat(true)
	prepare_emission()
	attack_direction = Vector3.FORWARD.rotated(Vector3.UP, avatar.rotation.y)
	var color := player_color()
	# Poison cloud, like LilyPlayer.
	poison_cloud = Node3D.new()
	add_child(poison_cloud)
	var poison_mat := LilyAvatar.material(Color("ae79c5"))
	for i in 5:
		LilyAvatar.box(poison_cloud, Vector3.ZERO, Vector3.ONE * 0.10, poison_mat)
	poison_cloud.visible = poisoned
	# Shadow disc.
	shadow = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.40
	disk.bottom_radius = 0.40
	disk.height = 0.008
	disk.radial_segments = 24
	shadow.mesh = disk
	var shadow_mat := LilyAvatar.material(Color(0.02, 0.08, 0.10, 0.45))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)
	# Coloured ring on the ground.
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.78
	torus.rings = 28
	torus.ring_segments = 6
	ring.mesh = torus
	var ring_mat := LilyAvatar.material(color)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.scale = Vector3(1, 0.12, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	add_child(ring)
	# Soft additive pool of light under the player and a glow behind the silhouette.
	halo = LilyDuelFx.add_glow_sprite(self, HALO_SIZE, Color(color.r, color.g, color.b, 0.95), false)
	halo.top_level = true
	back_glow = LilyDuelFx.add_glow_sprite(self, 3.6, Color(color.r, color.g, color.b, 0.6), true)
	back_glow.top_level = true
	flash_material = LilyDuelFx.make_material(Color(1, 1, 1, 0.0), true)
	flash_glow = MeshInstance3D.new()
	flash_glow.mesh = LilyDuelFx.unit_quad()
	flash_glow.material_override = flash_material
	flash_glow.scale = Vector3.ONE * 2.6
	flash_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_glow.top_level = true
	flash_glow.visible = false
	add_child(flash_glow)
	# Name tag.
	label = Label3D.new()
	label.text = "P%d" % (index + 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 72
	label.pixel_size = 0.0125
	label.outline_size = 22
	label.modulate = color
	label.outline_modulate = Color(0.03, 0.05, 0.10, 1.0)
	label.no_depth_test = true
	label.position = Vector3(0, 2.9, 0)
	add_child(label)
	# Glow.
	light = OmniLight3D.new()
	light.light_color = color.lerp(Color("ffcf7a"), 0.35)
	light.omni_range = 6.0
	light.position = Vector3(0, 1.3, 0)
	light.shadow_enabled = false
	light.light_energy = light_target()
	light_base = light.light_energy
	add_child(light)
	# Trailing swarm.
	swarm = Node3D.new()
	swarm.top_level = true
	add_child(swarm)
	var spark := LilyDuelFx.additive_material(Color(1.0, 0.92, 0.5, 1.0).lerp(Color(color.r, color.g, color.b, 1.0), 0.22), true)
	for i in MAX_MOTES:
		var mote := MeshInstance3D.new()
		mote.mesh = LilyDuelFx.unit_quad()
		mote.material_override = spark
		mote.scale = Vector3.ONE * 1.0
		mote.visible = false
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		swarm.add_child(mote)
		motes.append(mote)
	swarm_trail = LilyDuelFx.Trail.new(MAX_MOTES, 10, 0.36, 0.12)
	swarm_trail.head_color = Color(1.0, 0.88, 0.42, 0.85).lerp(Color(color.r, color.g, color.b, 0.85), 0.2)
	swarm_trail.tail_color = Color(1.0, 0.7, 0.25, 0.0)
	swarm.add_child(swarm_trail)
	streak = LilyDuelFx.Trail.new(1, 24, 0.45, 0.28)
	streak.interval = 0.0
	streak.head_color = Color(1.0, 1.0, 1.0, 0.7).lerp(Color(color.r, color.g, color.b, 0.7), 0.5)
	streak.tail_color = Color(color.r, color.g, color.b, 0.0)
	swarm.add_child(streak)
	set_carried(carried)

func light_target() -> float:
	return 0.6 + minf(float(carried), float(MAX_MOTES)) / float(MAX_MOTES) * 2.4

func visible_mote_count() -> int:
	var count := 0
	for mote in motes:
		if mote.visible:
			count += 1
	return count

func set_carried(count: int) -> void:
	carried = maxi(0, count)
	if motes.is_empty():
		return
	var shown := mini(carried, MAX_MOTES)
	for i in motes.size():
		var want := i < shown
		if want and not motes[i].visible:
			motes[i].global_position = global_position + Vector3(0, 0.9, 0)
			if swarm_trail != null:
				swarm_trail.clear_strip(i)
		motes[i].visible = want
		if not want and swarm_trail != null:
			swarm_trail.clear_strip(i)

func set_poisoned(value: bool) -> void:
	poisoned = value
	if is_instance_valid(poison_cloud):
		poison_cloud.visible = value
	if not value:
		poison_clock = 0.0

func set_queen(value: bool) -> void:
	has_queen = value

func clear_input() -> void:
	buffered = 0.0
	for what in ["left", "right", "up", "down", "jump", "swing"]:
		Input.action_release(action_name(index, what))

func drop_through() -> void:
	falling_through = true
	coyote = 0.0
	jump_consumed = true
	clear_input()
	cancel_swing()
	velocity = Vector3(velocity.x * 0.2, -2.0, velocity.z * 0.2)

func request_swing() -> void:
	if not active or swing_remaining > 0.0 or falling_through or stun_remaining > 0.0:
		return
	swing_remaining = SWING_TIME
	impact_pending = true
	attack_direction = Vector3.FORWARD.rotated(Vector3.UP, avatar.rotation.y)
	avatar.swing()
	swung.emit(self)

func cancel_swing() -> void:
	swing_remaining = 0.0
	impact_pending = false
	if avatar:
		avatar.swing_time = 0.0

func bat_reaches(target: Vector3) -> bool:
	var offset := target - global_position
	var horizontal := Vector3(offset.x, 0, offset.z)
	if horizontal.length() > 2.3 or absf(offset.y) > 1.1:
		return false
	return horizontal.length() <= 0.1 or attack_direction.dot(horizontal.normalized()) >= 0.20

func knockback(direction: Vector3, horizontal_speed := 9.0, up_speed := 5.0, stun := 0.45) -> void:
	var flat := Vector3(direction.x, 0, direction.z)
	if flat.length() < 0.001:
		flat = -Vector3.FORWARD.rotated(Vector3.UP, avatar.rotation.y)
	flat = flat.normalized()
	velocity = Vector3(flat.x * horizontal_speed, up_speed, flat.z * horizontal_speed)
	stun_remaining = stun
	invulnerable_remaining = 0.8
	buffered = 0.0
	coyote = 0.0
	cancel_swing()
	if streak != null:
		streak.clear()

func face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0, direction.z)
	if flat.length() < 0.001:
		return
	avatar.rotation.y = atan2(-flat.x, -flat.z)
	attack_direction = flat.normalized()

func respawn(spawn: Vector3, face_direction: Vector3) -> void:
	falling_through = false
	stun_remaining = 0.0
	invulnerable_remaining = 0.0
	health = 100.0
	set_poisoned(false)
	global_position = spawn
	velocity = Vector3.ZERO
	coyote = 0.0
	buffered = 0.0
	jump_consumed = true
	cancel_swing()
	avatar.rotation = Vector3.ZERO
	avatar.landing = 0.0
	avatar.scale = Vector3.ONE
	avatar.visible = true
	face(face_direction)
	clear_input()
	for mote in motes:
		if mote.visible:
			mote.global_position = spawn + Vector3(0, 0.9, 0)
	if swarm_trail != null:
		swarm_trail.clear()
		streak.clear()
	reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	if not active or stun_remaining > 0.0 or falling_through or event.is_echo():
		return
	if event.is_action_pressed(action_name(index, "jump")):
		buffered = buffer_duration
	if event.is_action_pressed(action_name(index, "swing")):
		request_swing()

func _physics_process(delta: float) -> void:
	if not active:
		avatar.animate(delta, 0.0, true, 0.0)
		avatar.visible = true
		return
	stun_remaining = maxf(0.0, stun_remaining - delta)
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	var grounded := is_on_floor() and not falling_through
	if grounded:
		coyote = coyote_duration
		jump_consumed = false
	else:
		coyote = maxf(0.0, coyote - delta)
	buffered = maxf(0.0, buffered - delta)
	var stunned := stun_remaining > 0.0
	var input := Vector2.ZERO
	if not stunned and not falling_through:
		input = Input.get_vector(action_name(index, "left"), action_name(index, "right"), action_name(index, "up"), action_name(index, "down"))
	# Screen-relative: up is world -Z, right is world +X.
	var direction := Vector3(input.x, 0, input.y)
	if not stunned:
		var target := direction * move_speed * speed_scale
		var rate := acceleration if direction.length() > 0.0 else braking
		if not grounded:
			rate = air_acceleration
		velocity.x = move_toward(velocity.x, target.x, rate * delta)
		velocity.z = move_toward(velocity.z, target.z, rate * delta)
	if not grounded:
		velocity.y -= gravity * delta
	if buffered > 0.0 and coyote > 0.0 and not jump_consumed and not stunned and not falling_through:
		velocity.y = jump_speed
		buffered = 0.0
		coyote = 0.0
		jump_consumed = true
		jump_count += 1
		jumped.emit(self)
	if direction.length() > 0.05 and swing_remaining <= 0.0:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 16, 1))
	move_and_slide()
	# Dropping through ends in the water. If something (a bat hit mid-fall) puts the player
	# back on solid footing instead, they must get their controls back.
	if falling_through and is_on_floor():
		falling_through = false
	if swing_remaining > 0.0:
		swing_remaining = maxf(0.0, swing_remaining - delta)
		if impact_pending and swing_remaining <= IMPACT_AT:
			impact_pending = false
			bat_impact.emit(self)
	if is_on_floor() and not grounded and not falling_through:
		avatar.landing = 1.0
	avatar.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y)
	avatar.visible = invulnerable_remaining <= 0.0 or int(invulnerable_remaining * 14.0) % 2 == 0
	update_shadow()
	stepped.emit(self, delta)

func update_shadow() -> void:
	if not is_instance_valid(shadow) or not is_inside_tree():
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 8.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	shadow.visible = not hit.is_empty()
	ring.visible = shadow.visible
	if not hit.is_empty():
		shadow.global_position = hit.position + Vector3.UP * 0.014
		ring.global_position = hit.position + Vector3.UP * 0.03
		var size := clampf(1.0 - (global_position.y - hit.position.y) * 0.10, 0.55, 1.0)
		shadow.scale = Vector3(size, 1, size)

# Brief white flash on the avatar (emission colour on every avatar material plus a glow sprite
# and a light spike). Always ends back at black emission; safe to repeat and when inactive.
func flash_hit() -> void:
	if not is_instance_valid(flash_glow) or not is_instance_valid(avatar):
		return
	if flash_remaining <= 0.0:
		# Re-scan so an avatar rebuilt by apply_appearance() flashes too.
		prepare_emission()
		flash_materials.assign(emissive_materials)
		for mat in flash_materials:
			mat.emission = Color.WHITE
			mat.emission_energy_multiplier = 2.2
	flash_remaining = FLASH_TIME
	flash_glow.visible = true
	flash_glow.global_position = flash_center()
	flash_material.albedo_color = Color(1, 1, 1, 0.9)

func flash_center() -> Vector3:
	var center := global_position + Vector3(0, 1.1, 0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		center += (cam.global_position - center).normalized() * 0.7
	return center

# Collects the avatar's own materials and turns emission on (black) for each one that is not
# yet on. Materials already prepared are left alone, so repeat calls are cheap and silent.
func prepare_emission() -> void:
	emissive_materials.clear()
	var pending: Array[Node] = [avatar]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = node.material_override
			if not emissive_materials.has(mat):
				emissive_materials.append(mat)
				if not mat.emission_enabled:
					mat.emission_enabled = true
					mat.emission = Color.BLACK
					mat.emission_energy_multiplier = 1.0

func end_flash() -> void:
	flash_remaining = 0.0
	for mat in flash_materials:
		mat.emission = Color.BLACK
		mat.emission_energy_multiplier = 1.0
	flash_materials.clear()
	flash_glow.visible = false

func update_fx(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if ring.visible:
		halo.visible = true
		halo.global_position = ring.global_position + Vector3(0, 0.02, 0)
		var breathe := 1.0 + sin(Time.get_ticks_msec() * 0.003 + index * 2.0) * 0.06
		halo.scale = Vector3(HALO_SIZE * breathe, HALO_SIZE * breathe, HALO_SIZE)
	else:
		halo.visible = false
	var center := global_position + Vector3(0, 1.0, 0)
	if cam != null:
		center += (center - cam.global_position).normalized() * 0.9
	back_glow.global_position = center
	if flash_remaining > 0.0:
		flash_material.albedo_color = Color(1, 1, 1, 0.9 * flash_remaining / FLASH_TIME)
		flash_glow.global_position = flash_center()
	if stun_remaining > 0.0 and active:
		streak.track(0, global_position + Vector3(0, 0.9, 0))
	swarm_trail.advance(delta)
	streak.advance(delta)

func _process(delta: float) -> void:
	if not is_instance_valid(light):
		return
	light_base = lerpf(light_base, light_target(), minf(delta * 5.0, 1.0))
	var spike := 0.0
	if flash_remaining > 0.0:
		flash_remaining = maxf(0.0, flash_remaining - delta)
		spike = 5.0 * flash_remaining / FLASH_TIME
		if flash_remaining <= 0.0:
			end_flash()
	light.light_energy = light_base + spike
	if ring.visible:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004 + index) * 0.04
		ring.scale = Vector3(pulse, 0.12, pulse)
	if poison_cloud.visible:
		poison_clock += delta
		for i in poison_cloud.get_child_count():
			var angle := poison_clock * 2.1 + i * TAU / 5
			poison_cloud.get_child(i).position = Vector3(cos(angle) * 0.65, 0.55 + fmod(poison_clock * 0.65 + i * 0.3, 1.2), sin(angle) * 0.65)
	mote_clock += delta
	var leader := global_position + Vector3(0, 1.0, 0)
	var back := Vector3(velocity.x, 0, velocity.z)
	var trail_dir := -back.normalized() if back.length() > 0.5 else Vector3.BACK.rotated(Vector3.UP, avatar.rotation.y)
	var follow := 1.0 - exp(-9.0 * delta)
	for i in motes.size():
		var mote := motes[i]
		if not mote.visible:
			continue
		var away := mote.global_position - leader
		var spread := Vector3(sin(mote_clock * 1.3 + i * 1.9), 0, cos(mote_clock * 1.1 + i * 2.3)) * 0.18
		var wanted := leader + (away.normalized() if away.length() > 0.01 else trail_dir) * 0.44 + trail_dir * 0.05 + spread
		wanted.y += sin(mote_clock * 3.0 + i * 0.9) * 0.12 - 0.02 * i
		mote.global_position = mote.global_position.lerp(wanted, follow)
		mote.scale = Vector3.ONE * (1.0 - 0.025 * i + sin(mote_clock * 9.0 + i * 2.1) * 0.1)
		swarm_trail.track(i, mote.global_position)
		leader = mote.global_position
	update_fx(delta)
