#include <metal_stdlib>
using namespace metal;

#define OCTAVES 5

// Helper function to generate a pseudo-random value from a 3D coordinate
float random(float3 st) {
    return fract(sin(dot(st.xyz, float3(12.9898, 78.233, 45.543))) * 43758.5453123);
}

// 3D Value Noise function
float noise(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);

    // Use a smooth curve for interpolation (quintic hermite)
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    // Get random values at the 8 corners of the cube
    float v000 = random(i + float3(0,0,0));
    float v100 = random(i + float3(1,0,0));
    float v010 = random(i + float3(0,1,0));
    float v110 = random(i + float3(1,1,0));
    float v001 = random(i + float3(0,0,1));
    float v101 = random(i + float3(1,0,1));
    float v011 = random(i + float3(0,1,1));
    float v111 = random(i + float3(1,1,1));

    // Trilinear interpolation
    return mix(mix(mix(v000, v100, f.x),
                   mix(v010, v110, f.x), f.y),
               mix(mix(v001, v101, f.x),
                   mix(v011, v111, f.x), f.y), f.z);
}

// Fractal Brownian Motion (FBM)
float fbm(float3 p) {
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
                              constant float& u_time [[buffer(1)]],
                              constant float& u_audio [[buffer(2)]]) {
    float2 uv = in.uv;
    
    // Adjust coordinates to be centered and aspect-ratio correct
    float2 p = (2.0 * uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);
    
    // Define the lava lamp colors
    float3 orange_bg = float3(1.0, 0.4, 0.05);
    float3 purple_lava = float3(0.6, 0.1, 0.9);

    // Control animation speed with time and audio input
    float speed = 0.2 + u_audio * 0.3;
    float time = u_time * speed;
    
    // Zoom level for the blobs
    float zoom = 1.5;

    // Use two layers of noise for a more organic, swirling motion.
    // The first FBM call creates a displacement field (like turbulence).
    float3 p1 = float3(p * zoom, time);
    float displacement = fbm(p1);

    // The second FBM call uses the displaced coordinates to create the main blob shapes.
    // This makes the blobs warp and merge like real lava.
    float3 p2 = float3(p * zoom + displacement, time);
    float noise_value = fbm(p2);
    
    // Use smoothstep to create the soft, "nebulous" edges of the lava blobs.
    // The values 0.48 and 0.52 define the softness of the transition.
    // Adjusting this range will make the blobs larger/smaller or sharper/softer.
    float mix_factor = smoothstep(0.48, 0.52, noise_value);

    // Mix the background and lava colors based on the noise
    float3 color = mix(orange_bg, purple_lava, mix_factor);
    
    return float4(color, 1.0);
}