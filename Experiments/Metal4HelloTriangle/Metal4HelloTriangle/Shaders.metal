#include <metal_stdlib>
using namespace metal;

// MARK: - Compute

// Writes a time-varying gradient into a texture. One thread per texel.
kernel void gradient_kernel(texture2d<float, access::write> output [[texture(0)]],
                            constant float& time [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    const uint w = output.get_width();
    const uint h = output.get_height();
    if (gid.x >= w || gid.y >= h) {
        return;
    }
    float2 uv = float2(gid) / float2(w, h);
    float3 color = float3(uv.x,
                          uv.y,
                          0.5 + 0.5 * sin(time * 4.0 + (uv.x + uv.y) * 6.2831));
    output.write(float4(color, 1.0), gid);
}

// MARK: - Render

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Vertex {
    float2 position;
    float2 uv;
};

vertex VertexOut vertex_main(uint vid [[vertex_id]],
                             const device Vertex* vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vid].position, 0.0, 1.0);
    out.uv = vertices[vid].uv;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> gradient [[texture(0)]],
                              sampler linearSampler [[sampler(0)]]) {
    return gradient.sample(linearSampler, in.uv);
}
