extends Area2D
class_name Bug
## The boss's projectile - the port of the bug entity in js/core/simulation.js.

var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
    var sprite := get_node_or_null("Sprite") as Sprite2D
    if sprite != null:
        sprite.scale = Vector2.ONE * Rules.scale_for(Rules.ART_SCALE)
    area_entered.connect(_on_area_entered)

func launch(from: Vector2, direction: Vector2, speed: float) -> void:
    position = from
    velocity = direction.normalized() * speed

func _physics_process(delta: float) -> void:
    position += velocity * delta
    if position.y > Rules.WORLD_H + 20.0 or position.x < -30.0 or position.x > Rules.WORLD_W + 30.0:
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if area is Spear:
        (area as Spear).spend_pierce()
        queue_free()
    elif area is Player:
        (area as Player).take_hit()
        queue_free()

