shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_amount : hint_range(0.0, 8.0) = 4.0;

void fragment() {
	vec2 texel_size = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 sum = vec4(0.0);

	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2(-1.0, -1.0)) * 0.0625;
	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2( 0.0, -1.0)) * 0.125;
	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2( 1.0, -1.0)) * 0.0625;

	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2(-1.0,  0.0)) * 0.125;
	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2( 0.0,  0.0)) * 0.25;
	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2( 1.0,  0.0)) * 0.125;

	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2(-1.0,  1.0)) * 0.0625;
	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2( 0.0,  1.0)) * 0.125;
	sum += texture(screen_texture, SCREEN_UV + texel_size * vec2( 1.0,  1.0)) * 0.0625;

	COLOR = sum;
}