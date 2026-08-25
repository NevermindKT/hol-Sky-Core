extends Node

@onready var sub_viewport: SubViewport = $SubViewport
@onready var color_rect: ColorRect = $SubViewport/ColorRect

const SEEDS := [12.3, 87.1, 234.5, 401.9, 512.2, 733.6]
const OUTPUT_DIR := "res://textures/vfx/blood/"

func _ready() -> void:
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var material := color_rect.material as ShaderMaterial
	material.set_shader_parameter("edge_color", Color("#1a0303"))
	material.set_shader_parameter("center_color", Color("#990505"))

	await _bake_all(material)

	print("Готово. Текстури перезаписані в ", OUTPUT_DIR, " — можна закривати вікно.")


func _bake_all(material: ShaderMaterial) -> void:
	for i in SEEDS.size():
		material.set_shader_parameter("seed_offset", SEEDS[i])

		await get_tree().process_frame
		await get_tree().process_frame

		var image := sub_viewport.get_texture().get_image()
		var path := OUTPUT_DIR + "blood_splat_%02d.png" % (i + 1)
		image.save_png(path)
		print("Збережено: ", path)
