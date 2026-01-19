extends Node2D

enum NightVariant {
	CALM,
	BREACH_HEAVY
}

@export var night_duration: float = 60.0
@export var calm_night_chance: float = 0.35
@export var calm_spawn_count: int = 4
@export var heavy_spawn_count: int = 10
@export var calm_spawn_interval: float = 6.0
@export var heavy_spawn_interval: float = 3.0
@export var gun_response_spawns: int = 2
@export var ramp_interval_nights: int = 2
@export var ramp_spawn_increase: int = 1
@export var ramp_interval_decrease: float = 0.25
@export var ramp_heavy_spawn_multiplier: int = 2
@export var ramp_gun_response_increase: int = 1
@export var min_calm_interval: float = 2.5
@export var min_heavy_interval: float = 1.5
@export var base_scene_path: String = "res://Scenes/Base.tscn"
@export var results_scene_path: String = "res://Scenes/Results.tscn"
@export var intruder_scene: PackedScene
@export var spawn_points_path: NodePath = NodePath("SpawnPoints")
@export var intruder_container_path: NodePath = NodePath("Intruders")
@export var night_hud_path: NodePath = NodePath("NightHud")
@export var message_hud_path: NodePath = NodePath("MessageHud")
@export var lights_out_path: NodePath = NodePath("LightsOut/ColorRect")

@export var breach_base_damage: float = 0.1
@export var breach_pressure_gain: float = 0.08
@export var breach_loss_wood: int = 1
@export var breach_loss_scrap: int = 1
@export var breach_loss_food: int = 0
@export var breach_loss_ammo: int = 0

@export var death_base_damage: float = 0.3
@export var death_pressure_gain: float = 0.2
@export var death_loss_wood: int = 2
@export var death_loss_scrap: int = 2
@export var death_loss_food: int = 1
@export var death_loss_ammo: int = 1

@export var calm_message: String = "Night: calm"
@export var heavy_message: String = "Night: breaches likely"
@export var tutorial_message: String = "Hold the line. Repairs lock you in."
@export var lights_out_spawn_multiplier: float = 0.6

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_points: Array[Node2D] = []
var _intruder_container: Node = null
var _night_hud: Node = null
var _message_hud: Node = null
var _lights_out: CanvasItem = null
var _variant: NightVariant = NightVariant.CALM
var _time_left: float = 0.0
var _spawn_timer: float = 0.0
var _remaining_spawns: int = 0
var _spawn_interval: float = 0.0
var _finishing: bool = false
var _ramped_calm_spawn_count: int = 0
var _ramped_heavy_spawn_count: int = 0
var _ramped_calm_interval: float = 0.0
var _ramped_heavy_interval: float = 0.0
var _gun_response_spawns: int = 0

func _ready() -> void:
	add_to_group("night_manager")
	GameState.run_state = GameState.RunState.NIGHT
	GameState.reset_phase_state()
	_rng.randomize()
	_resolve_nodes()
	_update_lighting()
	_cache_spawn_points()
	_apply_difficulty_ramp()
	_choose_variant()
	_time_left = max(night_duration, 1.0)
	_spawn_timer = 0.0
	_update_hud()
	_connect_player()
	_show_tutorial_message()
	if SoundBus != null:
		SoundBus.sound_emitted.connect(_on_sound_emitted)

func _process(delta: float) -> void:
	if _finishing:
		return
	_time_left = max(_time_left - delta, 0.0)
	_update_lighting()
	_update_hud()
	_update_spawns(delta)
	if _time_left <= 0.0:
		_finish_night()

func _connect_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

func _resolve_nodes() -> void:
	_intruder_container = get_node_or_null(intruder_container_path)
	_night_hud = get_node_or_null(night_hud_path)
	_message_hud = get_node_or_null(message_hud_path)
	_lights_out = get_node_or_null(lights_out_path) as CanvasItem

func _cache_spawn_points() -> void:
	_spawn_points.clear()
	var root: Node = get_node_or_null(spawn_points_path)
	if root == null:
		return
	for child in root.get_children():
		if child is Node2D:
			_spawn_points.append(child as Node2D)

func _choose_variant() -> void:
	var adjusted_chance: float = calm_night_chance - float(max(GameState.night_index - 1, 0)) * 0.05
	adjusted_chance = clampf(adjusted_chance, 0.1, 0.8)
	_variant = NightVariant.CALM if _rng.randf() <= adjusted_chance else NightVariant.BREACH_HEAVY
	if _variant == NightVariant.CALM:
		_remaining_spawns = max(_ramped_calm_spawn_count, 0)
		_spawn_interval = max(_ramped_calm_interval, 0.2)
		_show_message(calm_message)
	else:
		_remaining_spawns = max(_ramped_heavy_spawn_count, 0)
		_spawn_interval = max(_ramped_heavy_interval, 0.2)
		_show_message(heavy_message)

func _update_spawns(delta: float) -> void:
	if _remaining_spawns <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var interval := _spawn_interval
	if not GameState.is_generator_active():
		interval = max(_spawn_interval * lights_out_spawn_multiplier, 0.2)
	_spawn_timer = interval
	_spawn_intruder()
	_remaining_spawns -= 1

func _spawn_intruder() -> void:
	if intruder_scene == null:
		return
	var spawn_pos := _pick_spawn_position()
	var intruder: Node = intruder_scene.instantiate()
	if intruder == null:
		return
	if _intruder_container != null:
		_intruder_container.add_child(intruder)
	else:
		add_child(intruder)
	if intruder is Node2D:
		(intruder as Node2D).global_position = spawn_pos
	if intruder.has_method("set_manager"):
		intruder.call("set_manager", self)
	if intruder.has_method("set_target"):
		var target: Node2D = get_breach_target()
		if target != null:
			intruder.call("set_target", target)

func _pick_spawn_position() -> Vector2:
	if _spawn_points.size() == 0:
		return global_position + Vector2.RIGHT * 400.0
	var idx: int = _rng.randi_range(0, _spawn_points.size() - 1)
	return _spawn_points[idx].global_position

func get_breach_target() -> Node2D:
	var all_repairables: Array = get_tree().get_nodes_in_group("repairable")
	var damaged: Array[Node2D] = []
	var candidates: Array[Node2D] = []
	for node in all_repairables:
		if node == null:
			continue
		if not (node is Node2D):
			continue
		var node2d: Node2D = node as Node2D
		candidates.append(node2d)
		if node2d.has_method("is_repaired"):
			if not bool(node2d.call("is_repaired")):
				damaged.append(node2d)
	if damaged.size() > 0:
		var idx: int = _rng.randi_range(0, damaged.size() - 1)
		return damaged[idx]
	if candidates.size() == 0:
		return null
	var any_idx: int = _rng.randi_range(0, candidates.size() - 1)
	return candidates[any_idx]

func register_breach(target: Node, _intruder: Node) -> void:
	if _finishing:
		return
	_apply_breach_consequences()
	if target != null and target.has_method("apply_breach_damage"):
		target.call("apply_breach_damage")

func _apply_breach_consequences() -> void:
	GameState.base_damage += breach_base_damage
	GameState.global_pressure += breach_pressure_gain
	GameState.add_resource("wood", -breach_loss_wood)
	GameState.add_resource("scrap", -breach_loss_scrap)
	GameState.add_resource("food", -breach_loss_food)
	GameState.add_resource("ammo", -breach_loss_ammo)

func _on_player_died(_context: String) -> void:
	if _finishing:
		return
	_finishing = true
	_apply_death_consequences()
	GameState.player_hp = GameState.player_max_hp
	get_tree().change_scene_to_file("res://Scenes/Night.tscn")

func _apply_death_consequences() -> void:
	GameState.base_damage += death_base_damage
	GameState.global_pressure += death_pressure_gain
	GameState.add_resource("wood", -death_loss_wood)
	GameState.add_resource("scrap", -death_loss_scrap)
	GameState.add_resource("food", -death_loss_food)
	GameState.add_resource("ammo", -death_loss_ammo)

func _finish_night() -> void:
	_finishing = true
	GameState.night_index += 1
	GameState.run_state = GameState.RunState.RESULTS
	GameState.escape_only = false
	var target_scene := results_scene_path
	if target_scene == "":
		target_scene = base_scene_path
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)

func _update_hud() -> void:
	if _night_hud != null and _night_hud.has_method("set_time_left"):
		_night_hud.call("set_time_left", _time_left)

func _update_lighting() -> void:
	if _lights_out == null:
		return
	_lights_out.visible = not GameState.is_generator_active()

func _show_message(text: String) -> void:
	if text == "":
		return
	if _message_hud != null and _message_hud.has_method("show_message"):
		_message_hud.call("show_message", text, 2.0)

func _on_sound_emitted(event: SoundEvent) -> void:
	if event == null:
		return
	if event.tag != "gun":
		return
	for i in range(_gun_response_spawns):
		_spawn_intruder()

func _apply_difficulty_ramp() -> void:
	var steps: int = _get_ramp_steps()
	_ramped_calm_spawn_count = calm_spawn_count + steps * ramp_spawn_increase
	_ramped_heavy_spawn_count = heavy_spawn_count + steps * ramp_spawn_increase * ramp_heavy_spawn_multiplier
	_ramped_calm_interval = max(calm_spawn_interval - float(steps) * ramp_interval_decrease, min_calm_interval)
	_ramped_heavy_interval = max(heavy_spawn_interval - float(steps) * ramp_interval_decrease, min_heavy_interval)
	_gun_response_spawns = gun_response_spawns + steps * ramp_gun_response_increase

func _get_ramp_steps() -> int:
	var interval: int = max(ramp_interval_nights, 1)
	return int((GameState.night_index - 1) / interval)

func _show_tutorial_message() -> void:
	if tutorial_message == "":
		return
	GameState.show_tutorial_message("tutorial_night", tutorial_message, 2.5, get_node_or_null("MessageHud") as Node)
