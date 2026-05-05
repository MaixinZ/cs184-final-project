/*
 * Architectural prototype for branch-aware region compositing in ReShade.
 *
 * Core separation:
 * 1. Input stroke representation
 * 2. Curve smoothing / fitting
 * 3. Endpoint tangent estimation
 * 4. Closure strategy selection
 * 5. Closed contour construction
 * 6. Region mask evaluation
 * 7. Branch A / Branch B evaluation
 * 8. Final compositing
 *
 * Future extension hooks:
 * - Replace the single stored stroke with multiple strokes
 * - Replace contour-based closure with brush / painted masks
 * - Add editable control points or arbitrary screen-space shapes
 * - Replace EvaluateRegionMaskFromContour with richer boolean region logic
 */

#include "../ReShade.fxh"
#include "SplitStackEffects_new.fxh"

#define SSC_MAX_STROKE_POINTS 1440
#define SSC_META_TEXELS 2
#define SSC_MAX_CONTOUR_POINTS 96

#define SSC_CLOSURE_DIRECT 0
#define SSC_CLOSURE_EDGE 1
#define SSC_CLOSURE_ALREADY_CLOSED 2

#define SSC_STATE_MAGIC 13.375
#define SSC_STROKE_SPACING_PX 18.0
#define SSC_CLOSE_THRESHOLD_PX 18.0
#define SSC_BOUNDARY_WIDTH_PX 2.0
#define SSC_BOUNDARY_FADE_DURATION_MS 1000.0

#define SSC_BEZIER_POINTS_PER_SEGMENT 6
#define SSC_BEZIER_SEGMENT_STRIDE 5
#define SSC_MAX_BEZIER_SEGMENTS (((SSC_MAX_STROKE_POINTS - 2) / SSC_BEZIER_SEGMENT_STRIDE) + 1)

#define SSC_MAX_STROKE_SAMPLES 56
#define SSC_DIRECT_CLOSURE_SAMPLES 20
#define SSC_EDGE_CONNECTOR_SAMPLES 12
#define SSC_EDGE_PATH_SAMPLES 12

#define SSC_STACK_EFFECT_ITEMS \
    "None\0" \
    "Oil Paint\0" \
    "Painter\0" \
    "Celluloid\0" \
    "Black Ink\0" \
    "Pixel Art\0" \
    "Myopia Blur\0" \
    "Hyperopia Blur\0" \
    "Depth Probe\0" \
    "RedGreen Assist\0" \
    "Depth Fog Stylization\0" \
    "Depth Layered Painterly\0" \
    "Depth Outline Overlay\0" \
    "Depth Screentone Overlay\0" \
    "Silver Depth Edge\0" \
    "Near Bright Far Dark\0" \
    "Depth Band Assist\0" \
    "Atmospheric Depth Cue\0"

uniform int MaskMode <
	ui_category = "Split Screen Controller";
	ui_label = "Mask Mode";
	ui_type = "combo";
	ui_items =
		"Vertical Split\0"
		"Drawn Stroke\0";
	ui_tooltip = "Uses the original fixed vertical split or the interactive drawn-stroke region mask.";
> = 1;

uniform float SplitPosition <
	ui_category = "Split Screen Controller";
	ui_label = "Split Position";
	ui_type = "drag";
	ui_min = 0.05;
	ui_max = 0.95;
	ui_step = 0.005;
	ui_tooltip = "Split position used by the original vertical split mode.";
> = 0.5;

uniform int BranchA_Slot1 < ui_category = "Split Stack A"; ui_label = "Slot 1"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchA_Slot2 < ui_category = "Split Stack A"; ui_label = "Slot 2"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchA_Slot3 < ui_category = "Split Stack A"; ui_label = "Slot 3"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchA_Slot4 < ui_category = "Split Stack A"; ui_label = "Slot 4"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchA_Slot5 < ui_category = "Split Stack A"; ui_label = "Slot 5"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchA_Slot6 < ui_category = "Split Stack A"; ui_label = "Slot 6"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchA_Slot7 < ui_category = "Split Stack A"; ui_label = "Slot 7"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchA_Slot8 < ui_category = "Split Stack A"; ui_label = "Slot 8"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;

uniform int BranchB_Slot1 < ui_category = "Split Stack B"; ui_label = "Slot 1"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchB_Slot2 < ui_category = "Split Stack B"; ui_label = "Slot 2"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchB_Slot3 < ui_category = "Split Stack B"; ui_label = "Slot 3"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchB_Slot4 < ui_category = "Split Stack B"; ui_label = "Slot 4"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchB_Slot5 < ui_category = "Split Stack B"; ui_label = "Slot 5"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchB_Slot6 < ui_category = "Split Stack B"; ui_label = "Slot 6"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchB_Slot7 < ui_category = "Split Stack B"; ui_label = "Slot 7"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;
uniform int BranchB_Slot8 < ui_category = "Split Stack B"; ui_label = "Slot 8"; ui_type = "combo"; ui_items = SSC_STACK_EFFECT_ITEMS; > = 0;

uniform bool InvertDrawnRegion <
	ui_category = "Split Screen Controller";
	ui_label = "Invert Drawn Region";
	ui_tooltip = "Swaps which branch is used inside versus outside the closed drawn region.";
> = false;

uniform bool ShowBoundary <
	ui_category = "Split Screen Controller";
	ui_label = "Show Boundary";
	ui_tooltip = "Draws the active split boundary or drawn contour.";
> = true;

uniform bool ShowDebugMask <
	ui_category = "Split Screen Controller";
	ui_label = "Show Debug Mask";
	ui_tooltip = "Displays the evaluated region mask instead of the branch compositing result.";
> = false;

uniform bool ArmStrokeCapture <
	ui_category = "Split Screen Controller";
	ui_label = "Arm Stroke Capture";
	ui_tooltip = "Manual fallback for enabling drawn-stroke capture. Useful when the S + L + I/T hotkey is inconvenient or the overlay has keyboard focus.";
> = false;

uniform bool StrokeModeKeyS <
	source = "key";
	keycode = 0x53;
	toggle = false;
> = false;

uniform bool StrokeModeKeyI <
	source = "key";
	keycode = 0x49;
	toggle = false;
> = false;

uniform bool StrokeModeKeyT <
	source = "key";
	keycode = 0x54;
	toggle = false;
> = false;

uniform bool StrokeModeKeyL <
	source = "key";
	keycode = 0x4C;
	toggle = false;
> = false;

uniform float2 StrokeMousePixels <
	source = "mousepoint";
> = float2(0.0, 0.0);

uniform bool StrokeMouseLeftDown <
	source = "mousebutton";
	keycode = 0;
	toggle = false;
> = false;

uniform float StrokeFrameTimeMs <
	source = "frametime";
> = 0.0;
texture StrokePointsA
{
	Width = SSC_MAX_STROKE_POINTS;
	Height = 1;
	Format = RGBA16F;
};
texture StrokePointsB
{
	Width = SSC_MAX_STROKE_POINTS;
	Height = 1;
	Format = RGBA16F;
};
texture StrokeMetaA
{
	Width = SSC_META_TEXELS;
	Height = 1;
	Format = RGBA16F;
};
texture StrokeMetaB
{
	Width = SSC_META_TEXELS;
	Height = 1;
	Format = RGBA16F;
};
texture ContourMetaTex
{
	Width = 1;
	Height = 1;
	Format = RGBA16F;
};
texture ContourPointsTex
{
	Width = SSC_MAX_CONTOUR_POINTS;
	Height = 1;
	Format = RGBA16F;
};
texture RegionMaskTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG16F;
};
texture BranchA_PingTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};
texture BranchA_PongTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};
texture BranchB_PingTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};
texture BranchB_PongTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA16F;
};

sampler StrokePointsSamplerA
{
	Texture = StrokePointsA;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler StrokePointsSamplerB
{
	Texture = StrokePointsB;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler StrokeMetaSamplerA
{
	Texture = StrokeMetaA;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler StrokeMetaSamplerB
{
	Texture = StrokeMetaB;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler ContourMetaSampler
{
	Texture = ContourMetaTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler ContourPointsSampler
{
	Texture = ContourPointsTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler RegionMaskSampler
{
	Texture = RegionMaskTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler BranchA_PingSampler
{
	Texture = BranchA_PingTex;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler BranchA_PongSampler
{
	Texture = BranchA_PongTex;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler BranchB_PingSampler
{
	Texture = BranchB_PingTex;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
sampler BranchB_PongSampler
{
	Texture = BranchB_PongTex;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};

static const float3 SSC_BOUNDARY_COLOR = float3(1.0, 0.78, 0.18);
static const float3 SSC_MASK_A_COLOR = float3(0.08, 0.18, 0.36);
static const float3 SSC_MASK_B_COLOR = float3(0.95, 0.33, 0.12);
static const float3 SSC_DRAWING_BOUNDARY_COLOR = float3(0.88, 0.91, 0.96);
static const float3 SSC_FINAL_BOUNDARY_COLOR = float3(1.0, 0.82, 0.22);
static const float3 SSC_CURSOR_GLOW_CORE_COLOR = float3(0.96, 0.98, 1.0);
static const float3 SSC_CURSOR_GLOW_EDGE_COLOR = float3(0.72, 0.78, 0.88);
static const float SSC_CURSOR_GLOW_RADIUS_PX = 18.0;
static const float SSC_CURSOR_CORE_RADIUS_PX = 5.0;
float FloatFromBool(bool value)
{
	return value ? 1.0 : 0.0;
}

bool BoolFromFloat(float value)
{
	return value > 0.5;
}

int DecodeRoundedInt(float value, int max_value)
{
	return clamp((int)(value + 0.5), 0, max_value);
}

float2 SafeNormalize2(float2 value, float2 fallback_value)
{
	const float value_length = length(value);
	return (value_length > 1e-5) ? (value / value_length) : fallback_value;
}

float2 GetMouseUV()
{
	return saturate(StrokeMousePixels * BUFFER_PIXEL_SIZE);
}

bool IsStrokeComboDown()
{
	// Accept either I or T as the third key so the requested "S + L + IT" combo is easy to trigger.
	return StrokeModeKeyS && StrokeModeKeyL && (StrokeModeKeyI || StrokeModeKeyT);
}

float4 SampleTexel1D(sampler source_sampler, int index, int width)
{
	const float u = (index + 0.5) / width;
	return tex2Dlod(source_sampler, float4(u, 0.5, 0.0, 0.0));
}

float4 LoadStrokePointRaw(sampler source_sampler, int index)
{
	return SampleTexel1D(source_sampler, clamp(index, 0, SSC_MAX_STROKE_POINTS - 1), SSC_MAX_STROKE_POINTS);
}

float2 LoadStrokePoint(sampler source_sampler, int index)
{
	return LoadStrokePointRaw(source_sampler, index).xy;
}

float4 LoadStrokeMetaTexel(sampler source_sampler, int index)
{
	return SampleTexel1D(source_sampler, clamp(index, 0, SSC_META_TEXELS - 1), SSC_META_TEXELS);
}

void LoadStrokeState(
	sampler meta_sampler,
	out int stroke_count,
	out bool is_drawing,
	out bool mode_enabled,
	out bool previous_left_down,
	out bool previous_combo_down,
	out float boundary_fade_remaining_ms)
{
	stroke_count = 0;
	is_drawing = false;
	mode_enabled = false;
	previous_left_down = false;
	previous_combo_down = false;
	boundary_fade_remaining_ms = 0.0;

	const float4 meta0 = LoadStrokeMetaTexel(meta_sampler, 0);
	const float4 meta1 = LoadStrokeMetaTexel(meta_sampler, 1);

	if (abs(meta0.w - SSC_STATE_MAGIC) > 0.1)
	{
		stroke_count = 0;
		is_drawing = false;
		mode_enabled = false;
		previous_left_down = false;
		previous_combo_down = false;
		boundary_fade_remaining_ms = 0.0;
		return;
	}

	stroke_count = DecodeRoundedInt(meta0.x, SSC_MAX_STROKE_POINTS);
	is_drawing = BoolFromFloat(meta0.y);
	mode_enabled = BoolFromFloat(meta0.z);
	previous_left_down = BoolFromFloat(meta1.x);
	previous_combo_down = BoolFromFloat(meta1.y);
	boundary_fade_remaining_ms = max(meta1.z, 0.0);
}

void ResolveStrokeInputState(
	bool previous_mode_enabled,
	bool previous_is_drawing,
	bool previous_left_down,
	bool previous_combo_down,
	out bool combo_down,
	out bool mode_enabled,
	out bool left_pressed,
	out bool begin_stroke,
	out bool end_stroke,
	out bool drawing_after)
{
	combo_down = false;
	mode_enabled = previous_mode_enabled;
	left_pressed = false;
	begin_stroke = false;
	end_stroke = false;
	drawing_after = previous_is_drawing;

	combo_down = IsStrokeComboDown();
	const bool combo_pressed = combo_down && !previous_combo_down;

	const bool toggled_mode_enabled = combo_pressed ? !previous_mode_enabled : previous_mode_enabled;
	mode_enabled = ArmStrokeCapture || toggled_mode_enabled;
	left_pressed = StrokeMouseLeftDown && !previous_left_down;
	const bool left_released = !StrokeMouseLeftDown && previous_left_down;
	begin_stroke = mode_enabled && left_pressed && !previous_is_drawing;
	end_stroke = mode_enabled && left_released && previous_is_drawing;
	drawing_after = mode_enabled && StrokeMouseLeftDown;
}

float GetDistancePixels(float2 point_a, float2 point_b)
{
	return length((point_a - point_b) * BUFFER_SCREEN_SIZE);
}

bool ShouldAppendAnchorPoint(sampler point_sampler, int previous_count, bool previous_is_drawing, float2 mouse_uv)
{
	bool should_append = false;

	if (!previous_is_drawing || previous_count >= SSC_MAX_STROKE_POINTS || previous_count <= 0)
	{
		return should_append;
	}

	const int anchor_index = (previous_count > 1) ? (previous_count - 2) : 0;
	const float2 anchor_point = LoadStrokePoint(point_sampler, anchor_index);
	should_append = GetDistancePixels(mouse_uv, anchor_point) >= SSC_STROKE_SPACING_PX;
	return should_append;
}

int ResolveUpdatedStrokeCount(int previous_count, bool begin_stroke, bool previous_is_drawing, bool end_stroke, bool append_anchor)
{
	int updated_count = previous_count;

	if (begin_stroke)
	{
		updated_count = 1;
		return updated_count;
	}

	if ((previous_is_drawing || end_stroke) && previous_count <= 0)
	{
		updated_count = 1;
		return updated_count;
	}

	if ((previous_is_drawing || end_stroke) && append_anchor)
	{
		updated_count = min(previous_count + 1, SSC_MAX_STROKE_POINTS);
		return updated_count;
	}

	return updated_count;
}

float4 PS_UpdateStrokePointsA(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	const int texel_index = clamp((int)position.x, 0, SSC_MAX_STROKE_POINTS - 1);

	int previous_count = 0;
	bool previous_is_drawing = false;
	bool previous_mode_enabled = false;
	bool previous_left_down = false;
	bool previous_combo_down = false;
	float previous_boundary_fade_remaining_ms = 0.0;
	LoadStrokeState(
		StrokeMetaSamplerB,
		previous_count,
		previous_is_drawing,
		previous_mode_enabled,
		previous_left_down,
		previous_combo_down,
		previous_boundary_fade_remaining_ms);

	const float2 mouse_uv = GetMouseUV();

	bool combo_down = false;
	bool mode_enabled = false;
	bool left_pressed = false;
	bool begin_stroke = false;
	bool end_stroke = false;
	bool drawing_after = false;
	ResolveStrokeInputState(
		previous_mode_enabled,
		previous_is_drawing,
		previous_left_down,
		previous_combo_down,
		combo_down,
		mode_enabled,
		left_pressed,
		begin_stroke,
		end_stroke,
		drawing_after);

	const bool append_anchor = ShouldAppendAnchorPoint(StrokePointsSamplerB, previous_count, previous_is_drawing, mouse_uv);

	float2 stored_point = float2(0.0, 0.0);

	if (begin_stroke)
	{
		stored_point = (texel_index == 0) ? mouse_uv : float2(0.0, 0.0);
	}
	else if (previous_is_drawing || end_stroke)
	{
		if (append_anchor)
		{
			if (texel_index < previous_count)
			{
				stored_point = LoadStrokePoint(StrokePointsSamplerB, texel_index);
			}
			else if (texel_index == previous_count)
			{
				stored_point = mouse_uv;
			}
		}
		else
		{
			const int live_tail_index = max(previous_count - 1, 0);

			if (texel_index < live_tail_index)
			{
				stored_point = LoadStrokePoint(StrokePointsSamplerB, texel_index);
			}
			else if (texel_index == live_tail_index)
			{
				stored_point = mouse_uv;
			}
		}
	}
	else if (texel_index < previous_count)
	{
		stored_point = LoadStrokePoint(StrokePointsSamplerB, texel_index);
	}

	return float4(stored_point, 0.0, 1.0);
}

float4 PS_UpdateStrokeMetaA(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	const int texel_index = clamp((int)position.x, 0, SSC_META_TEXELS - 1);

	int previous_count = 0;
	bool previous_is_drawing = false;
	bool previous_mode_enabled = false;
	bool previous_left_down = false;
	bool previous_combo_down = false;
	float previous_boundary_fade_remaining_ms = 0.0;
	LoadStrokeState(
		StrokeMetaSamplerB,
		previous_count,
		previous_is_drawing,
		previous_mode_enabled,
		previous_left_down,
		previous_combo_down,
		previous_boundary_fade_remaining_ms);

	const float2 mouse_uv = GetMouseUV();

	bool combo_down = false;
	bool mode_enabled = false;
	bool left_pressed = false;
	bool begin_stroke = false;
	bool end_stroke = false;
	bool drawing_after = false;
	ResolveStrokeInputState(
		previous_mode_enabled,
		previous_is_drawing,
		previous_left_down,
		previous_combo_down,
		combo_down,
		mode_enabled,
		left_pressed,
		begin_stroke,
		end_stroke,
		drawing_after);

	const bool append_anchor = ShouldAppendAnchorPoint(StrokePointsSamplerB, previous_count, previous_is_drawing, mouse_uv);
	const int updated_count = ResolveUpdatedStrokeCount(previous_count, begin_stroke, previous_is_drawing, end_stroke, append_anchor);
	float updated_boundary_fade_remaining_ms = max(previous_boundary_fade_remaining_ms - max(StrokeFrameTimeMs, 0.0), 0.0);

	if (begin_stroke || drawing_after || updated_count < 2)
	{
		updated_boundary_fade_remaining_ms = 0.0;
	}
	else if (end_stroke)
	{
		updated_boundary_fade_remaining_ms = SSC_BOUNDARY_FADE_DURATION_MS;
	}

	if (texel_index == 0)
	{
		return float4(updated_count, FloatFromBool(drawing_after), FloatFromBool(mode_enabled), SSC_STATE_MAGIC);
	}

	return float4(FloatFromBool(StrokeMouseLeftDown), FloatFromBool(combo_down), updated_boundary_fade_remaining_ms, 0.0);
}

float4 PS_CopyStrokePointsToB(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	const int texel_index = clamp((int)position.x, 0, SSC_MAX_STROKE_POINTS - 1);
	return LoadStrokePointRaw(StrokePointsSamplerA, texel_index);
}

float4 PS_CopyStrokeMetaToB(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	const int texel_index = clamp((int)position.x, 0, SSC_META_TEXELS - 1);
	return LoadStrokeMetaTexel(StrokeMetaSamplerA, texel_index);
}
int GetStrokeCount()
{
	int stroke_count = 0;
	bool is_drawing = false;
	bool mode_enabled = false;
	bool previous_left_down = false;
	bool previous_combo_down = false;
	float boundary_fade_remaining_ms = 0.0;
	LoadStrokeState(
		StrokeMetaSamplerB,
		stroke_count,
		is_drawing,
		mode_enabled,
		previous_left_down,
		previous_combo_down,
		boundary_fade_remaining_ms);
	return stroke_count;
}

void GetStrokeRuntimeState(out int stroke_count, out bool is_drawing, out bool mode_enabled, out float boundary_fade_remaining_ms)
{
	bool previous_left_down = false;
	bool previous_combo_down = false;
	LoadStrokeState(
		StrokeMetaSamplerB,
		stroke_count,
		is_drawing,
		mode_enabled,
		previous_left_down,
		previous_combo_down,
		boundary_fade_remaining_ms);
}

float2 GetRawStrokePoint(int index)
{
	return LoadStrokePoint(StrokePointsSamplerB, index);
}

float2 EstimateStartTangent(int stroke_count)
{
	if (stroke_count < 2)
	{
		return float2(1.0, 0.0);
	}

	float2 tangent = GetRawStrokePoint(1) - GetRawStrokePoint(0);

	if (stroke_count >= 3)
	{
		tangent = (GetRawStrokePoint(1) - GetRawStrokePoint(0)) * 0.75 +
			(GetRawStrokePoint(2) - GetRawStrokePoint(1)) * 0.25;
	}

	return SafeNormalize2(tangent, float2(1.0, 0.0));
}

float2 EstimateEndTangent(int stroke_count)
{
	if (stroke_count < 2)
	{
		return float2(1.0, 0.0);
	}

	const int last_index = stroke_count - 1;
	float2 tangent = GetRawStrokePoint(last_index) - GetRawStrokePoint(last_index - 1);

	if (stroke_count >= 3)
	{
		tangent = (GetRawStrokePoint(last_index) - GetRawStrokePoint(last_index - 1)) * 0.75 +
			(GetRawStrokePoint(last_index - 1) - GetRawStrokePoint(last_index - 2)) * 0.25;
	}

	return SafeNormalize2(tangent, float2(1.0, 0.0));
}

int GetBezierSegmentCount(int stroke_count)
{
	if (stroke_count <= 1)
	{
		return 0;
	}

	return min(((stroke_count - 2) / SSC_BEZIER_SEGMENT_STRIDE) + 1, SSC_MAX_BEZIER_SEGMENTS);
}

int GetBezierSegmentStartIndex(int segment_index)
{
	return max(segment_index, 0) * SSC_BEZIER_SEGMENT_STRIDE;
}

float2 LoadBezierControlPoint(int stroke_count, int segment_index, int control_index)
{
	const int start_index = GetBezierSegmentStartIndex(segment_index);
	const int source_index = clamp(start_index + control_index, 0, stroke_count - 1);
	return GetRawStrokePoint(source_index);
}

float2 EvaluateQuinticBezier(float2 point0, float2 point1, float2 point2, float2 point3, float2 point4, float2 point5, float t)
{
	const float omt = 1.0 - t;
	const float omt2 = omt * omt;
	const float omt3 = omt2 * omt;
	const float omt4 = omt3 * omt;
	const float omt5 = omt4 * omt;
	const float t2 = t * t;
	const float t3 = t2 * t;
	const float t4 = t3 * t;
	const float t5 = t4 * t;

	return
		point0 * omt5 +
		point1 * (5.0 * omt4 * t) +
		point2 * (10.0 * omt3 * t2) +
		point3 * (10.0 * omt2 * t3) +
		point4 * (5.0 * omt * t4) +
		point5 * t5;
}

float EstimateBezierSegmentLength(int stroke_count, int segment_index)
{
	float length_estimate = 0.0;
	float2 previous_point = LoadBezierControlPoint(stroke_count, segment_index, 0);

	[unroll]
	for (int control_index = 1; control_index < SSC_BEZIER_POINTS_PER_SEGMENT; ++control_index)
	{
		const float2 current_point = LoadBezierControlPoint(stroke_count, segment_index, control_index);
		length_estimate += max(distance(current_point, previous_point), 1e-4);
		previous_point = current_point;
	}

	return max(length_estimate, 1e-4);
}

float2 SampleBezierSegment(int stroke_count, int segment_index, float local_t)
{
	const float2 point0 = LoadBezierControlPoint(stroke_count, segment_index, 0);
	const float2 point1 = LoadBezierControlPoint(stroke_count, segment_index, 1);
	const float2 point2 = LoadBezierControlPoint(stroke_count, segment_index, 2);
	const float2 point3 = LoadBezierControlPoint(stroke_count, segment_index, 3);
	const float2 point4 = LoadBezierControlPoint(stroke_count, segment_index, 4);
	const float2 point5 = LoadBezierControlPoint(stroke_count, segment_index, 5);
	return EvaluateQuinticBezier(point0, point1, point2, point3, point4, point5, saturate(local_t));
}

float GetBezierStrokeLength(int stroke_count)
{
	const int segment_count = GetBezierSegmentCount(stroke_count);

	if (segment_count <= 0)
	{
		return 1e-4;
	}

	float total_length = 0.0;

	[loop]
	for (int segment_index = 0; segment_index < SSC_MAX_BEZIER_SEGMENTS; ++segment_index)
	{
		if (segment_index >= segment_count)
		{
			break;
		}

		total_length += EstimateBezierSegmentLength(stroke_count, segment_index);
	}

	return max(total_length, 1e-4);
}

float2 SampleUserStroke(float stroke_u, int stroke_count)
{
	if (stroke_count <= 0)
	{
		return float2(0.5, 0.5);
	}

	if (stroke_count == 1)
	{
		return GetRawStrokePoint(0);
	}

	const int segment_count = GetBezierSegmentCount(stroke_count);

	if (segment_count <= 0)
	{
		return GetRawStrokePoint(stroke_count - 1);
	}

	const float total_length = GetBezierStrokeLength(stroke_count);
	const float target_length = saturate(stroke_u) * total_length;
	float accumulated_length = 0.0;

	// Each segment uses six raw points as a quintic Bezier control net.
	// Neighboring segments advance by five points so they share one endpoint.
	[loop]
	for (int segment_index = 0; segment_index < SSC_MAX_BEZIER_SEGMENTS; ++segment_index)
	{
		if (segment_index >= segment_count)
		{
			break;
		}

		const float segment_length = EstimateBezierSegmentLength(stroke_count, segment_index);
		const bool is_last_segment = (segment_index == segment_count - 1);

		if (target_length <= accumulated_length + segment_length || is_last_segment)
		{
			const float local_t = saturate((target_length - accumulated_length) / segment_length);
			return SampleBezierSegment(stroke_count, segment_index, local_t);
		}

		accumulated_length += segment_length;
	}

	return GetRawStrokePoint(stroke_count - 1);
}

void EstimateEndpointTangents(int stroke_count, out float2 start_tangent, out float2 end_tangent)
{
	start_tangent = EstimateStartTangent(stroke_count);
	end_tangent = EstimateEndTangent(stroke_count);
}

float ComputeDirectionalPenalty(float2 from_point, float2 to_point, float2 desired_direction)
{
	const float2 delta = to_point - from_point;
	const float delta_length = length(delta);

	if (delta_length <= 1e-5)
	{
		return 0.0;
	}

	const float alignment = saturate(dot(delta / delta_length, desired_direction));
	return 1.0 - alignment;
}

float2 ProjectPointToScreenEdge(float2 sample_point, int edge_index)
{
	if (edge_index == 0)
	{
		return float2(saturate(sample_point.x), 0.0);
	}

	if (edge_index == 1)
	{
		return float2(1.0, saturate(sample_point.y));
	}

	if (edge_index == 2)
	{
		return float2(saturate(sample_point.x), 1.0);
	}

	return float2(0.0, saturate(sample_point.y));
}

void ChooseBestEdgeProjection(float2 endpoint, float2 outward_tangent, out int best_edge_index, out float2 best_edge_point, out float best_edge_score)
{
	best_edge_index = 0;
	best_edge_point = ProjectPointToScreenEdge(endpoint, 0);
	best_edge_score = 1e9;

	[unroll]
	for (int edge_index = 0; edge_index < 4; ++edge_index)
	{
		const float2 candidate_edge_point = ProjectPointToScreenEdge(endpoint, edge_index);
		const float candidate_distance = distance(endpoint, candidate_edge_point);
		const float candidate_penalty = ComputeDirectionalPenalty(endpoint, candidate_edge_point, outward_tangent);
		const float candidate_score = candidate_distance + candidate_penalty * 0.35;

		if (candidate_score < best_edge_score)
		{
			best_edge_score = candidate_score;
			best_edge_index = edge_index;
			best_edge_point = candidate_edge_point;
		}
	}
}

float GetPerimeterParam(float2 perimeter_point, int edge_index)
{
	if (edge_index == 0)
	{
		return saturate(perimeter_point.x);
	}

	if (edge_index == 1)
	{
		return 1.0 + saturate(perimeter_point.y);
	}

	if (edge_index == 2)
	{
		return 2.0 + (1.0 - saturate(perimeter_point.x));
	}

	return 3.0 + (1.0 - saturate(perimeter_point.y));
}

float2 SamplePerimeterByParam(float perimeter_param)
{
	const float wrapped_param = frac(perimeter_param * 0.25) * 4.0;

	if (wrapped_param < 1.0)
	{
		return float2(wrapped_param, 0.0);
	}

	if (wrapped_param < 2.0)
	{
		return float2(1.0, wrapped_param - 1.0);
	}

	if (wrapped_param < 3.0)
	{
		return float2(3.0 - wrapped_param, 1.0);
	}

	return float2(0.0, 4.0 - wrapped_param);
}

float2 GetPerimeterTangent(float perimeter_param)
{
	const float wrapped_param = frac(perimeter_param * 0.25) * 4.0;

	if (wrapped_param < 1.0)
	{
		return float2(1.0, 0.0);
	}

	if (wrapped_param < 2.0)
	{
		return float2(0.0, 1.0);
	}

	if (wrapped_param < 3.0)
	{
		return float2(-1.0, 0.0);
	}

	return float2(0.0, -1.0);
}

float GetClockwisePerimeterDistance(float start_param, float end_param)
{
	return (end_param >= start_param) ? (end_param - start_param) : (end_param + 4.0 - start_param);
}

float2 GetPerimeterRouteTangent(float perimeter_param, bool use_clockwise_route)
{
	const float2 tangent = GetPerimeterTangent(perimeter_param);
	return use_clockwise_route ? tangent : -tangent;
}

float2 SamplePerimeterRoute(float start_param, float end_param, bool use_clockwise_route, float path_u)
{
	const float path_length = use_clockwise_route ?
		GetClockwisePerimeterDistance(start_param, end_param) :
		GetClockwisePerimeterDistance(end_param, start_param);

	const float sampled_param = use_clockwise_route ?
		(start_param + saturate(path_u) * path_length) :
		(start_param - saturate(path_u) * path_length);

	return SamplePerimeterByParam(sampled_param);
}

float ComputeDirectClosureScore(float2 start_point, float2 end_point, float2 start_tangent, float2 end_tangent)
{
	const float2 closure_direction = SafeNormalize2(start_point - end_point, end_tangent);
	const float distance_score = distance(start_point, end_point);
	const float tangent_penalty =
		(1.0 - saturate(dot(closure_direction, end_tangent))) +
		(1.0 - saturate(dot(closure_direction, start_tangent)));

	return distance_score + tangent_penalty * 0.35;
}

bool IsStrokeEffectivelyClosed(float2 start_point, float2 end_point)
{
	const float normalized_threshold = SSC_CLOSE_THRESHOLD_PX / max(length(BUFFER_SCREEN_SIZE), 1.0);
	return distance(start_point, end_point) <= normalized_threshold;
}

void ChooseClosureStrategy(
	int stroke_count,
	out int closure_strategy,
	out float2 start_point,
	out float2 end_point,
	out float2 start_tangent,
	out float2 end_tangent,
	out float2 start_edge_point,
	out float2 end_edge_point,
	out float start_edge_param,
	out float end_edge_param,
	out bool use_clockwise_route)
{
	start_point = GetRawStrokePoint(0);
	end_point = GetRawStrokePoint(stroke_count - 1);
	EstimateEndpointTangents(stroke_count, start_tangent, end_tangent);

	start_edge_point = start_point;
	end_edge_point = end_point;
	start_edge_param = 0.0;
	end_edge_param = 0.0;
	use_clockwise_route = true;

	if (IsStrokeEffectivelyClosed(start_point, end_point))
	{
		closure_strategy = SSC_CLOSURE_ALREADY_CLOSED;
		return;
	}

	int start_edge_index = 0;
	int end_edge_index = 0;
	float start_edge_score = 0.0;
	float end_edge_score = 0.0;

	ChooseBestEdgeProjection(start_point, -start_tangent, start_edge_index, start_edge_point, start_edge_score);
	ChooseBestEdgeProjection(end_point, end_tangent, end_edge_index, end_edge_point, end_edge_score);

	start_edge_param = GetPerimeterParam(start_edge_point, start_edge_index);
	end_edge_param = GetPerimeterParam(end_edge_point, end_edge_index);

	const float clockwise_distance = GetClockwisePerimeterDistance(end_edge_param, start_edge_param);
	const float counter_clockwise_distance = GetClockwisePerimeterDistance(start_edge_param, end_edge_param);

	use_clockwise_route = clockwise_distance <= counter_clockwise_distance;

	const float direct_score = ComputeDirectClosureScore(start_point, end_point, start_tangent, end_tangent);
	const float edge_score = start_edge_score + end_edge_score + min(clockwise_distance, counter_clockwise_distance);

	closure_strategy = (edge_score + 0.02 < direct_score) ? SSC_CLOSURE_EDGE : SSC_CLOSURE_DIRECT;
}

float2 EvaluateCubicBezier(float2 point0, float2 point1, float2 point2, float2 point3, float t)
{
	const float omt = 1.0 - t;
	const float omt2 = omt * omt;
	const float omt3 = omt2 * omt;
	const float t2 = t * t;
	const float t3 = t2 * t;

	return
		point0 * omt3 +
		point1 * (3.0 * omt2 * t) +
		point2 * (3.0 * omt * t2) +
		point3 * t3;
}

float2 BuildBezierConnector(float2 from_point, float2 to_point, float2 from_tangent, float2 to_tangent, float connector_u)
{
	const float connector_distance = distance(from_point, to_point);
	const float handle_length = min(connector_distance * 0.35, 0.25);

	const float2 control0 = from_point;
	const float2 control1 = from_point + SafeNormalize2(from_tangent, float2(1.0, 0.0)) * handle_length;
	const float2 control2 = to_point - SafeNormalize2(to_tangent, float2(1.0, 0.0)) * handle_length;
	const float2 control3 = to_point;

	return EvaluateCubicBezier(control0, control1, control2, control3, saturate(connector_u));
}

float2 BuildEndpointBezierClosure(float closure_u, float2 start_point, float2 end_point, float2 start_tangent, float2 end_tangent)
{
	return BuildBezierConnector(end_point, start_point, end_tangent, start_tangent, closure_u);
}

int ComputeStrokeSampleCount(int stroke_count)
{
	return clamp((stroke_count - 1) * 3 + 1, 8, SSC_MAX_STROKE_SAMPLES);
}

void ComputeContourLayout(
	int stroke_count,
	int closure_strategy,
	out int stroke_samples,
	out int direct_closure_samples,
	out int edge_connector_samples,
	out int edge_path_samples,
	out int total_contour_samples)
{
	stroke_samples = ComputeStrokeSampleCount(stroke_count);
	direct_closure_samples = 0;
	edge_connector_samples = 0;
	edge_path_samples = 0;

	if (closure_strategy == SSC_CLOSURE_DIRECT)
	{
		direct_closure_samples = SSC_DIRECT_CLOSURE_SAMPLES;
	}
	else if (closure_strategy == SSC_CLOSURE_EDGE)
	{
		edge_connector_samples = SSC_EDGE_CONNECTOR_SAMPLES;
		edge_path_samples = SSC_EDGE_PATH_SAMPLES;
	}
	else
	{
		direct_closure_samples = 1;
	}

	total_contour_samples = stroke_samples + direct_closure_samples + edge_connector_samples + edge_path_samples + edge_connector_samples;
	total_contour_samples = min(total_contour_samples, SSC_MAX_CONTOUR_POINTS);
}

float4 PS_BuildContourMeta(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	int stroke_count = 0;
	bool is_drawing = false;
	bool mode_enabled = false;
	float boundary_fade_remaining_ms = 0.0;
	GetStrokeRuntimeState(stroke_count, is_drawing, mode_enabled, boundary_fade_remaining_ms);

	if (is_drawing || stroke_count < 2)
	{
		return float4(0.0, 0.0, 0.0, 0.0);
	}

	int closure_strategy = SSC_CLOSURE_DIRECT;
	float2 start_point = float2(0.0, 0.0);
	float2 end_point = float2(0.0, 0.0);
	float2 start_tangent = float2(1.0, 0.0);
	float2 end_tangent = float2(1.0, 0.0);
	float2 start_edge_point = float2(0.0, 0.0);
	float2 end_edge_point = float2(0.0, 0.0);
	float start_edge_param = 0.0;
	float end_edge_param = 0.0;
	bool use_clockwise_route = true;

	ChooseClosureStrategy(
		stroke_count,
		closure_strategy,
		start_point,
		end_point,
		start_tangent,
		end_tangent,
		start_edge_point,
		end_edge_point,
		start_edge_param,
		end_edge_param,
		use_clockwise_route);

	int stroke_samples = 0;
	int direct_closure_samples = 0;
	int edge_connector_samples = 0;
	int edge_path_samples = 0;
	int total_contour_samples = 0;
	ComputeContourLayout(
		stroke_count,
		closure_strategy,
		stroke_samples,
		direct_closure_samples,
		edge_connector_samples,
		edge_path_samples,
		total_contour_samples);

	return float4(total_contour_samples, 1.0, closure_strategy, FloatFromBool(use_clockwise_route));
}

float2 SampleContourPointByIndex(int contour_index)
{
	const float4 contour_meta = tex2Dlod(ContourMetaSampler, float4(0.5, 0.5, 0.0, 0.0));
	const int total_contour_samples = DecodeRoundedInt(contour_meta.x, SSC_MAX_CONTOUR_POINTS);
	const int closure_strategy = DecodeRoundedInt(contour_meta.z, SSC_CLOSURE_ALREADY_CLOSED);
	const int stroke_count = GetStrokeCount();

	if (stroke_count < 2 || total_contour_samples <= 0)
	{
		return float2(-1.0, -1.0);
	}

	int stroke_samples = 0;
	int direct_closure_samples = 0;
	int edge_connector_samples = 0;
	int edge_path_samples = 0;
	int total_samples = 0;
	ComputeContourLayout(
		stroke_count,
		closure_strategy,
		stroke_samples,
		direct_closure_samples,
		edge_connector_samples,
		edge_path_samples,
		total_samples);

	if (contour_index < 0 || contour_index >= total_samples)
	{
		return float2(-1.0, -1.0);
	}

	float2 start_point = float2(0.0, 0.0);
	float2 end_point = float2(0.0, 0.0);
	float2 start_tangent = float2(1.0, 0.0);
	float2 end_tangent = float2(1.0, 0.0);
	float2 start_edge_point = float2(0.0, 0.0);
	float2 end_edge_point = float2(0.0, 0.0);
	float start_edge_param = 0.0;
	float end_edge_param = 0.0;
	bool route_clockwise = true;
	int resolved_closure_strategy = closure_strategy;

	ChooseClosureStrategy(
		stroke_count,
		resolved_closure_strategy,
		start_point,
		end_point,
		start_tangent,
		end_tangent,
		start_edge_point,
		end_edge_point,
		start_edge_param,
		end_edge_param,
		route_clockwise);

	if (contour_index < stroke_samples)
	{
		const float stroke_u = (stroke_samples > 1) ? (contour_index / (stroke_samples - 1.0)) : 0.0;
		return SampleUserStroke(stroke_u, stroke_count);
	}

	if (resolved_closure_strategy == SSC_CLOSURE_ALREADY_CLOSED)
	{
		return start_point;
	}

	if (resolved_closure_strategy == SSC_CLOSURE_DIRECT)
	{
		const int local_index = contour_index - stroke_samples;
		const float closure_u = (local_index + 1.0) / direct_closure_samples;
		return BuildEndpointBezierClosure(closure_u, start_point, end_point, start_tangent, end_tangent);
	}

	const int edge_local_index = contour_index - stroke_samples;

	if (edge_local_index < edge_connector_samples)
	{
		const float connector_u = (edge_local_index + 1.0) / edge_connector_samples;
		return BuildBezierConnector(
			end_point,
			end_edge_point,
			end_tangent,
			GetPerimeterRouteTangent(end_edge_param, route_clockwise),
			connector_u);
	}

	if (edge_local_index < edge_connector_samples + edge_path_samples)
	{
		const int path_index = edge_local_index - edge_connector_samples;
		const float path_u = (path_index + 1.0) / edge_path_samples;
		return SamplePerimeterRoute(end_edge_param, start_edge_param, route_clockwise, path_u);
	}

	const int connector_index = edge_local_index - edge_connector_samples - edge_path_samples;
	const float connector_u = (connector_index + 1.0) / edge_connector_samples;
	return BuildBezierConnector(
		start_edge_point,
		start_point,
		GetPerimeterRouteTangent(start_edge_param, route_clockwise),
		start_tangent,
		connector_u);
}

float4 PS_BuildContourPoints(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	const int contour_index = clamp((int)position.x, 0, SSC_MAX_CONTOUR_POINTS - 1);
	const float4 contour_meta = tex2Dlod(ContourMetaSampler, float4(0.5, 0.5, 0.0, 0.0));
	const int total_contour_samples = DecodeRoundedInt(contour_meta.x, SSC_MAX_CONTOUR_POINTS);

	if (contour_index >= total_contour_samples)
	{
		return float4(-1.0, -1.0, 0.0, 0.0);
	}

	const float2 contour_point = SampleContourPointByIndex(contour_index);
	return float4(contour_point, 1.0, 0.0);
}
float2 LoadContourPoint(int contour_index)
{
	return SampleTexel1D(ContourPointsSampler, clamp(contour_index, 0, SSC_MAX_CONTOUR_POINTS - 1), SSC_MAX_CONTOUR_POINTS).xy;
}

float DistanceToSegmentPixels(float2 point_pixels, float2 segment_a_pixels, float2 segment_b_pixels)
{
	const float2 segment = segment_b_pixels - segment_a_pixels;
	const float segment_length_squared = dot(segment, segment);

	if (segment_length_squared <= 1e-6)
	{
		return length(point_pixels - segment_a_pixels);
	}

	const float projection = saturate(dot(point_pixels - segment_a_pixels, segment) / segment_length_squared);
	const float2 closest_point = segment_a_pixels + segment * projection;
	return length(point_pixels - closest_point);
}

float EvaluateLiveStrokeBoundary(float2 uv, int stroke_count)
{
	if (stroke_count < 2)
	{
		return 0.0;
	}

	float minimum_boundary_distance_px = 1e9;
	const float2 point_pixels = uv * BUFFER_SCREEN_SIZE;
	float2 previous_point = GetRawStrokePoint(0);

	[loop]
	for (int stroke_index = 1; stroke_index < SSC_MAX_STROKE_POINTS; ++stroke_index)
	{
		if (stroke_index >= stroke_count)
		{
			break;
		}

		const float2 current_point = GetRawStrokePoint(stroke_index);
		const float segment_distance_px = DistanceToSegmentPixels(
			point_pixels,
			previous_point * BUFFER_SCREEN_SIZE,
			current_point * BUFFER_SCREEN_SIZE);
		minimum_boundary_distance_px = min(minimum_boundary_distance_px, segment_distance_px);
		previous_point = current_point;
	}

	return 1.0 - smoothstep(0.5 * SSC_BOUNDARY_WIDTH_PX, SSC_BOUNDARY_WIDTH_PX, minimum_boundary_distance_px);
}

float2 EvaluateRegionMaskFromContour(float2 uv)
{
	int stroke_count = 0;
	bool is_drawing = false;
	bool mode_enabled = false;
	float boundary_fade_remaining_ms = 0.0;
	GetStrokeRuntimeState(stroke_count, is_drawing, mode_enabled, boundary_fade_remaining_ms);

	const float4 contour_meta = tex2Dlod(ContourMetaSampler, float4(0.5, 0.5, 0.0, 0.0));
	const int contour_count = DecodeRoundedInt(contour_meta.x, SSC_MAX_CONTOUR_POINTS);
	const bool contour_ready = BoolFromFloat(contour_meta.y);
	const bool wants_drawn_mask = (MaskMode == 1);
	const bool use_drawn_mask = wants_drawn_mask && contour_ready && contour_count >= 3;

	if (wants_drawn_mask && is_drawing)
	{
		// While the left mouse button is held, show only the live open stroke preview.
		// The actual closure strategy is deferred until the button is released.
		return float2(0.0, EvaluateLiveStrokeBoundary(uv, stroke_count));
	}

	if (wants_drawn_mask && !use_drawn_mask)
	{
		return float2(0.0, 0.0);
	}

	if (!use_drawn_mask)
	{
		const float region_value = (uv.x >= SplitPosition) ? 1.0 : 0.0;
		const float vertical_distance_px = abs(uv.x - SplitPosition) * BUFFER_WIDTH;
		const float boundary_value = 1.0 - smoothstep(0.5 * SSC_BOUNDARY_WIDTH_PX, SSC_BOUNDARY_WIDTH_PX, vertical_distance_px);
		return float2(region_value, boundary_value);
	}

	bool inside_region = false;
	float minimum_boundary_distance_px = 1e9;

	const float2 point_pixels = uv * BUFFER_SCREEN_SIZE;
	float2 previous_point = LoadContourPoint(0);

	[loop]
	for (int contour_index = 1; contour_index < SSC_MAX_CONTOUR_POINTS; ++contour_index)
	{
		if (contour_index >= contour_count)
		{
			break;
		}

		const float2 current_point = LoadContourPoint(contour_index);

		const float segment_distance_px = DistanceToSegmentPixels(
			point_pixels,
			previous_point * BUFFER_SCREEN_SIZE,
			current_point * BUFFER_SCREEN_SIZE);
		minimum_boundary_distance_px = min(minimum_boundary_distance_px, segment_distance_px);

		const bool straddles_scanline = ((previous_point.y > uv.y) != (current_point.y > uv.y));

		if (straddles_scanline)
		{
			const float edge_delta_y = current_point.y - previous_point.y;
			const float ray_intersection_x = previous_point.x +
				(uv.y - previous_point.y) * (current_point.x - previous_point.x) / edge_delta_y;

			if (uv.x < ray_intersection_x)
			{
				inside_region = !inside_region;
			}
		}

		previous_point = current_point;
	}

	float region_value = FloatFromBool(inside_region);

	if (InvertDrawnRegion)
	{
		region_value = 1.0 - region_value;
	}

	const float boundary_value = 1.0 - smoothstep(0.5 * SSC_BOUNDARY_WIDTH_PX, SSC_BOUNDARY_WIDTH_PX, minimum_boundary_distance_px);
	return float2(region_value, boundary_value);
}

float4 PS_BuildRegionMask(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	const float2 mask_data = EvaluateRegionMaskFromContour(uv);
	return float4(mask_data.x, mask_data.y, 0.0, 1.0);
}

float4 ApplyBranchSlotPass(sampler source_sampler, float2 uv, int effect_id)
{
	return float4(saturate(SSB_ApplyEffect(source_sampler, uv, effect_id)), 1.0);
}

float4 PS_BranchA_Slot1(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(ReShade::BackBuffer, uv, BranchA_Slot1); }
float4 PS_BranchA_Slot2(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchA_PingSampler, uv, BranchA_Slot2); }
float4 PS_BranchA_Slot3(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchA_PongSampler, uv, BranchA_Slot3); }
float4 PS_BranchA_Slot4(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchA_PingSampler, uv, BranchA_Slot4); }
float4 PS_BranchA_Slot5(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchA_PongSampler, uv, BranchA_Slot5); }
float4 PS_BranchA_Slot6(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchA_PingSampler, uv, BranchA_Slot6); }
float4 PS_BranchA_Slot7(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchA_PongSampler, uv, BranchA_Slot7); }
float4 PS_BranchA_Slot8(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchA_PingSampler, uv, BranchA_Slot8); }

float4 PS_BranchB_Slot1(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(ReShade::BackBuffer, uv, BranchB_Slot1); }
float4 PS_BranchB_Slot2(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchB_PingSampler, uv, BranchB_Slot2); }
float4 PS_BranchB_Slot3(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchB_PongSampler, uv, BranchB_Slot3); }
float4 PS_BranchB_Slot4(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchB_PingSampler, uv, BranchB_Slot4); }
float4 PS_BranchB_Slot5(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchB_PongSampler, uv, BranchB_Slot5); }
float4 PS_BranchB_Slot6(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchB_PingSampler, uv, BranchB_Slot6); }
float4 PS_BranchB_Slot7(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchB_PongSampler, uv, BranchB_Slot7); }
float4 PS_BranchB_Slot8(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target { return ApplyBranchSlotPass(BranchB_PingSampler, uv, BranchB_Slot8); }

float GetCursorGlowMask(float2 uv, float2 cursor_uv)
{
	const float distance_px = length((uv - cursor_uv) * BUFFER_SCREEN_SIZE);
	const float outer_glow = 1.0 - smoothstep(0.0, SSC_CURSOR_GLOW_RADIUS_PX, distance_px);
	const float core_glow = 1.0 - smoothstep(0.0, SSC_CURSOR_CORE_RADIUS_PX, distance_px);
	return saturate(outer_glow * 0.75 + core_glow);
}

float4 CompositeBranches(float2 uv, float4 branch_a, float4 branch_b)
{
	const float2 mask_data = tex2D(RegionMaskSampler, uv).xy;
	const float region_value = saturate(mask_data.x);
	const float boundary_value = ShowBoundary ? saturate(mask_data.y) : 0.0;

	int stroke_count = 0;
	bool is_drawing = false;
	bool mode_enabled = false;
	float boundary_fade_remaining_ms = 0.0;
	GetStrokeRuntimeState(stroke_count, is_drawing, mode_enabled, boundary_fade_remaining_ms);

	const bool drawn_mask_mode = (MaskMode == 1);
	const bool drawn_capture_enabled = (MaskMode == 1) && mode_enabled;
	const bool use_silver_boundary = drawn_mask_mode && is_drawing;
	const float3 boundary_color = use_silver_boundary ? SSC_DRAWING_BOUNDARY_COLOR : SSC_FINAL_BOUNDARY_COLOR;
	const float drawn_boundary_fade = is_drawing ? 1.0 : saturate(boundary_fade_remaining_ms / SSC_BOUNDARY_FADE_DURATION_MS);
	const float boundary_visibility = drawn_mask_mode ? drawn_boundary_fade : 1.0;

	float3 composed = lerp(branch_a.rgb, branch_b.rgb, region_value);

	if (ShowDebugMask)
	{
		composed = lerp(SSC_MASK_A_COLOR, SSC_MASK_B_COLOR, region_value);
	}

	composed = lerp(composed, boundary_color, boundary_value * boundary_visibility);

	if (drawn_capture_enabled)
	{
		const float2 cursor_uv = GetMouseUV();
		const float cursor_glow_strength = is_drawing ? 1.0 : 0.45;
		const float cursor_glow = GetCursorGlowMask(uv, cursor_uv) * cursor_glow_strength;
		const float3 cursor_color = lerp(SSC_CURSOR_GLOW_EDGE_COLOR, SSC_CURSOR_GLOW_CORE_COLOR, cursor_glow);
		composed += cursor_color * cursor_glow * 0.65;
	}

	return float4(composed, 1.0);
}

float4 PS_SplitScreenController(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	const float4 branch_a = tex2D(BranchA_PongSampler, uv);
	const float4 branch_b = tex2D(BranchB_PongSampler, uv);
	return CompositeBranches(uv, branch_a, branch_b);
}

technique SplitScreenController_new
{
	pass UpdateStrokePointsA
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_UpdateStrokePointsA;
		RenderTarget = StrokePointsA;
	}
	pass UpdateStrokeMetaA
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_UpdateStrokeMetaA;
		RenderTarget = StrokeMetaA;
	}
	pass CopyStrokePointsToB
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyStrokePointsToB;
		RenderTarget = StrokePointsB;
	}
	pass CopyStrokeMetaToB
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyStrokeMetaToB;
		RenderTarget = StrokeMetaB;
	}
	pass BuildContourMeta
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BuildContourMeta;
		RenderTarget = ContourMetaTex;
	}
	pass BuildContourPoints
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BuildContourPoints;
		RenderTarget = ContourPointsTex;
	}
	pass BuildRegionMask
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BuildRegionMask;
		RenderTarget = RegionMaskTex;
	}
	pass BranchA_Slot1
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot1;
		RenderTarget = BranchA_PingTex;
	}
	pass BranchA_Slot2
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot2;
		RenderTarget = BranchA_PongTex;
	}
	pass BranchA_Slot3
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot3;
		RenderTarget = BranchA_PingTex;
	}
	pass BranchA_Slot4
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot4;
		RenderTarget = BranchA_PongTex;
	}
	pass BranchA_Slot5
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot5;
		RenderTarget = BranchA_PingTex;
	}
	pass BranchA_Slot6
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot6;
		RenderTarget = BranchA_PongTex;
	}
	pass BranchA_Slot7
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot7;
		RenderTarget = BranchA_PingTex;
	}
	pass BranchA_Slot8
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchA_Slot8;
		RenderTarget = BranchA_PongTex;
	}
	pass BranchB_Slot1
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot1;
		RenderTarget = BranchB_PingTex;
	}
	pass BranchB_Slot2
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot2;
		RenderTarget = BranchB_PongTex;
	}
	pass BranchB_Slot3
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot3;
		RenderTarget = BranchB_PingTex;
	}
	pass BranchB_Slot4
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot4;
		RenderTarget = BranchB_PongTex;
	}
	pass BranchB_Slot5
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot5;
		RenderTarget = BranchB_PingTex;
	}
	pass BranchB_Slot6
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot6;
		RenderTarget = BranchB_PongTex;
	}
	pass BranchB_Slot7
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot7;
		RenderTarget = BranchB_PingTex;
	}
	pass BranchB_Slot8
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_BranchB_Slot8;
		RenderTarget = BranchB_PongTex;
	}
	pass Composite
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_SplitScreenController;
	}
}
