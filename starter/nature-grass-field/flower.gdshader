shader_type spatial;
// Meadow flower: thin green stem plus a procedural 5-petal head drawn with alpha scissor on a
// small horizontal quad (UV 0.5..1). Sways with the same gust field as grass.gdshader.
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
uniform vec3 petal_color : source_color = vec3(0.95, 0.92, 0.85);
uniform vec3 centre_color : source_color = vec3(0.95, 0.72, 0.15);
uniform vec3 stem_color : source_color = vec3(0.24, 0.4, 0.12);
uniform float wind_strength = 1.0;
uniform vec2 wind_dir = vec2(0.93, 0.37);
varying vec2 v_uv;
float fh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	v_uv = UV;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(VERTEX.y, 0.0, 1.0);
	float gust = sin(dot(root.xz, wind_dir) * 0.32 - TIME * 1.7) * 0.5 + 0.5;
	float sway = (gust * gust * 0.8 + sin(TIME * 3.0 + root.x * 5.0) * 0.1) * wind_strength * 0.18 * h * h;
	VERTEX.xz += (inverse(mat3(MODEL_MATRIX)) * vec3(wind_dir.x, 0.0, wind_dir.y)).xz * sway;
}
void fragment() {
	if (v_uv.y < 0.49) {
		ALBEDO = stem_color * (0.6 + 0.6 * v_uv.y);
	} else {
		vec2 p = (v_uv - vec2(0.75)) * 4.0;
		float r = length(p);
		float a = atan(p.y, p.x);
		float petals = 0.62 + 0.38 * cos(a * 5.0);
		if (r > petals) { discard; }
		float centre = 1.0 - smoothstep(0.22, 0.3, r);
		ALBEDO = mix(petal_color * (0.85 + 0.25 * (1.0 - r)), centre_color, centre);
	}
	ROUGHNESS = 0.8;
	BACKLIGHT = ALBEDO * 0.3;
}
