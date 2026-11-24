; SPDX-License-Identifier: MIT
; GeoLosung: help page as in GeoMaler (style of the GeoWorks help windows):
; title, white text page with bold headings and bullets, scroll bar,
; buttons "Seite hoch", "Seite runter", "Schliessen".
; Lines: help_text (helptext.inc), kind byte H/S/T/B/C/E + text + 0
; (C = continuation of a bullet, indented without a bullet).

%define H_SB      18        ; scroll bar width
%define H_TTOP    (BAR_H+26)
%define H_BTNW    116
%define H_BTNH    22
%define H_BTN     K_HBTN
%define H_BOT     K_HBOT
%define H_SBX     K_HSBX
%define H_T0      K_HT0
%define H_T1      K_HT1

; height of a line of kind AL -> AX
help_lh:
 mov ah,26
 cmp al,'H'
 je .r
 mov ah,8
 cmp al,'E'
 je .r
 mov ah,15
.r:
 mov al,ah
 xor ah,ah
 ret

; CS:SI at a line -> SI at the next one
help_next:
 inc si
.s:
 cmp byte [cs:si],0
 je .e
 inc si
 jmp .s
.e:
 inc si
 ret

; font: DX = size, AL = style bits (0x20 bold)
help_font:
 push ax
 push di
 mov cx,0x1200
 xor ah,ah
 KCALL 366                        ; GrSetFont URW Sans
 pop di
 pop ax
 push di
 mov ah,al
 not ah
 KCALL 362                        ; GrSetTextStyle
 pop di
 ret

paint_help:
 mov es,[V_BSEG]
 mov ax,[V_FH]
 sub ax,H_BTNH+12
 mov [es:H_BTN],ax
 sub ax,10
 mov [es:H_BOT],ax
 mov ax,[V_FW]
 sub ax,8+H_SB
 mov [es:H_SBX],ax
 ; title bar
 mov al,8
 call set_area
 mov ax,8
 mov bx,BAR_H+4
 mov cx,[V_FW]
 sub cx,8
 mov dx,BAR_H+22
 call fill
 mov al,15
 call set_tcol
 mov dx,12
 mov al,0x20
 call help_font
 mov si,s_htitle
 mov ax,16
 mov bx,BAR_H+6
 call text_cs
 ; white page with a black frame
 mov al,15
 call set_area
 mov es,[V_BSEG]
 mov ax,8
 mov bx,H_TTOP
 mov cx,[es:H_SBX]
 mov dx,[es:H_BOT]
 call fill
 xor al,al
 call set_line
 mov es,[V_BSEG]
 mov ax,7
 mov bx,H_TTOP-1
 mov cx,[es:H_SBX]
 mov dx,[es:H_BOT]
 call frame
 ; count the lines
 mov si,help_text
 xor cx,cx
.cnt:
 cmp byte [cs:si],0
 je .cntd
 call help_next
 inc cx
 jmp .cnt
.cntd:
 mov [V_NENT],cx
 mov ax,[V_LTOP]
 cmp ax,cx
 jb .t0
 xor ax,ax
 mov [V_LTOP],ax
.t0:
 ; skip to the first shown line
 mov si,help_text
 mov cx,[V_LTOP]
 jcxz .sk
.skl:
 call help_next
 loop .skl
.sk:
 xor al,al
 call set_tcol
 mov bx,H_TTOP+6                  ; y
 mov word [V_NROW],0
.line:
 mov al,[cs:si]
 or al,al
 jnz .l1
 jmp .ldone
.l1:
 push ax
 call help_lh
 mov dx,bx
 add dx,ax
 mov es,[V_BSEG]
 cmp dx,[es:H_BOT]
 pop ax
 jbe .l2
 jmp .ldone
.l2:
 push dx                          ; next y
 push si
 cmp al,'H'
 jne .nh
 push bx
 mov dx,12
 mov al,0x20
 call help_font
 pop bx
 inc si
 mov ax,18
 add bx,8
 call text_cs
 jmp .ln
.nh:
 cmp al,'E'
 je .ln
 mov cl,al
 push cx
 push bx
 mov dx,10
 xor al,al
 cmp cl,'S'
 jne .ns
 mov al,0x20
.ns:
 call help_font
 pop bx
 pop cx
 inc si
 mov ax,18
 cmp cl,'C'
 jne .nc
 mov ax,34
.nc:
 cmp cl,'B'
 jne .txt
 push si
 push bx
 mov si,s_bullet
 mov ax,22
 call text_cs
 pop bx
 pop si
 mov ax,34
.txt:
 call text_cs
.ln:
 pop si
 call help_next
 pop bx
 inc word [V_NROW]
 jmp .line
.ldone:
 mov dx,10                        ; buttons: URW Sans 10, plain
 xor al,al
 call help_font
 call help_scrollbar
 ; buttons
 mov es,[V_BSEG]
 mov ax,20
 mov si,s_hb0
 call help_button
 mov ax,[V_FW]
 sub ax,H_BTNW
 shr ax,1
 mov si,s_hb1
 call help_button
 mov ax,[V_FW]
 sub ax,H_BTNW+20
 mov si,s_hb2
 call help_button
 ret

; button with label CS:SI at x = AX, y = H_BTN
help_button:
 push si
 mov es,[V_BSEG]
 mov bx,[es:H_BTN]
 mov cx,ax
 add cx,H_BTNW
 mov dx,bx
 add dx,H_BTNH
 call hbevel
 push ax
 xor al,al
 call set_line
 pop ax
 call frame4
 ; label roughly centred (about 6 pixels per character)
 pop si
 push ax
 push bx
 xor cx,cx
.len:
 cmp byte [cs:si],0
 je .lend
 inc si
 inc cx
 jmp .len
.lend:
 sub si,cx
 mov ax,cx
 mov cl,6
 mul cl
 mov cx,H_BTNW
 sub cx,ax
 sar cx,1
 pop bx
 pop ax
 add ax,cx
 add bx,5
 push ax
 push bx
 xor al,al
 call set_tcol
 pop bx
 pop ax
 jmp text_cs

; raised box AX,BX - CX,DX (grey face, white top/left, dark bottom/right).
; Keeps AX..DX.
hbevel:
 push ax
 push bx
 push cx
 push dx
 push ax
 mov al,7
 call set_area
 pop ax
 call fill4
 push ax
 mov al,15
 call set_area
 pop ax
 push dx
 mov dx,bx
 inc dx
 call fill4
 pop dx
 push cx
 mov cx,ax
 inc cx
 call fill4
 pop cx
 push ax
 mov al,8
 call set_area
 pop ax
 push bx
 mov bx,dx
 dec bx
 call fill4
 pop bx
 push ax
 mov ax,cx
 dec ax
 call fill4
 pop ax
 pop dx
 pop cx
 pop bx
 pop ax
 ret
fill4:
 push ax
 push bx
 push cx
 push dx
 call fill
 pop dx
 pop cx
 pop bx
 pop ax
 ret

; scroll bar: arrow buttons, track, thumb
help_scrollbar:
 mov es,[V_BSEG]
 mov ax,[es:H_SBX]
 mov bx,H_TTOP-1
 mov cx,ax
 add cx,H_SB
 mov dx,[es:H_BOT]
 push ax
 mov al,8
 call set_area
 pop ax
 call fill4
 push ax
 xor al,al
 call set_line
 pop ax
 call frame4
 ; up arrow
 mov dx,bx
 add dx,H_SB
 call hbevel
 push ax
 push bx
 add ax,H_SB/2
 add bx,5
 mov cx,1                         ; pointing up
 call arrow
 pop bx
 pop ax
 ; down arrow
 mov cx,ax
 add cx,H_SB
 mov es,[V_BSEG]
 mov dx,[es:H_BOT]
 mov bx,dx
 sub bx,H_SB
 call hbevel
 add ax,H_SB/2
 add bx,H_SB-6
 xor cx,cx
 call arrow
 ; thumb: start and length proportional to the lines
 mov es,[V_BSEG]
 mov cx,[es:H_BOT]
 sub cx,H_TTOP+2*H_SB             ; track length
 jle .r
 mov bx,[V_NENT]
 or bx,bx
 jz .r
 mov ax,[V_LTOP]
 mul cx
 div bx
 add ax,H_TTOP+H_SB-1
 mov [es:H_T0],ax
 mov ax,[V_NROW]
 mul cx
 div bx
 cmp ax,12
 jge .tl
 mov ax,12
.tl:
 add ax,[es:H_T0]
 mov dx,[es:H_BOT]
 sub dx,H_SB
 cmp ax,dx
 jle .tm
 mov ax,dx
.tm:
 mov [es:H_T1],ax
 mov dx,ax
 mov bx,[es:H_T0]
 mov ax,[es:H_SBX]
 inc ax
 mov cx,ax
 add cx,H_SB-2
 call hbevel
.r:
 ret

; small black triangle, tip at AX,BX; CX = 1 up, 0 down
arrow:
 push ax
 xor al,al
 call set_area
 pop ax
 push si
 xor si,si
.l:
 cmp si,5
 jae .d
 push ax
 push bx
 push cx
 sub ax,si
 or cx,cx
 jz .dn
 add bx,si
 jmp .f
.dn:
 sub bx,si
.f:
 mov cx,ax
 add cx,si
 add cx,si
 inc cx
 mov dx,bx
 inc dx
 call fill
 pop cx
 pop bx
 pop ax
 inc si
 jmp .l
.d:
 pop si
 ret

; scroll by AX lines (signed)
help_scroll:
 add ax,[V_LTOP]
 jge .a
 xor ax,ax
.a:
 push ax
 call help_maxtop
 pop ax
 cmp ax,bx
 jle .c
 mov ax,bx
.c:
 mov [V_LTOP],ax
 ret
; first line from which the rest fits on the page -> BX
help_maxtop:
 mov es,[V_BSEG]
 mov dx,[es:H_BOT]
 sub dx,H_TTOP+6
 xor bx,bx
 mov si,help_text
.t:
 push si
 xor cx,cx
.s:
 mov al,[cs:si]
 or al,al
 jz .se
 call help_lh
 add cx,ax
 call help_next
 jmp .s
.se:
 pop si
 cmp cx,dx
 jbe .r
 call help_next
 inc bx
 jmp .t
.r:
 ret
help_page:                        ; AX = +1 / -1
 mov bx,[V_NROW]
 dec bx
 jg .p
 mov bx,1
.p:
 imul bx
 jmp help_scroll

; click in the help page: CX,DX window coordinates
help_click:
 mov es,[V_BSEG]
 mov ax,dx
 sub ax,[es:H_BTN]
 jl .sb
 cmp ax,H_BTNH
 jge .r
 ; buttons
 cmp cx,20
 jl .r
 cmp cx,20+H_BTNW
 jl .up
 mov ax,[V_FW]
 sub ax,H_BTNW
 shr ax,1
 cmp cx,ax
 jl .r
 add ax,H_BTNW
 cmp cx,ax
 jl .down
 mov ax,[V_FW]
 sub ax,H_BTNW+20
 cmp cx,ax
 jl .r
 add ax,H_BTNW
 cmp cx,ax
 jge .r
 mov word [V_MODE],0              ; Schliessen
 jmp .redraw
.sb:
 mov ax,[es:H_SBX]
 cmp cx,ax
 jl .r
 add ax,H_SB
 cmp cx,ax
 jge .r
 cmp dx,H_TTOP
 jl .r
 cmp dx,H_TTOP+H_SB
 jl .line_up
 mov ax,[es:H_BOT]
 cmp dx,ax
 jge .r
 sub ax,H_SB
 cmp dx,ax
 jge .line_down
 cmp dx,[es:H_T0]
 jl .up
 cmp dx,[es:H_T1]
 jg .down
 jmp .r
.line_up:
 mov ax,-3
 call help_scroll
 jmp .redraw
.line_down:
 mov ax,3
 call help_scroll
 jmp .redraw
.up:
 mov ax,-1
 call help_page
 jmp .redraw
.down:
 mov ax,1
 call help_page
.redraw:
 call repaint
.r:
 ret

; key in the help page: CL, CH
help_key:
 cmp cl,0x1b
 je .close
 cmp cl,0x0d
 je .close
 cmp ch,0xff
 jne .asc
 cmp cl,0x90
 je .up1
 cmp cl,0x91
 je .dn1
.asc:
 cmp cl,'8'
 je .up1
 cmp cl,'2'
 je .dn1
 cmp cl,'9'
 je .pup
 cmp cl,'3'
 je .pdn
 cmp cl,' '
 je .pdn
 ret
.close:
 mov word [V_MODE],0
 ret
.up1:
 mov ax,-1
 jmp help_scroll
.dn1:
 mov ax,1
 jmp help_scroll
.pup:
 mov ax,-1
 jmp help_page
.pdn:
 mov ax,1
 jmp help_page

s_htitle: db 'Hilfe zu GeoLosung',0
s_bullet: db 0xa5,0
s_hb0:    db 'Seite hoch',0
s_hb1:    db 'Seite runter',0
s_hb2:    db 'Schlie',0xa7,'en',0

%include "helptext.inc"

; helpers taken over from GeoMaler
text_cs:
 push ds
 push cs
 pop ds
 call text_ds
 pop ds
 ret
set_line:
 push di
 xor ah,ah
 KCALL 346                        ; GrSetLineColor
 pop di
 ret
frame:
 push di
 KCALL 316                        ; GrDrawRect
 pop di
 ret
frame4:
 push ax
 push bx
 push cx
 push dx
 call frame
 pop dx
 pop cx
 pop bx
 pop ax
 ret
