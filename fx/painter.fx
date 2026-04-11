// Geometry-driven painter style for ReShade.
// Uses real depth/normal signals for contouring and edge-preserving abstraction.

#include "geometry.fxh"

uniform float Painter_EffectBlend <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend between the original scene color and the painterly result.";
> = 1.0;

uniform float Painter_BlurRadius <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.5; ui_max = 4.0;
    ui_tooltip = "Radius of the depth/normal-aware bilateral wash.";
> = 1.75;

uniform float Painter_DepthSigma <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0005; ui_max = 0.05;
    ui_tooltip = "Depth preservation for the bilateral wash. Smaller values keep form boundaries sharper.";
> = 0.008;

uniform float Painter_NormalSigma <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 1.0; ui_max = 24.0;
    ui_tooltip = "Normal preservation exponent for the bilateral wash.";
> = 8.0;

uniform float Painter_WashStrength <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Blend between the source color and the geometry-guided paint wash.";
> = 0.60;

uniform float Painter_PosterLevels <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 3.0; ui_max = 12.0; ui_step = 1.0;
    ui_tooltip = "Number of tonal levels in the simplified paint treatment.";
> = 6.0;

uniform float Painter_ContourStrength <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.2;
    ui_tooltip = "Strength of the warm contour accent from depth/normal edges.";
> = 0.58;

uniform float Painter_GlazeStrength <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Strength of restrained gold glazing on lit contours.";
> = 0.35;

uniform float Painter_GrainStrength <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 0.08;
    ui_tooltip = "Paper grain modulation strength.";
> = 0.03;

uniform float3 Painter_LightDir <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = -1.0; ui_max = 1.0;
    ui_tooltip = "Direction used for highlight glazing and form-sensitive layering.";
> = float3(-0.35, 0.28, 0.90);

float Painter_Grain(float2 uv)
{
    float2 pixelPos = uv * BUFFER_SCREEN_SIZE;
    return frac(sin(dot(pixelPos * float2(0.91, 1.13), float2(12.9898, 78.233))) * 43758.5453);
}

float3 Painter_BilateralBlur(float2 uv, float centerDepth, float3 centerNormal)
{
    float2 px = BUFFER_PIXEL_SIZE;
    float2 dx = float2(px.x * Painter_BlurRadius, 0.0);
    float2 dy = float2(0.0, px.y * Painter_BlurRadius);

    float3 accum = CS184_GetSceneColor(uv) * 4.0;
    float weightSum = 4.0;

    float2 uv1 = uv + dx;
    float2 uv2 = uv - dx;
    float2 uv3 = uv + dy;
    float2 uv4 = uv - dy;
    float2 uv5 = uv + dx + dy;
    float2 uv6 = uv - dx - dy;
    float2 uv7 = uv + dx - dy;
    float2 uv8 = uv - dx + dy;

    float w1 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv1), centerNormal, CS184_GetSceneNormal(uv1), 1.0, Painter_DepthSigma, Painter_NormalSigma);
    float w2 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv2), centerNormal, CS184_GetSceneNormal(uv2), 1.0, Painter_DepthSigma, Painter_NormalSigma);
    float w3 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv3), centerNormal, CS184_GetSceneNormal(uv3), 1.0, Painter_DepthSigma, Painter_NormalSigma);
    float w4 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv4), centerNormal, CS184_GetSceneNormal(uv4), 1.0, Painter_DepthSigma, Painter_NormalSigma);
    float w5 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv5), centerNormal, CS184_GetSceneNormal(uv5), 0.85, Painter_DepthSigma, Painter_NormalSigma);
    float w6 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv6), centerNormal, CS184_GetSceneNormal(uv6), 0.85, Painter_DepthSigma, Painter_NormalSigma);
    float w7 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv7), centerNormal, CS184_GetSceneNormal(uv7), 0.85, Painter_DepthSigma, Painter_NormalSigma);
    float w8 = CS184_BilateralWeight(centerDepth, CS184_GetLinearDepth(uv8), centerNormal, CS184_GetSceneNormal(uv8), 0.85, Painter_DepthSigma, Painter_NormalSigma);

    accum += CS184_GetSceneColor(uv1) * w1;
    accum += CS184_GetSceneColor(uv2) * w2;
    accum += CS184_GetSceneColor(uv3) * w3;
    accum += CS184_GetSceneColor(uv4) * w4;
    accum += CS184_GetSceneColor(uv5) * w5;
    accum += CS184_GetSceneColor(uv6) * w6;
    accum += CS184_GetSceneColor(uv7) * w7;
    accum += CS184_GetSceneColor(uv8) * w8;

    weightSum += w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8;
    return accum / max(weightSum, 1e-4);
}

float4 Painter_PS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 baseColor = CS184_GetSceneColor(texcoord);
    if (!CS184_HasDepth)
        return float4(baseColor, 1.0);

    CS184SurfaceData surface = CS184_LoadSurfaceData(texcoord);
    float3 blurred = Painter_BilateralBlur(texcoord, surface.depth, surface.normal);

    float depthLayer = saturate(surface.depth * 3.0);
    float pigmentPool = saturate((1.0 - surface.ao) * 0.65 + surface.curvature * 0.70);
    float washAmount = Painter_WashStrength * lerp(0.82, 1.08, depthLayer) * lerp(1.0, 1.15, pigmentPool);

    float3 painter = lerp(surface.color, blurred, saturate(washAmount));
    float luma = CS184_Luminance(painter);
    painter = lerp(float3(luma, luma, luma), painter, 0.88);

    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;
    painter *= 1.0 - pigmentPool * 0.08;
    painter = pow(saturate(painter), float3(0.92, 0.92, 0.92));
    painter = floor(saturate(painter) * max(Painter_PosterLevels, 2.0)) / max(Painter_PosterLevels, 2.0);

    float edgeSignal = surface.edgeDepth * 5.2 + surface.edgeNormal * 2.8 + surface.curvature * 1.3;
    float contour = smoothstep(0.08, 0.38, edgeSignal);

    float3 lightDir = CS184_SafeNormalize(Painter_LightDir);
    float3 halfVec = CS184_SafeNormalize(lightDir + surface.viewDir);
    float glaze = pow(saturate(dot(surface.normal, halfVec)), lerp(18.0, 52.0, 1.0 - surface.roughness));
    glaze *= smoothstep(0.20, 0.70, contour) * smoothstep(0.35, 0.85, saturate(dot(surface.normal, lightDir)));

    float grain = Painter_Grain(texcoord);
    float grainMod = 0.985 + Painter_GrainStrength * grain * lerp(0.85, 1.15, pigmentPool);

    static const float3 paper = float3(0.95, 0.88, 0.74);
    static const float3 lineColor = float3(0.42, 0.28, 0.10);
    static const float3 gold = float3(0.82, 0.68, 0.30);

    float3 result = lerp(paper, painter, 0.92);
    result = lerp(result, lineColor, contour * Painter_ContourStrength * 0.55);
    result = lerp(result, gold, glaze * Painter_GlazeStrength);
    result *= grainMod;

    return float4(lerp(baseColor, saturate(result), Painter_EffectBlend), 1.0);
}

technique CS184_Painter_GBuffer <
    ui_tooltip = "Painterly abstraction driven by real depth and normals, with bilateral wash, contour accents, pigment pooling, and paper finish.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = Painter_PS;
    }
}
