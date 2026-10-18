extends GameScreen
class_name LobbyScreen
## The title screen: hero picker, name, headline stats and the way into the game.
## Mirrors renderLobby() in js/ui.js.

signal start_pressed()
signal hero_selected(hero: String)
signal name_changed(new_name: String)
signal shop_pressed()
signal progress_pressed()
signal howto_pressed()
signal review_pressed()

var _preview: TextureRect
var _hero_row: HBoxContainer
var _name_field: LineEdit
var _stats: Label
var _start_button: Button

func build() -> void:
    # The web build's two-tone logo, then the tagline (.logo-code / .logo-play).
    column.add_child(UiKit.logo("Code", "Play"))
    var tagline := UiKit.label("Throw the spear, absorb the code box, answer the checkpoint.", 12, UiKit.MUTED)
    tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tagline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(tagline)
    column.add_child(UiKit.spacer(4))

    _preview = TextureRect.new()
    _preview.custom_minimum_size = Vector2(70, 78)
    _preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var preview_row := UiKit.row()
    preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
    preview_row.add_child(_preview)
    column.add_child(preview_row)

    _hero_row = UiKit.row(8)
    column.add_child(_hero_row)
    for id in ["boy", "girl"]:
        var hero_id := String(id)
        var hero_button := UiKit.button("Boy Warrior" if hero_id == "boy" else "Girl Warrior", 12)
        hero_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hero_button.pressed.connect(func() -> void: hero_selected.emit(hero_id))
        _hero_row.add_child(hero_button)

    var name_row := UiKit.row(6)
    var name_label := UiKit.label("Name", 11, UiKit.MUTED, false)
    name_label.name = "NameLabel"
    name_row.add_child(name_label)
    _name_field = LineEdit.new()
    _name_field.max_length = 12
    _name_field.placeholder_text = "Bagani"
    _name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _name_field.add_theme_font_size_override("font_size", 12)
    _name_field.text_changed.connect(func(text: String) -> void: name_changed.emit(text))
    name_row.add_child(_name_field)
    column.add_child(name_row)

    _stats = UiKit.label("", 11, UiKit.MUTED)
    column.add_child(_stats)
    column.add_child(UiKit.spacer(4))

    _start_button = UiKit.primary_button("Start", 16)
    _start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _start_button.pressed.connect(func() -> void: start_pressed.emit())
    column.add_child(_start_button)

    var nav := [
        {"label": "Shop", "signal_name": "shop"},
        {"label": "Progress and badges", "signal_name": "progress"},
        {"label": "Review questions", "signal_name": "review"},
        {"label": "How to play", "signal_name": "howto"},
    ]
    for entry in nav:
        var which := String(entry["signal_name"])
        var node := UiKit.button(String(entry["label"]), 13)
        node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        node.pressed.connect(func() -> void: _navigate(which))
        column.add_child(node)

func _navigate(which: String) -> void:
    match which:
        "shop":
            shop_pressed.emit()
        "progress":
            progress_pressed.emit()
        "review":
            review_pressed.emit()
        "howto":
            howto_pressed.emit()

func render(progress: Dictionary) -> void:
    var hero := String(progress.get("hero", "boy"))
    var equipped: Dictionary = progress.get("equipped", {})
    var garment := String(equipped.get("garment", "garment-bahag"))
    _preview.texture = Sprites.hero(hero, garment)

    var current_name := String(progress.get("name", "Bagani"))
    if _name_field.text != current_name:
        _name_field.text = current_name

    var stats := Rules.derived_stats(progress)
    var badges: Array = progress.get("badges", [])
    _stats.text = "Module %d - %d pts - %d hearts - %d correct - %d/%d badges" % [
        int(progress.get("module", 1)),
        int(progress.get("points", 0)),
        int(stats["maxHearts"]),
        int(progress.get("correct", 0)),
        badges.size(),
        Rules.badges().size(),
    ]
    _start_button.text = "Start Module %d" % int(progress.get("module", 1))

    for i in _hero_row.get_child_count():
        var node := _hero_row.get_child(i) as Button
        var is_selected := (i == 0 and hero == "boy") or (i == 1 and hero == "girl")
        var base := "Boy Warrior" if i == 0 else "Girl Warrior"
        node.text = ("> " + base) if is_selected else base

