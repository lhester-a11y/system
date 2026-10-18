extends GameScreen
class_name ReviewScreen
## "Review questions" - every checkpoint in the bank, with the right answer
## marked and the explanation shown, so a lesson can be studied outside the run.
##
## The questions come from the same res://data/questions.json the game asks, so
## this screen can never drift from what the player is actually tested on.

signal back_pressed()

var _tabs: HBoxContainer
var _count: Label
var _list: VBoxContainer
var _lang: String = "all"

func build() -> void:
    add_title("Review questions", "Every checkpoint, with the answer and the reason.")

    _tabs = UiKit.row(6)
    column.add_child(_tabs)
    var all_tab := UiKit.button("All", 11)
    all_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    all_tab.pressed.connect(func() -> void: _select("all"))
    _tabs.add_child(all_tab)
    for lang in Rules.LANGUAGES:
        var lang_id := String(lang["id"])
        var tab := UiKit.button(String(lang["label"]), 11)
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.pressed.connect(func() -> void: _select(lang_id))
        _tabs.add_child(tab)

    _count = UiKit.label("", 10, UiKit.MUTED)
    column.add_child(_count)

    _list = UiKit.column(8)
    column.add_child(_list)

    column.add_child(UiKit.spacer(6))
    var back := UiKit.button("Back", 14)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(func() -> void: back_pressed.emit())
    column.add_child(back)

func _select(lang_id: String) -> void:
    _lang = lang_id
    render(_progress)

var _progress: Dictionary = {}

func render(progress: Dictionary) -> void:
    _progress = progress
    if _lang == "all":
        _lang = String(Rules.level_config(int(progress.get("module", 1)))["lang"])

    for i in _tabs.get_child_count():
        var node := _tabs.get_child(i) as Button
        var is_active := (i == 0 and _lang == "all") or (_lang != "all" and i > 0 and String((Rules.LANGUAGES[i - 1] as Dictionary)["id"]) == _lang)
        var base := "All" if i == 0 else String((Rules.LANGUAGES[i - 1] as Dictionary)["label"])
        node.text = ("> " + base) if is_active else base
        _tint_tab(node, is_active)

    for child in _list.get_children():
        child.queue_free()

    var answered: Dictionary = progress.get("answered", {})
    var shown := 0
    for lang in Rules.LANGUAGES:
        var lang_id := String(lang["id"])
        if lang_id != _lang:
            continue
        _list.add_child(_lang_heading(String(lang["name"]), lang_id))
        for question in QuestionBank.questions_for(lang_id, 3):
            _list.add_child(_question_card(question, answered.has(String(question["id"]))))
            shown += 1

    _count.text = "%d question%s - a tick marks the ones you have answered correctly." % [
        shown, "" if shown == 1 else "s",
    ]

func _lang_heading(name: String, lang_id: String) -> Control:
    var label := UiKit.label(name, 14, Rules.language_color(lang_id))
    return label

func _question_card(question: Dictionary, solved: bool) -> Control:
    var card := UiKit.panel(UiKit.PANEL_BG if solved else UiKit.PANEL_BG_ALT, UiKit.GOLD if solved else UiKit.LINE)
    var inner := UiKit.column(5)
    card.add_child(inner)

    var head := UiKit.row(6)
    inner.add_child(head)
    var tick := UiKit.label("[x]" if solved else "[  ]", 11, UiKit.GOLD if solved else UiKit.MUTED, false)
    tick.custom_minimum_size = Vector2(26, 0)
    head.add_child(tick)
    var meta := UiKit.label("%s - %s" % [
        QuestionBank.difficulty_label(int(question["difficulty"])), String(question.get("topic", "")),
    ], 10, UiKit.MUTED, false)
    meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(meta)

    inner.add_child(UiKit.label(String(question["prompt"]).replace("__BLANK__", "____"), 12))
    var code := String(question.get("code", ""))
    if code != "":
        inner.add_child(UiKit.label(code, 11, Color("#cfe8ff")))

    var answer := int(question["answer"])
    var choices: Array = question["choices"]
    for i in choices.size():
        var correct := i == answer
        inner.add_child(UiKit.label("%s  %s" % [
            "[x]" if correct else "[  ]", String(choices[i]),
        ], 11, UiKit.GOOD if correct else UiKit.MUTED))

    inner.add_child(UiKit.label(String(question.get("explain", "")), 10, UiKit.MUTED))
    return card

func _tint_tab(node: Button, active: bool) -> void:
    if active:
        node.add_theme_stylebox_override("normal", UiKit.button_style(UiKit.PRIMARY_BG, UiKit.PRIMARY_BD, 3, 8, 6))
        node.add_theme_stylebox_override("hover", UiKit.button_style(UiKit.PRIMARY_BG_HOVER, UiKit.PRIMARY_BD, 3, 8, 6))
        node.add_theme_color_override("font_color", UiKit.PRIMARY_FG)
        node.add_theme_color_override("font_hover_color", UiKit.PRIMARY_FG)
    else:
        node.remove_theme_stylebox_override("normal")
        node.remove_theme_stylebox_override("hover")
        node.remove_theme_color_override("font_color")
        node.remove_theme_color_override("font_hover_color")
