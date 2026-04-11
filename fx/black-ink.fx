// Geometry-driven black-ink style for ReShade.
// Uses depth/normal contours, contact structure, black mass grouping, and screentone.

#include "geometry.fxh"

uniform float BlackInk_EffectBlend <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend between the original scene color and the black-ink result.";
> = 1.0;

uniform int BlackInk_DebugMode <
    ui_category = "Black Ink";
    ui_type = "combo";
    ui_items = "Final\0Depth\0Silhouette\0Crease\0Contact\0Shadow\0Black Fill\0Screentone\0Line Priority\0Ink Coverage\0";
    ui_tooltip = "Debug output selection.";
> = 0;

uniform float3 BlackInk_LightDir <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = -1.0; ui_max = 1.0;
    ui_tooltip = "Directional light used for black-mass and hatch grouping.";
> = float3(-0.28, 0.18, 0.94);

uniform float BlackInk_OutlineThreshold <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.02; ui_max = 1.0;
    ui_tooltip = "Sensitivity of silhouette and crease extraction from geometry.";
> = 0.10;

uniform float BlackInk_BlackFillThreshold <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.20; ui_max = 1.0;
    ui_tooltip = "Threshold for collapsing shadow structure into solid black masses.";
> = 0.58;

uniform float BlackInk_ToneStrength <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.3;
    ui_tooltip = "Strength of screentone dots and hatching.";
> = 1.0;

uniform float BlackInk_DistanceSimplify <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "How strongly distance collapses detail into simpler line/tone groups.";
> = 0.55;

uniform float BlackInk_PaperWhiteness <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.92; ui_max = 1.02;
    ui_tooltip = "Brightness of the paper base before print darkening.";
> = 0.985;

float2 BlackInk_Rotate(float2 value, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2(c * value.x - s * value.y, s * value.x + c * value.y);
}

float BlackInk_DotTone(float2 pixelPos, float density)
{
    float2 rotated = BlackInk_Rotate(pixelPos, 0.48);
    float2 cell = frac(rotated / 7.0) - 0.5;
    float dist = length(cell);
    float radius = lerp(0.06, 0.38, density);
    return 1.0 - smoothstep(radius, radius + 0.05, dist);
}

float BlackInk_Hatch(float2 pixelPos, float density, float angle)
{
    float2 rotated = BlackInk_Rotate(pixelPos, angle);
    float stripe = abs(frac(rotated.x / 8.0) - 0.5);
    float thickness = lerp(0.46, 0.14, density);
    return 1.0 - smoothstep(thickness, thickness + 0.06, stripe);
}

float BlackInk_CrossHatch(float2 pixelPos, float density, float angle)
{
    float2 rotated = BlackInk_Rotate(pixelPos, angle + 1.5707963);
    float stripe = abs(frac(rotated.x / 8.0) - 0.5);
    float thickness = lerp(0.48, 0.16, density);
    return 1.0 - smoothstep(thickness, thickness + 0.06, stripe);
}

float BlackInk_PaperNoise(float2 pixelPos)
{
    return frac(sin(dot(pixelPos * float2(0.91, 1.07), float2(12.9898, 78.233))) * 43758.5453);
}

float4 BlackInk_PS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 baseColor = CS184_GetSceneColor(texcoord);
    if (!CS184_HasDepth)
        return float4(baseColor, 1.0);

    CS184SurfaceData surface = CS184_LoadSurfaceData(texcoord);
    float2 pixelPos = texcoord * BUFFER_SCREEN_SIZE;
    float3 lightDir = CS184_SafeNormalize(BlackInk_LightDir);

    float depthFade = smoothstep(0.18, 0.82, surface.depth) * BlackInk_DistanceSimplify;
    float viewFacing = 1.0 - saturate(abs(dot(surface.normal, surface.viewDir)));
    float silhouetteSignal = surface.edgeDepth * 5.8 + surface.edgeNormal * 2.2 + viewFacing * 0.75;
    float silhouetteMask = smoothstep(BlackInk_OutlineThreshold, BlackInk_OutlineThreshold + 0.20, silhouetteSignal);

    float creaseSignal = surface.curvature * 2.4 + surface.edgeNormal * 1.4;
    float creaseMask = smoothstep(BlackInk_OutlineThreshold * 1.1, BlackInk_OutlineThreshold * 1.1 + 0.22, creaseSignal);
    creaseMask *= lerp(1.0, 0.72, depthFade);

    float lightFacingness = saturate(dot(surface.normal, lightDir) * 0.5 + 0.5);
    float contactSignal = surface.edgeDepth * 7.0 * (1.0 - lightFacingness * 0.35) + (1.0 - surface.ao) * 0.85 + surface.curvature * 0.55;
    float contactMask = smoothstep(0.12, 0.42, contactSignal);

    float shadowClass = saturate((1.0 - lightFacingness) * 0.74 + (1.0 - surface.ao) * 0.40 + depthFade * 0.14);
    float blackSeed = shadowClass * 0.72 + contactMask * 0.58 + creaseMask * 0.24;
    float blackFillMask = smoothstep(BlackInk_BlackFillThreshold, BlackInk_BlackFillThreshold + 0.24, blackSeed);

    float2 hatchBasis = CS184_SafeNormalize(float3(surface.normal.y + lightDir.y * 0.35, -surface.normal.x - lightDir.x * 0.35, 0.0)).xy;
    float hatchAngle = atan2(hatchBasis.y, hatchBasis.x);

    float mildTone = smoothstep(0.22, 0.44, shadowClass) * (1.0 - smoothstep(0.58, 0.74, shadowClass));
    float denseTone = smoothstep(0.46, 0.70, shadowClass) * (1.0 - blackFillMask);

    float dotDensity = saturate(shadowClass * 1.10);
    float hatchDensity = saturate((shadowClass - 0.20) * 1.35);
    float crossDensity = saturate((shadowClass - 0.48) * 2.00);

    float dots = BlackInk_DotTone(pixelPos, dotDensity);
    float hatch = BlackInk_Hatch(pixelPos, hatchDensity, hatchAngle);
    float cross = BlackInk_CrossHatch(pixelPos, crossDensity, hatchAngle);

    float screentoneMask = lerp(dots * mildTone, hatch * denseTone, 0.55 + surface.roughness * 0.20);
    screentoneMask = max(screentoneMask, cross * denseTone * smoothstep(0.62, 0.82, shadowClass));
    screentoneMask *= BlackInk_ToneStrength;
    screentoneMask *= lerp(1.0, 0.72, depthFade);
    screentoneMask = saturate(screentoneMask * (1.0 - blackFillMask));

    float linePriority = silhouetteMask * 1.00 + creaseMask * 0.58 + contactMask * 0.82;
    linePriority *= lerp(1.0, 0.65, depthFade);
    linePriority = saturate(linePriority);

    float silhouetteInk = smoothstep(0.08, 0.52, silhouetteMask) * lerp(0.88, 1.00, linePriority);
    float creaseInk = smoothstep(0.12, 0.66, creaseMask) * lerp(0.42, 0.84, linePriority);
    float contactInk = smoothstep(0.10, 0.58, contactMask) * lerp(0.72, 0.96, linePriority);
    float lineInk = saturate(max(max(silhouetteInk, creaseInk), contactInk));

    float reserveWhite = smoothstep(0.78, 0.98, lightFacingness) * smoothstep(0.75, 0.95, surface.ao) * blackFillMask;
    float blackCoverage = smoothstep(0.36, 0.82, blackFillMask * (1.0 - reserveWhite));
    float toneCoverage = smoothstep(0.18, 0.70, screentoneMask) * 0.84;
    float inkCoverage = max(blackCoverage, max(toneCoverage, lineInk));
    inkCoverage = max(inkCoverage, silhouetteMask * 0.90);
    inkCoverage = saturate(inkCoverage);

    float paperTone = BlackInk_PaperWhiteness + BlackInk_PaperNoise(pixelPos) * 0.012;
    float3 paperTint = float3(paperTone, paperTone, paperTone);
    float3 finalColor = lerp(float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0), inkCoverage);
    finalColor = min(finalColor, paperTint);
    finalColor = lerp(finalColor, float3(0.0, 0.0, 0.0), smoothstep(0.58, 0.95, inkCoverage) * 0.08);
    finalColor = saturate(finalColor);

    float3 debugColor = finalColor;
    if (BlackInk_DebugMode == 1)
        debugColor = float3(surface.depth, surface.depth, surface.depth);
    else if (BlackInk_DebugMode == 2)
        debugColor = float3(silhouetteMask, silhouetteMask, silhouetteMask);
    else if (BlackInk_DebugMode == 3)
        debugColor = float3(creaseMask, creaseMask, creaseMask);
    else if (BlackInk_DebugMode == 4)
        debugColor = float3(contactMask, contactMask, contactMask);
    else if (BlackInk_DebugMode == 5)
        debugColor = float3(shadowClass, shadowClass, shadowClass);
    else if (BlackInk_DebugMode == 6)
        debugColor = float3(blackFillMask, blackFillMask, blackFillMask);
    else if (BlackInk_DebugMode == 7)
        debugColor = float3(screentoneMask, screentoneMask, screentoneMask);
    else if (BlackInk_DebugMode == 8)
        debugColor = float3(linePriority, linePriority, linePriority);
    else if (BlackInk_DebugMode == 9)
        debugColor = float3(inkCoverage, inkCoverage, inkCoverage);

    return float4(lerp(baseColor, debugColor, BlackInk_EffectBlend), 1.0);
}

technique CS184_BlackInk_GBuffer <
    ui_tooltip = "Monochrome comic abstraction driven by depth/normal silhouettes, curvature lines, contact structure, black masses, and screentone.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlackInk_PS;
    }
}
