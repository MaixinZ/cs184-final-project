#pragma once

#include <string>

#include "app_types.h"

ImageInfo probeImage(const std::string& path);
Texture2D loadTexture2D(const std::string& path);
void saveFramebufferToPpm(const std::string& path, int width, int height);
void saveFramebufferRegionToPpm(const std::string& path, int x, int y, int width, int height);
