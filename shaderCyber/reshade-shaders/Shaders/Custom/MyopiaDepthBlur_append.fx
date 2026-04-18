#ifndef MYOPIA_DEPTH_BLUR_APPEND_FX
#define MYOPIA_DEPTH_BLUR_APPEND_FX

#ifndef MYOPIA_DEPTH_BLUR_APPEND_LIBRARY_MODE
#include "../ReShade.fxh"
#endif

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

float MyopiaAppend_GetLinearDepth(float2 uv)
{
    return ReShade::GetLinearizedDepth(uv);
}

float3 MyopiaAppend_GetSceneColor(sampler source_sampler, float2 uv)
{
    return tex2D(source_sampler, uv).rgb;
}

float MyopiaAppend_GetBlurFactor(float depth_value)
{
    float start_depth = lerp(0.34, 0.10, MyopiaDegree);
    float full_depth = lerp(0.88, 0.42, MyopiaDegree);
    return smoothstep(start_depth, max(full_depth, start_depth + 1e-4), depth_value);
}

void MyopiaAppend_AddTap(
    inout float3 accum_color,
    inout float accum_weight,
    sampler source_sampler,
    float2 uv,
    float center_depth,
    float2 blur_radius_uv,
    float2 direction,
    float radius_scale,
    float tap_weight)
{
    float2 sample_uv = saturate(uv + direction * blur_radius_uv * radius_scale);
    float3 sample_color = MyopiaAppend_GetSceneColor(source_sampler, sample_uv);
    float sample_depth = MyopiaAppend_GetLinearDepth(sample_uv);

    float depth_delta = abs(sample_depth - center_depth);
    float depth_weight = exp(-depth_delta * 40.0);
    float final_weight = tap_weight * depth_weight;

    accum_color += sample_color * final_weight;
    accum_weight += final_weight;
}

float3 MyopiaAppend_ApplyBlurFromSampler(sampler source_sampler, float2 uv, float blur_factor)
{
    float3 center_color = MyopiaAppend_GetSceneColor(source_sampler, uv);
    if (blur_factor <= 1e-4)
        return center_color;

    float center_depth = MyopiaAppend_GetLinearDepth(uv);
    float max_blur_px = lerp(1.2, 12.0, MyopiaDegree);
    float2 blur_radius_uv = BUFFER_PIXEL_SIZE * (max_blur_px * blur_factor);

    float3 accum_color = center_color;
    float accum_weight = 1.0;

    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 0.50, 0.95);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 0.50, 0.95);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 0.50, 0.95);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 0.50, 0.95);

    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.7071,  0.7071), 0.78, 0.78);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-0.7071,  0.7071), 0.78, 0.78);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.7071, -0.7071), 0.78, 0.78);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-0.7071, -0.7071), 0.78, 0.78);

    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 1.00, 0.58);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 1.00, 0.58);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 1.00, 0.58);
    MyopiaAppend_AddTap(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 1.00, 0.58);

    return accum_color / max(accum_weight, 1e-4);
}

float3 MyopiaAppend_ApplyFromSampler(sampler source_sampler, float2 uv)
{
    float3 scene = MyopiaAppend_GetSceneColor(source_sampler, uv);

    if (!Myopia_HasDepth)
        return scene;

    float linear_depth = MyopiaAppend_GetLinearDepth(uv);
    float blur_factor = MyopiaAppend_GetBlurFactor(linear_depth);

    return MyopiaAppend_ApplyBlurFromSampler(source_sampler, uv, blur_factor);
}

#ifndef MYOPIA_DEPTH_BLUR_APPEND_LIBRARY_MODE
float4 MyopiaAppend_PS(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return float4(MyopiaAppend_ApplyFromSampler(ReShade::BackBuffer, uv), 1.0);
}

technique MyopiaDepthBlur_Append
<
    ui_tooltip = "Append-labeled copy of the myopia blur. Distant objects blur progressively using the true depth buffer.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MyopiaAppend_PS;
    }
}
#endif

#endif
