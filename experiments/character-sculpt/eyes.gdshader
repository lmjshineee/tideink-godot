shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment(){
    vec2 p=UV-vec2(.50,.50);float r=length(p);
    float iris=1.-smoothstep(.216,.225,r),pupil=1.-smoothstep(.091,.102,r);
    vec3 amber=mix(vec3(.92,.245,.022),vec3(.22,.047,.017),smoothstep(.187,.224,r));
    amber+=vec3(.011*sin(atan(p.y,p.x)*47.+r*120.));
    vec3 col=mix(vec3(.93,.91,.84),amber,iris);col=mix(col,vec3(.006,.009,.016),pupil);
    float glint=1.-smoothstep(.027,.038,length(p-vec2(-.055,-.061)));
    ALBEDO=mix(col,vec3(.99),glint);ROUGHNESS=.29;SPECULAR=.23;
}
