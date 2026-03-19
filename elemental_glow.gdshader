shader_type canvas_item;

uniform vec4 element_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength = 1.5;
uniform float pulse_speed = 2.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);

    // Look at neighboring pixels to find the edges of your sprite
    vec2 size = TEXTURE_PIXEL_SIZE;
    float outline = tex.a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;

    // If a neighbor is solid but this pixel is transparent, it's the border!
    float border = step(0.1, outline) - step(0.1, tex.a);
    border = clamp(border, 0.0, 1.0);

    // Add the glowing, pulsing rim around the artwork
    vec3 final_rgb = tex.rgb + (element_color.rgb * border * rim_strength * pulse);
    
    // Draw the sprite PLUS the glowing border
    COLOR = vec4(final_rgb, max(tex.a, border));
}