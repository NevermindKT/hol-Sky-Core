extends RefCounted

class_name JsonLoader


func load_json(path: String) -> Dictionary:

    if !FileAccess.file_exists(path):

        push_error(
            "JSON file not found:\n%s" % path
        )

        return {}

    var file := FileAccess.open(
        path,
        FileAccess.READ
    )

    if file == null:

        push_error(
            "Cannot open JSON:\n%s" % path
        )

        return {}

    var parser := JSON.new()

    var error := parser.parse(
        file.get_as_text()
    )

    if error != OK:

        push_error(
			"JSON parse error in '%s'\n%s"
            % [
                path,
                parser.get_error_message()
            ]
        )

        return {}

    if !(parser.data is Dictionary):

        push_error(
			"Root JSON must be Dictionary:\n%s"
            % path
        )

        return {}

    return parser.data
