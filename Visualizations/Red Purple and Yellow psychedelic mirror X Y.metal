// Prompt: Please create a psychedelic pattern that mimrrors on teh x and y axes. Use a color scheme consisting of dark purple, vibrant red, and school bus yellow.

#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Center and correct aspect ratio
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;
    
    // Mirror on both x and y axes to create four-way symmetry
    p = abs(p);

    // Animate and distort coordinates for a liquid/warped effect
    float time = u_time * 0.3;
    p += sin(p.yx * 5.0 + time) * 0.15;
    
    // Convert to polar coordinates
    float angle = atan2(p.y, p.x);
    float radius = length(p);

    // Generate the core psychedelic pattern by combining multiple sine waves
    // with different frequencies based on angle, radius, and time.
    float v = 0.0;
    v += sin((angle * 8.0) + (radius * 12.0) - time * 2.0);
    v += cos((angle * 4.0) - (radius * 6.0) + time);
    
    // Normalize the value to the [0, 1] range for color mapping.
    // The sum of two sines is in [-2, 2], so we map it to [0, 1].
    float t = (v + 2.0) * 0.25;
    
    // Use smoothstep for a more organic feel to the gradient
    t = smoothstep(0.0, 1.0, t);
    
    // Define the color palette
    float3 darkPurple = float3(0.3, 0.0, 0.5);
    float3 vibrantRed = float3(1.0, 0.1, 0.1);
    float3 schoolBusYellow = float3(1.0, 0.8, 0.0);
    
    // Create a three-color gradient.
    // Mix between purple and red for the lower half of the value range.
    float3 color = mix(darkPurple, vibrantRed, smoothstep(0.0, 0.55, t));
    // Mix the result with yellow for the upper half, creating a smooth transition.
    color = mix(color, schoolBusYellow, smoothstep(0.45, 1.0, t));
    
    return float4(color, 1.0);
}