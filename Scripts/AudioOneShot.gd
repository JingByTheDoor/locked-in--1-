extends Node
class_name AudioOneShot

static func play_2d(stream: AudioStream, position: Vector2, parent: Node = null, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var target_parent: Node = parent
	if target_parent == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			target_parent = tree.current_scene if tree.current_scene != null else tree.root
	if target_parent == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	target_parent.add_child(player)
	player.play()
