// Prompt: Generate a grayscale image of horizontal bars using 20 shades of gray. It should look like the old raster graphics on the Commodore 64 home computer. Cycle through the gray shades. There should not be any sudden shade changes, so the grayscale bars should cycle between dark to light and back to dark again, without sudden shade changes.

#include <metal_stdlib>
using namespace metal;

#define NUM_BARS 20.0
#define NUM_SHADES 20.0

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;

    // Determine which horizontal bar we are in (from 0 to NUM_BARS-1)
    float bar_index = floor(uv.y * NUM_BARS);

    // Create a smoothly oscillating value based on time and the bar's index.
    // The sine wave ensures a smooth cycle from dark to light and back to dark.
    // (sin(...) + 1.0) * 0.5 maps the sine's [-1, 1] output range to [0, 1].
    float cycle_speed = 2.0;
    float bar_phase_shift = 0.4;
    float continuous_value = (sin(u_time * cycle_speed + bar_index * bar_phase_shift) + 1.0) * 0.5;

    // Quantize the continuous value into a fixed number of discrete gray shades.
    // This creates the distinct "raster" bar effect.
    // The formula round(value * (N-1)) / (N-1) maps a value in [0,1] to N discrete steps.
    float gray_shade = round(continuous_value * (NUM_SHADES - 1.0)) / (NUM_SHADES - 1.0);

    // Create the final grayscale color
    float3 color = float3(gray_shade);
    
    return float4(color, 1.0);
}