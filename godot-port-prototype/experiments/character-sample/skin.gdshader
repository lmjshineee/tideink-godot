shader_type spatial;
render_mode cull_disabled;
uniform vec4 mouth=vec4(.75,1.,0.,0.);
uniform vec4 team_color:source_color;
varying vec3 head_direction;
void vertex(){head_direction=vec3(UV,UV2.x);}
void fragment(){
 vec3 col=COLOR.rgb;
 if(length(head_direction)>.5){
  vec3 d=normalize(head_direction);float az=atan(d.x,d.z),el=asin(clamp(d.y,-1.,1.));
  float cheek=exp(-pow((abs(az)-.57)/.25,2.)-pow((el+.26)/.14,2.));
  col=mix(col,col*vec3(1.,.79,.76),cheek*.23);
  // A slim ink marking around the eyes, without a raised goggle bevel.
  vec2 q=vec2((abs(az)-.355)/.275,(el-.14-.13*(abs(az)-.355))/.20);
  float sd=length(q)-1.;float aa=max(fwidth(sd),.002);
  float mask=1.-smoothstep(-aa,aa,sd);
  float bridge=(1.-smoothstep(.10,.14,abs(az)))*(1.-smoothstep(.027,.04,abs(el-.165)));
  col=mix(col,vec3(.018,.025,.04),max(mask,bridge));
  float mx=az+mouth.w*(el+.38),my=el+.38;
  float width=.15*mouth.y;float line=my-mouth.x*.07*pow(mx/.13,2.);
  float dist=length(vec2(max(abs(mx)-width,0.),line));
  float smile=1.-smoothstep(.006,.012,dist);
  col=mix(col,vec3(.27,.075,.08),smile);
 }
 ALBEDO=col;ROUGHNESS=.72;METALLIC=0.;SPECULAR=.35;
}
