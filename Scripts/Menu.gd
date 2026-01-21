extends Control

@export var start_scene_path: String = "res://Scenes/Base.tscn"

@onready var new_button: Button = $CenterContainer/VBoxContainer/NewRunButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var sound_toggle: CheckButton = $CenterContainer/VBoxContainer/SoundToggle
@onready var music_toggle: CheckButton = $CenterContainer/VBoxContainer/MusicToggle
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	if new_button != null:
		new_button.pressed.connect(_on_new_run_pressed)
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)
	if sound_toggle != null:
		sound_toggle.button_pressed = GameState.sound_enabled
		sound_toggle.toggled.connect(_on_sound_toggled)
	if music_toggle != null:
		music_toggle.button_pressed = GameState.music_enabled
		music_toggle.toggled.connect(_on_music_toggled)
	_update_toggle_labels()
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_new_run_pressed() -> void:
	GameState.reset_run()
	_go_to_start_scene()

func _on_continue_pressed() -> void:
	if GameState.load_run():
		_go_to_start_scene()

func _on_sound_toggled(pressed: bool) -> void:
	GameState.set_sound_enabled(pressed)
	_update_toggle_labels()

func _on_music_toggled(pressed: bool) -> void:
	GameState.set_music_enabled(pressed)
	_update_toggle_labels()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _go_to_start_scene() -> void:
	if start_scene_path == "":
		return
	get_tree().change_scene_to_file(start_scene_path)

func _update_toggle_labels() -> void:
	if sound_toggle != null:
		sound_toggle.text = "Sound: On" if GameState.sound_enabled else "Sound: Off"
	if music_toggle != null:
		music_toggle.text = "Music: On" if GameState.music_enabled else "Music: Off"
