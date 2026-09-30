shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 body_direction = vec3(0.0, 0.4, 1.0);
uniform float body_distance = 2500.0;
uniform float quad_half_angle_deg = 6.0;
uniform float visibility = 1.0;

uniform sampler2D moon_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction = vec3(0.0, -0.2, -1.0);
uniform float texture_longitude_offset_deg = 0.0;

uniform float disc_radius_deg = 2.0;
uniform float moon_intensity = 1.6;
uniform vec4 moon_tint : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float earthshine = 0.015;
uniform float terminator_softness = 0.08;
uniform float texture_contrast = 0.55;
uniform float texture_brightness = 1.15;

uniform float halo_intensity = 0.08;
uniform float halo_falloff_deg = 1.2;

uniform vec4 horizon_tint : source_color = vec4(1.0, 0.62, 0.38, 1.0);
uniform float horizon_tint_height = 0.12;
uniform float horizon_softness = 0.004;

varying vec2 quad_pos;
varying vec3 view_up;
varying vec3 view_position;
varying vec3 sun_local;

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

	vec3 sun_view = normalize((VIEW_MATRIX * vec4(normalize(sun_direction), 0.0)).xyz);
	sun_local = vec3(dot(sun_view, right), dot(sun_view, up), dot(sun_view, -dir_view));

	POSITION = PROJECTION_MATRIX * vec4(view_pos, 1.0);
}

void fragment() {
	float r_deg = degrees(atan(length(quad_pos) * tan(radians(quad_half_angle_deg))));
	vec2 p = quad_pos * (r_deg / max(length(quad_pos), 1e-5)) / disc_radius_deg;
	float r = length(p);

	float aa = fwidth(r) * 1.5;
	float disc = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);

	vec3 n = vec3(p, sqrt(max(1.0 - r * r, 0.0)));
	float lon = atan(n.x, n.z) + radians(texture_longitude_offset_deg);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	vec2 uv = vec2(0.5 + lon / TAU, 0.5 - lat / PI);
	vec3 albedo = texture(moon_texture, uv).rgb;
	albedo = max(mix(vec3(0.62), albedo, texture_contrast), 0.0) * texture_brightness;

	float ndl = dot(n, normalize(sun_local));
	float lit = smoothstep(-terminator_softness, terminator_softness, ndl) * mix(0.35, 1.0, clamp(ndl, 0.0, 1.0));
	vec3 surface = albedo * moon_tint.rgb * (lit * moon_intensity + earthshine);

	float outside = max(r_deg - disc_radius_deg, 0.0);
	float halo = exp(-outside / halo_falloff_deg) * (1.0 - disc) * smoothstep(1.0, 0.8, length(quad_pos));
	float phase = clamp(dot(normalize(sun_local), vec3(0.0, 0.0, 1.0)) * 0.5 + 0.5, 0.0, 1.0);

	vec3 view_dir = normalize(view_position);
	float height = dot(view_dir, normalize(view_up));
	float above_horizon = smoothstep(-horizon_softness, horizon_softness, height);
	vec3 tint = mix(horizon_tint.rgb, vec3(1.0), smoothstep(0.0, horizon_tint_height, height));
	float extinction = mix(0.45, 1.0, smoothstep(0.0, horizon_tint_height, height));

	vec3 color = surface * disc + moon_tint.rgb * halo * halo_intensity * phase;
	ALBEDO = color * tint * extinction * above_horizon * visibility;
}
