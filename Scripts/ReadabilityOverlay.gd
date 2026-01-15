extends CanvasLayer

@export var vignette_intensity: float = 0.25
@export var vignette_softness: float = 0.45
@export var distortion_intensity: float = 0.0
@export var distortion_speed: float = 1.0

@onready var vignette_rect: ColorRect = $Vignette
@onready var distortion_rect: ColorRect = $Distortion

func _ready() -> void:
	_apply()

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	if vignette_rect != null:
		var vig_mat := vignette_rect.material as ShaderMaterial
		if vig_mat != null:
			vig_mat.set_shader_parameter("intensity", vignette_intensity)
			vig_mat.set_shader_parameter("softness", vignette_softness)
	if distortion_rect != null:
		var dist_mat := distortion_rect.material as ShaderMaterial
		if dist_mat != null:
			dist_mat.set_shader_parameter("distortion_intensity", distortion_intensity)
			dist_mat.set_shader_parameter("distortion_speed", distortion_speed)
