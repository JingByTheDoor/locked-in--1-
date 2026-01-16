extends Node2D

@export var duration: float = 0.25
@export var radius: float = 5.0
@export var scatter: float = 8.0
@export var color: Color = Color(0.9, 0.1, 0.1, 0.9)
@export var dot_count: int = 4

var _elapsed: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	if _points.is_empty():
		_generate_points()
	queue_redraw()

func setup(new_color: Color, new_radius: float = -1.0, new_duration: float = -1.0) -> void:
	if new_radius > 0.0:
		radius = new_radius
	if new_duration > 0.0:
		duration = new_duration
	color = new_color
	_generate_points()
	_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _generate_points() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_points = PackedVector2Array()
	var count: int = max(dot_count, 1)
	for i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(0.0, scatter)
		_points.push_back(Vector2.RIGHT.rotated(angle) * dist)

func _draw() -> void:
	var t: float = clampf(_elapsed / max(duration, 0.01), 0.0, 1.0)
	var col: Color = color
	col.a *= 1.0 - t
	var draw_radius: float = lerpf(radius, max(1.0, radius * 0.5), t)
	for p in _points:
		draw_circle(p, draw_radius, col)
