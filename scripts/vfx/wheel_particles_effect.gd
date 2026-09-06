extends Node3D
class_name WheelParticlesEffect

@export var dust: GPUParticles3D
@export var water_drops: GPUParticles3D

var chose_effect: GPUParticles3D

func _ready() -> void:
	dust.emitting = false
	water_drops.emitting = false
	chose_effect = dust
	
func choose_water_drops() -> void:
	dust.emitting = false
	water_drops.emitting = true
	chose_effect = water_drops
	
func choose_dust() -> void:
	dust.emitting = true
	water_drops.emitting = false
	chose_effect = dust
