// Prompt: please create a light blue sky with wispy procedural clouds over a procedural jungle on the horizon. The jungle should be a gray silhouette and the camera should travel from the right to the left, with the jungle moving in a parallax motion. Please make the clouds a promenent feature.

#include <metal_stdlib>
using namespace metal;

#define OCTAVES 6

// Helper Functions

// 2D pseudo-random generator
float2 hash(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// 2D Gradient Noise (Perlin-like)
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f); // Smoothstep curve

    return mix(mix(dot(hash(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
                   dot(hash(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
               mix(dot(hash(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
                   dot(hash(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x), u.y);
}

// Fractional Brownian Motion (fBm)
float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float2x2 rot = float2x2(float2(0.8, 0.6), float2(-0.6, 0.8)); // Rotation matrix
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(p);
        p = rot * p * 2.0;
        amplitude *= 0.5;
    }
    return value;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // --- Sky ---
    // A vertical gradient for the sky, lighter blue at the horizon.
    float3 sky_color_horizon = float3(0.6, 0.75, 0.9);
    float3 sky_color_zenith = float3(0.25, 0.45, 0.7);
    float3 color = mix(sky_color_horizon, sky_color_zenith, smoothstep(0.1, 0.7, uv.y));

    // --- Wispy Clouds ---
    // Use domain warping for a wispy, swirling effect.
    float2 cloud_uv = uv * float2(3.0, 4.0);
    // Move clouds slower than the jungle for parallax.
    cloud_uv.x += u_time * 0.03;

    // The warp field itself moves slowly, creating a dynamic, evolving look.
    float2 warp_offset = float2(fbm(cloud_uv + u_time * 0.02),
                                fbm(cloud_uv + float2(5.2, 1.3) + u_time * 0.015));
    
    float cloud_noise = fbm(cloud_uv + 2.0 * warp_offset);
    
    // Shape the cloud layer to be denser near the horizon and fade out at the top.
    float cloud_distribution = smoothstep(0.8, 0.25, uv.y);
    
    // Create the final cloud mask from the noise and distribution.
    float cloud_mask = smoothstep(0.45, 0.6, cloud_noise) * cloud_distribution;
    
    // Add clouds to the sky.
    float3 cloud_color = float3(1.0);
    color = mix(color, cloud_color, cloud_mask * 0.9);

    // --- Jungle Silhouette with Parallax ---
    // The camera travels right-to-left, so the scene moves left-to-right (uv.x + u_time).
    // Each layer moves at a different speed to create a sense of depth.
    
    // Layer 1: Farthest, slowest, lightest gray silhouette.
    float x1 = (uv.x + u_time * 0.08) * 4.0;
    float h1 = fbm(float2(x1, 0.0)) * 0.15 + 0.03 * noise(float2(x1 * 5.0, 0.0));
    float y1 = 0.1 + h1;
    color = mix(color, float3(0.25), 1.0 - smoothstep(y1, y1 + 0.005, uv.y));

    // Layer 2: Middle distance, medium speed, medium gray.
    float x2 = (uv.x + u_time * 0.15) * 6.0;
    float h2 = fbm(float2(x2, 1.0)) * 0.12 + 0.04 * noise(float2(x2 * 7.0, 1.0));
    float y2 = 0.05 + h2;
    color = mix(color, float3(0.18), 1.0 - smoothstep(y2, y2 + 0.005, uv.y));

    // Layer 3: Closest, fastest, darkest gray.
    float x3 = (uv.x + u_time * 0.3) * 9.0;
    float h3 = fbm(float2(x3, 2.0)) * 0.1 + 0.05 * noise(float2(x3 * 9.0, 2.0));
    float y3 = 0.0 + h3;
    color = mix(color, float3(0.1), 1.0 - smoothstep(y3, y3 + 0.005, uv.y));

    return float4(color, 1.0);
}