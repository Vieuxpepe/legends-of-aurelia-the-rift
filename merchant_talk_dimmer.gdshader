shader_type canvas_item;

uniform vec3 dim_rgb : source_color = vec3(0.03, 0.022, 0.014);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.82;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float dist = length(c) * 1.38;
	float vig = mix(1.0, 0.68, smoothstep(0.16, 0.94, dist));
	float n = fract(sin(dot(UV * 420.0, vec2(12.9898, 78.233))) * 43758.5453);
	float grain = (n - 0.5) * 0.035;
	COLOR = vec4(dim_rgb + vec3(grain), clamp(base_alpha * vig + grain * 0.5, 0.0, 1.0));
}
