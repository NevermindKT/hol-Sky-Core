#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform readonly image2D source_image;
layout(rgba16f, set = 0, binding = 1) uniform writeonly image2D destination_image;
layout(set = 0, binding = 2) uniform sampler2D depth_texture;

layout(push_constant, std430) uniform Params {
	mat4 inv_projection;
	vec4 sizes;
	vec4 settings;
} params;

const float TENT[4] = float[4](1.0, 3.0, 3.0, 1.0);
const int SKY_SEARCH_STEPS = 48;
const int SKY_SEARCH_STRIDE = 6;

float linear_depth_at(ivec2 texel, vec2 source_size, float depth) {
	vec2 uv = (vec2(texel) + 0.5) / source_size;
	vec4 view_pos = params.inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view_pos.z / view_pos.w;
}

vec2 fog_and_far(ivec2 texel, vec2 source_size) {
	float depth = texelFetch(depth_texture, texel, 0).r;
	if (depth <= 0.0) {
		return vec2(1.0, 0.0);
	}
	float linear_depth = linear_depth_at(texel, source_size, depth);
	float fog_t = smoothstep(params.settings.x, params.settings.y, linear_depth);
	float far_t = 0.0;
	if (params.settings.w > params.settings.y) {
		far_t = smoothstep(params.settings.y, params.settings.w, linear_depth);
	}
	return vec2(fog_t, far_t);
}

vec4 sky_above(ivec2 texel) {
	for (int i = 1; i <= SKY_SEARCH_STEPS; i++) {
		ivec2 probe = ivec2(texel.x, texel.y - i * SKY_SEARCH_STRIDE);
		if (probe.y < 0) {
			break;
		}
		if (texelFetch(depth_texture, probe, 0).r <= 0.0) {
			return vec4(imageLoad(source_image, probe).rgb, 1.0);
		}
	}
	return vec4(0.0);
}

void main() {
	ivec2 source_size = ivec2(params.sizes.xy);
	ivec2 destination_size = ivec2(params.sizes.zw);
	ivec2 dst_uv = ivec2(gl_GlobalInvocationID.xy);
	if (dst_uv.x >= destination_size.x || dst_uv.y >= destination_size.y) {
		return;
	}

	bool first_pass = params.settings.z > 0.5;
	ivec2 max_texel = source_size - ivec2(1);
	ivec2 base = dst_uv * 2 - ivec2(1);

	bool sky_checked = false;
	vec4 sky = vec4(0.0);

	vec4 sum = vec4(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			ivec2 texel = clamp(base + ivec2(x, y), ivec2(0), max_texel);
			vec4 value;
			if (first_pass) {
				vec2 weights = fog_and_far(texel, vec2(source_size));
				vec3 color = imageLoad(source_image, texel).rgb;
				float weight = weights.x;
				if (weights.y > 0.0) {
					if (!sky_checked) {
						sky = sky_above(clamp(dst_uv * 2, ivec2(0), max_texel));
						sky_checked = true;
					}
					if (sky.a > 0.0) {
						color = mix(color, sky.rgb, weights.y);
					}
				}
				value = vec4(color * weight, weight);
			} else {
				value = imageLoad(source_image, texel);
			}
			sum += value * (TENT[x] * TENT[y]);
		}
	}

	imageStore(destination_image, dst_uv, sum / 64.0);
}
