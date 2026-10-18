extends Node2D
class_name AmbientFx
## The drifting motes a bought Effect item wraps around the warrior - the port of
## EFFECT_STYLES plus updateAmbient() in js/render/renderer.js.
##
## The web build recycles a particle array every frame; this node keeps one
## pooled ColorRect per particle and moves it in _process, which is the same
## maths without the per-frame allocation.

const STYLES := {
    "effect-fly": {"colors": ["#e8f77a", "#b7ffd2"], "count": 10, "radius": 26.0, "life": 1.4, "gravity": -4.0},
    "effect-ember": {"colors": ["#f2a65a", "#ef6a5a"], "count": 8, "radius": 20.0, "life": 1.0, "gravity": -18.0},
    "effect-leaf": {"colors": ["#86b566", "#d9c9a8"], "count": 7, "radius": 30.0, "life": 1.8, "gravity": 12.0},
    "effect-spark": {"colors": ["#7ee3e3", "#6bb8ff"], "count": 9, "radius": 24.0, "life": 0.9, "gravity": 6.0},
}

var effect_id: String = "effect-none"
var target: Node2D = null

var _particles: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    z_index = -5      # behind the warrior, above the background
    _rng.randomize()

## Called when the loadout changes; "effect-none" (or an unknown id) clears it.
func set_effect(id: String) -> void:
    if id == effect_id:
        return
    effect_id = id
    _rebuild()

func _rebuild() -> void:
    for particle in _particles:
        (particle["rect"] as ColorRect).queue_free()
    _particles.clear()
    var style: Dictionary = STYLES.get(effect_id, {})
    if style.is_empty():
        return
    for i in int(style["count"]):
        var rect := ColorRect.new()
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(rect)
        _particles.append(_spawn(style, rect))

func _spawn(style: Dictionary, rect: ColorRect) -> Dictionary:
    var origin := target.position if target != null else Vector2(Rules.WORLD_W / 2.0, Rules.GROUND_Y)
    var angle := _rng.randf_range(0.0, TAU)
    var radius := float(style["radius"]) * _rng.randf_range(0.5, 1.1)
    var colors: Array = style["colors"]
    var size := 3.0 if _rng.randf() > 0.6 else 2.0
    rect.size = Vector2(size, size)
    rect.color = Color.from_string(String(colors[_rng.randi_range(0, colors.size() - 1)]), Color.WHITE)
    return {
        "rect": rect,
        "x": origin.x + cos(angle) * radius,
        "y": origin.y - 10.0 + sin(angle) * radius * 0.6,
        "vx": _rng.randf_range(-6.0, 6.0),
        "vy": float(style["gravity"]) * _rng.randf(),
        "life": float(style["life"]),
        "max_life": float(style["life"]),
    }

func _process(delta: float) -> void:
    var style: Dictionary = STYLES.get(effect_id, {})
    if style.is_empty() or _particles.is_empty():
        return
    for i in _particles.size():
        var particle: Dictionary = _particles[i]
        particle["x"] = float(particle["x"]) + float(particle["vx"]) * delta
        particle["y"] = float(particle["y"]) + float(particle["vy"]) * delta
        particle["life"] = float(particle["life"]) - delta
        if float(particle["life"]) <= 0.0:
            particle = _spawn(style, particle["rect"] as ColorRect)
            _particles[i] = particle
        var rect: ColorRect = particle["rect"]
        rect.position = Vector2(roundf(float(particle["x"])), roundf(float(particle["y"])))
        rect.modulate.a = clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0) * 0.9
