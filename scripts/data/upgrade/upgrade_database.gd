extends Resource
class_name UpgradeDatabase

@export var upgrades: Array[UpgradeData]


static func from_json(path: String) -> UpgradeDatabase:
	var database := UpgradeDatabase.new()
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not rows is Array:
		push_error("Invalid upgrade catalog: " + path)
		return database
	var by_id: Dictionary = {}
	var branches: Dictionary = {}
	for row in rows:
		var upgrade := UpgradeData.new()
		upgrade.id = str(row["id"])
		upgrade.display_name = str(row.get("name", ""))
		upgrade.description = str(row.get("description", ""))
		upgrade.tier = int(row.get("tier", 0))
		var branch_name := str(row.get("branch", ""))
		if not branch_name.is_empty():
			if not branches.has(branch_name):
				var branch := UpgradeBranch.new()
				branch.display_name = branch_name
				branches[branch_name] = branch
			upgrade.branch = branches[branch_name]
		for entry in row["levels"]:
			var level := UpgradeLevel.new()
			level.cost = int(entry["cost"])
			level.description = str(entry.get("description", ""))
			for spec in entry["effects"]:
				var effect := StatMultiplierEffect.new()
				effect.stat_id = StringName(str(spec["stat_id"]))
				effect.operation = int(spec.get("operation", 0))
				effect.multiplier = float(spec.get("multiplier", 1.0))
				level.effects.append(effect)
			upgrade.levels.append(level)
		by_id[upgrade.id] = upgrade
		database.upgrades.append(upgrade)
	for row in rows:
		for prerequisite_id in row.get("prerequisites", []):
			if not by_id.has(prerequisite_id):
				push_error("Unknown upgrade prerequisite: " + str(prerequisite_id))
				return UpgradeDatabase.new()
			by_id[row["id"]].prerequisites.append(by_id[prerequisite_id])
	return database
