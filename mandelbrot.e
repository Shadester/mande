OPT MODULE
OPT PREPROCESS

MODULE 'intuition/intuition','graphics/graphics'

PROC WaitLeftClick(win:PTR TO Window)
    DEF msg:PTR TO IntuiMessage
    REPEAT
        WaitPort(win.UserPort)
        msg := GetMsg(win.UserPort)
        IF msg <> NIL THEN
            IF msg.Class = IDCMP_MOUSEBUTTONS THEN
                ReplyMsg(msg)
                RETURN
            ENDIF
            ReplyMsg(msg)
        ENDIF
    UNTIL FALSE
ENDPROC

PROC main()
    DEF win:PTR TO Window
    DEF rp:PTR TO RastPort
    DEF x,y,iteration
    DEF zx, zy, cx, cy, temp

    win := OpenWindowTagList(NIL,
        [WA_Left,0, WA_Top,0,
         WA_Width,320, WA_Height,256,
         WA_IDCMP,IDCMP_MOUSEBUTTONS,
         WA_Flags,WFLG_SIMPLE_REFRESH|WFLG_SMART_REFRESH|WFLG_DRAGBAR|WFLG_DEPTHGADGET|WFLG_CLOSEGADGET,
         WA_Title,"Mandelbrot",TAG_END])

    IF win = NIL THEN RETURN
    rp := win.rport

    y := 0
    WHILE y < 256 DO
        cy := (y-128.0)/128.0*1.5
        x := 0
        WHILE x < 320 DO
            cx := (x-160.0)/160.0*2.0-0.5
            zx := 0.0
            zy := 0.0
            iteration := 0
            WHILE (zx*zx + zy*zy <= 4.0) AND (iteration < 255) DO
                temp := zx*zx - zy*zy + cx
                zy := 2.0*zx*zy + cy
                zx := temp
                iteration++
            ENDWHILE
            SetAPen(rp, iteration)
            WritePixel(rp, x, y)
            x++
        ENDWHILE
        y++
    ENDWHILE

    WaitLeftClick(win)
    CloseWindow(win)
ENDPROC
