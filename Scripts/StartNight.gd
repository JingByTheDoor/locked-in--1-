extends Area2D
class_name StartNight

@export var night_scene_path: String = "res://Scenes/Night.tscn"
@export var start_message: String = "Night begins..."
@export var start_message_duration: float = 1.6

func _ready() -> void:
	add_to_group("interactable")

func interact(_player: Node) -> void:
	if night_scene_path == "":
		return
	_show_message(start_message)
	get_tree().change_scene_to_file(night_scene_path)

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, start_message_duration)
