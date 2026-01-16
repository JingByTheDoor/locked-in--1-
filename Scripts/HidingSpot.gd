extends Area2D

@export var enter_message: String = "Hiding..."
@export var exit_message: String = "Left hiding."
@export var toggle_on_interact: bool = true

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Node) -> void:
	if player == null:
		return
	if player.has_method("toggle_hiding") and toggle_on_interact:
		player.call("toggle_hiding")
		_show_message(_current_message(player))
	elif player.has_method("set_hiding"):
		player.call("set_hiding", true)
		_show_message(enter_message)

func _current_message(player: Node) -> String:
	if player != null and player.has_method("is_hiding"):
		if bool(player.call("is_hiding")):
			return enter_message
	return exit_message

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud := get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.2)
