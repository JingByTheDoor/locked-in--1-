extends Area2D
class_name BaseGenerator

@export var fuel_item_value: float = 20.0
@export var on_color: Color = Color(0.6, 1.0, 0.6, 1.0)
@export var off_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var refuel_message: String = "Generator refueled."
@export var no_fuel_message: String = "No fuel."
@export var toggle_on_message: String = "Generator on."
@export var toggle_off_message: String = "Generator off."
@export var prompt_refuel: String = "Press E to refuel generator"
@export var prompt_toggle_on: String = "Press E to turn generator on"
@export var prompt_toggle_off: String = "Press E to turn generator off"
@export var prompt_no_fuel: String = "No fuel"
@export var hum_stream: AudioStream = preload("res://Audio/generator hum.wav")
@export var hum_volume_db: float = -8.0
@export var shutdown_stream: AudioStream = preload("res://Audio/generator shutdown.wav")
@export var shutdown_volume_db: float = -4.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hum_player: AudioStreamPlayer2D = get_node_or_null("HumLoop") as AudioStreamPlayer2D

var _last_active: bool = false

func _ready() -> void:
	add_to_group("interactable")
	_last_active = GameState.is_generator_active()
	_apply_audio_streams()
	_update_visuals()

func _process(_delta: float) -> void:
	_update_visuals()
	_update_shutdown_audio()

func interact(_player: Node) -> void:
	if GameState.generator_charge < GameState.GENERATOR_CHARGE_MAX and _has_fuel():
		_consume_fuel()
		GameState.generator_on = true
		_show_message(refuel_message)
		return
	if GameState.generator_charge <= GameState.GENERATOR_CHARGE_MIN:
		_show_message(no_fuel_message)
		return
	GameState.generator_on = not GameState.generator_on
	if GameState.generator_on:
		_show_message(toggle_on_message)
	else:
		_show_message(toggle_off_message)

func _has_fuel() -> bool:
	if GameState.resources.has("fuel"):
		return int(GameState.resources["fuel"]) > 0
	return false

func _consume_fuel() -> void:
	GameState.add_resource("fuel", -1)
	GameState.generator_charge = clampf(GameState.generator_charge + fuel_item_value, GameState.GENERATOR_CHARGE_MIN, GameState.GENERATOR_CHARGE_MAX)

func _update_visuals() -> void:
	if sprite != null:
		sprite.modulate = on_color if GameState.is_generator_active() else off_color
	if hum_player != null and hum_player.stream != null:
		if GameState.is_generator_active():
			if not hum_player.playing:
				hum_player.play()
		else:
			if hum_player.playing:
				hum_player.stop()

func _apply_audio_streams() -> void:
	if hum_player != null and hum_player.stream == null and hum_stream != null:
		_enable_loop(hum_stream)
		hum_player.stream = hum_stream
		hum_player.volume_db = hum_volume_db

func _update_shutdown_audio() -> void:
	var active := GameState.is_generator_active()
	if _last_active and not active:
		AudioOneShot.play_2d(shutdown_stream, global_position, get_tree().current_scene, shutdown_volume_db)
	_last_active = active

func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.4)

func get_interact_prompt(_player: Node) -> String:
	if GameState.generator_charge < GameState.GENERATOR_CHARGE_MAX and _has_fuel():
		return prompt_refuel
	if GameState.generator_charge <= GameState.GENERATOR_CHARGE_MIN:
		return prompt_no_fuel
	if GameState.generator_on:
		return prompt_toggle_off
	return prompt_toggle_on
