#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define DURATION 20.0
#define MARCH_STEPS 100
#define MAX_DIST 100.0
#define HIT_DIST 0.001
#define REPEAT_Z 8.0

// Helper function to create a 2D rotation matrix
float2x2 rot(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(c, -s, s, c);
}

// Signed Distance Function for the fractal tunnel scene
float sceneSDF(float3 p, float loop_time) {
    // Twist the entire space along the Z axis for a spiral effect
    float twist_angle = p.z * 0.15 + loop_time * 0.1;
    p.xy = rot(twist_angle) * p.xy;

    // Repeat the geometry along the Z axis to create an infinite tunnel
    // fmod centers the repetition around the origin for the given length
    p.z = fmod(p.z + REPEAT_Z * 0.5, REPEAT_Z) - REPEAT_Z * 0.5;

    // Use polar coordinates for radial repetition around the Z axis
    float num_radial_repeats = 6.0;
    float angle_step = (2.0 * PI) / num_radial_repeats;
    float angle = atan2(p.y, p.x);
    float radius = length(p.xy);
    angle = fmod(angle + angle_step * 0.5, angle_step) - angle_step * 0.5;

    // Convert back to Cartesian coordinates, now within a single radial "slice"
    p.xy = float2(cos(angle), sin(angle)) * radius;

    // Define the fractal shape within the slice
    // Start by offsetting it from the center
    float3 offset = float3(2.8, 0.0, 0.0);
    float3 q = p - offset;

    // Animate the fractal's own rotation for a dynamic effect
    float fractal_angle = loop_time * PI * 0.25;
    q.xz = rot(fractal_angle) * q.xz;
    q.xy = rot(fractal_angle * 0.7) * q.xy;

    // The iterative folding process that creates the fractal detail
    float scale = 1.8;
    for(int i = 0; i < 4; ++i) {
        q = 2.0 * clamp(q, -0.9, 0.9) - q; // Box folding
        q *= scale;
    }

    // The final primitive shape is a sphere.
    // The distance is scaled back to provide a correct distance estimate.
    return (length(q) - 0.7) / pow(scale, 4.0);
}

// Function to calculate the normal vector at a point on the surface
float3 calcNormal(float3 p, float loop_time) {
    float2 e = float2(0.001, 0.0);
    float dx = sceneSDF(p + e.xyy, loop_time) - sceneSDF(p - e.xyy, loop_time);
    float dy = sceneSDF(p + e.yxy, loop_time) - sceneSDF(p - e.yxy, loop_time);
    float dz = sceneSDF(p + e.yyx, loop_time) - sceneSDF(p - e.yyx, loop_time);
    return normalize(float3(dx, dy, dz));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    
    // Normalize and aspect-correct the fragment coordinates
    float2 p = (2.0 * in.uv - 1.0) * float2(u_resolution.x / u_resolution.y, 1.0);

    // Time for seamless 20-second loop
    float loop_time = fmod(u_time, DURATION);

    // Camera setup
    // Move the camera forward along Z. The speed is set so that after DURATION seconds,
    // it has traveled exactly one repetition length, ensuring a seamless geometric loop.
    float cam_z = loop_time * (REPEAT_Z / DURATION);
    float3 ro = float3(0.0, 0.0, cam_z); // Ray origin
    float3 rd = normalize(float3(p, -1.5)); // Ray direction, -1.5 gives a wider field of view

    // Raymarching
    float t = 0.0; // Distance traveled along the ray
    for (int i = 0; i < MARCH_STEPS; ++i) {
        float3 pos = ro + t * rd;
        float d = sceneSDF(pos, loop_time);
        if (d < HIT_DIST) {
            break; // We hit something
        }
        t += d;
        if (t > MAX_DIST) {
            t = MAX_DIST; // We missed
            break;
        }
    }

    float3 color = float3(0.0);

    if (t < MAX_DIST) {
        // We hit the surface, calculate shading
        float3 pos = ro + t * rd;
        float3 normal = calcNormal(pos, loop_time);

        // --- Lighting ---
        float3 light_dir = normalize(float3(0.8, 0.5, -0.3));
        float diffuse = max(0.1, dot(normal, light_dir)); // Basic diffuse with ambient term

        // --- Coloring ---
        // Create a color palette that shifts between purple and red.
        float3 purple = float3(0.7, 0.1, 1.0);
        float3 red = float3(1.0, 0.2, 0.2);
        
        // Use a mix of position and time to create a swirling, seamless color pattern
        float color_pattern = cos(pos.x * 2.0 + loop_time) * 0.5 + 0.5;
        float3 base_color = mix(purple, red, color_pattern);
        
        // Modulate color by another wave. The position-based frequency is a multiple of
        // (2*PI / REPEAT_Z) to ensure the color pattern is identical at the start and end of the loop.
        float z_freq = 3.0 * (2.0 * PI / REPEAT_Z);
        float color_mod = 0.6 + 0.4 * sin(pos.z * z_freq - loop_time * 2.0);
        base_color *= color_mod;

        // --- Fog ---
        // Add atmospheric fog to give a sense of depth
        float fog = exp(-0.08 * t);

        color = base_color * diffuse * fog;
    }
    
    // Final color output, clamped to prevent artifacts
    return float4(clamp(color, 0.0, 1.0), 1.0);
}