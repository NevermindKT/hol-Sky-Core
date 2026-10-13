extends RefCounted

class_name DialogueValidator


func validate_files(dialogues_path: String, speakers_path: String, visuals_path := "") -> Dictionary:
    var report := {
        "errors": [],
        "warnings": [],
    }
    var dialogues := _load_dictionary(dialogues_path, "dialogues", report)
    var speakers := _load_dictionary(speakers_path, "speakers", report)

    _find_duplicate_root_keys(dialogues_path, report)
    _find_duplicate_root_keys(speakers_path, report)

    if dialogues.is_empty() or speakers.is_empty():
        return report

    _validate_speakers(speakers, report)
    _validate_dialogues(dialogues, speakers, report)
    if !visuals_path.is_empty():
        var visuals := _load_dictionary(visuals_path, "visuals", report)
        _validate_visuals(dialogues, visuals, report)
    _validate_graph(dialogues, report)
    return report


func format_report(report: Dictionary) -> String:
    var output: Array[String] = []
    var errors: Array = report.get("errors", [])
    var warnings: Array = report.get("warnings", [])

    output.append("Dialogue validation: %d error(s), %d warning(s)" % [errors.size(), warnings.size()])
    for message in errors:
        output.append("ERROR: %s" % message)
    for message in warnings:
        output.append("WARNING: %s" % message)
    return "\n".join(output)


func _load_dictionary(path: String, label: String, report: Dictionary) -> Dictionary:
    if !FileAccess.file_exists(path):
        _error(report, "%s file not found: %s" % [label.capitalize(), path])
        return {}

    var file := FileAccess.open(path, FileAccess.READ)
    if !file:
        _error(report, "Cannot open %s file: %s" % [label, path])
        return {}

    var parser := JSON.new()
    var parse_error := parser.parse(file.get_as_text())
    if parse_error != OK:
        _error(report, "%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
        return {}
    if !(parser.data is Dictionary):
        _error(report, "%s root must be an object" % path)
        return {}
    return parser.data


func _find_duplicate_root_keys(path: String, report: Dictionary) -> void:
    if !FileAccess.file_exists(path):
        return

    var lines := FileAccess.get_file_as_string(path).split("\n")
    var expression := RegEx.new()
    expression.compile("^(\\s*)\"([^\"]+)\"\\s*:")
    var matches: Array[Dictionary] = []
    var minimum_indent := 1000000

    for line_number in lines.size():
        var match := expression.search(lines[line_number])
        if !match:
            continue
        var indent := match.get_string(1).replace("\t", "    ").length()
        minimum_indent = min(minimum_indent, indent)
        matches.append({"key": match.get_string(2), "indent": indent, "line": line_number + 1})

    var seen := {}
    for item in matches:
        if item.indent != minimum_indent:
            continue
        if seen.has(item.key):
            _error(
                report,
                "%s:%d: duplicate root key '%s' (first declared on line %d)"
                % [path, item.line, item.key, seen[item.key]]
            )
        else:
            seen[item.key] = item.line


func _validate_speakers(speakers: Dictionary, report: Dictionary) -> void:
    for speaker_id in speakers:
        var data = speakers[speaker_id]
        if !(data is Dictionary):
            _error(report, "Speaker '%s' must be an object" % speaker_id)
            continue
        if !data.has("name") or !(data.name is String):
            _error(report, "Speaker '%s' must have a string 'name'" % speaker_id)
        if data.has("color") and !(data.color is String):
            _error(report, "Speaker '%s' color must be a string" % speaker_id)
        elif data.has("color") and !Color.html_is_valid(data.color):
            _error(report, "Speaker '%s' has invalid color '%s'" % [speaker_id, data.color])


func _validate_dialogues(dialogues: Dictionary, speakers: Dictionary, report: Dictionary) -> void:
    for line_id in dialogues:
        var line = dialogues[line_id]
        if !(line is Dictionary):
            _error(report, "Dialogue '%s' must be an object" % line_id)
            continue

        var speaker := str(line.get("speaker", ""))
        if !speaker.is_empty() and !speakers.has(speaker):
            _error(report, "Dialogue '%s' refers to missing speaker '%s'" % [line_id, speaker])

        var segments = line.get("segments", [])
        if !(segments is Array) or segments.is_empty():
            _error(report, "Dialogue '%s' must contain at least one segment" % line_id)
        else:
            for index in segments.size():
                _validate_segment(line_id, index, segments[index], report)

        _validate_time(line_id, line, "interrupt_time", report)
        _validate_time(line_id, line, "choice_time", report)
        _validate_target(line_id, "next", str(line.get("next", "")), dialogues, report)
        _validate_target(line_id, "ignore", str(line.get("ignore", "")), dialogues, report)
        _validate_choices(line_id, "interrupt_choices", line.get("interrupt_choices", []), dialogues, report)
        _validate_choices(line_id, "choices", line.get("choices", []), dialogues, report)


func _validate_segment(line_id: String, index: int, segment, report: Dictionary) -> void:
    if !(segment is Dictionary):
        _error(report, "Dialogue '%s' segment %d must be an object" % [line_id, index])
        return
    if !segment.has("text") or !(segment.text is String) or segment.text.is_empty():
        _error(report, "Dialogue '%s' segment %d must have non-empty string text" % [line_id, index])
    if segment.has("speed") and (!(segment.speed is float or segment.speed is int) or float(segment.speed) <= 0.0):
        _error(report, "Dialogue '%s' segment %d speed must be greater than zero" % [line_id, index])
    for field in ["before_pause", "after_pause"]:
        if segment.has(field) and (!(segment[field] is float or segment[field] is int) or float(segment[field]) < 0.0):
            _error(report, "Dialogue '%s' segment %d %s cannot be negative" % [line_id, index, field])
    if segment.has("tags") and !(segment.tags is Array):
        _error(report, "Dialogue '%s' segment %d tags must be an array" % [line_id, index])


func _validate_time(line_id: String, line: Dictionary, field: String, report: Dictionary) -> void:
    if line.has(field) and (!(line[field] is float or line[field] is int) or float(line[field]) < 0.0):
        _error(report, "Dialogue '%s' %s cannot be negative" % [line_id, field])


func _validate_choices(line_id: String, field: String, choices, dialogues: Dictionary, report: Dictionary) -> void:
    if !(choices is Array):
        _error(report, "Dialogue '%s' %s must be an array" % [line_id, field])
        return
    for index in choices.size():
        var choice = choices[index]
        if !(choice is Dictionary):
            _error(report, "Dialogue '%s' %s item %d must be an object" % [line_id, field, index])
            continue
        if !choice.has("text") or !(choice.text is String) or choice.text.is_empty():
            _error(report, "Dialogue '%s' %s item %d has no text" % [line_id, field, index])
        _validate_target(line_id, "%s item %d" % [field, index], str(choice.get("next", "")), dialogues, report, false)


func _validate_target(line_id: String, field: String, target: String, dialogues: Dictionary, report: Dictionary, allow_empty := true) -> void:
    if target.is_empty():
        if !allow_empty:
            _error(report, "Dialogue '%s' %s has no target" % [line_id, field])
        return
    if !dialogues.has(target):
        _error(report, "Dialogue '%s' %s refers to missing '%s'" % [line_id, field, target])


func _validate_graph(dialogues: Dictionary, report: Dictionary) -> void:
    var escapable := {}
    var targets_by_id := {}

    for line_id in dialogues:
        var targets := _get_targets(dialogues[line_id])
        targets_by_id[line_id] = targets
        if targets.is_empty():
            escapable[line_id] = true
        else:
            for target in targets:
                if !dialogues.has(target):
                    # Missing references are already reported as errors. Treat
                    # them as graph exits to avoid a warning on every parent.
                    escapable[line_id] = true
                    break

    var changed := true
    while changed:
        changed = false
        for line_id in dialogues:
            if escapable.has(line_id):
                continue
            for target in targets_by_id[line_id]:
                if escapable.has(target):
                    escapable[line_id] = true
                    changed = true
                    break

    for line_id in dialogues:
        if !escapable.has(line_id):
            _warning(report, "Dialogue '%s' cannot reach an ending (closed cycle)" % line_id)


func _get_targets(line) -> Array[String]:
    var targets: Array[String] = []
    if !(line is Dictionary):
        return targets
    for field in ["next", "ignore"]:
        var target := str(line.get(field, ""))
        if !target.is_empty():
            targets.append(target)
    for field in ["interrupt_choices", "choices"]:
        var choices = line.get(field, [])
        if choices is Array:
            for choice in choices:
                if choice is Dictionary:
                    var target := str(choice.get("next", ""))
                    if !target.is_empty():
                        targets.append(target)
    return targets


func _error(report: Dictionary, message: String) -> void:
    report.errors.append(message)


func _warning(report: Dictionary, message: String) -> void:
    report.warnings.append(message)


func _validate_visuals(dialogues: Dictionary, visuals: Dictionary, report: Dictionary) -> void:
    var environments = visuals.get("environments", {})
    var characters = visuals.get("characters", {})
    if !(environments is Dictionary) or !(characters is Dictionary):
        _error(report, "Visuals environments and characters must be objects")
        return
    for id in environments:
        var data = environments[id]
        if !(data is Dictionary):
            _error(report, "Environment '%s' must be an object" % id)
            continue
        for field in ["background", "footer"]:
            _validate_texture(data.get(field, ""), "Environment '%s' %s" % [id, field], report)
    for id in characters:
        var data = characters[id]
        if !(data is Dictionary) or !(data.get("emotions") is Dictionary):
            _error(report, "Character '%s' must define an emotions object" % id)
            continue
        if !data.emotions.has(data.get("default_emotion", "")):
            _error(report, "Character '%s' has no valid default_emotion" % id)
        for emotion in data.emotions:
            _validate_texture(data.emotions[emotion], "Character '%s' emotion '%s'" % [id, emotion], report)
    for id in dialogues:
        if !(dialogues[id] is Dictionary):
            continue
        var data = dialogues[id].get("presentation", {})
        if !(data is Dictionary):
            _error(report, "Dialogue '%s' presentation must be an object" % id)
            continue
        for field in data:
            if field not in ["environment", "character", "emotion"] or !(data[field] is String):
                _error(report, "Dialogue '%s' has invalid presentation field '%s'" % [id, field])
        var environment = data.get("environment", "")
        if environment is String and !environment.is_empty() and !environments.has(environment):
            _error(report, "Dialogue '%s' refers to missing environment '%s'" % [id, environment])
        var character_id = data.get("character", "")
        if character_id is String and !character_id.is_empty():
            if !characters.has(character_id):
                _error(report, "Dialogue '%s' refers to missing character '%s'" % [id, character_id])
            elif data.has("emotion") and characters[character_id] is Dictionary:
                var emotions = characters[character_id].get("emotions", {})
                if emotions is Dictionary and !emotions.has(data.emotion):
                    _error(report, "Dialogue '%s' has unknown emotion '%s'" % [id, data.emotion])
        elif data.has("character") and data.has("emotion"):
            _error(report, "Dialogue '%s' cannot set emotion on a hidden character" % id)


func _validate_texture(path, label: String, report: Dictionary) -> void:
    if !(path is String) or !path.begins_with("res://") or !ResourceLoader.exists(path, "Texture2D"):
        _error(report, "%s must refer to an existing Texture2D: %s" % [label, path])
