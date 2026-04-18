#ifndef DEPTH_DISTANCE_COMMON_FXH
#define DEPTH_DISTANCE_COMMON_FXH

float DDS_GetLinearDepth(float2 uv)
{
    return ReShade::GetLinearizedDepth(uv);
}

float3 DDS_GetSceneColor(float2 uv)
{
    return tex2D(ReShade::BackBuffer, uv).rgb;
}

float3 DDS_GetSourceColor(sampler source_sampler, float2 uv)
{
    return tex2D(source_sampler, uv).rgb;
}

float DDS_Luminance(float3 color_value)
{
    return dot(color_value, float3(0.299, 0.587, 0.114));
}

float DDS_GetDepthWindow(float depth_value, float start_depth, float full_depth)
{
    return smoothstep(start_depth, max(full_depth, start_depth + 1e-4), depth_value);
}

void DDS_AddBilateralTap(
    inout float3 accum_color,
    inout float accum_weight,
    float2 uv,
    float center_depth,
    float2 blur_radius_uv,
    float2 direction,
    float radius_scale,
    float tap_weight,
    float depth_protection)
{
    float2 sample_uv = saturate(uv + direction * blur_radius_uv * radius_scale);
    float3 sample_color = DDS_GetSceneColor(sample_uv);
    float sample_depth = DDS_GetLinearDepth(sample_uv);

    float depth_delta = abs(sample_depth - center_depth);
    float depth_weight = exp(-depth_delta * (10.0 + depth_protection * 26.0));
    float final_weight = tap_weight * depth_weight;

    accum_color += sample_color * final_weight;
    accum_weight += final_weight;
}

void DDS_AddBilateralTapFromSampler(
    inout float3 accum_color,
    inout float accum_weight,
    sampler source_sampler,
    float2 uv,
    float center_depth,
    float2 blur_radius_uv,
    float2 direction,
    float radius_scale,
    float tap_weight,
    float depth_protection)
{
    float2 sample_uv = saturate(uv + direction * blur_radius_uv * radius_scale);
    float3 sample_color = DDS_GetSourceColor(source_sampler, sample_uv);
    float sample_depth = DDS_GetLinearDepth(sample_uv);

    float depth_delta = abs(sample_depth - center_depth);
    float depth_weight = exp(-depth_delta * (10.0 + depth_protection * 26.0));
    float final_weight = tap_weight * depth_weight;

    accum_color += sample_color * final_weight;
    accum_weight += final_weight;
}

float3 DDS_BilateralBlur(float2 uv, float blur_radius_px, float depth_protection)
{
    float3 center_color = DDS_GetSceneColor(uv);
    if (blur_radius_px <= 1e-4)
        return center_color;

    float center_depth = DDS_GetLinearDepth(uv);
    float2 blur_radius_uv = BUFFER_PIXEL_SIZE * blur_radius_px;

    float3 accum_color = center_color;
    float accum_weight = 1.0;

    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 0.50, 0.95, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 0.50, 0.95, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 0.50, 0.95, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 0.50, 0.95, depth_protection);

    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.7071,  0.7071), 0.78, 0.78, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-0.7071,  0.7071), 0.78, 0.78, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.7071, -0.7071), 0.78, 0.78, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-0.7071, -0.7071), 0.78, 0.78, depth_protection);

    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 1.00, 0.58, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 1.00, 0.58, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 1.00, 0.58, depth_protection);
    DDS_AddBilateralTap(accum_color, accum_weight, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 1.00, 0.58, depth_protection);

    return accum_color / max(accum_weight, 1e-4);
}

float3 DDS_BilateralBlurFromSampler(sampler source_sampler, float2 uv, float blur_radius_px, float depth_protection)
{
    float3 center_color = DDS_GetSourceColor(source_sampler, uv);
    if (blur_radius_px <= 1e-4)
        return center_color;

    float center_depth = DDS_GetLinearDepth(uv);
    float2 blur_radius_uv = BUFFER_PIXEL_SIZE * blur_radius_px;

    float3 accum_color = center_color;
    float accum_weight = 1.0;

    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 0.50, 0.95, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 0.50, 0.95, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 0.50, 0.95, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 0.50, 0.95, depth_protection);

    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.7071,  0.7071), 0.78, 0.78, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-0.7071,  0.7071), 0.78, 0.78, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.7071, -0.7071), 0.78, 0.78, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-0.7071, -0.7071), 0.78, 0.78, depth_protection);

    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 1.0,  0.0), 1.00, 0.58, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2(-1.0,  0.0), 1.00, 0.58, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0,  1.0), 1.00, 0.58, depth_protection);
    DDS_AddBilateralTapFromSampler(accum_color, accum_weight, source_sampler, uv, center_depth, blur_radius_uv, float2( 0.0, -1.0), 1.00, 0.58, depth_protection);

    return accum_color / max(accum_weight, 1e-4);
}

float DDS_DepthEdge(float2 uv, float scale)
{
    float2 px = BUFFER_PIXEL_SIZE;
    float center_depth = DDS_GetLinearDepth(uv);
    float depth_l = DDS_GetLinearDepth(uv - float2(px.x, 0.0));
    float depth_r = DDS_GetLinearDepth(uv + float2(px.x, 0.0));
    float depth_u = DDS_GetLinearDepth(uv - float2(0.0, px.y));
    float depth_d = DDS_GetLinearDepth(uv + float2(0.0, px.y));

    float edge = abs(depth_l - center_depth) + abs(depth_r - center_depth) + abs(depth_u - center_depth) + abs(depth_d - center_depth);
    return saturate(edge * scale);
}

float DDS_PaperNoise(float2 pixel_pos)
{
    return frac(sin(dot(pixel_pos * float2(0.91, 1.07), float2(12.9898, 78.233))) * 43758.5453);
}

#endif
