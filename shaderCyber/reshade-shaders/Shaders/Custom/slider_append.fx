#ifndef SLIDER_APPEND_FX
#define SLIDER_APPEND_FX

#ifndef SLIDER_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

float SliderAppend_Luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float3 SliderAppend_AssistRG(float3 c)
{
    float rStrength = c.r - max(c.g, c.b);
    float gStrength = c.g - max(c.r, c.b);

    float redMask = smoothstep(0.04, 0.22, rStrength);
    float greenMask = smoothstep(0.04, 0.22, gStrength);

    float luma = SliderAppend_Luminance(c);

    float3 redTarget = float3(
        min(c.r * 1.08 + 0.12, 1.0),
        min(c.g * 0.75 + 0.32, 1.0),
        c.b * 0.45
    );

    float3 greenTarget = float3(
        c.r * 0.45,
        min(c.g * 0.85 + 0.05, 1.0),
        min(c.b * 1.25 + 0.35, 1.0)
    );

    redTarget *= luma / max(SliderAppend_Luminance(redTarget), 0.001);
    greenTarget *= luma / max(SliderAppend_Luminance(greenTarget), 0.001);

    float3 outColor = c;
    outColor = lerp(outColor, redTarget, redMask * 0.85);
    outColor = lerp(outColor, greenTarget, greenMask * 0.85);

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
