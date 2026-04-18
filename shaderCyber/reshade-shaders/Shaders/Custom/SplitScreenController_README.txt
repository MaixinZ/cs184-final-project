SplitScreenController
=====================

Location
--------
- Shader file: Custom\SplitScreenController.fx
- Shared branch wrappers: Custom\SplitStackEffects.fxh
- Standalone custom effects now also live under Custom\

What changed
------------
This version keeps the existing mask system:
- Vertical Split
- Drawn Stroke

But the branch system is no longer one effect per side.
It is now:
- Split Stack A: 8 slots
- Split Stack B: 8 slots

Each side starts from the original backbuffer color and then applies its slots in order.

Available slot effects
----------------------
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

How to enable it
----------------
1. Launch Cyberpunk 2077 with ReShade enabled.
2. Open the ReShade overlay.
3. Search for "SplitScreenController".
4. Enable the "SplitScreenController" technique from Custom\SplitScreenController.fx.

Core controls
-------------
- Mask Mode
  - Vertical Split: fixed fallback split
  - Drawn Stroke: uses the captured stroke-driven region mask
- Split Position
  - Position for the fixed vertical split mode
- Split Stack A / Split Stack B
  - Each side now has Slot 1 through Slot 8
  - Slots are evaluated in order
  - Use None for unused slots
- Invert Drawn Region
- Show Boundary
- Show Debug Mask
- Arm Stroke Capture

Suggested usage
---------------
- If you want one effect on each side:
  - Put it in Slot 1 for A
  - Put it in Slot 1 for B
  - Leave the remaining slots as None

- If you want stacked stylization:
  - Example A:
    - Slot 1 = Oil Paint
    - Slot 2 = Depth Layered Painterly
  - Example B:
    - Slot 1 = Celluloid
    - Slot 2 = Depth Outline Overlay

- For a comic-style side:
  - Slot 1 = Black Ink
  - Slot 2 = Depth Screentone Overlay

Drawn-stroke workflow
---------------------
1. Set Mask Mode to Drawn Stroke.
2. Enable Arm Stroke Capture in the ReShade UI.
3. Press and hold the left mouse button to begin drawing.
4. Move the mouse while holding the button.
5. Release the left mouse button to finish.
6. The controller then closes the contour and uses it as the region mask.

Boundary behavior
-----------------
- While drawing:
  - open stroke preview is silver
  - cursor glow is silver
- After release:
  - the resolved closed boundary becomes gold
  - the gold boundary fades out over one second
  - the split regions stay active

Important implementation note
-----------------------------
This stays inside pure ReShade FX.

That means the slot system is implemented as branch-wrapper logic inside the controller.
It does not directly call external ReShade techniques as functions, because ReShade effects
do not support technique-to-technique calls.

Practical result:
- the selected custom effects are available in the split controller
- the same effects can still be enabled standalone from their own Custom\*.fx files

Custom folder contents
----------------------
The custom effects were moved into:
- Shaders\Custom\

ReShade.fxh and ReShadeUI.fxh remain one level above in:
- Shaders\

So custom files now include them via:
- #include "../ReShade.fxh"

