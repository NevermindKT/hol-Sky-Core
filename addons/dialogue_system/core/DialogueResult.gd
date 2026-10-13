extends RefCounted

class_name DialogueResult

enum Type {
    END,
    NEXT,
    IGNORE,
    CHOICE,
    CANCELLED
}

var type: Type = Type.END

## Подія (раніше next / ignore)
var event := ""

## Якщо був вибір
var choice: DialogueChoice = null


static func end() -> DialogueResult:

    return DialogueResult.new()


static func next(event: String) -> DialogueResult:

    var r := DialogueResult.new()
    r.type = Type.NEXT
    r.event = event
    return r


static func ignore(event: String) -> DialogueResult:

    var r := DialogueResult.new()
    r.type = Type.IGNORE
    r.event = event
    return r


static func choice_result(choice: DialogueChoice) -> DialogueResult:

    var r := DialogueResult.new()
    r.type = Type.CHOICE
    r.choice = choice
    return r


static func cancelled() -> DialogueResult:

    var r := DialogueResult.new()
    r.type = Type.CANCELLED
    return r
