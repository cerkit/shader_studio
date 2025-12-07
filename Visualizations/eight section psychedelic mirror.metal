// Prompt: Please make a psychedelic pattern that mirrors the content horizontally and vertically. The color scheme should be shades of orange, blue, yellow, and purple. After 10 seconds, divide the screen into four sections of four rectangles that repeat the mirroring along the x and y axes for all 8 rectangles.

#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // After 10 seconds, tile the UV space into a 2x2 grid.
    if (u_time > 10.0) {
        uv = fract(uv * 2.0);
    }
    
    // Center coordinates and correct for aspect ratio.
    float2 p = (uv * 2.0 - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // Apply horizontal and vertical mirroring.
    p = abs(p);

    // Convert to polar coordinates for the pattern.
    float r = length(p);
    float a = atan2(p.y, p.x);
    
    float t = u_time * 0.5;

    // Create a psychedelic, evolving pattern by warping the polar coordinates.
    // Warp the angle based on radius and time for a swirling effect.
    a += sin(r * 6.0 - t * 2.0) * 1.5;
    
    // Warp the radius to create a pulsing/tunneling effect.
    r = 0.2 / r + t;

    // Combine multiple sine waves using the warped coordinates to generate the final value.
    float val = cos(a * 5.0) * 0.5 + 0.5;
    val *= sin(r * 4.0) * 0.5 + 0.5;

    // Define the color palette.
    float3 orange = float3(1.0, 0.5, 0.1);
    float3 blue   = float3(0.1, 0.2, 1.0);
    float3 yellow = float3(1.0, 0.9, 0.2);
    float3 purple = float3(0.6, 0.1, 0.8);
    
    // Create a smooth gradient using the palette colors.
    // The overlapping smoothstep ranges create smoother transitions.
    float3 color = mix(blue, purple, smoothstep(0.0, 0.4, val));
    color = mix(color, orange, smoothstep(0.3, 0.8, val));
    color = mix(color, yellow, smoothstep(0.7, 1.0, val));

    // A touch of gamma correction for richer colors.
    color = pow(color, float3(0.85));

    return float4(color, 1.0);
}