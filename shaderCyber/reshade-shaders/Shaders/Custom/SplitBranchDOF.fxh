/*
 * Branch-compatible depth-of-field helper for SplitScreenController.fx
 *
 * This is intentionally not a direct import of DOF.fx's technique graph.
 * ReShade techniques cannot be called like functions from another effect,
 * so this include exposes a self-contained DOF branch function instead.
 */

#ifndef SPLIT_BRANCH_DOF_FXH
#define SPLIT_BRANCH_DOF_FXH

uniform float SSC_DOF_FocusDepth <
	ui_category = "Split Screen Controller";
	ui_label = "DOF Focus Depth";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
	ui_tooltip = "Linearized depth value used as the branch DOF focus plane.";
> = 0.18;

uniform float SSC_DOF_FocusRange <
	ui_category = "Split Screen Controller";
	ui_label = "DOF Focus Range";
	ui_type = "drag";
	ui_min = 0.001;
	ui_max = 0.5;
	ui_step = 0.001;
	ui_tooltip = "Depth interval that remains relatively sharp around the focus plane.";
> = 0.035;

uniform float SSC_DOF_MaxBlurPx <
	ui_category = "Split Screen Controller";
	ui_label = "DOF Max Blur Px";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 24.0;
	ui_step = 0.25;
	ui_tooltip = "Maximum blur radius in pixels for the branch DOF example.";
> = 10.0;

uniform float SSC_DOF_FarStrength <
	ui_category = "Split Screen Controller";
	ui_label = "DOF Far Strength";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.01;
	ui_tooltip = "Relative strength of far-plane blur.";
> = 1.0;

uniform float SSC_DOF_NearStrength <
	ui_category = "Split Screen Controller";
	ui_label = "DOF Near Strength";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.01;
	ui_tooltip = "Relative strength of near-plane blur.";
> = 0.8;

float SSC_GetDOFDepth(float2 uv)
{
	return ReShade::GetLinearizedDepth(uv);
}

float SSC_ComputeDOFBlurAmount(float2 uv)
{
	const float scene_depth = SSC_GetDOFDepth(uv);
	const float focus_range = max(SSC_DOF_FocusRange, 1e-4);
	const float depth_delta = scene_depth - SSC_DOF_FocusDepth;
	const float far_blur = saturate(max(depth_delta, 0.0) / focus_range) * SSC_DOF_FarStrength;
	const float near_blur = saturate(max(-depth_delta, 0.0) / focus_range) * SSC_DOF_NearStrength;
	return saturate(max(far_blur, near_blur));
}

float3 SSC_EvaluateDOFBranch(float2 uv)
{
	const float blur_amount = SSC_ComputeDOFBlurAmount(uv);
	const float blur_radius_px = blur_amount * SSC_DOF_MaxBlurPx;

	if (blur_radius_px <= 0.01)
	{
		return tex2D(ReShade::BackBuffer, uv).rgb;
	}

	const float2 radius = blur_radius_px * BUFFER_PIXEL_SIZE;

	float3 accum = tex2D(ReShade::BackBuffer, uv).rgb * 0.24;
	float weight = 0.24;

	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(1.0, 0.0)).rgb * 0.10;
	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(-1.0, 0.0)).rgb * 0.10;
	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(0.0, 1.0)).rgb * 0.10;
	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(0.0, -1.0)).rgb * 0.10;
	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(0.707, 0.707)).rgb * 0.09;
	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(-0.707, 0.707)).rgb * 0.09;
	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(0.707, -0.707)).rgb * 0.09;
	accum += tex2D(ReShade::BackBuffer, uv + radius * float2(-0.707, -0.707)).rgb * 0.09;

	weight += 0.10 * 4.0 + 0.09 * 4.0;

	const float inner_radius_scale = 0.45;
	accum += tex2D(ReShade::BackBuffer, uv + radius * inner_radius_scale * float2(1.0, 0.0)).rgb * 0.06;
	accum += tex2D(ReShade::BackBuffer, uv + radius * inner_radius_scale * float2(-1.0, 0.0)).rgb * 0.06;
	accum += tex2D(ReShade::BackBuffer, uv + radius * inner_radius_scale * float2(0.0, 1.0)).rgb * 0.06;
	accum += tex2D(ReShade::BackBuffer, uv + radius * inner_radius_scale * float2(0.0, -1.0)).rgb * 0.06;
	weight += 0.06 * 4.0;

	return accum / max(weight, 1e-4);
}

#endif
