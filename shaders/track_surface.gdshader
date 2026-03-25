// Track Surface Shader — PBR asphalt using real textures, tiled across the world.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D displacement_tex : filter_linear_mipmap_anisotropic, repeat_enable;

uniform float tile_scale : hint_range(0.001, 1.0) = 0.05;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.0;
uniform float roughness_multiplier : hint_range(0.0, 2.0) = 1.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 wuv = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * tile_scale;

	vec3 albedo = texture(albedo_tex, wuv).rgb;
	albedo = mix(albedo, albedo * 0.15, darkness); // Darken for night scene

	float rough = texture(roughness_tex, wuv).r * roughness_multiplier;

	ALBEDO = albedo;
	METALLIC = 0.0;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	NORMAL_MAP = texture(normal_tex, wuv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
