shader_type spatial;
render_mode cull_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	VERTEX.z += COLOR.a * 0.07 * sin(TIME*2.1+world.x*3.2+world.y*1.3);
}
void fragment() {
	vec4 art=texture(artwork,UV);
	ALBEDO=mix(COLOR.rgb,art.rgb,art.a);
	ROUGHNESS=0.82;
}
