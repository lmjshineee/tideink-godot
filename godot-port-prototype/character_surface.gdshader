shader_type spatial;
render_mode cull_disabled;
uniform vec4 team_color : source_color = vec4(1.0,0.4,0.1,1.0);
void fragment() {
 ALBEDO = mix(COLOR.rgb, team_color.rgb * COLOR.rgb, COLOR.a);
 ROUGHNESS = mix(0.62,0.32,COLOR.a);
 CLEARCOAT = 0.22;
 CLEARCOAT_ROUGHNESS = 0.3;
}
