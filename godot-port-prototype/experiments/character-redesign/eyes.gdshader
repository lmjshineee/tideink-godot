shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 iris_color : source_color = vec4(0.94,0.44,0.045,1.0);

void fragment() {
    vec2 p=(UV-vec2(0.50,0.48))*vec2(1.0,0.37);
    float r=length(p);
    vec3 white=vec3(0.91,0.91,0.84);
    float iris=1.0-smoothstep(0.209,0.221,r);
    float pupil=1.0-smoothstep(0.105,0.118,r);
    float edge=smoothstep(0.184,0.214,r);
    vec3 amber=mix(iris_color.rgb*1.14,iris_color.rgb*0.30,edge);
    float radial=0.012*sin(atan(p.y,p.x)*43.0+r*70.0);
    amber+=vec3(radial);
    vec3 eye=mix(white,amber,iris);
    eye=mix(eye,vec3(0.014,0.021,0.032),pupil);
    float glint=1.0-smoothstep(0.022,0.036,length(p-vec2(-0.046,-0.048)));
    eye=mix(eye,vec3(0.99),glint);
    ALBEDO=eye;
    ROUGHNESS=0.31;
    SPECULAR=0.27;
}
