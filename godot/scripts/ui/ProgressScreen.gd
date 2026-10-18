extends GameScreen
class_name ProgressScreen
## The progress tracker: headline stats, per-language mastery, the badge case and
## the upgrades earned so far. Mirrors renderProgress() in js/ui.js.
##
## Every card here is EXPAND_FILL with non-wrapping labels. Without that, a
## GridContainer sizes its columns to each cell's minimum width, and an
## autowrapping Label reports about one character - which is exactly what
## squashed the old badge list into a row of vertical letter columns.

signal back_pressed()

var _summary: GridContainer
var _mastery: VBoxContainer
var _badge_count: Label
var _badges: VBoxContainer
var _upgrades: Label
var _upgrades_flow: HFlowContainer

func build() -> void:
    add_title("Progress and badges", "Everything the mountain remembers about you.")

    _summary = GridContainer.new()
    _summary.columns = 2
    _summary.add_theme_constant_override("h_separation", 6)
    _summary.add_theme_constant_override("v_separation", 6)
    column.add_child(_summary)

    column.add_child(UiKit.spacer(4))
    column.add_child(UiKit.label("Mastery per language", 13, UiKit.GOLD))
    _mastery = UiKit.column(9)
    column.add_child(_mastery)

    column.add_child(UiKit.spacer(4))
    _badge_count = UiKit.label("Badges", 13, UiKit.GOLD)
    column.add_child(_badge_count)
    _badges = UiKit.column(5)
    column.add_child(_badges)

    column.add_child(UiKit.spacer(4))
    column.add_child(UiKit.label("Upgrades earned", 13, UiKit.GOLD))
    _upgrades_flow = HFlowContainer.new()
    _upgrades_flow.add_theme_constant_override("h_separation", 4)
    _upgrades_flow.add_theme_constant_override("v_separation", 4)
    column.add_child(_upgrades_flow)
    _upgrades = UiKit.label("", 10, UiKit.MUTED)
    column.add_child(_upgrades)

    column.add_child(UiKit.spacer(6))
    var back := UiKit.button("Back", 14)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(func() -> void: back_pressed.emit())
    column.add_child(back)

## A stat card: big value over a muted caption, side by side so two fit a row.
func _stat_box(key: String, value: String) -> Control:
    var box := UiKit.panel(UiKit.PANEL_BG_ALT, UiKit.LINE_2)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var inner := UiKit.row(8)
    box.add_child(inner)
    var value_label := UiKit.label(value, 16, UiKit.GOLD, false)
    value_label.custom_minimum_size = Vector2(44, 0)
    inner.add_child(value_label)
    var key_label := UiKit.label(key, 10, UiKit.MUTED, false)
    key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inner.add_child(key_label)
    return box

func render(progress: Dictionary) -> void:
    var stats := Rules.derived_stats(progress)
    var earned: Array = progress.get("badges", [])
    var all_badges := Rules.badges()

    for child in _summary.get_children():
        child.queue_free()
    var boxes := [
        ["Points", str(int(progress.get("points", 0)))],
        ["Correct answers", str(int(progress.get("correct", 0)))],
        ["Accuracy", "%d%%" % Rules.accuracy(progress)],
        ["Best streak", str(int(progress.get("bestStreak", 0)))],
        ["Bosses beaten", str(int(progress.get("bossesDefeated", 0)))],
        ["Modules cleared", str(int(progress.get("modulesCleared", 0)))],
        ["Hearts", str(int(stats["maxHearts"]))],
        ["Badges", "%d/%d" % [earned.size(), all_badges.size()]],
    ]
    for entry in boxes:
        _summary.add_child(_stat_box(String(entry[0]), String(entry[1])))

    for child in _mastery.get_children():
        child.queue_free()
    for lang in Rules.LANGUAGES:
        var lang_id := String(lang["id"])
        var solved := Rules.solved_ids(progress, lang_id).size()
        var total := QuestionBank.questions_for(lang_id, 3).size()
        var percent := Rules.mastery_percent(progress, lang_id)
        var mastery: Dictionary = progress.get("mastery", {})
        var record: Dictionary = mastery.get(lang_id, {"correct": 0, "wrong": 0})

        var card := UiKit.panel(UiKit.PANEL_BG_ALT, UiKit.LINE)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var inner := UiKit.column(3)
        card.add_child(inner)

        var row := UiKit.row(6)
        var name_label := UiKit.label(String(lang["name"]), 12, Rules.language_color(lang_id), false)
        name_label.custom_minimum_size = Vector2(66, 0)
        row.add_child(name_label)
        var meter := UiKit.meter(float(percent) / 100.0, 120.0, 7.0, Rules.language_color(lang_id))
        row.add_child(meter)
        var count_label := UiKit.label("%d/%d" % [solved, total], 10, UiKit.MUTED, false)
        count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(count_label)
        inner.add_child(row)
        inner.add_child(UiKit.label("%d right - %d wrong - %s" % [
            int(record.get("correct", 0)), int(record.get("wrong", 0)), String(lang["blurb"]),
        ], 9, UiKit.MUTED))
        _mastery.add_child(card)

    _badge_count.text = "Badges %d/%d" % [earned.size(), all_badges.size()]
    for child in _badges.get_children():
        child.queue_free()
    for badge in all_badges:
        var badge_id := String(badge["id"])
        var has_it: bool = earned.has(badge_id)
        var card := UiKit.panel(
            UiKit.PANEL_BG if has_it else UiKit.PANEL_BG_ALT,
            UiKit.GOLD if has_it else UiKit.LINE
        )
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size = Vector2(296, 0)
        var inner := UiKit.row(7)
        card.add_child(inner)

        # The tick is its own fixed-width cell, so every badge name starts in the
        # same place whether it is earned or not.
        var tick := UiKit.label("[x]" if has_it else "[  ]", 12, UiKit.GOLD if has_it else UiKit.MUTED, false)
        tick.custom_minimum_size = Vector2(26, 0)
        inner.add_child(tick)

        var text_col := UiKit.column(1)
        text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        text_col.custom_minimum_size = Vector2(232, 0)
        inner.add_child(text_col)
        text_col.add_child(UiKit.label(String(badge["name"]), 12, UiKit.GOLD if has_it else UiKit.FG, false))
        text_col.add_child(UiKit.label(String(badge["desc"]), 9, UiKit.MUTED))
        _badges.add_child(card)

    for child in _upgrades_flow.get_children():
        child.queue_free()
    var earned_upgrades := UpgradeSystem.summary()
    _upgrades.text = "Answer checkpoints correctly to earn upgrades." if earned_upgrades.is_empty() else ""
    for upgrade in earned_upgrades:
        _upgrades_flow.add_child(UiKit.pill(String(upgrade), UiKit.GOLD, UiKit.PANEL_BG_ALT))
