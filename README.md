This project contains an interactive Mandelbrot viewer for AmigaOS written in ANSI C. It opens a 640×512 8-bit screen, lets you zoom by dragging a rectangle, and provides a menu item to save the current view as an IFF ILBM image.

## Build

The code can be cross-compiled with [vbcc](http://www.compilers.de/vbcc/). A Docker image is provided so the compiler does not need to be installed locally.

### Build with Docker

To compile the program using vbcc inside Docker:

```
docker build -t mandelbrot-c .
docker run --rm -v "$PWD:/src" mandelbrot-c
```

Running the container writes the `Mandelbrot` binary to the repository directory. Copy this binary to an Amiga system or emulator to run it.

## Usage

Launch `Mandelbrot` on your Amiga. Drag with the left mouse button to select a zoom area. Use the **Project → Save** menu item to write `mandel.iff` and **Project → Quit** or the close gadget to exit.
