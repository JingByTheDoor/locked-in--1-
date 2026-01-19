extends CanvasLayer

@export var refresh_interval: float = 0.2

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HpBar
@onready var ammo_label: Label = $MarginContainer/VBoxContainer/AmmoLabel
@onready var carry_label: Label = $MarginContainer/VBoxContainer/CarryLabel
@onready var phase_label: Label = $MarginContainer/VBoxContainer/PhaseLabel

var _refresh_timer: float = 0.0

func _ready() -> void:
	_update_display()

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = refresh_interval
	_update_display()

func _update_display() -> void:
	if hp_bar != null:
		hp_bar.max_value = float(GameState.player_max_hp)
		hp_bar.value = float(GameState.player_hp)
	if ammo_label != null:
		ammo_label.text = "Ammo: %d" % _res("ammo")
	if carry_label != null:
		carry_label.text = "Carry rank: %d" % GameState.player_carry_rank
	if phase_label != null:
		phase_label.text = "Phase: %s" % _phase_name(GameState.phase_state)

func _res(name: String) -> int:
	if GameState.resources.has(name):
		return int(GameState.resources[name])
	return 0

func _phase_name(phase: int) -> String:
	match phase:
		GameState.PhaseState.QUIET:
			return "QUIET"
		GameState.PhaseState.INVESTIGATE:
			return "INVESTIGATE"
		GameState.PhaseState.PRESSURE:
			return "PRESSURE"
		GameState.PhaseState.HUNTED:
			return "HUNTED"
		_:
			return "UNKNOWN"
