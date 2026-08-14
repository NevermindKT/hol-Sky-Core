shader_type spatial;

uniform sampler2D shoulder_texture : source_color, repeat_enable;
uniform sampler2D ground_texture : source_color, repeat_enable;

uniform float uv_scale : hint_range(0.01, 2.0) = 0.2;
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

void fragment()
{
	vec2 tiled_uv = UV * uv_scale;

	vec3 shoulder_color = texture(shoulder_texture, tiled_uv).rgb;
	vec3 ground_color = texture(ground_texture, tiled_uv).rgb;

	// COLOR.r запечений по вершинах у Ground_generator._build_side() за
	// shoulder_ground_blend_curve: 0.0 = чисте узбіччя (біля дороги),
	// 1.0 = чиста земля (дальній край перед туманом).
	ALBEDO = mix(shoulder_color, ground_color, COLOR.r);
	ROUGHNESS = roughness_value;
}
