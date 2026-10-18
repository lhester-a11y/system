extends GameScreen
class_name ShopScreen
## The tradepost: spears, garments and effects bought with checkpoint points.
## Mirrors renderShop() in js/ui.js.

signal buy_requested(item_id: String)
signal equip_requested(item_id: String)
signal back_pressed()

var _points: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _tab: String = "spear"

func build() -> void:
    add_title("Tradepost", "")
    _points = UiKit.label("", 13, UiKit.GOLD)
    column.add_child(_points)

    _tabs = UiKit.row(6)
    column.add_child(_tabs)
    for category in Rules.SHOP_CATEGORIES:
        var cat_id := String(category["id"])
        var tab := UiKit.button(String(category["name"]), 12)
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.pressed.connect(func() -> void: _select_tab(cat_id))
        _tabs.add_child(tab)

    _list = UiKit.column(8)
    column.add_child(_list)
    column.add_child(UiKit.spacer(6))

    var back := UiKit.button("Back", 14)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(func() -> void: back_pressed.emit())
    column.add_child(back)

func _select_tab(cat_id: String) -> void:
    _tab = cat_id
    render(_progress)

var _progress: Dictionary = {}

func render(progress: Dictionary) -> void:
    _progress = progress
    _points.text = "%d pts" % int(progress.get("points", 0))

    for i in _tabs.get_child_count():
        var node := _tabs.get_child(i) as Button
        var cat_id := String((Rules.SHOP_CATEGORIES[i] as Dictionary)["id"])
        var label := String((Rules.SHOP_CATEGORIES[i] as Dictionary)["name"])
        var active := cat_id == _tab
        node.text = ("> " + label) if active else label
        # .tab.active is the gold tab.
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

    for child in _list.get_children():
        child.queue_free()

    var owned: Array = progress.get("owned", [])
    var equipped: Dictionary = progress.get("equipped", {})
    for item in Rules.items_in_category(_tab):
        var item_id := String(item["id"])
        var card := UiKit.panel()
        var is_equipped := String(equipped.get(String(item["cat"]), "")) == item_id
        var is_owned: bool = owned.has(item_id)
        card.add_theme_stylebox_override("panel", UiKit.style(
            UiKit.PANEL_BG if not is_equipped else Color("#1c2740"),
            UiKit.GOOD if is_equipped else UiKit.BORDER
        ))
        _list.add_child(card)

        var row := UiKit.row(9)
        card.add_child(row)
        row.add_child(_preview(item, progress))

        var info := UiKit.column(3)
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info)
        info.add_child(UiKit.label(String(item["name"]), 13))
        info.add_child(UiKit.label(String(item["desc"]), 10, UiKit.MUTED))
        var perk_text := String(item["perk_text"])
        if perk_text != "":
            info.add_child(UiKit.label(perk_text, 10, UiKit.GOLD))

        # .item-btn is the gold action button; an action the player cannot take
        # yet is the flat .locked variant.
        var action := UiKit.button("", 12)
        action.custom_minimum_size = Vector2(84, 0)
        if is_equipped:
            action.text = "Equipped"
            action.disabled = true
        elif is_owned:
            action.text = "Equip"
            action.add_theme_stylebox_override("normal", UiKit.button_style(Color("#2f7d4d"), Color("#123f24"), 3, 6, 8))
            action.pressed.connect(func() -> void: equip_requested.emit(item_id))
        elif bool(Rules.can_buy(progress, item_id)["ok"]):
            action.text = "%d pts" % int(item["cost"])
            action.add_theme_stylebox_override("normal", UiKit.button_style(UiKit.PRIMARY_BG, UiKit.PRIMARY_BD, 3, 6, 8))
            action.add_theme_stylebox_override("hover", UiKit.button_style(UiKit.PRIMARY_BG_HOVER, UiKit.PRIMARY_BD, 3, 6, 8))
            action.add_theme_stylebox_override("pressed", UiKit.button_style(UiKit.PRIMARY_BG, UiKit.PRIMARY_BD, 3, 6, 8))
            for state in ["font_color", "font_hover_color", "font_pressed_color"]:
                action.add_theme_color_override(state, UiKit.PRIMARY_FG)
            action.pressed.connect(func() -> void: buy_requested.emit(item_id))
        else:
            action.text = "%d pts" % int(item["cost"])
            action.disabled = true
        row.add_child(action)

func _preview(item: Dictionary, progress: Dictionary) -> Control:
    var cat := String(item["cat"])
    if cat == "effect":
        var swatches := UiKit.column(2)
        var colors: Array = Rules.EFFECT_COLORS.get(String(item["id"]), ["#3c4a63"])
        for color in colors:
            swatches.add_child(UiKit.swatch(Color.from_string(String(color), Color.GRAY), Vector2(16, 7)))
        return swatches
    var texture := TextureRect.new()
    texture.custom_minimum_size = Vector2(34, 40)
    texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    if cat == "spear":
        texture.texture = Sprites.spear(String(item["id"]).replace("spear-", ""))
    else:
        var hero := String(progress.get("hero", "boy"))
        texture.texture = Sprites.hero(hero, String(item["id"]))
    return texture

