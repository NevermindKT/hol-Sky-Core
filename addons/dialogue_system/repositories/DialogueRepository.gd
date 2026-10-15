extends Repository

class_name DialogueRepository


func from_dictionary(data: Dictionary, validate_data := true) -> void:

    clear()

    for id in data.keys():

        var line_data: Dictionary = data[id].duplicate(true)

        line_data["id"] = id

        add(
            id,
            DialogueLine.new(line_data)
        )

    if validate_data:
        validate()


func validate() -> bool:

    var valid := true

    for id in ids():

        var line: DialogueLine = get_r(id)

        valid = _validate_next(line) and valid
        valid = _validate_ignore(line) and valid
        valid = _validate_interrupt_choices(line) and valid
        valid = _validate_choices(line) and valid

    return valid


func _validate_next(line: DialogueLine) -> bool:

    if !line.has_next():
        return true

    if has(line.next):
        return true

    push_error(
		"Dialogue '%s' refers to missing next '%s'."
        % [line.id, line.next]
    )

    return false


func _validate_ignore(line: DialogueLine) -> bool:

    if !line.has_ignore():
        return true

    if has(line.ignore):
        return true

    push_error(
		"Dialogue '%s' refers to missing ignore '%s'."
        % [line.id, line.ignore]
    )

    return false


func _validate_interrupt_choices(line: DialogueLine) -> bool:

    var valid := true

    for choice in line.interrupt_choices:

        if has(choice.next):
            continue

        push_error(
			"Dialogue '%s' interrupt choice '%s' refers to missing '%s'."
            % [
                line.id,
                choice.text,
                choice.next
            ]
        )

        valid = false

    return valid


func _validate_choices(line: DialogueLine) -> bool:

    var valid := true

    for choice in line.choices:

        if has(choice.next):
            continue

        push_error(
			"Dialogue '%s' choice '%s' refers to missing '%s'."
            % [
                line.id,
                choice.text,
                choice.next
            ]
        )

        valid = false

    return valid
