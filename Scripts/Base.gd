extends Node2D

@export var lights_out_path: NodePath = NodePath("LightsOut")
@export var startup_message: String = "BASE: plan & repair"
@export var startup_message_duration: float = 2.0
@export var tutorial_message: String = "Repairs cost wood+scrap. Food heals here."

var _lights_out: CanvasItem

func _ready() -> void:
	GameState.run_state = GameState.RunState.BASE
	GameState.reset_phase_state()
	_lights_out = get_node_or_null(lights_out_path) as CanvasItem
	_update_lighting()
	_show_startup_message()
	_show_tutorial_message()

func _process(_delta: float) -> void:
	_update_lighting()

func _update_lighting() -> void:
	if _lights_out == null:
		return
	_lights_out.visible = not GameState.is_generator_active()

func _show_startup_message() -> void:
	if startup_message == "":
		return
	var hud: Node = get_node_or_null("MessageHud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", startup_message, startup_message_duration)

func _show_tutorial_message() -> void:
	if tutorial_message == "":
		return
	GameState.show_tutorial_message("tutorial_base", tutorial_message, 2.5, get_node_or_null("MessageHud") as Node)
