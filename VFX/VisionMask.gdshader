shader_type canvas_item;
render_mode unshaded;

uniform vec2 player_screen_pos = vec2(0.0);
uniform vec2 aim_dir = vec2(1.0, 0.0);
uniform float cone_angle = 1.0472;
uniform float cone_angle_softness = 0.1745;
uniform float cone_length = 320.0;
uniform float cone_softness = 48.0;
uniform float base_darkness = 0.85;
uniform float inner_radius = 200.0;
uniform float inner_softness = 24.0;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform sampler2D occlusion_tex;
uniform float occlusion_strength = 0.0;

void fragment() {
	vec2 pixel_pos = SCREEN_UV * viewport_size;
	vec2 to_pixel = pixel_pos - player_screen_pos;
	float dist = length(to_pixel);
	float visibility = 0.0;
	if (dist < 1.0) {
		visibility = 1.0;
	} else {
		vec2 dir = to_pixel / dist;
		vec2 aim = normalize(aim_dir);
		float angle = acos(clamp(dot(aim, dir), -1.0, 1.0));
		float angle_factor = 1.0 - smoothstep(cone_angle * 0.5, cone_angle * 0.5 + cone_angle_softness, angle);
		float edge = max(1.0, cone_softness);
		float dist_factor = 1.0 - smoothstep(cone_length - edge, cone_length, dist);
		visibility = angle_factor * dist_factor;
	}
	float inner_edge = max(1.0, inner_softness);
	float inner_visibility = 1.0 - smoothstep(max(0.0, inner_radius - inner_edge), inner_radius, dist);
	visibility = max(visibility, inner_visibility);
	if (occlusion_strength > 0.0) {
		float occlusion = texture(occlusion_tex, SCREEN_UV).r;
		visibility *= mix(1.0, occlusion, clamp(occlusion_strength, 0.0, 1.0));
	}
	float darkness = base_darkness * (1.0 - clamp(visibility, 0.0, 1.0));
	COLOR = vec4(0.0, 0.0, 0.0, clamp(darkness, 0.0, 1.0));
}
