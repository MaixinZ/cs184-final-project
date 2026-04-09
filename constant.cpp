#include "constant.h"

namespace constants {

const char kDefaultInputPath[] = "example/profile.png";
const char kDefaultStyleName[] = "painter";
const char kShaderDirectory[] = "shaders";
const char kWindowTitle[] = "Stylized Shader Viewer";

const int kDefaultWindowWidth = 1280;
const int kDefaultWindowHeight = 720;
const int kOpenGLMajorVersion = 3;
const int kOpenGLMinorVersion = 3;

const int kDebugFinal = 0;
const int kDebugNdotL = 1;
const int kDebugBand = 2;
const int kDebugShadow = 3;
const int kDebugRim = 4;
const int kDebugOutline = 5;
const int kDebugFog = 6;
const int kDebugSilhouette = 7;
const int kDebugInternalEdge = 8;
const int kDebugEmissiveAdjacency = 9;
const int kDebugHighPass = 10;
const int kDebugContrastPositive = 11;
const int kDebugContrastNegative = 12;
const int kDebugEdgeContribution = 13;
const int kDebugContrastContribution = 14;
const int kDebugContactEdge = 15;
const int kDebugBlackFill = 16;
const int kDebugScreentone = 17;
const int kDebugHatchDirection = 18;
const int kDebugLinePriority = 19;
const int kDebugInkCoverage = 20;

const GLfloat kClearColor[4] = {0.95f, 0.88f, 0.74f, 1.0f};
const GLfloat kLightDir[3] = {-0.45f, 0.35f, 0.82f};
const GLfloat kLightTint[3] = {1.10f, 1.03f, 0.96f};
const GLfloat kMidTint[3] = {0.92f, 0.96f, 1.00f};
const GLfloat kShadowTint[3] = {0.68f, 0.78f, 0.96f};
const GLfloat kSpecColor[3] = {1.00f, 0.94f, 0.84f};
const GLfloat kRimColor[3] = {0.98f, 0.90f, 0.72f};
const GLfloat kOutlineColor[3] = {0.19f, 0.15f, 0.18f};
const GLfloat kAtmosphereColor[3] = {0.74f, 0.82f, 0.92f};

const GLfloat kShadowThreshold = 0.36f;
const GLfloat kShadowSoftness = 0.06f;
const GLfloat kMidThreshold = 0.58f;
const GLfloat kHighlightThreshold = 0.82f;
const GLfloat kSpecThreshold = 0.58f;
const GLfloat kRimThreshold = 0.42f;
const GLfloat kOutlineThreshold = 0.16f;
const GLfloat kFogWeight = 0.55f;

const GLfloat kBlackInkLightDir[3] = {-0.28f, 0.18f, 0.94f};
const GLfloat kBlackInkShadowThreshold = 0.28f;
const GLfloat kBlackInkMidThreshold = 0.46f;
const GLfloat kBlackInkHighlightThreshold = 0.70f;
const GLfloat kBlackInkOutlineThreshold = 0.10f;

}  // namespace constants
