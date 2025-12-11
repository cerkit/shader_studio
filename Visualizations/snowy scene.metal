// Prompt: Please create a wintery scene with a snow-covered hill on the horizon and procedural snowflakes moving from the top of the screen to the bottom.

#include <metal_stdlib>
using namespace metal;

// A simple pseudo-random number generator (hash function)
float hash(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // --- Background and Hill ---
    
    // Create a sky gradient
    float3 sky_color = mix(float3(0.1, 0.2, 0.4), float3(0.5, 0.7, 0.9), smoothstep(0.1, 0.7, uv.y));
    
    // Create a procedural snow-covered hill on the horizon
    float hill_height = 0.35 + 0.05 * sin(uv.x * 4.0) + 0.02 * cos(uv.x * 11.0 - 1.0);
    float3 ground_color = float3(0.9, 0.92, 1.0);
    
    // Blend sky and ground using a smooth step for a soft edge
    float hill_mask = smoothstep(hill_height - 0.005, hill_height + 0.005, uv.y);
    float3 scene_color = mix(ground_color, sky_color, hill_mask);
    
    // --- Snowflakes ---
    
    // Correct aspect ratio for snowflakes so they are not stretched
    float2 snow_uv = uv;
    snow_uv.x *= u_resolution.x / u_resolution.y;
    
    float snow = 0.0;
    float time = u_time * 0.25;

    // Create 3 layers of snowflakes for a parallax effect
    for (int i = 0; i < 3; ++i) {
        float depth = (float(i) + 1.0) / 3.0; // depth from 0.33 to 1.0
        
        // Deeper layers have smaller, slower, and more numerous flakes
        float scale = mix(20.0, 5.0, depth);
        float speed = mix(0.2, 0.6, depth);
        float size = mix(0.015, 0.035, depth);
        
        float2 p = snow_uv * scale;
        p.y += time * speed; // Animate falling
        
        float2 grid_id = floor(p);
        float2 cell_uv = fract(p);
        
        // Check current cell and its 8 neighbors to avoid flakes popping at edges
        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                float2 neighbor_id = grid_id + float2(x, y);
                
                // Get a random, stable position for a flake in this cell
                float2 flake_base_pos = float2(hash(neighbor_id), hash(neighbor_id.yx));
                
                // Add a gentle horizontal sway to the flakes
                float sway = sin(hash(neighbor_id) * 6.283 + time * (1.0 + hash(neighbor_id+1.0))) * 0.25;
                float2 flake_pos = flake_base_pos + float2(sway, 0.0);
                
                // Vector from the current pixel to the flake's center
                float2 offset = float2(x, y) - cell_uv + flake_pos;
                float dist = length(offset);
                
                // Use a random value to vary flake size slightly
                float flake_size = size * (0.6 + 0.4 * hash(neighbor_id + 42.0));
                
                // Draw a soft, circular flake
                snow += smoothstep(flake_size, flake_size * 0.7, dist);
            }
        }
    }
    
    snow = clamp(snow, 0.0, 1.0);
    
    // --- Combine Scene and Snow ---
    
    // Blend the white snowflakes over the background scene
    float3 color = mix(scene_color, float3(1.0), snow);
    
    return float4(color, 1.0);
}