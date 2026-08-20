shader_type canvas_item;

uniform vec3 edge_color : source_color = vec3(0.1, 0.01, 0.01);
uniform vec3 center_color : source_color = vec3(0.6, 0.02, 0.02);
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;

float hash(float n)
{
	return fract(sin(n) * 43758.5453123);
}

float circle_sdf(vec2 uv, vec2 center, float radius)
{
	return length(uv - center) - radius;
}

float sdf_to_mask(float sdf)
{
	return 1.0 - smoothstep(-0.02, 0.02, sdf);
}

float noise(vec2 p)
{
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p)
{
	vec2 offset = vec2(
		hash(seed_offset + 100.0),
		hash(seed_offset + 200.0)
	) * 100.0;

	p += offset;

	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = noise(i);
	float b = noise(i + vec2(1.0, 0.0));
	float c = noise(i + vec2(0.0, 1.0));
	float d = noise(i + vec2(1.0, 1.0));

	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}

float blood_sdf(vec2 uv)
{
	float sdf = circle_sdf(uv, vec2(0.0), 0.45);

	for (int i = 0; i < 6; i++)
	{
		float fi = float(i);

		float angle = hash(fi) * 6.28318;
		float distance = mix(0.35, 0.4, hash(fi + 15.0));

		vec2 center = vec2(cos(angle), sin(angle)) * distance;

		float radius = mix(0.1, 0.25, hash(fi + 42.0 + seed_offset));

		sdf = min(sdf, circle_sdf(uv, center, radius));
	}

	sdf += value_noise(uv * 7.0) * 0.15;

	return sdf;
}

void fragment()
{
	vec2 uv = UV * 2.0 - 1.0;

	float sdf = blood_sdf(uv);
	float mask = sdf_to_mask(sdf);

	float thickness = clamp(-sdf / 0.5, 0.0, 1.0);
	float detail = value_noise(uv * 12.0);
	detail = detail * 2.0 - 1.0;
	detail *= 0.2;

	float color_mask = clamp(thickness + detail, 0.0, 1.0);
	vec3 blood_color = mix(edge_color, center_color, color_mask);

	COLOR.rgb = blood_color;
	COLOR.a = mask;
}
