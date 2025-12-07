// Prompt: Please create a psychedelic pattern that mirrors on the x and y axes.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define ITERATIONS 5

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Setup Coordinates
    // Center the coordinates to (-1, 1) and correct for aspect ratio
    float2 p = (uv * 2.0 - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // 2. Mirroring
    // Apply absolute value to mirror the pattern across both X and Y axes
    p = abs(p);

    // 3. Psychedelic Pattern Generation
    // We'll use a feedback loop to create a fractal, flowing pattern.
    float color_value = 0.0;
    float amplitude = 0.6;
    float zoom = 1.5;

    for (int i = 0; i < ITERATIONS; i++) {
        // Add a layer of pattern based on the sine of distance and angle
        color_value += amplitude * sin(length(p * zoom) - u_time * 0.5);

        // Distort the coordinate space for the next iteration
        // This creates the swirling, organic look
        float angle = atan2(p.y, p.x);
        p.x += amplitude * 0.3 * cos(angle * 4.0 + u_time);
        p.y += amplitude * 0.3 * sin(angle * 4.0 - u_time);

        // Scale up the coordinates and reduce the amplitude for the next layer
        p *= 1.4;
        amplitude *= 0.6;
    }

    // 4. Coloring
    // Use the final value to drive a vibrant, shifting color palette
    float r = sin(color_value * PI) * 0.5 + 0.5;
    float g = sin(color_value * PI + (2.0 * PI / 3.0)) * 0.5 + 0.5;
    float b = sin(color_value * PI + (4.0 * PI / 3.0)) * 0.5 + 0.5;
    
    float3 color = float3(r, g, b);

    return float4(color, 1.0);
}