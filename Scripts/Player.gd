extends CharacterBody2D

signal died(context: String)
signal damaged(amount: int, context: String)

@export var move_speed: float = 180.0
@export var sprint_multiplier: float = 1.5
@export var interact_radius: float = 48.0
@export var idle_animation_name: StringName = &"idle"
@export var walk_animation_name: StringName = &"walk"
@export var aim_rotation_offset_degrees: float = 0.0
@export var attack_arc_degrees: float = 160.0
@export var attack_range: float = 80.0
@export var attack_windup: float = 0.05
@export var attack_active_time: float = 0.12
@export var attack_cooldown: float = 0.25
@export var attack_damage: int = 1
@export var attack_knockback: float = 120.0
@export var emit_air_swing_sound: bool = true
@export var air_swing_radius: float = 140.0
@export var air_swing_loudness: float = 0.2
@export var hit_loudness_enemy: float = 0.9
@export var hit_radius_enemy: float = 260.0
@export var hit_loudness_wall: float = 1.1
@export var hit_radius_wall: float = 420.0
@export var hit_vfx_scene: PackedScene
@export var enemy_hit_color: Color = Color(0.9, 0.1, 0.1, 0.9)
@export var wall_hit_color: Color = Color(1.0, 0.9, 0.6, 0.9)
@export var walk_sound_interval: float = 0.55
@export var sprint_sound_interval: float = 0.35
@export var walk_sound_radius: float = 220.0
@export var sprint_sound_radius: float = 360.0
@export var walk_sound_loudness: float = 0.35
@export var sprint_sound_loudness: float = 0.8
@export var gun_enabled: bool = true
@export var gun_damage: int = 999
@export var gun_range: float = 900.0
@export var gun_fire_cooldown: float = 0.45
@export var gun_knockback: float = 220.0
@export var gun_shot_loudness: float = 2.6
@export var gun_shot_radius: float = 1600.0
@export var gun_empty_message: String = "No ammo."
@export var gun_collision_mask: int = 1
@export var gun_muzzle_offset: float = 18.0
@export var gun_muzzle_flash_scene: PackedScene
@export var carry_rank_min: int = 1
@export var carry_rank_max: int = 5
@export var carry_speed_step: float = 0.1
@export var carry_noise_step: float = 0.15

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var interact_shape: CollisionShape2D = $InteractArea/CollisionShape2D
@onready var vision_cone: Node2D = get_node_or_null("VisionCone")
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var is_dead: bool = false
var _aim_angle: float = 0.0
var _sound_timer: float = 0.0

enum AttackState {
	IDLE,
	WINDUP,
	ACTIVE
}

var _attack_state: AttackState = AttackState.IDLE
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _attack_hit_ids: Dictionary = {}
var _attack_hit_enemy: bool = false
var _attack_hit_wall: bool = false
var _carry_rank: int = 1
var _is_hiding: bool = false
var _repair_locked: bool = false
var _gun_cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_sync_hp()
	_sync_carry_rank()
	_apply_interact_radius()
	_setup_attack_area()
	_update_animation(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	_gun_cooldown_timer = max(0.0, _gun_cooldown_timer - delta)
	if _repair_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		_update_aim()
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := move_speed * _get_carry_speed_multiplier()
	var is_sprinting := Input.is_action_pressed("sprint")
	if is_sprinting:
		speed *= sprint_multiplier
	velocity = input_vector * speed
	move_and_slide()
	_update_animation(input_vector)
	_update_aim()
	_update_attack(delta)
	_update_movement_sound(delta, input_vector, is_sprinting)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if _repair_locked:
		return
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("attack"):
		_start_attack()
	elif event.is_action_pressed("gun_fire"):
		_try_fire_gun()

func _update_aim() -> void:
	if visuals == null:
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 0.001:
		return
	_aim_angle = to_mouse.angle()
	visuals.rotation = _aim_angle + deg_to_rad(aim_rotation_offset_degrees)
	if vision_cone != null:
		vision_cone.rotation = _aim_angle

func _update_animation(input_vector: Vector2) -> void:
	if sprite == null:
		return
	var frames := sprite.sprite_frames
	if frames == null:
		return
	var anim_name := idle_animation_name
	if input_vector.length() > 0.1:
		anim_name = walk_animation_name
	if frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
	elif not sprite.is_playing():
		sprite.play()

func _setup_attack_area() -> void:
	if attack_area == null:
		return
	attack_area.monitoring = false
	attack_area.monitorable = false
	if attack_shape != null and attack_shape.shape is CircleShape2D:
		var circle := attack_shape.shape as CircleShape2D
		circle.radius = attack_range

func _update_attack(delta: float) -> void:
	_attack_cooldown_timer = max(0.0, _attack_cooldown_timer - delta)
	if _attack_state == AttackState.IDLE:
		return
	_attack_timer -= delta
	if _attack_state == AttackState.WINDUP:
		if _attack_timer <= 0.0:
			_begin_attack_active()
	elif _attack_state == AttackState.ACTIVE:
		_apply_attack_hits()
		if _attack_timer <= 0.0:
			_end_attack()

func _start_attack() -> void:
	if _attack_state != AttackState.IDLE:
		return
	if _attack_cooldown_timer > 0.0:
		return
	_attack_state = AttackState.WINDUP
	_attack_timer = max(attack_windup, 0.0)
	_attack_hit_ids.clear()
	_attack_hit_enemy = false
	_attack_hit_wall = false

func _begin_attack_active() -> void:
	_attack_state = AttackState.ACTIVE
	_attack_timer = max(attack_active_time, 0.01)
	_set_attack_monitoring(true)

func _end_attack() -> void:
	_set_attack_monitoring(false)
	if emit_air_swing_sound and not _attack_hit_enemy and not _attack_hit_wall:
		_emit_sound(SoundEvent.SoundType.EXPECTED, air_swing_loudness, air_swing_radius)
	_attack_state = AttackState.IDLE
	_attack_cooldown_timer = max(attack_cooldown, 0.0)

func _set_attack_monitoring(enabled: bool) -> void:
	if attack_area == null:
		return
	attack_area.set_deferred("monitoring", enabled)

func _apply_attack_hits() -> void:
	if attack_area == null:
		return
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(_aim_angle)
	var half_arc: float = deg_to_rad(attack_arc_degrees * 0.5)
	var bodies: Array = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body is Node:
			_try_hit_target(body as Node, aim_dir, half_arc)
	var areas: Array = attack_area.get_overlapping_areas()
	for area in areas:
		if area is Node:
			_try_hit_target(area as Node, aim_dir, half_arc)

func _try_hit_target(target: Node, aim_dir: Vector2, half_arc: float) -> void:
	if target == self or is_ancestor_of(target) or target.is_in_group("player"):
		return
	var node2d: Node2D = target as Node2D
	if node2d == null:
		return
	var id: int = target.get_instance_id()
	if _attack_hit_ids.has(id):
		return
	var to_target: Vector2 = node2d.global_position - global_position
	var dist: float = to_target.length()
	if dist > attack_range:
		return
	if dist > 0.001:
		var angle: float = abs(aim_dir.angle_to(to_target))
		if angle > half_arc:
			return
	_attack_hit_ids[id] = true
	if target.has_method("apply_damage"):
		target.call("apply_damage", attack_damage, "bat")
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", to_target.normalized(), attack_knockback)
		if not _attack_hit_enemy:
			_emit_sound(SoundEvent.SoundType.ANOMALOUS, hit_loudness_enemy, hit_radius_enemy)
		_attack_hit_enemy = true
		_spawn_hit_vfx(node2d.global_position, true)
	else:
		if target is PhysicsBody2D or target is Area2D or target is TileMap:
			if not _attack_hit_wall and not _attack_hit_enemy:
				_emit_sound(SoundEvent.SoundType.ANOMALOUS, hit_loudness_wall, hit_radius_wall)
			_attack_hit_wall = true
			_spawn_hit_vfx(node2d.global_position, false)

func _emit_sound(sound_type: int, loudness: float, radius: float) -> void:
	if SoundBus == null:
		return
	SoundBus.emit_sound_at(global_position, loudness, radius, sound_type, self)

func _emit_gun_sound() -> void:
	if SoundBus == null:
		return
	SoundBus.emit_sound_at(global_position, gun_shot_loudness, gun_shot_radius, SoundEvent.SoundType.ANOMALOUS, self, "gun")

func _spawn_hit_vfx(position: Vector2, is_enemy: bool) -> void:
	if hit_vfx_scene == null:
		return
	var vfx := hit_vfx_scene.instantiate()
	if vfx == null:
		return
	add_child(vfx)
	if vfx is Node2D:
		(vfx as Node2D).global_position = position
	if vfx.has_method("setup"):
		var color: Color = enemy_hit_color if is_enemy else wall_hit_color
		vfx.call("setup", color)

func _update_movement_sound(delta: float, input_vector: Vector2, is_sprinting: bool) -> void:
	if input_vector.length() < 0.1:
		_sound_timer = 0.0
		return
	var interval := walk_sound_interval
	var radius := walk_sound_radius
	var loudness := walk_sound_loudness
	var sound_type := SoundEvent.SoundType.EXPECTED
	if is_sprinting:
		interval = sprint_sound_interval
		radius = sprint_sound_radius
		loudness = sprint_sound_loudness
		sound_type = SoundEvent.SoundType.ANOMALOUS
	_sound_timer -= delta
	if _sound_timer > 0.0:
		return
	_sound_timer = max(interval, 0.05)
	SoundBus.emit_sound_at(global_position, loudness, radius, sound_type, self)

func apply_damage(amount: int, context: String = "") -> void:
	if is_dead:
		return
	GameState.player_hp = clampi(GameState.player_hp - amount, 0, GameState.player_max_hp)
	damaged.emit(amount, context)
	if GameState.player_hp <= 0:
		_handle_death(context)

func heal(amount: int) -> void:
	if is_dead:
		return
	GameState.player_hp = clampi(GameState.player_hp + amount, 0, GameState.player_max_hp)

func add_carry_rank(amount: int) -> void:
	if amount == 0:
		return
	set_carry_rank(_carry_rank + amount)

func set_carry_rank(value: int) -> void:
	_carry_rank = clampi(value, carry_rank_min, carry_rank_max)
	GameState.player_carry_rank = _carry_rank

func get_carry_rank() -> int:
	return _carry_rank

func get_interaction_noise_multiplier() -> float:
	var rank_offset: int = max(_carry_rank - carry_rank_min, 0)
	return 1.0 + float(rank_offset) * carry_noise_step

func toggle_hiding() -> void:
	set_hiding(not _is_hiding)

func set_hiding(value: bool) -> void:
	_is_hiding = value
	if _is_hiding:
		if not is_in_group("hiding"):
			add_to_group("hiding")
	else:
		if is_in_group("hiding"):
			remove_from_group("hiding")

func is_hiding() -> bool:
	return _is_hiding

func set_repair_lock(locked: bool) -> void:
	_repair_locked = locked

func _handle_death(context: String) -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(context)

func _sync_hp() -> void:
	if GameState.player_max_hp <= 0:
		GameState.player_max_hp = 100
	GameState.player_hp = clampi(GameState.player_hp, 0, GameState.player_max_hp)

func _sync_carry_rank() -> void:
	_carry_rank = clampi(GameState.player_carry_rank, carry_rank_min, carry_rank_max)
	GameState.player_carry_rank = _carry_rank

func _apply_interact_radius() -> void:
	if interact_shape == null:
		return
	if interact_shape.shape is CircleShape2D:
		var circle := interact_shape.shape as CircleShape2D
		circle.radius = interact_radius

func _try_interact() -> void:
	if interact_area == null:
		return
	var target := _find_best_interactable()
	if target == null:
		return
	if target.has_method("interact"):
		target.call("interact", self)
		return
	var parent := target.get_parent()
	if parent != null and parent.has_method("interact"):
		parent.call("interact", self)

func _try_fire_gun() -> void:
	if not gun_enabled:
		return
	if _gun_cooldown_timer > 0.0:
		return
	var ammo: int = 0
	if GameState.resources.has("ammo"):
		ammo = int(GameState.resources["ammo"])
	if ammo <= 0:
		_show_message(gun_empty_message)
		return
	GameState.add_resource("ammo", -1)
	_gun_cooldown_timer = max(gun_fire_cooldown, 0.05)
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(_aim_angle)
	var muzzle_pos: Vector2 = global_position + aim_dir * gun_muzzle_offset
	_spawn_muzzle_flash(muzzle_pos, _aim_angle)
	_emit_gun_sound()
	_fire_gun_ray(muzzle_pos, aim_dir)

func _fire_gun_ray(from: Vector2, direction: Vector2) -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	params.from = from
	params.to = from + direction.normalized() * gun_range
	params.collision_mask = gun_collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.exclude = _build_gun_exclude_list()
	var hit: Dictionary = space_state.intersect_ray(params)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	var hit_pos: Vector2 = hit.get("position", from)
	var is_enemy: bool = false
	if collider is Node:
		var node := collider as Node
		if node.has_method("apply_damage"):
			node.call("apply_damage", gun_damage, "gun")
			is_enemy = true
		if node.has_method("apply_knockback"):
			node.call("apply_knockback", direction, gun_knockback)
	_spawn_hit_vfx(hit_pos, is_enemy)

func _spawn_muzzle_flash(position: Vector2, rotation_angle: float) -> void:
	if gun_muzzle_flash_scene == null:
		return
	var flash: Node = gun_muzzle_flash_scene.instantiate()
	if flash == null:
		return
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(flash)
	else:
		add_child(flash)
	if flash is Node2D:
		var node2d := flash as Node2D
		node2d.global_position = position
		node2d.global_rotation = rotation_angle

func _build_gun_exclude_list() -> Array:
	var exclude: Array = []
	_append_collision_objects(exclude, self)
	return exclude

func _append_collision_objects(exclude: Array, node: Node) -> void:
	if node is CollisionObject2D:
		exclude.append(node)
	var children: Array = node.get_children()
	for child in children:
		if child is Node:
			_append_collision_objects(exclude, child)

func _find_best_interactable() -> Node:
	var nearest: Node = null
	var nearest_dist := INF
	for area in interact_area.get_overlapping_areas():
		if not area.is_in_group("interactable") and not area.has_method("interact"):
			continue
		var dist := global_position.distance_to(area.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = area
	for body in interact_area.get_overlapping_bodies():
		if not body.is_in_group("interactable") and not body.has_method("interact"):
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body
	return nearest

func _get_carry_speed_multiplier() -> float:
	var rank_offset: int = max(_carry_rank - carry_rank_min, 0)
	var mult: float = 1.0 - float(rank_offset) * carry_speed_step
	return clampf(mult, 0.3, 1.0)

func _show_message(text: String) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group("message_hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.2)
