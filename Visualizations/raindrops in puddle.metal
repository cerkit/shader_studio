// Prompt: Please create a shader that resembles looking straight down at a puddle of water with random raindrops falling into it causing ripples in the puddle. Use dark colors for the puddle and a lighter gray color for the ripples.

#include <metal_stdlib>
using namespace metal;

// A simple and effective hash function for generating a pseudo-random float from a float2
// This creates a consistent but random-looking value for each grid cell.
float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 443.8975);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv_raw = in.uv; // uv is already normalized 0..1 from vertex shader
    
    // 1. Setup coordinates
    // Center the coordinates to (-1..1) and correct for aspect ratio to make ripples circular
    float2 uv = (2.0 * uv_raw - 1.0) * (u_resolution / u_resolution.y);
    
    // Scale the space to control the apparent density of raindrops
    float2 p = uv * 5.0;

    // This will accumulate the wave height from all ripples affecting this pixel
    float totalWaveHeight = 0.0;
    
    // Control overall animation speed
    float t = u_time * 0.5;

    // 2. Tile the space and check neighboring cells for ripples
    // Get the integer coordinate of the cell this pixel is in
    float2 cellId = floor(p);

    // Iterate over a 3x3 grid of cells around the current one.
    // This ensures that ripples starting in neighboring cells can affect the current pixel.
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 neighborCell = cellId + float2(i, j);

            // 3. Generate properties for the raindrop in this cell
            // Use hash to get a consistent random value for each cell
            float cellHash = hash(neighborCell);
            
            // Randomize the drop position within its cell for a less grid-like appearance
            float2 dropCenter = neighborCell + float2(hash(neighborCell * 1.23), hash(neighborCell * 4.56));
            
            // Use time and the cell's hash to create a repeating event (the raindrop)
            // 'fract' makes the value loop from 0.0 to 1.0 over a fixed duration.
            // This 'eventTime' represents the life of a single ripple, from birth to fade-out.
            float eventTime = fract(t * 0.2 + cellHash);
            
            // 4. Calculate the ripple effect from this drop
            float dist = distance(p, dropCenter);
            
            // The ripple expands outwards over its lifetime. Its radius is based on eventTime.
            float waveSpeed = 2.0;
            float radius = eventTime * waveSpeed;

            // Only calculate the wave if the pixel is inside the ripple's current radius
            if (dist < radius) {
                // The wave is a cosine function that depends on the distance from the expanding edge
                float waveFrequency = 20.0;
                float wave = cos((dist - radius) * waveFrequency);
                
                // The amplitude of the wave should decrease as the ripple ages (eventTime increases)
                // and should be soft at its outer edge.
                float amplitude = pow(1.0 - eventTime, 2.0); // Fade out over lifetime (quadratic falloff)
                amplitude *= smoothstep(radius, radius - 0.25, dist); // Soften the outer edge
                
                totalWaveHeight += wave * amplitude;
            }
        }
    }

    // 5. Determine the final color
    float3 puddleColor = float3(0.05, 0.1, 0.15);    // Dark blue/black for the water
    float3 rippleColor = float3(0.6, 0.7, 0.8); // Light gray for the ripple highlights
    
    // Add the wave effect to the base puddle color.
    // Positive wave height creates highlights, negative creates shadows, mimicking light reflection.
    float intensity = 0.4;
    float3 color = puddleColor + totalWaveHeight * rippleColor * intensity;
    
    // Ensure the color is within the valid [0, 1] range
    color = clamp(color, 0.0, 1.0);
    
    return float4(color, 1.0);
}