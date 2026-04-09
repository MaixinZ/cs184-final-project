# Light-Accent Pipeline Adaptation

## Current project constraints

This repo currently supports:

- one fullscreen quad
- one source texture as the scene input
- one fragment shader pass at a time
- offline `.ppm` export
- debug output routed through a single shader uniform

This repo does not yet support:

- separate base / lighting / edge / glow render targets
- sprite normal maps as dedicated buffers
- depth or layer buffers as real inputs
- object/material ID buffers
- signed distance fields as independent textures
- multi-pass bloom chains

## Pruned implementation target

The original prompt describes a layered accent pipeline. In this project, `light-accent` collapses that into a **single image-space shader with explicit logical stages**:

1. base scene sampling
2. pseudo light-facingness evaluation
3. silhouette / internal / emissive-adjacent edge extraction
4. asymmetric fake local contrast
5. narrow accent / glow composite
6. contrast-safe final grade

## What is real vs. approximated

Real in this repo:

- edge-conditioned highlight bands
- narrow emissive-adjacent accenting
- asymmetric positive/negative local contrast shaping
- final composite and grade
- debug views for the intermediate masks

Approximated in image space:

- `light-facingness` comes from luminance-gradient pseudo normals
- silhouette cues come from alpha and luma discontinuity rather than true geometry
- internal feature detection comes from luma/chroma gradients
- emissive adjacency is inferred from bright saturated pixels, not a dedicated emissive buffer
- local contrast uses blur-difference luma fields instead of a true layered pass graph

## Shader split

- `shaders/light-accent.vert`
  - passthrough fullscreen vertex stage
- `shaders/light-accent.frag`
  - modular post-lighting accent pipeline

## Fragment stages

- `evalLightFacingness`
- `evalSilhouetteEdge`
- `evalInternalEdge`
- `evalEmissiveAdjacency`
- `evalLocalHighPass`
- `applyFakeLocalContrast`
- `applyEdgeHighlightComposite`
- `applyNeonEdgeGlow`
- `applyFinalContrastSafeGrade`

## Debug views

The style supports:

- `ndotl`
- `silhouette`
- `internal-edge`
- `emissive-adj`
- `high-pass`
- `contrast-pos`
- `contrast-neg`
- `edge-contrib`
- `contrast-contrib`

## Intended next upgrade path

To move closer to the original full prompt:

1. add a real emissive mask input
2. add sprite alpha/SDF and layer/depth auxiliary buffers
3. split fake local contrast and edge accents into separate render passes
4. add material/category masks to gate composite behavior
5. promote pseudo normals to authored normals or normal maps
