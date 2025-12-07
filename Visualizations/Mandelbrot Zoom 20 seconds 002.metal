#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define LOOP_DURATION 20.0
#define MIN_ITER 100
#define MAX_ITER 1200
#define MAX_ZOOM 5.0e7

// Target point in the "Seahorse Valley" near the main cardioid's tip.
constant float2 C_TARGET = float2(-0.745429, 0.113009);

// Generates a color palette ranging from red to purple based on iteration count.
float3 get_color(float iter) {
    float r = 0.7 + 0.3 * cos(iter * 0.1 + 2.0);    // Strong red component
    float g = 0.0;                                 // No green for a purple/red theme
    float b = 0.5 + 0.4 * cos(iter * 0.08 - 1.5);   // Variable blue for purples/magentas
    return clamp(float3(r, g, b), 0.0, 1.0);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv; // uv is already normalized 0..1 from vertex shader
    
    // 1. Animation Timing & Looping
    // Create a 0-1 progress value that loops every LOOP_DURATION seconds.
    float progress = fmod(u_time, LOOP_DURATION) / LOOP_DURATION;
    // Use a cosine curve for smooth ease-in and ease-out, making the loop seamless.
    float eased_progress = 0.5 - 0.5 * cos(progress * 2.0 * PI);

    // 2. Zoom & Detail Calculation
    // Exponential zoom based on the eased progress.
    float zoom = pow(MAX_ZOOM, eased_progress);
    // Increase the max iterations as we zoom in to maintain detail.
    int current_max_iter = int(mix(float(MIN_ITER), float(MAX_ITER), eased_progress * eased_progress));

    // 3. Map UV coordinates to the complex plane
    // Adjust for aspect ratio so the fractal is not stretched.
    float2 aspect_ratio = float2(u_resolution.x / u_resolution.y, 1.0);
    // Center on the target point and apply the zoom.
    float2 c = C_TARGET + (uv - 0.5) * aspect_ratio * 2.5 / zoom;

    // 4. Mandelbrot Set Iteration
    float2 z = float2(0.0);
    int n = 0;
    for (; n < current_max_iter; n++) {
        // z = z^2 + c
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        // If the magnitude escapes the bailout radius of 2, stop.
        // We use dot(z,z) > 4 which is length_squared > 2^2 (more efficient).
        if (dot(z, z) > 4.0) {
            break;
        }
    }

    // 5. Coloring
    float3 color;
    if (n == current_max_iter) {
        // Point is inside the set - color it black.
        color = float3(0.0, 0.0, 0.0);
    } else {
        // Point is outside the set. Use a smooth iteration count for coloring.
        // This avoids color banding and creates smooth gradients.
        float smooth_iter = float(n) - log2(log2(dot(z, z)) * 0.5);
        color = get_color(smooth_iter);
    }
    
    return float4(color, 1.0);
}