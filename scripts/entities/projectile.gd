extends Area2D
class_name Projectile

var target: Node2D
var speed: float = 400.0
var damage: int = 20

func _physics_process(delta):
	if is_instance_valid(target) and target.has_method("take_damage"):
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * speed * delta
		look_at(target.global_position)
		
		if global_position.distance_to(target.global_position) < 10.0:
			target.take_damage(damage)
			queue_free()
	else:
		queue_free()
