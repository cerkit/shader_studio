// Prompt: Please create a psychedlic shader that is mirrored in 5 equal facets along the x and y axes.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define FACETS 5.0

// Helper function to convert HSV to RGB color space
// H, S, V in range [0, 1]
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;

    // Create 5x5 mirrored facets
    float2 p = uv * FACETS;
    float2 i = floor(p);
    float2 f = fract(p);

    // Mirror every other cell for a kaleidoscopic effect
    if (fmod(i.x, 2.0) > 0.5) {
        f.x = 1.0 - f.x;
    }
    if (fmod(i.y, 2.0) > 0.5) {
        f.y = 1.0 - f.y;
    }

    // Center coordinates and correct for aspect ratio
    float2 coord = f * 2.0 - 1.0;
    coord.x *= u_resolution.x / u_resolution.y;

    // Convert to polar coordinates
    float r = length(coord);
    float a = atan2(coord.y, coord.x);

    // --- Psychedelic Pattern Generation ---

    // Warp the angle and radius over time to create a flowing, liquid effect
    float angle_warp = sin(r * 4.0 - u_time) * 0.5;
    a += angle_warp;
    
    float radius_warp_speed = u_time * 0.5;
    float radius_warp_freq = 3.0;
    r = abs(fmod(r * radius_warp_freq - radius_warp_speed, 2.0) - 1.0);

    // Combine radial and angular components for a complex pattern
    float pattern = sin(r * 15.0 - u_time * 3.0) * cos(a * 7.0);
    pattern = 0.5 + 0.5 * pattern; // Normalize to [0, 1] for brightness

    // --- Colorization using HSV ---

    // Hue cycles with time and is based on the angle, creating rotating colors
    float hue = a / (2.0 * PI) + u_time * 0.1;
    hue = fract(hue);

    // Saturation pulses based on radius and time
    float saturation = 0.7 + 0.3 * sin(r * 10.0 + u_time * 2.0);
    
    // Value (brightness) is based on the main pattern
    float value = pattern;

    float3 color = hsv2rgb(float3(hue, saturation, value));

    return float4(color, 1.0);
}