shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// A large, very transparent, soft-edged sheet of drifting noise. Edges fade to nothing.
// The drift is driven by TIME here, so the CPU never touches this material while it animates.
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 mist_color : source_color = vec3(0.3, 0.4, 0.6);
uniform vec2 drift_start = vec2(0.0);
uniform vec2 drift_speed = vec2(0.0);
uniform vec2 tiling = vec2(3.0, 1.0);
uniform float density = 0.2;

void fragment() {
	vec2 drift = drift_start + drift_speed * TIME;
	float n1 = texture(noise_tex, UV * tiling + drift).r;
	float n2 = texture(noise_tex, UV * tiling * 0.53 - drift * 0.7 + vec2(0.3, 0.6)).r;
	float m = smoothstep(0.38, 0.85, n1 * 0.6 + n2 * 0.4);
	vec2 e = smoothstep(vec2(0.0), vec2(0.3), UV) * smoothstep(vec2(0.0), vec2(0.3), 1.0 - UV);
	ALBEDO = mist_color;
	ALPHA = m * e.x * e.y * density;
}
