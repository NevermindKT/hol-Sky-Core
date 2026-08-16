extends Node3D
class_name BackLights

@export_group("On Mode")
@export var on_energy: float = 0.3

@export_group("Off Mode")
@export var off_energy: float = 0.05

@export_group("Lights")
@export var back_lights: Array[SpotLight3D]

func turn_on():
	for i in range(back_lights.size()):
		back_lights[i].light_energy = on_energy
	
func turn_off():
	for i in range(back_lights.size()):
		back_lights[i].light_energy = off_energy
