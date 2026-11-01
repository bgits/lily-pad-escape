class_name LilyFrog
extends AnimatableBody3D

var alive := true
var is_decoy := false
var is_chance := false
var pad_index := 0
var clock := 0.0
var death_time := 0.0
var visual: Node3D
var collider: CollisionShape3D
var home_position := Vector3.ZERO
var behavior := "watching"
var landing_marker: MeshInstance3D
const CYCLE := 4.8
const WATCH := 1.6
const CROUCH := 0.7
const HOP := 0.7

func _ready() -> void:
	home_position = position
	collision_layer = 0 if is_decoy or is_chance else 4
	collision_mask = 0
	visual = Node3D.new()
	add_child(visual)
	var green := LilyAvatar.material(Color("c49a28") if is_chance else (Color("b13942") if is_decoy else Color("508c49")))
	var lime := LilyAvatar.material(Color("f4d654") if is_chance else (Color("ee5659") if is_decoy else Color("88b85a")))
	var belly := LilyAvatar.material(Color("fff2b4") if is_chance else (Color("ffb29a") if is_decoy else Color("dbe5a3")))
	var gold := LilyAvatar.material(Color("fff1a2"))
	var ink := LilyAvatar.material(Color("193d32"))
	LilyAvatar.box(visual, Vector3(0,0.43,0.03), Vector3(0.88,0.55,0.72), green)
	LilyAvatar.box(visual, Vector3(0,0.43,-0.34), Vector3(0.72,0.34,0.12), belly)
	LilyAvatar.box(visual, Vector3(0,0.63,-0.12), Vector3(0.96,0.28,0.65), lime)
	LilyAvatar.box(visual, Vector3(0,0.48,-0.46), Vector3(0.60,0.035,0.02), ink)
	for side in [-1.0,1.0]:
		LilyAvatar.box(visual, Vector3(side*0.34,0.84,-0.20), Vector3(0.32,0.35,0.31), green)
		LilyAvatar.box(visual, Vector3(side*0.34,0.85,-0.365), Vector3(0.25,0.23,0.04), gold)
		LilyAvatar.box(visual, Vector3(side*0.34,0.85,-0.39), Vector3(0.09,0.15,0.02), ink)
		LilyAvatar.box(visual, Vector3(side*0.52,0.19,0.23), Vector3(0.36,0.32,0.48), green)
		LilyAvatar.box(visual, Vector3(side*0.48,0.07,-0.17), Vector3(0.42,0.14,0.47), lime)
		LilyAvatar.box(visual, Vector3(side*0.29,0.11,-0.44), Vector3(0.14,0.24,0.25), green)
	for x in [-0.24,0.0,0.24]:
		LilyAvatar.box(visual, Vector3(x,0.72,0.21), Vector3(0.13,0.04,0.16), green)
	collider = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.57
	shape.height = 0.83
	collider.shape = shape
	collider.position.y = 0.415
	# A warning frog is decorative: it must never become a foothold over a trap.
	collider.disabled = is_decoy or is_chance
	add_child(collider)
	clock = pad_index * 0.13
	rotation.y = PI
	if not is_decoy and not is_chance:
		landing_marker = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.26
		ring.outer_radius = 0.32
		ring.rings = 24
		ring.ring_segments = 4
		landing_marker.mesh = ring
		landing_marker.material_override = LilyAvatar.material(Color("ffe18a"))
		landing_marker.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		landing_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(landing_marker)
		landing_marker.top_level = true
		landing_marker.visible = false

func defeat() -> void:
	if is_decoy or is_chance or not alive:
		return
	alive = false
	behavior = "defeated"
	if is_instance_valid(landing_marker):
		landing_marker.visible = false
	collision_layer = 0
	collider.set_deferred("disabled",true)
	death_time = 0.0

func animate(delta: float, player_position: Vector3) -> void:
	if not alive:
		death_time += delta
		var t := clampf(death_time / 0.38,0,1)
		visual.position.y = sin(t*PI)*0.8
		visual.rotation.z = t*PI
		visual.scale = Vector3.ONE * (1-t)
		visible = t < 1
		return
	clock += delta
	if not is_decoy and not is_chance:
		animate_hop(player_position)
		return
	# A small hop and throat pulse keep the silhouette readable on its pad.
	var hop := maxf(0,sin(clock*2.2))
	visual.position.y = hop*hop*0.18
	visual.scale = Vector3(1+sin(clock*4.4)*0.025,1-sin(clock*4.4)*0.035,1)
	var offset := player_position - global_position
	if Vector2(offset.x,offset.z).length() < 8:
		rotation.y = lerp_angle(rotation.y,atan2(-offset.x,-offset.z),minf(1,delta*5))

func animate_hop(player_position: Vector3) -> void:
	var t := fposmod(clock,CYCLE)
	var reverse := int(clock/CYCLE)%2 == 1
	var side := -1.0 if pad_index%2 == 0 else 1.0
	var a := home_position+Vector3(side*0.9 if reverse else 0.0,0,0)
	var b := home_position+Vector3(0.0 if reverse else side*0.9,0,0)
	landing_marker.global_position = get_parent().to_global(b)+Vector3.UP*0.025
	landing_marker.visible = t >= WATCH and t < WATCH+CROUCH+HOP
	visual.position.y = 0.0
	visual.scale = Vector3.ONE
	if t < WATCH:
		behavior = "watching"
		position = a
		visual.scale.y = 1.0+sin(clock*3.0)*0.025
	elif t < WATCH+CROUCH:
		behavior = "crouching"
		position = a
		var amount := (t-WATCH)/CROUCH
		visual.scale = Vector3(1.0+amount*0.18,1.0-amount*0.36,1.0+amount*0.12)
		landing_marker.scale = Vector3.ONE*(1.0+sin(amount*PI*4)*0.12)
	elif t < WATCH+CROUCH+HOP:
		behavior = "hopping"
		var amount := (t-WATCH-CROUCH)/HOP
		position = a.lerp(b,amount)+Vector3.UP*sin(amount*PI)*0.8
		visual.scale = Vector3(0.93,1.12,0.93)
	else:
		behavior = "resting"
		position = b
		var squash := maxf(0.0,1.0-(t-WATCH-CROUCH-HOP)/0.25)
		visual.scale = Vector3(1.0+squash*0.16,1.0-squash*0.25,1.0+squash*0.12)
	if behavior in ["watching","resting"]:
		var offset := player_position-global_position
		if Vector2(offset.x,offset.z).length() < 8:
			rotation.y = lerp_angle(rotation.y,atan2(-offset.x,-offset.z),0.08)
