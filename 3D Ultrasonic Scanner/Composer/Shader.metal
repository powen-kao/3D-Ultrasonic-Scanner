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

constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);

// Particle vertex shader outputs and fragment shader inputs
struct VoxelVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};
/*
 convert image coordinate to world coordinate
 */
static simd_float4 imageToWorld(simd_float2 cameraPoint, matrix_float3x3 cameraIntrinsicsInversed, matrix_float4x4 transform) {
    const auto localPoint = cameraIntrinsicsInversed * simd_float3(cameraPoint, 1);
    const auto worldPoint = transform * simd_float4(simd_float3(localPoint.xy, 0), 1);
    // TODO: add transform from iPhone to ultrasound image
    return worldPoint; // without normalization

//    return worldPoint / worldPoint.w;
}

/*
 convert from world coordinate to camera local coordinate (not image coordinate).
 */
static simd_float3 worldToLocal(simd_float3 worldPoint, matrix_float4x4 transform) {
    const auto localPoint = transform * simd_float4(worldPoint, 1);
    return localPoint.xyz; // without normalization
}

static float3 idToPosition_3d(int id , constant VoxelInfo *info){
    const auto xyArea = info->size.x * info->size.y;
    const auto z = id / xyArea;
    const auto y = (id - z * xyArea) / info->size.x;
    const auto x = id % info->size.x;
    return float3(x, y, z);
}
static int positionToId_3d(simd_int3 position, const device VoxelInfo *info){
    // clamp the range of (x, y, z)
    position = clamp(position, simd_int3(0), info->size - 1);
    
    const auto xyArea = info->size.x * info->size.y;
    return xyArea * position.z + position.y * info->size.x + position.x;
}

struct NearByResult{
    const device Voxel *neighbors;
    int count;
};
/*
 find voxel nearby
 */
static void findNearBy(float3 position, const device Voxel* neighbors){
    
}

///  Vertex shader that takes in a 2D grid-point and infers its 3D position in world-space, along with RGB and confidence
vertex void unprojectVertex(uint vertexID [[vertex_id]],
                            constant FrameInfo &fInfo [[buffer(kFrameInfo)]],
                            device Voxel *voxel [[buffer(kVoxel)]],
                            device VoxelInfo &vInfo [[buffer(kVoxelInfo)]],
                            device char *dbgInfo [[buffer(kDebugInfo)]],
                            constant float2 *gridPoints [[buffer(kGridPoint)]],
                            texture2d<float, access::sample> uImageTexture [[texture(kTexture)]]
//                            texture2d<float, access::sample> depthTexture [[texture(kTextureDepth)]],
//                            texture2d<unsigned int, access::sample> confidenceTexture [[texture(kTextureConfidence)]]
                            ){
    const auto gridPoint = gridPoints[vertexID];
    const auto gridX = vertexID % fInfo.imageWidth;
    const auto gridY = (int) (vertexID / fInfo.imageWidth);
    
    
    // With a 2D point and depth, we can compute its global 3D position
    // unit in meter
    const auto worldPosition = imageToWorld(float2(gridX, gridY),fInfo.uIntrinsicsInversed, fInfo.cameraTransform);

    // transform points with inverse transform of the first frame (which serves as reference)
    // (this provide local coordinate and scale)
    auto localPosition = worldToLocal(worldPosition.xyz, vInfo.inversedTransform);
    // TODO: check the position of "vInfo.size/2"
    auto vPosition = simd_int3(localPosition / vInfo.stepSize) - vInfo.size/2;

    // find the ID of the voxel and write corresponding data
    const int64_t targetID = positionToId_3d(vPosition, &vInfo);
    voxel[targetID].position = worldPosition.xyz;
//    voxel[targetID].color = uImageTexture.sample(colorSampler, float2(gridX/fInfo.imageWidth, gridY/fInfo.imageHeight));
    voxel[targetID].color = float4(0.5,0.5,0.8,0.1);
    
    
    // contribute to voxels
    
    
    // update min max value of xyz
    if (vInfo.axisMax.x < worldPosition.x){
        vInfo.axisMax.x = worldPosition.x;
    }
    if (vInfo.axisMin.x > worldPosition.x){
        vInfo.axisMin.x = worldPosition.x;
    }
    
    if (vInfo.axisMax.y < worldPosition.y){
        vInfo.axisMax.y = worldPosition.y;
    }
    if (vInfo.axisMin.y > worldPosition.y){
        vInfo.axisMin.y = worldPosition.y;
    }
    
    if (vInfo.axisMax.z < worldPosition.z){
        vInfo.axisMax.z = worldPosition.z;
    }
    if (vInfo.axisMin.z > worldPosition.z){
        vInfo.axisMin.z = worldPosition.z;
    }

}

vertex VoxelVertexOut voxelVertex(uint vertexID [[vertex_id]],
                                  constant Voxel *voxel [[buffer(kVoxel)]],
                                  constant VoxelInfo *voxelInfo [[buffer(kVoxelInfo)]]
                                  ){
    // TODO: safty check whether vertex id is withing buffer range
    const auto position = idToPosition_3d(vertexID, voxelInfo);

//    auto projectedPosition = position * info.viewProjectionMatrix;
//    projectedPosition /= projectedPosition.w;
//    auto voxelPosisition = float3(x, y, z);
    
    VoxelVertexOut out;
    out.pointSize = 5;
    out.color = float4(voxel->color);
    return out;
}

fragment float4 particleFragment(VoxelVertexOut in [[stage_in]],
                                 const float2 coords [[point_coord]]) {
    
    return in.color;
}
