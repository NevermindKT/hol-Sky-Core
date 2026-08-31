shader_type spatial;

render_mode blend_mix, cull_disabled, fog_disabled, diffuse_lambert;

uniform vec4 rain_color : source_color = vec4(0.85, 0.9, 1.0, 0.35);
uniform float emission_strength : hint_range(0.0, 1.0) = 0.1;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.95;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.35;


void fragment()
{
    float x = 1.0 - abs(UV.x - 0.5) * 2.0;
    x = pow(x, 4.0);

    float y = sin(UV.y * PI);

    float alpha = x * y;

    ALBEDO = rain_color.rgb;

    EMISSION = rain_color.rgb * emission_strength * alpha;
    SPECULAR = specular_amount;
    ROUGHNESS = roughness_amount;
    METALLIC = 0.0;
    ALPHA = alpha * rain_color.a;
}
