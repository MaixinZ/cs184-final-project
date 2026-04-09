#pragma once

#include <string>

#include "app_types.h"

ShaderProgram createShaderProgram(const std::string& vertexShaderPath, const std::string& fragmentShaderPath);
void configureStyleUniforms(const ShaderProgram& program, const std::string& styleName, int debugMode);
void setShadeEnabled(const ShaderProgram& program, bool enabled);
