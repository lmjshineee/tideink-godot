shader_type spatial;
render_mode cull_disabled;
// Source skin and expressions with small cheek ornaments replacing the dark mask.
uniform vec4 team_color : source_color;
uniform vec4 mouth=vec4(0.75,1.0,0.0,0.0);
uniform bool freckles=false;
uniform int ornament_pattern=0;
uniform vec4 ornament_color : source_color = vec4(1.0,0.68,0.14,1.0);
uniform vec4 ornament_pose=vec4(1.0,0.0,0.0,0.0); // scale, rotation, angle offsets
uniform int ornament_side=0;

varying vec3 vBindPos;
varying float vEx;
varying vec3 vHead;

float iwHash(vec3 p){ p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float iwNoise(vec3 x){ vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(iwHash(i), iwHash(i + vec3(1,0,0)), f.x), mix(iwHash(i + vec3(0,1,0)), iwHash(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(iwHash(i + vec3(0,0,1)), iwHash(i + vec3(1,0,1)), f.x), mix(iwHash(i + vec3(0,1,1)), iwHash(i + vec3(1,1,1)), f.x), f.y), f.z); }
float iwFbm(vec3 p){ return 0.56 * iwNoise(p) + 0.29 * iwNoise(p * 2.07 + 7.1) + 0.15 * iwNoise(p * 4.31 + 3.7); }
float iwBand(float x, float a, float b){ float w = max(fwidth(x) * 0.8, 1e-4); return smoothstep(a - w, a + w, x) - smoothstep(b - w, b + w, x); }
float iwHash2(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float iwAAw(float d){ return max(fwidth(d), 1e-5); }
// filled SDF (d < 0 inside) and stroke of half-width hw, both antialiased
float iwFill(float d){ float w = iwAAw(d); return 1.0 - smoothstep(-w, w, d); }
float iwStroke(float d, float hw){ float w = iwAAw(d); return 1.0 - smoothstep(hw - w, hw + w, abs(d)); }
// 1 while a pattern of spatial period P (same units as coord) is resolvable (>= ~3 px), fading to 0 when sub-pixel
float iwLod(float coord, float P){ float px = fwidth(coord) / P; return 1.0 - smoothstep(0.22, 0.55, px); }
// dashed stitch along s (period P, duty 0..1)
float iwDash(float s, float P, float duty){ float x = s / P; float f = fract(x); float w = min(max(fwidth(x), 1e-4) * 1.2, 0.3); return smoothstep(0.0, w, f) * (1.0 - smoothstep(duty - w, duty, f)); }
float iwSdBox(vec2 p, vec2 b, float r){ vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
float iwSdSeg(vec2 p, vec2 a, vec2 b){ vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
float iwSmin(float a, float b, float k){ float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }


vec3 iwBumpN(vec3 n, float h, vec3 pos){
  vec3 dpx = dFdx(pos), dpy = dFdy(pos);
  vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
  float det = dot(dpx, r1);
  vec3 g = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
  return abs(det) > 1e-14 ? normalize(abs(det) * n - g) : n;
}


// Signed distance to a ten-vertex, five-point star in face-angle coordinates.
float iwStar(vec2 p, float radius){
  float nearest = 100.0;
  bool inside = false;
  for (int i=0; i<10; i++) {
    float a = 1.5707963 + float(i)*0.62831853;
    float b = a+0.62831853;
    float ra = i%2==0 ? radius : radius*0.45;
    float rb = i%2==0 ? radius*0.45 : radius;
    vec2 v = vec2(cos(a),sin(a))*ra;
    vec2 w = vec2(cos(b),sin(b))*rb;
    nearest = min(nearest,iwSdSeg(p,v,w));
    if ((v.y>p.y)!=(w.y>p.y)) {
      float cross_x = v.x+(p.y-v.y)*(w.x-v.x)/(w.y-v.y);
      if (p.x<cross_x) inside = !inside;
    }
  }
  return inside ? -nearest : nearest;
}
float iwHairline(float az){ float a = abs(az) / 3.14159265; float h = mix(0.58, 0.3, smoothstep(0.1, 0.42, a)); return mix(h, -0.8, smoothstep(0.5, 0.96, a)); }

void vertex(){vBindPos=CUSTOM0.xyz;vEx=CUSTOM0.w;vHead=vec3(UV,UV2.x);}
void fragment(){
 vec4 diffuseColor=COLOR;
 
        float iwDecor = 0.0; float iwHairP = 0.0; float iwH = 0.0; float iwNail = 0.0; float iwMouthIn = 0.0; float iwAO = 1.0;
        float iwSub = floor(vEx + 0.5);
        // subtle skin mottling (breaks the plastic look up close; invisible at range)
        {
          float mott = iwFbm(vBindPos * 60.0);
          diffuseColor.rgb *= 1.0 + (mott - 0.5) * 0.06 * iwLod(vBindPos.y * 60.0, 1.0);
        }
        if (iwSub > 0.5 && iwSub < 1.5) {        // fingernail
          iwNail = 1.0;
          diffuseColor.rgb = mix(diffuseColor.rgb, vec3(1.0, 0.86, 0.84), 0.45);
        } else if (iwSub > 1.5 && iwSub < 2.5) { // inner ear: warmer, darker
          diffuseColor.rgb *= vec3(1.0, 0.8, 0.78);
          iwAO = 0.72;
        }
        {
          float hl = length(vHead);
          if (hl > 0.5) {
            vec3 d = vHead / hl;
            float az = atan(d.x, d.z), el = asin(clamp(d.y, -1.0, 1.0));
            // ---- painted hairline under the cap edge (hides the cap/skin seam), soft shadow just below it
            float hs = el - iwHairline(az) + 0.004;
            float hw = max(fwidth(hs), 1e-4);
            iwHairP = smoothstep(-hw, hw, hs);
            float capShadow = smoothstep(-0.09, 0.0, hs) * (1.0 - iwHairP);
            diffuseColor.rgb *= 1.0 - 0.22 * capShadow;
            diffuseColor.rgb = mix(diffuseColor.rgb, team_color.rgb * 0.55, iwHairP);
            // ---- freckles across the nose bridge + cheeks
            if ((freckles?1.0:0.0) > 0.5) {
              vec2 fp = vec2(az, el + 0.12) * 42.0;
              vec2 cell = floor(fp); vec2 fr = fract(fp) - 0.5;
              float rnd = iwHash2(cell);
              vec2 off = vec2(iwHash2(cell + 3.1), iwHash2(cell + 7.7)) - 0.5;
              float region = exp(-pow((abs(az) - 0.3) / 0.28, 2.0) - pow((el + 0.14) / 0.1, 2.0));
              float fd = length(fr - off * 0.5) - 0.13 * rnd;
              float fk = iwFill(fd) * step(0.45, rnd) * region;
              diffuseColor.rgb = mix(diffuseColor.rgb, diffuseColor.rgb * vec3(0.78, 0.6, 0.5), fk * 0.7);
            }
            // ---- nose tip: slightly warmer
            float nose = exp(-pow(az / 0.06, 2.0) - pow((el + 0.125) / 0.06, 2.0));
            diffuseColor.rgb *= mix(vec3(1.0), vec3(1.0, 0.9, 0.88), nose * 0.6);
            // Small independent cheek marks, below the eye patches; no bridge or mask.
            vec2 mark = (vec2(abs(az)-0.64,el+0.24)-ornament_pose.zw)/ornament_pose.x;
            float rot = ornament_pose.y;
            mark = mat2(vec2(cos(rot),sin(rot)),vec2(-sin(rot),cos(rot)))*mark;
            if (ornament_pattern==0) {
              iwDecor = iwFill(iwStar(mark,0.105));
            } else if (ornament_pattern==1) {
              float stripe = min(iwSdSeg(mark,vec2(-0.065,0.035),vec2(0.065,-0.025)),
                                 iwSdSeg(mark,vec2(-0.04,-0.035),vec2(0.055,-0.075)));
              iwDecor = iwFill(stripe-0.012);
            } else if (ornament_pattern==2) {
              float bolt = min(iwSdSeg(mark,vec2(0.035,0.09),vec2(-0.045,0.0)),
                          min(iwSdSeg(mark,vec2(-0.045,0.0),vec2(0.035,0.0)),
                              iwSdSeg(mark,vec2(0.035,0.0),vec2(-0.035,-0.09))));
              iwDecor = iwFill(bolt-0.014);
            } else if (ornament_pattern==3) {
              float wave = max(abs(mark.y-sin(mark.x*35.0)*0.025)-0.011,abs(mark.x)-0.10);
              iwDecor = iwFill(wave);
            } else if (ornament_pattern==4) {
              iwDecor = iwFill((abs(mark.x)+abs(mark.y))-0.10);
            } else if (ornament_pattern==5) {
              float flower = 1.0;
              for (int i=0; i<5; i++) {
                float a = float(i)*1.256637;
                flower = min(flower,length(mark-vec2(cos(a),sin(a))*0.055)-0.042);
              }
              iwDecor = iwFill(flower);
            } else if (ornament_pattern==6) {
              float dots = min(length(mark-vec2(-0.055,0.04))-0.025,
                          min(length(mark-vec2(0.035,0.005))-0.032,
                              length(mark-vec2(-0.015,-0.055))-0.021));
              iwDecor = iwFill(dots);
            } else {
              iwDecor = iwFill(max(length(mark)-0.10,-(length(mark-vec2(0.045,0.025))-0.085)));
            }
            if (ornament_side!=0 && az*float(ornament_side)<0.0) iwDecor = 0.0;
            diffuseColor.rgb = mix(diffuseColor.rgb,ornament_color.rgb,iwDecor*0.9);
            // ---- mouth
            float curve = mouth.x, width = mouth.y, open = mouth.z, tilt = mouth.w;
            float ca = cos(tilt), sa = sin(tilt);
            float mx = az * ca + (el + 0.38) * sa;
            float my = -az * sa + (el + 0.38) * ca;
            float mhw = 0.145 * width;
            // closed mouth: tapered smile line with tucked corners and a soft lower-lip shadow
            float xn = mx / max(mhw, 1e-3);
            float ly = curve * 0.05 * (mx / 0.11) * (mx / 0.11);
            float along = max(abs(mx) - mhw, 0.0);
            float dl = length(vec2(along * 1.3, my - ly));
            float taper = mix(1.0, 0.45, smoothstep(0.55, 1.05, abs(xn)));
            float lw = max(fwidth(dl), 1e-4);
            float closedK = 1.0 - smoothstep(0.15, 0.4, open);
            float line = (1.0 - smoothstep(0.0105 * taper - lw, 0.0105 * taper + lw, dl)) * closedK * step(0.001, width);
            // corner tucks (short upward ticks when smiling)
            float tuckK = clamp(curve, 0.0, 1.2) * closedK;
            for (int s = -1; s <= 1; s += 2) {
              vec2 c0 = vec2(float(s) * mhw, ly * 0.0 + curve * 0.05 * (mhw / 0.11) * (mhw / 0.11));
              float dt = iwSdSeg(vec2(mx, my), c0, c0 + vec2(float(s) * 0.018, 0.016));
              line = max(line, (1.0 - smoothstep(0.0055 - lw, 0.0055 + lw, dt)) * tuckK);
            }
            float lowerLip = exp(-pow(mx / (mhw * 0.7), 2.0) - pow((my - ly + 0.03) / 0.014, 2.0)) * closedK;
            diffuseColor.rgb *= 1.0 - 0.08 * lowerLip;
            // open mouth: D shape (flat-ish top, round bottom), throat gradient, teeth, tongue
            float ow = 0.13 * width * (0.85 + 0.15 * open);
            float u2 = mx / max(ow, 1e-3);
            float top = 0.012 + max(curve, 0.0) * 0.03 * u2 * u2;
            float bot = -open * 0.13 * sqrt(max(0.0, 1.0 - u2 * u2)) * (curve < 0.0 ? 0.7 : 1.0) + top;
            float inside = step(abs(u2), 1.0) * smoothstep(bot - lw, bot + lw, my) * (1.0 - smoothstep(top - lw, top + lw, my)) * step(0.02, open);
            float depth = clamp((top - my) / max(top - bot, 1e-3), 0.0, 1.0);
            vec3 mcol = mix(vec3(0.34, 0.05, 0.08), vec3(0.16, 0.02, 0.05), smoothstep(0.1, 0.6, depth) * (1.0 - abs(u2) * 0.5));
            float tongue = 1.0 - smoothstep(0.8, 1.0, length(vec2(u2 / 0.62, (my - bot - 0.022) / 0.034)));
            float groove = exp(-pow(u2 / 0.06, 2.0)) * tongue;
            mcol = mix(mcol, vec3(0.93, 0.42, 0.47) * (1.0 - 0.18 * groove), tongue * step(0.3, open));
            float teeth = smoothstep(top - 0.02 - lw, top - 0.02 + lw, my) * step(abs(u2), 0.78);
            float gap = iwStroke(fract(u2 * 2.2 + 0.5) - 0.5, 0.012) * 0.25;
            mcol = mix(mcol, vec3(0.97, 0.96, 0.94) * (1.0 - gap), teeth);
            float edge = (1.0 - smoothstep(0.0, 0.012, min(my - bot, top - my))) * inside;
            mcol *= 1.0 - 0.35 * edge;
            iwMouthIn = inside;
            diffuseColor.rgb = mix(diffuseColor.rgb, min(vec3(0.24, 0.05, 0.07), diffuseColor.rgb * vec3(0.42, 0.3, 0.3)), line);
            diffuseColor.rgb = mix(diffuseColor.rgb, mcol, inside);
            iwH -= inside * 0.0012 + line * 0.0003;
          }
        }
      
 ALBEDO=diffuseColor.rgb;
 ROUGHNESS=mix(0.58,0.48,iwDecor);
 ROUGHNESS=mix(ROUGHNESS,0.35,iwHairP);
 ROUGHNESS=mix(ROUGHNESS,0.22,iwNail);
 ROUGHNESS=mix(ROUGHNESS,0.3,iwMouthIn);
 CLEARCOAT=0.04+iwNail*0.15;
 CLEARCOAT_ROUGHNESS=0.4;
 NORMAL=iwBumpN(NORMAL,iwH,VERTEX);
 AO=iwAO;
}
