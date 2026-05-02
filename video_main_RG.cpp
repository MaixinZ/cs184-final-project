#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <opencv2/opencv.hpp>
#include <iostream>

const char* vertexShaderSource = R"(
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aUV;

out vec2 uv;

void main()
{
    uv = aUV;
    gl_Position = vec4(aPos, 0.0, 1.0);
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

vec3 assistRG(vec3 c)
{
    float rStrength = c.r - max(c.g, c.b);
    float gStrength = c.g - max(c.r, c.b);

    float redMask = smoothstep(0.04, 0.22, rStrength);
    float greenMask = smoothstep(0.04, 0.22, gStrength);

    float luma = luminance(c);

    // Push red-dominant areas toward yellow/orange.
    // Yellow is more distinguishable than red/green for dichromats.
    vec3 redTarget = vec3(
        min(c.r * 1.08 + 0.12, 1.0),
        min(c.g * 0.75 + 0.32, 1.0),
        c.b * 0.45
    );

    // Push green-dominant areas toward blue/cyan.
    // Blue is separated from yellow on a more visible axis.
    vec3 greenTarget = vec3(
        c.r * 0.45,
        min(c.g * 0.85 + 0.05, 1.0),
        min(c.b * 1.25 + 0.35, 1.0)
    );

    // Preserve luminance so objects do not become unnaturally bright/dark.
    redTarget *= luma / max(luminance(redTarget), 0.001);
    greenTarget *= luma / max(luminance(greenTarget), 0.001);

    vec3 outColor = c;
    outColor = mix(outColor, redTarget, redMask * 0.85);
    outColor = mix(outColor, greenTarget, greenMask * 0.85);

    return clamp(outColor, 0.0, 1.0);
}

void main()
{
    vec3 c = texture(tex, uv).rgb;
    vec3 result = assistRG(c);
    FragColor = vec4(result, 1.0);
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

    GLFWwindow* window = glfwCreateWindow(1280, 720, "Video Viewer", NULL, NULL);
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
        return -1;
    }

    GLuint program = createProgram();

    float quad[] =
    {
        -1,-1, 0,0,
         1,-1, 1,0,
         1, 1, 1,1,

        -1,-1, 0,0,
         1, 1, 1,1,
        -1, 1, 0,1
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

    cv::VideoCapture cap("video_demo.mov");
    if (!cap.isOpened())
    {
        std::cout << "Video failed to open\n";
        return -1;
    }

    cv::Mat frame;
    if (!cap.read(frame))
    {
        std::cout << "Failed to read first frame\n";
        return -1;
    }

    cv::cvtColor(frame, frame, cv::COLOR_BGR2RGB);
    cv::flip(frame, frame, 0);

    int width = frame.cols;
    int height = frame.rows;
    int channels = frame.channels();

    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    GLenum format = channels == 4 ? GL_RGBA : GL_RGB;

    glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0,
                 format, GL_UNSIGNED_BYTE, frame.data);

    glUseProgram(program);
    glUniform1i(glGetUniformLocation(program, "tex"), 0);

    bool isPlaying = false;
    bool spacePressedLastFrame = false;

    double fps = cap.get(cv::CAP_PROP_FPS);
    double frameTime = 1.0 / fps;
    double lastFrameSwitch = glfwGetTime();

    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        bool spacePressedNow = glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS;
        if (spacePressedNow && !spacePressedLastFrame)
        {
            isPlaying = !isPlaying;
        }
        spacePressedLastFrame = spacePressedNow;

        double now = glfwGetTime();

        if (isPlaying && now - lastFrameSwitch >= frameTime)
        {
            if (!cap.read(frame))
                break;

            cv::cvtColor(frame, frame, cv::COLOR_BGR2RGB);
            cv::flip(frame, frame, 0);

            glBindTexture(GL_TEXTURE_2D, texture);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height,
                            format, GL_UNSIGNED_BYTE, frame.data);

            lastFrameSwitch = now;
        }

        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(program);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glfwSwapBuffers(window);
    }
    cap.release();
    glfwTerminate();
    return 0;
}