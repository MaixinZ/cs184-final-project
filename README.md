# Image Stylization Viewer (OpenGL)

A small OpenGL application that loads a single image, draws it as a full-screen textured quad, and applies one of several **fragment shaders** in real time. It is intended for experimenting with painterly, ink-wash, and pixel-art looks for a graphics course project.

## Features

- **Multiple styles** via embedded GLSL fragment shaders: painterly, grayscale, Chinese ink–style painterly, pixel art, and a passthrough “original” view.
- **Runtime switching** with number keys.
- **Optional startup shader** via command-line index.
- **Frame export**: press **P** to save the current framebuffer as a numbered **PNG** in the working directory (see [Saving images](#saving-images)).

## Requirements

- **C++17** (or newer) compiler
- **OpenGL 3.3 Core** context
- **GLFW 3**
- **GLEW**
- **macOS**: `sips` is used to convert a temporary PPM to PNG when you press **P** (available by default on macOS).

The project vendors **stb_image** as `stb_image.h` for loading JPEG/PNG input.

## Building

From the project root (adjust include/library paths if your Homebrew prefix differs):

```bash
g++ -std=c++17 main.cpp -o viewer \
  -I/opt/homebrew/include \
  -L/opt/homebrew/lib \
  -lglfw -lGLEW -framework OpenGL
```

On Intel Macs, Homebrew often uses `/usr/local` instead of `/opt/homebrew`.

## Running

The program expects to find the input image **`a6d288a49638ed480a7854f3ca3205a5.jpg`** in the **current working directory** (same folder from which you launch `./viewer`).

```bash
./viewer # default: first shader (Painterly)
./viewer 4            # start with shader index 4 (PixelArt)
```

### Shader indices

| Index | Name | Description (short)                          |
|------:|--------------------|-----------------------------------------------|
| 0     | Painterly          | Soft blur, warm paper, decorative contours |
| 1     | Original           | Unmodified texture sampling                  |
| 2     | Gray               | Luminance-only                               |
| 3     | ChinesePainterly   | Ink-wash / landscape-inspired stylization    |
| 4     | PixelArt           | Blocky sampling + color quantization           |

### Controls

| Key | Action |
|-----|---------------------------------------------|
| 1–5 | Switch shader (1 = index 0, …, 5 = index 4) |
| P   | Save current frame to `pixelart_capture_N.png` |

Close the window to quit.

## Saving images

When you press **P**, the app reads pixels from the **back buffer** after the current frame is drawn, writes a temporary PPM, then runs **`sips`** to produce **`pixelart_capture_<N>.png`** in the process working directory. Each successful save increments `N`.

If saving fails, check that you are on macOS (or adapt the conversion step) and that the working directory is writable.

## Project layout

| File        | Role |
|------------|------|
| `main.cpp` | Window, texture load, shader programs, render loop, screenshot |
| `stb_image.h` | Image decoding (single-header library) |
| `PixelArt.fx` | Optional **ReShade**-style HLSL for a similar pixel-art pass (not used by `main.cpp`) |
| `a6d288a49638ed480a7854f3ca3205a5.jpg` | Default input image (filename is hardcoded in `main.cpp`) |

## Customizing the input image

Change the path passed to `stbi_load` in `main.cpp` to point at your own image, or rename your file to match the current string and keep the program’s working directory consistent when you run `./viewer`.

## License / third party

- **stb_image** is public domain / permissive; see the header in `stb_image.h` for details.
