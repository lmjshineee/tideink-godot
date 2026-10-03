shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 skin_color : source_color = vec4(1.0,0.851,0.761,1.0);

void fragment() {
    ALBEDO=skin_color.rgb;
    ROUGHNESS=.78;
    SPECULAR=.20;
}

void light() {
    float diffuse=clamp((dot(NORMAL,LIGHT)+.42)/1.42,0.,1.);
    DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*diffuse/3.14159265;
}
