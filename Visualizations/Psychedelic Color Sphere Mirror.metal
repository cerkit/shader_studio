// Prompt: create a psychedelic shader with vibrant colors. Mirror it along the vertical center.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Setup coordinates: normalized, centered, aspect-corrected
    float2 p = (uv * 2.0 - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // 2. Mirror the coordinate space along the vertical center
    p.x = abs(p.x);

    // Keep a copy of the pre-rotated coordinates for the vignette
    float2 p_vignette = p;

    // 3. Psychedelic Pattern Generation
    
    // Apply a slow global rotation
    float angle = u_time * 0.25;
    float s = sin(angle);
    float c = cos(angle);
    float2x2 rot_matrix = float2x2(c, -s, s, c);
    p = rot_matrix * p;

    // Convert to polar coordinates for radial/angular effects
    float r = length(p);
    float a = atan2(p.y, p.x);

    // Create a complex, time-varying value 'f' to warp the space
    float f = 0.0;
    f += sin(r * 6.0 - u_time * 2.0) * 0.5;  // Pulsing radial waves
    f += cos(a * 5.0 + u_time) * 0.3;       // Rotating angular sectors
    
    // Apply the warp to the coordinates, creating a fluid distortion
    p += f * 0.1;

    // Generate the final pattern from the warped coordinates
    float val = 0.0;
    val += sin(p.x * 10.0 + u_time);
    val += cos(p.y * 10.0 - u_time);
    val += sin(length(p) * 15.0 - u_time * 3.0);
    
    float final_pattern = fract(val * 0.2);

    // 4. Color Generation
    // Use a cosine-based palette to create vibrant, cycling colors
    float3 color;
    float time_color_shift = u_time * 0.1;
    color.r = 0.5 + 0.5 * cos(2.0 * PI * (final_pattern + time_color_shift + 0.0));
    color.g = 0.5 + 0.5 * cos(2.0 * PI * (final_pattern + time_color_shift + 0.333));
    color.b = 0.5 + 0.5 * cos(2.0 * PI * (final_pattern + time_color_shift + 0.666));
    
    // Apply a soft vignette to darken the edges
    float vignette = 1.0 - smoothstep(0.8, 1.4, length(p_vignette));
    color *= vignette;

    return float4(color, 1.0);
}