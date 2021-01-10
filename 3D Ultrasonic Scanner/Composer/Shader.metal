//
//  Shader.metal
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/4.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"
using namespace metal;

/**
 Convert
 */

// Particle vertex shader outputs and fragment shader inputs
struct ParticleVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};

static simd_float4 worldPoint(simd_float2 cameraPoint, matrix_float4x4 localToWorld) {
    const auto localPoint = simd_float3(cameraPoint, 1);
    const auto worldPoint = localToWorld * simd_float4(localPoint, 1);
    
    return worldPoint / worldPoint.w;
}

///  Vertex shader that takes in a 2D grid-point and infers its 3D position in world-space, along with RGB and confidence
vertex ParticleVertexOut unprojectVertex(uint vertexID [[vertex_id]],
                            constant FrameInfo &info [[buffer(kFrameInfo)]],
                            device Voxel *voxel [[buffer(kVoxel)]],
                            constant float2 *gridPoints [[buffer(kGridPoint)]]
//                            texture2d<float, access::sample> depthTexture [[texture(kTextureDepth)]],
//                            texture2d<unsigned int, access::sample> confidenceTexture [[texture(kTextureConfidence)]]
                            ){
    
    const auto gridPoint = gridPoints[vertexID];
    const auto gridX = vertexID % info.imageWidth;
    const auto gridY = (int) (vertexID / info.imageWidth);
    
    // With a 2D point plus depth, we can now get its 3D position
    const auto position = worldPoint(float2(gridX, gridY), info.localToWorld);
    
    auto projectedPosition = position * info.viewProjectionMatrix;
    projectedPosition /= projectedPosition.w;

    
    // Write the data to the buffer
//    voxel[vertexID].position = projectedPosition.xyz / 100;
//    voxel[vertexID].position = position.xyz;
    voxel[vertexID].position = float3(float2(gridX, gridY), 0.5) / info.imageWidth;
    
//    voxel[vertexID].position = float3(gridX/100.0, gridY/100.0 + gridX/50.0, 0.2);
    voxel[vertexID].alpha = 0.5;
    
    ParticleVertexOut out;
    out.position = float4(voxel[vertexID].position, 1);
    out.pointSize = 5;
    out.color = float4(0.5, 0.2, 0.3, 0.8);
    return out;
}


fragment float4 particleFragment(ParticleVertexOut in [[stage_in]],
                                 const float2 coords [[point_coord]]) {
    
    return in.color;
}
