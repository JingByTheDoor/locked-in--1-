extends CanvasLayer

@export var target_path: NodePath
@export var cone_angle_degrees: float = 90.0
@export var cone_angle_softness_degrees: float = 10.0
@export var cone_length: float = 320.0
@export var cone_softness: float = 48.0
@export var base_darkness: float = 0.85
@export var inner_radius: float = 120.0
@export var inner_softness: float = 24.0
@export var use_occlusion: bool = true
@export var occlusion_rays: int = 160
@export var occlusion_mask: int = 1
@export var occlusion_margin: float = 4.0
@export var occlusion_update_interval: float = 0.0
@export var occlusion_exclude_groups: Array[String] = ["interactable", "breakable", "hiding_spot", "exit"]
@export var occlusion_override_include_groups: Array[String] = ["repairable", "door"]
@export var occlusion_max_hits: int = 6

@onready var rect: ColorRect = $ColorRect
@onready var occlusion_viewport: SubViewport = $OcclusionViewport
@onready var occlusion_polygon: Polygon2D = $OcclusionViewport/OcclusionRoot/OcclusionPolygon

var target: Node2D
var _occlusion_timer: float = 0.0
var _last_viewport_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D
	_apply_occlusion_texture()
	_apply_params()

func _process(_delta: float) -> void:
	if target == null or rect == null:
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		return
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	_ensure_viewport_size(viewport_size)
	var screen_pos: Vector2 = viewport.get_canvas_transform() * target.global_position
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(target.global_rotation).normalized()
	mat.set_shader_parameter("player_screen_pos", screen_pos)
	mat.set_shader_parameter("aim_dir", aim_dir)
	mat.set_shader_parameter("viewport_size", viewport_size)
	_apply_params(mat)
	_update_occlusion(_delta)

func _apply_params(mat: ShaderMaterial = null) -> void:
	var use_mat := mat
	if use_mat == null and rect != null:
		use_mat = rect.material as ShaderMaterial
	if use_mat == null:
		return
	var angle_deg := cone_angle_degrees
	var length := cone_length
	if target != null:
		if target.has_method("get_cone_angle_degrees"):
			angle_deg = float(target.call("get_cone_angle_degrees"))
		if target.has_method("get_cone_length"):
			length = float(target.call("get_cone_length"))
	use_mat.set_shader_parameter("cone_angle", deg_to_rad(angle_deg))
	use_mat.set_shader_parameter("cone_angle_softness", deg_to_rad(cone_angle_softness_degrees))
	use_mat.set_shader_parameter("cone_length", length)
	use_mat.set_shader_parameter("cone_softness", cone_softness)
	use_mat.set_shader_parameter("base_darkness", base_darkness)
	use_mat.set_shader_parameter("inner_radius", inner_radius)
	use_mat.set_shader_parameter("inner_softness", inner_softness)
	use_mat.set_shader_parameter("occlusion_strength", 1.0 if use_occlusion else 0.0)

func _ensure_viewport_size(size: Vector2) -> void:
	if occlusion_viewport == null:
		return
	if size == _last_viewport_size:
		return
	_last_viewport_size = size
	occlusion_viewport.size = Vector2i(int(size.x), int(size.y))

func _apply_occlusion_texture() -> void:
	if rect == null:
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		return
	if occlusion_viewport == null:
		mat.set_shader_parameter("occlusion_strength", 0.0)
		return
	mat.set_shader_parameter("occlusion_tex", occlusion_viewport.get_texture())

func _update_occlusion(delta: float) -> void:
	if not use_occlusion:
		return
	if target == null or occlusion_polygon == null:
		return
	if occlusion_update_interval > 0.0:
		_occlusion_timer -= delta
		if _occlusion_timer > 0.0:
			return
		_occlusion_timer = occlusion_update_interval
	_update_occlusion_polygon()

func _update_occlusion_polygon() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var forward: Vector2 = Vector2.RIGHT.rotated(target.global_rotation).normalized()
	var origin: Vector2 = target.global_position
	var cone_angle: float = deg_to_rad(_get_cone_angle())
	var cone_half: float = cone_angle * 0.5
	var cone_len: float = _get_cone_length()
	var circle_len: float = maxf(inner_radius, 0.0)
	var rays: int = maxi(occlusion_rays, 32)
	var points := PackedVector2Array()
	var canvas_xform: Transform2D = viewport.get_canvas_transform()
	for i in range(rays):
		var t: float = float(i) / float(rays)
		var angle: float = -PI + t * TAU
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var angle_diff: float = abs(forward.angle_to(dir))
		var max_len: float = circle_len
		if angle_diff <= cone_half:
			max_len = cone_len
		var hit_pos := _raycast_to(origin, dir, max_len)
		points.append(canvas_xform * hit_pos)
	occlusion_polygon.polygon = points

func _raycast_to(origin: Vector2, dir: Vector2, max_len: float) -> Vector2:
	var to: Vector2 = origin + dir * max_len
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return to
	var world: World2D = viewport.get_world_2d()
	if world == null:
		return to
	var space_state: PhysicsDirectSpaceState2D = world.direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	params.from = origin
	params.to = to
	params.collision_mask = _get_occlusion_mask()
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var exclude := _build_exclude_list()
	var iterations: int = maxi(occlusion_max_hits, 1)
	for _i in range(iterations):
		params.exclude = exclude
		var hit: Dictionary = space_state.intersect_ray(params)
		if hit.is_empty():
			return to
		var collider_obj: Object = hit.get("collider") as Object
		if _should_ignore_collider(collider_obj):
			if collider_obj != null:
				exclude.append(collider_obj)
			continue
		var hit_pos: Vector2 = hit.get("position", to)
		if occlusion_margin <= 0.0:
			return hit_pos
		var dist: float = maxf(0.0, origin.distance_to(hit_pos) - occlusion_margin)
		return origin + dir * dist
	return to

func _get_cone_angle() -> float:
	if target != null and target.has_method("get_cone_angle_degrees"):
		return float(target.call("get_cone_angle_degrees"))
	return cone_angle_degrees

func _get_cone_length() -> float:
	if target != null and target.has_method("get_cone_length"):
		return float(target.call("get_cone_length"))
	return cone_length

func _get_occlusion_mask() -> int:
	if target != null and target.has_method("get"):
		var value: Variant = target.get("occlusion_mask")
		if typeof(value) == TYPE_INT:
			return int(value)
	return occlusion_mask

func _build_exclude_list() -> Array:
	var exclude: Array = []
	exclude.append(self)
	if target != null:
		exclude.append(target)
	var parent: Node = target.get_parent() if target != null else null
	if parent != null:
		exclude.append(parent)
	return exclude

func _should_ignore_collider(collider: Object) -> bool:
	if collider == null:
		return false
	var node := collider as Node
	if node == null:
		return false
	for group in occlusion_override_include_groups:
		if node.is_in_group(group):
			return false
	for group in occlusion_exclude_groups:
		if node.is_in_group(group):
			return true
	return false
