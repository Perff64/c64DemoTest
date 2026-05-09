    processor 6502

    ; --- Constants ---
VIC_BASE      = $d000
VIC_SCROLY    = $d011
VIC_RASTER    = $d012
VIC_SCROLX    = $d016
VIC_VMCSB     = $d018
VIC_INTERRUPT = $d019
VIC_IMR       = $d01a
VIC_BGCOL0    = $d021
VIC_MC1       = $d022
VIC_MC2       = $d023

SCREEN_RAM    = $0400
CHAR_RAM      = $2000

    ORG $0801
    ; BASIC stub: 10 SYS 2061
    .word next_line
    .word 10
    .byte $9e, "2061", 0
next_line:
    .word 0

start:
    sei
    lda #$7f
    sta $dc0d       ; Disable CIA interrupts
    sta $dd0d
    lda $dc0d       ; Acknowledge any pending CIA interrupts
    lda $dd0d

    lda #$01
    sta VIC_IMR     ; Enable raster interrupts

    lda #$1b        ; Standard screen height, etc.
    sta VIC_SCROLY
    lda #$00        ; Raster line 0
    sta VIC_RASTER

    lda #<irq_top
    sta $0314
    lda #>irq_top
    sta $0315

    ; --- Initialization ---
    jsr clear_screen
    jsr init_logo
    jsr init_chars
    jsr init_music

    lda #$00
    sta VIC_BGCOL0
    sta $d020       ; Border black

    lda #$0b        ; Multicolor colors
    sta VIC_MC1     ; Dark Grey
    lda #$01
    sta VIC_MC2     ; White

    cli

main_loop:
    jmp main_loop

; --- IRQ Handlers ---

irq_top:
    asl VIC_INTERRUPT ; Ack interrupt

    jsr play_music

    ; Set up logo area
    lda #$18        ; Screen at $0400, Chars at $2000 ($18 = %00011000)
    sta VIC_VMCSB

    ; Logo Sine Movement
    ldx sine_ptr
    lda sine_table,x
    lsr
    lsr
    lsr             ; Get character offset (0-2)
    tay
    clc
    adc #10         ; Base X position in chars
    sta logo_x_pos

    lda sine_table,x
    and #$07        ; Soft scroll
    eor #$07        ; Invert for right-to-left feel if needed, or keep
    ora #$18        ; Multicolor bit + 40 cols
    sta VIC_SCROLX

    inc sine_ptr
    lda sine_ptr
    and #$3f
    sta sine_ptr

    jsr update_logo_pos

    ; Set next interrupt for rasterbars
    lda #$80        ; Around line 128
    sta VIC_RASTER
    lda #<irq_bars
    sta $0314
    lda #>irq_bars
    sta $0315

    jmp $ea31

irq_bars:
    asl VIC_INTERRUPT

    ; Moving Rasterbars
    lda bar_y
    clc
    adc #$80
    sta .bar_start

    ldx #0
.bar_loop:
    lda bar_colors,x
    tay
.wait:
    lda VIC_RASTER
.bar_start = * + 1
    cmp #$80
    bcc .wait

    tya
    sta VIC_BGCOL0

    ; Update wait for next line
    inc .bar_start

    inx
    cpx #16
    bne .bar_loop

    lda #$00
    sta VIC_BGCOL0

    ; Move bars
    inc bar_tick
    lda bar_tick
    and #$3f
    tax
    lda sine_table,x
    lsr
    sta bar_y

    ; Set next interrupt for scrolltext
    lda #$f0        ; Bottom of screen
    sta VIC_RASTER
    lda #<irq_scroll
    sta $0314
    lda #>irq_scroll
    sta $0315

    jmp $ea31

irq_scroll:
    asl VIC_INTERRUPT

    ; Standard characters
    lda #$14        ; Screen $0400, Chars $1000 (default ROM)
    sta VIC_VMCSB

    lda scroll_soft
    and #$07
    ora #$08        ; 40 cols, no multicolor
    sta VIC_SCROLX

    jsr update_scroll

    ; Reset to top
    lda #$00
    sta VIC_RASTER
    lda #<irq_top
    sta $0314
    lda #>irq_top
    sta $0315

    jmp $ea31

; --- Subroutines ---

; SID Player
init_music:
    lda #0          ; Tune 0
    jsr $5fb2       ; Init address from SID header
    rts

play_music:
    jsr $5012       ; Play address from SID header
    rts

clear_screen:
    ldx #0
    lda #$20 ; Space
.lp:
    sta SCREEN_RAM,x
    sta SCREEN_RAM+250,x
    sta SCREEN_RAM+500,x
    sta SCREEN_RAM+750,x
    lda #$00 ; Black text for hidden areas
    sta $d800,x
    sta $d800+250,x
    sta $d800+500,x
    sta $d800+750,x
    dex
    bne .lp
    rts

init_logo:
    ; Data is copied in init_chars
    rts

update_logo_pos:
    ; Clear old logo line
    ldx #39
    lda #$20
.clear_lp: sta SCREEN_RAM + 40*5,x
    sta SCREEN_RAM + 40*6,x
    dex
    bpl .clear_lp

    ; Draw new logo position
    ldx #0
.l1: lda logo_chars,x
    ldy logo_x_pos
    sta SCREEN_RAM + 40*5,y
    lda #$07 ; Yellow
    sta $d800 + 40*5,y
    inc logo_x_pos
    inx
    cpx #10
    bne .l1

    ; Reset x_pos for second row
    lda logo_x_pos
    sec
    sbc #10
    sta logo_x_pos

    ldx #0
.l2: lda logo_chars+10,x
    ldy logo_x_pos
    sta SCREEN_RAM + 40*6,y
    lda #$07
    sta $d800 + 40*6,y
    inc logo_x_pos
    inx
    cpx #10
    bne .l2
    rts

init_chars:
    ldx #0
.c1:
    lda logo_data,x
    sta CHAR_RAM,x
    lda logo_data+100,x
    sta CHAR_RAM+100,x
    lda logo_data+200,x
    sta CHAR_RAM+200,x
    inx
    cpx #100
    bne .c1
    rts

update_scroll:
    lda scroll_soft
    sec
    sbc #1
    and #$07
    sta scroll_soft
    bcs .no_new_char

    ; Shift screen left
    ldx #0
.shift:
    lda SCREEN_RAM + 40*22 + 1,x
    sta SCREEN_RAM + 40*22,x
    lda #$01 ; White color for scroll
    sta $d800 + 40*22,x
    inx
    cpx #39
    bne .shift

    ; Add new char
    ldx scroll_ptr
    lda scroll_text,x
    sta SCREEN_RAM + 40*22 + 39
    lda #$01
    sta $d800 + 40*22 + 39

    inc scroll_ptr
    lda scroll_ptr
    cmp #<scroll_len
    bne .no_reset
    lda #0
    sta scroll_ptr
.no_reset:

.no_new_char:
    rts

; --- Data ---

logo_x_pos: .byte 15
bar_y: .byte 0
bar_tick: .byte 0

scroll_ptr: .byte 0
scroll_soft: .byte 0
scroll_len = 330
scroll_text:
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 23
    .byte  5, 12, 3, 15, 13, 5, 0, 20, 15, 0
    .byte  20, 8, 5, 0, 16, 5, 18, 6, 6, 0
    .byte  4, 5, 13, 15, 33, 0, 3, 15, 4, 5
    .byte  4, 0, 2, 25, 0, 10, 21, 12, 5, 19
    .byte  0, 21, 19, 9, 14, 7, 0, 20, 8, 5
    .byte  0, 16, 15, 23, 5, 18, 0, 15, 6, 0
    .byte  1, 9, 33, 0, 34, 14, 5, 23, 0, 7
    .byte  5, 14, 5, 18, 1, 20, 9, 15, 14, 0
    .byte  15, 6, 0, 4, 5, 13, 15, 0, 3, 15
    .byte  4, 9, 14, 7, 34, 0, 45, 0, 20, 8
    .byte  9, 19, 0, 9, 19, 0, 10, 21, 19, 20
    .byte  0, 20, 8, 5, 0, 2, 5, 7, 9, 14
    .byte  14, 9, 14, 7, 33, 0, 7, 18, 5, 5
    .byte  20, 19, 0, 7, 15, 0, 15, 21, 20, 0
    .byte  20, 15, 0, 20, 8, 5, 0, 12, 5, 7
    .byte  5, 14, 4, 1, 18, 25, 0, 7, 18, 15
    .byte  21, 16, 0, 34, 14, 15, 0, 14, 1, 13
    .byte  5, 34, 0, 1, 14, 4, 0, 1, 12, 12
    .byte  0, 9, 20, 19, 0, 13, 5, 13, 2, 5
    .byte  18, 19, 58, 0, 2, 15, 14, 15, 12, 0
    .byte  3, 5, 12, 20, 9, 3, 12, 0, 3, 25
    .byte  2, 5, 18, 2, 18, 1, 9, 14, 12, 0
    .byte  7, 8, 15, 19, 20, 18, 9, 4, 5, 18
    .byte  12, 0, 7, 9, 7, 1, 2, 25, 20, 5
    .byte  12, 0, 7, 15, 2, 21, 19, 12, 0, 12
    .byte  15, 21, 9, 19, 12, 0, 13, 1, 4, 13
    .byte  1, 14, 12, 0, 14, 5, 9, 12, 12, 0
    .byte  18, 15, 18, 12, 0, 19, 12, 5, 5, 16
    .byte  23, 1, 12, 11, 5, 18, 12, 0, 1, 14
    .byte  4, 0, 15, 6, 0, 3, 15, 21, 18, 19
    .byte  5, 0, 16, 5, 18, 6, 6, 0, 8, 9
    .byte  13, 19, 5, 12, 6, 33, 0, 11, 5, 5
    .byte  16, 0, 20, 8, 5, 0, 3, 54, 0, 19
    .byte  16, 9, 18, 9, 20, 0, 1, 12, 9, 22
    .byte  5, 33, 0, 0, 0, 0, 0, 0, 0, 0

sine_ptr: .byte 0
sine_table:
    .byte 10, 10, 11, 12, 13, 14, 15, 16, 17, 17
    .byte  18, 18, 19, 19, 19, 19, 20, 19, 19, 19
    .byte  19, 18, 18, 17, 17, 16, 15, 14, 13, 12
    .byte  11, 10, 10, 9, 8, 7, 6, 5, 4, 3
    .byte  2, 2, 1, 1, 0, 0, 0, 0, 0, 0
    .byte  0, 0, 0, 1, 1, 2, 2, 3, 4, 5
    .byte  6, 7, 8, 9

bar_colors:
    .byte $06, $0e, $03, $01, $01, $03, $0e, $06, $00, $00, $00, $00, $00, $00, $00, $00

logo_chars:
    .byte 0, 1, 4, 5, 8, 9, 12, 13, 16, 17 ; Top row
    .byte 2, 3, 6, 7, 10, 11, 14, 15, 18, 19 ; Bottom row

logo_data:
    .byte 85,170,255,255,255,170,85,85 ; P 0
    .byte 80,160,240,240,240,160,80,80 ; P 1
    .byte 85,85,80,160,240,240,160,80 ; P 2
    .byte 80,80,0,0,0,0,0,0 ; P 3
    .byte 85,170,255,255,255,170,85,85 ; E 0
    .byte 85,170,255,255,255,170,85,85 ; E 1
    .byte 85,85,85,170,255,255,170,85 ; E 2
    .byte 0,0,85,170,0,0,170,85 ; E 3
    .byte 85,170,255,255,255,170,85,85 ; R 0
    .byte 80,160,240,240,240,160,80,80 ; R 1
    .byte 85,85,85,170,240,240,160,80 ; R 2
    .byte 80,80,80,160,240,240,160,80 ; R 3
    .byte 85,170,255,255,255,170,85,85 ; F 0
    .byte 85,170,255,255,255,170,85,85 ; F 1
    .byte 80,80,80,160,240,240,160,80 ; F 2
    .byte 0,0,80,160,0,0,0,0 ; F 3
    .byte 85,170,255,255,255,170,85,85 ; F 0
    .byte 85,170,255,255,255,170,85,85 ; F 1
    .byte 80,80,80,160,240,240,160,80 ; F 2
    .byte 0,0,80,160,0,0,0,0 ; F 3

    ; SID Data at $5000
    ORG $5000
    incbin "commando_data.bin"
