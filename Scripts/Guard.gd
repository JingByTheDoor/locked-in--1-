extends CharacterBody2D
class_name Guard

signal attacked(target: Node, damage: int)

enum State {
	PATROL,
	INVESTIGATE,
	CHASE
}

@export var patrol_speed: float = 90.0
@export var investigate_speed: float = 110.0
@export var chase_speed: float = 130.0
@export var arrival_distance: float = 10.0
@export var attack_range: float = 28.0
@export var attack_damage: int = 15
@export var attack_cooldown: float = 1.1
@export var lose_interest_time: float = 2.5
@export var hearing_multiplier: float = 2.5
@export var min_hearing_radius: float = 600.0
@export var max_hearing_radius: float = 1400.0
@export var alert_hit_points: int = 3
@export var knockback_decay: float = 600.0
@export var knockback_resistance: float = 1.0
@export var patrol_path: NodePath
@export var player_path: NodePath
@export var idle_animation_name: StringName = &"idle"
@export var walk_animation_name: StringName = &"walk"
@export var aim_rotation_offset_degrees: float = 0.0
@export var debug_state_colors: bool = true
@export var patrol_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var investigate_color: Color = Color(1.0, 0.85, 0.4, 1.0)
@export var chase_color: Color = Color(1.0, 0.35, 0.35, 1.0)

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var vision_cone: Node2D = $VisionCone

var state: State = State.PATROL
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0
var last_heard_position: Vector2 = Vector2.ZERO
var has_last_heard: bool = false
var last_seen_position: Vector2 = Vector2.ZERO
var has_last_seen: bool = false

var _player: Node2D
var _attack_timer: float = 0.0
var _lose_timer: float = 0.0
var _aim_angle: float = 0.0
var _current_alert_hp: int = 3
var _knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_resolve_player()
	_cache_patrol_points()
	_update_animation(Vector2.ZERO)
	_current_alert_hp = max(1, alert_hit_points)
	if SoundBus != null:
		SoundBus.sound_emitted.connect(_on_sound_emitted)

func _physics_process(delta: float) -> void:
	_attack_timer = max(0.0, _attack_timer - delta)

	var sees_player: bool = _can_see_player()
	if sees_player:
		state = State.CHASE
		_lose_timer = 0.0
	else:
		if state == State.CHASE:
			_lose_timer += delta
			if _lose_timer >= lose_interest_time:
				if has_last_seen:
					last_heard_position = last_seen_position
					has_last_heard = true
				state = State.INVESTIGATE if has_last_heard else State.PATROL
				_lose_timer = 0.0

	var target_pos: Vector2 = global_position
	var has_target: bool = false
	var speed: float = 0.0

	match state:
		State.PATROL:
			if patrol_points.size() > 0:
				target_pos = patrol_points[patrol_index]
				has_target = true
				speed = patrol_speed
		State.INVESTIGATE:
			if has_last_heard:
				target_pos = last_heard_position
				has_target = true
				speed = investigate_speed
			else:
				state = State.PATROL
		State.CHASE:
			if _player != null:
				if sees_player:
					target_pos = _player.global_position
					has_target = true
				else:
					if has_last_seen:
						target_pos = last_seen_position
						has_target = true
				speed = chase_speed
			else:
				state = State.PATROL

	var move_dir: Vector2 = Vector2.ZERO
	if has_target:
		var to_target: Vector2 = target_pos - global_position
		var dist: float = to_target.length()
		if dist > 0.001:
			_update_facing(to_target.normalized())
		if state == State.CHASE:
			if dist <= attack_range:
				_try_attack()
				move_dir = Vector2.ZERO
			else:
				move_dir = to_target.normalized()
		else:
			if dist <= arrival_distance:
				if state == State.PATROL:
					_advance_patrol()
				elif state == State.INVESTIGATE:
					has_last_heard = false
					state = State.PATROL
			else:
				move_dir = to_target.normalized()

	velocity = move_dir * speed
	velocity += _knockback_velocity
	move_and_slide()
	_update_animation(move_dir)
	_apply_state_debug_color()
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)

func _process(_delta: float) -> void:
	if GameState.debug_show_vision or GameState.debug_show_sound:
		queue_redraw()

func _draw() -> void:
	if vision_cone != null and GameState.debug_show_vision:
		var angle_deg: float = float(vision_cone.call("get_cone_angle_degrees"))
		var length: float = float(vision_cone.call("get_cone_length"))
		var half: float = deg_to_rad(angle_deg * 0.5)
		var start_angle: float = vision_cone.rotation - half
		var end_angle: float = vision_cone.rotation + half
		var left: Vector2 = Vector2.RIGHT.rotated(start_angle) * length
		var right: Vector2 = Vector2.RIGHT.rotated(end_angle) * length
		var col := Color(0.2, 0.9, 1.0, 0.6)
		draw_line(Vector2.ZERO, left, col, 1.0)
		draw_line(Vector2.ZERO, right, col, 1.0)
		draw_arc(Vector2.ZERO, length, start_angle, end_angle, 24, Color(0.2, 0.9, 1.0, 0.3), 1.0)
	if GameState.debug_show_sound and has_last_heard:
		var local: Vector2 = to_local(last_heard_position)
		draw_line(Vector2.ZERO, local, Color(1.0, 0.2, 0.2, 0.5), 1.0)
		draw_circle(local, 6.0, Color(1.0, 0.2, 0.2, 0.7))

func _update_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return
	_aim_angle = direction.angle()
	if visuals != null:
		visuals.rotation = _aim_angle + deg_to_rad(aim_rotation_offset_degrees)
	if vision_cone != null:
		vision_cone.rotation = _aim_angle

func _update_animation(move_dir: Vector2) -> void:
	if sprite == null:
		return
	var frames := sprite.sprite_frames
	if frames == null:
		return
	var anim_name := idle_animation_name
	if move_dir.length() > 0.1:
		anim_name = walk_animation_name
	if frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
	elif not sprite.is_playing():
		sprite.play()

func _apply_state_debug_color() -> void:
	if sprite == null:
		return
	if not debug_state_colors:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	match state:
		State.PATROL:
			sprite.modulate = patrol_color
		State.INVESTIGATE:
			sprite.modulate = investigate_color
		State.CHASE:
			sprite.modulate = chase_color

func _try_attack() -> void:
	if _attack_timer > 0.0:
		return
	if _player == null:
		return
	if _player.has_method("apply_damage"):
		_player.call("apply_damage", attack_damage, "guard")
	attacked.emit(_player, attack_damage)
	_attack_timer = attack_cooldown

func apply_damage(amount: int, context: String = "") -> void:
	if amount <= 0:
		return
	if state == State.PATROL:
		_die(context)
		return
	_current_alert_hp -= amount
	if _current_alert_hp <= 0:
		_die(context)
		return
	state = State.CHASE
	_lose_timer = 0.0

func apply_knockback(direction: Vector2, strength: float) -> void:
	if strength <= 0.0:
		return
	var dir := direction
	if dir.length_squared() < 0.001:
		return
	_knockback_velocity += dir.normalized() * (strength / max(knockback_resistance, 0.1))

func _die(_context: String) -> void:
	queue_free()

func _on_sound_emitted(event: SoundEvent) -> void:
	if event == null:
		return
	if event.sound_type != SoundEvent.SoundType.ANOMALOUS:
		return
	if event.source_path != NodePath() and event.source_path == get_path():
		return
	var dist: float = global_position.distance_to(event.position)
	var hearing_radius: float = clampf(event.radius * hearing_multiplier, min_hearing_radius, max_hearing_radius)
	if dist > hearing_radius:
		return
	last_heard_position = event.position
	has_last_heard = true
	if state != State.CHASE:
		state = State.INVESTIGATE

func _can_see_player() -> bool:
	if _player == null or vision_cone == null:
		return false
	if not vision_cone.has_method("can_see_node"):
		return false
	var visible: bool = bool(vision_cone.call("can_see_node", _player))
	if visible:
		last_seen_position = _player.global_position
		has_last_seen = true
	return visible

func _advance_patrol() -> void:
	if patrol_points.size() == 0:
		return
	patrol_index = (patrol_index + 1) % patrol_points.size()

func _cache_patrol_points() -> void:
	patrol_points.clear()
	var source: Node = _get_patrol_source()
	if source == null:
		if patrol_points.size() == 0:
			patrol_points.append(global_position)
		return
	var children: Array = source.get_children()
	for child in children:
		if child is Node2D:
			patrol_points.append((child as Node2D).global_position)
	if patrol_points.size() == 0:
		patrol_points.append(global_position)

func _get_patrol_source() -> Node:
	if patrol_path != NodePath():
		return get_node_or_null(patrol_path)
	var parent: Node = get_parent()
	if parent != null:
		return parent.get_node_or_null("PatrolPath")
	return null

func _resolve_player() -> void:
	var node: Node = null
	if player_path != NodePath():
		node = get_node_or_null(player_path)
	if node == null:
		node = get_tree().get_first_node_in_group("player")
	if node == null:
		node = get_tree().get_root().find_child("Player", true, false)
	if node is Node2D:
		_player = node as Node2D
