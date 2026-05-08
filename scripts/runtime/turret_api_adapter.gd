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

func _get_distance(enemy) -> int:
	if typeof(enemy) == TYPE_DICTIONARY and enemy.has("distance"):
		return enemy["distance"]
	return 9999
