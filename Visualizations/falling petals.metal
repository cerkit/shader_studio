#include <metal_stdlib>
using namespace metal;

float2x2 rotate2d(float _angle) {
    return float2x2(cos(_angle), -sin(_angle),
                    sin(_angle), cos(_angle));
}

float circle(float2 uv, float radius, float blur) {
    float d = length(uv);
    return smoothstep(radius, radius - blur, d);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float2& u_resolution [[buffer(0)]],
                              constant float& u_time [[buffer(1)]]) {
    float2 uv = in.uv;
    uv -= float2(0.5, 1.1);

    float s = 0.01;
    float3 coll = float3(0.0);
    float t = u_time / 4.0;
    float vl = 0.0;
    float r = 0.05;
    
    for (float f = 0.0; f < 1.0; f += s) {
        float2 st = uv;

        st.x += fract((sin(f * 1245.0)) * 114.0) - 0.5;
        st.y += fract(t * sin(f + 0.1) + f * 2.0) * 1.2;

        st *= mix(f, 0.9, 2.0);

        st.x *= u_resolution.x / u_resolution.y;
        st = rotate2d(u_time + sin(f * 175.0) * 1854.0) * st;
        st.y *= 1.82;
        st.y -= abs(st.x / 3.0 + sin(u_time + fract(f)) * 0.01);
        vl = max(circle(st, r, 0.027), vl);

        coll = vl * float3(1.0, 0.5, 0.7);
    }
    
    float3 color = coll;
    
    return float4(color, 1.0);
}