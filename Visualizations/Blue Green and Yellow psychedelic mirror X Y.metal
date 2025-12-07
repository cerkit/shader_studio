// Prompt: Please create a psychedelic pattern that mirrors on the x and y axes. Use a color scheme consisting of vibrant blue, true green, and school bus yellow

#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // 1. Set up coordinate system
    // Normalize coordinates to be -1.0 to 1.0 and centered
    float2 st = uv * 2.0 - 1.0;

    // Correct for aspect ratio to make patterns circular instead of stretched
    st.x *= u_resolution.x / u_resolution.y;
    
    // 2. Create symmetrical/mirrored pattern
    // Use the absolute value of the coordinates. This folds all four quadrants
    // into the top-right, creating perfect mirroring on both X and Y axes.
    float2 p = abs(st);

    // 3. Generate the psychedelic motion
    // Convert to polar coordinates (radius and angle) which are great for swirls and rings
    float radius = length(p * 1.2); // Scale up for more detail
    float angle = atan2(p.y, p.x);

    // Create a base value using a sine wave on the radius, animated over time.
    // This forms the foundation of expanding/contracting rings.
    float v1 = sin(radius * 10.0 - u_time * 2.5);
    
    // Create another value using the angle and time.
    // This will create rotating "spokes" or sectors.
    float v2 = cos(angle * 6.0 + u_time);
    
    // Combine the values in a non-linear way to create complex interference patterns.
    // Adding another layer of distortion based on radius makes the motion more organic.
    float pattern_value = sin(v1 * 3.14 + v2 * 1.57 + radius * 4.0);
    
    // Normalize the final value to the 0.0 to 1.0 range, which is ideal for coloring.
    pattern_value = (pattern_value + 1.0) * 0.5;

    // 4. Apply the requested color scheme
    // Define the vibrant colors
    float3 vibrant_blue = float3(0.0, 0.0, 1.0);
    float3 true_green = float3(0.0, 1.0, 0.0);
    float3 school_bus_yellow = float3(1.0, 0.84, 0.0);

    // Use a three-way mix to apply the colors based on the pattern value.
    // First, mix between blue and green for the lower half of the value range.
    float3 color = mix(vibrant_blue, true_green, smoothstep(0.0, 0.6, pattern_value));
    
    // Then, mix the result with yellow for the upper half of the value range.
    // The smoothstep ranges overlap slightly to create smoother transitions between all three colors.
    color = mix(color, school_bus_yellow, smoothstep(0.4, 1.0, pattern_value));

    // Return the final color with full alpha
    return float4(color, 1.0);
}