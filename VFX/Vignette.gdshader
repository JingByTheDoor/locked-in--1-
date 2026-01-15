shader_type canvas_item;
render_mode unshaded;

uniform float intensity = 0.25;
uniform float softness = 0.45;

void fragment() {
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	float dist = length(uv);
	float vig = smoothstep(softness, 1.0, dist);
	float alpha = clamp(intensity * vig, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
