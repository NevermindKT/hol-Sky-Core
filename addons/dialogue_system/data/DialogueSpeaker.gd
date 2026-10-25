extends RefCounted

class_name DialogueSpeaker

var id: String
var _source_name: String = ""
var name: String:
    get:
        return tr(_source_name)
    set(value):
        _source_name = value
var color: String


func _init(
    id: String,
    data: Dictionary
) -> void:

    self.id = id

    name = str(
        data.get("name", id)
    )

    color = str(
        data.get("color", "#FFFFFF")
    )
