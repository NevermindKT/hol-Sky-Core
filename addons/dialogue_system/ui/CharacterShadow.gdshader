shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float softness : hint_range(0.0, 12.0) = 3.0;

void fragment() {
    vec2 step_uv = TEXTURE_PIXEL_SIZE * softness;
    float alpha = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 sample_uv = UV + vec2(float(x), float(y)) * step_uv;
            if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThanEqual(sample_uv, vec2(1.0)))) {
                alpha += texture(TEXTURE, sample_uv).a;
            }
        }
    }
    COLOR = vec4(shadow_color.rgb, shadow_color.a * alpha / 9.0);
}
