extends Control

@onready var btn_continue: Button = $VBoxContainer/Continue
@onready var btn_new_game: Button = $VBoxContainer/NewGame
@onready var btn_exit: Button = $VBoxContainer/Exit

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if btn_continue and not btn_continue.pressed.is_connected(_on_continue_pressed):
		btn_continue.pressed.connect(_on_continue_pressed)
		
	if btn_new_game and not btn_new_game.pressed.is_connected(_on_new_game_pressed):
		btn_new_game.pressed.connect(_on_new_game_pressed)
		
	if btn_exit and not btn_exit.pressed.is_connected(_on_exit_pressed):
		btn_exit.pressed.connect(_on_exit_pressed)

func _on_continue_pressed() -> void:
	_change_to_map()

func _on_new_game_pressed() -> void:
	# Кнопка NewGame теперь ведет себя так же, как Continue, не ломая сохранения
	_change_to_map()

func _change_to_map() -> void:
	var error = get_tree().change_scene_to_file("res://scenes/menu/map/Map.tscn")
	if error != OK:
		print("Ошибка: не удалось загрузить сцену карты по пути res://scenes/menu/map/Map.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
