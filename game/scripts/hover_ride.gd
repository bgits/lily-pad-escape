class_name HoverRide
extends Node

const HOVER_HEIGHT := 0.55
var player: LilyPlayer
var track: RiverRapids
var board: Node3D
var jets: Array[MeshInstance3D] = []
var leg := 0
var distance := 0.0
var shortcut := false
var speed := 12.0
var lateral := 0.0
var lateral_velocity := 0.0
var energy := 100.0
var attached := true
var completed := false
var crashed := false
var reason := ""
var boosting := false
var course_distance := 0.0
var air_velocity := Vector3.ZERO
var jump_down := false
var loop_inverted := false
var spiral_completed := false
var route_taken := "wide"
var camera_look := Vector3.ZERO
var air_time := 0.0
var current_frame: Dictionary = {}
var takeoff_frame: Dictionary = {}
var bump_cooldown := 0.0

func setup(owner_player: LilyPlayer) -> void:
	player = owner_player
	board = Node3D.new()
	player.add_child(board)
	var deck := LilyAvatar.material(Color("23394e"))
	var trim := LilyAvatar.material(Color("f6c860"))
	var glow := LilyAvatar.material(Color("68fff0"))
	glow.emission_enabled = true
	glow.emission = Color("38b7ba")
	LilyAvatar.box(board,Vector3(0,-0.14,0),Vector3(1.05,0.18,2.1),deck)
	LilyAvatar.box(board,Vector3(0,-0.10,-1.03),Vector3(0.86,0.13,0.32),trim).rotation.x = -0.18
	LilyAvatar.box(board,Vector3(0,-0.10,1.03),Vector3(0.86,0.13,0.32),trim).rotation.x = 0.18
	for side in [-1,1]:
		LilyAvatar.box(board,Vector3(side*0.47,-0.12,0),Vector3(0.09,0.12,1.8),glow)
		LilyAvatar.box(board,Vector3(0,-0.03,side*0.4),Vector3(0.75,0.05,0.24),trim)
		jets.append(LilyAvatar.box(board,Vector3(side*0.32,-0.3,0.65),Vector3(0.23,0.13,0.7),glow))
	board.visible = false

func reset(course: RiverRapids) -> void:
	track = course
	board.visible = is_instance_valid(track)
	leg = 0
	distance = 0
	shortcut = false
	speed = 12
	lateral = 0
	lateral_velocity = 0
	energy = 100
	attached = true
	completed = false
	crashed = false
	reason = ""
	boosting = false
	course_distance = 0
	air_velocity = Vector3.ZERO
	jump_down = false
	loop_inverted = false
	spiral_completed = false
	route_taken = "wide"
	air_time = 0
	bump_cooldown = 0
	# SpringArm rewrites direct-child camera transforms even with top_level set.
	# Give the board its own chase camera parent; restore the arm for walking.
	var camera_parent: Node3D = player if is_instance_valid(track) else player.arm
	if player.camera.get_parent() != camera_parent: player.camera.reparent(camera_parent)
	player.camera.top_level = is_instance_valid(track)
	player.camera.far = 650 if is_instance_valid(track) else 220
	if is_instance_valid(track):
		current_frame = track.frame(0,0)
		player.global_position = current_frame.p+current_frame.up*HOVER_HEIGHT
		player.camera.global_position = player.position-current_frame.f*11+Vector3.UP*5
		camera_look = player.position+current_frame.f*12
		player.camera.look_at(camera_look,Vector3.UP)
		animate_board(0)
	else:
		player.camera.transform = Transform3D.IDENTITY
		player.avatar.rotation = Vector3.ZERO
		player.avatar.left_leg.position.x = -0.17
		player.avatar.right_leg.position.x = 0.17

func step(delta: float) -> void:
	if crashed or completed: return
	bump_cooldown = maxf(0,bump_cooldown-delta)
	var steering := Input.get_axis("move_left","move_right")
	var throttle := Input.get_action_strength("move_forward")
	var braking := Input.get_action_strength("move_back")
	var held_jump := Input.is_action_pressed("jump")
	var jump := held_jump and not jump_down
	jump_down = held_jump
	boosting = Input.is_action_pressed("boost") and energy > 1 and braking < 0.1
	energy = clampf(energy+(-42.0 if boosting else 18.0)*delta,0,100)
	var target_speed := track.boost_speed if boosting else lerpf(track.cruise_speed,track.throttle_speed,throttle)
	if braking > 0.1: target_speed = 9.0
	speed = move_toward(speed,target_speed,(22.0 if braking > 0.1 else 13.0)*delta)
	current_frame = track.frame(leg,distance,shortcut)
	if attached:
		speed = clampf(speed+Vector3.DOWN.dot(current_frame.f)*12.0*delta,6,track.speed_limit)
	lateral_velocity = move_toward(lateral_velocity,steering*track.steer_speed,22*delta)
	if attached and jump:
		launch(8.4,false)
	if attached:
		lateral += lateral_velocity*delta
		advance_path(speed*delta)
		current_frame = track.frame(leg,distance,shortcut)
		if track.beginner and track.legs[leg].kind != "gap":
			var edge := float(current_frame.width)*0.5-0.65
			if absf(lateral) > edge:
				lateral = clampf(lateral,-edge,edge)
				lateral_velocity = 0
				if bump_cooldown <= 0:
					speed *= 0.85
					bump_cooldown = 0.6
		player.position = current_frame.p+current_frame.right*lateral+current_frame.up*HOVER_HEIGHT
		player.velocity = current_frame.f*speed+current_frame.right*lateral_velocity
		if track.legs[leg].kind == "gap":
			launch(6.8,true)
		elif absf(lateral) > float(current_frame.width)*0.5-0.1:
			launch(0,false,false)
	else:
		air_time += delta
		var old_position := player.position
		air_velocity += Vector3.DOWN*22*delta
		if boosting: air_velocity += Vector3(current_frame.f)*8*delta
		air_velocity += Vector3(current_frame.right)*steering*11*delta
		player.position += air_velocity*delta
		advance_path(maxf(0,air_velocity.dot(current_frame.f))*delta)
		current_frame = track.frame(leg,distance,shortcut)
		var offset: Vector3 = player.position-current_frame.p
		var height := offset.dot(current_frame.up)
		var side := offset.dot(current_frame.right)
		var along := offset.dot(current_frame.f)
		# Land only when the ballistic trajectory actually crosses the visible deck.
		if track.legs[leg].kind != "gap" and height <= HOVER_HEIGHT and height > -0.8 and absf(side) < float(current_frame.width)*0.5-0.15 and absf(along) < 4.0 and air_velocity.dot(current_frame.up) < 0:
			attached = true
			lateral = side
			lateral_velocity = clampf(air_velocity.dot(current_frame.right),-track.steer_speed,track.steer_speed)
			speed = clampf(air_velocity.dot(current_frame.f),9,track.speed_limit)
			player.position = current_frame.p+current_frame.right*lateral+current_frame.up*HOVER_HEIGHT
			player.landed.emit()
			air_time = 0
		player.velocity = (player.position-old_position)/delta
		if air_time > 3.5: crash("Missed the landing — carry speed and line up early.")
	course_distance = track.course_progress(leg,distance,shortcut)
	if Vector3(current_frame.up).y < -0.8 and attached: loop_inverted = true
	for hazard in track.hazards:
		if int(hazard.leg) != leg or absf(distance-float(hazard.distance)) > 1.25: continue
		var offset: Vector3 = player.position-current_frame.p
		if absf(offset.dot(current_frame.right)-float(hazard.lateral)) < float(hazard.half_width)+0.35 and offset.dot(current_frame.up) < float(hazard.height)+0.5:
			if track.beginner:
				if bump_cooldown <= 0:
					speed = maxf(9,speed*0.65)
					lateral = float(hazard.lateral)-signf(hazard.lateral)*(float(hazard.half_width)+0.5)
					lateral_velocity = -signf(hazard.lateral)*2
					bump_cooldown = 0.8
			else:
				crash("Clipped a coral block — steer around it or hop over.")
	if player.position.y < -0.1: crash("Splash! Keep the board on the track.")
	animate_board(delta)
	update_camera(delta)
	player.shadow.visible = attached and Vector3(current_frame.up).y > 0.4
	if player.shadow.visible:
		player.shadow.position = current_frame.p+current_frame.right*lateral+current_frame.up*0.02
		player.shadow.quaternion = Quaternion(Vector3.UP,Vector3(current_frame.up))

func advance_path(amount: float) -> void:
	distance += amount
	while distance >= track.path_length(leg,shortcut):
		var remaining := distance-track.path_length(leg,shortcut)
		var end := track.frame(leg,track.path_length(leg,shortcut),shortcut)
		var endpoint: Vector3 = end.p+end.right*lateral
		if leg == track.legs.size()-1:
			distance = track.path_length(leg,shortcut)
			completed = attached
			return
		if track.legs[leg].kind == "spiral": spiral_completed = true
		var entering_split: bool = track.legs[leg].kind == "fork"
		leg += 1
		if track.legs[leg].kind == "gap": takeoff_frame = end
		if entering_split:
			shortcut = lateral < 0
			route_taken = "fast" if shortcut else "wide"
		elif track.legs[leg].kind != "split": shortcut = false
		var start := track.frame(leg,0,shortcut)
		lateral = (endpoint-Vector3(start.p)).dot(start.right)
		distance = remaining

func launch(lift: float, ramp: bool, sound := true) -> void:
	attached = false
	air_time = 0
	var launch_frame := takeoff_frame if ramp and not takeoff_frame.is_empty() else current_frame
	air_velocity = launch_frame.f*speed+launch_frame.right*lateral_velocity+launch_frame.up*lift
	if ramp:
		player.launch_count += 1
		player.launched.emit()
	elif sound:
		player.jump_count += 1
		player.jumped.emit()

func crash(message: String) -> void:
	crashed = true
	reason = message

func animate_board(delta: float) -> void:
	player.avatar.animate(delta,0,attached,air_velocity.y)
	var orientation: Basis = current_frame.basis
	if not attached:
		var f := Vector3(air_velocity.x,0,air_velocity.z).normalized()
		if f.length() > 0.1: orientation = Basis(f.cross(Vector3.UP),Vector3.UP,-f)
	var lean := Basis(Vector3.FORWARD,lateral_velocity*0.025)
	board.basis = orientation*lean
	player.avatar.basis = orientation*lean*Basis(Vector3.UP,PI/2)
	player.avatar.left_leg.position.x = -0.32
	player.avatar.right_leg.position.x = 0.32
	player.avatar.left_leg.rotation.x = -0.15
	player.avatar.right_leg.rotation.x = 0.12
	player.avatar.left_arm.rotation.z = -0.65
	player.avatar.right_arm.rotation.z = 0.65
	player.avatar.left_arm.rotation.x = -0.3
	player.avatar.right_arm.rotation.x = 0.3
	for jet in jets: jet.scale.z = lerpf(jet.scale.z,2.5 if boosting else 0.8,delta*8)

func update_camera(delta: float) -> void:
	var f: Vector3 = current_frame.f
	var desired: Vector3 = player.position-f*11+Vector3.UP*5
	var look: Vector3 = player.position+f*12+Vector3.UP
	var loop_preview := clampf((distance-track.path_length(leg)+35)/35,0,1) if leg+1 < track.legs.size() and track.legs[leg+1].kind == "loop" else 0.0
	if loop_preview > 0:
		desired = desired.lerp(track.loop_camera,loop_preview)
		look = look.lerp(player.position.lerp(track.loop_focus,0.25),loop_preview)
	if track.legs[leg].kind == "loop":
		desired = track.loop_camera
		look = player.position.lerp(track.loop_focus,0.25)
	else:
		desired = player.position+(desired-player.position).rotated(Vector3.UP,player.yaw)
	player.camera.global_position = player.camera.global_position.lerp(desired,1-exp(-delta*5))
	camera_look = camera_look.lerp(look,1-exp(-delta*7))
	player.camera.look_at(camera_look,Vector3.UP)
	player.camera.fov = lerpf(player.camera.fov,72+clampf((speed-20)*0.7,0,8),1-exp(-delta*3))
	if player.camera_manual <= 0: player.yaw = lerpf(player.yaw,0,1-exp(-delta*2))
