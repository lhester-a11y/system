extends CanvasLayer
class_name QuizUI
## The learning-checkpoint modal, built in code so the project needs no extra
## scene files.
##
## IMPORTANT: this whole UI runs with PROCESS_MODE_ALWAYS. CodePlayCheckpoint
## pauses the SceneTree, and only nodes that opt out of the pause keep receiving
## input - which is exactly what a question modal has to do.

signal answer_selected(index: int)
signal continue_pressed()

const CORRECT_FG := Color("#5fe08a")
const WRONG_FG := Color("#ef6a5a")
const GOLD := Color("#f2c14e")

var _root: Control
var _lang_label: Label
var _kind_label: Label
var _prompt_label: Label
var _code_label: Label
var _choice_box: VBoxContainer
var _feedback_box: VBoxContainer
var _feedback_head: Label
var _feedback_body: Label
var _reward_label: Label
var _choice_buttons: Array = []
var _awaiting := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    _build()
    set_open(false)

func _build() -> void:
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.anchor_right = 1.0
    _root.anchor_bottom = 1.0
    add_child(_root)

    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.03, 0.06, 0.88)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.anchor_right = 1.0
    dim.anchor_bottom = 1.0
    _root.add_child(dim)

    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.anchor_right = 1.0
    margin.anchor_bottom = 1.0
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    _root.add_child(margin)

    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    margin.add_child(scroll)

    var panel := UiKit.panel(UiKit.PANEL_BG, UiKit.BORDER)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(panel)

    var column := UiKit.column(9)
    panel.add_child(column)

    _lang_label = UiKit.label("", 12)
    column.add_child(_lang_label)
    _kind_label = UiKit.label("", 11, UiKit.MUTED)
    column.add_child(_kind_label)

    _prompt_label = UiKit.label("", 16)
    column.add_child(_prompt_label)

    _code_label = UiKit.label("", 13, Color("#cfe8ff"))
    _code_label.visible = false
    column.add_child(_code_label)

    _choice_box = UiKit.column(7)
    column.add_child(_choice_box)

    _feedback_box = UiKit.column(7)
    column.add_child(_feedback_box)

    _feedback_head = UiKit.label("", 15)
    _feedback_box.add_child(_feedback_head)
    _feedback_body = UiKit.label("", 12)
    _feedback_box.add_child(_feedback_body)
    _reward_label = UiKit.label("", 12, GOLD)
    _feedback_box.add_child(_reward_label)

    var continue_button := UiKit.primary_button("Continue", 15)
    continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    continue_button.pressed.connect(func() -> void: continue_pressed.emit())
    _feedback_box.add_child(continue_button)

func set_open(value: bool) -> void:
    _root.visible = value

func is_open() -> bool:
    return _root.visible

## Show a freshly absorbed code box as a question.
func show_question(question: Dictionary, kind: String = "Checkpoint", points_label: String = "") -> void:
    var lang := String(question["lang"])
    _lang_label.text = Rules.language_name(lang)
    _lang_label.add_theme_color_override("font_color", Rules.language_color(lang))
    var difficulty := QuestionBank.difficulty_label(int(question["difficulty"]))
    _kind_label.text = "%s - %s %s" % [kind, difficulty, points_label]
    _prompt_label.text = String(question["prompt"]).replace("__BLANK__", "____")

    var code := String(question.get("code", ""))
    _code_label.visible = code != ""
    _code_label.text = code

    for button in _choice_buttons:
        button.queue_free()
    _choice_buttons.clear()

    var choices: Array = question["choices"]
    for i in choices.size():
        var button := UiKit.button("", 14)
        var key := "F"
        if choices.size() == 2:
            key = "T" if i == 0 else "F"
        else:
            key = String.chr(65 + i)
        button.text = "%s)  %s" % [key, String(choices[i])]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(func() -> void: answer_selected.emit(i))
        _choice_box.add_child(button)
        _choice_buttons.append(button)

    _awaiting = true
    _feedback_box.visible = false
    set_open(true)

## Reveal the graded answer: the right choice in green, a miss in red.
func show_result(result: Dictionary) -> void:
    _awaiting = false
    var question: Dictionary = result["question"]
    var chosen := int(result["choice"])
    var answer := int(question["answer"])

    for i in _choice_buttons.size():
        var button: Button = _choice_buttons[i]
        button.disabled = true
        if i == answer:
            # .choice.correct: green border and body, green key chip.
            button.add_theme_color_override("font_color", CORRECT_FG)
            button.add_theme_color_override("font_disabled_color", CORRECT_FG)
            button.add_theme_stylebox_override("disabled", UiKit.style(Color("#14301f"), UiKit.GOOD))
            button.text = "[x] " + button.text
        elif i == chosen:
            button.add_theme_color_override("font_color", WRONG_FG)
            button.add_theme_color_override("font_disabled_color", WRONG_FG)
            button.add_theme_stylebox_override("disabled", UiKit.style(Color("#2a1310"), UiKit.BAD))

    var correct := bool(result["correct"])
    _feedback_head.text = "Correct - checkpoint cleared" if correct else "Not quite - upgrade lost"
    _feedback_head.add_theme_color_override("font_color", CORRECT_FG if correct else WRONG_FG)
    _feedback_body.text = String(question.get("explain", ""))

    var upgrade: Dictionary = result["upgrade"]
    if correct and not upgrade.is_empty():
        _reward_label.text = "UPGRADE EARNED  %s  Lv%d  (%s)   +%d pts" % [
            String(upgrade["name"]), int(upgrade["level"]),
            String(upgrade["description"]), int(result["points"]),
        ]
        if int(result["streak"]) >= 3:
            _reward_label.text += "   %d in a row" % int(result["streak"])
    elif correct:
        _reward_label.text = "+%d pts - every upgrade is already maxed." % int(result["points"])
    else:
        _reward_label.text = "No upgrade, no points. Read the explanation and take the next bat."
    _feedback_box.visible = true

## Keyboard shortcuts from main.js: 1-4 answer, Enter continues.
func _input(event: InputEvent) -> void:
    if not _root.visible:
        return
    var key_event := event as InputEventKey
    if key_event == null or not key_event.pressed or key_event.echo:
        return
    if _awaiting:
        var index := -1
        match key_event.keycode:
            KEY_1:
                index = 0
            KEY_2:
                index = 1
            KEY_3:
                index = 2
            KEY_4:
                index = 3
        if index >= 0 and index < _choice_buttons.size():
            answer_selected.emit(index)
            get_viewport().set_input_as_handled()
    elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
        continue_pressed.emit()
        get_viewport().set_input_as_handled()

