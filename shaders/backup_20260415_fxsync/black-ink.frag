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

vec2 evalGradientField(vec2 sampleUv, vec2 texel, float radius)
{
    float lL = luminance(sampleCrossBlur(sampleUv - vec2(texel.x * radius, 0.0), texel, radius));
    float lR = luminance(sampleCrossBlur(sampleUv + vec2(texel.x * radius, 0.0), texel, radius));
    float lU = luminance(sampleCrossBlur(sampleUv + vec2(0.0, texel.y * radius), texel, radius));
    float lD = luminance(sampleCrossBlur(sampleUv - vec2(0.0, texel.y * radius), texel, radius));
    return vec2(lR - lL, lU - lD);
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
    return clamp(mix(lumaValue, broad, 0.58) + highlight * 0.10, 0.0, 1.0);
}

float evalViewSilhouette(float alphaValue, float alphaRange, vec2 alphaGradient, vec2 lumaGradient, float broadContrast)
{
    float alphaEdge = smoothstep(0.01, 0.16, length(alphaGradient));
    float alphaShell = smoothstep(0.03, 0.34, alphaRange) * smoothstep(0.01, 0.995, alphaValue);
    float lumaEdge = smoothstep(uOutlineThreshold * 0.55, uOutlineThreshold * 1.65, length(lumaGradient));
    float broadEdge = smoothstep(0.04, 0.18, broadContrast);
    return clamp(max(max(alphaEdge, alphaShell) * 0.95, max(lumaEdge * 0.78, broadEdge * 0.48)), 0.0, 1.0);
}

float evalCreaseLine(vec2 lumaGradient, vec3 baseColor, vec3 smallBlur, float detailMask)
{
    float lumaEdge = smoothstep(uOutlineThreshold * 0.50, uOutlineThreshold * 1.80, length(lumaGradient));
    float chromaEdge = smoothstep(0.03, 0.18, length(baseColor - smallBlur));
    return clamp((lumaEdge * 0.72 + chromaEdge * 0.28) * mix(0.52, 1.0, detailMask), 0.0, 1.0);
}

float evalContactEdge(float cavityMask, vec2 lumaGradient, float shadowSignal)
{
    float grounded = smoothstep(0.10, 0.34, cavityMask);
    float compression = smoothstep(uOutlineThreshold * 0.45, uOutlineThreshold * 1.20, length(lumaGradient));
    return clamp(grounded * compression * mix(0.45, 1.0, shadowSignal), 0.0, 1.0);
}

float evalLinePriority(float silhouetteMask, float creaseMask, float contactMask, float detailMask, float depthProxy)
{
    float priority = silhouetteMask * 1.00 + creaseMask * 0.58 + contactMask * 0.82;
    priority *= mix(1.0, 0.68, depthProxy);
    priority *= mix(0.62, 1.0, detailMask);
    return clamp(priority, 0.0, 1.0);
}

float classifyShadowRegion(float lightFacingness, float lumaValue, float cavityMask)
{
    float shadowSignal = (1.0 - lightFacingness) * 0.68;
    shadowSignal += cavityMask * 0.34;
    shadowSignal += (1.0 - lumaValue) * 0.16;
    return clamp(shadowSignal, 0.0, 1.0);
}

float evalBlackFillMask(float shadowClass, float contactMask, float joinedDarkness)
{
    float blackSeed = shadowClass * 0.72 + contactMask * 0.58 + joinedDarkness * 0.34;
    return smoothstep(0.58, 0.82, blackSeed);
}

float evalDotTone(vec2 pixelPos, float density)
{
    vec2 rotated = rotation2D(0.48) * pixelPos;
    vec2 cell = fract(rotated / 7.0) - 0.5;
    float dist = length(cell);
    float radius = mix(0.06, 0.38, density);
    return 1.0 - smoothstep(radius, radius + 0.05, dist);
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

    float dotDensity = clamp(shadowClass * 1.10, 0.0, 1.0);
    float hatchDensity = clamp((shadowClass - 0.20) * 1.35, 0.0, 1.0);
    float crossDensity = clamp((shadowClass - 0.48) * 2.00, 0.0, 1.0);

    float dots = evalDotTone(pixelPos, dotDensity);
    float hatch = evalHatchPattern(pixelPos, hatchDensity, hatchAngle);
    float cross = evalCrossHatchPattern(pixelPos, crossDensity, hatchAngle);

    hatchDirectionDebug = fract(hatchAngle / 6.2831853);

    float tone = mix(dots * mildTone, hatch * denseTone, materialStyle);
    tone = max(tone, cross * denseTone * smoothstep(0.62, 0.82, shadowClass));
    return clamp(tone * (1.0 - blackFillMask), 0.0, 1.0);
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

    float lineInk = clamp(max(max(silhouetteInk, creaseInk), contactInk), 0.0, 1.0);
    float blackCoverage = smoothstep(0.36, 0.82, blackFillMask * (1.0 - reserveWhite));
    float toneCoverage = smoothstep(0.18, 0.70, screentoneMask) * 0.84;
    float coverage = max(blackCoverage, max(toneCoverage, lineInk));
    coverage = max(coverage, silhouetteMask * 0.90);
    inkCoverage = clamp(coverage, 0.0, 1.0);

    vec3 paper = vec3(1.0);
    return mix(paper, vec3(0.0), inkCoverage);
}

vec3 applyPaperAndPrintFinish(vec3 inkColor, float inkCoverage, vec2 pixelPos)
{
    float paperNoise = fract(sin(dot(pixelPos * vec2(0.91, 1.07), vec2(12.9898, 78.233))) * 43758.5453);
    float paperTone = 0.985 + paperNoise * 0.012;
    vec3 paperTint = vec3(paperTone);

    vec3 result = min(inkColor, paperTint);
    float inkSpread = smoothstep(0.58, 0.95, inkCoverage) * 0.08;
    result = mix(result, vec3(0.0), inkSpread);
    return clamp(result, 0.0, 1.0);
}

void main()
{
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));
    vec2 pixelPos = uv * vec2(textureSize(tex, 0));

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

    float detailMask = clamp(length(baseColor - mediumBlur) * 2.0 + length(lumaGradient) * 2.6, 0.0, 1.0);
    float depthProxy = 1.0 - smoothstep(0.10, 0.78, detailMask);
    float cavityMask = smoothstep(0.05, 0.26, max(mediumLuma - lumaValue, 0.0) + max(largeLuma - mediumLuma, 0.0));
    float broadContrast = max(abs(lumaValue - largeLuma), length(baseColor - mediumBlur) * 0.70);

    float lightFacingness = evalLightFacingness(pseudoNormal, lightDirValue, smallLuma);
    float silhouetteMask = evalViewSilhouette(alphaValue, alphaRange, alphaGradient, lumaGradient, broadContrast);
    float creaseMask = evalCreaseLine(lumaGradient, baseColor, smallBlur, detailMask);
    float shadowClass = classifyShadowRegion(lightFacingness, lumaValue, cavityMask);
    float contactMask = evalContactEdge(cavityMask, lumaGradient, shadowClass);
    float joinedDarkness = smoothstep(0.08, 0.38, max(largeLuma - lumaValue, 0.0));
    float blackFillMask = evalBlackFillMask(shadowClass, contactMask, joinedDarkness);

    float materialStyle = smoothstep(0.06, 0.24, saturationEstimate(baseColor) + detailMask * 0.18);
    float hatchAngle = atan(lightDirValue.y, lightDirValue.x) + mix(0.35, 0.95, materialStyle);
    float hatchDirectionDebug = 0.0;
    float screentoneMask = evalScreentoneMask(
        shadowClass,
        blackFillMask,
        materialStyle,
        pixelPos,
        hatchAngle,
        hatchDirectionDebug
    );

    float linePriority = evalLinePriority(silhouetteMask, creaseMask, contactMask, detailMask, depthProxy);
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
        FragColor = vec4(vec3(hatchDirectionDebug, hatchDirectionDebug, hatchDirectionDebug), 1.0);
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
