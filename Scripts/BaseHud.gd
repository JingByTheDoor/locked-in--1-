extends CanvasLayer

@export var refresh_interval: float = 0.2

@onready var label: Label = $Label

var _refresh_timer: float = 0.0

func _ready() -> void:
	_update_text()

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = refresh_interval
	_update_text()

func _update_text() -> void:
	if label == null:
		return
	var lines: Array[String] = []
	lines.append("RESOURCES")
	lines.append("Scrap: %d  Wood: %d  Fuel: %d" % [_res("scrap"), _res("wood"), _res("fuel")])
	lines.append("Food: %d  Ammo: %d" % [_res("food"), _res("ammo")])
	lines.append("")
	lines.append("GENERATOR: %d%% %s" % [int(round(GameState.generator_charge)), _generator_state()])
	lines.append("")
	lines.append("REPAIRS")
	for entry in _repair_entries():
		lines.append(entry)
	label.text = "\n".join(lines)

func _res(name: String) -> int:
	if GameState.resources.has(name):
		return int(GameState.resources[name])
	return 0

func _generator_state() -> String:
	return "ON" if GameState.is_generator_active() else "OFF"

func _repair_entries() -> Array[String]:
	var entries: Array[String] = []
	var nodes: Array = get_tree().get_nodes_in_group("repairable")
	for node in nodes:
		if node == null:
			continue
		var label_text: String = str(node.name)
		if node.has_method("get_display_name"):
			label_text = str(node.call("get_display_name"))
		var repaired := false
		if node.has_method("is_repaired"):
			repaired = bool(node.call("is_repaired"))
		var state_text := "OK" if repaired else "DAMAGED"
		entries.append("%s: %s" % [label_text, state_text])
	entries.sort()
	return entries
