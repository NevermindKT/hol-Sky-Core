extends CanvasLayer

@export var effect_rects: Dictionary[StringName, ColorRect] = {}

func show_effect(effect_id: StringName) -> void:
	var rect: ColorRect = effect_rects.get(effect_id)

	if rect:
		rect.visible = true

func hide_effect(effect_id: StringName) -> void:
	var rect: ColorRect = effect_rects.get(effect_id)

	if rect:
		rect.visible = false
