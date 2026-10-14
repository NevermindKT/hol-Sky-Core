shader_type spatial;
render_mode cull_back;

uniform int shell_count = 14;
uniform float shell_height = 0.32;
uniform float fade_start = 38.0;
uniform float fade_end = 58.0;
uniform float road_start = 10.0;
uniform float road_fade = 3.5;
uniform float edge_noise_scale = 0.35;
uniform float edge_noise_amount = 1.5;
uniform float grass_growth_distance = 4.0;
uniform float forest_thinning : hint_range(0.0, 1.0) = 0.6;

uniform float blade_density = 11.0;
uniform float blade_width : hint_range(0.1, 1.0) = 0.8;
uniform float min_blade_height : hint_range(0.0, 1.0) = 0.35;
uniform float patch_scale = 0.08;
uniform float patch_strength : hint_range(0.0, 1.0) = 0.55;

uniform vec3 root_color : source_color = vec3(0.12, 0.11, 0.05);
uniform vec3 tip_color : source_color = vec3(0.36, 0.40, 0.15);
uniform vec3 dry_color : source_color = vec3(0.44, 0.39, 0.19);
uniform float dry_amount : hint_range(0.0, 1.0) = 0.35;

uniform float wind_strength = 0.12;
uniform float wind_speed = 1.6;
uniform float wind_wave_scale = 0.12;
uniform vec2 wind_direction = vec2(1.0, 0.3);

varying float layer;
varying float coverage;
varying vec2 ground_uv;
varying float road_distance;

float hash(vec2 p)
{
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex()
{
	layer = (float(INSTANCE_ID) + 1.0) / float(shell_count);
	ground_uv = UV;

	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float distance_fade = 1.0 - smoothstep(fade_start, fade_end, distance(world_position.xz, CAMERA_POSITION_WORLD.xz));
	road_distance = CUSTOM0.z;
	float forest_mask = 1.0 - smoothstep(0.3, 0.9, CUSTOM0.y) * forest_thinning;
	coverage = distance_fade * forest_mask;

	vec2 dir = normalize(wind_direction);
	float wave = sin(dot(UV, dir) * wind_wave_scale - TIME * wind_speed) * 0.5 + 0.5;
	float gust = sin(dot(UV, vec2(-dir.y, dir.x)) * wind_wave_scale * 0.7 + TIME * wind_speed * 0.37) * 0.25 + 0.75;
	float sway = wind_strength * layer * layer * (0.35 + 0.65 * wave) * gust;

	VERTEX += NORMAL * shell_height * layer;
	VERTEX.xz += dir * sway;
}

void fragment()
{
	if (coverage <= 0.01)
	{
		discard;
	}

	float edge = (value_noise(ground_uv * edge_noise_scale) * 0.65 + value_noise(ground_uv * edge_noise_scale * 3.1) * 0.35 - 0.5) * 2.0 * edge_noise_amount;
	float grass_start = road_start + road_fade * 0.6;
	float road_mask = smoothstep(grass_start, grass_start + grass_growth_distance, road_distance + edge);
	if (road_mask <= 0.01)
	{
		discard;
	}

	vec2 p = ground_uv * blade_density;
	vec2 cell = floor(p);
	float rnd = hash(cell);
	vec2 offset = vec2(hash(cell + 17.3), hash(cell + 41.7)) - 0.5;
	vec2 local = fract(p) - 0.5 - offset * 0.35;

	float patches = value_noise(ground_uv * patch_scale);
	float height = mix(min_blade_height, 1.0, rnd) * mix(1.0, patches, patch_strength) * coverage * road_mask;
	if (layer > height)
	{
		discard;
	}

	float t = layer / max(height, 0.001);
	if (length(local) > blade_width * 0.5 * (1.0 - t))
	{
		discard;
	}

	float dryness = smoothstep(0.55, 0.85, value_noise(ground_uv * patch_scale * 1.7 + 13.1)) * dry_amount;
	vec3 tip = mix(tip_color, dry_color, dryness) * (0.85 + 0.3 * rnd);
	ALBEDO = mix(root_color, tip, t * t);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
