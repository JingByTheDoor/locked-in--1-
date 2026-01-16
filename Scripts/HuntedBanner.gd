extends CanvasLayer

@export var hunted_text: String = "HUNTED"

@onready var label: Label = $Label

func _ready() -> void:
	_update_state()

func _process(_delta: float) -> void:
	_update_state()

func _update_state() -> void:
	if label == null:
		return
	label.text = hunted_text
	label.visible = GameState.phase_state == GameState.PhaseState.HUNTED
