// Prompt: please generate a scene with purple and red procedural smoke on a black background. The smoke should occupy the entire image. Cycle the colors of the smoke between the shades of purple to red, then back to purple. Mirror the scene on the x axis.

#include <metal_stdlib>
using namespace metal;

#define OCTAVES 6

// Pseudo-random number generator
float random(float2 p) {
    return fract(sin(dot(p.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

// 2D Value Noise
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));

    // Smoothstep interpolation
    float2 u = f * f * (3.0 - 2.0 * f);

    // Mix the four corners
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion
float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 2.0;
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}


fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Adjust coordinates: center, correct aspect ratio
    float2 p = (2.0 * uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);
    
    // Mirror the scene on the x-axis
    p.x = abs(p.x);

    // --- Procedural Smoke Generation ---
    
    // 1. Create a base coordinate system that moves over time
    float2 base_p = p * 2.5; // Zoom in
    base_p.x -= u_time * 0.2; // Pan horizontally
    base_p.y += u_time * 0.1; // Pan vertically

    // 2. Create a distortion field using fbm to make the smoke swirl
    float2 distortion_p = p * 1.5;
    float2 distortion = float2(fbm(distortion_p + u_time * 0.3),
                               fbm(distortion_p - u_time * 0.2 + float2(5.2, 1.3)));

    // 3. Apply the distortion to the base coordinates
    float final_noise = fbm(base_p + distortion * 1.5);
    
    // --- Coloring ---
    
    // Remap the noise to create more contrast and shape for the smoke
    float intensity = smoothstep(0.3, 0.7, final_noise);
    
    // Define the two colors to cycle between
    float3 purple = float3(0.5, 0.1, 0.9);
    float3 red = float3(1.0, 0.2, 0.1);
    
    // Create a time-based cycle value (0 to 1 and back)
    float cycle = (sin(u_time * 0.5) + 1.0) * 0.5;
    
    // Lerp between the primary colors based on the cycle
    float3 color1 = mix(purple, red, cycle);
    float3 color2 = mix(red, purple, cycle);
    
    // Color the smoke by mixing the two cycling colors based on the noise value
    float3 smoke_color = mix(color1, color2, final_noise);
    
    // Multiply the smoke color by the intensity.
    // This makes the thin parts of the smoke fade to black.
    float3 color = smoke_color * intensity;
    
    return float4(color, 1.0);
}