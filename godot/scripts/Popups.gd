extends Node2D
class_name PopupLayer
## Floating world text - "CODE ABSORBED", "2 HP LEFT" - the port of addPopup()
## and drawPopups() in js/render/renderer.js.
##
## Each popup is a dark shadow copy plus a coloured copy (the web build draws the
## text twice for the same effect), rises 26px/s and fades out over its 1.1s life.

const LIFE := 1.1
const RISE := 26.0
const WIDTH := 260.0

func _ready() -> void:
    z_index = 10      # above every world sprite, below the HUD CanvasLayers

func push(text: String, at: Vector2, color: Color = Color("#f2c14e")) -> void:
    if text == "":
        return
    var holder := Node2D.new()
    holder.position = at
    add_child(holder)

    var shadow := UiKit.label(text, 11, Color("#05070d"), false)
    var main := UiKit.label(text, 11, color, false)
    for node in [shadow, main]:
        var label := node as Label
        label.size = Vector2(WIDTH, 16.0)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.position = Vector2(-WIDTH / 2.0, -16.0)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        holder.add_child(label)
    shadow.position += Vector2(1, 1)

    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(holder, "position:y", holder.position.y - RISE * LIFE, LIFE)
    tween.tween_property(holder, "modulate:a", 0.0, LIFE - 0.6).set_delay(0.6)
    tween.set_parallel(false)
    tween.tween_callback(holder.queue_free)
