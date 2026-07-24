shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float arms : hint_range(1.0, 12.0) = 3.0;
uniform float twist : hint_range(0.0, 20.0) = 6.0;
uniform float edge_softness : hint_range(0.0, 0.2) = 0.04;
uniform vec2 origin = vec2(0.5, 0.5);
uniform vec2 grid_size = vec2(64.0, 36.0);

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	// grid cell for this pixel
	vec2 cell_uv = vec2(1.0) / grid_size;
	vec2 cell_idx = floor(uv * grid_size);
	vec2 cell_center = (cell_idx + vec2(0.5)) * cell_uv;

	// evaluate spiral at the cell center
	vec2 centered = cell_center - origin;
	centered.x *= aspect;

	float r = length(centered);
	vec2 farthest = max(origin, vec2(1.0) - origin) * vec2(aspect, 1.0);
	float max_r = length(farthest) + 0.001;
	float norm_r = r / max_r;

	float angle = atan(centered.y, centered.x);

	float arm_pos = (angle + norm_r * twist) * arms / TAU;
	float arm_local = fract(arm_pos + 100.0);

	float eased = smoothstep(0.0, 1.0, progress);

	float extent = eased * (1.0 + edge_softness * 2.0);
	float r_edge = smoothstep(extent - edge_softness, extent + edge_softness, norm_r);

	float arm_fill_raw = max(0.0, eased - 0.1) / 0.9;
	float arm_fill = arm_fill_raw * (1.0 + edge_softness * 2.0) - edge_softness;
	float f_edge = smoothstep(arm_fill - edge_softness, arm_fill + edge_softness, arm_local);

	float cell_coverage = 1.0 - max(r_edge, f_edge);

	// each cell is split by the anti-diagonal into two triangles
	// they fill from the anti-diagonal (through cell center) outward to the far corners
	vec2 cell_local = uv * grid_size - cell_idx; // 0..1 within cell
	float tri_dist = abs(cell_local.x + cell_local.y - 1.0);

	// pop animation: triangle briefly overshoots as it expands
	float tri_soft = 0.02;
	float pop = cell_coverage * (1.0 + tri_soft * 2.0) + 0.15 * cell_coverage * (1.0 - cell_coverage) * (1.0 - cell_coverage);
	float tri_edge = smoothstep(pop - tri_soft, pop + tri_soft, tri_dist);
	float mask = 1.0 - clamp(tri_edge, 0.0, 1.0);

	COLOR = vec4(fill_color.rgb, fill_color.a * mask);
}
