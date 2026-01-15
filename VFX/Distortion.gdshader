shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float distortion_intensity = 0.0;
uniform float distortion_speed = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * distortion_speed;
	float wave = sin((uv.y + t) * 18.0) * 0.003;
	vec2 offset = vec2(wave, 0.0) * distortion_intensity;
	vec4 col = texture(screen_texture, uv + offset);
	COLOR = col;
}
