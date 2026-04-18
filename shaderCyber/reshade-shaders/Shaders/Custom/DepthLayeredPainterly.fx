#include "../ReShade.fxh"
#include "DepthDistanceCommon.fxh"

uniform float DLP_Strength <
    ui_category = "Depth Layered Painterly";
    ui_type = "slider";
    ui_label = "Painterly Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls how strongly the far distance is simplified into a painterly look.";
> = 0.60;

uniform float DLP_StartDepth <
    ui_category = "Depth Layered Painterly";
    ui_type = "slider";
    ui_label = "Start Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linear depth where the painterly distance layer begins.";
> = 0.22;

uniform float DLP_FullDepth <
    ui_category = "Depth Layered Painterly";
    ui_type = "slider";
    ui_label = "Full Depth";
    ui_min = 0.01; ui_max = 1.0;
    ui_tooltip = "Linear depth where the painterly simplification reaches full strength.";
> = 0.76;

uniform bool DLP_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float4 DLP_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 scene = DDS_GetSceneColor(uv);

    if (!DLP_HasDepth)
        return float4(scene, 1.0);

    float linear_depth = DDS_GetLinearDepth(uv);
    float far_factor = DDS_GetDepthWindow(linear_depth, DLP_StartDepth, DLP_FullDepth) * DLP_Strength;

    float2 texel = BUFFER_PIXEL_SIZE;
    float3 blur = 0.0.xxx;
    blur += scene * 4.0;
    blur += DDS_GetSceneColor(saturate(uv + float2(texel.x, 0.0)));
    blur += DDS_GetSceneColor(saturate(uv - float2(texel.x, 0.0)));
    blur += DDS_GetSceneColor(saturate(uv + float2(0.0, texel.y)));
    blur += DDS_GetSceneColor(saturate(uv - float2(0.0, texel.y)));
    blur += DDS_GetSceneColor(saturate(uv + texel));
    blur += DDS_GetSceneColor(saturate(uv - texel));
    blur += DDS_GetSceneColor(saturate(uv + float2(texel.x, -texel.y)));
    blur += DDS_GetSceneColor(saturate(uv + float2(-texel.x, texel.y)));
    blur /= 12.0;

    float blur_amount = lerp(0.08, 0.62, far_factor);
    float3 painter = lerp(scene, blur, blur_amount);

    float painter_luma = DDS_Luminance(painter);
    painter = lerp(painter_luma.xxx, painter, 0.88);
    painter.r *= lerp(1.0, 1.08, far_factor);
    painter.b *= lerp(1.0, 0.96, far_factor);

    float levels = lerp(12.0, 6.0, far_factor);
    painter = floor(saturate(painter) * levels) / levels;

    float3 paper = float3(0.95, 0.89, 0.76);
    float3 painterly = lerp(paper, painter, 0.92);

    float grain = DDS_PaperNoise(uv * BUFFER_SCREEN_SIZE);
    painterly *= 0.988 + grain * 0.022;

    return float4(saturate(lerp(scene, painterly, far_factor)), 1.0);
}

technique DepthLayeredPainterly <
    ui_tooltip = "Standalone distance simplification layer: far regions become more painterly. Stack after oilPaint for stronger far-distance oil treatment.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DLP_PS;
    }
}
