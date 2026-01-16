extends Node2D

@export var startup_message: String = "DEBUG: Game start"
@export var startup_message_duration: float = 2.0

func _ready() -> void:
	if startup_message == "":
		return
	var hud := get_node_or_null("MessageHud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", startup_message, startup_message_duration)
