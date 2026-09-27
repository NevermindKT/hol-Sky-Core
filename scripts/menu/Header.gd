extends Control

@onready var money_label: Label = $Header/HeaderButtons/Money/MoneyEquals

func _ready() -> void:
	# 1. При запуске сразу запрашиваем актуальное количество денег из базы через GameManager
	update_money_display(GameManager.get_player_money())
	
	# 2. Подписываемся на сигнал изменения денег
	if not GameManager.is_connected("money_changed", Callable(self, "_on_money_changed")):
		GameManager.connect("money_changed", Callable(self, "_on_money_changed"))

func _on_money_changed(new_amount: int) -> void:
	update_money_display(new_amount)

func update_money_display(amount: int) -> void:
	if money_label:
		money_label.text = str(amount)
