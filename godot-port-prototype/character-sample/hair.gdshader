shader_type spatial;
render_mode cull_disabled;
uniform vec4 team_color:source_color;
void fragment(){
 vec3 col=team_color.rgb;
 if(UV2.x<=-1.5){
  ALBEDO=COLOR.rgb;ROUGHNESS=.72;
 }else{
  float top=UV2.y>=1.5?COLOR.g:UV.y*.5+.5;
  col=mix(col*.70,mix(col,vec3(1.),.10),smoothstep(.05,.85,top));
  if(UV2.y<1.5){
   float stripe=pow(max(0.,1.-abs(UV.y-.42)),18.);
   col=mix(col,mix(col,vec3(1.),.24),stripe*.35);
  }
  ALBEDO=col;ROUGHNESS=.39;CLEARCOAT=.20;CLEARCOAT_ROUGHNESS=.3;SPECULAR=.4;
 }
}
