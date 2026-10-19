extends Resource
class_name UpgradeData

@export var id: String
@export var display_name: String
@export var description: String
@export var branch: UpgradeBranch
@export var tier: int
@export var prerequisites: Array[UpgradeData]
@export var levels: Array[UpgradeLevel]

var max_level: int:
	get:
		return levels.size()

func get_level_data(level: int) -> UpgradeLevel:
	if level < 1 or level > levels.size():
		return null
	return levels[level - 1]
