shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 tint_color : source_color = vec3(0.4, 1.0, 0.5);
uniform float grain_strength : hint_range(0.0, 1.0) = 0.15;
uniform float noise_speed : hint_range(0.0, 20.0) = 8.0;
uniform float saturation_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float hot_color_boost : hint_range(1.0, 3.0) = 1.3;
uniform float hot_hue_center : hint_range(0.0, 360.0) = 58.0;
uniform float hot_hue_width : hint_range(0.0, 180.0) = 25.0;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float get_hue_degrees(vec3 c, float delta, float cmax) {
	if (delta < 0.0001) {
		return 0.0;
	}

	float h;
	if (cmax == c.r) {
		h = mod((c.g - c.b) / delta, 6.0);
	} else if (cmax == c.g) {
		h = (c.b - c.r) / delta + 2.0;
	} else {
		h = (c.r - c.g) / delta + 4.0;
	}

	return h * 60.0;
}

void fragment() {
	vec3 base_color = texture(screen_texture, SCREEN_UV).rgb;

	float max_c = max(base_color.r, max(base_color.g, base_color.b));
	float min_c = min(base_color.r, min(base_color.g, base_color.b));
	float saturation = max_c - min_c;
	float hue = get_hue_degrees(base_color, saturation, max_c);

	vec3 green_look = tint_color * max_c;
	vec3 hot_look = base_color * hot_color_boost;

	float sat_amount = smoothstep(saturation_threshold, saturation_threshold + 0.2, saturation);
	float hue_distance = abs(hue - hot_hue_center);
	float hue_amount = 1.0 - smoothstep(hot_hue_width, hot_hue_width + 15.0, hue_distance);

	float hot_amount = sat_amount * hue_amount;
	vec3 tinted = mix(green_look, hot_look, hot_amount);

	float noise = random(SCREEN_UV * vec2(1000.0, 1000.0) + TIME * noise_speed);
	tinted += (noise - 0.5) * grain_strength;

	COLOR = vec4(tinted, 1.0);
}
