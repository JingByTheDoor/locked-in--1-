extends CharacterBody2D
class_name Hunter

signal attacked(target: Node, damage: int)

enum State {
	IDLE,
	SEARCH,
	CHASE
}

@export var search_speed: float = 280.0
@export var chase_speed: float = 420.0
@export var attack_range: float = 26.0
@export var attack_damage: int = 999
@export var attack_cooldown: float = 0.7
@export var search_radius: float = 140.0
@export var search_points_count: int = 4
@export var search_pause: float = 0.2
@export var hearing_multiplier: float = 2.0
@export var hearing_min_radius: float = 220.0
@export var hearing_max_radius: float = 2000.0
@export var gun_pull_radius: float = 5000.0
@export var hiding_discovery_chance: float = 0.35
@export var hiding_check_interval: float = 0.4
@export var door_delay_default: float = 0.6
@export var aim_rotation_offset_degrees: float = 0.0
@export var presence_max_distance: float = 640.0
@export var presence_volume_min_db: float = -24.0
@export var presence_volume_max_db: float = -6.0
@export var presence_stream: AudioStream = preload("res://Audio/Enemy Presence Breathing.wav")
@export var spotted_stream: AudioStream = preload("res://Audio/HUNTER SPOTED YOU.wav")
@export var spotted_volume_db: float = -2.0
@export var spotted_cooldown: float = 6.0
@export var wall_break_delay: float = 0.05
@export var wall_break_pass_duration: float = 0.1
@export var wall_break_cooldown: float = 0.9
@export var wall_break_speed_multiplier: float = 0.95
@export var idle_animation_name: StringName = &"idle"
@export var walk_animation_name: StringName = &"walk"
@export var player_path: NodePath

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var vision_cone: Node2D = $VisionCone
@onready var door_sensor: Area2D = $DoorSensor
@onready var presence_player: AudioStreamPlayer2D = $PresenceLoop

var state: State = State.IDLE
var last_seen_position: Vector2 = Vector2.ZERO
var last_heard_position: Vector2 = Vector2.ZERO
var has_last_heard: bool = false

var _player: Node2D
var _attack_timer: float = 0.0
var _delay_timer: float = 0.0
var _search_points: Array[Vector2] = []
var _search_index: int = 0
var _search_pause_timer: float = 0.0
var _hidden_check_timer: float = 0.0
var _aim_angle: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spotted_cooldown_timer: float = 0.0
var _wall_break_delay_timer: float = 0.0
var _wall_break_pass_timer: float = 0.0
var _wall_break_cooldown_timer: float = 0.0
var _wall_break_pending: bool = false
var _wall_break_target: Node = null

func _ready() -> void:
	add_to_group("enemy")
	_rng.randomize()
	_resolve_player()
	_apply_presence_stream()
	if SoundBus != null:
		SoundBus.sound_emitted.connect(_on_sound_emitted)
	if door_sensor != null:
		door_sensor.area_entered.connect(_on_door_entered)
		door_sensor.body_entered.connect(_on_door_entered)

func _physics_process(delta: float) -> void:
	if GameState.phase_state != GameState.PhaseState.HUNTED:
		velocity = Vector2.ZERO
		if presence_player != null and presence_player.playing:
			presence_player.stop()
		return
	_wall_break_cooldown_timer = max(0.0, _wall_break_cooldown_timer - delta)
	if _wall_break_delay_timer > 0.0:
		_wall_break_delay_timer = max(0.0, _wall_break_delay_timer - delta)
		if _wall_break_delay_timer <= 0.0 and _wall_break_pending:
			_begin_wall_break_pass()
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		return
	if _wall_break_pass_timer > 0.0:
		_wall_break_pass_timer = max(0.0, _wall_break_pass_timer - delta)
	_spotted_cooldown_timer = max(0.0, _spotted_cooldown_timer - delta)
	_update_presence_audio()
	_attack_timer = max(0.0, _attack_timer - delta)
	if _delay_timer > 0.0:
		_delay_timer = max(0.0, _delay_timer - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var sees: bool = _can_see_player(delta)
	if sees:
		_play_spotted_stinger()
		state = State.CHASE
		_search_points.clear()
		_search_pause_timer = 0.0
		_hidden_check_timer = 0.0
		if _player != null:
			last_seen_position = _player.global_position
	elif state == State.CHASE:
		state = State.SEARCH
		_begin_search(last_seen_position)
	elif state == State.IDLE and has_last_heard:
		state = State.SEARCH
		_begin_search(last_heard_position)

	var target_pos: Vector2 = global_position
	var speed: float = 0.0
	var move_dir: Vector2 = Vector2.ZERO

	match state:
		State.CHASE:
			speed = chase_speed
			if _player != null:
				target_pos = _player.global_position
				move_dir = (target_pos - global_position).normalized()
				_update_facing(move_dir)
				if global_position.distance_to(target_pos) <= attack_range:
					_try_attack()
		State.SEARCH:
			speed = search_speed
			if _search_pause_timer > 0.0:
				_search_pause_timer = max(0.0, _search_pause_timer - delta)
			elif _search_points.size() > 0:
				target_pos = _search_points[_search_index]
				var to_target: Vector2 = target_pos - global_position
				if to_target.length() <= 8.0:
					_advance_search()
				else:
					move_dir = to_target.normalized()
					_update_facing(move_dir)
			else:
				state = State.IDLE
		State.IDLE:
			speed = 0.0

	if _wall_break_pass_timer > 0.0:
		speed *= clampf(wall_break_speed_multiplier, 0.1, 1.0)
	velocity = move_dir * speed
	move_and_slide()
	_update_animation(move_dir)
	_trigger_wall_break_if_blocked()

func apply_damage(_amount: int, _context: String = "") -> void:
	return

func apply_knockback(_direction: Vector2, _strength: float) -> void:
	return

func _try_attack() -> void:
	if _attack_timer > 0.0:
		return
	if _player != null and _player.has_method("apply_damage"):
		_player.call("apply_damage", attack_damage, "hunter")
	attacked.emit(_player, attack_damage)
	_attack_timer = attack_cooldown

func _on_sound_emitted(event: SoundEvent) -> void:
	if event == null:
		return
	if event.sound_type != SoundEvent.SoundType.ANOMALOUS:
		return
	if event.source_path != NodePath() and event.source_path == get_path():
		return
	var dist: float = global_position.distance_to(event.position)
	var hearing_radius: float = clampf(event.radius * hearing_multiplier, hearing_min_radius, hearing_max_radius)
	if event.tag == "gun":
		hearing_radius = max(hearing_radius, gun_pull_radius)
	if dist > hearing_radius:
		return
	last_heard_position = event.position
	has_last_heard = true
	if state != State.CHASE:
		state = State.SEARCH
		_begin_search(last_heard_position)

func _can_see_player(delta: float) -> bool:
	if _player == null or vision_cone == null:
		return false
	if not vision_cone.has_method("can_see_node"):
		return false
	if not bool(vision_cone.call("can_see_node", _player)):
		return false
	if _is_player_hidden():
		_hidden_check_timer += delta
		if _hidden_check_timer < hiding_check_interval:
			return false
		_hidden_check_timer = 0.0
		if _rng.randf() > hiding_discovery_chance:
			return false
	return true

func _is_player_hidden() -> bool:
	if _player == null:
		return false
	if _player.has_method("is_hiding"):
		return bool(_player.call("is_hiding"))
	if _player.is_in_group("hiding"):
		return true
	return false

func _begin_search(origin: Vector2) -> void:
	_search_points.clear()
	_search_index = 0
	_search_pause_timer = search_pause
	var count: int = max(search_points_count, 1)
	for i in range(count):
		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(search_radius * 0.5, search_radius)
		_search_points.append(origin + Vector2.RIGHT.rotated(angle) * dist)

func _advance_search() -> void:
	if _search_points.is_empty():
		state = State.IDLE
		return
	_search_index += 1
	_search_pause_timer = search_pause
	if _search_index >= _search_points.size():
		_search_index = 0

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

func _on_door_entered(node: Node) -> void:
	if node == null:
		return
	var delay: float = door_delay_default
	if node.has_method("get_hunter_delay"):
		delay = float(node.call("get_hunter_delay"))
	elif not node.is_in_group("door"):
		return
	_delay_timer = max(_delay_timer, delay)

func _trigger_wall_break_if_blocked() -> void:
	if _wall_break_cooldown_timer > 0.0:
		return
	if _wall_break_pass_timer > 0.0:
		return
	if _wall_break_delay_timer > 0.0:
		return
	var count: int = get_slide_collision_count()
	for i in range(count):
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		if collider is StaticBody2D or collider is TileMap:
			_wall_break_target = collider as Node
			_start_wall_break()
			return

func _start_wall_break() -> void:
	_wall_break_delay_timer = max(wall_break_delay, 0.0)
	_wall_break_cooldown_timer = max(wall_break_cooldown, 0.1)
	_wall_break_pending = true
	if _wall_break_delay_timer <= 0.0:
		_begin_wall_break_pass()

func _begin_wall_break_pass() -> void:
	_wall_break_pending = false
	if wall_break_pass_duration <= 0.0:
		return
	_wall_break_pass_timer = max(wall_break_pass_duration, 0.05)
	_temporarily_break_wall(_wall_break_target)
	_wall_break_target = null

func _temporarily_break_wall(target: Node) -> void:
	if target == null:
		return
	if not _has_property(target, "collision_layer"):
		return
	if target.has_meta("wall_break_layer"):
		return
	var prev_layer: int = int(target.get("collision_layer"))
	target.set_meta("wall_break_layer", prev_layer)
	target.set("collision_layer", 0)

func _has_property(obj: Object, prop: String) -> bool:
	var list: Array = obj.get_property_list()
	for info in list:
		if typeof(info) == TYPE_DICTIONARY and info.has("name") and info["name"] == prop:
			return true
	return false

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

func _update_presence_audio() -> void:
	if presence_player == null:
		return
	if presence_player.stream == null:
		return
	if not presence_player.playing:
		presence_player.play()
	if _player == null:
		return
	var dist: float = global_position.distance_to(_player.global_position)
	var t: float = 1.0 - clampf(dist / max(presence_max_distance, 0.01), 0.0, 1.0)
	presence_player.volume_db = lerpf(presence_volume_min_db, presence_volume_max_db, t)

func _apply_presence_stream() -> void:
	if presence_player == null:
		return
	if presence_player.stream == null and presence_stream != null:
		_enable_loop(presence_stream)
		presence_player.stream = presence_stream

func _play_spotted_stinger() -> void:
	if _spotted_cooldown_timer > 0.0:
		return
	if spotted_stream == null:
		return
	AudioOneShot.play_2d(spotted_stream, global_position, get_tree().current_scene, spotted_volume_db)
	_spotted_cooldown_timer = max(spotted_cooldown, 0.1)

func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
