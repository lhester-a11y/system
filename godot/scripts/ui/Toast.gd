extends CanvasLayer
class_name ToastStack
## The transient messages along the top of the screen (ui.js toast()).

const LIFE := 2.4
const MAX_VISIBLE := 3
## Below the HUD column (which ends around y=140) and above the touch pad, so a
## toast never hides the hearts, the points or the buff chips.
const TOP := 150.0

var _column: VBoxContainer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 20

    var holder := Control.new()
    holder.set_anchors_preset(Control.PRESET_FULL_RECT)
    holder.anchor_right = 1.0
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(holder)

    _column = UiKit.column(4)
    _column.position = Vector2(12, TOP)
    _column.custom_minimum_size = Vector2(336, 0)
    _column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(_column)

## Main calls this after every HUD refresh: the strip drops to wherever the
## readout actually ends, so text-metric changes or the boss bar can never push
## the HUD under a toast.
func place_below(y: float) -> void:
    _column.position.y = maxf(TOP, y)

func top_y() -> float:
    return _column.position.y

func push(message: String, kind: String = "") -> void:
    if message == "":
        return
    while _column.get_child_count() >= MAX_VISIBLE:
        _column.get_child(0).free()

    var color := UiKit.FG
    match kind:
        "good":
            color = UiKit.GOOD
        "bad":
            color = UiKit.BAD

    var card := UiKit.panel(UiKit.PANEL_BG_ALT, color)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(UiKit.label(message, 11, color))
    _column.add_child(card)

    var timer := get_tree().create_timer(LIFE, true, false, true)
    timer.timeout.connect(_expire.bind(card))

func _expire(card: Node) -> void:
    if is_instance_valid(card):
        card.queue_free()

