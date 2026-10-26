extends RefCounted

class_name DialogueSegment

var _source_text: String = ""
var text: String:
    get:
        return tr(_source_text)
    set(value):
        _source_text = value

## Символів за секунду.
var speed: float = 30.0

## BBCode-теги.
## Наприклад:
## ["color=#ff4444", "shake"]
var tags: Array[String] = []

var before_pause: float = 0.0
var after_pause: float = 0.0

func _init(data: Dictionary = {}) -> void:

    text = data.get("text", "")
    speed = float(data.get("speed", 30.0))
    
    before_pause = float(data.get("before_pause", 0.0))
    after_pause = float(data.get("after_pause", 0.0))

    if data.has("tags"):
        for tag in data["tags"]:
            tags.append(str(tag))


func _get_open_tags() -> String:

    var result := ""

    for tag in tags:
        result += "[%s]" % tag

    return result


func _get_close_tags() -> String:

    var result := ""

    for i in range(tags.size() - 1, -1, -1):
        var tag := tags[i]

        var name := tag.split("=")[0]

        result += "[/%s]" % name

    return result


func to_bbcode(length := -1) -> String:

    var content := text

    if length >= 0:
        content = text.substr(0, length)

    var result := _get_open_tags() + content + _get_close_tags()
    for tag in tags:
        if tag.begins_with("color="):
            result = "[outline_color=%s]%s[/outline_color]" % [tag.trim_prefix("color="), result]
    return result
