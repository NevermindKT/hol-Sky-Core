shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 warm_light : source_color = vec4(1.0, 0.78, 0.42, 0.35);
uniform vec4 cool_light : source_color = vec4(0.60, 0.78, 1.0, 0.28);
uniform float radius : hint_range(1.0, 48.0) = 18.0;

void fragment() {
    float halo = 0.0;
    for (int ring = 1; ring <= 3; ring++) {
        float distance = float(ring) / 3.0;
        float weight = exp(-distance * distance * 2.5);
        for (int direction = 0; direction < 16; direction++) {
            float angle = float(direction) * 6.2831853 / 16.0;
            vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * radius * distance;
            vec2 sample_uv = UV + offset;
            if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThanEqual(sample_uv, vec2(1.0)))) {
                halo = max(halo, texture(TEXTURE, sample_uv).a * weight);
            }
        }
    }
    // Only the outside of the silhouette glows; the portrait remains untouched.
    halo *= 1.0 - texture(TEXTURE, UV).a;
    vec4 light = mix(warm_light, cool_light, smoothstep(0.25, 0.75, UV.x));
    float upper_light = mix(1.0, 0.35, smoothstep(0.5, 1.0, UV.y));
    COLOR = vec4(light.rgb, halo * light.a * upper_light);
}
