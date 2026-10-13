@tool
extends EditorPlugin

var _main_screen: Control
var _dialogue_list: ItemList
var _search: LineEdit
var _output: RichTextLabel
var _graph: GraphEdit
var _selected_id: LineEdit
var _json_editor: CodeEdit
var _dialogues: Dictionary = {}
var _selected_original_id := ""
var _delete_confirmation: ConfirmationDialog
var _pending_delete_id := ""
var _validator
var _autosave_timer: Timer
var _graph_node_selected_callback: Callable
var _undo_history: Array[Dictionary] = []
var _redo_history: Array[Dictionary] = []
const HISTORY_LIMIT := 100


func _enter_tree() -> void:
    _validator = load("res://addons/dialogue_system/validation/DialogueValidator.gd").new()

    var editor_main_screen := get_editor_interface().get_editor_main_screen()
    for child in editor_main_screen.get_children():
        if str(child.name).begins_with("DialogueMainScreen"):
            child.free()

    _main_screen = HSplitContainer.new()
    _main_screen.name = "DialogueMainScreen"
    _main_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _main_screen.visible = false
    editor_main_screen.add_child(_main_screen)

    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(290, 0)
    _main_screen.add_child(left)

    var title := Label.new()
    title.text = "Dialogue Database"
    title.add_theme_font_size_override("font_size", 24)
    left.add_child(title)

    _search = LineEdit.new()
    _search.placeholder_text = "Search dialogue ID, speaker or text..."
    _search.text_changed.connect(_refresh_dialogue_list)
    left.add_child(_search)

    _dialogue_list = ItemList.new()
    _dialogue_list.custom_minimum_size = Vector2(280, 260)
    _dialogue_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _dialogue_list.item_selected.connect(_on_list_item_selected)
    left.add_child(_dialogue_list)

    var list_actions := HBoxContainer.new()
    left.add_child(list_actions)

    var quick_new_button := Button.new()
    quick_new_button.text = "+ New"
    quick_new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quick_new_button.pressed.connect(_new_node)
    list_actions.add_child(quick_new_button)

    var quick_delete_button := Button.new()
    quick_delete_button.text = "Delete selected"
    quick_delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quick_delete_button.tooltip_text = "Delete selected dialogue node (Delete key)"
    quick_delete_button.pressed.connect(_request_delete_selected_node)
    list_actions.add_child(quick_delete_button)

    var validate_button := Button.new()
    validate_button.text = "Validate JSON"
    validate_button.tooltip_text = "Validate dialogues.json and speakers.json"
    validate_button.pressed.connect(_validate_database)
    left.add_child(validate_button)

    var graph_button := Button.new()
    graph_button.text = "Refresh Graph"
    graph_button.tooltip_text = "Rebuild the visual dialogue graph"
    graph_button.pressed.connect(_rebuild_graph)
    left.add_child(graph_button)

    _output = RichTextLabel.new()
    _output.bbcode_enabled = true
    _output.custom_minimum_size = Vector2(280, 180)
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_child(_output)

    var center := VBoxContainer.new()
    center.custom_minimum_size = Vector2(700, 0)
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _main_screen.add_child(center)

    var graph_title := Label.new()
    graph_title.text = "Попередні репліки → Поточна репліка → Наслідки"
    graph_title.add_theme_font_size_override("font_size", 24)
    center.add_child(graph_title)

    _graph = GraphEdit.new()
    _graph.custom_minimum_size = Vector2(700, 600)
    _graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _graph.show_grid = true
    _graph.show_zoom_label = true
    _graph.minimap_enabled = true
    _graph_node_selected_callback = func(node: Node) -> void:
        if node is GraphNode:
            var line_id: String = str(node.get_meta("dialogue_id", ""))
            if _dialogues.has(line_id) and line_id != _selected_original_id:
                _select_node.call_deferred(line_id)
    _graph.node_selected.connect(_graph_node_selected_callback)
    center.add_child(_graph)

    var inspector := VBoxContainer.new()
    inspector.custom_minimum_size = Vector2(480, 0)
    _main_screen.add_child(inspector)

    var editor_title := Label.new()
    editor_title.text = "Selected dialogue node"
    editor_title.add_theme_font_size_override("font_size", 24)
    inspector.add_child(editor_title)

    _selected_id = LineEdit.new()
    _selected_id.placeholder_text = "Dialogue ID"
    inspector.add_child(_selected_id)

    var hint := Label.new()
    hint.text = "Full node JSON: segments, pauses, tags, colors, choices and transitions"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    inspector.add_child(hint)

    _json_editor = CodeEdit.new()
    _json_editor.custom_minimum_size = Vector2(470, 600)
    _json_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _json_editor.placeholder_text = "Select a graph node to edit its JSON object."
    inspector.add_child(_json_editor)
    _autosave_timer = Timer.new()
    _autosave_timer.one_shot = true
    _autosave_timer.wait_time = 1.0
    _main_screen.add_child(_autosave_timer)
    _autosave_timer.timeout.connect(_autosave_node)
    _json_editor.text_changed.connect(_queue_autosave)
    _selected_id.text_changed.connect(func(_text: String) -> void: _queue_autosave())

    var actions := HBoxContainer.new()
    inspector.add_child(actions)

    var new_button := Button.new()
    new_button.text = "New"
    new_button.pressed.connect(_new_node)
    actions.add_child(new_button)

    var save_button := Button.new()
    save_button.text = "Save"
    save_button.pressed.connect(_save_selected_node)
    actions.add_child(save_button)

    var delete_button := Button.new()
    delete_button.text = "Delete"
    delete_button.tooltip_text = "Delete selected dialogue node (Delete key)"
    delete_button.pressed.connect(_request_delete_selected_node)
    actions.add_child(delete_button)

    _delete_confirmation = ConfirmationDialog.new()
    _delete_confirmation.title = "Delete dialogue line?"
    _delete_confirmation.ok_button_text = "Delete"
    _delete_confirmation.cancel_button_text = "Cancel"
    _delete_confirmation.confirmed.connect(_delete_selected_node)
    _main_screen.add_child(_delete_confirmation)

    _validate_database()
    _rebuild_graph()


func _exit_tree() -> void:
    if _graph and _graph_node_selected_callback.is_valid():
        if _graph.node_selected.is_connected(_graph_node_selected_callback):
            _graph.node_selected.disconnect(_graph_node_selected_callback)
    if _main_screen:
        _main_screen.free()
        _main_screen = null


func _has_main_screen() -> bool:
    return true


func _make_visible(is_visible: bool) -> void:
    if _main_screen:
        _main_screen.visible = is_visible


func _get_plugin_name() -> String:
    return "Dialogue"


func _get_plugin_icon() -> Texture2D:
    return get_editor_interface().get_base_control().get_theme_icon("GraphEdit", "EditorIcons")


func _input(event: InputEvent) -> void:
    if !_main_screen or !_main_screen.visible:
        return
    if !(event is InputEventKey) or !event.pressed or event.echo:
        return
    var focused := _main_screen.get_viewport().gui_get_focus_owner()
    var keycode: int = event.keycode if event.keycode != KEY_NONE else event.physical_keycode

    if event.ctrl_pressed and keycode == KEY_Z:
        # Text fields have their own character-level undo history.
        if focused is LineEdit or focused is TextEdit:
            return
        if event.shift_pressed:
            _redo_dialogue_change()
        else:
            _undo_dialogue_change()
        get_viewport().set_input_as_handled()
        return

    if keycode != KEY_DELETE:
        return
    if focused is LineEdit or focused is TextEdit:
        return

    _request_delete_selected_node()
    get_viewport().set_input_as_handled()


func _validate_database() -> void:
    var report: Dictionary = _validator.validate_files(
        "res://jsons/dialogues.json",
        "res://jsons/speakers.json"
    )
    _output.clear()

    var errors: Array = report.errors
    var warnings: Array = report.warnings
    var color := "#72d572" if errors.is_empty() else "#ff6961"
    _output.append_text(
        "[color=%s][b]%d error(s), %d warning(s)[/b][/color]\n\n"
        % [color, errors.size(), warnings.size()]
    )
    for message in errors:
        _output.append_text("[color=#ff6961]ERROR[/color] %s\n\n" % _escape_bbcode(str(message)))
    for message in warnings:
        _output.append_text("[color=#e8b84a]WARNING[/color] %s\n\n" % _escape_bbcode(str(message)))

    print(_validator.format_report(report))


func _escape_bbcode(value: String) -> String:
    return value.replace("[", "[lb]")


func _rebuild_graph() -> void:
    _dialogues = _load_dialogues()
    _refresh_dialogue_list()
    if !_dialogues.has(_selected_original_id):
        var ids := _dialogues.keys()
        ids.sort()
        _selected_original_id = str(ids[0]) if !ids.is_empty() else ""
    if !_selected_original_id.is_empty():
        _load_node_in_inspector(_selected_original_id)
    _render_neighborhood()


func _render_neighborhood() -> void:
    _graph.clear_connections()
    for child in _graph.get_children():
        if child is GraphNode:
            _graph.remove_child(child)
            child.queue_free()

    var line_id := _selected_original_id
    if !_dialogues.has(line_id) or !(_dialogues[line_id] is Dictionary):
        return
    var incoming := _find_incoming_references(line_id)
    var outgoing := _line_targets(_dialogues[line_id])
    _add_context_node("current", line_id, Vector2(400, 0), "Поточна")
    for index in incoming.size():
        var view_id := "incoming_%d" % index
        _add_context_node(view_id, incoming[index],
            Vector2(0, (index - (incoming.size() - 1) / 2.0) * 190), "Попередня")
        _graph.connect_node(view_id, 0, "current", 0)
    for index in outgoing.size():
        var view_id := "outgoing_%d" % index
        _add_context_node(view_id, outgoing[index],
            Vector2(800, (index - (outgoing.size() - 1) / 2.0) * 190), "Наслідок")
        _graph.connect_node("current", 0, view_id, 0)
    _center_context.call_deferred()


func _add_context_node(view_id: String, line_id: String, position: Vector2, role: String) -> void:
    var graph_node := GraphNode.new()
    graph_node.draggable = false
    graph_node.name = view_id
    graph_node.set_meta("dialogue_id", line_id)
    graph_node.title = "%s: %s" % [role, line_id]
    graph_node.position_offset = position
    var summary := Label.new()
    summary.custom_minimum_size = Vector2(280, 80)
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var line = _dialogues.get(line_id)
    summary.text = _line_summary(line) if line is Dictionary else "Репліку не знайдено"
    if !(line is Dictionary):
        graph_node.modulate = Color("#ff6961")
    graph_node.add_child(summary)
    graph_node.set_slot(0, true, 0, Color("#8b8175"), true, 0, Color("#d6b36a"))
    _graph.add_child(graph_node)
    graph_node.selected = view_id == "current"


func _center_context() -> void:
    var node := _graph.get_node_or_null("current") as GraphNode
    if node:
        _graph.scroll_offset = (node.position_offset + node.size / 2.0) * _graph.zoom - _graph.size / 2.0


func _load_dialogues() -> Dictionary:
    var path := "res://jsons/dialogues.json"
    if !FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}


func _line_summary(line: Dictionary) -> String:
    var speaker := str(line.get("speaker", "Narrator"))
    var text := ""
    var segments = line.get("segments", [])
    if segments is Array:
        for segment in segments:
            if segment is Dictionary:
                text += str(segment.get("text", ""))
    if text.length() > 110:
        text = text.left(107) + "..."
    return "%s\n%s" % [speaker, text]


func _line_targets(line: Dictionary) -> Array[String]:
    var targets: Array[String] = []
    for field in ["next", "ignore"]:
        var target := str(line.get(field, ""))
        if !target.is_empty() and !targets.has(target):
            targets.append(target)
    for field in ["interrupt_choices", "choices"]:
        var choices = line.get(field, [])
        if choices is Array:
            for choice in choices:
                if choice is Dictionary:
                    var target := str(choice.get("next", ""))
                    if !target.is_empty() and !targets.has(target):
                        targets.append(target)
    return targets


func _on_graph_node_selected(node: Node) -> void:
    if !(node is GraphNode) or !_dialogues.has(node.name):
        return
    _load_node_in_inspector(str(node.name))


func _new_node() -> void:
    if !_autosave_timer.is_stopped():
        _autosave_node()
    _autosave_timer.stop()
    _selected_original_id = ""
    _selected_id.text = _unique_id("new_dialogue")
    _json_editor.text = JSON.stringify({
        "speaker": "narrator",
        "segments": [{"text": "New dialogue line", "speed": 30}],
        "interrupt_choices": [],
        "choices": [],
        "next": "",
    }, "\t", false)
    _json_editor.grab_focus()


func _queue_autosave() -> void:
    _autosave_timer.start()


func _autosave_node() -> void:
    var parser := JSON.new()
    if _selected_id.text.strip_edges().is_empty():
        return
    # Incomplete JSON is normal while typing; keep it in the editor.
    if parser.parse(_json_editor.text) != OK or !(parser.data is Dictionary):
        return
    _save_selected_node(true)


func _save_selected_node(autosave := false) -> void:
    _autosave_timer.stop()
    if !_can_safely_write():
        return

    var line_id := _selected_id.text.strip_edges()
    if line_id.is_empty():
        _show_editor_error("Dialogue ID cannot be empty.")
        return

    var parser := JSON.new()
    if parser.parse(_json_editor.text) != OK or !(parser.data is Dictionary):
        _show_editor_error(
            "Selected node must be a JSON object: %s" % parser.get_error_message()
        )
        return

    var before: Dictionary = _dialogues.duplicate(true)
    var previous_selection := _selected_original_id

    if line_id != _selected_original_id and _dialogues.has(line_id):
        _show_editor_error("Dialogue '%s' already exists." % line_id)
        return
    if line_id == _selected_original_id and _dialogues.get(line_id) == parser.data:
        return

    if !_selected_original_id.is_empty() and _selected_original_id != line_id:
        if _dialogues.has(line_id):
            _show_editor_error("Dialogue '%s' already exists." % line_id)
            return
        _dialogues.erase(_selected_original_id)
        _rename_all_targets(_selected_original_id, line_id)

    _dialogues[line_id] = parser.data
    if !_write_dialogues():
        _dialogues = before
        return

    _record_history(before, _dialogues, previous_selection, line_id)
    _validate_database()
    if autosave:
        _selected_original_id = line_id
        _refresh_dialogue_list()
        _render_neighborhood()
        return
    _rebuild_graph()
    _select_node(line_id)


func _request_delete_selected_node() -> void:
    if !_can_safely_write():
        return

    _pending_delete_id = (
        _selected_original_id
        if !_selected_original_id.is_empty()
        else _selected_id.text.strip_edges()
    )
    if !_dialogues.has(_pending_delete_id):
        _show_editor_error("Select a dialogue node to delete.")
        return

    var incoming := _find_incoming_references(_pending_delete_id)
    var details := "Delete dialogue '%s'?" % _pending_delete_id
    if !incoming.is_empty():
        details += "\n\n%d dialogue(s) refer to it:\n%s" % [
            incoming.size(),
            ", ".join(incoming.slice(0, 8)),
        ]
        if incoming.size() > 8:
            details += "\n…and %d more" % (incoming.size() - 8)
        details += "\n\nThose references will become validation errors."
    _delete_confirmation.dialog_text = details
    _delete_confirmation.popup_centered(Vector2i(520, 300))


func _delete_selected_node() -> void:
    var line_id := _pending_delete_id
    _pending_delete_id = ""
    if line_id.is_empty() or !_dialogues.has(line_id):
        return

    var before: Dictionary = _dialogues.duplicate(true)
    _dialogues.erase(line_id)
    if !_write_dialogues():
        _dialogues = before
        return

    _record_history(before, _dialogues, line_id, "")
    _selected_id.clear()
    _json_editor.clear()
    _selected_original_id = ""
    _validate_database()
    _rebuild_graph()


func _find_incoming_references(target_id: String) -> Array[String]:
    var incoming: Array[String] = []
    for line_id in _dialogues:
        var line = _dialogues[line_id]
        if line is Dictionary and target_id in _line_targets(line):
            incoming.append(str(line_id))
    incoming.sort()
    return incoming


func _can_safely_write() -> bool:
    var report: Dictionary = _validator.validate_files(
        "res://jsons/dialogues.json",
        "res://jsons/speakers.json"
    )
    for message in report.errors:
        if "duplicate root key" in str(message):
            _show_editor_error(
                "Saving is blocked because duplicate dialogue IDs would be lost. "
                + "Resolve duplicate keys in JSON first."
            )
            return false
    return true


func _write_dialogues() -> bool:
    var file := FileAccess.open("res://jsons/dialogues.json", FileAccess.WRITE)
    if !file:
        _show_editor_error("Cannot write res://jsons/dialogues.json")
        return false
    file.store_string(JSON.stringify(_dialogues, "  ", false) + "\n")
    file.close()
    get_editor_interface().get_resource_filesystem().scan()
    return true


func _record_history(
    before: Dictionary,
    after: Dictionary,
    selection_before: String,
    selection_after: String
) -> void:
    _undo_history.append({
        "before": before.duplicate(true),
        "after": after.duplicate(true),
        "selection_before": selection_before,
        "selection_after": selection_after,
    })
    if _undo_history.size() > HISTORY_LIMIT:
        _undo_history.pop_front()
    _redo_history.clear()


func _undo_dialogue_change() -> void:
    if _undo_history.is_empty():
        return
    var change: Dictionary = _undo_history.pop_back()
    if _restore_history_state(change.before, str(change.selection_before)):
        _redo_history.append(change)
    else:
        _undo_history.append(change)


func _redo_dialogue_change() -> void:
    if _redo_history.is_empty():
        return
    var change: Dictionary = _redo_history.pop_back()
    if _restore_history_state(change.after, str(change.selection_after)):
        _undo_history.append(change)
    else:
        _redo_history.append(change)


func _restore_history_state(state: Dictionary, selected_line_id: String) -> bool:
    var current: Dictionary = _dialogues
    _dialogues = state.duplicate(true)
    if !_write_dialogues():
        _dialogues = current
        return false

    _validate_database()
    _rebuild_graph()
    if !selected_line_id.is_empty() and _dialogues.has(selected_line_id):
        _select_node(selected_line_id)
    else:
        _selected_id.clear()
        _json_editor.clear()
        _selected_original_id = ""
    return true


func _unique_id(base: String) -> String:
    var candidate := base
    var suffix := 1
    while _dialogues.has(candidate):
        candidate = "%s_%d" % [base, suffix]
        suffix += 1
    return candidate


func _select_node(line_id: String) -> void:
    if !_autosave_timer.is_stopped():
        _autosave_node()
    if !_dialogues.has(line_id):
        return
    _load_node_in_inspector(line_id)
    _render_neighborhood()


func _refresh_dialogue_list(_query := "") -> void:
    if !_dialogue_list:
        return

    _dialogue_list.clear()
    var query := _search.text.strip_edges().to_lower() if _search else ""
    var ids := _dialogues.keys()
    ids.sort()

    for line_id in ids:
        var line = _dialogues[line_id]
        var searchable := str(line_id).to_lower()
        if line is Dictionary:
            searchable += " " + str(line.get("speaker", "")).to_lower()
            searchable += " " + _line_summary(line).to_lower()
        if !query.is_empty() and !searchable.contains(query):
            continue
        _dialogue_list.add_item(str(line_id))
        _dialogue_list.set_item_metadata(_dialogue_list.item_count - 1, str(line_id))


func _on_list_item_selected(index: int) -> void:
    var line_id := str(_dialogue_list.get_item_metadata(index))
    _select_node(line_id)


func _load_node_in_inspector(line_id: String) -> void:
    _autosave_timer.stop()
    if !_dialogues.has(line_id):
        return
    _selected_original_id = line_id
    _selected_id.text = line_id
    _json_editor.text = JSON.stringify(_dialogues[line_id], "\t", false)


func _rename_all_targets(old_id: String, new_id: String) -> void:
    for line_id in _dialogues:
        var line = _dialogues[line_id]
        if !(line is Dictionary):
            continue
        for field in ["next", "ignore"]:
            if str(line.get(field, "")) == old_id:
                line[field] = new_id
        for field in ["interrupt_choices", "choices"]:
            var choices = line.get(field, [])
            if choices is Array:
                for choice in choices:
                    if choice is Dictionary and str(choice.get("next", "")) == old_id:
                        choice["next"] = new_id


func _show_editor_error(message: String) -> void:
    _output.append_text("\n[color=#ff6961][b]EDITOR ERROR[/b][/color] %s\n" % _escape_bbcode(message))
    push_error(message)
