extends RefCounted
class_name Fx
## One-shot particle bursts, the Godot stand-in for the canvas particle pool in
## js/render/renderer.js.

static func burst(parent: Node, at: Vector2, color: Color, count: int = 8, speed: float = 80.0) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var particles := CPUParticles2D.new()
    particles.position = at
    particles.amount = maxi(1, count)
    particles.lifetime = 0.6
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.emitting = true
    particles.direction = Vector2.UP
    particles.spread = 180.0
    particles.gravity = Vector2(0, 160)
    particles.initial_velocity_min = speed * 0.4
    particles.initial_velocity_max = speed * 1.1
    particles.scale_amount_min = 1.0
    particles.scale_amount_max = 2.0
    particles.color = color
    parent.add_child(particles)
    var tree := parent.get_tree()
    if tree == null:
        return
    var timer := tree.create_timer(0.9, true, false, true)
    timer.timeout.connect(particles.queue_free)

