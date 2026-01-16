extends Node2D

@export var ripple_scene: PackedScene
@export var indicator_scene: PackedScene
@export var expected_color: Color = Color(0.85, 0.85, 0.85, 0.85)
@export var anomalous_color: Color = Color(1.0, 0.25, 0.25, 0.95)
@export var indicator_margin: float = 24.0
@export var indicator_lifetime: float = 0.8
@export var indicators_for_expected: bool = false
@export var indicators_for_anomalous: bool = true

@onready var indicator_layer: CanvasLayer = $IndicatorLayer
@onready var indicator_root: Node2D = $IndicatorLayer/Indicators

func _ready() -> void:
	if SoundBus != null:
		SoundBus.sound_emitted.connect(_on_sound_emitted)

func _on_sound_emitted(event: SoundEvent) -> void:
	if event == null:
		return
	var color := _get_color(event)
	_spawn_ripple(event, color)
	_spawn_indicator_if_needed(event, color)

func _get_color(event: SoundEvent) -> Color:
	if event.sound_type == SoundEvent.SoundType.ANOMALOUS:
		return anomalous_color
	return expected_color

func _spawn_ripple(event: SoundEvent, color: Color) -> void:
	if ripple_scene == null:
		return
	var ripple := ripple_scene.instantiate()
	if ripple == null:
		return
	add_child(ripple)
	if ripple is Node2D:
		(ripple as Node2D).global_position = event.position
	if ripple.has_method("setup"):
		var duration := clampf(event.radius / 420.0, 0.45, 1.6)
		ripple.call("setup", event.radius, color, duration)

func _spawn_indicator_if_needed(event: SoundEvent, color: Color) -> void:
	if indicator_scene == null or indicator_root == null:
		return
	var wants_indicator := event.sound_type == SoundEvent.SoundType.ANOMALOUS and indicators_for_anomalous
	if event.sound_type == SoundEvent.SoundType.EXPECTED and indicators_for_expected:
		wants_indicator = true
	if not wants_indicator:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect: Rect2 = viewport.get_visible_rect()
	var screen_pos: Vector2 = viewport.get_canvas_transform() * event.position
	if rect.has_point(screen_pos):
		return
	var center: Vector2 = rect.size * 0.5
	var dir: Vector2 = (screen_pos - center).normalized()
	if dir.length_squared() < 0.001:
		return
	var half: Vector2 = center - Vector2(indicator_margin, indicator_margin)
	var abs_dir: Vector2 = Vector2(abs(dir.x), abs(dir.y))
	var denom_x: float = max(abs_dir.x, 0.001)
	var denom_y: float = max(abs_dir.y, 0.001)
	var t: float = min(half.x / denom_x, half.y / denom_y)
	var edge_pos: Vector2 = center + dir * t
	var indicator := indicator_scene.instantiate()
	if indicator == null:
		return
	indicator_root.add_child(indicator)
	if indicator is Node2D:
		(indicator as Node2D).position = edge_pos
	if indicator.has_method("setup"):
		indicator.call("setup", dir, color, indicator_lifetime)
