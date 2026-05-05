#ifndef ATMOSPHERIC_DEPTH_CUE_APPEND_FX
#define ATMOSPHERIC_DEPTH_CUE_APPEND_FX

#ifndef ATMOSPHERIC_DEPTH_CUE_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif
#include "DepthDistanceCommon.fxh"

uniform float ADC_FogStartDepth <
    ui_category = "Atmospheric Depth Cue";
    ui_type = "slider";
    ui_label = "Fog Start Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linearized depth where atmospheric cueing begins.";
> = 0.518;

uniform float ADC_FogEndDepth <
    ui_category = "Atmospheric Depth Cue";
    ui_type = "slider";
    ui_label = "Fog End Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linearized depth where atmospheric cueing reaches full strength.";
> = 1.00;

uniform float ADC_FogStrength <
    ui_category = "Atmospheric Depth Cue";
    ui_type = "slider";
    ui_label = "Fog Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Strength of the subtle far haze.";
> = 0.683;

uniform float3 ADC_FogTintColor <
    ui_category = "Atmospheric Depth Cue";
    ui_type = "color";
    ui_label = "Fog Tint Color";
    ui_tooltip = "Tint color blended into distant atmospheric haze.";
> = float3(0.992157, 0.027451, 0.254902);

uniform float ADC_FarDesaturation <
    ui_category = "Atmospheric Depth Cue";
    ui_type = "slider";
    ui_label = "Far Desaturation";
    ui_min = 0.0; ui_max = 0.80;
    ui_tooltip = "How much saturation is removed from distant objects.";
> = 0.316;

uniform float ADC_NearClarityBoost <
    ui_category = "Atmospheric Depth Cue";
    ui_type = "slider";
    ui_label = "Near Clarity Boost";
    ui_min = 0.0; ui_max = 0.45;
    ui_tooltip = "Small near-field clarity boost to keep the foreground crisp.";
> = 0.12;

uniform float ADC_BlendStrength <
    ui_category = "Atmospheric Depth Cue";
    ui_type = "slider";
    ui_label = "Blend Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend with the incoming branch image.";
> = 1.00;

uniform bool ADC_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float ADC_DepthWindow(float linear_depth)
{
    float start_depth = min(ADC_FogStartDepth, ADC_FogEndDepth);
    float end_depth = max(ADC_FogStartDepth, ADC_FogEndDepth);
    return smoothstep(start_depth, max(end_depth, start_depth + 1e-4), linear_depth);
}

float3 ADC_NearSharpen(sampler source_sampler, float2 uv, float amount)
{
    float3 center = DDS_GetSourceColor(source_sampler, uv);
    if (amount <= 1e-4)
        return center;

    float2 px = BUFFER_PIXEL_SIZE;
    float3 blur = center * 4.0;
    blur += DDS_GetSourceColor(source_sampler, saturate(uv + float2( px.x, 0.0)));
    blur += DDS_GetSourceColor(source_sampler, saturate(uv + float2(-px.x, 0.0)));
    blur += DDS_GetSourceColor(source_sampler, saturate(uv + float2(0.0,  px.y)));
    blur += DDS_GetSourceColor(source_sampler, saturate(uv + float2(0.0, -px.y)));
    blur /= 8.0;

    return saturate(center + (center - blur) * amount);
}

float3 ADCAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = DDS_GetSourceColor(source_sampler, uv);

    if (!ADC_HasDepth)
        return scene;

    float depth_window = ADC_DepthWindow(DDS_GetLinearDepth(uv));
    float fog_factor = depth_window * ADC_FogStrength;

    float near_amount = ADC_NearClarityBoost * (1.0 - depth_window);
    float3 clear_near = ADC_NearSharpen(source_sampler, uv, near_amount);

    float3 haze_source = DDS_BilateralBlurFromSampler(source_sampler, uv, lerp(0.0, 3.25, fog_factor), 1.25);
    float haze_luma = DDS_Luminance(haze_source);
    float3 desaturated = lerp(haze_source, haze_luma.xxx, saturate(fog_factor * ADC_FarDesaturation));
    float3 cooled = desaturated * lerp(float3(1.0, 1.0, 1.0), float3(0.92, 0.98, 1.08), fog_factor);
    float3 fogged = lerp(cooled, ADC_FogTintColor, fog_factor * 0.34);

    float3 cued = lerp(clear_near, fogged, saturate(fog_factor));
    return saturate(lerp(scene, cued, ADC_BlendStrength));
}

#ifndef ATMOSPHERIC_DEPTH_CUE_APPEND_LIBRARY_MODE
float4 ADCAppend_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(ADCAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique AtmosphericDepthCue_Append <
    ui_tooltip = "Adds subtle cool far haze and near clarity from true linearized depth.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ADCAppend_PS;
    }
}
#endif

#endif
