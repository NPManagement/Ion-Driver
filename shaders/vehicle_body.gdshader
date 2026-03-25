// Ion Vehicle Body Shader — PBR metallic body with energy shield pulse and emission trim.
shader_type spatial;

uniform vec4  body_color     : source_color = vec4(0.10, 0.45, 0.95, 1.0);
uniform vec4  accent_color   : source_color = vec4(0.30, 0.85, 1.00, 1.0);
uniform float metallic_val   : hint_range(0.0, 1.0)  = 0.92;
uniform float roughness_val  : hint_range(0.0, 1.0)  = 0.10;
uniform float clearcoat_val  : hint_range(0.0, 1.0)  = 1.00;
uniform float emission_str   : hint_range(0.0, 8.0)  = 2.00;
uniform float shield_level   : hint_range(0.0, 1.0)  = 1.00;  // Set from script
uniform float boost_level    : hint_range(0.0, 1.0)  = 0.00;  // Set from script
uniform float energy_level   : hint_range(0.0, 1.0)  = 1.00;

void fragment() {
	// Edge Fresnel effect
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);

	// Shield ripple when damaged
	float shield_pulse = 0.0;
	if (shield_level < 0.99) {
		shield_pulse = sin(TIME * 12.0) * (1.0 - shield_level) * 0.5;
	}

	// Boost glow
	vec3 boost_glow = accent_color.rgb * boost_level * 3.0;

	// Energy trim emission (pulses with energy level)
	float energy_pulse = sin(TIME * 3.0) * 0.15 + 0.85;
	vec3 trim_emission = accent_color.rgb * emission_str * energy_level * energy_pulse;

	// Shield hex pattern (subtle, visible when hit)
	float hex_pattern = 0.0;
	if (shield_level < 0.8) {
		vec2 hex_uv = UV * 8.0;
		hex_pattern = sin(hex_uv.x * 6.283) * sin(hex_uv.y * 6.283);
		hex_pattern = clamp(hex_pattern * (1.0 - shield_level) * 2.0, 0.0, 1.0);
	}

	ALBEDO    = body_color.rgb;
	METALLIC  = metallic_val;
	ROUGHNESS = roughness_val;
	CLEARCOAT = clearcoat_val;
	CLEARCOAT_ROUGHNESS = 0.04;
	SPECULAR  = 0.85;

	// Final emission
	vec3 emission  = trim_emission;
	emission      += boost_glow;
	emission      += accent_color.rgb * fresnel * 1.5 * energy_level;
	emission      += vec3(0.2, 0.6, 1.0) * hex_pattern * 3.0 + shield_pulse;
	EMISSION       = emission;
}
