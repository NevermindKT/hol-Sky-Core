shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;

uniform vec4 haze_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

uniform float opacity : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D vertical_gradient : hint_default_black;

void fragment()
{
	float alpha = texture(vertical_gradient, vec2(UV.y, 0.5)).r;

	vec3 blurred_backdrop = textureLod(screen_texture, SCREEN_UV, blur_amount).rgb;
	vec3 color = mix(blurred_backdrop, haze_tint.rgb, tint_strength);

	ALBEDO = color;
	ALPHA = alpha * opacity;
}
