shader_type canvas_item;


uniform float pixel_size : hint_range(0.0, 20.0, 1.0);
uniform vec2 gamma;

uniform float posterize_strength : hint_range(0.0, 1.0) = 1.0;

uniform float shadow_levels : hint_range(1.0, 32.0, 1.0) = 3.0;
uniform float midtone_levels : hint_range(1.0, 32.0, 1.0) = 6.0;
uniform float highlight_levels : hint_range(1.0, 32.0, 1.0) = 4.0;

uniform float shadow_range : hint_range(0.0, 1.0, 0.01) = 0.33;
uniform float highlight_range : hint_range(0.0, 1.0, 0.01) = 0.66;

uniform float noise_strength : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float noise_darkness : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float noise_scale : hint_range(1.0, 100.0, 1.0) = 40.0;
uniform float noise_speed : hint_range(0.0, 30.0, 0.1) = 10.0;

// Доля "цветного" шума (хрома) против чисто яркостного (моно).
// 0.0 = как раньше, одноцветный шум. 1.0 = полностью цветной спекл.
uniform float noise_chroma : hint_range(0.0, 1.0, 0.01) = 0.6;


void posterize(inout vec3 color) {
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));

	float lower;
	float upper;
	float local_levels;

	if (luminance < shadow_range) {
		lower = 0.0;
		upper = shadow_range;
		local_levels = shadow_levels;
	}
	else if (luminance < highlight_range) {
		lower = shadow_range;
		upper = highlight_range;
		local_levels = midtone_levels;
	}
	else {
		lower = highlight_range;
		upper = 1.0;
		local_levels = highlight_levels;
	}

	float range = upper - lower;
	float normalized = (luminance - lower) / range;
	float posterized = floor(normalized * local_levels + 0.5) / local_levels;

	posterized = lower + posterized * range;

	posterized = mix(
		luminance,
		posterized,
		posterize_strength
	);

	float ratio = posterized / max(luminance, 0.0001);

	color *= ratio;
}


float random(vec2 uv, float seed) {
	return fract(
		sin(dot(uv, vec2(12.9898, 78.233)) + seed * 37.719) * 43758.5453
	);
}


vec3 random_rgb(vec2 uv, float seed) {
	float r = random(uv, seed);
	float g = random(uv + 17.0, seed + 11.0);
	float b = random(uv + 43.0, seed + 29.0);
	return vec3(r, g, b);
}


vec3 animated_noise_rgb(vec2 position) {
	float time_step = floor(TIME * noise_speed);
	return random_rgb(position, time_step) * 2.0 - 1.0;
}


void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));

	vec2 pixel_count = tex_size / (pixel_size * 2.0);
	vec2 pixel_index = floor(UV * pixel_count);
	vec2 pixaleted_uv = pixel_index / pixel_count;

	vec4 color = texture(TEXTURE, pixaleted_uv);

	color.rgb = pow(color.rgb, vec3(gamma.x));

	float luminance = dot(
		color.rgb,
		vec3(0.299, 0.587, 0.114)
	);

	// Зерно шума — своя, отдельная от пикселизации сетка. Теперь noise_scale
	// реально на что-то влияет.
	vec2 noise_pixel_count = tex_size / noise_scale;
	vec2 noise_index = floor(UV * noise_pixel_count);

	// Чем темнее — тем сильнее шум (усиление сигнала на камере при высоком ISO).
	// pow() делает нарастание резче — середина тона почти чистая, в тенях резкий скачок.
	float shadow_mask = 1.0 - smoothstep(0.0, noise_darkness, luminance);
	shadow_mask = pow(shadow_mask, 1.5);

	vec3 noise_rgb = animated_noise_rgb(noise_index);
	float noise_luma = (noise_rgb.r + noise_rgb.g + noise_rgb.b) / 3.0;

	// Смешиваем монохромный (общий) и цветной (по каналам) шум.
	vec3 final_noise = mix(vec3(noise_luma), noise_rgb, noise_chroma);

	// Реальные сенсоры шумят неравномерно по каналам (зелёный чище,
	// т.к. в байеровском фильтре на него вдвое больше сэмплов). Чисто
	// косметическая деталь — можно убрать, если не понравится.
	final_noise *= vec3(1.15, 0.85, 1.2);

	posterize(color.rgb);
	color.rgb = pow(color.rgb, vec3(gamma.y));
	color.rgb += final_noise * noise_strength * shadow_mask;
	color.rgb = clamp(color.rgb, 0.0, 1.0);

	COLOR = color;
}