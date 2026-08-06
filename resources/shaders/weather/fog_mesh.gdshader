shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 fog_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

uniform float opacity : hint_range(0.0, 1.0) = 0.5;

uniform float bottom_start : hint_range(0.0, 1.0) = 0.0;
uniform float bottom_end   : hint_range(0.0, 1.0) = 0.4;

uniform float top_start    : hint_range(0.0, 1.0) = 0.6;
uniform float top_end      : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D noise_texture;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.15;
uniform float noise_scale = 1.0;

void fragment()
{
    float bottom = smoothstep(bottom_start, bottom_end, UV.y);
    float top = 1.0 - smoothstep(top_start, top_end, UV.y);

    float alpha = bottom * top;
	
	float noise = texture(noise_texture, UV * noise_scale).r;

	alpha *= mix(1.0, noise, noise_strength);

    ALBEDO = fog_color.rgb;
    ALPHA = alpha * opacity;
}