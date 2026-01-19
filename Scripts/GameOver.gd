extends Control

@export var retry_scene_path: String = "res://Scenes/Night.tscn"
@export var menu_scene_path: String = "res://Scenes/Menu.tscn"

@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/MenuButton

func _ready() -> void:
	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button != null:
		menu_button.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	if retry_scene_path == "":
		return
	get_tree().change_scene_to_file(retry_scene_path)

func _on_menu_pressed() -> void:
	if menu_scene_path == "":
		return
	get_tree().change_scene_to_file(menu_scene_path)
