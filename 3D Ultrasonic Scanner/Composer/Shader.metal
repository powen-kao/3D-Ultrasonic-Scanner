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
static simd_float4 imageToWorld(simd_float2 cameraPoint, const device VoxelInfo *vInfo, constant FrameInfo *fInfo) {
    auto localPoint = fInfo->uIntrinsicsInversed * simd_float3(cameraPoint, 1);
    const auto worldPoint = fInfo->cameraTransform * vInfo->rotateToARCamera * fInfo->flipY * simd_float4(simd_float3(localPoint.xy, 0), 1);
    // TODO: add transform from iPhone to ultrasound image
    return worldPoint; // without normalization
}

/*
 convert from world coordinate to camera local coordinate (not image coordinate).
 */
static simd_float4 worldToLocal(simd_float3 worldPoint, const device VoxelInfo *vInfo) {
    const auto localPoint = vInfo->inversedRotateToARCamera * vInfo->inversedTransform * simd_float4(worldPoint, 1);
    return localPoint; // without normalization
}

static int3 idTovPosition_3d(int id , const device VoxelInfo *vInfo){
    const auto xyArea = vInfo->size.x * vInfo->size.y;
    const auto z = id / xyArea;
    const auto y = (id - z * xyArea) / vInfo->size.x;
    const auto x = id % vInfo->size.x;
    return int3(x, y, z);
}
static int vPositionToId_3d(int3 vPosition, const device VoxelInfo *vInfo){
    // clamp the range of (x, y, z)
    auto _vPosition = clamp(vPosition, int3(0), int3(vInfo->size) - 1);
    
    if (_vPosition.x != vPosition.x ||
        _vPosition.y != vPosition.y ||
        _vPosition.z != vPosition.z){
        return -1;
    }
    
    const auto xyArea = vInfo->size.x * vInfo->size.y;
    return xyArea * _vPosition.z + _vPosition.y * vInfo->size.x + _vPosition.x;
}

/*
 check whether the point is withing voxel range
 */
static bool positionIsValid(float3 position, const device VoxelInfo *info){
    auto _position = clamp(position, float3(0), float3(info->size - 1) * info->stepSize);
    
    if (_position.x != position.x ||
        _position.y != position.y ||
        _position.z != position.z){
        return false;
    }
    return true;
}

/*
 find voxel nearby
 */
struct NearByResult{
    int ids[8]; // IDs to access voxel
};


static bool findNearby(simd_float3 position, device VoxelInfo &vInfo, thread NearByResult &result){
    result = {{-1}}; // set default value
    if (!positionIsValid(position, &vInfo)){
        // WARNING: ignore the points that locate outside the voxel box edge.
        return false;
    }
    
    auto vPosition = simd_int3(position / vInfo.stepSize);
    for (uint8_t z = 0; z < 2 ; z ++){
        for (uint8_t y = 0; y < 2 ; y ++){
            for (uint8_t x = 0; x < 2 ; x ++){
                uint16_t id = x + y * 2 + z * 4;
                // TODO: check whether ID is valid
                
                auto _vPosistion = vPosition + int3(x, y, z);
                result.ids[id] = vPositionToId_3d(_vPosistion, &vInfo);
            }
        }
    }
    
    return true;
}

///  Vertex shader that takes in a 2D grid-point and infers its 3D position in world-space, along with RGB and confidence
vertex void unprojectVertex(uint vertexID [[vertex_id]],
                            device Voxel *voxel [[buffer(kVoxel)]],
                            device Voxel *imgVoxel [[buffer(kImageVoxel)]],
                            constant FrameInfo &fInfo [[buffer(kFrameInfo)]],
                            device VoxelInfo &vInfo [[buffer(kVoxelInfo)]],
                            device char *dbgInfo [[buffer(kDebugInfo)]],
                            constant float2 *gridPoints [[buffer(kGridPoint)]],
                            texture2d<float, access::sample> uImageTexture [[texture(kTexture)]]
                            ){
    const auto gridX = vertexID % fInfo.imageWidth;
    const auto gridY = (int) (vertexID / fInfo.imageWidth);
    
    
    // With a 2D point and depth, we can compute its global 3D position
    // unit in meter
    auto worldPosition = imageToWorld(float2(gridX, gridY), &vInfo, &fInfo);

    // transform points with inverse transform of the first frame (which serves as reference)
    // (this provide local coordinate and scale)
    auto localPosition = worldToLocal(worldPosition.xyz, &vInfo);
    // TODO: check the position of "vInfo.size/2"
    
    // Prepate data
    float4 color = uImageTexture.sample(colorSampler, float2(float(gridX)/fInfo.imageWidth, float(gridY)/fInfo.imageHeight));
    
    // convert image pixel into image voxel
    imgVoxel[vertexID].position = localPosition.xyz;
    imgVoxel[vertexID].color = color;

    // find near by voxels
    NearByResult result;
    if (!findNearby(localPosition.xyz, vInfo, result)){
        return; // the pixel is located outside voxel range
    }
    
    
    // ----- ALGORITHM BEGIN-----
    // foreach neighbor
    for (uint8_t i = 0; i < 8; i ++){
        int id = result.ids[i];
        if (id < 0)
            break;
        
        device Voxel *v = &voxel[id];
        int3 vPosition = idTovPosition_3d(id, &vInfo);
        v->position = float3(vPosition) * vInfo.stepSize + (vInfo.stepSize / 2);

        // TODO: Synchronous multithreading

        float invDistance = 1.0/distance(localPosition.xyz, v->position);
        
        // WARNING: retrieve colors and convert to B&W
//        color = color * fInfo.colorSpaceTransform;
                
        // update near-by voxels
        auto sum = v->color * v->weight + color * invDistance;
        v->weight += invDistance;
        v->color = sum/v->weight;
        
        // update state
        v->touched = true;
    }
    // ----- ALGORITHM END-----
        
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

kernel void holeFilling(device Voxel *voxel [[buffer(kVoxel)]],
                        constant Voxel *voxelCopy [[buffer(kCopyVoxel)]],
                        device VoxelInfo &vInfo [[buffer(kVoxelInfo)]],
                        uint3 grid_pos [[thread_position_in_grid]]
                        ){
    
    if (grid_pos.x >= vInfo.size.x ||
        grid_pos.y >= vInfo.size.y ||
        grid_pos.z >= vInfo.size.z)
        return;
        
    uint vertexID = vPositionToId_3d(int3(grid_pos), &vInfo);
    if (vertexID < 0)
        return;
    
    // ----- ALGORITHM BEGIN-----
    if (voxel[vertexID].weight != 0)
        return; // is not empty

    int count = 0;
    float sum = 0;
    
    // find neighbors
    for (int z = -1; z < 2 ; z++){
        for (int y = -1; y < 2 ; y++){
            for (int x = -1; x < 2 ; x++){
                // check if the neighbor has value
                int _id = vPositionToId_3d(int3(grid_pos) + int3(x, y, z), &vInfo);
                if (_id < 0)
                    continue; // skip of neighbor is outside

                constant Voxel &vc = voxelCopy[_id];
                float _color = dot(vc.color.xyz, float3(0.333, 0.333, 0.333));
                // ignore this neighbor if it's doesn't has any color value
                if (_color > 0){
                    sum += _color;
                    count ++;
                }
            }
        }
    }
    if (count > 0){
        // TODO: what about transparency?
        voxel[vertexID].color = float4(float3(sum / count), 1);
    }
    // ----- ALGORITHM END-----
}


vertex VoxelVertexOut voxelVertex(uint vertexID [[vertex_id]],
                                  constant Voxel *voxel [[buffer(kVoxel)]],
                                  constant VoxelInfo *voxelInfo [[buffer(kVoxelInfo)]]
                                  ){
    // TODO: safty check whether vertex id is withing buffer range
//    const auto position = idToPosition_3d(vertexID, voxelInfo);

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
