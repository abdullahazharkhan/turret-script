extends Node2D
class_name GameWorld

@onready var enemy_path = $EnemyPath
@onready var turret = $TurretPosition/Turret

var enemy_scene = preload("res://scenes/entities/enemy.tscn")
var enemy_id_counter: int = 0
var time_since_spawn: float = 0.0

var debug_stepping_enabled: bool = false

func _process(delta):
	if debug_stepping_enabled:
		return
		
	time_since_spawn += delta
	if time_since_spawn >= 2.0:
		time_since_spawn = 0.0
		_spawn_enemy()

func debug_step(delta: float):
	time_since_spawn += delta
	if time_since_spawn >= 2.0:
		time_since_spawn = 0.0
		_spawn_enemy()

func _spawn_enemy():
	var path_follow = PathFollow2D.new()
	path_follow.loop = false
	enemy_path.add_child(path_follow)
	
	var enemy = enemy_scene.instantiate()
	enemy.id = enemy_id_counter
	enemy_id_counter += 1
	enemy.path_follow = path_follow
	path_follow.add_child(enemy)

func api_get_enemies() -> Array:
	var enemies = []
	for child in enemy_path.get_children():
		if child is PathFollow2D and child.get_child_count() > 0:
			var e = child.get_child(0)
			if e is Enemy and e.alive:
				enemies.append(e)
	return enemies

func api_nearest() -> Node2D:
	var enemies = api_get_enemies()
	var nearest = null
	var min_dist = INF
	var t_pos = turret.global_position
	for e in enemies:
		var d = t_pos.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest

func api_distance(enemy: Node2D) -> float:
	if is_instance_valid(enemy):
		return turret.global_position.distance_to(enemy.global_position)
	return INF

func api_shoot(enemy: Node2D):
	if is_instance_valid(enemy):
		turret.shoot(enemy)

func api_reload():
	turret.reload()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			var n = api_nearest()
			if n:
				api_shoot(n)
		elif event.keycode == KEY_R:
			api_reload()

