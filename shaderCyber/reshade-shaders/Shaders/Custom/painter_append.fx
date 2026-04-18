// CS184 painter style adapted for ReShade
// Source memory:
// - memory/painter.md
// - shaders/painter.frag

#ifndef PAINTER_APPEND_FX
#define PAINTER_APPEND_FX

#ifndef PAINTER_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

uniform float Painter_EffectBlend <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Overall blend between the original image and the painterly result.";
> = 1.0;

uniform float Painter_BlurMix <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "How much the 9-tap blur is mixed into the original color.";
> = 0.55;

uniform float Painter_ColorRestore <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Reinjects luminance structure after the blur wash.";
> = 0.88;

uniform float Painter_GammaLift <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.6; ui_max = 1.4;
    ui_tooltip = "Gamma shaping applied before posterization. Lower values brighten the wash.";
> = 0.92;

uniform float Painter_PosterLevels <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 2.0; ui_max = 12.0; ui_step = 1.0;
    ui_tooltip = "Number of quantized color levels used in the painterly abstraction.";
> = 6.0;

uniform float Painter_PaperAmount <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Mix between warm paper and the painterly tone.";
> = 0.92;

uniform float Painter_LineStrength <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.2;
    ui_tooltip = "Strength of the brown edge-tinted line accent.";
> = 0.55;

uniform float Painter_GoldStrength <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Amount of restrained gold accent on stronger edges.";
> = 0.35;

uniform float Painter_GrainStrength <
    ui_category = "Painter";
    ui_type = "drag";
    ui_min = 0.0; ui_max = 0.08;
    ui_tooltip = "Paper grain modulation strength.";
> = 0.03;

float PainterAppend_Luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float3 PainterAppend_SampleBlur(sampler source_sampler, float2 uv, float2 texel)
{
    float3 blur = 0.0.xxx;
    blur += tex2D(source_sampler, uv).rgb * 4.0;
    blur += tex2D(source_sampler, uv + float2(texel.x, 0.0)).rgb;
    blur += tex2D(source_sampler, uv - float2(texel.x, 0.0)).rgb;
    blur += tex2D(source_sampler, uv + float2(0.0, texel.y)).rgb;
    blur += tex2D(source_sampler, uv - float2(0.0, texel.y)).rgb;
    blur += tex2D(source_sampler, uv + texel).rgb;
    blur += tex2D(source_sampler, uv - texel).rgb;
    blur += tex2D(source_sampler, uv + float2(texel.x, -texel.y)).rgb;
    blur += tex2D(source_sampler, uv + float2(-texel.x, texel.y)).rgb;
    return blur / 12.0;
}

float3 PainterAppend_ApplyTone(float3 color, float3 blur)
{
    float3 painter = lerp(color, blur, Painter_BlurMix);

    float luma = PainterAppend_Luminance(painter);
    painter = lerp(luma.xxx, painter, Painter_ColorRestore);

    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;

    painter = pow(saturate(painter), Painter_GammaLift.xxx);

    float levels = max(Painter_PosterLevels, 2.0);
    return floor(saturate(painter) * levels) / levels;
}

float PainterAppend_ComputeEdge(sampler source_sampler, float2 uv, float2 texel)
{
    float lL = PainterAppend_Luminance(tex2D(source_sampler, uv - float2(texel.x, 0.0)).rgb);
    float lR = PainterAppend_Luminance(tex2D(source_sampler, uv + float2(texel.x, 0.0)).rgb);
    float lU = PainterAppend_Luminance(tex2D(source_sampler, uv + float2(0.0, texel.y)).rgb);
    float lD = PainterAppend_Luminance(tex2D(source_sampler, uv - float2(0.0, texel.y)).rgb);

    float2 gradient = float2(lR - lL, lU - lD);
    return length(gradient);
}

float PainterAppend_PaperGrain(float2 uv)
{
    return frac(sin(dot(uv * float2(1400.0, 900.0), float2(12.9898, 78.233))) * 43758.5453);
}

float3 PainterAppend_CompositePaper(float3 painter, float edge, float grain)
{
    static const float3 paper = float3(0.95, 0.88, 0.74);
    static const float3 lineColor = float3(0.42, 0.28, 0.10);
    static const float3 gold = float3(0.82, 0.68, 0.30);

    float3 result = lerp(paper, painter, Painter_PaperAmount);

    float lineMask = smoothstep(0.05, 0.16, edge);
    result = lerp(result, lineColor, lineMask * Painter_LineStrength);

    float goldMask = smoothstep(0.10, 0.22, edge) * Painter_GoldStrength;
    result = lerp(result, gold, goldMask);

    return result * (0.985 + Painter_GrainStrength * grain);
}

float3 PainterAppend_ApplyFromSampler(sampler source_sampler, float2 texcoord)
{
    float2 texel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float3 baseColor = tex2D(source_sampler, texcoord).rgb;

    float3 blur = PainterAppend_SampleBlur(source_sampler, texcoord, texel);
    float3 painter = PainterAppend_ApplyTone(baseColor, blur);
    float edge = PainterAppend_ComputeEdge(source_sampler, texcoord, texel);
    float grain = PainterAppend_PaperGrain(texcoord);
    float3 stylized = saturate(PainterAppend_CompositePaper(painter, edge, grain));

    return lerp(baseColor, stylized, Painter_EffectBlend);
}

#ifndef PAINTER_APPEND_LIBRARY_MODE
float4 PainterAppend_PS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(PainterAppend_ApplyFromSampler(ReShade::BackBuffer, texcoord), 1.0);
}

technique CS184_Painter_Append <
    ui_tooltip = "Append-labeled copy of the painter effect.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PainterAppend_PS;
    }
}
#endif

#endif
