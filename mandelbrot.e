OPT MODULE
OPT PREPROCESS

MODULE 'intuition/intuition','graphics/graphics','graphics/displayinfo','exec/memory','dos/dos'

CONST WIDTH=640, HEIGHT=512

PROC WriteLong(fh,value)
    DEF buf[4]:ARRAY OF UBYTE
    buf[0]:=value>>24
    buf[1]:=value>>16
    buf[2]:=value>>8
    buf[3]:=value
    Write(fh,buf,4)
ENDPROC

PROC Render(rp:PTR TO RastPort, data:PTR TO UBYTE, xmin, xmax, ymin, ymax)
    DEF x,y,iteration
    DEF zx, zy, cx, cy, temp
    DEF dx, dy

    dx := (xmax - xmin) / WIDTH
    dy := (ymax - ymin) / HEIGHT

    y := 0
    WHILE y < HEIGHT DO
        cy := ymin + y * dy
        x := 0
        WHILE x < WIDTH DO
            cx := xmin + x * dx
            zx := 0.0
            zy := 0.0
            iteration := 0
            WHILE (zx*zx + zy*zy <= 4.0) AND (iteration < 255) DO
                temp := zx*zx - zy*zy + cx
                zy := 2.0*zx*zy + cy
                zx := temp
                iteration++
            ENDWHILE
            data[y*WIDTH + x] := iteration
            SetAPen(rp, iteration)
            WritePixel(rp, x, y)
            x++
        ENDWHILE
        y++
    ENDWHILE
ENDPROC

PROC SaveIFF(filename:PTR TO CHAR, data:PTR TO UBYTE, palette:PTR TO UBYTE)
    DEF fh
    DEF bodySize, formSize
    DEF widthBytes, planeSize
    DEF planes:PTR TO UBYTE
    DEF x,y,b,byteIndex,bit,pix
    DEF id:LONG

    widthBytes := WIDTH/8
    planeSize := widthBytes*HEIGHT
    planes := AllocMem(planeSize*8, MEMF_ANY|MEMF_CLEAR)
    IF planes = NIL THEN RETURN

    y := 0
    WHILE y < HEIGHT DO
        x := 0
        WHILE x < WIDTH DO
            pix := data[y*WIDTH + x]
            byteIndex := y*widthBytes + (x>>3)
            bit := 7 - (x AND 7)
            b := 0
            WHILE b < 8 DO
                IF (pix >> b) AND 1 THEN
                    planes[b*planeSize + byteIndex] := planes[b*planeSize + byteIndex] OR (1 << bit)
                ENDIF
                b++
            ENDWHILE
            x++
        ENDWHILE
        y++
    ENDWHILE

    bodySize := planeSize*8
    formSize := 4 + (8+20) + (8+768) + (8+bodySize)

    fh := Open(filename, MODE_NEWFILE)
    IF fh <> 0 THEN
        id := 'FORM'
        Write(fh,ADR id,4)
        WriteLong(fh, formSize)
        id := 'ILBM'
        Write(fh,ADR id,4)

        id := 'BMHD'
        Write(fh,ADR id,4)
        WriteLong(fh,20)
        DEF bmhd[20]:ARRAY OF UBYTE
        bmhd[0] := WIDTH >> 8
        bmhd[1] := WIDTH AND $FF
        bmhd[2] := HEIGHT >> 8
        bmhd[3] := HEIGHT AND $FF
        bmhd[8] := 8
        Write(fh,ADR bmhd,20)

        id := 'CMAP'
        Write(fh,ADR id,4)
        WriteLong(fh,768)
        Write(fh,palette,768)

        id := 'BODY'
        Write(fh,ADR id,4)
        WriteLong(fh,bodySize)
        y := 0
        WHILE y < HEIGHT DO
            b := 0
            WHILE b < 8 DO
                Write(fh, planes + b*planeSize + y*widthBytes, widthBytes)
                b++
            ENDWHILE
            y++
        ENDWHILE
        Close(fh)
    ENDIF

    FreeMem(planes, planeSize*8)
ENDPROC

PROC main()
    DEF screen:PTR TO Screen
    DEF win:PTR TO Window
    DEF rp:PTR TO RastPort
    DEF colors[256*3]:ARRAY OF UBYTE
    DEF data:PTR TO UBYTE
    DEF i
    DEF xmin,xmax,ymin,ymax
    DEF msg:PTR TO IntuiMessage
    DEF startX,startY,endX,endY
    DEF x1,x2,y1,y2
    DEF done

    screen := OpenScreenTagList(NIL,
        [SA_Width,WIDTH, SA_Height,HEIGHT, SA_Depth,8,
         SA_DisplayID,HIRESLACE_KEY, TAG_END])
    IF screen = NIL THEN RETURN

    FOR i := 0 TO 255 DO
        SetRGB32(screen.ViewPort, i, i<<24, i<<24, i<<24)
        colors[i*3] := i
        colors[i*3+1] := i
        colors[i*3+2] := i
    ENDFOR

    win := OpenWindowTagList(NIL,
        [WA_CustomScreen,screen,
         WA_Left,0, WA_Top,0,
         WA_Width,WIDTH, WA_Height,HEIGHT,
         WA_IDCMP,IDCMP_MOUSEBUTTONS|IDCMP_VANILLAKEY,
         WA_Flags,WFLG_SIMPLE_REFRESH|WFLG_SMART_REFRESH|WFLG_DRAGBAR|WFLG_DEPTHGADGET|WFLG_CLOSEGADGET,
         WA_Title,"Mandelbrot",TAG_END])

    IF win <> NIL THEN
        rp := win.rport
        data := AllocMem(WIDTH*HEIGHT, MEMF_ANY)
        IF data <> NIL THEN
            xmin := -2.5
            xmax := 1.0
            ymin := -1.5
            ymax := 1.5
            Render(rp, data, xmin, xmax, ymin, ymax)
            REPEAT
                WaitPort(win.UserPort)
                msg := GetMsg(win.UserPort)
                IF msg <> NIL THEN
                    IF msg.Class = IDCMP_MOUSEBUTTONS THEN
                        IF msg.Code = SELECTDOWN THEN
                            startX := msg.MouseX
                            startY := msg.MouseY
                        ELIF msg.Code = SELECTUP THEN
                            endX := msg.MouseX
                            endY := msg.MouseY
                            IF startX <> endX AND startY <> endY THEN
                                x1 := xmin + startX*(xmax - xmin)/WIDTH
                                x2 := xmin + endX*(xmax - xmin)/WIDTH
                                y1 := ymin + startY*(ymax - ymin)/HEIGHT
                                y2 := ymin + endY*(ymax - ymin)/HEIGHT
                                IF x1 < x2 THEN
                                    xmin := x1
                                    xmax := x2
                                ELSE
                                    xmin := x2
                                    xmax := x1
                                ENDIF
                                IF y1 < y2 THEN
                                    ymin := y1
                                    ymax := y2
                                ELSE
                                    ymin := y2
                                    ymax := y1
                                ENDIF
                                Render(rp, data, xmin, xmax, ymin, ymax)
                            ENDIF
                        ELSE
                            done := TRUE
                        ENDIF
                    ELIF msg.Class = IDCMP_VANILLAKEY THEN
                        IF msg.Code = ord('s') THEN
                            SaveIFF("mandel.iff", data, colors)
                        ELSEIF msg.Code = $1b THEN
                            done := TRUE
                        ENDIF
                    ENDIF
                    ReplyMsg(msg)
                ENDIF
            UNTIL done
            FreeMem(data, WIDTH*HEIGHT)
        ENDIF
        CloseWindow(win)
    ENDIF
    CloseScreen(screen)
ENDPROC

