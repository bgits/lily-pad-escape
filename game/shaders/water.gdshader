shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world;
uniform vec3 deep_color : source_color = vec3(0.07, 0.55, 0.64);
uniform vec3 light_color : source_color = vec3(0.17, 0.70, 0.73);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 tile = floor(world.xz * 2.8);
 float patch = hash(floor(tile * 0.25));
 float fine = hash(tile);
 float ripple = sin(world.z * 2.5 + TIME * 1.15 + sin(world.x * 0.7));
 float glint = step(0.95, fine) * step(0.82, ripple);
 ALBEDO = mix(deep_color, light_color, patch * 0.6 + fine * 0.22) + vec3(0.18, 0.25, 0.24) * glint;
}
