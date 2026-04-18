#ifndef OILPAINT_APPEND_FX
#define OILPAINT_APPEND_FX

#ifndef OILPAINT_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

float OilPaintAppend_Luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float3 OilPaintAppend_Sample(sampler source_sampler, float2 uv)
{
    return tex2D(source_sampler, uv).rgb;
}

float3 OilPaintAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float2 texel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

    float3 c  = OilPaintAppend_Sample(source_sampler, uv);
    float baseLuma = OilPaintAppend_Luminance(c);

    float3 cL  = OilPaintAppend_Sample(source_sampler, uv - float2(texel.x, 0.0));
    float3 cR  = OilPaintAppend_Sample(source_sampler, uv + float2(texel.x, 0.0));
    float3 cU  = OilPaintAppend_Sample(source_sampler, uv + float2(0.0, texel.y));
    float3 cD  = OilPaintAppend_Sample(source_sampler, uv - float2(0.0, texel.y));
    float3 cUL = OilPaintAppend_Sample(source_sampler, uv + float2(-texel.x, texel.y));
    float3 cUR = OilPaintAppend_Sample(source_sampler, uv + float2(texel.x, texel.y));
    float3 cDL = OilPaintAppend_Sample(source_sampler, uv + float2(-texel.x, -texel.y));
    float3 cDR = OilPaintAppend_Sample(source_sampler, uv + float2(texel.x, -texel.y));

    float3 blur = float3(0.0, 0.0, 0.0);
    blur += c * 4.0;
    blur += cL + cR + cU + cD;
    blur += cUL + cUR + cDL + cDR;
    blur /= 12.0;

    float lL  = OilPaintAppend_Luminance(cL);
    float lR  = OilPaintAppend_Luminance(cR);
    float lU  = OilPaintAppend_Luminance(cU);
    float lD  = OilPaintAppend_Luminance(cD);
    float lUL = OilPaintAppend_Luminance(cUL);
    float lUR = OilPaintAppend_Luminance(cUR);
    float lDL = OilPaintAppend_Luminance(cDL);
    float lDR = OilPaintAppend_Luminance(cDR);

    float localMin = min(min(min(lL, lR), min(lU, lD)), min(min(lUL, lUR), min(lDL, lDR)));
    float localMax = max(max(max(lL, lR), max(lU, lD)), max(max(lUL, lUR), max(lDL, lDR)));
    float localContrast = localMax - localMin;

    float shadowProtect = 1.0 - smoothstep(0.08, 0.30, baseLuma);
    float contrastProtect = smoothstep(0.03, 0.09, localContrast);

    float blurAmount = 0.55;
    blurAmount *= (1.0 - 0.65 * shadowProtect);
    blurAmount *= (1.0 - 0.50 * contrastProtect);
    blurAmount = clamp(blurAmount, 0.10, 0.55);

    float3 painter = lerp(c, blur, blurAmount);

    float luma = OilPaintAppend_Luminance(painter);
    painter = lerp(luma.xxx, painter, 0.90);

    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;

    painter = pow(painter, 0.92.xxx);

    float shadowLift = smoothstep(0.00, 0.22, baseLuma);
    float3 lifted = lerp(painter * 1.18, painter, shadowLift);
    painter = lerp(lifted, painter, 0.35);

    float levelsDark = 10.0;
    float levelsBright = 6.0;
    float levels = lerp(levelsDark, levelsBright, smoothstep(0.08, 0.45, baseLuma));
    painter = floor(painter * levels) / levels;

    float dx = lR - lL;
    float dy = lU - lD;
    float edge = length(float2(dx, dy));
    edge *= lerp(1.6, 1.0, smoothstep(0.05, 0.35, baseLuma));

    float3 paper = float3(0.95, 0.88, 0.74);
    float3 result = lerp(paper, painter, 0.92);

    edge *= 1.1;

    float3 lineColor = float3(0.42, 0.28, 0.10);
    float lineMask = smoothstep(0.035, 0.12, edge);
    result = lerp(result, lineColor, lineMask * 0.72);

    float3 gold = float3(0.82, 0.68, 0.30);
    float goldMask = smoothstep(0.09, 0.20, edge) * 0.28;
    result = lerp(result, gold, goldMask);

    float grain = frac(sin(dot(uv * float2(1400.0, 900.0), float2(12.9898, 78.233))) * 43758.5453);
    result *= 0.985 + 0.03 * grain;

    return saturate(result);
}

#ifndef OILPAINT_APPEND_LIBRARY_MODE
float4 OilPaintAppend_PS(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    return float4(OilPaintAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique PainterlyCyberpunk_Append
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OilPaintAppend_PS;
    }
}
#endif

#endif
