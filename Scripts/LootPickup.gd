extends Area2D
class_name LootPickup

enum LootType {
	SCRAP,
	WOOD,
	FUEL,
	FOOD,
	AMMO
}

@export var loot_type: LootType = LootType.SCRAP
@export var amount: int = 1
@export var grade: int = 1
@export var carry_rank_add: int = 1
@export var pickup_loudness: float = 0.2
@export var pickup_radius: float = 140.0
@export var pickup_anomaly: bool = false
@export var deny_when_escape_only: bool = false
@export var prompt_text: String = ""
@export var pickup_stream: AudioStream = preload("res://Audio/pickup sound.wav")
@export var pickup_volume_db: float = -6.0
@export var hunted_noise_multiplier: float = 1.6
@export var animation_overrides: Dictionary = {
	LootType.SCRAP: "Scrap",
	LootType.WOOD: "Plank",
	LootType.FUEL: "Fuel",
	LootType.FOOD: "Food",
	LootType.AMMO: "Ammo"
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("loot")
	_update_sprite_animation()

func interact(player: Node) -> void:
	if deny_when_escape_only and GameState.escape_only:
		_show_message("Escape only.")
		return
	_play_pickup_audio()
	_apply_pickup(player)
	queue_free()

func get_interact_prompt(_player: Node) -> String:
	if deny_when_escape_only and GameState.escape_only:
		return "Escape only."
	if prompt_text != "":
		return prompt_text
	return "Press E to collect " + _loot_name()

func _apply_pickup(player: Node) -> void:
	match loot_type:
		LootType.SCRAP:
			GameState.add_resource("scrap", amount)
		LootType.WOOD:
			GameState.add_resource("wood", amount)
		LootType.AMMO:
			GameState.add_resource("ammo", amount)
		LootType.FUEL:
			GameState.add_fuel(grade, amount)
		LootType.FOOD:
			GameState.add_food(grade, amount)
	if player != null and player.has_method("add_carry_rank"):
		player.call("add_carry_rank", carry_rank_add)
	var noise_mult: float = 1.0
	if player != null and player.has_method("get_interaction_noise_multiplier"):
		noise_mult = float(player.call("get_interaction_noise_multiplier"))
	if SoundBus != null:
		var sound_type: int = SoundEvent.SoundType.EXPECTED
		if pickup_anomaly:
			sound_type = SoundEvent.SoundType.ANOMALOUS
		var loudness := pickup_loudness * noise_mult
		var radius := pickup_radius * noise_mult
		if GameState.phase_state == GameState.PhaseState.HUNTED:
			sound_type = SoundEvent.SoundType.ANOMALOUS
			var mult: float = max(hunted_noise_multiplier, 0.1)
			loudness *= mult
			radius *= mult
		SoundBus.emit_sound_at(global_position, loudness, radius, sound_type, self)

func _show_message(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.5)

func _update_sprite_animation() -> void:
	if sprite == null:
		return
	var anim_name := _animation_name()
	if anim_name == "":
		return
	if sprite.animation != anim_name:
		sprite.animation = anim_name
	if not sprite.is_playing():
		sprite.play(anim_name)

func _loot_name() -> String:
	match loot_type:
		LootType.SCRAP:
			return "scrap"
		LootType.WOOD:
			return "plank"
		LootType.FUEL:
			return "fuel"
		LootType.FOOD:
			return "food"
		LootType.AMMO:
			return "ammo"
		_:
			return "item"

func _animation_name() -> String:
	if animation_overrides.has(loot_type):
		return str(animation_overrides[loot_type])
	match loot_type:
		LootType.SCRAP:
			return "Scrap"
		LootType.WOOD:
			return "Plank"
		LootType.FUEL:
			return "Fuel"
		LootType.FOOD:
			return "Food"
		LootType.AMMO:
			return "Ammo"
	return ""

func _play_pickup_audio() -> void:
	if pickup_stream == null:
		return
	AudioOneShot.play_2d(pickup_stream, global_position, get_tree().current_scene, pickup_volume_db)
