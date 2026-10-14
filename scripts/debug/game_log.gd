class_name GameLog

const SETTING := "game/debug/logs"

static var enabled: bool = ProjectSettings.get_setting(SETTING, false)


static func print(...args: Array) -> void:
	if not enabled:
		return
	var parts := PackedStringArray()
	for arg in args:
		parts.append(str(arg))
	printraw("".join(parts) + "\n")
