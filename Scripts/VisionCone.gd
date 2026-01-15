extends Node2D

@export var cone_angle_degrees: float = 90.0
@export var cone_length: float = 520.0
@export var auto_length_from_viewport: bool = true
@export var extra_length: float = 300.0
@export var require_line_of_sight: bool = true
@export var occlusion_mask: int = 1

var _runtime_length: float = -1.0

func _process(_delta: float) -> void:
	_runtime_length = _compute_runtime_length()

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
	return can_see_point(node.global_position)

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
