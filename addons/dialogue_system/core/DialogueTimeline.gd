extends ProgressBar

class_name DialogueTimeline

signal interrupt_started
signal interrupt_finished

signal choice_started
signal choice_finished


enum Mode {
    IDLE,
    INTERRUPT,
    CHOICE
}

var mode := Mode.IDLE

var _interrupt_time := 0.0
var _choice_time := 0.0

var _timer := 0.0
var _style: DialogueStyle


func _ready() -> void:

    value = 0
    max_value = 1

    set_process(false)


func configure(style: DialogueStyle) -> void:

    _style = style

    if _style == null:
        return

    add_theme_stylebox_override(
        "background",
        _create_stylebox(_style.timeline_background_color)
    )
    _apply_fill_color(_style.timeline_choice_color)


func play(
    interrupt_time: float,
    choice_time: float
) -> void:

    stop()

    _interrupt_time = max(interrupt_time, 0.0)
    _choice_time = max(choice_time, 0.0)

    if _interrupt_time > 0.0:

        _start_interrupt()

    else:

        _start_choice()


func stop() -> void:

    set_process(false)

    mode = Mode.IDLE

    _timer = 0.0

    value = 0
    max_value = 1


func is_running() -> bool:

    return mode != Mode.IDLE


func is_interrupt() -> bool:

    return mode == Mode.INTERRUPT


func is_choice() -> bool:

    return mode == Mode.CHOICE


func _start_interrupt() -> void:

    mode = Mode.INTERRUPT

    if _style:
        _apply_fill_color(_style.timeline_interrupt_color)

    _timer = _interrupt_time

    max_value = _interrupt_time
    value = _interrupt_time

    interrupt_started.emit()

    set_process(true)


func _start_choice() -> void:

    mode = Mode.CHOICE

    if _style:
        _apply_fill_color(_style.timeline_choice_color)

    _timer = _choice_time

    max_value = max(_choice_time, 0.001)
    value = 0

    choice_started.emit()

    set_process(true)


func _process(delta: float) -> void:

    match mode:

        Mode.INTERRUPT:

            _timer -= delta

            value = max(_timer, 0.0)

            if _timer <= 0.0:

                interrupt_finished.emit()

                if _choice_time > 0.0:

                    _start_choice()

                else:

                    stop()

                    choice_finished.emit()


        Mode.CHOICE:

            _timer -= delta

            value = max_value - max(_timer, 0.0)

            if _timer <= 0.0:

                stop()

                choice_finished.emit()


func _apply_fill_color(color: Color) -> void:

    add_theme_stylebox_override("fill", _create_stylebox(color))


func _create_stylebox(color: Color) -> StyleBoxFlat:

    var box := StyleBoxFlat.new()
    box.bg_color = color

    if _style:
        box.corner_radius_top_left = _style.timeline_corner_radius
        box.corner_radius_top_right = _style.timeline_corner_radius
        box.corner_radius_bottom_left = _style.timeline_corner_radius
        box.corner_radius_bottom_right = _style.timeline_corner_radius

    return box
