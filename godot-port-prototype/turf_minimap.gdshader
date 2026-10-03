shader_type canvas_item;
render_mode unshaded;
uniform sampler2D cell_lookup : filter_nearest, repeat_disable;
uniform sampler2D ownership : filter_nearest, repeat_disable;
uniform vec2 atlas_size;
uniform vec4 team_a : source_color;
uniform vec4 team_b : source_color;
uniform vec2 edge_feather = vec2(0.0);
float owner_at(float k) {
 vec2 p = vec2(mod(k, atlas_size.x), floor(k / atlas_size.x));
 return floor(texture(ownership, (p + 0.5) / atlas_size).r * 255.0 + 0.5);
}
vec2 field(vec2 uv) {
 vec4 m = texture(cell_lookup, uv);
 if (m.x < 0.0) return vec2(0.0);
 vec4 g = vec4(owner_at(m.x), owner_at(m.x+1.0), owner_at(m.x+m.y), owner_at(m.x+m.y+1.0));
 vec4 w = vec4((1.0-m.z)*(1.0-m.w), m.z*(1.0-m.w), (1.0-m.z)*m.w, m.z*m.w);
 float a = dot(w, vec4(equal(g, vec4(1.0))));
 float b = dot(w, vec4(equal(g, vec4(2.0))));
 return vec2(smoothstep(0.34, 0.62, max(a,b)), a >= b ? 0.0 : 1.0);
}
void fragment() {
 vec4 base = texture(TEXTURE, UV);
 vec2 f = field(UV);
 vec2 texel = 1.0 / vec2(textureSize(cell_lookup, 0));
 float lit = max(0.0, f.x-field(UV-texel).x);
 float dark = max(0.0, f.x-field(UV+texel).x);
 vec3 ink = mix(team_a.rgb, team_b.rgb, f.y)*(0.94-dark*0.32)+lit*0.59;
 COLOR = vec4(mix(base.rgb, ink, f.x), base.a);
 // Borderless displays also soften the baked image's outer seam.
 if (edge_feather.x > 0.0 && edge_feather.y > 0.0) {
  vec2 edge = min(UV, vec2(1.0)-UV);
  vec2 mask = smoothstep(edge_feather*0.5, edge_feather, edge);
  COLOR.a *= min(mask.x, mask.y);
 }
}
