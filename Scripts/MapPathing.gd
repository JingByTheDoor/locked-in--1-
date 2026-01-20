extends Node2D
class_name MapPathing

@export var bounds: Rect2 = Rect2(Vector2(-640, -440), Vector2(1280, 880))
@export var cell_size: int = 32
@export var sample_radius: float = 12.0
@export var collision_mask: int = 1
@export var allow_diagonal: bool = false
@export var refresh_interval: float = 0.0
@export var max_search_radius: int = 6
@export var line_of_sight_max_hits: int = 6
@export var exclude_groups: Array[String] = ["player", "enemy", "interactable", "hiding_spot", "exit"]

var _grid: AStarGrid2D
var _grid_size: Vector2i = Vector2i.ZERO
var _needs_rebuild: bool = true
var _refresh_timer: float = 0.0

func _ready() -> void:
	add_to_group("map_pathing")
	call_deferred("_rebuild_grid")

func _process(delta: float) -> void:
	if refresh_interval <= 0.0:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = refresh_interval
		_rebuild_grid()

func request_rebuild() -> void:
	_needs_rebuild = true

func set_bounds(new_bounds: Rect2) -> void:
	bounds = new_bounds
	_needs_rebuild = true

func get_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	_ensure_grid()
	if _grid == null:
		return []
	if _grid_size.x <= 0 or _grid_size.y <= 0:
		return []
	var from_cell := _world_to_cell(from_pos)
	var to_cell := _world_to_cell(to_pos)
	if not _is_in_bounds(from_cell):
		from_cell = _clamp_cell(from_cell)
	if not _is_in_bounds(to_cell):
		to_cell = _clamp_cell(to_cell)
	if from_cell.x < 0 or to_cell.x < 0:
		return []
	if _grid.is_point_solid(from_cell):
		from_cell = _find_nearest_open(from_cell)
	if _grid.is_point_solid(to_cell):
		to_cell = _find_nearest_open(to_cell)
	if from_cell.x < 0 or to_cell.x < 0:
		return []
	var cells: Array = _grid.get_id_path(from_cell, to_cell)
	var world: Array[Vector2] = []
	for cell in cells:
		if cell is Vector2i:
			world.append(_cell_to_world(cell))
		else:
			world.append(_cell_to_world(Vector2i(cell)))
	return world

func has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	var world := get_world_2d()
	if world == null:
		return true
	var space_state := world.direct_space_state
	if space_state == null:
		return true
	var params := PhysicsRayQueryParameters2D.new()
	params.from = from_pos
	params.to = to_pos
	params.collision_mask = collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var exclude: Array = [self]
	var max_hits := maxi(line_of_sight_max_hits, 1)
	for _i in range(max_hits):
		params.exclude = exclude
		var hit: Dictionary = space_state.intersect_ray(params)
		if hit.is_empty():
			return true
		var collider: Object = hit.get("collider")
		if not _is_blocking(collider):
			if collider != null:
				exclude.append(collider)
			continue
		return false
	return true

func _ensure_grid() -> void:
	if _grid == null or _needs_rebuild:
		_rebuild_grid()

func _rebuild_grid() -> void:
	_needs_rebuild = false
	_grid_size = _compute_grid_size()
	if _grid_size.x <= 0 or _grid_size.y <= 0:
		_grid = null
		return
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, _grid_size)
	_grid.cell_size = Vector2(cell_size, cell_size)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS if allow_diagonal else AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	_mark_obstacles()

func _compute_grid_size() -> Vector2i:
	if cell_size <= 0:
		return Vector2i.ZERO
	var cols: int = int(ceil(bounds.size.x / float(cell_size)))
	var rows: int = int(ceil(bounds.size.y / float(cell_size)))
	return Vector2i(maxi(cols, 0), maxi(rows, 0))

func _mark_obstacles() -> void:
	if _grid == null:
		return
	var world := get_world_2d()
	if world == null:
		return
	var space_state := world.direct_space_state
	if space_state == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = max(sample_radius, 0.1)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var max_hits := 32
	for y in range(_grid_size.y):
		for x in range(_grid_size.x):
			var cell := Vector2i(x, y)
			params.transform = Transform2D(0.0, _cell_to_world(cell))
			var hits: Array = space_state.intersect_shape(params, max_hits)
			var blocked := false
			for hit in hits:
				var collider: Object = hit.get("collider")
				if _is_blocking(collider):
					blocked = true
					break
			_grid.set_point_solid(cell, blocked)

func _is_blocking(collider: Object) -> bool:
	if collider == null:
		return false
	if collider == self:
		return false
	var node := collider as Node
	if node == null:
		return true
	for group in exclude_groups:
		if node.is_in_group(group):
			return false
	return true

func _world_to_cell(point: Vector2) -> Vector2i:
	var local := point - bounds.position
	var x := int(floor(local.x / float(cell_size)))
	var y := int(floor(local.y / float(cell_size)))
	return Vector2i(x, y)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return bounds.position + Vector2((cell.x + 0.5) * cell_size, (cell.y + 0.5) * cell_size)

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_size.x and cell.y < _grid_size.y

func _clamp_cell(cell: Vector2i) -> Vector2i:
	if _grid_size.x <= 0 or _grid_size.y <= 0:
		return Vector2i(-1, -1)
	return Vector2i(clampi(cell.x, 0, _grid_size.x - 1), clampi(cell.y, 0, _grid_size.y - 1))

func _find_nearest_open(cell: Vector2i) -> Vector2i:
	if _grid == null:
		return Vector2i(-1, -1)
	if _is_in_bounds(cell) and not _grid.is_point_solid(cell):
		return cell
	var origin := _clamp_cell(cell)
	if origin.x < 0:
		return Vector2i(-1, -1)
	var max_radius := maxi(max_search_radius, 1)
	for r in range(1, max_radius + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if abs(x) != r and abs(y) != r:
					continue
				var candidate := origin + Vector2i(x, y)
				if not _is_in_bounds(candidate):
					continue
				if not _grid.is_point_solid(candidate):
					return candidate
	return Vector2i(-1, -1)
