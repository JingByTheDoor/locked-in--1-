extends Node2D

@export var base_scene_path: String = "res://Scenes/Base.tscn"
@export var player_path: NodePath = NodePath("Player")
@export var startup_message: String = "SCAVENGE: stay quiet"
@export var startup_message_duration: float = 2.0
@export var tutorial_message: String = "Noise draws attention. Extract when ready."

func _ready() -> void:
	GameState.run_state = GameState.RunState.SCAVENGE
	_connect_player()
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
