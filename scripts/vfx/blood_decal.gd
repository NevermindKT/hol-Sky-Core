extends Decal
class_name Blood_decal

@export var texture_variants: Array[Texture2D] = []
@export var normal_variants: Array[Texture2D] = []
@export var orm_variants: Array[Texture2D] = []

@export var surface_margin: float = 0.05

@export var scale_range: Vector2 = Vector2(0.7, 1.3)

@export var color_boost: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	if texture_variants.is_empty():
		push_warning("Blood_decal: texture_variants порожній — призначте PNG-варіанти в Inspector.")
		return

	var index := randi() % texture_variants.size()
	texture_albedo = texture_variants[index]

	if index < normal_variants.size():
		texture_normal = normal_variants[index]
	if index < orm_variants.size():
		texture_orm = orm_variants[index]

	modulate = color_boost

	apply_random_scale(scale_range)


func apply_random_scale(range: Vector2) -> void:
	scale = Vector3.ONE * randf_range(range.x, range.y)


func place(surface_position: Vector3, surface_normal: Vector3) -> void:
	var up := surface_normal.normalized()
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD

	var new_basis := Basis()
	new_basis.y = up
	new_basis.x = reference.cross(up).normalized()
	new_basis.z = new_basis.x.cross(up).normalized()

	global_basis = new_basis.rotated(up, randf_range(0.0, TAU))
	global_position = surface_position + up * surface_margin
