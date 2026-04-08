#include "gui.h"

#include <stdexcept>

#include "constant.h"
#include "synth.h"
#include "texture.h"

namespace {

struct AppState {
    WindowContext window;
    ShaderProgram program;
    FullscreenQuad quad;
    Texture2D texture;
    bool exported = false;
};

void framebufferSizeCallback(GLFWwindow*, int width, int height)
{
    glViewport(0, 0, width, height);
}

WindowContext initWindow(const AppConfig& config)
{
    if (!glfwInit()) {
        throw std::runtime_error("GLFW initialization failed.");
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, constants::kOpenGLMajorVersion);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, constants::kOpenGLMinorVersion);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    GLFWwindow* window = glfwCreateWindow(
        config.windowWidth,
        config.windowHeight,
        constants::kWindowTitle,
        nullptr,
        nullptr
    );

    if (window == nullptr) {
        glfwTerminate();
        throw std::runtime_error("Window creation failed.");
    }

    glfwMakeContextCurrent(window);

    glewExperimental = GL_TRUE;
    if (glewInit() != GLEW_OK) {
        glfwDestroyWindow(window);
        glfwTerminate();
        throw std::runtime_error("GLEW initialization failed.");
    }

    glGetError();

    int framebufferWidth = 0;
    int framebufferHeight = 0;
    glfwGetFramebufferSize(window, &framebufferWidth, &framebufferHeight);
    glViewport(0, 0, framebufferWidth, framebufferHeight);
    glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);

    WindowContext context;
    context.handle = window;
    context.initialized = true;
    return context;
}

FullscreenQuad createFullscreenQuad()
{
    static const float quadVertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f,
         1.0f, -1.0f, 1.0f, 0.0f,
         1.0f,  1.0f, 1.0f, 1.0f,

        -1.0f, -1.0f, 0.0f, 0.0f,
         1.0f,  1.0f, 1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f, 1.0f
    };

    FullscreenQuad quad;
    glGenVertexArrays(1, &quad.vao);
    glGenBuffers(1, &quad.vbo);

    glBindVertexArray(quad.vao);
    glBindBuffer(GL_ARRAY_BUFFER, quad.vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), reinterpret_cast<void*>(0));
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), reinterpret_cast<void*>(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    return quad;
}

void renderFrame(const ShaderProgram& program, const FullscreenQuad& quad, const Texture2D& texture)
{
    glClearColor(
        constants::kClearColor[0],
        constants::kClearColor[1],
        constants::kClearColor[2],
        constants::kClearColor[3]
    );
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(program.id);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glBindVertexArray(quad.vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

void exportFrameIfRequested(AppState& state, const AppConfig& config)
{
    if (!config.shouldExport() || state.exported) {
        return;
    }

    int framebufferWidth = 0;
    int framebufferHeight = 0;
    glfwGetFramebufferSize(state.window.handle, &framebufferWidth, &framebufferHeight);
    saveFramebufferToPpm(config.outputPath, framebufferWidth, framebufferHeight);
    state.exported = true;
    glfwSetWindowShouldClose(state.window.handle, GLFW_TRUE);
}

}  // namespace

void runViewer(AppConfig config)
{
    if (config.shouldExport() && !config.sizeSpecified) {
        const ImageInfo sourceImage = probeImage(config.inputPath);
        config.windowWidth = sourceImage.width;
        config.windowHeight = sourceImage.height;
    }

    AppState state;
    state.window = initWindow(config);
    state.program = createShaderProgram(config.vertexShaderPath, config.fragmentShaderPath);
    state.quad = createFullscreenQuad();
    state.texture = loadTexture2D(config.inputPath);

    configureCelluloidUniforms(state.program, config.debugMode);

    while (!glfwWindowShouldClose(state.window.handle)) {
        glfwPollEvents();
        renderFrame(state.program, state.quad, state.texture);
        exportFrameIfRequested(state, config);
        glfwSwapBuffers(state.window.handle);
    }
}
