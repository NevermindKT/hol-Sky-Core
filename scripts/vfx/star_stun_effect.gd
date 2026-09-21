extends Node3D
class_name Star_Stun_Effect


@export var star_scene: PackedScene
@export var star_count: int = 3
@export var orbit_radius: float = 0.25
@export var orbit_speed: float = 1.5
@export var fade_duration: float = 0.4

var _stars: Array[Node3D] = []
var _materials: Array[StandardMaterial3D] = []
var _trails: Array[GPUParticles3D] = []
var _tweens: Array[Tween] = []
var _time := 0.0


func _ready() -> void:
	for i in star_count:
		var star := star_scene.instantiate() as Node3D
		add_child(star)

		var sprite := star.get_node("Sprite") as MeshInstance3D
		var material := (sprite.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.albedo_color.a = 0.0
		sprite.material_override = material

		_stars.append(star)
		_materials.append(material)
		_trails.append(star.get_node("Trail") as GPUParticles3D)
		_tweens.append(null)

	set_process(false)


func play() -> void:
	set_process(true)

	for i in _stars.size():
		if _tweens[i]:
			_tweens[i].kill()

		_trails[i].emitting = true

		var tween := create_tween()
		tween.tween_property(_materials[i], "albedo_color:a", 1.0, fade_duration)
		_tweens[i] = tween


func stop() -> void:
	var pending := _stars.size()

	for i in _stars.size():
		if _tweens[i]:
			_tweens[i].kill()

		var trail := _trails[i]
		var tween := create_tween()
		tween.tween_property(_materials[i], "albedo_color:a", 0.0, fade_duration)
		tween.finished.connect(func() -> void:
			trail.emitting = false
			pending -= 1
			if pending <= 0:
				set_process(false)
		)
		_tweens[i] = tween


func _process(delta: float) -> void:
	_time += delta

	for i in _stars.size():
		var angle := _time * orbit_speed + i * TAU / star_count
		_stars[i].position = Vector3(cos(angle) * orbit_radius, 0.0, sin(angle) * orbit_radius)
