extends Node

class_name ChoiceManager

signal finished(choice: DialogueChoice)

@export var timeline: DialogueTimeline
@export var container: BoxContainer
@export var button_scene: PackedScene

var _line: DialogueLine
var _waiting := false
var _style: DialogueStyle


func _ready() -> void:

    timeline.interrupt_started.connect(_on_interrupt_started)
    timeline.interrupt_finished.connect(_on_interrupt_finished)
    timeline.choice_started.connect(_on_choice_started)
    timeline.choice_finished.connect(_on_choice_finished)


func configure(style: DialogueStyle) -> void:

    _style = style


func start(line: DialogueLine) -> void:

    stop()

    if !line.requires_choice():
        return

    _line = line
    _waiting = true


func stop() -> void:

    clear()
    _line = null
    _waiting = false


func cancel() -> void:

    if !_waiting:
        stop()
        return

    stop()
    finished.emit(null)


func clear() -> void:

    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _create_buttons(
    choices: Array[DialogueChoice],
    mode: ChoiceMode.Type
) -> void:

    clear()

    for choice in choices:
        var button := button_scene.instantiate() as DialogueChoiceButton

        button.setup(choice, mode, _style)
        button.selected.connect(_on_choice_selected)
        container.add_child(button)


func _on_interrupt_started() -> void:

    if _line:
        _create_buttons(_line.interrupt_choices, ChoiceMode.Type.INTERRUPT)


func _on_interrupt_finished() -> void:

    clear()


func _on_choice_started() -> void:

    if _line:
        _create_buttons(_line.choices, ChoiceMode.Type.NORMAL)


func _on_choice_finished() -> void:

    if !_waiting:
        return

    clear()
    _waiting = false
    finished.emit(null)


func _on_choice_selected(choice: DialogueChoice) -> void:

    if !_waiting:
        return

    _waiting = false
    clear()
    finished.emit(choice)
