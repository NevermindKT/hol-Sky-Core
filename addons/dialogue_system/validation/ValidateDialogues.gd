extends SceneTree


func _init() -> void:
    var validator := DialogueValidator.new()
    var report := validator.validate_files(
        "res://jsons/dialogues.json",
        "res://jsons/speakers.json",
        "res://jsons/visuals.json"
    )
    print(validator.format_report(report))
    quit(1 if !report.errors.is_empty() else 0)
