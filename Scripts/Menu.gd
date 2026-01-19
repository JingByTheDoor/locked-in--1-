extends Control

@export var start_scene_path: String = "res://Scenes/Base.tscn"

@onready var new_button: Button = $CenterContainer/VBoxContainer/NewRunButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	if new_button != null:
		new_button.pressed.connect(_on_new_run_pressed)
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_new_run_pressed() -> void:
	GameState.reset_run()
	_go_to_start_scene()

func _on_continue_pressed() -> void:
	if GameState.load_run():
		_go_to_start_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _go_to_start_scene() -> void:
	if start_scene_path == "":
		return
	get_tree().change_scene_to_file(start_scene_path)
