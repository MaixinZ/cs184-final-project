#ifndef DEPTH_OUTLINE_OVERLAY_APPEND_FX
#define DEPTH_OUTLINE_OVERLAY_APPEND_FX

#ifndef DEPTH_OUTLINE_OVERLAY_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif
#include "DepthDistanceCommon.fxh"

uniform float DOO_Strength <
    ui_category = "Depth Outline Overlay";
    ui_type = "slider";
    ui_label = "Outline Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls how strongly true depth-based outlines are blended into the current image.";
> = 0.60;

uniform float DOO_EdgeSensitivity <
    ui_category = "Depth Outline Overlay";
    ui_type = "slider";
    ui_label = "Edge Sensitivity";
    ui_min = 2.0; ui_max = 80.0;
    ui_tooltip = "Higher values make smaller depth differences show up as outlines.";
> = 28.0;

uniform bool DOO_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float3 DOOAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = DDS_GetSourceColor(source_sampler, uv);

    if (!DOO_HasDepth)
        return scene;

    float edge = DDS_DepthEdge(uv, DOO_EdgeSensitivity);
    float line_mask = smoothstep(0.06, 0.32, edge) * DOO_Strength;

    float linear_depth = DDS_GetLinearDepth(uv);
    float far_boost = smoothstep(0.18, 0.80, linear_depth);
    line_mask *= lerp(0.82, 1.08, far_boost);

    float3 line_color = float3(0.12, 0.09, 0.11);
    float3 outlined = lerp(scene, line_color, saturate(line_mask));

    return saturate(outlined);
}

#ifndef DEPTH_OUTLINE_OVERLAY_APPEND_LIBRARY_MODE
float4 DOOAppend_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(DOOAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique DepthOutlineOverlay_Append <
    ui_tooltip = "Append-labeled copy of the standalone true depth-outline layer.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DOOAppend_PS;
    }
}
#endif

#endif
