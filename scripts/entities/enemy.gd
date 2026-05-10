extends CharacterBody2D

var id: int = 0
var enemy_type: String = "scout"
var max_health: int = 70
var health: int = 50
var speed: float = 100.0
var armor: int = 0
var alive: bool = true
var path_follow: PathFollow2D
var reached_tower: bool = false
var move_dir: Vector2 = Vector2.ZERO
var _last_global_pos: Vector2 = Vector2.ZERO

const HEALTH_BAR_WIDTH: float = 34.0
const HEALTH_BAR_HEIGHT: float = 5.0
const HEALTH_BAR_OFFSET: Vector2 = Vector2(-17.0, -28.0)

func _ready():
	max_health = max(1, health)
	_last_global_pos = global_position
	queue_redraw()

func _physics_process(delta):
	if not alive:
		move_dir = Vector2.ZERO
		return

	var prev_pos = global_position

	if path_follow:
		path_follow.progress += speed * delta

		if path_follow.progress_ratio >= 1.0:
			reach_tower()

	var delta_pos = global_position - prev_pos
	if delta_pos.length() > 0.001:
		move_dir = delta_pos.normalized()
	else:
		move_dir = Vector2.ZERO
	_last_global_pos = global_position

func _draw():
	var ratio = clamp(float(health) / float(max_health), 0.0, 1.0)

	draw_rect(Rect2(HEALTH_BAR_OFFSET, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(HEALTH_BAR_OFFSET, Vector2(HEALTH_BAR_WIDTH * ratio, HEALTH_BAR_HEIGHT)), Color(0.1, 0.9, 0.2))
	draw_rect(Rect2(HEALTH_BAR_OFFSET, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color.WHITE, false, 1.0)

func take_damage(amount: int):
	if not alive:
		return

	var actual_damage = max(1, amount - armor)
	health = max(0, health - actual_damage)
	queue_redraw()

	if health <= 0:
		die()

func reach_tower():
	if not alive:
		return

	reached_tower = true
	alive = false

	# Keep the enemy in the scene after reaching the tower.
	# The enemy is no longer active, so it will stop moving and no longer be targeted.
	if is_instance_valid(path_follow):
		path_follow.progress_ratio = 1.0

	# Notify GameWorld
	var game_world = get_parent().get_parent().get_parent()  # GameWorld -> EnemyPath -> PathFollow2D -> Enemy
	if game_world and game_world.has_method("on_enemy_reached_tower"):
		game_world.on_enemy_reached_tower()

func die():
	if not alive:
		return

	alive = false

	if is_instance_valid(path_follow):
		path_follow.call_deferred("queue_free")
	else:
		call_deferred("queue_free")
