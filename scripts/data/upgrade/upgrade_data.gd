extends Resource
class_name UpgradeData

@export var id: String
@export var display_name: String
@export var description: String
@export var cost: int
@export var branch: UpgradeBranch
@export var tier: int
@export var prerequisites: Array[UpgradeData]
@export var effects: Array[UpgradeEffect]
