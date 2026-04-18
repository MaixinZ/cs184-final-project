#include "../ReShade.fxh"

uniform float PixelScale <
    ui_type = "slider";
    ui_min = 1.0; ui_max = 32.0;
    ui_label = "Pixel Scale";
> = 8.0;

uniform float ColorLevels <
    ui_type = "slider";
    ui_min = 2.0; ui_max = 16.0;
    ui_label = "Color Levels";
> = 6.0;

uniform float SaturationBoost <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
    ui_label = "Saturation Boost";
> = 1.2;

float luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float3 ApplyPixelArt(float2 uv)
{
    float2 texSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);

    float2 pixelGrid = texSize / PixelScale;
    float2 snappedUV = (floor(uv * pixelGrid) + 0.5) / pixelGrid;

    float3 c = tex2D(ReShade::BackBuffer, snappedUV).rgb;

    c = floor(c * ColorLevels) / ColorLevels;

    float luma = luminance(c);
    c = lerp(luma.xxx, c, SaturationBoost);

    return saturate(c);
}

float4 PS_PixelArt(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    float3 result = ApplyPixelArt(uv);
    return float4(result, 1.0);
}

technique PixelArt
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_PixelArt;
    }
}
