shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;

// Ownership remains CPU-authoritative. This filtered mask only rounds the
// displayed boundary (at most half a grid cell); it never drives scoring.
uniform sampler2D ink_texture : filter_linear, repeat_disable;
uniform vec2 surface_size = vec2(1.0);
uniform vec4 team_a : source_color = vec4(1.0);
uniform vec4 team_b : source_color = vec4(1.0);

// Compact tent reconstruction smooths the 0.25m ledger silhouette locally.
// Support stays within half a cell; no new mask or ownership data is written.
vec4 filtered_mask(vec2 uv) {
 vec2 d = vec2(0.085) / surface_size;
 return texture(ink_texture,uv)*0.5 +
  (texture(ink_texture,uv+vec2(d.x,d.y)) + texture(ink_texture,uv-vec2(d.x,d.y)) +
   texture(ink_texture,uv+vec2(d.x,-d.y)) + texture(ink_texture,uv+vec2(-d.x,d.y)))*0.125;
}
void fragment() {
	vec4 mask = filtered_mask(UV);
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
	float pixel_footprint = max(length(dFdx(p)), length(dFdy(p)));
	float detail = 1.0 - smoothstep(0.06, 0.24, pixel_footprint);
	vec2 folds = vec2(cos(a) * 0.075 - cos(b) * 0.026,
		cos(a) * 0.047 + cos(b) * 0.066) + vec2(cos(c), sin(c)) * 0.014 * detail;
	NORMAL_MAP = normalize(vec3(-bevel * 0.62 + folds, 1.0)) * 0.5 + 0.5;
	ALBEDO = ink_color * (0.90 + 0.018 * sin(a + b) - 0.035 * rim);
	// A smooth pigmented body under a thin wet coat; distance raises roughness
	// as fine normals disappear, preventing tiny specular sparkles in motion.
	ROUGHNESS = 0.105 + 0.018 * sin(a + b) + 0.075 * rim + 0.055 * (1.0-detail);
	SPECULAR = 0.78;
	CLEARCOAT = 0.95;
	CLEARCOAT_ROUGHNESS = 0.085 + 0.055 * (1.0-detail);
	float coverage_width = max(fwidth(mask.a),0.012);
	ALPHA = smoothstep(0.5-coverage_width,0.5+coverage_width,mask.a);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.45;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(ink_texture,0));
}
