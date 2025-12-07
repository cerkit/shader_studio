// Prompt: Please create a psychedlic shader that is mirrored in 6 equal facets along the x and y axes.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define N_SLICES 6.0

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Setup Coordinates
    // Center the coordinates and correct for aspect ratio
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // 2. Kaleidoscope Transform
    // Convert to polar coordinates
    float r = length(p);
    float a = atan2(p.y, p.x);

    // Add a slow rotation to the whole scene
    a += u_time * 0.1;

    // The angle of a single slice/facet
    float slice_angle = 2.0 * PI / N_SLICES;

    // Bring angle into the [0, 2*PI] range to simplify modulo
    if (a < 0.0) {
        a += 2.0 * PI;
    }

    // Fold the angle into the first slice
    a = fmod(a, slice_angle);

    // Mirror the angle within the slice (reflect across the center line)
    if (a > slice_angle / 2.0) {
        a = slice_angle - a;
    }
    
    // Reconstruct the coordinates from the transformed polar coordinates.
    // We will use these new coordinates 'p_kal' to draw our pattern.
    float2 p_kal = r * float2(cos(a), sin(a));

    // 3. Psychedelic Pattern Generation
    // Animate a pulsing zoom effect
    p_kal *= (1.0 + 0.1 * sin(u_time * 0.5));

    // Add some warping/distortion over time for a liquid effect
    p_kal += 0.1 * float2(sin(p_kal.y * 3.0 + u_time * 1.2), cos(p_kal.x * 3.0 + u_time * 1.2));

    // Calculate a base value from the transformed coordinates
    float val = 0.0;
    // Layer 1: Spirals and rays from the center
    val += sin(length(p_kal * 4.0) - atan2(p_kal.y, p_kal.x) * 5.0 - u_time * 2.0) * 0.5;
    
    // Layer 2: Concentric rings
    val += cos(length(p_kal) * 15.0 + u_time * 1.5) * 0.5;
    
    // Layer 3: Another pattern for complexity
    float len = length(p_kal + float2(0.2, 0.0));
    val += sin( (len - 0.5) * 20.0 + u_time * 3.0);
    
    // Normalize the value (sum of 3 sin/cos is roughly in [-2.0, 2.0])
    val *= 0.4;

    // 4. Coloring
    // Use the value to drive a colorful pattern.
    // The different offsets and multipliers create complex color shifts.
    float3 color = 0.5 + 0.5 * cos(val * 2.0 * PI + u_time * float3(0.2, 0.25, 0.3) + float3(0.0, 1.5, 3.0));

    // Add a subtle vignette to focus the view
    color *= (1.0 - length(p) * 0.5);

    return float4(color, 1.0);
}