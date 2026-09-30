shader_type spatial;
render_mode cull_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_size;
uniform float mural_id;
void fragment() {
	vec2 uv=vec2(UV.x*surface_size.x/(surface_size.y*8.0),(mural_id+1.0-clamp(UV.y,0.004,0.996))/4.0);
	vec4 art=texture(artwork,uv);
	ALBEDO=art.rgb;
	ALPHA=art.a;
	ALPHA_SCISSOR_THRESHOLD=0.5;
	ROUGHNESS=0.78;
}
