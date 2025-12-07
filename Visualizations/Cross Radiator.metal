// Prompt: Please create a shader that displays a  Christian cross in the center with multiple colored bands surrounding it that stretch from the cross to the outer edges of the screen. Use a blue and purple color palette. The shader should cycle through the color palette by setting the color of the radiating bands to the new color, giving the sense of colors eminating from the cross in the center.

#include <metal_stdlib>
using namespace metal;

#define PI 3.1415926535

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Center coordinates and correct for aspect ratio
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // --- Background Bands ---
    
    // 2. Convert to polar coordinates to get angle and radius
    float r = length(p);
    float a = atan2(p.y, p.x);

    // 3. Define the angular bands (spokes)
    float num_bands = 14.0;
    // Map angle from [-PI, PI] to [0, 1], then scale by num_bands to get an index
    float band_idx = floor((a / (PI * 2.0) + 0.5) * num_bands);
    
    // 4. Create an animation value that propagates outwards from the center.
    // The subtraction of radius ('- r * 4.0') makes the color wave emanate from the cross.
    float wave_time = u_time * 2.5 - r * 4.0;

    // 5. Select a color from the palette based on the band index and the propagating wave time.
    // The fmod cycles the color selection through 3 different palette entries.
    float color_selector = fmod(band_idx + floor(wave_time), 3.0);
    
    // Define the blue/purple color palette
    float3 color1 = float3(0.1, 0.0, 0.5); // Deep Blue/Purple
    float3 color2 = float3(0.4, 0.1, 0.9); // Bright Blue
    float3 color3 = float3(0.7, 0.2, 0.8); // Magenta/Purple

    float3 band_color;
    if (color_selector < 1.0) {
        band_color = color1;
    } else if (color_selector < 2.0) {
        band_color = color2;
    } else {
        band_color = color3;
    }

    // --- Christian Cross ---

    // 6. Define the cross shape using Signed Distance Functions (SDF) of two rectangles.
    // Dimensions for vertical and horizontal bars
    float2 v_dims = float2(0.05, 0.3);
    float2 h_dims = float2(0.2, 0.05);

    // Calculate SDF for two axis-aligned rectangles
    float vert_bar_dist = max(abs(p.x) - v_dims.x, abs(p.y) - v_dims.y);
    float horz_bar_dist = max(abs(p.x) - h_dims.x, abs(p.y) - h_dims.y);
    
    // 7. Combine the two rectangles with a min operation to form the final cross shape
    float cross_dist = min(vert_bar_dist, horz_bar_dist);

    // 8. Create a soft mask for the cross for anti-aliasing the edges
    float cross_mask = 1.0 - smoothstep(-0.015, 0.015, cross_dist);
    
    float3 cross_color = float3(1.0, 1.0, 0.9); // A soft, bright white/yellow color

    // --- Composition ---

    // 9. Mix the background band color and the cross color using the mask
    float3 color = mix(band_color, cross_color, cross_mask);

    return float4(color, 1.0);
}