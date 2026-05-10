extends Node2D
class_name Turret

var ammo: int = 10
var max_ammo: int = 10
var cooldown: float = 0.4  # Decreased from 0.8
var time_since_last_shot: float = 0.0
var ammo_type: String = "basic"
@export var run_direction: Vector2 = Vector2.ZERO
@export var run_speed: float = 0.0
@export var rotation_speed: float = 15.0
var is_simulating: bool = false
var current_target: Node2D = null

# Burst fire properties
var burst_count: int = 3
var burst_interval: float = 0.1
var shots_in_burst: int = 0
var time_since_burst_shot: float = 0.0
var is_bursting: bool = false

@onready var barrel = $TurretBarrel
var projectile_scene = preload("res://scenes/entities/projectile.tscn")

func _process(delta):
	time_since_last_shot += delta
	_apply_run(delta)
	_track_target(delta)
	_process_burst(delta)

func _process_burst(delta: float) -> void:
	if not is_bursting:
		return
	
	time_since_burst_shot += delta
	if time_since_burst_shot >= burst_interval:
		if ammo > 0 and is_instance_valid(current_target) and current_target.alive:
			_fire_projectile(current_target)
			shots_in_burst += 1
			time_since_burst_shot = 0.0
			
			if shots_in_burst >= burst_count or ammo <= 0:
				is_bursting = false
		else:
			is_bursting = false

func _apply_run(delta: float) -> void:
	if not is_simulating:
		return
	if run_speed <= 0.0:
		return
	if run_direction == Vector2.ZERO:
		return
	# Increased base speed by 1.5x
	position += run_direction.normalized() * run_speed * 1.5 * delta

func _track_target(delta: float) -> void:
	if is_instance_valid(current_target) and current_target.alive:
		var target_dir = (current_target.global_position - global_position).normalized()
		var target_angle = target_dir.angle()
		barrel.rotation = rotate_toward(barrel.rotation, target_angle, rotation_speed * delta)

func set_target(target: Node2D):
	current_target = target

func shoot(target: Node2D):
	if ammo <= 0:
		api_reload()
		return

	if not is_bursting and ammo > 0 and time_since_last_shot >= cooldown:
		set_target(target)
		
		# Only start burst if we are somewhat aimed at the target
		var target_dir = (target.global_position - global_position).normalized()
		var angle_to_target = abs(angle_difference(barrel.rotation, target_dir.angle()))
		
		if angle_to_target < 0.2: # Roughly 11 degrees
			is_bursting = true
			shots_in_burst = 0
			time_since_burst_shot = burst_interval # Fire first shot immediately
			time_since_last_shot = 0.0

func _fire_projectile(target: Node2D):
	ammo -= 1
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	proj.target = target
	# Make projectile faster
	proj.speed *= 2.0
	get_tree().current_scene.add_child(proj)
	print("Turret shot at enemy in burst! Ammo left: ", ammo)

func api_reload():
	ammo = max_ammo
	print("Turret reloaded!")
