shader_type spatial;

render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 lightning_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float intensity = 8.0;

void fragment()
{
	float dist = abs(UV.x - 0.5) * 2.0;

	float edge = 1.0 - smoothstep(0.3, 1.0, dist);

	ALBEDO = lightning_color.rgb * intensity;
	ALPHA = edge;
}