// CS184 painter style adapted for ReShade
// Source memory:
// - memory/painter.md
// - shaders/painter.frag

#include "ReShade.fxh"

texture2D Painter_SourceTex : COLOR;
sampler2D Painter_SourceSampler
{
    Texture = Painter_SourceTex;
    AddressU = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = POINT;
};

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

float Painter_Luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float3 Painter_SampleBlur(float2 uv, float2 texel)
{
    float3 blur = 0.0.xxx;
    blur += tex2D(Painter_SourceSampler, uv).rgb * 4.0;
    blur += tex2D(Painter_SourceSampler, uv + float2(texel.x, 0.0)).rgb;
    blur += tex2D(Painter_SourceSampler, uv - float2(texel.x, 0.0)).rgb;
    blur += tex2D(Painter_SourceSampler, uv + float2(0.0, texel.y)).rgb;
    blur += tex2D(Painter_SourceSampler, uv - float2(0.0, texel.y)).rgb;
    blur += tex2D(Painter_SourceSampler, uv + texel).rgb;
    blur += tex2D(Painter_SourceSampler, uv - texel).rgb;
    blur += tex2D(Painter_SourceSampler, uv + float2(texel.x, -texel.y)).rgb;
    blur += tex2D(Painter_SourceSampler, uv + float2(-texel.x, texel.y)).rgb;
    return blur / 12.0;
}

float3 Painter_ApplyTone(float3 color, float3 blur)
{
    float3 painter = lerp(color, blur, Painter_BlurMix);

    float luma = Painter_Luminance(painter);
    painter = lerp(luma.xxx, painter, Painter_ColorRestore);

    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;

    painter = pow(saturate(painter), Painter_GammaLift.xxx);

    float levels = max(Painter_PosterLevels, 2.0);
    return floor(saturate(painter) * levels) / levels;
}

float Painter_ComputeEdge(float2 uv, float2 texel)
{
    float lL = Painter_Luminance(tex2D(Painter_SourceSampler, uv - float2(texel.x, 0.0)).rgb);
    float lR = Painter_Luminance(tex2D(Painter_SourceSampler, uv + float2(texel.x, 0.0)).rgb);
    float lU = Painter_Luminance(tex2D(Painter_SourceSampler, uv + float2(0.0, texel.y)).rgb);
    float lD = Painter_Luminance(tex2D(Painter_SourceSampler, uv - float2(0.0, texel.y)).rgb);

    float2 gradient = float2(lR - lL, lU - lD);
    return length(gradient);
}

float Painter_PaperGrain(float2 uv)
{
    return frac(sin(dot(uv * float2(1400.0, 900.0), float2(12.9898, 78.233))) * 43758.5453);
}

float3 Painter_CompositePaper(float3 painter, float edge, float grain)
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

float4 Painter_PS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 texel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float3 baseColor = tex2D(Painter_SourceSampler, texcoord).rgb;

    float3 blur = Painter_SampleBlur(texcoord, texel);
    float3 painter = Painter_ApplyTone(baseColor, blur);
    float edge = Painter_ComputeEdge(texcoord, texel);
    float grain = Painter_PaperGrain(texcoord);
    float3 stylized = saturate(Painter_CompositePaper(painter, edge, grain));

    return float4(lerp(baseColor, stylized, Painter_EffectBlend), 1.0);
}

technique CS184_Painter <
    ui_tooltip = "Painterly image abstraction with warm paper, posterized color grouping, brown line accents, and restrained gold highlights.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = Painter_PS;
    }
}
