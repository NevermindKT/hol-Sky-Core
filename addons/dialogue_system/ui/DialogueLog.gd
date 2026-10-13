extends Control

class_name DialogueLog

signal open_state_changed(is_open: bool)

@export var entries_label: RichTextLabel
@export var open_button: Button
@export var close_button: Button

var entries: Array[Dictionary] = []


func _ready() -> void:
    if open_button:
        open_button.pressed.connect(toggle)
    if close_button:
        close_button.pressed.connect(close)

    visible = false


func add_line(
    line_id: String,
    speaker_name: String,
    speaker_color: Color,
    dialogue_text: String
) -> void:
    entries.append({
        "line_id": line_id,
        "speaker": speaker_name,
        "color": speaker_color,
        "text": dialogue_text,
    })
    _render_entries()


func clear_log() -> void:
    entries.clear()
    _render_entries()


func open() -> void:
    visible = true
    open_state_changed.emit(true)


func close() -> void:
    visible = false
    open_state_changed.emit(false)


func toggle() -> void:
    if visible:
        close()
    else:
        open()


func _render_entries() -> void:
    if !entries_label:
        return

    entries_label.clear()

    for index in entries.size():
        var entry: Dictionary = entries[index]
        var speaker := _escape_bbcode(str(entry.speaker))
        var text := _escape_bbcode(str(entry.text))
        var color: Color = entry.color

        if !speaker.strip_edges().is_empty():
            entries_label.append_text(
                "[font_size=25][outline_color=#%s][color=#%s][b]%s[/b][/color][/outline_color][/font_size]\n"
                % [color.to_html(false), color.to_html(false), speaker]
            )

        entries_label.append_text("[font_size=28]%s[/font_size]" % text)

        if index < entries.size() - 1:
            entries_label.append_text("\n[outline_color=#706b63][color=#706b63]────────────────────[/color][/outline_color]\n")

    await get_tree().process_frame
    entries_label.scroll_to_line(max(entries_label.get_line_count() - 1, 0))


func _escape_bbcode(value: String) -> String:
    return value.replace("[", "[lb]")
