CS284A Cyberpunk ReShade Shader Project
=======================================

Purpose
-------
This folder contains the ReShade FX implementation for a CS284A final project on
real-time, region-aware stylization in Cyberpunk 2077. The project contribution is
not a single filter: it is a project-authored shader family plus a split-screen
multi-shader branch pipeline that lets two independently ordered stylization stacks
run on different screen regions in real time.

All project files described below use relative paths from this reshade-shaders
folder. README files should not contain machine-specific absolute paths.

Folder layout
-------------
- Shaders/Custom/
  - Project shaders, split controllers, auxiliary stages, and legacy files.
- Shaders/Custom/AppendShared/
  - Library-mode wrappers used by the split pipeline.
- Shaders/ReShade.fxh
  - ReShade-provided include file required by the current custom shaders.
- Shaders/ReShadeUI.fxh
  - ReShade-provided UI helper used by some stock effects; not directly required
    by the current Custom pipeline unless future shaders include it.

Ownership and contribution boundary
-----------------------------------
The Custom folder contains final project contributions, retained existing effects,
and earlier exploratory stages. They should not all be described as the same kind
of contribution.

Final project-authored contribution:
- Five main stylization shaders: Oil Paint, Red-green Color Assistance, Black Ink,
  Celluloid, and Pixel Art.
- Six depth-aware shaders: Myopia Depth Blur, Hyperopia Depth Blur, Silver Depth
  Edge, Near Bright Far Dark, Depth Band Assist, and Atmospheric Depth Cue.
- Region-aware split system: SplitScreenController_new.fx,
  SplitStackEffects_new.fxh, the AppendShared wrappers needed by the new branch
  pipeline, and the README documentation.

Required external ReShade runtime file:
- Shaders/ReShade.fxh is provided by ReShade, not authored by the project, but it
  is required because the custom shaders include it through ../ReShade.fxh.

Pre-existing / retained non-contribution effect:
- Painter is kept as a selectable slot in the new controller, but it is not one of
  the final project-authored shaders. The related files are painter.fx,
  painter_append.fx, and AppendShared/painter_append_shared.fxh.

Earlier exploratory depth stages:
- DepthFogStylization, DepthLayeredPainterly, DepthOutlineOverlay, and
  DepthScreentoneOverlay are earlier depth experiments retained for comparison and
  compatibility with the new controller's slot list.
- DepthCoordinateProbe is a debugging/helper stage for inspecting depth behavior.
- SplitScreenController.fx and SplitStackEffects.fxh are older controller files;
  the current report pipeline uses the _new versions.

Upload implication:
- For a full runnable upload of the current Custom folder, keep the retained and
  exploratory files because SplitStackEffects_new.fxh still includes their append
  wrappers and the controller exposes them as selectable slots.
- For a minimal final-contribution upload, remove those slot labels and includes
  first; otherwise the controller will reference missing files.

Main project stylization shaders
--------------------------------
These are the five main screen-space shaders described in the report. Each one is
project-authored and can be used as a standalone ReShade technique or as a split
pipeline stage through its append implementation.

1. Oil Paint
   - Standalone: Shaders/Custom/oilPaint.fx
   - Append stage: Shaders/Custom/oilPaint_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/oilPaint_append_shared.fxh
   - Technique names: OilPaint_UserControls, OilPaint_UserControls_Append
   - Split function: OilPaintAppend_ApplyFromSampler(...)
   - Role: bilateral-like smoothing, luminance-dependent color quantization, and
     procedural stroke texture.

2. Red-green Color Assistance
   - Standalone: Shaders/Custom/slider.fx
   - Append stage: Shaders/Custom/slider_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/slider_append_shared.fxh
   - Technique names: RedGreenAssist, RedGreenAssist_Append
   - Split function: SliderAppend_ApplyFromSampler(...)
   - Role: hue remapping that separates red-dominant and green-dominant regions
     while preserving brightness.

3. Black Ink
   - Standalone: Shaders/Custom/black-ink.fx
   - Append stage: Shaders/Custom/black-ink_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/black-ink_append_shared.fxh
   - Technique names: CS184_BlackInk, CS184_BlackInk_Append
   - Split function: BlackInkAppend_ApplyFromSampler(...)
   - Role: monochrome comic abstraction with silhouettes, creases, contact edges,
     black fills, screentone, hatching, and paper finish.

4. Celluloid
   - Standalone: Shaders/Custom/celluloid.fx
   - Append stage: Shaders/Custom/celluloid_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/celluloid_append_shared.fxh
   - Technique names: CS184_Celluloid, CS184_Celluloid_Append
   - Split function: CelluloidAppend_ApplyFromSampler(...)
   - Role: image-space cel shading with pseudo-normal lighting, banded tone,
     rim/specular accents, outlines, and atmospheric flattening.

5. Pixel Art
   - Standalone: Shaders/Custom/pixelArt.fx
   - Append stage: Shaders/Custom/pixelArt_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/pixelArt_append_shared.fxh
   - Technique names: PixelArt, PixelArt_Append
   - Split function: PixelArtAppend_ApplyFromSampler(...)
   - Role: screen-space pixel grid resampling, color quantization, and saturation
     boost.

Depth-aware project shaders
---------------------------
These six project-authored depth-aware shaders use ReShade linearized depth as a
scene-aware control signal. They do not use game geometry, material IDs, true
normals, or lighting buffers.

1. Myopia Depth Blur
   - Standalone: Shaders/Custom/MyopiaDepthBlur.fx
   - Append stage: Shaders/Custom/MyopiaDepthBlur_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/MyopiaDepthBlur_append_shared.fxh
   - Technique names: MyopiaDepthBlur, MyopiaDepthBlur_Append
   - Split function: MyopiaAppend_ApplyFromSampler(...)
   - Role: distant regions receive stronger depth-aware blur.

2. Hyperopia Depth Blur
   - Standalone: Shaders/Custom/HyperopiaDepthBlur.fx
   - Append stage: Shaders/Custom/HyperopiaDepthBlur_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/HyperopiaDepthBlur_append_shared.fxh
   - Technique names: HyperopiaDepthBlur, HyperopiaDepthBlur_Append
   - Split function: HyperopiaAppend_ApplyFromSampler(...)
   - Role: nearby regions receive stronger depth-aware blur.

3. Silver Depth Edge
   - Append stage: Shaders/Custom/SilverDepthEdge_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/SilverDepthEdge_append_shared.fxh
   - Technique name: SilverDepthEdge_Append
   - Split function: SDEAppend_ApplyFromSampler(...)
   - Role: silver or user-tinted outlines at depth discontinuities.

4. Near Bright Far Dark
   - Append stage: Shaders/Custom/NearBrightFarDark_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/NearBrightFarDark_append_shared.fxh
   - Technique name: NearBrightFarDark_Append
   - Split function: NBFDAppend_ApplyFromSampler(...)
   - Role: near-field brightening and far-field darkening while preserving hue.

5. Depth Band Assist
   - Append stage: Shaders/Custom/DepthBandAssist_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/DepthBandAssist_append_shared.fxh
   - Technique name: DepthBandAssist_Append
   - Split function: DBAAppend_ApplyFromSampler(...)
   - Role: quantizes depth into readable near, middle, and far visual bands.

6. Atmospheric Depth Cue
   - Append stage: Shaders/Custom/AtmosphericDepthCue_append.fx
   - Split wrapper: Shaders/Custom/AppendShared/AtmosphericDepthCue_append_shared.fxh
   - Technique name: AtmosphericDepthCue_Append
   - Split function: ADCAppend_ApplyFromSampler(...)
   - Role: far-depth haze, tinting, desaturation, depth-aware blur, and near
     clarity.

Split-screen contribution
-------------------------
The current report pipeline uses Shaders/Custom/SplitScreenController_new.fx. It
supports two region masks:

1. Vertical Split
   - Uses SplitPosition to divide the screen into branch A and branch B.
   - Useful for direct side-by-side comparison.

2. Drawn Stroke
   - Records a screen-space stroke, reconstructs it with overlapping quintic
     Bezier segments, closes the contour automatically, and converts it to a
     region mask with an even-odd inside/outside test.
   - Useful for curved, user-defined regions inspired by split-perspective game
     presentation.

Multi-shader branch pipeline
----------------------------
SplitScreenController_new evaluates two independent branches, A and B. Each branch
has eight GUI slots. Slot 1 reads the original ReShade backbuffer. Later slots read
the previous slot output through ping-pong render targets. The dispatch function is
SSB_ApplyEffect(...) in Shaders/Custom/SplitStackEffects_new.fxh.

Operational relationship:
- Standalone .fx files expose normal ReShade techniques.
- *_append.fx files expose both standalone append techniques and ApplyFromSampler
  functions.
- AppendShared/*.fxh wrappers include append shaders in library mode for the split
  pipeline, preventing duplicate technique registration inside the controller.
- SplitStackEffects_new.fxh calls the ApplyFromSampler(...) function selected by
  each branch slot.
- SplitScreenController_new.fx composites the final branch outputs with the chosen
  vertical or drawn-stroke mask.

Citation and ownership note
---------------------------
The code in Shaders/Custom/ is project-authored for this CS284A project. The final
paper cites the rendering ideas that inspired specific methods, such as bilateral
filtering for edge-preserving smoothing and non-photorealistic rendering work for
ink/cel stylization. ReShade itself provides the post-processing runtime, the
backbuffer/depth access, and common include files; the shader logic and split
pipeline described here are our implementation.

Related READMEs
---------------
- Shaders/Custom/SplitScreenController_README.txt
  - Details the current split-screen controller and multi-shader branch pipeline.
- Shaders/Custom/DepthAssistShaders_README.txt
  - Details the six depth-aware project shaders and their standalone/split roles.