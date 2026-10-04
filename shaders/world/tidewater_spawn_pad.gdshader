shader_type spatial;
render_mode cull_disabled;
uniform vec4 team_color : source_color;
void fragment() {
	vec2 p=(UV-0.5)*2.0;
	float radius=length(p);
	float ring=1.0-smoothstep(0.018,0.025,abs(radius-0.82));
	float inner=1.0-smoothstep(0.008,0.014,abs(radius-0.52));
	float angle=atan(p.y,p.x);
	float ticks=(1.0-smoothstep(0.72,0.74,radius))*smoothstep(0.63,0.65,radius)*step(0.8,fract(angle*12.0/6.28318));
	float mark=max(ring,max(inner,ticks));
	ALBEDO=mix(vec3(0.03,0.04,0.06),team_color.rgb,mark*0.95);
	EMISSION=team_color.rgb*mark*0.45;
	ROUGHNESS=0.4;
	ALPHA=1.0-step(0.995,radius);
	ALPHA_SCISSOR_THRESHOLD=0.5;
}
