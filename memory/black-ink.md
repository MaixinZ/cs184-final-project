# Black-Ink Style Memory

Canonical style name:

- `black-ink`

Alias note:

- `black-int` appeared in chat as a typo; it refers to `black-ink`

Source shaders:

- `shaders/black-ink.vert`
- `shaders/black-ink.frag`
- `fx/black-ink.fx`

## 1. Support Constraint

This project currently supports:

- one source texture for the viewer and one backbuffer-style color input for ReShade
- one fullscreen image-space pass per target
- pseudo-form classification from luminance, alpha, and multi-scale local blur
- monochrome paper/ink compositing
- screentone built from irregular clustered micro-dots, directional smudge, paper-driven erosion, hatch, and cross-hatch
- debug views for `light-facingness`, `silhouette`, `internal-edge`, `shadow`, `contact-edge`, `black-fill`, `screentone`, `hatch-dir`, `line-priority`, and `ink-coverage`
- viewer split compare plus shaded-only `16:9` `.ppm` export
- style selection through `./viewer -s black-ink`

This project does not yet support:

- real geometry feature buffers
- world/view-space normals, linear depth, material IDs, or object IDs
- true cast-shadow maps
- multi-pass line, black-mass, tone, and print compositing
- authored reserve-white masks or object-space tone anchoring
- shell outlines or curvature-aware crease extraction

## 2. GLSL Render Pipeline

Ordered stages shared in spirit by `shaders/black-ink.frag` and `fx/black-ink.fx`:

1. sample the source color and compute small, medium, and large local blurs
2. reconstruct a luminance gradient, alpha gradient, alpha neighborhood range, and pseudo normal
3. estimate light-facingness from pseudo normal plus local luminance structure
4. extract silhouette, crease, and contact-line candidates
5. classify a coarse shadow region from light-facingness, darkness, and cavity proxy
6. collapse deeper shadow and contact structures into black-fill regions
7. generate screentone using clustered micro-dots, directional smudge, paper-texture erosion, hatch, and cross-hatch
8. suppress screentone near strong line structure
9. compute line priority and reserve-white behavior
10. composite black fill, line work, and screentone into a single ink coverage value
11. place the result onto white paper and apply a restrained print finish
12. branch to debug outputs when a debug layer is requested

Current gradient note:

- the viewer shader still keeps a baked `kGradientMode` constant and currently defaults it to Sobel
- the current ReShade shader was later simplified and now fixes the gradient stage to Sobel directly

Current debug note:

- the viewer shader still uses `uDebugMode` IDs aligned with `constant.cpp`
- the current ReShade shader uses 10 independent debug toggles and mixes all enabled layers by averaging them

Bypass mode:

- if `uShadeEnabled == 0` in the viewer, the shader returns the original texture unchanged

## 3. Remarkable Parameter

Primary style defaults shared by the viewer and the ReShade adaptation:

- light direction: `(-0.28, 0.18, 0.94)`
- `ShadowThreshold = 0.28`
- `MidThreshold = 0.46`
- `HighlightThreshold = 0.70`
- `OutlineThreshold = 0.10`
- `ToneStrength = 1.0`
- `PaperWhiteness = 0.885`

Important black-ink constants in the viewer shader:

- `kGradientMode = 1`, so the active kernel is Sobel
- `kDotBoost = 1.15`
- `kDarkOutlineAssist = 0.38`
- dot spacing: `mix(3.8, 4.2, density)`
- micro-dot base radius: `mix(0.25, 0.42, density)`
- dot smudge strength: `mix(0.46, 0.82, density)`
- dot tone shaping: `smoothstep(0.44, 0.82, field)`
- screentone density seed: `saturate(shadowClass * 2.80)`
- final tone attenuation near strong lines: `1.0 - smoothstep(0.22, 0.55, linePriority) * 0.60`

Important latest ReShade simplification:

- `fx/black-ink.fx` no longer exposes `GradientMode`, `DotBoost`, or `DarkOutlineAssist`
- the current ReShade target fixes the gradient stage to Sobel and removes those extra boost/assist branches for a simpler UI and simpler control path

Interpretation:

- `OutlineThreshold` is the most sensitive style control because it gates silhouette, crease, and contact extraction
- the screentone is no longer a regular circle-dot halftone; it is intentionally closer to graphite or dry-media clustering
- the latest design intent favors a simpler ReShade parameter surface even though the viewer shader still retains a few baked enhancement constants

## 4. Notable Failure And Later Solution

Failure 1:

- the original art direction assumed a geometry-aware manga pipeline with real normals, depth, and richer line/black-mass passes, but the repository only had a single fullscreen image pass

Current solution:

- the implemented style is a framebuffer-only surrogate built from luma, alpha, multi-scale blur, and procedural tone synthesis

Failure 2:

- early dot tone behaved like regular circular halftone printing and read as mechanical rather than hand-drawn

Current solution:

- the dot stage was rebuilt as a combination of clustered micro-dots, directional smudge, and paper-texture-driven erosion

Failure 3:

- screentone darkened text edges and other strong line boundaries, creating unwanted black halos

Current solution:

- an explicit tone-edge suppression stage now damps screentone near strong silhouette, crease, and contact signals, and `compositeInkLayers()` applies a second line-priority attenuation as a final safety pass

Failure 4:

- the ReShade version accumulated too many small control branches for gradient mode, dot boosting, and dark-scene outline assist

Current solution:

- the current ReShade implementation prunes those branches, fixes the gradient stage to Sobel, and keeps the control surface smaller

## 5. Intended Next Upgrade Path

If ReShade exposes usable depth:

1. replace pseudo normals with normals reconstructed from depth
2. replace alpha/luma silhouette logic with depth/normal contour logic
3. derive contact lines from depth compression and AO-like depth neighborhoods instead of luma-only cavity proxies
4. replace `depthProxy` with real linear depth when weighting line priority
5. make black-fill grouping and screentone suppression aware of object boundaries and distance
6. drive hatch direction from projected geometry normals while preserving color cues only for interior material detail
7. keep alpha/luma fallback terms for depth-missing regions such as UI or sky

If a full engine-side GBuffer is available:

1. implement geometry-space silhouette and crease extraction from normals, curvature, and object IDs
2. use shadow maps and AO as shape sources for black masses rather than as grayscale attenuation
3. split line art, black fill, screentone, hatch, and print finish into separate passes
4. anchor screentone in UV or object space for moving characters and reserve screen-space tone only for deliberate print-layout effects
5. support per-material ink languages such as sparse cloth hatch, technical metal hatch, and bold hair black-fill groupings
6. add authored reserve-white masks and focal-line masks for faces, hands, and hero props

## 6. Style Academic Description

`black-ink` is a monochrome comic-graphics abstraction pipeline. It translates form into a hierarchy of ink decisions: contour, structural line, contact accent, black mass, patterned tone, and reserve white. The intended reading is that of manga or graphic print design rather than grayscale realism.

Academically, it belongs to non-photorealistic rendering for comic graphics and print-like mark-making. In the current repository it remains a framebuffer-only surrogate for a much richer manga NPR architecture; it approximates contour and shadow semantics from luminance, alpha, and procedural tone rather than from true geometric features.
