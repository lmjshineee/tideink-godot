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
	float rim = 1.0 - smoothstep(0.48, 0.95, mask.a);
	vec2 p = UV * surface_size;
	vec2 wave = vec2(sin(p.x * 12.0 + p.y * 3.0), cos(p.y * 11.0 - p.x * 2.0));
	NORMAL_MAP = normalize(vec3(wave * 0.045, 1.0)) * 0.5 + 0.5;
	ALBEDO = ink_color * (1.0 - 0.12 * rim);
	EMISSION = ink_color * 0.045;
	ROUGHNESS = 0.32 + 0.12 * rim;
	SPECULAR = 0.4;
	CLEARCOAT = 0.3;
	CLEARCOAT_ROUGHNESS = 0.24;
	ALPHA = mask.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
