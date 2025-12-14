// Prompt: Please create a pattern of a cycling julia set using bright purple and bright orange-yellow with background. Mirror the image on the y axis

#include <metal_stdlib>
using namespace metal;

#define MAX_ITERATIONS 128
#define PI 3.1415926535

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Create a centered coordinate system with aspect ratio correction
    float2 p = (uv * 2.0 - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);

    // Mirror the image on the Y-axis (vertical center line) by using absolute value of x
    p.x = abs(p.x);

    // Zoom out slightly to see more of the set
    p *= 1.4;

    // Animate the Julia constant 'c' by moving it on a circle over time.
    // The value 0.7885 is a classic radius for interesting shapes.
    float angle = u_time * 0.2;
    float2 c = 0.7885 * float2(cos(angle), sin(angle));
    
    float2 z = p;
    float iterations = 0.0;
    
    for (int i = 0; i < MAX_ITERATIONS; ++i) {
        // The Julia set iteration: z = z^2 + c
        // For a complex number z = (x, y), z^2 is (x*x - y*y, 2*x*y)
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        
        // If the point escapes a circle of radius 4 (squared radius 16), stop.
        if (dot(z, z) > 16.0) {
            break;
        }
        iterations += 1.0;
    }
    
    // Default to a dark purple background color for points inside the set
    float3 color = float3(0.05, 0.0, 0.1);

    // If the point escaped, color it based on how many iterations it took
    if (iterations < float(MAX_ITERATIONS)) {
        // Use a smooth iteration count for continuous coloring, avoiding sharp bands.
        // This formula provides a fractional value based on the final distance.
        float smooth_iter = iterations - log2(log2(length(z)));
        
        // Define the two bright colors for the gradient
        float3 colorA = float3(0.6, 0.1, 0.9); // Bright Purple
        float3 colorB = float3(1.0, 0.7, 0.0); // Bright Orange-Yellow
        
        // Create a value 't' that oscillates smoothly between 0 and 1
        // based on the iteration count, used to mix the two colors.
        float t = smooth_iter * 0.1;
        t = 0.5 + 0.5 * cos(t * 2.0 * PI);
        
        color = mix(colorA, colorB, t);
    }
    
    return float4(color, 1.0);
}