// Prompt: Please create a shader that displays a  Christian cross in the center with multiple colored bands surrounding it that stretch from the cross to the outer edges of the screen. Use a orange and yellow color palette(represents the sun). The shader should cycle through the color palette by setting the color of the radiating bands to the new color, giving the sense of colors eminating from the cross in the center.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Coordinate setup
    // Center coordinates and correct for screen aspect ratio
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    // 2. Define color palette
    float3 color_yellow = float3(1.0, 0.85, 0.2);
    float3 color_orange = float3(1.0, 0.5, 0.0);
    float3 cross_color = float3(1.0, 1.0, 0.9);

    // 3. Create radiating background bands
    // Get angle and distance from center
    float angle = atan2(p.y, p.x);
    float dist = length(p);

    // Create a rotating wave pattern based on the angle
    float num_bands = 10.0;
    float band_speed = 1.5;
    float wave = sin(angle * num_bands - u_time * band_speed * 2.0);
    
    // Sharpen the sine wave to create more distinct bands
    float band_factor = smoothstep(-0.25, 0.25, wave);

    // Mix between the two main colors to create the bands
    float3 band_color = mix(color_yellow, color_orange, band_factor);
    
    // Make the bands brighter near the center and fade out
    band_color *= (1.0 - smoothstep(0.0, 1.8, dist)) * 0.7 + 0.3;

    // 4. Create the cross shape using Signed Distance Functions (SDF)
    // Define the dimensions of the Christian cross
    float cross_v_height = 0.4;
    float cross_h_length = 0.3;
    float cross_thickness = 0.05;
    float cross_y_offset = 0.08; // Offset the horizontal bar upwards

    // SDF for the vertical bar (centered at origin)
    float2 size_v = float2(cross_thickness, cross_v_height);
    float sdf_v = max(abs(p.x) - size_v.x, abs(p.y) - size_v.y);
    
    // SDF for the horizontal bar (shifted up)
    float2 p_h = p - float2(0.0, cross_y_offset);
    float2 size_h = float2(cross_h_length, cross_thickness);
    float sdf_h = max(abs(p_h.x) - size_h.x, abs(p_h.y) - size_h.y);

    // Combine the two bars to form the cross shape (union)
    float cross_sdf = min(sdf_v, sdf_h);

    // 5. Composite the final image
    // Create a soft glow around the cross
    float glow_mask = 1.0 - smoothstep(0.0, 0.06, cross_sdf);
    
    // Create the solid shape of the cross with anti-aliasing
    float cross_mask = 1.0 - smoothstep(-0.005, 0.005, cross_sdf);
    
    // First, apply the glow to the background bands
    float3 color = mix(band_color, cross_color, glow_mask * 0.4);
    
    // Then, draw the solid cross on top
    color = mix(color, cross_color, cross_mask);
    
    return float4(color, 1.0);
}