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
const CARRY_RANK_MIN: int = 1
const CARRY_RANK_MAX: int = 5
const GRADE_MIN: int = 1
const GRADE_MAX: int = 5
const DEFAULT_GRADES: Array[int] = [1, 2, 3]
const GENERATOR_CHARGE_MIN: float = 0.0
const GENERATOR_CHARGE_MAX: float = 100.0
const GENERATOR_DRAIN_STEP: float = 1.0
const GENERATOR_DRAIN_INTERVAL: float = 5.0

var run_state: RunState = RunState.MAIN_MENU
var phase_state: PhaseState = PhaseState.QUIET
var night_index: int = 1

var player_max_hp: int = 100
var player_hp: int = 100
var player_carry_rank: int = 1

var resources: Dictionary = {
	"scrap": 0,
	"wood": 0,
	"ammo": 0,
	"food": 0,
	"fuel": 0,
	"meds": 0
}
var food_grades: Dictionary = {
	"1": 0,
	"2": 0,
	"3": 0
}
var fuel_grades: Dictionary = {
	"1": 0,
	"2": 0,
	"3": 0
}

var base_damage: float = 0.0
var global_pressure: float = 0.0
var global_pressure_floor: float = 0.0
var escape_only: bool = false
var generator_charge: float = 75.0
var generator_on: bool = true
var base_repairs: Dictionary = {}
var tutorial_flags: Dictionary = {}

var debug_show_vision: bool = false
var debug_show_sound: bool = false
var debug_print_pressure: bool = false
var _generator_drain_timer: float = 0.0

func _ready() -> void:
	_ensure_input_map()
	_ensure_resource_defaults()
	_normalize_carry_rank()
	_normalize_generator()
	set_process(true)

func _process(delta: float) -> void:
	_update_generator_drain(delta)

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
		"player_carry_rank": player_carry_rank,
		"resources": resources.duplicate(true),
		"food_grades": food_grades.duplicate(true),
		"fuel_grades": fuel_grades.duplicate(true),
		"base_damage": base_damage,
		"global_pressure": global_pressure,
		"global_pressure_floor": global_pressure_floor,
		"escape_only": escape_only,
		"generator_charge": generator_charge,
		"generator_on": generator_on,
		"base_repairs": base_repairs.duplicate(true),
		"tutorial_flags": tutorial_flags.duplicate(true)
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
	if data.has("player_carry_rank"):
		player_carry_rank = clampi(int(data["player_carry_rank"]), CARRY_RANK_MIN, CARRY_RANK_MAX)
	if data.has("resources") and typeof(data["resources"]) == TYPE_DICTIONARY:
		resources = data["resources"].duplicate(true)
	if data.has("food_grades") and typeof(data["food_grades"]) == TYPE_DICTIONARY:
		food_grades = data["food_grades"].duplicate(true)
	if data.has("fuel_grades") and typeof(data["fuel_grades"]) == TYPE_DICTIONARY:
		fuel_grades = data["fuel_grades"].duplicate(true)
	if data.has("base_damage"):
		base_damage = float(data["base_damage"])
	if data.has("global_pressure"):
		global_pressure = float(data["global_pressure"])
	if data.has("global_pressure_floor"):
		global_pressure_floor = float(data["global_pressure_floor"])
	if data.has("escape_only"):
		escape_only = bool(data["escape_only"])
	if data.has("generator_charge"):
		generator_charge = float(data["generator_charge"])
	if data.has("generator_on"):
		generator_on = bool(data["generator_on"])
	if data.has("base_repairs") and typeof(data["base_repairs"]) == TYPE_DICTIONARY:
		base_repairs = data["base_repairs"].duplicate(true)
	if data.has("tutorial_flags") and typeof(data["tutorial_flags"]) == TYPE_DICTIONARY:
		tutorial_flags = data["tutorial_flags"].duplicate(true)
	if global_pressure < global_pressure_floor:
		global_pressure = global_pressure_floor
	_ensure_resource_defaults()
	_normalize_carry_rank()
	_normalize_generator()

func get_repair_state(repair_id: String, default_repaired: bool = false) -> bool:
	if repair_id == "":
		return default_repaired
	if base_repairs.has(repair_id):
		return bool(base_repairs[repair_id])
	return default_repaired

func set_repair_state(repair_id: String, repaired: bool) -> void:
	if repair_id == "":
		return
	base_repairs[repair_id] = repaired

func is_generator_active() -> bool:
	return generator_on and generator_charge > GENERATOR_CHARGE_MIN

func reset_phase_state() -> void:
	phase_state = PhaseState.QUIET
	escape_only = false

func has_tutorial(key: String) -> bool:
	if key == "":
		return false
	if tutorial_flags.has(key):
		return bool(tutorial_flags[key])
	return false

func mark_tutorial(key: String) -> void:
	if key == "":
		return
	tutorial_flags[key] = true

func show_tutorial_message(key: String, text: String, duration: float = 2.0, hud: Node = null) -> void:
	if key != "" and has_tutorial(key):
		return
	if text == "":
		return
	var target: Node = hud
	if target == null:
		target = get_tree().get_first_node_in_group("message_hud")
	if target != null and target.has_method("show_message"):
		target.call("show_message", text, duration)
	if key != "":
		mark_tutorial(key)

func add_resource(name: String, amount: int) -> void:
	if amount == 0:
		return
	var current: int = 0
	if resources.has(name):
		current = int(resources[name])
	resources[name] = max(current + amount, 0)

func add_food(grade: int, amount: int) -> void:
	if amount == 0:
		return
	var key := _grade_key(grade)
	var current: int = 0
	if food_grades.has(key):
		current = int(food_grades[key])
	food_grades[key] = max(current + amount, 0)
	add_resource("food", amount)

func add_fuel(grade: int, amount: int) -> void:
	if amount == 0:
		return
	var key := _grade_key(grade)
	var current: int = 0
	if fuel_grades.has(key):
		current = int(fuel_grades[key])
	fuel_grades[key] = max(current + amount, 0)
	add_resource("fuel", amount)

func save_run() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: unable to open save file.")
		return false
	file.store_string(JSON.stringify(get_save_data()))
	return true

func reset_run() -> void:
	run_state = RunState.MAIN_MENU
	phase_state = PhaseState.QUIET
	night_index = 1
	player_max_hp = 100
	player_hp = 100
	player_carry_rank = 1
	resources = {
		"scrap": 0,
		"wood": 0,
		"ammo": 0,
		"food": 0,
		"fuel": 0,
		"meds": 0
	}
	food_grades = {
		"1": 0,
		"2": 0,
		"3": 0
	}
	fuel_grades = {
		"1": 0,
		"2": 0,
		"3": 0
	}
	base_damage = 0.0
	global_pressure = 0.0
	global_pressure_floor = 0.0
	escape_only = false
	generator_charge = 75.0
	generator_on = true
	base_repairs = {}
	tutorial_flags = {}
	debug_show_vision = false
	debug_show_sound = false
	debug_print_pressure = false
	_generator_drain_timer = 0.0
	_ensure_resource_defaults()
	_normalize_carry_rank()
	_normalize_generator()

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

	_ensure_action("gun_fire")
	_add_default_mouse_events("gun_fire", [MOUSE_BUTTON_RIGHT])
	_add_default_key_events("gun_fire", [KEY_F])

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

func _ensure_resource_defaults() -> void:
	var defaults: Dictionary = {
		"scrap": 0,
		"wood": 0,
		"ammo": 0,
		"food": 0,
		"fuel": 0,
		"meds": 0
	}
	for key in defaults.keys():
		if not resources.has(key):
			resources[key] = defaults[key]
	_ensure_grade_defaults(food_grades)
	_ensure_grade_defaults(fuel_grades)

func _ensure_grade_defaults(grade_dict: Dictionary) -> void:
	for grade in DEFAULT_GRADES:
		var key := _grade_key(grade)
		if not grade_dict.has(key):
			grade_dict[key] = 0

func _normalize_carry_rank() -> void:
	player_carry_rank = clampi(player_carry_rank, CARRY_RANK_MIN, CARRY_RANK_MAX)

func _normalize_generator() -> void:
	generator_charge = clampf(generator_charge, GENERATOR_CHARGE_MIN, GENERATOR_CHARGE_MAX)
	if generator_charge <= GENERATOR_CHARGE_MIN:
		generator_on = false

func _update_generator_drain(delta: float) -> void:
	if run_state != RunState.NIGHT:
		_generator_drain_timer = 0.0
		return
	if not generator_on or generator_charge <= GENERATOR_CHARGE_MIN:
		generator_on = false
		return
	_generator_drain_timer += delta
	while _generator_drain_timer >= GENERATOR_DRAIN_INTERVAL:
		_generator_drain_timer -= GENERATOR_DRAIN_INTERVAL
		generator_charge = max(generator_charge - GENERATOR_DRAIN_STEP, GENERATOR_CHARGE_MIN)
		if generator_charge <= GENERATOR_CHARGE_MIN:
			generator_on = false
			break

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

func _grade_key(grade: int) -> String:
	var clamped := clampi(grade, GRADE_MIN, GRADE_MAX)
	return str(clamped)
