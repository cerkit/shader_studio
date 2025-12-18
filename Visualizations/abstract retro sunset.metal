#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359

// Simple random function for texture and grain
float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]],
                              constant float& u_audio [[buffer(2)]]) {
    float2 uv = in.uv;
    
    // 1. Setup normalized coordinates with aspect ratio correction
    float2 p = (2.0 * uv - 1.0);
    p.x *= u_resolution.x / u_resolution.y;

    float3 color = float3(0.0);
    
    // 2. Define color palette
    float3 PURPLE = float3(0.6, 0.1, 1.0);
    float3 BLUE = float3(0.1, 0.2, 0.8);
    float3 RED = float3(1.0, 0.2, 0.2);
    float3 ORANGE = float3(1.0, 0.6, 0.0);
    float3 YELLOW = float3(1.0, 0.9, 0.4);
    float3 BLACK_INK = float3(0.05, 0.0, 0.1);
    float3 DARK_PURPLE = float3(0.2, 0.0, 0.3);
    
    // 3. Draw Sky Gradient
    float sky_y = p.y;
    float sky_grad = smoothstep(-0.05, 0.8, sky_y);
    float3 sky_color = mix(RED, DARK_PURPLE, sky_grad);
    color = sky_color;
    
    // 4. Draw Sun
    float sun_size = 0.25 + u_audio * 0.03;
    float2 sun_pos = float2(0.0, 0.2);
    float sun_dist = length(p - sun_pos);
    
    float sun_disc = smoothstep(sun_size, sun_size - 0.01, sun_dist);
    float sun_glow = smoothstep(sun_size + 0.3, sun_size - 0.1, sun_dist);

    float3 sun_color = mix(ORANGE, YELLOW, smoothstep(sun_size * 0.7, 0.0, sun_dist));
    
    color = mix(color, sun_color * 1.2, sun_glow);
    color = mix(color, sun_color, sun_disc);
    
    if (sun_disc > 0.0) {
        color *= 1.0 - random(p * 200.0) * 0.2; // Sun texture
    }
    
    // 5. Draw Horizon Scanlines
    float horizon_band_y = (p.y + 0.05) / 0.25;
    if (horizon_band_y > 0.0 && horizon_band_y < 1.0) {
        float line_fade = pow(sin(horizon_band_y * PI), 0.5);
        float lines = pow(abs(sin(p.y * 100.0)), 1.5);
        color = mix(color, RED * 1.5, lines * 0.6 * line_fade);
    }
    
    // 6. Draw Floor Grid
    if (p.y < 0.0) {
        // Simple ray-plane intersection for perspective
        float3 cam_pos = float3(0.0, 0.4, 0.0);
        float3 ray_dir = normalize(float3(p.x, p.y + 0.5, 1.2));
        
        float3 floor_color;
        if (ray_dir.y < -0.01) { // Only draw if ray is pointing down
            float t = -cam_pos.y / ray_dir.y;
            float3 floor_pos = cam_pos + t * ray_dir;
            
            // Animate grid
            floor_pos.z -= u_time * 2.5;

            // Grid lines
            float line_thickness = 0.04 / (1.0 + floor_pos.z * 0.5);
            
            float dist_x = abs(fract(floor_pos.x * 0.5 + 0.5) - 0.5);
            float dist_y = abs(fract(floor_pos.z) - 0.5);
            
            float grid_lines_val = smoothstep(line_thickness, 0.0, min(dist_x, dist_y));

            // Grid color and fade
            float grid_fade = smoothstep(15.0, 3.0, t);
            float3 grid_cell_color = mix(BLUE, PURPLE, smoothstep(0.0, -0.6, p.y)) * grid_fade;
            
            // Grid line glow
            float grid_glow_val = pow(1.0 - smoothstep(0.0, 0.25, min(dist_x, dist_y)), 6.0);
            grid_cell_color += PURPLE * grid_glow_val * 0.8 * grid_fade;
            
            floor_color = mix(grid_cell_color, BLACK_INK, grid_lines_val);
        } else {
            floor_color = color; // Use sky color if ray misses floor
        }
        
        // Blend sky reflection and floor at the horizon
        float horizon_blend = smoothstep(0.0, -0.05, p.y);
        color = mix(color, floor_color, horizon_blend);
    }

    // 7. Post-processing: Comic book effect (Halftone + Hatching)
    float luma = dot(color, float3(0.299, 0.587, 0.114)) + 0.05;

    // Halftone dots
    float2 screen_grid_uv = fract(uv * u_resolution / 3.0);
    float dot_dist = length(screen_grid_uv - 0.5);
    float dot_radius = sqrt(1.0 - luma) * 0.7; // Dark colors get large dots
    float dots = 1.0 - smoothstep(dot_radius, dot_radius - 0.05, dot_dist);

    // Hatching lines for the sky
    float hatch = 0.0;
    if (p.y > 0.05) {
       float2 rot_p = float2x2(cos(0.4), -sin(0.4), sin(0.4), cos(0.4)) * p;
       hatch = smoothstep(0.9, 1.0, abs(sin(rot_p.x * 120.0))) * (1.0 - luma);
    }
    
    // Combine comic effects and apply to color
    float comic_mask = saturate(dots + hatch * 0.7);
    color = mix(color, BLACK_INK, comic_mask * 0.8);
    
    // Add subtle film grain
    color += (random(uv * u_time) - 0.5) * 0.04;
    
    return float4(saturate(color), 1.0);
}