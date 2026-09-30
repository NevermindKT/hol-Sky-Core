extends CanvasLayer
class_name Debug_Overlay

@onready var label: RichTextLabel = $DebugLabel

@export var toggle_action: String = "toggle_debug" # добавь в Input Map, либо замени на прямую проверку клавиши
@export var update_interval: float = 0.25

var _time_since_update := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(toggle_action):
		visible = not visible

	if not visible:
		return

	_time_since_update += delta
	if _time_since_update < update_interval:
		return
	_time_since_update = 0.0

	_update_stats()


func _update_stats() -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var cpu_frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var render_ms := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var video_mem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var static_mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	var object_count := Performance.get_monitor(Performance.OBJECT_COUNT)
	var node_count := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	label.text = (
		"[b]FPS:[/b] %d\n" +
		"[b]CPU (process):[/b] %.2f ms\n" +
		"[b]Physics:[/b] %.2f ms\n" +
		"[b]Draw calls:[/b] %d\n" +
		"[b]Primitives:[/b] %d\n" +
		"[b]VRAM:[/b] %.1f MB\n" +
		"[b]RAM (static):[/b] %.1f MB\n" +
		"[b]Objects / Nodes:[/b] %d / %d"
	) % [
		fps, cpu_frame_ms, physics_ms, draw_calls, primitives,
		video_mem / 1048576.0, static_mem / 1048576.0,
		object_count, node_count
	]
