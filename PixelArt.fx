#include "ReShade.fxh"

float4 PS_PixelArt(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    float2 texSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);

    float pixelScale = 8.0;

    float2 pixelGrid = texSize / pixelScale;
    float2 snappedUV = (floor(uv * pixelGrid) + 0.5) / pixelGrid;

    float3 c = tex2D(ReShade::BackBuffer, snappedUV).rgb;

    float levels = 6.0;
    c = floor(c * levels) / levels;

    float luma = dot(c, float3(0.299, 0.587, 0.114));
    c = lerp(luma.xxx, c, 1.2);

    return float4(saturate(c), 1.0);
}

technique PixelArt
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_PixelArt;
    }
}