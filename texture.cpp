#include "texture.h"

#include <fstream>
#include <stdexcept>
#include <vector>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

namespace {

GLenum textureFormatFromChannels(int channels)
{
    switch (channels) {
        case 1:
            return GL_RED;
        case 2:
            return GL_RG;
        case 3:
            return GL_RGB;
        case 4:
            return GL_RGBA;
        default:
            throw std::runtime_error("Unsupported image channel count.");
    }
}

}  // namespace

ImageInfo probeImage(const std::string& path)
{
    ImageInfo image;
    if (!stbi_info(path.c_str(), &image.width, &image.height, &image.channels)) {
        throw std::runtime_error("Failed to read image info: " + path);
    }
    return image;
}

Texture2D loadTexture2D(const std::string& path)
{
    stbi_set_flip_vertically_on_load(true);

    Texture2D texture;
    int channels = 0;
    unsigned char* data = stbi_load(path.c_str(), &texture.width, &texture.height, &channels, 0);
    if (data == nullptr) {
        throw std::runtime_error("Image failed to load: " + path);
    }

    texture.format = textureFormatFromChannels(channels);

    glGenTextures(1, &texture.id);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(
        GL_TEXTURE_2D,
        0,
        static_cast<GLint>(texture.format),
        texture.width,
        texture.height,
        0,
        texture.format,
        GL_UNSIGNED_BYTE,
        data
    );

    stbi_image_free(data);
    return texture;
}

void saveFramebufferRegionToPpm(const std::string& path, int x, int y, int width, int height)
{
    std::vector<unsigned char> pixels(static_cast<size_t>(width) * static_cast<size_t>(height) * 3U);

    glFinish();
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadBuffer(GL_BACK);
    glReadPixels(x, y, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels.data());

    std::ofstream output(path, std::ios::binary);
    if (!output) {
        throw std::runtime_error("Failed to open output file: " + path);
    }

    output << "P6\n" << width << ' ' << height << "\n255\n";
    for (int y = height - 1; y >= 0; --y) {
        const auto* row = reinterpret_cast<const char*>(
            pixels.data() + static_cast<size_t>(y) * static_cast<size_t>(width) * 3U
        );
        output.write(row, static_cast<std::streamsize>(width * 3));
    }
}

void saveFramebufferToPpm(const std::string& path, int width, int height)
{
    saveFramebufferRegionToPpm(path, 0, 0, width, height);
}
