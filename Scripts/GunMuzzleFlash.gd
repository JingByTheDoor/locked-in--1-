extends Node2D

@export var lifetime: float = 0.08
@export var start_scale: float = 0.35
@export var end_scale: float = 0.85
@export var start_alpha: float = 1.0
@export var end_alpha: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

var _time_left: float = 0.0

func _ready() -> void:
	_time_left = max(lifetime, 0.01)
	_apply(0.0)

func _process(delta: float) -> void:
	if sprite == null:
		queue_free()
		return
	_time_left -= delta
	var t: float = 1.0 - clampf(_time_left / max(lifetime, 0.01), 0.0, 1.0)
	_apply(t)
	if _time_left <= 0.0:
		queue_free()

func _apply(t: float) -> void:
	var scale_value: float = lerpf(start_scale, end_scale, t)
	sprite.scale = Vector2.ONE * scale_value
	var color: Color = sprite.modulate
	color.a = lerpf(start_alpha, end_alpha, t)
	sprite.modulate = color
