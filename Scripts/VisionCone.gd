extends Node2D

@export var cone_angle_degrees: float = 120.0
@export var cone_length: float = 0.1
@export var auto_length_from_viewport: bool = true
@export var extra_length: float = 0.0
@export var require_line_of_sight: bool = true
@export var occlusion_mask: int = 1
@export var show_cone: bool = true
@export var cone_fill_color: Color = Color(0.25, 0.9, 1.0, 0.15)
@export var cone_outline_color: Color = Color(0.25, 0.9, 1.0, 0.35)
@export var cone_outline_width: float = 1.0
@export var cone_segments: int = 28

var _runtime_length: float = -1.0

func _process(_delta: float) -> void:
	_runtime_length = _compute_runtime_length()
	if show_cone:
		queue_redraw()

func _draw() -> void:
	if not show_cone:
		return
	var length: float = _get_length()
	if length <= 0.0:
		return
	var half_angle: float = deg_to_rad(cone_angle_degrees * 0.5)
	var segments: int = max(cone_segments, 6)
	var start_angle: float = -half_angle
	var end_angle: float = half_angle
	var points := PackedVector2Array()
	points.push_back(Vector2.ZERO)
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.push_back(Vector2.RIGHT.rotated(angle) * length)
	var colors := PackedColorArray()
	colors.resize(points.size())
	for i in range(colors.size()):
		colors[i] = cone_fill_color
	draw_polygon(points, colors)
	draw_arc(Vector2.ZERO, length, start_angle, end_angle, segments, cone_outline_color, cone_outline_width, true)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(start_angle) * length, cone_outline_color, cone_outline_width, true)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(end_angle) * length, cone_outline_color, cone_outline_width, true)

func can_see_point(point: Vector2) -> bool:
	var to_target: Vector2 = point - global_position
	var dist: float = to_target.length()
	var length := _get_length()
	if dist > length:
		return false
	if dist < 0.001:
		return true
	var forward: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	var angle: float = abs(forward.angle_to(to_target))
	if angle > deg_to_rad(cone_angle_degrees * 0.5):
		return false
	if not require_line_of_sight:
		return true
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	params.from = global_position
	params.to = point
	params.collision_mask = occlusion_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.exclude = [self, get_parent()]
	var hit: Dictionary = space_state.intersect_ray(params)
	return hit.is_empty()

func can_see_node(node: Node2D) -> bool:
	if node == null:
		return false
	var point: Vector2 = node.global_position
	var to_target: Vector2 = point - global_position
	var dist: float = to_target.length()
	var length: float = _get_length()
	if dist > length:
		return false
	if dist < 0.001:
		return true
	var forward: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	var angle: float = abs(forward.angle_to(to_target))
	if angle > deg_to_rad(cone_angle_degrees * 0.5):
		return false
	if not require_line_of_sight:
		return true
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	params.from = global_position
	params.to = point
	params.collision_mask = occlusion_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.exclude = _build_exclude_list(node)
	var hit: Dictionary = space_state.intersect_ray(params)
	return hit.is_empty()

func get_cone_angle_degrees() -> float:
	return cone_angle_degrees

func get_cone_length() -> float:
	return _get_length()

func _get_length() -> float:
	if _runtime_length < 0.0:
		_runtime_length = _compute_runtime_length()
	return _runtime_length

func _compute_runtime_length() -> float:
	if not auto_length_from_viewport:
		return cone_length
	var viewport := get_viewport()
	if viewport == null:
		return cone_length
	var size := viewport.get_visible_rect().size
	return max(cone_length, size.length() + extra_length)

func _build_exclude_list(target: Node) -> Array:
	var exclude: Array = []
	exclude.append(self)
	var parent: Node = get_parent()
	if parent != null:
		exclude.append(parent)
	if target != null:
		_append_collision_objects(exclude, target)
	return exclude

func _append_collision_objects(exclude: Array, node: Node) -> void:
	if node is CollisionObject2D:
		exclude.append(node)
	var children: Array = node.get_children()
	for child in children:
		if child is Node:
			_append_collision_objects(exclude, child)
