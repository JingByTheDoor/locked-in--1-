extends StaticBody2D
class_name BreakableProp

@export var max_hp: int = 2
@export var break_loudness: float = 1.3
@export var break_radius: float = 820.0
@export var break_tag: String = "destruction"
@export var break_vfx_scene: PackedScene
@export var break_color: Color = Color(0.8, 0.6, 0.3, 0.9)
@export var intact_color: Color = Color(0.7, 0.6, 0.5, 1.0)
@export var broken_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var broken_texture: Texture2D
@export var break_on_interact: bool = false
@export var disable_collision_on_break: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _hp: int = 2
var _broken: bool = false

func _ready() -> void:
	add_to_group("breakable")
	if break_on_interact:
		add_to_group("interactable")
	_hp = max(1, max_hp)
	_apply_visuals()

func apply_damage(amount: int, _context: String = "") -> void:
	if amount <= 0 or _broken:
		return
	_hp -= amount
	if _hp <= 0:
		_break()

func interact(_player: Node) -> void:
	if break_on_interact:
		_break()

func _break() -> void:
	if _broken:
		return
	_broken = true
	_hp = 0
	if disable_collision_on_break and collision_shape != null:
		collision_shape.disabled = true
	_emit_break_sound()
	_spawn_break_vfx()
	_apply_visuals()

func _emit_break_sound() -> void:
	if SoundBus == null:
		return
	SoundBus.emit_sound_at(global_position, break_loudness, break_radius, SoundEvent.SoundType.ANOMALOUS, self, break_tag)

func _spawn_break_vfx() -> void:
	if break_vfx_scene == null:
		return
	var vfx: Node = break_vfx_scene.instantiate()
	if vfx == null:
		return
	add_child(vfx)
	if vfx is Node2D:
		(vfx as Node2D).global_position = global_position
	if vfx.has_method("setup"):
		vfx.call("setup", break_color, 6.0, 0.35)

func _apply_visuals() -> void:
	if sprite == null:
		return
	if _broken and broken_texture != null:
		sprite.texture = broken_texture
	sprite.modulate = broken_color if _broken else intact_color

func get_interact_prompt(_player: Node) -> String:
	if not break_on_interact:
		return ""
	if _broken:
		return "Broken"
	return "Press E to smash"
