extends Node

signal sound_emitted(event: SoundEvent)

func emit_sound(event: SoundEvent) -> void:
	if event == null:
		return
	if event.timestamp_msec <= 0:
		event.timestamp_msec = Time.get_ticks_msec()
	sound_emitted.emit(event)

func emit_sound_at(position: Vector2, loudness: float, radius: float, sound_type: int, source: Node = null, tag: String = "") -> SoundEvent:
	var event: SoundEvent = SoundEvent.new()
	event.position = position
	event.loudness = loudness
	event.radius = radius
	event.sound_type = sound_type
	if source != null:
		event.source_path = source.get_path()
	if tag != "":
		event.tag = tag
	emit_sound(event)
	return event
