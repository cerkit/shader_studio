// Simple Gradient Shader
#include <metal_stdlib>
using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    float3 color = float3(uv.x, uv.y, 0.5 + 0.5 * sin(u_time));
    return float4(color, 1.0);
}