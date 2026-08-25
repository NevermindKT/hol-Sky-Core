shader_type spatial;

render_mode unshaded, blend_add, cull_disabled, depth_draw_never, particle_trails;

uniform vec4 trail_color : source_color = vec4(1.0);

uniform float tail_width : hint_range(0.05, 1.0) = 0.2;
uniform float core_size : hint_range(0.05, 1.0) = 0.25;
uniform float glow_size : hint_range(0.1, 2.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 5.0) = 1.0;

void fragment()
{
	float alpha_length = UV.y;

	float width_scale = mix(tail_width, 1.0, UV.y);
	float dist = abs(UV.x - 0.5) * 2.0 / width_scale;

	float glow = 1.0 - smoothstep(0.0, glow_size, dist);
	float core = 1.0 - smoothstep(0.0, core_size, dist);

	float alpha = alpha_length * glow;

	vec3 color = trail_color.rgb * (glow + core) * emission_strength;

	ALBEDO = color;
	EMISSION = color;
	ALPHA = alpha * trail_color.a;
}