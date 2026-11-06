extends Control
class_name BoostHud

@export var slots: Array[BoostHudSlot] = []
@export var slots_container: Control
@export var spare_prompt: Control
@export var spare_key_label: Label
@export var spare_text_label: Label
@export var spare_icon: TextureRect


static func action_key(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var keycode := key.keycode
		if keycode == KEY_NONE:
			keycode = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		return OS.get_keycode_string(keycode)
	return ""


func _ready() -> void:
	BoostManager.slots_changed.connect(_refresh)
	BoostManager.boost_used.connect(_on_boost_used)
	BoostManager.boost_denied.connect(_on_boost_denied)
	Events.run_started.connect(_refresh)
	Events.wheel_lost.connect(_refresh_spare)
	Events.wheel_repaired.connect(_refresh_spare)
	Settings.language_changed.connect(_refresh_spare)
	_refresh()


func _refresh() -> void:
	var any := false
	for hud_slot in slots:
		hud_slot.set_boost(BoostManager.get_slot_boost(hud_slot.slot))
		any = any or hud_slot.boost != null
	slots_container.visible = any
	_refresh_spare()


func _refresh_spare() -> void:
	var spare := BoostManager.get_spare_tire()
	var amount := BoostManager.count(spare)
	var wheels := Wheel_Loss_Controller.current
	spare_prompt.visible = amount > 0 and wheels != null and wheels.has_missing_wheel()
	if not spare_prompt.visible:
		return

	spare_key_label.text = action_key(&"spare_tire")
	spare_text_label.text = tr("Fit the spare tire") + "  ×%d" % amount
	var row := BoostManager.object_for_boost(spare)
	var icon_path := str(row.get("IconPath", ""))
	spare_icon.texture = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null


func _on_boost_used(_boost: BoostData) -> void:
	for hud_slot in slots:
		hud_slot.update_count()
	_refresh_spare()


func _on_boost_denied(boost: BoostData) -> void:
	for hud_slot in slots:
		if hud_slot.boost == boost:
			hud_slot.flash_denied()
