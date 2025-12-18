#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]],
                              constant float& u_audio [[buffer(2)]]) {
    float2 uv = in.uv;
    
    // Create a centered, aspect-corrected coordinate system from -1 to 1
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u_resolution.x / u_resolution.y;
    
    // Mirror across both axes by taking the absolute value.
    // This effectively renders one quadrant and mirrors it to the other three.
    p = abs(p);
    
    // Vertically center the coordinate system for the line in the mirrored quadrant.
    p.y -= 0.5;

    // Define the scrolling heartbeat line as a function of x
    float time_scroll = u_time * 2.5;
    float period = 5.0;
    float freq = 6.0;
    float x_mod = fmod(p.x * freq - time_scroll, period);
    
    // Make the audio response more pronounced for louder sounds
    float audio_curve = pow(u_audio, 1.5);

    // The main spike ("R wave")
    // Sharpness is controlled by audio: high audio -> sharp spike (low exponent)
    float main_sharpness = mix(4.0, 0.8, audio_curve);
    // Height is controlled by audio
    float main_height = mix(0.1, 0.5, u_audio);
    float main_pulse = main_height * exp(-pow(abs(x_mod - 2.5), main_sharpness));

    // A secondary, smaller, and consistently rounded wave ("T wave")
    float second_height = main_height * 0.4;
    float second_pulse = second_height * exp(-pow(abs(x_mod - 3.5), 3.0));

    float y_line = main_pulse + second_pulse;

    // Calculate the vertical distance from the current pixel to the line
    float dist = abs(p.y - y_line);

    // Create two layers for the line effect: a wide glow and a sharp core
    float glow = exp(-dist * 25.0);
    float core = exp(-dist * 200.0);

    // Define colors: Orange/Red for the glow, bright yellow for the core
    float3 glow_color = mix(float3(1.0, 0.3, 0.0), float3(1.0, 0.1, 0.0), u_audio);
    float3 core_color = float3(1.0, 1.0, 0.7);

    // Combine colors using additive blending for a bright, glowing effect
    float3 color = glow_color * glow + core_color * core;
    
    // Add a faint, persistent horizontal baseline
    float baseline_dist = abs(p.y);
    float baseline = exp(-baseline_dist * 100.0) * 0.08;
    color += glow_color * baseline;

    return float4(color, 1.0);
}