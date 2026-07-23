shader_type canvas_item;

uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float sunset_glow : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float t = UV.y;

	vec3 night_zenith = vec3(0.01, 0.005, 0.08);
	vec3 day_zenith = vec3(0.35, 0.55, 0.80);

	vec3 night_horizon = vec3(0.04, 0.02, 0.10);
	vec3 day_horizon = vec3(0.60, 0.70, 0.85);
	vec3 sunset_horizon = vec3(1.0, 0.35, 0.08);

	vec3 zenith = mix(day_zenith, night_zenith, night_factor);
	vec3 horizon = mix(day_horizon, night_horizon, night_factor);

	float sunset_fade = max(0.0, 1.0 - t * 1.8);
	horizon = mix(horizon, sunset_horizon, sunset_glow * sunset_fade * sunset_fade);

	vec3 color = mix(zenith, horizon, pow(t, 0.4));

	COLOR = vec4(color, mix(0.65, 0.25, t));
}
