shader_type spatial;
render_mode cull_disabled;
// Readable garment construction; no fractal noise or derivative micro-bump.
uniform vec4 team_color : source_color;
uniform vec4 shirt_color : source_color;
uniform vec4 shorts_color : source_color;
uniform vec4 shoe_color : source_color;
uniform vec4 sole_color : source_color;
uniform vec4 sock_color : source_color;
uniform vec4 strap_color : source_color;
uniform int garment_kind = 0;
uniform int trouser_kind = 0;
uniform int graphic = 0;
varying vec3 bind_pos;
varying float colour_slot;
varying vec3 cloth;
varying vec2 textile_uv;

float band(float x, float a, float b) {
  float w = max(fwidth(x), 0.0005);
  return smoothstep(a-w,a+w,x)*(1.0-smoothstep(b-w,b+w,x));
}
float box(vec2 p, vec2 half_size) {
  vec2 d=abs(p)-half_size;
  float edge=max(d.x,d.y);
  float w=max(fwidth(edge),0.0006);
  return 1.0-smoothstep(-w,w,edge);
}
vec3 accent(vec3 base) { return mix(base,sole_color.rgb,0.72); }

void vertex() {
  bind_pos=CUSTOM0.xyz;colour_slot=CUSTOM0.w;
  cloth=CUSTOM1.xyz;textile_uv=UV;
}

void fragment() {
  vec3 p=bind_pos;
  float part=floor(cloth.x+0.5);
  float slot=floor(colour_slot+0.5);
  vec3 base=shirt_color.rgb;
  if(slot==1.0) base=team_color.rgb;
  else if(slot==3.0) base=shorts_color.rgb;
  else if(slot==4.0) base=shoe_color.rgb;
  else if(slot==5.0) base=sock_color.rgb;
  else if(slot==6.0) base=sole_color.rgb;
  else if(slot==7.0) base=strap_color.rgb;
  else if(slot==8.0) base=shoe_color.rgb*0.64;
  else if(slot==9.0) base=shorts_color.rgb*0.43;
  else if(slot==10.0) base=sole_color.rgb*0.86;
  else if(slot==11.0) base=strap_color.rgb*0.56;
  else if(slot==12.0) base=sock_color.rgb;
  else if(slot==13.0) base=team_color.rgb*0.62;
  else if(slot==14.0) base=part==15.0 ? shorts_color.rgb*0.83 : accent(shirt_color.rgb);
  if(part==21.0) base=shirt_color.rgb*0.93;

  // Hidden source waistband/strap decorations follow the cut, never the print.
  if(garment_kind>0 && part==10.0 && p.z>0.0) discard;
  if(garment_kind>0 && part==0.0 && p.z>0.04 && p.y>0.84 && p.y<0.91) discard;
  if((trouser_kind==1 || trouser_kind==2) && part==16.0 && p.y>0.5) discard;

  if(part==1.0 || part==2.0 || part==3.0) {
    vec3 trim=accent(shirt_color.rgb);
    if(garment_kind==0) {
      // Ringer tee: short sleeves, contrasting neck and cuffs.
      if(part==3.0) base=trim;
      if(part==2.0) base=mix(base,trim,smoothstep(cloth.z-0.018,cloth.z-0.009,textile_uv.y));
    } else if(garment_kind==1) {
      // Closed track jacket: shoulder yoke, centre zip and ribbed hem.
      if(part==1.0) {
        base=mix(base,trim,band(p.y,0.934,1.02));
        base=mix(base,shorts_color.rgb,band(p.y,0.69,0.726));
        if(p.z>0.0) {
          float zip=band(abs(p.x),0.0,0.004)*band(p.y,0.70,1.01);
          base=mix(base,sole_color.rgb,zip);
          float pull=box(vec2(p.x,p.y-0.947),vec2(0.006,0.011));
          base=mix(base,strap_color.rgb,pull);
        }
      }
      if(part==2.0) base=mix(base,trim,band(textile_uv.x,0.18,0.24));
    } else if(garment_kind==2) {
      // Work overshirt: placket, small buttons and paired patch-pocket shading.
      if(part==1.0 && p.z>0.0) {
        base=mix(base,base*0.80,band(abs(p.x),0.0,0.009));
        float button=box(vec2(p.x,mod(p.y-0.745,0.048)-0.024),vec2(0.0028,0.0028))*band(p.y,0.72,0.99);
        base=mix(base,sole_color.rgb,button);
        vec2 q=vec2(abs(p.x)-0.060,p.y-0.872);
        float pocket=box(q,vec2(0.025,0.029));
        base=mix(base,base*0.79,pocket);
        base=mix(base,trim,box(q-vec2(0,0.021),vec2(0.026,0.007)));
      }
      if(part==3.0) base=base*0.78;
    } else {
      // Boxy sports jersey: shoulder panel and broad sleeve hems.
      if(part==1.0) base=mix(base,trim,band(p.y,0.926,1.01));
      if(part==2.0) base=mix(base,trim,smoothstep(cloth.z-0.028,cloth.z-0.015,textile_uv.y));
      if(part==3.0) base=shorts_color.rgb;
    }
    // All four rolled graphics work on each cut.
    if(part==1.0) {
      if(graphic==0) base=mix(base,trim,band(p.y,0.810,0.836)+band(p.y,0.850,0.863));
      else if(graphic==1) base=mix(base,trim,band(p.y+abs(p.x)*0.24,0.803,0.856));
      else if(graphic==2) base=mix(base,trim,band(abs(p.x),0.086,0.106));
      else if(graphic==3 && p.z>0.0) {
        vec2 q=vec2(p.x-0.047,p.y-0.923);
        base=mix(base,trim,box(q,vec2(0.017,0.012)));
        base=mix(base,team_color.rgb,box(q,vec2(0.010,0.005)));
      }
      float tab=box(vec2(p.x-0.084,p.y-0.74),vec2(0.012,0.008));
      base=mix(base,team_color.rgb,tab);
    }
  } else if(part==4.0 || part==5.0 || part==15.0) {
    base=shorts_color.rgb;
    float side=band(textile_uv.x,0.22,0.27);
    base=mix(base,mix(accent(base),team_color.rgb,0.36),side);
    if(trouser_kind==2 && part==5.0) {
      float cargo=box(vec2(textile_uv.x-0.25,p.y-0.553),vec2(0.09,0.043));
      base=mix(base,base*0.77,cargo);
    }
    if(part==15.0) base=mix(base,mix(sole_color.rgb,team_color.rgb,0.40),0.38);
  } else if(slot==4.0) {
    float panel=band(p.z,0.006,0.075)*band(abs(p.x),0.091,0.127);
    base=mix(base,accent(base),panel);
  }
  ALBEDO=base;
  ROUGHNESS=(slot==6.0 || slot==9.0) ? 0.84 : 0.70;
  METALLIC=0.0;
}
