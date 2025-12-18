#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359

// A simple 2D noise function.
float noise(float2 st) {
    return fract(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]],
                              constant float& u_audio [[buffer(2)]]) {
    // 1. Setup coordinates
    // Normalize and aspect-correct coordinates, with (0,0) at the center.
    float2 p = (2.0 * in.uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;
    
    // Mirror the scene on the horizontal axis by taking the absolute value of p.y.
    // This makes the bottom half of the screen a reflection of the top half.
    p.y = abs(p.y);

    // 2. Audio and Time dependent parameters
    float time = u_time * 0.5;
    // Smooth the audio input with a sine wave to create a calmer, pulsing effect.
    float audio_pulse = u_audio * (0.5 + 0.5 * sin(u_time * 4.0));

    // Apply a "liquid" distortion to the coordinates for a flowing effect.
    float2 p_distort = p;
    p_distort += 0.02 * float2(sin(p.y * 10.0 + time * 2.0), cos(p.x * 10.0 - time * 2.0));

    float r = length(p_distort);
    float a = atan2(p_distort.y, p_distort.x);

    // Dynamic radii and amplitudes based on audio.
    float inner_rad = 0.4 - 0.1 * audio_pulse;
    float outer_rad = 0.7 + 0.1 * audio_pulse;
    float orbit_rad = 0.55;
    float circle_rad = 0.05 + 0.03 * audio_pulse;
    float wave_amp = 0.04 + 0.08 * u_audio;

    // 3. Define the scene distance field (SDF) for drawing the black lines.
    // We will find the minimum distance to any line element.
    float d = 1e6;

    // a. Concentric rings
    d = min(d, abs(r - inner_rad));
    d = min(d, abs(r - outer_rad));
    
    // b. Radiating spokes (8 spokes)
    // Only draw spokes outside the main rings.
    if (r > outer_rad || r < inner_rad) {
        float angle_repeat = PI / 4.0; // 2*PI / 8 spokes
        float mod_a = fmod(a + angle_repeat * 0.5, angle_repeat) - angle_repeat * 0.5;
        // The distance to a line through the origin in a repeated angular sector.
        float spoke_d = abs(sin(mod_a) * r);
        d = min(d, spoke_d);
    }

    // c. Small circles (10 circles) using polar domain repetition for efficiency.
    float num_circles = 10.0;
    float angle_step = 2.0 * PI / num_circles;
    float rotated_a = a + time * 0.4;
    float mod_circle_a = fmod(rotated_a + angle_step * 0.5, angle_step) - angle_step * 0.5;
    float2 p_circle_frame = float2(r * cos(mod_circle_a), r * sin(mod_circle_a));
    // SDF for one circle in the repeated frame.
    float small_circles_d = length(p_circle_frame - float2(orbit_rad, 0.0)) - circle_rad;
    d = min(d, abs(small_circles_d));

    // d. Wavy horizontal band
    float wave = wave_amp * (sin(p.x * 2.5 + time) + 0.5 * cos(p.x * 5.0 - time * 0.8));
    float band_height = 0.07;
    // SDF for the two edges of the band.
    d = min(d, abs(p_distort.y - (wave + band_height)));
    d = min(d, abs(p_distort.y - (wave - band_height)));

    // 4. Determine background color based on position.
    float3 color_cyan = float3(0.1, 0.8, 0.9);
    float3 color_blue = float3(0.2, 0.2, 0.9);
    float3 color_purple = float3(0.6, 0.1, 0.8);

    // Base color is a radial gradient from blue to purple to cyan.
    float3 color = mix(color_blue, color_purple, smoothstep(inner_rad, outer_rad, r));
    color = mix(color, color_cyan, smoothstep(outer_rad, outer_rad + 0.4, r));
    
    // Add angular color variation for the "petal" effect.
    float angle_color_mix = 0.5 + 0.5 * sin(a * 4.0 + time * 0.5);
    color = mix(color, color_purple, angle_color_mix * 0.4);

    // Override the color for the area inside the wavy band.
    if (abs(p_distort.y - wave) < band_height) {
        float band_uv = (p_distort.y - (wave - band_height)) / (2.0 * band_height);
        color = mix(color_blue, color_cyan, band_uv * 1.2);
    }
    
    // 5. Compose the final image.
    // Perturb the distance field with noise to create a wobbly, hand-drawn line style.
    d -= noise(in.uv * 150.0) * 0.006;

    // Draw the lines using the SDF.
    float line_thickness = 0.01;
    float line = 1.0 - smoothstep(0.0, line_thickness, d);

    // Mix the background color with the line color (a dark purple).
    color = mix(color, float3(0.1, 0.0, 0.15), line);

    return float4(color, 1.0);
}