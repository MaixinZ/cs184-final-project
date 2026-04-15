#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

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

const char* fragmentShaderSourceChinesePainterly = R"(
#version 330 core
in vec2 uv;
out vec4 FragColor;
uniform sampler2D tex;
void main(){
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));
    vec3 color = texture(tex, uv).rgb;

    // ---- 1. 亮度提取 ----
    float luma = dot(color, vec3(0.299, 0.587, 0.114));

    // ---- 2. 边缘检测（同原版，用于描线） ----
    float lLeft  = dot(texture(tex, uv - vec2(texel.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float lRight = dot(texture(tex, uv + vec2(texel.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float lUp    = dot(texture(tex, uv + vec2(0.0, texel.y)).rgb, vec3(0.299, 0.587, 0.114));
    float lDown  = dot(texture(tex, uv - vec2(0.0, texel.y)).rgb, vec3(0.299, 0.587, 0.114));
    float dx = lRight - lLeft;
    float dy = lUp    - lDown;
    float edge = length(vec2(dx, dy));

    // ---- 3. 宣纸底色 ----
    // 比原版更暖、更黄，加轻微纤维噪点
    float paperNoise = fract(sin(dot(uv * 800.0, vec2(127.1, 311.7))) * 43758.5);
    vec3  paper = vec3(0.97, 0.94, 0.85) + paperNoise * 0.012;

    // ---- 4. 墨色分层：焦浓重淡清 五档 ----
    // 山水画不做连续渐变，而是量化成几个墨色层次
    float darkness = 1.0 - luma;
    float inkLevel;
    if      (darkness < 0.15) inkLevel = 0.00;  // 留白：高亮区域不上墨
    else if (darkness < 0.35) inkLevel = 0.12;  // 清墨：极淡
    else if (darkness < 0.55) inkLevel = 0.32;  // 淡墨
    else if (darkness < 0.75) inkLevel = 0.62;  // 重墨
    else                      inkLevel = 0.88;  // 焦墨：最深

    // 在层级边界加一点 smoothstep 过渡，避免完全硬切
    inkLevel = mix(inkLevel,
                   inkLevel + 0.08,
                   smoothstep(0.0, 0.05, fract(darkness / 0.20)));
    inkLevel = clamp(inkLevel, 0.0, 1.0);

    // ---- 5. 弱笔触墨纹（去除明显方向性斜线） ----
    // 使用各向同性噪点代替正弦斜线，避免暗部出现重复斜纹。
    float washNoise = fract(sin(dot(uv * vec2(350.0, 290.0), vec2(12.9898, 78.233))) * 43758.5453);
    float brushStroke = smoothstep(0.86, 1.00, washNoise) * smoothstep(0.55, 0.95, darkness);
    brushStroke *= 0.08;  // 只保留极轻微墨纹
    brushStroke = clamp(brushStroke, 0.0, 1.0);

    // ---- 6. 墨色定义 ----
    // 山水画的墨不是纯黑，而是带一点冷调的深灰（松烟墨色）
    vec3 ink = vec3(0.08, 0.09, 0.11);

    // ---- 7. 合成：纸 → 墨色渲染 → 笔触 → 边缘线 ----

    // 基础底色：纸 + 墨色分层
    vec3 result = mix(paper, ink, inkLevel * 0.80);

    // 叠加皴法笔触
    result = mix(result, ink, brushStroke * 0.12);

    // 边缘线：山水画轮廓线比素描细、浅，更像"勾勒"而非"描边"
    // 同时加一点飞白：边缘线也不完全实
    float edgeMask = smoothstep(0.06, 0.16, edge);
    float edgeFly  = fract(sin(dot(uv * 500.0, vec2(23.1, 71.5))) * 7919.0);
    edgeMask *= step(0.15, edgeFly);  // 边缘线也有断裂
    result = mix(result, ink * 1.1, edgeMask * 0.75);

    // ---- 8. 留白保护：极亮区域强制还原纸色 ----
    // 山水画的留白是主动设计的，不能被任何效果覆盖
    float highlight = smoothstep(0.80, 0.95, luma);
    result = mix(result, paper, highlight * 0.9);

    FragColor = vec4(result, 1.0);
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


   vec3 c = texture(tex, uv).rgb;


   // Soft painterly blur
   vec3 blur = vec3(0.0);
   blur += texture(tex, uv).rgb * 4.0;
   blur += texture(tex, uv + vec2(texel.x, 0.0)).rgb;
   blur += texture(tex, uv - vec2(texel.x, 0.0)).rgb;
   blur += texture(tex, uv + vec2(0.0, texel.y)).rgb;
   blur += texture(tex, uv - vec2(0.0, texel.y)).rgb;
   blur += texture(tex, uv + texel).rgb;
   blur += texture(tex, uv - texel).rgb;
   blur += texture(tex, uv + vec2(texel.x, -texel.y)).rgb;
   blur += texture(tex, uv + vec2(-texel.x, texel.y)).rgb;
   blur /= 12.0;


   // Blend toward flatter painted masses
   vec3 painter = mix(c, blur, 0.55);


   // Keep much more color than before
   float luma = luminance(painter);
   painter = mix(vec3(luma), painter, 0.88);


   // Warm decorative palette shift:
   // boost reds/oranges slightly, keep greens/blues rich
   painter.r *= 1.10;
   painter.g *= 1.00;
   painter.b *= 0.97;


   // Mild color shaping for flatter ornamental feel
   painter = pow(painter, vec3(0.92));


   // Slight posterization to make regions feel painted
   float levels = 6.0;
   painter = floor(painter * levels) / levels;


   // Edge detection
   float lL = luminance(texture(tex, uv - vec2(texel.x, 0.0)).rgb);
   float lR = luminance(texture(tex, uv + vec2(texel.x, 0.0)).rgb);
   float lU = luminance(texture(tex, uv + vec2(0.0, texel.y)).rgb);
   float lD = luminance(texture(tex, uv - vec2(0.0, texel.y)).rgb);


   float dx = lR - lL;
   float dy = lU - lD;
   float edge = length(vec2(dx, dy));


   // Paper tone like your reference
   vec3 paper = vec3(0.95, 0.88, 0.74);


   // Mix painted image onto warm paper
   vec3 result = mix(paper, painter, 0.92);


   // Decorative contour line: dark brown-gold feel
   vec3 lineColor = vec3(0.42, 0.28, 0.10);
   float lineMask = smoothstep(0.05, 0.16, edge);
   result = mix(result, lineColor, lineMask * 0.55);


   // Add a subtle warm highlight around stronger contours
   vec3 gold = vec3(0.82, 0.68, 0.30);
   float goldMask = smoothstep(0.10, 0.22, edge) * 0.35;
   result = mix(result, gold, goldMask);


   // Very light paper grain
   float grain = fract(sin(dot(uv * vec2(1400.0, 900.0), vec2(12.9898, 78.233))) * 43758.5453);
   result *= 0.985 + 0.03 * grain;


   FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
)";

const char* fragmentShaderSourceOriginal = R"(
#version 330 core
in vec2 uv;
out vec4 FragColor;
uniform sampler2D tex;
void main()
{
    FragColor = texture(tex, uv);
}
)";

const char* fragmentShaderSourceGray = R"(
#version 330 core
in vec2 uv;
out vec4 FragColor;
uniform sampler2D tex;
void main()
{
    vec3 c = texture(tex, uv).rgb;
    float luma = dot(c, vec3(0.299, 0.587, 0.114));
    FragColor = vec4(vec3(luma), 1.0);
}
)";

const char* fragmentShaderSourcePixelArt = R"(
#version 330 core
in vec2 uv;
out vec4 FragColor;
uniform sampler2D tex;
void main()
{
    // 先把采样坐标吸附到固定网格，形成像素块效果
    vec2 texSize = vec2(textureSize(tex, 0));
    float pixelScale = 8.0; // 越大像素块越大
    vec2 pixelGrid = texSize / pixelScale;
    vec2 snappedUV = (floor(uv * pixelGrid) + 0.5) / pixelGrid;

    vec3 c = texture(tex, snappedUV).rgb;

    // 再做颜色量化，让颜色层次更像像素游戏
    float levels = 6.0;
    c = floor(c * levels) / levels;

    // 轻微提升饱和度，让像素风更“干净”
    float luma = dot(c, vec3(0.299, 0.587, 0.114));
    c = mix(vec3(luma), c, 1.2);

    FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
)";


GLuint compileShader(GLenum type, const char* src)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader,1,&src,nullptr);
    glCompileShader(shader);

    GLint ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok)
    {
        char log[512];
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        std::cout << "Shader compile error:\n" << log << "\n";
    }

    return shader;
}

GLuint createProgram(const char* fragmentSource)
{
    GLuint vs = compileShader(GL_VERTEX_SHADER,vertexShaderSource);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER,fragmentSource);

    GLuint program = glCreateProgram();
    glAttachShader(program,vs);
    glAttachShader(program,fs);
    glLinkProgram(program);

    GLint ok = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &ok);
    if (!ok)
    {
        char log[512];
        glGetProgramInfoLog(program, sizeof(log), nullptr, log);
        std::cout << "Program link error:\n" << log << "\n";
    }

    glDeleteShader(vs);
    glDeleteShader(fs);

    return program;
}

bool saveCurrentFramePPM(const std::string& outputPath, int width, int height)
{
    if (width <= 0 || height <= 0)
    {
        return false;
    }

    std::vector<unsigned char> pixels(width * height * 3);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadBuffer(GL_BACK);
    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels.data());

    std::ofstream out(outputPath, std::ios::binary);
    if (!out.is_open())
    {
        return false;
    }

    out << "P6\n" << width << " " << height << "\n255\n";

    // OpenGL 的原点在左下角，PPM 习惯从左上角开始写
    for (int y = height - 1; y >= 0; --y)
    {
        const unsigned char* row = pixels.data() + y * width * 3;
        out.write(reinterpret_cast<const char*>(row), width * 3);
    }

    return out.good();
}

bool saveCurrentFramePNG(const std::string& outputPath, int width, int height, int index)
{
    std::string tempPPM = "pixelart_tmp_" + std::to_string(index) + ".ppm";
    if (!saveCurrentFramePPM(tempPPM, width, height))
    {
        return false;
    }

    std::string command = "sips -s format png \"" + tempPPM + "\" --out \"" + outputPath + "\" > /dev/null 2>&1";
    int ret = std::system(command.c_str());
    std::remove(tempPPM.c_str());

    return ret == 0;
}

int main(int argc, char** argv)
{
    if(!glfwInit())
    {
        std::cout<<"GLFW failed\n";
        return -1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR,3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR,3);
    glfwWindowHint(GLFW_OPENGL_PROFILE,GLFW_OPENGL_CORE_PROFILE);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT,GL_TRUE);
#endif

    GLFWwindow* window = glfwCreateWindow(1280,720,"Viewer",NULL,NULL);

    glfwMakeContextCurrent(window);

    glewExperimental = true;
    glewInit();

    struct ShaderOption
    {
        const char* name;
        const char* source;
        GLuint program;
    };

    std::vector<ShaderOption> shaders =
    {
        {"Painterly", fragmentShaderSource, 0},
        {"Original", fragmentShaderSourceOriginal, 0},
        {"Gray", fragmentShaderSourceGray, 0},
        {"ChinesePainterly", fragmentShaderSourceChinesePainterly, 0},
        {"PixelArt", fragmentShaderSourcePixelArt, 0}
    };

    for (auto& shader : shaders)
    {
        shader.program = createProgram(shader.source);
    }

    int activeShader = 0;
    if (argc > 1)
    {
        int cliShader = std::atoi(argv[1]);
        activeShader = std::clamp(cliShader, 0, (int)shaders.size() - 1);
    }

    std::cout << "Shader options:\n";
    for (int i = 0; i < (int)shaders.size(); ++i)
    {
        std::cout << "  " << i << ": " << shaders[i].name << "\n";
    }
    std::cout << "Run with ./viewer <index> to choose startup shader.\n";
    std::cout << "Press keys 1-" << shaders.size() << " to switch at runtime.\n";
    std::cout << "Press P to save current frame to project folder.\n";
    std::cout << "Current shader: " << shaders[activeShader].name << "\n";

    for (const auto& shader : shaders)
    {
        glUseProgram(shader.program);
        GLint texLoc = glGetUniformLocation(shader.program, "tex");
        if (texLoc >= 0)
        {
            glUniform1i(texLoc, 0);
        }
    }

    float quad[] =
    {
        -1,-1, 0,0,
         1,-1, 1,0,
         1, 1, 1,1,

        -1,-1, 0,0,
         1, 1, 1,1,
        -1, 1, 0,1
    };

    GLuint vao,vbo;
    glGenVertexArrays(1,&vao);
    glGenBuffers(1,&vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,sizeof(quad),quad,GL_STATIC_DRAW);

    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,4*sizeof(float),(void*)0);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1,2,GL_FLOAT,GL_FALSE,4*sizeof(float),(void*)(2*sizeof(float)));
    glEnableVertexAttribArray(1);

    int width,height,channels;

    stbi_set_flip_vertically_on_load(true);
    unsigned char* data = stbi_load("a6d288a49638ed480a7854f3ca3205a5.jpg",&width,&height,&channels,0);

    if(!data)
    {
        std::cout<<"Image failed to load\n";
        return -1;
    }

    GLuint texture;

    glGenTextures(1,&texture);
    glBindTexture(GL_TEXTURE_2D,texture);

    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);

    GLenum format = channels==4 ? GL_RGBA : GL_RGB;

    glTexImage2D(GL_TEXTURE_2D,0,format,width,height,0,format,GL_UNSIGNED_BYTE,data);

    stbi_image_free(data);

    bool saveKeyWasDown = false;
    int captureIndex = 1;
    while(!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        if (glfwGetKey(window, GLFW_KEY_1) == GLFW_PRESS) activeShader = 0;
        if ((int)shaders.size() > 1 && glfwGetKey(window, GLFW_KEY_2) == GLFW_PRESS) activeShader = 1;
        if ((int)shaders.size() > 2 && glfwGetKey(window, GLFW_KEY_3) == GLFW_PRESS) activeShader = 2;
        if ((int)shaders.size() > 3 && glfwGetKey(window, GLFW_KEY_4) == GLFW_PRESS) activeShader = 3;
        if ((int)shaders.size() > 4 && glfwGetKey(window, GLFW_KEY_5) == GLFW_PRESS) activeShader = 4;

        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaders[activeShader].program);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D,texture);

        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES,0,6);

        int saveKeyDown = glfwGetKey(window, GLFW_KEY_P) == GLFW_PRESS;
        if (saveKeyDown && !saveKeyWasDown)
        {
            int fbWidth = 0;
            int fbHeight = 0;
            glfwGetFramebufferSize(window, &fbWidth, &fbHeight);

            std::string fileName = "pixelart_capture_" + std::to_string(captureIndex) + ".png";
            bool ok = saveCurrentFramePNG(fileName, fbWidth, fbHeight, captureIndex);
            captureIndex++;
            if (ok)
            {
                std::cout << "Saved frame to " << fileName << "\n";
            }
            else
            {
                std::cout << "Failed to save frame\n";
            }
        }
        saveKeyWasDown = saveKeyDown;

        glfwSwapBuffers(window);
    }

    for (const auto& shader : shaders)
    {
        glDeleteProgram(shader.program);
    }

    glDeleteTextures(1, &texture);
    glDeleteBuffers(1, &vbo);
    glDeleteVertexArrays(1, &vao);

    glfwTerminate();
}