extends CanvasLayer
class_name BannerPanel
## The end-of-module and game-over card: title, body, stat rows and up to two
## buttons. Mirrors showBanner() in js/ui.js.

signal primary_pressed()
signal secondary_pressed()

var _root: Control
var _panel: PanelContainer
var _title: Label
var _body: Label
var _stats: VBoxContainer
var _primary: Button
var _secondary: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 9

    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.anchor_right = 1.0
    _root.anchor_bottom = 1.0
    add_child(_root)

    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.03, 0.06, 0.9)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.anchor_right = 1.0
    dim.anchor_bottom = 1.0
    _root.add_child(dim)

    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.anchor_right = 1.0
    margin.anchor_bottom = 1.0
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 16)
    _root.add_child(margin)

    _panel = UiKit.panel(UiKit.PANEL_BG, UiKit.GOLD)
    margin.add_child(_panel)

    var column := UiKit.column(8)
    _panel.add_child(column)

    _title = UiKit.label("", 19, UiKit.GOLD)
    column.add_child(_title)
    _body = UiKit.label("", 12, UiKit.FG)
    column.add_child(_body)

    _stats = UiKit.column(3)
    column.add_child(_stats)

    column.add_child(UiKit.spacer(4))
    _primary = UiKit.primary_button("Continue", 15)
    _primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _primary.pressed.connect(func() -> void: primary_pressed.emit())
    column.add_child(_primary)

    _secondary = UiKit.button("Back to lobby", 13)
    _secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _secondary.pressed.connect(func() -> void: secondary_pressed.emit())
    column.add_child(_secondary)

    close()

func close() -> void:
    _root.visible = false

func is_open() -> bool:
    return _root.visible

## data: {title, body, stats: [[label, value], ...], primary, secondary}
func show_banner(data: Dictionary) -> void:
    _title.text = String(data.get("title", ""))
    _body.text = String(data.get("body", ""))

    for child in _stats.get_children():
        child.queue_free()
    var stats: Array = data.get("stats", [])
    for entry in stats:
        var row := UiKit.row(6)
        var key := UiKit.label(String(entry[0]), 11, UiKit.MUTED, false)
        key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(key)
        row.add_child(UiKit.label(str(entry[1]), 11, UiKit.FG, false))
        _stats.add_child(row)

    _primary.text = String(data.get("primary", "Continue"))
    var secondary := String(data.get("secondary", ""))
    _secondary.visible = secondary != ""
    _secondary.text = secondary
    _root.visible = true

