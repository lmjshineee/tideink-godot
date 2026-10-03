shader_type spatial;
render_mode cull_disabled;
// Generated from unmodified character-mats.js; CUSTOM0/1 retain bind-space data.
uniform vec4 team_color : source_color;
uniform vec4 shirt_color : source_color;
uniform vec4 shorts_color : source_color;
uniform vec4 shoe_color : source_color;
uniform vec4 sole_color : source_color;
uniform vec4 sock_color : source_color;
uniform vec4 strap_color : source_color;
uniform int pattern = 0;
varying vec3 vBindPos;
varying float vEx;
varying vec3 vCloth;
varying vec2 vIwUv;

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




float iwLum(vec3 c){ return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 iwContrast(vec3 c){ return iwLum(c) > 0.42 ? c * 0.74 : c * 1.55 + 0.05; }
// ---- tee graphics -------------------------------------------------------------------------------
float iwShirtPattern(vec3 p) {
  float ax = abs(p.x);
  float m = 0.0;
  if (float(pattern) < 0.5) {            // ringer: no body pattern (trim + big emblem)
    m = 0.0;
  } else if (float(pattern) < 1.5) {     // double pinstripe
    m = iwBand(p.y, 0.842, 0.852) + iwBand(p.y, 0.866, 0.876);
  } else if (float(pattern) < 2.5) {     // raglan sleeves + side panel
    float sleeve = smoothstep(0.108, 0.115, ax) * step(0.86, p.y);
    m = max(sleeve, iwBand(ax, 0.098, 0.2) * step(p.y, 0.86) * step(0.74, p.y) * step(abs(p.z + 0.012), 0.05));
  } else {                         // chevron + hem band
    float y0 = 0.925 - 0.55 * ax;
    m = iwBand(p.y - y0, -0.022, 0.0) * step(0.0, p.z);
    m = max(m, iwBand(p.y, 0.726, 0.738));
  }
  return clamp(m, 0.0, 1.0);
}
// squid badge: ink splat with a white squid glyph; returns (splat coverage, glyph coverage)
vec2 iwEmblem(vec2 q, float R) {
  float a = atan(q.y, q.x); float r = length(q);
  float wob = 1.0 + 0.1 * sin(5.0 * a + 0.6) + 0.06 * sin(9.0 * a + 2.1) + 0.035 * sin(14.0 * a + 1.0);
  float splat = r - R * wob;
  splat = min(splat, length(q - vec2(R * 1.18, R * 0.62)) - R * 0.13);
  splat = min(splat, length(q - vec2(-R * 1.12, -R * 0.7)) - R * 0.1);
  splat = min(splat, length(q - vec2(R * 0.5, -R * 1.22)) - R * 0.08);
  // glyph: one silhouette — arrowhead mantle with swept fins flowing into a tall body, low oval eyes, four tentacles
  vec2 g = q / R;
  float fins = max(abs(g.x) * 1.02 + (g.y - 0.7) * 0.95, -(g.y - 0.22));
  float body = iwSdBox(g - vec2(0.0, 0.06), vec2(0.17, 0.3), 0.15);
  float glyph = iwSmin(fins, body, 0.08);
  float tent = 1e3;
  for (int i = 0; i < 4; i++) {
    float fi = float(i) - 1.5;
    vec2 tq = g - vec2(fi * 0.1, -0.2);
    tq.x -= fi * 0.1 * smoothstep(0.0, -0.3, tq.y) + 0.03 * sin(tq.y * 13.0 + fi) * smoothstep(-0.05, -0.3, tq.y);
    float w = mix(0.052, 0.03, smoothstep(-0.02, -0.3, tq.y));
    tent = min(tent, iwSdBox(tq - vec2(0.0, -0.15), vec2(w, 0.15), 0.028));
  }
  glyph = iwSmin(glyph, tent, 0.05);
  vec2 e1 = (g - vec2(0.075, 0.0)) / vec2(0.04, 0.062), e2 = (g - vec2(-0.075, 0.0)) / vec2(0.04, 0.062);
  float eyes = (min(length(e1), length(e2)) - 1.0) * 0.04;
  glyph = max(glyph, -eyes);
  return vec2(iwFill(splat), iwFill(glyph * R));
}

#include "res://character-sculpt/tee_patterns.gdshaderinc"

void vertex(){vBindPos=CUSTOM0.xyz;vEx=CUSTOM0.w;vCloth=CUSTOM1.xyz;vIwUv=UV;}
void fragment(){
 vec4 diffuseColor=COLOR;
 float iwHurtM=0.0;
 
        float iwH = 0.0; float iwAO = 1.0; float iwCls = floor(vCloth.y + 0.5); float iwPart = floor(vCloth.x + 0.5);
        float iwGloss = 0.0; float iwShine = 0.0; // extra clearcoat / sheen tweaks from decorations
        {
          float slot = floor(vEx + 0.5);
          vec3 p = vBindPos; vec2 uv = vIwUv;
          vec3 base = vec3(1.0);
          if (slot == 1.0) base = team_color.rgb;
          else if (slot == 2.0) base = mix(shirt_color.rgb, team_color.rgb, iwShirtPattern(p));
          else if (slot == 3.0) base = shorts_color.rgb;
          else if (slot == 4.0) base = shoe_color.rgb;
          else if (slot == 5.0) base = sock_color.rgb;
          else if (slot == 6.0) base = sole_color.rgb;
          else if (slot == 7.0) base = strap_color.rgb;
          else if (slot == 8.0) base = iwContrast(shoe_color.rgb);
          else if (slot == 9.0) base = mix(sole_color.rgb * 0.3 + vec3(0.035), vec3(0.09, 0.09, 0.1), 0.35);
          else if (slot == 10.0) base = vec3(0.78, 0.8, 0.84);
          else if (slot == 11.0) base = strap_color.rgb * 0.55 + vec3(0.02);
          else if (slot == 12.0) base = mix(sock_color.rgb, vec3(0.96), 0.6);
          else if (slot == 13.0) base = team_color.rgb * 0.62;
          else if (slot == 14.0) base = float(pattern) < 0.5 || float(pattern) > 2.5 ? team_color.rgb : iwContrast(shirt_color.rgb);

          // ---------------- part decorations ----------------
          if (iwPart == 1.0) { // TEE body: uv = (theta/2pi, y)
            float circ = 0.68;
            float th = uv.x;
            // side seams (x = +-90 deg) with twin stitching
            for (int s = 0; s < 2; s++) {
              float c = s == 0 ? 0.25 : 0.75;
              float dx = (th - c) * circ;
              float seam = iwStroke(dx, 0.0008);
              iwH -= 0.0005 * exp(-pow(dx / 0.0016, 2.0));
              float st = iwStroke(abs(dx) - 0.004, 0.0005) * iwDash(p.y, 0.0055, 0.6);
              base *= 1.0 - 0.12 * seam;
              base = mix(base, base * 0.8, st * iwLod(p.y, 0.0055));
              iwH += 0.00025 * st;
            }
            // double-needle hem stitching + hem fold
            float hy = p.y - vCloth.z;
            float st2 = (iwStroke(hy - 0.013, 0.0005) + iwStroke(hy - 0.019, 0.0005)) * iwDash(th * circ, 0.0055, 0.62);
            base = mix(base, base * 0.8, st2 * iwLod(th * circ, 0.0055));
            iwH += 0.0003 * st2 - 0.0006 * exp(-pow((hy - 0.024) / 0.002, 2.0));
            // gentle drape folds toward the hem + fabric slack at the waist
            float drape = sin(th * 6.2831 * 7.0 + 1.3 * sin(th * 6.2831 * 3.0)) * smoothstep(0.8, 0.705, p.y);
            iwH += 0.0016 * drape;
            iwH += 0.0009 * sin(p.y * 180.0 + 3.0 * sin(th * 25.0)) * smoothstep(0.8, 0.76, p.y) * smoothstep(0.7, 0.74, p.y);
            // chest emblem (pattern-dependent placement)
            if (p.z > 0.0) {
              vec2 q; float R; float on = 1.0;
              if (float(pattern) < 0.5) { q = vec2(p.x, p.y - 0.826); R = 0.038; }
              else if (float(pattern) < 1.5) { q = vec2(p.x, p.y - 0.927); R = 0.0135; }
              else if (float(pattern) < 2.5) { q = vec2(p.x, p.y - 0.818); R = 0.032; }
              else { q = vec2(p.x, p.y - 0.8); R = 0.028; }
              vec2 e = iwEmblem(q, R) * on;
              vec3 ink = team_color.rgb;
              base = mix(base, ink, e.x);
              base = mix(base, shirt_color.rgb * 1.02 + 0.02, e.y * e.x);
              iwH += 0.00018 * e.x;             // screen print sits slightly proud
              iwShine += 0.35 * e.x;            // plastisol print: a touch glossier
            }
            // lower-back print (visible around the tank from the gameplay camera)
            if (p.z < 0.0 && float(pattern) > 0.5) {
              float band = iwBand(p.y, 0.735, 0.748) * step(0.06, abs(p.x));
              base = mix(base, team_color.rgb, band * 0.9);
            }
            // tank-strap pressure shading on the shoulders (strap sits on top)
            iwAO *= 1.0 - 0.18 * exp(-pow((abs(p.x) - 0.075) / 0.018, 2.0)) * smoothstep(0.9, 0.98, p.y);
          } else if (iwPart == 2.0) { // SLEEVE: uv = (theta, s along from shoulder)
            float s = uv.y, L = vCloth.z;
            float cuff = smoothstep(L - 0.02, L - 0.018, s);
            base = mix(base, slot == 2.0 ? (float(pattern) < 0.5 || float(pattern) > 2.5 ? team_color.rgb : iwContrast(shirt_color.rgb)) : base, cuff);
            float circ = 0.3;
            float st = iwStroke(s - (L - 0.024), 0.0005) * iwDash(uv.x * circ, 0.005, 0.6);
            float st2 = iwStroke(s - 0.012, 0.0005) * iwDash(uv.x * circ, 0.005, 0.6);
            base = mix(base, base * 0.78, (st + st2) * iwLod(uv.x * circ, 0.005));
            iwH += 0.0003 * (st + st2);
            // rib on the cuff
            float rib = sin(uv.x * 6.2831 * 70.0);
            iwH += cuff * 0.00035 * rib * iwLod(uv.x * circ, circ / 70.0);
            // crease folds at the armpit side
            iwH += 0.0012 * sin(uv.x * 6.2831 * 3.0 + s * 60.0) * smoothstep(0.03, 0.0, s);
          } else if (iwPart == 3.0) { // COLLAR rib: uv = (theta, across)
            float rib = sin(uv.x * 6.2831 * 90.0);
            iwH += 0.0004 * rib * iwLod(uv.x * 0.3, 0.3 / 90.0);
            iwAO *= mix(0.8, 1.0, smoothstep(0.0, 0.35, uv.y));
          } else if (iwPart == 4.0 || iwPart == 5.0) { // SHORTS: uv = (theta, y | s)
            float circ = iwPart == 4.0 ? 0.66 : 0.46;
            float th = uv.x;
            // side seams + a team side stripe on some outfits
            float dx0 = (th - 0.25) * circ, dx1 = (th - 0.75) * circ;
            float dxs = iwPart == 4.0 ? min(abs(dx0), abs(dx1)) : abs(dx0);   // legs: outer seam only (0.75 = inseam)
            iwH -= 0.0005 * exp(-pow(dxs / 0.0016, 2.0));
            float stripe = (float(pattern) > 0.5 && float(pattern) < 2.5) ? iwStroke(dxs, 0.0065) : 0.0;
            base = mix(base, team_color.rgb, stripe);
            float ss = iwStroke(dxs - 0.0045, 0.00045) * iwDash(p.y, 0.005, 0.6);
            base = mix(base, base * 0.75 + 0.02, ss * iwLod(p.y, 0.005));
            if (iwPart == 4.0) {
              vec2 f = vec2(p.x, p.y);
              // front: fly J-stitch + slant pocket openings
              if (p.z > 0.0) {
                float fly = iwSdSeg(f, vec2(0.012, 0.745), vec2(0.012, 0.64));
                fly = min(fly, iwSdSeg(f, vec2(0.012, 0.64), vec2(0.0, 0.625)));
                float fs = iwStroke(fly, 0.0005) * iwDash(p.y + p.x, 0.005, 0.6);
                base = mix(base, base * 0.72 + 0.02, fs * iwLod(p.y, 0.005));
                iwH -= 0.0006 * exp(-pow(abs(p.x) / 0.0018, 2.0)) * step(0.63, p.y);
                for (int s = -1; s <= 1; s += 2) {
                  float sx = float(s);
                  float pk = iwSdSeg(f, vec2(sx * 0.062, 0.752), vec2(sx * 0.112, 0.668));
                  iwH -= 0.0009 * exp(-pow(pk / 0.0018, 2.0));
                  float ps = iwStroke(pk - 0.004, 0.00045) * iwDash(p.y, 0.005, 0.6);
                  base = mix(base, base * 0.72 + 0.02, ps * iwLod(p.y, 0.005));
                  iwAO *= 1.0 - 0.25 * exp(-pow(pk / 0.003, 2.0));
                }
              } else {
                // back patch pockets with a little team label on the right one
                for (int s = -1; s <= 1; s += 2) {
                  float sx = float(s);
                  float pb = iwSdBox(f - vec2(sx * 0.058, 0.668), vec2(0.036, 0.04), 0.01);
                  iwH += 0.0008 * (1.0 - smoothstep(-0.002, 0.0015, pb));
                  float ps = (iwStroke(pb + 0.0035, 0.00045)) * iwDash(p.x + p.y, 0.005, 0.6);
                  base = mix(base, base * 0.72 + 0.02, ps * iwLod(p.y, 0.005));
                  iwAO *= 1.0 - 0.3 * exp(-pow(pb / 0.0022, 2.0)) * step(0.0, pb);
                  if (s < 0) { float lab = iwSdBox(f - vec2(sx * 0.03, 0.692), vec2(0.006, 0.012), 0.002); base = mix(base, team_color.rgb, iwFill(lab)); }
                }
                // seat seam
                iwH -= 0.0006 * exp(-pow(p.x / 0.0017, 2.0));
              }
              // waistband stitch (mostly under the tee hem)
              float ws = iwStroke(p.y - 0.735, 0.0005) * iwDash(th * circ, 0.005, 0.6);
              base = mix(base, base * 0.75, ws);
            } else {
              // leg: inseam
              float dxi = abs((th - 0.75) * circ);
              iwH -= 0.0004 * exp(-pow(dxi / 0.0015, 2.0));
              // hem stitch above the cuff
              float L = vCloth.z;
              float hs = iwStroke(uv.y - (L - 0.02), 0.00045) * iwDash(th * circ, 0.005, 0.6);
              base = mix(base, base * 0.72 + 0.02, hs * iwLod(th * circ, 0.005));
              // relaxed folds
              iwH += 0.0013 * sin(th * 6.2831 * 5.0 + uv.y * 30.0) * smoothstep(0.02, 0.1, uv.y);
            }
          } else if (iwPart == 6.0) { // SOCK: uv = (theta, s from top)
            float rib = sin(uv.x * 6.2831 * 56.0);
            iwH += 0.00045 * rib * iwLod(uv.x * 0.22, 0.22 / 56.0);
            float s = uv.y;
            float stripes = iwBand(s, 0.018, 0.026) + iwBand(s, 0.033, 0.041);
            base = mix(base, team_color.rgb, stripes);
            iwH += 0.0012 * sin(s * 190.0 + uv.x * 18.0) * smoothstep(0.05, 0.1, s) * smoothstep(0.14, 0.1, s); // scrunch
          } else if (iwPart == 7.0 || iwPart == 20.0) { // SHOE UPPER: uv = (phi/2pi from toe, t sole->collar); p = bind pos
            float phi = uv.x, t = uv.y;
            float lat = vCloth.z; // +1 lateral side is +x for the left shoe
            float front = cos(phi * 6.2831);   // 1 at the toe, -1 at the heel
            float side = sin(phi * 6.2831);    // +-1 at the sides
            // overlay panels: toe cap + heel counter in the contrast colour, stitched edges
            float toeCapD = (0.62 - front) - 0.18 * t;           // < 0 inside
            float heelD = (front + 0.55) + 0.25 * (t - 0.2);     // < 0 inside
            vec3 c2 = iwContrast(shoe_color.rgb);
            float toeM = iwFill(toeCapD * 0.05), heelM = iwFill(heelD * 0.05);
            base = mix(base, c2, max(toeM, heelM));
            float edgeS = iwStroke(toeCapD * 0.05 + 0.0025, 0.0004) + iwStroke(heelD * 0.05 + 0.0025, 0.0004);
            base = mix(base, base * 0.7, edgeS * iwDash(phi * 0.62, 0.004, 0.62) * iwLod(phi * 0.62, 0.004));
            iwH += 0.0006 * (toeM + heelM) - 0.0004 * (iwStroke(toeCapD * 0.05, 0.0006) + iwStroke(heelD * 0.05, 0.0006));
            // side logo: a team-colour wave stripe (both sides)
            float wx = front * 0.5 + 0.12;                       // along the shoe
            float wy = t - 0.42 - 0.12 * sin(wx * 9.0);
            float logo = step(0.2, abs(side)) * iwFill((abs(wy) - 0.075 * (1.0 - smoothstep(-0.2, 0.45, abs(wx - 0.06)))) * 0.06);
            base = mix(base, team_color.rgb, logo);
            iwH += 0.00045 * logo;
            iwShine += 0.5 * logo;
            // perforations on the toe box (vamp top)
            float perfZ = step(0.55, front) * step(0.3, t);
            vec2 pp = vec2(p.x, p.z) * 260.0; vec2 pc = fract(pp) - 0.5;
            float perf = iwFill(length(pc) - 0.18) * perfZ * (1.0 - toeM) * iwLod(p.z * 260.0, 1.0);
            iwAO *= 1.0 - 0.5 * perf; iwH -= 0.0002 * perf;
            // leather grain
            iwH += 0.00012 * (iwNoise(p * 900.0) - 0.5) * iwLod(p.z * 900.0, 1.0);
            // creasing across the vamp
            iwH += 0.0005 * sin(t * 70.0) * smoothstep(0.2, 0.42, front) * smoothstep(0.78, 0.55, front) * smoothstep(0.3, 0.45, t) * smoothstep(0.9, 0.7, t);
            iwAO *= mix(0.72, 1.0, smoothstep(0.0, 0.16, t));   // contact darkening at the sole line
          } else if (iwPart == 8.0) { // MIDSOLE: uv = (phi, h 0..1)
            float phi = uv.x, h = uv.y;
            float front = cos(phi * 6.2831);
            // sculpted groove line + team accent pinstripe
            iwH -= 0.0009 * exp(-pow((h - 0.46 - 0.12 * front) / 0.07, 2.0));
            float pin = iwStroke(h - 0.72, 0.06) * step(abs(front), 0.95);
            base = mix(base, team_color.rgb, pin * 0.95);
            // heel window (team) on both sides
            float side = sin(phi * 6.2831);
            float win = iwSdBox(vec2(front + 0.62, h - 0.4), vec2(0.18, 0.2), 0.09);
            float wm = iwFill(win * 0.05) * step(0.3, abs(side));
            base = mix(base, team_color.rgb * 0.85, wm);
            iwH -= 0.0006 * wm; iwShine += wm;
            // foam micro texture
            iwH += 0.0001 * (iwNoise(p * 700.0) - 0.5) * iwLod(p.z * 700.0, 1.0);
          } else if (iwPart == 9.0) { // OUTSOLE: uv = foot-local (x, z) ; tread on the bottom
            vec2 f = uv;
            float herr = abs(fract(f.y * 55.0 + abs(f.x) * 22.0) - 0.5);
            float lug = smoothstep(0.18, 0.26, herr);
            float edgeZone = step(0.5, vCloth.z);
            iwH += 0.0012 * lug * (1.0 - edgeZone) * iwLod(f.y * 55.0, 1.0);
            iwAO *= mix(0.6, 1.0, lug);
            // siping on the side wall
            iwH += 0.0005 * edgeZone * step(0.5, fract(atan(f.x, f.y) * 12.0));
          } else if (iwPart == 10.0) { // STRAP webbing: uv = (along m, across -1..1)
            float edge = abs(uv.y);
            float st = iwStroke(edge - 0.72, 0.035) * iwDash(uv.x, 0.005, 0.62);
            base = mix(base, base * 0.6 + 0.06, st * iwLod(uv.x, 0.005));
            iwH += 0.00025 * st;
            iwAO *= mix(1.0, 0.8, smoothstep(0.8, 1.0, edge));
          } else if (iwPart == 11.0) { // TONGUE: uv = (across -1..1, along 0..1); team tab + logo at the top
            float tab = smoothstep(0.78, 0.8, uv.y);
            base = mix(base, team_color.rgb, tab);
            vec2 e = iwEmblem(vec2(uv.x * 0.018, (uv.y - 0.9) * 0.02), 0.0065);
            base = mix(base, vec3(0.97), e.x * tab);
            float st = iwStroke(abs(uv.x) - 0.82, 0.03) * iwDash(uv.y * 0.05, 0.004, 0.6);
            base = mix(base, base * 0.7, st);
            vec2 mp = vec2(uv.x * 0.02, uv.y * 0.05) * 700.0; // mesh
            float mh = iwFill(length(fract(mp) - 0.5) - 0.2) * (1.0 - tab) * iwLod(uv.y * 0.05 * 700.0, 1.0);
            iwAO *= 1.0 - 0.35 * mh;
          } else if (iwPart == 12.0) { // TANK CAP: uv = (theta, h); knurled grip band
            float kn = sin(uv.x * 6.2831 * 48.0);
            float band = step(0.18, uv.y) * step(uv.y, 0.82);
            iwH += 0.0005 * kn * band * iwLod(uv.x * 0.42, 0.42 / 48.0);
          } else if (iwPart == 13.0) { // GAUGE face: uv = polar (angle 0..1, r 0..1)
            float a = uv.x, r = uv.y;
            vec3 face = vec3(0.95, 0.94, 0.9);
            float ticks = iwStroke(fract(a * 24.0) - 0.5, 0.06) * step(0.72, r) * step(r, 0.9) * step(0.1, a) * step(a, 0.9);
            float red = step(0.72, r) * step(r, 0.9) * step(0.78, a) * step(a, 0.9);
            face = mix(face, vec3(0.1), ticks);
            face = mix(face, vec3(0.85, 0.15, 0.12), red);
            base = mix(face, vec3(0.05), smoothstep(0.93, 0.97, r));
          } else if (iwPart == 15.0) { // shorts CUFF: rolled hem, rib-less twill + stitch
            float st = iwStroke(uv.y - 0.5, 0.05) * iwDash(uv.x * 0.46, 0.005, 0.6);
            base = mix(base, base * 0.75, st);
          } else if (iwPart == 17.0) { // COLLAR PAD: soft quilting lines
            iwH += 0.0005 * sin(uv.x * 6.2831 * 14.0);
          } else if (iwPart == 18.0) { // PLATE: quilted back pad
            vec2 q = vec2(uv.x, uv.y) * 38.0;
            float quilt = iwStroke(fract(q.x + q.y) - 0.5, 0.03) + iwStroke(fract(q.x - q.y) - 0.5, 0.03);
            iwH -= 0.0004 * quilt; iwAO *= 1.0 - 0.18 * quilt;
          } else if (iwPart == 16.0) { // drawcord: twisted
            iwH += 0.0003 * sin(uv.x * 900.0 + uv.y * 6.2831 * 3.0);
          }

          // Preview-only tee art. All other original garment parts stay intact.
          if (iwPart == 1.0) base = teeBody(p);
          else if (iwPart == 2.0) base = teeSleeve(p, uv, vCloth.z);
          else if (iwPart == 3.0) base = trim_color.rgb;

          // ---------------- material-class micro detail ----------------
          if (iwCls == 0.0) {        // jersey knit: fine interlocked loops
            vec3 q = p * 1100.0;
            float k = sin(q.x + q.z) * sin(q.y * 1.4);
            iwH += 0.00006 * k * iwLod(p.y * 1100.0, 6.2831);
          } else if (iwCls == 1.0) { // twill: diagonal wales
            float k = sin((p.y * 0.9 + (p.x + p.z) * 0.6) * 1500.0);
            iwH += 0.00007 * k * iwLod(p.y * 1500.0, 6.2831);
          } else if (iwCls == 8.0) { // webbing: cross ribs
            float k = sin(uv.x * 2600.0);
            iwH += 0.00004 * k * iwLod(uv.x * 2600.0, 6.2831);
          } else if (iwCls == 10.0) { // lace braid
            iwH += 0.00012 * sin(uv.x * 1800.0) * iwLod(uv.x * 1800.0, 6.2831);
          }
          diffuseColor.rgb *= base;
        }
      
 
        {
          float r = 0.84;
          if (iwCls == 1.0) r = 0.8; else if (iwCls == 2.0) r = 0.86; else if (iwCls == 3.0) r = 0.46; else if (iwCls == 4.0) r = 0.62;
          else if (iwCls == 5.0) r = 0.86; else if (iwCls == 6.0) r = 0.3; else if (iwCls == 7.0) r = 0.28; else if (iwCls == 8.0) r = 0.7;
          else if (iwCls == 9.0) r = 0.74; else if (iwCls == 10.0) r = 0.8; else if (iwCls == 11.0) r = 0.78; else if (iwCls == 12.0) r = 0.5;
          ROUGHNESS = mix(r, r * 0.55, clamp(iwShine, 0.0, 1.0));
          ROUGHNESS = mix(ROUGHNESS, 0.16, iwHurtM);
        }
      
 METALLIC=iwCls==7.0?1.0:0.0;
 NORMAL=iwBumpN(NORMAL,iwH,VERTEX);
 float cc=iwCls==3.0?0.35:iwCls==4.0?0.05:iwCls==6.0?1.0:iwCls==7.0?0.4:0.0;
 CLEARCOAT=max(cc,iwShine*0.6);
 CLEARCOAT_ROUGHNESS=iwCls==6.0?0.12:0.3;
 AO=iwAO;
 ALBEDO=diffuseColor.rgb;
}
