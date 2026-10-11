shader_type spatial;
render_mode cull_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_size;
uniform float mural_id;
uniform bool new_art=false;
uniform int theme=0;
void fragment() {
	vec2 uv=vec2(UV.x*surface_size.x/(surface_size.y*8.0),(mural_id+1.0-clamp(UV.y,0.004,0.996))/4.0);
	vec4 art=texture(artwork,uv);
	if(new_art){
		// Original poster/sticker motifs: wave crest, compass and transit chevrons.
		vec2 p=vec2(fract(UV.x*surface_size.x/max(surface_size.y,1.0)),UV.y)-0.5;
		float frame=max(abs(p.x)-.43,abs(p.y)-.35);
		float mark=abs(p.y-sin(p.x*15.0+mural_id)*.10)-.025;
		if(mod(mural_id,3.0)<1.0)mark=abs(length(p)-.22)-.027;
		else if(mod(mural_id,3.0)>2.0)mark=min(abs(p.x-p.y*.7)-.04,abs(p.x+p.y*.7)-.04);
		float aa=max(fwidth(mark),.002);
		float icon=1.0-smoothstep(-aa,aa,mark);
		vec3 paper=theme==0?vec3(.93,.81,.63):vec3(.15,.34,.35);
		vec3 accent=theme==0?vec3(.24,.46,.49):vec3(.97,.74,.40);
		art=vec4(mix(paper,accent,icon),1.0-smoothstep(-.008,.008,frame));
	}
	ALBEDO=art.rgb;
	ALPHA=art.a;
	ALPHA_SCISSOR_THRESHOLD=0.5;
	ROUGHNESS=0.78;
}
