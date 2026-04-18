#include "../ReShade.fxh"

uniform float HyperopiaDegree <
    ui_category = "Hyperopia Depth Blur";
    ui_type = "slider";
    ui_label = "Hyperopia Degree";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "0 keeps nearby objects almost clear. 1 makes nearby objects blur much more strongly and across a wider near range.";
> = 0.55;

uniform bool Hyperopia_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float Hyperopia_GetLinearDepth(float2 uv)
{
    return ReShade::GetLinearizedDepth(uv);
}

float3 Hyperopia_GetSceneColor(float2 uv)
{
    return tex2D(ReShade::BackBuffer, uv).rgb;
}

float Hyperopia_GetBlurFactor(float depth_value)
{
    float full_near_depth = lerp(0.01, 0.05, HyperopiaDegree);
    float clear_depth = lerp(0.08, 0.28, HyperopiaDegree);
    return 1.0 - smoothstep(full_near_depth, max(clear_depth, full_near_depth + 1e-4), depth_value);
}

void Hyperopia_AddTap(
    inout float3 accum_color,
    inout float accum_weight,
    float2 uv,
    float center_depth,
    float2 blur_radius_uv,
    float2 direction,
    float radius_scale,
    float tap_weight)
{
    float2 sample_uv = saturate(uv + direction * blur_radius_uv * radius_scale);
    float3 sample_color = Hyperopia_GetSceneColor(sample_uv);
    float sample_depth = Hyperopia_GetLinearDepth(sample_uv);

    float depth_delta = abs(sample_depth - center_depth);
    float depth_weight = exp(-depth_delta * 40.0);
    float final_weight = tap_weight * depth_weight;

    accum_color += sample_color * final_weight;
    accum_weight += final_weight;
}

float3 Hyperopia_ApplyBlur(float2 uv, float blur_factor)
{
    float3 center_color = Hyperopia_GetSceneColor(uv);
    if (blur_factor <= 1e-4)
        return center_color;

    float center_depth = Hyperopia_GetLinearDepth(uv);
    float max_blur_px = lerp(1.2, 12.0, HyperopiaDegree);
    float2 blur_radius_uv = BUFFER_PIXEL_SIZE * (max_blur_px * blur_factor);

    float3 accum_color = center_color;
    float accum_weight = 1.0;

    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 0.50, 0.95);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 0.50, 0.95);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 0.50, 0.95);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 0.50, 0.95);

    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.7071,  0.7071), 0.78, 0.78);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-0.7071,  0.7071), 0.78, 0.78);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.7071, -0.7071), 0.78, 0.78);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-0.7071, -0.7071), 0.78, 0.78);

    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 1.00, 0.58);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 1.00, 0.58);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 1.00, 0.58);
    Hyperopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 1.00, 0.58);

    return accum_color / max(accum_weight, 1e-4);
}

float4 Hyperopia_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 scene = Hyperopia_GetSceneColor(uv);

    if (!Hyperopia_HasDepth)
        return float4(scene, 1.0);

    float linear_depth = Hyperopia_GetLinearDepth(uv);
    float blur_factor = Hyperopia_GetBlurFactor(linear_depth);

    return float4(Hyperopia_ApplyBlur(uv, blur_factor), 1.0);
}

technique HyperopiaDepthBlur
<
    ui_tooltip = "Nearby objects blur progressively using true depth-buffer information, while farther objects stay clearer.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = Hyperopia_PS;
    }
}
