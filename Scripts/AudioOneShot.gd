extends Node
class_name AudioOneShot

static func play_2d(stream: AudioStream, position: Vector2, parent: Node = null, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var safe_stream := _disable_loop(stream)
	var target_parent: Node = parent
	if target_parent == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			target_parent = tree.current_scene if tree.current_scene != null else tree.root
	if target_parent == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = safe_stream
	player.global_position = position
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	target_parent.add_child(player)
	player.play()

static func _disable_loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream.duplicate() as AudioStreamWAV
		if wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
		return wav if wav != null else stream
	return stream
