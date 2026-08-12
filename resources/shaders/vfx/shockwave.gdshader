shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// Легке викривлення екрана крізь сферу — імітує "сколихнуте повітря". 
// dissolve керується скриптом (0 = щойно з'явилась,
// 1 = повністю згасла) під час play().

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float distortion_strength : hint_range(0.0, 0.3) = 0.06;
uniform float fresnel_power : hint_range(0.1, 8.0) = 2.5;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 screen_uv = SCREEN_UV;

	vec3 view_normal = normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 offset = view_normal.xy * distortion_strength * (1.0 - dissolve);

	vec3 distorted = textureLod(screen_texture, screen_uv + offset, 0.0).rgb;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);

	ALBEDO = distorted;
	ALPHA = fresnel * (1.0 - dissolve);
}
