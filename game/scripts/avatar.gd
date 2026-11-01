class_name LilyAvatar
extends Node3D

var hoodie: StandardMaterial3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var torso: Node3D
var clock := 0.0
var landing := 0.0
var bat: Node3D
var swing_time := 0.0
var outfit: Dictionary = LilyAppearance.DEFAULTS.duplicate()
var ponytail: Node3D

func equip_bat(equipped: bool) -> void:
	bat.visible = equipped
	swing_time = 0.0

func swing() -> void:
	swing_time = 0.48

func make_bat() -> void:
	bat = Node3D.new()
	bat.position = Vector3(0,-0.40,-0.03)
	bat.rotation = Vector3(0.35,0,-0.50)
	right_arm.add_child(bat)
	var wood := material(Color("c48a4e"))
	var grip := material(Color("503b32"))
	for section in [Vector3(0.08,0.26,0.13),Vector3(0.12,0.33,0.42),Vector3(0.18,0.64,0.88)]:
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = section.x*0.65
		mesh.top_radius = section.x
		mesh.height = section.y
		mesh.radial_segments = 8
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = grip if section.z < 0.2 else wood
		part.position.y = section.z
		bat.add_child(part)
	box(bat,Vector3(0,-0.035,0),Vector3(0.18,0.07,0.18),wood)
	bat.visible = false

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	return result

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func _ready() -> void:
	apply_appearance(outfit)

func apply_appearance(data: Dictionary) -> void:
	outfit = LilyAppearance.sanitize(data,true)
	var equipped := is_instance_valid(bat) and bat.visible
	# Keep the avatar root, heading, and animation clocks; rebuild only its outfit.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	ponytail = null
	hoodie = material(LilyAppearance.color_for(outfit,"top_color"))
	var skin := material(LilyAppearance.color_for(outfit,"skin"))
	var hair := material(LilyAppearance.color_for(outfit,"hair_color"))
	var pants := material(LilyAppearance.color_for(outfit,"pants_color"))
	var shoe := material(LilyAppearance.color_for(outfit,"shoe_color"))
	var cream := material(Color("fff2d3"))
	var ink := material(Color("243c51"))
	var trim := material(hoodie.albedo_color.darkened(0.18))
	var shoulder: float = [0.40,0.36,0.38][outfit.character]
	var width: float = [0.60,0.54,0.57][outfit.character]
	var head_width: float = [0.56,0.53,0.55][outfit.character]
	torso = Node3D.new()
	add_child(torso)
	box(torso,Vector3(0,0.91,0),Vector3(width,0.57,0.38),hoodie)
	if outfit.top_style == 0:
		box(torso,Vector3(0,1.14,0.17),Vector3(0.46,0.20,0.16),hoodie)
		box(torso,Vector3(0,0.78,-0.21),Vector3(0.30,0.13,0.06),trim)
		for side in [-1,1]:
			box(torso,Vector3(side*0.12,1.08,-0.21),Vector3(0.025,0.13,0.03),cream)
	elif outfit.top_style == 1:
		box(torso,Vector3(0,1.17,-0.02),Vector3(0.25,0.045,0.35),trim)
		box(torso,Vector3(0.15,0.99,-0.20),Vector3(0.12,0.12,0.025),trim)
	else:
		box(torso,Vector3(0,0.94,-0.20),Vector3(0.19,0.49,0.035),cream)
		for side in [-1,1]:
			box(torso,Vector3(side*0.12,0.94,-0.225),Vector3(0.04,0.5,0.035),trim)
			box(torso,Vector3(side*0.21,0.80,-0.22),Vector3(0.13,0.10,0.035),trim)
			box(torso,Vector3(side*0.15,1.16,-0.10),Vector3(0.14,0.10,0.25),hoodie)
	box(torso,Vector3(0,1.47,-0.01),Vector3(head_width,0.53,0.48),skin)
	build_hair(hair,head_width)
	box(torso,Vector3(0.13,1.48,-0.257),Vector3(0.055,0.065,0.018),ink)
	box(torso,Vector3(-0.13,1.48,-0.257),Vector3(0.055,0.065,0.018),ink)
	box(torso,Vector3(0,1.35,-0.258),Vector3(0.11,0.025,0.018),material(Color("704732")))
	for side in [-1.0,1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*shoulder,1.10,0)
		torso.add_child(arm)
		if outfit.top_style == 1:
			box(arm,Vector3(0,-0.10,0),Vector3(0.23,0.25,0.28),hoodie)
			box(arm,Vector3(0,-0.31,0),Vector3(0.19,0.24,0.23),skin)
		else:
			box(arm,Vector3(0,-0.18,0),Vector3(0.22,0.42,0.28),hoodie)
		box(arm,Vector3(0,-0.41,0),Vector3(0.20,0.14,0.23),skin)
		var leg := Node3D.new()
		leg.position = Vector3(side*0.17,0.65,0)
		add_child(leg)
		if outfit.pants_style == 0:
			box(leg,Vector3(0,-0.12,0),Vector3(0.28,0.29,0.33),pants)
			box(leg,Vector3(0,-0.34,0),Vector3(0.16,0.22,0.20),skin)
			box(leg,Vector3(0,-0.45,0),Vector3(0.18,0.13,0.23),cream)
		else:
			box(leg,Vector3(0,-0.27,0),Vector3(0.27,0.58,0.32),pants)
			if outfit.pants_style == 2:
				box(leg,Vector3(0,-0.49,0),Vector3(0.22,0.10,0.29),material(pants.albedo_color.darkened(0.18)))
			else:
				box(leg,Vector3(side*0.13,-0.25,0),Vector3(0.015,0.52,0.28),material(pants.albedo_color.lightened(0.20)))
		var height: float = [0.16,0.30,0.24][outfit.shoe_style]
		box(leg,Vector3(0,-0.61+height*0.5,-0.06),Vector3(0.28,height,0.39),shoe)
		box(leg,Vector3(0,-0.61,-0.06),Vector3(0.29,0.055,0.40),ink if outfit.shoe_style == 1 else cream)
		if outfit.shoe_style != 1:
			box(leg,Vector3(0,-0.61+height*0.65,-0.263),Vector3(0.15,0.035,0.02),cream)
			if outfit.shoe_style == 2:
				box(leg,Vector3(0,-0.40,-0.06),Vector3(0.29,0.035,0.39),cream)
		if side < 0:
			left_arm = arm
			left_leg = leg
		else:
			right_arm = arm
			right_leg = leg
	make_bat()
	bat.visible = equipped

func build_hair(hair: StandardMaterial3D, head_width: float) -> void:
	if outfit.hair_style == 5:
		return
	var hair_root := Node3D.new()
	hair_root.name = "Hair"
	torso.add_child(hair_root)
	var light := material(hair.albedo_color.lightened(0.12))
	var width := head_width+0.08
	if outfit.hair_style == 4:
		box(hair_root,Vector3(0,1.73,0.02),Vector3(width,0.085,0.53),hair)
		box(hair_root,Vector3(0,1.61,0.23),Vector3(width,0.20,0.09),hair)
		return
	box(hair_root,Vector3(0,1.73,0.025),Vector3(width,0.20,0.58),hair)
	box(hair_root,Vector3(0,1.48,0.22),Vector3(width-0.04,0.42,0.16),hair)
	if outfit.hair_style == 3:
		for x in 3:
			for z in 3:
				box(hair_root,Vector3((x-1)*0.22,1.79+0.035*((x+z)%2),(z-1)*0.21),Vector3(0.26,0.23,0.26),light if (x+z)%2 else hair)
		for side in [-1,1]:
			box(hair_root,Vector3(side*width*0.47,1.60,0.04),Vector3(0.20,0.29,0.45),hair)
	else:
		var length := 0.54 if outfit.hair_style == 1 else 0.28
		for side in [-1,1]:
			box(hair_root,Vector3(side*width*0.45,1.70-length*0.5,0.02),Vector3(0.14,length,0.49),hair)
		box(hair_root,Vector3(-0.13,1.65,-0.27),Vector3(0.34,0.16,0.09),light)
		box(hair_root,Vector3(0.16,1.70,-0.27),Vector3(0.20,0.13,0.08),hair)
	if outfit.hair_style == 2:
		ponytail = Node3D.new()
		ponytail.position = Vector3(0,1.62,0.32)
		hair_root.add_child(ponytail)
		box(ponytail,Vector3(0,-0.21,0.10),Vector3(0.26,0.58,0.24),hair)
		box(ponytail,Vector3(0,0.02,0.07),Vector3(0.28,0.075,0.25),material(Color("f3cc58")))

func animate(delta: float, speed: float, grounded: bool, vertical: float) -> void:
	clock += delta
	if is_instance_valid(ponytail):
		ponytail.rotation.x = sin(clock*3.0)*0.08
	landing = move_toward(landing, 0, delta * 3.5)
	var stride := sin(clock * 13.0) * minf(speed / 5.4, 1.0) * 0.62
	left_leg.rotation.x = stride if grounded else -0.22
	right_leg.rotation.x = -stride if grounded else 0.35
	left_arm.rotation.x = -stride if grounded else -0.7
	right_arm.rotation.x = stride if grounded else -0.7
	right_arm.rotation.y = 0
	right_arm.rotation.z = 0
	if bat.visible:
		right_arm.rotation.x = -0.25
		right_arm.rotation.z = -0.18
		bat.rotation = Vector3(0.35,0,-0.50)
		if swing_time > 0:
			swing_time = maxf(0,swing_time-delta)
			var t := 1.0 - swing_time/0.48
			# Wind-up, a quick sweep across the front, then return to ready.
			var sweep := lerpf(-1.4,1.2,clampf(t/0.50,0,1))
			if t > 0.5:
				sweep = lerpf(1.2,0,(t-0.5)*2)
			right_arm.rotation.y = sweep
			right_arm.rotation.x = -0.18 - sin(t*PI)*0.25
			left_arm.rotation.x = -sin(t*PI)*0.65
			var recovery := clampf((t-0.5)*2,0,1)
			bat.rotation.x = lerpf(-PI/2,0.35,recovery)
			bat.rotation.z = lerpf(0,-0.50,recovery)
	torso.position.y = sin(clock * 2.8) * 0.016 if speed < 0.1 else absf(sin(clock * 13)) * 0.035
	torso.rotation.x = -0.07 if not grounded and vertical > 0 else 0.0
	scale = Vector3(1.0 + landing * 0.12, 1.0 - landing * 0.16, 1.0 + landing * 0.12)
