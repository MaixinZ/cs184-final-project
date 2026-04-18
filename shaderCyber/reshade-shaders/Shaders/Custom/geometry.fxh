// Shared geometry/GBuffer helper for the CS184 ReShade effects.
//
// The default path uses ReShade depth to reconstruct view-space position and normal.
// If your ReShade runtime or addon exposes direct GBuffer data, define the macros
// below before including this file:
//
//   #define CS184_HAS_DIRECT_NORMAL 1
//   #define CS184_DIRECT_NORMAL_SAMPLE(uv) tex2D(MyNormalSampler, uv).xyz
//   #define CS184_HAS_AO 1
//   #define CS184_AO_SAMPLE(uv) tex2D(MyAOSampler, uv).x
//   #define CS184_HAS_ROUGHNESS 1
//   #define CS184_ROUGHNESS_SAMPLE(uv) tex2D(MyMaterialSampler, uv).y
//   #define CS184_HAS_METALNESS 1
//   #define CS184_METALNESS_SAMPLE(uv) tex2D(MyMaterialSampler, uv).z
//   #define CS184_HAS_MATERIAL_ID 1
//   #define CS184_MATERIAL_ID_SAMPLE(uv) tex2D(MyMaterialIdSampler, uv).x

#pragma once

#include "../ReShade.fxh"

#ifndef CS184_HAS_DIRECT_NORMAL
    #define CS184_HAS_DIRECT_NORMAL 0
#endif
#ifndef CS184_HAS_AO
    #define CS184_HAS_AO 0
#endif
#ifndef CS184_HAS_ROUGHNESS
    #define CS184_HAS_ROUGHNESS 0
#endif
#ifndef CS184_HAS_METALNESS
    #define CS184_HAS_METALNESS 0
#endif
#ifndef CS184_HAS_MATERIAL_ID
    #define CS184_HAS_MATERIAL_ID 0
#endif

#ifndef CS184_DIRECT_NORMAL_SAMPLE
    #define CS184_DIRECT_NORMAL_SAMPLE(uv) float3(0.5, 0.5, 1.0)
#endif
#ifndef CS184_AO_SAMPLE
    #define CS184_AO_SAMPLE(uv) 1.0
#endif
#ifndef CS184_ROUGHNESS_SAMPLE
    #define CS184_ROUGHNESS_SAMPLE(uv) 0.5
#endif
#ifndef CS184_METALNESS_SAMPLE
    #define CS184_METALNESS_SAMPLE(uv) 0.0
#endif
#ifndef CS184_MATERIAL_ID_SAMPLE
    #define CS184_MATERIAL_ID_SAMPLE(uv) 0.0
#endif

uniform bool CS184_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

struct CS184SurfaceData
{
    float3 color;
    float depth;
    float3 viewPos;
    float3 normal;
    float3 viewDir;
    float ao;
    float roughness;
    float metalness;
    float materialId;
    float edgeDepth;
    float edgeNormal;
    float curvature;
};

float3 CS184_SafeNormalize(float3 value)
{
    float lenSq = max(dot(value, value), 1e-8);
    return value * rsqrt(lenSq);
}

float CS184_Luminance(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

float3 CS184_GetSceneColor(float2 uv)
{
    return tex2D(ReShade::BackBuffer, uv).rgb;
}

float CS184_GetLinearDepth(float2 uv)
{
    return ReShade::GetLinearizedDepth(uv);
}

float3 CS184_ReconstructViewPosition(float2 uv, float linearDepth)
{
    float2 ndc = uv * 2.0 - 1.0;
    ndc.x *= BUFFER_ASPECT_RATIO;
    return float3(ndc, 1.0) * max(linearDepth, 1e-5);
}

float3 CS184_ReconstructNormalFromDepth(float2 uv)
{
    float2 px = BUFFER_PIXEL_SIZE;

    float centerDepth = CS184_GetLinearDepth(uv);
    float depthL = CS184_GetLinearDepth(uv - float2(px.x, 0.0));
    float depthR = CS184_GetLinearDepth(uv + float2(px.x, 0.0));
    float depthU = CS184_GetLinearDepth(uv - float2(0.0, px.y));
    float depthD = CS184_GetLinearDepth(uv + float2(0.0, px.y));

    float3 posC = CS184_ReconstructViewPosition(uv, centerDepth);
    float3 posL = CS184_ReconstructViewPosition(uv - float2(px.x, 0.0), depthL);
    float3 posR = CS184_ReconstructViewPosition(uv + float2(px.x, 0.0), depthR);
    float3 posU = CS184_ReconstructViewPosition(uv - float2(0.0, px.y), depthU);
    float3 posD = CS184_ReconstructViewPosition(uv + float2(0.0, px.y), depthD);

    float3 dx = (abs(depthR - centerDepth) < abs(centerDepth - depthL)) ? (posR - posC) : (posC - posL);
    float3 dy = (abs(depthD - centerDepth) < abs(centerDepth - depthU)) ? (posD - posC) : (posC - posU);

    return CS184_SafeNormalize(cross(dy, dx));
}

float3 CS184_DecodeDirectNormal(float3 encoded)
{
    return CS184_SafeNormalize(encoded * 2.0 - 1.0);
}

float3 CS184_GetSceneNormal(float2 uv)
{
#if CS184_HAS_DIRECT_NORMAL
    return CS184_DecodeDirectNormal(CS184_DIRECT_NORMAL_SAMPLE(uv));
#else
    return CS184_ReconstructNormalFromDepth(uv);
#endif
}

float CS184_GetSceneAO(float2 uv)
{
#if CS184_HAS_AO
    return saturate(CS184_AO_SAMPLE(uv));
#else
    return 1.0;
#endif
}

float CS184_GetSceneRoughness(float2 uv)
{
#if CS184_HAS_ROUGHNESS
    return saturate(CS184_ROUGHNESS_SAMPLE(uv));
#else
    return 0.5;
#endif
}

float CS184_GetSceneMetalness(float2 uv)
{
#if CS184_HAS_METALNESS
    return saturate(CS184_METALNESS_SAMPLE(uv));
#else
    return 0.0;
#endif
}

float CS184_GetSceneMaterialId(float2 uv)
{
#if CS184_HAS_MATERIAL_ID
    return CS184_MATERIAL_ID_SAMPLE(uv);
#else
    return 0.0;
#endif
}

float CS184_ComputeDepthEdge(float2 uv, float centerDepth)
{
    float2 px = BUFFER_PIXEL_SIZE;
    float depthL = CS184_GetLinearDepth(uv - float2(px.x, 0.0));
    float depthR = CS184_GetLinearDepth(uv + float2(px.x, 0.0));
    float depthU = CS184_GetLinearDepth(uv - float2(0.0, px.y));
    float depthD = CS184_GetLinearDepth(uv + float2(0.0, px.y));

    float edge = abs(depthL - centerDepth) + abs(depthR - centerDepth) + abs(depthU - centerDepth) + abs(depthD - centerDepth);
    return edge / max(centerDepth * 2.0, 1e-3);
}

float CS184_ComputeNormalEdge(float2 uv, float3 centerNormal)
{
    float2 px = BUFFER_PIXEL_SIZE;
    float3 normalL = CS184_GetSceneNormal(uv - float2(px.x, 0.0));
    float3 normalR = CS184_GetSceneNormal(uv + float2(px.x, 0.0));
    float3 normalU = CS184_GetSceneNormal(uv - float2(0.0, px.y));
    float3 normalD = CS184_GetSceneNormal(uv + float2(0.0, px.y));

    float edge = (1.0 - saturate(dot(centerNormal, normalL)));
    edge += (1.0 - saturate(dot(centerNormal, normalR)));
    edge += (1.0 - saturate(dot(centerNormal, normalU)));
    edge += (1.0 - saturate(dot(centerNormal, normalD)));
    return edge * 0.25;
}

float CS184_ComputeCurvature(float2 uv, float3 centerNormal)
{
    float2 px = BUFFER_PIXEL_SIZE;
    float3 normalL = CS184_GetSceneNormal(uv - float2(px.x, 0.0));
    float3 normalR = CS184_GetSceneNormal(uv + float2(px.x, 0.0));
    float3 normalU = CS184_GetSceneNormal(uv - float2(0.0, px.y));
    float3 normalD = CS184_GetSceneNormal(uv + float2(0.0, px.y));

    float3 laplacian = normalL + normalR + normalU + normalD - centerNormal * 4.0;
    return length(laplacian) * 0.25;
}

float CS184_BilateralWeight(
    float centerDepth,
    float sampleDepth,
    float3 centerNormal,
    float3 sampleNormal,
    float spatialWeight,
    float depthSigma,
    float normalSigma
)
{
    float depthWeight = exp(-abs(sampleDepth - centerDepth) / max(depthSigma, 1e-4));
    float normalWeight = pow(saturate(dot(centerNormal, sampleNormal)), max(normalSigma, 1e-4));
    return spatialWeight * depthWeight * normalWeight;
}

CS184SurfaceData CS184_LoadSurfaceData(float2 uv)
{
    CS184SurfaceData surface;
    surface.color = CS184_GetSceneColor(uv);
    surface.depth = CS184_GetLinearDepth(uv);
    surface.viewPos = CS184_ReconstructViewPosition(uv, surface.depth);
    surface.normal = CS184_GetSceneNormal(uv);
    surface.viewDir = CS184_SafeNormalize(-surface.viewPos);
    surface.ao = CS184_GetSceneAO(uv);
    surface.roughness = CS184_GetSceneRoughness(uv);
    surface.metalness = CS184_GetSceneMetalness(uv);
    surface.materialId = CS184_GetSceneMaterialId(uv);
    surface.edgeDepth = CS184_ComputeDepthEdge(uv, surface.depth);
    surface.edgeNormal = CS184_ComputeNormalEdge(uv, surface.normal);
    surface.curvature = CS184_ComputeCurvature(uv, surface.normal);
    return surface;
}
