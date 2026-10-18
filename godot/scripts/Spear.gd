extends Area2D
class_name Spear
## The thrown spear. An Area2D so it can overlap Bat, Bug and the boss.

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var pierce: int = 0            ## how many extra enemies the spear may pass through
var _spent: int = 0

func _ready() -> void:
    var sprite := get_node_or_null("Sprite") as Sprite2D
    if sprite != null:
        sprite.texture = Sprites.spear(UpgradeSystem.spear_design)
        sprite.scale = Vector2.ONE * Rules.scale_for(Rules.ART_SCALE)

func launch(from: Vector2, direction: Vector2, speed: float, power: int, pierce_count: int) -> void:
    position = from
    velocity = direction.normalized() * speed
    damage = power
    pierce = pierce_count
    rotation = velocity.angle() + PI / 2.0

func _physics_process(delta: float) -> void:
    position += velocity * delta
    if position.y < -40.0 or position.x < -24.0 or position.x > Rules.WORLD_W + 24.0:
        queue_free()

## Returns true when the spear survives the hit (it had a pierce charge left).
func spend_pierce() -> bool:
    if _spent < pierce:
        _spent += 1
        return true
    queue_free()
    return false

