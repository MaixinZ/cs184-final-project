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
    return normalize(vec3(-gradientField * 2.6, 1.0));
}

float evalLightFacingness(vec3 pseudoNormal, vec3 lightDirValue, float lumaValue)
{
    float ndotl = max(dot(pseudoNormal, lightDirValue), 0.0);
    float broadBand = smoothstep(uShadowThreshold, uMidThreshold + 0.04, ndotl);
    float highlightBias = smoothstep(uMidThreshold, uHighlightThreshold + 0.04, ndotl);
    return clamp(mix(lumaValue, broadBand, 0.62) + highlightBias * 0.14, 0.0, 1.0);
}

float evalSilhouetteEdge(float alphaValue, vec2 alphaGradient, vec2 light2D)
{
    float contour = smoothstep(uOutlineThreshold * 0.60, uOutlineThreshold * 1.40, length(alphaGradient));
    float directional = 1.0;
    if (length(alphaGradient) > 0.0001) {
        directional = smoothstep(-0.25, 0.80, dot(normalize(alphaGradient), -light2D));
    }

    float interiorBias = smoothstep(0.02, 0.98, alphaValue) * (1.0 - smoothstep(0.98, 1.00, alphaValue));
    return contour * directional * max(interiorBias, contour);
}

float evalInternalEdge(vec2 lumaGradient, vec3 baseColor, vec3 smallBlur, float lightFacingness)
{
    float lumaEdge = smoothstep(uOutlineThreshold * 0.75, uOutlineThreshold * 2.40, length(lumaGradient));
    float chromaEdge = smoothstep(0.05, 0.28, length(baseColor - smallBlur));
    float directional = smoothstep(0.24, 0.92, lightFacingness);
    return clamp((lumaEdge * 0.60 + chromaEdge * 0.40) * directional, 0.0, 1.0);
}

float evalEmissiveCore(vec3 colorValue)
{
    float intensity = max(max(colorValue.r, colorValue.g), colorValue.b);
    float chroma = saturationEstimate(colorValue);
    return smoothstep(0.58, 0.94, intensity) * smoothstep(0.08, 0.40, chroma);
}

float evalEmissiveAdjacency(float emissiveCore, float emissiveBlur)
{
    float narrowShell = max(emissiveBlur - emissiveCore * 0.80, 0.0);
    return smoothstep(0.02, 0.24, narrowShell);
}

vec3 evalEdgeHighlightColor(vec3 baseColor, float lightFacingness, float emissiveAdjacency)
{
    vec3 localLift = mix(baseColor, uLightTint, 0.28);
    vec3 emissiveLift = mix(uSpecColor, uRimColor, 0.25);
    return mix(localLift, emissiveLift, emissiveAdjacency * 0.75 + lightFacingness * 0.15);
}

float evalLocalHighPass(float lumaValue, float blurredLuma)
{
    return lumaValue - blurredLuma;
}

vec3 applyFakeLocalContrast(
    vec3 colorValue,
    float highPass,
    float lightFacingness,
    float cavityMask,
    vec3 accentColor,
    out float positiveLobe,
    out float negativeLobe
)
{
    positiveLobe = max(highPass, 0.0);
    negativeLobe = max(-highPass, 0.0);

    float posWeight = mix(0.18, 0.52, lightFacingness);
    float negWeight = mix(0.20, 0.58, 1.0 - lightFacingness + cavityMask * 0.35);

    colorValue += accentColor * (positiveLobe * posWeight);
    colorValue -= vec3(negativeLobe * negWeight);
    return colorValue;
}

vec3 applyEdgeHighlightComposite(
    vec3 colorValue,
    vec3 edgeColor,
    float silhouetteEdge,
    float internalEdge,
    float lightFacingness,
    out vec3 edgeContribution
)
{
    float edgeMask = silhouetteEdge * 0.78 + internalEdge * 0.52;
    float edgeEnergy = edgeMask * mix(0.42, 1.00, lightFacingness);
    edgeContribution = edgeColor * edgeEnergy;
    return colorValue + edgeContribution;
}

vec3 applyNeonEdgeGlow(
    vec3 colorValue,
    vec3 edgeColor,
    float emissiveAdjacency,
    float silhouetteEdge,
    out vec3 neonContribution
)
{
    float neonMask = emissiveAdjacency * mix(0.55, 1.0, silhouetteEdge);
    neonContribution = mix(edgeColor, uSpecColor, 0.40) * neonMask * 0.44;
    return colorValue + neonContribution;
}

vec3 applyAtmosphericCompression(vec3 colorValue, float fogFactor)
{
    vec3 foggedColor = mix(colorValue, uAtmosphereColor, fogFactor * 0.34);
    float foggedLuma = luminance(foggedColor);
    vec3 flattenedColor = mix(foggedColor, mix(vec3(foggedLuma), uAtmosphereColor, 0.32), fogFactor * 0.28);
    return mix(colorValue, flattenedColor, fogFactor);
}

vec3 applyFinalContrastSafeGrade(vec3 colorValue)
{
    float peak = max(max(colorValue.r, colorValue.g), colorValue.b);
    float shoulder = max(peak - 1.0, 0.0);
    colorValue /= 1.0 + shoulder * 0.52;

    float lumaValue = luminance(colorValue);
    vec3 saturated = mix(vec3(lumaValue), colorValue, 1.08);
    return clamp(pow(max(saturated, 0.0), vec3(0.96)), 0.0, 1.0);
}

void main()
{
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));

    vec4 baseSample = texture(tex, uv);
    vec3 baseColor = baseSample.rgb;
    float alphaValue = baseSample.a;
    if (uShadeEnabled == 0) {
        FragColor = vec4(baseColor, 1.0);
        return;
    }

    vec3 smallBlur = sampleCrossBlur(uv, texel, 1.0);
    vec3 mediumBlur = sampleCrossBlur(uv, texel, 2.5);
    float lumaValue = luminance(baseColor);
    float blurredLuma = luminance(mediumBlur);

    vec2 lumaGradient = evalGradientField(uv, texel, 1.0);
    vec2 alphaGradient = vec2(
        texture(tex, uv + vec2(texel.x, 0.0)).a - texture(tex, uv - vec2(texel.x, 0.0)).a,
        texture(tex, uv + vec2(0.0, texel.y)).a - texture(tex, uv - vec2(0.0, texel.y)).a
    );

    vec3 lightDirValue = normalize(uLightDir);
    vec2 light2D = normalize(lightDirValue.xy + vec2(0.0001, 0.0001));
    vec3 pseudoNormal = evalPseudoNormal(lumaGradient);

    float lightFacingness = evalLightFacingness(pseudoNormal, lightDirValue, luminance(smallBlur));
    float silhouetteEdge = evalSilhouetteEdge(alphaValue, alphaGradient, light2D);
    float internalEdge = evalInternalEdge(lumaGradient, baseColor, smallBlur, lightFacingness);

    float emissiveCore = evalEmissiveCore(baseColor);
    float emissiveAdjacency = evalEmissiveAdjacency(emissiveCore, evalEmissiveCore(smallBlur));

    float highPass = evalLocalHighPass(lumaValue, blurredLuma);
    float cavityMask = smoothstep(0.08, 0.34, length(baseColor - mediumBlur));
    vec3 edgeColor = evalEdgeHighlightColor(baseColor, lightFacingness, emissiveAdjacency);

    vec3 litScene = mix(baseColor * uShadowTint, baseColor * uLightTint, lightFacingness);
    litScene = mix(litScene, baseColor * uMidTint, 0.36);

    float positiveLobe = 0.0;
    float negativeLobe = 0.0;
    vec3 contrastContribution = vec3(0.0);
    vec3 contrastColor = applyFakeLocalContrast(
        litScene,
        highPass,
        lightFacingness,
        cavityMask,
        edgeColor,
        positiveLobe,
        negativeLobe
    );
    contrastContribution = contrastColor - litScene;

    vec3 edgeContribution = vec3(0.0);
    vec3 edgeComposite = applyEdgeHighlightComposite(
        contrastColor,
        edgeColor,
        silhouetteEdge,
        internalEdge,
        lightFacingness,
        edgeContribution
    );

    vec3 neonContribution = vec3(0.0);
    vec3 glowComposite = applyNeonEdgeGlow(edgeComposite, edgeColor, emissiveAdjacency, silhouetteEdge, neonContribution);

    float fogFactor = clamp(
        (smoothstep(0.16, 0.86, 1.0 - cavityMask) * 0.72 + smoothstep(0.18, 0.94, uv.y) * 0.18) * uFogWeight,
        0.0,
        1.0
    );
    vec3 finalColor = applyAtmosphericCompression(glowComposite, fogFactor);
    finalColor = applyFinalContrastSafeGrade(finalColor);

    if (uDebugMode == 1) {
        FragColor = vec4(vec3(lightFacingness), 1.0);
        return;
    }
    if (uDebugMode == 7) {
        FragColor = vec4(vec3(silhouetteEdge), 1.0);
        return;
    }
    if (uDebugMode == 8) {
        FragColor = vec4(vec3(internalEdge), 1.0);
        return;
    }
    if (uDebugMode == 9) {
        FragColor = vec4(vec3(emissiveAdjacency), 1.0);
        return;
    }
    if (uDebugMode == 10) {
        FragColor = vec4(vec3(highPass * 0.5 + 0.5), 1.0);
        return;
    }
    if (uDebugMode == 11) {
        FragColor = vec4(vec3(positiveLobe), 1.0);
        return;
    }
    if (uDebugMode == 12) {
        FragColor = vec4(vec3(negativeLobe), 1.0);
        return;
    }
    if (uDebugMode == 13) {
        FragColor = vec4(clamp(edgeContribution, 0.0, 1.0), 1.0);
        return;
    }
    if (uDebugMode == 14) {
        FragColor = vec4(clamp(contrastContribution * 0.5 + 0.5, 0.0, 1.0), 1.0);
        return;
    }

    FragColor = vec4(finalColor, 1.0);
}
