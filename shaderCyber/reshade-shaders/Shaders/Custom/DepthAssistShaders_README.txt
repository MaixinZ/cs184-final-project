Depth-Aware Project Shaders
===========================

Purpose
-------
This depth-aware family is designed for Cyberpunk 2077 + ReShade stylization. The
goal is not a raw depth debug view. These shaders use ReShade linearized depth to
support foreground/background separation, occlusion-boundary readability, and
stylized spatial perception while keeping the original game image visible.

All shaders described here are project-authored. They use screen-space color and
ReShade depth only; they do not use game geometry, material IDs, true normals, or
lighting buffers.

Depth shader set
----------------
The report's depth-aware shader family contains six shaders:
- Myopia Depth Blur
- Hyperopia Depth Blur
- Silver Depth Edge
- Near Bright Far Dark
- Depth Band Assist
- Atmospheric Depth Cue

Depth access
------------
The myopia and hyperopia shaders call ReShade::GetLinearizedDepth directly. The
newer assistive depth shaders call DDS_GetLinearDepth(...) from
DepthDistanceCommon.fxh, which wraps the same ReShade depth-linearization path.
Each depth shader also checks a hidden bufready_depth flag. If ReShade depth is
not available, the shader returns the input color unchanged.

Architecture note
-----------------
The depth shaders follow the same standalone/append pattern used by the rest of
the project.

Standalone mode:
- ReShade scans the .fx or *_append.fx file directly.
- The technique reads the current ReShade backbuffer.
- The shader uses ReShade depth for depth-based control.

Split-pipeline mode:
- The shader exposes an ApplyFromSampler(...) function.
- SplitStackEffects_new.fxh calls that function from branch A/B slots.
- The color input is the previous branch layer sampler, so the depth shader can be
  stacked after oil paint, cel, black ink, pixel art, or another depth effect.

AppendShared wrappers:
- AppendShared/*.fxh files include matching append shaders in library mode.
- Library mode keeps uniforms and ApplyFromSampler(...) functions available while
  preventing duplicate standalone technique registration inside the controller.

Files
-----
Myopia Depth Blur:
- Standalone: MyopiaDepthBlur.fx
- Append stage: MyopiaDepthBlur_append.fx
- Split wrapper: AppendShared/MyopiaDepthBlur_append_shared.fxh
- Technique names: MyopiaDepthBlur, MyopiaDepthBlur_Append
- Pipeline function: MyopiaAppend_ApplyFromSampler(...)

Hyperopia Depth Blur:
- Standalone: HyperopiaDepthBlur.fx
- Append stage: HyperopiaDepthBlur_append.fx
- Split wrapper: AppendShared/HyperopiaDepthBlur_append_shared.fxh
- Technique names: HyperopiaDepthBlur, HyperopiaDepthBlur_Append
- Pipeline function: HyperopiaAppend_ApplyFromSampler(...)

Silver Depth Edge:
- Append stage: SilverDepthEdge_append.fx
- Split wrapper: AppendShared/SilverDepthEdge_append_shared.fxh
- Technique name: SilverDepthEdge_Append
- Pipeline function: SDEAppend_ApplyFromSampler(...)

Near Bright Far Dark:
- Append stage: NearBrightFarDark_append.fx
- Split wrapper: AppendShared/NearBrightFarDark_append_shared.fxh
- Technique name: NearBrightFarDark_Append
- Pipeline function: NBFDAppend_ApplyFromSampler(...)

Depth Band Assist:
- Append stage: DepthBandAssist_append.fx
- Split wrapper: AppendShared/DepthBandAssist_append_shared.fxh
- Technique name: DepthBandAssist_Append
- Pipeline function: DBAAppend_ApplyFromSampler(...)

Atmospheric Depth Cue:
- Append stage: AtmosphericDepthCue_append.fx
- Split wrapper: AppendShared/AtmosphericDepthCue_append_shared.fxh
- Technique name: AtmosphericDepthCue_Append
- Pipeline function: ADCAppend_ApplyFromSampler(...)

How to use standalone
---------------------
Open the main ReShade UI and enable any available depth technique directly:
- MyopiaDepthBlur
- HyperopiaDepthBlur
- MyopiaDepthBlur_Append
- HyperopiaDepthBlur_Append
- SilverDepthEdge_Append
- NearBrightFarDark_Append
- DepthBandAssist_Append
- AtmosphericDepthCue_Append

How to use in SplitScreenController_new
---------------------------------------
Enable SplitScreenController_new, then choose any of these slot labels in Split
Stack A or Split Stack B:
- Myopia Blur
- Hyperopia Blur
- Silver Depth Edge
- Near Bright Far Dark
- Depth Band Assist
- Atmospheric Depth Cue

The split-stack controller evaluates each branch through ping-pong render targets.
Slot 1 reads the original backbuffer. Slot 2 reads Slot 1 output. Slot 3 reads Slot
2 output, and so on. Depth shaders participate in that chain by reading color from
the source_sampler passed into ApplyFromSampler(...).

Shader details
--------------
Myopia Depth Blur
- Role: Simulates far-field defocus.
- Source color: previous layer sampler in split-stack, backbuffer in standalone.
- Depth use: far-depth smoothstep response from linearized depth.
- Fallback: If bufready_depth is false, returns the input color unchanged.
- Main control: Myopia Degree.

Hyperopia Depth Blur
- Role: Simulates near-field defocus.
- Source color: previous layer sampler in split-stack, backbuffer in standalone.
- Depth use: inverted near-depth smoothstep response from linearized depth.
- Fallback: If bufready_depth is false, returns the input color unchanged.
- Main control: Hyperopia Degree.

Silver Depth Edge
- Role: Adds silver or user-tinted outlines at depth discontinuities.
- Source color: previous layer sampler in split-stack, backbuffer in standalone.
- Depth use: Sobel depth gradient from linearized depth.
- Fallback: If bufready_depth is false, returns the input color unchanged.
- Main controls: Edge Strength, Edge Threshold, Edge Width, Edge Color Preset,
  Silver Tint Color, Edge Glow Strength, Min Depth, Max Depth, Depth Edge Gamma.

Near Bright Far Dark
- Role: Brightens near space and darkens far space to clarify depth ordering.
- Source color: previous layer sampler in split-stack, backbuffer in standalone.
- Depth use: normalized linearized depth ramp between Near Depth and Far Depth.
- Fallback: If bufready_depth is false, returns the input color unchanged.
- Main controls: Near Depth, Far Depth, Near Brightness, Far Brightness, Curve
  Power, Preserve Saturation, Far Desaturation, Blend Strength.

Depth Band Assist
- Role: Separates continuous depth into restrained readable layers.
- Source color: previous layer sampler in split-stack, backbuffer in standalone.
- Depth use: linearized depth quantized into 3 to 5 bands.
- Fallback: If bufready_depth is false, returns the input color unchanged.
- Main controls: Band Count, Near Depth, Far Depth, Band Contrast, Band Boundary
  Strength, Near/Mid/Far Band Brightness, Tint Strength, Blend Strength.

Atmospheric Depth Cue
- Role: Adds far-depth haze, tinting, desaturation, depth-aware blur, and near
  clarity.
- Source color: previous layer sampler in split-stack, backbuffer in standalone.
- Depth use: smooth linearized far-depth window for atmospheric perspective.
- Fallback: If bufready_depth is false, returns the input color unchanged.
- Main controls: Fog Start Depth, Fog End Depth, Fog Strength, Fog Tint Color, Far
  Desaturation, Near Clarity Boost, Blend Strength.

Operational relationship with the split pipeline
------------------------------------------------
- SplitScreenController_new.fx owns the branch passes and final composition.
- SplitStackEffects_new.fxh maps slot ids to ApplyFromSampler(...) calls.
- Depth-aware append shaders provide those ApplyFromSampler(...) functions.
- AppendShared wrappers include append shaders in library mode for controller use.
- The four assistive depth shaders share DepthDistanceCommon.fxh for depth helpers.

Citation and report relationship
--------------------------------
The README documents code structure. Academic references and method citations are
kept in the final LaTeX report and bibliography. In the report, these depth shaders
are described as ReShade depth-buffer, screen-space effects rather than true
geometry-aware rendering.

Path note
---------
All paths in this README are relative to the Custom folder or to the
reshade-shaders folder. Do not add machine-specific absolute paths to README files.