@tool
extends CompositorEffect
class_name HorizonFogEffect

const MIP_COUNT := 4
const CONTEXT := &"horizon_fog"

@export var fog_start := 60.0
@export var fog_end := 220.0
@export var blur_amount := 5.0
@export var haze_tint := Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0) var tint_strength := 0.0
@export_range(0.0, 1.0) var opacity := 1.0
@export var debug_view_depth := false

var rd: RenderingDevice

var downsample_shader: RID
var downsample_pipeline: RID
var composite_shader: RID
var composite_pipeline: RID
var mip_sampler: RID
var depth_sampler: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	_build_pipelines()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or rd == null:
		return
	for id in [downsample_shader, composite_shader, mip_sampler, depth_sampler]:
		if id.is_valid():
			rd.free_rid(id)


func _build_pipelines() -> void:
	if rd == null:
		return

	var downsample_file: RDShaderFile = load("res://resources/shaders/weather/compute/horizon_fog_downsample.glsl")
	downsample_shader = rd.shader_create_from_spirv(downsample_file.get_spirv())
	downsample_pipeline = rd.compute_pipeline_create(downsample_shader)

	var composite_file: RDShaderFile = load("res://resources/shaders/weather/compute/horizon_fog_composite.glsl")
	composite_shader = rd.shader_create_from_spirv(composite_file.get_spirv())
	composite_pipeline = rd.compute_pipeline_create(composite_shader)

	var mip_sampler_state := RDSamplerState.new()
	mip_sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	mip_sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	mip_sampler_state.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	mip_sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	mip_sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	mip_sampler_state.max_lod = float(MIP_COUNT - 1)
	mip_sampler = rd.sampler_create(mip_sampler_state)

	var depth_sampler_state := RDSamplerState.new()
	depth_sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	depth_sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	depth_sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	depth_sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	depth_sampler = rd.sampler_create(depth_sampler_state)


func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if rd == null or p_effect_callback_type != EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT:
		return
	if not downsample_pipeline.is_valid() or not composite_pipeline.is_valid():
		return

	var scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	var scene_data: RenderSceneDataRD = p_render_data.get_render_scene_data()
	if scene_buffers == null or scene_data == null:
		return

	var size := scene_buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return

	for view in range(scene_buffers.get_view_count()):
		_render_view(scene_buffers, scene_data, view, size)


func _render_view(scene_buffers: RenderSceneBuffersRD, scene_data: RenderSceneDataRD, view: int, size: Vector2i) -> void:
	var color_image := scene_buffers.get_color_layer(view)
	var depth_image := scene_buffers.get_depth_layer(view)
	var projection_floats := _inverse_projection_floats(scene_data)

	var mip_name := StringName("mip_chain_%d" % view)
	var base_mip_size := Vector2i(maxi(1, size.x / 2), maxi(1, size.y / 2))

	scene_buffers.create_texture(
		CONTEXT, mip_name,
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT,
		RenderingDevice.TEXTURE_SAMPLES_1,
		base_mip_size, 1, MIP_COUNT, true, true
	)

	var level_sizes: Array[Vector2i] = [base_mip_size]
	for i in range(1, MIP_COUNT):
		var previous: Vector2i = level_sizes[i - 1]
		level_sizes.append(Vector2i(maxi(1, previous.x / 2), maxi(1, previous.y / 2)))

	var previous_image := color_image
	var previous_size := size
	for mip in range(MIP_COUNT):
		var dest_image := scene_buffers.get_texture_slice(CONTEXT, mip_name, 0, mip, 1, 1)
		_dispatch_downsample(previous_image, dest_image, depth_image, projection_floats, previous_size, level_sizes[mip], mip == 0)
		previous_image = dest_image
		previous_size = level_sizes[mip]

	var mip_texture := scene_buffers.get_texture(CONTEXT, mip_name)
	_dispatch_composite(color_image, depth_image, mip_texture, projection_floats, size)


func _inverse_projection_floats(scene_data: RenderSceneDataRD) -> PackedFloat32Array:
	var inv_projection := scene_data.get_cam_projection().inverse()
	var floats := PackedFloat32Array()
	for column in [inv_projection.x, inv_projection.y, inv_projection.z, inv_projection.w]:
		floats.append_array(PackedFloat32Array([column.x, column.y, column.z, column.w]))
	return floats


func _dispatch_downsample(source_image: RID, destination_image: RID, depth_image: RID, projection_floats: PackedFloat32Array, source_size: Vector2i, destination_size: Vector2i, first_pass: bool) -> void:
	var source_uniform := RDUniform.new()
	source_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	source_uniform.binding = 0
	source_uniform.add_id(source_image)

	var destination_uniform := RDUniform.new()
	destination_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	destination_uniform.binding = 1
	destination_uniform.add_id(destination_image)

	var depth_uniform := RDUniform.new()
	depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth_uniform.binding = 2
	depth_uniform.add_id(depth_sampler)
	depth_uniform.add_id(depth_image)

	var uniform_set := UniformSetCacheRD.get_cache(downsample_shader, 0, [source_uniform, destination_uniform, depth_uniform])

	var push_constant := projection_floats.duplicate()
	push_constant.append_array(PackedFloat32Array([
		float(source_size.x), float(source_size.y),
		float(destination_size.x), float(destination_size.y),
	]))
	push_constant.append_array(PackedFloat32Array([fog_start, fog_end, 1.0 if first_pass else 0.0, 0.0]))

	var x_groups := (destination_size.x - 1) / 8 + 1
	var y_groups := (destination_size.y - 1) / 8 + 1

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, downsample_pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()


func _dispatch_composite(color_image: RID, depth_image: RID, mip_texture: RID, projection_floats: PackedFloat32Array, size: Vector2i) -> void:
	var color_uniform := RDUniform.new()
	color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_uniform.binding = 0
	color_uniform.add_id(color_image)

	var depth_uniform := RDUniform.new()
	depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth_uniform.binding = 1
	depth_uniform.add_id(depth_sampler)
	depth_uniform.add_id(depth_image)

	var mip_uniform := RDUniform.new()
	mip_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	mip_uniform.binding = 2
	mip_uniform.add_id(mip_sampler)
	mip_uniform.add_id(mip_texture)

	var uniform_set := UniformSetCacheRD.get_cache(composite_shader, 0, [color_uniform, depth_uniform, mip_uniform])

	var push_constant := projection_floats.duplicate()
	push_constant.append_array(PackedFloat32Array([haze_tint.r, haze_tint.g, haze_tint.b, haze_tint.a]))
	push_constant.append_array(PackedFloat32Array([float(size.x), float(size.y), fog_start, fog_end]))
	push_constant.append_array(PackedFloat32Array([blur_amount, tint_strength, opacity, float(MIP_COUNT)]))
	push_constant.append_array(PackedFloat32Array([1.0 if debug_view_depth else 0.0, 0.0, 0.0, 0.0]))

	var x_groups := (size.x - 1) / 8 + 1
	var y_groups := (size.y - 1) / 8 + 1

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, composite_pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
