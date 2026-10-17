shader_type sky;

//========================================================================== SKY

uniform vec4 sky_top_color : source_color = vec4(0.385, 0.454, 0.55, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float sky_curve : hint_range(0.001, 1.0) = 0.15;
uniform float sky_energy = 1.0;

uniform vec4 ground_bottom_color : source_color = vec4(0.2, 0.169, 0.133, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float ground_curve : hint_range(0.001, 1.0) = 0.02;
uniform float ground_energy = 1.0;

uniform float exposure = 1.0;

uniform vec3 sun_direction = vec3(0.0, 0.2, -1.0);
uniform vec4 sun_glow_color : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform float sun_glow_energy = 0.0;
uniform float sun_glow_inner_power = 400.0;
uniform float sun_glow_inner_strength = 1.5;
uniform float sun_glow_outer_power = 12.0;
uniform float sun_glow_outer_strength = 0.4;
uniform float sun_horizon_glow_strength = 0.8;
uniform float sun_horizon_glow_height = 6.0;
uniform float sun_horizon_glow_spread = 3.0;

uniform vec3 moon_direction = vec3(0.0, 0.4, 1.0);
uniform vec4 moon_glow_color : source_color = vec4(0.6, 0.7, 0.85, 1.0);
uniform float moon_glow_energy = 0.0;
uniform float moon_glow_power = 250.0;

uniform bool use_debanding = true;

//======================================================================= CLOUDS

uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;

uniform vec4 cloud_light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.6, 0.65, 0.75, 1.0);

uniform float cloud_yaw = 0.0;

uniform float cloud_scale : hint_range(0.05, 3.0) = 0.4;
uniform vec2 cloud_wind = vec2(0.01, 0.004);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_softness : hint_range(0.01, 1.0) = 0.25;
uniform float cloud_horizon_fade : hint_range(0.01, 1.0) = 0.2;


vec3 interleaved_gradient_noise(vec2 pos) {
	const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
	float res = fract(magic.z * fract(dot(pos, magic.xy))) * 2.0 - 1.0;
	return vec3(res, -res, res) / 255.0;
}

void sky() {
	float v_angle = acos(clamp(EYEDIR.y, -1.0, 1.0));
	float c = 1.0 - v_angle / (PI * 0.5);
	vec3 sky = mix(sky_horizon_color.rgb, sky_top_color.rgb, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	sky *= sky_energy;

	c = (v_angle - PI * 0.5) / (PI * 0.5);
	vec3 ground = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, clamp(1.0 - pow(1.0 - c, 1.0 / ground_curve), 0.0, 1.0));
	ground *= ground_energy;

	vec3 color = mix(ground, sky, step(0.0, EYEDIR.y));

	if (EYEDIR.y > 0.0) {
		float s = sin(cloud_yaw);
		float cs = cos(cloud_yaw);
		vec2 dir_xz = vec2(EYEDIR.x * cs - EYEDIR.z * s, EYEDIR.x * s + EYEDIR.z * cs);
		vec2 cloud_uv = dir_xz / (EYEDIR.y + 0.1) * cloud_scale;

		float n1 = texture(cloud_noise, cloud_uv + cloud_wind * TIME).r;
		float n2 = texture(cloud_noise, cloud_uv * 2.3 - cloud_wind * TIME * 0.6).r;
		float n = n1 * 0.65 + n2 * 0.35;

		float density = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, n);
		density *= smoothstep(0.0, cloud_horizon_fade, EYEDIR.y);

		vec3 cloud_col = mix(cloud_shadow_color.rgb, cloud_light_color.rgb, smoothstep(0.4, 0.9, n));
		cloud_col *= sky_energy;

		color = mix(color, cloud_col, density);
	}

	if (sun_glow_energy > 0.0) {
		vec3 sun_dir = normalize(sun_direction);
		float sun_cos = max(dot(EYEDIR, sun_dir), 0.0);
		float inner = pow(sun_cos, sun_glow_inner_power) * sun_glow_inner_strength;
		float outer = pow(sun_cos, sun_glow_outer_power) * sun_glow_outer_strength;

		vec2 eye_flat = EYEDIR.xz;
		vec2 sun_flat = sun_dir.xz;
		float flat_cos = dot(eye_flat, sun_flat) / max(length(eye_flat) * length(sun_flat), 1e-4);
		float around = pow(clamp(flat_cos * 0.5 + 0.5, 0.0, 1.0), sun_horizon_glow_spread);
		float band = exp(-max(EYEDIR.y, 0.0) * sun_horizon_glow_height) * smoothstep(-0.08, 0.0, EYEDIR.y);
		float horizon = around * band * sun_horizon_glow_strength;

		color += sun_glow_color.rgb * sun_glow_energy * (inner + outer + horizon);
	}

	if (moon_glow_energy > 0.0) {
		float moon_cos = max(dot(EYEDIR, normalize(moon_direction)), 0.0);
		color += moon_glow_color.rgb * moon_glow_energy * pow(moon_cos, moon_glow_power) * step(0.0, EYEDIR.y + 0.02);
	}

	color *= exposure;

	if (use_debanding && !AT_CUBEMAP_PASS) {
		color += interleaved_gradient_noise(FRAGCOORD.xy);
	}

	COLOR = color;
}
