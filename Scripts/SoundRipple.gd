extends Node2D

@export var max_radius: float = 220.0
@export var duration: float = 0.9
@export var thickness: float = 2.0

var _elapsed: float = 0.0
var _color: Color = Color(1, 1, 1, 0.8)
var _current_radius: float = 0.0

func setup(radius: float, color: Color, life: float = -1.0) -> void:
	max_radius = max(1.0, radius)
	_color = color
	if life > 0.0:
		duration = life
	_elapsed = 0.0
	_current_radius = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / max(duration, 0.01), 0.0, 1.0)
	_current_radius = lerpf(0.0, max_radius, t)
	if t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_elapsed / max(duration, 0.01), 0.0, 1.0)
	var col := _color
	col.a *= 1.0 - t
	draw_arc(Vector2.ZERO, _current_radius, 0.0, TAU, 64, col, thickness, true)
