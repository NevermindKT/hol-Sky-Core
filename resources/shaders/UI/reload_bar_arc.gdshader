shader_type canvas_item;

uniform float arc_strength = 2.0;

void fragment() {
    float x = UV.x - 0.5;
    float bend = arc_strength * (x * x);
    vec2 uv = vec2(UV.x, UV.y + bend);

    if (uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0);
    } else {
        COLOR = texture(TEXTURE, uv);
    }
}