extends Area2D
class_name Repairable

@export var repair_id: String = ""
@export var display_name: String = ""
@export var repair_type: String = "Door"
@export var cost_wood: int = 0
@export var cost_scrap: int = 0
@export var default_repaired: bool = false
@export var day_repair_time: float = 0.0
@export var night_repair_time: float = 2.5
@export var breach_damage_message: String = "Breach!"
@export var breach_loudness: float = 1.4
@export var breach_radius: float = 900.0
@export var breach_emit_sound: bool = true
@export var repaired_texture: Texture2D
@export var damaged_texture: Texture2D
@export var repaired_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var damaged_color: Color = Color(0.6, 0.25, 0.25, 1.0)

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("RepairSound") as AudioStreamPlayer2D

var _repair_timer: Timer
var _repairing: bool = false
var _repairing_player: Node = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("repairable")
	_apply_state()
	_repair_timer = Timer.new()
	_repair_timer.one_shot = true
	_repair_timer.timeout.connect(_finish_repair)
	add_child(_repair_timer)
	body_exited.connect(_on_body_exited)

func interact(_player: Node) -> void:
	if is_repaired():
		_show_message("%s repaired." % get_display_name())
		return
	if not _has_resources():
		_show_message("Need %d wood + %d scrap." % [cost_wood, cost_scrap])
		return
	if _repairing:
		return
	var repair_time := _get_repair_time()
	if repair_time <= 0.0:
		_complete_repair()
		return
	_start_repair(_player, repair_time)

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

func apply_breach_damage() -> void:
	if _repairing:
		_cancel_repair()
	var was_repaired := is_repaired()
	GameState.set_repair_state(_effective_id(), false)
	_apply_state()
	if breach_emit_sound and SoundBus != null:
		SoundBus.emit_sound_at(global_position, breach_loudness, breach_radius, SoundEvent.SoundType.ANOMALOUS, self, "destruction")
	if was_repaired and breach_damage_message != "":
		_show_message(breach_damage_message)

func _start_repair(player: Node, duration: float) -> void:
	_repairing = true
	_repairing_player = player
	_repair_timer.start(duration)
	if _repairing_player != null and _repairing_player.has_method("set_repair_lock"):
		_repairing_player.call("set_repair_lock", true)
	_show_message("Repairing...")

func _finish_repair() -> void:
	if not _repairing:
		return
	_complete_repair()

func _complete_repair() -> void:
	_repairing = false
	_unlock_player()
	GameState.add_resource("wood", -cost_wood)
	GameState.add_resource("scrap", -cost_scrap)
	GameState.set_repair_state(_effective_id(), true)
	_apply_state()
	if audio_player != null and audio_player.stream != null:
		audio_player.play()
	_show_message("%s fixed." % get_display_name())

func _cancel_repair() -> void:
	_repairing = false
	if _repair_timer != null:
		_repair_timer.stop()
	_unlock_player()
	_show_message("Repair canceled.")

func _unlock_player() -> void:
	if _repairing_player != null and _repairing_player.has_method("set_repair_lock"):
		_repairing_player.call("set_repair_lock", false)
	_repairing_player = null

func _on_body_exited(body: Node) -> void:
	if not _repairing:
		return
	if body != _repairing_player:
		return
	_cancel_repair()

func _get_repair_time() -> float:
	if GameState.run_state == GameState.RunState.NIGHT:
		return max(night_repair_time, 0.0)
	return max(day_repair_time, 0.0)

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.6)
