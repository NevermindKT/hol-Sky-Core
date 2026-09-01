shader_type spatial;

uniform sampler2D albedo_texture : source_color;
uniform vec2 uv_scale = vec2(0.1, 8.0);

uniform float dry_roughness : hint_range(0.0, 1.0) = 1.0;
uniform float dry_specular : hint_range(0.0, 1.0) = 0.5;
uniform vec3 dry_albedo_tint : source_color = vec3(1.0, 1.0, 1.0);

uniform float wet_roughness : hint_range(0.0, 1.0) = 0.4;
uniform float wet_specular : hint_range(0.0, 1.0) = 0.75;
uniform vec3 wet_albedo_tint : source_color = vec3(0.93, 0.93, 0.95);

uniform float previous_state : hint_range(0.0, 2.0) = 0.0;
uniform float target_state : hint_range(0.0, 2.0) = 0.0;
uniform float fade_start = 0.0;
uniform float fade_end = 1.0;
uniform bool use_uv_y_for_gradient = false;

uniform sampler2D wet_noise_texture : hint_default_white;
uniform vec2 wet_noise_uv_scale = vec2(0.15, 12.0);
uniform float patch_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float patch_edge_softness : hint_range(0.01, 0.5) = 0.2;

uniform sampler2D puddle_noise_texture : hint_default_black;
uniform vec2 puddle_noise_uv_scale = vec2(0.05, 4.0);
uniform float puddle_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float puddle_edge_softness : hint_range(0.01, 0.5) = 0.12;
uniform float puddle_sharpness : hint_range(1.0, 8.0) = 3.0;

uniform float puddle_roughness : hint_range(0.0, 1.0) = 0.02;
uniform float puddle_specular : hint_range(0.0, 1.0) = 1.0;
uniform vec3 puddle_albedo_tint : source_color = vec3(0.75, 0.75, 0.8);
uniform float puddle_clearcoat : hint_range(0.0, 1.0) = 1.0;
uniform float puddle_clearcoat_roughness : hint_range(0.0, 1.0) = 0.01;


void fragment()
{
	float pos_along_road = use_uv_y_for_gradient ? UV.y : UV.x;

	float progress = 0.0;
	if (fade_end > fade_start) {
		progress = smoothstep(fade_start, fade_end, pos_along_road);
	}
	float state = mix(previous_state, target_state, progress);

	float wet_factor = smoothstep(0.0, 1.0, state);
	float coverage_factor = smoothstep(1.0, 2.0, state);
	float puddle_factor = smoothstep(1.3, 2.0, state);

	float patch_noise = texture(wet_noise_texture, UV * wet_noise_uv_scale).r;
	float patch_mask = smoothstep(patch_coverage - patch_edge_softness, patch_coverage + patch_edge_softness, patch_noise);
	patch_mask = mix(patch_mask, 1.0, coverage_factor);

	float wetness = wet_factor * patch_mask;

	vec3 tint = mix(dry_albedo_tint, wet_albedo_tint, wetness);
	float roughness = mix(dry_roughness, wet_roughness, wetness);
	float specular = mix(dry_specular, wet_specular, wetness);
	float clearcoat = 0.0;
	float clearcoat_roughness = 1.0;

	float puddle_noise = texture(puddle_noise_texture, UV * puddle_noise_uv_scale).r;
	float puddle_shape = pow(clamp(1.0 - puddle_noise, 0.0, 1.0), puddle_sharpness);
	float puddle_mask = smoothstep(puddle_coverage - puddle_edge_softness, puddle_coverage + puddle_edge_softness, puddle_shape);
	puddle_mask *= puddle_factor;

	tint = mix(tint, puddle_albedo_tint, puddle_mask);
	roughness = mix(roughness, puddle_roughness, puddle_mask);
	specular = mix(specular, puddle_specular, puddle_mask);
	clearcoat = mix(clearcoat, puddle_clearcoat, puddle_mask);
	clearcoat_roughness = mix(clearcoat_roughness, puddle_clearcoat_roughness, puddle_mask);

	ALBEDO = texture(albedo_texture, UV * uv_scale).rgb * tint;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
}
