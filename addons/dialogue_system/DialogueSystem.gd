extends CanvasLayer

class_name DialogueSystem

const FONT_FIT := preload("res://addons/dialogue_system/ui/DialogueFontFit.gd")

signal dialogue_started(entry_id: String)
signal dialogue_finished(entry_id: String, result: DialogueResult)
signal dialogue_cancelled(entry_id: String)
signal dialogue_paused
signal dialogue_resumed
signal database_validation_finished(report: Dictionary)

signal line_started(line_id: String)
signal line_finished(line_id: String, result: DialogueResult)

signal choice_selected(
	line_id: String,
	choice_id: String,
	target_id: String,
	event_id: String
)
signal branch_reached(event_id: String)

@export_file("*.json") var dialogues_path := ""
@export_file("*.json") var speakers_path := ""

@export_file("*.json") var visuals_path := ""
@export var background: TextureRect
@export var footer: TextureRect
@export var character: TextureRect

var _visuals: Dictionary = {}
var _character_id := ""

@export var typer: TextTyper
@export var timeline: DialogueTimeline
@export var choice_manager: ChoiceManager
@export var name_label: RichTextLabel
@export var dialogue_log: DialogueLog
@export var dialogue_style: DialogueStyle

var dialogue_repository := DialogueRepository.new()
var speaker_repository := SpeakerRepository.new()

var _loader := JsonLoader.new()
var _validator := DialogueValidator.new()
var last_validation_report := {"errors": [], "warnings": []}
var _active := false
var _entry_id := ""
var _session := 0
var _pause_reasons: Dictionary = {}
var _tree_was_paused := false
var _waiting_for_advance := false
var _current_line: DialogueLine


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or !is_node_ready():
		return
	if _current_line != null:
		_show_speaker(_current_line)
	if dialogue_log:
		for entry in dialogue_log.entries:
			var line: DialogueLine = dialogue_repository.try_get(entry.line_id)
			if line == null:
				continue
			entry.text = line.full_text()
			var speaker: DialogueSpeaker = speaker_repository.try_get(line.speaker)
			entry.speaker = speaker.name if speaker else line.speaker
		dialogue_log._render_entries()


func _ready() -> void:
	if name_label:
		name_label.resized.connect(_fit_speaker_name)

	timeline.configure(dialogue_style)
	choice_manager.configure(dialogue_style)

	if dialogue_log:
		dialogue_log.open_state_changed.connect(_on_log_open_state_changed)

	reload_database()
	clear_visuals()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:

	if !_active or !_waiting_for_advance or is_paused() or get_tree().paused:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		if typer.is_typing():
			typer.accelerate()
		else:
			_waiting_for_advance = false


func reload_database() -> bool:

	dialogue_repository.clear()
	speaker_repository.clear()

	if dialogues_path.is_empty() or speakers_path.is_empty():
		return false

	last_validation_report = _validator.validate_files(
		dialogues_path,
		speakers_path,
		visuals_path
	)
	database_validation_finished.emit(last_validation_report)

	for message in last_validation_report.errors:
		push_error("Dialogue validation: %s" % message)
	for message in last_validation_report.warnings:
		push_warning("Dialogue validation: %s" % message)

	if !last_validation_report.errors.is_empty():
		return false

	_visuals = _loader.load_json(visuals_path) if !visuals_path.is_empty() else {}
	var speakers := _loader.load_json(speakers_path)
	var dialogues := _loader.load_json(dialogues_path)

	if speakers.is_empty() or dialogues.is_empty():
		return false

	# The full cross-file validator already ran above, so avoid emitting the
	# repositories' legacy subset of the same errors a second time.
	speaker_repository.from_dictionary(speakers, false)
	dialogue_repository.from_dictionary(dialogues, false)
	return true


func is_running() -> bool:

	return _active


func is_paused() -> bool:

	return !_pause_reasons.is_empty()


func pause_dialogue(reason := "manual") -> void:

	if reason.is_empty() or _pause_reasons.has(reason):
		return

	if _pause_reasons.is_empty():
		_tree_was_paused = get_tree().paused

	_pause_reasons[reason] = true
	get_tree().paused = true
	dialogue_paused.emit()


func resume_dialogue(reason := "manual") -> void:

	if !_pause_reasons.erase(reason):
		return

	if !_pause_reasons.is_empty():
		return

	get_tree().paused = _tree_was_paused
	_tree_was_paused = false
	dialogue_resumed.emit()


func toggle_pause() -> void:

	if _pause_reasons.has("manual"):
		resume_dialogue("manual")
	else:
		pause_dialogue("manual")


func start_dialogue(entry_id: String) -> DialogueResult:

	if _active:
		push_warning(
			"Cannot start dialogue '%s': dialogue '%s' is already running."
			% [entry_id, _entry_id]
		)
		return DialogueResult.cancelled()

	if !dialogue_repository.has(entry_id):
		push_error("Dialogue '%s' not found." % entry_id)
		return DialogueResult.end()

	_active = true
	_entry_id = entry_id
	_session += 1
	var session := _session
	var current := entry_id
	var result := DialogueResult.end()

	dialogue_started.emit(entry_id)

	while _active and session == _session and !current.is_empty():
		result = await _play_line(current, session)

		if !_active or session != _session:
			return DialogueResult.cancelled()

		match result.type:
			DialogueResult.Type.NEXT, DialogueResult.Type.IGNORE:
				current = result.event
			DialogueResult.Type.CHOICE:
				current = result.choice.next
			_:
				current = ""

	_active = false
	_entry_id = ""
	_clear_presentation()
	dialogue_finished.emit(entry_id, result)
	return result


func play(line_id: String) -> DialogueResult:

	if _active:
		push_warning("Cannot play a line while another dialogue is running.")
		return DialogueResult.cancelled()

	if !dialogue_repository.has(line_id):
		push_error("Dialogue '%s' not found." % line_id)
		return DialogueResult.end()

	_active = true
	_entry_id = line_id
	_session += 1
	var session := _session
	dialogue_started.emit(line_id)

	var result := await _play_line(line_id, session)

	if !_active or session != _session:
		return DialogueResult.cancelled()

	_active = false
	_entry_id = ""
	_clear_presentation()
	dialogue_finished.emit(line_id, result)
	return result


func stop_dialogue() -> void:

	if !_active:
		return

	var cancelled_entry := _entry_id
	_clear_pause_reasons()
	_active = false
	_entry_id = ""
	_session += 1

	choice_manager.cancel()
	_clear_presentation()
	dialogue_cancelled.emit(cancelled_entry)


func _play_line(line_id: String, session: int) -> DialogueResult:

	var line: DialogueLine = dialogue_repository.try_get(line_id)

	if line == null:
		push_error("Dialogue '%s' not found." % line_id)
		return DialogueResult.end()

	_apply_presentation(line.presentation)
	_current_line = line
	line_started.emit(line_id)

	if !line.event.is_empty():
		branch_reached.emit(line.event)

	_show_speaker(line)
	_add_line_to_log(line)
	choice_manager.start(line)
	_waiting_for_advance = !line.requires_choice()
	typer.play(line.segments, line.speaker)

	if line.requires_choice():
		timeline.play(line.interrupt_time, line.choice_time)
		var choice: DialogueChoice = await choice_manager.finished

		if !_active or session != _session:
			return DialogueResult.cancelled()

		_stop_line()

		var choice_result: DialogueResult

		if choice != null:
			choice_selected.emit(
				line.id,
				choice.id,
				choice.next,
				choice.event
			)

			if !choice.event.is_empty():
				branch_reached.emit(choice.event)

			choice_result = DialogueResult.choice_result(choice)
		elif line.has_ignore():
			choice_result = DialogueResult.ignore(line.ignore)
		else:
			choice_result = DialogueResult.end()

		line_finished.emit(line_id, choice_result)
		return choice_result

	while _waiting_for_advance and _active and session == _session:
		await get_tree().process_frame

	if !_active or session != _session:
		return DialogueResult.cancelled()

	_stop_line()

	var result := (
		DialogueResult.next(line.next)
		if line.has_next()
		else DialogueResult.end()
	)

	line_finished.emit(line_id, result)
	return result


func _stop_line() -> void:

	_waiting_for_advance = false
	typer.stop()
	timeline.stop()
	choice_manager.stop()


func _clear_presentation() -> void:
	_current_line = null

	_stop_line()
	typer.clear_text()

	if name_label:
		name_label.clear()


func _on_log_open_state_changed(is_open: bool) -> void:

	if is_open:
		pause_dialogue("log")
	else:
		resume_dialogue("log")


func _clear_pause_reasons() -> void:

	if _pause_reasons.is_empty():
		return

	_pause_reasons.clear()
	get_tree().paused = _tree_was_paused
	_tree_was_paused = false
	dialogue_resumed.emit()


func _show_speaker(line: DialogueLine) -> void:

	if !name_label:
		return

	if line.speaker.is_empty():
		name_label.clear()
		return

	var speaker: DialogueSpeaker = speaker_repository.try_get(line.speaker)

	if speaker == null:
		name_label.text = line.speaker
		_fit_speaker_name()
		return

	name_label.bbcode_enabled = true
	name_label.clear()
	name_label.append_text(
		"[outline_color=%s][color=%s]%s[/color][/outline_color]" % [speaker.color, speaker.color, speaker.name]
	)
	_fit_speaker_name()


func _fit_speaker_name() -> void:
	if name_label:
		FONT_FIT.fit(name_label, name_label.text, 40)


func _add_line_to_log(line: DialogueLine) -> void:

	if !dialogue_log:
		return

	var speaker_name := line.speaker
	var speaker_color := Color.WHITE
	var speaker: DialogueSpeaker = speaker_repository.try_get(line.speaker)

	if speaker:
		speaker_name = speaker.name
		speaker_color = Color.from_string(speaker.color, Color.WHITE)

	dialogue_log.add_line(
		line.id,
		speaker_name,
		speaker_color,
		line.full_text()
	)


## Visuals persist between lines and after dialogue completion.
func clear_visuals() -> void:
	_character_id = ""
	for layer in [background, footer, character]:
		if layer:
			layer.texture = null
			layer.hide()


func _apply_presentation(presentation: Dictionary) -> void:
	if presentation.has("environment"):
		var environment_id: String = presentation.environment
		if environment_id.is_empty():
			_set_texture(background, null)
			_set_texture(footer, null)
		else:
			var environment: Dictionary = _visuals.get("environments", {}).get(environment_id, {})
			# Load both resources before replacing either layer.
			var bg := load(str(environment.get("background", ""))) as Texture2D
			var fg := load(str(environment.get("footer", ""))) as Texture2D
			if bg and fg:
				_set_texture(background, bg)
				_set_texture(footer, fg)

	if presentation.has("character"):
		_character_id = presentation.character
	if presentation.has("character") or presentation.has("emotion"):
		if _character_id.is_empty():
			_set_texture(character, null)
			return
		var data: Dictionary = _visuals.get("characters", {}).get(_character_id, {})
		var emotion: String = presentation.get("emotion", data.get("default_emotion", ""))
		var path: String = data.get("emotions", {}).get(emotion, "")
		if !path.is_empty():
			_set_texture(character, load(path) as Texture2D)
		else:
			push_error("Unknown emotion '%s' for character '%s'." % [emotion, _character_id])


func _set_texture(layer: TextureRect, texture: Texture2D) -> void:
	if layer:
		layer.texture = texture
		layer.visible = texture != null
		if layer == character:
			var glow := character.get_node_or_null("Glow") as TextureRect
			if glow:
				glow.texture = texture
				glow.visible = texture != null
