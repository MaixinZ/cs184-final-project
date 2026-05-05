#ifndef NEAR_BRIGHT_FAR_DARK_APPEND_FX
#define NEAR_BRIGHT_FAR_DARK_APPEND_FX

#ifndef NEAR_BRIGHT_FAR_DARK_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif
#include "DepthDistanceCommon.fxh"

uniform float NBFD_NearDepth <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Near Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linearized depth treated as the bright near field.";
> = 0.04;

uniform float NBFD_FarDepth <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Far Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linearized depth treated as the dark far field.";
> = 0.809;

uniform float NBFD_NearBrightness <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Near Brightness";
    ui_min = 0.75; ui_max = 1.50;
    ui_tooltip = "Brightness multiplier near the camera.";
> = 1.50;

uniform float NBFD_FarBrightness <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Far Brightness";
    ui_min = 0.35; ui_max = 1.10;
    ui_tooltip = "Brightness multiplier in the distance.";
> = 0.35;

uniform float NBFD_CurvePower <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Curve Power";
    ui_min = 0.35; ui_max = 3.00;
    ui_tooltip = "Depth falloff curve. Higher values keep mid range brighter for longer.";
> = 1.51;

uniform float NBFD_PreserveSaturation <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Preserve Saturation";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Higher values preserve original color saturation.";
> = 0.86;

uniform float NBFD_FarDesaturation <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Far Desaturation";
    ui_min = 0.0; ui_max = 0.75;
    ui_tooltip = "Optional desaturation applied to distant regions.";
> = 0.18;

uniform float NBFD_BlendStrength <
    ui_category = "Near Bright Far Dark";
    ui_type = "slider";
    ui_label = "Blend Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend with the incoming branch image.";
> = 1.00;

uniform bool NBFD_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float NBFD_Depth01(float linear_depth)
{
    float near_depth = min(NBFD_NearDepth, NBFD_FarDepth);
    float far_depth = max(NBFD_NearDepth, NBFD_FarDepth);
    return saturate((linear_depth - near_depth) / max(far_depth - near_depth, 1e-4));
}

float3 NBFDAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = DDS_GetSourceColor(source_sampler, uv);

    if (!NBFD_HasDepth)
        return scene;

    float linear_depth = DDS_GetLinearDepth(uv);
    float depth01 = NBFD_Depth01(linear_depth);
    float curve = pow(depth01, max(NBFD_CurvePower, 1e-3));

    float brightness = lerp(NBFD_NearBrightness, NBFD_FarBrightness, curve);
    float3 graded = scene * brightness;

    float far_desat = curve * NBFD_FarDesaturation * (1.0 - NBFD_PreserveSaturation);
    float luma = DDS_Luminance(graded);
    graded = lerp(graded, luma.xxx, saturate(far_desat));

    return saturate(lerp(scene, graded, NBFD_BlendStrength));
}

#ifndef NEAR_BRIGHT_FAR_DARK_APPEND_LIBRARY_MODE
float4 NBFDAppend_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(NBFDAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique NearBrightFarDark_Append <
    ui_tooltip = "Uses linearized depth to brighten foregrounds and gently darken distance while preserving hue.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = NBFDAppend_PS;
    }
}
#endif

#endif
