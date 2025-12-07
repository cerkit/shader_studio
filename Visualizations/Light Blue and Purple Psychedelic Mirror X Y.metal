// Prompt: Please make a psychedelic pattern that mirrors the content horizontally and vertically. The coor scheme should be shades of light blue to purple.

#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv; // uv is already normalized 0..1 from vertex shader
    
    // Center coordinates and correct for aspect ratio
    float2 p = (uv * 2.0 - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // --- Mirroring ---
    // Take the absolute value to mirror the pattern horizontally and vertically
    p = abs(p);

    // --- Psychedelic Pattern ---
    // Create a dynamic, swirling effect by combining distance, angle, and time.
    
    // Start with a base value derived from distance from the center.
    float d = length(p);
    
    // Add a time-based rotation to the angle for a swirling motion.
    float angle = atan2(p.y, p.x) + u_time * 0.4;
    
    // Combine multiple sine and cosine waves with different frequencies and phases.
    // This creates intricate, evolving interference patterns.
    float v1 = sin(d * 8.0 + u_time * 2.0);
    float v2 = cos(angle * 6.0 - u_time);
    float v3 = sin(length(p * 0.8 + 0.2 * sin(u_time)) * 12.0);
    
    // Combine the waves to form a complex value.
    float combined = v1 + v2 * v3;
    
    // Normalize the result to a 0.0 to 1.0 range for coloring.
    // The sine function maps the complex value into a smooth oscillation.
    float intensity = (sin(combined * 3.0) + 1.0) * 0.5;

    // --- Color Scheme ---
    // Define the start and end colors for our gradient.
    float3 lightBlue = float3(0.5, 0.7, 1.0);
    float3 purple = float3(0.8, 0.4, 1.0);

    // Use smoothstep to create sharper transitions between the colors,
    // enhancing the psychedelic look.
    float t = smoothstep(0.4, 0.6, intensity);

    // Interpolate between light blue and purple based on the final value.
    float3 color = mix(lightBlue, purple, t);
    
    return float4(color, 1.0);
}