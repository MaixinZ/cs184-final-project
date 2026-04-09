# Black-Ink Style Memory

Canonical style name:

- `black-ink`

Alias note:

- `black-int` appeared in chat as a typo; it refers to `black-ink`

Source shaders:

- `shaders/black-ink.vert`
- `shaders/black-ink.frag`

## 1. Support Constraint

This project currently supports:

- one source texture for the full frame
- one fullscreen quad and one fragment pass at a time
- image-space pseudo-form classification from luma and alpha structure
- monochrome paper/ink compositing
- screentone dots, hatch, and cross-hatch pattern generation
- debug views for `silhouette`, `internal-edge`, `contact-edge`, `shadow`, `black-fill`, `screentone`, `hatch-dir`, `line-priority`, and `ink-coverage`
- GUI split compare and offline `.ppm` export
- style selection through `./viewer -s black-ink`

This project does not yet support:

- real geometry / feature buffers
- world/view-space normals, linear depth, material ID, or object ID buffers
- true cast-shadow maps
- multi-pass line, black-mass, screentone, and hatch compositing
- authored ink masks, reserve-white masks, or UV-anchored tone sheets
- geometry shell outlines or curvature-aware crease extraction

## 2. GLSL Render Pipeline

Ordered stages in `shaders/black-ink.frag`:

1. sample source color and compute small, medium, and large local blurs
2. reconstruct luma gradient, alpha gradient, alpha neighborhood range, and pseudo normal
3. estimate light-facingness from pseudo normal plus local luminance structure
4. extract silhouette, crease, and contact-line candidates
5. classify a coarse shadow region from light-facingness, darkness, and cavity proxy
6. collapse deeper shadow/contact structures into black fill regions
7. generate screentone coverage using dots, hatch, and cross-hatch
8. compute line priority and reserve-white behavior
9. composite black fill, screentone, and line work into a single ink coverage value
10. place the result onto white paper and apply a restrained print finish
11. branch to debug views when `uDebugMode` requests an intermediate signal

Bypass mode:

- if `uShadeEnabled == 0`, the shader returns the original texture unchanged

## 3. Remarkable Parameter

Black-ink-specific uniform defaults set in `configureStyleUniforms()`:

- `uLightDir = (-0.28, 0.18, 0.94)`
- `uShadowThreshold = 0.28`
- `uMidThreshold = 0.46`
- `uHighlightThreshold = 0.70`
- `uOutlineThreshold = 0.10`

Important hardcoded ink-composition parameters inside `shaders/black-ink.frag`:

- silhouette alpha shell: `smoothstep(0.03, 0.34, alphaRange)`
- silhouette alpha-edge sensitivity: `smoothstep(0.01, 0.16, length(alphaGradient))`
- black fill formation: `smoothstep(0.58, 0.82, blackSeed)`
- silhouette ink weighting: `mix(0.88, 1.00, linePriority)`
- crease ink weighting: `mix(0.42, 0.84, linePriority)`
- contact ink weighting: `mix(0.72, 0.96, linePriority)`
- tone coverage shaping: `smoothstep(0.18, 0.70, screentoneMask) * 0.84`
- paper base: `paperTone = 0.985 + paperNoise * 0.012`
- print darkening: `inkSpread = smoothstep(0.58, 0.95, inkCoverage) * 0.08`

Interpretation:

- `uOutlineThreshold` is especially important because it affects whether line work reads as intentional ink or disappears into the source image
- the silhouette logic now depends on both local alpha change and neighbor alpha range so the contour can survive beyond a 1-pixel antialias fringe

## 4. Notable Failure And Later Solution

Failure 1:

- the early `black-ink` result produced pale contours and a washed paper base

Root cause:

- it reused generic stylization defaults and applied a soft paper mix that lifted dark ink back toward gray

Later solution:

- add style-specific defaults in `configureStyleUniforms()`
- harden black-fill and line coverage in `compositeInkLayers()`
- brighten the paper base while removing the extra grayish remap in `applyPaperAndPrintFinish()`

Failure 2:

- the silhouette mask did not cover the full outer contour, especially when alpha went quickly from antialiased edge to fully opaque interior

Root cause:

- contour detection relied too heavily on narrow `alphaGradient` behavior, so only the fringe pixels counted as silhouette

Later solution:

- extend `evalViewSilhouette()` to use neighbor `alphaRange` as an `alphaShell`
- add `broadContrast` as a fallback contour cue for edges that are visually strong but not alpha-rich

## 5. Intended Next Upgrade Path

If a ReShade-like framework exposes depth and normal:

1. replace pseudo normals with real normals for stable light-facingness and hatch orientation
2. replace alpha/luma silhouette logic with depth/normal contour logic
3. derive contact lines from depth compression and AO-like depth neighborhoods instead of luma-only cavity proxies
4. use linear depth to thin internal lines and simplify background tone with distance
5. use depth-aware dilation so silhouette shells remain stable without overgrowing across gaps

If a full engine-side GBuffer is available:

1. implement geometry-space silhouette and crease extraction from normal, curvature, and object IDs
2. use shadow maps and AO as shape sources for black masses rather than as grayscale attenuation
3. split line art, black fill, screentone, hatch, and print finish into separate passes
4. anchor screentone in UV or object space for moving characters and reserve screen-space tone only for deliberate print-layout effects
5. support per-material ink languages such as sparse cloth hatch, technical metal hatch, and bold hair black-fill groupings
6. add authored reserve-white masks and focal-line masks for faces, hands, and hero props

## 6. Style Academic Description

`black-ink` is a monochrome comic-graphics abstraction pipeline. It translates form into a hierarchy of ink decisions: contour, structural line, contact accent, black mass, patterned tone, and reserve white. The intended reading is that of manga or line-art print design rather than grayscale realism.

Academically, it belongs to non-photorealistic rendering for graphic comics and print-like mark-making. In the current repo it is an image-space surrogate for a much richer manga NPR architecture; it approximates contour and shadow semantics from luma and alpha rather than from true geometric features.
