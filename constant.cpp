#include "constant.h"

namespace constants {

const char kDefaultInputPath[] = "profile.png";
const char kDefaultVertexShaderPath[] = "shaders/painter.vert";
const char kDefaultFragmentShaderPath[] = "shaders/painter.frag";
const char kWindowTitle[] = "Celluloid Viewer";

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

}  // namespace constants
