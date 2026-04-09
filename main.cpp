#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>

#include "constant.h"
#include "gui.h"
#include "parse.h"

namespace {

std::string buildShaderPath(const std::string& styleName, const char* extension)
{
    if (styleName.empty()) {
        throw std::runtime_error("Style name cannot be empty.");
    }

    return std::string(constants::kShaderDirectory) + "/" + styleName + extension;
}

void resolveStyleShaders(AppConfig& config)
{
    config.vertexShaderPath = buildShaderPath(config.styleName, ".vert");
    config.fragmentShaderPath = buildShaderPath(config.styleName, ".frag");
}

}  // namespace

int main(int argc, char** argv)
{
    try {
        std::optional<AppConfig> maybeConfig = parseArgs(argc, argv);
        if (!maybeConfig.has_value()) {
            return 0;
        }

        AppConfig config = *maybeConfig;
        resolveStyleShaders(config);
        runViewer(config);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return -1;
    }

    return 0;
}
