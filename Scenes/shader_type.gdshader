shader_type canvas_item;

uniform float scroll_speed = 2.0;

void fragment() {
    // Shift the UV coordinates based on time to create movement
    vec2 shifted_uv = vec2(UV.x - (TIME * scroll_speed), UV.y);
    COLOR = texture(TEXTURE, shifted_uv) * COLOR;
}
//	// Uncomment to replace the default light processing function with this one.
//}
