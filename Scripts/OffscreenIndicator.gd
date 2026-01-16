extends Node2D

@export var size: float = 18.0
@export var lifetime: float = 0.8

var _elapsed: float = 0.0
var _color: Color = Color(1, 1, 1, 0.9)

func setup(direction: Vector2, color: Color, life: float = -1.0) -> void:
	if life > 0.0:
		lifetime = life
	_color = color
	_elapsed = 0.0
	var dir := direction
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	rotation = dir.angle()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_elapsed / max(lifetime, 0.01), 0.0, 1.0)
	var col := _color
	col.a *= 1.0 - t
	var w := size
	var h := size * 0.6
	var points := PackedVector2Array([
		Vector2(w, 0.0),
		Vector2(0.0, -h),
		Vector2(0.0, h)
	])
	draw_polygon(points, PackedColorArray([col, col, col]))
