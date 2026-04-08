#pragma once

#include <GL/glew.h>

namespace constants {

extern const char kDefaultInputPath[];
extern const char kDefaultVertexShaderPath[];
extern const char kDefaultFragmentShaderPath[];
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

}  // namespace constants
