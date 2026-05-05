#ifndef DEPTH_BAND_ASSIST_APPEND_FX
#define DEPTH_BAND_ASSIST_APPEND_FX

#ifndef DEPTH_BAND_ASSIST_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif
#include "DepthDistanceCommon.fxh"

uniform int DBA_BandCount <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Band Count";
    ui_min = 3; ui_max = 5;
    ui_tooltip = "Number of readable depth layers.";
> = 3;

uniform float DBA_NearDepth <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Near Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Start of the assisted depth range.";
> = 0.00;

uniform float DBA_FarDepth <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Far Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "End of the assisted depth range.";
> = 1.00;

uniform float DBA_BandContrast <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Band Contrast";
    ui_min = 0.0; ui_max = 0.55;
    ui_tooltip = "Small value/contrast separation applied per depth band.";
> = 0.18;

uniform float DBA_BandBoundaryStrength <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Band Boundary Strength";
    ui_min = 0.0; ui_max = 0.75;
    ui_tooltip = "Subtle highlight at depth band transitions.";
> = 0.273;

uniform float DBA_NearBandBrightness <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Near Band Brightness";
    ui_min = 0.75; ui_max = 1.35;
    ui_tooltip = "Brightness for nearest band.";
> = 1.35;

uniform float DBA_MidBandBrightness <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Mid Band Brightness";
    ui_min = 0.70; ui_max = 1.25;
    ui_tooltip = "Brightness for middle depth bands.";
> = 0.83;

uniform float DBA_FarBandBrightness <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Far Band Brightness";
    ui_min = 0.45; ui_max = 1.10;
    ui_tooltip = "Brightness for farthest band.";
> = 0.45;

uniform float DBA_TintStrength <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Tint Strength";
    ui_min = 0.0; ui_max = 0.40;
    ui_tooltip = "Subtle warm-to-cool tint across depth bands.";
> = 0.10;

uniform float DBA_BlendStrength <
    ui_category = "Depth Band Assist";
    ui_type = "slider";
    ui_label = "Blend Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend with the incoming branch image.";
> = 1.00;

uniform bool DBA_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float DBA_Depth01(float linear_depth)
{
    float near_depth = min(DBA_NearDepth, DBA_FarDepth);
    float far_depth = max(DBA_NearDepth, DBA_FarDepth);
    return saturate((linear_depth - near_depth) / max(far_depth - near_depth, 1e-4));
}

float DBA_GetBandBrightness(float band_u)
{
    if (band_u < 0.5)
        return lerp(DBA_NearBandBrightness, DBA_MidBandBrightness, band_u * 2.0);

    return lerp(DBA_MidBandBrightness, DBA_FarBandBrightness, (band_u - 0.5) * 2.0);
}

float3 DBAAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = DDS_GetSourceColor(source_sampler, uv);

    if (!DBA_HasDepth)
        return scene;

    float depth01 = DBA_Depth01(DDS_GetLinearDepth(uv));
    int band_count = clamp(DBA_BandCount, 3, 5);
    float bands = (float)band_count;

    float band_index = min(floor(depth01 * bands), bands - 1.0);
    float band_u = band_index / max(bands - 1.0, 1.0);
    float brightness = DBA_GetBandBrightness(band_u);

    float3 band_color = scene * brightness;
    float luma = DDS_Luminance(band_color);
    band_color = lerp(luma.xxx, band_color, 1.0 + DBA_BandContrast);

    float3 near_tint = float3(1.04, 1.01, 0.96);
    float3 mid_tint = float3(1.00, 1.00, 1.00);
    float3 far_tint = float3(0.88, 0.96, 1.10);
    float3 tint = lerp(near_tint, mid_tint, saturate(band_u * 2.0));
    tint = lerp(tint, far_tint, saturate(band_u * 1.35 - 0.35));
    band_color = lerp(band_color, band_color * tint, DBA_TintStrength);

    float cell = frac(depth01 * bands);
    float boundary_distance = min(cell, 1.0 - cell);
    float boundary = 1.0 - smoothstep(0.010, 0.060, boundary_distance);
    float3 boundary_color = lerp(band_color, float3(0.78, 0.88, 1.00), boundary * DBA_BandBoundaryStrength);

    return saturate(lerp(scene, boundary_color, DBA_BlendStrength));
}

#ifndef DEPTH_BAND_ASSIST_APPEND_LIBRARY_MODE
float4 DBAAppend_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(DBAAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique DepthBandAssist_Append <
    ui_tooltip = "Separates linearized depth into restrained near/mid/far visual bands for spatial readability.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DBAAppend_PS;
    }
}
#endif

#endif
