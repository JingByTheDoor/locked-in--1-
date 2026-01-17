extends CanvasLayer

@export var refresh_interval: float = 0.05
@export var hide_when_empty: bool = true

@onready var label: Label = $Label

var _refresh_timer: float = 0.0
var _last_text: String = ""

func _ready() -> void:
	if label != null:
		label.visible = false

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = refresh_interval
	_update_prompt()

func _update_prompt() -> void:
	if label == null:
		return
	var text: String = _get_prompt_text()
	if text == "":
		if hide_when_empty:
			label.visible = false
		return
	if text != _last_text:
		label.text = text
		_last_text = text
	label.visible = true

func _get_prompt_text() -> String:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return ""
	if player.has_method("get_interact_prompt_text"):
		return str(player.call("get_interact_prompt_text"))
	return ""
