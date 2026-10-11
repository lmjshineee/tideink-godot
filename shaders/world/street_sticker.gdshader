shader_type spatial;
render_mode cull_disabled;
uniform int theme=0;
uniform float sticker_id=0.0;
float line(vec2 p,vec2 a,vec2 b,float width){vec2 v=b-a;return 1.0-smoothstep(width,width+fwidth(p.x),length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0)));}
void fragment(){
 vec2 p=UV*vec2(4.0,1.0);
 vec3 paper=theme==0?vec3(0.95,0.83,0.64):vec3(0.13,0.29,0.32);
 vec3 ink=theme==0?vec3(0.24,0.38,0.40):vec3(0.97,0.77,0.42);
 float art=0.0;
 float ring=abs(length(p-vec2(0.55,0.5))-0.26);
 art=max(art,1.0-smoothstep(0.035,0.04,ring));
 if(theme==0){
  art=max(art,line(p,vec2(.18,.48),vec2(.91,.48),.02));
  for(int i=0;i<3;i++){float x=1.1+float(i)*.76;art=max(art,line(p,vec2(x,.25),vec2(x+.45,.72),.065));art=max(art,line(p,vec2(x+.45,.72),vec2(x+.60,.25),.065));}
 }else{
  art=max(art,line(p,vec2(.36,.34),vec2(.75,.65),.05));
  for(int i=0;i<3;i++){float x=1.15+float(i)*.80;art=max(art,line(p,vec2(x,.22),vec2(x,.78),.07));art=max(art,line(p,vec2(x,.78),vec2(x+.47,.78),.055));art=max(art,line(p,vec2(x,.47),vec2(x+.36,.47),.055));}
 }
 float trim=step(UV.y,.09)+step(.91,UV.y);
 ALBEDO=mix(paper,ink,max(art,trim));ROUGHNESS=.76;
}
