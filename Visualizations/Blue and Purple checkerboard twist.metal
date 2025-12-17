#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Center and aspect-correct UVs to work in a square coordinate system
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // Convert to polar coordinates (radius and angle)
    float r = length(p);
    float angle = atan2(p.y, p.x);

    // Warp the angle based on distance from the center and time.
    // The strength of the warp is inversely proportional to the radius,
    // creating a strong swirl near the center that weakens outwards.
    float warp_strength = 0.6 / (r + 0.25);
    angle += warp_strength * u_time * 0.4;

    // Convert the warped polar coordinates back to Cartesian coordinates
    float2 warped_p = r * float2(cos(angle), sin(angle));

    // Create the checkerboard pattern from the warped coordinates
    float checker_scale = 12.0;
    float2 check_coords = floor(warped_p * checker_scale);
    float pattern = fmod(check_coords.x + check_coords.y, 2.0);

    // Define two colors for the gradient
    float3 blue = float3(0.1, 0.2, 0.9);
    float3 purple = float3(0.7, 0.1, 0.8);

    // Cycle between the colors over time using a sine wave for a smooth transition
    float t = 0.5 + 0.5 * sin(u_time * 0.8);
    float3 color1 = mix(blue, purple, t);
    float3 color2 = mix(purple, blue, t);

    // Apply the cycling colors to the checkerboard pattern
    float3 color = mix(color1, color2, pattern);

    // Create the "black hole" at the center by smoothly fading to black
    // The smoothstep function creates a soft edge for the hole.
    float hole_fade = smoothstep(0.05, 0.1, r);
    color = mix(float3(0.0), color, hole_fade);

    return float4(color, 1.0);
}