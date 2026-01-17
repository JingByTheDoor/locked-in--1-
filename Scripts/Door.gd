extends Node2D

@export var slam_loudness: float = 1.0
@export var slam_radius: float = 420.0
@export var slam_on_interact: bool = false
@export var slam_when_sprinting: bool = true
@export var open_loudness: float = 0.2
@export var open_radius: float = 140.0
@export var hunter_delay: float = 0.6
@export var prompt_open: String = "Press E to open"
@export var prompt_slam: String = "Press E to open (sprint to slam)"
@export var prompt_slam_only: String = "Press E to slam"
@export var open_stream: AudioStream = preload("res://Audio/Door Opening.wav")
@export var open_volume_db: float = -6.0
@export var slam_stream: AudioStream = preload("res://Audio/door slaming.wav")
@export var slam_volume_db: float = -2.0

func _ready() -> void:
	add_to_group("door")

func slam() -> void:
	if SoundBus == null:
		return
	SoundBus.emit_sound_at(global_position, slam_loudness, slam_radius, SoundEvent.SoundType.ANOMALOUS, self)
	AudioOneShot.play_2d(slam_stream, global_position, get_tree().current_scene, slam_volume_db)

func open_quiet() -> void:
	if SoundBus == null:
		return
	SoundBus.emit_sound_at(global_position, open_loudness, open_radius, SoundEvent.SoundType.EXPECTED, self)
	AudioOneShot.play_2d(open_stream, global_position, get_tree().current_scene, open_volume_db)

func interact(_player: Node) -> void:
	var wants_slam: bool = slam_on_interact
	if not wants_slam and slam_when_sprinting:
		wants_slam = Input.is_action_pressed("sprint")
	if wants_slam:
		slam()
	else:
		open_quiet()

func get_hunter_delay() -> float:
	return hunter_delay

func get_interact_prompt(_player: Node) -> String:
	if slam_on_interact:
		return prompt_slam_only
	if slam_when_sprinting:
		return prompt_slam
	return prompt_open
