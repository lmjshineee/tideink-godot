shader_type spatial;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float wave=sin(world.x*.14+TIME*.12)*sin(world.z*.12-TIME*.10);
 ALBEDO=mix(vec3(.13,.30,.33),vec3(.24,.42,.42),wave*.5+.5);
 ROUGHNESS=.42;SPECULAR=.35;
}
