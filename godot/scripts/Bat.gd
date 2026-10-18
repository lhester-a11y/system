extends Area2D
class_name Bat
## A bat carrying a syntax box - the port of the bat + boss entities in
## js/core/simulation.js.
##
## A normal bat dies to one spear thrust and reports `killed`, which is what
## opens the learning checkpoint. The boss (`is_boss`) is never killed by a
## spear: a spear reaching it reports `boss_engaged` and only a *correct answer*
## takes a health point off it, through lose_health().

signal killed(bat: Bat, code_box: String)
signal wounded(bat: Bat)
signal boss_engaged(bat: Bat)
signal fired(bat: Bat, origin: Vector2, velocity_speed: float)

var speed: float = 46.0
var altitude_min: float = 110.0
var altitude_max: float = 330.0
var dive_speed: float = 155.0
var approach_speed: float = 48.0
var return_speed: float = 135.0
var can_dive: bool = false
var code_box: String = "HTML"
var hp: int = 1
var max_hp: int = 1
var direction: int = 1
var is_boss: bool = false
var invulnerable: float = 0.0
var fire_interval: float = 1.7
var solved: bool = false
## Set by Main so a diving bat can chase the warrior.
var target: Node2D = null

var _base_y: float = 0.0
var _bob: float = 0.0
var _mode: String = "wave"      ## wave -> dive -> return
var _dive_at: float = 0.0
var _fire_timer: float = 1.8
var _elapsed: float = 0.0
var _sprite: Sprite2D
var _crown: Sprite2D
var _warn: ColorRect
var _hp_track: ColorRect
var _hp_fill: ColorRect

func _ready() -> void:
    _sprite = get_node_or_null("Sprite") as Sprite2D
    _crown = get_node_or_null("Crown") as Sprite2D
    hp = max_hp
    _base_y = randf_range(altitude_min, altitude_max)
    position.y = _base_y
    direction = 1 if randf() > 0.5 else -1
    _dive_at = randf_range(3.5, 9.0)
    if _sprite != null:
        _sprite.scale = Vector2.ONE * Rules.scale_for(6.0 if is_boss else Rules.ART_SCALE)
    if _crown != null:
        _crown.texture = load("res://assets/sprites/crown.png")
        _crown.scale = Vector2.ONE * Rules.scale_for(3.0)
        _crown.position = Vector2(0, -46)
        _crown.visible = is_boss

    # A dive warning (the web renderer blinks a red square under a diving bat)
    # and a small health bar for bats that take more than one hit.
    _warn = ColorRect.new()
    _warn.position = Vector2(-3, 20)
    _warn.size = Vector2(6, 6)
    _warn.color = Color("#ef6a5a")
    _warn.visible = false
    _warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_warn)

    _hp_track = ColorRect.new()
    _hp_track.position = Vector2(-16, -26)
    _hp_track.size = Vector2(32, 5)
    _hp_track.color = Color("#0a0e18")
    _hp_track.visible = false
    _hp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_hp_track)

    _hp_fill = ColorRect.new()
    _hp_fill.position = Vector2(-15, -25)
    _hp_fill.size = Vector2(30, 3)
    _hp_fill.color = Color("#5fe08a")
    _hp_fill.visible = false
    _hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_hp_fill)

    area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
    if solved or get_tree().paused:
        return
    _elapsed += delta
    _bob += delta * (1.6 if is_boss else 2.4)

    if is_boss:
        _process_boss(delta)
        return

    if _sprite != null:
        _sprite.flip_h = direction > 0

    if _warn != null:
        _warn.visible = _mode == "dive"
        if _warn.visible:
            _warn.modulate.a = 0.4 + 0.3 * sin(_elapsed * 18.0)

    match _mode:
        "wave":
            position.x += direction * speed * delta
            position.y = _base_y + sin(_bob) * 7.0
            if can_dive and _elapsed >= _dive_at:
                _mode = "dive"
        "dive":
            position.y += dive_speed * delta
            if target != null:
                position.x += signf(target.position.x - position.x) * approach_speed * delta
            if position.y > Rules.GROUND_Y - 16.0:
                _mode = "return"
        _:
            position.y -= return_speed * delta
            if position.y <= _base_y:
                position.y = _base_y
                _mode = "wave"
                _dive_at = _elapsed + randf_range(4.5, 10.0)

    # Wrap instead of escaping, so the player is never stuck waiting for a bat.
    if position.x < -60.0:
        position.x = Rules.WORLD_W + 60.0
    elif position.x > Rules.WORLD_W + 60.0:
        position.x = -60.0

func _process_boss(delta: float) -> void:
    position.x += direction * speed * delta
    if position.x < 72.0:
        position.x = 72.0
        direction = 1
    elif position.x > Rules.WORLD_W - 72.0:
        position.x = Rules.WORLD_W - 72.0
        direction = -1
    position.y = 150.0 + sin(_bob) * 16.0
    if invulnerable > 0.0:
        invulnerable -= delta
        visible = int(invulnerable * 18.0) % 2 == 0
        if invulnerable <= 0.0:
            visible = true
    _fire_timer -= delta
    if _fire_timer <= 0.0:
        _fire_timer = fire_interval * randf_range(0.8, 1.25)
        fired.emit(self, position + Vector2(0, 26), speed * 3.0 + 60.0)

func _on_area_entered(area: Area2D) -> void:
    if solved or get_tree().paused:
        return
    if area is Spear:
        var spear := area as Spear
        if is_boss:
            if invulnerable > 0.0:
                return
            spear.spend_pierce()
            boss_engaged.emit(self)
            return
        var survives := spear.spend_pierce()
        apply_damage(spear.damage)
        if survives:
            pass    # the spear keeps flying
    elif area is Player:
        (area as Player).take_hit()

func apply_damage(amount: int) -> void:
    if is_boss or solved:
        return
    hp -= amount
    _refresh_health_bar()
    if hp > 0:
        wounded.emit(self)
        return
    solved = true
    set_deferred("monitoring", false)
    killed.emit(self, code_box)
    _dissolve()

## Called by Main when a boss checkpoint is answered correctly. Returns true when
## that answer finished the boss off.
func lose_health() -> bool:
    hp -= 1
    if hp > 0:
        invulnerable = 1.4
        return false
    solved = true
    set_deferred("monitoring", false)
    killed.emit(self, code_box)
    _dissolve()
    return true

## The web build draws a 32x5 bar over any bat that can take more than one hit.
func _refresh_health_bar() -> void:
    if _hp_track == null:
        return
    var damaged := max_hp > 1 and hp < max_hp
    _hp_track.visible = damaged
    _hp_fill.visible = damaged
    if damaged:
        _hp_fill.size = Vector2(roundf(30.0 * float(hp) / float(max_hp)), 3.0)

func _dissolve() -> void:
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.08)
    tween.tween_property(self, "modulate:a", 0.0, 0.18)
    tween.finished.connect(queue_free)

