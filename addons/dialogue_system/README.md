# DialogueSystem

Звичайні репліки очікують натискання лівої кнопки миші: під час друку клік
прискорює поточну репліку до 120 символів на секунду, а після завершення — переходить далі (або завершує
діалог на останній репліці). Репліки з перебиванням чи відповідями зберігають
свої часові вікна й не пропускаються кліком. Кнопка журналу не перемикає репліку.

Прискорення діє до кінця поточної репліки, прибирає поточну й наступні паузи між сегментами
й скидається на наступній репліці. Повторний клік під час друку не показує текст миттєво.

## Налаштування вигляду

Кольори, висота кнопок, розмір шрифту, відступи, радіус кутів, кольори шкали
та трясіння interrupt-кнопок знаходяться в `ui/DefaultDialogueStyle.tres`.
Виберіть ресурс у FileSystem і змінюйте поля в Inspector — редагувати GDScript
для зміни оформлення не потрібно.

Інший ресурс `DialogueStyle` можна призначити полю `dialogue_style` екземпляра
`DialogueSystem`, якщо різні сцени повинні мати різне оформлення.

Автономний runtime-модуль розгалужених діалогів для Godot 4.

## Підключення

1. Скопіюйте всю папку `addons/dialogue_system` у новий проєкт.
2. Додайте `DialogueSystem.tscn` до потрібної сцени.
3. В Inspector задайте `dialogues_path` і `speakers_path`.
4. Запустіть гілку через `start_dialogue()`:

```gdscript
@onready var dialogue: DialogueSystem = $DialogueSystem

func _ready() -> void:
    dialogue.choice_selected.connect(_on_choice_selected)
    dialogue.branch_reached.connect(_on_branch_reached)

    var result := await dialogue.start_dialogue("intro")
```

`start_dialogue(entry_id)` автоматично проходить переходи `next`, `ignore` та
вибрані відповіді. `play(line_id)` відтворює одну репліку й повертає її
`DialogueResult`, не переходячи далі.

Одночасно може виконуватися лише один діалог. Повторний запуск буде відхилено.
Активний діалог можна завершити через `stop_dialogue()`.

## Сигнали

```gdscript
dialogue_started(entry_id)
dialogue_finished(entry_id, result)
dialogue_cancelled(entry_id)

line_started(line_id)
line_finished(line_id, result)

choice_selected(line_id, choice_id, target_id, event_id)
branch_reached(event_id)
```

`choice_selected` повідомляє про кожну відповідь. `branch_reached` призначений
для ігрових наслідків: квестів, репутації, прапорців сюжету тощо.

```gdscript
func _on_branch_reached(event_id: String) -> void:
    match event_id:
        "player_agreed_to_help":
            quest.accept()
        "player_refused":
            reputation -= 1
```

## Дані гілок

Варіант відповіді підтримує стабільні `id` та `event`:

```json
{
  "id": "agree_to_help",
  "text": "Я допоможу",
  "next": "helper_response",
  "event": "player_agreed_to_help"
}
```

`id` і `event` не повинні залежати від локалізованого тексту. Якщо `id` не
вказано, модуль створить його у форматі `line_id.choice_0` або
`line_id.interrupt_0`.

Подію також можна розмістити безпосередньо на репліці:

```json
{
  "speaker": "narrator",
  "event": "secret_branch_entered",
  "segments": []
}
```

Вона буде передана через `branch_reached` на початку репліки.

## Межі модуля

Модуль відповідає за завантаження, показ тексту, часові вікна, вибір і переходи.
Контент JSON та реакції ігрового світу залишаються у проєкті гри. Стандартний UI
можна змінювати в `DialogueSystem.tscn`, не торкаючись даних чи логіки гілок.
# Dialogue system

## Pause

`DialogueSystem` can pause the entire `SceneTree`, including text typing,
interrupt windows, choice timers and scene animations:

```gdscript
dialogue.pause_dialogue()
dialogue.resume_dialogue()
dialogue.toggle_pause()
```

Pause reasons are tracked independently. Opening `Log` adds the `log` reason,
while programmatic pause uses the `manual` reason. Closing the log therefore does
not resume a dialogue that the player also paused manually.

The following signals are available:

```gdscript
dialogue.dialogue_paused
dialogue.dialogue_resumed
```

## JSON validation

Enable the `Dialogue System Tools` editor plugin and open the full-size
`Dialogue` main-screen tab next to Godot's 2D, 3D and Script workspaces. Press
`Validate JSON` to validate `dialogues.json` and `speakers.json`.

The Dialogue workspace contains a searchable dialogue list, validation output,
a pannable and zoomable transition graph, and a full-height node editor. Press
`Refresh Graph` after editing JSON to rebuild it. Nodes show the speaker and a
short text preview; connections include `next`, `ignore`, normal choices and
interrupt choices. Selecting a node opens its complete JSON object for editing.
The workspace can create, save and delete nodes, including their segments and choice
arrays. Saving is deliberately blocked while duplicate root IDs exist, because
normalizing such a file would silently discard one of the duplicate values.
Renaming an ID updates every `next`, `ignore` and choice target that referred to
the old ID.

To remove a line, select it in the list or graph and press `Delete`, or use
`Delete selected` beside the dialogue list. A confirmation dialog lists incoming
references before deletion. The Delete key keeps its normal text-editing
behavior while the ID or JSON editor has keyboard focus.

The validator checks:

- JSON parsing and root types;
- duplicate root IDs;
- speaker references and colors;
- dialogue segments and timing values;
- `next`, `ignore` and choice targets;
- choices without text or targets;
- closed graph cycles that cannot reach an ending.

The same validation can be run from the command line:

```text
godot --headless --path . --script res://addons/dialogue_system/validation/ValidateDialogues.gd
```

The command exits with code `1` when validation errors are found, so it can be
used by CI or an export pipeline.
