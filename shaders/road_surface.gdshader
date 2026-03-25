// Road Surface Shader — samples road strip from atlas texture, tiles along road length.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D road_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

// Atlas region for the road strip (center-top of atlas)
uniform float atlas_u_min : hint_range(0.0, 1.0) = 0.245;
uniform float atlas_u_max : hint_range(0.0, 1.0) = 0.755;
uniform float atlas_v_min : hint_range(0.0, 1.0) = 0.0;
uniform float atlas_v_max : hint_range(0.0, 1.0) = 0.63;

void fragment() {
	// UV.x = 0..1 across road width -> remap to atlas U region
	float u = mix(atlas_u_min, atlas_u_max, UV.x);

	// UV.y tiles along road length -> remap to atlas V region (repeating)
	float v_frac = fract(UV.y);
	float v = mix(atlas_v_min, atlas_v_max, v_frac);

	vec3 albedo = texture(road_tex, vec2(u, v)).rgb;
	albedo = mix(albedo, albedo * 0.15, darkness);

	ALBEDO = albedo;
	METALLIC = 0.0;
	ROUGHNESS = 0.8;
}
