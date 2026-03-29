shader_type canvas_item;

uniform vec4 element_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength = 1.5;
uniform float pulse_speed = 2.0;
/// 0 = normal, 1 = ranch selection (brighter, faster, slightly “shimmer” pulse on the rim)
uniform float selection_boost : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float spd = pulse_speed * (1.0 + 0.50 * selection_boost);
    float pulse = 0.75 + (0.25 + 0.20 * selection_boost) * sin(TIME * spd);
    pulse += selection_boost * 0.07 * sin(TIME * (spd * 2.6 + 0.8));

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
    float rim_mul = rim_strength * (1.0 + 0.90 * selection_boost);
    vec3 rim_light = element_color.rgb * border * rim_mul * pulse;
    vec3 final_rgb = tex.rgb + rim_light;

    // Draw the sprite PLUS the glowing border
    COLOR = vec4(final_rgb, max(tex.a, border));
}