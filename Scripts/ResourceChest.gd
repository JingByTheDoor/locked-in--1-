extends Area2D

@export var stash_message: String = ""
@export var stash_message_duration: float = 1.4

var _stashed_once: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_stash(null)

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player"):
		_stash(body)

func _stash(player: Node) -> void:
	GameState.player_carry_rank = GameState.CARRY_RANK_MIN
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_carry_rank"):
		player.call("set_carry_rank", GameState.CARRY_RANK_MIN)
	if _stashed_once:
		return
	_stashed_once = true
	if stash_message == "":
		return
	var hud := get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", stash_message, stash_message_duration)
