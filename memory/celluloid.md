# Celluloid Style Memory

Source shaders:

- `shaders/celluloid.vert`
- `shaders/celluloid.frag`

## 1. Support Constraint

This project currently supports:

- one source image texture for the full frame
- one fullscreen quad and one GLSL program at a time
- image-space pseudo-normal reconstruction from luminance gradients
- grouped cel-like light bands, stylized shadow, specular, rim, outline, and atmosphere proxies
- debug views for `ndotl`, `band`, `shadow`, `rim`, `outline`, and `fog`
- GUI split compare and offline `.ppm` export
- style selection through `./viewer -s celluloid`

This project does not yet support:

- true 3D meshes, geometry passes, or GBuffer outputs
- world/view-space normals from geometry
- cast-shadow maps or shell outlines
- material IDs, object IDs, or authored region masks
- multi-pass post chains
- world-space or height-based fog

## 2. GLSL Render Pipeline

Ordered stages in `shaders/celluloid.frag`:

1. sample source color and compute a locally smoothed region average
2. reconstruct a pseudo normal from multi-sample luminance gradients
3. derive a stylized shading signal from smoothed luminance and pseudo `NdotL`
4. quantize the signal into cel bands through `evalCelBand` and `evalBandIndex`
5. build warm/cool cel diffuse regions through `evalCelDiffuse`
6. estimate stylized shadow mass through `evalStylizedShadow`
7. add hemisphere ambient fill through `evalAmbientHemisphere`
8. add thresholded stylized specular through `evalStylizedSpecular`
9. add contour-biased rim lighting through `evalRimLight`
10. extract screen-space outline through `evalOutlineFromDepthNormal`
11. compress distant/detail-poor regions through `applyAtmosphericPerspective`
12. finalize with `applyBandPreservingTonemap`
13. branch to debug outputs when `uDebugMode` requests an intermediate signal

Bypass mode:

- if `uShadeEnabled == 0`, the shader returns the original texture unchanged

## 3. Remarkable Parameter

Primary style uniforms and current default values:

- `uLightDir = (-0.45, 0.35, 0.82)`
- `uShadowThreshold = 0.36`
- `uShadowSoftness = 0.06`
- `uMidThreshold = 0.58`
- `uHighlightThreshold = 0.82`
- `uSpecThreshold = 0.58`
- `uRimThreshold = 0.42`
- `uOutlineThreshold = 0.16`
- `uFogWeight = 0.55`

Important color presets:

- `uLightTint = (1.10, 1.03, 0.96)`
- `uMidTint = (0.92, 0.96, 1.00)`
- `uShadowTint = (0.68, 0.78, 0.96)`
- `uSpecColor = (1.00, 0.94, 0.84)`
- `uRimColor = (0.98, 0.90, 0.72)`
- `uOutlineColor = (0.19, 0.15, 0.18)`
- `uAtmosphereColor = (0.74, 0.82, 0.92)`

Interpretation:

- `uShadowThreshold`, `uMidThreshold`, and `uHighlightThreshold` define the band structure
- `uOutlineThreshold` controls how easily luminance/chroma discontinuities become line work
- `uFogWeight` determines how strongly detail-poor regions are flattened toward atmosphere

## 4. Notable Failure And Later Solution

Primary implementation failure:

- the original art prompt assumed a full 3D cel pipeline with normals, depth, shadow maps, shell outlines, and material control, but this repo only had a single image input and a fullscreen pass

Later solution:

- the style was explicitly pruned into an image-space NPR approximation built from pseudo normals, detail-derived cavity proxies, luma/chroma outlines, and atmosphere proxies

Secondary failure mode:

- a naive single-pass toon shader in this environment would collapse into plain posterization or black-outline filtering

Current solution:

- the shader separates cel diffuse, stylized shadow, ambient fill, specular, rim, outline, fog, and tonemapping into modular functions so the look remains layered rather than becoming a single thresholded filter

## 5. Intended Next Upgrade Path

If a ReShade-like framework exposes depth and normal:

1. replace pseudo normals from luminance gradients with true normals
2. replace detail-based fog with linear-depth atmospheric compression
3. compute outline from depth and normal discontinuity rather than color discontinuity
4. use actual view-facingness for more stable rim placement
5. allow shadow band selection to respond to real directional light instead of color-derived proxies

If a full engine-side GBuffer is available:

1. implement a geometry pass for albedo, normal, depth, material ID, and AO
2. move cel lighting into a dedicated stylized lighting pass
3. integrate shadow maps as graphic band selectors rather than gray attenuation
4. add shell-outline rendering for hero assets and preserve screen-space outline for environment detail
5. add per-material presets for skin, cloth, hair, metal, foliage, and rock
6. drive fog and distance simplification from real linear depth and height fields

## 6. Style Academic Description

`celluloid` is an image-space approximation of cel-shaded non-photorealistic rendering. It uses grouped tonal bands, hue-separated lit and shadow regions, stylized highlight placement, rim accents, and contour enhancement to simulate the visual logic of hand-authored animation cels and stylized 3D NPR lighting.

Academically, it sits between toon shading and illustrative deferred rendering. In the current repo it is not a true deferred NPR implementation; it is a proxy-based image-space reconstruction of cel rendering principles under severe input constraints.
