// Holographic UI Shader — scanlines, edge glow, and subtle glitch for CanvasItem panels.
shader_type canvas_item;

uniform float scanline_count : hint_range(20.0, 300.0) = 100.0;
uniform float scanline_str   : hint_range(0.0,   0.5)  = 0.12;
uniform float glitch_str     : hint_range(0.0,   0.3)  = 0.04;
uniform float flicker_speed  : hint_range(0.0,  20.0)  = 9.0;
uniform vec4  tint           : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform float edge_glow      : hint_range(0.0,   2.0)  = 0.6;
uniform float corner_radius  : hint_range(0.0,  50.0)  = 8.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// Scanlines
	float scan = sin(UV.y * scanline_count * 3.14159) * 0.5 + 0.5;
	scan = 1.0 - scan * scanline_str;

	// Subtle glitch
	vec2 g_uv = UV;
	float glitch_t = sin(TIME * 13.7);
	if (glitch_t > 0.93) {
		g_uv.x += sin(UV.y * 80.0 + TIME * 30.0) * glitch_str;
	}
	vec4 glitch_sample = texture(TEXTURE, g_uv);
	base = mix(base, glitch_sample, 0.2);

	// Subtle flicker
	float flicker = sin(TIME * flicker_speed) * 0.015 + 1.0;

	// Edge glow
	float edge_x  = min(UV.x, 1.0 - UV.x);
	float edge_y  = min(UV.y, 1.0 - UV.y);
	float edge_d  = min(edge_x, edge_y) * 10.0;
	float edge_f  = 1.0 - smoothstep(0.0, 1.0, edge_d);
	vec3  glow    = tint.rgb * edge_f * edge_glow;

	// Compose
	vec4 result  = base * tint;
	result.rgb  *= scan * flicker;
	result.rgb  += glow;

	COLOR = result;
}
