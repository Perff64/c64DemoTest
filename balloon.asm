    processor 6502

    org $0801

    ; BASIC stub: 10 SYS 2061 ($080D)
    .word next_line
    .word 10
    .byte $9e, "2061", 0
next_line:
    .word 0

start:
    jsr $ff81       ; Clear screen
    sei             ; Disable interrupts for smooth movement

    lda #$01
    sta $d015       ; Enable sprite 0

    lda #balloon_ptr ; Set sprite 0 pointer
    sta $07f8

    lda #160
    sta $d000       ; Initial X position
    lda #120
    sta $d001       ; Initial Y position
    lda $d010
    and #$fe        ; Clear MSB of X for sprite 0
    sta $d010

    lda #01         ; White color
    sta $d027

loop:
    ; Wait for raster line 255 for vertical sync
wait_ras:
    lda $d012
    cmp #$ff
    bne wait_ras

    lda $dc00       ; Read joystick port 2
    tay             ; Save reading in Y

    ; Check Fire button (bit 4) to exit
    and #$10
    beq exit

    ; Check Up (bit 0)
    tya
    and #$01
    bne skip_up
    dec $d001
skip_up:

    ; Check Down (bit 1)
    tya
    and #$02
    bne skip_down
    inc $d001
skip_down:

    ; Check Left (bit 2)
    tya
    and #$04
    bne skip_left
    jsr move_left
skip_left:

    ; Check Right (bit 3)
    tya
    and #$08
    bne skip_right
    jsr move_right
skip_right:

    jmp loop

exit:
    lda #$00
    sta $d015       ; Disable sprite 0
    cli             ; Re-enable interrupts
    rts             ; Return to BASIC

move_left:
    lda $d000
    sec
    sbc #$01
    sta $d000
    bcs .done_left
    lda $d010
    eor #$01
    sta $d010
.done_left:
    rts

move_right:
    lda $d000
    clc
    adc #$01
    sta $d000
    bcc .done_right
    lda $d010
    eor #$01
    sta $d010
.done_right:
    rts

    ; Align to 64-byte boundary for sprite data
    align 64
balloon_data:
    .byte 0,127,0,1,255,192,3,255,224,3,231,224,7,217,240,7,223,240,7,217,240,3,231,224,3,255,224,3,255,224,2,255,160,1,127,64,1,62,64,0,156,128,0,156,128,0,73,0,0,73,0,0,62,0,0,62,0,0,62,0,0,28,0,0

balloon_ptr = balloon_data / 64
