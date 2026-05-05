SplitScreenController_new
=========================

Purpose
-------
SplitScreenController_new is the current project controller for region-aware
real-time stylization. It combines two contributions:

1. A split-screen mask system with two modes:
   - Vertical Split
   - Drawn Stroke

2. A multi-shader branch pipeline:
   - Split Stack A: 8 ordered slots
   - Split Stack B: 8 ordered slots

Each branch starts from the original ReShade backbuffer and applies its selected
slots in order. The final image composites branch A and branch B through the chosen
region mask.

Location
--------
- Current controller: SplitScreenController_new.fx
- Current dispatch file: SplitStackEffects_new.fxh
- Append library wrappers: AppendShared/*.fxh
- Standalone and append project shaders: *.fx in this Custom folder

Legacy note
-----------
SplitScreenController.fx and SplitStackEffects.fxh are older compatibility files.
The report pipeline and current multi-shader system should refer to
SplitScreenController_new.fx and SplitStackEffects_new.fxh.

Contribution boundary for slot labels
-------------------------------------
The slot list contains both final project shaders and retained helper stages.
Painter is a pre-existing retained effect, not one of the final project-authored
shaders. Depth Fog Stylization, Depth Layered Painterly, Depth Outline Overlay,
and Depth Screentone Overlay are earlier exploratory depth stages. They remain in
the controller for comparison and compatibility, while the report's final depth
family is Myopia Blur, Hyperopia Blur, Silver Depth Edge, Near Bright Far Dark,
Depth Band Assist, and Atmospheric Depth Cue.

Available slot effects
----------------------
The current new controller exposes these exact slot labels:
- None
- Oil Paint
- Painter
- Celluloid
- Black Ink
- Pixel Art
- Myopia Blur
- Hyperopia Blur
- Depth Probe
- RedGreen Assist
- Depth Fog Stylization
- Depth Layered Painterly
- Depth Outline Overlay
- Depth Screentone Overlay
- Silver Depth Edge
- Near Bright Far Dark
- Depth Band Assist
- Atmospheric Depth Cue

Main project shader contribution
--------------------------------
The five main project stylization shaders are:
- Oil Paint
- RedGreen Assist
- Black Ink
- Celluloid
- Pixel Art

They are project-authored screen-space shaders. Each has a standalone ReShade
technique and an append-stage implementation used by the split pipeline.

Depth shader contribution
-------------------------
The six project depth-aware shaders are:
- Myopia Blur
- Hyperopia Blur
- Silver Depth Edge
- Near Bright Far Dark
- Depth Band Assist
- Atmospheric Depth Cue

They use ReShade linearized depth as a scene-aware control signal. They do not use
true geometry, true normals, material IDs, or lighting buffers.

How to enable the controller
----------------------------
1. Launch the game with ReShade enabled.
2. Open the ReShade overlay.
3. Enable the SplitScreenController_new technique from this Custom folder.
4. Choose Mask Mode and fill Split Stack A / Split Stack B slots.

Core controls
-------------
- Mask Mode
  - Vertical Split: fixed split using Split Position.
  - Drawn Stroke: interactive contour region from captured mouse stroke.
- Split Position
  - Screen-space split location for Vertical Split.
- Split Stack A / Split Stack B
  - Each branch has Slot 1 through Slot 8.
  - Slots are evaluated in order.
  - Use None for unused slots.
- Invert Drawn Region
  - Swaps inside and outside assignment for the drawn-stroke mask.
- Show Boundary
  - Displays the active split boundary.
- Show Debug Mask
  - Displays the generated region mask.
- Arm Stroke Capture
  - Enables interactive stroke capture.

Vertical split mode
-------------------
Vertical Split assigns one side of the screen to branch A and the other side to
branch B. It is intended for direct visual comparison between two shader pipelines.

Drawn-stroke mode
-----------------
Drawn Stroke records screen-space points, reconstructs a smooth contour from
overlapping quintic Bezier segments, automatically closes open strokes, and uses an
even-odd inside/outside test to generate a region mask.

Drawn-stroke workflow
---------------------
1. Set Mask Mode to Drawn Stroke.
2. Enable Arm Stroke Capture.
3. Hold the left mouse button and draw a curve.
4. Release the mouse button.
5. The controller closes the contour and uses it as the split mask.

Boundary behavior
-----------------
- While drawing, the open stroke preview is silver.
- After release, the resolved closed boundary becomes gold.
- The gold boundary fades out over one second.
- The split regions stay active after the boundary fade.

Multi-shader branch pipeline
----------------------------
The controller runs this pass order:
1. UpdateStrokePointsA
2. UpdateStrokeMetaA
3. CopyStrokePointsToB
4. CopyStrokeMetaToB
5. BuildContourMeta
6. BuildContourPoints
7. BuildRegionMask
8. BranchA_Slot1 through BranchA_Slot8
9. BranchB_Slot1 through BranchB_Slot8
10. Composite

Slot 1 reads ReShade::BackBuffer. Later slots alternate between ping and pong
render targets. Every slot calls SSB_ApplyEffect(...) in SplitStackEffects_new.fxh.
That function dispatches the selected label to the matching ApplyFromSampler(...)
shader function.

Operational relationship
------------------------
ReShade does not allow one technique to directly call another technique as a
function. The split pipeline therefore uses append shader functions instead:

- Standalone shader files can be enabled normally in the ReShade UI.
- Append shader files expose ApplyFromSampler(...) functions.
- AppendShared/*.fxh wrappers include those append files in library mode.
- SplitStackEffects_new.fxh dispatches the current slot id to the right function.
- SplitScreenController_new.fx stores intermediate branch outputs in ping-pong
  textures before compositing the two branches.

Suggested usage
---------------
One effect on each side:
- Branch A Slot 1 = Oil Paint
- Branch B Slot 1 = Celluloid
- Remaining slots = None

Stacked stylization:
- Branch A Slot 1 = Oil Paint
- Branch A Slot 2 = Silver Depth Edge
- Branch B Slot 1 = Celluloid
- Branch B Slot 2 = Near Bright Far Dark

Depth readability comparison:
- Branch A Slot 1 = Depth Band Assist
- Branch B Slot 1 = Atmospheric Depth Cue

Important path note
-------------------
All paths in this README are relative to the Custom folder or to the
reshade-shaders folder. Do not add machine-specific absolute paths to README files.