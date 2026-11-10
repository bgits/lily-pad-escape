class_name LilyLevel
extends Resource

@export var title := "Sunlit lagoon"
@export var has_bat := false
@export var river_rapids := false
@export var rapids_beginner := false
@export var poison_damage_per_second := 20.0
@export var frog_pads: Array[int] = []
@export var chance_pad_indices: Array[int] = []
# Permanent precision platforms around optional chance pads: X, Z, radius.
@export var bypass_pads: Array[Vector3] = []
# Optional exploration branches. X, Z, radius; drift travel is a world-space offset.
@export var drift_pad := Vector3.ZERO
@export var drift_travel := Vector3(3.2,0,0)
@export var exploration_pads: Array[Vector3] = []
# Three world-space locations. The first firefly rides the drifting pad.
@export var fireflies: Array[Vector3] = []
# Optional side paths, using the same X, Z, radius layout as the safe pads.
@export var decoy_pads: Array[Vector3] = []

# X, Z, radius. All required surfaces have a top at 0.60 m.
@export var pads: Array[Vector3] = [
	Vector3(0, 0, 2.70),
	Vector3(0, -5.35, 1.90),
	Vector3(1.50, -9.80, 1.85),
	Vector3(3.80, -14.40, 1.85),
	Vector3(4.30, -19.30, 1.80),
	Vector3(2.00, -23.80, 1.85),
	Vector3(-0.20, -28.40, 1.80),
	Vector3(1.70, -33.10, 1.85),
	Vector3(4.30, -37.50, 1.90),
]
@export var spawn := Vector3(0, 0.68, 0.55)
@export var island_center := Vector3(5.50, 0.0, -43.50)
@export var island_radius := 3.35
@export var flag_position := Vector3(5.50, 0.60, -43.80)
@export var water_height := 0.04
@export var surface_height := 0.60
