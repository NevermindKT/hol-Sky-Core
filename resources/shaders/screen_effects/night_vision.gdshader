shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 tint_color : source_color = vec3(0.4, 1.0, 0.5);
uniform float grain_strength : hint_range(0.0, 1.0) = 0.15;
uniform float noise_speed : hint_range(0.0, 20.0) = 8.0;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec3 base_color = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(base_color, vec3(0.299, 0.587, 0.114));
	vec3 tinted = tint_color * luminance;

	float noise = random(SCREEN_UV * vec2(1000.0, 1000.0) + TIME * noise_speed);
	tinted += (noise - 0.5) * grain_strength;

	COLOR = vec4(tinted, 1.0);
}
