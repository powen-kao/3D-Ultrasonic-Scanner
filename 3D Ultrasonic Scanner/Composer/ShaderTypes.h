//
//  ShaderTypes.h
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/4.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h
//#include <string>
#include <simd/simd.h>

enum BufferIndices {
    kFrameInfo = 0,
    kVoxel = 1,
    kGridPoint = 2,
    kVoxelInfo = 3,
    kTexture = 4,
    kDebugInfo = 5
};

//enum DebugInfoType{
//    kDbgInfo
//}

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
    simd_int3 size;
    int count;

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
    simd_float3 position; // TODO: remove later
    simd_float4 color; // rgba
//    float alpha;
    simd_int3 location;
};


#endif /* ShaderTypes_h */