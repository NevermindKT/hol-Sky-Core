uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale = 1.0;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.4;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.1;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

uniform float wind_strength = 0.0;
uniform float wind_speed = 1.0;
uniform float wind_height = 1.0;
uniform float wind_intensity = 1.0;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.3);

void vertex()
{
	UV = UV * uv1_scale.xy + uv1_offset.xy;

	float h = clamp(VERTEX.y / max(wind_height, 0.001), 0.0, 1.0);
	float bend = h * h * wind_strength * wind_intensity;
	if (bend > 0.0)
	{
		float phase = INSTANCE_CUSTOM.x * 6.2831853;
		float t = TIME * wind_speed;
		float gust = sin(t + phase) * 0.65 + sin(t * 2.37 + phase * 1.7) * 0.35;
		vec3 dir = normalize(transpose(mat3(MODEL_MATRIX)) * wind_direction);
		float flutter = sin(t * 6.0 + dot(VERTEX, vec3(3.1, 2.3, 4.7)) + phase * 3.0);
		VERTEX += dir * bend * (0.4 + 0.6 * gust);
		VERTEX += NORMAL * flutter * bend * 0.08;
	}
}

void fragment()
{
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = albedo.rgb;
#ifdef CUTOUT
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
#endif
	ROUGHNESS = dot(texture(roughness_texture, UV), roughness_channel) * roughness;
	AO = dot(texture(ao_texture, UV), ao_channel);
	AO_LIGHT_AFFECT = ao_light_affect;
	SPECULAR = specular_amount;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
