shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float arms : hint_range(1.0, 12.0) = 3.0;
uniform float twist : hint_range(0.0, 20.0) = 6.0;
uniform float edge_softness : hint_range(0.0, 0.2) = 0.04;
uniform vec2 origin = vec2(0.5, 0.5);
uniform vec2 pixel_size = vec2(0.00078125, 0.00138889);

void fragment() {
	vec2 uv = UV;
	vec2 aspect = vec2(1.0, pixel_size.y / pixel_size.x);

	vec2 centered = (uv - origin) * aspect;
	vec2 farthest = max(origin, vec2(1.0) - origin) * aspect;
	float max_r = length(farthest) + 0.001;
	float norm_r = length(centered) / max_r;

	float angle = atan(centered.y, centered.x);
	float arm_pos = (angle + norm_r * twist) * arms / TAU;
	float arm_local = fract(arm_pos + 100.0);

	float eased = smoothstep(0.0, 1.0, progress);
	float extent = eased * (1.0 + edge_softness * 2.0);
	float r_edge = smoothstep(extent - edge_softness, extent + edge_softness, norm_r);

	float arm_fill_raw = max(0.0, eased - 0.1) / 0.9;
	float arm_fill = arm_fill_raw * (1.0 + edge_softness * 2.0) - edge_softness;
	float f_edge = smoothstep(arm_fill - edge_softness, arm_fill + edge_softness, arm_local);

	float mask = 1.0 - clamp(max(r_edge, f_edge), 0.0, 1.0);

	COLOR = vec4(fill_color.rgb, fill_color.a * mask);
}