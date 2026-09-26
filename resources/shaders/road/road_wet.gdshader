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
uniform float road_distance_offset = 0.0;

uniform sampler2D transition_noise_texture : hint_default_black;
uniform vec2 transition_noise_uv_scale = vec2(0.015, 6.0);
uniform float transition_noise_strength : hint_range(0.0, 1.0) = 1.0;
uniform float transition_edge_softness : hint_range(0.05, 20.0) = 8.0;
uniform float transition_fade_amount : hint_range(0.0, 1.0) = 0.5;

uniform float noise_detail_scale : hint_range(1.0, 8.0) = 2.7;
uniform float noise_detail_mix : hint_range(0.0, 1.0) = 0.35;

uniform sampler2D macro_noise_texture : hint_default_black;
uniform vec2 macro_noise_uv_scale = vec2(0.004, 1.5);
uniform float macro_patch_strength : hint_range(0.0, 1.0) = 0.3;
uniform float macro_puddle_strength : hint_range(0.0, 1.0) = 0.15;

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

vec2 road_noise_uv(vec2 uv, vec2 scale)
{
	return vec2(fract(road_distance_offset * scale.x) + uv.x * scale.x, uv.y * scale.y);
}

float layered_noise(sampler2D tex, vec2 uv, vec2 scale)
{
	float base = texture(tex, road_noise_uv(uv, scale)).r;
	float detail = texture(tex, road_noise_uv(uv, scale * noise_detail_scale) + vec2(0.37, 0.61)).r;
	float blended = mix(base, detail, noise_detail_mix);
	float contrast = inversesqrt(pow(1.0 - noise_detail_mix, 2.0) + pow(noise_detail_mix, 2.0));
	return (blended - 0.5) * contrast + 0.5;
}

void fragment()
{
	float pos_along_road = use_uv_y_for_gradient ? UV.y : UV.x;

	float progress = 0.0;
	if (fade_end > fade_start) {
		float zone_length = fade_end - fade_start;
		float softness = min(transition_edge_softness, zone_length * 0.5);
		float front_noise = texture(transition_noise_texture, road_noise_uv(UV, transition_noise_uv_scale)).r;
		float front = mix(0.5, front_noise, transition_noise_strength);
		float front_pos = fade_start + softness + front * (zone_length - 2.0 * softness);
		progress = smoothstep(front_pos - softness, front_pos + softness, pos_along_road);
	}
	float state = mix(previous_state, target_state, progress);

	float wet_factor = smoothstep(0.0, 1.0, state);
	float coverage_factor = smoothstep(1.0, 2.0, state);
	float puddle_factor = smoothstep(1.3, 2.0, state);

	float macro = texture(macro_noise_texture, road_noise_uv(UV, macro_noise_uv_scale)).r - 0.5;
	float local_patch_coverage = patch_coverage - macro * macro_patch_strength;
	float local_puddle_coverage = puddle_coverage - macro * macro_puddle_strength;

	float patch_noise = layered_noise(wet_noise_texture, UV, wet_noise_uv_scale);
	float patch_threshold = mix(1.0 + patch_edge_softness, local_patch_coverage, wet_factor);
	patch_threshold = mix(patch_threshold, -patch_edge_softness, coverage_factor);
	float grown_wetness = smoothstep(patch_threshold - patch_edge_softness, patch_threshold + patch_edge_softness, patch_noise);
	float patch_mask = smoothstep(local_patch_coverage - patch_edge_softness, local_patch_coverage + patch_edge_softness, patch_noise);
	float faded_wetness = wet_factor * mix(patch_mask, 1.0, coverage_factor);
	float wetness = mix(grown_wetness, faded_wetness, transition_fade_amount);

	vec3 tint = mix(dry_albedo_tint, wet_albedo_tint, wetness);
	float roughness = mix(dry_roughness, wet_roughness, wetness);
	float specular = mix(dry_specular, wet_specular, wetness);
	float clearcoat = 0.0;
	float clearcoat_roughness = 1.0;

	float puddle_noise = layered_noise(puddle_noise_texture, UV, puddle_noise_uv_scale);
	float puddle_shape = pow(clamp(1.0 - puddle_noise, 0.0, 1.0), puddle_sharpness);
	float puddle_threshold = mix(1.0 + puddle_edge_softness, local_puddle_coverage, puddle_factor);
	float grown_puddle = smoothstep(puddle_threshold - puddle_edge_softness, puddle_threshold + puddle_edge_softness, puddle_shape);
	float faded_puddle = puddle_factor * smoothstep(local_puddle_coverage - puddle_edge_softness, local_puddle_coverage + puddle_edge_softness, puddle_shape);
	float puddle_mask = mix(grown_puddle, faded_puddle, transition_fade_amount);

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
