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
@export var deny_when_escape_only: bool = true

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Node) -> void:
	if deny_when_escape_only and GameState.escape_only:
		_show_message("Escape only.")
		return
	_apply_pickup(player)
	queue_free()

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
		SoundBus.emit_sound_at(global_position, pickup_loudness * noise_mult, pickup_radius * noise_mult, sound_type, self)

func _show_message(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.5)
