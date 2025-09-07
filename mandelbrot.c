#include <exec/types.h>
#include <exec/memory.h>
#include <intuition/intuition.h>
#include <graphics/gfx.h>
#include <graphics/displayinfo.h>
#include <proto/exec.h>
#include <proto/intuition.h>
#include <proto/graphics.h>
#include <proto/dos.h>

#define WIDTH 640
#define HEIGHT 512

static void write_long(BPTR fh, ULONG value) {
    UBYTE buf[4];
    buf[0] = value >> 24;
    buf[1] = value >> 16;
    buf[2] = value >> 8;
    buf[3] = value;
    Write(fh, buf, 4);
}

static void draw_box(struct RastPort *rp, WORD x1, WORD y1, WORD x2, WORD y2) {
    Move(rp, x1, y1); Draw(rp, x2, y1);
    Draw(rp, x2, y2); Draw(rp, x1, y2);
    Draw(rp, x1, y1);
}

static void render(struct RastPort *rp, UBYTE *data, double xmin, double xmax, double ymin, double ymax) {
    double dx = (xmax - xmin) / WIDTH;
    double dy = (ymax - ymin) / HEIGHT;
    for (WORD y = 0; y < HEIGHT; y++) {
        double cy = ymin + y * dy;
        for (WORD x = 0; x < WIDTH; x++) {
            double cx = xmin + x * dx;
            double zx = 0.0, zy = 0.0;
            UBYTE iteration = 0;
            while ((zx * zx + zy * zy <= 4.0) && (iteration < 255)) {
                double temp = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = temp;
                iteration++;
            }
            data[y * WIDTH + x] = iteration;
            SetAPen(rp, iteration);
            WritePixel(rp, x, y);
        }
    }
}

static void save_iff(const char *filename, UBYTE *data, UBYTE *palette) {
    LONG widthBytes = WIDTH / 8;
    LONG planeSize = widthBytes * HEIGHT;
    UBYTE *planes = AllocMem(planeSize * 8, MEMF_ANY | MEMF_CLEAR);
    if (!planes) return;

    for (LONG y = 0; y < HEIGHT; y++) {
        for (LONG x = 0; x < WIDTH; x++) {
            UBYTE pix = data[y * WIDTH + x];
            LONG byteIndex = y * widthBytes + (x >> 3);
            UBYTE bit = 7 - (x & 7);
            for (UBYTE b = 0; b < 8; b++) {
                if ((pix >> b) & 1) {
                    planes[b * planeSize + byteIndex] |= (1 << bit);
                }
            }
        }
    }

    ULONG bodySize = planeSize * 8;
    ULONG formSize = 4 + (8 + 20) + (8 + 768) + (8 + bodySize);

    BPTR fh = Open(filename, MODE_NEWFILE);
    if (fh) {
        Write(fh, "FORM", 4);
        write_long(fh, formSize);
        Write(fh, "ILBM", 4);

        Write(fh, "BMHD", 4);
        write_long(fh, 20);
        UBYTE bmhd[20] = {0};
        bmhd[0] = WIDTH >> 8;
        bmhd[1] = WIDTH & 0xFF;
        bmhd[2] = HEIGHT >> 8;
        bmhd[3] = HEIGHT & 0xFF;
        bmhd[8] = 8;
        Write(fh, bmhd, 20);

        Write(fh, "CMAP", 4);
        write_long(fh, 768);
        Write(fh, palette, 768);

        Write(fh, "BODY", 4);
        write_long(fh, bodySize);
        for (LONG y = 0; y < HEIGHT; y++) {
            for (UBYTE b = 0; b < 8; b++) {
                Write(fh, planes + b * planeSize + y * widthBytes, widthBytes);
            }
        }
        Close(fh);
    }

    FreeMem(planes, planeSize * 8);
}

int main() {
    struct Screen *screen;
    struct Window *win;
    struct RastPort *rp;
    struct Menu *menu = NULL;
    UBYTE *data;
    UBYTE colors[256 * 3];
    BOOL done = FALSE;
    double xmin = -2.5, xmax = 1.0, ymin = -1.5, ymax = 1.5;

    screen = OpenScreenTags(NULL,
        SA_Width, WIDTH,
        SA_Height, HEIGHT,
        SA_Depth, 8,
        SA_DisplayID, HIRESLACE_KEY,
        TAG_END);
    if (!screen) return 0;

    for (ULONG i = 0; i < 256; i++) {
        SetRGB32(&screen->ViewPort, i, i << 24, i << 24, i << 24);
        colors[i * 3] = colors[i * 3 + 1] = colors[i * 3 + 2] = (UBYTE)i;
    }

    struct NewMenu newmenu[] = {
        { NM_TITLE, "Project", 0, 0, 0, NULL },
        { NM_ITEM, "Save", 'S', 0, 0, NULL },
        { NM_ITEM, "Quit", 'Q', 0, 0, NULL },
        { NM_END, NULL, 0, 0, 0, NULL }
    };

    menu = CreateMenus(newmenu, TAG_END);

    win = OpenWindowTags(NULL,
        WA_CustomScreen, screen,
        WA_Left, 0,
        WA_Top, 0,
        WA_Width, WIDTH,
        WA_Height, HEIGHT,
        WA_IDCMP, IDCMP_MOUSEBUTTONS | IDCMP_MOUSEMOVE | IDCMP_MENUPICK | IDCMP_CLOSEWINDOW,
        WA_Flags, WFLG_DRAGBAR | WFLG_DEPTHGADGET | WFLG_CLOSEGADGET | WFLG_SMART_REFRESH,
        WA_Title, (ULONG)"Mandelbrot",
        TAG_END);
    if (!win) {
        CloseScreen(screen);
        return 0;
    }

    if (menu) {
        LayoutMenus(menu, NULL, TAG_END);
        SetMenuStrip(win, menu);
    }

    rp = win->RPort;
    data = AllocMem(WIDTH * HEIGHT, MEMF_ANY);
    if (!data) {
        CloseWindow(win);
        CloseScreen(screen);
        return 0;
    }

    render(rp, data, xmin, xmax, ymin, ymax);

    WORD startX = 0, startY = 0, lastX = 0, lastY = 0;
    BOOL selecting = FALSE;

    while (!done) {
        WaitPort(win->UserPort);
        struct IntuiMessage *msg;
        while ((msg = (struct IntuiMessage *)GetMsg(win->UserPort))) {
            switch (msg->Class) {
                case IDCMP_MOUSEBUTTONS:
                    if (msg->Code == SELECTDOWN) {
                        selecting = TRUE;
                        startX = msg->MouseX;
                        startY = msg->MouseY;
                        lastX = startX;
                        lastY = startY;
                        SetDrMd(rp, COMPLEMENT);
                    } else if (msg->Code == SELECTUP && selecting) {
                        draw_box(rp, startX, startY, lastX, lastY);
                        SetDrMd(rp, JAM1);
                        selecting = FALSE;
                        WORD endX = msg->MouseX;
                        WORD endY = msg->MouseY;
                        if (startX != endX && startY != endY) {
                            double x1 = xmin + startX * (xmax - xmin) / WIDTH;
                            double x2 = xmin + endX * (xmax - xmin) / WIDTH;
                            double y1 = ymin + startY * (ymax - ymin) / HEIGHT;
                            double y2 = ymin + endY * (ymax - ymin) / HEIGHT;
                            if (x1 < x2) { xmin = x1; xmax = x2; } else { xmin = x2; xmax = x1; }
                            if (y1 < y2) { ymin = y1; ymax = y2; } else { ymin = y2; ymax = y1; }
                            render(rp, data, xmin, xmax, ymin, ymax);
                        }
                    }
                    break;
                case IDCMP_MOUSEMOVE:
                    if (selecting) {
                        draw_box(rp, startX, startY, lastX, lastY);
                        lastX = msg->MouseX;
                        lastY = msg->MouseY;
                        draw_box(rp, startX, startY, lastX, lastY);
                    }
                    break;
                case IDCMP_MENUPICK: {
                    LONG code = msg->Code;
                    while (code != MENUNULL) {
                        struct MenuItem *item = ItemAddress(menu, code);
                        if (item->MenuNum == 0 && item->ItemNum == 0) {
                            save_iff("mandel.iff", data, colors);
                        } else if (item->MenuNum == 0 && item->ItemNum == 1) {
                            done = TRUE;
                        }
                        code = item->NextSelect;
                    }
                    break; }
                case IDCMP_CLOSEWINDOW:
                    done = TRUE;
                    break;
            }
            ReplyMsg((struct Message *)msg);
        }
    }

    if (menu) {
        ClearMenuStrip(win);
        FreeMenus(menu);
    }
    FreeMem(data, WIDTH * HEIGHT);
    CloseWindow(win);
    CloseScreen(screen);
    return 0;
}

