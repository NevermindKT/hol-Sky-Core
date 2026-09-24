shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float desaturation : hint_range(0.0, 1.0) = 0.5;
uniform vec3 tint_color : source_color = vec3(0.6, 0.75, 1.0);
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.6;

void fragment() {
	vec3 base_color = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(base_color, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(base_color, vec3(luminance), desaturation);
	vec3 tinted = desaturated * tint_color;

	float dist = distance(SCREEN_UV, vec2(0.5));
	float vignette = smoothstep(0.8, 0.2, dist * (1.0 + vignette_strength));

	COLOR = vec4(tinted * mix(0.4, 1.0, vignette), 1.0);
}
