// CS184 celluloid style adapted for ReShade
// Source memory:
// - memory/celluloid.md
// - shaders/celluloid.frag

#ifndef CELLULOID_APPEND_FX
#define CELLULOID_APPEND_FX

#ifndef CELLULOID_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

uniform float Celluloid_EffectBlend <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend between the original image and the cel-rendered approximation.";
> = 1.0;

uniform int Celluloid_DebugMode <
    ui_category = "Celluloid";
    ui_type = "combo";
    ui_items = "Final\0NdotL\0Band\0Shadow\0Rim\0Outline\0Fog\0";
    ui_tooltip = "Debug output selection.";
> = 0;

uniform float3 Celluloid_LightDir <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = -1.0; ui_max = 1.0;
    ui_tooltip = "Stylized light direction used by the pseudo-normal lighting pass.";
> = float3(-0.45, 0.35, 0.82);

uniform float Celluloid_ShadowThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Entry point of the shadow band.";
> = 0.36;

uniform float Celluloid_ShadowSoftness <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 0.2;
    ui_tooltip = "Softness for the cel band transitions.";
> = 0.06;

uniform float Celluloid_MidThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Transition point from mid band to lit band.";
> = 0.58;

uniform float Celluloid_HighlightThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Threshold for the highlight band.";
> = 0.82;

uniform float Celluloid_SpecThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Threshold for the stylized specular response.";
> = 0.58;

uniform float Celluloid_RimThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Threshold for the rim-light mask.";
> = 0.42;

uniform float Celluloid_OutlineThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.01; ui_max = 0.40;
    ui_tooltip = "Sensitivity of screen-space outline extraction.";
> = 0.16;

uniform int Celluloid_GradientMode <
    ui_category = "Celluloid";
    ui_type = "combo";
    ui_items = "Central Difference\0Sobel\0Scharr\0";
    ui_tooltip = "Gradient kernel used by pseudo normals and outline extraction. Sobel is the default balanced option, Scharr is slightly stronger and more rotation-stable.";
> = 1;

uniform float Celluloid_FogWeight <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Amount of atmospheric flattening in detail-poor regions.";
> = 0.55;

float CelluloidAppend_Luminance(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

float3 CelluloidAppend_SampleRegionAverage(sampler source_sampler, float2 uv, float2 texel)
{
    float3 color = 0.0.xxx;
    color += tex2D(source_sampler, uv).rgb * 4.0;
    color += tex2D(source_sampler, uv + float2(texel.x, 0.0)).rgb;
    color += tex2D(source_sampler, uv - float2(texel.x, 0.0)).rgb;
    color += tex2D(source_sampler, uv + float2(0.0, texel.y)).rgb;
    color += tex2D(source_sampler, uv - float2(0.0, texel.y)).rgb;
    color += tex2D(source_sampler, uv + texel).rgb;
    color += tex2D(source_sampler, uv - texel).rgb;
    color += tex2D(source_sampler, uv + float2(texel.x, -texel.y)).rgb;
    color += tex2D(source_sampler, uv + float2(-texel.x, texel.y)).rgb;
    return color / 12.0;
}

float CelluloidAppend_SampleBlurredLuma(sampler source_sampler, float2 uv, float2 texel)
{
    return CelluloidAppend_Luminance(CelluloidAppend_SampleRegionAverage(source_sampler, uv, texel));
}

float2 CelluloidAppend_EvalCentralGradient(sampler source_sampler, float2 uv, float2 texel)
{
    float lL = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - float2(texel.x, 0.0), texel);
    float lR = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(texel.x, 0.0), texel);
    float lU = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(0.0, texel.y), texel);
    float lD = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - float2(0.0, texel.y), texel);
    return float2(lR - lL, lU - lD);
}

float2 CelluloidAppend_EvalSobelGradient(sampler source_sampler, float2 uv, float2 texel)
{
    float tl = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(-texel.x, texel.y), texel);
    float tc = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(0.0, texel.y), texel);
    float tr = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + texel, texel);
    float ml = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - float2(texel.x, 0.0), texel);
    float mr = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(texel.x, 0.0), texel);
    float bl = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - texel, texel);
    float bc = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - float2(0.0, texel.y), texel);
    float br = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(texel.x, -texel.y), texel);

    float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    float gy = (tl + 2.0 * tc + tr) - (bl + 2.0 * bc + br);
    return float2(gx, gy) * 0.25;
}

float2 CelluloidAppend_EvalScharrGradient(sampler source_sampler, float2 uv, float2 texel)
{
    float tl = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(-texel.x, texel.y), texel);
    float tc = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(0.0, texel.y), texel);
    float tr = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + texel, texel);
    float ml = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - float2(texel.x, 0.0), texel);
    float mr = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(texel.x, 0.0), texel);
    float bl = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - texel, texel);
    float bc = CelluloidAppend_SampleBlurredLuma(source_sampler, uv - float2(0.0, texel.y), texel);
    float br = CelluloidAppend_SampleBlurredLuma(source_sampler, uv + float2(texel.x, -texel.y), texel);

    float gx = (3.0 * tr + 10.0 * mr + 3.0 * br) - (3.0 * tl + 10.0 * ml + 3.0 * bl);
    float gy = (3.0 * tl + 10.0 * tc + 3.0 * tr) - (3.0 * bl + 10.0 * bc + 3.0 * br);
    return float2(gx, gy) * (1.0 / 16.0);
}

float2 CelluloidAppend_EvalLumaGradient(sampler source_sampler, float2 uv, float2 texel)
{
    if (Celluloid_GradientMode == 1)
        return CelluloidAppend_EvalSobelGradient(source_sampler, uv, texel);
    if (Celluloid_GradientMode == 2)
        return CelluloidAppend_EvalScharrGradient(source_sampler, uv, texel);
    return CelluloidAppend_EvalCentralGradient(source_sampler, uv, texel);
}

float3 CelluloidAppend_EvalPseudoNormal(float2 lumaGradient)
{
    return normalize(float3(-lumaGradient * 3.2, 1.0));
}

float CelluloidAppend_EvalCelBand(float signalValue, float threshold, float softness)
{
    return smoothstep(threshold - softness, threshold + softness, signalValue);
}

float CelluloidAppend_EvalBandIndex(float shadeSignal)
{
    float bandIndex = 0.0;
    bandIndex += CelluloidAppend_EvalCelBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    bandIndex += CelluloidAppend_EvalCelBand(shadeSignal, Celluloid_MidThreshold, Celluloid_ShadowSoftness);
    bandIndex += CelluloidAppend_EvalCelBand(shadeSignal, Celluloid_HighlightThreshold, Celluloid_ShadowSoftness * 0.75);
    return bandIndex;
}

float3 CelluloidAppend_EvalCelDiffuse(float3 baseColor, float shadeSignal)
{
    static const float3 lightTint = float3(1.10, 1.03, 0.96);
    static const float3 midTint = float3(0.92, 0.96, 1.00);
    static const float3 shadowTint = float3(0.68, 0.78, 0.96);

    float shadowToMid = CelluloidAppend_EvalCelBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    float midToLight = CelluloidAppend_EvalCelBand(shadeSignal, Celluloid_MidThreshold, Celluloid_ShadowSoftness);
    float lightToHighlight = CelluloidAppend_EvalCelBand(shadeSignal, Celluloid_HighlightThreshold, Celluloid_ShadowSoftness * 0.75);

    float3 shadowRegion = baseColor * shadowTint;
    float3 midRegion = baseColor * midTint;
    float3 lightRegion = baseColor * lightTint;
    float3 highlightRegion = lerp(lightRegion, 1.0.xxx, 0.22);

    float3 diffuse = lerp(shadowRegion, midRegion, shadowToMid);
    diffuse = lerp(diffuse, lightRegion, midToLight);
    diffuse = lerp(diffuse, highlightRegion, lightToHighlight * 0.65);
    return diffuse;
}

float CelluloidAppend_EvalStylizedShadow(float shadeSignal, float cavityMask)
{
    float broadShadow = 1.0 - CelluloidAppend_EvalCelBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    return saturate(max(broadShadow * 0.88, cavityMask * 0.55));
}

float3 CelluloidAppend_EvalAmbientHemisphere(float3 normalValue, float3 baseColor, float aoMask)
{
    float3 skyColor = float3(0.53, 0.67, 0.84);
    float3 groundColor = float3(0.40, 0.34, 0.28);
    float hemiMix = normalValue.y * 0.5 + 0.5;
    float3 hemiColor = lerp(groundColor, skyColor, hemiMix);
    float ambientStrength = lerp(0.58, 0.34, aoMask);
    return baseColor * hemiColor * ambientStrength;
}

float CelluloidAppend_EvalSpecularMask(float3 normalValue, float3 lightDirValue, float3 viewDirValue, float shadeSignal, float materialMask)
{
    float3 halfVector = normalize(lightDirValue + viewDirValue);
    float ndh = max(dot(normalValue, halfVector), 0.0);
    float specSignal = pow(ndh, 18.0);
    float specMask = smoothstep(Celluloid_SpecThreshold - 0.08, Celluloid_SpecThreshold + 0.08, specSignal);
    specMask *= smoothstep(0.50, 0.85, shadeSignal);
    specMask *= materialMask;
    return specMask;
}

float3 CelluloidAppend_EvalStylizedSpecular(float3 normalValue, float3 lightDirValue, float3 viewDirValue, float shadeSignal, float materialMask)
{
    static const float3 specColor = float3(1.00, 0.94, 0.84);
    return specColor * CelluloidAppend_EvalSpecularMask(normalValue, lightDirValue, viewDirValue, shadeSignal, materialMask) * 0.48;
}

float CelluloidAppend_EvalRimMask(float3 normalValue, float3 viewDirValue, float edgeMask, float shadowMask)
{
    float rim = 1.0 - max(dot(normalValue, viewDirValue), 0.0);
    rim = pow(rim, 1.35);
    rim = smoothstep(Celluloid_RimThreshold, 1.0, rim);
    rim *= lerp(0.45, 1.0, shadowMask);
    rim *= lerp(0.35, 0.85, edgeMask);
    return rim;
}

float CelluloidAppend_EvalOutline(float2 lumaGradient, float3 baseColor, float3 smoothColor)
{
    float lumaEdge = length(lumaGradient);
    float chromaEdge = length(baseColor - smoothColor);
    float edgeSignal = lumaEdge * 2.2 + chromaEdge * 1.35;
    return smoothstep(Celluloid_OutlineThreshold, Celluloid_OutlineThreshold + 0.12, edgeSignal);
}

float CelluloidAppend_EvalFogFactor(float detailMask, float2 uv)
{
    float farProxy = smoothstep(0.18, 0.82, 1.0 - detailMask);
    float skyBias = smoothstep(0.20, 0.92, uv.y);
    return saturate((farProxy * 0.78 + skyBias * 0.22) * Celluloid_FogWeight);
}

float3 CelluloidAppend_ApplyAtmosphere(float3 colorValue, float fogFactor)
{
    static const float3 atmosphereColor = float3(0.74, 0.82, 0.92);

    float3 foggedColor = lerp(colorValue, atmosphereColor, fogFactor * 0.38);
    float foggedLuma = CelluloidAppend_Luminance(foggedColor);
    float3 flattenedColor = lerp(foggedColor, lerp(foggedLuma.xxx, atmosphereColor, 0.35), fogFactor * 0.30);
    return lerp(colorValue, flattenedColor, fogFactor);
}

float3 CelluloidAppend_ApplyBandPreservingTonemap(float3 colorValue)
{
    float peak = max(max(colorValue.r, colorValue.g), colorValue.b);
    float shoulder = max(peak - 1.0, 0.0);
    colorValue /= 1.0 + shoulder * 0.65;
    colorValue = pow(max(colorValue, 0.0.xxx), float3(0.96, 0.96, 0.96));
    return saturate(colorValue);
}

float3 CelluloidAppend_BandDebugColor(float bandIndex)
{
    if (bandIndex < 0.5)
        return float3(0.16, 0.23, 0.44);
    if (bandIndex < 1.5)
        return float3(0.39, 0.53, 0.82);
    if (bandIndex < 2.5)
        return float3(0.85, 0.72, 0.39);
    return float3(0.98, 0.93, 0.76);
}

float3 CelluloidAppend_ApplyFromSampler(sampler source_sampler, float2 texcoord)
{
    float2 texel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float3 baseColor = tex2D(source_sampler, texcoord).rgb;
    float3 smoothColor = CelluloidAppend_SampleRegionAverage(source_sampler, texcoord, texel);
    float smoothLuma = CelluloidAppend_Luminance(smoothColor);
    float2 lumaGradient = CelluloidAppend_EvalLumaGradient(source_sampler, texcoord, texel);
    float3 pseudoNormal = CelluloidAppend_EvalPseudoNormal(lumaGradient);

    float3 lightDirValue = normalize(Celluloid_LightDir);
    float3 viewDirValue = float3(0.0, 0.0, 1.0);

    float ndotl = max(dot(pseudoNormal, lightDirValue), 0.0);
    float detailMask = saturate(length(baseColor - smoothColor) * 1.8 + length(lumaGradient) * 2.4);
    float cavityMask = smoothstep(0.18, 0.65, detailMask) * (1.0 - smoothstep(0.58, 0.92, smoothLuma));
    float shadeSignal = saturate(lerp(smoothLuma, ndotl, 0.62) + 0.10);
    float bandIndex = CelluloidAppend_EvalBandIndex(shadeSignal);

    float3 celDiffuse = CelluloidAppend_EvalCelDiffuse(smoothColor, shadeSignal);
    float shadowMask = CelluloidAppend_EvalStylizedShadow(shadeSignal, cavityMask);
    float3 ambientTerm = CelluloidAppend_EvalAmbientHemisphere(pseudoNormal, smoothColor, cavityMask);
    float specMask = smoothstep(0.24, 0.82, smoothLuma) * (1.0 - detailMask * 0.30);
    float3 specularTerm = CelluloidAppend_EvalStylizedSpecular(pseudoNormal, lightDirValue, viewDirValue, shadeSignal, specMask);
    float outlineMask = CelluloidAppend_EvalOutline(lumaGradient, baseColor, smoothColor);
    float rimMask = CelluloidAppend_EvalRimMask(pseudoNormal, viewDirValue, outlineMask, shadowMask);

    static const float3 rimColor = float3(0.98, 0.90, 0.72);
    static const float3 outlineColor = float3(0.19, 0.15, 0.18);

    float3 rimTerm = rimColor * rimMask * 0.42;
    float fogFactor = CelluloidAppend_EvalFogFactor(detailMask, texcoord);

    float3 litColor = celDiffuse + ambientTerm + specularTerm + rimTerm;
    litColor = lerp(litColor, baseColor, 0.18);

    float3 localOutlineColor = lerp(baseColor * 0.28, outlineColor, 0.75);
    float outlineBlend = outlineMask * (1.0 - fogFactor * 0.65);
    litColor = lerp(litColor, localOutlineColor, outlineBlend * 0.88);
    litColor = CelluloidAppend_ApplyAtmosphere(litColor, fogFactor);
    litColor = CelluloidAppend_ApplyBandPreservingTonemap(litColor);

    float3 debugColor = litColor;
    if (Celluloid_DebugMode == 1)
        debugColor = ndotl.xxx;
    else if (Celluloid_DebugMode == 2)
        debugColor = CelluloidAppend_BandDebugColor(bandIndex);
    else if (Celluloid_DebugMode == 3)
        debugColor = shadowMask.xxx;
    else if (Celluloid_DebugMode == 4)
        debugColor = rimMask.xxx;
    else if (Celluloid_DebugMode == 5)
        debugColor = outlineMask.xxx;
    else if (Celluloid_DebugMode == 6)
        debugColor = fogFactor.xxx;

    return lerp(baseColor, saturate(debugColor), Celluloid_EffectBlend);
}

#ifndef CELLULOID_APPEND_LIBRARY_MODE
float4 CelluloidAppend_PS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(CelluloidAppend_ApplyFromSampler(ReShade::BackBuffer, texcoord), 1.0);
}

technique CS184_Celluloid_Append <
    ui_tooltip = "Append-labeled copy of the celluloid effect.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CelluloidAppend_PS;
    }
}
#endif

#endif
