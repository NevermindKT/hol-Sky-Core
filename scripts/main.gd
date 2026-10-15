extends Node

@export var overlay: TextureRect

func _ready() -> void:
	Settings.register_overlay(overlay)
