extends Resource

class_name DialogueStyle

@export_group("Interrupt buttons")
@export var interrupt_button_min_height := 88.0
@export var interrupt_button_font_size := 24
@export var interrupt_button_color := Color("#b91c1c")
@export var interrupt_button_hover_color := Color("#dc2626")
@export var interrupt_button_pressed_color := Color("#7f1d1d")
@export var interrupt_button_text_color := Color.WHITE

@export_group("Normal buttons")
@export var normal_button_min_height := 60.0
@export var normal_button_font_size := 20
@export var normal_button_color := Color("#303030")
@export var normal_button_hover_color := Color("#484848")
@export var normal_button_pressed_color := Color("#202020")
@export var normal_button_text_color := Color.WHITE

@export_group("Button shape")
@export var button_texture: Texture2D
@export var button_texture_hover_tint := Color(1.15, 1.12, 1.06, 1.0)
@export var button_texture_pressed_tint := Color(0.75, 0.75, 0.75, 1.0)
@export_range(0, 12) var button_outline_size := 5
@export var button_outline_color := Color.WHITE
@export var button_corner_radius := 6
@export var button_horizontal_padding := 16.0
@export var button_vertical_padding := 10.0

@export_group("Interrupt shake")
@export var interrupt_shake_enabled := true
@export_range(0.0, 10.0, 0.1) var interrupt_shake_degrees := 1.2
@export_range(0.0, 60.0, 0.5) var interrupt_shake_speed := 24.0

@export_group("Timeline")
@export var timeline_interrupt_color := Color("#dc2626")
@export var timeline_choice_color := Color("#e5e7eb")
@export var timeline_background_color := Color(0.08, 0.08, 0.08, 0.85)
@export var timeline_corner_radius := 3
