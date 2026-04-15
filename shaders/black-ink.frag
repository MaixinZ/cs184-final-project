#version 330 core

in vec2 uv;
out vec4 FragColor;

uniform sampler2D tex;
uniform int uDebugMode;
uniform int uShadeEnabled;

uniform vec3 uLightDir;
uniform vec3 uLightTint;
uniform vec3 uMidTint;
uniform vec3 uShadowTint;
uniform vec3 uSpecColor;
uniform vec3 uRimColor;
uniform vec3 uOutlineColor;
uniform vec3 uAtmosphereColor;

uniform float uShadowThreshold;
uniform float uShadowSoftness;
uniform float uMidThreshold;
uniform float uHighlightThreshold;
uniform float uSpecThreshold;
uniform float uRimThreshold;
uniform float uOutlineThreshold;
uniform float uFogWeight;

const int kGradientMode = 1; // 0: Central Difference, 1: Sobel, 2: Scharr
const float kToneStrength = 1.0;
const float kDotBoost = 1.15;
const float kDarkOutlineAssist = 0.38;
const float kPaperWhiteness = 0.885;

float saturate(float x)
{
    return clamp(x, 0.0, 1.0);
}

vec3 saturate(vec3 x)
{
    return clamp(x, vec3(0.0), vec3(1.0));
}

float luminance(vec3 color)
{
    return dot(color, vec3(0.299, 0.587, 0.114));
}

float saturationEstimate(vec3 color)
{
    float cMin = min(min(color.r, color.g), color.b);
    float cMax = max(max(color.r, color.g), color.b);
    return cMax - cMin;
}

mat2 rotation2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c);
}

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float valueNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 sampleCrossBlur(vec2 sampleUv, vec2 texel, float radius)
{
    vec2 dx = vec2(texel.x * radius, 0.0);
    vec2 dy = vec2(0.0, texel.y * radius);

    vec3 color = texture(tex, sampleUv).rgb * 4.0;
    color += texture(tex, sampleUv + dx).rgb;
    color += texture(tex, sampleUv - dx).rgb;
    color += texture(tex, sampleUv + dy).rgb;
    color += texture(tex, sampleUv - dy).rgb;
    color += texture(tex, sampleUv + dx + dy).rgb;
    color += texture(tex, sampleUv - dx - dy).rgb;
    color += texture(tex, sampleUv + dx - dy).rgb;
    color += texture(tex, sampleUv - dx + dy).rgb;
    return color / 12.0;
}

float sampleBlurredLuma(vec2 sampleUv, vec2 texel, float radius)
{
    return luminance(texture(tex, sampleUv).rgb);
}

vec2 evalCentralGradientField(vec2 sampleUv, vec2 texel, float radius)
{
    vec2 offset = texel * radius;
    float lL = sampleBlurredLuma(sampleUv - vec2(offset.x, 0.0), texel, radius);
    float lR = sampleBlurredLuma(sampleUv + vec2(offset.x, 0.0), texel, radius);
    float lU = sampleBlurredLuma(sampleUv + vec2(0.0, offset.y), texel, radius);
    float lD = sampleBlurredLuma(sampleUv - vec2(0.0, offset.y), texel, radius);
    return vec2(lR - lL, lU - lD);
}

vec2 evalSobelGradientField(vec2 sampleUv, vec2 texel, float radius)
{
    vec2 offset = texel * radius;

    float tl = sampleBlurredLuma(sampleUv + vec2(-offset.x, offset.y), texel, radius);
    float tc = sampleBlurredLuma(sampleUv + vec2(0.0, offset.y), texel, radius);
    float tr = sampleBlurredLuma(sampleUv + vec2(offset.x, offset.y), texel, radius);
    float ml = sampleBlurredLuma(sampleUv - vec2(offset.x, 0.0), texel, radius);
    float mr = sampleBlurredLuma(sampleUv + vec2(offset.x, 0.0), texel, radius);
    float bl = sampleBlurredLuma(sampleUv - vec2(offset.x, offset.y), texel, radius);
    float bc = sampleBlurredLuma(sampleUv - vec2(0.0, offset.y), texel, radius);
    float br = sampleBlurredLuma(sampleUv + vec2(offset.x, -offset.y), texel, radius);

    float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    float gy = (tl + 2.0 * tc + tr) - (bl + 2.0 * bc + br);
    return vec2(gx, gy) * 0.25;
}

vec2 evalScharrGradientField(vec2 sampleUv, vec2 texel, float radius)
{
    vec2 offset = texel * radius;

    float tl = sampleBlurredLuma(sampleUv + vec2(-offset.x, offset.y), texel, radius);
    float tc = sampleBlurredLuma(sampleUv + vec2(0.0, offset.y), texel, radius);
    float tr = sampleBlurredLuma(sampleUv + vec2(offset.x, offset.y), texel, radius);
    float ml = sampleBlurredLuma(sampleUv - vec2(offset.x, 0.0), texel, radius);
    float mr = sampleBlurredLuma(sampleUv + vec2(offset.x, 0.0), texel, radius);
    float bl = sampleBlurredLuma(sampleUv - vec2(offset.x, offset.y), texel, radius);
    float bc = sampleBlurredLuma(sampleUv - vec2(0.0, offset.y), texel, radius);
    float br = sampleBlurredLuma(sampleUv + vec2(offset.x, -offset.y), texel, radius);

    float gx = (3.0 * tr + 10.0 * mr + 3.0 * br) - (3.0 * tl + 10.0 * ml + 3.0 * bl);
    float gy = (3.0 * tl + 10.0 * tc + 3.0 * tr) - (3.0 * bl + 10.0 * bc + 3.0 * br);
    return vec2(gx, gy) * (1.0 / 16.0);
}

vec2 evalGradientField(vec2 sampleUv, vec2 texel, float radius)
{
    if (kGradientMode == 1) {
        return evalSobelGradientField(sampleUv, texel, radius);
    }
    if (kGradientMode == 2) {
        return evalScharrGradientField(sampleUv, texel, radius);
    }
    return evalCentralGradientField(sampleUv, texel, radius);
}

vec3 evalPseudoNormal(vec2 gradientField)
{
    return normalize(vec3(-gradientField * 3.0, 1.0));
}

float evalLightFacingness(vec3 pseudoNormal, vec3 lightDirValue, float lumaValue)
{
    float ndotl = max(dot(pseudoNormal, lightDirValue), 0.0);
    float broad = smoothstep(uShadowThreshold, uMidThreshold + 0.05, ndotl);
    float highlight = smoothstep(uMidThreshold, uHighlightThreshold + 0.05, ndotl);
    return saturate(mix(lumaValue, broad, 0.58) + highlight * 0.10);
}

float evalAlphaReliability(float alphaValue, float alphaRange, vec2 alphaGradient)
{
    float deviation = abs(alphaValue - 1.0);
    return saturate(alphaRange * 8.0 + length(alphaGradient) * 6.0 + deviation * 3.0);
}

float evalViewSilhouette(
    float alphaValue,
    float alphaRange,
    vec2 alphaGradient,
    vec2 lumaGradient,
    float broadContrast,
    float alphaReliability,
    float darkAssist
)
{
    float outlineThreshold = uOutlineThreshold * mix(1.0, 0.82, darkAssist);
    float alphaEdge = smoothstep(0.01, 0.16, length(alphaGradient));
    float alphaShell = smoothstep(0.03, 0.34, alphaRange) * smoothstep(0.01, 0.995, alphaValue);
    float lumaEdge = smoothstep(outlineThreshold * 0.48, outlineThreshold * 1.45, length(lumaGradient));
    float broadEdge = smoothstep(0.03, 0.16, broadContrast + darkAssist * 0.03);
    float alphaCue = max(alphaEdge, alphaShell) * mix(0.15, 0.95, alphaReliability);
    float lumaCue = max(lumaEdge * mix(0.78, 0.96, darkAssist), broadEdge * mix(0.48, 0.66, darkAssist));
    return saturate(max(alphaCue, lumaCue));
}

float evalCreaseLine(vec2 lumaGradient, vec3 baseColor, vec3 smallBlur, float detailMask, float darkAssist)
{
    float outlineThreshold = uOutlineThreshold * mix(1.0, 0.78, darkAssist);
    float lumaEdge = smoothstep(outlineThreshold * 0.44, outlineThreshold * 1.55, length(lumaGradient));
    float chromaEdge = smoothstep(0.03, 0.18, length(baseColor - smallBlur));
    return saturate((lumaEdge * mix(0.72, 0.88, darkAssist) + chromaEdge * 0.28) * mix(0.52, 1.0, detailMask));
}

float evalContactEdge(float cavityMask, vec2 lumaGradient, float shadowSignal, float darkAssist)
{
    float grounded = smoothstep(0.10, 0.34, cavityMask);
    float outlineThreshold = uOutlineThreshold * mix(1.0, 0.76, darkAssist);
    float compression = smoothstep(outlineThreshold * 0.38, outlineThreshold * 1.05, length(lumaGradient));
    return saturate(grounded * compression * mix(0.45, 1.0, shadowSignal));
}

float evalLinePriority(float silhouetteMask, float creaseMask, float contactMask, float detailMask, float depthProxy)
{
    float priority = silhouetteMask * 1.00 + creaseMask * 0.58 + contactMask * 0.82;
    priority *= mix(1.0, 0.68, depthProxy);
    priority *= mix(0.62, 1.0, detailMask);
    return saturate(priority);
}

float classifyShadowRegion(float lightFacingness, float lumaValue, float cavityMask)
{
    float shadowSignal = (1.0 - lightFacingness) * 0.68;
    shadowSignal += cavityMask * 0.34;
    shadowSignal += (1.0 - lumaValue) * 0.16;
    return saturate(shadowSignal);
}

float evalBlackFillMask(float shadowClass, float contactMask, float joinedDarkness)
{
    float blackSeed = shadowClass * 0.72 + contactMask * 0.58 + joinedDarkness * 0.34;
    return smoothstep(0.58, 0.82, blackSeed);
}

float evalPaperGrain(vec2 pixelPos, float angle)
{
    vec2 grainUv = rotation2D(angle * 0.18 + 0.31) * (pixelPos * vec2(0.18, 0.24));
    float coarse = valueNoise(grainUv);
    float mid = valueNoise(grainUv * 2.1 + vec2(13.7, 5.9));
    float fine = valueNoise(grainUv * 4.3 + vec2(21.1, 17.3));
    return saturate(coarse * 0.50 + mid * 0.34 + fine * 0.16);
}

float evalDirectionalSmudge(vec2 pixelPos, float angle)
{
    vec2 smudgeUv = rotation2D(angle) * pixelPos;
    float longStroke = valueNoise(smudgeUv * vec2(0.08, 0.34) + vec2(9.7, 3.1));
    float shortStroke = valueNoise(smudgeUv * vec2(0.17, 0.78) + vec2(17.3, 11.2));
    return saturate(longStroke * 0.62 + shortStroke * 0.38);
}

float evalMicroDotField(vec2 cell, vec2 center, float radius, float angle, float smudge, float seed)
{
    vec2 q = rotation2D(angle) * (cell - center);
    q.x /= mix(1.0, 1.75, smudge);
    q.y /= mix(1.0, 0.72, smudge);

    float edgeWarp = mix(0.84, 1.18, valueNoise(q * 5.5 + vec2(seed * 9.7, seed * 15.1)));
    float radial = dot(q, q) / max(radius * radius, 1e-4);
    radial *= edgeWarp;

    return exp(-radial * 1.6);
}

float evalDotTone(vec2 pixelPos, float density, float smudgeAngle)
{
    float spacing = mix(3.8, 4.2, density);
    vec2 rotated = rotation2D(0.48) * pixelPos;
    vec2 grid = rotated / spacing;
    vec2 cellId = floor(grid);
    vec2 cell = fract(grid) - 0.5;

    float seed0 = hash12(cellId + vec2(1.3, 2.1));
    float seed1 = hash12(cellId + vec2(4.7, 0.9));
    float seed2 = hash12(cellId + vec2(8.2, 6.4));

    vec2 center0 = (hash22(cellId + vec2(1.7, 3.2)) - 0.5) * vec2(0.62, 0.34);
    vec2 center1 = (hash22(cellId + vec2(5.4, 1.6)) - 0.5) * vec2(0.56, 0.30);
    vec2 center2 = (hash22(cellId + vec2(9.1, 7.5)) - 0.5) * vec2(0.48, 0.26);

    float smudge = mix(0.46, 0.82, density);
    float localAngle = smudgeAngle + mix(-0.35, 0.35, hash12(cellId + vec2(2.9, 4.4)));
    float baseRadius = mix(0.25, 0.42, density);

    float field = 0.0;
    field += evalMicroDotField(cell, center0, baseRadius * mix(0.90, 1.20, seed0), localAngle, smudge, seed0);
    field += evalMicroDotField(cell, center1, baseRadius * mix(0.70, 1.05, seed1), localAngle, smudge, seed1) * 0.92;
    field += evalMicroDotField(cell, center2, baseRadius * mix(0.58, 0.92, seed2), localAngle, smudge, seed2) * 0.84;

    float paperNoise = evalPaperGrain(pixelPos, localAngle);
    float smudgeNoise = evalDirectionalSmudge(pixelPos, smudgeAngle);

    field += (smudgeNoise - 0.5) * mix(0.12, 0.28, density);
    field -= (1.0 - paperNoise) * mix(0.26, 0.12, density);

    float tone = smoothstep(0.44, 0.82, field);
    tone *= smoothstep(0.18, 0.88, paperNoise + density * 0.42);
    return saturate(tone);
}

float evalHatchPattern(vec2 pixelPos, float density, float angle)
{
    vec2 rotated = rotation2D(angle) * pixelPos;
    float stripe = abs(fract(rotated.x / 8.0) - 0.5);
    float thickness = mix(0.46, 0.14, density);
    return 1.0 - smoothstep(thickness, thickness + 0.06, stripe);
}

float evalCrossHatchPattern(vec2 pixelPos, float density, float angle)
{
    vec2 rotated = rotation2D(angle + 1.5707963) * pixelPos;
    float stripe = abs(fract(rotated.x / 8.0) - 0.5);
    float thickness = mix(0.48, 0.16, density);
    return 1.0 - smoothstep(thickness, thickness + 0.06, stripe);
}

float evalScreentoneMask(
    float shadowClass,
    float blackFillMask,
    float materialStyle,
    vec2 pixelPos,
    float hatchAngle,
    out float hatchDirectionDebug
)
{
    float mildTone = smoothstep(0.22, 0.44, shadowClass) * (1.0 - smoothstep(0.58, 0.74, shadowClass));
    float denseTone = smoothstep(0.46, 0.70, shadowClass) * (1.0 - blackFillMask);

    float dotDensity = saturate(shadowClass * 2.80);
    float hatchDensity = saturate((shadowClass - 0.20) * 1.35);
    float crossDensity = saturate((shadowClass - 0.48) * 2.00);

    float dots = evalDotTone(pixelPos, dotDensity, hatchAngle);
    dots = saturate(dots * kDotBoost);
    float hatch = evalHatchPattern(pixelPos, hatchDensity, hatchAngle);
    float cross = evalCrossHatchPattern(pixelPos, crossDensity, hatchAngle);

    hatchDirectionDebug = fract(hatchAngle / 6.2831853);

    float tone = mix(dots * mildTone, hatch * denseTone, saturate(materialStyle * 0.92));
    tone = max(tone, cross * denseTone * smoothstep(0.62, 0.82, shadowClass));
    return saturate(tone * (1.0 - blackFillMask) * kToneStrength);
}

float evalToneEdgeSuppression(float silhouetteMask, float creaseMask, float contactMask, float linePriority)
{
    float edgeSuppress = smoothstep(0.14, 0.42, max(max(silhouetteMask, creaseMask), contactMask));
    float prioritySuppress = smoothstep(0.18, 0.52, linePriority);
    return saturate(max(edgeSuppress * 0.85, prioritySuppress * 0.70));
}

vec3 compositeInkLayers(
    float blackFillMask,
    float screentoneMask,
    float silhouetteMask,
    float creaseMask,
    float contactMask,
    float linePriority,
    float reserveWhite,
    out float inkCoverage
)
{
    float silhouetteInk = smoothstep(0.08, 0.52, silhouetteMask) * mix(0.88, 1.00, linePriority);
    float creaseInk = smoothstep(0.12, 0.66, creaseMask) * mix(0.42, 0.84, linePriority);
    float contactInk = smoothstep(0.10, 0.58, contactMask) * mix(0.72, 0.96, linePriority);

    float lineInk = saturate(max(max(silhouetteInk, creaseInk), contactInk));
    float blackCoverage = smoothstep(0.36, 0.82, blackFillMask * (1.0 - reserveWhite));
    float toneCoverage = smoothstep(0.18, 0.70, screentoneMask) * 0.84;
    toneCoverage *= 1.0 - smoothstep(0.22, 0.55, linePriority) * 0.60;
    float coverage = max(blackCoverage, max(toneCoverage, lineInk));
    coverage = max(coverage, silhouetteMask * 0.90);
    inkCoverage = saturate(coverage);

    return mix(vec3(1.0), vec3(0.0), inkCoverage);
}

vec3 applyPaperAndPrintFinish(vec3 inkColor, float inkCoverage, vec2 pixelPos)
{
    float paperNoise = fract(sin(dot(pixelPos * vec2(0.91, 1.07), vec2(12.9898, 78.233))) * 43758.5453);
    float paperTone = kPaperWhiteness + paperNoise * 0.012;
    vec3 paperTint = vec3(paperTone);

    vec3 result = min(inkColor, paperTint);
    float inkSpread = smoothstep(0.58, 0.95, inkCoverage) * 0.08;
    result = mix(result, vec3(0.0), inkSpread);
    return saturate(result);
}

void main()
{
    vec2 texSize = vec2(textureSize(tex, 0));
    vec2 texel = 1.0 / texSize;
    vec2 pixelPos = uv * texSize;

    vec4 baseSample = texture(tex, uv);
    vec3 baseColor = baseSample.rgb;
    float alphaValue = baseSample.a;

    if (uShadeEnabled == 0) {
        FragColor = vec4(baseColor, 1.0);
        return;
    }

    vec3 smallBlur = sampleCrossBlur(uv, texel, 1.0);
    vec3 mediumBlur = sampleCrossBlur(uv, texel, 2.2);
    vec3 largeBlur = sampleCrossBlur(uv, texel, 4.0);

    float lumaValue = luminance(baseColor);
    float smallLuma = luminance(smallBlur);
    float mediumLuma = luminance(mediumBlur);
    float largeLuma = luminance(largeBlur);

    vec2 lumaGradient = evalGradientField(uv, texel, 1.0);
    vec2 alphaGradient = vec2(
        texture(tex, uv + vec2(texel.x, 0.0)).a - texture(tex, uv - vec2(texel.x, 0.0)).a,
        texture(tex, uv + vec2(0.0, texel.y)).a - texture(tex, uv - vec2(0.0, texel.y)).a
    );
    float alphaLeft = texture(tex, uv - vec2(texel.x, 0.0)).a;
    float alphaRight = texture(tex, uv + vec2(texel.x, 0.0)).a;
    float alphaUp = texture(tex, uv + vec2(0.0, texel.y)).a;
    float alphaDown = texture(tex, uv - vec2(0.0, texel.y)).a;
    float alphaMin = min(min(alphaLeft, alphaRight), min(alphaUp, alphaDown));
    float alphaMax = max(max(alphaLeft, alphaRight), max(alphaUp, alphaDown));
    float alphaRange = alphaMax - alphaMin;

    vec3 pseudoNormal = evalPseudoNormal(lumaGradient);
    vec3 lightDirValue = normalize(uLightDir);

    float detailMask = saturate(length(baseColor - mediumBlur) * 2.0 + length(lumaGradient) * 2.6);
    float depthProxy = 1.0 - smoothstep(0.10, 0.78, detailMask);
    float cavityMask = smoothstep(0.05, 0.26, max(mediumLuma - lumaValue, 0.0) + max(largeLuma - mediumLuma, 0.0));
    float broadContrast = max(abs(lumaValue - largeLuma), length(baseColor - mediumBlur) * 0.70);
    float alphaReliability = evalAlphaReliability(alphaValue, alphaRange, alphaGradient);
    float darkAssist = (1.0 - smoothstep(0.16, 0.44, smallLuma)) * kDarkOutlineAssist;

    float lightFacingness = evalLightFacingness(pseudoNormal, lightDirValue, smallLuma);
    float silhouetteMask = evalViewSilhouette(alphaValue, alphaRange, alphaGradient, lumaGradient, broadContrast, alphaReliability, darkAssist);
    float creaseMask = evalCreaseLine(lumaGradient, baseColor, smallBlur, detailMask, darkAssist);
    float shadowClass = classifyShadowRegion(lightFacingness, lumaValue, cavityMask);
    float contactMask = evalContactEdge(cavityMask, lumaGradient, shadowClass, darkAssist);
    float joinedDarkness = smoothstep(0.08, 0.38, max(largeLuma - lumaValue, 0.0));
    float blackFillMask = evalBlackFillMask(shadowClass, contactMask, joinedDarkness);

    float materialStyle = smoothstep(0.06, 0.24, saturationEstimate(baseColor) + detailMask * 0.18);
    float hatchAngle = atan(lightDirValue.y, lightDirValue.x) + mix(0.35, 0.95, materialStyle);
    float linePriority = evalLinePriority(silhouetteMask, creaseMask, contactMask, detailMask, depthProxy);
    float hatchDirectionDebug = 0.0;
    float screentoneMask = evalScreentoneMask(
        shadowClass,
        blackFillMask,
        materialStyle,
        pixelPos,
        hatchAngle,
        hatchDirectionDebug
    );
    screentoneMask *= 1.0 - evalToneEdgeSuppression(silhouetteMask, creaseMask, contactMask, linePriority);

    float reserveWhite = smoothstep(0.74, 0.96, lightFacingness) * smoothstep(0.72, 0.95, lumaValue) * blackFillMask;

    float inkCoverage = 0.0;
    vec3 inkComposite = compositeInkLayers(
        blackFillMask,
        screentoneMask,
        silhouetteMask,
        creaseMask,
        contactMask,
        linePriority,
        reserveWhite,
        inkCoverage
    );
    vec3 finalColor = applyPaperAndPrintFinish(inkComposite, inkCoverage, pixelPos);

    if (uDebugMode == 1) {
        FragColor = vec4(vec3(lightFacingness), 1.0);
        return;
    }
    if (uDebugMode == 7) {
        FragColor = vec4(vec3(silhouetteMask), 1.0);
        return;
    }
    if (uDebugMode == 8) {
        FragColor = vec4(vec3(creaseMask), 1.0);
        return;
    }
    if (uDebugMode == 3) {
        FragColor = vec4(vec3(shadowClass), 1.0);
        return;
    }
    if (uDebugMode == 15) {
        FragColor = vec4(vec3(contactMask), 1.0);
        return;
    }
    if (uDebugMode == 16) {
        FragColor = vec4(vec3(blackFillMask), 1.0);
        return;
    }
    if (uDebugMode == 17) {
        FragColor = vec4(vec3(screentoneMask), 1.0);
        return;
    }
    if (uDebugMode == 18) {
        FragColor = vec4(vec3(hatchDirectionDebug), 1.0);
        return;
    }
    if (uDebugMode == 19) {
        FragColor = vec4(vec3(linePriority), 1.0);
        return;
    }
    if (uDebugMode == 20) {
        FragColor = vec4(vec3(inkCoverage), 1.0);
        return;
    }

    FragColor = vec4(finalColor, 1.0);
}
