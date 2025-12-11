// Prompt: Please create a scene of the aurora borealis that is shades of green flickering over a black background

#include <metal_stdlib>
using namespace metal;

// 2D Random
float random(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453123);
}

// 2D Value Noise
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    // Smooth Hermite interpolation (smoothstep)
    f = f * f * (3.0 - 2.0 * f);
    
    float a = random(i + float2(0.0, 0.0));
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

#define OCTAVES 6

// Fractal Brownian Motion
float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}


fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Adjust coordinates to be centered and aspect-ratio correct
    float2 st = (2.0 * uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);
    st *= 1.5; // Zoom out a bit to see more of the effect

    float3 color = float3(0.0);
    
    // First layer of aurora (slow, large, horizontal waves)
    float2 q1 = st;
    q1.x += u_time * 0.05; // Slow horizontal movement
    q1.y *= 0.4;           // Stretch vertically
    float fbm1 = fbm(q1);
    
    // Second layer (faster, more detailed, flickering ripples)
    float2 q2 = st;
    q2.x -= u_time * 0.2;  // Faster movement in opposite direction
    q2.y *= 0.6;
    float fbm2 = fbm(q2 * 2.0);

    // Combine noise layers to perturb the y-coordinate.
    // This creates the main flowing curtain shape.
    float y_perturb = 1.5 * fbm1 + 0.4 * fbm2;
    
    // Create the aurora band by calculating intensity based on the distance
    // from the perturbed y-coordinate. The pow() function sharpens the band
    // and creates a bright, glowing core with a soft falloff.
    float intensity = pow(0.03 / abs(st.y + y_perturb), 1.8);
    
    // Add a third noise layer for faint vertical rays, characteristic of auroras.
    // We stretch the coordinates heavily on the y-axis to create vertical patterns.
    float2 q3 = st * float2(0.2, 2.5);
    q3.x += u_time * 0.08;
    float rays = fbm(q3);
    intensity += pow(rays, 3.0) * 0.2;

    // The main color is a bright green.
    float3 aurora_color = float3(0.1, 1.0, 0.4);
    color += intensity * aurora_color;
    
    // Fade the effect out at the bottom and top of the screen to keep it in the "sky".
    float fade = smoothstep(0.2, 0.5, uv.y) * (1.0 - smoothstep(0.85, 1.0, uv.y));
    color *= fade;

    return float4(color, 1.0);
}