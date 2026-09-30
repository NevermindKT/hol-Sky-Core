extends Control

@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider


func _ready() -> void:
	master_slider.value = Settings.master_volume
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume

	master_slider.value_changed.connect(Settings.set_master_volume)
	music_slider.value_changed.connect(Settings.set_music_volume)
	sfx_slider.value_changed.connect(Settings.set_sfx_volume)
