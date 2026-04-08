#pragma once

#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include <string>

#include "constant.h"

struct AppConfig {
    std::string inputPath = constants::kDefaultInputPath;
    std::string outputPath;
    std::string vertexShaderPath = constants::kDefaultVertexShaderPath;
    std::string fragmentShaderPath = constants::kDefaultFragmentShaderPath;
    int windowWidth = constants::kDefaultWindowWidth;
    int windowHeight = constants::kDefaultWindowHeight;
    int debugMode = constants::kDebugFinal;
    bool sizeSpecified = false;

    bool shouldExport() const
    {
        return !outputPath.empty();
    }
};

struct ImageInfo {
    int width = 0;
    int height = 0;
    int channels = 0;
};

struct FullscreenQuad {
    GLuint vao = 0;
    GLuint vbo = 0;

    FullscreenQuad() = default;
    FullscreenQuad(const FullscreenQuad&) = delete;
    FullscreenQuad& operator=(const FullscreenQuad&) = delete;

    FullscreenQuad(FullscreenQuad&& other) noexcept
        : vao(other.vao), vbo(other.vbo)
    {
        other.vao = 0;
        other.vbo = 0;
    }

    FullscreenQuad& operator=(FullscreenQuad&& other) noexcept
    {
        if (this != &other) {
            if (vbo != 0) {
                glDeleteBuffers(1, &vbo);
            }
            if (vao != 0) {
                glDeleteVertexArrays(1, &vao);
            }

            vao = other.vao;
            vbo = other.vbo;
            other.vao = 0;
            other.vbo = 0;
        }
        return *this;
    }

    ~FullscreenQuad()
    {
        if (vbo != 0) {
            glDeleteBuffers(1, &vbo);
        }
        if (vao != 0) {
            glDeleteVertexArrays(1, &vao);
        }
    }
};

struct Texture2D {
    GLuint id = 0;
    int width = 0;
    int height = 0;
    GLenum format = GL_RGB;

    Texture2D() = default;
    Texture2D(const Texture2D&) = delete;
    Texture2D& operator=(const Texture2D&) = delete;

    Texture2D(Texture2D&& other) noexcept
        : id(other.id), width(other.width), height(other.height), format(other.format)
    {
        other.id = 0;
        other.width = 0;
        other.height = 0;
        other.format = GL_RGB;
    }

    Texture2D& operator=(Texture2D&& other) noexcept
    {
        if (this != &other) {
            if (id != 0) {
                glDeleteTextures(1, &id);
            }

            id = other.id;
            width = other.width;
            height = other.height;
            format = other.format;

            other.id = 0;
            other.width = 0;
            other.height = 0;
            other.format = GL_RGB;
        }
        return *this;
    }

    ~Texture2D()
    {
        if (id != 0) {
            glDeleteTextures(1, &id);
        }
    }
};

struct ShaderProgram {
    GLuint id = 0;

    ShaderProgram() = default;
    ShaderProgram(const ShaderProgram&) = delete;
    ShaderProgram& operator=(const ShaderProgram&) = delete;

    ShaderProgram(ShaderProgram&& other) noexcept
        : id(other.id)
    {
        other.id = 0;
    }

    ShaderProgram& operator=(ShaderProgram&& other) noexcept
    {
        if (this != &other) {
            if (id != 0) {
                glDeleteProgram(id);
            }

            id = other.id;
            other.id = 0;
        }
        return *this;
    }

    ~ShaderProgram()
    {
        if (id != 0) {
            glDeleteProgram(id);
        }
    }
};

struct WindowContext {
    GLFWwindow* handle = nullptr;
    bool initialized = false;

    WindowContext() = default;
    WindowContext(const WindowContext&) = delete;
    WindowContext& operator=(const WindowContext&) = delete;

    WindowContext(WindowContext&& other) noexcept
        : handle(other.handle), initialized(other.initialized)
    {
        other.handle = nullptr;
        other.initialized = false;
    }

    WindowContext& operator=(WindowContext&& other) noexcept
    {
        if (this != &other) {
            if (handle != nullptr) {
                glfwDestroyWindow(handle);
            }
            if (initialized) {
                glfwTerminate();
            }

            handle = other.handle;
            initialized = other.initialized;
            other.handle = nullptr;
            other.initialized = false;
        }
        return *this;
    }

    ~WindowContext()
    {
        if (handle != nullptr) {
            glfwDestroyWindow(handle);
        }
        if (initialized) {
            glfwTerminate();
        }
    }
};
