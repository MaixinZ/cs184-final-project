#ifndef DEPTH_SCREENTONE_OVERLAY_APPEND_FX
#define DEPTH_SCREENTONE_OVERLAY_APPEND_FX

#ifndef DEPTH_SCREENTONE_OVERLAY_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif
#include "DepthDistanceCommon.fxh"

uniform float DSO_Strength <
    ui_category = "Depth Screentone Overlay";
    ui_type = "slider";
    ui_label = "Screentone Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls how strongly distant regions receive dots and hatch-like print treatment.";
> = 0.60;

uniform float DSO_StartDepth <
    ui_category = "Depth Screentone Overlay";
    ui_type = "slider";
    ui_label = "Start Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linear depth where screentone starts appearing.";
> = 0.26;

uniform float DSO_FullDepth <
    ui_category = "Depth Screentone Overlay";
    ui_type = "slider";
    ui_label = "Full Depth";
    ui_min = 0.01; ui_max = 1.0;
    ui_tooltip = "Linear depth where screentone reaches full influence.";
> = 0.82;

uniform bool DSO_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float2 DSOAppend_Rotate(float2 value, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2(c * value.x - s * value.y, s * value.x + c * value.y);
}

float DSOAppend_DotMask(float2 pixel_pos, float cell_size, float radius)
{
    float2 cell = frac(pixel_pos / cell_size) - 0.5;
    float dist = length(cell);
    return 1.0 - smoothstep(radius, radius + 0.06, dist);
}

float DSOAppend_HatchMask(float2 pixel_pos, float cell_size, float thickness, float angle)
{
    float2 rotated = DSOAppend_Rotate(pixel_pos, angle);
    float stripe = abs(frac(rotated.x / cell_size) - 0.5);
    return 1.0 - smoothstep(thickness, thickness + 0.05, stripe);
}

float3 DSOAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = DDS_GetSourceColor(source_sampler, uv);

    if (!DSO_HasDepth)
        return scene;

    float linear_depth = DDS_GetLinearDepth(uv);
    float far_factor = DDS_GetDepthWindow(linear_depth, DSO_StartDepth, DSO_FullDepth) * DSO_Strength;

    float luma = DDS_Luminance(scene);
    float darkness = saturate(1.0 - luma);
    float tone_factor = far_factor * darkness;

    float2 pixel_pos = uv * BUFFER_SCREEN_SIZE;
    float cell_size = lerp(16.0, 6.0, far_factor);
    float dot_radius = lerp(0.08, 0.34, tone_factor);
    float line_thickness = lerp(0.46, 0.16, tone_factor);

    float dots = DSOAppend_DotMask(pixel_pos, cell_size, dot_radius);
    float hatch = DSOAppend_HatchMask(pixel_pos, cell_size * 0.9, line_thickness, 0.55);
    float hatch2 = DSOAppend_HatchMask(pixel_pos, cell_size * 1.1, line_thickness + 0.04, 2.10);

    float tone_mask = max(dots * 0.75, hatch * 0.55);
    tone_mask = max(tone_mask, hatch2 * smoothstep(0.45, 1.0, tone_factor) * 0.38);
    tone_mask *= far_factor;

    float3 ink_color = float3(0.14, 0.10, 0.08);
    float3 toned = lerp(scene, ink_color, tone_mask * 0.78);

    return saturate(toned);
}

#ifndef DEPTH_SCREENTONE_OVERLAY_APPEND_LIBRARY_MODE
float4 DSOAppend_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(DSOAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique DepthScreentoneOverlay_Append <
    ui_tooltip = "Append-labeled copy of the standalone depth-driven screentone layer.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DSOAppend_PS;
    }
}
#endif

#endif
