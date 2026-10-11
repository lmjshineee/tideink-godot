shader_type spatial;
uniform vec4 base_color:source_color=vec4(.6,.6,.6,1.0);
uniform bool night=false;
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX;n=NORMAL;}
void fragment(){
 vec2 face=abs(n.x)>.5?p.zy:p.xy;
 vec2 tile=fract((face+vec2(10.0,20.0))/vec2(1.3,1.5));
 float window=step(.22,tile.x)*step(tile.x,.77)*step(.20,tile.y)*step(tile.y,.74)*step(abs(n.y),.5);
 vec3 glass=night?vec3(.91,.67,.38):vec3(.37,.52,.53);
 ALBEDO=mix(base_color.rgb,glass,window*.75);
 ROUGHNESS=.82;
 EMISSION=night?glass*window*.12:vec3(0.0);
}
