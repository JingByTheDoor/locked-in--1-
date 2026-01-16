extends CharacterBody2D

signal died(context: String)
signal damaged(amount: int, context: String)

@export var move_speed: float = 180.0
@export var sprint_multiplier: float = 1.5
@export var interact_radius: float = 48.0
@export var idle_animation_name: StringName = &"idle"
@export var walk_animation_name: StringName = &"walk"
@export var aim_rotation_offset_degrees: float = 0.0
@export var walk_sound_interval: float = 0.55
@export var sprint_sound_interval: float = 0.35
@export var walk_sound_radius: float = 220.0
@export var sprint_sound_radius: float = 360.0
@export var walk_sound_loudness: float = 0.35
@export var sprint_sound_loudness: float = 0.8

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var interact_shape: CollisionShape2D = $InteractArea/CollisionShape2D
@onready var vision_cone: Node2D = get_node_or_null("VisionCone")

var is_dead: bool = false
var _aim_angle: float = 0.0
var _sound_timer: float = 0.0

func _ready() -> void:
	_sync_hp()
	_apply_interact_radius()
	_update_animation(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := move_speed
	var is_sprinting := Input.is_action_pressed("sprint")
	if is_sprinting:
		speed *= sprint_multiplier
	velocity = input_vector * speed
	move_and_slide()
	_update_animation(input_vector)
	_update_aim()
	_update_movement_sound(delta, input_vector, is_sprinting)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("interact"):
		_try_interact()

func _update_aim() -> void:
	if visuals == null:
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 0.001:
		return
	_aim_angle = to_mouse.angle()
	visuals.rotation = _aim_angle + deg_to_rad(aim_rotation_offset_degrees)
	if vision_cone != null:
		vision_cone.rotation = _aim_angle

func _update_animation(input_vector: Vector2) -> void:
	if sprite == null:
		return
	var frames := sprite.sprite_frames
	if frames == null:
		return
	var anim_name := idle_animation_name
	if input_vector.length() > 0.1:
		anim_name = walk_animation_name
	if frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
	elif not sprite.is_playing():
		sprite.play()

func _update_movement_sound(delta: float, input_vector: Vector2, is_sprinting: bool) -> void:
	if input_vector.length() < 0.1:
		_sound_timer = 0.0
		return
	var interval := walk_sound_interval
	var radius := walk_sound_radius
	var loudness := walk_sound_loudness
	var sound_type := SoundEvent.SoundType.EXPECTED
	if is_sprinting:
		interval = sprint_sound_interval
		radius = sprint_sound_radius
		loudness = sprint_sound_loudness
		sound_type = SoundEvent.SoundType.ANOMALOUS
	_sound_timer -= delta
	if _sound_timer > 0.0:
		return
	_sound_timer = max(interval, 0.05)
	SoundBus.emit_sound_at(global_position, loudness, radius, sound_type, self)

func apply_damage(amount: int, context: String = "") -> void:
	if is_dead:
		return
	GameState.player_hp = clampi(GameState.player_hp - amount, 0, GameState.player_max_hp)
	damaged.emit(amount, context)
	if GameState.player_hp <= 0:
		_handle_death(context)

func heal(amount: int) -> void:
	if is_dead:
		return
	GameState.player_hp = clampi(GameState.player_hp + amount, 0, GameState.player_max_hp)

func _handle_death(context: String) -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(context)

func _sync_hp() -> void:
	if GameState.player_max_hp <= 0:
		GameState.player_max_hp = 100
	GameState.player_hp = clampi(GameState.player_hp, 0, GameState.player_max_hp)

func _apply_interact_radius() -> void:
	if interact_shape == null:
		return
	if interact_shape.shape is CircleShape2D:
		var circle := interact_shape.shape as CircleShape2D
		circle.radius = interact_radius

func _try_interact() -> void:
	if interact_area == null:
		return
	var target := _find_best_interactable()
	if target == null:
		return
	if target.has_method("interact"):
		target.call("interact", self)
		return
	var parent := target.get_parent()
	if parent != null and parent.has_method("interact"):
		parent.call("interact", self)

func _find_best_interactable() -> Node:
	var nearest: Node = null
	var nearest_dist := INF
	for area in interact_area.get_overlapping_areas():
		if not area.is_in_group("interactable") and not area.has_method("interact"):
			continue
		var dist := global_position.distance_to(area.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = area
	for body in interact_area.get_overlapping_bodies():
		if not body.is_in_group("interactable") and not body.has_method("interact"):
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body
	return nearest
