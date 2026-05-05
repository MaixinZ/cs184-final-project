#ifndef OILPAINT_APPEND_FX
#define OILPAINT_APPEND_FX

#ifndef OILPAINT_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

uniform float BlurStrength
<
    ui_type = "slider";
    ui_label = "Blur Strength";
    ui_tooltip = "Controls how strongly the bilateral-blurred color replaces the original image.";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.51;

uniform float StrokeStrength
<
    ui_type = "slider";
    ui_label = "Stroke Strength";
    ui_tooltip = "Controls the visibility of procedural brush-stroke texture.";
    ui_min = 0.0; ui_max = 0.30; ui_step = 0.005;
> = 0.114;

uniform float ColorQuantization
<
    ui_type = "slider";
    ui_label = "Color Quantization";
    ui_tooltip = "Controls how strongly colors are reduced into discrete paint-like levels.";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.80;

float OilPaintAppend_Luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float OilPaintAppend_Rand(float2 p)
{
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float OilPaintAppend_BrushNoise(float2 uv)
{
    float2 cell = floor(uv * float2(20.0, 20.0));
    float angle = OilPaintAppend_Rand(cell) * 6.2831;
    float2 dir = float2(cos(angle), sin(angle));
    float proj = dot(uv * 8.0, dir);
    float stroke = sin(proj * 40.0 + OilPaintAppend_Rand(cell + 3.7) * 6.2831);
    float variation = OilPaintAppend_Rand(cell + floor(uv * 100.0));
    stroke = lerp(stroke, variation * 2.0 - 1.0, 0.4);
    return 0.5 + 0.5 * stroke;
}

float3 OilPaintAppend_Sample(sampler source_sampler, float2 uv)
{
    return tex2D(source_sampler, uv).rgb;
}

float3 OilPaintAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float2 texel = ReShade::PixelSize;
    float3 c = OilPaintAppend_Sample(source_sampler, uv);
    float baseLuma = OilPaintAppend_Luminance(c);

    float3 blur = 0.0;
    float totalWeight = 0.0;

    [loop]
    for (int x = -4; x <= 4; x++)
    {
        [loop]
        for (int y = -4; y <= 4; y++)
        {
            float2 offset = float2((float)x, (float)y) * texel;
            float3 sampleColor = OilPaintAppend_Sample(source_sampler, uv + offset);
            float dist = length(float2((float)x, (float)y));
            float spatialSigma = lerp(8.0, 60.0, BlurStrength);
            float spatialWeight = exp(-(dist * dist) / spatialSigma);
            float colorDiff = length(sampleColor - c);
            float colorWeight = exp(-(colorDiff * colorDiff) / 0.30);
            float weight = spatialWeight * colorWeight;
            blur += sampleColor * weight;
            totalWeight += weight;
        }
    }

    blur /= max(totalWeight, 1e-5);

    float blendAmount = lerp(0.0, 1.0, BlurStrength);
    float3 painter = lerp(c, blur, blendAmount);

    float levelsDark = lerp(24.0, 10.0, ColorQuantization);
    float levelsBright = lerp(24.0, 4.0, ColorQuantization);
    float levels = lerp(levelsDark, levelsBright, smoothstep(0.08, 0.45, baseLuma));
    painter = floor(painter * levels) / max(levels, 1e-5);

    float stroke = OilPaintAppend_BrushNoise(uv);
    painter *= (1.0 - StrokeStrength * 0.5) + StrokeStrength * stroke;

    return saturate(painter);
}

#ifndef OILPAINT_APPEND_LIBRARY_MODE
float4 OilPaintAppend_PS(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    return float4(OilPaintAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique OilPaint_UserControls_Append
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OilPaintAppend_PS;
    }
}
#endif

#endif
