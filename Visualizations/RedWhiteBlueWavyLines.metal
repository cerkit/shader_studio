// Prompt: Please generate wavy lines extending from the left edge to the right edge. The lines should be thick and resemble an American flag without the stars. There should be three colors: red, white, and blue. Make sure that the lines are symmetrical and that they wave in sync with each other like a sine wave.

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define NUM_STRIPES 12.0

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // --- Wave Parameters ---
    // Amplitude: How high the waves are (as a fraction of screen height)
    float amplitude = 0.05;
    // Frequency: How many waves appear across the screen
    float frequency = 3.0 * 2.0 * PI;
    // Speed: How fast the waves move
    float speed = 1.5;

    // Calculate the horizontal sine wave distortion
    float wave_offset = amplitude * sin(uv.x * frequency + u_time * speed);
    
    // Apply the wave to the vertical coordinate
    float wavy_y = uv.y + wave_offset;

    // --- Color and Stripe Logic ---
    
    // Define the three colors for the stripes
    float3 red   = float3(0.8, 0.1, 0.15);
    float3 white = float3(1.0, 1.0, 1.0);
    float3 blue  = float3(0.1, 0.2, 0.5);

    // Determine which stripe the current fragment is in based on the wavy coordinate
    float stripe_id = floor(wavy_y * NUM_STRIPES);
    
    // Determine the color index (0 for red, 1 for white, 2 for blue)
    int color_index = int(fmod(stripe_id, 3.0));
    
    // Ensure the modulus result is positive for a consistent pattern
    if (color_index < 0) {
        color_index += 3;
    }

    // Select the final color based on the index
    float3 color;
    if (color_index == 0) {
        color = red;
    } else if (color_index == 1) {
        color = white;
    } else {
        color = blue;
    }
    
    return float4(color, 1.0);
}