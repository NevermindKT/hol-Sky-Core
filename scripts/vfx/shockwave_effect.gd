@tool
extends Node3D
class_name ShockwaveEffect

## Легка ударна хвиля — сфера з shader-дисторсією екрана позаду неї, без
## частинок. play() розширює її від start_radius до end_radius й гасить за
## duration секунд, після чого вузол сам себе прибирає.

@export var data: ShockwaveData:
	set(value):
		data = value
		apply_profile()

@export var mesh: MeshInstance3D

var _material: ShaderMaterial

func _ready() -> void:
	apply_profile()

	if not Engine.is_editor_hint():
		visible = false

func apply_profile() -> void:
	if data == null or mesh == null:
		return

	_material = mesh.material_override as ShaderMaterial
	if _material == null:
		return

	_material.set_shader_parameter("distortion_strength", data.distortion_strength)
	_material.set_shader_parameter("fresnel_power", data.fresnel_power)

	scale = Vector3.ONE * data.start_radius

func play() -> void:
	if Engine.is_editor_hint() or data == null:
		return

	visible = true
	scale = Vector3.ONE * data.start_radius
	if _material:
		_material.set_shader_parameter("dissolve", 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * data.end_radius, data.duration).set_ease(Tween.EASE_OUT)
	if _material:
		tween.tween_property(_material, "shader_parameter/dissolve", 1.0, data.duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
