#pragma once

#include <GL/glew.h>

namespace constants {

extern const char kDefaultInputPath[];
extern const char kDefaultStyleName[];
extern const char kShaderDirectory[];
extern const char kWindowTitle[];

extern const int kDefaultWindowWidth;
extern const int kDefaultWindowHeight;
extern const int kOpenGLMajorVersion;
extern const int kOpenGLMinorVersion;

extern const int kDebugFinal;
extern const int kDebugNdotL;
extern const int kDebugBand;
extern const int kDebugShadow;
extern const int kDebugRim;
extern const int kDebugOutline;
extern const int kDebugFog;
extern const int kDebugSilhouette;
extern const int kDebugInternalEdge;
extern const int kDebugEmissiveAdjacency;
extern const int kDebugHighPass;
extern const int kDebugContrastPositive;
extern const int kDebugContrastNegative;
extern const int kDebugEdgeContribution;
extern const int kDebugContrastContribution;
extern const int kDebugContactEdge;
extern const int kDebugBlackFill;
extern const int kDebugScreentone;
extern const int kDebugHatchDirection;
extern const int kDebugLinePriority;
extern const int kDebugInkCoverage;

extern const GLfloat kClearColor[4];
extern const GLfloat kLightDir[3];
extern const GLfloat kLightTint[3];
extern const GLfloat kMidTint[3];
extern const GLfloat kShadowTint[3];
extern const GLfloat kSpecColor[3];
extern const GLfloat kRimColor[3];
extern const GLfloat kOutlineColor[3];
extern const GLfloat kAtmosphereColor[3];

extern const GLfloat kShadowThreshold;
extern const GLfloat kShadowSoftness;
extern const GLfloat kMidThreshold;
extern const GLfloat kHighlightThreshold;
extern const GLfloat kSpecThreshold;
extern const GLfloat kRimThreshold;
extern const GLfloat kOutlineThreshold;
extern const GLfloat kFogWeight;

extern const GLfloat kBlackInkLightDir[3];
extern const GLfloat kBlackInkShadowThreshold;
extern const GLfloat kBlackInkMidThreshold;
extern const GLfloat kBlackInkHighlightThreshold;
extern const GLfloat kBlackInkOutlineThreshold;

}  // namespace constants
