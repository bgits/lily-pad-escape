class_name LilyDuelFx
extends RefCounted

# Shared, cached visual helpers for the Midnight Pond entities: a soft radial glow texture
# built in code, additive unshaded materials, shared unit quads and a ring-buffer ribbon trail.
# Nothing here needs bloom: every effect is plain additive blending.

static var glow_tex: ImageTexture
static var ray_tex: ImageTexture
static var unit_quad_mesh: QuadMesh
static var ray_quad_mesh: QuadMesh
static var ribbon_mat: StandardMaterial3D
static var material_cache := {}

static func glow_texture() -> ImageTexture:
	if glow_tex == null:
		var size := 64
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
				var falloff := clampf(1.0 - d, 0.0, 1.0)
				var a := minf(1.0, falloff * falloff * 0.9 + pow(falloff, 6.0) * 0.9)
				image.set_pixel(x, y, Color(1, 1, 1, a))
		glow_tex = ImageTexture.create_from_image(image)
	return glow_tex

# Light-ray texture: u across (soft edges), v along (v = 1 at the base of the ray, 0 at the tip).
static func ray_texture() -> ImageTexture:
	if ray_tex == null:
		var w := 16
		var h := 64
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var out := 1.0 - (y + 0.5) / h   # 0 at the base, 1 at the tip
			var along := pow(1.0 - out, 1.4) * smoothstep(0.0, 0.28, out)
			for x in w:
				var across := 1.0 - absf((x + 0.5) / w * 2.0 - 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, along * across * across))
		ray_tex = ImageTexture.create_from_image(image)
	return ray_tex

static func unit_quad() -> QuadMesh:
	if unit_quad_mesh == null:
		unit_quad_mesh = QuadMesh.new()
		unit_quad_mesh.size = Vector2.ONE
	return unit_quad_mesh

# A 1 x 1 quad whose base sits on the origin and extends up +Y (scale it to width x length).
static func ray_quad() -> QuadMesh:
	if ray_quad_mesh == null:
		ray_quad_mesh = QuadMesh.new()
		ray_quad_mesh.size = Vector2.ONE
		ray_quad_mesh.center_offset = Vector3(0, 0.5, 0)
	return ray_quad_mesh

# Builds a fresh additive unshaded sprite material (use when one instance must change colour).
static func make_material(color: Color, billboard := true, texture: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mat.albedo_texture = texture if texture != null else glow_texture()
	mat.disable_receive_shadows = true
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
	return mat

# Cached: the same arguments always return the same material object. Do not mutate it.
static func additive_material(color: Color, billboard := true, ray := false) -> StandardMaterial3D:
	var key := "%s|%d|%d" % [color.to_html(true), 1 if billboard else 0, 1 if ray else 0]
	if not material_cache.has(key):
		material_cache[key] = make_material(color, billboard, ray_texture() if ray else glow_texture())
	return material_cache[key]

# Additive vertex-coloured material for ribbons (rgb * alpha is added to the scene).
static func ribbon_material() -> StandardMaterial3D:
	if ribbon_mat == null:
		ribbon_mat = StandardMaterial3D.new()
		ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ribbon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ribbon_mat.vertex_color_use_as_albedo = true
		ribbon_mat.albedo_color = Color.WHITE
		ribbon_mat.disable_receive_shadows = true
	return ribbon_mat

static func add_glow_sprite(parent: Node3D, size: float, color: Color, billboard := true) -> MeshInstance3D:
	var sprite := MeshInstance3D.new()
	sprite.mesh = unit_quad()
	sprite.material_override = additive_material(color, billboard)
	sprite.scale = Vector3(size, size, size)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not billboard:
		sprite.rotation_degrees.x = -90.0
	parent.add_child(sprite)
	return sprite


# Camera-facing ribbon trails kept in fixed ring buffers and drawn into one reused
# ImmediateMesh (a single triangle-strip surface for all strips). Create once per owner;
# `track` / `push` write points, `advance` ages them and rebuilds the mesh in place.
class Trail extends MeshInstance3D:
	var strips := 1
	var capacity := 8
	var life := 0.4
	var width := 0.2
	var interval := 0.03
	var head_color := Color(1, 0.9, 0.5, 0.9)
	var tail_color := Color(1, 0.6, 0.2, 0.0)
	var points := PackedVector3Array()
	var births := PackedFloat64Array()
	var heads := PackedInt32Array()
	var counts := PackedInt32Array()
	var clock := 0.0
	var immediate := ImmediateMesh.new()
	var side_l := PackedVector3Array()
	var side_r := PackedVector3Array()
	var has_surface := false

	func _init(strip_count := 1, point_capacity := 8, lifetime := 0.4, ribbon_width := 0.2) -> void:
		strips = maxi(1, strip_count)
		capacity = maxi(2, point_capacity)
		life = maxf(0.01, lifetime)
		width = ribbon_width
		points.resize(strips * capacity)
		births.resize(strips * capacity)
		heads.resize(strips)
		counts.resize(strips)
		side_l.resize(capacity)
		side_r.resize(capacity)
		mesh = immediate
		material_override = LilyDuelFx.ribbon_material()
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top_level = true
		visible = false

	func buffer_size() -> int:
		return points.size()

	func live_points() -> int:
		var total := 0
		for s in strips:
			total += live_count(s)
		return total

	func live_count(strip: int) -> int:
		var n := 0
		for k in counts[strip]:
			var idx := strip * capacity + posmod(heads[strip] - k, capacity)
			if clock - births[idx] >= life:
				break
			n += 1
		return n

	# Always starts a new point (the ring buffer overwrites the oldest one).
	func push(strip: int, pos: Vector3) -> void:
		if strip < 0 or strip >= strips:
			return
		heads[strip] = (heads[strip] + 1) % capacity if counts[strip] > 0 else 0
		var idx := strip * capacity + heads[strip]
		points[idx] = pos
		births[idx] = clock
		counts[strip] = mini(counts[strip] + 1, capacity)
		visible = true

	# Follows `pos` with the newest point every call and commits a new point every `interval`.
	func track(strip: int, pos: Vector3) -> void:
		if strip < 0 or strip >= strips:
			return
		if counts[strip] == 0:
			push(strip, pos)
			return
		var idx := strip * capacity + heads[strip]
		if clock - births[idx] >= interval:
			push(strip, pos)
		else:
			points[idx] = pos
		visible = true

	func clear_strip(strip: int) -> void:
		if strip >= 0 and strip < strips:
			counts[strip] = 0

	func clear() -> void:
		for s in strips:
			counts[s] = 0
		immediate.clear_surfaces()
		has_surface = false
		visible = false

	func vert(pos: Vector3, color: Color) -> void:
		immediate.surface_set_color(color)
		immediate.surface_add_vertex(pos)

	func advance(delta: float) -> void:
		clock += delta
		if not visible:
			return
		var cam_pos := Vector3.ZERO
		var have_cam := false
		if is_inside_tree():
			var cam := get_viewport().get_camera_3d()
			if cam != null:
				cam_pos = cam.global_position
				have_cam = true
		if has_surface:
			immediate.clear_surfaces()
			has_surface = false
		var begun := false
		var last := Vector3.ZERO
		var last_color := Color(0, 0, 0, 0)
		for s in strips:
			var n := live_count(s)
			if n < 2:
				continue
			var base := s * capacity
			for k in n:
				var idx := base + posmod(heads[s] - k, capacity)
				var p := points[idx]
				var newer := points[base + posmod(heads[s] - maxi(k - 1, 0), capacity)]
				var older := points[base + posmod(heads[s] - mini(k + 1, n - 1), capacity)]
				var tangent := newer - older
				var to_cam := (cam_pos - p) if have_cam else Vector3.UP
				var side := tangent.cross(to_cam)
				if side.length_squared() < 0.000001:
					side = Vector3.RIGHT
				side = side.normalized()
				var f := clampf((clock - births[idx]) / life, 0.0, 1.0)
				var w := width * (1.0 - f)
				side_l[k] = p + side * w
				side_r[k] = p - side * w
			if not begun:
				immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
				begun = true
			else:
				# Degenerate join between strips.
				vert(last, last_color)
				vert(side_l[0], Color(0, 0, 0, 0))
			for k in n:
				var idx2 := base + posmod(heads[s] - k, capacity)
				var f2 := clampf((clock - births[idx2]) / life, 0.0, 1.0)
				var c := head_color.lerp(tail_color, f2)
				c.a *= (1.0 - f2)
				vert(side_l[k], c)
				vert(side_r[k], c)
				last = side_r[k]
				last_color = c
		if begun:
			immediate.surface_end()
			has_surface = true
		else:
			visible = false
