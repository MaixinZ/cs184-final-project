#include "../ReShade.fxh"
#include "DepthDistanceCommon.fxh"

uniform float DFS_Strength <
    ui_category = "Depth Fog Stylization";
    ui_type = "slider";
    ui_label = "Stylization Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls how strongly distant regions become colder, flatter, paler, and softer.";
> = 0.65;

uniform float DFS_StartDepth <
    ui_category = "Depth Fog Stylization";
    ui_type = "slider";
    ui_label = "Start Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Linear depth where the far-distance stylization begins.";
> = 0.24;

uniform float DFS_FullDepth <
    ui_category = "Depth Fog Stylization";
    ui_type = "slider";
    ui_label = "Full Depth";
    ui_min = 0.01; ui_max = 1.0;
    ui_tooltip = "Linear depth where the stylization reaches full strength.";
> = 0.78;

uniform bool DFS_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float4 DFS_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 scene = DDS_GetSceneColor(uv);

    if (!DFS_HasDepth)
        return float4(scene, 1.0);

    float linear_depth = DDS_GetLinearDepth(uv);
    float far_factor = DDS_GetDepthWindow(linear_depth, DFS_StartDepth, DFS_FullDepth) * DFS_Strength;

    float3 softened = DDS_BilateralBlur(uv, lerp(0.0, 5.5, far_factor), 1.1);
    float softened_luma = DDS_Luminance(softened);
    float3 desaturated = lerp(softened, softened_luma.xxx, far_factor * 0.42);

    float3 fog_color = float3(0.66, 0.79, 0.95);
    float3 cooled = desaturated * lerp(float3(1.0, 1.0, 1.0), float3(0.92, 0.98, 1.08), far_factor);
    float3 flattened = lerp(cooled, fog_color, far_factor * 0.24);

    float mid_luma = DDS_Luminance(flattened);
    flattened = lerp(flattened, lerp(0.5.xxx, mid_luma.xxx, 0.85), far_factor * 0.18);

    return float4(saturate(lerp(scene, flattened, far_factor)), 1.0);
}

technique DepthFogStylization <
    ui_tooltip = "Standalone far-distance stylization layer: distant regions become colder, paler, flatter, and slightly softer.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DFS_PS;
    }
}
