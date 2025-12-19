#include <metal_stdlib>
using namespace metal;

// Per-eye camera matrices for stereo rendering
struct CameraUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

// Uniforms for immersive rendering - model transform plus two cameras (left/right eye)
struct Uniforms {
    float4x4 modelMatrix;
    CameraUniforms cameras[2];
};

// Vertex attributes matching the MTLVertexDescriptor in Swift
struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

// Data passed from vertex to fragment shader
struct VertexOut {
    float4 position [[position]];
    float3 localPos;  // For diagonal effects across the cube
    float4 color;
    float2 uv;
};

// Standard vertex shader for single-view rendering (macOS/iOS windows).
// Takes a pre-computed model-view-projection matrix.
vertex VertexOut vertexMain(
    VertexIn in [[stage_in]],
    constant float4x4 &transform [[buffer(1)]]
) {
    VertexOut out;
    out.position = transform * float4(in.position, 1.0);
    out.localPos = in.position;
    out.color = in.color;
    out.uv = in.uv;
    return out;
}

// Immersive vertex shader for visionOS stereo rendering.
// Uses vertex amplification to render both eyes in a single draw call.
// The amplification ID (0 or 1) selects which eye's camera matrices to use.
vertex VertexOut vertexImmersive(
    VertexIn in [[stage_in]],
    ushort ampId [[amplification_id]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    constant CameraUniforms &camera = uniforms.cameras[ampId];
    
    VertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
    out.position = camera.projectionMatrix * camera.viewMatrix * worldPos;
    out.localPos = in.position;
    out.color = in.color;
    out.uv = in.uv;
    return out;
}

// Shared fragment shader - renders vertex colors with animated effects.
// Time is passed from Swift to enable animation independent of geometry rotation.
fragment float4 fragmentMain(
    VertexOut in [[stage_in]],
    constant float &time [[buffer(0)]]  // Elapsed time in seconds from Swift
) {
    float edgeDistU = min(in.uv.x, 1.0 - in.uv.x);
    float edgeDistV = min(in.uv.y, 1.0 - in.uv.y);
    float edgeDist = min(edgeDistU, edgeDistV);

    // Pulse edge width between 0.5% and 2.5%
    float edgeWidth = 0.015 + 0.01 * sin(time * 3.0);
    
    if (edgeDist < edgeWidth) {
        return float4(1.0, 1.0, 1.0, 1.0);
    }
    
    // Diagonal wipe effect - a bright band sweeps from -XYZ corner to +XYZ corner.
    // Uses localPos to compute diagonal distance across the cube.
    float cycle = fmod(time, 2.5);
    if (cycle < 0.5) {
        // Diagonal ranges from -3 to +3 across the cube, normalize to 0-1
        float diagonal = (in.localPos.x + in.localPos.y + in.localPos.z + 3.0) / 6.0;
        float progress = cycle / 0.5;
        
        // Sweep a band across the diagonal
        float bandCenter = progress;
        float bandDist = abs(diagonal - bandCenter);
        float bandAmount = saturate(1.0 - bandDist * 8.0);
        
        return in.color + float4(bandAmount * 0.6);
    }
    
    return in.color;
}
