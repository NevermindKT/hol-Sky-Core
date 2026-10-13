extends RefCounted

class_name DialogueChoice

var id: String = ""
var event: String = ""

## Текст кнопки.
var text: String = ""

## ID наступної репліки.
var next: String = ""

func _init(data: Dictionary = {}) -> void:

    id = str(data.get("id", ""))
    text = str(data.get("text", ""))
    next = str(data.get("next", ""))
    event = str(data.get("event", ""))
