shader_type spatial;
render_mode cull_disabled;
// Source layered iris, capsule pupil, lid/lash, three catchlights and emission.
uniform vec4 iris_color : source_color;
uniform vec4 iris_dark : source_color;
uniform vec2 look=vec2(0.0);
varying vec2 vEyeUv;
varying float vSide;
float iwCircle(vec2 p,vec2 c,float r){float d=length(p-c)-r;float w=max(fwidth(d),1e-4);return 1.0-smoothstep(-w,w,d);}
void vertex(){vEyeUv=UV;vSide=UV2.x;}
void fragment(){
 vec4 diffuseColor=COLOR;
 
        vec3 iwEyeEmit = vec3(0.0); float iwEyeRim = 0.0;
        {
          vec2 p = vEyeUv;
          float r = length(p);
          float outer = p.x * sign(vSide + 1e-3);           // + toward the outer corner
          vec2 q = p - look;
          // sclera: cool white, shaded under the top lid and toward the rim
          vec3 sclera = mix(vec3(0.93, 0.94, 0.97), vec3(0.78, 0.8, 0.88), smoothstep(0.35, 1.0, r));
          sclera *= mix(0.72, 1.0, smoothstep(0.98, 0.3, p.y));
          // iris
          vec2 iq = q * vec2(1.0, 0.94);
          float ir = length(iq) / 0.66;
          float iris = iwCircle(iq, vec2(0.0), 0.66);
          float ang = atan(iq.y, iq.x);
          vec3 ic = mix(iris_dark.rgb, iris_color.rgb, smoothstep(0.55, -0.75, q.y));
          float stri = 0.5 + 0.5 * sin(ang * 23.0 + 3.0 * sin(ang * 5.0)) ;
          ic *= mix(0.86, 1.08, stri * smoothstep(0.25, 0.8, ir));
          ic = mix(ic, ic * 1.45 + 0.06, smoothstep(0.3, 0.95, ir) * smoothstep(0.15, -0.65, q.y)); // lower glow crescent
          ic = mix(ic, ic * 1.25 + 0.04, (1.0 - smoothstep(0.34, 0.5, ir)) * 0.6);                  // inner ring
          ic *= mix(1.0, 0.42, smoothstep(0.78, 1.0, ir));                                           // limbal ring
          ic *= mix(0.7, 1.0, smoothstep(0.75, 0.1, q.y));                                           // lid shadow
          // pupil: tall rounded capsule
          vec2 pq = (q - vec2(0.0, 0.03)) * vec2(1.0, 0.8);
          float pd = length(vec2(pq.x, max(abs(pq.y) - 0.07, 0.0))) - 0.24;
          float pw = max(fwidth(pd), 1e-4);
          float pupil = 1.0 - smoothstep(-pw, pw, pd);
          vec3 col = mix(sclera, ic, iris);
          col = mix(col, vec3(0.012, 0.01, 0.028), pupil);
          // catch-lights (same key light for both eyes) + a soft window reflection
          float h1 = iwCircle(p * vec2(1.0, 0.9), look * 0.5 + vec2(-0.25, 0.3), 0.19);
          float h2 = iwCircle(p, look * 0.5 + vec2(0.24, -0.3), 0.075);
          float h3 = iwCircle(p * vec2(1.0, 1.6), look * 0.5 + vec2(0.08, 0.62), 0.07) * 0.6;
          col = mix(col, vec3(1.0), max(max(h1, h2 * 0.9), h3));
          // top lid: thick dark lash line, thinner lower lid, lash flicks at the outer corner
          float lidTop = smoothstep(0.7, 0.82, p.y + 0.12 * outer * outer) * smoothstep(0.35, 0.6, r);
          float lash1 = iwCircle(vec2(outer, p.y) , vec2(0.86, 0.46), 0.1);
          float lash2 = iwCircle(vec2(outer, p.y) , vec2(0.95, 0.24), 0.07);
          float rim = smoothstep(0.84, 0.97, r);
          float lids = max(max(lidTop, rim), max(lash1, lash2) * smoothstep(0.7, 0.9, r));
          col = mix(col, vec3(0.018, 0.018, 0.03), lids);
          iwEyeRim = lids;
          diffuseColor.rgb = col;
          iwEyeEmit = col * (0.07 * (1.0 - lids)) + vec3(1.0) * max(h1, h2) * 0.2 + ic * iris * (1.0 - pupil) * 0.06;
        }
      
 ALBEDO=diffuseColor.rgb;
 EMISSION=iwEyeEmit*0.25;
 ROUGHNESS=mix(0.28,0.45,iwEyeRim);
 CLEARCOAT=0.25;
 CLEARCOAT_ROUGHNESS=0.2;
}
