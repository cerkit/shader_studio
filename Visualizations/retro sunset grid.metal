// Prompt: please create a shader that has a grid on the bottom half of the screen. The camera should move forward along the grid and the grid should move as if we are traveling over it. Make a 80’s retro sunset on the horizon. Use colors similar to a retro 80’s synthwave music video.

#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Create a centered, aspect-corrected coordinate system
    // (0,0) is center, Y is up
    float2 st = (2.0 * uv - 1.0);
    st.x *= u_resolution.x / u_resolution.y;

    float3 color = float3(0.0);
    float horizon_y = 0.0;

    if (st.y > horizon_y) {
        // --- SKY AND SUN ---
        
        // Normalize y coordinate for the sky part (0 at horizon, grows upwards)
        float sky_y = st.y;

        // Background sky gradient
        float3 sky_top_color = float3(0.1, 0.0, 0.2); // Deep Purple
        float3 sky_horizon_color = float3(1.0, 0.3, 0.4); // Pinkish-Orange
        color = mix(sky_horizon_color, sky_top_color, smoothstep(0.0, 0.6, sky_y));

        // Sun
        float2 sun_pos = float2(0.0, 0.1);
        float sun_dist = distance(st, sun_pos);

        // Sun's glowing corona
        float sun_glow = smoothstep(0.25, 0.0, sun_dist);
        color = mix(color, float3(1.0, 0.8, 0.4), sun_glow * 0.8);

        // Sun's bright core
        float sun_core = smoothstep(0.08, 0.075, sun_dist);
        color = mix(color, float3(1.0, 1.0, 0.9), sun_core);
        
        // Horizontal scan lines across the sun for that retro CRT look
        float sun_mask_for_lines = sun_glow * 0.7;
        float line_freq = 80.0;
        float lines = sin((st.y - sun_pos.y) * line_freq) * 0.5 + 0.5;
        lines = smoothstep(0.8, 1.0, lines);
        color *= 1.0 - lines * sun_mask_for_lines;

    } else {
        // --- GROUND GRID ---
        
        // Perspective Projection: transform screen space to a 3D ground plane
        // The y-coordinate is inverted and used to create depth.
        // The closer to the horizon (st.y -> 0), the further away the point is.
        float camera_height = 0.4;
        float depth = camera_height / (-st.y + 0.01); // Add epsilon to avoid division by zero
        
        // Create 2D coordinates for the ground plane
        float2 ground_pos = float2(st.x * depth, depth);

        // Animate the camera moving forward by offsetting the z-coordinate (ground_pos.y)
        float speed = 3.0;
        ground_pos.y += u_time * speed;

        // --- Draw the grid ---
        float grid_scale = 1.0;
        float2 grid_uv = fract(ground_pos * grid_scale);
        
        // Use derivatives (fwidth) for anti-aliased lines of constant screen-space thickness
        float2 grid_deriv = fwidth(ground_pos * grid_scale);
        
        // Calculate distance to nearest grid line
        float2 dist_to_line = min(grid_uv, 1.0 - grid_uv);
        
        // Create smooth lines using the distance and derivative
        float2 grid_lines = smoothstep(grid_deriv * 1.5, float2(0.0), dist_to_line);
        
        // Combine horizontal and vertical lines. max() gives bright intersections.
        float grid_intensity = max(grid_lines.x, grid_lines.y);
        
        // --- Color the grid ---
        float3 grid_color = float3(1.0, 0.2, 0.8); // Bright Magenta
        color = grid_color * grid_intensity;
        
        // Add a secondary color for horizontal lines to make them distinct
        float3 h_line_color = float3(0.2, 0.8, 1.0); // Bright Cyan
        color = mix(color, h_line_color, grid_lines.x);

        // --- Fog ---
        // Fade the grid to black as it approaches the horizon
        float fog = exp(-depth * 0.15);
        color *= fog;
    }
    
    return float4(color, 1.0);
}