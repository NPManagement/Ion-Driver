// Chevron chase animation — sequential pulsing like an advert arrow sign.
// Phase is read from INSTANCE_CUSTOM.x when used with MultiMesh batching.
shader_type spatial;
render_mode unshaded;

uniform vec3 base_color : source_color = vec3(1.0, 0.0, 0.6);
uniform float speed : hint_range(0.5, 5.0) = 2.5;
uniform float emission_strength : hint_range(1.0, 50.0) = 25.0;

void fragment() {
	// Phase from MultiMesh custom data (per-instance)
	float p = INSTANCE_CUSTOM.x;
	// Chase wave: each chevron lights up in sequence, then fades
	float t = fract(TIME * speed / 3.0 - p);
	// Sharp pulse: bright when t is near 0, fades out
	float pulse = smoothstep(0.0, 0.1, t) * smoothstep(0.5, 0.1, t);
	// Very dim when off, bright neon when on
	float brightness = mix(0.03, 1.0, pulse);

	ALBEDO = base_color * brightness;
	EMISSION = base_color * brightness * emission_strength;
}
