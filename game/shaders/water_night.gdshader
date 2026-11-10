shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// Night water: chunky tiles, swell, glints, ripple rings, bioluminescent flashes, moon path, light reflections.
// Driven by LilyDuelWater (duel_water.gd). World XZ in metres; tile = 1/2.8 m.
// Cost notes: every loop rejects on plain distances first and only then does trigonometry.
// Time terms are wrapped per term by exactly one period (seamless); stepped hash times by 64 s.
varying vec3 world;
uniform vec3 deep_color : source_color = vec3(0.02, 0.10, 0.17);
uniform vec3 light_color : source_color = vec3(0.05, 0.21, 0.30);
uniform vec3 glint_color : source_color = vec3(0.6, 0.85, 1.0);
uniform vec3 moon_dir = vec3(0.4, -0.7, 0.5);
uniform vec3 cam_pos = vec3(0.0, 24.0, 19.0);
uniform vec4 ripples[24];      // x, z, age01, strength (0 = inactive)
uniform vec4 flashes[4];       // x, z, age01, strength
uniform vec4 flash_colors[4];
uniform vec4 refl_pos[16];     // x, z, energy, phase
uniform vec4 refl_col[16];
uniform vec2 refl_dir[16];     // unit direction from each light toward the camera (0 = unused)

const float TILE = 2.8;
const float TAU_F = 6.28318530718;

// Sin-free hash (no large sin() arguments, stable on every GPU).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
// time reduced by whole periods of a sine of angular speed w: sin(x + w * wrap(t, w)) == sin(x + w * t)
float wrap(float t, float w) { return mod(t, TAU_F / w); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 tile = floor(world.xz * TILE);
	vec2 tc = (tile + 0.5) / TILE;            // tile centre in metres
	float patch = hash(floor(tile * 0.25));
	float fine = hash(tile);
	float t = TIME;
	float step_t = mod(TIME, 64.0);           // for stepped (floor) hash times
	// slow large swell + small travelling pattern
	float swell = sin(tc.x * 0.09 + wrap(t, 0.21) * 0.21) * sin(tc.y * 0.07 - wrap(t, 0.17) * 0.17);
	float wave = sin(tc.y * 2.5 + wrap(t, 1.15) * 1.15 + sin(tc.x * 0.7));
	vec3 col = mix(deep_color, light_color, clamp(patch * 0.55 + fine * 0.2 + swell * 0.22 + 0.08, 0.0, 1.0));
	col += glint_color * 0.55 * step(0.965, fine) * step(0.75, wave);

	// moon path: band from the camera's ground point toward the moon, broken by the wave pattern
	vec2 h = moon_dir.xz;
	float hl = length(h);
	if (hl > 0.01) {
		h /= hl;
		vec2 rel = tc - cam_pos.xz;
		float along = dot(rel, -h);           // distance toward the moon
		float across = dot(rel, vec2(-h.y, h.x)) + sin(along * 0.18 + wrap(t, 0.4) * 0.4) * 1.2;
		float halfw = 3.0 + clamp(along, 0.0, 60.0) * 0.07;
		float band = (1.0 - smoothstep(halfw * 0.35, halfw, abs(across))) * smoothstep(2.0, 12.0, along);
		float shimmer = step(0.45, hash(tile + floor(step_t * 2.5 + patch * 4.0))) * (0.5 + 0.5 * wave);
		col += vec3(0.62, 0.74, 1.0) * band * shimmer * (0.55 + swell * 0.2);
	}

	// ripples: crisp rings quantised to the tile grid
	for (int i = 0; i < 24; i++) {
		vec4 r = ripples[i];
		if (r.w <= 0.0) continue;
		vec2 dv = tc - r.xy;
		float d2 = dot(dv, dv);
		float reach = 0.35 + 2.65 * r.w + 0.55;      // widest radius a ring can reach plus its soft edge
		if (d2 > reach * reach) continue;
		float q = 1.0 - r.z;
		float rad = (0.35 + 2.65 * r.w) * (1.0 - q * q);
		float d = sqrt(d2);
		if (abs(d - rad) >= 0.55) continue;
		float ring = 1.0 - smoothstep(0.25, 0.55, abs(d - rad));
		float fade = q * sqrt(q);
		col += (glint_color * 1.3 + vec3(0.1)) * ring * fade * min(r.w, 1.5);
		col += light_color * 0.5 * step(d, rad) * ring * fade * 0.5;
	}

	// bioluminescent flashes
	for (int i = 0; i < 4; i++) {
		vec4 f = flashes[i];
		if (f.w <= 0.0) continue;
		vec2 dv = tc - f.xy;
		float d2 = dot(dv, dv);
		float reach = (1.6 + 2.4 * f.w) * 1.15;
		if (d2 > reach * reach) continue;
		float q = 1.0 - f.z;
		float rad = (1.6 + 2.4 * f.w) * (0.35 + 0.65 * (1.0 - q * q));
		float d = sqrt(d2);
		if (d > rad * 1.15) continue;
		float fall = 1.0 - smoothstep(0.0, rad, d);
		float fade = pow(q, 1.6);
		float spark = step(0.82, hash(tile + floor(step_t * 9.0))) * 1.2;
		col += flash_colors[i].rgb * (fall * fall * 1.1 + spark * fall) * fade * min(f.w, 2.0);
	}

	// reflections: streak from each light's ground position toward the camera
	for (int i = 0; i < 16; i++) {
		vec4 rp = refl_pos[i];
		if (rp.z <= 0.0) continue;
		vec2 u = refl_dir[i];
		if (dot(u, u) < 0.5) continue;
		vec2 rel = tc - rp.xy;
		float len = 2.0 + 4.5 * rp.z;
		float a = dot(rel, u);
		if (a < -0.4 || a > len) continue;
		float across = dot(rel, vec2(-u.y, u.x));
		// widest the streak gets (0.45 + 0.6 * energy) plus the largest wobble (0.85)
		if (abs(across) > 1.3 + 0.6 * rp.z) continue;
		float k = clamp(a / len, 0.0, 1.0);
		float wob = sin(a * 1.9 + wrap(t, 2.3) * 2.3 + rp.w) * (0.15 + 0.5 * k) + sin(a * 0.7 - wrap(t, 1.3) * 1.3 + rp.w * 2.0) * 0.2;
		float s = across - wob;
		float halfw = 0.45 + 0.4 * rp.z * (0.5 + k);
		float shape = 1.0 - smoothstep(halfw * 0.3, halfw, abs(s));
		float broken = step(0.6 * k * k + 0.05, hash(tile + floor(step_t * 3.0 + rp.w)));
		float amp = shape * (1.0 - k * 0.7) * mix(0.5, 1.0, broken) * (0.4 + 0.7 * min(rp.z, 3.0));
		col += refl_col[i].rgb * amp * step(-0.4, a);
	}
	ALBEDO = col;
}
