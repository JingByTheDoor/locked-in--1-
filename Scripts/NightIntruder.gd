extends CharacterBody2D
class_name NightIntruder

signal died

@export var move_speed: float = 80.0
@export var breach_range: float = 18.0
@export var breach_cooldown: float = 1.1
@export var attack_range: float = 22.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var max_hp: int = 2
@export var knockback_decay: float = 600.0
@export var knockback_resistance: float = 1.0
@export var target_path: NodePath
@export var player_path: NodePath
@export var manager_path: NodePath

@onready var sprite: Sprite2D = $Sprite2D

var _target: Node2D = null
var _player: Node2D = null
var _manager: Node = null
var _attack_timer: float = 0.0
var _breach_timer: float = 0.0
var _current_hp: int = 2
var _knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	_current_hp = max(1, max_hp)
	_resolve_refs()

func _physics_process(delta: float) -> void:
	_attack_timer = max(0.0, _attack_timer - delta)
	_breach_timer = max(0.0, _breach_timer - delta)

	if _target == null or not is_instance_valid(_target):
		_request_target()

	var move_dir: Vector2 = Vector2.ZERO
	if _target != null and is_instance_valid(_target):
		var to_target: Vector2 = _target.global_position - global_position
		var dist: float = to_target.length()
		if dist > breach_range:
			if dist > 0.001:
				move_dir = to_target.normalized()
		else:
			_try_breach()

	if _player != null and is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() <= attack_range:
			_try_attack_player()

	velocity = move_dir * move_speed
	velocity += _knockback_velocity
	move_and_slide()
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)

func set_target(target: Node) -> void:
	if target is Node2D:
		_target = target as Node2D

func set_manager(manager: Node) -> void:
	_manager = manager

func apply_damage(amount: int, _context: String = "") -> void:
	if amount <= 0:
		return
	_current_hp -= amount
	if _current_hp <= 0:
		died.emit()
		queue_free()

func apply_knockback(direction: Vector2, strength: float) -> void:
	if strength <= 0.0:
		return
	var dir := direction
	if dir.length_squared() < 0.001:
		return
	_knockback_velocity += dir.normalized() * (strength / max(knockback_resistance, 0.1))

func _resolve_refs() -> void:
	if player_path != NodePath():
		var player_node: Node = get_node_or_null(player_path)
		if player_node is Node2D:
			_player = player_node as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if manager_path != NodePath():
		_manager = get_node_or_null(manager_path)

func _request_target() -> void:
	if _manager != null and _manager.has_method("get_breach_target"):
		var target: Node = _manager.call("get_breach_target")
		if target is Node2D:
			_target = target as Node2D

func _try_attack_player() -> void:
	if _attack_timer > 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("apply_damage"):
		_player.call("apply_damage", attack_damage, "night")
	_attack_timer = attack_cooldown

func _try_breach() -> void:
	if _breach_timer > 0.0:
		return
	_breach_timer = breach_cooldown
	if _manager != null and _manager.has_method("register_breach"):
		_manager.call("register_breach", _target, self)
	_target = null
