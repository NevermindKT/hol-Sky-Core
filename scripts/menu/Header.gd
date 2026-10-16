extends Control

@export var money_label: Label


func _ready() -> void:
	update_money_display(BaseInventoryManager.get_player_money())

	if not BaseInventoryManager.money_changed.is_connected(_on_money_changed):
		BaseInventoryManager.money_changed.connect(_on_money_changed)


func _on_money_changed(new_amount: int) -> void:
	update_money_display(new_amount)


func update_money_display(amount: int) -> void:
	if money_label:
		money_label.text = str(amount)
