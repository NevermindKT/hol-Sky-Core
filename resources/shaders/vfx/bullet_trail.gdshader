shader_type spatial;

render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 trail_color : source_color = vec4(1.0);

uniform float tail_width : hint_range(0.05, 1.0) = 0.2;
uniform float core_size : hint_range(0.05, 1.0) = 0.25;
uniform float glow_size : hint_range(0.1, 2.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 5.0) = 1.0;

void fragment()
{
	float alpha_length = UV.y;
	float width_scale = mix(tail_width, 1.0, UV.y);

	float dist = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float glow = 1.0 - smoothstep(0.0, glow_size, dist);
	float core = 1.0 - smoothstep(0.0, core_size, dist);

	vec3 color = trail_color.rgb * (0.4 + glow + core) * emission_strength;

	ALBEDO = color;
	EMISSION = color;
	ALPHA = alpha_length * width_scale * trail_color.a;
}