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

static bool vPositionIsValid(int3 vPosition, const device VoxelInfo &info){
    auto _vPosition = clamp(vPosition, int3(0), int3(info.size - 1));

    if (_vPosition.x != vPosition.x ||
        _vPosition.y != vPosition.y ||
        _vPosition.z != vPosition.z){
        return false;
    }
    return true;
}

/*
 convert image coordinate to world coordinate
 */
static simd_float4 imageToWorld(simd_float2 cameraPoint, const device VoxelInfo *vInfo, constant FrameInfo *fInfo) {
    auto localPoint = fInfo->uIntrinsicsInversed * simd_float3(cameraPoint, 1);
    const auto worldPoint = fInfo->transform * vInfo->rotateToARCamera * fInfo->flipY * simd_float4(simd_float3(localPoint.xy, 0), 1);
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
static int vPositionToId_2d(int2 vPosition, constant FrameInfo *fInfo){
    auto _vPosition = clamp(vPosition, int2(0), int2(fInfo->imageWidth, fInfo->imageHeight) - 1);
    if (_vPosition.x != vPosition.x ||
        _vPosition.y != vPosition.y ){
        return -1;
    }
    
    return _vPosition.y * fInfo->imageWidth + _vPosition.x;
}

///// Convert the local coordinate position to voxel position
static int3 positionTovPosition_voxel(float3 position, const device VoxelInfo &vInfo, thread bool &isValid){
    // transform to another coordinate for easier position conversion
    auto offset = (float4(0, 0, 0, 1) * vInfo.centerizeTransform * vInfo.stepSize).xyz;
    auto _vPosition = int3((position - offset) / vInfo.stepSize);

    if (!vPositionIsValid(_vPosition, vInfo)) {
        isValid = false;
        return int3(-1, -1, -1);
    }
    isValid = true;
    return _vPosition;
}


/*
 find voxel nearby
 */
struct NearByResult{
    int ids[8]; // IDs to access voxel
};


/// Find the neighbor voxels with local position
static bool findNearby(simd_float3 position, device VoxelInfo &vInfo, thread NearByResult &result){
    result = {{-1}}; // set default value
    
    bool isValid;
    auto vPosition = positionTovPosition_voxel(position, vInfo, isValid);
    if (!isValid){
        return false;
    }
    
    for (uint8_t z = 0; z < 2 ; z ++){
        for (uint8_t y = 0; y < 2 ; y ++){
            for (uint8_t x = 0; x < 2 ; x ++){
                uint16_t id = x + y * 2 + z * 4;
                // TODO: check whether ID is valid
                
                vPosition = vPosition + (int3(x, y, z) - 1);
                result.ids[id] = vPositionToId_3d(vPosition, &vInfo);
            }
        }
    }
    
    return true;
}

static void updateMinMax(float3 position ,device VoxelInfo &vInfo){
    // update min max value of xyz
    if (vInfo.axisMax.x < position.x){
        vInfo.axisMax.x = position.x;
    }
    if (vInfo.axisMin.x > position.x){
        vInfo.axisMin.x = position.x;
    }
    
    if (vInfo.axisMax.y < position.y){
        vInfo.axisMax.y = position.y;
    }
    if (vInfo.axisMin.y > position.y){
        vInfo.axisMin.y = position.y;
    }
    
    if (vInfo.axisMax.z < position.z){
        vInfo.axisMax.z = position.z;
    }
    if (vInfo.axisMin.z > position.z){
        vInfo.axisMin.z = position.z;
    }
}

/// Sample texture and render the preview

kernel void renderPreview(uint2 grid_pos [[thread_position_in_grid]],
                          device Voxel *imgVoxel [[buffer(kImageVoxel)]],
                          constant FrameInfo &fInfo [[buffer(kPreviewFrameInfo)]],
                          device VoxelInfo &vInfo [[buffer(kVoxelInfo)]],
                          texture2d<float, access::sample> uImageTexture [[texture(kPreviewTexture)]]
                          ){
    
    const int vertexID = vPositionToId_2d(int2(grid_pos), &fInfo);
    if (vertexID < 0){
        return;
    }
    
    auto worldPosition = imageToWorld(float2(grid_pos), &vInfo, &fInfo);
    auto localPosition = worldToLocal(worldPosition.xyz, &vInfo);
    
    float4 color = uImageTexture.sample(colorSampler, float2(float(grid_pos.x)/fInfo.imageWidth, float(grid_pos.y)/fInfo.imageHeight));
    
    switch (fInfo.mode){
        case kPD_DrawAll:
            break;
        case kPD_TransparentBlack:
            if (dot(color, float4(1, 1, 1, 0)) == 0){
                color.a = 0;
            }
            break;
    }
    
    // convert image pixel into image voxel
    imgVoxel[vertexID].position = localPosition.xyz;
    imgVoxel[vertexID].color = color;
    
}

///  Vertex shader that takes in a 2D grid-point and infers its 3D position in world-space, along with RGB and confidence
kernel void unproject(uint3 grid_pos [[thread_position_in_grid]],
                            device Voxel *voxel [[buffer(kVoxel)]],
                            constant FrameInfo &fInfo [[buffer(kFrameInfo)]],
                            device VoxelInfo &vInfo [[buffer(kVoxelInfo)]],
                            texture2d<float, access::sample> uImageTexture [[texture(kTexture)]]
                            ){
    const auto gridX = grid_pos.x;
    const auto gridY = grid_pos.y;
    
    
    // With a 2D point and depth, we can compute its global 3D position
    // unit in meter
    auto worldPosition = imageToWorld(float2(gridX, gridY), &vInfo, &fInfo);

    // transform points with inverse transform of the first frame (which serves as reference)
    // (this provide local coordinate and scale)
    auto localPosition = worldToLocal(worldPosition.xyz, &vInfo);
    
    // TODO: remove if not used
//    updateMinMax(worldPosition.xyz ,vInfo);
    
    // Prepate data
    float4 color = uImageTexture.sample(colorSampler, float2(float(gridX)/fInfo.imageWidth, float(gridY)/fInfo.imageHeight));

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
                    continue; // skip of neighbor is outside

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

kernel void executeTask(device Voxel *voxel [[buffer(kVoxel)]],
                        constant FrameInfo &fInfo [[buffer(kFrameInfo)]],
                        device VoxelInfo &vInfo [[buffer(kVoxelInfo)]],
                        device Task &task [[buffer(kTask)]],
                        uint3 grid_pos [[thread_position_in_grid]]
                        ){
    switch (task.type){
        case kT_ResetVoxels: {
            const auto id = vPositionToId_3d(int3(grid_pos), &vInfo);
            if (id < 0)
                return;
            voxel[id].color = float4(0, 0, 0, 0);
            voxel[id].weight = 0;
            voxel[id].position = (float4(float3(grid_pos), 1) * vInfo.centerizeTransform * vInfo.stepSize).xyz;
            break;
        }
    }
    
}
