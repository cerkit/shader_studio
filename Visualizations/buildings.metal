#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define HORIZON 0.48
#define FOCAL_LENGTH 0.8

// Helper functions for procedural generation
float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float2 hash2(float n) {
    return fract(sin(float2(n, n + 1.0)) * float2(43758.5453, 22578.1459));
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0;
    return mix(mix(hash1(n + 0.0), hash1(n + 1.0), f.x),
               mix(hash1(n + 57.0), hash1(n + 58.0), f.x), f.y);
}

// Function to draw the sky, sun, and clouds
float3 get_sky_color(float2 uv, float u_time) {
    float3 sky_color_top = float3(0.3, 0.0, 0.2);
    float3 sky_color_mid = float3(1.0, 0.3, 0.1);
    float3 sky_color_horizon = float3(1.0, 0.6, 0.2);

    float3 sky_color = mix(sky_color_horizon, sky_color_mid, smoothstep(HORIZON, HORIZON + 0.2, uv.y));
    sky_color = mix(sky_color, sky_color_top, smoothstep(HORIZON + 0.2, 1.0, uv.y));

    float2 sun_pos = float2(0.5, HORIZON + 0.08);
    float sun_dist = distance(uv, sun_pos);
    float sun = smoothstep(0.1, 0.09, sun_dist);
    float sun_glow = smoothstep(0.25, 0.0, sun_dist);

    float2 ray_uv = uv - sun_pos;
    float angle = atan2(ray_uv.y, ray_uv.x);
    float rays = pow(sin(angle * 12.0) * 0.5 + 0.5, 30.0) * sun_glow * (1.0 - uv.y);
    rays = smoothstep(0.0, 0.1, rays) * (1.0 - smoothstep(0.0, 0.1, sun_dist));

    float cloud_noise = noise(float2(uv.x * 4.0 - u_time * 0.02, uv.y * 2.0));
    float cloud_mask = smoothstep(0.5, 0.7, cloud_noise) * step(HORIZON + 0.05, uv.y);
    float3 cloud_color = mix(float3(0.9, 0.5, 0.3), float3(0.5, 0.2, 0.3), cloud_mask);
    
    float2 contrail_p = uv;
    contrail_p.x -= u_time * 0.1;
    float contrail = smoothstep(0.005, 0.0, abs(contrail_p.y - 0.7 + contrail_p.x * 0.1));
    contrail += smoothstep(0.005, 0.0, abs(contrail_p.y - 0.72 + contrail_p.x * 0.1));

    float3 final_color = sky_color;
    final_color = mix(final_color, cloud_color, cloud_mask * 0.7);
    final_color += float3(1.0, 0.7, 0.4) * sun_glow * 0.6;
    final_color += float3(1.0, 0.5, 0.2) * rays * 0.5;
    final_color += float3(1.0, 0.95, 0.9) * sun;
    final_color += contrail * float3(0.9, 0.8, 0.7) * 0.7;

    return final_color;
}

// Struct for building info
struct Building {
    float4 rect; // x, y, w, h in screen space
    float3 color;
    float id;
    bool is_wavy;
};

// Procedural building projection
Building get_building(float i, float z, constant float2& u_resolution, float u_time, float u_audio) {
    float id = i * 100.0 + z;
    float2 rnd = hash2(id);
    
    float x_world = i * 1.8 + (rnd.x - 0.5) * 0.5;
    float h_world = (2.0 + rnd.y * 5.0) * (0.8 + 0.2 * sin(id + u_time * 2.0));
    h_world *= (1.0 + u_audio * 0.3);
    float w_world = 0.9 + hash1(id * 2.3) * 0.8;
    float z_depth = z * 2.5 + 5.0;

    float y_top_screen = HORIZON + (h_world / z_depth) * FOCAL_LENGTH;
    float x_center_screen = 0.5 + (x_world / z_depth) * FOCAL_LENGTH;
    float w_screen = (w_world / z_depth) * FOCAL_LENGTH;
    
    float4 rect = float4(x_center_screen - w_screen / 2.0, HORIZON, w_screen, y_top_screen - HORIZON);
    
    float3 lit_color = mix(float3(0.8, 0.3, 0.1), float3(0.5, 0.3, 0.2), clamp(z/10.0, 0.0, 1.0));
    float3 shadow_color = mix(float3(0.2, 0.1, 0.3), float3(0.05, 0.02, 0.1), clamp(z/10.0, 0.0, 1.0));
    float3 bldg_color = (x_world > -0.2) ? lit_color : shadow_color;

    bool is_wavy = hash1(id * 1.23) > 0.6;

    return Building{rect, bldg_color, id, is_wavy};
}

// Renders the main scene (sky and buildings) for a given UV coordinate
float3 render_scene(float2 uv, constant float2& u_resolution, constant float& u_time, constant float& u_audio) {
    float3 color = get_sky_color(uv, u_time);
    
    // Draw buildings from back to front
    for (int z = 8; z >= 0; --z) {
        for (int i = -8; i <= 8; ++i) {
            if (i == 0) continue;
            Building b = get_building(float(i), float(z), u_resolution, u_time, u_audio);
            
            float local_u = (uv.x - b.rect.x) / b.rect.z;
            float local_v = (uv.y - b.rect.y) / b.rect.w;
            
            float wave = b.is_wavy ? sin(local_v * 25.0 + b.id) * 0.08 : 0.0;

            if (uv.y > b.rect.y && local_v < 1.0 && local_u > 0.0 && local_u < 1.0 && abs(local_u - 0.5) < 0.5 + wave) {
                float3 bldg_color = b.color;
                
                // Windows
                float window_v_coord = local_v * (15.0 + hash1(b.id * 2.34) * 10.0);
                if (hash1(floor(local_u*10.0) + floor(window_v_coord) * 100.0 + b.id) > 0.5) {
                    float window_pattern = step(0.2, fract(window_v_coord));
                    bldg_color = mix(bldg_color, float3(1.0, 0.8, 0.4), window_pattern * 0.9);
                }
                
                // Hatching lines for shadows
                if (i <= 0) {
                    float hatch = fmod(uv.x * 250.0 - uv.y * 350.0, 4.0) > 3.0 ? 0.2 : 0.0;
                    bldg_color -= hatch;
                }

                float outline_thickness_u = 2.0 / u_resolution.x / b.rect.z;
                float outline_thickness_v = 2.0 / u_resolution.y / b.rect.w;
                float outline = smoothstep(0.0, outline_thickness_v, local_v) *
                                smoothstep(1.0, 1.0 - outline_thickness_v, local_v) *
                                smoothstep(0.0, outline_thickness_u, local_u) *
                                smoothstep(1.0, 1.0 - outline_thickness_u, local_u);
                
                color = mix(float3(0.0), bldg_color, outline);
            }
        }
    }
    return color;
}


fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]],
                              constant float& u_audio [[buffer(2)]]) {
    float2 uv = in.uv;
    float3 final_color;

    if (uv.y < HORIZON) {
        // --- Road & Reflection Section ---
        float2 p = uv - float2(0.5, HORIZON);
        float pz = 1.0 / (-p.y + 0.01);
        float px = p.x / (-p.y + 0.01);
        
        float road_y = 1.0 - (uv.y / HORIZON);

        // Render reflection
        float2 refl_uv = uv;
        refl_uv.y = HORIZON + (HORIZON - uv.y) * 0.7;
        float3 reflection_color = render_scene(refl_uv, u_resolution, u_time, u_audio);
        reflection_color = mix(reflection_color, float3(0.3, 0.2, 0.4), 0.3); // Tint reflection

        // Base road color and mix with reflection
        float3 road_color = mix(float3(0.9, 0.4, 0.2), float3(0.3, 0.1, 0.2), road_y * 1.2);
        final_color = mix(road_color, reflection_color, 0.5 * pow(1.0 - road_y, 2.0));
        
        // Road lines
        float lane_pos1 = 0.1, lane_pos2 = 0.2, line_width = 0.02;
        float is_line_area = step(abs(px), lane_pos1 + line_width) - step(abs(px), lane_pos1);
        is_line_area += step(abs(px), lane_pos2 + line_width) - step(abs(px), lane_pos2);
        float dash_pattern = step(0.5, fract(pz * 0.04));
        final_color = mix(final_color, float3(0.9, 0.8, 0.6), is_line_area * dash_pattern * 0.9);
        
        // Road texture/hatching
        float road_hatch = fmod((uv.x - 0.5) * 600.0, 5.0) > 4.5 ? -0.1 : 0.0;
        final_color += road_hatch;
        
    } else {
        // --- Sky & City Section ---
        final_color = render_scene(uv, u_resolution, u_time, u_audio);
    }
    
    // --- Overpass (drawn on top of everything) ---
    float overpass_y = 0.45;
    float overpass_thickness = 0.035;
    if (uv.y > overpass_y && uv.y < overpass_y + overpass_thickness) {
         float y_norm = (uv.y - overpass_y) / overpass_thickness;
         float3 bridge_color = float3(0.1, 0.08, 0.12);
         if (y_norm > 0.9 || (y_norm > 0.0 && y_norm < 0.1) ) bridge_color *= 0.7; // Guard rails
         
         final_color = mix(final_color, bridge_color, 0.8);
         if (abs(y_norm-0.5) > 0.48) final_color = float3(0.0); // Outline
    }

    // Final color grading
    final_color = pow(final_color, float3(0.95));
    final_color = clamp(final_color, 0.0, 1.0);
    
    return float4(final_color, 1.0);
}