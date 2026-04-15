// CS184 black-ink style adapted for ReShade
// Source memory:
// - memory/black-ink.md
// - shaders/black-ink.frag
//
// Note:
// ReShade post-processing often receives an opaque backbuffer alpha.
// This version preserves the original alpha-driven silhouette logic when
// alpha is informative, but falls back to luma-based contour cues when it is not.

#include "ReShade.fxh"

texture2D BlackInk_SourceTex : COLOR;
sampler2D BlackInk_SourceSampler
{
    Texture = BlackInk_SourceTex;
    AddressU = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = POINT;
};

uniform float BlackInk_EffectBlend <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend between the original image and the monochrome ink treatment.";
> = 1.0;

uniform int BlackInk_DebugMode <
    ui_category = "Black Ink";
    ui_type = "combo";
    ui_items = "Final\0Light Facingness\0Silhouette\0Internal Edge\0Shadow\0Contact Edge\0Black Fill\0Screentone\0Hatch Direction\0Line Priority\0Ink Coverage\0";
    ui_tooltip = "Debug output selection.";
> = 0;

uniform float3 BlackInk_LightDir <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = -1.0; ui_max = 1.0;
    ui_tooltip = "Stylized light direction for shadow grouping and hatch orientation.";
> = float3(-0.28, 0.18, 0.94);

uniform float BlackInk_ShadowThreshold <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Shadow threshold for the pseudo lighting classifier.";
> = 0.28;

uniform float BlackInk_MidThreshold <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Mid-tone threshold used by the light-facingness estimator.";
> = 0.46;

uniform float BlackInk_HighlightThreshold <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Highlight threshold used by the light-facingness estimator.";
> = 0.70;

uniform float BlackInk_OutlineThreshold <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.01; ui_max = 0.30;
    ui_tooltip = "Sensitivity of silhouette, crease, and contact-line extraction.";
> = 0.10;

uniform float BlackInk_ToneStrength <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.3;
    ui_tooltip = "Strength of screentone and hatch coverage.";
> = 1.0;

uniform float BlackInk_DotBoost <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.5; ui_max = 2.0;
    ui_tooltip = "Extra emphasis for dot screentone before hatch takeover.";
> = 1.65;

uniform float BlackInk_DarkOutlineAssist <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Relaxes outline thresholds in dark scenes to reduce contour drop-out.";
> = 0.38;

uniform float BlackInk_PaperWhiteness <
    ui_category = "Black Ink";
    ui_type = "drag";
    ui_min = 0.92; ui_max = 1.02;
    ui_tooltip = "Paper base brightness before print darkening.";
> = 0.885;

float BlackInk_Luminance(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

float BlackInk_SaturationEstimate(float3 color)
{
    float cMin = min(min(color.r, color.g), color.b);
    float cMax = max(max(color.r, color.g), color.b);
    return cMax - cMin;
}

float2x2 BlackInk_Rotation2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, -s, s, c);
}

float3 BlackInk_SampleCrossBlur(float2 uv, float2 texel, float radius)
{
    float2 dx = float2(texel.x * radius, 0.0);
    float2 dy = float2(0.0, texel.y * radius);

    float3 color = tex2D(BlackInk_SourceSampler, uv).rgb * 4.0;
    color += tex2D(BlackInk_SourceSampler, uv + dx).rgb;
    color += tex2D(BlackInk_SourceSampler, uv - dx).rgb;
    color += tex2D(BlackInk_SourceSampler, uv + dy).rgb;
    color += tex2D(BlackInk_SourceSampler, uv - dy).rgb;
    color += tex2D(BlackInk_SourceSampler, uv + dx + dy).rgb;
    color += tex2D(BlackInk_SourceSampler, uv - dx - dy).rgb;
    color += tex2D(BlackInk_SourceSampler, uv + dx - dy).rgb;
    color += tex2D(BlackInk_SourceSampler, uv - dx + dy).rgb;
    return color / 12.0;
}

float2 BlackInk_EvalGradientField(float2 uv, float2 texel, float radius)
{
    float lL = BlackInk_Luminance(BlackInk_SampleCrossBlur(uv - float2(texel.x * radius, 0.0), texel, radius));
    float lR = BlackInk_Luminance(BlackInk_SampleCrossBlur(uv + float2(texel.x * radius, 0.0), texel, radius));
    float lU = BlackInk_Luminance(BlackInk_SampleCrossBlur(uv + float2(0.0, texel.y * radius), texel, radius));
    float lD = BlackInk_Luminance(BlackInk_SampleCrossBlur(uv - float2(0.0, texel.y * radius), texel, radius));
    return float2(lR - lL, lU - lD);
}

float3 BlackInk_EvalPseudoNormal(float2 gradientField)
{
    return normalize(float3(-gradientField * 3.0, 1.0));
}

float BlackInk_EvalLightFacingness(float3 pseudoNormal, float3 lightDirValue, float lumaValue)
{
    float ndotl = max(dot(pseudoNormal, lightDirValue), 0.0);
    float broad = smoothstep(BlackInk_ShadowThreshold, BlackInk_MidThreshold + 0.05, ndotl);
    float highlight = smoothstep(BlackInk_MidThreshold, BlackInk_HighlightThreshold + 0.05, ndotl);
    return saturate(lerp(lumaValue, broad, 0.58) + highlight * 0.10);
}

float BlackInk_EvalAlphaReliability(float alphaValue, float alphaRange, float2 alphaGradient)
{
    float deviation = abs(alphaValue - 1.0);
    return saturate(alphaRange * 8.0 + length(alphaGradient) * 6.0 + deviation * 3.0);
}

float BlackInk_EvalViewSilhouette(
    float alphaValue,
    float alphaRange,
    float2 alphaGradient,
    float2 lumaGradient,
    float broadContrast,
    float alphaReliability,
    float darkAssist
)
{
    float outlineThreshold = BlackInk_OutlineThreshold * lerp(1.0, 0.72, darkAssist);
    float alphaEdge = smoothstep(0.01, 0.16, length(alphaGradient));
    float alphaShell = smoothstep(0.03, 0.34, alphaRange) * smoothstep(0.01, 0.995, alphaValue);
    float lumaEdge = smoothstep(outlineThreshold * 0.48, outlineThreshold * 1.45, length(lumaGradient));
    float broadEdge = smoothstep(0.03, 0.16, broadContrast + darkAssist * 0.03);
    float alphaCue = max(alphaEdge, alphaShell) * lerp(0.15, 0.95, alphaReliability);
    float lumaCue = max(lumaEdge * lerp(0.78, 0.96, darkAssist), broadEdge * lerp(0.48, 0.66, darkAssist));
    return saturate(max(alphaCue, lumaCue));
}

float BlackInk_EvalCreaseLine(float2 lumaGradient, float3 baseColor, float3 smallBlur, float detailMask, float darkAssist)
{
    float outlineThreshold = BlackInk_OutlineThreshold * lerp(1.0, 0.78, darkAssist);
    float lumaEdge = smoothstep(outlineThreshold * 0.44, outlineThreshold * 1.55, length(lumaGradient));
    float chromaEdge = smoothstep(0.03, 0.18, length(baseColor - smallBlur));
    return saturate((lumaEdge * lerp(0.72, 0.88, darkAssist) + chromaEdge * 0.28) * lerp(0.52, 1.0, detailMask));
}

float BlackInk_EvalContactEdge(float cavityMask, float2 lumaGradient, float shadowSignal, float darkAssist)
{
    float grounded = smoothstep(0.10, 0.34, cavityMask);
    float outlineThreshold = BlackInk_OutlineThreshold * lerp(1.0, 0.76, darkAssist);
    float compression = smoothstep(outlineThreshold * 0.38, outlineThreshold * 1.05, length(lumaGradient));
    return saturate(grounded * compression * lerp(0.45, 1.0, shadowSignal));
}

float BlackInk_EvalLinePriority(float silhouetteMask, float creaseMask, float contactMask, float detailMask, float depthProxy)
{
    float priority = silhouetteMask * 1.00 + creaseMask * 0.58 + contactMask * 0.82;
    priority *= lerp(1.0, 0.68, depthProxy);
    priority *= lerp(0.62, 1.0, detailMask);
    return saturate(priority);
}

float BlackInk_ClassifyShadowRegion(float lightFacingness, float lumaValue, float cavityMask)
{
    float shadowSignal = (1.0 - lightFacingness) * 0.68;
    shadowSignal += cavityMask * 0.34;
    shadowSignal += (1.0 - lumaValue) * 0.16;
    return saturate(shadowSignal);
}

float BlackInk_EvalBlackFillMask(float shadowClass, float contactMask, float joinedDarkness)
{
    float blackSeed = shadowClass * 0.72 + contactMask * 0.58 + joinedDarkness * 0.34;
    return smoothstep(0.58, 0.82, blackSeed);
}

float BlackInk_EvalDotTone(float2 pixelPos, float density)
{
    float2 rotated = mul(BlackInk_Rotation2D(0.48), pixelPos);
    float2 cell = frac(rotated / 7.0) - 0.5;
    float dist = length(cell);
    float radius = lerp(0.06, 0.38, density);
    return 1.0 - smoothstep(radius, radius + 0.05, dist);
}

float BlackInk_EvalHatchPattern(float2 pixelPos, float density, float angle)
{
    float2 rotated = mul(BlackInk_Rotation2D(angle), pixelPos);
    float stripe = abs(frac(rotated.x / 8.0) - 0.5);
    float thickness = lerp(0.46, 0.14, density);
    return 1.0 - smoothstep(thickness, thickness + 0.06, stripe);
}

float BlackInk_EvalCrossHatchPattern(float2 pixelPos, float density, float angle)
{
    float2 rotated = mul(BlackInk_Rotation2D(angle + 1.5707963), pixelPos);
    float stripe = abs(frac(rotated.x / 8.0) - 0.5);
    float thickness = lerp(0.48, 0.16, density);
    return 1.0 - smoothstep(thickness, thickness + 0.06, stripe);
}

float BlackInk_EvalScreentoneMask(
    float shadowClass,
    float blackFillMask,
    float materialStyle,
    float2 pixelPos,
    float hatchAngle,
    out float hatchDirectionDebug
)
{
    float mildTone = smoothstep(0.22, 0.44, shadowClass) * (1.0 - smoothstep(0.58, 0.74, shadowClass));
    float denseTone = smoothstep(0.46, 0.70, shadowClass) * (1.0 - blackFillMask);

    float dotDensity = saturate(shadowClass * 1.10);
    float hatchDensity = saturate((shadowClass - 0.20) * 1.35);
    float crossDensity = saturate((shadowClass - 0.48) * 2.00);

    float dots = BlackInk_EvalDotTone(pixelPos, dotDensity);
    dots = saturate(dots * BlackInk_DotBoost);
    float hatch = BlackInk_EvalHatchPattern(pixelPos, hatchDensity, hatchAngle);
    float cross = BlackInk_EvalCrossHatchPattern(pixelPos, crossDensity, hatchAngle);

    hatchDirectionDebug = frac(hatchAngle / 6.2831853);

    float tone = lerp(dots * mildTone, hatch * denseTone, saturate(materialStyle * 0.92));
    tone = max(tone, cross * denseTone * smoothstep(0.62, 0.82, shadowClass));
    return saturate(tone * (1.0 - blackFillMask) * BlackInk_ToneStrength);
}

float3 BlackInk_CompositeInkLayers(
    float blackFillMask,
    float screentoneMask,
    float silhouetteMask,
    float creaseMask,
    float contactMask,
    float linePriority,
    float reserveWhite,
    out float inkCoverage
)
{
    float silhouetteInk = smoothstep(0.08, 0.52, silhouetteMask) * lerp(0.88, 1.00, linePriority);
    float creaseInk = smoothstep(0.12, 0.66, creaseMask) * lerp(0.42, 0.84, linePriority);
    float contactInk = smoothstep(0.10, 0.58, contactMask) * lerp(0.72, 0.96, linePriority);

    float lineInk = saturate(max(max(silhouetteInk, creaseInk), contactInk));
    float blackCoverage = smoothstep(0.36, 0.82, blackFillMask * (1.0 - reserveWhite));
    float toneCoverage = smoothstep(0.18, 0.70, screentoneMask) * 0.84;
    float coverage = max(blackCoverage, max(toneCoverage, lineInk));
    coverage = max(coverage, silhouetteMask * 0.90);
    inkCoverage = saturate(coverage);

    return lerp(1.0.xxx, 0.0.xxx, inkCoverage);
}

float3 BlackInk_ApplyPaperAndPrintFinish(float3 inkColor, float inkCoverage, float2 pixelPos)
{
    float paperNoise = frac(sin(dot(pixelPos * float2(0.91, 1.07), float2(12.9898, 78.233))) * 43758.5453);
    float paperTone = BlackInk_PaperWhiteness + paperNoise * 0.012;
    float3 paperTint = paperTone.xxx;

    float3 result = min(inkColor, paperTint);
    float inkSpread = smoothstep(0.58, 0.95, inkCoverage) * 0.08;
    result = lerp(result, 0.0.xxx, inkSpread);
    return saturate(result);
}

float4 BlackInk_PS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 texel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float2 pixelPos = texcoord * float2(BUFFER_WIDTH, BUFFER_HEIGHT);

    float4 baseSample = tex2D(BlackInk_SourceSampler, texcoord);
    float3 baseColor = baseSample.rgb;
    float alphaValue = baseSample.a;

    float3 smallBlur = BlackInk_SampleCrossBlur(texcoord, texel, 1.0);
    float3 mediumBlur = BlackInk_SampleCrossBlur(texcoord, texel, 2.2);
    float3 largeBlur = BlackInk_SampleCrossBlur(texcoord, texel, 4.0);

    float lumaValue = BlackInk_Luminance(baseColor);
    float smallLuma = BlackInk_Luminance(smallBlur);
    float mediumLuma = BlackInk_Luminance(mediumBlur);
    float largeLuma = BlackInk_Luminance(largeBlur);

    float2 lumaGradient = BlackInk_EvalGradientField(texcoord, texel, 1.0);
    float2 alphaGradient = float2(
        tex2D(BlackInk_SourceSampler, texcoord + float2(texel.x, 0.0)).a - tex2D(BlackInk_SourceSampler, texcoord - float2(texel.x, 0.0)).a,
        tex2D(BlackInk_SourceSampler, texcoord + float2(0.0, texel.y)).a - tex2D(BlackInk_SourceSampler, texcoord - float2(0.0, texel.y)).a
    );
    float alphaLeft = tex2D(BlackInk_SourceSampler, texcoord - float2(texel.x, 0.0)).a;
    float alphaRight = tex2D(BlackInk_SourceSampler, texcoord + float2(texel.x, 0.0)).a;
    float alphaUp = tex2D(BlackInk_SourceSampler, texcoord + float2(0.0, texel.y)).a;
    float alphaDown = tex2D(BlackInk_SourceSampler, texcoord - float2(0.0, texel.y)).a;
    float alphaMin = min(min(alphaLeft, alphaRight), min(alphaUp, alphaDown));
    float alphaMax = max(max(alphaLeft, alphaRight), max(alphaUp, alphaDown));
    float alphaRange = alphaMax - alphaMin;

    float3 pseudoNormal = BlackInk_EvalPseudoNormal(lumaGradient);
    float3 lightDirValue = normalize(BlackInk_LightDir);

    float detailMask = saturate(length(baseColor - mediumBlur) * 2.0 + length(lumaGradient) * 2.6);
    float depthProxy = 1.0 - smoothstep(0.10, 0.78, detailMask);
    float cavityMask = smoothstep(0.05, 0.26, max(mediumLuma - lumaValue, 0.0) + max(largeLuma - mediumLuma, 0.0));
    float broadContrast = max(abs(lumaValue - largeLuma), length(baseColor - mediumBlur) * 0.70);
    float alphaReliability = BlackInk_EvalAlphaReliability(alphaValue, alphaRange, alphaGradient);
    float darkAssist = (1.0 - smoothstep(0.16, 0.44, smallLuma)) * BlackInk_DarkOutlineAssist;

    float lightFacingness = BlackInk_EvalLightFacingness(pseudoNormal, lightDirValue, smallLuma);
    float silhouetteMask = BlackInk_EvalViewSilhouette(alphaValue, alphaRange, alphaGradient, lumaGradient, broadContrast, alphaReliability, darkAssist);
    float creaseMask = BlackInk_EvalCreaseLine(lumaGradient, baseColor, smallBlur, detailMask, darkAssist);
    float shadowClass = BlackInk_ClassifyShadowRegion(lightFacingness, lumaValue, cavityMask);
    float contactMask = BlackInk_EvalContactEdge(cavityMask, lumaGradient, shadowClass, darkAssist);
    float joinedDarkness = smoothstep(0.08, 0.38, max(largeLuma - lumaValue, 0.0));
    float blackFillMask = BlackInk_EvalBlackFillMask(shadowClass, contactMask, joinedDarkness);

    float materialStyle = smoothstep(0.06, 0.24, BlackInk_SaturationEstimate(baseColor) + detailMask * 0.18);
    float hatchAngle = atan2(lightDirValue.y, lightDirValue.x) + lerp(0.35, 0.95, materialStyle);
    float hatchDirectionDebug = 0.0;
    float screentoneMask = BlackInk_EvalScreentoneMask(
        shadowClass,
        blackFillMask,
        materialStyle,
        pixelPos,
        hatchAngle,
        hatchDirectionDebug
    );

    float linePriority = BlackInk_EvalLinePriority(silhouetteMask, creaseMask, contactMask, detailMask, depthProxy);
    float reserveWhite = smoothstep(0.74, 0.96, lightFacingness) * smoothstep(0.72, 0.95, lumaValue) * blackFillMask;

    float inkCoverage = 0.0;
    float3 inkComposite = BlackInk_CompositeInkLayers(
        blackFillMask,
        screentoneMask,
        silhouetteMask,
        creaseMask,
        contactMask,
        linePriority,
        reserveWhite,
        inkCoverage
    );
    float3 finalColor = BlackInk_ApplyPaperAndPrintFinish(inkComposite, inkCoverage, pixelPos);

    float3 debugColor = finalColor;
    if (BlackInk_DebugMode == 1)
        debugColor = lightFacingness.xxx;
    else if (BlackInk_DebugMode == 2)
        debugColor = silhouetteMask.xxx;
    else if (BlackInk_DebugMode == 3)
        debugColor = creaseMask.xxx;
    else if (BlackInk_DebugMode == 4)
        debugColor = shadowClass.xxx;
    else if (BlackInk_DebugMode == 5)
        debugColor = contactMask.xxx;
    else if (BlackInk_DebugMode == 6)
        debugColor = blackFillMask.xxx;
    else if (BlackInk_DebugMode == 7)
        debugColor = screentoneMask.xxx;
    else if (BlackInk_DebugMode == 8)
        debugColor = hatchDirectionDebug.xxx;
    else if (BlackInk_DebugMode == 9)
        debugColor = linePriority.xxx;
    else if (BlackInk_DebugMode == 10)
        debugColor = inkCoverage.xxx;

    return float4(lerp(baseColor, saturate(debugColor), BlackInk_EffectBlend), 1.0);
}

technique CS184_BlackInk <
    ui_tooltip = "Monochrome comic abstraction with silhouette logic, black fill, screentone dots, hatch, cross-hatch, and print-finish paper.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlackInk_PS;
    }
}
