extends Area2D
class_name StartScavenge

@export var scavenge_scene_paths: Array[String] = [
	"res://Scenes/ScavengeRun.tscn",
	"res://Scenes/ScavengeRun_B.tscn"
]
@export var randomize_scene: bool = true
@export var start_message: String = "Scavenge begins..."
@export var start_message_duration: float = 1.6
@export var prompt_text: String = "Press E to scavenge"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("interactable")
	_rng.randomize()

func interact(_player: Node) -> void:
	var path: String = _pick_scene_path()
	if path == "":
		return
	_show_message(start_message)
	get_tree().change_scene_to_file(path)

func _pick_scene_path() -> String:
	if scavenge_scene_paths.is_empty():
		return ""
	if not randomize_scene or scavenge_scene_paths.size() == 1:
		return scavenge_scene_paths[0]
	var idx: int = _rng.randi_range(0, scavenge_scene_paths.size() - 1)
	return scavenge_scene_paths[idx]

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, start_message_duration)

func get_interact_prompt(_player: Node) -> String:
	return prompt_text
