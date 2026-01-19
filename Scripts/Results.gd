extends Control

@export var base_scene_path: String = "res://Scenes/Base.tscn"

@onready var night_label: Label = $CenterContainer/VBoxContainer/NightLabel
@onready var resources_label: Label = $CenterContainer/VBoxContainer/ResourcesLabel
@onready var base_damage_label: Label = $CenterContainer/VBoxContainer/BaseDamageLabel
@onready var pressure_label: Label = $CenterContainer/VBoxContainer/PressureLabel
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	_update_labels()
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)

func _update_labels() -> void:
	if night_label != null:
		night_label.text = "Night: %d" % GameState.night_index
	if resources_label != null:
		resources_label.text = _resources_summary()
	if base_damage_label != null:
		base_damage_label.text = "Base damage: %.2f" % GameState.base_damage
	if pressure_label != null:
		pressure_label.text = "Global pressure: %.2f" % GameState.global_pressure

func _resources_summary() -> String:
	var parts: Array[String] = []
	parts.append("Resources gained/lost:")
	parts.append("Scrap %d  Wood %d  Ammo %d" % [_res("scrap"), _res("wood"), _res("ammo")])
	parts.append("Food %d  Fuel %d  Meds %d" % [_res("food"), _res("fuel"), _res("meds")])
	return "\n".join(parts)

func _res(name: String) -> int:
	if GameState.resources.has(name):
		return int(GameState.resources[name])
	return 0

func _on_continue_pressed() -> void:
	if base_scene_path == "":
		return
	get_tree().change_scene_to_file(base_scene_path)
