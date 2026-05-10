extends RefCounted

signal log_message(msg: String)

var game_world = null

func _init(world = null):
	game_world = world

func get_enemies() -> Array:
	emit_signal("log_message", "[API] get_enemies() called.")
	if game_world and game_world.has_method("api_get_enemies"):
		return game_world.api_get_enemies()
	return []

func nearest(enemies: Array):
	emit_signal("log_message", "[API] nearest() called with %d enemies." % enemies.size())
	if enemies.is_empty(): return null
	
	if game_world and game_world.has_method("api_nearest"):
		return game_world.api_nearest(enemies)
		
	return null

func distance(enemy) -> int:
	if game_world and game_world.has_method("api_distance"):
		var d = int(game_world.api_distance(enemy))
		emit_signal("log_message", "[API] distance() returned %d." % d)
		return d
	return 9999

func shoot(enemy):
	var eid = enemy.id if (typeof(enemy) == TYPE_OBJECT and "id" in enemy) else "?"
	emit_signal("log_message", "[API] -> SHOOTING enemy ID: %s" % str(eid))
	if game_world and game_world.has_method("api_shoot"):
		game_world.api_shoot(enemy)

func reload():
	emit_signal("log_message", "[API] -> RELOADING turret.")
	if game_world and game_world.has_method("api_reload"):
		game_world.api_reload()

func run(dx, dy, speed):
	emit_signal("log_message", "[API] -> RUN dir=(%s,%s) speed=%s" % [str(dx), str(dy), str(speed)])
	if game_world and game_world.has_method("api_run"):
		game_world.api_run(dx, dy, speed)

func enemy_x(enemy) -> int:
	if game_world and game_world.has_method("api_enemy_x"):
		return game_world.api_enemy_x(enemy)
	return 0

func enemy_y(enemy) -> int:
	if game_world and game_world.has_method("api_enemy_y"):
		return game_world.api_enemy_y(enemy)
	return 0

func enemy_dir_x(enemy) -> int:
	if game_world and game_world.has_method("api_enemy_dir_x"):
		return game_world.api_enemy_dir_x(enemy)
	return 0

func enemy_dir_y(enemy) -> int:
	if game_world and game_world.has_method("api_enemy_dir_y"):
		return game_world.api_enemy_dir_y(enemy)
	return 0

func turret_x() -> int:
	if game_world and game_world.has_method("api_turret_x"):
		return game_world.api_turret_x()
	return 0

func turret_y() -> int:
	if game_world and game_world.has_method("api_turret_y"):
		return game_world.api_turret_y()
	return 0

func _get_distance(enemy) -> int:
	if typeof(enemy) == TYPE_DICTIONARY and enemy.has("distance"):
		return enemy["distance"]
	return 9999
