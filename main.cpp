#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <vector>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

const char* vertexShaderSource = R"(
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aUV;

out vec2 uv;

void main()
{
    uv = aUV;
    gl_Position = vec4(aPos,0.0,1.0);
}
)";

const char* fragmentShaderSource = R"(
#version 330 core

in vec2 uv;
out vec4 FragColor;

uniform sampler2D tex;

float luminance(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main()
{
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));

    vec3 c  = texture(tex, uv).rgb;
    float baseLuma = luminance(c);

    // 3x3 neighborhood
    vec3 cL  = texture(tex, uv - vec2(texel.x, 0.0)).rgb;
    vec3 cR  = texture(tex, uv + vec2(texel.x, 0.0)).rgb;
    vec3 cU  = texture(tex, uv + vec2(0.0, texel.y)).rgb;
    vec3 cD  = texture(tex, uv - vec2(0.0, texel.y)).rgb;
    vec3 cUL = texture(tex, uv + vec2(-texel.x, texel.y)).rgb;
    vec3 cUR = texture(tex, uv + vec2(texel.x, texel.y)).rgb;
    vec3 cDL = texture(tex, uv + vec2(-texel.x, -texel.y)).rgb;
    vec3 cDR = texture(tex, uv + vec2(texel.x, -texel.y)).rgb;

    // Soft blur
    vec3 blur = vec3(0.0);
    blur += c * 4.0;
    blur += cL + cR + cU + cD;
    blur += cUL + cUR + cDL + cDR;
    blur /= 12.0;

    // Estimate local contrast so detailed areas blur less
    float lL  = luminance(cL);
    float lR  = luminance(cR);
    float lU  = luminance(cU);
    float lD  = luminance(cD);
    float lUL = luminance(cUL);
    float lUR = luminance(cUR);
    float lDL = luminance(cDL);
    float lDR = luminance(cDR);

    float localMin = min(min(min(lL, lR), min(lU, lD)), min(min(lUL, lUR), min(lDL, lDR)));
    float localMax = max(max(max(lL, lR), max(lU, lD)), max(max(lUL, lUR), max(lDL, lDR)));
    float localContrast = localMax - localMin;

    // Less blur in shadows and in high-contrast areas
    float shadowProtect = 1.0 - smoothstep(0.08, 0.30, baseLuma);   // high in dark regions
    float contrastProtect = smoothstep(0.03, 0.09, localContrast);  // high near detailed structure

    float blurAmount = 0.55;
    blurAmount *= (1.0 - 0.65 * shadowProtect);
    blurAmount *= (1.0 - 0.50 * contrastProtect);
    blurAmount = clamp(blurAmount, 0.10, 0.55);

    vec3 painter = mix(c, blur, blurAmount);

    // Preserve more chroma
    float luma = luminance(painter);
    painter = mix(vec3(luma), painter, 0.90);

    // Warm palette shift
    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;

    painter = pow(painter, vec3(0.92));

    // Dark-area contrast lift: prevents blacks from collapsing together
    float shadowLift = smoothstep(0.00, 0.22, baseLuma);
    vec3 lifted = mix(painter * 1.18, painter, shadowLift);
    painter = mix(lifted, painter, 0.35); // subtle, not too washed out

    // Less posterization in shadows
    float levelsDark = 10.0;
    float levelsBright = 6.0;
    float levels = mix(levelsDark, levelsBright, smoothstep(0.08, 0.45, baseLuma));
    painter = floor(painter * levels) / levels;

    // Edge detection
    float dx = lR - lL;
    float dy = lU - lD;
    float edge = length(vec2(dx, dy));

    // Boost edge response slightly in dark regions
    edge *= mix(1.6, 1.0, smoothstep(0.05, 0.35, baseLuma));

    vec3 paper = vec3(0.95, 0.88, 0.74);
    vec3 result = mix(paper, painter, 0.92);

    edge *= 1.1;

    vec3 lineColor = vec3(0.42, 0.28, 0.10);
    float lineMask = smoothstep(0.035, 0.12, edge);
    result = mix(result, lineColor, lineMask * 0.72);

    vec3 gold = vec3(0.82, 0.68, 0.30);
    float goldMask = smoothstep(0.09, 0.20, edge) * 0.28;
    result = mix(result, gold, goldMask);

    // Very light paper grain
    float grain = fract(sin(dot(uv * vec2(1400.0, 900.0), vec2(12.9898, 78.233))) * 43758.5453);
    result *= 0.985 + 0.03 * grain;

    FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
)";


GLuint compileShader(GLenum type, const char* src)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    return shader;
}

GLuint createProgram()
{
    GLuint vs = compileShader(GL_VERTEX_SHADER, vertexShaderSource);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, fragmentShaderSource);

    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    glDeleteShader(vs);
    glDeleteShader(fs);

    return program;
}

void saveScreenshot(const char* filename, int width, int height)
{
    std::vector<unsigned char> pixels(width * height * 3);

    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels.data());

    // Flip vertically because OpenGL's origin is bottom-left
    for (int y = 0; y < height / 2; y++) {
        for (int x = 0; x < width * 3; x++) {
            std::swap(
                pixels[y * width * 3 + x],
                pixels[(height - 1 - y) * width * 3 + x]
            );
        }
    }

    stbi_write_png(filename, width, height, 3, pixels.data(), width * 3);
}

int main()
{
    if (!glfwInit())
    {
        std::cout << "GLFW failed\n";
        return -1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    GLFWwindow* window = glfwCreateWindow(1280, 720, "Viewer", NULL, NULL);
    if (!window)
    {
        std::cout << "Window creation failed\n";
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);

    glewExperimental = true;
    if (glewInit() != GLEW_OK)
    {
        std::cout << "GLEW failed\n";
        glfwTerminate();
        return -1;
    }

    GLuint program = createProgram();

    float quad[] =
    {
        -1, -1, 0, 0,
         1, -1, 1, 0,
         1,  1, 1, 1,

        -1, -1, 0, 0,
         1,  1, 1, 1,
        -1,  1, 0, 1
    };

    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    int imgWidth, imgHeight, channels;

    stbi_set_flip_vertically_on_load(true);
    unsigned char* data = stbi_load("demo.jpg", &imgWidth, &imgHeight, &channels, 0);

    if (!data)
    {
        std::cout << "Image failed to load\n";
        glfwTerminate();
        return -1;
    }

    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    GLenum format = (channels == 4) ? GL_RGBA : GL_RGB;
    glTexImage2D(GL_TEXTURE_2D, 0, format, imgWidth, imgHeight, 0, format, GL_UNSIGNED_BYTE, data);

    stbi_image_free(data);

    glUseProgram(program);
    glUniform1i(glGetUniformLocation(program, "tex"), 0);

    bool saved = false;

    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(program);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texture);

        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        if (!saved) {
            int fbWidth, fbHeight;
            glfwGetFramebufferSize(window, &fbWidth, &fbHeight);
            saveScreenshot("output.png", fbWidth, fbHeight);
            saved = true;
        }

        glfwSwapBuffers(window);
    }

    glfwTerminate();
    return 0;
}