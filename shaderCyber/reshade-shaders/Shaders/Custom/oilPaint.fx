#include "../ReShade.fxh"

float luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float4 PS_Painterly(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    float2 texel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

    float3 c  = tex2D(ReShade::BackBuffer, uv).rgb;
    float baseLuma = luminance(c);

    // 3x3 neighborhood
    float3 cL  = tex2D(ReShade::BackBuffer, uv - float2(texel.x, 0.0)).rgb;
    float3 cR  = tex2D(ReShade::BackBuffer, uv + float2(texel.x, 0.0)).rgb;
    float3 cU  = tex2D(ReShade::BackBuffer, uv + float2(0.0, texel.y)).rgb;
    float3 cD  = tex2D(ReShade::BackBuffer, uv - float2(0.0, texel.y)).rgb;
    float3 cUL = tex2D(ReShade::BackBuffer, uv + float2(-texel.x, texel.y)).rgb;
    float3 cUR = tex2D(ReShade::BackBuffer, uv + float2(texel.x, texel.y)).rgb;
    float3 cDL = tex2D(ReShade::BackBuffer, uv + float2(-texel.x, -texel.y)).rgb;
    float3 cDR = tex2D(ReShade::BackBuffer, uv + float2(texel.x, -texel.y)).rgb;

    // Soft blur
    float3 blur = float3(0.0, 0.0, 0.0);
    blur += c * 4.0;
    blur += cL + cR + cU + cD;
    blur += cUL + cUR + cDL + cDR;
    blur /= 12.0;

    // Estimate local contrast so detailed areas blur less
    float lL  = luminance(cL);
    float lR  = luminance(cR);
    float lU  = luminance(cU);
    float lD  = luminance(cD);
    float lUL = luminance(cUL);
    float lUR = luminance(cUR);
    float lDL = luminance(cDL);
    float lDR = luminance(cDR);

    float localMin = min(min(min(lL, lR), min(lU, lD)), min(min(lUL, lUR), min(lDL, lDR)));
    float localMax = max(max(max(lL, lR), max(lU, lD)), max(max(lUL, lUR), max(lDL, lDR)));
    float localContrast = localMax - localMin;

    // Less blur in shadows and in high-contrast areas
    float shadowProtect = 1.0 - smoothstep(0.08, 0.30, baseLuma);
    float contrastProtect = smoothstep(0.03, 0.09, localContrast);

    float blurAmount = 0.55;
    blurAmount *= (1.0 - 0.65 * shadowProtect);
    blurAmount *= (1.0 - 0.50 * contrastProtect);
    blurAmount = clamp(blurAmount, 0.10, 0.55);

    float3 painter = lerp(c, blur, blurAmount);

    // Preserve more chroma
    float luma = luminance(painter);
    painter = lerp(luma.xxx, painter, 0.90);

    // Warm palette shift
    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;

    painter = pow(painter, 0.92.xxx);

    // Dark-area contrast lift: prevents blacks from collapsing together
    float shadowLift = smoothstep(0.00, 0.22, baseLuma);
    float3 lifted = lerp(painter * 1.18, painter, shadowLift);
    painter = lerp(lifted, painter, 0.35);

    // Less posterization in shadows
    float levelsDark = 10.0;
    float levelsBright = 6.0;
    float levels = lerp(levelsDark, levelsBright, smoothstep(0.08, 0.45, baseLuma));
    painter = floor(painter * levels) / levels;

    // Edge detection
    float dx = lR - lL;
    float dy = lU - lD;
    float edge = length(float2(dx, dy));

    // Boost edge response slightly in dark regions
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

    // Very light paper grain
    float grain = frac(sin(dot(uv * float2(1400.0, 900.0), float2(12.9898, 78.233))) * 43758.5453);
    result *= 0.985 + 0.03 * grain;

    return float4(saturate(result), 1.0);
}

technique PainterlyCyberpunk
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Painterly;
    }
}
