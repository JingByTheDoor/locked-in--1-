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
@export var alarm_pause_time: float = 0.5
@export var alarm_vfx_scene: PackedScene
@export var alarm_color: Color = Color(1.0, 0.4, 0.2, 0.95)
@export var alarm_pulse_duration: float = 1.2
@export var patrol_path: NodePath
@export var player_path: NodePath
@export var idle_animation_name: StringName = &"idle"
@export var walk_animation_name: StringName = &"walk"
@export var attack_animation_name: StringName = &"attack"
@export var attack_animation_time: float = 0.4
@export var aim_rotation_offset_degrees: float = 0.0
@export var debug_state_colors: bool = true
@export var pathing_enabled: bool = true
@export var path_repath_interval: float = 0.25
@export var path_repath_distance: float = 48.0
@export var path_next_point_distance: float = 16.0
@export var path_allow_direct: bool = false
@export var path_stuck_time: float = 0.25
@export var path_stuck_distance: float = 4.0
@export var investigate_unreachable_time: float = 4.5
@export var investigate_progress_epsilon: float = 2.0
@export var patrol_idle_enabled: bool = true
@export var patrol_idle_interval_min: float = 1.5
@export var patrol_idle_interval_max: float = 3.5
@export var patrol_idle_time_min: float = 0.4
@export var patrol_idle_time_max: float = 1.0
@export var patrol_color: Color = Color(0.9, 0.9, 1.0, 1.0)
@export var investigate_color: Color = Color(1.0, 0.8, 0.4, 1.0)
@export var alert_color: Color = Color(1.0, 0.45, 0.3, 1.0)
@export var alarm_stream: AudioStream = preload("res://Audio/Watcher alarm.wav")
@export var alarm_volume_db: float = -3.0
@export var footstep_interval: float = 0.7
@export var footstep_stream: AudioStream = preload("res://Audio/Guard Footsteps.wav")
@export var footstep_volume_db: float = -14.0
@export var footstep_max_distance: float = 320.0
@export var flee_speed: float = 190.0
@export var flee_duration: float = 2.5

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
var _attack_anim_timer: float = 0.0
var _footstep_timer: float = 0.0
var _current_alert_hp: int = 3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fleeing: bool = false
var _flee_timer: float = 0.0
var _flee_source: Node2D = null
var _flee_dir: Vector2 = Vector2.ZERO
var _alarm_pause_timer: float = 0.0
var _pathing: Node = null
var _path_points: Array[Vector2] = []
var _path_index: int = 0
var _path_timer: float = 0.0
var _path_target: Vector2 = Vector2.ZERO
var _path_last_pos: Vector2 = Vector2.ZERO
var _path_stuck_timer: float = 0.0
var _investigate_timer: float = 0.0
var _investigate_last_goal_dist: float = INF
var _investigate_last_path_index: int = -1
var _patrol_idle_timer: float = 0.0
var _patrol_pause_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	_rng.randomize()
	_resolve_player()
	_cache_patrol_points()
	_resolve_pathing()
	_path_last_pos = global_position
	_reset_patrol_idle_timer()
	_update_animation(Vector2.ZERO)
	_current_alert_hp = max(1, alert_hit_points)
	if SoundBus != null:
		SoundBus.sound_emitted.connect(_on_sound_emitted)

func _physics_process(delta: float) -> void:
	if _fleeing:
		_update_flee(delta)
		return
	_alarm_timer = max(0.0, _alarm_timer - delta)
	_alarm_pause_timer = max(0.0, _alarm_pause_timer - delta)
	_attack_anim_timer = max(0.0, _attack_anim_timer - delta)
	if _alarm_pause_timer > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		return
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
		var desired_dir: Vector2 = Vector2.ZERO
		if dist > 0.001:
			desired_dir = _get_path_direction(target_pos, delta)
			if desired_dir.length_squared() > 0.001:
				_update_facing(desired_dir)
		var goal_dist := _get_path_goal_distance()
		var has_los := _has_line_of_sight(target_pos)
		var arrival_dist := dist
		if goal_dist >= 0.0:
			arrival_dist = goal_dist
		_update_investigate_progress(delta, arrival_dist, has_los)
		var arrived := false
		if has_los:
			arrived = arrival_dist <= arrival_distance
		elif goal_dist >= 0.0:
			arrived = arrival_dist <= arrival_distance
		if arrived:
			if state == State.PATROL:
				_advance_patrol()
			elif state == State.INVESTIGATE:
				has_last_heard = false
				state = State.PATROL
		else:
			move_dir = desired_dir
	else:
		_clear_path()

	if _update_patrol_idle(delta, sees_player):
		move_dir = Vector2.ZERO

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
	if _attack_anim_timer > 0.0 and frames.has_animation(attack_animation_name):
		anim_name = attack_animation_name
	elif move_dir.length() > 0.1:
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
	if state == State.PATROL or state == State.INVESTIGATE:
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
	_alarm_pause_timer = max(alarm_pause_time, 0.0)
	_attack_anim_timer = max(attack_animation_time, 0.05)

func _die() -> void:
	queue_free()

func flee_and_despawn(hunter: Node = null) -> void:
	if _fleeing:
		return
	_fleeing = true
	_flee_timer = max(flee_duration, 0.1)
	if hunter is Node2D:
		_flee_source = hunter as Node2D
	elif _player != null:
		_flee_source = _player
	_flee_dir = _get_flee_direction()

func _update_flee(delta: float) -> void:
	_flee_timer -= delta
	if _flee_timer <= 0.0:
		queue_free()
		return
	_flee_dir = _get_flee_direction()
	velocity = _flee_dir * flee_speed
	move_and_slide()
	_update_animation(_flee_dir)
	_update_facing(_flee_dir)

func _get_flee_direction() -> Vector2:
	if _flee_source != null and is_instance_valid(_flee_source):
		var away := global_position - _flee_source.global_position
		if away.length_squared() > 0.001:
			return away.normalized()
	if _flee_dir.length_squared() > 0.001:
		return _flee_dir
	var angle: float = _rng.randf_range(0.0, TAU)
	return Vector2.RIGHT.rotated(angle)

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

func _resolve_pathing() -> void:
	var node := get_tree().get_first_node_in_group("map_pathing")
	if node != null and node.has_method("get_nav_path") and node.has_method("has_line_of_sight"):
		_pathing = node as Node
	else:
		_pathing = null

func _clear_path() -> void:
	_path_points.clear()
	_path_index = 0
	_path_timer = 0.0
	_path_stuck_timer = 0.0
	_path_last_pos = global_position
	_reset_investigate_progress()

func _get_path_direction(target_pos: Vector2, delta: float) -> Vector2:
	var direct := target_pos - global_position
	if direct.length_squared() < 0.001:
		return Vector2.ZERO
	if not pathing_enabled:
		return direct.normalized()
	if _pathing == null:
		_resolve_pathing()
	if _pathing == null:
		return direct.normalized()
	_update_path_stuck(delta, direct.length())
	if path_allow_direct and bool(_pathing.call("has_line_of_sight", global_position, target_pos)):
		_clear_path()
		return direct.normalized()
	_path_timer -= delta
	var needs_repath: bool = _path_timer <= 0.0 or _path_points.is_empty() or _path_target.distance_to(target_pos) > path_repath_distance
	if needs_repath:
		_path_timer = max(path_repath_interval, 0.05)
		_path_target = target_pos
		var result: Variant = _pathing.call("get_nav_path", global_position, target_pos)
		_path_points = result if result is Array else []
		_path_index = 0
		_drop_close_path_points()
	if _path_points.is_empty():
		return direct.normalized()
	if _path_index >= _path_points.size():
		_path_index = _path_points.size() - 1
	var next_point: Vector2 = _path_points[_path_index]
	if global_position.distance_to(next_point) <= path_next_point_distance and _path_index < _path_points.size() - 1:
		_path_index += 1
		next_point = _path_points[_path_index]
	var dir := next_point - global_position
	if dir.length_squared() < 0.001:
		return direct.normalized()
	return dir.normalized()

func _update_path_stuck(delta: float, target_dist: float) -> void:
	var moved := global_position.distance_to(_path_last_pos)
	_path_last_pos = global_position
	var needs_progress: bool = target_dist > path_next_point_distance * 1.5
	if moved <= path_stuck_distance and needs_progress:
		_path_stuck_timer += delta
		if state == State.INVESTIGATE and _path_stuck_timer >= investigate_unreachable_time:
			_abandon_investigation()
			return
		if _path_stuck_timer >= path_stuck_time:
			_path_timer = 0.0
			_path_points.clear()
			_path_index = 0
			_path_stuck_timer = 0.0
	else:
		_path_stuck_timer = 0.0

func _abandon_investigation() -> void:
	has_last_heard = false
	state = State.PATROL
	_clear_path()

func _reset_investigate_progress() -> void:
	_investigate_timer = 0.0
	_investigate_last_goal_dist = INF
	_investigate_last_path_index = -1

func _update_investigate_progress(delta: float, goal_dist: float, has_los: bool) -> void:
	if state != State.INVESTIGATE:
		_reset_investigate_progress()
		return
	if has_los:
		_reset_investigate_progress()
		return
	if _path_points.is_empty():
		_investigate_timer += delta
		if _investigate_timer >= investigate_unreachable_time:
			_abandon_investigation()
		return
	if _investigate_last_path_index != _path_index:
		_investigate_last_path_index = _path_index
		_investigate_last_goal_dist = goal_dist
		_investigate_timer = 0.0
		return
	if _investigate_last_goal_dist == INF:
		_investigate_last_goal_dist = goal_dist
		_investigate_timer = 0.0
		return
	if goal_dist <= _investigate_last_goal_dist - investigate_progress_epsilon:
		_investigate_timer = 0.0
	else:
		_investigate_timer += delta
		if _investigate_timer >= investigate_unreachable_time:
			_abandon_investigation()
	_investigate_last_goal_dist = goal_dist

func _update_patrol_idle(delta: float, sees_player: bool) -> bool:
	if not patrol_idle_enabled:
		_patrol_pause_timer = 0.0
		_patrol_idle_timer = 0.0
		return false
	if state != State.PATROL or sees_player:
		_patrol_pause_timer = 0.0
		_patrol_idle_timer = 0.0
		return false
	if _patrol_pause_timer > 0.0:
		_patrol_pause_timer = max(0.0, _patrol_pause_timer - delta)
		return _patrol_pause_timer > 0.0
	if _patrol_idle_timer <= 0.0:
		_reset_patrol_idle_timer()
	_patrol_idle_timer = max(0.0, _patrol_idle_timer - delta)
	if _patrol_idle_timer <= 0.0:
		_start_patrol_pause()
		_reset_patrol_idle_timer()
		return _patrol_pause_timer > 0.0
	return false

func _reset_patrol_idle_timer() -> void:
	var min_interval: float = max(patrol_idle_interval_min, 0.0)
	var max_interval: float = max(patrol_idle_interval_max, min_interval)
	if max_interval <= 0.0:
		_patrol_idle_timer = 0.0
		return
	_patrol_idle_timer = _rng.randf_range(min_interval, max_interval)

func _start_patrol_pause() -> void:
	var min_pause: float = max(patrol_idle_time_min, 0.0)
	var max_pause: float = max(patrol_idle_time_max, min_pause)
	if max_pause <= 0.0:
		_patrol_pause_timer = 0.0
		return
	_patrol_pause_timer = _rng.randf_range(min_pause, max_pause)

func _drop_close_path_points() -> void:
	while _path_points.size() > 0 and global_position.distance_to(_path_points[0]) <= path_next_point_distance:
		_path_points.remove_at(0)

func _get_path_goal_distance() -> float:
	if _path_points.is_empty():
		return -1.0
	var goal: Vector2 = _path_points[_path_points.size() - 1]
	return global_position.distance_to(goal)

func _has_line_of_sight(target_pos: Vector2) -> bool:
	if not pathing_enabled:
		return true
	if _pathing == null:
		_resolve_pathing()
	if _pathing == null:
		return true
	return bool(_pathing.call("has_line_of_sight", global_position, target_pos))

func _update_footsteps(delta: float, move_dir: Vector2) -> void:
	if move_dir.length() < 0.1:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	if _player != null:
		var max_dist: float = maxf(footstep_max_distance, 0.0)
		if global_position.distance_squared_to(_player.global_position) > max_dist * max_dist:
			return
	_footstep_timer = max(footstep_interval, 0.1)
	_play_one_shot(footstep_stream, footstep_volume_db)

func _play_one_shot(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	AudioOneShot.play_2d(stream, global_position, get_tree().current_scene, volume_db)
