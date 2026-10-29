extends Control
class_name item_view

@export var button: Button
@export var count_label: RichTextLabel
@export var price_label: RichTextLabel

var item_id: String = ""

func setup(item_data: Dictionary) -> void:
	item_id = str(item_data.get("ID", item_data.get("id", "")))

	var icon_path := str(item_data.get("IconPath", item_data.get("icon", "")))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var texture := load(icon_path) as Texture2D
		if texture:
			set_button_icon(texture)

	var quantity := int(item_data.get("Quantity", 0))
	if count_label:
		count_label.visible = quantity > 0
		set_count(quantity)

	var price := int(item_data.get("Emount", item_data.get("price", 0)))
	if price_label:
		price_label.visible = price > 0
		price_label.text = str(price)


func set_count(amount: int) -> void:
	if count_label:
		count_label.text = str(amount) + "x"


func set_button_icon(icon: Texture2D) -> void:
	if button:
		button.icon = icon
