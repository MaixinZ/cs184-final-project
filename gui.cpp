#include "gui.h"

#include <stdexcept>

#include "constant.h"
#include "synth.h"
#include "texture.h"

namespace {

enum class ViewMode {
    SplitCompare,
    OriginalOnly,
    ShadedOnly,
};

struct AppState {
    WindowContext window;
    ShaderProgram program;
    FullscreenQuad quad;
    Texture2D texture;
    int singleWindowWidth = 0;
    int singleWindowHeight = 0;
    int splitWindowWidth = 0;
    int splitWindowHeight = 0;
    ViewMode viewMode = ViewMode::SplitCompare;
    ViewMode lastSingleMode = ViewMode::ShadedOnly;
    bool exported = false;
};

void resizeWindowForViewMode(AppState& state)
{
    if (state.window.handle == nullptr) {
        return;
    }

    if (state.viewMode == ViewMode::SplitCompare) {
        glfwSetWindowSize(state.window.handle, state.splitWindowWidth, state.splitWindowHeight);
        return;
    }

    glfwSetWindowSize(state.window.handle, state.singleWindowWidth, state.singleWindowHeight);
}

void setSingleViewMode(AppState& state, ViewMode mode)
{
    state.viewMode = mode;
    state.lastSingleMode = mode;
    resizeWindowForViewMode(state);
}

void keyCallback(GLFWwindow* window, int key, int, int action, int)
{
    if (action != GLFW_PRESS) {
        return;
    }

    auto* state = static_cast<AppState*>(glfwGetWindowUserPointer(window));
    if (state == nullptr) {
        return;
    }

    if (key == GLFW_KEY_1) {
        state->viewMode = ViewMode::SplitCompare;
        resizeWindowForViewMode(*state);
        return;
    }

    if (key == GLFW_KEY_2) {
        setSingleViewMode(*state, ViewMode::OriginalOnly);
        return;
    }

    if (key == GLFW_KEY_3) {
        setSingleViewMode(*state, ViewMode::ShadedOnly);
        return;
    }

    if (key == GLFW_KEY_TAB) {
        if (state->viewMode == ViewMode::SplitCompare) {
            setSingleViewMode(*state, state->lastSingleMode);
        } else {
            state->viewMode = ViewMode::SplitCompare;
            resizeWindowForViewMode(*state);
        }
        return;
    }

    if (key == GLFW_KEY_S || key == GLFW_KEY_SPACE) {
        ViewMode nextMode = ViewMode::ShadedOnly;
        if (state->viewMode == ViewMode::ShadedOnly || state->lastSingleMode == ViewMode::ShadedOnly) {
            nextMode = ViewMode::OriginalOnly;
        }
        setSingleViewMode(*state, nextMode);
    }
}

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
    glfwSetKeyCallback(window, keyCallback);

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

void drawSubview(
    const ShaderProgram& program,
    const FullscreenQuad& quad,
    const Texture2D& texture,
    int viewportX,
    int viewportY,
    int viewportWidth,
    int viewportHeight,
    bool shadeEnabled
)
{
    glViewport(viewportX, viewportY, viewportWidth, viewportHeight);
    glUseProgram(program.id);
    setShadeEnabled(program, shadeEnabled);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glBindVertexArray(quad.vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

void renderFrame(AppState& state)
{
    glClearColor(
        constants::kClearColor[0],
        constants::kClearColor[1],
        constants::kClearColor[2],
        constants::kClearColor[3]
    );
    glClear(GL_COLOR_BUFFER_BIT);

    int framebufferWidth = 0;
    int framebufferHeight = 0;
    glfwGetFramebufferSize(state.window.handle, &framebufferWidth, &framebufferHeight);

    if (state.viewMode == ViewMode::SplitCompare) {
        const int leftWidth = framebufferWidth / 2;
        const int rightWidth = framebufferWidth - leftWidth;
        drawSubview(state.program, state.quad, state.texture, 0, 0, leftWidth, framebufferHeight, false);
        drawSubview(state.program, state.quad, state.texture, leftWidth, 0, rightWidth, framebufferHeight, true);
        return;
    }

    const bool shadeEnabled = state.viewMode == ViewMode::ShadedOnly;
    drawSubview(state.program, state.quad, state.texture, 0, 0, framebufferWidth, framebufferHeight, shadeEnabled);
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
    const ImageInfo sourceImage = probeImage(config.inputPath);

    const int singleWindowWidth = config.sizeSpecified ? config.windowWidth : sourceImage.width;
    const int singleWindowHeight = config.sizeSpecified ? config.windowHeight : sourceImage.height;
    const int splitWindowWidth = singleWindowWidth * 2;
    const int splitWindowHeight = singleWindowHeight;

    config.windowWidth = splitWindowWidth;
    config.windowHeight = splitWindowHeight;

    AppState state;
    state.singleWindowWidth = singleWindowWidth;
    state.singleWindowHeight = singleWindowHeight;
    state.splitWindowWidth = splitWindowWidth;
    state.splitWindowHeight = splitWindowHeight;
    state.viewMode = ViewMode::SplitCompare;
    state.lastSingleMode = ViewMode::ShadedOnly;
    state.window = initWindow(config);
    glfwSetWindowUserPointer(state.window.handle, &state);
    state.program = createShaderProgram(config.vertexShaderPath, config.fragmentShaderPath);
    state.quad = createFullscreenQuad();
    state.texture = loadTexture2D(config.inputPath);

    configureStyleUniforms(state.program, config.styleName, config.debugMode);

    while (!glfwWindowShouldClose(state.window.handle)) {
        glfwPollEvents();
        renderFrame(state);
        exportFrameIfRequested(state, config);
        glfwSwapBuffers(state.window.handle);
    }
}
