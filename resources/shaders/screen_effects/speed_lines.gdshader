shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float line_count : hint_range(8.0, 300.0) = 110.0;
uniform float line_thickness : hint_range(0.0, 1.0) = 0.45;
uniform float line_density : hint_range(0.0, 1.0) = 0.45;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.6;
uniform float reach_variation : hint_range(0.0, 1.0) = 0.35;
uniform float taper_softness : hint_range(0.01, 1.0) = 0.25;
uniform float flicker_speed : hint_range(0.0, 60.0) = 14.0;
uniform float edge_darkening : hint_range(0.0, 1.0) = 0.15;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453123);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = screen_size.x / screen_size.y;

	vec2 centered = UV - 0.5;
	vec2 p = centered * vec2(aspect, 1.0);
	float r_px = max(length(p), 0.0001);
	float r_edge = length(centered * 2.0);

	float angle = atan(p.y, p.x) / TAU + 0.5;
	float cell_coord = angle * line_count;
	float cell = floor(cell_coord);
	float f = fract(cell_coord);

	float time_step = floor(TIME * flicker_speed + hash(cell) * 7.0);
	float seed = cell * 13.37 + time_step * 1.618;

	float alive = step(1.0 - line_density, hash(seed));
	float start = inner_radius + hash(seed + 5.1) * reach_variation;
	float reach = smoothstep(start, start + taper_softness, r_edge);

	float width = line_thickness * mix(0.35, 1.0, hash(cell + 91.7)) * reach;
	float offset = (hash(seed + 23.9) - 0.5) * (1.0 - width) * 0.8;
	float fw = line_count * SCREEN_PIXEL_SIZE.y / (TAU * r_px);
	float dist = abs(f - 0.5 - offset);
	float line = 1.0 - smoothstep(width * 0.5 - fw, width * 0.5 + fw, dist);

	float line_alpha = line * reach * alive * line_color.a;
	float darken = smoothstep(inner_radius, 1.4, r_edge) * edge_darkening;

	vec3 color = line_color.rgb;
	float alpha = max(line_alpha, darken * (1.0 - line_alpha));
	color = mix(vec3(0.0), color, line_alpha / max(alpha, 0.0001));

	COLOR = vec4(color, alpha * intensity);
}
