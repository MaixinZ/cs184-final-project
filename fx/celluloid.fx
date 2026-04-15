// CS184 celluloid style adapted for ReShade
// Source memory:
// - memory/celluloid.md
// - shaders/celluloid.frag
//
// This version stays framebuffer-only, but improves weak low-saturation and dim scenes
// by using local contrast assists, adaptive band lifting, and darker-scene outline support.

#include "ReShade.fxh"

texture2D Celluloid_SourceTex : COLOR;
sampler2D Celluloid_SourceSampler
{
    Texture = Celluloid_SourceTex;
    AddressU = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = POINT;
};

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

uniform float Celluloid_FogWeight <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Amount of atmospheric flattening in detail-poor regions.";
> = 0.55;

uniform float Celluloid_ContrastBoost <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.5; ui_max = 2.5;
    ui_tooltip = "Boosts local contrast before band classification. Useful when scenes are flat or low saturation.";
> = 1.5;

uniform float Celluloid_DarkSceneAssist <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Lifts band separation, rim, and spec support in dark scenes without brightening the whole frame.";
> = 0.55;

uniform float Celluloid_OutlineAssist <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Additional outline sensitivity in low-contrast and low-saturation scenes.";
> = 0.55;

float Celluloid_Luminance(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

float Celluloid_SaturationEstimate(float3 color)
{
    float cMin = min(min(color.r, color.g), color.b);
    float cMax = max(max(color.r, color.g), color.b);
    return cMax - cMin;
}

float3 Celluloid_SampleRegionAverage(float2 uv, float2 texel, float radius)
{
    float2 dx = float2(texel.x * radius, 0.0);
    float2 dy = float2(0.0, texel.y * radius);

    float3 color = float3(0.0, 0.0, 0.0);
    color += tex2D(Celluloid_SourceSampler, uv).rgb * 4.0;
    color += tex2D(Celluloid_SourceSampler, uv + dx).rgb;
    color += tex2D(Celluloid_SourceSampler, uv - dx).rgb;
    color += tex2D(Celluloid_SourceSampler, uv + dy).rgb;
    color += tex2D(Celluloid_SourceSampler, uv - dy).rgb;
    color += tex2D(Celluloid_SourceSampler, uv + dx + dy).rgb;
    color += tex2D(Celluloid_SourceSampler, uv - dx - dy).rgb;
    color += tex2D(Celluloid_SourceSampler, uv + dx - dy).rgb;
    color += tex2D(Celluloid_SourceSampler, uv + float2(-dx.x, dy.y)).rgb;
    return color / 12.0;
}

float2 Celluloid_EvalLumaGradient(float2 uv, float2 texel)
{
    float lL = Celluloid_Luminance(Celluloid_SampleRegionAverage(uv - float2(texel.x, 0.0), texel, 1.0));
    float lR = Celluloid_Luminance(Celluloid_SampleRegionAverage(uv + float2(texel.x, 0.0), texel, 1.0));
    float lU = Celluloid_Luminance(Celluloid_SampleRegionAverage(uv + float2(0.0, texel.y), texel, 1.0));
    float lD = Celluloid_Luminance(Celluloid_SampleRegionAverage(uv - float2(0.0, texel.y), texel, 1.0));
    return float2(lR - lL, lU - lD);
}

float3 Celluloid_EvalPseudoNormal(float2 lumaGradient, float normalGain)
{
    return normalize(float3(-lumaGradient * normalGain, 1.0));
}

float Celluloid_EvalCelBand(float signalValue, float threshold, float softness)
{
    return smoothstep(threshold - softness, threshold + softness, signalValue);
}

float Celluloid_EvalBandIndex(float shadeSignal)
{
    float bandIndex = 0.0;
    bandIndex += Celluloid_EvalCelBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    bandIndex += Celluloid_EvalCelBand(shadeSignal, Celluloid_MidThreshold, Celluloid_ShadowSoftness);
    bandIndex += Celluloid_EvalCelBand(shadeSignal, Celluloid_HighlightThreshold, Celluloid_ShadowSoftness * 0.75);
    return bandIndex;
}

float3 Celluloid_EvalCelDiffuse(float3 baseColor, float shadeSignal)
{
    static const float3 lightTint = float3(1.10, 1.03, 0.96);
    static const float3 midTint = float3(0.92, 0.96, 1.00);
    static const float3 shadowTint = float3(0.68, 0.78, 0.96);

    float shadowToMid = Celluloid_EvalCelBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    float midToLight = Celluloid_EvalCelBand(shadeSignal, Celluloid_MidThreshold, Celluloid_ShadowSoftness);
    float lightToHighlight = Celluloid_EvalCelBand(shadeSignal, Celluloid_HighlightThreshold, Celluloid_ShadowSoftness * 0.75);

    float3 shadowRegion = baseColor * shadowTint;
    float3 midRegion = baseColor * midTint;
    float3 lightRegion = baseColor * lightTint;
    float3 highlightRegion = lerp(lightRegion, float3(1.0, 1.0, 1.0), 0.22);

    float3 diffuse = lerp(shadowRegion, midRegion, shadowToMid);
    diffuse = lerp(diffuse, lightRegion, midToLight);
    diffuse = lerp(diffuse, highlightRegion, lightToHighlight * 0.65);
    return diffuse;
}

float Celluloid_EvalStylizedShadow(float shadeSignal, float cavityMask, float darkAssist)
{
    float broadShadow = 1.0 - Celluloid_EvalCelBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    return saturate(max(broadShadow * lerp(0.88, 0.72, darkAssist), cavityMask * lerp(0.55, 0.68, darkAssist)));
}

float3 Celluloid_EvalAmbientHemisphere(float3 normalValue, float3 baseColor, float cavityMask)
{
    float3 skyColor = float3(0.53, 0.67, 0.84);
    float3 groundColor = float3(0.40, 0.34, 0.28);
    float hemiMix = normalValue.y * 0.5 + 0.5;
    float3 hemiColor = lerp(groundColor, skyColor, hemiMix);
    float ambientStrength = lerp(0.46, 0.24, cavityMask);
    return baseColor * hemiColor * ambientStrength;
}

float Celluloid_EvalSpecularMask(float3 normalValue, float3 lightDirValue, float3 viewDirValue, float shadeSignal, float materialMask, float darkAssist)
{
    float3 halfVector = normalize(lightDirValue + viewDirValue);
    float ndh = max(dot(normalValue, halfVector), 0.0);
    float specSignal = pow(ndh, 18.0);
    float specMask = smoothstep(Celluloid_SpecThreshold - 0.08, Celluloid_SpecThreshold + 0.08, specSignal);
    specMask *= smoothstep(0.50 - darkAssist * 0.14, 0.85 - darkAssist * 0.08, shadeSignal);
    specMask *= materialMask;
    return specMask;
}

float3 Celluloid_EvalStylizedSpecular(float3 normalValue, float3 lightDirValue, float3 viewDirValue, float shadeSignal, float materialMask, float darkAssist)
{
    static const float3 specColor = float3(1.00, 0.94, 0.84);
    return specColor * Celluloid_EvalSpecularMask(normalValue, lightDirValue, viewDirValue, shadeSignal, materialMask, darkAssist) * lerp(0.48, 0.56, darkAssist);
}

float Celluloid_EvalRimMask(float3 normalValue, float3 viewDirValue, float edgeMask, float shadowMask, float darkAssist)
{
    float rim = 1.0 - max(dot(normalValue, viewDirValue), 0.0);
    rim = pow(rim, lerp(1.35, 1.18, darkAssist));
    rim = smoothstep(Celluloid_RimThreshold - darkAssist * 0.10, 1.0, rim);
    rim *= lerp(0.45, 1.0, shadowMask);
    rim *= lerp(lerp(0.35, 0.55, darkAssist), 0.85, edgeMask);
    return rim;
}

float Celluloid_EvalOutline(float2 lumaGradient, float3 baseColor, float3 smoothColor, float contrastAssist, float darkAssist)
{
    float outlineThreshold = Celluloid_OutlineThreshold * lerp(1.0, 0.70, darkAssist * Celluloid_OutlineAssist);
    float lumaEdge = length(lumaGradient);
    float chromaEdge = length(baseColor - smoothColor);
    float edgeSignal = lumaEdge * lerp(2.2, 3.3, darkAssist * Celluloid_OutlineAssist);
    edgeSignal += chromaEdge * lerp(1.35, 1.85, contrastAssist);
    edgeSignal += contrastAssist * 0.14;
    return smoothstep(outlineThreshold, outlineThreshold + 0.12, edgeSignal);
}

float Celluloid_EvalFogFactor(float detailMask, float contrastAssist, float2 uv)
{
    float farProxy = smoothstep(0.18, 0.82, 1.0 - detailMask);
    float skyBias = smoothstep(0.20, 0.92, uv.y);
    float fogSuppression = 1.0 - contrastAssist * 0.35;
    return saturate((farProxy * 0.78 + skyBias * 0.22) * Celluloid_FogWeight * fogSuppression);
}

float3 Celluloid_ApplyAtmosphere(float3 colorValue, float fogFactor)
{
    static const float3 atmosphereColor = float3(0.74, 0.82, 0.92);

    float3 foggedColor = lerp(colorValue, atmosphereColor, fogFactor * 0.38);
    float foggedLuma = Celluloid_Luminance(foggedColor);
    float3 flattenedColor = lerp(foggedColor, lerp(float3(foggedLuma, foggedLuma, foggedLuma), atmosphereColor, 0.35), fogFactor * 0.30);
    return lerp(colorValue, flattenedColor, fogFactor);
}

float3 Celluloid_ApplyBandPreservingTonemap(float3 colorValue)
{
    float peak = max(max(colorValue.r, colorValue.g), colorValue.b);
    float shoulder = max(peak - 1.0, 0.0);
    colorValue /= 1.0 + shoulder * 0.65;
    colorValue = pow(max(colorValue, float3(0.0, 0.0, 0.0)), float3(0.96, 0.96, 0.96));
    return saturate(colorValue);
}

float3 Celluloid_BandDebugColor(float bandIndex)
{
    if (bandIndex < 0.5)
        return float3(0.16, 0.23, 0.44);
    if (bandIndex < 1.5)
        return float3(0.39, 0.53, 0.82);
    if (bandIndex < 2.5)
        return float3(0.85, 0.72, 0.39);
    return float3(0.98, 0.93, 0.76);
}

float4 Celluloid_PS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 texel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float3 baseColor = tex2D(Celluloid_SourceSampler, texcoord).rgb;
    float3 smoothColor = Celluloid_SampleRegionAverage(texcoord, texel, 1.0);
    float3 wideColor = Celluloid_SampleRegionAverage(texcoord, texel, 2.3);
    float smoothLuma = Celluloid_Luminance(smoothColor);
    float wideLuma = Celluloid_Luminance(wideColor);
    float2 lumaGradient = Celluloid_EvalLumaGradient(texcoord, texel);

    float baseSaturation = Celluloid_SaturationEstimate(baseColor);
    float lowSatAssist = 1.0 - smoothstep(0.06, 0.24, baseSaturation);
    float darkAssist = (1.0 - smoothstep(0.18, 0.46, smoothLuma)) * Celluloid_DarkSceneAssist;
    float contrastAssist = saturate(
        length(lumaGradient) * 2.8 * Celluloid_ContrastBoost +
        abs(smoothLuma - wideLuma) * 2.1 * Celluloid_ContrastBoost +
        length(baseColor - smoothColor) * 1.2
    );

    float normalGain = lerp(3.2, 4.6, saturate(darkAssist + lowSatAssist * 0.35));
    float3 pseudoNormal = Celluloid_EvalPseudoNormal(lumaGradient, normalGain);

    float3 lightDirValue = normalize(Celluloid_LightDir);
    float3 viewDirValue = float3(0.0, 0.0, 1.0);

    float ndotl = max(dot(pseudoNormal, lightDirValue), 0.0);
    float boostedNdotL = saturate(ndotl + contrastAssist * 0.08 + darkAssist * 0.08);
    float detailMask = saturate(length(baseColor - smoothColor) * 1.8 + abs(smoothLuma - wideLuma) * 1.4 + length(lumaGradient) * 2.4);
    float cavityMask = smoothstep(0.16, 0.62, detailMask + contrastAssist * 0.16) * (1.0 - smoothstep(0.60 - darkAssist * 0.12, 0.92, smoothLuma));
    float liftedLuma = smoothLuma + contrastAssist * 0.14 + darkAssist * 0.18 + lowSatAssist * 0.06;
    float remappedLuma = smoothstep(0.05, 0.90, saturate(liftedLuma));
    float shadeSignal = saturate(lerp(remappedLuma, boostedNdotL, 0.62 + lowSatAssist * 0.08) + 0.04);
    float bandIndex = Celluloid_EvalBandIndex(shadeSignal);

    float3 celDiffuse = Celluloid_EvalCelDiffuse(smoothColor, shadeSignal);
    float shadowMask = Celluloid_EvalStylizedShadow(shadeSignal, cavityMask, darkAssist);
    float3 ambientTerm = Celluloid_EvalAmbientHemisphere(pseudoNormal, smoothColor, cavityMask);

    float specMask = smoothstep(0.16 - darkAssist * 0.08, 0.78, smoothLuma + contrastAssist * 0.16 + lowSatAssist * 0.04);
    specMask *= (1.0 - cavityMask * 0.25);
    float3 specularTerm = Celluloid_EvalStylizedSpecular(pseudoNormal, lightDirValue, viewDirValue, shadeSignal, specMask, darkAssist);

    float outlineMask = Celluloid_EvalOutline(lumaGradient, baseColor, smoothColor, saturate(contrastAssist + lowSatAssist * 0.25), darkAssist);
    float rimMask = Celluloid_EvalRimMask(pseudoNormal, viewDirValue, outlineMask, shadowMask, darkAssist);

    static const float3 rimColor = float3(0.98, 0.90, 0.72);
    static const float3 outlineColor = float3(0.19, 0.15, 0.18);

    float3 rimTerm = rimColor * rimMask * 0.42;
    float fogFactor = Celluloid_EvalFogFactor(detailMask, saturate(contrastAssist + darkAssist * 0.30), texcoord);

    float3 litColor = celDiffuse + ambientTerm + specularTerm + rimTerm;
    litColor = lerp(litColor, baseColor, lerp(0.18, 0.10, saturate(darkAssist + lowSatAssist * 0.20)));

    float3 localOutlineColor = lerp(baseColor * 0.28, outlineColor, 0.75);
    float outlineBlend = outlineMask * (1.0 - fogFactor * 0.65);
    litColor = lerp(litColor, localOutlineColor, outlineBlend * 0.88);
    litColor = Celluloid_ApplyAtmosphere(litColor, fogFactor);
    litColor = Celluloid_ApplyBandPreservingTonemap(litColor);

    float3 debugColor = litColor;
    if (Celluloid_DebugMode == 1)
        debugColor = float3(boostedNdotL, boostedNdotL, boostedNdotL);
    else if (Celluloid_DebugMode == 2)
        debugColor = Celluloid_BandDebugColor(bandIndex);
    else if (Celluloid_DebugMode == 3)
        debugColor = float3(shadowMask, shadowMask, shadowMask);
    else if (Celluloid_DebugMode == 4)
        debugColor = float3(rimMask, rimMask, rimMask);
    else if (Celluloid_DebugMode == 5)
        debugColor = float3(outlineMask, outlineMask, outlineMask);
    else if (Celluloid_DebugMode == 6)
        debugColor = float3(fogFactor, fogFactor, fogFactor);

    return float4(lerp(baseColor, saturate(debugColor), Celluloid_EffectBlend), 1.0);
}

technique CS184_Celluloid <
    ui_tooltip = "Image-space cel shading approximation with pseudo normals, grouped bands, stylized shadow, rim light, outlines, and atmosphere.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = Celluloid_PS;
    }
}
