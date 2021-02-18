//
//  ShaderTypes.h
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/4.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h
#include <simd/simd.h>

enum BufferIndices {
    kFrameInfo,
    kVoxel,
    kCopyVoxel,
    kImageVoxel,
    kGridPoint,
    kVoxelInfo,
    kTexture,
    kPreviewFrameInfo,
    kPreviewTexture
};

typedef enum State{
    kVInit,
    kVReady
} VoxelInfoState;

struct FrameInfo {
    // 'u' represent 'ultrasound'
    matrix_float4x4 viewProjectionMatrix;
    matrix_float4x4 cameraTransform;
    matrix_float4x4 uImageToCamera;
    matrix_float3x3 cameraIntrinsicsInversed;
    matrix_float3x3 uIntrinsicsInversed;
    matrix_float3x3 uIntrinsics;
    matrix_float4x4 colorSpaceTransform;
    matrix_float4x4 flipY;
    

    simd_float2 cameraResolution;
    int imageWidth;
    int imageHeight;
    
    float particleSize;
    int maxPoints;
    int pointCloudCurrentIndex;
    int confidenceThreshold;
};

struct Particle {
    simd_float4 position;
    float alpha;
};

struct VoxelInfo{
    simd_float4x4 transform; // transform from local voxel to global position
    simd_float4x4 inversedTransform;
    simd_float4x4 rotateToARCamera;
    simd_float4x4 inversedRotateToARCamera;
    simd_uint3 size;
    uint count;

    // flag
    VoxelInfoState state;
        
    // Output
    simd_float3 axisMin;
    simd_float3 axisMax;
    
//    int xy_area = size.x * size.y;
    float stepSize; // meter per voxel step
    
    
};

struct DebugInfo{
//     infoString;
//    device char *string;
};

struct Voxel {
    simd_float3 position;
    simd_float4 color; // rgba
    float weight;
    uint8_t touched;
};


#endif /* ShaderTypes_h */
