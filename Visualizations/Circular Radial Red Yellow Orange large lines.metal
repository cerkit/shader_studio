// Prompt: The background should radiate from the bottom-middle of the image to the outside edges of the image in a starburst pattern. make the radial lines red, yellow, and orange. THe radiating lines should be animated to cycle between each of the colors. The lines should be thick.

#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Center coordinates at the bottom-middle of the screen
    float2 p = uv - float2(0.5, 0.0);
    // Correct for aspect ratio to make rays circular instead of skewed
    p.x *= u_resolution.x / u_resolution.y;

    // Convert to polar coordinates to get the angle for each pixel
    float angle = atan2(p.y, p.x);
    
    // Number of radiating lines (the pattern is mirrored, so we get double this number)
    float num_lines = 16.0;
    
    // Create the radial pattern using the sine of the angle
    // The absolute value creates the repeating "beam" effect
    float raw_pattern = abs(sin(angle * num_lines));
    
    // Use smoothstep to create thick, anti-aliased lines.
    // The first parameter (0.7) controls the thickness: a lower value means a thicker line.
    // The small gap between the two parameters (0.7 and 0.75) creates a soft edge.
    float line_mask = smoothstep(0.7, 0.75, raw_pattern);

    // Define the color palette
    float3 red = float3(1.0, 0.1, 0.1);
    float3 yellow = float3(1.0, 0.9, 0.1);
    float3 orange = float3(1.0, 0.5, 0.0);

    // Create a time value that cycles smoothly between 0.0 and 3.0
    float t = fmod(u_time * 0.5, 3.0);
    
    float3 animated_color;
    // Linearly interpolate (mix) between the three colors over the 3-second cycle
    if (t < 1.0) {
        animated_color = mix(red, yellow, t);
    } else if (t < 2.0) {
        animated_color = mix(yellow, orange, t - 1.0);
    } else {
        animated_color = mix(orange, red, t - 2.0);
    }

    // Set the background color to black
    float3 background_color = float3(0.0);
    
    // Combine the background color and the line color using the line mask
    // Where the mask is 0, we see the background. Where it's 1, we see the line color.
    float3 color = mix(background_color, animated_color, line_mask);
    
    return float4(color, 1.0);
}