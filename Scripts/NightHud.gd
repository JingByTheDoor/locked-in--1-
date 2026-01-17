extends CanvasLayer

@onready var label: Label = $Label

func set_time_left(seconds: float) -> void:
	if label == null:
		return
	var remaining: int = max(int(ceil(seconds)), 0)
	var minutes: int = remaining / 60
	var secs: int = remaining % 60
	label.text = "Night %d  %02d:%02d" % [GameState.night_index, minutes, secs]
