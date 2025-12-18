#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]],
                              constant float& u_audio [[buffer(2)]]) {
    float2 uv = in.uv; // uv is already normalized 0..1 from vertex shader
    
    // 1. Center coordinates, correct for aspect ratio, and mirror
    float2 st = (uv - 0.5) * 2.0; // Remap uv to [-1, 1]
    st.x *= u_resolution.x / u_resolution.y;
    st = abs(st); // Mirror on both axes, effectively working in one quadrant

    // 2. Calculate distance from the center for a circular shape
    float d = length(st);

    // 3. Define the circle's radius with pulsing effects
    // It pulses gently with time and reacts strongly to audio
    float time_pulse = sin(u_time * 6.0) * 0.05;
    float audio_pulse = u_audio * 0.4; // Strong audio reaction for size
    float radius = 0.3 + time_pulse + audio_pulse;
    
    // Create a smooth mask for the circle (1 inside, 0 outside)
    float circle_mask = smoothstep(radius + 0.1, radius, d);

    // 4. Create vibrant, pulsating colors (orange, red, yellow)
    // Generate color bands that move inwards over time
    float color_wave = sin(d * 15.0 - u_time * 8.0) * 0.5 + 0.5;
    
    // Define the fiery color palette
    float3 color_orange = float3(1.0, 0.4, 0.0);
    float3 color_yellow = float3(1.0, 0.9, 0.1);
    float3 color_red = float3(0.9, 0.1, 0.1);

    // Mix between orange and yellow to create the base pattern
    float3 color = mix(color_orange, color_yellow, color_wave);
    
    // On audio peaks, make the color flash towards red for an energetic feel
    color = mix(color, color_red, u_audio * 0.8); // Strong audio reaction for color

    // 5. Apply the circle mask to the generated color
    color *= circle_mask;
    
    return float4(color, 1.0);
}