shader_type canvas_item;

uniform float pixel_size : hint_range(0.0, 20.0, 1.0);
uniform float levels : hint_range(0.0, 100.0, 1.0);
uniform vec2 gamma;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));

	vec2 pixel_count = tex_size / (pixel_size * 2.0);
	vec2 pixaleted_uv = floor(UV * pixel_count) / pixel_count;

	vec4 color = texture(TEXTURE, pixaleted_uv);

	color.rgb = pow(color.rgb, vec3(gamma.x));

	float grayscale = max(color.r, max(color.g, color.b));
	float lower = floor(grayscale * levels) / levels;
	float higher = ceil(grayscale * levels) / levels;

	float lower_diff = abs(lower - grayscale);
	float higher_diff = abs(higher - grayscale);

	float level = lower_diff < higher_diff ? lower : higher;
	float adjusment = level / grayscale;

	color.rgb *= adjusment;
	color.rgb = pow(color.rgb, vec3(gamma.y));

	COLOR = color;
}