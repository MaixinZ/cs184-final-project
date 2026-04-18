#include "../ReShade.fxh"

uniform float MyopiaDegree <
    ui_category = "Myopia Depth Blur";
    ui_type = "slider";
    ui_label = "Myopia Degree";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "0 keeps distant objects almost clear. 1 makes distant objects blur much more strongly and earlier.";
> = 0.55;

uniform bool Myopia_HasDepth <
    source = "bufready_depth";
    hidden = true;
> = false;

float Myopia_GetLinearDepth(float2 uv)
{
    return ReShade::GetLinearizedDepth(uv);
}

float3 Myopia_GetSceneColor(float2 uv)
{
    return tex2D(ReShade::BackBuffer, uv).rgb;
}

float Myopia_GetBlurFactor(float depth_value)
{
    float start_depth = lerp(0.34, 0.10, MyopiaDegree);
    float full_depth = lerp(0.88, 0.42, MyopiaDegree);
    return smoothstep(start_depth, max(full_depth, start_depth + 1e-4), depth_value);
}

void Myopia_AddTap(
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
    float3 sample_color = Myopia_GetSceneColor(sample_uv);
    float sample_depth = Myopia_GetLinearDepth(sample_uv);

    float depth_delta = abs(sample_depth - center_depth);
    float depth_weight = exp(-depth_delta * 40.0);
    float final_weight = tap_weight * depth_weight;

    accum_color += sample_color * final_weight;
    accum_weight += final_weight;
}

float3 Myopia_ApplyBlur(float2 uv, float blur_factor)
{
    float3 center_color = Myopia_GetSceneColor(uv);
    if (blur_factor <= 1e-4)
        return center_color;

    float center_depth = Myopia_GetLinearDepth(uv);
    float max_blur_px = lerp(1.2, 12.0, MyopiaDegree);
    float2 blur_radius_uv = BUFFER_PIXEL_SIZE * (max_blur_px * blur_factor);

    float3 accum_color = center_color;
    float accum_weight = 1.0;

    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 0.50, 0.95);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 0.50, 0.95);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 0.50, 0.95);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 0.50, 0.95);

    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.7071,  0.7071), 0.78, 0.78);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-0.7071,  0.7071), 0.78, 0.78);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.7071, -0.7071), 0.78, 0.78);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-0.7071, -0.7071), 0.78, 0.78);

    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 1.00, 0.58);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 1.00, 0.58);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 1.00, 0.58);
    Myopia_AddTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 1.00, 0.58);

    return accum_color / max(accum_weight, 1e-4);
}

float4 Myopia_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 scene = Myopia_GetSceneColor(uv);

    if (!Myopia_HasDepth)
        return float4(scene, 1.0);

    float linear_depth = Myopia_GetLinearDepth(uv);
    float blur_factor = Myopia_GetBlurFactor(linear_depth);

    return float4(Myopia_ApplyBlur(uv, blur_factor), 1.0);
}

technique MyopiaDepthBlur
<
    ui_tooltip = "Distant objects blur progressively using true depth-buffer information, while nearby objects stay clearer.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = Myopia_PS;
    }
}
