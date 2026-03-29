shader_type canvas_item;

/// Uses the dragon texture’s alpha only so tint stays warm gold (no multiply with blue/green body pixels).
uniform vec4 fill_color : source_color = vec4(1.0, 0.82, 0.16, 0.72);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = smoothstep(0.04, 0.96, tex.a);
	COLOR = vec4(fill_color.rgb, fill_color.a * a);
}
