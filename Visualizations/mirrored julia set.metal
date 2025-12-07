// Prompt: Please create a shader that features cycling through the julia set, mirroring the image on the x and y axes.

#include <metal_stdlib>
using namespace metal;

#define MAX_ITERATIONS 128
#define PI 3.14159265359

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Set up coordinate system
    // Map uv from [0, 1] to [-1.5, 1.5] for a centered view
    float2 st = (uv * 2.0 - 1.0) * 1.5;
    
    // Correct for aspect ratio to avoid stretching
    st.x *= u_resolution.x / u_resolution.y;
    
    // 2. Mirror on both axes
    // Take the absolute value of the coordinate. This maps all four quadrants
    // to the top-right, creating a 4-way symmetrical/mirrored image.
    st = abs(st);

    // 3. Animate the Julia set constant 'c'
    // This makes 'c' travel in a circle over time, creating an animation
    // of the fractal morphing. The value 0.7885 is a classic for Julia sets.
    float angle = u_time * 0.3;
    float2 c = 0.7885 * float2(cos(angle), sin(angle));

    // 4. Julia set iteration
    // Start with z at the current pixel's coordinate
    float2 z = st;
    int i = 0;
    
    for (; i < MAX_ITERATIONS; ++i) {
        // The core formula: z = z^2 + c
        // For complex numbers (x + yi), z^2 is (x^2 - y^2) + (2xy)i
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        
        // If the magnitude of z exceeds 2, it will escape to infinity.
        // We check |z|^2 > 4 to avoid a square root.
        if (dot(z, z) > 4.0) {
            break;
        }
    }
    
    // 5. Color the pixel
    float3 color;
    if (i == MAX_ITERATIONS) {
        // If the loop finished, the point is inside the set (black)
        color = float3(0.0);
    } else {
        // If the point escaped, color it based on how many iterations it took.
        // This creates the characteristic colored bands.
        float t = float(i) / float(MAX_ITERATIONS - 1);
        
        // Use a cosine-based palette for smooth, psychedelic colors
        color = 0.5 + 0.5 * cos(2.0 * PI * (t * 4.0 + float3(0.0, 0.2, 0.4)));
    }

    return float4(color, 1.0);
}