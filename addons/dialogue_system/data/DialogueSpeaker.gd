extends RefCounted

class_name DialogueSpeaker

var id: String
var name: String
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
