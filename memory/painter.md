# Painter Style Memory

Source shaders:

- `shaders/painter.vert`
- `shaders/painter.frag`

## 1. Support Constraint

This project currently supports:

- one source image texture for the full frame
- one fullscreen quad and one GLSL program at a time
- GUI split compare via `uShadeEnabled`
- offline `.ppm` export
- style selection through `./viewer -s painter`

This project does not yet support:

- real 3D geometry, world/view normals, or linear depth
- GBuffer outputs or multi-pass deferred shading
- shadow maps or material/object IDs
- painter-specific debug views
- artist-authored brush masks, pigment maps, or paper maps as separate assets

## 2. GLSL Render Pipeline

Ordered stages in `shaders/painter.frag`:

1. sample the source color
2. compute a 9-tap local blur with center-heavy weighting
3. build a painterly tone by mixing source and blur
4. partially restore luminance structure, apply warm hue bias, apply a mild gamma lift, and posterize to 6 levels
5. estimate edge strength from local luminance differences
6. synthesize paper grain from procedural noise
7. composite the result onto warm paper with brown line accents and a restrained gold highlight accent
8. clamp and output

Bypass mode:

- if `uShadeEnabled == 0`, the shader returns the original texture unchanged

## 3. Remarkable Parameter

Important hardcoded parameters inside `shaders/painter.frag`:

- blur kernel: center weight `4.0`, eight neighbor samples, normalized by `12.0`
- painter blur mix: `mix(color, blur, 0.55)`
- grayscale reinjection: `mix(vec3(luma), painter, 0.88)`
- warm bias: `r *= 1.10`, `g *= 1.00`, `b *= 0.97`
- gamma shaping: `pow(painter, vec3(0.92))`
- posterization: `levels = 6.0`
- paper color: `vec3(0.95, 0.88, 0.74)`
- line color: `vec3(0.42, 0.28, 0.10)`
- line mask: `smoothstep(0.05, 0.16, edge)`
- gold accent: `smoothstep(0.10, 0.22, edge) * 0.35`

Important engineering note:

- these values are not currently exposed as uniforms; they are style-defining constants baked into the fragment shader

## 4. Notable Failure And Later Solution

Observed failure mode:

- a blur-only painter filter quickly collapses structure into mush and stops reading as intentional illustration

Current solution:

- the shader reintroduces structure through posterization, edge-driven line tinting, and paper-aware compositing rather than relying on blur alone

Engineering failure encountered earlier in the project:

- the original painter effect lived inline inside `main.cpp`, which made shader iteration, style switching, and reuse awkward

Later solution:

- the effect was externalized into `shaders/painter.vert` and `shaders/painter.frag`, and its internal logic was split into helper functions such as `sampleBlur`, `applyPainterTone`, `computeEdge`, `paperGrain`, and `compositePaper`

## 5. Intended Next Upgrade Path

If a ReShade-like framework exposes depth and normal:

1. replace color-only edge detection with normal/depth edge detection for cleaner contours
2. make the blur bilateral so forms are smoothed within objects but not across depth boundaries
3. modulate paper grain and wash intensity with depth or AO instead of applying them uniformly
4. use normal-facingness and depth layering to place painterly accents on forms rather than only on image contrast

If a full engine-side GBuffer is available:

1. separate base albedo abstraction from lighting abstraction
2. derive pigment pooling and contour emphasis from curvature, AO, and shadow regions
3. support per-material painterly presets such as canvas-like cloth, gouache-like skin, and metallic highlight glazing
4. move paper/grain/edge accents into distinct passes so line color, highlight accents, and paper finish can be tuned independently

## 6. Style Academic Description

`painter` is best described as a single-pass image-space painterly abstraction filter. It performs low-frequency color grouping, warm palette biasing, posterization, and paper-surface compositing to convert a photographic or rendered image into a stylized illustrative plate.

Academically, it belongs closer to non-photorealistic image abstraction and illustrative post-processing than to geometry-aware toon shading. Its emphasis is on surface treatment, color grouping, and decorative contour accent rather than on explicit 3D form classification.
