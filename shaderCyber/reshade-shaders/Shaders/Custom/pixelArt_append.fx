#ifndef PIXEL_ART_APPEND_FX
#define PIXEL_ART_APPEND_FX

#ifndef PIXEL_ART_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

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

float PixelArtAppend_Luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

float3 PixelArtAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float2 texSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 pixelGrid = texSize / PixelScale;
    float2 snappedUV = (floor(uv * pixelGrid) + 0.5) / pixelGrid;

    float3 c = tex2D(source_sampler, snappedUV).rgb;
    c = floor(c * ColorLevels) / ColorLevels;

    float luma = PixelArtAppend_Luminance(c);
    c = lerp(luma.xxx, c, SaturationBoost);

    return saturate(c);
}

#ifndef PIXEL_ART_APPEND_LIBRARY_MODE
float4 PixelArtAppend_PS(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    return float4(PixelArtAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique PixelArt_Append
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PixelArtAppend_PS;
    }
}
#endif

#endif
