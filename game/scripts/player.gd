class_name LilyPlayer
extends CharacterBody3D

signal jumped
signal launched
signal landed
signal stepped(delta: float)
signal swung
signal bat_impact

@export var move_speed := 5.4
@export var acceleration := 32.0
@export var braking := 42.0
@export var air_acceleration := 16.0
@export var jump_speed := 8.4
@export var gravity := 22.0
@export var coyote_duration := 0.10
@export var buffer_duration := 0.12
@export var mouse_sensitivity := 0.0026

var rapids: RiverRapids
var ride: HoverRide
var launch_cooldown := 0.0
var launch_count := 0
var camera_manual := 0.0
var camera_height := 0.0
var active := false
var look_delay := 0.0
var avatar: LilyAvatar
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var coyote := 0.0
var buffered := 0.0
var jump_consumed := false
var jump_count := 0
var yaw := 0.0
var pitch := -0.42
var shadow: MeshInstance3D
var has_bat := false
var swing_remaining := 0.0
var impact_pending := false
var swing_count := 0
var attack_direction := Vector3.FORWARD
var falling_through := false
var poison_cloud: Node3D
var poison_clock := 0.0

func set_poisoned(value: bool) -> void:
	poison_cloud.visible = value
	if not value:
		poison_clock = 0.0

func drop_through() -> void:
	falling_through = true
	coyote = 0.0
	jump_consumed = true
	clear_input()
	cancel_swing()
	velocity = Vector3(velocity.x*0.2,-2.0,velocity.z*0.2)

func request_swing() -> void:
	if not active or not has_bat or swing_remaining > 0 or falling_through:
		return
	swing_remaining = 0.48
	impact_pending = true
	swing_count += 1
	# Swing where the character is already facing, independently of the camera.
	attack_direction = Vector3.FORWARD.rotated(Vector3.UP,avatar.rotation.y)
	avatar.swing()
	swung.emit()

func cancel_swing() -> void:
	swing_remaining = 0.0
	impact_pending = false
	avatar.swing_time = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.15
	floor_stop_on_slope = true
	# Ride moving pads normally, but keep jump control independent of their drift.
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.65
	collider.shape = capsule
	collider.position.y = 0.825
	add_child(collider)
	avatar = LilyAvatar.new()
	add_child(avatar)
	poison_cloud = Node3D.new()
	add_child(poison_cloud)
	var poison_mat := LilyAvatar.material(Color("ae79c5"))
	for i in 5:
		LilyAvatar.box(poison_cloud,Vector3.ZERO,Vector3.ONE*0.10,poison_mat)
	poison_cloud.visible = false
	pivot = Node3D.new()
	pivot.position.y = 1.1
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 7.6
	arm.margin = 0.24
	arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	arm.shape = sphere
	pivot.add_child(arm)
	arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.fov = 65
	camera.near = 0.08
	camera.far = 220.0
	arm.add_child(camera)
	camera.current = true
	shadow = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.40
	disk.bottom_radius = 0.40
	disk.height = 0.008
	disk.radial_segments = 24
	shadow.mesh = disk
	var shadow_mat := LilyAvatar.material(Color(0.05, 0.25, 0.19, 0.30))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child.call_deferred(shadow)
	ride = HoverRide.new()
	add_child(ride)
	ride.setup(self)
	reset_camera()

func reset_camera() -> void:
	yaw = 0.0
	pitch = -0.42
	pivot.rotation = Vector3(pitch, yaw, 0)

func clear_input() -> void:
	buffered = 0.0
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "attack", "boost"]:
		Input.action_release(action)

func respawn(spawn: Vector3) -> void:
	falling_through = false
	launch_cooldown = 0
	launch_count = 0
	camera_manual = 0
	camera_height = spawn.y
	global_position = spawn
	velocity = Vector3.ZERO
	coyote = 0.0
	buffered = 0.0
	jump_consumed = true
	avatar.rotation = Vector3.ZERO
	avatar.landing = 0.0
	avatar.scale = Vector3.ONE
	cancel_swing()
	clear_input()
	reset_camera()
	if is_instance_valid(ride): ride.reset(rapids)
	reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and look_delay <= 0.0:
		if event.relative.length() > 180.0:
			return
		camera_manual = 2.5
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -0.95, -0.16)
		pivot.rotation = Vector3(pitch, yaw, 0)
	if event.is_action_pressed("jump") and not event.is_echo() and not falling_through:
		buffered = buffer_duration
	if event.is_action_pressed("attack") and not event.is_echo():
		request_swing()

func _physics_process(delta: float) -> void:
	if not active:
		return
	look_delay = maxf(0.0, look_delay - delta)
	launch_cooldown = maxf(0,launch_cooldown-delta)
	camera_manual = maxf(0,camera_manual-delta)
	if is_instance_valid(rapids):
		ride.step(delta)
		stepped.emit(delta)
		return
	if poison_cloud.visible:
		poison_clock += delta
		for i in poison_cloud.get_child_count():
			var angle := poison_clock*2.1+i*TAU/5
			poison_cloud.get_child(i).position = Vector3(cos(angle)*0.65,0.55+fmod(poison_clock*0.65+i*0.3,1.2),sin(angle)*0.65)
	var grounded := is_on_floor() and not falling_through
	if grounded:
		coyote = coyote_duration
		jump_consumed = false
	else:
		coyote = maxf(0, coyote - delta)
	buffered = maxf(0, buffered - delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if falling_through:
		input = Vector2.ZERO
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	floor_snap_length = 0.15
	var target := direction * move_speed
	var rate := acceleration if direction.length() > 0.0 else braking
	if not grounded: rate = air_acceleration
	velocity.x = move_toward(velocity.x,target.x,rate*delta)
	velocity.z = move_toward(velocity.z,target.z,rate*delta)
	if not grounded: velocity.y -= gravity*delta
	if buffered > 0 and coyote > 0 and not jump_consumed:
		velocity.y = jump_speed
		buffered = 0.0
		coyote = 0.0
		jump_consumed = true
		jump_count += 1
		jumped.emit()
	if direction.length() > 0.05 and swing_remaining <= 0:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 16, 1))
	move_and_slide()
	if swing_remaining > 0:
		swing_remaining = maxf(0,swing_remaining-delta)
		if impact_pending and swing_remaining <= 0.36:
			impact_pending = false
			bat_impact.emit()
	if is_on_floor() and not grounded:
		avatar.landing = 1.0
		landed.emit()
	avatar.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y)
	update_flow_camera(delta)
	update_shadow()
	stepped.emit(delta)

func update_shadow() -> void:
	if not is_instance_valid(shadow) or not shadow.is_inside_tree():
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 8.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	shadow.visible = not hit.is_empty()
	if not hit.is_empty():
		shadow.global_position = hit.position + hit.normal * 0.014
		if is_instance_valid(rapids):
			var normal: Vector3 = hit.normal
			shadow.quaternion = Quaternion(Vector3.UP,normal)
		else:
			shadow.rotation = Vector3.ZERO
		var size := clampf(1.0 - (global_position.y - hit.position.y) * 0.10, 0.55, 1.0)
		shadow.scale = Vector3(size, 1, size)

func update_flow_camera(delta: float) -> void:
	if not is_instance_valid(rapids):
		pivot.position = Vector3(0,1.1,0)
		camera.fov = 65
		arm.spring_length = 7.6
		return
