extends Node2D

@export var slam_loudness: float = 1.0
@export var slam_radius: float = 420.0
@export var slam_on_interact: bool = false

func slam() -> void:
	SoundBus.emit_sound_at(global_position, slam_loudness, slam_radius, SoundEvent.SoundType.ANOMALOUS, self)

func interact(_player: Node) -> void:
	if slam_on_interact:
		slam()
