# Celluloid Style Memory

Source shaders:

- `shaders/celluloid.vert`
- `shaders/celluloid.frag`
- `fx/celluloid.fx`

## 1. Support Constraint

This project currently supports:

- one source image texture in the viewer and one backbuffer-style color input in ReShade
- one fullscreen quad and one image-space stylization pass per target
- pseudo-normal reconstruction from luminance gradients
- grouped cel bands, stylized shadow grouping, hemisphere ambient, thresholded specular, rim light, outline, and atmosphere proxy
- debug views for `ndotl`, `band`, `shadow`, `rim`, `outline`, and `fog`
- viewer split compare plus shaded-only `16:9` `.ppm` export
- style selection through `./viewer -s celluloid`

This project does not yet support:

- true 3D meshes, geometry passes, or GBuffer outputs
- world/view-space normals from geometry
- linear depth-driven fog or depth-driven outlines
- shell outlines, cast-shadow maps, or material/object IDs
- multi-pass NPR chains
- per-material cel tuning

## 2. GLSL Render Pipeline

Ordered stages shared by `shaders/celluloid.frag` and `fx/celluloid.fx`:

1. sample source color and compute a locally smoothed region average
2. estimate luminance gradients from the smoothed image
3. reconstruct a pseudo normal from the gradient field
4. derive a stylized shading signal from pseudo `NdotL` and smoothed luminance
5. quantize that signal into grouped cel bands through `evalCelBand` and `evalBandIndex`
6. build warm/cool cel diffuse regions through `evalCelDiffuse`
7. estimate a stylized shadow mass through `evalStylizedShadow`
8. add hemisphere ambient fill through `evalAmbientHemisphere`
9. add thresholded stylized specular through `evalStylizedSpecular`
10. extract outline from luminance and chroma discontinuity through `evalOutline`
11. add contour-aware rim lighting through `evalRimMask`
12. compress distant or detail-poor regions through `evalFogFactor` and `applyAtmosphere`
13. finalize with `applyBandPreservingTonemap`
14. branch to debug outputs when the requested debug layer is selected

Gradient-kernel note:

- the viewer shader keeps `kGradientMode = 1`, so it is effectively fixed to Sobel
- the ReShade shader still exposes `Celluloid_GradientMode` with `Central Difference / Sobel / Scharr`, defaulting to Sobel

Bypass mode:

- if `uShadeEnabled == 0` in the viewer, the shader returns the original texture unchanged

## 3. Remarkable Parameter

Primary style defaults shared by the viewer and the ReShade adaptation:

- light direction: `(-0.45, 0.35, 0.82)`
- `ShadowThreshold = 0.36`
- `ShadowSoftness = 0.06`
- `MidThreshold = 0.58`
- `HighlightThreshold = 0.82`
- `SpecThreshold = 0.58`
- `RimThreshold = 0.42`
- `OutlineThreshold = 0.16`
- `FogWeight = 0.55`

Important color presets:

- light tint: `(1.10, 1.03, 0.96)`
- mid tint: `(0.92, 0.96, 1.00)`
- shadow tint: `(0.68, 0.78, 0.96)`
- spec color: `(1.00, 0.94, 0.84)`
- rim color: `(0.98, 0.90, 0.72)`
- outline color: `(0.19, 0.15, 0.18)`
- atmosphere color: `(0.74, 0.82, 0.92)`

Key hardcoded structure:

- pseudo normal scale: `vec3(-lumaGradient * 3.2, 1.0)`
- outline signal: `length(lumaGradient) * 2.2 + length(baseColor - smoothColor) * 1.35`
- fog proxy: `smoothstep(0.18, 0.82, 1.0 - detailMask)` with a screen-space sky bias term

Interpretation:

- `ShadowThreshold`, `MidThreshold`, and `HighlightThreshold` define the band structure
- `OutlineThreshold` controls whether the result reads as cel contouring or simple posterization
- `FogWeight` remains a detail-based proxy rather than a real distance control because no depth path is wired yet

## 4. Notable Failure And Later Solution

Primary implementation failure:

- the original art direction assumed a full geometry-aware cel pipeline with true normals, depth, shadow maps, and shell outlines, but the repo only had a single fullscreen image pass

Current solution:

- the style was explicitly reduced to a framebuffer-only cel approximation built from pseudo normals, detail-derived cavity proxies, luma/chroma outlines, and atmosphere proxies

Secondary failure mode:

- a naive one-pass toon filter in this environment quickly collapses into simple posterization or saturation shifts, especially in low-detail regions

Current solution:

- the shader keeps diffuse bands, stylized shadow, ambient, specular, rim, outline, fog, and tonemapping as separate modules so the result stays layered rather than becoming a single threshold filter

Remaining limitation:

- low-saturation and dark scenes are still bounded by the quality of pseudo normals reconstructed from luminance, so the current implementation can lose shape stability when color contrast is weak

## 5. Intended Next Upgrade Path

If ReShade exposes usable depth:

1. replace pseudo normals from luminance gradients with normals reconstructed from depth
2. compute fog from linear depth instead of `detailMask`
3. split outline into depth discontinuity, normal discontinuity, and fallback color-edge terms
4. derive cavity and contact shadow proxies from depth neighborhoods instead of local contrast alone
5. stabilize rim placement with true view-facingness rather than pseudo normals
6. keep color-based edges only as a secondary cue for material/internal detail

If a full engine-side GBuffer is available:

1. implement a geometry pass for albedo, normal, depth, material ID, and AO
2. move cel lighting into a dedicated stylized lighting pass
3. integrate shadow maps as band selectors rather than as grayscale attenuation
4. add shell-outline rendering for hero assets while preserving screen-space outline for fine environment detail
5. support per-material presets for skin, cloth, hair, metal, foliage, and rock
6. move fog and atmospheric flattening to real linear depth and height fields

## 6. Style Academic Description

`celluloid` is an image-space approximation of cel-shaded non-photorealistic rendering. It groups illumination into discrete bands, separates lit and shadow color regions, adds stylized highlight and rim placement, and enhances contour structure to emulate the visual logic of hand-authored animation cels and stylized 3D NPR lighting.

Academically, it sits between toon shading and illustrative deferred rendering. In the current repository it is not a true deferred NPR pipeline; it is a framebuffer-only reconstruction of cel-rendering principles under severe input constraints.
