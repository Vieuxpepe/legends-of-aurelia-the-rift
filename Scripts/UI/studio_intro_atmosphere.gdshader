shader_type canvas_item;

/// Deep cold vignette + subtle drifting grain (Rift-style intro overlay).
uniform float inner_radius = 0.32;
uniform float outer_radius = 0.96;
uniform float vignette_strength = 0.98;
uniform vec3 deep_tint : source_color = vec3(0.01, 0.03, 0.065);
uniform float grain_amount : hint_range(0.0, 0.12) = 0.042;
uniform float flicker_speed = 1.8;

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float dist = distance(uv, vec2(0.5));
	float vig = smoothstep(inner_radius, outer_radius, dist) * vignette_strength;

	float t = TIME * flicker_speed;
	float g1 = _hash(uv * 900.0 + vec2(t * 0.11, -t * 0.07));
	float g2 = _hash(uv * 420.0 - vec2(t * 0.08, t * 0.13));
	float grain = mix(g1, g2, 0.5);
	float flicker = 1.0 - grain_amount + grain * grain_amount * 2.0;

	vec3 col = deep_tint * (0.35 + 0.65 * vig) * flicker;
	float alpha = clamp(vig * 0.93 + 0.10, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
