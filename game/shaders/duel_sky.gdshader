shader_type sky;
// Midnight Pond night sky: gradient, two layers of cell stars and a blocky moon.
// Everything is driven by uniforms (no TIME: sky shaders cannot use it in the Compatibility
// renderer on Godot 4.6), so the CPU writes them only when the look changes. Stars do not twinkle.
uniform vec3 top_color : source_color = vec3(0.02, 0.04, 0.14);
uniform vec3 horizon_color : source_color = vec3(0.10, 0.20, 0.40);
uniform vec3 ground_color : source_color = vec3(0.03, 0.06, 0.14);
uniform vec3 moon_dir = vec3(0.0, 0.7, -0.7);
uniform vec3 moon_color : source_color = vec3(0.80, 0.88, 1.0);
uniform float moon_radius = 0.07;
uniform float star_strength = 1.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
vec3 hash33(vec3 p) {
	return vec3(hash13(p), hash13(p + 17.1), hash13(p + 41.7));
}
vec3 star_layer(vec3 d, float scale, float threshold) {
	vec3 p = d * scale;
	vec3 id = floor(p);
	vec3 f = fract(p);
	if (hash13(id) < threshold) {
		return vec3(0.0);
	}
	vec3 offset = hash33(id + 3.7) * 0.6 + 0.2;
	float size = mix(0.05, 0.2, pow(hash13(id + 7.3), 2.0));
	float spot = smoothstep(size, 0.0, length(f - offset));
	float bright = mix(0.6, 2.2, hash13(id + 9.1));
	vec3 tint = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.9, 0.7), hash13(id + 13.3));
	return tint * spot * bright;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.45));
	} else {
		col = mix(horizon_color, ground_color, pow(-h, 0.35));
	}
	float up = smoothstep(0.02, 0.3, h);
	vec3 stars = star_layer(d, 30.0, 0.82) + star_layer(d, 74.0, 0.88) * 0.9;
	col += stars * up * star_strength;
	float md = dot(d, normalize(moon_dir));
	float cr = cos(moon_radius);
	float disc = smoothstep(cr - 0.0006, cr + 0.0006, md);
	// Blocky craters: quantised local coordinates around the moon centre.
	vec3 m = normalize(moon_dir);
	vec3 right = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
	vec3 upv = cross(right, m);
	vec2 local = vec2(dot(d, right), dot(d, upv)) / moon_radius;
	float crater = step(0.7, hash13(vec3(floor(local * 3.0), 3.0))) * 0.35;
	vec3 moon_surface = moon_color * (1.0 - crater);
	float halo = pow(max(md, 0.0), 90.0) * 0.55 + pow(max(md, 0.0), 14.0) * 0.12;
	col += moon_color * halo;
	col = mix(col, moon_surface * 1.15, disc);
	COLOR = col;
}
