shader_type spatial;
render_mode cull_disabled;

uniform float normal_strength : hint_range(0.0, 30.0) = 10.0;

uniform vec3 edge_color : source_color = vec3(0.1, 0.01, 0.01);
uniform vec3 center_color : source_color = vec3(0.6, 0.02, 0.02);

varying float seed;

uniform float dissolve_amount = 0.35;

uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;


void vertex()
{
    seed = INSTANCE_CUSTOM.z + seed_offset;
}

// Псевдогенератор рандомного числа
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

// Стиснути 2D точку до одного псевдо-рандомного числа
float noise(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Той же noise, але для генерації більш плавного шуму (для симуляції плям крові)
float value_noise(vec2 p)
{
    vec2 offset = vec2(
        hash(seed + 100.0),
        hash(seed + 200.0)
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

    for(int i = 0; i < 6; i++)
    {
        float fi = float(i);

        float angle = hash(fi) * 6.28318;
        float distance = mix(0.35, 0.4, hash(fi + 15.0));

        vec2 center = vec2(cos(angle), sin(angle)) * distance;

        float radius = mix(0.1, 0.25, hash(fi + 42.0 + seed));

        sdf = min(sdf, circle_sdf(uv, center, radius));
    }

	sdf += value_noise(uv * 7.0) * 0.15;

    return sdf;
}

float blood_height(vec2 uv)
{
    float sdf = blood_sdf(uv);

    float thickness = clamp(-sdf / 0.5, 0.0, 1.0);

    float detail = value_noise(uv * 20.0);

    detail = detail * 2.0 - 1.0;

    return thickness + detail * 0.08;
}

vec3 calculate_normal(vec2 uv)
{
    float e = 0.003;

    float left  = blood_height(uv - vec2(e,0));
    float right = blood_height(uv + vec2(e,0));

    float down  = blood_height(uv - vec2(0,e));
    float up    = blood_height(uv + vec2(0,e));

    return normalize(vec3(
        (left-right)*normal_strength,
        (down-up)*normal_strength,
        1.0
    ));

}

void fragment()
{
    vec2 uv = UV * 2.0 - 1.0;

    float sdf = blood_sdf(uv);
	vec3 normal = calculate_normal(uv);


	float shrink = (1.0 - COLOR.a) * dissolve_amount;
	float mask = sdf_to_mask(sdf + shrink);
	ALPHA = mask;

	
	float thickness = clamp(-sdf / 0.5, 0.0, 1.0);
	float detail = value_noise(uv * 12.0);
	detail = detail * 2.0 - 1.0;
	detail *= 0.2;

	float color_mask = clamp(thickness + detail, 0.0, 1.0);
	vec3 blood_color = mix(edge_color, center_color, color_mask);
	
	float rough_noise = value_noise(uv * 14.0);
	float rough = mix(0.4, 0.2, thickness);
	rough += (rough_noise - 0.5) * 0.06;
	rough = clamp(rough, 0.16, 0.36);

    ALBEDO = blood_color;
	ROUGHNESS = rough;
	SPECULAR = 0.10;
	NORMAL_MAP = normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALPHA = mask;
}