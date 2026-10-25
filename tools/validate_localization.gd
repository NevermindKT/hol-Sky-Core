extends SceneTree


func _init() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var segment := DialogueSegment.new({"text": "Віктор"})
	var choice := DialogueChoice.new({"text": "Віктор", "next": "intro_line5.1"})
	var speaker := DialogueSpeaker.new("viktor", {"name": "Віктор"})
	var menu: CanvasLayer = load("res://scenes/general/settings.tscn").instantiate()
	root.add_child(menu)
	var dialogue: DialogueSystem = load("res://addons/dialogue_system/DialogueSystem.tscn").instantiate()
	root.add_child(dialogue)
	await process_frame
	assert(menu.language_option.item_count == 3)
	var line: DialogueLine = dialogue.dialogue_repository.try_get("intro_line2")
	dialogue._current_line = line
	dialogue._add_line_to_log(line)
	dialogue.typer.play(line.segments)
	dialogue.typer.finish_immediately()
	# Compile the modified UI consumers without loading the full world.
	for path in ["scripts/menu/inventory/Inventory.gd", "scripts/menu/map/map_main.gd",
			"scripts/menu/shop/Shop.gd", "scripts/menu/turret/turret.gd",
			"scripts/ui/run_summary_menu.gd"]:
		assert(load("res://" + path).can_instantiate(), path)
	for locale in ["uk", "en", "ru"]:
		var translation := load("res://localization/%s.po" % locale) as Translation
		assert(translation != null, "Cannot load translation: " + locale)
		TranslationServer.add_translation(translation)
		TranslationServer.set_locale(locale)
		var expected: String = {"uk": "Віктор", "en": "Viktor", "ru": "Виктор"}[locale]
		assert(segment.text == expected, "Segment: " + locale + " got " + segment.text)
		assert(choice.text == expected, "Choice: " + locale)
		assert(speaker.name == expected, "Speaker: " + locale)
		assert(choice.next == "intro_line5.1")
		assert(segment.to_bbcode(2) == expected.substr(0, 2))
		root.get_node("Settings").set_language(locale)
		await process_frame
		var expected_title: String = {"uk": "НАЛАШТУВАННЯ", "en": "SETTINGS", "ru": "НАСТРОЙКИ"}[locale]
		assert(menu.get_node("CategoriesCon/SettingsLabel").get_parsed_text() == expected_title)
		var expected_line: String = {
			"uk": "Повітря смерділо трупами, порохом та брехнею",
			"en": "The air reeks of corpses, gunpowder and lies",
			"ru": "Воздух смердел трупами, порохом и ложью"
		}[locale]
		assert(dialogue.typer.text == expected_line, "Typewriter refresh: " + locale)
		assert(dialogue.dialogue_log.entries[0].text == expected_line, "Log refresh: " + locale)
		print("Localization OK: ", locale, " (", translation.get_message_count(), " messages)")
	menu.queue_free()
	dialogue.queue_free()
	await process_frame
	quit()
