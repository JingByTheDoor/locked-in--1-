extends CharacterBody2D
class_name Watcher

enum State {
	PATROL,
	INVESTIGATE,
	ALERT
}

@export var patrol_speed: float = 75.0
@export var investigate_speed: float = 90.0
@export var alert_speed: float = 120.0
@export var arrival_distance: float = 10.0
@export var lose_interest_time: float = 2.5
@export var hearing_multiplier: float = 2.2
@export var min_hearing_radius: float = 700.0
@export var max_hearing_radius: float = 1600.0
@export var alert_hit_points: int = 3
@export var alarm_cooldown: float = 10.0
@export var alarm_loudness: float = 2.4
@export var alarm_radius: float = 2000.0
@export var alarm_vfx_scene: PackedScene
@export var alarm_color: Color = Color(1.0, 0.4, 0.2, 0.95)
@export var alarm_pulse_duration: float = 1.2
@export var patrol_path: NodePath
@export var player_path: NodePath
@export var idle_animation_name: StringName = &"idle"
@export var walk_animation_name: StringName = &"walk"
@export var aim_rotation_offset_degrees: float = 0.0
@export var debug_state_colors: bool = true
@export var patrol_color: Color = Color(0.9, 0.9, 1.0, 1.0)
@export var investigate_color: Color = Color(1.0, 0.8, 0.4, 1.0)
@export var alert_color: Color = Color(1.0, 0.45, 0.3, 1.0)
@export var alarm_stream: AudioStream = preload("res://Audio/Watcher alarm.wav")
@export var alarm_volume_db: float = -3.0
@export var footstep_interval: float = 0.7
@export var footstep_stream: AudioStream = preload("res://Audio/Guard Footsteps.wav")
@export var footstep_volume_db: float = -9.0

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
var _lose_timer: float = 0.0
var _aim_angle: float = 0.0
var _alarm_timer: float = 0.0
var _footstep_timer: float = 0.0
var _current_alert_hp: int = 3

func _ready() -> void:
	add_to_group("enemy")
	_resolve_player()
	_cache_patrol_points()
	_update_animation(Vector2.ZERO)
	_current_alert_hp = max(1, alert_hit_points)
	if SoundBus != null:
		SoundBus.sound_emitted.connect(_on_sound_emitted)

func _physics_process(delta: float) -> void:
	_alarm_timer = max(0.0, _alarm_timer - delta)
	var sees_player: bool = _can_see_player()
	if sees_player:
		if _player != null:
			last_seen_position = _player.global_position
		has_last_seen = true
		state = State.ALERT
		_lose_timer = 0.0
		_try_alarm()
	elif state == State.ALERT:
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
		State.ALERT:
			if _player != null:
				if sees_player:
					target_pos = _player.global_position
					has_target = true
				elif has_last_seen:
					target_pos = last_seen_position
					has_target = true
				speed = alert_speed
			else:
				state = State.PATROL

	var move_dir: Vector2 = Vector2.ZERO
	if has_target:
		var to_target: Vector2 = target_pos - global_position
		var dist: float = to_target.length()
		if dist > 0.001:
			_update_facing(to_target.normalized())
		if dist <= arrival_distance:
			if state == State.PATROL:
				_advance_patrol()
			elif state == State.INVESTIGATE:
				has_last_heard = false
				state = State.PATROL
		else:
			move_dir = to_target.normalized()

	velocity = move_dir * speed
	move_and_slide()
	_update_animation(move_dir)
	_apply_state_debug_color()
	_update_footsteps(delta, move_dir)

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
		State.ALERT:
			sprite.modulate = alert_color

func apply_damage(amount: int, _context: String = "") -> void:
	if amount <= 0:
		return
	if state == State.PATROL:
		_die()
		return
	_current_alert_hp -= amount
	if _current_alert_hp <= 0:
		_die()
		return
	state = State.ALERT
	_lose_timer = 0.0

func _try_alarm() -> void:
	if _alarm_timer > 0.0:
		return
	if SoundBus != null:
		SoundBus.emit_sound_at(global_position, alarm_loudness, alarm_radius, SoundEvent.SoundType.ANOMALOUS, self, "alarm")
	_spawn_alarm_pulse()
	_play_one_shot(alarm_stream, alarm_volume_db)
	_alarm_timer = max(alarm_cooldown, 0.1)

func _die() -> void:
	queue_free()

func _spawn_alarm_pulse() -> void:
	if alarm_vfx_scene == null:
		return
	var pulse: Node = alarm_vfx_scene.instantiate()
	if pulse == null:
		return
	add_child(pulse)
	if pulse is Node2D:
		(pulse as Node2D).global_position = global_position
	if pulse.has_method("setup"):
		pulse.call("setup", alarm_radius, alarm_color, alarm_pulse_duration)

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
	if state != State.ALERT:
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

func _update_footsteps(delta: float, move_dir: Vector2) -> void:
	if move_dir.length() < 0.1:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	_footstep_timer = max(footstep_interval, 0.1)
	_play_one_shot(footstep_stream, footstep_volume_db)

func _play_one_shot(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	AudioOneShot.play_2d(stream, global_position, get_tree().current_scene, volume_db)
