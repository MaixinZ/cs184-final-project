// Geometry-driven celluloid style for ReShade.
// Uses real depth and normal information instead of luma-derived pseudo lighting.

#include "geometry.fxh"

uniform float Celluloid_EffectBlend <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend between the original scene color and the cel-shaded result.";
> = 1.0;

uniform int Celluloid_DebugMode <
    ui_category = "Celluloid";
    ui_type = "combo";
    ui_items = "Final\0Depth\0NdotL\0Band\0Shadow\0Rim\0Outline\0Fog\0";
    ui_tooltip = "Debug output selection.";
> = 0;

uniform float3 Celluloid_LightDir <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = -1.0; ui_max = 1.0;
    ui_tooltip = "Directional light used for cel band placement.";
> = float3(-0.45, 0.35, 0.82);

uniform float Celluloid_ShadowThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Start of the shadow-to-mid transition.";
> = 0.36;

uniform float Celluloid_ShadowSoftness <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 0.20;
    ui_tooltip = "Band transition softness.";
> = 0.06;

uniform float Celluloid_MidThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Start of the lit band.";
> = 0.58;

uniform float Celluloid_HighlightThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Start of the highlight band.";
> = 0.82;

uniform float Celluloid_SpecThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Threshold applied to the stylized specular response.";
> = 0.58;

uniform float Celluloid_RimThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Threshold for rim light activation.";
> = 0.42;

uniform float Celluloid_OutlineThreshold <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.02; ui_max = 1.0;
    ui_tooltip = "Sensitivity of normal/depth contour extraction.";
> = 0.16;

uniform float Celluloid_FogWeight <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Amount of atmospheric simplification by depth.";
> = 0.55;

uniform float Celluloid_FogStart <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linear depth where atmospheric flattening begins.";
> = 0.22;

uniform float Celluloid_FogEnd <
    ui_category = "Celluloid";
    ui_type = "drag";
    ui_min = 0.05; ui_max = 1.0;
    ui_tooltip = "Linear depth where atmospheric flattening reaches full strength.";
> = 0.82;

float Celluloid_EvalBand(float value, float threshold, float softness)
{
    return smoothstep(threshold - softness, threshold + softness, value);
}

float Celluloid_EvalBandIndex(float shadeSignal)
{
    float index = 0.0;
    index += Celluloid_EvalBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    index += Celluloid_EvalBand(shadeSignal, Celluloid_MidThreshold, Celluloid_ShadowSoftness);
    index += Celluloid_EvalBand(shadeSignal, Celluloid_HighlightThreshold, Celluloid_ShadowSoftness * 0.75);
    return index;
}

float3 Celluloid_EvalDiffuse(float3 baseColor, float shadeSignal)
{
    static const float3 lightTint = float3(1.10, 1.03, 0.96);
    static const float3 midTint = float3(0.92, 0.96, 1.00);
    static const float3 shadowTint = float3(0.68, 0.78, 0.96);

    float shadowToMid = Celluloid_EvalBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness);
    float midToLight = Celluloid_EvalBand(shadeSignal, Celluloid_MidThreshold, Celluloid_ShadowSoftness);
    float lightToHighlight = Celluloid_EvalBand(shadeSignal, Celluloid_HighlightThreshold, Celluloid_ShadowSoftness * 0.75);

    float3 shadowRegion = baseColor * shadowTint;
    float3 midRegion = baseColor * midTint;
    float3 lightRegion = baseColor * lightTint;
    float3 highlightRegion = lerp(lightRegion, float3(1.0, 1.0, 1.0), 0.22);

    float3 diffuse = lerp(shadowRegion, midRegion, shadowToMid);
    diffuse = lerp(diffuse, lightRegion, midToLight);
    diffuse = lerp(diffuse, highlightRegion, lightToHighlight * 0.65);
    return diffuse;
}

float3 Celluloid_AmbientHemisphere(float3 normalValue, float3 baseColor, float ao)
{
    float3 skyColor = float3(0.53, 0.67, 0.84);
    float3 groundColor = float3(0.40, 0.34, 0.28);
    float hemiMix = normalValue.y * 0.5 + 0.5;
    float3 hemiColor = lerp(groundColor, skyColor, hemiMix);
    float ambientStrength = lerp(0.58, 0.34, 1.0 - ao);
    return baseColor * hemiColor * ambientStrength;
}

float3 Celluloid_Tonemap(float3 colorValue)
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

float4 Celluloid_PS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 baseColor = CS184_GetSceneColor(texcoord);
    if (!CS184_HasDepth)
        return float4(baseColor, 1.0);

    CS184SurfaceData surface = CS184_LoadSurfaceData(texcoord);
    float3 lightDir = CS184_SafeNormalize(Celluloid_LightDir);
    float ndotl = saturate(dot(surface.normal, lightDir));
    float shadeSignal = saturate(ndotl * lerp(0.88, 1.0, surface.ao) + surface.ao * 0.12);
    float bandIndex = Celluloid_EvalBandIndex(shadeSignal);

    float3 celDiffuse = Celluloid_EvalDiffuse(surface.color, shadeSignal);
    float shadowMask = saturate(max(1.0 - Celluloid_EvalBand(shadeSignal, Celluloid_ShadowThreshold, Celluloid_ShadowSoftness), (1.0 - surface.ao) * 0.60));
    float3 ambientTerm = Celluloid_AmbientHemisphere(surface.normal, surface.color, surface.ao);

    float3 halfVector = CS184_SafeNormalize(lightDir + surface.viewDir);
    float specExponent = lerp(10.0, 44.0, 1.0 - surface.roughness);
    float specSignal = pow(saturate(dot(surface.normal, halfVector)), specExponent);
    float specMask = smoothstep(Celluloid_SpecThreshold - 0.08, Celluloid_SpecThreshold + 0.08, specSignal);
    specMask *= smoothstep(0.50, 0.85, shadeSignal);
    float3 specularTerm = float3(1.00, 0.94, 0.84) * specMask * 0.48;

    float rimSignal = pow(1.0 - saturate(dot(surface.normal, surface.viewDir)), 1.35);
    float rimMask = smoothstep(Celluloid_RimThreshold, 1.0, rimSignal);
    rimMask *= lerp(0.45, 1.0, shadowMask);
    float3 rimTerm = float3(0.98, 0.90, 0.72) * rimMask * 0.42;

    float edgeSignal = surface.edgeDepth * 5.5 + surface.edgeNormal * 2.5 + surface.curvature * 0.9;
    float outlineMask = smoothstep(Celluloid_OutlineThreshold, Celluloid_OutlineThreshold + 0.16, edgeSignal);

    float fogFactor = smoothstep(Celluloid_FogStart, max(Celluloid_FogEnd, Celluloid_FogStart + 0.01), surface.depth) * Celluloid_FogWeight;
    float3 atmosphereColor = float3(0.74, 0.82, 0.92);

    float3 litColor = celDiffuse + ambientTerm + specularTerm + rimTerm;
    litColor = lerp(litColor, baseColor, 0.18);

    float3 localOutlineColor = lerp(baseColor * 0.28, float3(0.19, 0.15, 0.18), 0.75);
    float outlineBlend = outlineMask * (1.0 - fogFactor * 0.65);
    litColor = lerp(litColor, localOutlineColor, outlineBlend * 0.88);

    float3 foggedColor = lerp(litColor, atmosphereColor, fogFactor * 0.38);
    float foggedLuma = CS184_Luminance(foggedColor);
    float3 flattenedColor = lerp(foggedColor, lerp(float3(foggedLuma, foggedLuma, foggedLuma), atmosphereColor, 0.35), fogFactor * 0.30);
    litColor = lerp(litColor, flattenedColor, fogFactor);
    litColor = Celluloid_Tonemap(litColor);

    float3 debugColor = litColor;
    if (Celluloid_DebugMode == 1)
        debugColor = float3(surface.depth, surface.depth, surface.depth);
    else if (Celluloid_DebugMode == 2)
        debugColor = float3(ndotl, ndotl, ndotl);
    else if (Celluloid_DebugMode == 3)
        debugColor = Celluloid_BandDebugColor(bandIndex);
    else if (Celluloid_DebugMode == 4)
        debugColor = float3(shadowMask, shadowMask, shadowMask);
    else if (Celluloid_DebugMode == 5)
        debugColor = float3(rimMask, rimMask, rimMask);
    else if (Celluloid_DebugMode == 6)
        debugColor = float3(outlineMask, outlineMask, outlineMask);
    else if (Celluloid_DebugMode == 7)
        debugColor = float3(fogFactor, fogFactor, fogFactor);

    return float4(lerp(baseColor, saturate(debugColor), Celluloid_EffectBlend), 1.0);
}

technique CS184_Celluloid_GBuffer <
    ui_tooltip = "Geometry-driven cel shading with true normal lighting, depth/normal outlines, rim light, and linear-depth atmospheric perspective.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = Celluloid_PS;
    }
}
