shader_type spatial;

uniform sampler2D shoulder_texture_a : source_color, repeat_enable;
uniform sampler2D ground_texture_a : source_color, repeat_enable;
uniform sampler2D shoulder_texture_b : source_color, repeat_enable;
uniform sampler2D ground_texture_b : source_color, repeat_enable;

uniform float uv_scale : hint_range(0.01, 2.0) = 0.2;
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

void fragment()
{
	vec2 tiled_uv = UV * uv_scale;

	vec3 biome_a_color = mix(
		texture(shoulder_texture_a, tiled_uv).rgb,
		texture(ground_texture_a, tiled_uv).rgb,
		COLOR.r
	);
	vec3 biome_b_color = mix(
		texture(shoulder_texture_b, tiled_uv).rgb,
		texture(ground_texture_b, tiled_uv).rgb,
		COLOR.b
	);

	ALBEDO = mix(biome_a_color, biome_b_color, COLOR.g);
	ROUGHNESS = roughness_value;
}
