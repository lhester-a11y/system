extends Control
class_name UiKitMeter
## A thin horizontal meter: dark track plus a fill whose width is a ratio.

var bar_width: float = 200.0
var bar_height: float = 7.0
var fill_color: Color = Color("#5fe08a")

var _bar: ColorRect
var _ratio: float = 0.0

func _init(width: float = 200.0, height: float = 7.0, color: Color = Color("#5fe08a")) -> void:
    bar_width = width
    bar_height = height
    fill_color = color
    custom_minimum_size = Vector2(width, height)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
    var track := ColorRect.new()
    track.color = Color("#243149")
    track.size = Vector2(bar_width, bar_height)
    track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(track)
    _bar = ColorRect.new()
    _bar.color = fill_color
    _bar.size = Vector2(clampf(_ratio, 0.0, 1.0) * bar_width, bar_height)
    _bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_bar)

func set_ratio(ratio: float) -> void:
    _ratio = ratio
    if _bar == null:
        return
    _bar.size = Vector2(clampf(ratio, 0.0, 1.0) * bar_width, bar_height)

