// Ion Exhaust / Trail Shader — additive blended quad for engine exhaust glow.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4  glow_color   : source_color = vec4(0.30, 0.80, 1.00, 1.0);
uniform float intensity    : hint_range(0.0, 12.0) = 4.0;
uniform float core_size    : hint_range(0.05, 0.8) = 0.25;
uniform float speed        : hint_range(0.5, 8.0)  = 2.5;

void fragment() {
	// Radial distance from center of quad
	vec2  center  = UV - vec2(0.5);
	float dist    = length(center) * 2.0;

	// Core bright + soft falloff halo
	float core    = 1.0 - smoothstep(0.0, core_size, dist);
	float halo    = 1.0 - smoothstep(core_size, 1.0, dist);
	halo          = pow(halo, 2.5);

	// Animated flicker
	float flicker = sin(TIME * speed * 7.3 + UV.y * 4.0) * 0.08 + 0.92;

	float alpha   = (core * 1.5 + halo * 0.7) * flicker;
	alpha         = clamp(alpha, 0.0, 1.0);

	// Tail fade (UV.y = 0 at source, 1 at tip of trail)
	float tail_fade = 1.0 - UV.y;
	tail_fade       = pow(tail_fade, 0.7);

	ALBEDO  = glow_color.rgb;
	EMISSION= glow_color.rgb * intensity * alpha * tail_fade;
	ALPHA   = alpha * tail_fade * 0.85;
}
