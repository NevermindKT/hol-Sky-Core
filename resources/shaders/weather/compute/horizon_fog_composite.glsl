#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D depth_texture;
layout(set = 0, binding = 2) uniform sampler2D mip_chain;

layout(push_constant, std430) uniform Params {
	mat4 inv_projection;
	vec4 haze_tint;
	vec4 screen_and_fog;
	vec4 blur_and_opacity;
	vec4 debug_flags;
} params;

vec4 cubic_weights(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec4 sample_bicubic(vec2 uv, float lod) {
	vec2 texture_size = vec2(textureSize(mip_chain, int(lod)));
	vec2 inv_size = 1.0 / texture_size;

	vec2 coord = uv * texture_size - 0.5;
	vec2 fraction = fract(coord);
	coord -= fraction;

	vec4 x_cubic = cubic_weights(fraction.x);
	vec4 y_cubic = cubic_weights(fraction.y);

	vec4 centers = coord.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 sums = vec4(x_cubic.xz + x_cubic.yw, y_cubic.xz + y_cubic.yw);
	vec4 offsets = (centers + vec4(x_cubic.yw, y_cubic.yw) / sums) * inv_size.xxyy;

	vec4 sample0 = textureLod(mip_chain, offsets.xz, lod);
	vec4 sample1 = textureLod(mip_chain, offsets.yz, lod);
	vec4 sample2 = textureLod(mip_chain, offsets.xw, lod);
	vec4 sample3 = textureLod(mip_chain, offsets.yw, lod);

	float blend_x = sums.x / (sums.x + sums.y);
	float blend_y = sums.z / (sums.z + sums.w);

	return mix(mix(sample3, sample2, blend_x), mix(sample1, sample0, blend_x), blend_y);
}

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 screen_size = ivec2(params.screen_and_fog.xy);
	if (uv.x >= screen_size.x || uv.y >= screen_size.y) {
		return;
	}

	vec2 screen_uv = (vec2(uv) + 0.5) / vec2(screen_size);

	float fog_start = params.screen_and_fog.z;
	float fog_end = params.screen_and_fog.w;
	float blur_amount = params.blur_and_opacity.x;
	float tint_strength = params.blur_and_opacity.y;
	float opacity = params.blur_and_opacity.z;
	float mip_count = params.blur_and_opacity.w;

	float depth = texelFetch(depth_texture, uv, 0).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view_pos = params.inv_projection * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	float linear_depth = -view_pos.z;

	float fog_t = smoothstep(fog_start, fog_end, linear_depth);

	vec3 original = imageLoad(color_image, uv).rgb;

	if (params.debug_flags.x > 0.5) {
		vec3 debug_color = vec3(clamp(linear_depth / fog_end, 0.0, 1.0));
		imageStore(color_image, uv, vec4(debug_color, 1.0));
		return;
	}

	if (fog_t <= 0.0) {
		return;
	}

	float level = clamp(fog_t * blur_amount, 0.0, mip_count);

	vec4 far_layer;
	if (level <= 1.0) {
		far_layer = sample_bicubic(screen_uv, 0.0);
	} else {
		float low = floor(level - 1.0);
		float high = min(low + 1.0, mip_count - 1.0);
		float blend = (level - 1.0) - low;
		far_layer = mix(sample_bicubic(screen_uv, low), sample_bicubic(screen_uv, high), blend);
	}

	vec3 far_color = far_layer.a > 0.0001 ? far_layer.rgb / far_layer.a : original;
	vec3 blurred = level <= 1.0 ? mix(original, far_color, level) : far_color;

	vec3 hazy = mix(blurred, params.haze_tint.rgb, tint_strength);
	vec3 final_color = mix(original, hazy, fog_t * opacity);

	imageStore(color_image, uv, vec4(final_color, 1.0));
}
