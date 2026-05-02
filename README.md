# Oil Paint Shader

An OpenGL fragment shader that creates an oil-paint style effect from a source demo image. The code can be used as a local tester for shading effect. 
The files also include a video shader with the same fragment shading effect applying to the demo video taken from Cyberpunk 2077 trailor video. 

## What the shader does
- applies a soft 3×3 blur
- reduces blur in dark and high-contrast regions
- preserves color saturation
- adds a warm color shift
- lifts shadow detail
- adds mild posterization
- detects edges and overlays dark brown / gold lines
- blends the result with a paper-like background and light grain

---

## Build and Run

### Requirements
- OpenGL (3.3+)
- C++ compiler (g++ / clang)

### Compile

```bash
clang++ main.cpp -std=c++17 \
-I/opt/homebrew/include \
-L/opt/homebrew/lib \
-lglfw -lGLEW \
-framework OpenGL \
-framework Cocoa \
-framework IOKit \
-framework CoreVideo \
-o viewer
```

### Run
```bash
./viewer
```

