/*************************************************
Circular geometry flyby that loops over 10 seconds
**************************************************/


#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define LOOP_DURATION 10.0
#define REPEAT_LENGTH 5.0
#define MAX_STEPS 80
#define MAX_DIST 100.0
#define HIT_THRESHOLD 0.001
#define FOG_DENSITY 0.08

// Signed distance function for a Torus
float sdTorus(float3 p, float2 t) {
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Rotation matrix for a 2D vector
float2x2 rotate2d(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(c, -s, s, c);
}

// Defines the entire scene geometry
float sceneSDF(float3 p, constant float& u_time) {
    // We use a modified time that loops to ensure the animation is seamless
    float time = fmod(u_time, LOOP_DURATION);

    // Create a repeating effect for an infinite tunnel
    float3 p_mod = p;
    p_mod.z = fmod(p.z, REPEAT_LENGTH) - 0.5 * REPEAT_LENGTH;

    // Rotate the tunnel segments over time
    float angle = time * (2.0 * PI / LOOP_DURATION);
    p_mod.xy = p_mod.xy * rotate2d(angle);

    // The tunnel is made of two perpendicular tori, creating a wireframe-like link
    float2 torus_params = float2(1.2, 0.08); // Major radius, minor radius
    float d1 = sdTorus(p_mod, torus_params);
    float d2 = sdTorus(p_mod.yxz, torus_params); // Same torus, but with x and y swapped

    return min(d1, d2);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Setup Coordinates
    // Normalize and correct for aspect ratio
    float2 p = (2.0 * uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);

    // 2. Setup Camera
    float time = fmod(u_time, LOOP_DURATION);

    // Camera Position (ro)
    // Forward motion: move through 2 segments over the loop duration for a seamless loop
    float z_motion = time * (2.0 * REPEAT_LENGTH / LOOP_DURATION);
    
    // Wobble motion: Use sine waves with different frequencies for a smooth, non-circular path
    // The frequencies are integer multiples of (2*PI/LOOP_DURATION) to ensure the camera
    // starts and ends at the same x,y position.
    float wobble_x = 0.4 * sin(time * 2.0 * PI / LOOP_DURATION);
    float wobble_y = 0.4 * sin(time * 4.0 * PI / LOOP_DURATION);
    
    float3 ro = float3(wobble_x, wobble_y, z_motion);

    // Camera Direction (rd)
    // Point the camera forward along the Z axis from its current position
    float3 target = ro + float3(0.0, 0.0, 1.0);
    float3 fwd = normalize(target - ro);
    float3 right = normalize(cross(fwd, float3(0.0, 1.0, 0.0)));
    float3 up = normalize(cross(right, fwd));
    float3 rd = normalize(fwd + p.x * right + p.y * up);

    // 3. Raymarching
    float t = 0.0;
    float3 color = float3(0.0);
    
    for (int i = 0; i < MAX_STEPS; i++) {
        float3 pos = ro + rd * t;
        float d = sceneSDF(pos, u_time);
        
        if (d < HIT_THRESHOLD) {
            // We hit a surface
            float3 base_color = float3(0.5, 0.1, 1.0); // Base purple
            float3 bright_color = float3(1.0, 0.4, 0.8); // Brighter pink/purple
            
            // Vary color based on position in the tunnel to create patterns
            float z_pattern = 0.5 + 0.5 * sin(pos.z * 1.5);
            float xy_pattern = 0.5 + 0.5 * cos(pos.x * 2.0 - pos.y * 2.0);
            
            float3 hit_color = mix(base_color, bright_color, z_pattern * xy_pattern);
            
            // Add a simple glow effect based on how close the hit was (fewer steps = brighter)
            float glow = pow(1.0 - float(i) / float(MAX_STEPS), 2.0);
            color = hit_color * glow;
            break;
        }
        
        t += d;
        
        if (t > MAX_DIST) {
            // Ray escaped the scene
            break;
        }
    }

    // 4. Fog
    // Add atmospheric perspective with a dark purple fog
    float3 fog_color = float3(0.05, 0.0, 0.1);
    color = mix(color, fog_color, 1.0 - exp(-FOG_DENSITY * t));
    
    return float4(color, 1.0);
}