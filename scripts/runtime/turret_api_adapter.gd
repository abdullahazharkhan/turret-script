extends RefCounted

signal log_message(msg: String)

var game_world = null

func _init(world = null):
	game_world = world

func get_enemies() -> Array:
	emit_signal("log_message", "[API] get_enemies() called.")
	if game_world and game_world.has_method("get_enemies"):
		return game_world.get_enemies()
	# Mock data for testing
	return [
		{"id": 1, "health": 100, "type": "scout", "distance": 150},
		{"id": 2, "health": 200, "type": "tank", "distance": 50}
	]

func nearest(enemies: Array):
	emit_signal("log_message", "[API] nearest() called with %d enemies." % enemies.size())
	if enemies.is_empty(): return null
	
	var closest = enemies[0]
	var min_dist = _get_distance(closest)
	
	for e in enemies:
		var d = _get_distance(e)
		if d < min_dist:
			min_dist = d
			closest = e
	return closest

func distance(enemy) -> int:
	var d = _get_distance(enemy)
	emit_signal("log_message", "[API] distance() returned %d." % d)
	return d

func shoot(enemy):
	emit_signal("log_message", "[API] -> SHOOTING enemy ID: %s" % str(enemy.get("id", "?") if typeof(enemy) == TYPE_DICTIONARY else "?"))
	if game_world and game_world.has_method("shoot"):
		game_world.shoot(enemy)

func reload():
	emit_signal("log_message", "[API] -> RELOADING turret.")
	if game_world and game_world.has_method("reload"):
		game_world.reload()

func _get_distance(enemy) -> int:
	if typeof(enemy) == TYPE_DICTIONARY and enemy.has("distance"):
		return enemy["distance"]
	return 9999
