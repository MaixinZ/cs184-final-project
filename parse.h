#pragma once

#include <optional>
#include <string>

#include "app_types.h"

std::string usage(const char* executable);
std::optional<AppConfig> parseArgs(int argc, char** argv);
