shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 team_color : source_color = vec4(1.,.408,.114,1.);
uniform bool clay = false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
    vec2 uv=vec2(UV.x,1.-UV.y);vec2 grid=uv*vec2(9.,15.);vec2 cell=floor(grid);
    vec2 q=fract(grid)-vec2(.5,.5);q.y*=1.36;float spot=1.-smoothstep(.17,.26,length(q));spot*=step(.42,hash(cell));
    vec3 col=team_color.rgb*(1.-.16*spot);
    float wrap=abs(fract(uv.y-.75+.5)-.5);float underside=(1.-smoothstep(.09,.19,wrap))*smoothstep(.36,.71,uv.x);
    col=mix(col,vec3(.96,.74,.43),underside*.69);
    ALBEDO=clay?vec3(.39,.43,.47):col;ROUGHNESS=.52;SPECULAR=.30;CLEARCOAT=.06;CLEARCOAT_ROUGHNESS=.46;
}
