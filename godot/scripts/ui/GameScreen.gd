extends CanvasLayer
class_name GameScreen
## Base class for the full-screen menus: a CanvasLayer that keeps running while
## the SceneTree is paused, with a full-rect dim background and a scrollable
## column subclasses fill in through build().

const BG := Color("#0b1020")

var root: Control
var column: VBoxContainer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false

    root = Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.anchor_right = 1.0
    root.anchor_bottom = 1.0
    add_child(root)

    var dim := ColorRect.new()
    dim.color = BG
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.anchor_right = 1.0
    dim.anchor_bottom = 1.0
    root.add_child(dim)

    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.anchor_right = 1.0
    margin.anchor_bottom = 1.0
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 14)
    root.add_child(margin)

    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    margin.add_child(scroll)

    column = UiKit.column(10)
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(column)

    build()

func build() -> void:
    pass

func open() -> void:
    visible = true

func close() -> void:
    visible = false

func add_title(title: String, subtitle: String = "") -> void:
    # .section-title is the gold uppercase heading in the web build.
    column.add_child(UiKit.label(title, 20, UiKit.GOLD))
    if subtitle != "":
        column.add_child(UiKit.label(subtitle, 12, UiKit.MUTED))
    column.add_child(UiKit.spacer(4))

