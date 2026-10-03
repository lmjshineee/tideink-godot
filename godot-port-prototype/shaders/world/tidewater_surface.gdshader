shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform int pattern = 0;
uniform vec3 block_size = vec3(1.0);
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_position = VERTEX;
	local_normal = NORMAL;
}

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float grid_line(float p, float period, float width) {
	float d = min(fract(p / period), 1.0 - fract(p / period)) * period;
	return 1.0 - smoothstep(width, width + max(fwidth(p), 0.001), d);
}

void fragment() {
	// Metre-scaled patterns follow maps.js PATTERN IDs and levelMaterial.js.
	vec3 n = abs(local_normal);
	vec2 size = n.y > 0.5 ? block_size.xz : (n.x > n.z ? block_size.zy : block_size.xy);
	vec2 p = (n.y > 0.5 ? local_position.xz : (n.x > n.z ? local_position.zy : local_position.xy)) + size * 0.5;
	float edge = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	vec3 base = base_color.rgb;
	float rough = 0.83;
	vec2 micro = vec2(sin(p.x * 51.0 + sin(p.y * 27.0)), cos(p.y * 43.0 + sin(p.x * 19.0))) * 0.018;
	if (pattern == 1 || pattern == 2 || pattern == 8) {
		float repeat = pattern == 1 ? 2.0 : (pattern == 8 ? 0.6 : 0.5);
		float seam = max(grid_line(p.x, repeat, 0.012), grid_line(p.y, repeat, 0.012));
		base *= (0.94 + 0.08 * hash2(floor(p / repeat))) * (1.0 - 0.22 * seam);
		micro += vec2(sin(p.x / repeat * 6.28318), sin(p.y / repeat * 6.28318)) * seam * 0.12;
		rough = pattern == 1 ? 0.86 : 0.6;
		if (pattern == 8 && local_normal.y > 0.5) {
			float band = (1.0 - smoothstep(0.34, 0.36, edge)) * step(0.05, edge);
			base = mix(base, mix(vec3(0.93,0.64,0.04),vec3(0.025),step(0.5,fract((p.x+p.y)*1.6))), band);
		}
		if (pattern == 1 && world_normal.y > 0.5) {
			float radius = length(world_position.xz);
			float ring = 1.0 - smoothstep(0.07,0.07+max(fwidth(radius),0.005),abs(radius-9.5));
			float mid = (1.0-smoothstep(0.05,0.05+max(fwidth(world_position.z),0.005),abs(world_position.z)))*step(9.5,abs(world_position.x));
			base = mix(base,vec3(0.9),max(ring,mid)*0.9);
		}
	} else if (pattern == 3) {
		float seam = grid_line(p.y,1.2,0.01);
		vec2 tie = (fract(p/1.2-vec2(0.0,0.25))-0.5)*1.2;
		base *= (1.0-0.14*seam)*(1.0-0.3*(1.0-smoothstep(0.02,0.035,length(tie))));
	} else if (pattern == 4) {
		base *= 1.0-0.18*grid_line(p.y,0.35,0.02);
		if (local_normal.y > 0.5) base=mix(base,vec3(0.85,0.53,0.025),1.0-smoothstep(0.16,0.2,min(p.x,size.x-p.x)));
	} else if (pattern == 5) {
		float rib = sin(p.x/0.28*6.28318);
		micro.x += cos(p.x/0.28*6.28318) * 0.10;
		base *= 0.87+0.13*rib;
		base *= mix(0.68,1.0,smoothstep(0.06,0.1,edge));
		rough=0.5;
	} else if (pattern == 6) {
		float grain = sin(p.x*22.0+sin(p.y*8.0)*1.8);
		micro.x += grain * 0.045;
		base *= (0.92+grain*0.045)*(1.0-0.28*grid_line(p.y,0.26,0.008));
		base *= mix(0.78,1.0,smoothstep(0.07,0.11,edge));
		rough=0.78;
	} else if (pattern == 7) {
		base *= 0.94+0.06*sin(p.x*80.0);
		rough=0.45;
	} else if (pattern == 9 && local_normal.y > 0.5) {
		base=mix(base,vec3(0.10,0.27,0.045)*(0.9+0.2*hash2(floor(p*20.0))),smoothstep(0.24,0.27,edge));
	} else if (pattern == 10) {
		// Asphalt was previously an unimplemented plain colour in the native map.
		float grit=hash2(floor(p*45.0));
		base *= 0.78 + grit * 0.18;
		micro *= 2.2;rough=0.92;
		if(local_normal.y>0.5)base=mix(base,vec3(0.92,0.77,0.32),grid_line(p.x,3.0,0.045)*0.72);
	} else if (pattern == 11 || pattern == 12) {
		float seam=max(grid_line(p.x,1.2,0.015),grid_line(p.y,1.2,0.015));
		float chevron=sin(p.x*28.0+p.y*16.0)*sin(p.x*28.0-p.y*16.0);
		base *= 0.93-0.19*seam+chevron*0.035;
		micro+=vec2(chevron,-chevron)*0.045;rough=0.48;
	} else if (pattern == 13 || pattern == 16) {
		float row=floor(p.y/0.32);
		float seam=max(grid_line(p.x+mod(row,2.0)*0.3,0.6,0.012),grid_line(p.y,0.32,0.012));
		vec2 tile=vec2(floor((p.x+mod(row,2.0)*0.3)/0.6),row);
		base *= (0.88+hash2(tile)*0.14)*(1.0-seam*0.23);
		micro*=1.6;rough=0.81;
	} else if (pattern == 14) {
		base*=0.94-0.10*max(grid_line(p.x,0.08,0.005),grid_line(p.y,0.08,0.005));rough=0.96;
	} else if (pattern == 15) {
		float seam=max(grid_line(p.x,0.8,0.015),grid_line(p.y,0.8,0.015));
		base*=(0.92+hash2(floor(p/0.8))*0.09)*(1.0-seam*0.19);rough=0.26;
	}
	ALBEDO = base;
	NORMAL_MAP = normalize(vec3(micro,1.0)) * 0.5 + 0.5;
	ROUGHNESS = clamp(rough + hash2(floor(p * 8.0)) * 0.035,0.1,1.0);
	SPECULAR = 0.25;
}
