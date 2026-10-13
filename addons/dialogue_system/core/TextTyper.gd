extends RichTextLabel

class_name TextTyper

signal typing_started
signal typing_finished

signal segment_started(segment: DialogueSegment)
signal segment_finished(segment: DialogueSegment)

signal character_typed(character: String)

@export var typing_sound: AudioStream
@export_dir var speaker_sounds_path := "res://assets/dialogue_sounds"
@export_range(-40.0, 6.0, 1.0) var typing_volume_db := -12.0

var _letter_pattern := RegEx.new()
var _typing_audio: AudioStreamPlayer
var _speaker_sound_cache: Dictionary = {}
const SOUND_INTERVAL_USEC := 50000
var _last_sound_usec := -SOUND_INTERVAL_USEC


func _ready() -> void:
    _letter_pattern.compile("^\\p{L}$")
    _typing_audio = AudioStreamPlayer.new()
    _typing_audio.stream = typing_sound
    _typing_audio.volume_db = typing_volume_db
    _typing_audio.max_polyphony = 1
    add_child(_typing_audio)
    character_typed.connect(_on_character_typed)


func _on_character_typed(character: String) -> void:
    if _typing_audio.stream and _letter_pattern.search(character):
        var now := Time.get_ticks_usec()
        if now - _last_sound_usec < SOUND_INTERVAL_USEC:
            return
        _last_sound_usec = now
        _typing_audio.stop()
        _typing_audio.play()


func set_speaker(speaker_id: String) -> void:
    _typing_audio.stop()
    _typing_audio.stream = typing_sound
    if speaker_id.is_empty() or !speaker_id.is_valid_filename():
        return
    if _speaker_sound_cache.has(speaker_id):
        _typing_audio.stream = _speaker_sound_cache[speaker_id]
        return
    for extension in ["wav", "ogg", "mp3"]:
        var path := speaker_sounds_path.path_join("%s.%s" % [speaker_id, extension])
        if !ResourceLoader.exists(path, "AudioStream"):
            continue
        var sound := load(path) as AudioStream
        if sound:
            _speaker_sound_cache[speaker_id] = sound
            _typing_audio.stream = sound
            return


enum State {
    BEFORE,
    TYPING,
    AFTER
}


var _segments: Array[DialogueSegment] = []

var _segment_index := 0
var _character_index := 0

var _typing := false

var _state := State.BEFORE
var _timer := 0.0
var _type_accumulator := 0.0
var _speed_override := 0.0


func play(segments: Array[DialogueSegment], speaker_id := "") -> void:

    clear_text()
    set_speaker(speaker_id)

    _segments = segments.duplicate()

    if _segments.is_empty():

        typing_finished.emit()
        return

    _typing = true

    typing_started.emit()

    _segment_index = 0

    _start_segment()


func stop() -> void:

    _typing = false
    if _typing_audio:
        _typing_audio.stop()


func finish_immediately() -> void:

    if _typing_audio:
        _typing_audio.stop()
    _finish()


func accelerate() -> void:
    if _typing and _speed_override == 0.0:
        _speed_override = 120.0
        _type_accumulator = 0.0
        _timer = 0.0
        if _state == State.BEFORE:
            _state = State.TYPING
        elif _state == State.AFTER:
            _segment_index += 1
            _start_segment()


func clear_text() -> void:

    stop()
    clear()

    _segments.clear()

    _segment_index = 0
    _character_index = 0

    _typing = false

    _timer = 0.0
    _type_accumulator = 0.0
    _speed_override = 0.0

    _state = State.BEFORE


func is_typing() -> bool:

    return _typing


func _process(delta: float) -> void:

    if !_typing:
        return

    if _segment_index >= _segments.size():

        _finish()
        return

    var segment := _segments[_segment_index]

    match _state:

        State.BEFORE:

            _timer -= delta

            if _timer <= 0.0:

                _state = State.TYPING

        State.TYPING:

            _type_accumulator += delta

            var speed := _speed_override if _speed_override > 0.0 else segment.speed
            var interval = 1.0 / max(speed, 0.01)

            while _type_accumulator >= interval:

                _type_accumulator -= interval

                if _character_index < segment.text.length():

                    character_typed.emit(
                        segment.text[_character_index]
                    )

                    _character_index += 1

                    _render()

                if _character_index >= segment.text.length():

                    segment_finished.emit(segment)

                    if _segment_index == _segments.size() - 1:
                        _finish()
                        return

                    if _speed_override > 0.0:
                        _segment_index += 1
                        _start_segment()
                    else:
                        _state = State.AFTER
                        _timer = segment.after_pause

                    break

        State.AFTER:

            _timer -= delta

            if _timer <= 0.0:

                _segment_index += 1

                if _segment_index >= _segments.size():

                    _finish()

                else:

                    _start_segment()


func _start_segment() -> void:

    _character_index = 0
    _type_accumulator = 0.0

    var segment := _segments[_segment_index]

    segment_started.emit(segment)

    _timer = 0.0 if _speed_override > 0.0 else segment.before_pause

    if _timer > 0.0:

        _state = State.BEFORE

    else:

        _state = State.TYPING

    _render()


func _render() -> void:

    var result := ""

    for i in range(_segment_index):

        result += _segments[i].to_bbcode()

    if _segment_index < _segments.size():

        result += _segments[_segment_index].to_bbcode(
            _character_index
        )

    text = result


func _render_full() -> void:

    var result := ""

    for segment in _segments:

        result += segment.to_bbcode()

    text = result


func _finish() -> void:

    if !_typing:
        return

    _typing = false

    _render_full()

    typing_finished.emit()
