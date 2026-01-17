extends Area2D
class_name ExtractionZone

@export var interact_duration: float = 2.0
@export var base_scene_path: String = "res://Scenes/Base.tscn"
@export var start_message: String = "Extracting..."
@export var complete_message: String = "Extraction complete."
@export var cancel_message: String = "Extraction canceled."
@export var extraction_loudness: float = 1.2
@export var extraction_radius: float = 520.0
@export var prompt_text: String = "Press E to extract"

var _timer: Timer
var _extracting: bool = false
var _player: Node = null

func _ready() -> void:
	add_to_group("exit")
	add_to_group("interactable")
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_extract_complete)
	add_child(_timer)
	body_exited.connect(_on_body_exited)

func interact(player: Node) -> void:
	if _extracting:
		return
	_player = player
	_extracting = true
	_timer.start(max(interact_duration, 0.1))
	_emit_extraction_sound(player)
	_show_message(start_message, interact_duration)

func _on_extract_complete() -> void:
	if not _extracting:
		return
	_extracting = false
	_show_message(complete_message, 1.5)
	GameState.run_state = GameState.RunState.BASE
	GameState.escape_only = false
	if base_scene_path != "":
		get_tree().change_scene_to_file(base_scene_path)

func _on_body_exited(body: Node) -> void:
	if not _extracting:
		return
	if body != _player:
		return
	_cancel_extraction()

func _cancel_extraction() -> void:
	_extracting = false
	if _timer != null:
		_timer.stop()
	_show_message(cancel_message, 1.2)

func _emit_extraction_sound(player: Node) -> void:
	if SoundBus == null:
		return
	var loudness := extraction_loudness
	var radius := extraction_radius
	if player != null and player.has_method("get_interaction_noise_multiplier"):
		var mult: float = float(player.call("get_interaction_noise_multiplier"))
		loudness *= mult
		radius *= mult
	SoundBus.emit_sound_at(global_position, loudness, radius, SoundEvent.SoundType.ANOMALOUS, self)

func _show_message(text: String, duration: float) -> void:
	if text == "":
		return
	var hud := get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, duration)

func get_interact_prompt(_player: Node) -> String:
	return prompt_text
