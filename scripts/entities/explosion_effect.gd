extends Sprite2D

@export var frame_count: int = 6
@export var fps: int = 12
@export var loop: bool = false
@export var autostart: bool = true

var _elapsed := 0.0
var _started := false

func _exit_tree() -> void:
	# Ensure it never lingers in the scene.
	_started = false


func _ready() -> void:
	if autostart:
		start()

func start() -> void:
	if _started:
		return
	_started = true
	_elapsed = 0.0

func _process(delta: float) -> void:
	if not _started:
		return
	_elapsed += delta
	var frame := int(floor(_elapsed * float(fps)))
	if loop:
		frame = frame % frame_count
	else:
		if frame >= frame_count:
			queue_free()
			return

	# explosion_sheet_6x1.png (6 frames, 1 row)
	# Sprite2D uses region rect in pixels.
	# Godot 4: use texture's size; region is set in pixels.
	var tex := texture
	if tex == null:
		return
	var w := tex.get_width() / float(frame_count)
	var h := tex.get_height()
	region_enabled = true
	region_rect = Rect2(int(frame * w), 0, int(w), h)

	# subtle scale-up for impact
	# (safe even if you change this later)
	scale = Vector2.ONE * (1.0 + 0.15 * (1.0 - float(frame) / float(frame_count)))

