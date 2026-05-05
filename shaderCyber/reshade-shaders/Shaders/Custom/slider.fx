#include "../ReShade.fxh"

float luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float3 AssistRG(float3 c)
{
    float rStrength = c.r - max(c.g, c.b);
    float gStrength = c.g - max(c.r, c.b);

    float redMask = smoothstep(0.04, 0.22, rStrength);
    float greenMask = smoothstep(0.04, 0.22, gStrength);

    float luma = luminance(c);

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

    redTarget *= luma / max(luminance(redTarget), 0.001);
    greenTarget *= luma / max(luminance(greenTarget), 0.001);

    float3 outColor = c;
    outColor = lerp(outColor, redTarget, redMask * 0.85);
    outColor = lerp(outColor, greenTarget, greenMask * 0.85);

    return saturate(outColor);
}

float4 PS_RGAssist(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    float3 c = tex2D(ReShade::BackBuffer, uv).rgb;
    float3 result = AssistRG(c);
    return float4(result, 1.0);
}

technique RedGreenAssist
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_RGAssist;
    }
}
