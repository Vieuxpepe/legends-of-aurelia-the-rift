shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable;
uniform vec2 scroll_speed = vec2(0.015, 0.01); // Speed and direction of the wind
uniform vec4 shadow_color : source_color = vec4(0.05, 0.0, 0.1, 0.4); // Dark purpleish shadow
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45; // How much of the screen is covered
uniform float softness : hint_range(0.0, 1.0) = 0.5; // Blurs the edges of the clouds

void fragment() {
    // Scroll the texture coordinates over time to simulate wind
    vec2 scrolled_uv = UV + (scroll_speed * TIME);
    
    // Sample the noise texture
    float noise_val = texture(noise_texture, scrolled_uv).r;
    
    // Calculate the cloud shape using smoothstep for soft, natural edges
    float cloud_alpha = smoothstep(1.0 - cloud_coverage, (1.0 - cloud_coverage) + softness, noise_val);
    
    // Apply the shadow color and the calculated alpha
    COLOR = vec4(shadow_color.rgb, shadow_color.a * cloud_alpha);
}