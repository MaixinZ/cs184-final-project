#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <iostream>

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


GLuint compileShader(GLenum type, const char* src)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader,1,&src,nullptr);
    glCompileShader(shader);
    return shader;
}

GLuint createProgram()
{
    GLuint vs = compileShader(GL_VERTEX_SHADER,vertexShaderSource);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER,fragmentShaderSource);

    GLuint program = glCreateProgram();
    glAttachShader(program,vs);
    glAttachShader(program,fs);
    glLinkProgram(program);

    glDeleteShader(vs);
    glDeleteShader(fs);

    return program;
}

int main()
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
    unsigned char* data = stbi_load("profile.png",&width,&height,&channels,0);

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

    while(!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(program);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D,texture);

        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES,0,6);

        glfwSwapBuffers(window);
    }

    glfwTerminate();
}