extends GameScreen
class_name PauseScreen
## The pause card: resume, restart the module, or go back to the lobby.

signal resume_pressed()
signal restart_pressed()
signal lobby_pressed()

var _stats: Label

func build() -> void:
    add_title("Paused", "")
    _stats = UiKit.label("", 12)
    column.add_child(_stats)
    column.add_child(UiKit.spacer(6))

    var resume := UiKit.button("Resume", 15)
    resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resume.pressed.connect(func() -> void: resume_pressed.emit())
    column.add_child(resume)

    var restart := UiKit.button("Restart module", 13)
    restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    restart.pressed.connect(func() -> void: restart_pressed.emit())
    column.add_child(restart)

    var quit := UiKit.button("Back to lobby", 13)
    quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quit.pressed.connect(func() -> void: lobby_pressed.emit())
    column.add_child(quit)

func render(data: Dictionary) -> void:
    _stats.text = "Module %d - %s\nCheckpoints %d/%d\nAnswer streak %d - %d pts" % [
        int(data.get("module", 1)),
        String(data.get("lang_name", "")),
        int(data.get("cleared", 0)),
        int(data.get("total", 0)),
        int(data.get("streak", 0)),
        int(data.get("points", 0)),
    ]

## Escape or P resumes - the screen runs with PROCESS_MODE_ALWAYS, so it still
## receives input while the SceneTree is paused.
func _input(event: InputEvent) -> void:
    if not visible:
        return
    var key_event := event as InputEventKey
    if key_event == null or not key_event.pressed or key_event.echo:
        return
    if key_event.keycode in [KEY_ESCAPE, KEY_P]:
        get_viewport().set_input_as_handled()
        resume_pressed.emit()

