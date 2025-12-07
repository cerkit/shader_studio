// Prompt: Create a shader that resembles what can be seen using a kaleidescope looking at a stained glass window. The kaleidescope should have 5 facets, giving 5 mirrored images around the center of the image. Cycle through the colors as if the kaleidescope is moving to see different parts of the stained glass window.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define N_FACETS 5.0

// Converts HSV color space to RGB
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// 2D pseudo-random number generator
float2 random2(float2 p) {
    return fract(sin(float2(dot(p, float2(127.1, 311.7)),
                             dot(p, float2(269.5, 183.3)))) * 43758.5453);
}

// Generates the stained glass pattern using Voronoi noise
float3 generate_pattern(float2 pos, float time) {
    float2 st = pos * 5.0; // Scale the space
    st.x += time * 0.2; // Animate the "view"

    float2 i_st = floor(st);
    float2 f_st = fract(st);

    float min_dist = 1.0;
    float second_min_dist = 1.0;
    float2 cell_id;

    // 3x3 neighbor search for Voronoi
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 neighbor = float2(float(i), float(j));
            float2 point = random2(i_st + neighbor);

            // Animate points to make them "wobble"
            point = 0.5 + 0.5 * sin(time * 0.5 + 2.0 * PI * point);

            float2 diff = neighbor + point - f_st;
            float dist = length(diff);

            if (dist < min_dist) {
                second_min_dist = min_dist;
                min_dist = dist;
                cell_id = i_st + neighbor;
            } else if (dist < second_min_dist) {
                second_min_dist = dist;
            }
        }
    }
    
    // Generate color from the cell ID, cycling hue over time
    float hue = fract(random2(cell_id).x + time * 0.1);
    float3 color = hsv2rgb(float3(hue, 0.75, 0.9));

    // Create black borders between cells
    float edge_thickness = 0.05;
    float edge = smoothstep(0.0, edge_thickness, second_min_dist - min_dist);
    color *= edge;

    return color;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Center coordinates and correct aspect ratio
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // Kaleidoscope effect
    float angle = atan2(p.y, p.x);
    float radius = length(p);
    
    float wedge_angle = (2.0 * PI) / N_FACETS;
    
    // Modulo the angle to be within one wedge
    angle = fmod(angle, wedge_angle);
    // Mirror the coordinates within the wedge
    angle = abs(angle - wedge_angle * 0.5);
    
    // Convert back to Cartesian coordinates
    float2 kaleido_p = radius * float2(cos(angle), sin(angle));

    // Generate the stained glass pattern on the folded coordinates
    float3 color = generate_pattern(kaleido_p, u_time);
    
    return float4(color, 1.0);
}