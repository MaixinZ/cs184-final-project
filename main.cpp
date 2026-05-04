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

float rand(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float brushNoise(vec2 uv)
{
    // Divide into cells (each cell has its own stroke direction)
    vec2 cell = floor(uv * vec2(20.0, 20.0));

    // Random angle per cell
    float angle = rand(cell) * 6.2831; // 0 to 2π
    vec2 dir = vec2(cos(angle), sin(angle));

    // Project uv onto this random direction
    float proj = dot(uv * 8.0, dir);

    // Broken stroke (not continuous)
    float stroke = sin(proj * 40.0 + rand(cell + 3.7) * 6.2831);

    // Add secondary noise to break uniformity
    float variation = rand(cell + floor(uv * 100.0));

    stroke = mix(stroke, variation * 2.0 - 1.0, 0.4);

    return 0.5 + 0.5 * stroke;
}

void main()
{
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));

    vec3 c = texture(tex, uv).rgb;
    float baseLuma = luminance(c);

    vec3 blur = vec3(0.0);
    float totalWeight = 0.0;

    for (int x = -4; x <= 4; x++)
    {
        for (int y = -4; y <= 4; y++)
        {
            vec2 offset = vec2(float(x), float(y)) * texel;
            vec3 sampleColor = texture(tex, uv + offset).rgb;

            float dist = length(vec2(float(x), float(y)));
            float spatialWeight = exp(-(dist * dist) / 30.0);

            float colorDiff = length(sampleColor - c);
            float colorWeight = exp(-(colorDiff * colorDiff) / 0.30);

            float weight = spatialWeight * colorWeight;

            blur += sampleColor * weight;
            totalWeight += weight;
        }
    }

    blur /= totalWeight;

    vec3 painter = blur;

    float levelsDark = 10.0;
    float levelsBright = 4.0;
    float levels = mix(levelsDark, levelsBright, smoothstep(0.08, 0.45, baseLuma));
    painter = floor(painter * levels) / levels;

    float stroke = brushNoise(uv);

    // subtle modulation
    painter *= 0.97 + 0.06 * stroke;

    FragColor = vec4(clamp(painter, 0.0, 1.0), 1.0);
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