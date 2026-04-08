#pragma once

#include <string>

#include "app_types.h"

ShaderProgram createShaderProgram(const std::string& vertexShaderPath, const std::string& fragmentShaderPath);
void configureCelluloidUniforms(const ShaderProgram& program, int debugMode);
