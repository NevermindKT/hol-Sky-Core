shader_type spatial;

render_mode blend_mix, cull_disabled, fog_disabled;

uniform vec4 ring_color : source_color = vec4(0.9, 0.95, 1.0, 0.5);

uniform float radius : hint_range(0.0, 1.0) = 0.35;
uniform float thickness : hint_range(0.001, 0.5) = 0.08;
uniform float softness : hint_range(0.001, 0.2) = 0.03;

uniform float emission_strength : hint_range(0.0, 1.0) = 0.1;

void fragment()
{
    vec2 p = UV - vec2(0.5);
    float d = length(p);

    float outer = 1.0 - smoothstep(radius, radius + softness, d);

    float inner = 1.0 - smoothstep(radius - thickness, radius - thickness + softness, d);

    float alpha = outer - inner;

    ALBEDO = ring_color.rgb;
    EMISSION = ring_color.rgb * emission_strength * alpha;
    ALPHA = alpha * ring_color.a * COLOR.a;
}