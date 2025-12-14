// Prompt: Please make a psychedelic scene with vibrant geometric patterns. Make the color scheme transistion from shades of blue to shades of red. Mirror on the x and y axis.

#include <metal_stdlib>
using namespace metal;

// Helper function to create a 2D rotation matrix
float2x2 rotate2d(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(c, -s, s, c);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    // 1. Center coordinates and correct for aspect ratio
    float2 uv = (in.uv * 2.0 - 1.0);
    uv.x *= u_resolution.x / u_resolution.y;

    // 2. Mirror on both X and Y axes by taking the absolute value.
    // All subsequent operations will be in the top-right quadrant and mirrored.
    float2 p = abs(uv);

    // 3. Add dynamic transformations for a psychedelic feel
    p -= 0.5; // Offset from the corner to create more interesting shapes
    p = rotate2d(u_time * 0.2) * p; // Apply a slow overall rotation
    p *= (1.2 + sin(u_time * 0.3) * 0.2); // Add a slow pulsing zoom

    // 4. Generate the geometric pattern using an iterative fractal formula
    float v = 0.0;
    float2 z = p;
    float scale = 1.5;

    for (int i = 0; i < 7; i++) {
        z *= scale;
        z = abs(z);
        z = z / dot(z, z) - float2(0.5, 0.4);
        v += exp(-0.1 * length(z));
    }
    
    // 5. Generate a vibrant, transitioning color palette.
    // This technique uses cosine waves to create smooth, complex color gradients.
    // We will animate the phase (`d` vector) to shift the entire palette over time.
    
    // Create a value that smoothly oscillates between 0.0 and 1.0
    float color_anim = (sin(u_time * 0.25) + 1.0) * 0.5;

    // Palette parameters (from Iñigo Quílez)
    float3 a = float3(0.5, 0.5, 0.5); // Center color (gray offset)
    float3 b = float3(0.5, 0.5, 0.5); // Amplitude (controls contrast)
    float3 c = float3(1.0, 1.0, 1.0); // Frequency (controls how many color bands)
    
    // The phase `d` is what we will animate to transition the color scheme.
    // We define a blueish phase and a reddish phase, then mix between them.
    float3 blue_phase = float3(0.00, 0.15, 0.30);
    float3 red_phase  = float3(0.80, 0.90, 1.00);
    float3 d = mix(blue_phase, red_phase, color_anim);
    
    // The final palette function
    float3 color = a + b * cos(6.28318 * (c * v + d));

    // Optional: Add a subtle vignette to darken the edges, using the original un-mirrored uv
    color *= 1.0 - length(uv) * 0.5;

    return float4(color, 1.0);
}