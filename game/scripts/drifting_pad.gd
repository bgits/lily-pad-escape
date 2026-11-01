class_name LilyDriftingPad
extends AnimatableBody3D

var home := Vector3.ZERO
var travel := Vector3(3.2,0,0)
var clock := 0.0
const PERIOD := 8.0
const DWELL := 1.0
const LEG := 3.0

func fraction_at(seconds: float) -> float:
	var t := fposmod(seconds,PERIOD)
	if t < DWELL:
		return 0.0
	if t < DWELL+LEG:
		return (1.0-cos((t-DWELL)/LEG*PI))*0.5
	if t < DWELL*2+LEG:
		return 1.0
	return (1.0+cos((t-DWELL*2-LEG)/LEG*PI))*0.5

func advance(delta: float) -> void:
	clock += delta
	position = home+travel*fraction_at(clock)

func reset_motion() -> void:
	clock = 0.0
	# Reset without generating a large platform velocity on the next physics step.
	sync_to_physics = false
	position = home
	reset_physics_interpolation()
	sync_to_physics = true

