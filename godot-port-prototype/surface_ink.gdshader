shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Ownership remains CPU-authoritative. This filtered mask only rounds the
// displayed boundary (at most half a grid cell); it never drives scoring.
uniform sampler2D ink_texture : filter_linear, repeat_disable;
uniform vec2 surface_size = vec2(1.0);
uniform vec4 team_a : source_color = vec4(1.0);
uniform vec4 team_b : source_color = vec4(1.0);

void fragment() {
	vec4 mask = texture(ink_texture, UV);
	// Decode filtered ownership data independently of the display palette.
	// A majority contour rounds enemy-overpaint edges too, without a purple band.
	float blue_weight = mask.g / max(mask.a, 0.001);
	float aa = max(fwidth(blue_weight), 0.001);
	float team_edge = smoothstep(0.5 - aa, 0.5 + aa, blue_weight);
	vec3 ink_color = mix(team_a.rgb, team_b.rgb, team_edge);
	float rim = 1.0 - smoothstep(0.50, 0.98, mask.a);
	vec2 p = UV * surface_size;
	// Metre-scaled meniscus: boundary height slopes into the substrate, rather
	// than a dark flat sticker. Sampling never changes the ownership mask.
	vec2 du = vec2(0.07 / surface_size.x, 0.0);
	vec2 dv = vec2(0.0, 0.07 / surface_size.y);
	vec2 bevel = vec2(texture(ink_texture, UV + du).a - texture(ink_texture, UV - du).a,
		texture(ink_texture, UV + dv).a - texture(ink_texture, UV - dv).a);
	// Slow, broad surface folds read as viscous liquid; fine oscillations remain
	// subtle so stationary ink does not look like an ocean or flicker at distance.
	float a = p.x * 2.3 + p.y * 1.7 + TIME * 0.22;
	float b = p.y * 3.1 - p.x * 1.4 - TIME * 0.17;
	float c = p.x * 6.2 + p.y * 4.6 + sin(p.y * 1.3) + TIME * 0.11;
	vec2 folds = vec2(cos(a) * 0.075 - cos(b) * 0.026,
		cos(a) * 0.047 + cos(b) * 0.066) + vec2(cos(c), sin(c)) * 0.014;
	NORMAL_MAP = normalize(vec3(-bevel * 0.62 + folds, 1.0)) * 0.5 + 0.5;
	ALBEDO = ink_color * (0.94 - 0.08 * rim);
	ROUGHNESS = 0.20 + 0.025 * sin(a + b) + 0.08 * rim;
	SPECULAR = 0.65;
	CLEARCOAT = 0.85;
	CLEARCOAT_ROUGHNESS = 0.14;
	ALPHA = mask.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
