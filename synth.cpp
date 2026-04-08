#include "synth.h"

#include <fstream>
#include <sstream>
#include <stdexcept>

#include "constant.h"

namespace {

std::string shaderTypeName(GLenum type)
{
    switch (type) {
        case GL_VERTEX_SHADER:
            return "vertex";
        case GL_FRAGMENT_SHADER:
            return "fragment";
        default:
            return "unknown";
    }
}

std::string readTextFile(const std::string& path)
{
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        throw std::runtime_error("Failed to open file: " + path);
    }

    std::ostringstream buffer;
    buffer << input.rdbuf();
    return buffer.str();
}

GLuint compileShader(GLenum type, const char* source)
{
    const GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    GLint compiled = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled == GL_TRUE) {
        return shader;
    }

    GLint logLength = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    std::string log(logLength > 0 ? static_cast<size_t>(logLength) : 1U, '\0');
    glGetShaderInfoLog(shader, logLength, nullptr, log.data());
    glDeleteShader(shader);

    throw std::runtime_error("Failed to compile " + shaderTypeName(type) + " shader:\n" + log);
}

void setUniformInt(GLuint programId, const char* name, GLint value)
{
    const GLint location = glGetUniformLocation(programId, name);
    if (location >= 0) {
        glUniform1i(location, value);
    }
}

void setUniformFloat(GLuint programId, const char* name, GLfloat value)
{
    const GLint location = glGetUniformLocation(programId, name);
    if (location >= 0) {
        glUniform1f(location, value);
    }
}

void setUniformVec3(GLuint programId, const char* name, const GLfloat values[3])
{
    const GLint location = glGetUniformLocation(programId, name);
    if (location >= 0) {
        glUniform3f(location, values[0], values[1], values[2]);
    }
}

}  // namespace

ShaderProgram createShaderProgram(const std::string& vertexShaderPath, const std::string& fragmentShaderPath)
{
    const std::string vertexSource = readTextFile(vertexShaderPath);
    const std::string fragmentSource = readTextFile(fragmentShaderPath);

    const GLuint vertexShader = compileShader(GL_VERTEX_SHADER, vertexSource.c_str());
    const GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentSource.c_str());

    const GLuint programId = glCreateProgram();
    glAttachShader(programId, vertexShader);
    glAttachShader(programId, fragmentShader);
    glLinkProgram(programId);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    GLint linked = GL_FALSE;
    glGetProgramiv(programId, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) {
        GLint logLength = 0;
        glGetProgramiv(programId, GL_INFO_LOG_LENGTH, &logLength);
        std::string log(logLength > 0 ? static_cast<size_t>(logLength) : 1U, '\0');
        glGetProgramInfoLog(programId, logLength, nullptr, log.data());
        glDeleteProgram(programId);
        throw std::runtime_error("Failed to link program:\n" + log);
    }

    ShaderProgram program;
    program.id = programId;
    return program;
}

void configureCelluloidUniforms(const ShaderProgram& program, int debugMode)
{
    glUseProgram(program.id);

    setUniformInt(program.id, "tex", 0);
    setUniformInt(program.id, "uDebugMode", debugMode);

    setUniformVec3(program.id, "uLightDir", constants::kLightDir);
    setUniformVec3(program.id, "uLightTint", constants::kLightTint);
    setUniformVec3(program.id, "uMidTint", constants::kMidTint);
    setUniformVec3(program.id, "uShadowTint", constants::kShadowTint);
    setUniformVec3(program.id, "uSpecColor", constants::kSpecColor);
    setUniformVec3(program.id, "uRimColor", constants::kRimColor);
    setUniformVec3(program.id, "uOutlineColor", constants::kOutlineColor);
    setUniformVec3(program.id, "uAtmosphereColor", constants::kAtmosphereColor);

    setUniformFloat(program.id, "uShadowThreshold", constants::kShadowThreshold);
    setUniformFloat(program.id, "uShadowSoftness", constants::kShadowSoftness);
    setUniformFloat(program.id, "uMidThreshold", constants::kMidThreshold);
    setUniformFloat(program.id, "uHighlightThreshold", constants::kHighlightThreshold);
    setUniformFloat(program.id, "uSpecThreshold", constants::kSpecThreshold);
    setUniformFloat(program.id, "uRimThreshold", constants::kRimThreshold);
    setUniformFloat(program.id, "uOutlineThreshold", constants::kOutlineThreshold);
    setUniformFloat(program.id, "uFogWeight", constants::kFogWeight);
}
