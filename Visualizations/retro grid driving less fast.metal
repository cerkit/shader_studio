#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. COORDINATE SETUP
    // Remap uv from [0,1] to a centered, aspect-corrected coordinate system [-a,a]x[-1,1]
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    float3 color = float3(0.0);

    // 2. BOTTOM HALF OF SCREEN: The moving grid
    if (p.y < 0.0) {
        // Inverse perspective mapping to get a ground plane.
        // This simulates a camera looking forward over a plane.
        // p.y is negative here, so -p.y is positive.
        float2 ground_pos = float2(p.x, 1.0) / -p.y;

        // Animate grid movement towards the viewer
        ground_pos.y -= u_time * 0.25;

        // Calculate anti-aliased grid lines using derivatives
        float2 coord = ground_pos * 1.25;//2.0;
        float2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
        float line = min(grid.x, grid.y);
        
        // Make the lines glow, clamping to avoid artifacts
        float grid_intensity = pow(1.0 - saturate(line), 2.0);

        // A classic synthwave purple for the grid
        float3 grid_color = float3(0.8, 0.1, 1.0);

        // Fade the grid into the distance (towards the horizon at p.y = 0)
        float fade = exp(p.y * 2.5);
        
        color = grid_color * grid_intensity * fade;
    }
    // 3. TOP HALF OF SCREEN: Sky, sun, and horizon lines
    else {
        // Background sky gradient: pinkish at the horizon, dark purple at the top
        color = mix(float3(0.9, 0.3, 0.4), float3(0.2, 0.0, 0.3), p.y);
        
        // The Sun
        float2 sun_pos = float2(0.0, 0.3);
        float sun_radius = 0.22;
        float d = distance(p, sun_pos);
        
        // Sun disk and its outer glow
        float sun_disk = smoothstep(sun_radius, sun_radius - 0.01, d);
        float sun_glow = smoothstep(sun_radius + 0.4, sun_radius, d);
        
        // Yellow/orange sun color, additively blended
        float3 sun_color = float3(1.0, 0.9, 0.5) * sun_disk;
        sun_color += float3(1.0, 0.6, 0.3) * sun_glow * 0.4;
        color += sun_color;
        
        // Multi-colored horizontal lines on the horizon below the sun
        float line_region = step(0.0, p.y) * (1.0 - step(0.25, p.y));
        if (line_region > 0.5) {
            float y_norm = p.y / 0.25; // Normalize y in the line region
            float num_lines = 8.0;
            
            // Create sharp glowing lines
            float line_pattern = pow(1.0 - abs(fract(y_norm * num_lines) * 2.0 - 1.0), 10.0);
            
            // Fade lines in and out at the edges of the region
            line_pattern *= smoothstep(0.0, 0.1, y_norm) * smoothstep(1.0, 0.9, y_norm);
            
            // Color gradient for the lines from pink to orange
            float3 horizon_line_color = mix(float3(1.0, 0.2, 0.5), float3(1.0, 0.6, 0.3), y_norm);
            
            // Additively blend the lines onto the scene
            color += horizon_line_color * line_pattern * 0.7;
        }
    }

    // A subtle vignette effect to darken the corners
    color *= 1.0 - pow(length(uv - 0.5) * 1.2, 2.0);

    // Final color, clamped to the valid [0,1] range
    return float4(saturate(color), 1.0);
}