This is a Mandelbrot program in Amiga E or EVO for AmigaOS 3.1.
It renders in 640×512 AGA hi-res lace with 256 colours and supports interactive zooming
and saving the image as an uncompressed 8-bit ILBM (IFF) file.

## Build

Compile with the Amiga E compiler:

```
ec mandelbrot.e -o Mandelbrot
```

Run the resulting executable on an AGA-capable AmigaOS 3.1 machine. Drag with the left
mouse button to select an area and zoom. Press `s` to save the current view to
`mandel.iff` or press `Esc` or any other mouse button to exit.
