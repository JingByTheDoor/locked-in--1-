extends Area2D
class_name Repairable

@export var repair_id: String = ""
@export var display_name: String = ""
@export var repair_type: String = "Door"
@export var cost_wood: int = 0
@export var cost_scrap: int = 0
@export var default_repaired: bool = false
@export var repaired_texture: Texture2D
@export var damaged_texture: Texture2D
@export var repaired_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var damaged_color: Color = Color(0.6, 0.25, 0.25, 1.0)

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("RepairSound") as AudioStreamPlayer2D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("repairable")
	_apply_state()

func interact(_player: Node) -> void:
	if is_repaired():
		_show_message("%s repaired." % get_display_name())
		return
	if not _has_resources():
		_show_message("Need %d wood + %d scrap." % [cost_wood, cost_scrap])
		return
	GameState.add_resource("wood", -cost_wood)
	GameState.add_resource("scrap", -cost_scrap)
	GameState.set_repair_state(_effective_id(), true)
	_apply_state()
	if audio_player != null and audio_player.stream != null:
		audio_player.play()
	_show_message("%s fixed." % get_display_name())

func is_repaired() -> bool:
	return GameState.get_repair_state(_effective_id(), default_repaired)

func get_display_name() -> String:
	if display_name != "":
		return display_name
	if repair_type != "":
		return repair_type
	return name

func _effective_id() -> String:
	if repair_id != "":
		return repair_id
	return name

func _has_resources() -> bool:
	var wood: int = 0
	if GameState.resources.has("wood"):
		wood = int(GameState.resources["wood"])
	var scrap: int = 0
	if GameState.resources.has("scrap"):
		scrap = int(GameState.resources["scrap"])
	return wood >= cost_wood and scrap >= cost_scrap

func _apply_state() -> void:
	if sprite == null:
		return
	var repaired := is_repaired()
	if repaired and repaired_texture != null:
		sprite.texture = repaired_texture
	elif not repaired and damaged_texture != null:
		sprite.texture = damaged_texture
	sprite.modulate = repaired_color if repaired else damaged_color

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.6)
