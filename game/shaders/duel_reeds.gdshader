shader_type spatial;
render_mode cull_disabled;
// One merged mesh of reed clumps; the sway is done here so there is no per-frame CPU work.
uniform float sway = 0.16;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

void vertex() {
	float h = clamp(VERTEX.y / 2.4, 0.0, 1.0);
	float phase = VERTEX.x * 0.55 + VERTEX.z * 0.4;
	VERTEX.x += sin(TIME * 1.35 + phase) * sway * h * h;
	VERTEX.z += cos(TIME * 1.05 + phase * 1.3) * sway * 0.6 * h * h;
}

void fragment() {
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = 1.0;
}
