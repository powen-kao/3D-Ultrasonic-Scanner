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
    kFrameInfo = 0,
    kVoxel = 1,
    kGridPoint = 2,
};

struct FrameInfo {
    matrix_float4x4 viewProjectionMatrix;
    matrix_float4x4 localToWorld;
    matrix_float3x3 cameraIntrinsicsInversed;
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


struct Voxel {
    simd_float3 position;
    float alpha;
};


#endif /* ShaderTypes_h */
