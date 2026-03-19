shader_type canvas_item;

uniform float inner_radius = 0.6;
uniform float outer_radius = 1.0;
uniform float vignette_strength = 0.8;

void fragment() {
    // Get distance from the center of the screen
    float dist = distance(UV, vec2(0.5, 0.5));
    
    // Smoothly interpolate between the inner and outer radius
    float vignette = smoothstep(inner_radius, outer_radius, dist);
    
    // Output pure black, using the vignette math for the alpha transparency!
    COLOR = vec4(0.0, 0.0, 0.0, vignette * vignette_strength);
}