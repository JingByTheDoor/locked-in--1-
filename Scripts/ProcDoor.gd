extends StaticBody2D
class_name ProcDoor

@export var silent_open_chance: float = 0.5
@export var open_lock_min: float = 0.5
@export var open_lock_max: float = 2.0
@export var anomalous_loudness: float = 1.0
@export var anomalous_radius: float = 420.0
@export var anomalous_stream: AudioStream = preload("res://Audio/Door Opening.wav")
@export var anomalous_volume_db: float = -6.0
@export var hunter_delay: float = 0.6
@export var prompt_open: String = "Press E to open"
@export var prompt_close: String = "Press E to close"
@export var icon_texture: Texture2D = preload("res://icon.svg")
@export var icon_fill_ratio: float = 0.6
@export var icon_modulate: Color = Color(0.75, 0.75, 0.75, 1.0)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var _is_open: bool = false
var _is_opening: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("door")
	add_to_group("interactable")
	_rng.randomize()
	_apply_sprite_defaults()

func configure(tile_size: Vector2, horizontal: bool) -> void:
	var size := Vector2(tile_size.x, tile_size.y)
	if horizontal:
		size.x *= 2.0
	else:
		size.y *= 2.0
	_set_shape_size(size)
	_scale_sprite(size)

func interact(player: Node) -> void:
	if _is_opening:
		return
	if _is_open:
		_set_open(false)
		return
	var silent: bool = _rng.randf() <= clampf(silent_open_chance, 0.0, 1.0)
	if silent:
		_set_open(true)
		return
	_begin_open_sequence(player)

func get_interact_prompt(_player: Node) -> String:
	return prompt_close if _is_open else prompt_open

func get_hunter_delay() -> float:
	return hunter_delay

func _begin_open_sequence(player: Node) -> void:
	_is_opening = true
	_set_player_lock(player, true)
	var min_time: float = max(open_lock_min, 0.0)
	var max_time: float = max(open_lock_max, min_time)
	var wait_time: float = _rng.randf_range(min_time, max_time)
	_play_open_animation(wait_time)
	await get_tree().create_timer(wait_time).timeout
	if not is_inside_tree():
		return
	_set_open(true)
	_emit_anomalous_sound()
	_set_player_lock(player, false)
	_is_opening = false

func _set_open(open: bool) -> void:
	_is_open = open
	if collision_shape != null:
		collision_shape.disabled = open
	if sprite != null:
		sprite.visible = not open

func _emit_anomalous_sound() -> void:
	if SoundBus != null:
		SoundBus.emit_sound_at(global_position, anomalous_loudness, anomalous_radius, SoundEvent.SoundType.ANOMALOUS, self, "door")
	if anomalous_stream != null:
		AudioOneShot.play_2d(anomalous_stream, global_position, get_tree().current_scene, anomalous_volume_db)

func _set_player_lock(player: Node, locked: bool) -> void:
	if player == null:
		return
	if player.has_method("set_repair_lock"):
		player.call("set_repair_lock", locked)

func _set_shape_size(size: Vector2) -> void:
	if collision_shape == null:
		return
	var rect := collision_shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
	rect.size = size
	collision_shape.shape = rect

func _scale_sprite(size: Vector2) -> void:
	if sprite == null:
		return
	if icon_texture != null:
		sprite.texture = icon_texture
	if sprite.texture == null:
		return
	var tex_size := sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var ratio := clampf(icon_fill_ratio, 0.05, 1.0)
	sprite.scale = Vector2(size.x / tex_size.x, size.y / tex_size.y) * ratio
	sprite.modulate = icon_modulate

func _apply_sprite_defaults() -> void:
	if sprite == null:
		return
	if sprite.texture == null and icon_texture != null:
		sprite.texture = icon_texture
	sprite.modulate = icon_modulate

func _play_open_animation(duration: float) -> void:
	if sprite == null:
		return
	var base_scale := sprite.scale
	var bump := base_scale * 1.05
	var tween := create_tween()
	tween.tween_property(sprite, "scale", bump, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_scale, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
