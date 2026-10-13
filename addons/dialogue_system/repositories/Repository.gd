extends RefCounted

class_name Repository

var _data: Dictionary = {}


func clear() -> void:

    _data.clear()


func add(id: String, value) -> void:

    _data[id] = value


func remove(id: String) -> void:

    _data.erase(id)


func has(id: String) -> bool:

    return _data.has(id)


func get_r(id: String):

    if !_data.has(id):

        push_error("Unknown id: %s" % id)
        return null

    return _data[id]


func try_get(id: String):

    return _data.get(id, null)


func size() -> int:

    return _data.size()


func is_empty() -> bool:

    return _data.is_empty()


func ids() -> PackedStringArray:

    return PackedStringArray(_data.keys())


func values() -> Array:

    return _data.values()


func items() -> Dictionary:

    return _data.duplicate()


func validate() -> bool:

    return true
