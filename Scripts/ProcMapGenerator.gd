extends Node2D
class_name ProcMapGenerator

@export var generate_on_ready: bool = true
@export var randomize_seed: bool = true
@export var seed: int = 0

@export var floor_layer_path: NodePath = NodePath("../Floor")
@export var wall_layer_path: NodePath = NodePath("../Walls")
@export var map_width: int = 40
@export var map_height: int = 28
@export var center_map: bool = true
@export var origin_cell: Vector2i = Vector2i.ZERO

@export var room_attempts: int = 12
@export var room_min_size: Vector2i = Vector2i(4, 4)
@export var room_max_size: Vector2i = Vector2i(9, 9)
@export var corridor_width: int = 3

@export var floor_source_id: int = 0
@export var floor_atlas_coords: Vector2i = Vector2i(0, 0)
@export var wall_source_id: int = 0
@export var wall_atlas_coords: Vector2i = Vector2i(0, 0)
@export var use_floor_terrain: bool = false
@export var floor_terrain_set: int = 0
@export var floor_terrain: int = 0
@export var use_wall_terrain: bool = true
@export var wall_terrain_set: int = 0
@export var wall_terrain: int = 0

@export var spawn_root_path: NodePath = NodePath("../PlayerSpawns")
@export var spawn_count: int = 4
@export var spawn_min_floor_neighbors: int = 4
@export var player_path: NodePath = NodePath("../Player")
@export var place_player_on_spawn: bool = true
@export var door_enabled: bool = true
@export var door_scene: PackedScene = preload("res://Scenes/ProcDoor.tscn")
@export var door_hallway_clear_length: int = 2
@export var enemy_spawn_min_floor_neighbors: int = 3
@export var total_enemy_count: int = 15
@export_range(0.0, 1.0, 0.01) var watcher_chance: float = 0.2
@export var guard_scene: PackedScene = preload("res://Scenes/Guard.tscn")
@export var guard_count: int = 3
@export var watcher_scene: PackedScene = preload("res://Scenes/Watcher.tscn")
@export var watcher_count: int = 0
@export var patrol_points_per_enemy: int = 4
@export var patrol_radius_min: int = 3
@export var patrol_radius_max: int = 6
@export var remove_existing_enemies: bool = true

@export var exit_scene: PackedScene = preload("res://Scenes/ExtractionZone.tscn")
@export var hiding_scene: PackedScene = preload("res://Scenes/HidingSpot.tscn")
@export var exit_count: int = 2
@export var hiding_count: int = 2
@export var unfair_count: int = 1

@export var map_pathing_path: NodePath = NodePath("../MapPathing")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if generate_on_ready:
		call_deferred("generate")

func generate() -> void:
	var floor_layer := get_node_or_null(floor_layer_path)
	var wall_layer := get_node_or_null(wall_layer_path)
	if floor_layer == null or wall_layer == null:
		push_warning("ProcMapGenerator: missing Floor/Walls TileMapLayer nodes.")
		return
	if randomize_seed or seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed

	var width: int = maxi(map_width, 6)
	var height: int = maxi(map_height, 6)
	var grid := _init_grid(width, height)
	var rooms := _carve_rooms(grid, width, height)
	_connect_rooms(grid, rooms)
	_ensure_connected(grid, width, height)
	var doors := _build_doors(grid, rooms, width, height)

	var components: Array = _collect_floor_components(grid, width, height)
	var main_component: Array[Vector2i] = _select_main_component(components)

	var floor_cells: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if grid[y][x]:
				floor_cells.append(Vector2i(x, y))
	if main_component.is_empty():
		main_component = floor_cells

	var origin := _get_origin_cell(width, height)
	_clear_tilemap(floor_layer)
	_clear_tilemap(wall_layer)
	_paint_tiles(floor_layer, wall_layer, floor_cells, width, height, origin)

	_spawn_markers(floor_layer, main_component, width, height, origin)
	_spawn_enemies(floor_layer, main_component, width, height, origin)
	_spawn_doors(floor_layer, doors, origin)
	_place_player_spawn(floor_layer, main_component, origin)
	_update_pathing_bounds(floor_layer, width, height, origin)

func _init_grid(width: int, height: int) -> Array:
	var grid: Array = []
	for y in range(height):
		var row: Array = []
		row.resize(width)
		for x in range(width):
			row[x] = false
		grid.append(row)
	return grid

func _carve_rooms(grid: Array, width: int, height: int) -> Array[Rect2i]:
	var rooms: Array[Rect2i] = []
	var attempts: int = maxi(room_attempts, 1)
	var min_size := Vector2i(max(room_min_size.x, 3), max(room_min_size.y, 3))
	var max_size := Vector2i(max(room_max_size.x, min_size.x), max(room_max_size.y, min_size.y))
	for _i in range(attempts):
		var w := _rng.randi_range(min_size.x, max_size.x)
		var h := _rng.randi_range(min_size.y, max_size.y)
		var x := _rng.randi_range(1, width - w - 1)
		var y := _rng.randi_range(1, height - h - 1)
		var room := Rect2i(Vector2i(x, y), Vector2i(w, h))
		if _room_overlaps(room, rooms):
			continue
		rooms.append(room)
		_carve_rect(grid, room)
	if rooms.is_empty():
		var center := Vector2i(width / 2, height / 2)
		grid[center.y][center.x] = true
	return rooms

func _room_overlaps(room: Rect2i, rooms: Array[Rect2i]) -> bool:
	for other in rooms:
		var expanded := other.grow(1)
		if expanded.intersects(room):
			return true
	return false

func _carve_rect(grid: Array, room: Rect2i) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			grid[y][x] = true

func _connect_rooms(grid: Array, rooms: Array[Rect2i]) -> void:
	if rooms.size() < 2:
		return
	var last_center := _room_center(rooms[0])
	for i in range(1, rooms.size()):
		var center := _room_center(rooms[i])
		if _rng.randi_range(0, 1) == 0:
			_carve_corridor(grid, last_center, Vector2i(center.x, last_center.y))
			_carve_corridor(grid, Vector2i(center.x, last_center.y), center)
		else:
			_carve_corridor(grid, last_center, Vector2i(last_center.x, center.y))
			_carve_corridor(grid, Vector2i(last_center.x, center.y), center)
		last_center = center

func _room_center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2

func _carve_corridor(grid: Array, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var x_dir := 1 if to_cell.x >= from_cell.x else -1
	var y_dir := 1 if to_cell.y >= from_cell.y else -1
	for x in range(from_cell.x, to_cell.x + x_dir, x_dir):
		_carve_cell_with_width(grid, Vector2i(x, from_cell.y))
	for y in range(from_cell.y, to_cell.y + y_dir, y_dir):
		_carve_cell_with_width(grid, Vector2i(to_cell.x, y))

func _carve_cell_with_width(grid: Array, cell: Vector2i) -> void:
	var half: int = int(maxi(corridor_width, 1) / 2.0)
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var x := cell.x + dx
			var y := cell.y + dy
			if y >= 0 and y < grid.size() and x >= 0 and x < grid[0].size():
				grid[y][x] = true

func _clear_tilemap(layer: Node) -> void:
	if layer == null:
		return
	if layer.has_method("clear"):
		layer.call("clear")

func _paint_tiles(floor_layer: Node, wall_layer: Node, floor_cells: Array[Vector2i], width: int, height: int, origin: Vector2i) -> void:
	var floor_set: Dictionary = {
		"source_id": floor_source_id,
		"atlas": floor_atlas_coords
	}
	var wall_set: Dictionary = {
		"source_id": wall_source_id,
		"atlas": wall_atlas_coords
	}
	var floor_lookup: Dictionary = {}
	for cell in floor_cells:
		floor_lookup[cell] = true

	var floor_cells_world: Array[Vector2i] = []
	for cell in floor_cells:
		floor_cells_world.append(cell + origin)
	var wall_cells_world: Array[Vector2i] = _collect_wall_cells(
		floor_layer,
		wall_layer,
		floor_cells,
		floor_lookup,
		width,
		height,
		origin
	)

	var used_floor_terrain := use_floor_terrain and _set_terrain_cells(floor_layer, floor_cells_world, floor_terrain_set, floor_terrain)
	if not used_floor_terrain:
		for cell in floor_cells_world:
			_set_tile(floor_layer, cell, floor_set)

	var used_wall_terrain := use_wall_terrain and _set_terrain_cells(wall_layer, wall_cells_world, wall_terrain_set, wall_terrain)
	if not used_wall_terrain:
		for cell in wall_cells_world:
			_set_tile(wall_layer, cell, wall_set)

func _set_tile(layer: Node, cell: Vector2i, data: Dictionary) -> void:
	if layer == null:
		return
	if layer.has_method("set_cell"):
		layer.call("set_cell", cell, data["source_id"], data["atlas"])

func _set_wall_tile(floor_layer: Node, wall_layer: Node, floor_cell: Vector2i, data: Dictionary) -> void:
	if wall_layer == null or floor_layer == null:
		return
	if not wall_layer.has_method("set_cell"):
		return
	var wall_cell := _floor_cell_to_wall_cell(floor_layer, wall_layer, floor_cell)
	wall_layer.call("set_cell", wall_cell, data["source_id"], data["atlas"])

func _floor_cell_to_wall_cell(floor_layer: Node, wall_layer: Node, floor_cell: Vector2i) -> Vector2i:
	if not floor_layer.has_method("map_to_local") or not wall_layer.has_method("local_to_map"):
		return floor_cell
	var floor_local: Vector2 = floor_layer.call("map_to_local", floor_cell)
	var floor_global: Vector2 = floor_layer.to_global(floor_local)
	var wall_local: Vector2 = wall_layer.to_local(floor_global)
	return wall_layer.call("local_to_map", wall_local)

func _collect_wall_cells(
	floor_layer: Node,
	wall_layer: Node,
	floor_cells: Array[Vector2i],
	floor_lookup: Dictionary,
	width: int,
	height: int,
	origin: Vector2i
) -> Array[Vector2i]:
	var wall_cells_world: Array[Vector2i] = []
	var wall_cell_lookup: Dictionary = {}
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	var floor_tile_size: Vector2 = _get_tile_size(floor_layer)
	var wall_tile_size: Vector2 = _get_tile_size(wall_layer)
	var pad: int = 1
	var min_floor_cell_world: Vector2i = origin - Vector2i(pad, pad)
	var max_floor_cell_world: Vector2i = origin + Vector2i(width - 1 + pad, height - 1 + pad)
	var world_min: Vector2 = _floor_cell_to_global(floor_layer, min_floor_cell_world)
	var world_max: Vector2 = _floor_cell_to_global(floor_layer, max_floor_cell_world) + floor_tile_size
	var wall_min_cell: Vector2i = _world_to_wall_cell(wall_layer, world_min)
	var wall_max_cell: Vector2i = _world_to_wall_cell(wall_layer, world_max)
	var start_x: int = mini(wall_min_cell.x, wall_max_cell.x)
	var end_x: int = maxi(wall_min_cell.x, wall_max_cell.x)
	var start_y: int = mini(wall_min_cell.y, wall_max_cell.y)
	var end_y: int = maxi(wall_min_cell.y, wall_max_cell.y)

	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			var wall_cell := Vector2i(x, y)
			var world_pos: Vector2 = _wall_cell_to_world_center(wall_layer, wall_cell, wall_tile_size)
			var floor_cell_world: Vector2i = _world_to_floor_cell(floor_layer, world_pos)
			var floor_cell: Vector2i = floor_cell_world - origin
			if floor_lookup.has(floor_cell):
				continue
			var adjacent := false
			for offset in offsets:
				var neighbor: Vector2i = floor_cell + offset
				if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
					continue
				if floor_lookup.has(neighbor):
					adjacent = true
					break
			if not adjacent:
				continue
			if wall_cell_lookup.has(wall_cell):
				continue
			wall_cell_lookup[wall_cell] = true
			wall_cells_world.append(wall_cell)
	return wall_cells_world

func _get_tile_size(layer: Node) -> Vector2:
	if layer is TileMapLayer:
		var tile_set := (layer as TileMapLayer).tile_set
		if tile_set != null:
			return Vector2(tile_set.tile_size)
	return Vector2.ONE

func _floor_cell_to_global(floor_layer: Node, cell: Vector2i) -> Vector2:
	if floor_layer is TileMapLayer:
		var layer := floor_layer as TileMapLayer
		return layer.to_global(layer.map_to_local(cell))
	return Vector2(cell.x, cell.y)

func _world_to_floor_cell(floor_layer: Node, world_pos: Vector2) -> Vector2i:
	if floor_layer is TileMapLayer:
		var layer := floor_layer as TileMapLayer
		return layer.local_to_map(layer.to_local(world_pos))
	return Vector2i.ZERO

func _world_to_wall_cell(wall_layer: Node, world_pos: Vector2) -> Vector2i:
	if wall_layer is TileMapLayer:
		var layer := wall_layer as TileMapLayer
		return layer.local_to_map(layer.to_local(world_pos))
	return Vector2i.ZERO

func _wall_cell_to_world_center(wall_layer: Node, cell: Vector2i, tile_size: Vector2) -> Vector2:
	if wall_layer is TileMapLayer:
		var layer := wall_layer as TileMapLayer
		var local := layer.map_to_local(cell) + tile_size * 0.5
		return layer.to_global(local)
	return Vector2(cell.x, cell.y)

func _set_terrain_cells(layer: Node, cells: Array[Vector2i], terrain_set: int, terrain: int) -> bool:
	if layer == null or cells.is_empty():
		return false
	if not layer.has_method("set_cells_terrain_connect"):
		return false
	layer.callv("set_cells_terrain_connect", [cells, terrain_set, terrain, false])
	return true

func _build_terrain_connect_args(layer: Node, cells: Array[Vector2i], terrain_set: int, terrain: int) -> Array:
	if layer == null:
		return []
	var methods: Array = layer.get_method_list()
	for method in methods:
		if not (method is Dictionary):
			continue
		if method.get("name", "") != "set_cells_terrain_connect":
			continue
		var arg_defs: Array = method.get("args", [])
		if arg_defs.is_empty():
			break
		var args: Array = []
		for arg_def in arg_defs:
			var arg_name := ""
			if arg_def is Dictionary:
				arg_name = str(arg_def.get("name", ""))
			match arg_name:
				"cells":
					args.append(cells)
				"terrain_set":
					args.append(terrain_set)
				"terrain":
					args.append(terrain)
				"ignore_empty":
					args.append(false)
				_:
					return []
		return args
	return [cells, terrain_set, terrain]

func _spawn_markers(floor_layer: Node, floor_cells: Array[Vector2i], width: int, height: int, origin: Vector2i) -> void:
	if floor_layer == null or floor_cells.is_empty():
		return
	var generated := _get_or_create_generated_root()
	_clear_children(generated)

	var spawn_root := _get_or_create_spawn_root()
	_clear_children(spawn_root)

	var spawn_candidates := _filter_spawn_cells(floor_cells, width, height, spawn_min_floor_neighbors)
	var shuffled := spawn_candidates.duplicate()
	shuffled.shuffle()
	var spawn_total: int = maxi(spawn_count, 1)
	for i in range(mini(spawn_total, shuffled.size())):
		var pos := _cell_to_world_center(floor_layer, shuffled[i] + origin)
		var spawn := Node2D.new()
		spawn.position = pos
		spawn.name = "Spawn_%d" % i
		spawn_root.add_child(spawn)

	_place_scene_instances(generated, floor_layer, floor_cells, origin, exit_scene, exit_count, "exit", "Exit")
	_place_scene_instances(generated, floor_layer, floor_cells, origin, hiding_scene, hiding_count, "hiding_spot", "Hiding")
	_place_unfair_nodes(generated, floor_layer, floor_cells, origin, unfair_count)

func _place_player_spawn(floor_layer: Node, floor_cells: Array[Vector2i], origin: Vector2i) -> void:
	if not place_player_on_spawn:
		return
	var player := _get_player_node()
	if player == null:
		return
	var spawn_root := get_node_or_null(spawn_root_path)
	if spawn_root != null:
		var spawns: Array[Node2D] = []
		for child in spawn_root.get_children():
			if child is Node2D:
				spawns.append(child as Node2D)
		if not spawns.is_empty():
			var idx: int = _rng.randi_range(0, spawns.size() - 1)
			player.global_position = spawns[idx].global_position
			return
	if floor_cells.is_empty():
		return
	var fallback_idx: int = _rng.randi_range(0, floor_cells.size() - 1)
	player.global_position = _cell_to_world_center(floor_layer, floor_cells[fallback_idx] + origin)

func _spawn_enemies(floor_layer: Node, floor_cells: Array[Vector2i], width: int, height: int, origin: Vector2i) -> void:
	if floor_layer == null or floor_cells.is_empty():
		return
	if remove_existing_enemies:
		_clear_existing_enemies()
	var enemies_root := _get_or_create_enemies_root()
	_clear_children(enemies_root)
	var spawn_cells := _filter_spawn_cells(floor_cells, width, height, enemy_spawn_min_floor_neighbors)
	if spawn_cells.is_empty():
		spawn_cells = floor_cells
	spawn_cells.shuffle()
	var used: Dictionary = {}
	for cell in _collect_player_spawn_cells(floor_layer, origin):
		used[cell] = true
	var total: int = maxi(total_enemy_count, 0)
	if total == 0:
		_spawn_enemy_group(guard_scene, guard_count, "Guard", spawn_cells, used, floor_layer, floor_cells, origin, enemies_root)
		_spawn_enemy_group(watcher_scene, watcher_count, "Watcher", spawn_cells, used, floor_layer, floor_cells, origin, enemies_root)
		return
	_spawn_enemy_mix(total, spawn_cells, used, floor_layer, floor_cells, origin, enemies_root)

func _spawn_enemy_mix(
	total: int,
	spawn_cells: Array[Vector2i],
	used: Dictionary,
	floor_layer: Node,
	floor_cells: Array[Vector2i],
	origin: Vector2i,
	enemies_root: Node
) -> void:
	if total <= 0:
		return
	var available: Array[Vector2i] = []
	for cell in spawn_cells:
		if used.has(cell):
			continue
		available.append(cell)
	if available.is_empty():
		available = spawn_cells
	var spawn_total: int = mini(total, available.size())
	for i in range(spawn_total):
		var cell := available[i]
		used[cell] = true
		var spawn_watcher: bool = watcher_scene != null and watcher_chance > 0.0 and _rng.randf() <= watcher_chance
		var scene: PackedScene = watcher_scene if spawn_watcher else guard_scene
		var prefix := "Watcher" if spawn_watcher else "Guard"
		if scene == null:
			scene = guard_scene if guard_scene != null else watcher_scene
			prefix = "Guard" if scene == guard_scene else "Watcher"
		if scene == null:
			return
		var container := Node2D.new()
		container.name = "%s_%d" % [prefix, i]
		enemies_root.add_child(container)
		_build_patrol_path(container, floor_layer, floor_cells, cell, origin)
		var enemy := scene.instantiate()
		if enemy is Node2D:
			(enemy as Node2D).global_position = _cell_to_world_center(floor_layer, cell + origin)
		container.add_child(enemy)

func _spawn_enemy_group(
	scene: PackedScene,
	count: int,
	name_prefix: String,
	spawn_cells: Array[Vector2i],
	used: Dictionary,
	floor_layer: Node,
	floor_cells: Array[Vector2i],
	origin: Vector2i,
	enemies_root: Node
) -> void:
	if scene == null:
		return
	var total: int = maxi(count, 0)
	if total == 0:
		return
	var available: Array[Vector2i] = []
	for cell in spawn_cells:
		if used.has(cell):
			continue
		available.append(cell)
	if available.is_empty():
		available = spawn_cells
	var spawn_total: int = mini(total, available.size())
	for i in range(spawn_total):
		var cell := available[i]
		used[cell] = true
		var container := Node2D.new()
		container.name = "%s_%d" % [name_prefix, i]
		enemies_root.add_child(container)
		_build_patrol_path(container, floor_layer, floor_cells, cell, origin)
		var enemy := scene.instantiate()
		if enemy is Node2D:
			(enemy as Node2D).global_position = _cell_to_world_center(floor_layer, cell + origin)
		container.add_child(enemy)

func _build_patrol_path(
	container: Node2D,
	floor_layer: Node,
	floor_cells: Array[Vector2i],
	center_cell: Vector2i,
	origin: Vector2i
) -> void:
	if container == null:
		return
	var path := Node2D.new()
	path.name = "PatrolPath"
	container.add_child(path)
	var points: Array[Vector2i] = _pick_patrol_cells(floor_cells, center_cell)
	for i in range(points.size()):
		var point := Node2D.new()
		point.name = "Point_%d" % i
		point.global_position = _cell_to_world_center(floor_layer, points[i] + origin)
		path.add_child(point)

func _pick_patrol_cells(floor_cells: Array[Vector2i], center_cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	if floor_cells.is_empty():
		return points
	var min_radius: int = maxi(patrol_radius_min, 0)
	var max_radius: int = maxi(patrol_radius_max, min_radius)
	var candidates: Array[Vector2i] = []
	for cell in floor_cells:
		var dist: int = abs(cell.x - center_cell.x) + abs(cell.y - center_cell.y)
		if dist < min_radius or dist > max_radius:
			continue
		candidates.append(cell)
	candidates.shuffle()
	var total: int = maxi(patrol_points_per_enemy, 1)
	for i in range(mini(total, candidates.size())):
		points.append(candidates[i])
	while points.size() < total:
		points.append(center_cell)
	return points

func _collect_player_spawn_cells(floor_layer: Node, origin: Vector2i) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var spawn_root := get_node_or_null(spawn_root_path)
	if spawn_root == null:
		return results
	var children: Array = spawn_root.get_children()
	for child in children:
		if child is Node2D:
			var world_cell: Vector2i = _world_to_floor_cell(floor_layer, (child as Node2D).global_position)
			results.append(world_cell - origin)
	return results

func _clear_existing_enemies() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy is Node:
			(enemy as Node).queue_free()

func _get_or_create_enemies_root() -> Node2D:
	var node := get_node_or_null("Enemies")
	if node is Node2D:
		return node as Node2D
	var root := Node2D.new()
	root.name = "Enemies"
	get_parent().add_child(root)
	return root

func _get_player_node() -> Node2D:
	var node: Node = null
	if player_path != NodePath():
		node = get_node_or_null(player_path)
	if node == null:
		node = get_tree().get_first_node_in_group("player")
	if node == null:
		node = get_tree().get_root().find_child("Player", true, false)
	if node is Node2D:
		return node as Node2D
	return null

func _place_scene_instances(parent: Node, floor_layer: Node, cells: Array[Vector2i], origin: Vector2i, scene: PackedScene, count: int, group: String, name_prefix: String) -> void:
	if scene == null or parent == null:
		return
	var total: int = maxi(count, 0)
	var used := 0
	for cell in cells:
		if used >= total:
			break
		var instance := scene.instantiate()
		if instance is Node2D:
			(instance as Node2D).position = _cell_to_world_center(floor_layer, cell + origin)
		instance.name = "%s_%d" % [name_prefix, used]
		instance.add_to_group(group)
		parent.add_child(instance)
		used += 1

func _place_unfair_nodes(parent: Node, floor_layer: Node, cells: Array[Vector2i], origin: Vector2i, count: int) -> void:
	var total: int = maxi(count, 0)
	var used := 0
	for cell in cells:
		if used >= total:
			break
		var node := Node2D.new()
		node.position = _cell_to_world_center(floor_layer, cell + origin)
		node.name = "Unfair_%d" % used
		node.add_to_group("unfair_room")
		parent.add_child(node)
		used += 1

func _build_doors(grid: Array, rooms: Array[Rect2i], width: int, height: int) -> Array:
	var doors: Array = []
	if not door_enabled or door_scene == null:
		return doors
	if corridor_width < 2:
		return doors
	if rooms.is_empty():
		return doors
	var room_lookup := _build_room_lookup(rooms)
	var door_keys: Dictionary = {}
	var clear_len: int = maxi(door_hallway_clear_length, 1)
	for room in rooms:
		_collect_room_side_doors(grid, room_lookup, width, height, room, Vector2i(0, -1), true, clear_len, doors, door_keys)
		_collect_room_side_doors(grid, room_lookup, width, height, room, Vector2i(0, 1), true, clear_len, doors, door_keys)
		_collect_room_side_doors(grid, room_lookup, width, height, room, Vector2i(-1, 0), false, clear_len, doors, door_keys)
		_collect_room_side_doors(grid, room_lookup, width, height, room, Vector2i(1, 0), false, clear_len, doors, door_keys)
	return doors

func _collect_room_side_doors(
	grid: Array,
	room_lookup: Dictionary,
	width: int,
	height: int,
	room: Rect2i,
	dir_out: Vector2i,
	horizontal: bool,
	clear_len: int,
	doors: Array,
	door_keys: Dictionary
) -> void:
	if dir_out == Vector2i(0, -1) or dir_out == Vector2i(0, 1):
		var y := room.position.y + (room.size.y if dir_out.y > 0 else -1)
		if y < 0 or y >= height:
			return
		var segment: Array[Vector2i] = []
		for x in range(room.position.x, room.position.x + room.size.x):
			var cell := Vector2i(x, y)
			if _is_door_candidate(grid, room_lookup, width, height, cell, dir_out, clear_len):
				segment.append(cell)
			else:
				_finalize_door_segment(grid, segment, horizontal, doors, door_keys)
				segment.clear()
		_finalize_door_segment(grid, segment, horizontal, doors, door_keys)
	else:
		var x := room.position.x + (room.size.x if dir_out.x > 0 else -1)
		if x < 0 or x >= width:
			return
		var segment: Array[Vector2i] = []
		for y in range(room.position.y, room.position.y + room.size.y):
			var cell := Vector2i(x, y)
			if _is_door_candidate(grid, room_lookup, width, height, cell, dir_out, clear_len):
				segment.append(cell)
			else:
				_finalize_door_segment(grid, segment, horizontal, doors, door_keys)
				segment.clear()
		_finalize_door_segment(grid, segment, horizontal, doors, door_keys)

func _is_door_candidate(
	grid: Array,
	room_lookup: Dictionary,
	width: int,
	height: int,
	cell: Vector2i,
	dir_out: Vector2i,
	clear_len: int
) -> bool:
	if not _is_corridor_cell(grid, room_lookup, width, height, cell):
		return false
	var inside := cell - dir_out
	if not room_lookup.has(inside):
		return false
	for i in range(1, clear_len + 1):
		var check := cell + dir_out * i
		if not _is_corridor_cell(grid, room_lookup, width, height, check):
			return false
	return true

func _finalize_door_segment(
	grid: Array,
	segment: Array[Vector2i],
	horizontal: bool,
	doors: Array,
	door_keys: Dictionary
) -> void:
	if segment.is_empty():
		return
	if segment.size() < 2:
		return
	var max_len: int = mini(maxi(corridor_width, 2), 3)
	if segment.size() > max_len:
		return
	var door := _build_door_from_segment(grid, segment, horizontal)
	if door.is_empty():
		return
	var key := _door_key(door["cells"], horizontal)
	if door_keys.has(key):
		return
	door_keys[key] = true
	doors.append(door)

func _build_door_from_segment(grid: Array, segment: Array[Vector2i], horizontal: bool) -> Dictionary:
	if segment.size() < 2:
		return {}
	var door_cells: Array[Vector2i] = []
	if segment.size() == 2:
		door_cells = segment.duplicate()
	else:
		var remove_first: bool = _rng.randf() < 0.5
		if remove_first:
			door_cells = [segment[1], segment[2]]
			_remove_floor_cell(grid, segment[0])
		else:
			door_cells = [segment[0], segment[1]]
			_remove_floor_cell(grid, segment[2])
	return {
		"cells": door_cells,
		"horizontal": horizontal
	}

func _remove_floor_cell(grid: Array, cell: Vector2i) -> void:
	if cell.y < 0 or cell.y >= grid.size():
		return
	if cell.x < 0 or cell.x >= grid[cell.y].size():
		return
	grid[cell.y][cell.x] = false

func _door_key(cells: Array[Vector2i], horizontal: bool) -> String:
	if cells.size() < 2:
		return ""
	var a: Vector2i = cells[0]
	var b: Vector2i = cells[1]
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var tmp := a
		a = b
		b = tmp
	return "%d,%d;%d,%d;%s" % [a.x, a.y, b.x, b.y, "h" if horizontal else "v"]

func _is_corridor_cell(
	grid: Array,
	room_lookup: Dictionary,
	width: int,
	height: int,
	cell: Vector2i
) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	if not grid[cell.y][cell.x]:
		return false
	if room_lookup.has(cell):
		return false
	return true

func _build_room_lookup(rooms: Array[Rect2i]) -> Dictionary:
	var lookup: Dictionary = {}
	for room in rooms:
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in range(room.position.x, room.position.x + room.size.x):
				lookup[Vector2i(x, y)] = true
	return lookup

func _spawn_doors(floor_layer: Node, doors: Array, origin: Vector2i) -> void:
	if not door_enabled or door_scene == null:
		return
	if floor_layer == null:
		return
	if doors.is_empty():
		return
	var doors_root := _get_or_create_doors_root()
	_clear_children(doors_root)
	var tile_size := _get_tile_size(floor_layer)
	for i in range(doors.size()):
		var info: Dictionary = doors[i]
		if not info.has("cells"):
			continue
		var cells: Array = info["cells"]
		if cells.size() < 2:
			continue
		var door := door_scene.instantiate()
		if door == null:
			continue
		doors_root.add_child(door)
		if door is Node2D:
			var world_a := _cell_to_world_center(floor_layer, (cells[0] as Vector2i) + origin)
			var world_b := _cell_to_world_center(floor_layer, (cells[1] as Vector2i) + origin)
			(door as Node2D).global_position = (world_a + world_b) * 0.5
		if door.has_method("configure"):
			door.call("configure", tile_size, bool(info.get("horizontal", true)))
		door.name = "Door_%d" % i

func _get_or_create_doors_root() -> Node2D:
	var node := get_node_or_null("Doors")
	if node is Node2D:
		return node as Node2D
	var root := Node2D.new()
	root.name = "Doors"
	get_parent().add_child(root)
	return root

func _cell_to_world(floor_layer: Node, cell: Vector2i) -> Vector2:
	if floor_layer.has_method("map_to_local"):
		return floor_layer.call("map_to_local", cell)
	return Vector2(cell.x, cell.y)

func _cell_to_world_center(floor_layer: Node, cell: Vector2i) -> Vector2:
	if floor_layer is TileMapLayer:
		var layer := floor_layer as TileMapLayer
		var tile_size := Vector2.ONE
		var tile_set := layer.tile_set
		if tile_set != null:
			tile_size = Vector2(tile_set.tile_size)
		var local := layer.map_to_local(cell) + tile_size * 0.5
		return layer.to_global(local)
	if floor_layer is Node2D:
		return (floor_layer as Node2D).to_global(Vector2(cell.x, cell.y))
	return Vector2(cell.x, cell.y)

func _filter_spawn_cells(
	floor_cells: Array[Vector2i],
	width: int,
	height: int,
	min_neighbors: int
) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	if floor_cells.is_empty():
		return results
	var lookup: Dictionary = {}
	for cell in floor_cells:
		lookup[cell] = true
	var neighbor_min: int = clampi(min_neighbors, 0, 4)
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	for cell in floor_cells:
		var count: int = 0
		for offset in offsets:
			var neighbor := cell + offset
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if lookup.has(neighbor):
				count += 1
		if count >= neighbor_min:
			results.append(cell)
	if results.is_empty():
		return floor_cells
	return results

func _collect_floor_components(grid: Array, width: int, height: int) -> Array:
	var components: Array = []
	var visited: Dictionary = {}
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	for y in range(height):
		for x in range(width):
			if not grid[y][x]:
				continue
			var start := Vector2i(x, y)
			if visited.has(start):
				continue
			var component: Array[Vector2i] = []
			var queue: Array[Vector2i] = [start]
			visited[start] = true
			while not queue.is_empty():
				var current: Vector2i = queue.pop_back()
				component.append(current)
				for offset in offsets:
					var nx: int = current.x + offset.x
					var ny: int = current.y + offset.y
					if nx < 0 or nx >= width or ny < 0 or ny >= height:
						continue
					if not grid[ny][nx]:
						continue
					var neighbor := Vector2i(nx, ny)
					if visited.has(neighbor):
						continue
					visited[neighbor] = true
					queue.append(neighbor)
			components.append(component)
	return components

func _select_main_component(components: Array) -> Array[Vector2i]:
	if components.is_empty():
		return []
	var best_index: int = 0
	for i in range(1, components.size()):
		if components[i].size() > components[best_index].size():
			best_index = i
	return components[best_index]

func _ensure_connected(grid: Array, width: int, height: int) -> void:
	var components: Array = _collect_floor_components(grid, width, height)
	if components.size() <= 1:
		return
	var main: Array[Vector2i] = _select_main_component(components)
	for component in components:
		if component == main:
			continue
		var pair: Array[Vector2i] = _find_nearest_cells(component, main)
		if pair.size() == 2:
			_carve_corridor(grid, pair[0], pair[1])
			main.append_array(component)

func _find_nearest_cells(source: Array[Vector2i], target: Array[Vector2i]) -> Array[Vector2i]:
	if source.is_empty() or target.is_empty():
		return []
	var best_a: Vector2i = source[0]
	var best_b: Vector2i = target[0]
	var best_dist: int = 2147483647
	for a in source:
		for b in target:
			var dist: int = abs(a.x - b.x) + abs(a.y - b.y)
			if dist < best_dist:
				best_dist = dist
				best_a = a
				best_b = b
	return [best_a, best_b]

func _get_or_create_spawn_root() -> Node2D:
	var node := get_node_or_null(spawn_root_path)
	if node is Node2D:
		return node as Node2D
	var root := Node2D.new()
	root.name = "PlayerSpawns"
	get_parent().add_child(root)
	return root

func _get_or_create_generated_root() -> Node2D:
	var node := get_node_or_null("Generated")
	if node is Node2D:
		return node as Node2D
	var root := Node2D.new()
	root.name = "Generated"
	get_parent().add_child(root)
	return root

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()

func _get_origin_cell(width: int, height: int) -> Vector2i:
	if center_map:
		return Vector2i(-width / 2, -height / 2)
	return origin_cell

func _update_pathing_bounds(floor_layer: Node, width: int, height: int, origin: Vector2i) -> void:
	var pathing := get_node_or_null(map_pathing_path)
	if pathing == null:
		return
	var tile_size: Vector2 = Vector2(128, 128)
	if floor_layer.has_method("get"):
		var set_obj := floor_layer.get("tile_set") as TileSet
		if set_obj != null:
			tile_size = Vector2(set_obj.tile_size)
	var top_left := _cell_to_world(floor_layer, origin)
	var bounds := Rect2(top_left, Vector2(width * tile_size.x, height * tile_size.y))
	if pathing.has_method("set_bounds"):
		pathing.call("set_bounds", bounds)
	if pathing.has_method("request_rebuild"):
		pathing.call("request_rebuild")
