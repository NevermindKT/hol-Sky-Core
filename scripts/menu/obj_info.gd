extends Panel
class_name ObjInfo

signal purchase_requested(item_data: Dictionary, amount: int)
signal sell_requested(item_data: Dictionary, amount: int)

enum Mode {
	SHOP,
	INVENTORY
}

@export_category("Info")
@export var icon_rect: TextureRect
@export var name_label: Label
@export var rarity_label: Label
@export var description_label: Label
@export var owned_label: Label

@export_category("Buttons")
@export var minus_button: Button
@export var amount_input: LineEdit
@export var plus_button: Button
@export var action_button: Button

@export_category("Animation")
@export var slide_duration: float = 0.25
@export var slide_offset: float = 40.0

var _tween: Tween
var _shown_left: float
var _shown_right: float
var _is_closing: bool = false

const SELL_PRICE_MULTIPLIER := 0.67

var mode: Mode = Mode.INVENTORY
var item_data: Dictionary = {}
var amount: int = 1
var max_amount: int = 1
var unit_price: int = 0


func _ready() -> void:
	Settings.language_changed.connect(_refresh_language)
	await get_tree().process_frame
	minus_button.pressed.connect(_change_amount.bind(-1))
	plus_button.pressed.connect(_change_amount.bind(1))
	action_button.pressed.connect(_on_action_pressed)

	amount_input.text_submitted.connect(_on_amount_submitted)
	amount_input.focus_exited.connect(_on_amount_focus_exited)

	_shown_left = offset_left
	_shown_right = offset_right

	offset_left = _shown_left + size.x + slide_offset
	offset_right = _shown_right + size.x + slide_offset

	hide()


func setup(data: Dictionary, new_mode: Mode) -> void:
	item_data = data.duplicate(true)
	mode = new_mode

	unit_price = int(data.get("price", data.get("Emount", 0)))

	var icon_path := str(data.get("icon", data.get("IconPath", "")))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	else:
		icon_rect.texture = null

	name_label.text = str(data.get("name", data.get("Name", "")))
	rarity_label.text = str(data.get("rarity", data.get("Rarity", "")))
	description_label.text = str(data.get("desc", data.get("Descriprion", "")))

	var owned := int(data.get("Quantity", data.get("quantity", 0)))
	owned_label.text = tr("У вас є: %d") % owned

	if mode == Mode.SHOP:
		owned_label.hide()
		max_amount = 999999
		action_button.text = tr("Купити")
	else:
		owned_label.show()
		max_amount = owned
		action_button.text = tr("Продати")

	amount = 1
	amount_input.text = "1"

	_update_controls()
	open_panel()


func _change_amount(delta: int) -> void:
	_read_amount()
	amount = clampi(amount + delta, 1, maxi(1, max_amount))
	_update_controls()


func _refresh_language() -> void:
	if item_data.is_empty():
		return
	name_label.text = tr(str(item_data.get("name", item_data.get("Name", ""))))
	rarity_label.text = tr(str(item_data.get("rarity", item_data.get("Rarity", ""))))
	description_label.text = tr(str(item_data.get("desc", item_data.get("Descriprion", ""))))
	var owned := int(item_data.get("Quantity", item_data.get("quantity", 0)))
	owned_label.text = tr("У вас є: %d") % owned
	_update_controls()


func _on_amount_submitted(_text: String) -> void:
	_read_amount()
	_update_controls()


func _on_amount_focus_exited() -> void:
	_read_amount()
	_update_controls()


func _read_amount() -> void:
	var value := amount_input.text.to_int()
	amount = clampi(value, 1, maxi(1, max_amount))


func _update_controls() -> void:
	amount_input.text = str(amount)

	minus_button.disabled = amount <= 1
	plus_button.disabled = amount >= max_amount

	var total_price: int

	if mode == Mode.SHOP:
		total_price = unit_price * amount
		action_button.text = tr("Купити за: %d") % total_price
	else:
		total_price = int(round(
			unit_price * amount * SELL_PRICE_MULTIPLIER
		))
		action_button.text = tr("Продати за: %d") % total_price


func _on_action_pressed() -> void:
	_read_amount()
	_update_controls()

	if mode == Mode.SHOP:
		purchase_requested.emit(item_data, amount)
	else:
		sell_requested.emit(item_data, amount)


func close() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not visible or _is_closing:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not get_global_rect().has_point(event.position):
				close_panel()


func open_panel() -> void:
	_is_closing = false

	if _tween and _tween.is_running():
		_tween.kill()

	show()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		self, "offset_left",
		_shown_left,
		slide_duration
	)

	_tween.tween_property(
		self, "offset_right",
		_shown_right,
		slide_duration
	)


func close_panel() -> void:
	if not visible or _is_closing:
		return

	_is_closing = true

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)

	_tween.tween_property(
		self, "offset_left",
		_shown_left + size.x + slide_offset,
		slide_duration
	)

	_tween.tween_property(
		self, "offset_right",
		_shown_right + size.x + slide_offset,
		slide_duration
	)

	_tween.chain().tween_callback(hide)
