extends Node

enum RunState {
	MAIN_MENU,
	SCAVENGE,
	BASE,
	NIGHT,
	RESULTS,
	GAME_OVER
}

enum PhaseState {
	QUIET,
	INVESTIGATE,
	PRESSURE,
	HUNTED
}

const SAVE_PATH := "user://savegame.json"

var run_state: RunState = RunState.MAIN_MENU
var phase_state: PhaseState = PhaseState.QUIET
var night_index: int = 1

var player_max_hp: int = 100
var player_hp: int = 100

var resources: Dictionary = {
	"scrap": 0,
	"fuel": 0,
	"meds": 0
}

var base_damage: float = 0.0
var global_pressure: float = 0.0
var global_pressure_floor: float = 0.0

var debug_show_vision: bool = false
var debug_show_sound: bool = false
var debug_print_pressure: bool = false

func _ready() -> void:
	_ensure_input_map()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_vision"):
		debug_show_vision = !debug_show_vision
	elif event.is_action_pressed("debug_toggle_sound"):
		debug_show_sound = !debug_show_sound
	elif event.is_action_pressed("debug_toggle_pressure"):
		debug_print_pressure = !debug_print_pressure
		if debug_print_pressure:
			_print_pressure_tier()

func get_save_data() -> Dictionary:
	return {
		"run_state": int(run_state),
		"phase_state": int(phase_state),
		"night_index": night_index,
		"player_max_hp": player_max_hp,
		"player_hp": player_hp,
		"resources": resources.duplicate(true),
		"base_damage": base_damage,
		"global_pressure": global_pressure,
		"global_pressure_floor": global_pressure_floor
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("run_state"):
		run_state = int(data["run_state"])
	if data.has("phase_state"):
		phase_state = int(data["phase_state"])
	if data.has("night_index"):
		night_index = int(data["night_index"])
	if data.has("player_max_hp"):
		player_max_hp = int(data["player_max_hp"])
	if data.has("player_hp"):
		player_hp = int(data["player_hp"])
		player_hp = clampi(player_hp, 0, player_max_hp)
	if data.has("resources") and typeof(data["resources"]) == TYPE_DICTIONARY:
		resources = data["resources"].duplicate(true)
	if data.has("base_damage"):
		base_damage = float(data["base_damage"])
	if data.has("global_pressure"):
		global_pressure = float(data["global_pressure"])
	if data.has("global_pressure_floor"):
		global_pressure_floor = float(data["global_pressure_floor"])
	if global_pressure < global_pressure_floor:
		global_pressure = global_pressure_floor

func save_run() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: unable to open save file.")
		return false
	file.store_string(JSON.stringify(get_save_data()))
	return true

func load_run() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Load failed: unable to open save file.")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Load failed: save data is invalid.")
		return false
	apply_save_data(parsed)
	return true

func _ensure_input_map() -> void:
	_ensure_action("move_up")
	_ensure_action("move_down")
	_ensure_action("move_left")
	_ensure_action("move_right")
	_add_default_key_events("move_up", [KEY_W, KEY_UP])
	_add_default_key_events("move_down", [KEY_S, KEY_DOWN])
	_add_default_key_events("move_left", [KEY_A, KEY_LEFT])
	_add_default_key_events("move_right", [KEY_D, KEY_RIGHT])

	_ensure_action("sprint")
	_add_default_key_events("sprint", [KEY_SHIFT])

	_ensure_action("interact")
	_add_default_key_events("interact", [KEY_E])

	_ensure_action("attack")
	_add_default_mouse_events("attack", [MOUSE_BUTTON_LEFT])

	_ensure_action("reload")
	_add_default_key_events("reload", [KEY_R])

	_ensure_action("aim")
	_add_default_mouse_events("aim", [MOUSE_BUTTON_RIGHT])

	_ensure_action("pause")
	_add_default_key_events("pause", [KEY_ESCAPE])

	_ensure_action("debug_toggle_vision")
	_add_default_key_events("debug_toggle_vision", [KEY_F1])

	_ensure_action("debug_toggle_sound")
	_add_default_key_events("debug_toggle_sound", [KEY_F2])

	_ensure_action("debug_toggle_pressure")
	_add_default_key_events("debug_toggle_pressure", [KEY_F3])

func _print_pressure_tier() -> void:
	print("Pressure tier:", _phase_state_name(phase_state), "Global pressure:", global_pressure)

func _phase_state_name(state: PhaseState) -> String:
	match state:
		PhaseState.QUIET:
			return "QUIET"
		PhaseState.INVESTIGATE:
			return "INVESTIGATE"
		PhaseState.PRESSURE:
			return "PRESSURE"
		PhaseState.HUNTED:
			return "HUNTED"
		_:
			return "UNKNOWN"

func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _add_default_key_events(action_name: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		return
	var existing := InputMap.action_get_events(action_name)
	for key in keys:
		if _has_key_event(existing, key):
			continue
		var ev := InputEventKey.new()
		ev.keycode = key
		InputMap.action_add_event(action_name, ev)

func _add_default_mouse_events(action_name: StringName, buttons: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		return
	var existing := InputMap.action_get_events(action_name)
	for button in buttons:
		if _has_mouse_event(existing, button):
			continue
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		InputMap.action_add_event(action_name, ev)

func _has_key_event(events: Array[InputEvent], key: int) -> bool:
	for ev in events:
		if ev is InputEventKey and ev.keycode == key:
			return true
	return false

func _has_mouse_event(events: Array[InputEvent], button: int) -> bool:
	for ev in events:
		if ev is InputEventMouseButton and ev.button_index == button:
			return true
	return false
