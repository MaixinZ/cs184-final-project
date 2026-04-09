# Black-Ink Pipeline Adaptation

## Current project constraints

This project currently supports:

- one source texture for the full scene image
- one fullscreen quad
- one fragment shader pass at a time
- one debug uniform for intermediate visualization
- offline `.ppm` export

This project does not yet support:

- real geometry / feature buffers
- world/view-space normals from meshes
- depth, material ID, or object ID buffers
- true cast-shadow maps
- multi-pass tone / hatch compositing
- artist-authored ink masks as separate textures

## Pruned implementation target

The original prompt describes a full 3D manga NPR architecture. In this repo, `black-ink` is implemented as a **single image-space monochrome ink shader** with explicit logical stages:

1. scene sampling and feature proxies
2. form classification from pseudo normals and luma structure
3. silhouette / crease / contact line extraction
4. black-mass and screentone classification
5. hatch and cross-hatch pattern generation
6. ink compositing on white paper
7. paper / print finish

## What is real vs. approximated

Real in this repo:

- white paper base with black ink compositing
- silhouette-like contour masks
- internal structure line masks
- contact-edge-like dark accents
- discrete shadow classes
- black fill regions
- screentone dots and hatch / cross-hatch patterns
- final ink coverage debug

Approximated in image space:

- silhouette and crease logic from alpha and luma gradients
- pseudo normals from image gradients instead of geometry normals
- shadow classification from pseudo light-facingness, local darkness, and cavity proxies
- material mark language inferred from local detail / saturation, not real material IDs
- distance simplification inferred from local detail density, not true depth

## Shader split

- `shaders/black-ink.vert`
  - passthrough fullscreen vertex stage
- `shaders/black-ink.frag`
  - image-space monochrome manga ink pipeline

## Key fragment modules

- `evalViewSilhouette`
- `evalCreaseLine`
- `evalContactEdge`
- `evalLinePriority`
- `classifyShadowRegion`
- `evalBlackFillMask`
- `evalScreentoneMask`
- `evalHatchPattern`
- `evalCrossHatchPattern`
- `compositeInkLayers`
- `applyPaperAndPrintFinish`

## Debug views

Relevant debug modes for this style:

- `silhouette`
- `internal-edge`
- `contact-edge`
- `shadow`
- `black-fill`
- `screentone`
- `hatch-dir`
- `line-priority`
- `ink-coverage`

## Intended next upgrade path

To move closer to the original full prompt:

1. add true geometry-space silhouette and crease extraction
2. add real material / object / depth buffers
3. split black masses, screentone, and line art into separate passes
4. support author masks for emphasis lines and reserve white
5. use real shadow maps as black-mass shape sources
