CXX ?= clang++

RELEASE_TARGET := viewer
DEBUG_TARGET := viewer_debug
RELEASE_BUILD_DIR := build/release
DEBUG_BUILD_DIR := build/debug

BREW_PREFIX ?= /opt/homebrew

SOURCES := main.cpp parse.cpp synth.cpp gui.cpp texture.cpp constant.cpp

CPPFLAGS += -I. -I$(BREW_PREFIX)/include
COMMON_CXXFLAGS += -std=c++17 -Wall -Wextra -Wpedantic -MMD -MP
RELEASE_CXXFLAGS := $(COMMON_CXXFLAGS) -O2
DEBUG_CXXFLAGS := $(COMMON_CXXFLAGS) -O0 -g3
LDFLAGS += -L$(BREW_PREFIX)/lib
LDLIBS += -lglfw -lGLEW \
	-framework OpenGL \
	-framework Cocoa \
	-framework IOKit \
	-framework CoreVideo

RELEASE_OBJECTS := $(SOURCES:%.cpp=$(RELEASE_BUILD_DIR)/%.o)
DEBUG_OBJECTS := $(SOURCES:%.cpp=$(DEBUG_BUILD_DIR)/%.o)
RELEASE_DEPS := $(RELEASE_OBJECTS:.o=.d)
DEBUG_DEPS := $(DEBUG_OBJECTS:.o=.d)

.PHONY: all release debug run run-debug clean help view

all: release

release: $(RELEASE_TARGET)

debug: $(DEBUG_TARGET)

view: release

run: release
	./$(RELEASE_TARGET) $(ARGS)

run-debug: debug
	./$(DEBUG_TARGET) $(ARGS)

help:
	@echo "Targets:"
	@echo "  make release    Build optimized viewer"
	@echo "  make debug      Build debug viewer_debug"
	@echo "  make run        Build and run viewer, pass ARGS=\"...\""
	@echo "  make run-debug  Build and run viewer_debug"
	@echo "  make clean      Remove build artifacts"

$(RELEASE_TARGET): $(RELEASE_OBJECTS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(DEBUG_TARGET): $(DEBUG_OBJECTS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(RELEASE_BUILD_DIR) $(DEBUG_BUILD_DIR):
	mkdir -p $@

$(RELEASE_BUILD_DIR)/%.o: %.cpp | $(RELEASE_BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(RELEASE_CXXFLAGS) -c $< -o $@

$(DEBUG_BUILD_DIR)/%.o: %.cpp | $(DEBUG_BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(DEBUG_CXXFLAGS) -c $< -o $@

clean:
	rm -rf build $(RELEASE_TARGET) $(DEBUG_TARGET)

-include $(RELEASE_DEPS) $(DEBUG_DEPS)
