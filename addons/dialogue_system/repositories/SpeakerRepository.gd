extends Repository

class_name SpeakerRepository

func from_dictionary(data: Dictionary, validate_data := true) -> void:

    clear()

    for id in data.keys():

        add(
            id,
            DialogueSpeaker.new(id, data[id])
        )

    if validate_data:
        validate()


func validate() -> bool:

    var valid := true

    for speaker in values():

        if speaker.name.is_empty():

            push_warning(
                "Speaker '%s' has no display name." % speaker.id
            )

    return valid
