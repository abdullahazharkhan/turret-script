extends CharacterBody2D
class_name Enemy

var id: int = 0
var enemy_type: String = "scout"
var health: int = 100
var speed: float = 100.0
var armor: int = 0
var alive: bool = true

var path_follow: PathFollow2D

func _ready():
	pass

func _physics_process(delta):
	if alive and path_follow:
		path_follow.progress += speed * delta

func take_damage(amount: int):
	var actual_damage = max(1, amount - armor)
	health -= actual_damage
	if health <= 0 and alive:
		die()

func die():
	alive = false
	queue_free()
