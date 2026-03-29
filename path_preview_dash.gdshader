shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.78, 0.92, 1.0, 1.0);
uniform float dash_repeat : hint_range(4.0, 24.0) = 12.0;
uniform float dash_duty : hint_range(0.35, 0.75) = 0.58;
uniform float scroll_speed : hint_range(0.0, 3.0) = 1.15;

void fragment() {
	float u = UV.x;
	float pat = fract(u * dash_repeat - TIME * scroll_speed);
	float stroke = step(1.0 - dash_duty, pat);
	COLOR = vec4(line_color.rgb, line_color.a * stroke);
}
