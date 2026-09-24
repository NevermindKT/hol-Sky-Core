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

float far_weight(ivec2 texel, vec2 source_size) {
	float depth = texelFetch(depth_texture, texel, 0).r;
	vec2 uv = (vec2(texel) + 0.5) / source_size;
	vec4 view_pos = params.inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	float linear_depth = -view_pos.z / view_pos.w;
	return smoothstep(params.settings.x, params.settings.y, linear_depth);
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

	vec4 sum = vec4(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			ivec2 texel = clamp(base + ivec2(x, y), ivec2(0), max_texel);
			vec4 value;
			if (first_pass) {
				float weight = far_weight(texel, vec2(source_size));
				value = vec4(imageLoad(source_image, texel).rgb * weight, weight);
			} else {
				value = imageLoad(source_image, texel);
			}
			sum += value * (TENT[x] * TENT[y]);
		}
	}

	imageStore(destination_image, dst_uv, sum / 64.0);
}
