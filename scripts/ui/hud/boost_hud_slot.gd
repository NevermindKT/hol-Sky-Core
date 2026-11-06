extends Control
class_name BoostHudSlot

@export var slot := 0
@export var icon_rect: TextureRect
@export var fill: Control
@export var key_label: Label
@export var count_label: Label
@export var cooldown_shade: Control
@export var empty_alpha := 0.35
@export var denied_color := Color(1.0, 0.3, 0.25)

var boost: BoostData

var _flash_tween: Tween


func set_boost(new_boost: BoostData) -> void:
	boost = new_boost
	visible = boost != null
	if boost == null:
		return

	var row := BoostManager.object_for_boost(boost)
	var icon_path := str(row.get("IconPath", ""))
	icon_rect.texture = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
	key_label.text = BoostHud.action_key("boost_slot_%d" % (slot + 1))
	update_count()


func update_count() -> void:
	if boost == null:
		return
	var amount := BoostManager.run_left(slot)
	count_label.text = str(amount)
	icon_rect.modulate.a = 1.0 if amount > 0 or BoostManager.active.has(boost) else empty_alpha


func flash_denied() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = denied_color
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.35)


func _process(_delta: float) -> void:
	if boost == null:
		return
	update_count()
	var cooldown := BoostManager.get_cooldown_ratio()
	cooldown_shade.visible = cooldown > 0.0
	if cooldown_shade.visible:
		cooldown_shade.anchor_bottom = cooldown
	var time_left := BoostManager.get_time_left(boost)
	fill.visible = time_left > 0.0
	if fill.visible:
		fill.anchor_top = 1.0 - clampf(time_left / boost.duration, 0.0, 1.0)
