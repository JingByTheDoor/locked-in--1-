extends Area2D
class_name FoodStation

@export var heal_per_food: int = 20
@export var consume_per_use: int = 1
@export var no_food_message: String = "No food."
@export var heal_message: String = "Recovered."

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Node) -> void:
	var food: int = 0
	if GameState.resources.has("food"):
		food = int(GameState.resources["food"])
	if food < consume_per_use:
		_show_message(no_food_message)
		return
	GameState.add_resource("food", -consume_per_use)
	if player != null and player.has_method("heal"):
		player.call("heal", heal_per_food)
	else:
		GameState.player_hp = clampi(GameState.player_hp + heal_per_food, 0, GameState.player_max_hp)
	_show_message(heal_message)

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.4)
