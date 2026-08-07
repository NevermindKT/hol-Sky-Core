shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 fog_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

uniform float opacity : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D vertical_gradient : hint_default_black;

void fragment()
{
	// vertical_gradient is a CurveTexture: its X axis (0..1) maps to
	// UV.y (bottom → top of the plane), and the curve's Y value is
	// used directly as alpha. Shape the whole fade — bottom fade-in,
	// solid middle, top fade-out — by editing the Curve resource
	// assigned to this uniform in the Inspector.
	float alpha = texture(vertical_gradient, vec2(UV.y, 0.5)).r;

	ALBEDO = fog_color.rgb;
	ALPHA = alpha * opacity;
}
