; SPDX-License-Identifier: MIT
; GeoLosung - die Herrnhuter Losungen fuer GeoWorks Ensemble 1.2 (Kernel 1.28)
; 8086, NASM, SDK pcgeos-1-sdk-v2 (ensemble12 adapter). Menus and icon are
; added by tools/postbuild.pl (built like the PDF-Betrachter).
;
; Data: GLOSjjjj.DAT (GEOS character set, CR LF), made by GeoLosung-Umwandeln.
;   [MMTT]  T=title  F=feast  AE= AT= AS=  NE= NT= NS=   ... [ENDE]
; Searched in GEOWORKS\DOCUMENT\LOSUNGEN, GEOWORKS\DOCUMENT and GEOWORKS.
;
; Kernel calls used (all confirmed in owned GeoWorks 1.28 programs):
;   MemAlloc 0, MemFree 2, FileOpen 52, FileClose 54, FileRead 58,
;   FilePos 60, FilePushDir 73, FilePopDir 74, FileSetStandardPath 76,
;   DOS date (AH=2Ah) through entry 95 (as DCLOCK24 asks for the time),
;   GrCreateState 211, GrDestroyState 212, GrApplyTranslation 310,
;   GrDrawText 330, GrFillRect 336, GrSetAreaColor 355, GrSetTextColor 359,
;   GrSetTextStyle 362, GrSetFont 366, GrGetWinBounds 440,
;   GrBeginUpdate 446, GrEndUpdate 447, ObjCallSuperNoLock 489.
%include "ensemble12.inc"
%define PROCESS_CLASS 0x40

; ---- process DGROUP variables (0xA0..0xFF; the method table ends below) ----
%define V_BSEG    0xA0      ; work block (locked for the life of the app)
%define V_BHAN    0xA2
%define V_WIN     0xA4      ; last exposed window, 0 = closed
%define V_INIT    0xA6
%define V_FW      0xA8      ; window size
%define V_FH      0xAA
%define V_OX      0xAC      ; view origin (the GenView may scroll by itself)
%define V_OY      0xAE
%define V_FILE    0xB0      ; open data file, 0 = none
%define V_FYEAR   0xB2      ; year of the open (or missing) data file
%define V_YR      0xB4      ; shown date
%define V_MO      0xB6
%define V_DY      0xB8
%define V_TYR     0xBA      ; today
%define V_TMO     0xBC
%define V_TDY     0xBE
%define V_MODE    0xC0      ; 0 day, 1 date entry, 2 info, 3 help
%define V_SCR     0xC2      ; text scrolled up by n pixels
%define V_STATE   0xC4      ; 0 record loaded, 1 no file for the year, 2 no record
%define V_CONTH   0xC6      ; height of the text at the last paint
%define V_ELEN    0xC8      ; date entry: number of characters
%define B_L       0xCA      ; 3D box scratch
%define B_T       0xCC
%define B_R       0xCE
%define B_B       0xD0
%define B_SUNK    0xD2
%define V_CY      0xD4      ; text cursor (window y of the next line)
%define V_SIZE    0xD6      ; font size of the current text
%define V_XL      0xD8      ; text column
%define V_XR      0xDA
%define V_ALIGN   0xDC      ; 0 left, 1 right
%define V_ACCL    0xDE      ; width accumulator (units of 1/1000 point)
%define V_ACCH    0xE0
%define V_LIML    0xE2      ; line width limit (same units)
%define V_LIMH    0xE4
%define V_LSP     0xE6      ; last space on the line
%define V_TEND    0xE8      ; end of the text / of the read chunk
%define V_POSL    0xEA      ; index build: file offset of the chunk
%define V_POSH    0xEC
%define V_ST      0xEE      ; index build state: 0 inside a line, 1 line start, 2 digits
%define V_NUM     0xF0
%define V_KPOSL   0xF2      ; offset of the "[" being parsed
%define V_KPOSH   0xF4
%define V_NDIG    0xF6
%define V_EERR    0xF8      ; date entry: 1 = invalid date
%define V_TMP     0xFA
%define V_TMP2    0xFC
%define V_STYLE   0xFE      ; text style of the current font (0x20 bold)
; help page (mode 3) reuses words of the date entry
%define V_LTOP    V_ELEN    ; first shown help line
%define V_NROW    V_TMP     ; help lines on the page
%define V_NENT    V_TMP2    ; help lines in all

; ---- work block ----
%define K_IDX     0         ; 12*31 dword file offsets of the records
%define K_BUF     1536      ; read buffer for the index scan
%define BUF_SZ    4096
%define K_REC     5632      ; the shown record, NUL terminated
%define REC_SZ    3000
%define K_PATH    8704      ; file name
%define K_MSG     8768      ; generated text
%define K_ENT     8896      ; date entry text
%define ENT_MAX   10
%define K_POX     8912      ; view origin at the last full paint
%define K_POY     8914
%define K_COPIED  8916      ; 1 = "kopiert" shown in the tool bar
%define K_HBTN    8920      ; help page layout
%define K_HBOT    8922
%define K_HSBX    8924
%define K_HT0     8926
%define K_HT1     8928
%define K_CLIP    8960      ; text for the clipboard
%define CLIP_SZ   3200
%define K_SIZE    (K_CLIP+CLIP_SZ)

%define BAR_H     24        ; tool bar
%define PAD       16        ; text margin
%define FONT_ID   0x1200    ; URW Sans

; colours (true colour with 64K drivers, rounded with 16 colours)
%define C_BG      10,42,92
%define C_HEAD    133,183,235
%define C_FEAST   181,212,244
%define C_TEXT    255,255,255
%define C_PANEL   24,64,124

%macro AREA_RGB 3
 mov al,%1
 mov bl,%2
 mov bh,%3
 call area_rgb
%endmacro
%macro TEXT_RGB 3
 mov al,%1
 mov bl,%2
 mov bh,%3
 call text_rgb
%endmacro

G1_METHOD 0x0a01, app_open
G1_METHOD 0x0a03, app_close
G1_METHOD 0x0004, meta_attach
G1_METHOD 0x0057, view_closed
G1_METHOD 0x0049, view_exposed
G1_METHOD 0x007b, kbd_char
G1_METHOD 0x00c3, mouse_select
G1_METHOD 0x0c00, menu_today
G1_METHOD 0x0c01, menu_date
G1_METHOD 0x0c03, menu_info
G1_METHOD 0x0c04, menu_help
G1_METHOD 0x0c05, menu_copy

; ======================================================================
; lifecycle
; ======================================================================
app_open:
 push es
 pop ds
 mov di,PROCESS_CLASS
 KCALL 489                        ; ObjCallSuperNoLock
 retf

app_close:
 push es
 pop ds
 call shutdown
 xor cx,cx
 retf

meta_attach:
 mov di,PROCESS_CLASS
 KCALL 489
 retf

view_closed:
 mov word [V_WIN],0
 mov di,PROCESS_CLASS
 KCALL 489
 retf

view_exposed:
 mov [V_WIN],cx
 push cx
 cmp word [V_INIT],0
 jne .ready
 call startup
.ready:
 pop di
 KCALL 211                        ; GrCreateState
 KCALL 446                        ; GrBeginUpdate
 call get_bounds
 call paint
 KCALL 447                        ; GrEndUpdate
 KCALL 212                        ; GrDestroyState
 ; the view scrolled by itself (mouse wheel): paint everything again
 cmp word [V_BSEG],0
 je .r
 mov es,[V_BSEG]
 mov ax,[V_OX]
 cmp ax,[es:K_POX]
 jne .moved
 mov ax,[V_OY]
 cmp ax,[es:K_POY]
 je .r
.moved:
 mov ax,[V_OX]
 mov [es:K_POX],ax
 mov ax,[V_OY]
 mov [es:K_POY],ax
 call repaint
.r:
 retf

; redraw outside an exposed event
repaint:
 mov di,[V_WIN]
 or di,di
 jz .no
 KCALL 211
 call get_bounds
 call paint
 KCALL 212
.no:
 ret

; DI = gstate: window size to V_FW/V_FH, draw relative to the visible corner
get_bounds:
 push di
 KCALL 440                        ; GrGetWinBounds -> AX,BX,CX,DX
 pop di
 mov [V_OX],ax
 mov [V_OY],bx
 push ax
 push bx
 push cx
 push dx
 mov si,ax
 or si,bx
 jz .not
 mov dx,ax
 xor cx,cx
 xor ax,ax
 push di
 KCALL 310                        ; GrApplyTranslation (left, top)
 pop di
.not:
 pop dx
 pop cx
 pop bx
 pop ax
 sub cx,ax
 sub dx,bx
 inc cx
 inc dx
 mov [V_FW],cx
 mov [V_FH],dx
 ret

startup:
 mov word [V_INIT],1
 mov word [V_MODE],0
 mov word [V_FYEAR],0
 mov word [V_FILE],0
 mov ax,K_SIZE
 mov cx,0xc000                    ; zeroed and locked
 KCALL 0                          ; MemAlloc -> BX handle, AX segment
 jc .nomem
 mov [V_BHAN],bx
 mov [V_BSEG],ax
 call get_today
 call go_today
 ret
.nomem:
 mov word [V_BSEG],0
 ret

shutdown:
 call close_file
 mov bx,[V_BHAN]
 or bx,bx
 jz .nb
 KCALL 2                          ; MemFree
 mov word [V_BHAN],0
 mov word [V_BSEG],0
.nb:
 mov word [V_INIT],0
 ret

; today's date from DOS (function 2Ah through the kernel, like DCLOCK24)
get_today:
 push ds
 mov ah,0x2a
 KCALL 95
 pop ds
 cmp cx,1980
 jb .bad
 cmp cx,2099
 ja .bad
 cmp dh,1
 jb .bad
 cmp dh,12
 ja .bad
 cmp dl,1
 jb .bad
 cmp dl,31
 ja .bad
 mov [V_TYR],cx
 mov al,dh
 xor ah,ah
 mov [V_TMO],ax
 mov al,dl
 mov [V_TDY],ax
 ret
.bad:
 mov word [V_TYR],2027
 mov word [V_TMO],1
 mov word [V_TDY],1
 ret

go_today:
 mov ax,[V_TYR]
 mov [V_YR],ax
 mov ax,[V_TMO]
 mov [V_MO],ax
 mov ax,[V_TDY]
 mov [V_DY],ax
 jmp load_record

; ======================================================================
; dates
; ======================================================================
; AX = year, BX = month -> AX = days in the month
days_in:
 push bx
 push dx
 cmp bx,2
 jne .tab
 mov bx,ax                        ; leap year?
 test bx,3
 jnz .d28
 xor dx,dx
 mov cx,100
 div cx
 or dx,dx
 jnz .d29
 mov ax,bx
 xor dx,dx
 mov cx,400
 div cx
 or dx,dx
 jz .d29
.d28:
 mov ax,28
 jmp .r
.d29:
 mov ax,29
 jmp .r
.tab:
 dec bx
 mov al,[cs:dim_tab+bx]
 xor ah,ah
.r:
 pop dx
 pop bx
 ret
dim_tab: db 31,28,31,30,31,30,31,31,30,31,30,31

next_day:
 mov ax,[V_YR]
 mov bx,[V_MO]
 call days_in
 mov cx,[V_DY]
 inc cx
 cmp cx,ax
 jbe .d
 mov cx,1
 inc word [V_MO]
 cmp word [V_MO],12
 jbe .d
 mov word [V_MO],1
 cmp word [V_YR],2099
 jae .stop
 inc word [V_YR]
.d:
 mov [V_DY],cx
 jmp load_record
.stop:
 mov word [V_MO],12
 ret

prev_day:
 mov cx,[V_DY]
 dec cx
 jnz .d
 mov ax,[V_MO]
 dec ax
 jnz .m
 cmp word [V_YR],1900
 jbe .stop
 dec word [V_YR]
 mov ax,12
.m:
 mov [V_MO],ax
 mov bx,ax
 mov ax,[V_YR]
 call days_in
 mov cx,ax
.d:
 mov [V_DY],cx
 jmp load_record
.stop:
 ret

; ======================================================================
; data file
; ======================================================================
close_file:
 mov bx,[V_FILE]
 or bx,bx
 jz .r
 mov al,0
 KCALL 54                         ; FileClose
 mov word [V_FILE],0
.r:
 ret

; open GLOS<V_FYEAR>.DAT: CF = not found
open_year:
 KCALL 73                         ; FilePushDir
 xor ax,ax                        ; SP_TOP: the GEOWORKS directory
 KCALL 76                         ; FileSetStandardPath
 jc .fail
 xor bx,bx
.try:
 cmp bx,6
 jae .fail
 push bx
 mov si,[cs:prefix_tab+bx]
 mov es,[V_BSEG]
 mov di,K_PATH
 call copy_cs
 mov si,s_glos
 call copy_cs
 mov ax,[V_FYEAR]
 call put_num
 mov si,s_dat
 call copy_cs
 mov byte [es:di],0
 push ds
 mov ds,[V_BSEG]
 mov dx,K_PATH
 mov al,0x40                      ; FILE_DENY_NONE | FILE_ACCESS_R
 KCALL 52                         ; FileOpen
 pop ds
 pop bx
 jnc .ok
 add bx,2
 jmp .try
.ok:
 mov [V_FILE],ax
 KCALL 74                         ; FilePopDir
 clc
 ret
.fail:
 KCALL 74
 stc
 ret
prefix_tab: dw s_p0, s_p1, s_p2
s_p0: db 'DOCUMENT\LOSUNGEN\',0
s_p1: db 'DOCUMENT\',0
s_p2: db 0
s_glos: db 'GLOS',0
s_dat:  db '.DAT',0

; open the data file of V_YR (if not yet done) and index it
ensure_year:
 mov ax,[V_YR]
 cmp ax,[V_FYEAR]
 je .r
 call close_file
 mov ax,[V_YR]
 mov [V_FYEAR],ax
 call open_year
 jc .r
 call build_index
.r:
 ret

; scan the file for lines "[MMTT]" and keep their offsets in K_IDX
build_index:
 mov es,[V_BSEG]
 xor di,di
 mov cx,12*31*2
 xor ax,ax
 rep stosw
 mov bx,[V_FILE]
 xor cx,cx
 xor dx,dx
 mov al,0
 KCALL 60                         ; FilePos to 0
 mov word [V_POSL],0
 mov word [V_POSH],0
 mov word [V_ST],1
.chunk:
 mov bx,[V_FILE]
 mov cx,BUF_SZ
 push ds
 mov ds,[V_BSEG]
 mov dx,K_BUF
 mov al,0
 KCALL 58                         ; FileRead
 pop ds
 jnc .full
 cmp cx,BUF_SZ                    ; short read: CX = bytes read
 jbe .got
 xor cx,cx
 jmp .got
.full:
 mov cx,BUF_SZ
.got:
 mov [V_TEND],cx
 or cx,cx
 jnz .scan0
 jmp .eof
.scan0:
 mov es,[V_BSEG]
 xor bx,bx
.loop:
 cmp bx,[V_TEND]
 jae .next
 mov al,[es:K_BUF+bx]
 cmp byte [V_ST],2
 je .dig
 cmp byte [V_ST],1
 jne .norm
 cmp al,'['
 jne .norm
 mov ax,[V_POSL]
 add ax,bx
 mov [V_KPOSL],ax
 mov ax,[V_POSH]
 adc ax,0
 mov [V_KPOSH],ax
 mov byte [V_ST],2
 mov word [V_NUM],0
 mov word [V_NDIG],0
 jmp .nx
.dig:
 sub al,'0'
 cmp al,9
 ja .abort
 xor ah,ah
 mov cx,ax
 mov ax,[V_NUM]
 mov dx,10
 mul dx
 add ax,cx
 mov [V_NUM],ax
 inc word [V_NDIG]
 cmp word [V_NDIG],4
 jb .nx
 call store_idx
.abort:
 mov byte [V_ST],0
 jmp .nx
.norm:
 mov byte [V_ST],0
 cmp al,10
 jne .nx
 mov byte [V_ST],1
.nx:
 inc bx
 jmp .loop
.next:
 mov ax,[V_TEND]
 add [V_POSL],ax
 adc word [V_POSH],0
 cmp ax,BUF_SZ
 je .chunk
.eof:
 ret

; V_NUM = MMTT -> K_IDX[(MM-1)*31+TT-1] = V_KPOS
store_idx:
 push bx
 mov ax,[V_NUM]
 xor dx,dx
 mov cx,100
 div cx                           ; AX = month, DX = day
 cmp ax,1
 jb .r
 cmp ax,12
 ja .r
 cmp dx,1
 jb .r
 cmp dx,31
 ja .r
 dec ax
 mov cx,31
 push dx
 mul cx
 pop dx
 add ax,dx
 dec ax
 shl ax,1
 shl ax,1
 mov bx,ax
 mov ax,[V_KPOSL]
 mov [es:K_IDX+bx],ax
 mov ax,[V_KPOSH]
 mov [es:K_IDX+bx+2],ax
.r:
 pop bx
 ret

; read the record of V_YR/V_MO/V_DY into K_REC; sets V_STATE
load_record:
 mov word [V_SCR],0
 cmp word [V_BSEG],0
 je .nofile
 mov es,[V_BSEG]
 mov byte [es:K_COPIED],0
 call ensure_year
 cmp word [V_FILE],0
 je .nofile
 mov ax,[V_MO]
 dec ax
 mov cx,31
 mul cx
 add ax,[V_DY]
 dec ax
 shl ax,1
 shl ax,1
 mov bx,ax
 mov es,[V_BSEG]
 mov dx,[es:K_IDX+bx]
 mov cx,[es:K_IDX+bx+2]
 mov ax,dx
 or ax,cx
 jz .noday
 mov bx,[V_FILE]
 mov al,0
 KCALL 60                         ; FilePos CX:DX
 mov bx,[V_FILE]
 mov cx,REC_SZ
 push ds
 mov ds,[V_BSEG]
 mov dx,K_REC
 mov al,0
 KCALL 58                         ; FileRead
 pop ds
 jnc .full
 cmp cx,REC_SZ
 jbe .got
 xor cx,cx
 jmp .got
.full:
 mov cx,REC_SZ
.got:
 mov es,[V_BSEG]
 mov di,K_REC
 add di,cx
 mov byte [es:di],0
 ; end the record at the next line starting with "["
 mov di,K_REC+1
.find:
 mov al,[es:di]
 or al,al
 jz .done
 cmp al,10
 jne .fn
 cmp byte [es:di+1],'['
 jne .fn
 mov byte [es:di+1],0
 jmp .done
.fn:
 inc di
 jmp .find
.done:
 mov word [V_STATE],0
 ret
.nofile:
 mov word [V_STATE],1
 ret
.noday:
 mov word [V_STATE],2
 ret

; CS:SI = key ("AT=") -> ES:SI value, CX length; CF = not in the record
find_field:
 push di
 mov es,[V_BSEG]
 mov di,K_REC
.line:
 cmp byte [es:di],0
 je .nf
 push si
 push di
.cmp:
 mov al,[cs:si]
 or al,al
 jz .match
 cmp al,[es:di]
 jne .nomatch
 inc si
 inc di
 jmp .cmp
.match:
 add sp,4
 mov si,di
 xor cx,cx
.len:
 mov al,[es:di]
 or al,al
 jz .d
 cmp al,13
 je .d
 cmp al,10
 je .d
 inc di
 inc cx
 jmp .len
.d:
 pop di
 clc
 ret
.nomatch:
 pop di
 pop si
.skip:
 mov al,[es:di]
 or al,al
 jz .nf
 inc di
 cmp al,10
 jne .skip
 jmp .line
.nf:
 pop di
 stc
 ret

; ======================================================================
; drawing helpers (DI = gstate)
; ======================================================================
area_rgb:                         ; AL,BL,BH = red, green, blue
 push di
 mov ah,0x80
 KCALL 355                        ; GrSetAreaColor
 pop di
 ret
text_rgb:
 push di
 mov ah,0x80
 KCALL 359                        ; GrSetTextColor
 pop di
 ret
set_area:                         ; AL = palette index
 push di
 xor ah,ah
 KCALL 355
 pop di
 ret
set_tcol:
 push di
 xor ah,ah
 KCALL 359
 pop di
 ret
fill:                             ; AX,BX,CX,DX = left,top,right,bottom
 push di
 KCALL 336                        ; GrFillRect
 pop di
 ret
; AX = size, BL = style bits (0x20 bold)
set_font:
 push di
 push bx
 mov [V_SIZE],ax
 mov [V_STYLE],bl
 mov dx,ax
 mov cx,FONT_ID
 xor ah,ah
 KCALL 366                        ; GrSetFont
 pop bx
 pop di
 push di
 mov al,bl
 mov ah,0xff
 KCALL 362                        ; GrSetTextStyle
 pop di
 ret
; DS:SI NUL terminated at AX,BX
text_ds:
 push di
 push si
 xor cx,cx
 KCALL 330                        ; GrDrawText
 pop si
 pop di
 ret

; line height for V_SIZE -> AX
line_h:
 mov ax,[V_SIZE]
 mov bx,ax
 shr bx,1
 shr bx,1
 add ax,bx
 add ax,2
 ret

; ES:SI text, CX length: word wrapped between V_XL and V_XR from V_CY on
; (V_ALIGN 1 = right aligned). V_CY moves below the text.
draw_wrapped:
 mov [V_TEND],si
 add [V_TEND],cx
 mov ax,[V_XR]
 sub ax,[V_XL]
 cmp ax,40
 jge .w
 mov ax,40
.w:
 mov cx,960                       ; small reserve for the synthetic bold
 mul cx
 mov [V_LIML],ax
 mov [V_LIMH],dx
.line:
 cmp si,[V_TEND]
 jae .done
 cmp byte [es:si],' '
 jne .ls
 inc si
 jmp .line
.ls:
 mov word [V_ACCL],0
 mov word [V_ACCH],0
 mov word [V_LSP],0
 mov bx,si
.scan:
 cmp bx,[V_TEND]
 jae .end
 mov al,[es:bx]
 cmp al,' '
 jne .ns
 mov [V_LSP],bx
.ns:
 call char_units
 add [V_ACCL],ax
 adc [V_ACCH],dx
 mov ax,[V_ACCH]
 cmp ax,[V_LIMH]
 jb .fits
 ja .over
 mov ax,[V_ACCL]
 cmp ax,[V_LIML]
 jbe .fits
.over:
 mov cx,[V_LSP]
 cmp cx,si
 ja .atsp
 cmp bx,si
 jne .atbx
 inc bx
.atbx:
 mov cx,bx
 mov dx,bx
 jmp .emit
.atsp:
 mov dx,cx
 inc dx
 jmp .emit
.fits:
 inc bx
 jmp .scan
.end:
 mov cx,[V_TEND]
 mov dx,cx
.emit:
 push dx
 sub cx,si
 call emit_line
 call line_h
 add [V_CY],ax
 pop si
 jmp .line
.done:
 ret

; AL = character -> DX:AX = width * size (units of 1/1000 point)
char_units:
 push bx
 xor ah,ah
 mov bx,ax
 shl bx,1
 test byte [V_STYLE],0x20
 jz .reg
 mov ax,[cs:wtab+bx]
 jmp .mul
.reg:
 mov ax,[cs:wtab_r+bx]
.mul:
 mul word [V_SIZE]
 pop bx
 ret

; ES:SI, CX characters at V_CY (left or right aligned)
emit_line:
 push si
 push cx
 mov ax,[V_XL]
 cmp word [V_ALIGN],0
 je .pos
 ; width of the line in points
 push si
 push cx
 xor bx,bx
 mov [V_ACCL],bx
 mov [V_ACCH],bx
.wl:
 jcxz .wd
 mov al,[es:si]
 push cx
 call char_units
 pop cx
 add [V_ACCL],ax
 adc [V_ACCH],dx
 inc si
 dec cx
 jmp .wl
.wd:
 mov ax,[V_ACCL]
 mov dx,[V_ACCH]
 mov cx,1000
 div cx
 pop cx
 pop si
 mov bx,ax
 mov ax,[V_XR]
 sub ax,bx
.pos:
 mov bx,[V_CY]
 cmp bx,BAR_H-40                  ; far above the visible text: skip
 jl .skip
 cmp bx,[V_FH]
 jg .skip
 pop cx
 pop si
 push si
 push cx
 push es
 push ds
 push es
 pop ds
 push di
 KCALL 330                        ; GrDrawText DS:SI, CX characters
 pop di
 pop ds
 pop es
.skip:
 pop cx
 pop si
 ret

; key in CS (e.g. "AT="): draw its value wrapped, CF = field missing
draw_field:
 call find_field
 jc .r
 call draw_wrapped
 clc
.r:
 ret

; CS:SI NUL terminated: draw wrapped
draw_cs:
 push cs
 pop es
 xor cx,cx
 push si
.l:
 cmp byte [cs:si],0
 je .e
 inc si
 inc cx
 jmp .l
.e:
 pop si
 jmp draw_wrapped

; K_MSG: draw wrapped
draw_msg:
 mov es,[V_BSEG]
 mov si,K_MSG
 xor cx,cx
.l:
 cmp byte [es:si],0
 je .e
 inc si
 inc cx
 jmp .l
.e:
 mov si,K_MSG
 jmp draw_wrapped

; ======================================================================
; paint
; ======================================================================
paint:
 cmp word [V_BSEG],0
 je .bar
 cmp word [V_MODE],3
 jne .blue
 mov al,7                         ; help: grey like a dialog
 call set_area
 xor ax,ax
 mov bx,BAR_H
 mov cx,[V_FW]
 mov dx,[V_FH]
 call fill
 call paint_help
 jmp .bar
.blue:
 AREA_RGB C_BG
 xor ax,ax
 mov bx,BAR_H
 mov cx,[V_FW]
 mov dx,[V_FH]
 call fill
 mov word [V_XL],PAD
 mov ax,[V_FW]
 sub ax,PAD
 mov [V_XR],ax
 mov word [V_ALIGN],0
 mov ax,BAR_H+PAD-4
 sub ax,[V_SCR]
 mov [V_CY],ax
 mov ax,[V_MODE]
 cmp ax,1
 je .entry
 cmp ax,2
 jae .page
 call paint_day
 jmp .h
.entry:
 call paint_entry
 jmp .h
.page:
 call paint_page
.h:
 mov ax,[V_CY]
 add ax,[V_SCR]
 sub ax,BAR_H
 mov [V_CONTH],ax
.bar:
 call tool_bar
 ret

; heading in light blue
head_font:
 push ax
 TEXT_RGB C_HEAD
 pop ax
 mov bl,0x20
 jmp set_font
white_font:
 push ax
 TEXT_RGB C_TEXT
 pop ax
 mov bl,0                         ; white text: regular weight
 jmp set_font

paint_day:
 cmp word [V_STATE],0
 jne .missing
 ; date and day of the church year
 mov ax,18
 call head_font
 mov si,k_t
 call draw_field
 mov si,k_f
 call find_field
 jc .nof
 push si
 push cx
 TEXT_RGB C_FEAST
 mov ax,12
 mov bl,0x20
 call set_font
 pop cx
 pop si
 mov es,[V_BSEG]
 call draw_wrapped
.nof:
 add word [V_CY],12
 ; Losung (Old Testament), Lehrtext (New Testament)
 mov si,k_ae
 mov bx,s_losung
 call testament
 add word [V_CY],12
 mov si,k_ne
 mov bx,s_lehrtext
 call testament
 ret
.missing:
 ; no data: date of the day and a hint
 mov ax,18
 call head_font
 call date_msg
 call draw_msg
 add word [V_CY],10
 mov ax,12
 call white_font
 mov si,s_nofile1
 cmp word [V_STATE],1
 je .nf
 mov si,s_noday
 call draw_cs
 ret
.nf:
 call draw_cs
 add word [V_CY],6
 push di
 mov es,[V_BSEG]
 mov di,K_MSG
 mov si,s_nofile2
 call copy_cs
 mov ax,[V_YR]
 call put_num
 mov si,s_nofile3
 call copy_cs
 mov byte [es:di],0
 pop di
 call draw_msg
 ret

; SI = key of the introduction ("AE="), BX = heading text in CS.
; The keys of text and reference follow the introduction key in k_tab order.
testament:
 push si
 push bx
 mov ax,14
 call head_font
 pop si
 call draw_cs
 add word [V_CY],2
 mov ax,12
 call white_font
 pop si
 push si
 call draw_field                  ; introduction (may be missing)
 pop si
 add si,4
 push si
 call draw_field                  ; text
 pop si
 add si,4
 push si
 mov ax,11
 call white_font
 mov word [V_ALIGN],1
 pop si
 call draw_field                  ; reference, right aligned
 mov word [V_ALIGN],0
 ret

; keys: 4 bytes each (text, NUL)
k_t:  db 'T=',0,0
k_f:  db 'F=',0,0
k_ae: db 'AE=',0
k_at: db 'AT=',0
k_as: db 'AS=',0
k_ne: db 'NE=',0
k_nt: db 'NT=',0
k_ns: db 'NS=',0

s_losung:   db 'Losung',0
s_lehrtext: db 'Lehrtext',0
s_nofile1:  db 'F',0x9f,'r dieses Jahr ist keine Losungsdatei vorhanden.',0
s_nofile2:  db 'Bitte die Datei GLOS',0
s_nofile3:  db '.DAT in den Ordner DOCUMENT\LOSUNGEN im GeoWorks-Verzeichnis kopieren.',0
s_noday:    db 'F',0x9f,'r diesen Tag wurde in der Losungsdatei kein Eintrag gefunden.',0

; K_MSG = "T.M.JJJJ" of the shown day
date_msg:
 push di
 mov es,[V_BSEG]
 mov di,K_MSG
 mov ax,[V_DY]
 call put_num
 mov al,'.'
 stosb
 mov ax,[V_MO]
 call put_num
 mov al,'.'
 stosb
 mov ax,[V_YR]
 call put_num
 mov byte [es:di],0
 pop di
 ret

; date entry page
paint_entry:
 mov ax,16
 call head_font
 mov si,s_ehead
 call draw_cs
 add word [V_CY],8
 mov ax,12
 call white_font
 mov si,s_eask
 call draw_cs
 add word [V_CY],4
 ; white input field with the text and a cursor
 mov ax,15
 call set_area
 mov ax,PAD
 mov bx,[V_CY]
 mov cx,PAD+160
 mov dx,bx
 add dx,22
 call fill
 xor ax,ax
 call set_tcol
 mov ax,14
 mov bl,0x20
 call set_font
 push di
 mov es,[V_BSEG]
 mov di,K_MSG
 mov cx,[V_ELEN]
 push ds
 mov ds,[V_BSEG]
 mov si,K_ENT
 rep movsb
 pop ds
 mov al,'_'
 stosb
 mov byte [es:di],0
 pop di
 mov ax,PAD+6
 mov bx,[V_CY]
 add bx,3
 push ds
 mov ds,[V_BSEG]
 mov si,K_MSG
 call text_ds
 pop ds
 add word [V_CY],34
 mov ax,11
 call white_font
 mov si,s_ehint
 call draw_cs
 cmp word [V_EERR],0
 je .r
 add word [V_CY],6
 TEXT_RGB 255,190,120
 mov si,s_eerr
 call draw_cs
.r:
 ret
s_ehead: db 'Gehe zu Datum',0
s_eask:  db 'Datum eingeben (TT.MM.JJJJ), z. B. 24.12.2027:',0
s_ehint: db 'Eingabe: springen     Esc: abbrechen     R',0x9f,'cktaste: l',0x9a,'schen',0
s_eerr:  db 'Dieses Datum gibt es nicht. Bitte noch einmal eingeben.',0

; info (mode 2) / help (mode 3): size byte, colour byte, text, NUL ... 0
paint_page:
 mov si,t_info
 cmp word [V_MODE],2
 je .go
 mov si,t_help
.go:
 mov al,[cs:si]
 or al,al
 jz .done
 xor ah,ah
 mov bl,[cs:si+1]
 add si,2
 push si
 push ax
 cmp bl,1
 je .hd
 pop ax
 call white_font
 jmp .t
.hd:
 pop ax
 call head_font
.t:
 pop si
 push si
 call draw_cs
 add word [V_CY],6
 pop si
.skip:
 cmp byte [cs:si],0
 je .nx
 inc si
 jmp .skip
.nx:
 inc si
 jmp .go
.done:
 ret

t_info:
 db 20,1,'GeoLosung',0
 db 12,2,'Version 1.3 f',0x9f,'r GeoWorks Ensemble 1.2',0
 db 12,2,'Die Losungen der Herrnhuter Br',0x9f,'dergemeine: f',0x9f,'r jeden Tag ein Wort aus dem Alten Testament (Losung) und ein Wort aus dem Neuen Testament (Lehrtext).',0
 db 12,2,'Die Losungstexte: ',0xa9,' Evangelische Br',0x9f,'der-Unit',0x8a,'t ',0xd0,' Herrnhuter Br',0x9f,'dergemeine, www.losungen.de. Weitere Informationen dort.',0
 db 12,2,'Die Jahresdateien GLOSjjjj.DAT entstehen mit GeoLosung-Umwandeln aus den Losungsdateien von W32LOS.',0
 db 11,2,'Geschrieben mit dem pcgeos-1-sdk-v2 (NASM). Eine Taste oder ein Klick f',0x9f,'hrt zur',0x9f,'ck zur Losung.',0
 db 0
t_help:
 db 20,1,'Hilfe zu GeoLosung',0
 db 12,2,'Zur',0x9f,'ck / Vor oder Pfeiltasten links und rechts: einen Tag zur',0x9f,'ck oder vor.',0
 db 12,2,'Heute, Taste Pos1 oder H: zum heutigen Tag.',0
 db 12,2,'Datum',0xc9,' oder Taste D: ein Datum eingeben, zum Beispiel 24.12.2027, und mit der Eingabetaste springen.',0
 db 12,2,'Kopieren oder Taste K: die Losung des Tages in die Zwischenablage kopieren, zum Einf',0x9f,'gen in GeoWrite oder den Notizblock.',0
 db 12,2,'Pfeiltasten hoch und runter, Bild auf und ab: den Text verschieben, wenn er nicht ganz in das Fenster passt.',0
 db 12,2,'Die Dateien GLOSjjjj.DAT geh',0x9a,'ren in den Ordner DOCUMENT\LOSUNGEN im GeoWorks-Verzeichnis.',0
 db 11,2,'Eine Taste oder ein Klick f',0x9f,'hrt zur',0x9f,'ck zur Losung.',0
 db 0

; ======================================================================
; tool bar with own buttons
; ======================================================================
NBTN equ 6
btn_x:   dw 6, 76, 130, 194, 262, 316
btn_w:   dw 66, 50, 60, 64, 40, 66
btn_lbl: dw s_b0, s_b1, s_b2, s_b3, s_b4, s_b5
s_b0: db '< Zur',0x9f,'ck',0
s_b1: db 'Heute',0
s_b2: db 'Vor >',0
s_b3: db 'Datum',0xc9,0
s_b4: db 'Info',0
s_b5: db 'Kopieren',0
s_copied: db 'Losung kopiert',0

tool_bar:
 mov al,7
 call set_area
 xor ax,ax
 xor bx,bx
 mov cx,[V_FW]
 mov dx,BAR_H
 call fill
 mov ax,10
 mov bl,0
 call set_font
 xor si,si
.b:
 cmp si,NBTN
 jae .d
 mov bx,si
 shl bx,1
 mov ax,[cs:btn_x+bx]
 mov [B_L],ax
 add ax,[cs:btn_w+bx]
 mov [B_R],ax
 mov word [B_T],3
 mov word [B_B],BAR_H-3
 mov byte [B_SUNK],0
 push si
 call bevel
 pop si
 xor ax,ax
 call set_tcol
 ; centre the label: (button width - text width) / 2
 mov bx,si
 shl bx,1
 push si
 mov si,[cs:btn_lbl+bx]
 xor cx,cx
 mov [V_ACCL],cx
 mov [V_ACCH],cx
.len:
 mov al,[cs:si]
 or al,al
 jz .lend
 call char_units
 add [V_ACCL],ax
 adc [V_ACCH],dx
 inc si
 jmp .len
.lend:
 mov ax,[V_ACCL]
 mov dx,[V_ACCH]
 mov cx,1000
 div cx
 mov dx,[cs:btn_w+bx]
 sub dx,ax
 sar dx,1
 jns .pos
 xor dx,dx
.pos:
 mov ax,[cs:btn_x+bx]
 add ax,dx
 mov si,[cs:btn_lbl+bx]
 push ds
 push cs
 pop ds
 mov bx,6
 call text_ds
 pop ds
 pop si
 inc si
 jmp .b
.d:
 cmp word [V_BSEG],0
 je .r
 mov es,[V_BSEG]
 cmp byte [es:K_COPIED],0
 je .r
 xor ax,ax
 call set_tcol
 mov ax,390
 mov bx,6
 push ds
 push cs
 pop ds
 mov si,s_copied
 call text_ds
 pop ds
.r:
 ret

; Motif style 3D box [B_L],[B_T],[B_R],[B_B] (right/bottom exclusive)
bevel:
 mov al,7
 call set_area
 mov ax,[B_L]
 mov bx,[B_T]
 mov cx,[B_R]
 mov dx,[B_B]
 call fill
 mov al,15
 cmp byte [B_SUNK],0
 je .l1
 mov al,8
.l1:
 call set_area
 mov ax,[B_L]
 mov bx,[B_T]
 mov cx,[B_R]
 mov dx,bx
 inc dx
 call fill
 mov ax,[B_L]
 mov bx,[B_T]
 mov cx,ax
 inc cx
 mov dx,[B_B]
 call fill
 mov al,8
 cmp byte [B_SUNK],0
 je .l2
 mov al,15
.l2:
 call set_area
 mov ax,[B_L]
 inc ax
 mov dx,[B_B]
 mov bx,dx
 dec bx
 mov cx,[B_R]
 call fill
 mov cx,[B_R]
 mov ax,cx
 dec ax
 mov bx,[B_T]
 inc bx
 mov dx,[B_B]
 call fill
 ret

; ======================================================================
; input
; ======================================================================
kbd_char:
 test dl,0x81                     ; key release / state key
 jnz .pass
 cmp word [V_INIT],0
 je .pass
 cmp word [V_BSEG],0
 je .pass
 mov ax,[V_MODE]
 cmp ax,1
 je .entry
 cmp ax,3
 je .help
 cmp ax,2
 jb .day
 mov word [V_MODE],0              ; info: any key returns
 jmp .redraw
.help:
 call help_key
 jmp .redraw
.entry:
 call entry_key
 jc .pass
 jmp .redraw
.day:
 cmp ch,0xff
 jne .ascii
 cmp cl,0x93
 je .prev
 cmp cl,0x92
 je .next
 cmp cl,0x90
 je .up
 cmp cl,0x91
 je .down
 cmp cl,0x96
 je .pgup
 cmp cl,0x97
 je .pgdn
 cmp cl,0x94
 je .today
 cmp cl,'4'                       ; numeric keypad
 je .prev
 cmp cl,'6'
 je .next
 cmp cl,'8'
 je .up
 cmp cl,'2'
 je .down
 cmp cl,'9'
 je .pgup
 cmp cl,'3'
 je .pgdn
 cmp cl,'7'
 je .today
 jmp .pass
.ascii:
 mov al,cl
 or al,0x20
 cmp al,'h'
 je .today
 cmp al,'d'
 je .date
 cmp al,'i'
 je .info
 cmp al,'k'
 je .copy
 cmp cl,'+'
 je .next
 cmp cl,'-'
 je .prev
 cmp cl,' '
 je .next
 jmp .pass
.prev:
 call prev_day
 jmp .redraw
.next:
 call next_day
 jmp .redraw
.today:
 call get_today
 call go_today
 jmp .redraw
.date:
 call start_entry
 jmp .redraw
.info:
 mov word [V_MODE],2
 mov word [V_SCR],0
 jmp .redraw
.copy:
 call copy_day
 jmp .redraw
.up:
 mov ax,-30
 jmp .scroll
.down:
 mov ax,30
 jmp .scroll
.pgup:
 mov ax,[V_FH]
 sub ax,BAR_H+30
 neg ax
 jmp .scroll
.pgdn:
 mov ax,[V_FH]
 sub ax,BAR_H+30
.scroll:
 add ax,[V_SCR]
 call clamp_scr
 cmp ax,[V_SCR]
 je .done
 mov [V_SCR],ax
.redraw:
 call repaint
.done:
 retf
.pass:
 mov di,PROCESS_CLASS
 KCALL 489
 retf

; AX = wanted scroll -> AX clamped to 0 .. text height - visible height
clamp_scr:
 mov bx,[V_CONTH]
 add bx,PAD
 mov cx,[V_FH]
 sub cx,BAR_H
 sub bx,cx
 jg .m
 xor bx,bx
.m:
 cmp ax,bx
 jle .l
 mov ax,bx
.l:
 or ax,ax
 jge .r
 xor ax,ax
.r:
 ret

start_entry:
 mov word [V_MODE],1
 mov word [V_ELEN],0
 mov word [V_EERR],0
 mov word [V_SCR],0
 ret

; date entry key (CL, CH). CF = not used
entry_key:
 cmp cl,0x1b                      ; Esc
 je .esc
 cmp cl,0x0d                      ; Enter
 je .enter
 cmp cl,0x08                      ; Backspace
 je .back
 cmp cl,'.'
 je .add
 cmp cl,','
 je .comma
 cmp cl,'0'
 jb .no
 cmp cl,'9'
 ja .no
.add:
 mov bx,[V_ELEN]
 cmp bx,ENT_MAX
 jae .ok
 mov es,[V_BSEG]
 mov [es:K_ENT+bx],cl
 inc word [V_ELEN]
 mov word [V_EERR],0
.ok:
 clc
 ret
.comma:
 mov cl,'.'
 jmp .add
.back:
 cmp word [V_ELEN],0
 je .ok
 dec word [V_ELEN]
 mov word [V_EERR],0
 clc
 ret
.esc:
 mov word [V_MODE],0
 clc
 ret
.enter:
 call parse_entry
 jc .bad
 mov word [V_MODE],0
 call load_record
 clc
 ret
.bad:
 mov word [V_EERR],1
 clc
 ret
.no:
 stc
 ret

; K_ENT -> V_YR/V_MO/V_DY. Forms: T.M.JJJJ, T.M.JJ, T.M., T.M,
; TTMMJJJJ, TTMMJJ, TTMM. CF = invalid
parse_entry:
 mov es,[V_BSEG]
 mov cx,[V_ELEN]
 or cx,cx
 jnz .some
 jmp .bad
.some:
 ; any dot?
 mov si,K_ENT
 xor dx,dx
.cd:
 cmp byte [es:si],'.'
 jne .cn
 inc dx
.cn:
 inc si
 loop .cd
 or dx,dx
 jnz .dots
 ; digits only: TTMM[JJ[JJ]]
 mov cx,[V_ELEN]
 cmp cx,4
 je .d4
 cmp cx,6
 je .d6
 cmp cx,8
 je .d8
 jmp .bad
.d4:
 mov ax,[V_YR]
 mov [V_TMP2],ax
 jmp .dm
.d6:
 mov si,K_ENT+4
 mov cx,2
 call num_n
 add ax,2000
 mov [V_TMP2],ax
 jmp .dm
.d8:
 mov si,K_ENT+4
 mov cx,4
 call num_n
 mov [V_TMP2],ax
.dm:
 mov si,K_ENT
 mov cx,2
 call num_n
 mov [V_TMP],ax                   ; day
 mov si,K_ENT+2
 mov cx,2
 call num_n
 mov bx,ax                        ; month
 jmp .check
.dots:
 ; T.M[.[J]]
 mov si,K_ENT
 mov di,K_ENT
 add di,[V_ELEN]                  ; end
 call num_dot
 jc .bad
 mov [V_TMP],ax
 call num_dot
 jc .bad
 mov bx,ax
 mov ax,[V_YR]
 cmp si,di
 jae .yset
 push bx
 call num_dot
 pop bx
 jc .bad
 cmp ax,100
 jae .yset
 add ax,2000
.yset:
 mov [V_TMP2],ax
.check:
 ; BX month, V_TMP day, V_TMP2 year
 mov ax,[V_TMP2]
 cmp ax,1900
 jb .bad
 cmp ax,2099
 ja .bad
 cmp bx,1
 jb .bad
 cmp bx,12
 ja .bad
 call days_in
 mov cx,[V_TMP]
 cmp cx,1
 jb .bad
 cmp cx,ax
 ja .bad
 mov [V_DY],cx
 mov [V_MO],bx
 mov ax,[V_TMP2]
 mov [V_YR],ax
 clc
 ret
.bad:
 stc
 ret

; ES:SI, CX digits -> AX
num_n:
 xor ax,ax
.l:
 jcxz .r
 mov dx,10
 mul dx
 mov dl,[es:si]
 sub dl,'0'
 xor dh,dh
 add ax,dx
 inc si
 dec cx
 jmp .l
.r:
 ret

; ES:SI digits up to a dot or DI -> AX, SI behind the dot. CF = no digits
num_dot:
 xor ax,ax
 xor cx,cx
.l:
 cmp si,di
 jae .e
 mov dl,[es:si]
 inc si
 cmp dl,'.'
 je .e
 sub dl,'0'
 xor dh,dh
 push dx
 mov dx,10
 mul dx
 pop dx
 add ax,dx
 inc cx
 cmp cx,4
 ja .bad
 jmp .l
.e:
 jcxz .bad
 clc
 ret
.bad:
 stc
 ret

mouse_select:
 cmp word [V_INIT],0
 je .done
 cmp word [V_BSEG],0
 je .done
 sub cx,[V_OX]                    ; document -> window coordinates
 sub dx,[V_OY]
 cmp word [V_MODE],3
 jne .noth
 cmp dx,BAR_H
 jl .notpage                      ; tool bar works in the help too
 call help_click
 jmp .done
.noth:
 cmp word [V_MODE],2
 jb .notpage
 mov word [V_MODE],0              ; info: a click returns
 jmp .redraw
.notpage:
 cmp dx,BAR_H
 jge .done
 xor si,si
.btn:
 cmp si,NBTN
 jae .done
 mov bx,si
 shl bx,1
 mov ax,[cs:btn_x+bx]
 cmp cx,ax
 jl .nb
 add ax,[cs:btn_w+bx]
 cmp cx,ax
 jl .hit
.nb:
 inc si
 jmp .btn
.hit:
 mov word [V_MODE],0
 cmp si,0
 je .prev
 cmp si,1
 je .today
 cmp si,2
 je .next
 cmp si,3
 je .date
 cmp si,5
 je .copy
 mov word [V_MODE],2              ; Info
 mov word [V_SCR],0
 jmp .redraw
.prev:
 call prev_day
 jmp .redraw
.next:
 call next_day
 jmp .redraw
.today:
 call get_today
 call go_today
 jmp .redraw
.date:
 call start_entry
 jmp .redraw
.copy:
 call copy_day
.redraw:
 call repaint
.done:
 mov ax,0x8000                    ; MRF_PROCESSED
 retf

; ======================================================================
; menus
; ======================================================================
menu_today:
 cmp word [V_BSEG],0
 je .r
 mov word [V_MODE],0
 call get_today
 call go_today
 call repaint
.r:
 retf
menu_date:
 cmp word [V_BSEG],0
 je .r
 call start_entry
 call repaint
.r:
 retf
menu_info:
 mov ax,2
 jmp short show_page
menu_help:
 mov ax,3
show_page:
 cmp word [V_BSEG],0
 je .r
 mov [V_MODE],ax
 mov word [V_SCR],0
 mov word [V_LTOP],0
 call repaint
.r:
 retf

menu_copy:
 cmp word [V_BSEG],0
 je .r
 mov word [V_MODE],0
 call copy_day
 call repaint
.r:
 retf

; the shown day as text to the clipboard
copy_day:
 cmp word [V_STATE],0
 jne .r
 call clip_text                   ; -> K_CLIP, CX length
 jcxz .r
 push ds
 mov ds,[V_BSEG]
 mov si,K_CLIP
 mov dx,s_clipname
 call g1_clip_text
 pop ds
 jc .r
 mov es,[V_BSEG]
 mov byte [es:K_COPIED],1
.r:
 ret
s_clipname: db 'Tageslosung',0

; K_CLIP = title, feast, Losung, Lehrtext (CR between the paragraphs)
clip_text:
 mov es,[V_BSEG]
 mov di,K_CLIP
 mov si,k_t
 call .field
 call .nl
 mov si,k_f
 call .fieldnl
 call .nl
 mov si,s_losung
 call .cs
 mov si,k_ae
 call .intro
 mov si,k_at
 call .field
 call .nl
 mov si,k_as
 call .field
 call .nl
 call .nl
 mov si,s_lehrtext
 call .cs
 mov si,k_ne
 call .intro
 mov si,k_nt
 call .field
 call .nl
 mov si,k_ns
 call .field
 mov cx,di
 sub cx,K_CLIP
 ret
.nl:
 mov byte [es:di],13
 inc di
 ret
.cs:                              ; CS string and a CR
 call copy_cs
 jmp .nl
.fieldnl:                         ; field and a CR, if present
 push di
 call find_field
 pop di
 jc .no
 call .put
 jmp .nl
.intro:                           ; field and a space, if present
 push di
 call find_field
 pop di
 jc .no
 call .put
 mov byte [es:di],' '
 inc di
.no:
 ret
.field:
 push di
 call find_field
 pop di
 jc .no
.put:                             ; ES:SI, CX characters (within the block)
 cmp cx,600
 jbe .cp
 mov cx,600
.cp:
 jcxz .no
 mov al,[es:si]
 mov [es:di],al
 inc si
 inc di
 dec cx
 jmp .cp

%include "g1clip.inc"
%include "help.inc"

; ======================================================================
; strings
; ======================================================================
; copy NUL string CS:SI -> ES:DI (no terminator)
copy_cs:
 mov al,[cs:si]
 or al,al
 jz .d
 mov [es:di],al
 inc si
 inc di
 jmp copy_cs
.d:
 ret

; AX unsigned -> decimal at ES:DI
put_num:
 push bx
 push cx
 push dx
 mov cx,10
 xor bx,bx
.div:
 xor dx,dx
 div cx
 push dx
 inc bx
 or ax,ax
 jnz .div
.out:
 pop ax
 add al,'0'
 mov [es:di],al
 inc di
 dec bx
 jnz .out
 pop dx
 pop cx
 pop bx
 ret

; widths of URW Sans bold (= Helvetica-Bold) in 1/1000 em, GEOS character set
wtab:
 dw 278,278,278,278,278,278,278,278,278,278,278,278,278,278,278,278
 dw 278,278,278,278,278,278,278,278,278,278,278,278,278,278,278,278
 dw 278,333,474,556,556,889,722,238,333,333,389,584,278,333,278,278
 dw 556,556,556,556,556,556,556,556,556,556,333,333,584,584,584,611
 dw 975,722,722,722,722,667,611,778,722,278,556,722,611,833,722,778
 dw 667,778,722,667,611,722,667,944,667,667,611,333,278,333,584,556
 dw 333,556,611,556,611,556,333,611,611,278,278,556,278,889,611,611
 dw 611,611,389,556,333,611,556,778,556,556,500,389,280,389,584,500
 dw 722,722,722,667,722,778,722,556,556,556,556,556,556,556,556,556
 dw 556,556,278,278,278,278,611,611,611,611,611,611,611,611,611,611
 dw 556,400,556,556,556,350,556,611,737,737,1000,333,333,500,1000,778
 dw 500,584,500,500,556,611,500,500,500,500,500,370,365,500,889,611
 dw 611,333,584,500,556,500,500,556,556,1000,500,722,722,778,1000,944
 dw 556,1000,500,500,278,278,584,500,556,667,167,556,333,333,611,611
 dw 556,278,278,500,1000,722,667,722,667,667,278,278,278,278,778,778
 dw 500,778,722,722,722,278,333,333,333,333,333,333,333,333,333,333

; widths of URW Sans regular (= Helvetica)
wtab_r:
 dw 278,278,278,278,278,278,278,278,278,278,278,278,278,278,278,278
 dw 278,278,278,278,278,278,278,278,278,278,278,278,278,278,278,278
 dw 278,278,355,556,556,889,667,191,333,333,389,584,278,333,278,278
 dw 556,556,556,556,556,556,556,556,556,556,278,278,584,584,584,556
 dw 1015,667,667,722,722,667,611,778,722,278,500,667,556,833,722,778
 dw 667,778,722,667,611,722,667,944,667,667,611,278,278,278,469,556
 dw 333,556,556,500,556,556,278,556,556,222,222,500,222,833,556,556
 dw 556,556,333,500,278,556,500,722,500,500,500,334,260,334,584,500
 dw 667,667,722,667,722,778,722,556,556,556,556,556,556,500,556,556
 dw 556,556,278,278,278,278,556,556,556,556,556,556,556,556,556,556
 dw 556,400,556,556,556,350,537,611,737,737,1000,333,333,500,1000,778
 dw 500,584,500,500,556,556,500,500,500,500,500,370,365,500,889,611
 dw 611,333,584,500,556,500,500,556,556,1000,500,667,667,778,1000,944
 dw 556,1000,333,333,222,222,584,500,500,667,167,556,333,333,500,500
 dw 556,278,222,333,1000,667,667,667,667,667,278,278,278,278,778,778
 dw 500,778,722,722,722,278,333,333,333,333,333,333,333,333,333,333

G1_FINISH
