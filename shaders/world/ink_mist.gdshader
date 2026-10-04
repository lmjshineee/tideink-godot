shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec3 fog_center;
uniform vec3 fog_size = vec3(3.0, 2.0, 3.0);
uniform vec4 ink_color : source_color;
uniform float density = 1.0;
uniform float fade = 1.0;
varying vec3 world_vertex;
void vertex() { world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 origin = CAMERA_POSITION_WORLD;
	vec3 direction = normalize(world_vertex-origin);
	vec3 relative = (origin-fog_center)/fog_size;
	vec3 ray = direction/fog_size;
	float a = dot(ray,ray);
	float b = dot(relative,ray);
	float discriminant = b*b-a*(dot(relative,relative)-1.0);
	float near_t = max(0.0, (-b-sqrt(max(0.0,discriminant)))/a);
	float far_t = (-b+sqrt(max(0.0,discriminant)))/a;
	// Reverse-Z depth stops the integration at the actual wall, floor or actor.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0, depth);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ndc.z = depth*2.0-1.0;
#endif
	vec4 view_point = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_point /= view_point.w;
	vec3 scene_point = (INV_VIEW_MATRIX * view_point).xyz;
	far_t = min(far_t, length(scene_point-origin));
	float span = max(0.0, far_t-near_t);
	float optical = 0.0;
	float texture_tone = 0.0;
	for (int i=0; i<6; i++) {
		vec3 p = origin+direction*(near_t+span*(float(i)+0.5)/6.0)-fog_center;
		float swirl = sin(p.x*2.7+TIME*.8)*sin(p.y*3.0-TIME*.6)*sin(p.z*2.5+TIME*.4);
		float envelope = 1.0-smoothstep(.6, 1.0, length(p/fog_size));
		optical += envelope*(.7+.3*swirl);
		texture_tone += swirl;
	}
	ALBEDO = ink_color.rgb*(.8+.12*texture_tone/6.0);
	ALPHA = (1.0-exp(-density*span*optical/6.0))*fade;
}
