shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 body_direction = vec3(0.0, 0.2, -1.0);
uniform float body_distance = 2500.0;
uniform float quad_half_angle_deg = 25.0;
uniform float visibility = 1.0;

uniform vec4 sun_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float disc_radius_deg = 1.2;
uniform float disc_edge_deg = 0.15;
uniform float disc_intensity = 12.0;
uniform float limb_darkening = 0.45;

uniform float corona_intensity = 1.6;
uniform float corona_falloff_deg = 1.6;

uniform float rays_intensity = 0.8;
uniform float rays_length_deg = 16.0;
uniform float rays_sharpness = 4.0;
uniform float rays_count = 17.0;
uniform float rays_speed = 0.03;

uniform vec4 horizon_color : source_color = vec4(1.0, 0.42, 0.18, 1.0);
uniform float horizon_tint_height = 0.12;
uniform float horizon_softness = 0.004;

varying vec2 quad_pos;
varying vec3 view_up;
varying vec3 view_position;

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float angular_noise(float a, float freq, float seed) {
	float x = a * freq + seed;
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	float i0 = mod(i, freq);
	float i1 = mod(i + 1.0, freq);
	return mix(hash11(i0 + seed * 17.0), hash11(i1 + seed * 17.0), u);
}

void vertex() {
	vec3 dir_view = normalize((VIEW_MATRIX * vec4(normalize(body_direction), 0.0)).xyz);
	vec3 up_ref = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 right = normalize(cross(dir_view, up_ref));
	vec3 up = cross(right, dir_view);

	float half_size = body_distance * tan(radians(quad_half_angle_deg));
	quad_pos = VERTEX.xy * 2.0;
	vec3 view_pos = dir_view * body_distance + (right * quad_pos.x + up * quad_pos.y) * half_size;
	view_up = up_ref;
	view_position = view_pos;
	POSITION = PROJECTION_MATRIX * vec4(view_pos, 1.0);
}

void fragment() {
	float r = degrees(atan(length(quad_pos) * tan(radians(quad_half_angle_deg))));
	float angle = atan(quad_pos.y, quad_pos.x);

	float disc = smoothstep(disc_radius_deg + disc_edge_deg, disc_radius_deg - disc_edge_deg, r);
	float mu = sqrt(max(1.0 - pow(min(r / disc_radius_deg, 1.0), 2.0), 0.0));
	float limb = 1.0 - limb_darkening * (1.0 - mu);

	float outside = max(r - disc_radius_deg, 0.0);
	float corona = exp(-outside / corona_falloff_deg) * (1.0 - disc);

	float a01 = angle / TAU + 0.5;
	float t = TIME * rays_speed;
	float base_count = max(floor(rays_count), 1.0);
	float streaks = pow(angular_noise(a01 + t, base_count, 1.0), rays_sharpness)
		+ pow(angular_noise(a01 - t * 0.7, floor(base_count * 2.3), 2.0), rays_sharpness) * 0.6
		+ pow(angular_noise(a01 + t * 0.4, floor(base_count * 5.1), 3.0), rays_sharpness) * 0.3;
	float ray_len = rays_length_deg * (0.6 + 0.4 * angular_noise(a01, floor(base_count * 1.7), 4.0));
	float rays = streaks * exp(-outside / max(ray_len * 0.35, 0.001)) * smoothstep(disc_radius_deg * 0.6, disc_radius_deg * 1.4, r);

	float edge = smoothstep(1.0, 0.85, length(quad_pos));

	vec3 view_dir = normalize(view_position);
	float height = dot(view_dir, normalize(view_up));
	float above_horizon = smoothstep(-horizon_softness, horizon_softness, height);

	vec3 tint = mix(horizon_color.rgb, sun_color.rgb, smoothstep(0.0, horizon_tint_height, height));
	vec3 color = tint * (disc * limb * disc_intensity + corona * corona_intensity + rays * rays_intensity);
	ALBEDO = color * edge * above_horizon * visibility;
}
