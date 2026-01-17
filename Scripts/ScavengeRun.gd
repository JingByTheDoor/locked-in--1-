extends Node2D

@export var base_scene_path: String = "res://Scenes/Base.tscn"
@export var player_path: NodePath = NodePath("Player")
@export var spawn_points_path: NodePath = NodePath("PlayerSpawns")
@export var prefer_safe_spawn: bool = true
@export var safe_spawn_bonus: float = 10000.0
@export var startup_message: String = "SCAVENGE: stay quiet"
@export var startup_message_duration: float = 2.0
@export var tutorial_message: String = "Noise draws attention. Extract when ready."

func _ready() -> void:
	GameState.run_state = GameState.RunState.SCAVENGE
	GameState.reset_phase_state()
	_connect_player()
	_place_player_spawn()
	_show_startup_message()
	_show_tutorial_message()

func _connect_player() -> void:
	var player: Node = get_node_or_null(player_path)
	if player == null:
		return
	if player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

func _on_player_died(_context: String) -> void:
	GameState.player_hp = GameState.player_max_hp
	GameState.run_state = GameState.RunState.BASE
	if base_scene_path != "":
		get_tree().change_scene_to_file(base_scene_path)

func _show_startup_message() -> void:
	if startup_message == "":
		return
	var hud: Node = get_node_or_null("MessageHud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", startup_message, startup_message_duration)

func _show_tutorial_message() -> void:
	if tutorial_message == "":
		return
	GameState.show_tutorial_message("tutorial_scavenge", tutorial_message, 2.5, get_node_or_null("MessageHud") as Node)

func _place_player_spawn() -> void:
	var player := get_node_or_null(player_path) as Node2D
	if player == null:
		return
	var spawns := _get_spawn_points()
	if spawns.is_empty():
		return
	var enemies := _get_enemies()
	var best_spawn: Node2D = spawns[0]
	var best_score: float = -INF
	for spawn in spawns:
		var pos := spawn.global_position
		var seen: bool = _is_point_visible_to_enemies(pos, enemies)
		var dist: float = _min_distance_to_enemies(pos, enemies)
		var score: float = dist
		if prefer_safe_spawn and not seen:
			score += safe_spawn_bonus
		if score > best_score:
			best_score = score
			best_spawn = spawn
	player.global_position = best_spawn.global_position

func _get_spawn_points() -> Array[Node2D]:
	var root: Node = get_node_or_null(spawn_points_path)
	if root == null:
		return []
	var points: Array[Node2D] = []
	for child in root.get_children():
		if child is Node2D:
			points.append(child as Node2D)
	return points

func _get_enemies() -> Array[Node2D]:
	var nodes: Array = get_tree().get_nodes_in_group("enemy")
	var enemies: Array[Node2D] = []
	for node in nodes:
		if node is Node2D:
			enemies.append(node as Node2D)
	return enemies

func _is_point_visible_to_enemies(point: Vector2, enemies: Array[Node2D]) -> bool:
	for enemy in enemies:
		if enemy == null:
			continue
		var cone: Node = enemy.get_node_or_null("VisionCone")
		if cone != null and cone.has_method("can_see_point"):
			if bool(cone.call("can_see_point", point)):
				return true
	return false

func _min_distance_to_enemies(point: Vector2, enemies: Array[Node2D]) -> float:
	if enemies.is_empty():
		return 0.0
	var min_dist: float = INF
	for enemy in enemies:
		if enemy == null:
			continue
		var dist: float = point.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
	if min_dist == INF:
		return 0.0
	return min_dist
