#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define LOOP_DURATION 20.0

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Normalize coordinates and correct for screen aspect ratio
    float2 p = (2.0 * uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);

    // 2. Setup seamless looping animation for zoom
    float t = fmod(u_time, LOOP_DURATION);
    float loop_progress = t / LOOP_DURATION; // 0..1 over the loop duration

    // Create a smooth 0 -> 1 -> 0 "ping-pong" value over the loop
    // This will control the zoom in and zoom out effect
    float pingpong_progress = 1.0 - abs(1.0 - 2.0 * loop_progress);
    float smooth_pingpong = pingpong_progress * pingpong_progress * (3.0 - 2.0 * pingpong_progress);

    // 3. Define zoom level and center point
    // Zoom from a wide view down to a deep view and back
    float zoom_depth = 28.0; // Higher value means deeper zoom
    float scale = 1.2 * pow(0.5, zoom_depth * smooth_pingpong);

    // Pan to a visually interesting point in the "seahorse valley" near the main tip
    float2 center = float2(-0.745429, 0.113009);
    
    // Calculate the complex number 'c' for this pixel
    float2 c = center + p * scale;

    // 4. Mandelbrot set iteration
    float2 z = float2(0.0);
    
    // Increase iterations for deeper zooms to maintain detail
    int max_iterations = int(mix(250.0, 3500.0, smooth_pingpong));
    
    int i = 0;
    for (; i < max_iterations; ++i) {
        // z = z^2 + c
        // The real part is z.x*z.x - z.y*z.y
        // The imaginary part is 2.0*z.x*z.y
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        
        // Check if the point has "escaped" the radius of 2
        // We use dot(z,z) > 4.0 which is length(z)^2 > 2^2 to avoid a square root
        if (dot(z, z) > 4.0) {
            break;
        }
    }

    // 5. Coloring
    float3 color;
    if (i == max_iterations) {
        // Point is inside the set, color it black
        color = float3(0.0);
    } else {
        // Point is outside the set, color based on how quickly it escaped
        // Use a smooth iteration count to avoid color banding
        float log_zn = log(dot(z, z)) / 2.0;
        float nu = log(log_zn / log(2.0)) / log(2.0);
        float iter_smooth = float(i) + 1.0 - nu;

        // Create a smooth gradient using sine waves for purple/red tones
        float t_col = sqrt(iter_smooth / 200.0);
        float s = 0.5 + 0.5 * sin(t_col * 2.0 * PI - 1.5);
        
        // Define our color palette: Dark Purple -> Red/Pink -> Bright Accent
        float3 color1 = float3(0.1, 0.0, 0.2); // Dark Purple
        float3 color2 = float3(1.0, 0.2, 0.3); // Bright Red/Pink
        float3 color3 = float3(0.9, 0.8, 1.0); // Light Pink/White accent for contrast

        // Mix between the three colors for a rich, cycling palette
        color = mix(color1, color2, smoothstep(0.0, 0.6, s));
        color = mix(color, color3, smoothstep(0.6, 1.0, s));
    }

    return float4(color, 1.0);
}