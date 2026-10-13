extends RefCounted

class_name DialogueLine

var id: String = ""

var speaker: String = ""
var event: String = ""

## Missing fields preserve the previous presentation; empty IDs hide the layer.
var presentation: Dictionary = {}

var segments: Array[DialogueSegment] = []

var interrupt_choices: Array[DialogueChoice] = []
var choices: Array[DialogueChoice] = []

## Час, коли можна перебити співрозмовника.
var interrupt_time := 0.0

## Час, коли доступні звичайні відповіді.
var choice_time := 0.0

## Автоматичний перехід після закінчення репліки.
var next := ""

## Перехід, якщо гравець нічого не відповів.
var ignore := ""


func _init(data := {}) -> void:

    id = str(data.get("id", ""))

    speaker = str(data.get("speaker", ""))
    event = str(data.get("event", ""))
    presentation = data.get("presentation", {}).duplicate(true)

    interrupt_time = float(data.get("interrupt_time", 0.0))
    choice_time = float(data.get("choice_time", 0.0))

    next = str(data.get("next", ""))
    ignore = str(data.get("ignore", ""))

    for segment_data in data.get("segments", []):

        segments.append(
            DialogueSegment.new(segment_data)
        )

    for choice_data in data.get("interrupt_choices", []):

        var choice := DialogueChoice.new(choice_data)
        if choice.id.is_empty():
            choice.id = "%s.interrupt_%d" % [id, interrupt_choices.size()]
        interrupt_choices.append(choice)

    for choice_data in data.get("choices", []):

        var choice := DialogueChoice.new(choice_data)
        if choice.id.is_empty():
            choice.id = "%s.choice_%d" % [id, choices.size()]
        choices.append(choice)


func has_next() -> bool:

    return !next.is_empty()


func has_ignore() -> bool:

    return !ignore.is_empty()


func has_interrupt_choices() -> bool:

    return !interrupt_choices.is_empty()


func has_choices() -> bool:

    return !choices.is_empty()


func full_text() -> String:

    var result := ""

    for segment in segments:

        result += segment.text

    return result

func requires_choice() -> bool:
    return !interrupt_choices.is_empty() or !choices.is_empty()
