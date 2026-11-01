class_name LilyDecoyPad
extends StaticBody3D

var collapsed := false
var sink_time := 0.0
var home_position := Vector3.ZERO
var collider: CollisionShape3D
var marker: LilyFrog
var is_chance := false
var resolved := false

func resolve_chance(random: RandomNumberGenerator) -> bool:
	if not resolved:
		resolved = true
		if random.randf() < 0.5:
			collapse()
	return collapsed

func _ready() -> void:
	home_position = position

func collapse() -> bool:
	if collapsed:
		return false
	collapsed = true
	sink_time = 0.0
	# Remove support on the contact frame; the visible pad then sinks away.
	collision_layer = 0
	collider.set_deferred("disabled",true)
	return true

func advance(delta: float) -> void:
	if not collapsed:
		return
	sink_time = minf(sink_time+delta,0.55)
	var t := sink_time/0.55
	position.y = home_position.y - t*2.8
	rotation = Vector3(sin(t*PI)*0.22,0,sin(t*PI)*-0.16)
	visible = t < 1.0

func reset_trap() -> void:
	resolved = false
	collapsed = false
	sink_time = 0.0
	position = home_position
	rotation = Vector3.ZERO
	visible = true
	collision_layer = 1
	collider.set_deferred("disabled",false)
