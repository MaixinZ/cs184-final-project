#ifndef SILVER_DEPTH_EDGE_APPEND_FX
#define SILVER_DEPTH_EDGE_APPEND_FX

#ifndef SILVER_DEPTH_EDGE_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif
#include "DepthDistanceCommon.fxh"

uniform float SDE_EdgeStrength <
    ui_category = "Silver Depth Edge";
    ui_type = "slider";
    ui_label = "Edge Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend strength for silver-white depth discontinuity edges.";
> = 0.66;

uniform float SDE_EdgeThreshold <
    ui_category = "Silver Depth Edge";
    ui_type = "slider";
    ui_label = "Edge Threshold";
    ui_min = 0.001; ui_max = 0.20;
    ui_tooltip = "Depth-gradient threshold. Raise this to suppress small noisy edges.";
> = 0.030;

uniform float SDE_EdgeWidth <
    ui_category = "Silver Depth Edge";
    ui_type = "slider";
    ui_label = "Edge Width";
    ui_min = 0.5; ui_max = 3.0;
    ui_tooltip = "Depth sample radius in pixels.";
> = 1.15;

uniform int SDE_EdgeColorPreset <
    ui_category = "Silver Depth Edge";
    ui_type = "combo";
    ui_label = "Edge Color Preset";
    ui_items =
        "Custom Silver Tint\0"
        "Bright White\0"
        "Yellow\0"
        "Red\0";
    ui_tooltip = "Preset edge color. Bright White is intentionally very luminous; Custom uses the Silver Tint Color picker below.";
> = 0;

uniform float3 SDE_SilverTintColor <
    ui_category = "Silver Depth Edge";
    ui_type = "color";
    ui_label = "Silver Tint Color";
    ui_tooltip = "Custom metallic edge tint used when Edge Color Preset is Custom Silver Tint.";
> = float3(0.82, 0.90, 1.00);

uniform float SDE_EdgeGlowStrength <
    ui_category = "Silver Depth Edge";
    ui_type = "slider";
    ui_label = "Edge Glow Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Subtle halo around stronger depth edges.";
> = 0.22;

uniform float SDE_MinDepth <
    ui_category = "Silver Depth Edge";
    ui_type = "slider";
    ui_label = "Min Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Nearest linearized depth that can receive silver edges.";
> = 0.00;

uniform float SDE_MaxDepth <
    ui_category = "Silver Depth Edge";
    ui_type = "slider";
    ui_label = "Max Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Farthest linearized depth that can receive silver edges.";
> = 0.92;

uniform float SDE_DepthEdgeGamma <
    ui_category = "Silver Depth Edge";
    ui_type = "slider";
    ui_label = "Depth Edge Gamma";
    ui_min = 0.45; ui_max = 2.20;
    ui_tooltip = "Contrast curve for depth discontinuity edges.";
> = 0.82;

uniform bool SDE_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float SDE_SampleDepth(float2 uv)
{
    return DDS_GetLinearDepth(saturate(uv));
}

float SDE_SobelDepth(float2 uv, float radius_px)
{
    float2 step_uv = BUFFER_PIXEL_SIZE * max(radius_px, 0.5);

    float d00 = SDE_SampleDepth(uv + step_uv * float2(-1.0, -1.0));
    float d10 = SDE_SampleDepth(uv + step_uv * float2( 0.0, -1.0));
    float d20 = SDE_SampleDepth(uv + step_uv * float2( 1.0, -1.0));
    float d01 = SDE_SampleDepth(uv + step_uv * float2(-1.0,  0.0));
    float d21 = SDE_SampleDepth(uv + step_uv * float2( 1.0,  0.0));
    float d02 = SDE_SampleDepth(uv + step_uv * float2(-1.0,  1.0));
    float d12 = SDE_SampleDepth(uv + step_uv * float2( 0.0,  1.0));
    float d22 = SDE_SampleDepth(uv + step_uv * float2( 1.0,  1.0));

    float gx = -d00 - 2.0 * d01 - d02 + d20 + 2.0 * d21 + d22;
    float gy = -d00 - 2.0 * d10 - d20 + d02 + 2.0 * d12 + d22;
    return sqrt(gx * gx + gy * gy);
}

float SDE_DepthGate(float linear_depth)
{
    float min_depth = min(SDE_MinDepth, SDE_MaxDepth);
    float max_depth = max(SDE_MinDepth, SDE_MaxDepth);
    float feather = max((max_depth - min_depth) * 0.06, 0.01);

    float near_gate = (min_depth <= 0.0001) ? 1.0 : smoothstep(min_depth, min_depth + feather, linear_depth);
    float far_gate = (max_depth >= 0.9999) ? 1.0 : (1.0 - smoothstep(max_depth - feather, max_depth, linear_depth));
    return saturate(near_gate * far_gate);
}

float3 SDE_GetEdgeTintColor()
{
    if (SDE_EdgeColorPreset == 1)
        return float3(1.35, 1.35, 1.25);
    if (SDE_EdgeColorPreset == 2)
        return float3(1.00, 0.82, 0.12);
    if (SDE_EdgeColorPreset == 3)
        return float3(1.00, 0.16, 0.08);

    return SDE_SilverTintColor;
}

float3 SDEAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = DDS_GetSourceColor(source_sampler, uv);

    if (!SDE_HasDepth)
        return scene;

    float linear_depth = DDS_GetLinearDepth(uv);
    float depth_gate = SDE_DepthGate(linear_depth);

    float edge = SDE_SobelDepth(uv, SDE_EdgeWidth);
    float normalized_edge = saturate((edge - SDE_EdgeThreshold) / max(SDE_EdgeThreshold * 3.5, 1e-4));
    float edge_mask = pow(normalized_edge, max(SDE_DepthEdgeGamma, 1e-3)) * SDE_EdgeStrength * depth_gate;

    float wide_edge = SDE_SobelDepth(uv, SDE_EdgeWidth * 1.85);
    float halo_mask = smoothstep(SDE_EdgeThreshold * 0.55, SDE_EdgeThreshold * 2.4, wide_edge);
    halo_mask = saturate(halo_mask - edge_mask * 0.35) * SDE_EdgeGlowStrength * depth_gate;

    float scene_luma = DDS_Luminance(scene);
    float3 edge_tint = SDE_GetEdgeTintColor();
    float3 edge_color = saturate(edge_tint * (0.72 + scene_luma * 0.28) + 0.12.xxx);
    float3 haloed = saturate(scene + edge_color * halo_mask * 0.34);
    float3 edged = lerp(haloed, edge_color, saturate(edge_mask));

    return saturate(edged);
}

#ifndef SILVER_DEPTH_EDGE_APPEND_LIBRARY_MODE
float4 SDEAppend_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(SDEAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique SilverDepthEdge_Append <
    ui_tooltip = "Adds cool silver-white outlines at true depth discontinuities while keeping the scene readable.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = SDEAppend_PS;
    }
}
#endif

#endif