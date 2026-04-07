shader_type canvas_item;

// Legends of Aurelia game beat: subtle rift / parallax / shimmer / warm top breathing (TIME-driven).
uniform float rift_amount : hint_range(0.0, 0.05) = 0.008;
uniform float parallax_uv : hint_range(0.0, 0.01) = 0.002;
uniform float shimmer : hint_range(0.0, 1.0) = 0.45;
uniform float breath : hint_range(0.0, 0.2) = 0.07;

varying vec4 v_vertex_modulate;

void vertex() {
	v_vertex_modulate = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float y = uv.y;

	// Counter-motion: top vs bottom (fake depth).
	float top_w = 1.0 - smoothstep(0.44, 0.56, y);
	float bot_w = smoothstep(0.44, 0.56, y);
	float pr = sin(TIME * 0.85) * parallax_uv;
	uv.x += pr * (top_w - bot_w * 0.82);

	// Rift band: lower third-ish (subtitle / purple band on composite logo).
	float band = smoothstep(0.54, 0.70, y) * (1.0 - smoothstep(0.96, 1.0, y));
	float wob = sin(TIME * 2.25 + y * 28.0) * 0.65 + sin(TIME * 1.1 + y * 12.0) * 0.35;
	uv.x += wob * rift_amount * band;

	vec2 ch = vec2(rift_amount * 0.72 * band, 0.0);
	vec4 col = texture(TEXTURE, uv);
	col.r = texture(TEXTURE, uv + ch).r;
	col.b = texture(TEXTURE, uv - ch).b;

	// Purple shimmer sweep in lower region.
	float sw = smoothstep(0.50, 0.96, y);
	float sx = fract(uv.x * 2.8 - TIME * 0.28 + y * 1.7);
	float gl = smoothstep(0.38, 0.50, sx) * (1.0 - smoothstep(0.50, 0.62, sx));
	col.rgb += vec3(0.42, 0.22, 0.92) * gl * sw * shimmer * 0.22;

	// Warm "relic" breathing on upper title plate.
	float tw = 1.0 - smoothstep(0.0, 0.56, y);
	float br = 1.0 + sin(TIME * 1.75) * breath;
	vec3 warm = col.rgb * vec3(1.06, 1.02, 0.94) * br;
	col.rgb = mix(col.rgb, warm, tw * 0.42);

	// Preserve modulate / self_modulate / vertex tint (default fragment COLOR = texture × this).
	COLOR = col * v_vertex_modulate;
}
