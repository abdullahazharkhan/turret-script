extends Node2D

class_name GameWorld

@onready var enemy_path = $EnemyPath
@onready var turret_position = $TurretPosition
@onready var debug_label = $DebugLabel
@onready var tower_sprite = $Tower



signal vm_log(msg: String)
signal vm_error(msg: String)

const TurretScriptVM = preload("res://scripts/runtime/turretscript_vm.gd")
const APIAdapter = preload("res://scripts/runtime/turret_api_adapter.gd")
const TURRET_SCENE = preload("res://scenes/entities/turret.tscn")
const TOWER_SCENE = preload("res://scenes/entities/tower.tscn")
const DIR_SCALE = 100.0

var enemy_scene = preload("res://scenes/entities/enemy.tscn")
var enemy_id_counter: int = 0
var time_since_spawn: float = 0.0
var elapsed_time: float = 0.0
const BASE_SPAWN_INTERVAL = 2.0
const MIN_SPAWN_INTERVAL = 0.4  # Decreased from 0.6
const SPAWN_INTERVAL_DECAY = 0.04 # Increased from 0.02

var debug_stepping_enabled: bool = false
var is_simulating: bool = false

var active_ir_program = null
var vm: TurretScriptVM = null
var ai_tick_timer: float = 0.0
const AI_TICK_RATE = 0.2

var last_targeted_enemy: Node2D = null
var reached_enemy_count: int = 0
var turret: Node2D = null
var _initial_turret_local_pos: Vector2 = Vector2.ZERO
var _initial_tower_pos: Vector2 = Vector2.ZERO
var _initial_tower_scale: Vector2 = Vector2.ONE

func _ready():
	_capture_initial_state()
	_ensure_tower()
	_ensure_turret()

func _capture_initial_state() -> void:
	if is_instance_valid(turret_position):
		var existing = turret_position.get_node_or_null("Turret")
		if is_instance_valid(existing):
			turret = existing
			_initial_turret_local_pos = existing.position
		else:
			_initial_turret_local_pos = Vector2.ZERO
	if is_instance_valid(tower_sprite):
		_initial_tower_pos = tower_sprite.position
		_initial_tower_scale = tower_sprite.scale

func _ensure_turret() -> void:
	if is_instance_valid(turret):
		return
	if not is_instance_valid(turret_position):
		return
	var existing = turret_position.get_node_or_null("Turret")
	if is_instance_valid(existing):
		turret = existing
	else:
		var new_turret = TURRET_SCENE.instantiate()
		turret_position.add_child(new_turret)
		turret = new_turret
	if is_instance_valid(turret):
		turret.position = _initial_turret_local_pos
		turret.is_simulating = is_simulating

func _ensure_tower() -> void:
	if is_instance_valid(tower_sprite):
		tower_sprite.visible = true
		return
	var new_tower = TOWER_SCENE.instantiate()
	add_child(new_tower)
	tower_sprite = new_tower
	tower_sprite.position = _initial_tower_pos
	tower_sprite.scale = _initial_tower_scale

func load_program(ir):
	active_ir_program = ir
	_reset_vm()

func _reset_vm():
	if active_ir_program:
		var adapter = APIAdapter.new(self)
		vm = TurretScriptVM.new(active_ir_program, adapter)
		vm.max_ops_per_tick = 500
		vm.log_message.connect(func(msg): vm_log.emit(msg))
		vm.runtime_error.connect(func(msg): vm_error.emit(msg))

func toggle_simulation():
	is_simulating = not is_simulating
	if is_instance_valid(turret):
		turret.is_simulating = is_simulating

func reset_wave():
	is_simulating = false
	time_since_spawn = 0.0
	elapsed_time = 0.0
	ai_tick_timer = 0.0
	for c in enemy_path.get_children():
		c.queue_free()
	enemy_id_counter = 0
	reached_enemy_count = 0
	_ensure_tower()
	_ensure_turret()
	if is_instance_valid(turret):
		turret.ammo = turret.max_ammo
		turret.time_since_last_shot = turret.cooldown
		turret.is_simulating = false
		turret.position = _initial_turret_local_pos
		turret.run_direction = Vector2.ZERO
		turret.run_speed = 0.0
	if is_instance_valid(tower_sprite):
		tower_sprite.position = _initial_tower_pos
		tower_sprite.scale = _initial_tower_scale
	last_targeted_enemy = null
	_reset_vm()
	queue_redraw()

func _process(delta):
	_update_hud()
	
	if debug_stepping_enabled or not is_simulating:
		return
	
	elapsed_time += delta
	time_since_spawn += delta
	var spawn_interval = max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - (elapsed_time * SPAWN_INTERVAL_DECAY))
	if time_since_spawn >= spawn_interval:
		time_since_spawn = 0.0
		_spawn_enemy()
		
	if vm:
		ai_tick_timer += delta
		if ai_tick_timer >= AI_TICK_RATE:
			ai_tick_timer = 0.0
			_reset_vm()
			vm.run()
	
	queue_redraw()

func _draw():
	if is_instance_valid(last_targeted_enemy) and last_targeted_enemy.alive and is_instance_valid(turret):
		draw_line(turret.global_position, last_targeted_enemy.global_position, Color(1, 0, 0, 0.5), 2.0)
		draw_circle(last_targeted_enemy.global_position, 20.0, Color(1, 0, 0, 0.3))

func _update_hud():
	if not debug_label: return
	var text = "--- TURRET HUD ---\n"
	if is_instance_valid(turret):
		text += "Ammo: %d / %d\n" % [turret.ammo, turret.max_ammo]
		text += "Cooldown: %.1fs\n" % max(0.0, turret.cooldown - turret.time_since_last_shot)
		var spawn_interval = max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - (elapsed_time * SPAWN_INTERVAL_DECAY))
		text += "Enemy Spawn: %.2fs\n" % spawn_interval
	else:
		text += "Tower: DESTROYED - GAME OVER\n"
	text += "Reached Enemies: %d\n" % reached_enemy_count
	text += "Simulation: %s (x%.1f)\n" % [("RUNNING" if is_simulating else "PAUSED"), Engine.time_scale]
	if vm:
		text += "VM State: %d  IP: %d" % [vm.context.state, vm.context.ip]
	else:
		text += "VM: No Program"
	debug_label.text = text

func debug_step(delta: float):
	elapsed_time += delta
	time_since_spawn += delta
	var spawn_interval = max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - (elapsed_time * SPAWN_INTERVAL_DECAY))
	if time_since_spawn >= spawn_interval:
		time_since_spawn = 0.0
		_spawn_enemy()

func _spawn_enemy():
	# Create a unique path for this enemy to randomize their route
	var new_path = Path2D.new()
	var base_curve = enemy_path.curve
	var new_curve = Curve2D.new()
	
	for i in range(base_curve.point_count):
		var pos = base_curve.get_point_position(i)
		# Don't jitter the start and end points too much to keep them within bounds
		if i == 0:
			pos += Vector2(0, randf_range(-50, 50))
		elif i == base_curve.point_count - 1:
			# End point should stay near the tower
			pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))
		else:
			# Jitter middle points significantly for different routes
			pos += Vector2(randf_range(-150, 150), randf_range(-150, 150))
		new_curve.add_point(pos)
	
	new_path.curve = new_curve
	enemy_path.add_child(new_path)
	
	var path_follow = PathFollow2D.new()
	path_follow.loop = false
	new_path.add_child(path_follow)
	
	var enemy = enemy_scene.instantiate()
	enemy.id = enemy_id_counter
	enemy_id_counter += 1
	enemy.path_follow = path_follow
	path_follow.add_child(enemy)

func api_get_enemies() -> Array:
	var enemies = []

	# Search through all paths in the enemy_path container
	for path_node in enemy_path.get_children():
		# The path_node might be a Path2D (new structure) or PathFollow2D (old structure)
		if path_node is Path2D:
			for follow_node in path_node.get_children():
				if follow_node is PathFollow2D and follow_node.get_child_count() > 0:
					var e = follow_node.get_child(0)
					if e.has_method("take_damage") and e.get("alive") == true:
						enemies.append(e)
		elif path_node is PathFollow2D and path_node.get_child_count() > 0:
			var e = path_node.get_child(0)
			if e.has_method("take_damage") and e.get("alive") == true:
				enemies.append(e)

	return enemies

func api_nearest(enemies: Array) -> Node2D:
	var nearest = null
	var min_dist = INF
	if not is_instance_valid(turret):
		return null
	var t_pos = turret.global_position
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			var d = t_pos.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest

func api_distance(enemy: Node2D) -> float:
	if is_instance_valid(turret) and is_instance_valid(enemy):
		return turret.global_position.distance_to(enemy.global_position)
	return INF

func api_shoot(enemy: Node2D):
	if is_instance_valid(turret) and is_instance_valid(enemy) and enemy.alive:
		last_targeted_enemy = enemy
		turret.shoot(enemy)

func api_reload():
	if is_instance_valid(turret):
		turret.api_reload()

func _round_int(value: float) -> int:
	return int(round(value))

func api_enemy_x(enemy) -> int:
	if is_instance_valid(enemy):
		return _round_int(enemy.global_position.x)
	return 0

func api_enemy_y(enemy) -> int:
	if is_instance_valid(enemy):
		return _round_int(enemy.global_position.y)
	return 0

func api_enemy_dir_x(enemy) -> int:
	if is_instance_valid(enemy) and enemy.has_method("get"):
		var dir_val = enemy.get("move_dir")
		if typeof(dir_val) == TYPE_VECTOR2:
			return _round_int(dir_val.x * DIR_SCALE)
	return 0

func api_enemy_dir_y(enemy) -> int:
	if is_instance_valid(enemy) and enemy.has_method("get"):
		var dir_val = enemy.get("move_dir")
		if typeof(dir_val) == TYPE_VECTOR2:
			return _round_int(dir_val.y * DIR_SCALE)
	return 0

func api_turret_x() -> int:
	if is_instance_valid(turret):
		return _round_int(turret.global_position.x)
	return 0

func api_turret_y() -> int:
	if is_instance_valid(turret):
		return _round_int(turret.global_position.y)
	return 0

func _to_float(value) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return 0.0

func api_run(dx, dy, speed):
	if not is_instance_valid(turret):
		return
	var dir = Vector2(_to_float(dx), _to_float(dy))
	turret.run_direction = dir
	turret.run_speed = max(0.0, _to_float(speed))

func on_enemy_reached_tower():
	reached_enemy_count += 1
	if reached_enemy_count >= 10:
		# Visual blast at tower, then remove tower sprite (not the turret node).
		_spawn_tower_blast()
		if is_instance_valid(tower_sprite):
			tower_sprite.visible = false
			tower_sprite.queue_free()
			tower_sprite = null
		# Keep turret node removal as-is (it controls VM targeting).
		if is_instance_valid(turret):
			turret.queue_free()
			turret = null
		is_simulating = false
		print("Tower destroyed! Game Over.")


func _spawn_tower_blast() -> void:
	# Spawn the explosion at the visual tower sprite position.
	# Note: this can be triggered right as nodes are being freed, so we must
	# read positions before freeing.
	var explosion_scene := preload("res://scenes/entities/explosion_effect.tscn")
	var fx := explosion_scene.instantiate()

	var pos := Vector2.ZERO
	if is_instance_valid(tower_sprite):
		pos = tower_sprite.global_position
	elif is_instance_valid(turret):
		pos = turret.global_position

	fx.global_position = pos
	get_tree().current_scene.add_child(fx)





func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			Engine.time_scale = 1.0
		elif event.keycode == KEY_2:
			Engine.time_scale = 2.0
		elif event.keycode == KEY_3:
			Engine.time_scale = 4.0
		elif event.keycode == KEY_SPACE:
			var n = api_nearest(api_get_enemies())
			if n:
				api_shoot(n)
		elif event.keycode == KEY_R:


			api_reload()
