// Prompt: The background should radiate from the center to the outside edges of the image in a starburst pattern. make the radial lines red, yellow, and orange. THe radiating lines should be animated to cycle between each of the colors.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define NUM_RAYS 40.0

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv; // uv is already normalized 0..1 from vertex shader
    
    // Center coordinates and correct for aspect ratio
    float2 st = (2.0 * uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);

    // Calculate the angle from the center point
    float angle = atan2(st.y, st.x);

    // Add time to the angle to make the rays rotate
    float rotating_angle = angle + u_time * 0.4;
    
    // Normalize angle to 0-1 range and multiply by the number of rays
    // This creates a repeating pattern around the circle
    float pattern_val = fract(rotating_angle / (2.0 * PI) * NUM_RAYS);
    
    // Shape the pattern into sharp lines
    // 1. Create a triangle wave (0 -> 1 -> 0) for each segment
    float rays = 1.0 - abs(pattern_val * 2.0 - 1.0);
    // 2. Use pow to sharpen the peaks of the wave, creating thin lines
    rays = pow(rays, 30.0);
    // 3. Fade rays towards the center for a softer origin
    rays *= smoothstep(0.0, 0.3, length(st));

    // Define the colors for the animation cycle
    float3 red = float3(1.0, 0.1, 0.0);
    float3 orange = float3(1.0, 0.5, 0.0);
    float3 yellow = float3(1.0, 1.0, 0.0);

    // Use sine wave on time to create a smooth 0-1 value for mixing
    float t = fmod(u_time * 0.5, 3.0);
    float3 lineColor;
    
    if (t < 1.0) {
        lineColor = mix(red, orange, t);
    } else if (t < 2.0) {
        lineColor = mix(orange, yellow, t - 1.0);
    } else {
        lineColor = mix(yellow, red, t - 2.0);
    }
    
    // The final color is the line color multiplied by the ray pattern.
    // The background remains black where rays are 0.
    float3 color = lineColor * rays;

    return float4(color, 1.0);
}