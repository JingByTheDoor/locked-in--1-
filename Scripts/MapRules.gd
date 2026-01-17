extends Node

@export var min_exits: int = 2
@export var min_hiding_spots: int = 2
@export var min_unfair_rooms: int = 1
@export var warn_on_missing: bool = true

func _ready() -> void:
	if not warn_on_missing:
		return
	var missing: Array[String] = []
	if _count_group("exit") < min_exits:
		missing.append("exits")
	if _count_group("hiding_spot") < min_hiding_spots:
		missing.append("hiding spots")
	if _count_group("unfair_room") < min_unfair_rooms:
		missing.append("unfair rooms")
	if missing.is_empty():
		return
	var message: String = "Map rules missing: " + ", ".join(missing)
	push_warning(message)
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", message, 2.5)

func _count_group(group_name: String) -> int:
	var nodes: Array = get_tree().get_nodes_in_group(group_name)
	return nodes.size()
