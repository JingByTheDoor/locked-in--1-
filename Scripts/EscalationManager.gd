extends Node2D

@export var local_noise_decay: float = 0.4
@export var local_noise_decay_investigate: float = 0.7
@export var local_noise_gain: float = 0.35
@export var local_noise_max: float = 1.0
@export var local_noise_recenter_strength: float = 0.35
@export var local_noise_reinforce_radius: float = 260.0

@export var global_pressure_decay: float = 0.02
@export var global_pressure_gain_per_anomaly: float = 0.08
@export var global_pressure_gain_per_second: float = 0.03
@export var global_pressure_floor_ratio: float = 0.35
@export var gun_pressure_boost: float = 0.6
@export var gun_local_noise_boost: float = 0.7
@export var gun_spike_timer_boost: float = 0.6
@export var major_event_window: float = 6.0
@export var major_event_required: int = 2
@export var major_event_pressure_threshold: float = 1.1
@export var major_event_local_boost: float = 0.45
@export var major_event_global_boost: float = 0.35
@export var major_event_spike_timer_boost: float = 0.5
@export var major_event_tags: Array[String] = ["alarm", "callout", "destruction"]

@export var investigate_threshold: float = 0.25
@export var pressure_threshold: float = 0.6
@export var hunted_pressure_threshold: float = 1.4
@export var hunted_spike_threshold: float = 0.85
@export var hunted_spike_time: float = 0.6

@export var overlay_path: NodePath
@export var tension_player_path: NodePath
@export var heartbeat_player_path: NodePath
@export var tension_stream: AudioStream = preload("res://Audio/TENSION LAYER.wav")
@export var heartbeat_stream: AudioStream = preload("res://Audio/heartbeat.wav")
@export var message_hud_path: NodePath
@export var hunted_message: String = "HUNTED: escape or die"
@export var hunter_scene: PackedScene
@export var hunter_spawn_min_distance: float = 320.0
@export var hunter_spawn_radius: float = 640.0
@export var hunter_spawn_attempts: int = 6

@export var alarm_message: String = "Alarm raised — pressure surges."
@export var callout_message: String = "Callout heard — pressure rises."
@export var destruction_message: String = "Destruction echoes — pressure rises."
@export var investigate_message: String = "Something is investigating."
@export var pressure_message: String = "Pressure rising."
@export var hunted_message_once: String = "SOMETHING IS COMING."

@export var debug_noise_color: Color = Color(1.0, 0.3, 0.3, 0.35)
@export var debug_noise_radius_min: float = 30.0
@export var debug_noise_radius_max: float = 160.0

var local_noise_position: Vector2 = Vector2.ZERO
var local_noise_value: float = 0.0
var has_local_noise: bool = false

var _overlay: Node = null
var _tension_player: AudioStreamPlayer = null
var _heartbeat_player: AudioStreamPlayer = null
var _message_hud: Node = null
var _spike_timer: float = 0.0
var _last_phase: int = -1
var _hunted_locked: bool = false
var _hunter_instance: Node2D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _major_event_timer: float = 0.0
var _major_event_count: int = 0

func _ready() -> void:
	_rng.randomize()
	_resolve_nodes()
	if SoundBus != null:
		SoundBus.sound_emitted.connect(_on_sound_emitted)

func _process(delta: float) -> void:
	_update_major_event_timer(delta)
	_update_local_noise(delta)
	_update_global_pressure(delta)
	_update_phase_state(delta)
	_apply_phase_overlays()
	_apply_phase_audio()
	if GameState.debug_show_sound:
		queue_redraw()

func _draw() -> void:
	if not GameState.debug_show_sound:
		return
	if not has_local_noise:
		return
	var local_pos: Vector2 = to_local(local_noise_position)
	var radius: float = lerpf(debug_noise_radius_min, debug_noise_radius_max, local_noise_value)
	draw_circle(local_pos, radius, debug_noise_color)

func _on_sound_emitted(event: SoundEvent) -> void:
	if event == null:
		return
	if event.sound_type != SoundEvent.SoundType.ANOMALOUS:
		return
	var gain: float = clampf(event.loudness * local_noise_gain, 0.0, local_noise_max)
	if not has_local_noise:
		local_noise_position = event.position
		local_noise_value = clampf(local_noise_value + gain, 0.0, local_noise_max)
		has_local_noise = true
	else:
		var dist: float = local_noise_position.distance_to(event.position)
		var blend: float = local_noise_recenter_strength
		if dist > local_noise_reinforce_radius:
			blend = min(local_noise_recenter_strength * 1.5, 0.9)
		local_noise_position = local_noise_position.lerp(event.position, blend)
		local_noise_value = clampf(local_noise_value + gain, 0.0, local_noise_max)
	GameState.global_pressure += global_pressure_gain_per_anomaly * event.loudness
	if event.tag == "gun":
		local_noise_value = clampf(local_noise_value + gun_local_noise_boost, 0.0, local_noise_max)
		_spike_timer = min(_spike_timer + gun_spike_timer_boost, hunted_spike_time + gun_spike_timer_boost)
		GameState.global_pressure += gun_pressure_boost * event.loudness
	if _is_major_event(event):
		_register_major_event(event)
	_update_pressure_floor()

func _update_local_noise(delta: float) -> void:
	if not has_local_noise:
		local_noise_value = 0.0
		_spike_timer = max(0.0, _spike_timer - delta)
		return
	var decay: float = local_noise_decay
	if local_noise_value >= investigate_threshold or GameState.phase_state != GameState.PhaseState.QUIET:
		decay = local_noise_decay_investigate
	local_noise_value = max(local_noise_value - decay * delta, 0.0)
	if local_noise_value <= 0.001:
		has_local_noise = false
		local_noise_value = 0.0
	_spike_timer = _update_spike_timer(delta, local_noise_value)

func _update_global_pressure(delta: float) -> void:
	if local_noise_value >= investigate_threshold:
		var sustain_gain: float = global_pressure_gain_per_second * delta
		if local_noise_value >= pressure_threshold:
			sustain_gain *= 1.5
		GameState.global_pressure += sustain_gain
	GameState.global_pressure = max(GameState.global_pressure - global_pressure_decay * delta, GameState.global_pressure_floor)
	_update_pressure_floor()

func _update_pressure_floor() -> void:
	var floor_target: float = GameState.global_pressure * global_pressure_floor_ratio
	if floor_target > GameState.global_pressure_floor:
		GameState.global_pressure_floor = floor_target

func _update_phase_state(_delta: float) -> void:
	var prev_phase: int = GameState.phase_state
	if GameState.phase_state != GameState.PhaseState.HUNTED:
		GameState.escape_only = false
	if GameState.phase_state == GameState.PhaseState.HUNTED:
		if not _hunted_locked:
			_enter_hunted()
		return
	var next_phase: int = GameState.PhaseState.QUIET
	if GameState.global_pressure >= hunted_pressure_threshold and _spike_timer >= hunted_spike_time:
		next_phase = GameState.PhaseState.HUNTED
	elif local_noise_value >= pressure_threshold or GameState.global_pressure >= pressure_threshold:
		next_phase = GameState.PhaseState.PRESSURE
	elif local_noise_value >= investigate_threshold:
		next_phase = GameState.PhaseState.INVESTIGATE
	if next_phase == GameState.PhaseState.HUNTED:
		_enter_hunted()
	else:
		GameState.phase_state = next_phase
	if prev_phase != GameState.phase_state:
		_show_phase_message(GameState.phase_state)
	if GameState.debug_print_pressure and _last_phase != next_phase:
		_last_phase = next_phase
		print("Phase:", _phase_name(next_phase), "Global:", "%.2f" % GameState.global_pressure, "Local:", "%.2f" % local_noise_value)

func _apply_phase_overlays() -> void:
	if _overlay == null:
		return
	if not _overlay.has_method("set_phase_intensity"):
		return
	var phase_intensity: float = _compute_phase_intensity()
	_overlay.call("set_phase_intensity", phase_intensity, GameState.phase_state)

func _apply_phase_audio() -> void:
	var intensity: float = _compute_phase_intensity()
	_apply_audio_player(_tension_player, intensity)
	var heartbeat_intensity: float = intensity
	if GameState.phase_state == GameState.PhaseState.HUNTED:
		heartbeat_intensity = 1.0
	_apply_audio_player(_heartbeat_player, heartbeat_intensity)

func _apply_audio_player(player: AudioStreamPlayer, intensity: float) -> void:
	if player == null:
		return
	if player.stream == null:
		return
	if not player.playing:
		player.play()
	var clamped: float = clampf(intensity, 0.0, 1.0)
	player.volume_db = lerpf(-30.0, -6.0, clamped)

func _compute_phase_intensity() -> float:
	var pressure_norm: float = clampf(GameState.global_pressure / max(hunted_pressure_threshold, 0.01), 0.0, 1.0)
	var local_norm: float = clampf(local_noise_value, 0.0, 1.0)
	return max(pressure_norm, local_norm)

func _resolve_nodes() -> void:
	_overlay = get_node_or_null(overlay_path)
	_tension_player = get_node_or_null(tension_player_path) as AudioStreamPlayer
	_heartbeat_player = get_node_or_null(heartbeat_player_path) as AudioStreamPlayer
	_message_hud = get_node_or_null(message_hud_path)
	_apply_audio_streams()

func _update_spike_timer(delta: float, noise_value: float) -> float:
	var timer: float = _spike_timer
	if noise_value >= hunted_spike_threshold:
		timer += delta
	else:
		timer = max(0.0, timer - delta)
	return timer

func _phase_name(phase: int) -> String:
	match phase:
		GameState.PhaseState.QUIET:
			return "QUIET"
		GameState.PhaseState.INVESTIGATE:
			return "INVESTIGATE"
		GameState.PhaseState.PRESSURE:
			return "PRESSURE"
		GameState.PhaseState.HUNTED:
			return "HUNTED"
		_:
			return "UNKNOWN"

func _enter_hunted() -> void:
	GameState.phase_state = GameState.PhaseState.HUNTED
	GameState.escape_only = true
	_hunted_locked = true
	if hunted_message_once != "":
		GameState.show_tutorial_message("phase_hunted", hunted_message_once, 2.4, _message_hud)
	if _message_hud != null and hunted_message != "":
		if _message_hud.has_method("show_message"):
			_message_hud.call("show_message", hunted_message, 3.0)
	_spawn_hunter()

func _show_phase_message(phase: int) -> void:
	match phase:
		GameState.PhaseState.INVESTIGATE:
			if investigate_message != "":
				GameState.show_tutorial_message("phase_investigate", investigate_message, 2.0, _message_hud)
		GameState.PhaseState.PRESSURE:
			if pressure_message != "":
				GameState.show_tutorial_message("phase_pressure", pressure_message, 2.0, _message_hud)

func _is_major_event(event: SoundEvent) -> bool:
	if event.tag == "":
		return false
	for tag in major_event_tags:
		if event.tag == tag:
			return true
	return false

func _register_major_event(event: SoundEvent) -> void:
	_apply_major_spike(event)
	if _major_event_timer > 0.0:
		_major_event_count += 1
	else:
		_major_event_count = 1
	_major_event_timer = max(major_event_window, 0.1)
	if GameState.global_pressure >= major_event_pressure_threshold and _major_event_count >= major_event_required:
		if GameState.phase_state != GameState.PhaseState.HUNTED:
			_enter_hunted()

func _show_major_event_message(event: SoundEvent) -> void:
	if event.tag == "alarm":
		GameState.show_tutorial_message("cause_alarm", alarm_message, 2.0, _message_hud)
	elif event.tag == "callout":
		GameState.show_tutorial_message("cause_callout", callout_message, 2.0, _message_hud)
	elif event.tag == "destruction":
		GameState.show_tutorial_message("cause_destruction", destruction_message, 2.0, _message_hud)

func _apply_major_spike(event: SoundEvent) -> void:
	has_local_noise = true
	local_noise_position = event.position
	local_noise_value = max(local_noise_value, pressure_threshold + 0.05)
	local_noise_value = clampf(local_noise_value + major_event_local_boost, 0.0, local_noise_max)
	_spike_timer = min(_spike_timer + major_event_spike_timer_boost, hunted_spike_time + major_event_spike_timer_boost)
	GameState.global_pressure += major_event_global_boost * event.loudness
	_show_major_event_message(event)

func _update_major_event_timer(delta: float) -> void:
	if _major_event_timer <= 0.0:
		return
	_major_event_timer = max(_major_event_timer - delta, 0.0)
	if _major_event_timer <= 0.0:
		_major_event_count = 0

func _spawn_hunter() -> void:
	if hunter_scene == null:
		return
	if _hunter_instance != null and is_instance_valid(_hunter_instance):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var hunter := hunter_scene.instantiate()
	if hunter == null:
		return
	var spawn_pos: Vector2 = global_position
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		spawn_pos = _pick_spawn_position(player.global_position)
	parent.add_child(hunter)
	if hunter is Node2D:
		_hunter_instance = hunter as Node2D
		_hunter_instance.global_position = spawn_pos
	if hunter.has_method("set"):
		hunter.set("player_path", NodePath("../Player"))
	_notify_hunter_arrived(_hunter_instance)

func _notify_hunter_arrived(hunter: Node2D) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		if node == null:
			continue
		if node == hunter:
			continue
		if node.has_method("flee_and_despawn"):
			node.call("flee_and_despawn", hunter)

func _pick_spawn_position(origin: Vector2) -> Vector2:
	var best_pos: Vector2 = origin + Vector2.RIGHT * hunter_spawn_min_distance
	var best_dist: float = 0.0
	var attempts: int = max(hunter_spawn_attempts, 1)
	for i in range(attempts):
		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(hunter_spawn_min_distance, hunter_spawn_radius)
		var candidate: Vector2 = origin + Vector2.RIGHT.rotated(angle) * dist
		if dist > best_dist:
			best_dist = dist
			best_pos = candidate
	return best_pos

func _apply_audio_streams() -> void:
	if _tension_player != null and _tension_player.stream == null and tension_stream != null:
		_enable_loop(tension_stream)
		_tension_player.stream = tension_stream
	if _heartbeat_player != null and _heartbeat_player.stream == null and heartbeat_stream != null:
		_enable_loop(heartbeat_stream)
		_heartbeat_player.stream = heartbeat_stream

func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
