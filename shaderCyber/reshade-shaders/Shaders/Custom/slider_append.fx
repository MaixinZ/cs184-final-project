#ifndef SLIDER_APPEND_FX
#define SLIDER_APPEND_FX

#ifndef SLIDER_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

uniform float AssistStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Assist Strength";
> = 0.65;

uniform float DetectionMin <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.3;
    ui_label = "Detection Min";
> = 0.05;

uniform float DetectionMax <
    ui_type = "slider";
    ui_min = 0.05; ui_max = 0.5;
    ui_label = "Detection Max";
> = 0.25;

uniform float BlueShift <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.5;
    ui_label = "Blue Shift";
> = 0.18;

float3 SliderAppend_AssistRG(float3 c)
{
    float rStrength = c.r - max(c.g, c.b);
    float gStrength = c.g - max(c.r, c.b);

    float redMask = smoothstep(DetectionMin, DetectionMax, rStrength);
    float greenMask = smoothstep(DetectionMin, DetectionMax, gStrength);

    float3 redTarget = float3(
        c.r,
        c.g * 0.75,
        min(c.b + BlueShift, 1.0)
    );

    float3 greenTarget = float3(
        c.r * 0.75,
        c.g,
        min(c.b + BlueShift, 1.0)
    );

    float3 outColor = c;
    outColor = lerp(outColor, redTarget, redMask * AssistStrength);
    outColor = lerp(outColor, greenTarget, greenMask * AssistStrength);

    return saturate(outColor);
}

float3 SliderAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 c = tex2D(source_sampler, uv).rgb;
    return SliderAppend_AssistRG(c);
}

#ifndef SLIDER_APPEND_LIBRARY_MODE
float4 SliderAppend_PS(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    return float4(SliderAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique RedGreenAssist_Append
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = SliderAppend_PS;
    }
}
#endif

#endif
