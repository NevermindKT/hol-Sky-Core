shader_type spatial;

uniform sampler2D shoulder_texture : source_color, repeat_enable;
uniform sampler2D meadow_texture : source_color, repeat_enable;
uniform sampler2D forest_texture : source_color, repeat_enable;
uniform vec3 forest_tint : source_color = vec3(0.75);

uniform float uv_scale : hint_range(0.01, 2.0) = 0.2;
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

varying vec4 ground_weights;

void vertex()
{
	ground_weights = CUSTOM0;
}

void fragment()
{
	vec2 tiled_uv = UV * uv_scale;

	vec3 meadow = texture(meadow_texture, tiled_uv).rgb;
	vec3 forest = texture(forest_texture, tiled_uv * 0.9 + vec2(0.37, 0.61)).rgb * forest_tint;
	vec3 shoulder = texture(shoulder_texture, tiled_uv).rgb;

	vec3 ground = mix(meadow, forest, smoothstep(0.1, 0.7, ground_weights.y));
	ALBEDO = mix(ground, shoulder, clamp(ground_weights.x, 0.0, 1.0));
	ROUGHNESS = roughness_value;
}
