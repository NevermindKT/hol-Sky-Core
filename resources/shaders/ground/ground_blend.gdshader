shader_type spatial;

uniform sampler2D shoulder_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 forest_tint : source_color = vec3(0.75);

uniform sampler2D shoulder_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 4.0) = 1.0;

uniform sampler2D shoulder_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D meadow_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.2;
uniform float macro_scale : hint_range(0.001, 0.5) = 0.03;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.35;

uniform float uv_scale : hint_range(0.01, 2.0) = 0.2;
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

varying vec4 ground_weights;

void vertex()
{
	ground_weights = CUSTOM0;
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = cross(NORMAL, TANGENT);
}

void fragment()
{
	vec2 tiled_uv = UV * uv_scale;
	vec2 forest_uv = tiled_uv * 0.9 + vec2(0.37, 0.61);

	float forest_weight = smoothstep(0.1, 0.7, ground_weights.y);
	float shoulder_weight = clamp(ground_weights.x, 0.0, 1.0);

	vec3 meadow = texture(meadow_texture, tiled_uv).rgb;
	vec3 forest = texture(forest_texture, forest_uv).rgb * forest_tint;
	vec3 shoulder = texture(shoulder_texture, tiled_uv).rgb;
	vec3 macro = texture(meadow_texture, UV * macro_scale + vec2(0.13, 0.71), 4.0).rgb;
	float macro_tone = dot(macro, vec3(0.333)) / max(dot(textureLod(meadow_texture, vec2(0.5), 20.0).rgb, vec3(0.333)), 0.01);
	ALBEDO = mix(mix(meadow, forest, forest_weight), shoulder, shoulder_weight) * mix(1.0, macro_tone, macro_strength);

	vec3 meadow_n = texture(meadow_normal, tiled_uv).rgb;
	vec3 forest_n = texture(forest_normal, forest_uv).rgb;
	vec3 shoulder_n = texture(shoulder_normal, tiled_uv).rgb;
	NORMAL_MAP = mix(mix(meadow_n, forest_n, forest_weight), shoulder_n, shoulder_weight);
	NORMAL_MAP_DEPTH = normal_strength;

	vec3 meadow_m = texture(meadow_arm, tiled_uv).rgb;
	vec3 forest_m = texture(forest_arm, forest_uv).rgb;
	vec3 shoulder_m = texture(shoulder_arm, tiled_uv).rgb;
	vec3 arm = mix(mix(meadow_m, forest_m, forest_weight), shoulder_m, shoulder_weight);
	AO = arm.r;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = arm.g * roughness_value;
	SPECULAR = specular_amount;
}
