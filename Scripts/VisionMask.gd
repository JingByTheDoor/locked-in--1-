extends CanvasLayer

@export var target_path: NodePath
@export var cone_angle_degrees: float = 90.0
@export var cone_angle_softness_degrees: float = 10.0
@export var cone_length: float = 320.0
@export var cone_softness: float = 48.0
@export var base_darkness: float = 0.85
@export var inner_radius: float = 200.0
@export var inner_softness: float = 24.0

@onready var rect: ColorRect = $ColorRect

var target: Node2D

func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D
	_apply_params()

func _process(_delta: float) -> void:
	if target == null or rect == null:
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		return
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var screen_pos: Vector2 = viewport.get_canvas_transform() * target.global_position
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(target.global_rotation).normalized()
	mat.set_shader_parameter("player_screen_pos", screen_pos)
	mat.set_shader_parameter("aim_dir", aim_dir)
	mat.set_shader_parameter("viewport_size", viewport_size)
	_apply_params(mat)

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
