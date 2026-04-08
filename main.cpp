#include <iostream>
#include <optional>

#include "gui.h"
#include "parse.h"

int main(int argc, char** argv)
{
    try {
        std::optional<AppConfig> maybeConfig = parseArgs(argc, argv);
        if (!maybeConfig.has_value()) {
            return 0;
        }

        runViewer(*maybeConfig);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return -1;
    }

    return 0;
}
