extends Button

class_name DialogueChoiceButton

signal selected(choice: DialogueChoice)

var choice: DialogueChoice
var _shake_phase := 0.0
var _shake_degrees := 0.0
var _shake_speed := 0.0
var _maximum_font_size := 40
var _fit_queued := false


func _ready() -> void:
    clip_text = true
    _maximum_font_size = get_theme_font_size("font_size")
    _queue_font_fit()


func _queue_font_fit() -> void:
    if _fit_queued or not is_node_ready():
        return
    _fit_queued = true
    _fit_font.call_deferred()


func _fit_font() -> void:
    _fit_queued = false
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var box := get_theme_stylebox("normal")
    var available := size - box.get_minimum_size() - Vector2(8, 8)
    var paragraph := TextParagraph.new()
    paragraph.width = maxf(available.x, 1.0)
    paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
    var font := get_theme_font("font")
    for candidate in range(_maximum_font_size, 7, -1):
        paragraph.clear()
        paragraph.add_string(text, font, candidate)
        var measured := paragraph.get_size()
        if measured.x <= available.x and measured.y <= available.y or candidate == 8:
            add_theme_font_size_override("font_size", candidate)
            break


func setup(
    new_choice: DialogueChoice,
    mode: ChoiceMode.Type,
    style: DialogueStyle
) -> void:

    choice = new_choice
    text = choice.text

    if style == null:
        return

    add_theme_constant_override("outline_size", style.button_outline_size)
    var text_color := style.interrupt_button_text_color if mode == ChoiceMode.Type.INTERRUPT else style.normal_button_text_color
    add_theme_color_override("font_outline_color", text_color)
    for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
        add_theme_color_override(state, text_color)

    match mode:
        ChoiceMode.Type.INTERRUPT:
            theme_type_variation = "InterruptChoice"
            custom_minimum_size.y = style.interrupt_button_min_height
            add_theme_font_size_override(
                "font_size",
                roundi(style.interrupt_button_font_size * 1.4)
            )
            add_theme_color_override(
                "font_color",
                style.interrupt_button_text_color
            )
            _apply_styleboxes(
                style.interrupt_button_color,
                style.interrupt_button_hover_color,
                style.interrupt_button_pressed_color,
                style
            )
            _configure_shake(style)

        ChoiceMode.Type.NORMAL:
            theme_type_variation = "NormalChoice"
            custom_minimum_size.y = style.normal_button_min_height
            add_theme_font_size_override(
                "font_size",
                roundi(style.normal_button_font_size * 1.4)
            )
            add_theme_color_override(
                "font_color",
                style.normal_button_text_color
            )
            _apply_styleboxes(
                style.normal_button_color,
                style.normal_button_hover_color,
                style.normal_button_pressed_color,
                style
            )


func _pressed() -> void:

    selected.emit(choice)


func _process(delta: float) -> void:

    _shake_phase += delta * _shake_speed
    rotation = deg_to_rad(sin(_shake_phase) * _shake_degrees)


func _notification(what: int) -> void:

    if what == NOTIFICATION_RESIZED:
        pivot_offset = size * 0.5
        _queue_font_fit()
    elif what == NOTIFICATION_TRANSLATION_CHANGED and choice != null:
        text = choice.text
        _queue_font_fit()


func _configure_shake(style: DialogueStyle) -> void:

    if !style.interrupt_shake_enabled:
        return

    _shake_degrees = style.interrupt_shake_degrees
    _shake_speed = style.interrupt_shake_speed
    set_process(_shake_degrees > 0.0 and _shake_speed > 0.0)


func _apply_styleboxes(
    normal_color: Color,
    hover_color: Color,
    pressed_color: Color,
    style: DialogueStyle
) -> void:

    add_theme_stylebox_override(
        "normal",
        _create_stylebox(normal_color, style)
    )
    add_theme_stylebox_override(
        "hover",
        _create_stylebox(hover_color, style)
    )
    add_theme_stylebox_override(
        "pressed",
        _create_stylebox(pressed_color, style)
    )
    add_theme_stylebox_override(
        "focus",
        _create_stylebox(hover_color, style)
    )


func _create_stylebox(color: Color, style: DialogueStyle) -> StyleBox:

    var box: StyleBox
    if style.button_texture:
        var textured := StyleBoxTexture.new()
        textured.texture = style.button_texture
        for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
            textured.set_texture_margin(side, 12.0)
        # Preserve the artwork instead of tinting it with the flat button colors.
        if color == style.normal_button_hover_color or color == style.interrupt_button_hover_color:
            textured.modulate_color = style.button_texture_hover_tint
        elif color == style.normal_button_pressed_color or color == style.interrupt_button_pressed_color:
            textured.modulate_color = style.button_texture_pressed_tint
        box = textured
    else:
        var flat := StyleBoxFlat.new()
        flat.bg_color = color
        flat.corner_radius_top_left = style.button_corner_radius
        flat.corner_radius_top_right = style.button_corner_radius
        flat.corner_radius_bottom_left = style.button_corner_radius
        flat.corner_radius_bottom_right = style.button_corner_radius
        box = flat

    box.content_margin_left = style.button_horizontal_padding
    box.content_margin_right = style.button_horizontal_padding
    box.content_margin_top = style.button_vertical_padding
    box.content_margin_bottom = style.button_vertical_padding

    return box
