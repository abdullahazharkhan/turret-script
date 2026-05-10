extends Node2D

class_name GameWorld

@onready var enemy_path = $EnemyPath
@onready var turret = $TurretPosition/Turret
@onready var debug_label = $DebugLabel
@onready var tower_sprite = $Tower



signal vm_log(msg: String)
signal vm_error(msg: String)

const TurretScriptVM = preload("res://scripts/runtime/turretscript_vm.gd")
const APIAdapter = preload("res://scripts/runtime/turret_api_adapter.gd")

var enemy_scene = preload("res://scenes/entities/enemy.tscn")
var enemy_id_counter: int = 0
var time_since_spawn: float = 0.0

var debug_stepping_enabled: bool = false
var is_simulating: bool = false

var active_ir_program = null
var vm: TurretScriptVM = null
var ai_tick_timer: float = 0.0
const AI_TICK_RATE = 0.2

var last_targeted_enemy: Node2D = null
var reached_enemy_count: int = 0

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

func reset_wave():
	is_simulating = false
	time_since_spawn = 0.0
	ai_tick_timer = 0.0
	for c in enemy_path.get_children():
		c.queue_free()
	enemy_id_counter = 0
	reached_enemy_count = 0
	if is_instance_valid(turret):
		turret.ammo = turret.max_ammo
		turret.time_since_last_shot = turret.cooldown
	last_targeted_enemy = null
	_reset_vm()
	queue_redraw()

func _process(delta):
	_update_hud()
	
	if debug_stepping_enabled or not is_simulating:
		return
		
	time_since_spawn += delta
	if time_since_spawn >= 2.0:
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

func on_enemy_reached_tower():
	reached_enemy_count += 1
	if reached_enemy_count >= 10:
		# Visual blast at tower, then remove tower sprite (not the turret node).
		_spawn_tower_blast()
		if is_instance_valid(tower_sprite):
			tower_sprite.visible = false
			tower_sprite.queue_free()
		# Keep turret node removal as-is (it controls VM targeting).
		if is_instance_valid(turret):
			turret.queue_free()
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
