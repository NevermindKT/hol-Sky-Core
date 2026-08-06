extends VBoxContainer
class_name Progress_bar

@onready var level_progress_bar: ProgressBar = $LevelProgressBar


func _ready():
	Events.level_progress_changed.connect(update_progress)


func update_progress(current: float, max_distance: float):
	level_progress_bar.value = (current / max_distance) * 100.0
