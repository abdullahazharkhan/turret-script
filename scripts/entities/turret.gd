extends Node2D
class_name Turret

var ammo: int = 10
var max_ammo: int = 10
var cooldown: float = 0.2
var time_since_last_shot: float = 0.0
var ammo_type: String = "basic"
@export var run_direction: Vector2 = Vector2.ZERO
@export var run_speed: float = 0.0
var is_simulating: bool = false

@onready var barrel = $TurretBarrel
var projectile_scene = preload("res://scenes/entities/projectile.tscn")

func _process(delta):
	time_since_last_shot += delta
	_apply_run(delta)

func _apply_run(delta: float) -> void:
	if not is_simulating:
		return
	if run_speed <= 0.0:
		return
	if run_direction == Vector2.ZERO:
		return
	position += run_direction.normalized() * run_speed * delta

func set_target(target: Node2D):
	if is_instance_valid(target):
		barrel.look_at(target.global_position)

func shoot(target: Node2D):
	if ammo <= 0:
		api_reload()

	if ammo > 0 and time_since_last_shot >= cooldown:
		ammo -= 1
		time_since_last_shot = 0.0
		set_target(target)
		
		var proj = projectile_scene.instantiate()
		proj.global_position = global_position
		proj.target = target
		get_tree().current_scene.add_child(proj)
		print("Turret shot at enemy! Ammo left: ", ammo)

func api_reload():
	ammo = max_ammo
	print("Turret reloaded!")
