extends CanvasLayer

const INTENSITY_PARAM := &"intensity"

@export var effect_rects: Dictionary[StringName, ColorRect] = {}
@export var fade_in_time := 0.3
@export var fade_out_time := 0.6

var _tweens: Dictionary[StringName, Tween] = {}

func show_effect(effect_id: StringName) -> void:
	var rect: ColorRect = effect_rects.get(effect_id)

	if !rect:
		return

	rect.visible = true

	if _has_intensity(rect):
		_fade(effect_id, rect, 1.0, fade_in_time, false)

func hide_effect(effect_id: StringName) -> void:
	var rect: ColorRect = effect_rects.get(effect_id)

	if !rect:
		return

	if _has_intensity(rect):
		_fade(effect_id, rect, 0.0, fade_out_time, true)
	else:
		rect.visible = false

func _has_intensity(rect: ColorRect) -> bool:
	var material := rect.material as ShaderMaterial

	if !material or !material.shader:
		return false

	for uniform in material.shader.get_shader_uniform_list():
		if uniform.name == INTENSITY_PARAM:
			return true

	return false

func _fade(effect_id: StringName, rect: ColorRect, target: float, duration: float, hide_on_finish: bool) -> void:
	var previous: Tween = _tweens.get(effect_id)

	if previous and previous.is_valid():
		previous.kill()

	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(rect.material, "shader_parameter/" + INTENSITY_PARAM, target, duration)

	if hide_on_finish:
		tween.tween_callback(rect.hide)

	_tweens[effect_id] = tween
