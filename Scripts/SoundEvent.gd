extends Resource
class_name SoundEvent

enum SoundType {
	EXPECTED,
	ANOMALOUS
}

@export var sound_type: SoundType = SoundType.EXPECTED
@export var loudness: float = 1.0
@export var radius: float = 200.0
@export var position: Vector2 = Vector2.ZERO
@export var source_path: NodePath
@export var timestamp_msec: int = 0

func is_anomalous() -> bool:
	return sound_type == SoundType.ANOMALOUS
