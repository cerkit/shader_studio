#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define N_CIRCLES 10.0
#define N_SPOKES 8.0

// Helper function to create a 2D rotation matrix
float2x2 rot(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(c, -s, s, c);
}

// Simple pseudo-random noise function
float noise(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453123);
}

// Fractional Brownian Motion (FBM) for more organic patterns
float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Signed Distance Function for a circle
float sdCircle(float2 p, float r) {
    return length(p) - r;
}

// Signed Distance Function for a ring
float sdRing(float2 p, float r, float w) {
    return abs(length(p) - r) - w;
}


fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]],
                              constant float& u_audio [[buffer(2)]]) {
    float2 uv = in.uv;
    
    // 1. Setup coordinate system (center screen, correct aspect ratio)
    float2 aspect = float2(u_resolution.x / u_resolution.y, 1.0);
    float2 p = (2.0 * uv - 1.0) * aspect;
    p *= 1.3; // Zoom out slightly

    // 2. Create liquid/wobbly distortion
    float audio_amp = 0.5 + u_audio * 1.5;
    float2 p_distort = p;
    float2 noise_coord = p * 2.0 + u_time * 0.1;
    float2 offset = float2(fbm(noise_coord), fbm(noise_coord + float2(7.3, 3.7)));
    p_distort += (offset - 0.25) * 0.1 * audio_amp;

    // 3. Define the scene using Signed Distance Functions (SDFs)
    float d = 1e6; // Initialize distance to a large value

    // Convert distorted coordinates to polar for radial shapes
    float angle = atan2(p_distort.y, p_distort.x);

    // Central circles and rings
    d = min(d, sdCircle(p_distort, 0.22));
    d = min(d, sdRing(p_distort, 0.4, 0.08));

    // Outer ring of small circles using polar repetition
    float circle_angle_step = (2.0 * PI) / N_CIRCLES;
    float wrapped_circle_angle = fmod(angle + circle_angle_step * 0.5, circle_angle_step) - circle_angle_step * 0.5;
    float2 p_circle_local = rot(-wrapped_circle_angle) * p_distort;
    d = min(d, sdCircle(p_circle_local - float2(0.6, 0.0), 0.06));

    // Radial spokes using polar repetition
    float spoke_angle_step = (2.0 * PI) / N_SPOKES;
    float wrapped_spoke_angle = fmod(angle + spoke_angle_step * 0.5, spoke_angle_step) - spoke_angle_step * 0.5;
    float2 p_spoke_local = rot(-wrapped_spoke_angle) * p_distort;
    if (p_spoke_local.x > 0.55 && p_spoke_local.x < 1.0) {
        d = min(d, abs(p_spoke_local.y) - 0.008);
    }

    // Horizontal wavy band (using original, non-distorted coordinates for a different feel)
    float2 p_wavy = p;
    float wave_freq = 3.0;
    float wave_amp = 0.06 * (1.0 + u_audio * 4.0);
    p_wavy.y += sin(p_wavy.x * wave_freq + u_time * 1.5) * wave_amp;
    p_wavy.y += cos(p_wavy.x * wave_freq * 0.6 - u_time) * wave_amp * 0.5;
    float band_thickness = 0.07;
    d = min(d, abs(p_wavy.y) - band_thickness);
    
    // 4. Determine final color
    
    // Base color gradient (Cyan -> Blue -> Purple)
    float3 color_cyan = float3(0.1, 0.7, 0.8);
    float3 color_purple = float3(0.6, 0.1, 1.0);
    float grad_mix = 0.5 + 0.5 * sin(p.x * 0.8 - p.y * 1.2 + u_time * 0.2);
    float3 color = mix(color_cyan, color_purple, grad_mix);
    
    // Add pulsing vignette effect reacting to audio
    float vignette = 1.0 - smoothstep(0.5, 1.2, length(p));
    color *= vignette + u_audio * 0.3;

    // Draw the black outlines based on the combined SDF distance
    float outline_thickness = 0.008 + u_audio * 0.015;
    float line_aa = 0.005;
    float line_mask = 1.0 - smoothstep(outline_thickness - line_aa, outline_thickness, abs(d));
    color = mix(color, float3(0.0), line_mask);

    return float4(color, 1.0);
}