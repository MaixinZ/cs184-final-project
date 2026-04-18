#ifndef SPLIT_STACK_EFFECTS_FXH
#define SPLIT_STACK_EFFECTS_FXH

#include "DepthDistanceCommon.fxh"

#define SSC_EFFECT_NONE 0
#define SSC_EFFECT_OIL_PAINT 1
#define SSC_EFFECT_PAINTER 2
#define SSC_EFFECT_CELLULOID 3
#define SSC_EFFECT_BLACK_INK 4
#define SSC_EFFECT_PIXEL_ART 5
#define SSC_EFFECT_MYOPIA 6
#define SSC_EFFECT_HYPEROPIA 7
#define SSC_EFFECT_DEPTH_PROBE 8
#define SSC_EFFECT_RG_ASSIST 9
#define SSC_EFFECT_DEPTH_FOG 10
#define SSC_EFFECT_DEPTH_LAYERED_PAINTERLY 11
#define SSC_EFFECT_DEPTH_OUTLINE 12
#define SSC_EFFECT_DEPTH_SCREENTONE 13
#define SSC_EFFECT_OIL_PAINT_APPEND 14
#define SSC_EFFECT_PAINTER_APPEND 15
#define SSC_EFFECT_CELLULOID_APPEND 16
#define SSC_EFFECT_BLACK_INK_APPEND 17
#define SSC_EFFECT_PIXEL_ART_APPEND 18
#define SSC_EFFECT_MYOPIA_APPEND 19
#define SSC_EFFECT_HYPEROPIA_APPEND 20
#define SSC_EFFECT_DEPTH_PROBE_APPEND 21
#define SSC_EFFECT_RG_ASSIST_APPEND 22
#define SSC_EFFECT_DEPTH_FOG_APPEND 23
#define SSC_EFFECT_DEPTH_LAYERED_PAINTERLY_APPEND 24
#define SSC_EFFECT_DEPTH_OUTLINE_APPEND 25
#define SSC_EFFECT_DEPTH_SCREENTONE_APPEND 26

uniform float SSC_PainterStrength < ui_category = "Split Effect - Painter"; ui_type = "slider"; ui_label = "Painter Strength"; ui_min = 0.0; ui_max = 1.0; > = 0.72;
uniform float SSC_PainterPosterLevels < ui_category = "Split Effect - Painter"; ui_type = "slider"; ui_label = "Painter Levels"; ui_min = 2.0; ui_max = 12.0; ui_step = 1.0; > = 6.0;

uniform float3 SSC_CelluloidLightDir < ui_category = "Split Effect - Celluloid"; ui_type = "drag"; ui_label = "Light Direction"; ui_min = -1.0; ui_max = 1.0; > = float3(-0.45, 0.35, 0.82);
uniform float SSC_CelluloidShadowThreshold < ui_category = "Split Effect - Celluloid"; ui_type = "slider"; ui_label = "Shadow Threshold"; ui_min = 0.0; ui_max = 1.0; > = 0.36;
uniform float SSC_CelluloidOutlineThreshold < ui_category = "Split Effect - Celluloid"; ui_type = "slider"; ui_label = "Outline Threshold"; ui_min = 0.01; ui_max = 0.40; > = 0.16;
uniform float SSC_CelluloidFogWeight < ui_category = "Split Effect - Celluloid"; ui_type = "slider"; ui_label = "Fog Weight"; ui_min = 0.0; ui_max = 1.0; > = 0.55;

uniform float3 SSC_BlackInkLightDir < ui_category = "Split Effect - Black Ink"; ui_type = "drag"; ui_label = "Light Direction"; ui_min = -1.0; ui_max = 1.0; > = float3(-0.28, 0.18, 0.94);
uniform float SSC_BlackInkOutlineThreshold < ui_category = "Split Effect - Black Ink"; ui_type = "slider"; ui_label = "Outline Threshold"; ui_min = 0.01; ui_max = 0.30; > = 0.10;
uniform float SSC_BlackInkToneStrength < ui_category = "Split Effect - Black Ink"; ui_type = "slider"; ui_label = "Tone Strength"; ui_min = 0.0; ui_max = 1.3; > = 1.0;
uniform float SSC_BlackInkPaperWhiteness < ui_category = "Split Effect - Black Ink"; ui_type = "slider"; ui_label = "Paper Whiteness"; ui_min = 0.82; ui_max = 1.05; > = 0.885;

uniform float SSC_PixelScale < ui_category = "Split Effect - Pixel Art"; ui_type = "slider"; ui_label = "Pixel Scale"; ui_min = 1.0; ui_max = 32.0; > = 8.0;
uniform float SSC_PixelColorLevels < ui_category = "Split Effect - Pixel Art"; ui_type = "slider"; ui_label = "Color Levels"; ui_min = 2.0; ui_max = 16.0; > = 6.0;
uniform float SSC_PixelSaturationBoost < ui_category = "Split Effect - Pixel Art"; ui_type = "slider"; ui_label = "Saturation Boost"; ui_min = 0.0; ui_max = 2.0; > = 1.2;

uniform float SSC_AssistStrength < ui_category = "Split Effect - RedGreen Assist"; ui_type = "slider"; ui_label = "Assist Strength"; ui_min = 0.0; ui_max = 1.0; > = 0.65;
uniform float SSC_AssistDetectionMin < ui_category = "Split Effect - RedGreen Assist"; ui_type = "slider"; ui_label = "Detection Min"; ui_min = 0.0; ui_max = 0.3; > = 0.05;
uniform float SSC_AssistDetectionMax < ui_category = "Split Effect - RedGreen Assist"; ui_type = "slider"; ui_label = "Detection Max"; ui_min = 0.05; ui_max = 0.5; > = 0.25;
uniform float SSC_AssistBlueShift < ui_category = "Split Effect - RedGreen Assist"; ui_type = "slider"; ui_label = "Blue Shift"; ui_min = 0.0; ui_max = 0.5; > = 0.18;

uniform float SSC_MyopiaDegree < ui_category = "Split Effect - Myopia"; ui_type = "slider"; ui_label = "Myopia Degree"; ui_min = 0.0; ui_max = 1.0; > = 0.55;
uniform float SSC_HyperopiaDegree < ui_category = "Split Effect - Hyperopia"; ui_type = "slider"; ui_label = "Hyperopia Degree"; ui_min = 0.0; ui_max = 1.0; > = 0.55;
uniform bool SSC_HasDepth < source = "bufready_depth"; hidden = true; > = false;

uniform int SSC_DepthProbeMode < ui_category = "Split Effect - Depth Probe"; ui_type = "combo"; ui_label = "Probe Mode"; ui_items = "Depth Tint\0Linear Depth\0Raw Hardware Depth\0Depth Contours\0"; > = 0;
uniform float SSC_DepthProbeNear < ui_category = "Split Effect - Depth Probe"; ui_type = "slider"; ui_label = "Near"; ui_min = 0.0; ui_max = 1.0; > = 0.05;
uniform float SSC_DepthProbeFar < ui_category = "Split Effect - Depth Probe"; ui_type = "slider"; ui_label = "Far"; ui_min = 0.01; ui_max = 1.0; > = 0.85;
uniform float SSC_DepthProbeTintStrength < ui_category = "Split Effect - Depth Probe"; ui_type = "slider"; ui_label = "Tint Strength"; ui_min = 0.0; ui_max = 1.0; > = 0.80;
uniform float SSC_DepthProbeContourScale < ui_category = "Split Effect - Depth Probe"; ui_type = "slider"; ui_label = "Contour Scale"; ui_min = 4.0; ui_max = 120.0; > = 32.0;

uniform float SSC_DFS_Strength < ui_category = "Split Effect - Depth Fog"; ui_type = "slider"; ui_label = "Strength"; ui_min = 0.0; ui_max = 1.0; > = 0.65;
uniform float SSC_DFS_StartDepth < ui_category = "Split Effect - Depth Fog"; ui_type = "slider"; ui_label = "Start Depth"; ui_min = 0.0; ui_max = 1.0; > = 0.24;
uniform float SSC_DFS_FullDepth < ui_category = "Split Effect - Depth Fog"; ui_type = "slider"; ui_label = "Full Depth"; ui_min = 0.01; ui_max = 1.0; > = 0.78;

uniform float SSC_DLP_Strength < ui_category = "Split Effect - Depth Layered Painterly"; ui_type = "slider"; ui_label = "Strength"; ui_min = 0.0; ui_max = 1.0; > = 0.60;
uniform float SSC_DLP_StartDepth < ui_category = "Split Effect - Depth Layered Painterly"; ui_type = "slider"; ui_label = "Start Depth"; ui_min = 0.0; ui_max = 1.0; > = 0.22;
uniform float SSC_DLP_FullDepth < ui_category = "Split Effect - Depth Layered Painterly"; ui_type = "slider"; ui_label = "Full Depth"; ui_min = 0.01; ui_max = 1.0; > = 0.76;

uniform float SSC_DOO_Strength < ui_category = "Split Effect - Depth Outline"; ui_type = "slider"; ui_label = "Strength"; ui_min = 0.0; ui_max = 1.0; > = 0.60;
uniform float SSC_DOO_EdgeSensitivity < ui_category = "Split Effect - Depth Outline"; ui_type = "slider"; ui_label = "Edge Sensitivity"; ui_min = 2.0; ui_max = 80.0; > = 28.0;

uniform float SSC_DSO_Strength < ui_category = "Split Effect - Depth Screentone"; ui_type = "slider"; ui_label = "Strength"; ui_min = 0.0; ui_max = 1.0; > = 0.60;
uniform float SSC_DSO_StartDepth < ui_category = "Split Effect - Depth Screentone"; ui_type = "slider"; ui_label = "Start Depth"; ui_min = 0.0; ui_max = 1.0; > = 0.26;
uniform float SSC_DSO_FullDepth < ui_category = "Split Effect - Depth Screentone"; ui_type = "slider"; ui_label = "Full Depth"; ui_min = 0.01; ui_max = 1.0; > = 0.82;

float SSB_Luminance(float3 color_value) { return dot(color_value, float3(0.299, 0.587, 0.114)); }
float3 SSB_SampleScene(sampler source_sampler, float2 uv) { return tex2D(source_sampler, saturate(uv)).rgb; }
float3 SSB_SceneCrossBlur(sampler source_sampler, float2 uv, float radius)
{
    float2 texel = BUFFER_PIXEL_SIZE;
    float2 dx = float2(texel.x * radius, 0.0);
    float2 dy = float2(0.0, texel.y * radius);
    float3 color = SSB_SampleScene(source_sampler, uv) * 4.0;
    color += SSB_SampleScene(source_sampler, uv + dx) + SSB_SampleScene(source_sampler, uv - dx);
    color += SSB_SampleScene(source_sampler, uv + dy) + SSB_SampleScene(source_sampler, uv - dy);
    color += SSB_SampleScene(source_sampler, uv + dx + dy) + SSB_SampleScene(source_sampler, uv - dx - dy);
    color += SSB_SampleScene(source_sampler, uv + dx - dy) + SSB_SampleScene(source_sampler, uv - dx + dy);
    return color / 12.0;
}

float3 SSB_OilPaint(sampler source_sampler, float2 uv)
{
    float2 texel = BUFFER_PIXEL_SIZE;

    float3 c = SSB_SampleScene(source_sampler, uv);
    float baseLuma = SSB_Luminance(c);

    float3 cL  = SSB_SampleScene(source_sampler, uv - float2(texel.x, 0.0));
    float3 cR  = SSB_SampleScene(source_sampler, uv + float2(texel.x, 0.0));
    float3 cU  = SSB_SampleScene(source_sampler, uv + float2(0.0, texel.y));
    float3 cD  = SSB_SampleScene(source_sampler, uv - float2(0.0, texel.y));
    float3 cUL = SSB_SampleScene(source_sampler, uv + float2(-texel.x, texel.y));
    float3 cUR = SSB_SampleScene(source_sampler, uv + float2(texel.x, texel.y));
    float3 cDL = SSB_SampleScene(source_sampler, uv + float2(-texel.x, -texel.y));
    float3 cDR = SSB_SampleScene(source_sampler, uv + float2(texel.x, -texel.y));

    float3 blur = float3(0.0, 0.0, 0.0);
    blur += c * 4.0;
    blur += cL + cR + cU + cD;
    blur += cUL + cUR + cDL + cDR;
    blur /= 12.0;

    float lL  = SSB_Luminance(cL);
    float lR  = SSB_Luminance(cR);
    float lU  = SSB_Luminance(cU);
    float lD  = SSB_Luminance(cD);
    float lUL = SSB_Luminance(cUL);
    float lUR = SSB_Luminance(cUR);
    float lDL = SSB_Luminance(cDL);
    float lDR = SSB_Luminance(cDR);

    float localMin = min(min(min(lL, lR), min(lU, lD)), min(min(lUL, lUR), min(lDL, lDR)));
    float localMax = max(max(max(lL, lR), max(lU, lD)), max(max(lUL, lUR), max(lDL, lDR)));
    float localContrast = localMax - localMin;

    float shadowProtect = 1.0 - smoothstep(0.08, 0.30, baseLuma);
    float contrastProtect = smoothstep(0.03, 0.09, localContrast);

    float blurAmount = 0.55;
    blurAmount *= (1.0 - 0.65 * shadowProtect);
    blurAmount *= (1.0 - 0.50 * contrastProtect);
    blurAmount = clamp(blurAmount, 0.10, 0.55);

    float3 painter = lerp(c, blur, blurAmount);

    float luma = SSB_Luminance(painter);
    painter = lerp(luma.xxx, painter, 0.90);

    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;

    painter = pow(painter, 0.92.xxx);

    float shadowLift = smoothstep(0.00, 0.22, baseLuma);
    float3 lifted = lerp(painter * 1.18, painter, shadowLift);
    painter = lerp(lifted, painter, 0.35);

    float levelsDark = 10.0;
    float levelsBright = 6.0;
    float levels = lerp(levelsDark, levelsBright, smoothstep(0.08, 0.45, baseLuma));
    painter = floor(painter * levels) / levels;

    float dx = lR - lL;
    float dy = lU - lD;
    float edge = length(float2(dx, dy));
    edge *= lerp(1.6, 1.0, smoothstep(0.05, 0.35, baseLuma));

    float3 paper = float3(0.95, 0.88, 0.74);
    float3 result = lerp(paper, painter, 0.92);

    edge *= 1.1;

    float3 lineColor = float3(0.42, 0.28, 0.10);
    float lineMask = smoothstep(0.035, 0.12, edge);
    result = lerp(result, lineColor, lineMask * 0.72);

    float3 gold = float3(0.82, 0.68, 0.30);
    float goldMask = smoothstep(0.09, 0.20, edge) * 0.28;
    result = lerp(result, gold, goldMask);

    float grain = frac(sin(dot(uv * float2(1400.0, 900.0), float2(12.9898, 78.233))) * 43758.5453);
    result *= 0.985 + 0.03 * grain;

    return float3(saturate(result));
}

float3 SSB_Painter(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    float3 blur = SSB_SceneCrossBlur(source_sampler, uv, 1.0);
    float3 painter = lerp(input_color, blur, SSC_PainterStrength);
    float luma = SSB_Luminance(painter);
    painter = lerp(luma.xxx, painter, 0.88);
    painter.r *= 1.10;
    painter.b *= 0.97;
    painter = pow(saturate(painter), 0.92.xxx);
    painter = floor(painter * max(SSC_PainterPosterLevels, 2.0)) / max(SSC_PainterPosterLevels, 2.0);
    float edge = length(float2(ddx(luma), ddy(luma))) * 5.0;
    float3 result = lerp(float3(0.95, 0.88, 0.74), painter, 0.90);
    result = lerp(result, float3(0.42, 0.28, 0.10), smoothstep(0.05, 0.16, edge) * 0.55);
    result = lerp(result, float3(0.82, 0.68, 0.30), smoothstep(0.10, 0.22, edge) * 0.35);
    result *= 0.985 + 0.03 * DDS_PaperNoise(uv * BUFFER_SCREEN_SIZE);
    return saturate(result);
}

float3 SSB_Celluloid(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    float3 smoothColor = SSB_SceneCrossBlur(source_sampler, uv, 1.0);
    float smoothLuma = SSB_Luminance(smoothColor);
    float3 pseudoNormal = normalize(float3(-float2(ddx(smoothLuma), ddy(smoothLuma)) * 3.2, 1.0));
    float shadeSignal = saturate(lerp(smoothLuma, max(dot(pseudoNormal, normalize(SSC_CelluloidLightDir)), 0.0), 0.62) + 0.10);
    float shadowToMid = smoothstep(SSC_CelluloidShadowThreshold - 0.06, SSC_CelluloidShadowThreshold + 0.06, shadeSignal);
    float midToLight = smoothstep(0.58 - 0.06, 0.58 + 0.06, shadeSignal);
    float lightToHighlight = smoothstep(0.82 - 0.04, 0.82 + 0.04, shadeSignal);
    float3 diffuse = lerp(smoothColor * float3(0.68, 0.78, 0.96), smoothColor * float3(0.92, 0.96, 1.00), shadowToMid);
    diffuse = lerp(diffuse, smoothColor * float3(1.10, 1.03, 0.96), midToLight);
    diffuse = lerp(diffuse, 1.0.xxx, lightToHighlight * 0.18);
    float outline = smoothstep(SSC_CelluloidOutlineThreshold, SSC_CelluloidOutlineThreshold + 0.12, length(float2(ddx(smoothLuma), ddy(smoothLuma))) * 4.0);
    float fog = smoothstep(0.18, 0.82, 1.0 - saturate(length(input_color - smoothColor) * 1.8)) * SSC_CelluloidFogWeight;
    float3 lit = lerp(diffuse, float3(0.74, 0.82, 0.92), fog * 0.24);
    lit = lerp(lit, float3(0.19, 0.15, 0.18), outline * (1.0 - fog * 0.65) * 0.88);
    return saturate(lerp(input_color, lit, 1.0));
}

float3 SSB_BlackInk(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    float3 mediumBlur = SSB_SceneCrossBlur(source_sampler, uv, 2.2);
    float lumaValue = SSB_Luminance(input_color);
    float blurLuma = SSB_Luminance(mediumBlur);
    float2 gradient = float2(ddx(blurLuma), ddy(blurLuma)) * float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float3 pseudoNormal = normalize(float3(-gradient * 0.12, 1.0));
    float lightFacing = saturate(lerp(lumaValue, max(dot(pseudoNormal, normalize(SSC_BlackInkLightDir)), 0.0), 0.58));
    float shadowClass = saturate((1.0 - lightFacing) * 0.72 + smoothstep(0.08, 0.38, max(blurLuma - lumaValue, 0.0)) * 0.34);
    float lineMask = smoothstep(SSC_BlackInkOutlineThreshold, SSC_BlackInkOutlineThreshold + 0.16, length(gradient) * 0.02);
    float dots = smoothstep(0.44, 0.82, frac(sin(dot(uv * BUFFER_SCREEN_SIZE * 0.21, float2(12.9898, 78.233))) * 43758.5453));
    float screentone = dots * smoothstep(0.22, 0.70, shadowClass) * SSC_BlackInkToneStrength * (1.0 - lineMask * 0.7);
    float inkCoverage = saturate(max(lineMask, screentone));
    float paperNoise = frac(sin(dot(uv * BUFFER_SCREEN_SIZE * float2(0.91, 1.07), float2(12.9898, 78.233))) * 43758.5453);
    float paperTone = SSC_BlackInkPaperWhiteness + paperNoise * 0.012;
    float3 result = min(lerp(1.0.xxx, 0.0.xxx, inkCoverage), paperTone.xxx);
    return saturate(result);
}

float3 SSB_PixelArt(sampler source_sampler, float2 uv)
{
    float2 texSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 pixelGrid = texSize / max(SSC_PixelScale, 1.0);
    float2 snappedUV = (floor(uv * pixelGrid) + 0.5) / pixelGrid;
    float3 c = SSB_SampleScene(source_sampler, snappedUV);
    c = floor(c * max(SSC_PixelColorLevels, 2.0)) / max(SSC_PixelColorLevels, 2.0);
    float luma = SSB_Luminance(c);
    return saturate(lerp(luma.xxx, c, SSC_PixelSaturationBoost));
}

float3 SSB_RedGreenAssist(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    float rStrength = input_color.r - max(input_color.g, input_color.b);
    float gStrength = input_color.g - max(input_color.r, input_color.b);
    float redMask = smoothstep(SSC_AssistDetectionMin, SSC_AssistDetectionMax, rStrength);
    float greenMask = smoothstep(SSC_AssistDetectionMin, SSC_AssistDetectionMax, gStrength);
    float3 redTarget = float3(input_color.r, input_color.g * 0.75, min(input_color.b + SSC_AssistBlueShift, 1.0));
    float3 greenTarget = float3(input_color.r * 0.75, input_color.g, min(input_color.b + SSC_AssistBlueShift, 1.0));
    float3 outColor = lerp(input_color, redTarget, redMask * SSC_AssistStrength);
    outColor = lerp(outColor, greenTarget, greenMask * SSC_AssistStrength);
    return saturate(outColor);
}

float3 SSB_DepthProbe(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    if (!SSC_HasDepth) return input_color;
    float raw_depth = tex2D(ReShade::DepthBuffer, uv).x;
    float linear_depth = ReShade::GetLinearizedDepth(uv);
    float far_depth = max(SSC_DepthProbeFar, SSC_DepthProbeNear + 1e-4);
    float depth01 = saturate((linear_depth - SSC_DepthProbeNear) / (far_depth - SSC_DepthProbeNear));
    float contour = 1.0 - smoothstep(0.08, 0.14, abs(frac(depth01 * SSC_DepthProbeContourScale) - 0.5));
    if (SSC_DepthProbeMode == 1) return depth01.xxx;
    if (SSC_DepthProbeMode == 2) return raw_depth.xxx;
    if (SSC_DepthProbeMode == 3) return saturate(lerp(float3(0.02, 0.02, 0.02), float3(1.0, 0.84, 0.22), contour));
    float3 tint = lerp(float3(1.00, 0.28, 0.18), float3(0.95, 0.88, 0.25), saturate(depth01 * 2.0));
    tint = lerp(tint, float3(0.20, 0.85, 1.00), saturate(depth01 * 1.15 - 0.15));
    return saturate(lerp(input_color, input_color * tint, SSC_DepthProbeTintStrength));
}

float SSB_ComputeDepthBlurFactor(float degree, bool near_blur, float linear_depth)
{
    float blur_factor = 0.0;
    if (near_blur)
    {
        float full_near_depth = lerp(0.01, 0.05, degree);
        float clear_depth = lerp(0.08, 0.28, degree);
        blur_factor = 1.0 - smoothstep(full_near_depth, max(clear_depth, full_near_depth + 1e-4), linear_depth);
    }
    else
    {
        float start_depth = lerp(0.34, 0.10, degree);
        float full_depth = lerp(0.88, 0.42, degree);
        blur_factor = smoothstep(start_depth, max(full_depth, start_depth + 1e-4), linear_depth);
    }
    return blur_factor;
}

float3 SSB_DepthBlur(sampler source_sampler, float2 uv, float degree, bool near_blur)
{
    if (!SSC_HasDepth) return SSB_SampleScene(source_sampler, uv);
    float linear_depth = ReShade::GetLinearizedDepth(uv);
    float blur_factor = SSB_ComputeDepthBlurFactor(degree, near_blur, linear_depth);
    return DDS_BilateralBlurFromSampler(source_sampler, uv, lerp(1.2, 12.0, degree) * blur_factor, 1.15);
}

float3 SSB_DepthFog(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    if (!SSC_HasDepth) return input_color;
    float linear_depth = DDS_GetLinearDepth(uv);
    float far_factor = DDS_GetDepthWindow(linear_depth, SSC_DFS_StartDepth, SSC_DFS_FullDepth) * SSC_DFS_Strength;
    float3 softened = DDS_BilateralBlurFromSampler(source_sampler, uv, lerp(0.0, 5.5, far_factor), 1.1);
    float softened_luma = DDS_Luminance(softened);
    float3 desaturated = lerp(softened, softened_luma.xxx, far_factor * 0.42);
    float3 fog_color = float3(0.66, 0.79, 0.95);
    float3 cooled = desaturated * lerp(float3(1.0, 1.0, 1.0), float3(0.92, 0.98, 1.08), far_factor);
    float3 flattened = lerp(cooled, fog_color, far_factor * 0.24);
    return saturate(lerp(input_color, flattened, far_factor));
}

float3 SSB_DepthLayeredPainterly(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    if (!SSC_HasDepth) return input_color;
    float linear_depth = DDS_GetLinearDepth(uv);
    float far_factor = DDS_GetDepthWindow(linear_depth, SSC_DLP_StartDepth, SSC_DLP_FullDepth) * SSC_DLP_Strength;
    float3 blur = SSB_SceneCrossBlur(source_sampler, uv, 1.0);
    float3 painter = lerp(input_color, blur, lerp(0.08, 0.62, far_factor));
    float painter_luma = DDS_Luminance(painter);
    painter = lerp(painter_luma.xxx, painter, 0.88);
    painter.r *= lerp(1.0, 1.08, far_factor);
    painter.b *= lerp(1.0, 0.96, far_factor);
    painter = floor(saturate(painter) * lerp(12.0, 6.0, far_factor)) / lerp(12.0, 6.0, far_factor);
    float3 painterly = lerp(float3(0.95, 0.89, 0.76), painter, 0.92);
    painterly *= 0.988 + DDS_PaperNoise(uv * BUFFER_SCREEN_SIZE) * 0.022;
    return saturate(lerp(input_color, painterly, far_factor));
}

float3 SSB_DepthOutline(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    if (!SSC_HasDepth) return input_color;
    float edge = DDS_DepthEdge(uv, SSC_DOO_EdgeSensitivity);
    float line_mask = smoothstep(0.06, 0.32, edge) * SSC_DOO_Strength;
    return lerp(input_color, float3(0.12, 0.09, 0.11), saturate(line_mask));
}

float3 SSB_DepthScreentone(sampler source_sampler, float2 uv)
{
    float3 input_color = SSB_SampleScene(source_sampler, uv);
    if (!SSC_HasDepth) return input_color;
    float linear_depth = DDS_GetLinearDepth(uv);
    float far_factor = DDS_GetDepthWindow(linear_depth, SSC_DSO_StartDepth, SSC_DSO_FullDepth) * SSC_DSO_Strength;
    float darkness = saturate(1.0 - DDS_Luminance(input_color));
    float tone_factor = far_factor * darkness;
    float2 pixel_pos = uv * BUFFER_SCREEN_SIZE;
    float cell_size = lerp(16.0, 6.0, far_factor);
    float dots = 1.0 - smoothstep(lerp(0.08, 0.34, tone_factor), lerp(0.08, 0.34, tone_factor) + 0.06, length(frac(pixel_pos / cell_size) - 0.5));
    return lerp(input_color, float3(0.14, 0.10, 0.08), dots * far_factor * 0.78);
}

float3 SSB_ApplyEffect(sampler source_sampler, float2 uv, int effect_id)
{
    float3 source_color = SSB_SampleScene(source_sampler, uv);
    if (effect_id == SSC_EFFECT_NONE) return source_color;
    if (effect_id == SSC_EFFECT_OIL_PAINT) return SSB_OilPaint(source_sampler, uv);
    if (effect_id == SSC_EFFECT_PAINTER) return SSB_Painter(source_sampler, uv);
    if (effect_id == SSC_EFFECT_CELLULOID) return SSB_Celluloid(source_sampler, uv);
    if (effect_id == SSC_EFFECT_BLACK_INK) return SSB_BlackInk(source_sampler, uv);
    if (effect_id == SSC_EFFECT_PIXEL_ART) return SSB_PixelArt(source_sampler, uv);
    if (effect_id == SSC_EFFECT_MYOPIA) return SSB_DepthBlur(source_sampler, uv, SSC_MyopiaDegree, false);
    if (effect_id == SSC_EFFECT_HYPEROPIA) return SSB_DepthBlur(source_sampler, uv, SSC_HyperopiaDegree, true);
    if (effect_id == SSC_EFFECT_DEPTH_PROBE) return SSB_DepthProbe(source_sampler, uv);
    if (effect_id == SSC_EFFECT_RG_ASSIST) return SSB_RedGreenAssist(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_FOG) return SSB_DepthFog(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_LAYERED_PAINTERLY) return SSB_DepthLayeredPainterly(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_OUTLINE) return SSB_DepthOutline(source_sampler, uv);
    if (effect_id == SSC_EFFECT_OIL_PAINT_APPEND) return SSB_OilPaint(source_sampler, uv);
    if (effect_id == SSC_EFFECT_PAINTER_APPEND) return SSB_Painter(source_sampler, uv);
    if (effect_id == SSC_EFFECT_CELLULOID_APPEND) return SSB_Celluloid(source_sampler, uv);
    if (effect_id == SSC_EFFECT_BLACK_INK_APPEND) return SSB_BlackInk(source_sampler, uv);
    if (effect_id == SSC_EFFECT_PIXEL_ART_APPEND) return SSB_PixelArt(source_sampler, uv);
    if (effect_id == SSC_EFFECT_MYOPIA_APPEND) return SSB_DepthBlur(source_sampler, uv, SSC_MyopiaDegree, false);
    if (effect_id == SSC_EFFECT_HYPEROPIA_APPEND) return SSB_DepthBlur(source_sampler, uv, SSC_HyperopiaDegree, true);
    if (effect_id == SSC_EFFECT_DEPTH_PROBE_APPEND) return SSB_DepthProbe(source_sampler, uv);
    if (effect_id == SSC_EFFECT_RG_ASSIST_APPEND) return SSB_RedGreenAssist(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_FOG_APPEND) return SSB_DepthFog(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_LAYERED_PAINTERLY_APPEND) return SSB_DepthLayeredPainterly(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_OUTLINE_APPEND) return SSB_DepthOutline(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_SCREENTONE_APPEND) return SSB_DepthScreentone(source_sampler, uv);
    return SSB_DepthScreentone(source_sampler, uv);
}

#endif
