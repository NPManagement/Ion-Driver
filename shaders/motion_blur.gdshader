shader_type canvas_item;

// Forward radial motion blur — tunnel vision at speed.
// blur_strength is set from GDScript based on vehicle speed.

uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;
uniform int   samples       : hint_range(4, 24)    = 16;
uniform vec2  blur_center = vec2(0.5, 0.5);

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - blur_center;
	float dist = length(from_center);

	// Only affect edges — center stays perfectly clear
	float edge_mask = smoothstep(0.2, 0.75, dist);

	// Streak outward from center — forward tunnel vision
	vec2 streak_dir = normalize(from_center + vec2(0.0001));
	float strength = blur_strength * edge_mask * 0.12;

	vec4 col = vec4(0.0);
	float total_weight = 0.0;
	for (int i = 0; i < samples; i++) {
		float t = float(i) / float(samples - 1);
		vec2 offset = streak_dir * t * strength;
		float w = 1.0 - t * 0.7;
		col += texture(screen_tex, uv + offset) * w;
		total_weight += w;
	}
	col /= total_weight;

	COLOR = col;
}
