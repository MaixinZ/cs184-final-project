#include "parse.h"

#include <iostream>
#include <stdexcept>

#include "constant.h"

namespace {

bool hasPpmExtension(const std::string& path)
{
    return path.size() >= 4 && path.substr(path.size() - 4) == ".ppm";
}

int parsePositiveInt(const std::string& value, const char* flag)
{
    try {
        const int parsed = std::stoi(value);
        if (parsed <= 0) {
            throw std::runtime_error("");
        }
        return parsed;
    } catch (...) {
        throw std::runtime_error(std::string(flag) + " expects a positive integer.");
    }
}

int parseDebugMode(const std::string& value)
{
    if (value == "final") {
        return constants::kDebugFinal;
    }
    if (value == "ndotl") {
        return constants::kDebugNdotL;
    }
    if (value == "band") {
        return constants::kDebugBand;
    }
    if (value == "shadow") {
        return constants::kDebugShadow;
    }
    if (value == "rim") {
        return constants::kDebugRim;
    }
    if (value == "outline") {
        return constants::kDebugOutline;
    }
    if (value == "fog") {
        return constants::kDebugFog;
    }

    throw std::runtime_error("Unknown debug mode: " + value);
}

}  // namespace

std::string usage(const char* executable)
{
    return std::string("Usage: ") + executable +
           " [input_path] [output_path.ppm] [--input path] [--output path.ppm] [--vert shader.vert] [--frag shader.frag]\n"
           "       [--debug final|ndotl|band|shadow|rim|outline|fog] [--width pixels] [--height pixels]\n"
           "If --output is provided, the first rendered frame is saved as a PPM image and the program exits.\n"
           "Hotkeys: 1 split compare, 2 original only, 3 shaded only, Tab toggle split/single, S or Space toggle shading.\n";
}

std::optional<AppConfig> parseArgs(int argc, char** argv)
{
    AppConfig config;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];

        if (arg == "--help" || arg == "-h") {
            std::cout << usage(argv[0]);
            return std::nullopt;
        }

        auto readValue = [&](const char* flag) -> std::string {
            if (i + 1 >= argc) {
                throw std::runtime_error(std::string("Missing value for ") + flag + ".");
            }
            return argv[++i];
        };

        if (arg == "--input") {
            config.inputPath = readValue("--input");
            continue;
        }

        if (arg == "--output") {
            config.outputPath = readValue("--output");
            continue;
        }

        if (arg == "--vert") {
            config.vertexShaderPath = readValue("--vert");
            continue;
        }

        if (arg == "--frag") {
            config.fragmentShaderPath = readValue("--frag");
            continue;
        }

        if (arg == "--debug") {
            config.debugMode = parseDebugMode(readValue("--debug"));
            continue;
        }

        if (arg == "--width") {
            config.windowWidth = parsePositiveInt(readValue("--width"), "--width");
            config.sizeSpecified = true;
            continue;
        }

        if (arg == "--height") {
            config.windowHeight = parsePositiveInt(readValue("--height"), "--height");
            config.sizeSpecified = true;
            continue;
        }

        if (!arg.empty() && arg[0] == '-') {
            throw std::runtime_error("Unknown flag: " + arg + "\n" + usage(argv[0]));
        }

        if (config.inputPath == constants::kDefaultInputPath) {
            config.inputPath = arg;
            continue;
        }

        if (config.outputPath.empty()) {
            config.outputPath = arg;
            continue;
        }

        throw std::runtime_error("Too many positional arguments.\n" + usage(argv[0]));
    }

    if (config.shouldExport() && !hasPpmExtension(config.outputPath)) {
        throw std::runtime_error("Output path must end with .ppm.");
    }

    return config;
}
