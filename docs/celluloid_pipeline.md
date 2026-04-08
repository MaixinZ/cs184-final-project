# Celluloid Pipeline Adaptation

## Current project constraints

This project currently supports:

- one input image texture
- one fullscreen quad
- one GLSL program at a time
- offline export to `.ppm`

This project does not yet support:

- 3D meshes
- GBuffer outputs
- world/view-space normals from geometry
- shadow maps
- shell outlines
- material IDs
- multi-pass post chains

## Pruned implementation target

The original prompt describes a full 3D NPR render architecture. In this repo, `celluloid` is implemented as a **single-pass image-space stylization shader** that approximates the intended look using the source image as the only input.

Supported style layers:

- grouped cel-like tonal bands
- warm/cool lit-shadow separation
- stylized thresholded specular accents
- contour-biased rim lighting
- screen-space internal contour detection
- atmosphere-like contrast flattening
- band-preserving tonemap
- debug views for shading signals

Approximated with image-space proxies:

- `NdotL` is derived from a pseudo normal reconstructed from luminance gradients
- shadow grouping is driven by the cel signal plus local cavity/detail masks
- atmospheric perspective is driven by local detail density and screen position, not true depth
- outlines are derived from luminance/chroma discontinuities, not geometry shells

Not supported yet:

- true cast-shadow integration
- per-material region masks
- hero shell outlines
- height fog from world coordinates
- material archetype presets as separate runtime assets

## Shader split

- `shaders/celluloid.vert`
  - passthrough fullscreen vertex stage
- `shaders/celluloid.frag`
  - modular image-space NPR pass

Key fragment modules:

- `evalCelBand`
- `evalCelDiffuse`
- `evalStylizedShadow`
- `evalAmbientHemisphere`
- `evalStylizedSpecular`
- `evalRimLight`
- `evalOutlineFromDepthNormal`
- `applyAtmosphericPerspective`
- `applyBandPreservingTonemap`

## Runtime controls

The app now defaults to:

- `shaders/celluloid.vert`
- `shaders/celluloid.frag`

Optional CLI overrides:

- `--vert path/to/shader.vert`
- `--frag path/to/shader.frag`
- `--debug final|ndotl|band|shadow|rim|outline|fog`

## Intended next upgrade path

To move closer to the original full prompt:

1. replace image-space pseudo normals with geometry normals
2. add a real geometry pass and GBuffer
3. move cel lighting into a dedicated lighting pass
4. add shadow map sampling as a graphic band selector
5. combine shell outlines with screen-space outlines
6. drive fog with linear depth instead of local-detail heuristics
