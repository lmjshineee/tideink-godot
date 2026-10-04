shader_type spatial;
render_mode cull_disabled;
uniform vec4 iris_color:source_color=vec4(.08,.72,.62,1.);
uniform vec4 iris_dark:source_color=vec4(.01,.16,.18,1.);
uniform vec2 look=vec2(0.);
void fragment(){
 vec2 p=UV-look;float r=length(p*vec2(1.,.77));
 vec3 col=vec3(.94,.965,.95)*(1.-.13*smoothstep(.25,.9,UV.y));
 float iris=1.-smoothstep(.60,.63,r);
 vec3 ic=mix(iris_color.rgb,iris_dark.rgb,smoothstep(-.5,.6,p.y));
 ic=mix(ic,iris_dark.rgb,smoothstep(.46,.62,r));
 col=mix(col,ic,iris);
 float pupil=1.-smoothstep(.22,.25,length(p*vec2(1.,.68)));
 col=mix(col,vec3(.008,.02,.032),pupil);
 float highlight=1.-smoothstep(.11,.14,length(UV-vec2(-.20,.28)));
 col=mix(col,vec3(1.),highlight);
 float rim=smoothstep(.90,.98,length(UV));
 col=mix(col,vec3(.012,.022,.035),rim);
 ALBEDO=col;ROUGHNESS=.36;SPECULAR=.35;EMISSION=col*.035;
}
