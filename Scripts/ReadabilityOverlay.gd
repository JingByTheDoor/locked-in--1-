extends CanvasLayer

@export var vignette_intensity: float = 0.25
@export var vignette_softness: float = 0.45
@export var distortion_intensity: float = 0.0
@export var distortion_speed: float = 1.0
@export var distortion_multiplier: float = 3.0
@export var pulse_strength: float = 0.0
@export var pulse_speed: float = 1.5

@onready var vignette_rect: ColorRect = $Vignette
@onready var distortion_rect: ColorRect = $Distortion

func _ready() -> void:
	_apply()

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	var pulse: float = 0.0
	if pulse_strength > 0.0:
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		pulse = (sin(t * pulse_speed) * 0.5 + 0.5) * pulse_strength
	if vignette_rect != null:
		var vig_mat := vignette_rect.material as ShaderMaterial
		if vig_mat != null:
			var vig_value: float = clampf(vignette_intensity + pulse, 0.0, 1.0)
			vig_mat.set_shader_parameter("intensity", vig_value)
			vig_mat.set_shader_parameter("softness", vignette_softness)
	if distortion_rect != null:
		var dist_mat := distortion_rect.material as ShaderMaterial
		if dist_mat != null:
			var dist_value: float = clampf(distortion_intensity * distortion_multiplier + pulse * 0.2, 0.0, 1.0)
			dist_mat.set_shader_parameter("distortion_intensity", dist_value)
			dist_mat.set_shader_parameter("distortion_speed", distortion_speed)

func set_phase_intensity(intensity: float, phase_state: int) -> void:
	var clamped: float = clampf(intensity, 0.0, 1.0)
	var vig_base: float = lerpf(0.2, 0.6, clamped)
	var dist_base: float = lerpf(0.0, 0.35, clamped)
	var pulse_base: float = lerpf(0.0, 0.25, clamped)
	var pulse_rate: float = lerpf(0.6, 1.8, clamped)
	if phase_state == GameState.PhaseState.HUNTED:
		dist_base = max(dist_base, 0.45)
		pulse_base = max(pulse_base, 0.35)
		pulse_rate = max(pulse_rate, 2.4)
	vignette_intensity = vig_base
	distortion_intensity = dist_base
	pulse_strength = pulse_base
	pulse_speed = pulse_rate
