// Prompt: Please create a shader that displays a cross in the center with multiple colored bands surrounding it that stretch from the cross to the outer edges of the screen. Use a blue and purple color palette. The shader should cycle through the color palette by setting the color of the radiating bands to the new color, giving the sense of colors eminating from the cross in the center.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define NUM_BANDS 16.0

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Center coordinates and correct for aspect ratio
    float2 p = (2.0 * uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);

    // Convert to polar coordinates to work with angles and radius
    float angle = atan2(p.y, p.x);
    float radius = length(p);

    // --- Background Bands and Emanation ---
    
    // Define the two main colors for the palette
    float3 color_blue = float3(0.0, 0.2, 1.0);
    float3 color_purple = float3(0.6, 0.1, 0.8);

    // Create a pattern of angular bands (sectors) that alternates between the palette colors.
    // sin(angle * N) creates 2*N lobes, so we use NUM_BANDS / 2.0.
    float band_pattern = 0.5 + 0.5 * sin(angle * (NUM_BANDS / 2.0));
    
    // Determine the base color and the "pulse" color for each band
    float3 base_color = mix(color_blue, color_purple, band_pattern);
    float3 pulse_color = mix(color_purple, color_blue, band_pattern); // The opposite color

    // Create a wave that travels outwards from the center over time
    float wave = fract(radius * 2.5 - u_time * 0.7);
    
    // Shape the sawtooth wave into a smooth pulse with a defined width
    float pulse_amount = smoothstep(0.0, 0.15, wave) - smoothstep(0.4, 0.55, wave);
    
    // The final background color is the base color, which temporarily shifts to the
    // pulse color as the wave passes over it, creating the emanation effect.
    float3 bg_color = mix(base_color, pulse_color, pulse_amount);
    
    // --- Central Cross ---
    
    float thickness = 0.04;
    float feather = 0.01;
    
    // Define the horizontal and vertical bars with soft edges for anti-aliasing
    float h_bar = smoothstep(thickness + feather, thickness, abs(p.y));
    float v_bar = smoothstep(thickness + feather, thickness, abs(p.x));
    
    // Combine the bars into a single cross shape (used as a mask)
    float cross_mask = saturate(h_bar + v_bar);
    
    // Make the cross a bright, gently pulsing color to stand out
    float3 cross_color = float3(1.0, 0.9, 1.0) * (0.8 + 0.2 * sin(u_time * 1.5));

    // --- Final Composition ---
    
    // Composite the cross over the background using the mask
    float3 color = mix(bg_color, cross_color, cross_mask);

    return float4(color, 1.0);
}