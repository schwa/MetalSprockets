#include <metal_stdlib>
using namespace metal;

namespace YCbCrBillboard {

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 textureCoordinate [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

[[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.textureCoordinate = in.textureCoordinate;
    return out;
}

[[fragment]] float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> textureY [[texture(0)]],
    texture2d<float, access::sample> textureCbCr [[texture(1)]],
    sampler textureSampler [[sampler(0)]]
) {
    float y = textureY.sample(textureSampler, in.textureCoordinate).r;
    float2 cbcr = textureCbCr.sample(textureSampler, in.textureCoordinate).rg;

    // BT.601 YCbCr to RGB conversion
    const float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );

    float4 ycbcr = float4(y, cbcr, 1.0);
    return ycbcrToRGBTransform * ycbcr;
}

} // namespace YCbCrBillboard

