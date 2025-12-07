// Prompt: The background should radiate from the bottom-middle of the image to the outside edges of the image in a starburst pattern. make the radial lines red, yellow, and orange. THe radiating lines should be animated to cycle between each of the colors. The lines should be thick. The lines should rotate smoothly and slowly.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define NUM_LINES 24.0
#define ROTATION_SPEED 0.1
#define COLOR_CYCLE_SPEED 0.4

// Helper function to create a cycling color palette from red to orange to yellow and back.
float3 palette(float t) {
    float3 red    = float3(1.0, 0.1, 0.0);
    float3 orange = float3(1.0, 0.5, 0.0);
    float3 yellow = float3(1.0, 0.9, 0.0);

    // Make the cycle loop every 3 units of t
    t = fmod(t, 3.0);

    if (t < 1.0) {
        // Fade from red to orange
        return mix(red, orange, t);
    } else if (t < 2.0) {
        // Fade from orange to yellow
        return mix(orange, yellow, t - 1.0);
    } else {
        // Fade from yellow back to red
        return mix(yellow, red, t - 2.0);
    }
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv; // uv is already normalized 0..1 from vertex shader
    
    // 1. Center coordinates at the bottom-middle of the screen
    float2 p = uv - float2(0.5, 0.0);
    
    // 2. Correct for aspect ratio to make the pattern circular
    p.x *= u_resolution.x / u_resolution.y;

    // 3. Convert to polar coordinates (angle) and apply slow rotation
    float angle = atan2(p.y, p.x);
    angle += u_time * ROTATION_SPEED;

    // 4. Create the starburst pattern using a cosine wave based on the angle
    float wave = cos(angle * NUM_LINES);
    
    // 5. Use smoothstep to shape the wave into thick, soft-edged lines.
    // By using a threshold below 0, we make the bright parts of the wave (the lines)
    // wider than the dark parts.
    float line_intensity = smoothstep(-0.3, -0.25, wave);

    // 6. Get the current color from our animated palette
    float3 line_color = palette(u_time * COLOR_CYCLE_SPEED);

    // 7. Combine the line shape (intensity) with the line color
    float3 color = line_color * line_intensity;
    
    return float4(color, 1.0);
}