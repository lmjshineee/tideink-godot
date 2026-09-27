shader_type spatial;
render_mode unshaded;

uniform sampler2D ink_texture : source_color, filter_nearest;
uniform float arena_half = 20.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_position.xz + vec2(arena_half)) / (arena_half * 2.0);
	vec4 ink = texture(ink_texture, uv);
	vec2 grid = fract(world_position.xz * 0.5);
	float line = 0.03 * (1.0 - step(0.025, grid.x) + 1.0 - step(0.025, grid.y));
	vec3 dry = vec3(0.72, 0.75, 0.74) - vec3(line);
	ALBEDO = mix(dry, ink.rgb, ink.a);
	ROUGHNESS = 0.88;
}

