#ifndef DEPTH_COORDINATE_PROBE_APPEND_FX
#define DEPTH_COORDINATE_PROBE_APPEND_FX

#ifndef DEPTH_COORDINATE_PROBE_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

uniform bool DepthProbe_ShowIfNoDepth <
    ui_category = "Depth Coordinate Probe";
    ui_label = "Show Warning If No Depth";
    ui_tooltip = "If depth is unavailable, draw a visible magenta warning instead of silently passing through.";
> = true;

uniform int DepthProbe_Mode <
    ui_category = "Depth Coordinate Probe";
    ui_type = "combo";
    ui_label = "Mode";
    ui_items = "Depth Tint\0Linear Depth\0Raw Hardware Depth\0Depth Contours\0";
    ui_tooltip = "Choose how to visualize the real depth buffer values.";
> = 0;

uniform float DepthProbe_Near <
    ui_category = "Depth Coordinate Probe";
    ui_type = "slider";
    ui_label = "Near Depth";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Lower bound in linearized depth space.";
> = 0.05;

uniform float DepthProbe_Far <
    ui_category = "Depth Coordinate Probe";
    ui_type = "slider";
    ui_label = "Far Depth";
    ui_min = 0.01; ui_max = 1.0;
    ui_tooltip = "Upper bound in linearized depth space.";
> = 0.85;

uniform float DepthProbe_TintStrength <
    ui_category = "Depth Coordinate Probe";
    ui_type = "slider";
    ui_label = "Tint Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "How strongly the scene is recolored by linear depth.";
> = 0.80;

uniform float DepthProbe_ContourScale <
    ui_category = "Depth Coordinate Probe";
    ui_type = "slider";
    ui_label = "Contour Scale";
    ui_min = 4.0; ui_max = 120.0;
    ui_tooltip = "Higher values create more depth contour bands.";
> = 32.0;

uniform bool DepthProbe_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float DepthProbeAppend_GetRawDepth(float2 uv)
{
    return tex2D(ReShade::DepthBuffer, uv).x;
}

float DepthProbeAppend_GetLinearDepth(float2 uv)
{
    return ReShade::GetLinearizedDepth(uv);
}

float DepthProbeAppend_GetWindowedDepth(float linear_depth)
{
    float far_depth = max(DepthProbe_Far, DepthProbe_Near + 1e-4);
    return saturate((linear_depth - DepthProbe_Near) / (far_depth - DepthProbe_Near));
}

float3 DepthProbeAppend_GetDepthTint(float depth01)
{
    float3 near_color = float3(1.00, 0.28, 0.18);
    float3 mid_color = float3(0.95, 0.88, 0.25);
    float3 far_color = float3(0.20, 0.85, 1.00);

    float3 tint = lerp(near_color, mid_color, saturate(depth01 * 2.0));
    tint = lerp(tint, far_color, saturate(depth01 * 1.15 - 0.15));
    return tint;
}

float3 DepthProbeAppend_ReconstructApproxViewPosition(float2 uv, float linear_depth)
{
    float2 ndc = uv * 2.0 - 1.0;
    ndc.x *= BUFFER_ASPECT_RATIO;
    return float3(ndc, 1.0) * max(linear_depth, 1e-6);
}

float DepthProbeAppend_GetContourMask(float depth01)
{
    float bands = frac(depth01 * DepthProbe_ContourScale);
    float contour = 1.0 - smoothstep(0.08, 0.14, abs(bands - 0.5));
    return contour;
}

float3 DepthProbeAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = tex2D(source_sampler, uv).rgb;

    if (!DepthProbe_HasDepth)
    {
        if (!DepthProbe_ShowIfNoDepth)
            return scene;

        float2 centered = abs(uv * 2.0 - 1.0);
        float warning_mask = smoothstep(0.75, 0.15, max(centered.x, centered.y));
        float3 warning_color = lerp(scene, float3(1.0, 0.0, 1.0), warning_mask * 0.85);
        return warning_color;
    }

    float raw_depth = DepthProbeAppend_GetRawDepth(uv);
    float linear_depth = DepthProbeAppend_GetLinearDepth(uv);
    float depth01 = DepthProbeAppend_GetWindowedDepth(linear_depth);
    float contour = DepthProbeAppend_GetContourMask(depth01);
    float3 approx_view_pos = DepthProbeAppend_ReconstructApproxViewPosition(uv, linear_depth);

    if (DepthProbe_Mode == 1)
        return depth01.xxx;

    if (DepthProbe_Mode == 2)
        return raw_depth.xxx;

    if (DepthProbe_Mode == 3)
    {
        float3 contour_color = lerp(float3(0.02, 0.02, 0.02), float3(1.0, 0.84, 0.22), contour);
        contour_color *= 0.55 + saturate(approx_view_pos.z * 2.0) * 0.45;
        return saturate(contour_color);
    }

    float3 depth_tint = DepthProbeAppend_GetDepthTint(depth01);
    float3 tinted_scene = lerp(scene, scene * depth_tint, DepthProbe_TintStrength);
    tinted_scene = lerp(tinted_scene, float3(1.0, 0.95, 0.70), contour * 0.25);

    return saturate(tinted_scene);
}

#ifndef DEPTH_COORDINATE_PROBE_APPEND_LIBRARY_MODE
float4 DepthProbeAppend_PS(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(DepthProbeAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique DepthCoordinateProbe_Append
<
    ui_tooltip = "Append-labeled copy of the depth probe. Visualizes true screen-space depth values.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DepthProbeAppend_PS;
    }
}
#endif

#endif
