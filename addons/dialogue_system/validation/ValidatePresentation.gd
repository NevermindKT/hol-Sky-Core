extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene = load("res://addons/dialogue_system/DialogueSystem.tscn").instantiate()
    root.add_child(scene)
    assert(scene.typer and scene.timeline and scene.choice_manager)
    assert(scene.choice_manager.timeline and scene.choice_manager.container)
    assert(scene.background and scene.footer and scene.character)
    for id in scene.dialogue_repository.ids():
        var line = scene.dialogue_repository.try_get(id)
        scene._apply_presentation(line.presentation)
        assert(scene.background.texture and scene.footer.texture)
        assert(scene.character.visible == !line.presentation.character.is_empty())
        if scene.character.visible:
            assert(scene.character.texture)
    scene._apply_presentation({"environment": "guard", "character": "security"})
    var previous = scene.character.texture
    scene._apply_presentation({})
    assert(scene.character.texture == previous)
    scene._apply_presentation({"emotion": "irritated"})
    assert(scene.character.texture != previous)
    scene._apply_presentation({"environment": "", "character": ""})
    assert(!scene.background.visible and !scene.footer.visible and !scene.character.visible)
    scene.start_dialogue("intro_line1")
    await process_frame
    assert(scene.is_running())
    scene.stop_dialogue()
    assert(!scene.is_running())
    print("Visual smoke: all dialogue presentations, scene references, inheritance, hiding and cancellation passed")
    scene.queue_free()
    quit()
