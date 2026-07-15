    processor 6502

    org $c000

; ==============================================================================
; C64 REGISTER DEFINITIONER
; ==============================================================================
VIC_SCROLY    = $d011   ; VIC Control Register 1 (Bit 5 = Bitmap Mode)
VIC_SCROLX    = $d016   ; VIC Control Register 2 (Bit 4 = Multicolor Mode)
VIC_VMCSB     = $d018   ; VIC Memory Control Register (Screen & Bitmap base pointers)
CIA2_PORTA    = $dd00   ; CIA 2 Port A (Bits 0-1 = VIC Bank Select)

; ==============================================================================
; SUBRUTINE: show_bitmap_1
; Aktiverer det første bitmap-billede (placeret i $2000-$3FFF i VIC Bank 0).
; - VIC Bank 0: $0000-$3FFF
; - Bitmap-data ligger i $2000 (offset $2000 i Bank 0)
; - Skærm-RAM (farvedata) ligger i $0400 (offset $0400 i Bank 0)
; ==============================================================================
show_bitmap_1:
    ; 1. Vælg VIC Bank 0 ($0000-$3FFF)
    ; Bank 0 vælges ved at sætte de to laveste bits i $DD00 til %11 (værdi 3)
    ; Da bits 2-7 bruges til andre formål, ændrer vi kun de to laveste bits.
    lda CIA2_PORTA
    and #$fc            ; Nulstil bit 0 og 1
    ora #$03            ; Sæt bit 0 og 1 til %11 (Bank 0)
    sta CIA2_PORTA

    ; 2. Sæt skærm-RAM og bitmap placering via $D018
    ; Vi vil have skærm-RAM på $0400 (offset $0400) og bitmap på $2000 (offset $2000):
    ; - Skærm-RAM offset: $0400 -> overføres som %0001 i bit 4-7 af $D018 (værdi $10)
    ; - Bitmap offset: $2000 -> overføres som %1 i bit 3 af $D018 (værdi $08)
    ; - Samlet værdi: $10 + $08 = $18
    lda #$18
    sta VIC_VMCSB

    ; 3. Aktiver Bitmap-tilstand (BMM) i $D011
    ; Sæt bit 5 i $D011 til 1
    lda VIC_SCROLY
    ora #$20
    sta VIC_SCROLY

    ; 4. Sæt Hi-Res mode (standard) / Sørg for at Multicolor er slået fra
    ; Hires-tilstand kræver, at bit 4 i $D016 er 0.
    ; --- NOTE FOR MULTICOLOR ---
    ; Hvis du ønsker Multicolor bitmap, skal du ændre dette til:
    ;   lda VIC_SCROLX
    ;   ora #$10         ; Sæt bit 4 til 1 for Multicolor
    ;   sta VIC_SCROLX
    ; Husk også, at i multicolor-tilstand styres baggrundsfarven af $D021,
    ; og farve-RAM ($D800-$DBE7) styrer den tredje multicolor farve.
    lda VIC_SCROLX
    and #$ef            ; Nulstil bit 4 til 0 (Hi-Res mode)
    sta VIC_SCROLX

    rts

; ==============================================================================
; SUBRUTINE: show_bitmap_2
; Aktiverer det andet bitmap-billede (placeret i $4000-$5FFF i VIC Bank 1).
; - VIC Bank 1: $4000-$7FFF
; - Bitmap-data ligger i $4000 (offset $0000 i Bank 1)
; - Skærm-RAM (farvedata) ligger i $4400 (offset $0400 i Bank 1)
; ==============================================================================
show_bitmap_2:
    ; 1. Vælg VIC Bank 1 ($4000-$7FFF)
    ; Bank 1 vælges ved at sætte de to laveste bits i $DD00 til %10 (værdi 2)
    ; Da bits 2-7 bruges til andre formål, ændrer vi kun de to laveste bits.
    lda CIA2_PORTA
    and #$fc            ; Nulstil bit 0 og 1
    ora #$02            ; Sæt bit 0 og 1 til %10 (Bank 1)
    sta CIA2_PORTA

    ; 2. Sæt skærm-RAM og bitmap placering via $D018
    ; Vi vil have skærm-RAM på $4400 (offset $0400) og bitmap på $4000 (offset $0000):
    ; - Skærm-RAM offset: $0400 -> overføres som %0001 i bit 4-7 af $D018 (værdi $10)
    ; - Bitmap offset: $0000 -> overføres som %0 i bit 3 af $D018 (værdi $00)
    ; - Samlet værdi: $10 + $00 = $10
    lda #$10
    sta VIC_VMCSB

    ; 3. Aktiver Bitmap-tilstand (BMM) i $D011
    ; Sæt bit 5 i $D011 til 1
    lda VIC_SCROLY
    ora #$20
    sta VIC_SCROLY

    ; 4. Sæt Hi-Res mode (standard) / Sørg for at Multicolor er slået fra
    ; Hires-tilstand kræver, at bit 4 i $D016 er 0.
    ; --- NOTE FOR MULTICOLOR ---
    ; Hvis du ønsker Multicolor bitmap, skal du ændre dette til:
    ;   lda VIC_SCROLX
    ;   ora #$10         ; Sæt bit 4 til 1 for Multicolor
    ;   sta VIC_SCROLX
    lda VIC_SCROLX
    and #$ef            ; Nulstil bit 4 til 0 (Hi-Res mode)
    sta VIC_SCROLX

    rts
