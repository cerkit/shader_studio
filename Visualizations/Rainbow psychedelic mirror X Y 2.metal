// Prompt: Please create a psychedelic pattern that mirrors on the x and y axes.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define TWO_PI 6.28318530718

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Center coordinates and correct for aspect ratio
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u_resolution.x / u_resolution.y;

    // Mirror on both the X and Y axes
    p = abs(p);

    // Convert to polar coordinates
    float r = length(p);
    float a = atan2(p.y, p.x);

    // Create a base value by combining radial and angular components with time
    float val = 0.0;
    val += sin(r * 12.0 - u_time * 2.0);
    val += cos(a * 8.0 + u_time);

    // Add a second, more complex layer of distortion
    float distortion = sin(r * 5.0 + a * 6.0 + u_time) * 0.5;
    float final_val = val + distortion;

    // Generate smoothly shifting, psychedelic colors using phase-shifted sine waves
    // The final_val drives the color cycling
    float3 color = float3(
        0.5 + 0.5 * sin(final_val * PI + u_time),
        0.5 + 0.5 * sin(final_val * PI + TWO_PI / 3.0),
        0.5 + 0.5 * sin(final_val * PI + TWO_PI * 2.0 / 3.0)
    );

    // Add a subtle vignette effect to darken the edges
    color *= (1.0 - r * 0.7);

    return float4(color, 1.0);
}