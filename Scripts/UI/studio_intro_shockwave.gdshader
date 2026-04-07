shader_type canvas_item;

// Screen-space shockwave ring with subtle distortion (studio burst beat).
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float radius = 0.0;
uniform float thickness = 0.06;
uniform float softness = 0.02;
uniform float strength = 0.55;
uniform float distort_strength = 0.02;
uniform vec3 tint : source_color = vec3(1.0, 0.92, 0.62);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, center_uv);
	float half_t = max(thickness * 0.5, 0.0001);
	float inner = radius - half_t;
	float outer = radius + half_t;

	// Ring mask with soft edges.
	float a_in = smoothstep(inner - softness, inner + softness, d);
	float a_out = 1.0 - smoothstep(outer - softness, outer + softness, d);
	float ring = clamp(a_in * a_out, 0.0, 1.0);

	// Distort the underlying screen slightly along the radial direction.
	vec2 dir = (uv - center_uv);
	float dir_len = max(length(dir), 0.0001);
	dir /= dir_len;
	float wave = ring * strength;
	vec2 offset = dir * wave * distort_strength;

	vec4 base_col = texture(SCREEN_TEXTURE, SCREEN_UV + offset);
	// Add a warm ring highlight on top.
	base_col.rgb += tint * (wave * 0.55);
	COLOR = base_col;
}

