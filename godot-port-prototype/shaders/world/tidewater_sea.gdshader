shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep : source_color = vec4(0.039,0.31,0.54,1.0);
uniform vec4 shallow : source_color = vec4(0.07,0.65,0.72,1.0);
varying vec3 world_position;
void vertex() {
	VERTEX.y += sin(VERTEX.x*0.12+TIME*0.7)*0.045+sin(VERTEX.z*0.16-TIME*0.6)*0.03;
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float wave = sin(p.x*0.7+p.y*0.2+sin(p.y*0.13)+TIME)*sin(p.y*0.8-p.x*0.3-TIME*0.8);
	float distance_to_deck = length(max(abs(p)-vec2(25.0,44.0),vec2(0.0)));
	float near = exp(-distance_to_deck*0.016);
	vec3 base = mix(deep.rgb,shallow.rgb,near*0.65+wave*0.045);
	float foam = (1.0-smoothstep(0.2,1.6,distance_to_deck))*(0.5+0.5*sin(p.x*4.0+p.y*5.0+TIME*1.5));
	base=mix(base,vec3(0.8,0.94,0.93),foam*0.65);
	float detail=1.0/(1.0+length(fwidth(p))*2.0);
	NORMAL_MAP=normalize(vec3(sin(p.x*0.8+sin(p.y*0.3)+TIME)*0.035,cos(p.y*0.7+sin(p.x*0.17)-TIME)*0.035,1.0))*0.5+0.5;
	NORMAL_MAP_DEPTH=detail;
	ALBEDO=base;
	ROUGHNESS=0.52;
	SPECULAR=0.35;
}
