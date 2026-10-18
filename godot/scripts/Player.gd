extends Area2D
class_name Player
## The Igorot warrior: walks the terrace, throws spears upward, and survives
## hits with shield charges, hearts and - with the Elder Headdress - one revive.
##
## Movement and throwing come from either the keyboard (the built-in ui_* actions)
## or the on-screen buttons, which set `touch_dir` and `hold_throw`.
##
## Throwing is SINGLE: holding the button down does not keep firing. One press
## sends exactly one spear, which is what the keyboard and the touch pad both do.

signal threw_spear(spear: Spear)
signal took_damage(hearts_left: int)
signal shield_used(charges_left: int)
signal revived(hearts_left: int)
signal died()

const SPEAR_SCENE := preload("res://scenes/Spear.tscn")

var hearts: int = 3
var max_hearts: int = 3
var shield: int = 0
var revives: int = 0
var facing: int = 1
var invulnerable: float = 0.0
## Held while the THROW button or the throw key is down.
var hold_throw: bool = false
## -1 / 0 / 1 from the on-screen arrows. The keyboard uses Input.get_axis().
var touch_dir: float = 0.0
var min_x: float = 26.0
var max_x: float = 334.0

var _cooldown: float = 0.0
var _blink: float = 0.0
var _time: float = 0.0
var _sprite: Sprite2D
var _crown: Sprite2D
## True while the throw control is held, so a hold only fires on the edge.
var _throw_down: bool = false
var _shield_frame: Node2D

func _ready() -> void:
    _sprite = get_node_or_null("Sprite") as Sprite2D
    _crown = get_node_or_null("Crown") as Sprite2D
    if _crown != null:
        _crown.texture = load("res://assets/sprites/crown.png")
        _crown.scale = Vector2.ONE * Rules.scale_for(2.0)
        _crown.position = Vector2(0, -32)
        _crown.visible = false
    _build_shield_frame()

## The blue shimmer the web renderer draws around a shielded warrior: four bars
## that pulse in alpha, so the shield is visible instead of only a HUD number.
func _build_shield_frame() -> void:
    _shield_frame = Node2D.new()
    _shield_frame.visible = false
    add_child(_shield_frame)
    for bar in [[-20.0, -30.0, 40.0, 6.0], [-20.0, 24.0, 40.0, 6.0], [-22.0, -24.0, 4.0, 48.0], [18.0, -24.0, 4.0, 48.0]]:
        var rect := ColorRect.new()
        rect.position = Vector2(float(bar[0]), float(bar[1]))
        rect.size = Vector2(float(bar[2]), float(bar[3]))
        rect.color = Color("#6bb8ff")
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _shield_frame.add_child(rect)

## Put the warrior at the start of a module: full hearts, shields from upgrades
## and gear, fresh art for the chosen hero and garment.
func begin_run(progress: Dictionary) -> void:
    max_hearts = UpgradeSystem.max_hearts()
    hearts = max_hearts
    shield = UpgradeSystem.start_shield()
    revives = UpgradeSystem.revives()
    invulnerable = 0.0
    _cooldown = 0.0
    _blink = 0.0
    _throw_down = false
    visible = true
    position = Vector2(Rules.WORLD_W / 2.0, Rules.GROUND_Y)
    apply_loadout(progress)

func apply_loadout(progress: Dictionary) -> void:
    var hero := String(progress.get("hero", "boy"))
    var equipped: Dictionary = progress.get("equipped", {})
    var garment := String(equipped.get("garment", "garment-bahag"))
    if _sprite != null:
        _sprite.texture = Sprites.hero(hero, garment)
        _sprite.scale = Vector2.ONE * Rules.scale_for(Rules.ART_SCALE)
    if _crown != null:
        _crown.visible = garment == "garment-crown"

func _process(delta: float) -> void:
    _time += delta
    var axis := Input.get_axis("ui_left", "ui_right")
    var direction := touch_dir if absf(touch_dir) > 0.01 else axis
    if absf(direction) > 0.01:
        facing = 1 if direction > 0.0 else -1
    position.x = clampf(position.x + direction * UpgradeSystem.move_speed() * delta, min_x, max_x)

    if invulnerable > 0.0:
        invulnerable -= delta
        _blink += delta
        # Blink by hiding the sprite: the palette is baked into the texture, so
        # modulate would fight with it.
        visible = int(_blink * 12.0) % 2 == 0
        if invulnerable <= 0.0:
            visible = true
    _cooldown = maxf(0.0, _cooldown - delta)

    # Single shot: fire when the throw control goes down, never on every frame
    # it stays down.
    var wants_throw := hold_throw or Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")
    if wants_throw and not _throw_down:
        throw_spear()
    _throw_down = wants_throw

    if _sprite != null:
        _sprite.flip_h = facing < 0
    if _crown != null:
        _crown.flip_h = facing < 0

    if _shield_frame != null:
        _shield_frame.visible = shield > 0 and visible
        for bar in _shield_frame.get_children():
            (bar as ColorRect).modulate.a = 0.28 + 0.12 * sin(_time * 6.0)

## Fire exactly one spear. Respects the cooldown; returns false when the cooldown
## is still running.
func throw_spear() -> bool:
    if _cooldown > 0.0 or get_tree().paused:
        return false
    _cooldown = UpgradeSystem.throw_cooldown()

    var spear: Spear = SPEAR_SCENE.instantiate()
    get_parent().add_child(spear)
    spear.launch(
        global_position + Vector2(8.0 * facing, -34.0),
        Vector2.UP,
        UpgradeSystem.spear_speed(),
        UpgradeSystem.weapon_damage(),
        UpgradeSystem.pierce()
    )
    threw_spear.emit(spear)
    return true

## What a hit did: "immune", "shield", "heart", "revive" or "dead".
func take_hit() -> String:
    if invulnerable > 0.0 or get_tree().paused:
        return "immune"
    invulnerable = 1.6

    if shield > 0:
        shield -= 1
        shield_used.emit(shield)
        return "shield"

    hearts -= 1
    took_damage.emit(hearts)
    if hearts > 0:
        return "heart"
    if revives > 0:
        revives -= 1
        hearts = 1
        invulnerable = 2.6
        revived.emit(hearts)
        return "revive"
    hearts = 0
    died.emit()
    return "dead"

func add_shield(amount: int = 1) -> void:
    shield += amount

func heal(amount: int = 1) -> void:
    hearts = mini(max_hearts, hearts + amount)

