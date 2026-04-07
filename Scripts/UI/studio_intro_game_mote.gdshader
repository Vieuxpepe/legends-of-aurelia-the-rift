shader_type canvas_item;

/// Rift-style motes: soft blob + UV wobble + scrolling tangential “streams” (sucked toward logo read).
uniform float distort : hint_range(0.0, 0.12) = 0.042;
uniform float wobble_hz : hint_range(0.5, 8.0) = 3.2;
uniform float stream_strength : hint_range(0.0, 0.28) = 0.1;
uniform float stream_speed : hint_range(0.2, 14.0) = 5.0;
uniform float stream_ribbons : hint_range(2.0, 14.0) = 7.0;

varying vec4 v_vertex_modulate;

void vertex() {
	v_vertex_modulate = COLOR;
}

void fragment() {
	vec2 uv0 = UV - 0.5;
	float rad = length(uv0);
	float ang = atan(uv0.y, uv0.x);
	vec2 radial = rad > 1e-4 ? uv0 / rad : vec2(1.0, 0.0);
	vec2 tangent = vec2(-radial.y, radial.x);

	float t = TIME * wobble_hz;
	vec2 warp = vec2(
		sin(t + uv0.y * 22.0 + uv0.x * 8.0),
		cos(t * 0.81 + uv0.x * 20.0 - uv0.y * 7.0)
	) * distort;

	float st = TIME * stream_speed;
	float k = stream_ribbons;
	// Elong ripples that crawl around the speck — reads as mini rift filaments.
	float s1 = sin(ang * k + rad * 32.0 - st * 1.15);
	float s2 = cos(ang * (k * 0.62) - rad * 24.0 + st * 0.92);
	float s3 = sin(ang * (k * 1.35) + rad * 18.0 + st * 1.4);
	float s4 = sin(dot(uv0, vec2(13.0, 9.0)) + st * 2.1);
	vec2 stream = tangent * (s1 * 0.42 + s2 * 0.38 + s3 * 0.22 + s4 * 0.12);
	stream *= stream_strength * (1.0 - smoothstep(0.1, 0.52, rad));

	vec2 uv = uv0 + warp + stream;
	float l = length(uv);
	float soft = 1.0 - smoothstep(0.28, 0.5, l);
	float edge = smoothstep(0.22, 0.46, l) * (1.0 - smoothstep(0.46, 0.54, l));
	vec3 base = v_vertex_modulate.rgb;
	vec3 rim = vec3(
		base.r * 1.08,
		base.g * 0.92,
		base.b * 1.12
	);
	float stream_vis = clamp(abs(s1) * 0.35 + abs(s2) * 0.28 + abs(s4) * 0.2, 0.0, 1.0)
		* (1.0 - smoothstep(0.35, 0.52, rad));
	vec3 col = mix(base, rim, edge * 0.55);
	col = mix(col, rim * vec3(1.04, 0.88, 1.14), stream_vis * stream_strength * 3.8 * soft);
	float alpha = v_vertex_modulate.a * soft;
	COLOR = vec4(col, alpha);
}
