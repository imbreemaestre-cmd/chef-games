shader_type spatial;
// Wind-gust grass for generated blade clumps (UV.y 0 root -> 1 tip). Colour varies with large
// world-space patches (lush vs dry) and per-clump hash. Compatibility-safe: no COLOR, no instance uniforms.
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
uniform vec3 base_color : source_color = vec3(0.05, 0.1, 0.03);
uniform vec3 tip_color : source_color = vec3(0.3, 0.42, 0.11);
uniform vec3 dry_color : source_color = vec3(0.5, 0.45, 0.2);
uniform float dryness : hint_range(0.0, 1.0) = 0.35;
uniform float wind_strength = 1.0;
uniform vec2 wind_dir = vec2(0.93, 0.37);
uniform float wind_speed = 1.0;
varying float v_h;
varying vec3 v_world;
varying float v_rand;

float gh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float gn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(gh(i), gh(i + vec2(1, 0)), f.x), mix(gh(i + vec2(0, 1)), gh(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_h = UV.y;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_rand = gh(floor(root.xz * 3.1));
	float t = TIME * wind_speed;
	float gust = sin(dot(root.xz, wind_dir) * 0.32 - t * 1.7) * 0.5 + 0.5;
	gust = gust * gust * 0.9 + 0.25 * gn(root.xz * 0.15 + vec2(t * 0.3));
	float flutter = sin(t * 4.1 + root.x * 3.7 + root.z * 2.3) * 0.12;
	float bend = (gust + flutter) * wind_strength * 0.55 * v_h * v_h;
	vec3 offset_w = vec3(wind_dir.x, 0.0, wind_dir.y) * bend * (world.y - root.y + 0.05);
	offset_w.y = -abs(bend) * 0.25 * (world.y - root.y);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_w, 0.0)).xyz;
	v_world = world;
}

void fragment() {
	float patch_n = gn(v_world.xz * 0.06) * 0.65 + gn(v_world.xz * 0.21) * 0.35;
	float dry = smoothstep(1.0 - dryness, 1.0 - dryness + 0.35, patch_n);
	vec3 tip = mix(tip_color, dry_color, dry) * (0.82 + 0.36 * v_rand);
	vec3 c = mix(base_color, tip, smoothstep(0.0, 0.85, v_h));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = c * 0.35;
}
