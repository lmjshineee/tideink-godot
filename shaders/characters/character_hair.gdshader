shader_type spatial;
render_mode cull_disabled;
uniform vec4 team_color : source_color;
// Source strand tint, cap grooves and underside suction cups, carried by UV2.
void fragment() {
 vec3 tc=team_color.rgb,light=mix(tc,vec3(1.0),0.55),dark=tc*0.5;
 vec3 col=tc;
 float cup=0.0;
 ROUGHNESS=0.3;
 CLEARCOAT=0.65;
 if(UV2.x<=-1.5) {
  col=mix(COLOR.rgb,COLOR.rgb*tc,COLOR.a);
  float cls=floor(-UV2.x-2.0+0.5);
  ROUGHNESS=cls==2.0?0.85:0.4;
  METALLIC=cls==1.0?0.85:0.0;
  CLEARCOAT=cls==2.0?0.0:0.4;
 } else if(UV2.y>=1.5) {
  float groove=pow(1.0-abs(sin(UV.x*9.0+0.35*sin(UV.y*5.0))),6.0)*(1.0-smoothstep(0.9,1.45,UV.y));
  col=mix(dark,tc,0.55+0.45*smoothstep(0.0,0.25,COLOR.g));
  col=mix(col,light,0.18*smoothstep(0.8,1.5,UV.y))*(1.0-0.22*groove);
 } else {
  float t=COLOR.r,cs=UV.y,side=UV2.y*2.0-1.0;
  col=UV2.x>=0.0?mix(tc,light,UV2.x):mix(tc,dark,-UV2.x);
  col=mix(col*mix(0.78,1.0,smoothstep(0.0,0.35,t)),mix(col,light,0.22),smoothstep(0.55,1.0,t));
  col*=1.0-0.26*smoothstep(0.66,0.97,abs(side))*smoothstep(0.02,0.12,t);
  float ridge=smoothstep(0.75,1.0,cs)*(1.0-smoothstep(0.2,0.5,abs(side)));
  col=mix(col,light,ridge*0.17);
  col*=mix(0.82,1.0,smoothstep(-0.8,0.3,cs));
  if(COLOR.g>0.5&&t>0.3&&t<0.97&&cs< -0.15) {
   float row=side>0.0?0.5:0.0;
   float d=length(vec2((fract(UV.x/0.021+row)-0.5)*1.2,(abs(side)-0.42)/0.24));
   float sz=mix(0.58,0.34,smoothstep(0.35,0.96,t)),w=max(fwidth(d),0.005);
   cup=(1.0-smoothstep(sz-w,sz+w,d))*(1.0-smoothstep(-0.5,-0.15,cs));
   col=mix(col,light,cup*0.8);
   col*=1.0-0.22*(1.0-smoothstep(sz*0.25,sz*0.6,d))*cup;
  }
  ROUGHNESS=mix(0.3,0.42,cup);
 }
 ALBEDO=col;
 CLEARCOAT_ROUGHNESS=0.16;
}
