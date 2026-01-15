extends CanvasLayer

@export var default_duration: float = 2.0

@onready var label: Label = $Label

var _timer: Timer

func _ready() -> void:
	label.visible = false
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

func show_message(text: String, duration: float = -1.0) -> void:
	label.text = text
	label.visible = true
	var use_duration := duration
	if use_duration < 0.0:
		use_duration = default_duration
	if use_duration > 0.0:
		_timer.start(use_duration)
	else:
		_timer.stop()

func _on_timeout() -> void:
	label.visible = false
