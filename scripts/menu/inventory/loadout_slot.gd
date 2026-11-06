extends Button
class_name LoadoutSlot

signal slot_clicked(slot: int)

@export var slot := 0
@export var icon_rect: TextureRect
@export var key_label: Label
@export var count_label: Label
@export var empty_alpha := 0.35
@export var denied_color := Color(1.0, 0.35, 0.3)

var _flash_tween: Tween


func _ready() -> void:
	key_label.text = str(slot + 1)
	pressed.connect(func(): slot_clicked.emit(slot))
	BoostManager.slots_changed.connect(refresh)
	BaseInventoryManager.inventory_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var object_id := BoostManager.get_slot_object_id(slot)
	var row: Dictionary = BaseInventoryManager.find_object_by_id(object_id) if not object_id.is_empty() else {}

	if row.is_empty():
		icon_rect.texture = null
		count_label.hide()
		tooltip_text = ""
		return

	var icon_path := str(row.get("IconPath", ""))
	icon_rect.texture = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
	var taken := BoostManager.get_slot_count(slot)
	var quantity := int(row.get("Quantity", 0))
	icon_rect.modulate.a = 1.0 if taken > 0 else empty_alpha
	count_label.text = "%d/%d" % [taken, quantity]
	count_label.show()
	tooltip_text = tr(str(row.get("Name", "")))


func flash_denied() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = denied_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.35)


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		BoostManager.remove_one(slot)
		accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("object_id") \
		and BoostManager.is_slot_boost(BoostManager.boost_for_object(str(data["object_id"])))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not BoostManager.add_to_slot(slot, str(data["object_id"])):
		flash_denied()
