class_name LilyDuelWater
extends Node3D
## Reactive night water: one plane, one shader, fixed-size uniform arrays (see MIDNIGHT_POND_SPEC section 8).

const MAX_RIPPLES := 24
const MAX_REFLECTIONS := 16
const MAX_FLASHES := 4
const RIPPLE_LIFETIME := 1.6
const FLASH_LIFETIME := 1.2
const REFLECTION_EPSILON := 0.002
const SHADER_PATH := "res://shaders/water_night.gdshader"

var surface: MeshInstance3D
var material: ShaderMaterial
var level := 0.04

var _ripple_data := PackedVector4Array()   # x, z, age01, strength (strength 0 = inactive)
var _ripple_age := PackedFloat32Array()    # seconds, -1 = inactive
var _flash_data := PackedVector4Array()    # x, z, age01, strength
var _flash_color := PackedColorArray()
var _flash_age := PackedFloat32Array()
var _refl_pos := PackedVector4Array()      # x, z, energy, phase
var _refl_col := PackedColorArray()
var _refl_dir := PackedVector2Array()      # unit direction from the light toward the camera (zero = none)
var _cam := Vector3(0, 24, 19)
var _ripple_count := 0
var _flash_count := 0
var _refl_count := 0
var _dirty := true

func build(size := 350.0, height := 0.04) -> void:
	if surface != null:
		surface.queue_free()
	level = height
	_ripple_data.resize(MAX_RIPPLES)
	_ripple_age.resize(MAX_RIPPLES)
	_flash_data.resize(MAX_FLASHES)
	_flash_color.resize(MAX_FLASHES)
	_flash_age.resize(MAX_FLASHES)
	_refl_pos.resize(MAX_REFLECTIONS)
	_refl_col.resize(MAX_REFLECTIONS)
	_refl_dir.resize(MAX_REFLECTIONS)
	_ripple_age.fill(-1.0)
	_flash_age.fill(-1.0)
	_ripple_data.fill(Vector4.ZERO)
	_flash_data.fill(Vector4.ZERO)
	_flash_color.fill(Color(0, 0, 0, 0))
	_refl_pos.fill(Vector4.ZERO)
	_refl_col.fill(Color(0, 0, 0, 0))
	_refl_dir.fill(Vector2.ZERO)
	_ripple_count = 0
	_flash_count = 0
	_refl_count = 0
	surface = MeshInstance3D.new()
	surface.name = "NightWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	surface.mesh = plane
	material = ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	surface.material_override = material
	surface.position = Vector3(0, height, -20)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	set_palette(Color(0.02, 0.10, 0.17), Color(0.05, 0.21, 0.30), Color(0.6, 0.85, 1.0))
	set_camera_position(Vector3(0, 24, 19))
	set_moon_direction(Vector3(0.4, -0.7, 0.5))
	_dirty = true
	_push()

func add_ripple(point: Vector3, strength := 1.0) -> void:
	if material == null:
		return
	var slot := -1
	var oldest := -1.0
	for i in MAX_RIPPLES:
		if _ripple_age[i] < 0.0:
			slot = i
			break
		if _ripple_age[i] > oldest:
			oldest = _ripple_age[i]
			slot = i
	if _ripple_age[slot] < 0.0:
		_ripple_count += 1
	_ripple_age[slot] = 0.0
	_ripple_data[slot] = Vector4(point.x, point.z, 0.0, maxf(strength, 0.05))
	_dirty = true

func flash(point: Vector3, color: Color, strength := 1.0) -> void:
	if material == null:
		return
	var slot := -1
	var oldest := -1.0
	for i in MAX_FLASHES:
		if _flash_age[i] < 0.0:
			slot = i
			break
		if _flash_age[i] > oldest:
			oldest = _flash_age[i]
			slot = i
	if _flash_age[slot] < 0.0:
		_flash_count += 1
	_flash_age[slot] = 0.0
	_flash_data[slot] = Vector4(point.x, point.z, 0.0, maxf(strength, 0.05))
	_flash_color[slot] = color
	_dirty = true

func set_reflections(lights: Array) -> void:
	if material == null:
		return
	var n := mini(lights.size(), MAX_REFLECTIONS)
	var used := 0
	var changed := false
	for i in n:
		var entry = lights[i]
		if not (entry is Dictionary):
			continue
		var p: Vector3 = entry.get("position", Vector3.ZERO)
		var c: Color = entry.get("color", Color.WHITE)
		var e: float = float(entry.get("energy", 1.0))
		var packed := Vector4(p.x, p.z, clampf(e, 0.0, 6.0), float(i) * 1.7)
		# Same light as last time (within a hair)? Then nothing needs sending to the GPU.
		if used >= _refl_count or absf(packed.x - _refl_pos[used].x) > REFLECTION_EPSILON \
				or absf(packed.y - _refl_pos[used].y) > REFLECTION_EPSILON \
				or absf(packed.z - _refl_pos[used].z) > REFLECTION_EPSILON or packed.w != _refl_pos[used].w \
				or absf(c.r - _refl_col[used].r) > REFLECTION_EPSILON or absf(c.g - _refl_col[used].g) > REFLECTION_EPSILON \
				or absf(c.b - _refl_col[used].b) > REFLECTION_EPSILON or absf(c.a - _refl_col[used].a) > REFLECTION_EPSILON:
			changed = true
			_refl_pos[used] = packed
			_refl_col[used] = c
			_refl_dir[used] = _direction_to_camera(p)
		used += 1
	if used != _refl_count:
		changed = true
		for i in range(used, MAX_REFLECTIONS):
			_refl_pos[i] = Vector4.ZERO
			_refl_col[i] = Color(0, 0, 0, 0)
			_refl_dir[i] = Vector2.ZERO
	if changed:
		_dirty = true
	_refl_count = used

# Unit vector on the ground from a light toward the (fixed) camera; zero when they coincide.
func _direction_to_camera(point: Vector3) -> Vector2:
	var to_cam := Vector2(_cam.x - point.x, _cam.z - point.z)
	var dl := to_cam.length()
	return to_cam / dl if dl >= 0.01 else Vector2.ZERO

func set_camera_position(point: Vector3) -> void:
	_cam = point
	if material:
		material.set_shader_parameter("cam_pos", point)
		for i in _refl_count:
			_refl_dir[i] = _direction_to_camera(Vector3(_refl_pos[i].x, 0.0, _refl_pos[i].y))
		_dirty = true

func set_moon_direction(direction: Vector3) -> void:
	if material:
		material.set_shader_parameter("moon_dir", direction.normalized() if direction.length() > 0.0001 else Vector3(0.4, -0.7, 0.5).normalized())

# The three colours go to the shader as Color values (what its source_color hint expects).
func set_palette(deep: Color, light: Color, glint: Color) -> void:
	if material:
		material.set_shader_parameter("deep_color", deep)
		material.set_shader_parameter("light_color", light)
		material.set_shader_parameter("glint_color", glint)

func set_level(height: float) -> void:
	level = height
	if surface:
		surface.position.y = height

func advance(delta: float) -> void:
	if material == null:
		return
	var animating := false
	if _ripple_count > 0:
		for i in MAX_RIPPLES:
			var age := _ripple_age[i]
			if age < 0.0:
				continue
			age += delta
			if age >= RIPPLE_LIFETIME:
				_ripple_age[i] = -1.0
				_ripple_data[i] = Vector4.ZERO
				_ripple_count -= 1
			else:
				_ripple_age[i] = age
				var d := _ripple_data[i]
				d.z = age / RIPPLE_LIFETIME
				_ripple_data[i] = d
		animating = true
	if _flash_count > 0:
		for i in MAX_FLASHES:
			var age := _flash_age[i]
			if age < 0.0:
				continue
			age += delta
			if age >= FLASH_LIFETIME:
				_flash_age[i] = -1.0
				_flash_data[i] = Vector4.ZERO
				_flash_color[i] = Color(0, 0, 0, 0)
				_flash_count -= 1
			else:
				_flash_age[i] = age
				var d := _flash_data[i]
				d.z = age / FLASH_LIFETIME
				_flash_data[i] = d
		animating = true
	if animating or _dirty:
		_dirty = false
		_push()

func _push() -> void:
	material.set_shader_parameter("ripples", _ripple_data)
	material.set_shader_parameter("flashes", _flash_data)
	material.set_shader_parameter("flash_colors", _flash_color)
	material.set_shader_parameter("refl_pos", _refl_pos)
	material.set_shader_parameter("refl_col", _refl_col)
	material.set_shader_parameter("refl_dir", _refl_dir)

func debug_snapshot() -> Dictionary:
	return {"ripples": _ripple_count, "flashes": _flash_count, "reflections": _refl_count, "level": level}
