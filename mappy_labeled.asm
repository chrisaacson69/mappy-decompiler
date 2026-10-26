; Mappy (Japan) PRG $C000-$FFFF  --  labeled disassembly, generated from
; labels.toml + vars.toml + jump_tables.txt (from-scratch RE; no external labels).


reset_cold_boot_init:
    C031: 78          sei
    C032: D8          cld
    C033: A2 5F       ldx #$5f
    C035: 9A          txs
    C036: A9 00       lda #$00
    C038: 8D 00 20    sta PPUCTRL   ; $2000
    C03B: 8D 01 20    sta PPUMASK   ; $2001
@C03E:
    C03E: AD 02 20    lda PPUSTATUS   ; $2002
    C041: 10 FB       bpl @C03E   ; $C03E
    C043: A9 07       lda #$07
    C045: 85 01       sta ptr_hi   ; $01
    C047: A9 00       lda #$00
    C049: 85 00       sta indirect_ptr   ; $00
    C04B: A8          tay
@C04C:
    C04C: 91 00       sta (indirect_ptr),y   ; $00
    C04E: C8          iny
    C04F: D0 FB       bne @C04C   ; $C04C
    C051: C6 01       dec ptr_hi   ; $01
    C053: D0 F7       bne @C04C   ; $C04C
    C055: 20 5C C2    jsr validate_magic_and_restore_state_vars   ; $C25C
    C058: A9 5A       lda #$5a
    C05A: 85 3E       sta $3e
    C05C: A9 A5       lda #$a5
    C05E: 85 3F       sta $3f
    C060: A0 00       ldy #$00
    C062: 20 28 C1    jsr start_game_thread   ; $C128
    C065: 20 B5 F4    jsr init_apu_channels_and_frame_counter   ; $F4B5
    C068: A9 88       lda #$88
    C06A: 8D 00 20    sta PPUCTRL   ; $2000

render_loop:
    C06D: A5 20       lda vblank_flag   ; $20
    C06F: F0 FC       beq render_loop   ; $C06D
    C071: A9 07       lda #$07
    C073: 8D 14 40    sta OAMDMA   ; $4014
    C076: 20 50 C1    jsr flush_vram_write_queue   ; $C150
    C079: 20 C9 C1    jsr read_and_decode_input   ; $C1C9
    C07C: 20 D0 C0    jsr build_sprite_row_oam_shadow   ; $C0D0
    C07F: A2 14       ldx #$14
    C081: 86 2C       stx oam_cursor   ; $2C
    C083: A5 28       lda camera_x_lo   ; $28
    C085: 85 10       sta src_ptr   ; $10
    C087: A5 29       lda camera_x   ; $29
    C089: 06 10       asl src_ptr   ; $10
    C08B: 2A          rol a
    C08C: 06 10       asl src_ptr   ; $10
    C08E: 2A          rol a
    C08F: 06 10       asl src_ptr   ; $10
    C091: 2A          rol a
    C092: 8D 05 20    sta PPUSCROLL   ; $2005
    C095: A9 00       lda #$00
    C097: 8D 05 20    sta PPUSCROLL   ; $2005
    C09A: A9 88       lda #$88
    C09C: 69 00       adc #$00
    C09E: 8D 00 20    sta PPUCTRL   ; $2000
    C0A1: 20 F1 F4    jsr update_sound_frame   ; $F4F1
    C0A4: A5 23       lda paused   ; $23
    C0A6: F0 0D       beq @C0B5   ; $C0B5
    C0A8: 20 35 D7    jsr show_player_up_label   ; $D735
    C0AB: A5 24       lda draw_data_ptr   ; $24
    C0AD: 29 03       and #$03
    C0AF: C9 01       cmp #$01
    C0B1: D0 14       bne @C0C7   ; $C0C7
    C0B3: F0 12       beq @C0C7   ; $C0C7
@C0B5:
    C0B5: A5 24       lda draw_data_ptr   ; $24
    C0B7: 29 03       and #$03
    C0B9: C9 01       cmp #$01
    C0BB: D0 02       bne @C0BF   ; $C0BF
    C0BD: EA          nop
    C0BE: EA          nop
@C0BF:
    C0BF: 20 C9 C7    jsr flush_dirty_attribute_bytes   ; $C7C9
    C0C2: A0 00       ldy #$00
    C0C4: 20 46 C1    jsr swap_stack_pointer   ; $C146
@C0C7:
    C0C7: E6 21       inc frame_counter   ; $21
    C0C9: A9 00       lda #$00
    C0CB: 85 20       sta vblank_flag   ; $20
    C0CD: 4C 6D C0    jmp render_loop   ; $C06D

build_sprite_row_oam_shadow:
    C0D0: A2 00       ldx #$00
    C0D2: A5 23       lda paused   ; $23
    C0D4: F0 41       beq @C117   ; $C117
    C0D6: A5 24       lda draw_data_ptr   ; $24
    C0D8: 29 03       and #$03
    C0DA: C9 01       cmp #$01
    C0DC: EA          nop
    C0DD: EA          nop
    C0DE: A9 68       lda #$68
    C0E0: 85 10       sta src_ptr   ; $10
    C0E2: A0 67       ldy #$67
    C0E4: A5 21       lda frame_counter   ; $21
    C0E6: 29 10       and #$10
    C0E8: D0 02       bne @C0EC   ; $C0EC
    C0EA: A0 F7       ldy #$f7
@C0EC:
    C0EC: 84 11       sty zp_ptr_hi   ; $11
    C0EE: A0 00       ldy #$00
@C0F0:
    C0F0: A5 11       lda zp_ptr_hi   ; $11
    C0F2: 9D 00 07    sta $0700,x
    C0F5: E8          inx
    C0F6: B9 23 C1    lda $c123,y
    C0F9: C8          iny
    C0FA: 9D 00 07    sta $0700,x
    C0FD: E8          inx
    C0FE: A9 02       lda #$02
    C100: 9D 00 07    sta $0700,x
    C103: E8          inx
    C104: A5 10       lda src_ptr   ; $10
    C106: 9D 00 07    sta $0700,x
    C109: 18          clc
    C10A: 69 08       adc #$08
    C10C: 85 10       sta src_ptr   ; $10
    C10E: E8          inx
    C10F: E0 14       cpx #$14
    C111: D0 DD       bne @C0F0   ; $C0F0
@C113:
    C113: E8          inx
    C114: 10 FD       bpl @C113   ; $C113
    C116: 60          rts
@C117:
    C117: A9 F7       lda #$f7
@C119:
    C119: 9D 00 07    sta $0700,x
    C11C: E8          inx
    C11D: E8          inx
    C11E: E8          inx
    C11F: E8          inx
    C120: D0 F7       bne @C119   ; $C119
    C122: 60          rts
    C123: D0          .byte $D0
    C124: D2          .byte $D2
    C125: DC          .byte $DC
    C126: CF          .byte $CF
    C127: D4          .byte $D4

start_game_thread:
    C128: B9 3E C1    lda $c13e,y
    C12B: 85 1E       sta obj_record_ptr   ; $1E
    C12D: B9 3F C1    lda $c13f,y
    C130: 85 1F       sta obj_record_ptr_hi   ; $1F
    C132: BA          tsx
    C133: 8A          txa
    C134: BE 40 C1    ldx $c140,y
    C137: 9D C1 00    sta thread_sp_slot,x   ; $00C1
    C13A: 9A          txs
    C13B: 6C 1E 00    jmp (obj_record_ptr)   ; $001E
    C13E:            .word title_screen
    C140: 3F          .byte $3F

yield_to_render_loop:
    C141: BA          tsx
    C142: 8A          txa
    C143: 29 C0       and #$c0
    C145: A8          tay

swap_stack_pointer:
    C146: BA          tsx
    C147: 8A          txa
    C148: BE 00 01    ldx $0100,y
    C14B: 99 00 01    sta $0100,y
    C14E: 9A          txs

handler_rts_noop:
    C14F: 60          rts

flush_vram_write_queue:
    C150: 20 41 C2    jsr ppu_disable_render   ; $C241
@C153:
    C153: E4 2A       cpx ppu_buffer_cursor   ; $2A
    C155: F0 1E       beq @C175   ; $C175
    C157: BC 00 05    ldy vram_buffer,x   ; $0500
    C15A: E8          inx
    C15B: BD 00 05    lda vram_buffer,x   ; $0500
    C15E: E8          inx
    C15F: 8D 06 20    sta PPUADDR   ; $2006
    C162: 8C 06 20    sty PPUADDR   ; $2006
    C165: BC 00 05    ldy vram_buffer,x   ; $0500
    C168: E8          inx
@C169:
    C169: BD 00 05    lda vram_buffer,x   ; $0500
    C16C: E8          inx
    C16D: 8D 07 20    sta PPUDATA   ; $2007
    C170: 88          dey
    C171: D0 F6       bne @C169   ; $C169
    C173: F0 DE       beq @C153   ; $C153
@C175:
    C175: A2 00       ldx #$00

flush_vram_readback_queue_and_restore_render:
    C177: E4 2B       cpx vram_queue_cursor   ; $2B
    C179: F0 27       beq @C1A2   ; $C1A2
    C17B: BC C0 04    ldy $04c0,x
    C17E: E8          inx
    C17F: BD C0 04    lda $04c0,x
    C182: E8          inx
    C183: 8D 06 20    sta PPUADDR   ; $2006
    C186: 8C 06 20    sty PPUADDR   ; $2006
    C189: BD C0 04    lda $04c0,x
    C18C: E8          inx
    C18D: 85 1E       sta obj_record_ptr   ; $1E
    C18F: BD C0 04    lda $04c0,x
    C192: E8          inx
    C193: 85 1F       sta obj_record_ptr_hi   ; $1F
    C195: AD 07 20    lda PPUDATA   ; $2007
    C198: AD 07 20    lda PPUDATA   ; $2007
    C19B: A0 08       ldy #$08
    C19D: 91 1E       sta (obj_record_ptr),y   ; $1E
    C19F: 4C 77 C1    jmp flush_vram_readback_queue_and_restore_render   ; $C177
@C1A2:
    C1A2: 20 39 C2    jsr ppu_enable_render   ; $C239
    C1A5: A9 00       lda #$00
    C1A7: 8D 05 20    sta PPUSCROLL   ; $2005
    C1AA: 8D 05 20    sta PPUSCROLL   ; $2005
    C1AD: A9 88       lda #$88
    C1AF: 8D 00 20    sta PPUCTRL   ; $2000
    C1B2: A6 2B       ldx vram_queue_cursor   ; $2B
@C1B4:
    C1B4: EA          nop
    C1B5: EA          nop
    C1B6: E8          inx
    C1B7: E0 40       cpx #$40
    C1B9: D0 F9       bne @C1B4   ; $C1B4
    C1BB: A6 2A       ldx ppu_buffer_cursor   ; $2A
@C1BD:
    C1BD: EA          nop
    C1BE: EA          nop
    C1BF: EA          nop
    C1C0: EA          nop
    C1C1: E8          inx
    C1C2: D0 F9       bne @C1BD   ; $C1BD
    C1C4: 86 2A       stx ppu_buffer_cursor   ; $2A
    C1C6: 86 2B       stx vram_queue_cursor   ; $2B
    C1C8: 60          rts

read_and_decode_input:
    C1C9: A2 01       ldx #$01
    C1CB: 8E 16 40    stx JOY1   ; $4016
    C1CE: CA          dex
    C1CF: 8E 16 40    stx JOY1   ; $4016
    C1D2: 20 49 C2    jsr read_joypad   ; $C249
    C1D5: E8          inx
    C1D6: 20 49 C2    jsr read_joypad   ; $C249
    C1D9: A5 41       lda game_state_flags   ; $41
    C1DB: 49 01       eor #$01
    C1DD: AA          tax
    C1DE: 76 10       ror src_ptr,x   ; $10
    C1E0: 76 10       ror src_ptr,x   ; $10
    C1E2: A6 41       ldx game_state_flags   ; $41
    C1E4: 76 10       ror src_ptr,x   ; $10
    C1E6: 2A          rol a
    C1E7: 76 10       ror src_ptr,x   ; $10
    C1E9: 2A          rol a
    C1EA: 29 03       and #$03
    C1EC: C9 01       cmp #$01
    C1EE: 26 22       rol scan_ptr   ; $22
    C1F0: 66 11       ror zp_ptr_hi   ; $11
    C1F2: 66 10       ror src_ptr   ; $10
    C1F4: 26 24       rol draw_data_ptr   ; $24
    C1F6: 66 11       ror zp_ptr_hi   ; $11
    C1F8: 66 10       ror src_ptr   ; $10
    C1FA: 26 25       rol joypad_state   ; $25
    C1FC: B5 10       lda src_ptr,x   ; $10
    C1FE: 29 0F       and #$0f
    C200: 4A          lsr a
    C201: 4A          lsr a
    C202: AA          tax
    C203: BD 58 C2    lda $c258,x
    C206: A2 00       ldx #$00
    C208: C5 26       cmp pad_dir   ; $26
    C20A: F0 01       beq @C20D   ; $C20D
    C20C: E8          inx
@C20D:
    C20D: 85 26       sta pad_dir   ; $26
    C20F: 86 27       stx pad_dir_changed   ; $27
    C211: A5 42       lda game_phase   ; $42
    C213: F0 1F       beq @C234   ; $C234
    C215: A5 4F       lda round_cleared   ; $4F
    C217: 05 4B       ora player_down   ; $4B
    C219: D0 19       bne @C234   ; $C234
    C21B: AD 0F 04    lda $040f
    C21E: F0 14       beq @C234   ; $C234
    C220: A5 25       lda joypad_state   ; $25
    C222: 29 03       and #$03
    C224: C9 01       cmp #$01
    C226: D0 0B       bne @C233   ; $C233
    C228: 45 23       eor paused   ; $23
    C22A: 85 23       sta paused   ; $23
    C22C: F0 05       beq @C233   ; $C233
    C22E: A9 01       lda #$01
    C230: 8D 00 06    sta sound_trigger   ; $0600
@C233:
    C233: 60          rts
@C234:
    C234: A9 00       lda #$00
    C236: 85 23       sta paused   ; $23
    C238: 60          rts

ppu_enable_render:
    C239: A2 1E       ldx #$1e
    C23B: 8E 01 20    stx PPUMASK   ; $2001
    C23E: 86 2D       stx ppu_mask_shadow   ; $2D
    C240: 60          rts

ppu_disable_render:
    C241: A2 00       ldx #$00
    C243: 8E 01 20    stx PPUMASK   ; $2001
    C246: 86 2D       stx ppu_mask_shadow   ; $2D
    C248: 60          rts

read_joypad:
    C249: A0 08       ldy #$08
@C24B:
    C24B: BD 16 40    lda JOY1,x   ; $4016
    C24E: 29 03       and #$03
    C250: C9 01       cmp #$01
    C252: 76 10       ror src_ptr,x   ; $10
    C254: 88          dey
    C255: D0 F4       bne @C24B   ; $C24B
    C257: 60          rts
    C258: 00          .byte $00
    C259: FF          .byte $FF
    C25A: 01          .byte $01
    C25B: 00          .byte $00

validate_magic_and_restore_state_vars:
    C25C: A5 3E       lda $3e
    C25E: C9 5A       cmp #$5a
    C260: D0 45       bne @C2A7   ; $C2A7
    C262: A5 3F       lda $3f
    C264: C9 A5       cmp #$a5
    C266: D0 3F       bne @C2A7   ; $C2A7
    C268: A5 41       lda game_state_flags   ; $41
    C26A: F0 03       beq @C26F   ; $C26F
    C26C: 20 81 CA    jsr swap_player_state   ; $CA81
@C26F:
    C26F: 20 B3 C2    jsr pack_state_vars_into_zp_buffer   ; $C2B3
    C272: 20 E5 C2    jsr clear_zeropage_from_20   ; $C2E5
    C275: A2 01       ldx #$01
    C277: B5 00       lda indirect_ptr,x   ; $00
    C279: E8          inx
    C27A: 85 40       sta two_player_game   ; $40
    C27C: B5 00       lda indirect_ptr,x   ; $00
    C27E: E8          inx
    C27F: 85 41       sta game_state_flags   ; $41
    C281: B5 00       lda indirect_ptr,x   ; $00
    C283: E8          inx
    C284: 85 4A       sta seq_data_ptr   ; $4A
    C286: B5 00       lda indirect_ptr,x   ; $00
    C288: E8          inx
    C289: 85 77       sta ppu_block_src_ptr   ; $77
    C28B: A0 71       ldy #$71
    C28D: 20 97 C2    jsr copy_4_bytes_zp_to_ram   ; $C297
    C290: A0 B1       ldy #$b1
    C292: 20 97 C2    jsr copy_4_bytes_zp_to_ram   ; $C297
    C295: A0 44       ldy #$44

copy_4_bytes_zp_to_ram:
    C297: A9 04       lda #$04
    C299: 85 00       sta indirect_ptr   ; $00
@C29B:
    C29B: B5 00       lda indirect_ptr,x   ; $00
    C29D: E8          inx
    C29E: 99 00 00    sta indirect_ptr,y   ; $0000
    C2A1: C8          iny
    C2A2: C6 00       dec indirect_ptr   ; $00
    C2A4: D0 F5       bne @C29B   ; $C29B
    C2A6: 60          rts
@C2A7:
    C2A7: 20 E5 C2    jsr clear_zeropage_from_20   ; $C2E5
    C2AA: A9 02       lda #$02
    C2AC: 85 45       sta $45
    C2AE: A9 01       lda #$01
    C2B0: 85 77       sta ppu_block_src_ptr   ; $77
    C2B2: 60          rts

pack_state_vars_into_zp_buffer:
    C2B3: A2 01       ldx #$01
    C2B5: A5 40       lda two_player_game   ; $40
    C2B7: 95 00       sta indirect_ptr,x   ; $00
    C2B9: E8          inx
    C2BA: A5 41       lda game_state_flags   ; $41
    C2BC: 95 00       sta indirect_ptr,x   ; $00
    C2BE: E8          inx
    C2BF: A5 4A       lda seq_data_ptr   ; $4A
    C2C1: 95 00       sta indirect_ptr,x   ; $00
    C2C3: E8          inx
    C2C4: A5 77       lda ppu_block_src_ptr   ; $77
    C2C6: 95 00       sta indirect_ptr,x   ; $00
    C2C8: E8          inx
    C2C9: A0 71       ldy #$71
    C2CB: 20 D5 C2    jsr copy_4_bytes_absy_to_zpx   ; $C2D5
    C2CE: A0 B1       ldy #$b1
    C2D0: 20 D5 C2    jsr copy_4_bytes_absy_to_zpx   ; $C2D5
    C2D3: A0 44       ldy #$44

copy_4_bytes_absy_to_zpx:
    C2D5: A9 04       lda #$04
    C2D7: 85 00       sta indirect_ptr   ; $00
@C2D9:
    C2D9: B9 00 00    lda indirect_ptr,y   ; $0000
    C2DC: C8          iny
    C2DD: 95 00       sta indirect_ptr,x   ; $00
    C2DF: E8          inx
    C2E0: C6 00       dec indirect_ptr   ; $00
    C2E2: D0 F5       bne @C2D9   ; $C2D9
    C2E4: 60          rts

clear_zeropage_from_20:
    C2E5: A2 20       ldx #$20
    C2E7: A9 00       lda #$00
@C2E9:
    C2E9: 95 00       sta indirect_ptr,x   ; $00
    C2EB: E8          inx
    C2EC: D0 FB       bne @C2E9   ; $C2E9
    C2EE: 60          rts

nmi_count_vblank:
    C2EF: 08          php
    C2F0: 48          pha
    C2F1: 8A          txa
    C2F2: 48          pha
    C2F3: 98          tya
    C2F4: 48          pha
    C2F5: A5 20       lda vblank_flag   ; $20
    C2F7: F0 03       beq @C2FC   ; $C2FC
    C2F9: 20 F1 F4    jsr update_sound_frame   ; $F4F1
@C2FC:
    C2FC: E6 20       inc vblank_flag   ; $20
    C2FE: 68          pla
    C2FF: A8          tay
    C300: 68          pla
    C301: AA          tax
    C302: 68          pla
    C303: 28          plp

irq_rti_stub:
    C304: 40          rti

draw_object:
    C305: A5 2C       lda oam_cursor   ; $2C
    C307: 48          pha
    C308: A0 00       ldy #$00
    C30A: 84 11       sty zp_ptr_hi   ; $11
    C30C: B1 1E       lda (obj_record_ptr),y   ; $1E
    C30E: C8          iny
    C30F: 38          sec
    C310: E5 28       sbc camera_x_lo   ; $28
    C312: 85 10       sta src_ptr   ; $10
    C314: B1 1E       lda (obj_record_ptr),y   ; $1E
    C316: C8          iny
    C317: E5 29       sbc camera_x   ; $29
    C319: 06 10       asl src_ptr   ; $10
    C31B: 2A          rol a
    C31C: 06 10       asl src_ptr   ; $10
    C31E: 2A          rol a
    C31F: 06 10       asl src_ptr   ; $10
    C321: 2A          rol a
    C322: 90 02       bcc @C326   ; $C326
    C324: C6 11       dec zp_ptr_hi   ; $11
@C326:
    C326: 85 10       sta src_ptr   ; $10
    C328: B1 1E       lda (obj_record_ptr),y   ; $1E
    C32A: C8          iny
    C32B: 85 16       sta sprite_y   ; $16
    C32D: B1 1E       lda (obj_record_ptr),y   ; $1E
    C32F: C8          iny
    C330: 06 16       asl sprite_y   ; $16
    C332: 2A          rol a
    C333: 06 16       asl sprite_y   ; $16
    C335: 2A          rol a
    C336: 06 16       asl sprite_y   ; $16
    C338: 2A          rol a
    C339: 85 16       sta sprite_y   ; $16
    C33B: 20 42 C3    jsr dispatch_object_draw_from_record   ; $C342
    C33E: 68          pla
    C33F: C5 2C       cmp oam_cursor   ; $2C
    C341: 60          rts

dispatch_object_draw_from_record:
    C342: B1 1E       lda (obj_record_ptr),y   ; $1E

dispatch_object_draw_by_anim:
    C344: 85 15       sta scratch_counter   ; $15
    C346: 29 FE       and #$fe
    C348: AA          tax
    C349: BD 56 C3    lda $c356,x
    C34C: 85 1C       sta aux_ptr   ; $1C
    C34E: BD 57 C3    lda $c357,x
    C351: 85 1D       sta aux_ptr_hi   ; $1D
    C353: 6C 1C 00    jmp (aux_ptr)   ; $001C
    C356:            .word handler_rts_noop
    C358:            .word draw_walk_cycle
    C35A:            .word draw_type_pose_10
    C35C:            .word draw_fall_bounce_pose
    C35E:            .word draw_door_wave
    C360:            .word draw_tile_3c_type1_flicker
    C362:            .word draw_stunned_pose
    C364:            .word draw_stunned_blinking
    C366:            .word draw_wave_score
    C368:            .word draw_slot2_still_pose
    C36A:            .word draw_slot2_large_pose
    C36C:            .word draw_player_death_animation
    C36E:            .word draw_bonus_goal_object
    C370:            .word handler_rts_noop
    C372:            .word draw_8_sprite_row_to_oam
    C374:            .word draw_player_caught_pose
    C376:            .word draw_knocked_out
    C378:            .word draw_drop_stun_points
    C37A:            .word draw_drop_recover_blink

draw_drop_stun_points:
    C37C: A9 AE       lda #$ae
    C37E: 85 12       sta gfx_src_ptr   ; $12
    C380: A9 00       lda #$00
    C382: 85 14       sta scan_src_ptr   ; $14
    C384: A9 03       lda #$03
    C386: 85 13       sta data_ptr_hi   ; $13
    C388: A5 1E       lda obj_record_ptr   ; $1E
    C38A: C9 20       cmp #$20
    C38C: D0 04       bne @C392   ; $C392
    C38E: A9 66       lda #$66
    C390: 85 12       sta gfx_src_ptr   ; $12
@C392:
    C392: 20 15 C4    jsr write_sprite_to_oam   ; $C415
    C395: A9 67       lda #$67
    C397: 85 12       sta gfx_src_ptr   ; $12
    C399: A5 10       lda src_ptr   ; $10
    C39B: 18          clc
    C39C: 69 08       adc #$08
    C39E: 85 10       sta src_ptr   ; $10
    C3A0: 90 02       bcc @C3A4   ; $C3A4
    C3A2: E6 11       inc zp_ptr_hi   ; $11
@C3A4:
    C3A4: 4C 15 C4    jmp write_sprite_to_oam   ; $C415

draw_drop_recover_blink:
    C3A7: A0 07       ldy #$07
    C3A9: B1 1E       lda (obj_record_ptr),y   ; $1E
    C3AB: 29 08       and #$08
    C3AD: F0 10       beq @C3BF   ; $C3BF
    C3AF: A9 06       lda #$06
    C3B1: 4C 44 C3    jmp dispatch_object_draw_by_anim   ; $C344

load_type_sprite_palette:
    C3B4: A0 05       ldy #$05
    C3B6: B1 1E       lda (obj_record_ptr),y   ; $1E
    C3B8: AA          tax
    C3B9: BD 7C C4    lda $c47c,x
    C3BC: 85 13       sta data_ptr_hi   ; $13
    C3BE: 8A          txa
@C3BF:
    C3BF: 60          rts

draw_walk_cycle:
    C3C0: 20 B4 C3    jsr load_type_sprite_palette   ; $C3B4
    C3C3: 0A          asl a
    C3C4: 0A          asl a
    C3C5: 85 12       sta gfx_src_ptr   ; $12
    C3C7: A0 07       ldy #$07
    C3C9: B1 1E       lda (obj_record_ptr),y   ; $1E
    C3CB: 4A          lsr a
    C3CC: 4A          lsr a
    C3CD: 29 03       and #$03
    C3CF: 05 12       ora gfx_src_ptr   ; $12

load_metasprite_tile_base:
    C3D1: AA          tax
    C3D2: BD 80 C4    lda $c480,x
    C3D5: 85 12       sta gfx_src_ptr   ; $12

apply_facing_flip:
    C3D7: A0 06       ldy #$06
    C3D9: B1 1E       lda (obj_record_ptr),y   ; $1E
    C3DB: 30 06       bmi flip_bits_to_tile_xor   ; $C3E3
    C3DD: A5 13       lda data_ptr_hi   ; $13
    C3DF: 49 40       eor #$40
    C3E1: 85 13       sta data_ptr_hi   ; $13

flip_bits_to_tile_xor:
    C3E3: A5 13       lda data_ptr_hi   ; $13
    C3E5: 2A          rol a
    C3E6: 2A          rol a
    C3E7: 2A          rol a
    C3E8: 29 03       and #$03
    C3EA: 85 14       sta scan_src_ptr   ; $14

draw_metasprite_2x2:
    C3EC: 20 01 C4    jsr draw_sprite_pair   ; $C401
    C3EF: A5 10       lda src_ptr   ; $10
    C3F1: 38          sec
    C3F2: E9 08       sbc #$08
    C3F4: 85 10       sta src_ptr   ; $10
    C3F6: B0 02       bcs @C3FA   ; $C3FA
    C3F8: C6 11       dec zp_ptr_hi   ; $11
@C3FA:
    C3FA: A5 16       lda sprite_y   ; $16
    C3FC: 18          clc
    C3FD: 69 08       adc #$08
    C3FF: 85 16       sta sprite_y   ; $16

draw_sprite_pair:
    C401: 20 0F C4    jsr write_sprite_next_tile   ; $C40F
    C404: A5 10       lda src_ptr   ; $10
    C406: 18          clc
    C407: 69 08       adc #$08
    C409: 85 10       sta src_ptr   ; $10
    C40B: 90 02       bcc write_sprite_next_tile   ; $C40F
    C40D: E6 11       inc zp_ptr_hi   ; $11

write_sprite_next_tile:
    C40F: 20 15 C4    jsr write_sprite_to_oam   ; $C415
    C412: E6 12       inc gfx_src_ptr   ; $12
    C414: 60          rts

write_sprite_to_oam:
    C415: A5 11       lda zp_ptr_hi   ; $11
    C417: D0 3B       bne @C454   ; $C454
    C419: A5 10       lda src_ptr   ; $10
    C41B: C9 F9       cmp #$f9
    C41D: B0 35       bcs @C454   ; $C454
    C41F: A6 2C       ldx oam_cursor   ; $2C
    C421: E0 34       cpx #$34
    C423: 90 0E       bcc @C433   ; $C433
    C425: A5 21       lda frame_counter   ; $21
    C427: 29 0F       and #$0f
    C429: A8          tay
    C42A: 8A          txa
    C42B: 59 55 C4    eor $c455,y
    C42E: C9 34       cmp #$34
    C430: 90 01       bcc @C433   ; $C433
    C432: AA          tax
@C433:
    C433: A5 16       lda sprite_y   ; $16
    C435: 38          sec
    C436: E9 01       sbc #$01
    C438: 9D 00 07    sta $0700,x
    C43B: A5 12       lda gfx_src_ptr   ; $12
    C43D: 45 14       eor scan_src_ptr   ; $14
    C43F: 9D 01 07    sta $0701,x
    C442: 20 65 C4    jsr sprite_attr_with_priority   ; $C465
    C445: 9D 02 07    sta $0702,x
    C448: A5 10       lda src_ptr   ; $10
    C44A: 9D 03 07    sta $0703,x
    C44D: A5 2C       lda oam_cursor   ; $2C
    C44F: 18          clc
    C450: 69 04       adc #$04
    C452: 85 2C       sta oam_cursor   ; $2C
@C454:
    C454: 60          rts
    C455: 00          .byte $00
    C456: F0          .byte $F0
    C457: 20          .byte $20
    C458: D0          .byte $D0
    C459: 40          .byte $40
    C45A: B0          .byte $B0
    C45B: 60          .byte $60
    C45C: 90          .byte $90
    C45D: 80          .byte $80
    C45E: 70          .byte $70
    C45F: A0          .byte $A0
    C460: 50          .byte $50
    C461: C0          .byte $C0
    C462: 30          .byte $30
    C463: E0          .byte $E0
    C464: 10          .byte $10

sprite_attr_with_priority:
    C465: A5 7C       lda is_bonus_round   ; $7C
    C467: D0 10       bne @C479   ; $C479
    C469: A5 15       lda scratch_counter   ; $15
    C46B: 4A          lsr a
    C46C: B0 06       bcs @C474   ; $C474
    C46E: A5 16       lda sprite_y   ; $16
    C470: C9 40       cmp #$40
    C472: B0 05       bcs @C479   ; $C479
@C474:
    C474: A5 13       lda data_ptr_hi   ; $13
    C476: 09 20       ora #$20
    C478: 60          rts
@C479:
    C479: A5 13       lda data_ptr_hi   ; $13
    C47B: 60          rts
    C47C: 00          .byte $00
    C47D: 02          .byte $02
    C47E: 02          .byte $02
    C47F: 01          .byte $01
    C480: 04          .byte $04
    C481: 00          .byte $00
    C482: 04          .byte $04
    C483: 00          .byte $00
    C484: 74          .byte $74
    C485: 78          .byte $78
    C486: 7C          .byte $7C
    C487: A4          .byte $A4
    C488: 34          .byte $34
    C489: 38          .byte $38
    C48A: 34          .byte $34
    C48B: 30          .byte $30
    C48C: 1C          .byte $1C
    C48D: 18          .byte $18
    C48E: 1C          .byte $1C
    C48F: 18          .byte $18
    C490: 10          .byte $10
    C491: 74          .byte $74
    C492: 48          .byte $48
    C493: 28          .byte $28
    C494: 08          .byte $08
    C495: 0C          .byte $0C
    C496: 08          .byte $08
    C497: 0C          .byte $0C
    C498: 74          .byte $74
    C499: 78          .byte $78
    C49A: 7C          .byte $7C
    C49B: A4          .byte $A4
    C49C: 40          .byte $40
    C49D: 44          .byte $44
    C49E: 40          .byte $40
    C49F: 44          .byte $44
    C4A0: 20          .byte $20
    C4A1: 24          .byte $24
    C4A2: 20          .byte $20
    C4A3: 24          .byte $24
    C4A4: 14          .byte $14
    C4A5: A8          .byte $A8
    C4A6: 4C          .byte $4C
    C4A7: 2C          .byte $2C

draw_type_pose_10:
    C4A8: 20 B4 C3    jsr load_type_sprite_palette   ; $C3B4
    C4AB: 09 10       ora #$10
    C4AD: 4C D1 C3    jmp load_metasprite_tile_base   ; $C3D1

draw_fall_bounce_pose:
    C4B0: 20 B4 C3    jsr load_type_sprite_palette   ; $C3B4
    C4B3: 0A          asl a
    C4B4: 0A          asl a
    C4B5: 69 14       adc #$14
    C4B7: 85 12       sta gfx_src_ptr   ; $12
    C4B9: A0 07       ldy #$07
    C4BB: B1 1E       lda (obj_record_ptr),y   ; $1E
    C4BD: 29 0C       and #$0c
    C4BF: 4A          lsr a
    C4C0: 4A          lsr a
    C4C1: 05 12       ora gfx_src_ptr   ; $12
    C4C3: 4C D1 C3    jmp load_metasprite_tile_base   ; $C3D1

draw_door_wave:
    C4C6: A5 21       lda frame_counter   ; $21
    C4C8: 4A          lsr a
    C4C9: 29 03       and #$03
    C4CB: 85 13       sta data_ptr_hi   ; $13
    C4CD: A9 50       lda #$50
    C4CF: 85 12       sta gfx_src_ptr   ; $12
    C4D1: A0 06       ldy #$06
    C4D3: B1 1E       lda (obj_record_ptr),y   ; $1E
    C4D5: 30 06       bmi @C4DD   ; $C4DD
    C4D7: A5 13       lda data_ptr_hi   ; $13
    C4D9: 09 40       ora #$40
    C4DB: 85 13       sta data_ptr_hi   ; $13
@C4DD:
    C4DD: 20 E3 C3    jsr flip_bits_to_tile_xor   ; $C3E3
    C4E0: A5 10       lda src_ptr   ; $10
    C4E2: 38          sec
    C4E3: E9 08       sbc #$08
    C4E5: 85 10       sta src_ptr   ; $10
    C4E7: B0 02       bcs @C4EB   ; $C4EB
    C4E9: C6 11       dec zp_ptr_hi   ; $11
@C4EB:
    C4EB: A5 16       lda sprite_y   ; $16
    C4ED: 18          clc
    C4EE: 69 08       adc #$08
    C4F0: 85 16       sta sprite_y   ; $16
    C4F2: 4C E3 C3    jmp flip_bits_to_tile_xor   ; $C3E3

draw_tile_3c_type1_flicker:
    C4F5: A9 3C       lda #$3c
    C4F7: 85 12       sta gfx_src_ptr   ; $12
    C4F9: A0 05       ldy #$05
    C4FB: B1 1E       lda (obj_record_ptr),y   ; $1E
    C4FD: C9 01       cmp #$01
    C4FF: D0 08       bne @C509   ; $C509
    C501: A0 41       ldy #$41
    C503: A5 21       lda frame_counter   ; $21
    C505: 29 10       and #$10
    C507: D0 02       bne @C50B   ; $C50B
@C509:
    C509: A0 01       ldy #$01
@C50B:
    C50B: 84 13       sty data_ptr_hi   ; $13
    C50D: 4C E3 C3    jmp flip_bits_to_tile_xor   ; $C3E3

draw_stunned_blinking:
    C510: A0 07       ldy #$07
    C512: B1 1E       lda (obj_record_ptr),y   ; $1E
    C514: 29 08       and #$08
    C516: D0 08       bne @C520   ; $C520

draw_stunned_pose:
    C518: 20 B4 C3    jsr load_type_sprite_palette   ; $C3B4
    C51B: 09 24       ora #$24
    C51D: 4C D1 C3    jmp load_metasprite_tile_base   ; $C3D1
@C520:
    C520: 60          rts

draw_wave_score:
    C521: A5 21       lda frame_counter   ; $21
    C523: 4A          lsr a
    C524: 29 03       and #$03
    C526: 85 13       sta data_ptr_hi   ; $13
    C528: A9 00       lda #$00
    C52A: 85 14       sta scan_src_ptr   ; $14
    C52C: A0 07       ldy #$07
    C52E: B1 1E       lda (obj_record_ptr),y   ; $1E
    C530: 08          php
    C531: 0A          asl a
    C532: AA          tax
    C533: 20 40 C5    jsr draw_two_score_columns   ; $C540
    C536: A2 28       ldx #$28
    C538: 20 40 C5    jsr draw_two_score_columns   ; $C540
    C53B: 28          plp
    C53C: 10 24       bpl @C562   ; $C562
    C53E: A2 2C       ldx #$2c

draw_two_score_columns:
    C540: 20 43 C5    jsr draw_score_column   ; $C543

draw_score_column:
    C543: 20 63 C5    jsr draw_score_tile_if_any   ; $C563
    C546: A5 16       lda sprite_y   ; $16
    C548: 18          clc
    C549: 69 08       adc #$08
    C54B: 85 16       sta sprite_y   ; $16
    C54D: 20 63 C5    jsr draw_score_tile_if_any   ; $C563
    C550: A5 16       lda sprite_y   ; $16
    C552: 38          sec
    C553: E9 08       sbc #$08
    C555: 85 16       sta sprite_y   ; $16
    C557: A5 10       lda src_ptr   ; $10
    C559: 18          clc
    C55A: 69 08       adc #$08
    C55C: 85 10       sta src_ptr   ; $10
    C55E: 90 02       bcc @C562   ; $C562
    C560: E6 11       inc zp_ptr_hi   ; $11
@C562:
    C562: 60          rts

draw_score_tile_if_any:
    C563: BD 73 C5    lda $c573,x
    C566: F0 09       beq @C571   ; $C571
    C568: 85 12       sta gfx_src_ptr   ; $12
    C56A: 86 17       stx draw_row_counter   ; $17
    C56C: 20 15 C4    jsr write_sprite_to_oam   ; $C415
    C56F: A6 17       ldx draw_row_counter   ; $17
@C571:
    C571: E8          inx
    C572: 60          rts
    C573: 00          .byte $00
    C574: 00          .byte $00
    C575: 58          .byte $58
    C576: 5C          .byte $5C
    C577: 00          .byte $00
    C578: 00          .byte $00
    C579: 5E          .byte $5E
    C57A: 5F          .byte $5F
    C57B: 00          .byte $00
    C57C: 00          .byte $00
    C57D: 58          .byte $58
    C57E: 64          .byte $64
    C57F: 5A          .byte $5A
    C580: 5B          .byte $5B
    C581: 58          .byte $58
    C582: 5C          .byte $5C
    C583: 5A          .byte $5A
    C584: 5B          .byte $5B
    C585: 62          .byte $62
    C586: 63          .byte $63
    C587: 58          .byte $58
    C588: 5C          .byte $5C
    C589: 58          .byte $58
    C58A: 59          .byte $59
    C58B: 58          .byte $58
    C58C: 5D          .byte $5D
    C58D: 58          .byte $58
    C58E: 59          .byte $59
    C58F: 5E          .byte $5E
    C590: 5F          .byte $5F
    C591: 58          .byte $58
    C592: 59          .byte $59
    C593: 60          .byte $60
    C594: 61          .byte $61
    C595: 58          .byte $58
    C596: 59          .byte $59
    C597: 62          .byte $62
    C598: 63          .byte $63
    C599: 58          .byte $58
    C59A: 59          .byte $59
    C59B: 58          .byte $58
    C59C: 59          .byte $59
    C59D: 58          .byte $58
    C59E: 59          .byte $59
    C59F: 00          .byte $00
    C5A0: 65          .byte $65
    C5A1: 58          .byte $58
    C5A2: 5C          .byte $5C

draw_slot2_still_pose:
    C5A3: A9 02       lda #$02
    C5A5: 85 13       sta data_ptr_hi   ; $13
    C5A7: A9 70       lda #$70
    C5A9: 85 12       sta gfx_src_ptr   ; $12
    C5AB: A9 00       lda #$00
    C5AD: 85 14       sta scan_src_ptr   ; $14
    C5AF: 4C EC C3    jmp draw_metasprite_2x2   ; $C3EC

draw_slot2_large_pose:
    C5B2: A9 02       lda #$02
    C5B4: 85 13       sta data_ptr_hi   ; $13
    C5B6: A9 00       lda #$00
    C5B8: 85 14       sta scan_src_ptr   ; $14
    C5BA: A9 69       lda #$69
    C5BC: 85 12       sta gfx_src_ptr   ; $12
    C5BE: A5 10       lda src_ptr   ; $10
    C5C0: 38          sec
    C5C1: E9 08       sbc #$08
    C5C3: 85 10       sta src_ptr   ; $10
    C5C5: B0 02       bcs @C5C9   ; $C5C9
    C5C7: C6 11       dec zp_ptr_hi   ; $11
@C5C9:
    C5C9: A5 16       lda sprite_y   ; $16
    C5CB: 38          sec
    C5CC: E9 08       sbc #$08
    C5CE: 85 16       sta sprite_y   ; $16
    C5D0: 20 01 C4    jsr draw_sprite_pair   ; $C401
    C5D3: A5 10       lda src_ptr   ; $10
    C5D5: 38          sec
    C5D6: E9 08       sbc #$08
    C5D8: 85 10       sta src_ptr   ; $10
    C5DA: B0 02       bcs @C5DE   ; $C5DE
    C5DC: C6 11       dec zp_ptr_hi   ; $11
@C5DE:
    C5DE: A5 16       lda sprite_y   ; $16
    C5E0: 18          clc
    C5E1: 69 08       adc #$08
    C5E3: 85 16       sta sprite_y   ; $16
    C5E5: 20 0F C4    jsr write_sprite_next_tile   ; $C40F
    C5E8: A5 10       lda src_ptr   ; $10
    C5EA: 18          clc
    C5EB: 69 08       adc #$08
    C5ED: 85 10       sta src_ptr   ; $10
    C5EF: 90 02       bcc @C5F3   ; $C5F3
    C5F1: E6 11       inc zp_ptr_hi   ; $11
@C5F3:
    C5F3: 4C EC C3    jmp draw_metasprite_2x2   ; $C3EC

draw_player_death_animation:
    C5F6: A9 00       lda #$00
    C5F8: 85 13       sta data_ptr_hi   ; $13
    C5FA: A0 07       ldy #$07
    C5FC: B1 1E       lda (obj_record_ptr),y   ; $1E
    C5FE: 0A          asl a
    C5FF: 30 13       bmi @C614   ; $C614
    C601: 29 0C       and #$0c
    C603: 09 80       ora #$80
    C605: 85 12       sta gfx_src_ptr   ; $12
    C607: B1 1E       lda (obj_record_ptr),y   ; $1E
    C609: 29 08       and #$08
    C60B: F0 04       beq @C611   ; $C611
    C60D: A9 C0       lda #$c0
    C60F: 85 13       sta data_ptr_hi   ; $13
@C611:
    C611: 4C D7 C3    jmp apply_facing_flip   ; $C3D7
@C614:
    C614: 4A          lsr a
    C615: 29 04       and #$04
    C617: 09 90       ora #$90
    C619: 85 12       sta gfx_src_ptr   ; $12
    C61B: 4C D7 C3    jmp apply_facing_flip   ; $C3D7

draw_bonus_goal_object:
    C61E: A9 02       lda #$02
    C620: 85 13       sta data_ptr_hi   ; $13
    C622: A9 00       lda #$00
    C624: 85 14       sta scan_src_ptr   ; $14
    C626: A5 21       lda frame_counter   ; $21
    C628: 29 20       and #$20
    C62A: F0 11       beq draw_goal_block_dd   ; $C63D
    C62C: A9 E8       lda #$e8
    C62E: 85 12       sta gfx_src_ptr   ; $12
    C630: 20 4C C6    jsr draw_tile_block_3x4   ; $C64C
    C633: A5 16       lda sprite_y   ; $16
    C635: 38          sec
    C636: E9 08       sbc #$08
    C638: 85 16       sta sprite_y   ; $16
    C63A: 4C 15 C4    jmp write_sprite_to_oam   ; $C415

draw_goal_block_dd:
    C63D: A9 DD       lda #$dd
    C63F: 85 12       sta gfx_src_ptr   ; $12
    C641: A5 10       lda src_ptr   ; $10
    C643: 38          sec
    C644: E9 06       sbc #$06
    C646: 85 10       sta src_ptr   ; $10
    C648: B0 02       bcs draw_tile_block_3x4   ; $C64C
    C64A: C6 11       dec zp_ptr_hi   ; $11

draw_tile_block_3x4:
    C64C: A9 03       lda #$03
    C64E: 85 18       sta scratch_loop_counter   ; $18
@C650:
    C650: 20 5C C6    jsr draw_tile_row_of_3   ; $C65C
    C653: C6 18       dec scratch_loop_counter   ; $18
    C655: D0 F9       bne @C650   ; $C650
    C657: A9 02       lda #$02
    C659: 4C 5E C6    jmp draw_tile_row   ; $C65E

draw_tile_row_of_3:
    C65C: A9 03       lda #$03

draw_tile_row:
    C65E: 85 17       sta draw_row_counter   ; $17
@C660:
    C660: 20 15 C4    jsr write_sprite_to_oam   ; $C415
    C663: A5 10       lda src_ptr   ; $10
    C665: 18          clc
    C666: 69 08       adc #$08
    C668: 85 10       sta src_ptr   ; $10
    C66A: 90 02       bcc @C66E   ; $C66E
    C66C: E6 11       inc zp_ptr_hi   ; $11
@C66E:
    C66E: E6 12       inc gfx_src_ptr   ; $12
    C670: C6 17       dec draw_row_counter   ; $17
    C672: D0 EC       bne @C660   ; $C660
    C674: A5 10       lda src_ptr   ; $10
    C676: 38          sec
    C677: E9 18       sbc #$18
    C679: 85 10       sta src_ptr   ; $10
    C67B: B0 02       bcs @C67F   ; $C67F
    C67D: C6 11       dec zp_ptr_hi   ; $11
@C67F:
    C67F: A5 16       lda sprite_y   ; $16
    C681: 18          clc
    C682: 69 08       adc #$08
    C684: 85 16       sta sprite_y   ; $16
    C686: 60          rts

draw_8_sprite_row_to_oam:
    C687: A9 02       lda #$02
    C689: 85 13       sta data_ptr_hi   ; $13
    C68B: A9 00       lda #$00
    C68D: 85 14       sta scan_src_ptr   ; $14
    C68F: A9 F4       lda #$f4
    C691: 85 12       sta gfx_src_ptr   ; $12
    C693: A9 08       lda #$08
    C695: 85 17       sta draw_row_counter   ; $17
@C697:
    C697: 20 15 C4    jsr write_sprite_to_oam   ; $C415
    C69A: A5 10       lda src_ptr   ; $10
    C69C: 18          clc
    C69D: 69 08       adc #$08
    C69F: 85 10       sta src_ptr   ; $10
    C6A1: 90 02       bcc @C6A5   ; $C6A5
    C6A3: E6 11       inc zp_ptr_hi   ; $11
@C6A5:
    C6A5: E6 12       inc gfx_src_ptr   ; $12
    C6A7: C6 17       dec draw_row_counter   ; $17
    C6A9: D0 EC       bne @C697   ; $C697
    C6AB: 60          rts

draw_player_caught_pose:
    C6AC: A0 07       ldy #$07
    C6AE: B1 1E       lda (obj_record_ptr),y   ; $1E
    C6B0: C9 08       cmp #$08
    C6B2: A9 98       lda #$98
    C6B4: 90 02       bcc @C6B8   ; $C6B8
    C6B6: A9 9C       lda #$9c
@C6B8:
    C6B8: 85 12       sta gfx_src_ptr   ; $12
    C6BA: A9 00       lda #$00
    C6BC: 85 13       sta data_ptr_hi   ; $13
    C6BE: 4C D7 C3    jmp apply_facing_flip   ; $C3D7

draw_knocked_out:
    C6C1: A5 1E       lda obj_record_ptr   ; $1E
    C6C3: C9 20       cmp #$20
    C6C5: 90 05       bcc @C6CC   ; $C6CC
    C6C7: D0 0E       bne @C6D7   ; $C6D7
    C6C9: 4C B2 C5    jmp draw_slot2_large_pose   ; $C5B2
@C6CC:
    C6CC: A9 A8       lda #$a8
    C6CE: 85 12       sta gfx_src_ptr   ; $12
    C6D0: A9 02       lda #$02
    C6D2: 85 13       sta data_ptr_hi   ; $13
    C6D4: 4C D7 C3    jmp apply_facing_flip   ; $C3D7
@C6D7:
    C6D7: A9 2C       lda #$2c
    C6D9: 85 12       sta gfx_src_ptr   ; $12
    C6DB: A9 01       lda #$01
    C6DD: 85 13       sta data_ptr_hi   ; $13
    C6DF: 20 D7 C3    jsr apply_facing_flip   ; $C3D7
    C6E2: A5 16       lda sprite_y   ; $16
    C6E4: 38          sec
    C6E5: E9 10       sbc #$10
    C6E7: 85 16       sta sprite_y   ; $16
    C6E9: A9 AE       lda #$ae
    C6EB: 85 12       sta gfx_src_ptr   ; $12
    C6ED: A9 03       lda #$03
    C6EF: 85 13       sta data_ptr_hi   ; $13
    C6F1: 20 4D E8    jsr draw_sprite_advance_x   ; $E84D
    C6F4: A9 67       lda #$67
    C6F6: 85 12       sta gfx_src_ptr   ; $12
    C6F8: 4C 4D E8    jmp draw_sprite_advance_x   ; $E84D

draw_rle_text:
    C6FB: A0 00       ldy #$00
@C6FD:
    C6FD: B1 12       lda (gfx_src_ptr),y   ; $12
    C6FF: D0 16       bne @C717   ; $C717
    C701: C8          iny

draw_rle_text_step:
    C702: B1 12       lda (gfx_src_ptr),y   ; $12
    C704: F0 10       beq @C716   ; $C716
    C706: 10 02       bpl @C70A   ; $C70A
    C708: C6 11       dec zp_ptr_hi   ; $11
@C70A:
    C70A: C8          iny
    C70B: 18          clc
    C70C: 65 10       adc src_ptr   ; $10
    C70E: 85 10       sta src_ptr   ; $10
    C710: 90 EB       bcc @C6FD   ; $C6FD
    C712: E6 11       inc zp_ptr_hi   ; $11
    C714: B0 E7       bcs @C6FD   ; $C6FD
@C716:
    C716: 60          rts
@C717:
    C717: C8          iny
    C718: 85 15       sta scratch_counter   ; $15
    C71A: 85 16       sta sprite_y   ; $16
    C71C: 20 8E C7    jsr ppu_buffer_enqueue   ; $C78E
@C71F:
    C71F: A5 14       lda scan_src_ptr   ; $14
    C721: 30 5E       bmi @C781   ; $C781
    C723: A5 10       lda src_ptr   ; $10
    C725: 85 17       sta draw_row_counter   ; $17
    C727: A5 11       lda zp_ptr_hi   ; $11
    C729: 85 18       sta scratch_loop_counter   ; $18
    C72B: 06 17       asl draw_row_counter   ; $17
    C72D: 26 18       rol scratch_loop_counter   ; $18
    C72F: 06 17       asl draw_row_counter   ; $17
    C731: 2A          rol a
    C732: 06 17       asl draw_row_counter   ; $17
    C734: 06 17       asl draw_row_counter   ; $17
    C736: 26 18       rol scratch_loop_counter   ; $18
    C738: 06 17       asl draw_row_counter   ; $17
    C73A: 26 18       rol scratch_loop_counter   ; $18
    C73C: 06 17       asl draw_row_counter   ; $17
    C73E: 26 18       rol scratch_loop_counter   ; $18
    C740: 06 17       asl draw_row_counter   ; $17
    C742: 2A          rol a
    C743: 29 03       and #$03
    C745: AA          tax
    C746: A5 14       lda scan_src_ptr   ; $14
    C748: 85 17       sta draw_row_counter   ; $17
    C74A: A9 03       lda #$03
    C74C: E8          inx
    C74D: CA          dex
    C74E: F0 09       beq @C759   ; $C759
@C750:
    C750: 0A          asl a
    C751: 0A          asl a
    C752: 06 17       asl draw_row_counter   ; $17
    C754: 06 17       asl draw_row_counter   ; $17
    C756: CA          dex
    C757: D0 F7       bne @C750   ; $C750
@C759:
    C759: A6 18       ldx scratch_loop_counter   ; $18
    C75B: 49 FF       eor #$ff
    C75D: 3D 80 01    and $0180,x
    C760: 05 17       ora draw_row_counter   ; $17
    C762: 9D 80 01    sta $0180,x
    C765: 46 18       lsr scratch_loop_counter   ; $18
    C767: 46 18       lsr scratch_loop_counter   ; $18
    C769: 46 18       lsr scratch_loop_counter   ; $18
    C76B: 8A          txa
    C76C: 29 07       and #$07
    C76E: AA          tax
    C76F: A9 01       lda #$01
    C771: E8          inx
    C772: CA          dex
    C773: F0 04       beq @C779   ; $C779
@C775:
    C775: 0A          asl a
    C776: CA          dex
    C777: D0 FC       bne @C775   ; $C775
@C779:
    C779: A6 18       ldx scratch_loop_counter   ; $18
    C77B: 1D 70 01    ora attr_dirty_bitmap,x   ; $0170
    C77E: 9D 70 01    sta attr_dirty_bitmap,x   ; $0170
@C781:
    C781: E6 10       inc src_ptr   ; $10
    C783: D0 02       bne @C787   ; $C787
    C785: E6 11       inc zp_ptr_hi   ; $11
@C787:
    C787: C6 16       dec sprite_y   ; $16
    C789: D0 94       bne @C71F   ; $C71F
    C78B: 4C 02 C7    jmp draw_rle_text_step   ; $C702

ppu_buffer_enqueue:
    C78E: A5 2D       lda ppu_mask_shadow   ; $2D
    C790: F0 22       beq @C7B4   ; $C7B4
    C792: A6 2A       ldx ppu_buffer_cursor   ; $2A
    C794: A5 10       lda src_ptr   ; $10
    C796: 9D 00 05    sta vram_buffer,x   ; $0500
    C799: E8          inx
    C79A: A5 11       lda zp_ptr_hi   ; $11
    C79C: 9D 00 05    sta vram_buffer,x   ; $0500
    C79F: E8          inx
    C7A0: A5 15       lda scratch_counter   ; $15
    C7A2: 9D 00 05    sta vram_buffer,x   ; $0500
    C7A5: E8          inx
@C7A6:
    C7A6: B1 12       lda (gfx_src_ptr),y   ; $12
    C7A8: C8          iny
    C7A9: 9D 00 05    sta vram_buffer,x   ; $0500
    C7AC: E8          inx
    C7AD: C6 15       dec scratch_counter   ; $15
    C7AF: D0 F5       bne @C7A6   ; $C7A6
    C7B1: 86 2A       stx ppu_buffer_cursor   ; $2A
    C7B3: 60          rts
@C7B4:
    C7B4: A5 11       lda zp_ptr_hi   ; $11
    C7B6: 8D 06 20    sta PPUADDR   ; $2006
    C7B9: A5 10       lda src_ptr   ; $10
    C7BB: 8D 06 20    sta PPUADDR   ; $2006
@C7BE:
    C7BE: B1 12       lda (gfx_src_ptr),y   ; $12
    C7C0: C8          iny
    C7C1: 8D 07 20    sta PPUDATA   ; $2007
    C7C4: C6 15       dec scratch_counter   ; $15
    C7C6: D0 F6       bne @C7BE   ; $C7BE
    C7C8: 60          rts

flush_dirty_attribute_bytes:
    C7C9: A9 00       lda #$00
    C7CB: 85 12       sta gfx_src_ptr   ; $12
    C7CD: 85 13       sta data_ptr_hi   ; $13
    C7CF: A9 C0       lda #$c0
    C7D1: 85 10       sta src_ptr   ; $10
    C7D3: A9 23       lda #$23
    C7D5: 85 11       sta zp_ptr_hi   ; $11
    C7D7: 20 E2 C7    jsr init_zp14_zp15_to_8   ; $C7E2
    C7DA: A9 C0       lda #$c0
    C7DC: 85 10       sta src_ptr   ; $10
    C7DE: A9 27       lda #$27
    C7E0: 85 11       sta zp_ptr_hi   ; $11

init_zp14_zp15_to_8:
    C7E2: A9 08       lda #$08
    C7E4: 85 14       sta scan_src_ptr   ; $14
@C7E6:
    C7E6: A9 08       lda #$08
    C7E8: 85 15       sta scratch_counter   ; $15

emit_records_for_set_bits_in_bitmap:
    C7EA: A4 12       ldy gfx_src_ptr   ; $12
    C7EC: B9 70 01    lda attr_dirty_bitmap,y   ; $0170
    C7EF: F0 12       beq @C803   ; $C803
    C7F1: 4A          lsr a
    C7F2: 99 70 01    sta attr_dirty_bitmap,y   ; $0170
    C7F5: 90 03       bcc @C7FA   ; $C7FA
    C7F7: 20 18 C8    jsr write_attribute_byte   ; $C818
@C7FA:
    C7FA: E6 10       inc src_ptr   ; $10
    C7FC: E6 13       inc data_ptr_hi   ; $13
    C7FE: C6 15       dec scratch_counter   ; $15
    C800: 4C EA C7    jmp emit_records_for_set_bits_in_bitmap   ; $C7EA
@C803:
    C803: A5 10       lda src_ptr   ; $10
    C805: 18          clc
    C806: 65 15       adc scratch_counter   ; $15
    C808: 85 10       sta src_ptr   ; $10
    C80A: A5 13       lda data_ptr_hi   ; $13
    C80C: 18          clc
    C80D: 65 15       adc scratch_counter   ; $15
    C80F: 85 13       sta data_ptr_hi   ; $13
    C811: E6 12       inc gfx_src_ptr   ; $12
    C813: C6 14       dec scan_src_ptr   ; $14
    C815: D0 CF       bne @C7E6   ; $C7E6
    C817: 60          rts

write_attribute_byte:
    C818: A5 2D       lda ppu_mask_shadow   ; $2D
    C81A: F0 20       beq @C83C   ; $C83C
    C81C: A6 2A       ldx ppu_buffer_cursor   ; $2A
    C81E: A5 10       lda src_ptr   ; $10
    C820: 9D 00 05    sta vram_buffer,x   ; $0500
    C823: E8          inx
    C824: A5 11       lda zp_ptr_hi   ; $11
    C826: 9D 00 05    sta vram_buffer,x   ; $0500
    C829: E8          inx
    C82A: A9 01       lda #$01
    C82C: 9D 00 05    sta vram_buffer,x   ; $0500
    C82F: E8          inx
    C830: A4 13       ldy data_ptr_hi   ; $13
    C832: B9 80 01    lda $0180,y
    C835: 9D 00 05    sta vram_buffer,x   ; $0500
    C838: E8          inx
    C839: 86 2A       stx ppu_buffer_cursor   ; $2A
    C83B: 60          rts
@C83C:
    C83C: A5 11       lda zp_ptr_hi   ; $11
    C83E: 8D 06 20    sta PPUADDR   ; $2006
    C841: A5 10       lda src_ptr   ; $10
    C843: 8D 06 20    sta PPUADDR   ; $2006
    C846: A4 13       ldy data_ptr_hi   ; $13
    C848: B9 80 01    lda $0180,y
    C84B: 8D 07 20    sta PPUDATA   ; $2007
    C84E: 60          rts

title_screen:
    C84F: A9 00       lda #$00
    C851: 85 42       sta game_phase   ; $42
    C853: 20 BF F4    jsr init_sound_voices   ; $F4BF
    C856: A5 41       lda game_state_flags   ; $41
    C858: F0 03       beq @C85D   ; $C85D
    C85A: 20 81 CA    jsr swap_player_state   ; $CA81
@C85D:
    C85D: 85 75       sta current_record_index   ; $75
    C85F: A9 02       lda #$02
    C861: 85 76       sta record_index   ; $76
    C863: A9 FF       lda #$ff
    C865: 85 48       sta indirect_ptr   ; $48
    C867: A9 07       lda #$07
    C869: 85 49       sta indirect_ptr_hi   ; $49
    C86B: A9 03       lda #$03
    C86D: 85 70       sta p1_lives   ; $70
    C86F: A2 20       ldx #$20
    C871: A9 00       lda #$00
@C873:
    C873: 95 70       sta p1_lives,x   ; $70
    C875: E8          inx
    C876: E0 40       cpx #$40
    C878: D0 F9       bne @C873   ; $C873
    C87A: 20 41 C2    jsr ppu_disable_render   ; $C241
    C87D: 20 B1 CB    jsr draw_title_screen   ; $CBB1
    C880: 20 39 C2    jsr ppu_enable_render   ; $C239
    C883: A9 00       lda #$00
    C885: 85 28       sta camera_x_lo   ; $28
    C887: 85 29       sta camera_x   ; $29
    C889: 20 2B CD    jsr init_title_object   ; $CD2B
    C88C: A9 F0       lda #$f0
    C88E: 85 0F       sta countdown_lo   ; $0F
@C890:
    C890: 20 41 C1    jsr yield_to_render_loop   ; $C141
    C893: 20 3E CD    jsr draw_title_object   ; $CD3E
    C896: EA          nop
    C897: EA          nop
    C898: EA          nop
    C899: 20 3E D7    jsr title_menu_cursor   ; $D73E
    C89C: A5 25       lda joypad_state   ; $25
    C89E: 29 03       and #$03
    C8A0: C9 01       cmp #$01
    C8A2: F0 07       beq @C8AB   ; $C8AB
    C8A4: C6 0F       dec countdown_lo   ; $0F
    C8A6: D0 E8       bne @C890   ; $C890
    C8A8: 4C 65 FF    jmp attract_demo   ; $FF65
@C8AB:
    C8AB: A9 01       lda #$01
    C8AD: 85 42       sta game_phase   ; $42
    C8AF: A5 4A       lda seq_data_ptr   ; $4A
    C8B1: 85 40       sta two_player_game   ; $40
    C8B3: A9 00       lda #$00
    C8B5: 85 41       sta game_state_flags   ; $41
    C8B7: 85 71       sta score   ; $71
    C8B9: 85 72       sta draw_src_ptr   ; $72
    C8BB: 85 73       sta $73
    C8BD: 85 74       sta decode_src_ptr   ; $74
    C8BF: 85 7A       sta stage_number   ; $7A
    C8C1: 85 7D       sta stage_index   ; $7D
    C8C3: A9 01       lda #$01
    C8C5: 85 77       sta ppu_block_src_ptr   ; $77
    C8C7: A2 00       ldx #$00
@C8C9:
    C8C9: B5 70       lda p1_lives,x   ; $70
    C8CB: 95 B0       sta p2_lives,x   ; $B0
    C8CD: E8          inx
    C8CE: E0 20       cpx #$20
    C8D0: D0 F7       bne @C8C9   ; $C8C9
    C8D2: C6 70       dec p1_lives   ; $70
    C8D4: 20 A7 CA    jsr clear_object_tables   ; $CAA7
    C8D7: 20 41 C2    jsr ppu_disable_render   ; $C241
    C8DA: 20 49 CD    jsr build_stage_screen_layout   ; $CD49
    C8DD: 20 5B E3    jsr load_round_trampolines   ; $E35B
    C8E0: 20 C5 E5    jsr load_round_items   ; $E5C5
    C8E3: 20 62 E8    jsr load_round_doors   ; $E862
    C8E6: 20 01 F0    jsr spawn_floor_traps   ; $F001
    C8E9: 20 39 C2    jsr ppu_enable_render   ; $C239
    C8EC: A2 00       ldx #$00
@C8EE:
    C8EE: BD 00 02    lda obj_timer,x   ; $0200
    C8F1: 9D 00 03    sta obj_state,x   ; $0300
    C8F4: E8          inx
    C8F5: D0 F7       bne @C8EE   ; $C8EE
    C8F7: A2 01       ldx #$01
@C8F9:
    C8F9: B5 70       lda p1_lives,x   ; $70
    C8FB: 95 B0       sta p2_lives,x   ; $B0
    C8FD: E8          inx
    C8FE: E0 40       cpx #$40
    C900: D0 F7       bne @C8F9   ; $C8F9

play_round:
    C902: 20 C1 F3    jsr load_stage_params   ; $F3C1
    C905: 20 F1 D7    jsr init_player_record   ; $D7F1
    C908: 20 46 D8    jsr init_round_cats   ; $D846
    C90B: A9 00       lda #$00
    C90D: 85 4B       sta player_down   ; $4B
    C90F: 85 4F       sta round_cleared   ; $4F
    C911: 85 31       sta obj_record_ptr   ; $31
    C913: A9 3C       lda #$3c
    C915: 85 0F       sta countdown_lo   ; $0F
@C917:
    C917: 20 41 C1    jsr yield_to_render_loop   ; $C141
    C91A: 20 60 CB    jsr update_round_frame   ; $CB60
    C91D: 20 02 CB    jsr draw_player_number_text   ; $CB02
    C920: AD A6 CB    lda $cba6
    C923: 85 1E       sta obj_record_ptr   ; $1E
    C925: AD A7 CB    lda $cba7
    C928: 85 1F       sta obj_record_ptr_hi   ; $1F
    C92A: 20 3B CB    jsr draw_sprite_text   ; $CB3B
    C92D: C6 0F       dec countdown_lo   ; $0F
    C92F: D0 E6       bne @C917   ; $C917
    C931: A9 02       lda #$02
    C933: 8D 0F 04    sta $040f
    C936: A2 20       ldx #$20
@C938:
    C938: A9 02       lda #$02
    C93A: 9D 0F 04    sta $040f,x
    C93D: 8A          txa
    C93E: 18          clc
    C93F: 69 10       adc #$10
    C941: AA          tax
    C942: E4 68       cpx ptr_hi   ; $68
    C944: D0 F2       bne @C938   ; $C938
@C946:
    C946: 20 41 C1    jsr yield_to_render_loop   ; $C141
    C949: A5 60       lda sequence_state   ; $60
    C94B: C9 01       cmp #$01
    C94D: F0 12       beq @C961   ; $C961
    C94F: C9 03       cmp #$03
    C951: D0 06       bne @C959   ; $C959
    C953: A5 61       lda seq_data_ptr   ; $61
    C955: C9 3C       cmp #$3c
    C957: D0 08       bne @C961   ; $C961
@C959:
    C959: A9 01       lda #$01
    C95B: 8D 13 06    sta $0613
    C95E: 8D 14 06    sta $0614
@C961:
    C961: 20 60 CB    jsr update_round_frame   ; $CB60
    C964: 20 E6 F2    jsr tick_round_timer   ; $F2E6
    C967: A5 4F       lda round_cleared   ; $4F
    C969: D0 07       bne @C972   ; $C972
    C96B: A5 4B       lda player_down   ; $4B
    C96D: F0 D7       beq @C946   ; $C946
    C96F: 4C 28 CA    jmp handle_player_caught   ; $CA28
@C972:
    C972: 20 41 C1    jsr yield_to_render_loop   ; $C141
    C975: 20 60 CB    jsr update_round_frame   ; $CB60
    C978: AD A5 04    lda obj_state   ; $04A5
    C97B: 0D AD 04    ora $04ad
    C97E: D0 F2       bne @C972   ; $C972
    C980: A9 B4       lda #$b4
    C982: 85 0F       sta countdown_lo   ; $0F
@C984:
    C984: 20 41 C1    jsr yield_to_render_loop   ; $C141
    C987: A5 0F       lda countdown_lo   ; $0F
    C989: C9 78       cmp #$78
    C98B: D0 08       bne @C995   ; $C995
    C98D: A9 01       lda #$01
    C98F: 8D 11 06    sta $0611
    C992: 8D 12 06    sta $0612
@C995:
    C995: 20 60 CB    jsr update_round_frame   ; $CB60
    C998: C6 0F       dec countdown_lo   ; $0F
    C99A: D0 E8       bne @C984   ; $C984
    C99C: 20 BF F4    jsr init_sound_voices   ; $F4BF

next_round:
    C99F: 20 E8 D6    jsr advance_to_next_round   ; $D6E8
    C9A2: 20 A7 CA    jsr clear_object_tables   ; $CAA7
    C9A5: A2 20       ldx #$20
    C9A7: A9 00       lda #$00
@C9A9:
    C9A9: 95 70       sta p1_lives,x   ; $70
    C9AB: E8          inx
    C9AC: E0 40       cpx #$40
    C9AE: D0 F9       bne @C9A9   ; $C9A9
    C9B0: 20 41 C2    jsr ppu_disable_render   ; $C241
    C9B3: 20 49 CD    jsr build_stage_screen_layout   ; $CD49
    C9B6: 20 5B E3    jsr load_round_trampolines   ; $E35B
    C9B9: A5 7C       lda is_bonus_round   ; $7C
    C9BB: D0 12       bne @C9CF   ; $C9CF
    C9BD: 20 C5 E5    jsr load_round_items   ; $E5C5
    C9C0: 20 62 E8    jsr load_round_doors   ; $E862
    C9C3: 20 01 F0    jsr spawn_floor_traps   ; $F001
    C9C6: 20 17 EF    jsr load_dropped_objects   ; $EF17
    C9C9: 20 39 C2    jsr ppu_enable_render   ; $C239
    C9CC: 4C 02 C9    jmp play_round   ; $C902
@C9CF:
    C9CF: 20 C1 F3    jsr load_stage_params   ; $F3C1
    C9D2: 20 3A F1    jsr load_bonus_targets   ; $F13A
    C9D5: 20 39 C2    jsr ppu_enable_render   ; $C239
    C9D8: 20 0B D8    jsr init_bonus_player   ; $D80B
    C9DB: 20 C0 D8    jsr init_bonus_goal_object   ; $D8C0
    C9DE: A9 00       lda #$00
    C9E0: 85 4B       sta player_down   ; $4B
    C9E2: 85 4F       sta round_cleared   ; $4F
    C9E4: A9 AC       lda #$ac
    C9E6: 85 0F       sta countdown_lo   ; $0F
    C9E8: A9 08       lda #$08
    C9EA: 85 0E       sta countdown_hi   ; $0E
@C9EC:
    C9EC: 20 41 C1    jsr yield_to_render_loop   ; $C141
    C9EF: 20 7B CB    jsr update_bonus_round_frame   ; $CB7B
    C9F2: A5 4B       lda player_down   ; $4B
    C9F4: F0 08       beq @C9FE   ; $C9FE
    C9F6: AD 2F 04    lda stage_phase_state   ; $042F
    C9F9: 0D 3F 04    ora $043f
    C9FC: F0 13       beq @CA11   ; $CA11
@C9FE:
    C9FE: A5 4F       lda round_cleared   ; $4F
    CA00: D0 0F       bne @CA11   ; $CA11
    CA02: A5 0F       lda countdown_lo   ; $0F
    CA04: 38          sec
    CA05: E9 01       sbc #$01
    CA07: 85 0F       sta countdown_lo   ; $0F
    CA09: B0 02       bcs @CA0D   ; $CA0D
    CA0B: C6 0E       dec countdown_hi   ; $0E
@CA0D:
    CA0D: 05 0E       ora countdown_hi   ; $0E
    CA0F: D0 DB       bne @C9EC   ; $C9EC
@CA11:
    CA11: A9 1E       lda #$1e
    CA13: 85 0F       sta countdown_lo   ; $0F
@CA15:
    CA15: 20 41 C1    jsr yield_to_render_loop   ; $C141
    CA18: 20 1C D7    jsr blink_player_up_label   ; $D71C
    CA1B: C6 0F       dec countdown_lo   ; $0F
    CA1D: D0 F6       bne @CA15   ; $CA15
    CA1F: 20 BF F4    jsr init_sound_voices   ; $F4BF
    CA22: 20 1A CE    jsr show_bonus_results   ; $CE1A
    CA25: 4C 9F C9    jmp next_round   ; $C99F

handle_player_caught:
    CA28: 20 41 C1    jsr yield_to_render_loop   ; $C141
    CA2B: 20 60 CB    jsr update_round_frame   ; $CB60
    CA2E: AD 0F 04    lda $040f
    CA31: D0 F5       bne handle_player_caught   ; $CA28
    CA33: A5 40       lda two_player_game   ; $40
    CA35: D0 0A       bne @CA41   ; $CA41
    CA37: A5 70       lda p1_lives   ; $70
    CA39: D0 2C       bne @CA67   ; $CA67
    CA3B: 20 C3 CA    jsr game_over   ; $CAC3
    CA3E: 4C 4F C8    jmp title_screen   ; $C84F
@CA41:
    CA41: A5 70       lda p1_lives   ; $70
    CA43: D0 1B       bne @CA60   ; $CA60
    CA45: 20 B4 CA    jsr game_over_for_one_player   ; $CAB4
    CA48: A5 B0       lda p2_lives   ; $B0
    CA4A: D0 18       bne @CA64   ; $CA64
    CA4C: A9 3C       lda #$3c
    CA4E: 85 0F       sta countdown_lo   ; $0F
@CA50:
    CA50: 20 41 C1    jsr yield_to_render_loop   ; $C141
    CA53: 20 31 CB    jsr draw_game_over_text   ; $CB31
    CA56: 20 1C D7    jsr blink_player_up_label   ; $D71C
    CA59: C6 0F       dec countdown_lo   ; $0F
    CA5B: D0 F3       bne @CA50   ; $CA50
    CA5D: 4C 4F C8    jmp title_screen   ; $C84F
@CA60:
    CA60: A5 B0       lda p2_lives   ; $B0
    CA62: F0 03       beq @CA67   ; $CA67
@CA64:
    CA64: 20 81 CA    jsr swap_player_state   ; $CA81
@CA67:
    CA67: C6 70       dec p1_lives   ; $70
    CA69: 20 A7 CA    jsr clear_object_tables   ; $CAA7
    CA6C: 20 41 C2    jsr ppu_disable_render   ; $C241
    CA6F: 20 49 CD    jsr build_stage_screen_layout   ; $CD49
    CA72: 20 5B E3    jsr load_round_trampolines   ; $E35B
    CA75: 20 14 E6    jsr draw_round_items   ; $E614
    CA78: 20 B2 E8    jsr close_and_draw_doors   ; $E8B2
    CA7B: 20 39 C2    jsr ppu_enable_render   ; $C239
    CA7E: 4C 02 C9    jmp play_round   ; $C902

swap_player_state:
    CA81: A5 41       lda game_state_flags   ; $41
    CA83: 49 01       eor #$01
    CA85: 85 41       sta game_state_flags   ; $41
    CA87: A2 00       ldx #$00
@CA89:
    CA89: BD 00 02    lda obj_timer,x   ; $0200
    CA8C: BC 00 03    ldy obj_state,x   ; $0300
    CA8F: 9D 00 03    sta obj_state,x   ; $0300
    CA92: 98          tya
    CA93: 9D 00 02    sta obj_timer,x   ; $0200
    CA96: E8          inx
    CA97: D0 F0       bne @CA89   ; $CA89
@CA99:
    CA99: B5 70       lda p1_lives,x   ; $70
    CA9B: B4 B0       ldy p2_lives,x   ; $B0
    CA9D: 95 B0       sta p2_lives,x   ; $B0
    CA9F: 94 70       sty p1_lives,x   ; $70
    CAA1: E8          inx
    CAA2: E0 40       cpx #$40
    CAA4: D0 F3       bne @CA99   ; $CA99
    CAA6: 60          rts

clear_object_tables:
    CAA7: A9 00       lda #$00
    CAA9: A2 00       ldx #$00
@CAAB:
    CAAB: 9D 00 04    sta $0400,x
    CAAE: E8          inx
    CAAF: E0 C0       cpx #$c0
    CAB1: D0 F8       bne @CAAB   ; $CAAB
    CAB3: 60          rts

game_over_for_one_player:
    CAB4: A5 B0       lda p2_lives   ; $B0
    CAB6: F0 0B       beq game_over   ; $CAC3
    CAB8: A9 78       lda #$78
    CABA: 85 0F       sta countdown_lo   ; $0F
    CABC: A9 00       lda #$00
    CABE: 85 0E       sta countdown_hi   ; $0E
    CAC0: 4C DA CA    jmp show_game_over   ; $CADA

game_over:
    CAC3: A9 01       lda #$01
    CAC5: 8D 15 06    sta $0615
    CAC8: 8D 16 06    sta $0616
    CACB: 8D 17 06    sta $0617
    CACE: A9 00       lda #$00
    CAD0: 85 42       sta game_phase   ; $42
    CAD2: A9 A4       lda #$a4
    CAD4: 85 0F       sta countdown_lo   ; $0F
    CAD6: A9 01       lda #$01
    CAD8: 85 0E       sta countdown_hi   ; $0E

show_game_over:
    CADA: 20 41 C1    jsr yield_to_render_loop   ; $C141
    CADD: A5 40       lda two_player_game   ; $40
    CADF: F0 03       beq @CAE4   ; $CAE4
    CAE1: 20 02 CB    jsr draw_player_number_text   ; $CB02
@CAE4:
    CAE4: 20 31 CB    jsr draw_game_over_text   ; $CB31
    CAE7: 20 1C D7    jsr blink_player_up_label   ; $D71C
    CAEA: A5 25       lda joypad_state   ; $25
    CAEC: 29 03       and #$03
    CAEE: C9 01       cmp #$01
    CAF0: F0 0F       beq @CB01   ; $CB01
    CAF2: A5 0F       lda countdown_lo   ; $0F
    CAF4: 38          sec
    CAF5: E9 01       sbc #$01
    CAF7: 85 0F       sta countdown_lo   ; $0F
    CAF9: B0 02       bcs @CAFD   ; $CAFD
    CAFB: C6 0E       dec countdown_hi   ; $0E
@CAFD:
    CAFD: 05 0E       ora countdown_hi   ; $0E
    CAFF: D0 D9       bne show_game_over   ; $CADA
@CB01:
    CB01: 60          rts

draw_player_number_text:
    CB02: AD 8A CB    lda $cb8a
    CB05: 85 1E       sta obj_record_ptr   ; $1E
    CB07: AD 8B CB    lda $cb8b
    CB0A: 85 1F       sta obj_record_ptr_hi   ; $1F
    CB0C: 20 3B CB    jsr draw_sprite_text   ; $CB3B
    CB0F: A5 41       lda game_state_flags   ; $41
    CB11: 18          clc
    CB12: 69 D6       adc #$d6

draw_sprite_glyph:
    CB14: F0 0F       beq @CB25   ; $CB25
    CB16: 85 12       sta gfx_src_ptr   ; $12
    CB18: A9 02       lda #$02
    CB1A: 85 13       sta data_ptr_hi   ; $13
    CB1C: A9 00       lda #$00
    CB1E: 85 14       sta scan_src_ptr   ; $14
    CB20: 85 15       sta scratch_counter   ; $15
    CB22: 20 15 C4    jsr write_sprite_to_oam   ; $C415
@CB25:
    CB25: A5 10       lda src_ptr   ; $10
    CB27: 18          clc
    CB28: 69 08       adc #$08
    CB2A: 85 10       sta src_ptr   ; $10
    CB2C: D0 02       bne @CB30   ; $CB30
    CB2E: E6 11       inc zp_ptr_hi   ; $11
@CB30:
    CB30: 60          rts

draw_game_over_text:
    CB31: AD 97 CB    lda $cb97
    CB34: 85 1E       sta obj_record_ptr   ; $1E
    CB36: AD 98 CB    lda $cb98
    CB39: 85 1F       sta obj_record_ptr_hi   ; $1F

draw_sprite_text:
    CB3B: A0 00       ldy #$00
    CB3D: B1 1E       lda (obj_record_ptr),y   ; $1E
    CB3F: C8          iny
    CB40: 85 10       sta src_ptr   ; $10
    CB42: B1 1E       lda (obj_record_ptr),y   ; $1E
    CB44: C8          iny
    CB45: 85 11       sta zp_ptr_hi   ; $11
    CB47: B1 1E       lda (obj_record_ptr),y   ; $1E
    CB49: C8          iny
    CB4A: 85 16       sta sprite_y   ; $16
    CB4C: B1 1E       lda (obj_record_ptr),y   ; $1E
    CB4E: C8          iny
    CB4F: 85 18       sta scratch_loop_counter   ; $18
@CB51:
    CB51: B1 1E       lda (obj_record_ptr),y   ; $1E
    CB53: 84 17       sty draw_row_counter   ; $17
    CB55: 20 14 CB    jsr draw_sprite_glyph   ; $CB14
    CB58: A4 17       ldy draw_row_counter   ; $17
    CB5A: C8          iny
    CB5B: C6 18       dec scratch_loop_counter   ; $18
    CB5D: D0 F2       bne @CB51   ; $CB51
    CB5F: 60          rts

update_round_frame:
    CB60: 20 FE E3    jsr animate_trampolines   ; $E3FE
    CB63: 20 D8 D8    jsr update_and_respawn_objects   ; $D8D8
    CB66: 20 4E ED    jsr update_door_waves   ; $ED4E
    CB69: 20 3F EF    jsr update_dropped_objects   ; $EF3F
    CB6C: 20 34 E6    jsr update_items   ; $E634
    CB6F: 20 CC E8    jsr update_doors   ; $E8CC
    CB72: 20 4D F0    jsr update_floor_traps   ; $F04D
    CB75: 20 1C D7    jsr blink_player_up_label   ; $D71C
    CB78: 4C AB D5    jmp update_score   ; $D5AB

update_bonus_round_frame:
    CB7B: 20 FE E3    jsr animate_trampolines   ; $E3FE
    CB7E: 20 D8 D8    jsr update_and_respawn_objects   ; $D8D8
    CB81: 20 8F F1    jsr update_bonus_targets   ; $F18F
    CB84: 20 1C D7    jsr blink_player_up_label   ; $D71C
    CB87: 4C AB D5    jmp update_score   ; $D5AB
    CB8A: 8C          .byte $8C
    CB8B: CB          .byte $CB
    CB8C: 58          .byte $58
    CB8D: 00          .byte $00
    CB8E: 78          .byte $78
    CB8F: 07          .byte $07
    CB90: D0          .byte $D0
    CB91: D1          .byte $D1
    CB92: D2          .byte $D2
    CB93: D3          .byte $D3
    CB94: D4          .byte $D4
    CB95: D5          .byte $D5
    CB96: 00          .byte $00
    CB97: 99          .byte $99
    CB98: CB          .byte $CB
    CB99: 58          .byte $58
    CB9A: 00          .byte $00
    CB9B: 88          .byte $88
    CB9C: 09          .byte $09
    CB9D: D8          .byte $D8
    CB9E: D2          .byte $D2
    CB9F: D9          .byte $D9
    CBA0: D4          .byte $D4
    CBA1: 00          .byte $00
    CBA2: DA          .byte $DA
    CBA3: DB          .byte $DB
    CBA4: D4          .byte $D4
    CBA5: D5          .byte $D5
    CBA6: A8          .byte $A8
    CBA7: CB          .byte $CB
    CBA8: 60          .byte $60
    CBA9: 00          .byte $00
    CBAA: 88          .byte $88
    CBAB: 05          .byte $05
    CBAC: D5          .byte $D5
    CBAD: D4          .byte $D4
    CBAE: D2          .byte $D2
    CBAF: CA          .byte $CA
    CBB0: D3          .byte $D3

draw_title_screen:
    CBB1: 20 F5 CB    jsr ppu_clear_nametables   ; $CBF5
    CBB4: A0 02       ldy #$02
    CBB6: 20 15 CC    jsr ppu_run_draw_blocks   ; $CC15
    CBB9: A0 00       ldy #$00
    CBBB: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CBBE: A0 04       ldy #$04
    CBC0: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CBC3: A0 08       ldy #$08
    CBC5: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CBC8: A9 B0       lda #$b0
    CBCA: 85 10       sta src_ptr   ; $10
    CBCC: A0 00       ldy #$00
@CBCE:
    CBCE: A2 14       ldx #$14
    CBD0: B9 EE CB    lda $cbee,y
    CBD3: 8D 06 20    sta PPUADDR   ; $2006
    CBD6: B9 ED CB    lda $cbed,y
    CBD9: 8D 06 20    sta PPUADDR   ; $2006
@CBDC:
    CBDC: A5 10       lda src_ptr   ; $10
    CBDE: 8D 07 20    sta PPUDATA   ; $2007
    CBE1: E6 10       inc src_ptr   ; $10
    CBE3: CA          dex
    CBE4: D0 F6       bne @CBDC   ; $CBDC
    CBE6: C8          iny
    CBE7: C8          iny
    CBE8: C0 08       cpy #$08
    CBEA: D0 E2       bne @CBCE   ; $CBCE
    CBEC: 60          rts
    CBED: 07          .byte $07
    CBEE: 21          .byte $21
    CBEF: 27          .byte $27
    CBF0: 21          .byte $21
    CBF1: 47          .byte $47
    CBF2: 21          .byte $21
    CBF3: 67          .byte $67
    CBF4: 21          .byte $21

ppu_clear_nametables:
    CBF5: A9 00       lda #$00
    CBF7: 85 2A       sta ppu_buffer_cursor   ; $2A
    CBF9: 85 2B       sta vram_queue_cursor   ; $2B
    CBFB: A9 20       lda #$20
    CBFD: 8D 06 20    sta PPUADDR   ; $2006
    CC00: A9 00       lda #$00
    CC02: 8D 06 20    sta PPUADDR   ; $2006
    CC05: A9 00       lda #$00
    CC07: A0 08       ldy #$08
    CC09: A2 00       ldx #$00
@CC0B:
    CC0B: 8D 07 20    sta PPUDATA   ; $2007
    CC0E: CA          dex
    CC0F: D0 FA       bne @CC0B   ; $CC0B
    CC11: 88          dey
    CC12: D0 F7       bne @CC0B   ; $CC0B
@CC14:
    CC14: 60          rts

ppu_run_draw_blocks:
    CC15: B9 41 CC    lda tbl_palhud_ptr,y   ; $CC41
    CC18: 85 10       sta src_ptr   ; $10
    CC1A: B9 42 CC    lda $cc42,y
    CC1D: 85 11       sta zp_ptr_hi   ; $11
    CC1F: A0 00       ldy #$00
@CC21:
    CC21: B1 10       lda (src_ptr),y   ; $10
    CC23: F0 EF       beq @CC14   ; $CC14
    CC25: C8          iny
    CC26: 85 12       sta gfx_src_ptr   ; $12
    CC28: B1 10       lda (src_ptr),y   ; $10
    CC2A: C8          iny
    CC2B: AA          tax
    CC2C: B1 10       lda (src_ptr),y   ; $10
    CC2E: C8          iny
    CC2F: 8D 06 20    sta PPUADDR   ; $2006
    CC32: 8E 06 20    stx PPUADDR   ; $2006
@CC35:
    CC35: B1 10       lda (src_ptr),y   ; $10
    CC37: C8          iny
    CC38: 8D 07 20    sta PPUDATA   ; $2007
    CC3B: C6 12       dec gfx_src_ptr   ; $12
    CC3D: D0 F6       bne @CC35   ; $CC35
    CC3F: F0 E0       beq @CC21   ; $CC21

tbl_palhud_ptr:
    CC41:            .word palhud_block_00
    CC43:            .word palhud_block_02
    CC45:            .word palhud_block_04
    CC47:            .word palhud_block_06
    CC49:            .word palhud_block_08

palhud_block_00:
    CC4B: 11          .byte $11
    CC4C: 4B          .byte $4B
    CC4D: 20          .byte $20
    CC4E: A0          .byte $A0
    CC4F: A1          .byte $A1
    CC50: A2          .byte $A2
    CC51: A3          .byte $A3
    CC52: A4          .byte $A4
    CC53: A5          .byte $A5
    CC54: A6          .byte $A6
    CC55: A7          .byte $A7
    CC56: 00          .byte $00
    CC57: 00          .byte $00
    CC58: 00          .byte $00
    CC59: AC          .byte $AC
    CC5A: AD          .byte $AD
    CC5B: 00          .byte $00
    CC5C: 00          .byte $00
    CC5D: 00          .byte $00
    CC5E: AE          .byte $AE
    CC5F: 00          .byte $00

palhud_block_02:
    CC60: 20          .byte $20
    CC61: 00          .byte $00
    CC62: 3F          .byte $3F
    CC63: 0F          .byte $0F
    CC64: 30          .byte $30
    CC65: 16          .byte $16
    CC66: 21          .byte $21
    CC67: 0F          .byte $0F
    CC68: 16          .byte $16
    CC69: 17          .byte $17
    CC6A: 13          .byte $13
    CC6B: 0F          .byte $0F
    CC6C: 27          .byte $27
    CC6D: 29          .byte $29
    CC6E: 13          .byte $13
    CC6F: 0F          .byte $0F
    CC70: 29          .byte $29
    CC71: 21          .byte $21
    CC72: 13          .byte $13
    CC73: 0F          .byte $0F
    CC74: 10          .byte $10
    CC75: 11          .byte $11
    CC76: 36          .byte $36
    CC77: 0F          .byte $0F
    CC78: 25          .byte $25
    CC79: 11          .byte $11
    CC7A: 27          .byte $27
    CC7B: 0F          .byte $0F
    CC7C: 16          .byte $16
    CC7D: 11          .byte $11
    CC7E: 36          .byte $36
    CC7F: 0F          .byte $0F
    CC80: 30          .byte $30
    CC81: 30          .byte $30
    CC82: 30          .byte $30
    CC83: 06          .byte $06
    CC84: D1          .byte $D1
    CC85: 23          .byte $23
    CC86: 55          .byte $55
    CC87: 55          .byte $55
    CC88: 55          .byte $55
    CC89: AA          .byte $AA
    CC8A: FF          .byte $FF
    CC8B: FF          .byte $FF
    CC8C: 15          .byte $15
    CC8D: 45          .byte $45
    CC8E: 20          .byte $20
    CC8F: A8          .byte $A8
    CC90: AA          .byte $AA
    CC91: AB          .byte $AB
    CC92: 00          .byte $00
    CC93: 00          .byte $00
    CC94: 00          .byte $00
    CC95: A0          .byte $A0
    CC96: A1          .byte $A1
    CC97: A2          .byte $A2
    CC98: A3          .byte $A3
    CC99: A4          .byte $A4
    CC9A: A5          .byte $A5
    CC9B: A6          .byte $A6
    CC9C: A7          .byte $A7
    CC9D: 00          .byte $00
    CC9E: 00          .byte $00
    CC9F: 00          .byte $00
    CCA0: 00          .byte $00
    CCA1: A9          .byte $A9
    CCA2: AA          .byte $AA
    CCA3: AB          .byte $AB
    CCA4: 08          .byte $08
    CCA5: EB          .byte $EB
    CCA6: 21          .byte $21
    CCA7: 02          .byte $02
    CCA8: 00          .byte $00
    CCA9: 1A          .byte $1A
    CCAA: 16          .byte $16
    CCAB: 0B          .byte $0B
    CCAC: 23          .byte $23
    CCAD: 0F          .byte $0F
    CCAE: 1C          .byte $1C
    CCAF: 09          .byte $09
    CCB0: 2B          .byte $2B
    CCB1: 22          .byte $22
    CCB2: 03          .byte $03
    CCB3: 00          .byte $00
    CCB4: 1A          .byte $1A
    CCB5: 16          .byte $16
    CCB6: 0B          .byte $0B
    CCB7: 23          .byte $23
    CCB8: 0F          .byte $0F
    CCB9: 1C          .byte $1C
    CCBA: 1D          .byte $1D
    CCBB: 01          .byte $01
    CCBC: 8B          .byte $8B
    CCBD: 22          .byte $22
    CCBE: 27          .byte $27
    CCBF: 16          .byte $16
    CCC0: E5          .byte $E5
    CCC1: 22          .byte $22
    CCC2: 26          .byte $26
    CCC3: 00          .byte $00
    CCC4: 02          .byte $02
    CCC5: 0A          .byte $0A
    CCC6: 09          .byte $09
    CCC7: 04          .byte $04
    CCC8: 00          .byte $00
    CCC9: 02          .byte $02
    CCCA: 0A          .byte $0A
    CCCB: 09          .byte $09
    CCCC: 05          .byte $05
    CCCD: 00          .byte $00
    CCCE: 18          .byte $18
    CCCF: 0B          .byte $0B
    CCD0: 17          .byte $17
    CCD1: 0D          .byte $0D
    CCD2: 19          .byte $19
    CCD3: 00          .byte $00
    CCD4: 16          .byte $16
    CCD5: 1E          .byte $1E
    CCD6: 0E          .byte $0E
    CCD7: 25          .byte $25
    CCD8: 13          .byte $13
    CCD9: 27          .byte $27
    CCDA: 23          .byte $23
    CCDB: 0B          .byte $0B
    CCDC: 16          .byte $16
    CCDD: 16          .byte $16
    CCDE: 00          .byte $00
    CCDF: 1C          .byte $1C
    CCE0: 13          .byte $13
    CCE1: 11          .byte $11
    CCE2: 12          .byte $12
    CCE3: 1E          .byte $1E
    CCE4: 1D          .byte $1D
    CCE5: 00          .byte $00
    CCE6: 1C          .byte $1C
    CCE7: 0F          .byte $0F
    CCE8: 1D          .byte $1D
    CCE9: 0F          .byte $0F
    CCEA: 1C          .byte $1C
    CCEB: 20          .byte $20
    CCEC: 0F          .byte $0F
    CCED: 0E          .byte $0E
    CCEE: 00          .byte $00

palhud_block_04:
    CCEF: 10          .byte $10
    CCF0: 00          .byte $00
    CCF1: 3F          .byte $3F
    CCF2: 0F          .byte $0F
    CCF3: 30          .byte $30
    CCF4: 16          .byte $16
    CCF5: 21          .byte $21
    CCF6: 0F          .byte $0F
    CCF7: 16          .byte $16
    CCF8: 36          .byte $36
    CCF9: 17          .byte $17
    CCFA: 0F          .byte $0F
    CCFB: 19          .byte $19
    CCFC: 11          .byte $11
    CCFD: 36          .byte $36
    CCFE: 0F          .byte $0F
    CCFF: 29          .byte $29
    CD00: 19          .byte $19
    CD01: 13          .byte $13
    CD02: 00          .byte $00

palhud_block_06:
    CD03: 10          .byte $10
    CD04: 00          .byte $00
    CD05: 3F          .byte $3F
    CD06: 0F          .byte $0F
    CD07: 30          .byte $30
    CD08: 16          .byte $16
    CD09: 21          .byte $21
    CD0A: 0F          .byte $0F
    CD0B: 11          .byte $11
    CD0C: 36          .byte $36
    CD0D: 17          .byte $17
    CD0E: 0F          .byte $0F
    CD0F: 19          .byte $19
    CD10: 11          .byte $11
    CD11: 36          .byte $36
    CD12: 0F          .byte $0F
    CD13: 29          .byte $29
    CD14: 19          .byte $19
    CD15: 13          .byte $13
    CD16: 00          .byte $00

palhud_block_08:
    CD17: 10          .byte $10
    CD18: 00          .byte $00
    CD19: 3F          .byte $3F
    CD1A: 0F          .byte $0F
    CD1B: 30          .byte $30
    CD1C: 16          .byte $16
    CD1D: 21          .byte $21
    CD1E: 0F          .byte $0F
    CD1F: 19          .byte $19
    CD20: 36          .byte $36
    CD21: 17          .byte $17
    CD22: 0F          .byte $0F
    CD23: 19          .byte $19
    CD24: 11          .byte $11
    CD25: 36          .byte $36
    CD26: 0F          .byte $0F
    CD27: 29          .byte $29
    CD28: 19          .byte $19
    CD29: 13          .byte $13
    CD2A: 00          .byte $00

init_title_object:
    CD2B: A2 00       ldx #$00
@CD2D:
    CD2D: BD 39 CD    lda $cd39,x
    CD30: 9D 90 04    sta obj_state_counter,x   ; $0490
    CD33: E8          inx
    CD34: E0 05       cpx #$05
    CD36: D0 F5       bne @CD2D   ; $CD2D
    CD38: 60          rts
    CD39: 00          .byte $00
    CD3A: 0C          .byte $0C
    CD3B: 00          .byte $00
    CD3C: 14          .byte $14
    CD3D: 1C          .byte $1C

draw_title_object:
    CD3E: A9 90       lda #$90
    CD40: 85 1E       sta obj_record_ptr   ; $1E
    CD42: A9 04       lda #$04
    CD44: 85 1F       sta obj_record_ptr_hi   ; $1F
    CD46: 4C 05 C3    jmp draw_object   ; $C305

build_stage_screen_layout:
    CD49: 20 F5 CB    jsr ppu_clear_nametables   ; $CBF5
    CD4C: 20 03 D7    jsr draw_hud   ; $D703
    CD4F: A5 7A       lda stage_number   ; $7A
    CD51: 0A          asl a
    CD52: 0A          asl a
    CD53: 85 1F       sta obj_record_ptr_hi   ; $1F
    CD55: AA          tax
    CD56: BD BF CD    lda tbl_round_attributes,x   ; $CDBF
    CD59: 85 7C       sta is_bonus_round   ; $7C
    CD5B: F0 30       beq @CD8D   ; $CD8D
    CD5D: A9 00       lda #$00
    CD5F: 85 28       sta camera_x_lo   ; $28
    CD61: 85 29       sta camera_x   ; $29
    CD63: A0 0C       ldy #$0c
    CD65: 20 26 D1    jsr ppu_draw_mansion_stamps   ; $D126
    CD68: 20 39 C2    jsr ppu_enable_render   ; $C239
    CD6B: A9 01       lda #$01
    CD6D: 8D 0E 06    sta $060e
    CD70: 8D 0F 06    sta $060f
    CD73: 8D 10 06    sta $0610
    CD76: A9 D2       lda #$d2
    CD78: 85 0F       sta countdown_lo   ; $0F
@CD7A:
    CD7A: 20 41 C1    jsr yield_to_render_loop   ; $C141
    CD7D: 20 FF CD    jsr draw_bonus_intro_sprite   ; $CDFF
    CD80: C6 0F       dec countdown_lo   ; $0F
    CD82: D0 F6       bne @CD7A   ; $CD7A
    CD84: 20 41 C2    jsr ppu_disable_render   ; $C241
    CD87: 20 F5 CB    jsr ppu_clear_nametables   ; $CBF5
    CD8A: 20 03 D7    jsr draw_hud   ; $D703
@CD8D:
    CD8D: A0 08       ldy #$08
    CD8F: 20 69 CF    jsr ppu_draw_rle_blocks   ; $CF69
    CD92: A6 1F       ldx obj_record_ptr_hi   ; $1F
    CD94: BC C0 CD    ldy $cdc0,x
    CD97: 20 15 CC    jsr ppu_run_draw_blocks   ; $CC15
    CD9A: A6 1F       ldx obj_record_ptr_hi   ; $1F
    CD9C: BC C1 CD    ldy $cdc1,x
    CD9F: 20 69 CF    jsr ppu_draw_rle_blocks   ; $CF69
    CDA2: A6 1F       ldx obj_record_ptr_hi   ; $1F
    CDA4: BC C2 CD    ldy $cdc2,x
    CDA7: 20 26 D1    jsr ppu_draw_mansion_stamps   ; $D126
    CDAA: A2 00       ldx #$00
    CDAC: A0 18       ldy #$18
    CDAE: A9 00       lda #$00
    CDB0: 20 B7 CD    jsr fill_attr_map_run   ; $CDB7
    CDB3: A0 78       ldy #$78
    CDB5: A9 55       lda #$55

fill_attr_map_run:
    CDB7: 9D 70 01    sta attr_dirty_bitmap,x   ; $0170
    CDBA: E8          inx
    CDBB: 88          dey
    CDBC: D0 F9       bne fill_attr_map_run   ; $CDB7
    CDBE: 60          rts

tbl_round_attributes:
    CDBF: 00          .byte $00
    CDC0: 04          .byte $04
    CDC1: 00          .byte $00
    CDC2: 00          .byte $00
    CDC3: 00          .byte $00
    CDC4: 08          .byte $08
    CDC5: 00          .byte $00
    CDC6: 00          .byte $00
    CDC7: 02          .byte $02
    CDC8: 04          .byte $04
    CDC9: 0A          .byte $0A
    CDCA: 0A          .byte $0A
    CDCB: 00          .byte $00
    CDCC: 06          .byte $06
    CDCD: 02          .byte $02
    CDCE: 02          .byte $02
    CDCF: 00          .byte $00
    CDD0: 04          .byte $04
    CDD1: 02          .byte $02
    CDD2: 02          .byte $02
    CDD3: 00          .byte $00
    CDD4: 08          .byte $08
    CDD5: 02          .byte $02
    CDD6: 02          .byte $02
    CDD7: 04          .byte $04
    CDD8: 04          .byte $04
    CDD9: 0A          .byte $0A
    CDDA: 0A          .byte $0A
    CDDB: 00          .byte $00
    CDDC: 06          .byte $06
    CDDD: 04          .byte $04
    CDDE: 04          .byte $04
    CDDF: 00          .byte $00
    CDE0: 04          .byte $04
    CDE1: 04          .byte $04
    CDE2: 04          .byte $04
    CDE3: 00          .byte $00
    CDE4: 08          .byte $08
    CDE5: 04          .byte $04
    CDE6: 04          .byte $04
    CDE7: 06          .byte $06
    CDE8: 04          .byte $04
    CDE9: 0A          .byte $0A
    CDEA: 0A          .byte $0A
    CDEB: 00          .byte $00
    CDEC: 06          .byte $06
    CDED: 06          .byte $06
    CDEE: 06          .byte $06
    CDEF: 00          .byte $00
    CDF0: 04          .byte $04
    CDF1: 06          .byte $06
    CDF2: 06          .byte $06
    CDF3: 00          .byte $00
    CDF4: 08          .byte $08
    CDF5: 06          .byte $06
    CDF6: 06          .byte $06
    CDF7: 08          .byte $08
    CDF8: 04          .byte $04
    CDF9: 0A          .byte $0A
    CDFA: 0A          .byte $0A
    CDFB: 00          .byte $00
    CDFC: 06          .byte $06
    CDFD: 00          .byte $00
    CDFE: 00          .byte $00

draw_bonus_intro_sprite:
    CDFF: A9 7C       lda #$7c
    CE01: 85 10       sta src_ptr   ; $10
    CE03: A9 00       lda #$00
    CE05: 85 11       sta zp_ptr_hi   ; $11
    CE07: 85 14       sta scan_src_ptr   ; $14
    CE09: 85 15       sta scratch_counter   ; $15
    CE0B: A9 AA       lda #$aa
    CE0D: 85 16       sta sprite_y   ; $16
    CE0F: A9 CB       lda #$cb
    CE11: 85 12       sta gfx_src_ptr   ; $12
    CE13: A9 02       lda #$02
    CE15: 85 13       sta data_ptr_hi   ; $13
    CE17: 4C EC C3    jmp draw_metasprite_2x2   ; $C3EC

show_bonus_results:
    CE1A: A9 00       lda #$00
    CE1C: 85 28       sta camera_x_lo   ; $28
    CE1E: 85 29       sta camera_x   ; $29
    CE20: 20 41 C2    jsr ppu_disable_render   ; $C241
    CE23: 20 F5 CB    jsr ppu_clear_nametables   ; $CBF5
    CE26: 20 03 D7    jsr draw_hud   ; $D703
    CE29: 20 39 C2    jsr ppu_enable_render   ; $C239
    CE2C: A0 00       ldy #$00
    CE2E: 20 CD CE    jsr draw_indexed_text_line   ; $CECD
    CE31: A9 01       lda #$01
    CE33: 8D 01 06    sta $0601
    CE36: 8D 18 06    sta $0618
    CE39: 20 BB CE    jsr wait_120_frames   ; $CEBB
    CE3C: A0 04       ldy #$04
    CE3E: 20 CD CE    jsr draw_indexed_text_line   ; $CECD
    CE41: A0 0E       ldy #$0e
    CE43: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CE46: A0 12       ldy #$12
    CE48: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CE4B: 20 BB CE    jsr wait_120_frames   ; $CEBB
    CE4E: A0 08       ldy #$08
    CE50: 20 CD CE    jsr draw_indexed_text_line   ; $CECD
    CE53: A0 10       ldy #$10
    CE55: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CE58: A0 14       ldy #$14
    CE5A: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CE5D: 20 94 CE    jsr wait_120_frames_with_sprite   ; $CE94
    CE60: A5 5A       lda ppu_block_src_ptr   ; $5A
    CE62: 85 5E       sta $5e
    CE64: F0 10       beq @CE76   ; $CE76
    CE66: A5 52       lda object_def_ptr   ; $52
    CE68: D0 0C       bne @CE76   ; $CE76
    CE6A: A0 0C       ldy #$0c
    CE6C: 20 CD CE    jsr draw_indexed_text_line   ; $CECD
    CE6F: A5 5E       lda $5e
    CE71: 18          clc
    CE72: 69 50       adc #$50
    CE74: 85 5E       sta $5e
@CE76:
    CE76: 20 94 CE    jsr wait_120_frames_with_sprite   ; $CE94
    CE79: A0 10       ldy #$10
    CE7B: 20 CD CE    jsr draw_indexed_text_line   ; $CECD
    CE7E: A0 0A       ldy #$0a
    CE80: 20 E5 D4    jsr bcd_add_from_table   ; $D4E5
    CE83: A0 16       ldy #$16
    CE85: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    CE88: 20 94 CE    jsr wait_120_frames_with_sprite   ; $CE94
    CE8B: A9 01       lda #$01
    CE8D: 85 43       sta score_update_phase   ; $43
    CE8F: A0 0C       ldy #$0c
    CE91: 4C E5 D4    jmp bcd_add_from_table   ; $D4E5

wait_120_frames_with_sprite:
    CE94: A9 78       lda #$78
    CE96: 85 0F       sta countdown_lo   ; $0F
@CE98:
    CE98: 20 41 C1    jsr yield_to_render_loop   ; $C141
    CE9B: A9 38       lda #$38
    CE9D: 85 10       sta src_ptr   ; $10
    CE9F: A9 70       lda #$70
    CEA1: 85 16       sta sprite_y   ; $16
    CEA3: A9 00       lda #$00
    CEA5: 85 11       sta zp_ptr_hi   ; $11
    CEA7: 85 14       sta scan_src_ptr   ; $14
    CEA9: A9 02       lda #$02
    CEAB: 85 13       sta data_ptr_hi   ; $13
    CEAD: 20 3D C6    jsr draw_goal_block_dd   ; $C63D
    CEB0: 20 1C D7    jsr blink_player_up_label   ; $D71C
    CEB3: 20 AB D5    jsr update_score   ; $D5AB
    CEB6: C6 0F       dec countdown_lo   ; $0F
    CEB8: D0 DE       bne @CE98   ; $CE98
    CEBA: 60          rts

wait_120_frames:
    CEBB: A9 78       lda #$78
    CEBD: 85 0F       sta countdown_lo   ; $0F
@CEBF:
    CEBF: 20 41 C1    jsr yield_to_render_loop   ; $C141
    CEC2: 20 1C D7    jsr blink_player_up_label   ; $D71C
    CEC5: 20 AB D5    jsr update_score   ; $D5AB
    CEC8: C6 0F       dec countdown_lo   ; $0F
    CECA: D0 F3       bne @CEBF   ; $CEBF
    CECC: 60          rts

draw_indexed_text_line:
    CECD: B9 08 CF    lda $cf08,y
    CED0: 85 10       sta src_ptr   ; $10
    CED2: B9 09 CF    lda $cf09,y
    CED5: 85 11       sta zp_ptr_hi   ; $11
    CED7: B9 0A CF    lda $cf0a,y
    CEDA: 85 12       sta gfx_src_ptr   ; $12
    CEDC: B9 0B CF    lda $cf0b,y
    CEDF: 85 13       sta data_ptr_hi   ; $13
    CEE1: A9 80       lda #$80
    CEE3: 85 14       sta scan_src_ptr   ; $14
    CEE5: 4C FB C6    jmp draw_rle_text   ; $C6FB

dead_clear_zp_04_07:
    CEE8: A2          .byte $A2
    CEE9: 00          .byte $00
    CEEA: A9          .byte $A9
    CEEB: 00          .byte $00
    CEEC: 95          .byte $95
    CEED: 04          .byte $04
    CEEE: E8          .byte $E8
    CEEF: E0          .byte $E0
    CEF0: 04          .byte $04
    CEF1: D0          .byte $D0
    CEF2: F9          .byte $F9
    CEF3: A5          .byte $A5
    CEF4: 51          .byte $51
    CEF5: F0          .byte $F0
    CEF6: 04          .byte $04
    CEF7: A9          .byte $A9
    CEF8: 50          .byte $50
    CEF9: 85          .byte $85
    CEFA: 06          .byte $06
    CEFB: 60          .byte $60

dead_clear_zp_00_03:
    CEFC: A2          .byte $A2
    CEFD: 00          .byte $00
    CEFE: A9          .byte $A9
    CEFF: 00          .byte $00
    CF00: 95          .byte $95
    CF01: 00          .byte $00
    CF02: E8          .byte $E8
    CF03: E0          .byte $E0
    CF04: 04          .byte $04
    CF05: D0          .byte $D0
    CF06: F9          .byte $F9
    CF07: 60          .byte $60
    CF08: 0C          .byte $0C
    CF09: 21          .byte $21
    CF0A: 1C          .byte $1C
    CF0B: CF          .byte $CF
    CF0C: 67          .byte $67
    CF0D: 21          .byte $21
    CF0E: 26          .byte $26
    CF0F: CF          .byte $CF
    CF10: 09          .byte $09
    CF11: 22          .byte $22
    CF12: 3A          .byte $3A
    CF13: CF          .byte $CF
    CF14: 86          .byte $86
    CF15: 22          .byte $22
    CF16: 48          .byte $48
    CF17: CF          .byte $CF
    CF18: 0D          .byte $0D
    CF19: 23          .byte $23
    CF1A: 5F          .byte $5F
    CF1B: CF          .byte $CF
    CF1C: 08          .byte $08
    CF1D: 0F          .byte $0F
    CF1E: 0B          .byte $0B
    CF1F: 1C          .byte $1C
    CF20: 18          .byte $18
    CF21: 13          .byte $13
    CF22: 18          .byte $18
    CF23: 11          .byte $11
    CF24: 1D          .byte $1D
    CF25: 00          .byte $00
    CF26: 02          .byte $02
    CF27: 28          .byte $28
    CF28: 29          .byte $29
    CF29: 1E          .byte $1E
    CF2A: 0E          .byte $0E
    CF2B: 2A          .byte $2A
    CF2C: 2B          .byte $2B
    CF2D: 00          .byte $00
    CF2E: 03          .byte $03
    CF2F: 01          .byte $01
    CF30: 01          .byte $01
    CF31: 00          .byte $00
    CF32: 8B          .byte $8B
    CF33: 00          .byte $00
    CF34: 00          .byte $00
    CF35: 00          .byte $00
    CF36: 00          .byte $00
    CF37: 00          .byte $00
    CF38: 8A          .byte $8A
    CF39: 00          .byte $00
    CF3A: 0C          .byte $0C
    CF3B: 03          .byte $03
    CF3C: 01          .byte $01
    CF3D: 01          .byte $01
    CF3E: 01          .byte $01
    CF3F: 00          .byte $00
    CF40: 8B          .byte $8B
    CF41: 00          .byte $00
    CF42: 00          .byte $00
    CF43: 00          .byte $00
    CF44: 00          .byte $00
    CF45: 00          .byte $00
    CF46: 8A          .byte $8A
    CF47: 00          .byte $00
    CF48: 15          .byte $15
    CF49: 1A          .byte $1A
    CF4A: 0F          .byte $0F
    CF4B: 1C          .byte $1C
    CF4C: 10          .byte $10
    CF4D: 0F          .byte $0F
    CF4E: 0D          .byte $0D
    CF4F: 1E          .byte $1E
    CF50: 00          .byte $00
    CF51: 11          .byte $11
    CF52: 0B          .byte $0B
    CF53: 17          .byte $17
    CF54: 0F          .byte $0F
    CF55: 00          .byte $00
    CF56: 00          .byte $00
    CF57: 8A          .byte $8A
    CF58: 00          .byte $00
    CF59: 00          .byte $00
    CF5A: 06          .byte $06
    CF5B: 01          .byte $01
    CF5C: 01          .byte $01
    CF5D: 01          .byte $01
    CF5E: 00          .byte $00
    CF5F: 08          .byte $08
    CF60: 1E          .byte $1E
    CF61: 19          .byte $19
    CF62: 1E          .byte $1E
    CF63: 0B          .byte $0B
    CF64: 16          .byte $16
    CF65: 00          .byte $00
    CF66: 00          .byte $00
    CF67: 8A          .byte $8A
    CF68: 00          .byte $00

ppu_draw_rle_blocks:
    CF69: B9 A6 CF    lda tbl_frameitem_ptr,y   ; $CFA6
    CF6C: 85 10       sta src_ptr   ; $10
    CF6E: B9 A7 CF    lda $cfa7,y
    CF71: 85 11       sta zp_ptr_hi   ; $11
    CF73: A0 00       ldy #$00
@CF75:
    CF75: B1 10       lda (src_ptr),y   ; $10
    CF77: F0 2C       beq @CFA5   ; $CFA5
    CF79: C8          iny
    CF7A: 85 17       sta draw_row_counter   ; $17
    CF7C: B1 10       lda (src_ptr),y   ; $10
    CF7E: C8          iny
    CF7F: AA          tax
    CF80: B1 10       lda (src_ptr),y   ; $10
    CF82: C8          iny
    CF83: 8D 06 20    sta PPUADDR   ; $2006
    CF86: 8E 06 20    stx PPUADDR   ; $2006
    CF89: 84 16       sty sprite_y   ; $16
@CF8B:
    CF8B: B1 10       lda (src_ptr),y   ; $10
    CF8D: F0 0D       beq @CF9C   ; $CF9C
    CF8F: C8          iny
    CF90: AA          tax
    CF91: B1 10       lda (src_ptr),y   ; $10
    CF93: C8          iny
@CF94:
    CF94: 8D 07 20    sta PPUDATA   ; $2007
    CF97: CA          dex
    CF98: D0 FA       bne @CF94   ; $CF94
    CF9A: F0 EF       beq @CF8B   ; $CF8B
@CF9C:
    CF9C: C8          iny
    CF9D: C6 17       dec draw_row_counter   ; $17
    CF9F: F0 D4       beq @CF75   ; $CF75
    CFA1: A4 16       ldy sprite_y   ; $16
    CFA3: D0 E6       bne @CF8B   ; $CF8B
@CFA5:
    CFA5: 60          rts

tbl_frameitem_ptr:
    CFA6:            .word frameitem_block_00
    CFA8:            .word frameitem_block_02
    CFAA:            .word frameitem_block_04
    CFAC:            .word frameitem_block_06
    CFAE:            .word frameitem_frame_fixed
    CFB0:            .word frameitem_block_0A

frameitem_block_00:
    CFB2: 01          .byte $01
    CFB3: A3          .byte $A3
    CFB4: 20          .byte $20
    CFB5: 01          .byte $01
    CFB6: 5A          .byte $5A
    CFB7: 1C          .byte $1C
    CFB8: 84          .byte $84
    CFB9: 02          .byte $02
    CFBA: 00          .byte $00
    CFBB: 01          .byte $01
    CFBC: 5A          .byte $5A
    CFBD: 1D          .byte $1D
    CFBE: 84          .byte $84
    CFBF: 01          .byte $01
    CFC0: 00          .byte $00
    CFC1: 01          .byte $01
    CFC2: 5A          .byte $5A
    CFC3: 1E          .byte $1E
    CFC4: 84          .byte $84
    CFC5: 00          .byte $00
    CFC6: 01          .byte $01
    CFC7: A0          .byte $A0
    CFC8: 24          .byte $24
    CFC9: 18          .byte $18
    CFCA: 84          .byte $84
    CFCB: 01          .byte $01
    CFCC: 5B          .byte $5B
    CFCD: 07          .byte $07
    CFCE: 00          .byte $00
    CFCF: 19          .byte $19
    CFD0: 84          .byte $84
    CFD1: 01          .byte $01
    CFD2: 5B          .byte $5B
    CFD3: 06          .byte $06
    CFD4: 00          .byte $00
    CFD5: 1A          .byte $1A
    CFD6: 84          .byte $84
    CFD7: 01          .byte $01
    CFD8: 5B          .byte $5B
    CFD9: 00          .byte $00
    CFDA: 00          .byte $00

frameitem_block_02:
    CFDB: 01          .byte $01
    CFDC: 93          .byte $93
    CFDD: 20          .byte $20
    CFDE: 01          .byte $01
    CFDF: 74          .byte $74
    CFE0: 0C          .byte $0C
    CFE1: 75          .byte $75
    CFE2: 01          .byte $01
    CFE3: 00          .byte $00
    CFE4: 01          .byte $01
    CFE5: 7B          .byte $7B
    CFE6: 1E          .byte $1E
    CFE7: 84          .byte $84
    CFE8: 01          .byte $01
    CFE9: 00          .byte $00
    CFEA: 01          .byte $01
    CFEB: 77          .byte $77
    CFEC: 1E          .byte $1E
    CFED: 84          .byte $84
    CFEE: 01          .byte $01
    CFEF: 7B          .byte $7B
    CFF0: 1F          .byte $1F
    CFF1: 84          .byte $84
    CFF2: 00          .byte $00
    CFF3: 01          .byte $01
    CFF4: 80          .byte $80
    CFF5: 24          .byte $24
    CFF6: 08          .byte $08
    CFF7: 75          .byte $75
    CFF8: 01          .byte $01
    CFF9: 76          .byte $76
    CFFA: 17          .byte $17
    CFFB: 00          .byte $00
    CFFC: 1A          .byte $1A
    CFFD: 84          .byte $84
    CFFE: 01          .byte $01
    CFFF: 7E          .byte $7E
    D000: 05          .byte $05
    D001: 00          .byte $00
    D002: 1A          .byte $1A
    D003: 84          .byte $84
    D004: 01          .byte $01
    D005: 7A          .byte $7A
    D006: 05          .byte $05
    D007: 00          .byte $00
    D008: 1B          .byte $1B
    D009: 84          .byte $84
    D00A: 01          .byte $01
    D00B: 7E          .byte $7E
    D00C: 00          .byte $00
    D00D: 00          .byte $00

frameitem_block_04:
    D00E: 01          .byte $01
    D00F: 91          .byte $91
    D010: 20          .byte $20
    D011: 01          .byte $01
    D012: 74          .byte $74
    D013: 0E          .byte $0E
    D014: 75          .byte $75
    D015: 10          .byte $10
    D016: 00          .byte $00
    D017: 01          .byte $01
    D018: 7B          .byte $7B
    D019: 0F          .byte $0F
    D01A: 84          .byte $84
    D01B: 10          .byte $10
    D01C: 00          .byte $00
    D01D: 01          .byte $01
    D01E: 77          .byte $77
    D01F: 0F          .byte $0F
    D020: 84          .byte $84
    D021: 08          .byte $08
    D022: 00          .byte $00
    D023: 07          .byte $07
    D024: 81          .byte $81
    D025: 01          .byte $01
    D026: 7B          .byte $7B
    D027: 10          .byte $10
    D028: 84          .byte $84
    D029: 00          .byte $00
    D02A: 01          .byte $01
    D02B: 80          .byte $80
    D02C: 24          .byte $24
    D02D: 0A          .byte $0A
    D02E: 75          .byte $75
    D02F: 01          .byte $01
    D030: 76          .byte $76
    D031: 15          .byte $15
    D032: 00          .byte $00
    D033: 0B          .byte $0B
    D034: 84          .byte $84
    D035: 01          .byte $01
    D036: 7E          .byte $7E
    D037: 14          .byte $14
    D038: 00          .byte $00
    D039: 0B          .byte $0B
    D03A: 84          .byte $84
    D03B: 01          .byte $01
    D03C: 7A          .byte $7A
    D03D: 14          .byte $14
    D03E: 00          .byte $00
    D03F: 0C          .byte $0C
    D040: 84          .byte $84
    D041: 01          .byte $01
    D042: 7E          .byte $7E
    D043: 07          .byte $07
    D044: 81          .byte $81
    D045: 00          .byte $00
    D046: 00          .byte $00

frameitem_block_06:
    D047: 01          .byte $01
    D048: 82          .byte $82
    D049: 20          .byte $20
    D04A: 01          .byte $01
    D04B: 74          .byte $74
    D04C: 1D          .byte $1D
    D04D: 75          .byte $75
    D04E: 01          .byte $01
    D04F: 00          .byte $00
    D050: 01          .byte $01
    D051: 7B          .byte $7B
    D052: 1E          .byte $1E
    D053: 84          .byte $84
    D054: 01          .byte $01
    D055: 00          .byte $00
    D056: 01          .byte $01
    D057: 77          .byte $77
    D058: 1E          .byte $1E
    D059: 84          .byte $84
    D05A: 01          .byte $01
    D05B: 7B          .byte $7B
    D05C: 1F          .byte $1F
    D05D: 84          .byte $84
    D05E: 00          .byte $00
    D05F: 01          .byte $01
    D060: 80          .byte $80
    D061: 24          .byte $24
    D062: 19          .byte $19
    D063: 75          .byte $75
    D064: 01          .byte $01
    D065: 76          .byte $76
    D066: 06          .byte $06
    D067: 00          .byte $00
    D068: 1A          .byte $1A
    D069: 84          .byte $84
    D06A: 01          .byte $01
    D06B: 7E          .byte $7E
    D06C: 05          .byte $05
    D06D: 00          .byte $00
    D06E: 1A          .byte $1A
    D06F: 84          .byte $84
    D070: 01          .byte $01
    D071: 7A          .byte $7A
    D072: 05          .byte $05
    D073: 00          .byte $00
    D074: 1B          .byte $1B
    D075: 84          .byte $84
    D076: 01          .byte $01
    D077: 7E          .byte $7E
    D078: 00          .byte $00
    D079: 00          .byte $00

frameitem_frame_fixed:
    D07A: 05          .byte $05
    D07B: 01          .byte $01
    D07C: 21          .byte $21
    D07D: 01          .byte $01
    D07E: 4C          .byte $4C
    D07F: 1E          .byte $1E
    D080: 4A          .byte $4A
    D081: 01          .byte $01
    D082: 00          .byte $00
    D083: 01          .byte $01
    D084: 4C          .byte $4C
    D085: 1F          .byte $1F
    D086: 00          .byte $00
    D087: 01          .byte $01
    D088: 4C          .byte $4C
    D089: 1F          .byte $1F
    D08A: 00          .byte $00
    D08B: 01          .byte $01
    D08C: 4C          .byte $4C
    D08D: 1F          .byte $1F
    D08E: 00          .byte $00
    D08F: 00          .byte $00
    D090: 05          .byte $05
    D091: 00          .byte $00
    D092: 25          .byte $25
    D093: 1A          .byte $1A
    D094: 4A          .byte $4A
    D095: 01          .byte $01
    D096: 4D          .byte $4D
    D097: 1F          .byte $1F
    D098: 00          .byte $00
    D099: 01          .byte $01
    D09A: 4D          .byte $4D
    D09B: 1F          .byte $1F
    D09C: 00          .byte $00
    D09D: 01          .byte $01
    D09E: 4D          .byte $4D
    D09F: 1F          .byte $1F
    D0A0: 00          .byte $00
    D0A1: 01          .byte $01
    D0A2: 4D          .byte $4D
    D0A3: 05          .byte $05
    D0A4: 00          .byte $00
    D0A5: 00          .byte $00
    D0A6: 20          .byte $20
    D0A7: 80          .byte $80
    D0A8: 23          .byte $23
    D0A9: 01          .byte $01
    D0AA: 4E          .byte $4E
    D0AB: 01          .byte $01
    D0AC: 4F          .byte $4F
    D0AD: 00          .byte $00
    D0AE: 20          .byte $20
    D0AF: 80          .byte $80
    D0B0: 27          .byte $27
    D0B1: 01          .byte $01
    D0B2: 4E          .byte $4E
    D0B3: 01          .byte $01
    D0B4: 4F          .byte $4F
    D0B5: 00          .byte $00
    D0B6: 01          .byte $01
    D0B7: C0          .byte $C0
    D0B8: 23          .byte $23
    D0B9: 08          .byte $08
    D0BA: 00          .byte $00
    D0BB: 38          .byte $38
    D0BC: 55          .byte $55
    D0BD: 00          .byte $00
    D0BE: 01          .byte $01
    D0BF: C0          .byte $C0
    D0C0: 27          .byte $27
    D0C1: 40          .byte $40
    D0C2: 55          .byte $55
    D0C3: 00          .byte $00
    D0C4: 00          .byte $00

frameitem_block_0A:
    D0C5: 05          .byte $05
    D0C6: A2          .byte $A2
    D0C7: 20          .byte $20
    D0C8: 01          .byte $01
    D0C9: 82          .byte $82
    D0CA: 01          .byte $01
    D0CB: 83          .byte $83
    D0CC: 04          .byte $04
    D0CD: 4A          .byte $4A
    D0CE: 00          .byte $00
    D0CF: 16          .byte $16
    D0D0: C2          .byte $C2
    D0D1: 20          .byte $20
    D0D2: 01          .byte $01
    D0D3: 4C          .byte $4C
    D0D4: 01          .byte $01
    D0D5: 4D          .byte $4D
    D0D6: 04          .byte $04
    D0D7: 00          .byte $00
    D0D8: 01          .byte $01
    D0D9: 4C          .byte $4C
    D0DA: 01          .byte $01
    D0DB: 4D          .byte $4D
    D0DC: 04          .byte $04
    D0DD: 00          .byte $00
    D0DE: 01          .byte $01
    D0DF: 4C          .byte $4C
    D0E0: 01          .byte $01
    D0E1: 4D          .byte $4D
    D0E2: 04          .byte $04
    D0E3: 00          .byte $00
    D0E4: 01          .byte $01
    D0E5: 4C          .byte $4C
    D0E6: 01          .byte $01
    D0E7: 4D          .byte $4D
    D0E8: 04          .byte $04
    D0E9: 00          .byte $00
    D0EA: 01          .byte $01
    D0EB: 4C          .byte $4C
    D0EC: 01          .byte $01
    D0ED: 4D          .byte $4D
    D0EE: 06          .byte $06
    D0EF: 00          .byte $00
    D0F0: 00          .byte $00
    D0F1: 04          .byte $04
    D0F2: A0          .byte $A0
    D0F3: 24          .byte $24
    D0F4: 01          .byte $01
    D0F5: 82          .byte $82
    D0F6: 01          .byte $01
    D0F7: 83          .byte $83
    D0F8: 04          .byte $04
    D0F9: 4A          .byte $4A
    D0FA: 00          .byte $00
    D0FB: 01          .byte $01
    D0FC: B8          .byte $B8
    D0FD: 24          .byte $24
    D0FE: 01          .byte $01
    D0FF: 82          .byte $82
    D100: 01          .byte $01
    D101: 83          .byte $83
    D102: 00          .byte $00
    D103: 16          .byte $16
    D104: C0          .byte $C0
    D105: 24          .byte $24
    D106: 01          .byte $01
    D107: 4C          .byte $4C
    D108: 01          .byte $01
    D109: 4D          .byte $4D
    D10A: 04          .byte $04
    D10B: 00          .byte $00
    D10C: 01          .byte $01
    D10D: 4C          .byte $4C
    D10E: 01          .byte $01
    D10F: 4D          .byte $4D
    D110: 04          .byte $04
    D111: 00          .byte $00
    D112: 01          .byte $01
    D113: 4C          .byte $4C
    D114: 01          .byte $01
    D115: 4D          .byte $4D
    D116: 04          .byte $04
    D117: 00          .byte $00
    D118: 01          .byte $01
    D119: 4C          .byte $4C
    D11A: 01          .byte $01
    D11B: 4D          .byte $4D
    D11C: 04          .byte $04
    D11D: 00          .byte $00
    D11E: 01          .byte $01
    D11F: 4C          .byte $4C
    D120: 01          .byte $01
    D121: 4D          .byte $4D
    D122: 06          .byte $06
    D123: 00          .byte $00
    D124: 00          .byte $00
    D125: 00          .byte $00

ppu_draw_mansion_stamps:
    D126: B9 85 D1    lda tbl_mansion_ptr,y   ; $D185
    D129: 85 10       sta src_ptr   ; $10
    D12B: B9 86 D1    lda $d186,y
    D12E: 85 11       sta zp_ptr_hi   ; $11
    D130: A0 00       ldy #$00
@D132:
    D132: B1 10       lda (src_ptr),y   ; $10
    D134: F0 4E       beq @D184   ; $D184
    D136: C8          iny
    D137: 85 17       sta draw_row_counter   ; $17
    D139: B1 10       lda (src_ptr),y   ; $10
    D13B: C8          iny
    D13C: 85 12       sta gfx_src_ptr   ; $12
    D13E: B1 10       lda (src_ptr),y   ; $10
    D140: C8          iny
    D141: 85 13       sta data_ptr_hi   ; $13
@D143:
    D143: B1 10       lda (src_ptr),y   ; $10
    D145: C8          iny
    D146: 85 14       sta scan_src_ptr   ; $14
    D148: B1 10       lda (src_ptr),y   ; $10
    D14A: C8          iny
    D14B: 85 15       sta scratch_counter   ; $15
    D14D: 84 16       sty sprite_y   ; $16
    D14F: A0 00       ldy #$00
@D151:
    D151: A5 15       lda scratch_counter   ; $15
    D153: 8D 06 20    sta PPUADDR   ; $2006
    D156: A5 14       lda scan_src_ptr   ; $14
    D158: 8D 06 20    sta PPUADDR   ; $2006
    D15B: B1 12       lda (gfx_src_ptr),y   ; $12
    D15D: C8          iny
    D15E: AA          tax
@D15F:
    D15F: B1 12       lda (gfx_src_ptr),y   ; $12
    D161: C8          iny
    D162: 8D 07 20    sta PPUDATA   ; $2007
    D165: CA          dex
    D166: D0 F7       bne @D15F   ; $D15F
    D168: B1 12       lda (gfx_src_ptr),y   ; $12
    D16A: F0 10       beq @D17C   ; $D17C
    D16C: 10 02       bpl @D170   ; $D170
    D16E: C6 15       dec scratch_counter   ; $15
@D170:
    D170: C8          iny
    D171: 18          clc
    D172: 65 14       adc scan_src_ptr   ; $14
    D174: 85 14       sta scan_src_ptr   ; $14
    D176: 90 D9       bcc @D151   ; $D151
    D178: E6 15       inc scratch_counter   ; $15
    D17A: B0 D5       bcs @D151   ; $D151
@D17C:
    D17C: A4 16       ldy sprite_y   ; $16
    D17E: C6 17       dec draw_row_counter   ; $17
    D180: D0 C1       bne @D143   ; $D143
    D182: F0 AE       beq @D132   ; $D132
@D184:
    D184: 60          rts

tbl_mansion_ptr:
    D185:            .word mansion_block_00
    D187:            .word mansion_block_02
    D189:            .word mansion_block_04
    D18B:            .word mansion_block_06
    D18D:            .word mansion_block_08
    D18F:            .word mansion_block_0A
    D191:            .word mansion_frame_bonus

mansion_block_00:
    D193: 04          .byte $04
    D194: 51          .byte $51
    D195: D3          .byte $D3
    D196: A8          .byte $A8
    D197: 20          .byte $20
    D198: B2          .byte $B2
    D199: 20          .byte $20
    D19A: A8          .byte $A8
    D19B: 24          .byte $24
    D19C: B2          .byte $B2
    D19D: 24          .byte $24
    D19E: 03          .byte $03
    D19F: 6B          .byte $6B
    D1A0: D3          .byte $D3
    D1A1: 8D          .byte $8D
    D1A2: 20          .byte $20
    D1A3: 9D          .byte $9D
    D1A4: 20          .byte $20
    D1A5: 8D          .byte $8D
    D1A6: 24          .byte $24
    D1A7: 01          .byte $01
    D1A8: B3          .byte $B3
    D1A9: D3          .byte $D3
    D1AA: 06          .byte $06
    D1AB: 21          .byte $21
    D1AC: 04          .byte $04
    D1AD: D1          .byte $D1
    D1AE: D3          .byte $D3
    D1AF: 86          .byte $86
    D1B0: 21          .byte $21
    D1B1: 06          .byte $06
    D1B2: 22          .byte $22
    D1B3: 86          .byte $86
    D1B4: 22          .byte $22
    D1B5: 06          .byte $06
    D1B6: 23          .byte $23
    D1B7: 01          .byte $01
    D1B8: C2          .byte $C2
    D1B9: D3          .byte $D3
    D1BA: 00          .byte $00
    D1BB: 25          .byte $25
    D1BC: 04          .byte $04
    D1BD: C5          .byte $C5
    D1BE: D3          .byte $D3
    D1BF: 85          .byte $85
    D1C0: 25          .byte $25
    D1C1: 05          .byte $05
    D1C2: 26          .byte $26
    D1C3: 85          .byte $85
    D1C4: 26          .byte $26
    D1C5: 05          .byte $05
    D1C6: 27          .byte $27
    D1C7: 15          .byte $15
    D1C8: 10          .byte $10
    D1C9: D4          .byte $D4
    D1CA: 82          .byte $82
    D1CB: 21          .byte $21
    D1CC: 02          .byte $02
    D1CD: 22          .byte $22
    D1CE: 82          .byte $82
    D1CF: 22          .byte $22
    D1D0: 02          .byte $02
    D1D1: 23          .byte $23
    D1D2: A2          .byte $A2
    D1D3: 23          .byte $23
    D1D4: 92          .byte $92
    D1D5: 21          .byte $21
    D1D6: 12          .byte $12
    D1D7: 22          .byte $22
    D1D8: 92          .byte $92
    D1D9: 22          .byte $22
    D1DA: 12          .byte $12
    D1DB: 23          .byte $23
    D1DC: B2          .byte $B2
    D1DD: 23          .byte $23
    D1DE: 1C          .byte $1C
    D1DF: 21          .byte $21
    D1E0: 86          .byte $86
    D1E1: 25          .byte $25
    D1E2: 06          .byte $06
    D1E3: 26          .byte $26
    D1E4: 86          .byte $86
    D1E5: 26          .byte $26
    D1E6: 06          .byte $06
    D1E7: 27          .byte $27
    D1E8: A6          .byte $A6
    D1E9: 27          .byte $27
    D1EA: 96          .byte $96
    D1EB: 25          .byte $25
    D1EC: 16          .byte $16
    D1ED: 26          .byte $26
    D1EE: 96          .byte $96
    D1EF: 26          .byte $26
    D1F0: 16          .byte $16
    D1F1: 27          .byte $27
    D1F2: B6          .byte $B6
    D1F3: 27          .byte $27
    D1F4: 00          .byte $00

mansion_block_02:
    D1F5: 08          .byte $08
    D1F6: 5D          .byte $5D
    D1F7: D3          .byte $D3
    D1F8: C3          .byte $C3
    D1F9: 20          .byte $20
    D1FA: C7          .byte $C7
    D1FB: 20          .byte $20
    D1FC: CB          .byte $CB
    D1FD: 20          .byte $20
    D1FE: CF          .byte $CF
    D1FF: 20          .byte $20
    D200: CB          .byte $CB
    D201: 24          .byte $24
    D202: CF          .byte $CF
    D203: 24          .byte $24
    D204: D3          .byte $D3
    D205: 24          .byte $24
    D206: D7          .byte $D7
    D207: 24          .byte $24
    D208: 04          .byte $04
    D209: 51          .byte $51
    D20A: D3          .byte $D3
    D20B: B5          .byte $B5
    D20C: 20          .byte $20
    D20D: B8          .byte $B8
    D20E: 20          .byte $20
    D20F: A2          .byte $A2
    D210: 24          .byte $24
    D211: A5          .byte $A5
    D212: 24          .byte $24
    D213: 01          .byte $01
    D214: 6F          .byte $6F
    D215: D3          .byte $D3
    D216: BC          .byte $BC
    D217: 20          .byte $20
    D218: 02          .byte $02
    D219: B3          .byte $B3
    D21A: D3          .byte $D3
    D21B: 06          .byte $06
    D21C: 21          .byte $21
    D21D: 06          .byte $06
    D21E: 23          .byte $23
    D21F: 03          .byte $03
    D220: E0          .byte $E0
    D221: D3          .byte $D3
    D222: 86          .byte $86
    D223: 21          .byte $21
    D224: 06          .byte $06
    D225: 22          .byte $22
    D226: 86          .byte $86
    D227: 22          .byte $22
    D228: 02          .byte $02
    D229: C2          .byte $C2
    D22A: D3          .byte $D3
    D22B: 00          .byte $00
    D22C: 25          .byte $25
    D22D: 00          .byte $00
    D22E: 27          .byte $27
    D22F: 03          .byte $03
    D230: EF          .byte $EF
    D231: D3          .byte $D3
    D232: 80          .byte $80
    D233: 25          .byte $25
    D234: 00          .byte $00
    D235: 26          .byte $26
    D236: 80          .byte $80
    D237: 26          .byte $26
    D238: 13          .byte $13
    D239: 10          .byte $10
    D23A: D4          .byte $D4
    D23B: 02          .byte $02
    D23C: 21          .byte $21
    D23D: 82          .byte $82
    D23E: 21          .byte $21
    D23F: 02          .byte $02
    D240: 22          .byte $22
    D241: 82          .byte $82
    D242: 22          .byte $22
    D243: 02          .byte $02
    D244: 23          .byte $23
    D245: A2          .byte $A2
    D246: 23          .byte $23
    D247: 10          .byte $10
    D248: 22          .byte $22
    D249: 1C          .byte $1C
    D24A: 21          .byte $21
    D24B: 9C          .byte $9C
    D24C: 21          .byte $21
    D24D: 9C          .byte $9C
    D24E: 22          .byte $22
    D24F: 1C          .byte $1C
    D250: 23          .byte $23
    D251: BC          .byte $BC
    D252: 23          .byte $23
    D253: 08          .byte $08
    D254: 26          .byte $26
    D255: 16          .byte $16
    D256: 25          .byte $25
    D257: 96          .byte $96
    D258: 25          .byte $25
    D259: 16          .byte $16
    D25A: 26          .byte $26
    D25B: 96          .byte $96
    D25C: 26          .byte $26
    D25D: 16          .byte $16
    D25E: 27          .byte $27
    D25F: B6          .byte $B6
    D260: 27          .byte $27
    D261: 00          .byte $00

mansion_block_04:
    D262: 02          .byte $02
    D263: 81          .byte $81
    D264: D3          .byte $D3
    D265: 82          .byte $82
    D266: 20          .byte $20
    D267: 96          .byte $96
    D268: 24          .byte $24
    D269: 03          .byte $03
    D26A: 51          .byte $51
    D26B: D3          .byte $D3
    D26C: B2          .byte $B2
    D26D: 20          .byte $20
    D26E: BD          .byte $BD
    D26F: 20          .byte $20
    D270: A8          .byte $A8
    D271: 24          .byte $24
    D272: 04          .byte $04
    D273: 5D          .byte $5D
    D274: D3          .byte $D3
    D275: B6          .byte $B6
    D276: 20          .byte $20
    D277: B9          .byte $B9
    D278: 20          .byte $20
    D279: A1          .byte $A1
    D27A: 24          .byte $24
    D27B: A4          .byte $A4
    D27C: 24          .byte $24
    D27D: 03          .byte $03
    D27E: B3          .byte $B3
    D27F: D3          .byte $D3
    D280: 06          .byte $06
    D281: 21          .byte $21
    D282: 86          .byte $86
    D283: 21          .byte $21
    D284: 86          .byte $86
    D285: 22          .byte $22
    D286: 01          .byte $01
    D287: FE          .byte $FE
    D288: D3          .byte $D3
    D289: 06          .byte $06
    D28A: 22          .byte $22
    D28B: 01          .byte $01
    D28C: D1          .byte $D1
    D28D: D3          .byte $D3
    D28E: 06          .byte $06
    D28F: 23          .byte $23
    D290: 04          .byte $04
    D291: C2          .byte $C2
    D292: D3          .byte $D3
    D293: 00          .byte $00
    D294: 25          .byte $25
    D295: 80          .byte $80
    D296: 25          .byte $25
    D297: 00          .byte $00
    D298: 26          .byte $26
    D299: 80          .byte $80
    D29A: 26          .byte $26
    D29B: 01          .byte $01
    D29C: C5          .byte $C5
    D29D: D3          .byte $D3
    D29E: 05          .byte $05
    D29F: 27          .byte $27
    D2A0: 01          .byte $01
    D2A1: 16          .byte $16
    D2A2: D4          .byte $D4
    D2A3: 1C          .byte $1C
    D2A4: 21          .byte $21
    D2A5: 18          .byte $18
    D2A6: 10          .byte $10
    D2A7: D4          .byte $D4
    D2A8: 02          .byte $02
    D2A9: 21          .byte $21
    D2AA: 82          .byte $82
    D2AB: 21          .byte $21
    D2AC: 02          .byte $02
    D2AD: 22          .byte $22
    D2AE: 82          .byte $82
    D2AF: 22          .byte $22
    D2B0: 02          .byte $02
    D2B1: 23          .byte $23
    D2B2: A2          .byte $A2
    D2B3: 23          .byte $23
    D2B4: 12          .byte $12
    D2B5: 21          .byte $21
    D2B6: 92          .byte $92
    D2B7: 21          .byte $21
    D2B8: 12          .byte $12
    D2B9: 22          .byte $22
    D2BA: 92          .byte $92
    D2BB: 22          .byte $22
    D2BC: 12          .byte $12
    D2BD: 23          .byte $23
    D2BE: B2          .byte $B2
    D2BF: 23          .byte $23
    D2C0: 06          .byte $06
    D2C1: 25          .byte $25
    D2C2: 86          .byte $86
    D2C3: 25          .byte $25
    D2C4: 06          .byte $06
    D2C5: 26          .byte $26
    D2C6: 86          .byte $86
    D2C7: 26          .byte $26
    D2C8: 06          .byte $06
    D2C9: 27          .byte $27
    D2CA: A6          .byte $A6
    D2CB: 27          .byte $27
    D2CC: 16          .byte $16
    D2CD: 25          .byte $25
    D2CE: 96          .byte $96
    D2CF: 25          .byte $25
    D2D0: 16          .byte $16
    D2D1: 26          .byte $26
    D2D2: 96          .byte $96
    D2D3: 26          .byte $26
    D2D4: 16          .byte $16
    D2D5: 27          .byte $27
    D2D6: B6          .byte $B6
    D2D7: 27          .byte $27
    D2D8: 00          .byte $00

mansion_block_06:
    D2D9: 08          .byte $08
    D2DA: 51          .byte $51
    D2DB: D3          .byte $D3
    D2DC: A3          .byte $A3
    D2DD: 20          .byte $20
    D2DE: A9          .byte $A9
    D2DF: 20          .byte $20
    D2E0: AF          .byte $AF
    D2E1: 20          .byte $20
    D2E2: B5          .byte $B5
    D2E3: 20          .byte $20
    D2E4: A5          .byte $A5
    D2E5: 24          .byte $24
    D2E6: AB          .byte $AB
    D2E7: 24          .byte $24
    D2E8: B1          .byte $B1
    D2E9: 24          .byte $24
    D2EA: B7          .byte $B7
    D2EB: 24          .byte $24
    D2EC: 08          .byte $08
    D2ED: 5D          .byte $5D
    D2EE: D3          .byte $D3
    D2EF: A6          .byte $A6
    D2F0: 20          .byte $20
    D2F1: AC          .byte $AC
    D2F2: 20          .byte $20
    D2F3: B2          .byte $B2
    D2F4: 20          .byte $20
    D2F5: B8          .byte $B8
    D2F6: 20          .byte $20
    D2F7: A2          .byte $A2
    D2F8: 24          .byte $24
    D2F9: A8          .byte $A8
    D2FA: 24          .byte $24
    D2FB: AE          .byte $AE
    D2FC: 24          .byte $24
    D2FD: B4          .byte $B4
    D2FE: 24          .byte $24
    D2FF: 01          .byte $01
    D300: A1          .byte $A1
    D301: D3          .byte $D3
    D302: BC          .byte $BC
    D303: 20          .byte $20
    D304: 04          .byte $04
    D305: 65          .byte $65
    D306: D3          .byte $D3
    D307: 88          .byte $88
    D308: 20          .byte $20
    D309: 94          .byte $94
    D30A: 20          .byte $20
    D30B: 84          .byte $84
    D30C: 24          .byte $24
    D30D: 90          .byte $90
    D30E: 24          .byte $24
    D30F: 05          .byte $05
    D310: C2          .byte $C2
    D311: D3          .byte $D3
    D312: 06          .byte $06
    D313: 21          .byte $21
    D314: 86          .byte $86
    D315: 21          .byte $21
    D316: 06          .byte $06
    D317: 22          .byte $22
    D318: 86          .byte $86
    D319: 22          .byte $22
    D31A: 06          .byte $06
    D31B: 23          .byte $23
    D31C: 05          .byte $05
    D31D: B3          .byte $B3
    D31E: D3          .byte $D3
    D31F: 00          .byte $00
    D320: 25          .byte $25
    D321: 80          .byte $80
    D322: 25          .byte $25
    D323: 00          .byte $00
    D324: 26          .byte $26
    D325: 80          .byte $80
    D326: 26          .byte $26
    D327: 00          .byte $00
    D328: 27          .byte $27
    D329: 12          .byte $12
    D32A: 10          .byte $10
    D32B: D4          .byte $D4
    D32C: 02          .byte $02
    D32D: 21          .byte $21
    D32E: 82          .byte $82
    D32F: 21          .byte $21
    D330: 02          .byte $02
    D331: 23          .byte $23
    D332: A2          .byte $A2
    D333: 23          .byte $23
    D334: 0C          .byte $0C
    D335: 22          .byte $22
    D336: 8C          .byte $8C
    D337: 22          .byte $22
    D338: 9C          .byte $9C
    D339: 21          .byte $21
    D33A: 1C          .byte $1C
    D33B: 22          .byte $22
    D33C: 9C          .byte $9C
    D33D: 22          .byte $22
    D33E: 1C          .byte $1C
    D33F: 23          .byte $23
    D340: BC          .byte $BC
    D341: 23          .byte $23
    D342: 1C          .byte $1C
    D343: 21          .byte $21
    D344: 0C          .byte $0C
    D345: 26          .byte $26
    D346: 8C          .byte $8C
    D347: 26          .byte $26
    D348: 16          .byte $16
    D349: 25          .byte $25
    D34A: 96          .byte $96
    D34B: 25          .byte $25
    D34C: 16          .byte $16
    D34D: 27          .byte $27
    D34E: B6          .byte $B6
    D34F: 27          .byte $27

mansion_block_08:
    D350: 00          .byte $00
    D351: 02          .byte $02
    D352: 5C          .byte $5C
    D353: 5D          .byte $5D
    D354: 20          .byte $20
    D355: 02          .byte $02
    D356: 5E          .byte $5E
    D357: 5F          .byte $5F
    D358: 20          .byte $20
    D359: 02          .byte $02
    D35A: 60          .byte $60
    D35B: 60          .byte $60
    D35C: 00          .byte $00
    D35D: 02          .byte $02
    D35E: 71          .byte $71
    D35F: 72          .byte $72
    D360: 20          .byte $20
    D361: 02          .byte $02
    D362: 73          .byte $73
    D363: 73          .byte $73
    D364: 00          .byte $00
    D365: 04          .byte $04
    D366: 76          .byte $76
    D367: 00          .byte $00
    D368: 00          .byte $00
    D369: 74          .byte $74
    D36A: 00          .byte $00
    D36B: 02          .byte $02
    D36C: 61          .byte $61
    D36D: 62          .byte $62
    D36E: 1F          .byte $1F
    D36F: 04          .byte $04
    D370: 63          .byte $63
    D371: 64          .byte $64
    D372: 65          .byte $65
    D373: 66          .byte $66
    D374: 20          .byte $20
    D375: 04          .byte $04
    D376: 67          .byte $67
    D377: 68          .byte $68
    D378: 69          .byte $69
    D379: 6A          .byte $6A
    D37A: 20          .byte $20
    D37B: 04          .byte $04
    D37C: 67          .byte $67
    D37D: 6B          .byte $6B
    D37E: 6C          .byte $6C
    D37F: 6A          .byte $6A
    D380: 00          .byte $00
    D381: 04          .byte $04
    D382: 74          .byte $74
    D383: 75          .byte $75
    D384: 75          .byte $75
    D385: 76          .byte $76
    D386: 1F          .byte $1F
    D387: 06          .byte $06
    D388: 7B          .byte $7B
    D389: 84          .byte $84
    D38A: 78          .byte $78
    D38B: 79          .byte $79
    D38C: 84          .byte $84
    D38D: 7E          .byte $7E
    D38E: 20          .byte $20
    D38F: 06          .byte $06
    D390: 77          .byte $77
    D391: 84          .byte $84
    D392: 7C          .byte $7C
    D393: 7D          .byte $7D
    D394: 84          .byte $84
    D395: 7A          .byte $7A
    D396: 1F          .byte $1F
    D397: 08          .byte $08
    D398: 7B          .byte $7B
    D399: 84          .byte $84
    D39A: 84          .byte $84
    D39B: 6B          .byte $6B
    D39C: 6C          .byte $6C
    D39D: 84          .byte $84
    D39E: 84          .byte $84
    D39F: 7E          .byte $7E
    D3A0: 00          .byte $00
    D3A1: 04          .byte $04
    D3A2: 78          .byte $78
    D3A3: 7F          .byte $7F
    D3A4: 80          .byte $80
    D3A5: 79          .byte $79
    D3A6: 20          .byte $20
    D3A7: 04          .byte $04
    D3A8: 7C          .byte $7C
    D3A9: 00          .byte $00
    D3AA: 00          .byte $00
    D3AB: 7D          .byte $7D
    D3AC: 20          .byte $20
    D3AD: 04          .byte $04
    D3AE: 6B          .byte $6B
    D3AF: 00          .byte $00
    D3B0: 00          .byte $00
    D3B1: 6C          .byte $6C
    D3B2: 00          .byte $00
    D3B3: 01          .byte $01
    D3B4: 4B          .byte $4B
    D3B5: 06          .byte $06
    D3B6: 01          .byte $01
    D3B7: 4B          .byte $4B
    D3B8: 05          .byte $05
    D3B9: 01          .byte $01
    D3BA: 4B          .byte $4B
    D3BB: 05          .byte $05
    D3BC: 01          .byte $01
    D3BD: 4B          .byte $4B
    D3BE: 05          .byte $05
    D3BF: 01          .byte $01
    D3C0: 4B          .byte $4B
    D3C1: 00          .byte $00
    D3C2: 01          .byte $01
    D3C3: 4B          .byte $4B
    D3C4: 05          .byte $05
    D3C5: 01          .byte $01
    D3C6: 4B          .byte $4B
    D3C7: 05          .byte $05
    D3C8: 01          .byte $01
    D3C9: 4B          .byte $4B
    D3CA: 05          .byte $05
    D3CB: 01          .byte $01
    D3CC: 4B          .byte $4B
    D3CD: 06          .byte $06
    D3CE: 01          .byte $01
    D3CF: 4B          .byte $4B
    D3D0: 00          .byte $00
    D3D1: 01          .byte $01
    D3D2: 4B          .byte $4B
    D3D3: 06          .byte $06
    D3D4: 01          .byte $01
    D3D5: 4B          .byte $4B
    D3D6: 05          .byte $05
    D3D7: 01          .byte $01
    D3D8: 4B          .byte $4B
    D3D9: 05          .byte $05
    D3DA: 01          .byte $01
    D3DB: 4B          .byte $4B
    D3DC: 07          .byte $07
    D3DD: 01          .byte $01
    D3DE: 4B          .byte $4B
    D3DF: 00          .byte $00
    D3E0: 01          .byte $01
    D3E1: 4B          .byte $4B
    D3E2: 05          .byte $05
    D3E3: 01          .byte $01
    D3E4: 4B          .byte $4B
    D3E5: 04          .byte $04
    D3E6: 01          .byte $01
    D3E7: 4B          .byte $4B
    D3E8: 05          .byte $05
    D3E9: 01          .byte $01
    D3EA: 4B          .byte $4B
    D3EB: 07          .byte $07
    D3EC: 01          .byte $01
    D3ED: 4B          .byte $4B
    D3EE: 00          .byte $00
    D3EF: 01          .byte $01
    D3F0: 4B          .byte $4B
    D3F1: 07          .byte $07
    D3F2: 01          .byte $01
    D3F3: 4B          .byte $4B
    D3F4: 05          .byte $05
    D3F5: 01          .byte $01
    D3F6: 4B          .byte $4B
    D3F7: 04          .byte $04
    D3F8: 01          .byte $01
    D3F9: 4B          .byte $4B
    D3FA: 05          .byte $05
    D3FB: 01          .byte $01
    D3FC: 4B          .byte $4B
    D3FD: 00          .byte $00
    D3FE: 01          .byte $01
    D3FF: 4B          .byte $4B
    D400: 06          .byte $06
    D401: 01          .byte $01
    D402: 4B          .byte $4B
    D403: 05          .byte $05
    D404: 01          .byte $01
    D405: 4B          .byte $4B
    D406: 05          .byte $05
    D407: 01          .byte $01
    D408: 4B          .byte $4B
    D409: 03          .byte $03
    D40A: 01          .byte $01
    D40B: 4B          .byte $4B
    D40C: 02          .byte $02
    D40D: 01          .byte $01
    D40E: 4B          .byte $4B
    D40F: 00          .byte $00
    D410: 04          .byte $04
    D411: 00          .byte $00
    D412: 00          .byte $00
    D413: 00          .byte $00
    D414: 00          .byte $00
    D415: 00          .byte $00
    D416: 04          .byte $04
    D417: 49          .byte $49
    D418: 49          .byte $49
    D419: 49          .byte $49
    D41A: 49          .byte $49
    D41B: 00          .byte $00

mansion_block_0A:
    D41C: 05          .byte $05
    D41D: 67          .byte $67
    D41E: D4          .byte $D4
    D41F: E8          .byte $E8
    D420: 20          .byte $20
    D421: EE          .byte $EE
    D422: 22          .byte $22
    D423: E0          .byte $E0
    D424: 26          .byte $26
    D425: 66          .byte $66
    D426: 25          .byte $25
    D427: F2          .byte $F2
    D428: 24          .byte $24
    D429: 06          .byte $06
    D42A: 5B          .byte $5B
    D42B: D4          .byte $D4
    D42C: 68          .byte $68
    D42D: 22          .byte $22
    D42E: 14          .byte $14
    D42F: 21          .byte $21
    D430: 1A          .byte $1A
    D431: 22          .byte $22
    D432: 00          .byte $00
    D433: 25          .byte $25
    D434: EC          .byte $EC
    D435: 25          .byte $25
    D436: 72          .byte $72
    D437: 26          .byte $26
    D438: 04          .byte $04
    D439: 7B          .byte $7B
    D43A: D4          .byte $D4
    D43B: 02          .byte $02
    D43C: 22          .byte $22
    D43D: 8E          .byte $8E
    D43E: 22          .byte $22
    D43F: 80          .byte $80
    D440: 26          .byte $26
    D441: 12          .byte $12
    D442: 26          .byte $26
    D443: 0A          .byte $0A
    D444: 10          .byte $10
    D445: D4          .byte $D4
    D446: 84          .byte $84
    D447: 23          .byte $23
    D448: A4          .byte $A4
    D449: 23          .byte $23
    D44A: AA          .byte $AA
    D44B: 23          .byte $23
    D44C: B0          .byte $B0
    D44D: 23          .byte $23
    D44E: B6          .byte $B6
    D44F: 23          .byte $23
    D450: BC          .byte $BC
    D451: 23          .byte $23
    D452: A2          .byte $A2
    D453: 27          .byte $27
    D454: A8          .byte $A8
    D455: 27          .byte $27
    D456: AE          .byte $AE
    D457: 27          .byte $27
    D458: B4          .byte $B4
    D459: 27          .byte $27
    D45A: 00          .byte $00
    D45B: 02          .byte $02
    D45C: 00          .byte $00
    D45D: 00          .byte $00
    D45E: 20          .byte $20
    D45F: 02          .byte $02
    D460: 00          .byte $00
    D461: 00          .byte $00
    D462: 20          .byte $20
    D463: 02          .byte $02
    D464: 00          .byte $00
    D465: 00          .byte $00
    D466: 20          .byte $20
    D467: 02          .byte $02
    D468: 00          .byte $00
    D469: 00          .byte $00
    D46A: 20          .byte $20
    D46B: 02          .byte $02
    D46C: 00          .byte $00
    D46D: 00          .byte $00
    D46E: 20          .byte $20
    D46F: 02          .byte $02
    D470: 00          .byte $00
    D471: 00          .byte $00
    D472: 20          .byte $20
    D473: 02          .byte $02
    D474: 00          .byte $00
    D475: 00          .byte $00
    D476: 20          .byte $20
    D477: 02          .byte $02
    D478: 00          .byte $00
    D479: 00          .byte $00
    D47A: 00          .byte $00
    D47B: 02          .byte $02
    D47C: 82          .byte $82
    D47D: 83          .byte $83
    D47E: 06          .byte $06
    D47F: 02          .byte $02
    D480: 82          .byte $82
    D481: 83          .byte $83
    D482: 00          .byte $00

mansion_frame_bonus:
    D483: 01          .byte $01
    D484: 93          .byte $93
    D485: D4          .byte $D4
    D486: 6A          .byte $6A
    D487: 21          .byte $21
    D488: 01          .byte $01
    D489: A0          .byte $A0
    D48A: D4          .byte $D4
    D48B: 51          .byte $51
    D48C: 22          .byte $22
    D48D: 01          .byte $01
    D48E: AF          .byte $AF
    D48F: D4          .byte $D4
    D490: C9          .byte $C9
    D491: 22          .byte $22
    D492: 00          .byte $00
    D493: 0B          .byte $0B
    D494: 0C          .byte $0C
    D495: 19          .byte $19
    D496: 18          .byte $18
    D497: 1F          .byte $1F
    D498: 1D          .byte $1D
    D499: 00          .byte $00
    D49A: 1C          .byte $1C
    D49B: 19          .byte $19
    D49C: 1F          .byte $1F
    D49D: 18          .byte $18
    D49E: 0E          .byte $0E
    D49F: 00          .byte $00
    D4A0: 02          .byte $02
    D4A1: 28          .byte $28
    D4A2: 29          .byte $29
    D4A3: 1A          .byte $1A
    D4A4: 09          .byte $09
    D4A5: 1D          .byte $1D
    D4A6: 1E          .byte $1E
    D4A7: 13          .byte $13
    D4A8: 18          .byte $18
    D4A9: 11          .byte $11
    D4AA: 00          .byte $00
    D4AB: 2A          .byte $2A
    D4AC: 2B          .byte $2B
    D4AD: 1D          .byte $1D
    D4AE: 00          .byte $00
    D4AF: 0D          .byte $0D
    D4B0: 0C          .byte $0C
    D4B1: 0F          .byte $0F
    D4B2: 10          .byte $10
    D4B3: 19          .byte $19
    D4B4: 1C          .byte $1C
    D4B5: 0F          .byte $0F
    D4B6: 00          .byte $00
    D4B7: 00          .byte $00
    D4B8: 00          .byte $00
    D4B9: 0F          .byte $0F
    D4BA: 18          .byte $18
    D4BB: 0E          .byte $0E
    D4BC: 1D          .byte $1D
    D4BD: 00          .byte $00

add_score_n_times:
    D4BE: 85 19       sta draw_data_ptr_hi   ; $19
@D4C0:
    D4C0: A4 19       ldy draw_data_ptr_hi   ; $19
    D4C2: 20 CA D4    jsr add_score_from_table   ; $D4CA
    D4C5: C6 18       dec scratch_loop_counter   ; $18
    D4C7: D0 F7       bne @D4C0   ; $D4C0
@D4C9:
    D4C9: 60          rts

add_score_from_table:
    D4CA: A5 42       lda game_phase   ; $42
    D4CC: F0 FB       beq @D4C9   ; $D4C9
    D4CE: 85 43       sta score_update_phase   ; $43
    D4D0: 98          tya
    D4D1: 18          clc
    D4D2: 6D 61 D5    adc $d561
    D4D5: 85 12       sta gfx_src_ptr   ; $12
    D4D7: AD 62 D5    lda $d562
    D4DA: 69 00       adc #$00
    D4DC: 85 13       sta data_ptr_hi   ; $13
    D4DE: A2 74       ldx #$74
    D4E0: A0 03       ldy #$03
    D4E2: 4C 02 D5    jmp bcd_add   ; $D502

bcd_add_from_table:
    D4E5: B9 36 D5    lda $d536,y
    D4E8: 85 10       sta src_ptr   ; $10
    D4EA: B9 37 D5    lda $d537,y
    D4ED: 85 11       sta zp_ptr_hi   ; $11
    D4EF: A0 00       ldy #$00
    D4F1: B1 10       lda (src_ptr),y   ; $10
    D4F3: C8          iny
    D4F4: AA          tax
    D4F5: B1 10       lda (src_ptr),y   ; $10
    D4F7: C8          iny
    D4F8: 85 12       sta gfx_src_ptr   ; $12
    D4FA: B1 10       lda (src_ptr),y   ; $10
    D4FC: C8          iny
    D4FD: 85 13       sta data_ptr_hi   ; $13
    D4FF: B1 10       lda (src_ptr),y   ; $10
    D501: A8          tay

bcd_add:
    D502: 18          clc
@D503:
    D503: B1 12       lda (gfx_src_ptr),y   ; $12
    D505: 29 0F       and #$0f
    D507: 85 14       sta scan_src_ptr   ; $14
    D509: B1 12       lda (gfx_src_ptr),y   ; $12
    D50B: 29 F0       and #$f0
    D50D: 85 15       sta scratch_counter   ; $15
    D50F: B5 00       lda indirect_ptr,x   ; $00
    D511: 29 0F       and #$0f
    D513: 65 14       adc scan_src_ptr   ; $14
    D515: C9 0A       cmp #$0a
    D517: 90 02       bcc @D51B   ; $D51B
    D519: 69 05       adc #$05
@D51B:
    D51B: 85 14       sta scan_src_ptr   ; $14
    D51D: 18          clc
    D51E: B5 00       lda indirect_ptr,x   ; $00
    D520: 29 F0       and #$f0
    D522: 65 14       adc scan_src_ptr   ; $14
    D524: 65 15       adc scratch_counter   ; $15
    D526: B0 04       bcs @D52C   ; $D52C
    D528: C9 A0       cmp #$a0
    D52A: 90 03       bcc @D52F   ; $D52F
@D52C:
    D52C: 69 5F       adc #$5f
    D52E: 38          sec
@D52F:
    D52F: 95 00       sta indirect_ptr,x   ; $00
    D531: CA          dex
    D532: 88          dey
    D533: 10 CE       bpl @D503   ; $D503
    D535: 60          rts
    D536: 44          .byte $44
    D537: D5          .byte $D5
    D538: 48          .byte $48
    D539: D5          .byte $D5
    D53A: 4C          .byte $4C
    D53B: D5          .byte $D5
    D53C: 50          .byte $50
    D53D: D5          .byte $D5
    D53E: 54          .byte $54
    D53F: D5          .byte $D5
    D540: 58          .byte $58
    D541: D5          .byte $D5
    D542: 5C          .byte $5C
    D543: D5          .byte $D5
    D544: 76          .byte $76
    D545: 49          .byte $49
    D546: 00          .byte $00
    D547: 00          .byte $00
    D548: 70          .byte $70
    D549: 60          .byte $60
    D54A: D5          .byte $D5
    D54B: 00          .byte $00
    D54C: 77          .byte $77
    D54D: 60          .byte $60
    D54E: D5          .byte $D5
    D54F: 00          .byte $00
    D550: 50          .byte $50
    D551: 60          .byte $60
    D552: D5          .byte $D5
    D553: 00          .byte $00
    D554: 57          .byte $57
    D555: 67          .byte $67
    D556: D5          .byte $D5
    D557: 03          .byte $03
    D558: 5F          .byte $5F
    D559: 54          .byte $54
    D55A: 00          .byte $00
    D55B: 03          .byte $03
    D55C: 74          .byte $74
    D55D: 5C          .byte $5C
    D55E: 00          .byte $00
    D55F: 03          .byte $03
    D560: 01          .byte $01
    D561: 63          .byte $63
    D562: D5          .byte $D5
    D563: 00          .byte $00
    D564: 00          .byte $00
    D565: 01          .byte $01
    D566: 00          .byte $00
    D567: 00          .byte $00
    D568: 00          .byte $00
    D569: 02          .byte $02
    D56A: 00          .byte $00
    D56B: 00          .byte $00
    D56C: 00          .byte $00
    D56D: 03          .byte $03
    D56E: 00          .byte $00
    D56F: 00          .byte $00
    D570: 00          .byte $00
    D571: 04          .byte $04
    D572: 00          .byte $00
    D573: 00          .byte $00
    D574: 00          .byte $00
    D575: 05          .byte $05
    D576: 00          .byte $00
    D577: 00          .byte $00
    D578: 00          .byte $00
    D579: 02          .byte $02
    D57A: 00          .byte $00
    D57B: 00          .byte $00
    D57C: 00          .byte $00
    D57D: 04          .byte $04
    D57E: 00          .byte $00
    D57F: 00          .byte $00
    D580: 00          .byte $00
    D581: 08          .byte $08
    D582: 00          .byte $00
    D583: 00          .byte $00
    D584: 00          .byte $00
    D585: 12          .byte $12
    D586: 00          .byte $00
    D587: 00          .byte $00
    D588: 00          .byte $00
    D589: 16          .byte $16
    D58A: 00          .byte $00
    D58B: 00          .byte $00
    D58C: 00          .byte $00
    D58D: 20          .byte $20
    D58E: 00          .byte $00
    D58F: 00          .byte $00
    D590: 00          .byte $00
    D591: 30          .byte $30
    D592: 00          .byte $00
    D593: 00          .byte $00
    D594: 00          .byte $00
    D595: 40          .byte $40
    D596: 00          .byte $00
    D597: 00          .byte $00
    D598: 00          .byte $00
    D599: 50          .byte $50
    D59A: 00          .byte $00
    D59B: 00          .byte $00
    D59C: 00          .byte $00
    D59D: 60          .byte $60
    D59E: 00          .byte $00
    D59F: 00          .byte $00
    D5A0: 00          .byte $00
    D5A1: 00          .byte $00
    D5A2: 10          .byte $10
    D5A3: 00          .byte $00
    D5A4: 00          .byte $00
    D5A5: 00          .byte $00
    D5A6: 50          .byte $50
    D5A7: 00          .byte $00
    D5A8: 00          .byte $00
    D5A9: 10          .byte $10
    D5AA: 00          .byte $00

update_score:
    D5AB: A5 30       lda pending_score_count   ; $30
    D5AD: F0 0F       beq @D5BE   ; $D5BE
    D5AF: 85 18       sta scratch_loop_counter   ; $18
    D5B1: A9 40       lda #$40
    D5B3: 20 BE D4    jsr add_score_n_times   ; $D4BE
    D5B6: A9 00       lda #$00
    D5B8: 85 30       sta pending_score_count   ; $30
    D5BA: A9 01       lda #$01
    D5BC: 85 43       sta score_update_phase   ; $43
@D5BE:
    D5BE: A5 43       lda score_update_phase   ; $43
    D5C0: F0 66       beq @D628   ; $D628
    D5C2: C9 01       cmp #$01
    D5C4: F0 0F       beq @D5D5   ; $D5D5
    D5C6: A9 00       lda #$00
    D5C8: 85 43       sta score_update_phase   ; $43
    D5CA: 20 94 D6    jsr update_high_score   ; $D694
    D5CD: 20 AA D6    jsr award_extra_life   ; $D6AA
    D5D0: A0 08       ldy #$08
    D5D2: 4C D9 D5    jmp queue_bcd_number   ; $D5D9
@D5D5:
    D5D5: E6 43       inc score_update_phase   ; $43
    D5D7: A0 00       ldy #$00

queue_bcd_number:
    D5D9: B9 40 D6    lda $d640,y
    D5DC: 85 10       sta src_ptr   ; $10
    D5DE: B9 41 D6    lda $d641,y
    D5E1: 85 11       sta zp_ptr_hi   ; $11
    D5E3: A0 00       ldy #$00
    D5E5: B1 10       lda (src_ptr),y   ; $10
    D5E7: C8          iny
    D5E8: 85 12       sta gfx_src_ptr   ; $12
    D5EA: B1 10       lda (src_ptr),y   ; $10
    D5EC: C8          iny
    D5ED: 85 13       sta data_ptr_hi   ; $13
    D5EF: B1 10       lda (src_ptr),y   ; $10
    D5F1: C8          iny
    D5F2: AA          tax
    D5F3: B1 10       lda (src_ptr),y   ; $10
    D5F5: C8          iny
    D5F6: 85 14       sta scan_src_ptr   ; $14
    D5F8: B1 10       lda (src_ptr),y   ; $10
    D5FA: 85 15       sta scratch_counter   ; $15
    D5FC: A4 2A       ldy ppu_buffer_cursor   ; $2A
    D5FE: A5 12       lda gfx_src_ptr   ; $12
    D600: 99 00 05    sta vram_buffer,y   ; $0500
    D603: C8          iny
    D604: A5 13       lda data_ptr_hi   ; $13
    D606: 99 00 05    sta vram_buffer,y   ; $0500
    D609: C8          iny
    D60A: A5 14       lda scan_src_ptr   ; $14
    D60C: 0A          asl a
    D60D: 99 00 05    sta vram_buffer,y   ; $0500
    D610: C8          iny
@D611:
    D611: B5 00       lda indirect_ptr,x   ; $00
    D613: 4A          lsr a
    D614: 4A          lsr a
    D615: 4A          lsr a
    D616: 4A          lsr a
    D617: 20 29 D6    jsr queue_digit_blank_leading_zero   ; $D629
    D61A: B5 00       lda indirect_ptr,x   ; $00
    D61C: E8          inx
    D61D: 29 0F       and #$0f
    D61F: 20 29 D6    jsr queue_digit_blank_leading_zero   ; $D629
    D622: C6 14       dec scan_src_ptr   ; $14
    D624: D0 EB       bne @D611   ; $D611
    D626: 84 2A       sty ppu_buffer_cursor   ; $2A
@D628:
    D628: 60          rts

queue_digit_blank_leading_zero:
    D629: D0 09       bne @D634   ; $D634
    D62B: C6 15       dec scratch_counter   ; $15
    D62D: 30 05       bmi @D634   ; $D634
    D62F: 99 00 05    sta vram_buffer,y   ; $0500
    D632: C8          iny
    D633: 60          rts
@D634:
    D634: 18          clc
    D635: 69 01       adc #$01
    D637: 99 00 05    sta vram_buffer,y   ; $0500
    D63A: C8          iny
    D63B: A9 00       lda #$00
    D63D: 85 15       sta scratch_counter   ; $15
    D63F: 60          rts
    D640: 58          .byte $58
    D641: D6          .byte $D6
    D642: 5D          .byte $5D
    D643: D6          .byte $D6
    D644: 67          .byte $67
    D645: D6          .byte $D6
    D646: 62          .byte $62
    D647: D6          .byte $D6
    D648: 6C          .byte $6C
    D649: D6          .byte $D6
    D64A: 71          .byte $71
    D64B: D6          .byte $D6
    D64C: 76          .byte $76
    D64D: D6          .byte $D6
    D64E: 7B          .byte $7B
    D64F: D6          .byte $D6
    D650: 80          .byte $80
    D651: D6          .byte $D6
    D652: 85          .byte $85
    D653: D6          .byte $D6
    D654: 8A          .byte $8A
    D655: D6          .byte $D6
    D656: 8F          .byte $8F
    D657: D6          .byte $D6
    D658: 62          .byte $62
    D659: 20          .byte $20
    D65A: 71          .byte $71
    D65B: 04          .byte $04
    D65C: 06          .byte $06
    D65D: 74          .byte $74
    D65E: 20          .byte $20
    D65F: 71          .byte $71
    D660: 04          .byte $04
    D661: 06          .byte $06
    D662: 62          .byte $62
    D663: 20          .byte $20
    D664: B1          .byte $B1
    D665: 04          .byte $04
    D666: 06          .byte $06
    D667: 74          .byte $74
    D668: 20          .byte $20
    D669: B1          .byte $B1
    D66A: 04          .byte $04
    D66B: 06          .byte $06
    D66C: 6B          .byte $6B
    D66D: 20          .byte $20
    D66E: 44          .byte $44
    D66F: 04          .byte $04
    D670: 06          .byte $06
    D671: 76          .byte $76
    D672: 20          .byte $20
    D673: 70          .byte $70
    D674: 01          .byte $01
    D675: 01          .byte $01
    D676: 7A          .byte $7A
    D677: 20          .byte $20
    D678: 77          .byte $77
    D679: 01          .byte $01
    D67A: 01          .byte $01
    D67B: 90          .byte $90
    D67C: 21          .byte $21
    D67D: 50          .byte $50
    D67E: 01          .byte $01
    D67F: 01          .byte $01
    D680: 10          .byte $10
    D681: 22          .byte $22
    D682: 51          .byte $51
    D683: 01          .byte $01
    D684: 01          .byte $01
    D685: 97          .byte $97
    D686: 21          .byte $21
    D687: 56          .byte $56
    D688: 02          .byte $02
    D689: 02          .byte $02
    D68A: 17          .byte $17
    D68B: 22          .byte $22
    D68C: 5A          .byte $5A
    D68D: 02          .byte $02
    D68E: 02          .byte $02
    D68F: 15          .byte $15
    D690: 23          .byte $23
    D691: 5D          .byte $5D
    D692: 03          .byte $03
    D693: 04          .byte $04

update_high_score:
    D694: A2 03       ldx #$03
    D696: 38          sec
@D697:
    D697: B5 44       lda hi_score,x   ; $44
    D699: F5 71       sbc score,x   ; $71
    D69B: CA          dex
    D69C: 10 F9       bpl @D697   ; $D697
    D69E: B0 09       bcs @D6A9   ; $D6A9
    D6A0: A2 03       ldx #$03
@D6A2:
    D6A2: B5 71       lda score,x   ; $71
    D6A4: 95 44       sta hi_score,x   ; $44
    D6A6: CA          dex
    D6A7: 10 F9       bpl @D6A2   ; $D6A2
@D6A9:
    D6A9: 60          rts

award_extra_life:
    D6AA: A5 75       lda current_record_index   ; $75
    D6AC: C5 48       cmp indirect_ptr   ; $48
    D6AE: F0 F9       beq @D6A9   ; $D6A9
    D6B0: A5 72       lda draw_src_ptr   ; $72
    D6B2: C5 76       cmp record_index   ; $76
    D6B4: 90 F3       bcc @D6A9   ; $D6A9
    D6B6: A5 75       lda current_record_index   ; $75
    D6B8: D0 02       bne @D6BC   ; $D6BC
    D6BA: 85 76       sta record_index   ; $76
@D6BC:
    D6BC: E6 75       inc current_record_index   ; $75
    D6BE: D0 02       bne @D6C2   ; $D6C2
    D6C0: C6 75       dec current_record_index   ; $75
@D6C2:
    D6C2: A0 00       ldy #$00
    D6C4: 20 E5 D4    jsr bcd_add_from_table   ; $D4E5
    D6C7: 90 04       bcc @D6CD   ; $D6CD
    D6C9: A5 48       lda indirect_ptr   ; $48
    D6CB: 85 75       sta current_record_index   ; $75
@D6CD:
    D6CD: A9 01       lda #$01
    D6CF: 8D 02 06    sta $0602
    D6D2: 8D 03 06    sta $0603
    D6D5: 8D 04 06    sta $0604
    D6D8: A0 02       ldy #$02
    D6DA: 20 E5 D4    jsr bcd_add_from_table   ; $D4E5
    D6DD: 90 04       bcc @D6E3   ; $D6E3
    D6DF: A9 99       lda #$99
    D6E1: 85 70       sta p1_lives   ; $70
@D6E3:
    D6E3: A0 0A       ldy #$0a
    D6E5: 4C D9 D5    jmp queue_bcd_number   ; $D5D9

advance_to_next_round:
    D6E8: A0 04       ldy #$04
    D6EA: 20 E5 D4    jsr bcd_add_from_table   ; $D4E5
    D6ED: E6 7A       inc stage_number   ; $7A
    D6EF: A5 7A       lda stage_number   ; $7A
    D6F1: 29 0F       and #$0f
    D6F3: 85 7A       sta stage_number   ; $7A
    D6F5: A5 7D       lda stage_index   ; $7D
    D6F7: 18          clc
    D6F8: 69 01       adc #$01
    D6FA: C9 20       cmp #$20
    D6FC: 90 02       bcc @D700   ; $D700
    D6FE: A9 1C       lda #$1c
@D700:
    D700: 85 7D       sta stage_index   ; $7D
    D702: 60          rts

draw_hud:
    D703: A0 00       ldy #$00
    D705: 20 15 CC    jsr ppu_run_draw_blocks   ; $CC15
    D708: A0 08       ldy #$08
    D70A: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    D70D: A0 0A       ldy #$0a
    D70F: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    D712: A0 0C       ldy #$0c
    D714: 20 D9 D5    jsr queue_bcd_number   ; $D5D9
    D717: A0 00       ldy #$00
    D719: 4C D9 D5    jmp queue_bcd_number   ; $D5D9

blink_player_up_label:
    D71C: A5 42       lda game_phase   ; $42
    D71E: F0 15       beq show_player_up_label   ; $D735
    D720: A5 21       lda frame_counter   ; $21
    D722: 29 0F       and #$0f
    D724: D0 0E       bne @D734   ; $D734
    D726: A5 21       lda frame_counter   ; $21
    D728: 4A          lsr a
    D729: 4A          lsr a
    D72A: 4A          lsr a
    D72B: 29 02       and #$02
    D72D: 05 41       ora game_state_flags   ; $41
    D72F: 0A          asl a
    D730: A8          tay
    D731: 4C 7A D7    jmp queue_vram_packet   ; $D77A
@D734:
    D734: 60          rts

show_player_up_label:
    D735: A9 02       lda #$02
    D737: 05 41       ora game_state_flags   ; $41
    D739: 0A          asl a
    D73A: A8          tay
    D73B: 4C 7A D7    jmp queue_vram_packet   ; $D77A

title_menu_cursor:
    D73E: A5 24       lda draw_data_ptr   ; $24
    D740: 29 03       and #$03
    D742: C9 01       cmp #$01
    D744: D0 0A       bne @D750   ; $D750
    D746: A9 F0       lda #$f0
    D748: 85 0F       sta countdown_lo   ; $0F
    D74A: A5 4A       lda seq_data_ptr   ; $4A
    D74C: 49 01       eor #$01
    D74E: 85 4A       sta seq_data_ptr   ; $4A
@D750:
    D750: A5 4A       lda seq_data_ptr   ; $4A
    D752: 0A          asl a
    D753: 69 08       adc #$08
    D755: 48          pha
    D756: A8          tay
    D757: 20 7A D7    jsr queue_vram_packet   ; $D77A
    D75A: 68          pla
    D75B: 18          clc
    D75C: 69 04       adc #$04
    D75E: A8          tay
    D75F: 4C 7A D7    jmp queue_vram_packet   ; $D77A

dead_toggle_cat_touch_flag:
    D762: A5          .byte $A5
    D763: 22          .byte $22
    D764: 29          .byte $29
    D765: 03          .byte $03
    D766: C9          .byte $C9
    D767: 01          .byte $01
    D768: D0          .byte $D0
    D769: 0A          .byte $0A
    D76A: A9          .byte $A9
    D76B: F0          .byte $F0
    D76C: 85          .byte $85
    D76D: 0F          .byte $0F
    D76E: A5          .byte $A5
    D76F: 2E          .byte $2E
    D770: 49          .byte $49
    D771: 01          .byte $01
    D772: 85          .byte $85
    D773: 2E          .byte $2E
    D774: A5          .byte $A5
    D775: 2E          .byte $2E
    D776: 0A          .byte $0A
    D777: 69          .byte $69
    D778: 10          .byte $10
    D779: A8          .byte $A8

queue_vram_packet:
    D77A: B9 AD D7    lda $d7ad,y
    D77D: 85 10       sta src_ptr   ; $10
    D77F: B9 AE D7    lda $d7ae,y
    D782: 85 11       sta zp_ptr_hi   ; $11
    D784: A0 00       ldy #$00
    D786: A6 2A       ldx ppu_buffer_cursor   ; $2A
    D788: B1 10       lda (src_ptr),y   ; $10
    D78A: C8          iny
    D78B: 9D 00 05    sta vram_buffer,x   ; $0500
    D78E: E8          inx
    D78F: B1 10       lda (src_ptr),y   ; $10
    D791: C8          iny
    D792: 9D 00 05    sta vram_buffer,x   ; $0500
    D795: E8          inx
    D796: B1 10       lda (src_ptr),y   ; $10
    D798: C8          iny
    D799: 9D 00 05    sta vram_buffer,x   ; $0500
    D79C: 85 12       sta gfx_src_ptr   ; $12
    D79E: E8          inx
@D79F:
    D79F: B1 10       lda (src_ptr),y   ; $10
    D7A1: C8          iny
    D7A2: 9D 00 05    sta vram_buffer,x   ; $0500
    D7A5: E8          inx
    D7A6: C6 12       dec gfx_src_ptr   ; $12
    D7A8: D0 F5       bne @D79F   ; $D79F
    D7AA: 86 2A       stx ppu_buffer_cursor   ; $2A
    D7AC: 60          rts
    D7AD: C1          .byte $C1
    D7AE: D7          .byte $D7
    D7AF: C7          .byte $C7
    D7B0: D7          .byte $D7
    D7B1: CD          .byte $CD
    D7B2: D7          .byte $D7
    D7B3: D3          .byte $D3
    D7B4: D7          .byte $D7
    D7B5: D9          .byte $D9
    D7B6: D7          .byte $D7
    D7B7: E1          .byte $E1
    D7B8: D7          .byte $D7
    D7B9: DD          .byte $DD
    D7BA: D7          .byte $D7
    D7BB: E5          .byte $E5
    D7BC: D7          .byte $D7
    D7BD: E9          .byte $E9
    D7BE: D7          .byte $D7
    D7BF: ED          .byte $ED
    D7C0: D7          .byte $D7
    D7C1: 45          .byte $45
    D7C2: 20          .byte $20
    D7C3: 03          .byte $03
    D7C4: 00          .byte $00
    D7C5: 00          .byte $00
    D7C6: 00          .byte $00
    D7C7: 45          .byte $45
    D7C8: 20          .byte $20
    D7C9: 03          .byte $03
    D7CA: 00          .byte $00
    D7CB: 00          .byte $00
    D7CC: 00          .byte $00
    D7CD: 45          .byte $45
    D7CE: 20          .byte $20
    D7CF: 03          .byte $03
    D7D0: A8          .byte $A8
    D7D1: AA          .byte $AA
    D7D2: AB          .byte $AB
    D7D3: 45          .byte $45
    D7D4: 20          .byte $20
    D7D5: 03          .byte $03
    D7D6: A9          .byte $A9
    D7D7: AA          .byte $AA
    D7D8: AB          .byte $AB
    D7D9: E9          .byte $E9
    D7DA: 21          .byte $21
    D7DB: 01          .byte $01
    D7DC: AF          .byte $AF
    D7DD: 29          .byte $29
    D7DE: 22          .byte $22
    D7DF: 01          .byte $01
    D7E0: 00          .byte $00
    D7E1: E9          .byte $E9
    D7E2: 21          .byte $21
    D7E3: 01          .byte $01
    D7E4: 00          .byte $00
    D7E5: 29          .byte $29
    D7E6: 22          .byte $22
    D7E7: 01          .byte $01
    D7E8: AF          .byte $AF
    D7E9: AC          .byte $AC
    D7EA: 21          .byte $21
    D7EB: 01          .byte $01
    D7EC: 00          .byte $00
    D7ED: AC          .byte $AC
    D7EE: 21          .byte $21
    D7EF: 01          .byte $01
    D7F0: 18          .byte $18

init_player_record:
    D7F1: 20 25 D8    jsr reset_camera_and_point_at_player   ; $D825
@D7F4:
    D7F4: B9 38 D8    lda $d838,y
    D7F7: 91 1E       sta (obj_record_ptr),y   ; $1E
    D7F9: C8          iny
    D7FA: C0 07       cpy #$07
    D7FC: D0 F6       bne @D7F4   ; $D7F4
    D7FE: A9 4B       lda #$4b
    D800: A0 08       ldy #$08
    D802: 91 1E       sta (obj_record_ptr),y   ; $1E
    D804: A9 00       lda #$00
    D806: A0 0F       ldy #$0f
    D808: 91 1E       sta (obj_record_ptr),y   ; $1E
    D80A: 60          rts

init_bonus_player:
    D80B: 20 25 D8    jsr reset_camera_and_point_at_player   ; $D825
@D80E:
    D80E: B9 3F D8    lda $d83f,y
    D811: 91 1E       sta (obj_record_ptr),y   ; $1E
    D813: C8          iny
    D814: C0 07       cpy #$07
    D816: D0 F6       bne @D80E   ; $D80E
    D818: A9 00       lda #$00
    D81A: A0 08       ldy #$08
    D81C: 91 1E       sta (obj_record_ptr),y   ; $1E
    D81E: A9 02       lda #$02
    D820: A0 0F       ldy #$0f
    D822: 91 1E       sta (obj_record_ptr),y   ; $1E
    D824: 60          rts

reset_camera_and_point_at_player:
    D825: A9 00       lda #$00
    D827: 85 28       sta camera_x_lo   ; $28
    D829: A9 1C       lda #$1c
    D82B: 85 29       sta camera_x   ; $29
    D82D: A9 00       lda #$00
    D82F: 85 1E       sta obj_record_ptr   ; $1E
    D831: A9 04       lda #$04
    D833: 85 1F       sta obj_record_ptr_hi   ; $1F
    D835: A0 00       ldy #$00
    D837: 60          rts
    D838: 00          .byte $00
    D839: 34          .byte $34
    D83A: 00          .byte $00
    D83B: 1A          .byte $1A
    D83C: 02          .byte $02
    D83D: 00          .byte $00
    D83E: FF          .byte $FF
    D83F: 00          .byte $00
    D840: 35          .byte $35
    D841: 00          .byte $00
    D842: 0A          .byte $0A
    D843: 06          .byte $06
    D844: 00          .byte $00
    D845: FF          .byte $FF

init_round_cats:
    D846: A9 30       lda #$30
    D848: 85 4C       sta respawn_slot   ; $4C
    D84A: A9 00       lda #$00
    D84C: 85 4D       sta respawn_tick   ; $4D
    D84E: A9 10       lda #$10
    D850: 85 4E       sta respawn_interval   ; $4E
    D852: A9 30       lda #$30
    D854: 85 1E       sta obj_record_ptr   ; $1E
    D856: A9 04       lda #$04
    D858: 85 1F       sta obj_record_ptr_hi   ; $1F
    D85A: A2 00       ldx #$00
@D85C:
    D85C: A9 03       lda #$03
    D85E: 20 94 D8    jsr init_cat_record   ; $D894
    D861: A9 01       lda #$01
    D863: A0 06       ldy #$06
    D865: 91 1E       sta (obj_record_ptr),y   ; $1E
    D867: 8A          txa
    D868: 18          clc
    D869: 69 08       adc #$08
    D86B: AA          tax
    D86C: A5 1E       lda obj_record_ptr   ; $1E
    D86E: 18          clc
    D86F: 69 10       adc #$10
    D871: 85 1E       sta obj_record_ptr   ; $1E
    D873: C5 68       cmp ptr_hi   ; $68
    D875: D0 E5       bne @D85C   ; $D85C
    D877: A9 00       lda #$00
    D879: 85 35       sta obj_collision_state   ; $35
    D87B: A9 09       lda #$09
    D87D: 85 36       sta obj_record_ptr   ; $36
    D87F: A9 04       lda #$04
    D881: 85 37       sta obj_record_ptr_hi   ; $37
    D883: A9 20       lda #$20
    D885: 85 1E       sta obj_record_ptr   ; $1E
    D887: A9 04       lda #$04
    D889: 85 1F       sta obj_record_ptr_hi   ; $1F
    D88B: A9 FF       lda #$ff
    D88D: 8D 26 04    sta $0426
    D890: A2 00       ldx #$00
    D892: A9 02       lda #$02

init_cat_record:
    D894: A0 05       ldy #$05
    D896: 91 1E       sta (obj_record_ptr),y   ; $1E
    D898: 8A          txa
    D899: 0A          asl a
    D89A: 0A          asl a
    D89B: 69 20       adc #$20
    D89D: A0 00       ldy #$00
    D89F: 91 1E       sta (obj_record_ptr),y   ; $1E
    D8A1: C8          iny
    D8A2: BD 64 02    lda item_x,x   ; $0264
    D8A5: 91 1E       sta (obj_record_ptr),y   ; $1E
    D8A7: BD 65 02    lda item_y,x   ; $0265
    D8AA: A0 03       ldy #$03
    D8AC: 91 1E       sta (obj_record_ptr),y   ; $1E
    D8AE: C8          iny
    D8AF: A9 02       lda #$02
    D8B1: 91 1E       sta (obj_record_ptr),y   ; $1E
    D8B3: A9 00       lda #$00
    D8B5: A0 0F       ldy #$0f
    D8B7: 91 1E       sta (obj_record_ptr),y   ; $1E
    D8B9: A9 4B       lda #$4b
    D8BB: A0 08       ldy #$08
    D8BD: 91 1E       sta (obj_record_ptr),y   ; $1E
    D8BF: 60          rts

init_bonus_goal_object:
    D8C0: A2 00       ldx #$00
@D8C2:
    D8C2: BD D3 D8    lda $d8d3,x
    D8C5: 9D 10 04    sta $0410,x
    D8C8: E8          inx
    D8C9: E0 05       cpx #$05
    D8CB: D0 F5       bne @D8C2   ; $D8C2
    D8CD: A9 0E       lda #$0e
    D8CF: 8D 1F 04    sta obj_state   ; $041F
    D8D2: 60          rts
    D8D3: 00          .byte $00
    D8D4: 05          .byte $05
    D8D5: 00          .byte $00
    D8D6: 18          .byte $18
    D8D7: 18          .byte $18

update_and_respawn_objects:
    D8D8: A9 00       lda #$00
    D8DA: 85 1E       sta obj_record_ptr   ; $1E
    D8DC: A9 04       lda #$04
    D8DE: 85 1F       sta obj_record_ptr_hi   ; $1F
@D8E0:
    D8E0: 20 39 D9    jsr set_object_intent   ; $D939
    D8E3: 20 2C DA    jsr dispatch_object_state   ; $DA2C
    D8E6: 20 05 C3    jsr draw_object   ; $C305
    D8E9: A5 1E       lda obj_record_ptr   ; $1E
    D8EB: 18          clc
    D8EC: 69 10       adc #$10
    D8EE: 85 1E       sta obj_record_ptr   ; $1E
    D8F0: C9 90       cmp #$90
    D8F2: D0 EC       bne @D8E0   ; $D8E0
    D8F4: E6 4D       inc respawn_tick   ; $4D
    D8F6: A5 4D       lda respawn_tick   ; $4D
    D8F8: C5 4E       cmp respawn_interval   ; $4E
    D8FA: 90 3C       bcc @D938   ; $D938
    D8FC: A9 00       lda #$00
    D8FE: 85 4D       sta respawn_tick   ; $4D
    D900: A6 4C       ldx respawn_slot   ; $4C
    D902: BD 0F 04    lda $040f,x
    D905: C9 1A       cmp #$1a
    D907: D0 22       bne @D92B   ; $D92B
    D909: BD 07 04    lda $0407,x
    D90C: D0 1D       bne @D92B   ; $D92B
    D90E: 9D 00 04    sta $0400,x
    D911: 9D 02 04    sta $0402,x
    D914: A9 1D       lda #$1d
    D916: 9D 01 04    sta $0401,x
    D919: A9 06       lda #$06
    D91B: 9D 03 04    sta $0403,x
    D91E: 9D 04 04    sta $0404,x
    D921: A9 1C       lda #$1c
    D923: 9D 0F 04    sta $040f,x
    D926: A9 00       lda #$00
    D928: 9D 08 04    sta $0408,x
@D92B:
    D92B: 8A          txa
    D92C: 18          clc
    D92D: 69 10       adc #$10
    D92F: AA          tax
    D930: E0 90       cpx #$90
    D932: D0 02       bne @D936   ; $D936
    D934: A2 10       ldx #$10
@D936:
    D936: 86 4C       stx respawn_slot   ; $4C
@D938:
    D938: 60          rts

set_object_intent:
    D939: A0 0D       ldy #$0d
    D93B: A5 1E       lda obj_record_ptr   ; $1E
    D93D: F0 4B       beq @D98A   ; $D98A
    D93F: A9 00       lda #$00
    D941: 91 1E       sta (obj_record_ptr),y   ; $1E
    D943: A5 1E       lda obj_record_ptr   ; $1E
    D945: C9 20       cmp #$20
    D947: 90 02       bcc @D94B   ; $D94B
    D949: F0 4D       beq @D998   ; $D998
@D94B:
    D94B: A0 0F       ldy #$0f
    D94D: B1 1E       lda (obj_record_ptr),y   ; $1E
    D94F: C9 02       cmp #$02
    D951: F0 44       beq @D997   ; $D997
    D953: C9 0C       cmp #$0c
    D955: D0 40       bne @D997   ; $D997
    D957: AD 0F 04    lda $040f
    D95A: C9 0C       cmp #$0c
    D95C: D0 12       bne @D970   ; $D970
    D95E: A0 00       ldy #$00
    D960: B1 1E       lda (obj_record_ptr),y   ; $1E
    D962: 38          sec
    D963: ED 00 04    sbc $0400
    D966: C8          iny
    D967: B1 1E       lda (obj_record_ptr),y   ; $1E
    D969: ED 01 04    sbc $0401
    D96C: C9 02       cmp #$02
    D96E: 90 27       bcc @D997   ; $D997
@D970:
    D970: A0 0A       ldy #$0a
    D972: B1 1E       lda (obj_record_ptr),y   ; $1E
    D974: 29 FC       and #$fc
    D976: 09 01       ora #$01
    D978: A0 03       ldy #$03
    D97A: D1 1E       cmp (obj_record_ptr),y   ; $1E
    D97C: D0 19       bne @D997   ; $D997
    D97E: A0 0A       ldy #$0a
    D980: B1 1E       lda (obj_record_ptr),y   ; $1E
    D982: 4A          lsr a
    D983: A0 0D       ldy #$0d
    D985: B0 2E       bcs @D9B5   ; $D9B5
    D987: 4C BC D9    jmp set_intent_right   ; $D9BC
@D98A:
    D98A: A5 42       lda game_phase   ; $42
    D98C: F0 39       beq @D9C7   ; $D9C7
    D98E: A5 26       lda pad_dir   ; $26
    D990: 91 1E       sta (obj_record_ptr),y   ; $1E
    D992: A5 22       lda scan_ptr   ; $22
    D994: C8          iny
    D995: 91 1E       sta (obj_record_ptr),y   ; $1E
@D997:
    D997: 60          rts
@D998:
    D998: AD 2F 04    lda stage_phase_state   ; $042F
    D99B: C9 02       cmp #$02
    D99D: F0 F8       beq @D997   ; $D997
    D99F: C9 0C       cmp #$0c
    D9A1: D0 F4       bne @D997   ; $D997
    D9A3: A5 36       lda obj_record_ptr   ; $36
    D9A5: CD 23 04    cmp obj_state   ; $0423
    D9A8: 90 ED       bcc @D997   ; $D997
    D9AA: AD 21 04    lda target_compare_value   ; $0421
    D9AD: C9 06       cmp #$06
    D9AF: 90 0B       bcc set_intent_right   ; $D9BC
    D9B1: C9 34       cmp #$34
    D9B3: 90 0C       bcc @D9C1   ; $D9C1
@D9B5:
    D9B5: A9 FF       lda #$ff
    D9B7: 91 1E       sta (obj_record_ptr),y   ; $1E
    D9B9: 60          rts
@D9BA:
    D9BA: 30 F9       bmi @D9B5   ; $D9B5

set_intent_right:
    D9BC: A9 01       lda #$01
    D9BE: 91 1E       sta (obj_record_ptr),y   ; $1E
    D9C0: 60          rts
@D9C1:
    D9C1: AD 26 04    lda $0426
    D9C4: 91 1E       sta (obj_record_ptr),y   ; $1E
    D9C6: 60          rts
@D9C7:
    D9C7: 0E 0E 04    asl $040e
    D9CA: A5 3C       lda seq_data_ptr_hi   ; $3C
    D9CC: F0 03       beq @D9D1   ; $D9D1
    D9CE: C6 3C       dec seq_data_ptr_hi   ; $3C
    D9D0: 60          rts
@D9D1:
    D9D1: A6 3D       ldx demo_script_cursor   ; $3D
    D9D3: BD E1 FF    lda tbl_demo_input_script,x   ; $FFE1
    D9D6: F0 0F       beq @D9E7   ; $D9E7
    D9D8: 0A          asl a
    D9D9: 0A          asl a
    D9DA: 85 3C       sta seq_data_ptr_hi   ; $3C
    D9DC: BD E1 FF    lda tbl_demo_input_script,x   ; $FFE1
    D9DF: E8          inx
    D9E0: 86 3D       stx demo_script_cursor   ; $3D
    D9E2: 0A          asl a
    D9E3: B0 D5       bcs @D9BA   ; $D9BA
    D9E5: 30 05       bmi @D9EC   ; $D9EC
@D9E7:
    D9E7: A9 00       lda #$00
    D9E9: 91 1E       sta (obj_record_ptr),y   ; $1E
    D9EB: 60          rts
@D9EC:
    D9EC: EE 0E 04    inc $040e
    D9EF: 60          rts

slot2_maybe_step_target_floor:
    D9F0: AD 21 04    lda target_compare_value   ; $0421
    D9F3: 38          sec
    D9F4: E9 06       sbc #$06
    D9F6: C9 2E       cmp #$2e
    D9F8: B0 08       bcs slot2_step_target_floor   ; $DA02
    D9FA: A5 35       lda obj_collision_state   ; $35
    D9FC: F0 20       beq @DA1E   ; $DA1E
    D9FE: A9 00       lda #$00
    DA00: 85 35       sta obj_collision_state   ; $35

slot2_step_target_floor:
    DA02: A5 36       lda obj_record_ptr   ; $36
    DA04: C9 09       cmp #$09
    DA06: D0 07       bne @DA0F   ; $DA0F
    DA08: A9 04       lda #$04
    DA0A: 85 37       sta obj_record_ptr_hi   ; $37
    DA0C: 4C 17 DA    jmp slot2_add_floor_step   ; $DA17
@DA0F:
    DA0F: C9 19       cmp #$19
    DA11: D0 04       bne slot2_add_floor_step   ; $DA17
    DA13: A9 FC       lda #$fc
    DA15: 85 37       sta obj_record_ptr_hi   ; $37

slot2_add_floor_step:
    DA17: A5 36       lda obj_record_ptr   ; $36
    DA19: 18          clc
    DA1A: 65 37       adc obj_record_ptr_hi   ; $37
    DA1C: 85 36       sta obj_record_ptr   ; $36
@DA1E:
    DA1E: 60          rts
@DA1F:
    DA1F: BD 7A E1    lda $e17a,x
    DA22: 85 1C       sta aux_ptr   ; $1C
    DA24: BD 7B E1    lda $e17b,x
    DA27: 85 1D       sta aux_ptr_hi   ; $1D
    DA29: 6C 1C 00    jmp (aux_ptr)   ; $001C

dispatch_object_state:
    DA2C: A0 0F       ldy #$0f
    DA2E: B1 1E       lda (obj_record_ptr),y   ; $1E
    DA30: AA          tax
    DA31: A5 7C       lda is_bonus_round   ; $7C
    DA33: D0 EA       bne @DA1F   ; $DA1F
    DA35: BD 42 DA    lda $da42,x
    DA38: 85 1C       sta aux_ptr   ; $1C
    DA3A: BD 43 DA    lda $da43,x
    DA3D: 85 1D       sta aux_ptr_hi   ; $1D
    DA3F: 6C 1C 00    jmp (aux_ptr)   ; $001C
    DA42:            .word handler_rts_noop
    DA44:            .word state02_walk
    DA46:            .word state04_hop_off_ledge
    DA48:            .word state06_fall
    DA4A:            .word state08_player_caught
    DA4C:            .word state0A_trampoline_bounce
    DA4E:            .word state0C_rise
    DA50:            .word state0E_step_onto_floor
    DA52:            .word state10_door_knockback
    DA54:            .word state12_stunned
    DA56:            .word state14_recover
    DA58:            .word handler_rts_noop
    DA5A:            .word handler_rts_noop
    DA5C:            .word state1A_respawn_wait
    DA5E:            .word state1C_respawn_drop
    DA60:            .word state1E_slot2_on_item
    DA62:            .word state20_slot2_scored
    DA64:            .word state22_knocked_out
    DA66:            .word state24_slot2_landing_pause
    DA68:            .word state26_stunned_by_drop
    DA6A:            .word state28_drop_stun_recover
    DA6C:            .word state2A_wait_then_start_tune
    DA6E:            .word state2C_wait_tune

state02_walk:
    DA70: A5 1E       lda obj_record_ptr   ; $1E
    DA72: C9 20       cmp #$20
    DA74: D0 08       bne @DA7E   ; $DA7E
    DA76: AD 2A 04    lda bonus_item_timer   ; $042A
    DA79: F0 03       beq @DA7E   ; $DA7E
    DA7B: CE 2A 04    dec bonus_item_timer   ; $042A
@DA7E:
    DA7E: 20 B7 E0    jsr walking_cat_touches_player   ; $E0B7
    DA81: F0 55       beq catch_player_or_knock_out   ; $DAD8
    DA83: 20 90 EA    jsr walker_meets_closed_door   ; $EA90
    DA86: 20 B1 F0    jsr press_floor_traps   ; $F0B1
    DA89: 20 E7 F0    jsr walker_over_open_trap   ; $F0E7
    DA8C: D0 03       bne @DA91   ; $DA91
    DA8E: 4C 83 DB    jmp enter_fall   ; $DB83
@DA91:
    DA91: A0 08       ldy #$08
    DA93: B1 1E       lda (obj_record_ptr),y   ; $1E
    DA95: 38          sec
    DA96: E9 49       sbc #$49
    DA98: C9 09       cmp #$09
    DA9A: B0 06       bcs start_hop_off_ledge   ; $DAA2
    DA9C: 20 E9 DE    jsr walk_step   ; $DEE9
    DA9F: 4C 72 E9    jmp player_opens_nearest_door   ; $E972

start_hop_off_ledge:
    DAA2: A5 1E       lda obj_record_ptr   ; $1E
    DAA4: C9 20       cmp #$20
    DAA6: F0 03       beq @DAAB   ; $DAAB
    DAA8: 20 A6 DE    jsr choose_cat_target_floor   ; $DEA6
@DAAB:
    DAAB: A9 0B       lda #$0b
    DAAD: A0 07       ldy #$07
    DAAF: 91 1E       sta (obj_record_ptr),y   ; $1E
    DAB1: A9 D0       lda #$d0

start_hop:
    DAB3: A0 0B       ldy #$0b
    DAB5: 91 1E       sta (obj_record_ptr),y   ; $1E
    DAB7: A9 09       lda #$09
    DAB9: C8          iny
    DABA: 91 1E       sta (obj_record_ptr),y   ; $1E
    DABC: A9 04       lda #$04
    DABE: A0 0F       ldy #$0f
    DAC0: 91 1E       sta (obj_record_ptr),y   ; $1E
    DAC2: A0 04       ldy #$04
    DAC4: 91 1E       sta (obj_record_ptr),y   ; $1E
    DAC6: 60          rts

state04_hop_off_ledge:
    DAC7: A0 07       ldy #$07
    DAC9: B1 1E       lda (obj_record_ptr),y   ; $1E
    DACB: 38          sec
    DACC: E9 01       sbc #$01
    DACE: 91 1E       sta (obj_record_ptr),y   ; $1E
    DAD0: D0 03       bne @DAD5   ; $DAD5
    DAD2: 4C 83 DB    jmp enter_fall   ; $DB83
@DAD5:
    DAD5: 4C 3D E0    jmp move_hop_arc   ; $E03D

catch_player_or_knock_out:
    DAD8: A5 1E       lda obj_record_ptr   ; $1E
    DADA: D0 35       bne @DB11   ; $DB11
    DADC: A9 1E       lda #$1e
    DADE: 8D 04 04    sta $0404
    DAE1: A9 00       lda #$00
    DAE3: 8D 07 04    sta $0407
    DAE6: A9 08       lda #$08
    DAE8: 8D 0F 04    sta $040f
    DAEB: A9 01       lda #$01
    DAED: 85 4B       sta player_down   ; $4B

reset_objects_except_persistent_types:
    DAEF: 20 BF F4    jsr init_sound_voices   ; $F4BF
    DAF2: A2 10       ldx #$10
@DAF4:
    DAF4: BD 0F 04    lda $040f,x
    DAF7: C9 16       cmp #$16
    DAF9: F0 0C       beq @DB07   ; $DB07
    DAFB: C9 20       cmp #$20
    DAFD: F0 08       beq @DB07   ; $DB07
    DAFF: A9 00       lda #$00
    DB01: 9D 0F 04    sta $040f,x
    DB04: 9D 04 04    sta $0404,x
@DB07:
    DB07: 8A          txa
    DB08: 18          clc
    DB09: 69 10       adc #$10
    DB0B: AA          tax
    DB0C: E0 90       cpx #$90
    DB0E: D0 E4       bne @DAF4   ; $DAF4
    DB10: 60          rts
@DB11:
    DB11: A9 20       lda #$20
    DB13: A0 04       ldy #$04
    DB15: 91 1E       sta (obj_record_ptr),y   ; $1E
    DB17: A9 22       lda #$22
    DB19: A0 0F       ldy #$0f
    DB1B: 91 1E       sta (obj_record_ptr),y   ; $1E
    DB1D: A0 05       ldy #$05
    DB1F: B1 1E       lda (obj_record_ptr),y   ; $1E
    DB21: AA          tax
    DB22: A9 78       lda #$78
    DB24: E0 03       cpx #$03
    DB26: D0 02       bne @DB2A   ; $DB2A
    DB28: A5 65       lda active_object_count   ; $65
@DB2A:
    DB2A: A0 07       ldy #$07
    DB2C: 91 1E       sta (obj_record_ptr),y   ; $1E
    DB2E: BC 33 DB    ldy $db33,x
    DB31: 4C CA D4    jmp add_score_from_table   ; $D4CA
    DB34: 44          .byte $44
    DB35: 44          .byte $44
    DB36: 08          .byte $08

state22_knocked_out:
    DB37: A0 07       ldy #$07
    DB39: B1 1E       lda (obj_record_ptr),y   ; $1E
    DB3B: 38          sec
    DB3C: E9 01       sbc #$01
    DB3E: 91 1E       sta (obj_record_ptr),y   ; $1E
    DB40: D0 12       bne @DB54   ; $DB54
    DB42: 4C 17 DD    jmp land_on_floor   ; $DD17

state08_player_caught:
    DB45: EE 07 04    inc $0407
    DB48: AD 07 04    lda $0407
    DB4B: C9 20       cmp #$20
    DB4D: 90 05       bcc @DB54   ; $DB54
    DB4F: A9 2A       lda #$2a
    DB51: 8D 0F 04    sta $040f
@DB54:
    DB54: 60          rts

state2A_wait_then_start_tune:
    DB55: AD A5 04    lda obj_state   ; $04A5
    DB58: 0D AD 04    ora $04ad
    DB5B: D0 1D       bne @DB7A   ; $DB7A
    DB5D: 20 BF F4    jsr init_sound_voices   ; $F4BF
    DB60: A9 01       lda #$01
    DB62: 8D 0B 06    sta $060b
    DB65: 8D 0C 06    sta $060c
    DB68: 8D 0D 06    sta $060d
    DB6B: A9 16       lda #$16
    DB6D: 8D 04 04    sta $0404
    DB70: A9 00       lda #$00
    DB72: 8D 07 04    sta $0407
    DB75: A9 2C       lda #$2c
    DB77: 8D 0F 04    sta $040f
@DB7A:
    DB7A: 60          rts

state2C_wait_tune:
    DB7B: EE 07 04    inc $0407
    DB7E: 10 FA       bpl @DB7A   ; $DB7A
    DB80: 4C 6F DE    jmp clear_object   ; $DE6F

enter_fall:
    DB83: A9 00       lda #$00
    DB85: A0 08       ldy #$08
    DB87: 91 1E       sta (obj_record_ptr),y   ; $1E
    DB89: A9 06       lda #$06
    DB8B: A0 0F       ldy #$0f
    DB8D: 91 1E       sta (obj_record_ptr),y   ; $1E
    DB8F: A0 04       ldy #$04
    DB91: 91 1E       sta (obj_record_ptr),y   ; $1E
@DB93:
    DB93: 60          rts

state06_fall:
    DB94: 20 02 E1    jsr slot1_touches_player   ; $E102
    DB97: F0 0B       beq @DBA4   ; $DBA4
    DB99: A0 08       ldy #$08
    DB9B: B1 1E       lda (obj_record_ptr),y   ; $1E
    DB9D: 38          sec
    DB9E: E9 49       sbc #$49
    DBA0: C9 07       cmp #$07
    DBA2: B0 03       bcs @DBA7   ; $DBA7
@DBA4:
    DBA4: 4C D8 DA    jmp catch_player_or_knock_out   ; $DAD8
@DBA7:
    DBA7: A0 03       ldy #$03
    DBA9: B1 1E       lda (obj_record_ptr),y   ; $1E
    DBAB: C9 1C       cmp #$1c
    DBAD: 90 03       bcc @DBB2   ; $DBB2
    DBAF: 4C D8 DA    jmp catch_player_or_knock_out   ; $DAD8
@DBB2:
    DBB2: 20 6A E0    jsr fall_step   ; $E06A
    DBB5: 20 69 E4    jsr find_trampoline_below   ; $E469
    DBB8: B0 D9       bcs @DB93   ; $DB93

land_on_trampoline:
    DBBA: A0 05       ldy #$05
    DBBC: B1 1E       lda (obj_record_ptr),y   ; $1E
    DBBE: D0 23       bne @DBE3   ; $DBE3
    DBC0: 86 18       stx scratch_loop_counter   ; $18
    DBC2: A5 42       lda game_phase   ; $42
    DBC4: 8D 0A 06    sta $060a
    DBC7: A0 3C       ldy #$3c
    DBC9: 20 CA D4    jsr add_score_from_table   ; $D4CA
    DBCC: A6 18       ldx scratch_loop_counter   ; $18
    DBCE: BD 02 02    lda obj_timer,x   ; $0202
    DBD1: D0 10       bne @DBE3   ; $DBE3
    DBD3: A9 01       lda #$01
    DBD5: 9D 00 02    sta obj_timer,x   ; $0200
    DBD8: A9 09       lda #$09
    DBDA: 9D 01 02    sta obj_anim_timer,x   ; $0201
    DBDD: A9 80       lda #$80
    DBDF: 9D 02 02    sta obj_timer,x   ; $0202
    DBE2: 60          rts
@DBE3:
    DBE3: A0 01       ldy #$01
    DBE5: BD 01 02    lda obj_anim_timer,x   ; $0201
    DBE8: C9 08       cmp #$08
    DBEA: 90 01       bcc @DBED   ; $DBED
    DBEC: C8          iny
@DBED:
    DBED: 98          tya
    DBEE: 9D 00 02    sta obj_timer,x   ; $0200
    DBF1: 8A          txa
    DBF2: A0 0B       ldy #$0b
    DBF4: 91 1E       sta (obj_record_ptr),y   ; $1E
    DBF6: A9 00       lda #$00
    DBF8: A0 07       ldy #$07
    DBFA: 91 1E       sta (obj_record_ptr),y   ; $1E
    DBFC: A9 0A       lda #$0a
    DBFE: A0 0F       ldy #$0f
    DC00: 91 1E       sta (obj_record_ptr),y   ; $1E

state0A_trampoline_bounce:
    DC02: A0 0B       ldy #$0b
    DC04: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC06: AA          tax
    DC07: 20 A4 E4    jsr trampoline_bounce_step   ; $E4A4
    DC0A: BD 02 02    lda obj_timer,x   ; $0202
    DC0D: 10 03       bpl @DC12   ; $DC12
    DC0F: 4C 83 DB    jmp enter_fall   ; $DB83
@DC12:
    DC12: BD 01 02    lda obj_anim_timer,x   ; $0201
    DC15: C9 07       cmp #$07
    DC17: D0 3F       bne @DC58   ; $DC58
    DC19: A0 05       ldy #$05
    DC1B: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC1D: D0 03       bne @DC22   ; $DC22
    DC1F: DE 02 02    dec obj_timer,x   ; $0202
@DC22:
    DC22: A9 00       lda #$00
    DC24: A0 08       ldy #$08
    DC26: 91 1E       sta (obj_record_ptr),y   ; $1E
    DC28: A9 0C       lda #$0c
    DC2A: A0 0F       ldy #$0f
    DC2C: 91 1E       sta (obj_record_ptr),y   ; $1E
    DC2E: A9 06       lda #$06
    DC30: A0 04       ldy #$04
    DC32: 91 1E       sta (obj_record_ptr),y   ; $1E
    DC34: A5 1E       lda obj_record_ptr   ; $1E
    DC36: C9 20       cmp #$20
    DC38: F0 1F       beq @DC59   ; $DC59
    DC3A: A0 0A       ldy #$0a
    DC3C: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC3E: 29 FC       and #$fc
    DC40: 09 01       ora #$01
    DC42: A0 03       ldy #$03
    DC44: D1 1E       cmp (obj_record_ptr),y   ; $1E
    DC46: 90 10       bcc @DC58   ; $DC58
    DC48: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC4A: 29 FC       and #$fc
    DC4C: 85 10       sta src_ptr   ; $10
    DC4E: A0 0A       ldy #$0a
    DC50: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC52: 29 01       and #$01
    DC54: 05 10       ora src_ptr   ; $10
    DC56: 91 1E       sta (obj_record_ptr),y   ; $1E
@DC58:
    DC58: 60          rts
@DC59:
    DC59: 4C F0 D9    jmp slot2_maybe_step_target_floor   ; $D9F0

state0C_rise:
    DC5C: 20 02 E1    jsr slot1_touches_player   ; $E102
    DC5F: D0 03       bne @DC64   ; $DC64
    DC61: 4C D8 DA    jmp catch_player_or_knock_out   ; $DAD8
@DC64:
    DC64: A0 03       ldy #$03
    DC66: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC68: 29 03       and #$03
    DC6A: 38          sec
    DC6B: E9 01       sbc #$01
    DC6D: C9 02       cmp #$02
    DC6F: B0 06       bcs @DC77   ; $DC77
    DC71: A0 0D       ldy #$0d
    DC73: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC75: D0 56       bne @DCCD   ; $DCCD
@DC77:
    DC77: A0 08       ldy #$08
    DC79: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC7B: C9 59       cmp #$59
    DC7D: F0 12       beq @DC91   ; $DC91
    DC7F: 38          sec
    DC80: E9 30       sbc #$30
    DC82: C9 20       cmp #$20
    DC84: 90 0B       bcc @DC91   ; $DC91
    DC86: A0 03       ldy #$03
    DC88: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC8A: C9 06       cmp #$06
    DC8C: 90 03       bcc @DC91   ; $DC91
    DC8E: 4C 84 E0    jmp rise_step   ; $E084
@DC91:
    DC91: A0 03       ldy #$03
    DC93: B1 1E       lda (obj_record_ptr),y   ; $1E
    DC95: 29 FC       and #$fc
    DC97: 85 10       sta src_ptr   ; $10
    DC99: A5 1E       lda obj_record_ptr   ; $1E
    DC9B: C9 20       cmp #$20
    DC9D: F0 1E       beq @DCBD   ; $DCBD
    DC9F: A0 0A       ldy #$0a
    DCA1: B1 1E       lda (obj_record_ptr),y   ; $1E
    DCA3: 29 FC       and #$fc
    DCA5: C5 10       cmp src_ptr   ; $10
    DCA7: F0 0B       beq @DCB4   ; $DCB4
    DCA9: B1 1E       lda (obj_record_ptr),y   ; $1E
    DCAB: 29 03       and #$03
    DCAD: 05 10       ora src_ptr   ; $10
    DCAF: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCB1: 4C 83 DB    jmp enter_fall   ; $DB83
@DCB4:
    DCB4: B1 1E       lda (obj_record_ptr),y   ; $1E
    DCB6: 49 01       eor #$01
    DCB8: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCBA: 4C 83 DB    jmp enter_fall   ; $DB83
@DCBD:
    DCBD: A5 10       lda src_ptr   ; $10
    DCBF: 09 01       ora #$01
    DCC1: 38          sec
    DCC2: E5 37       sbc obj_record_ptr_hi   ; $37
    DCC4: 85 36       sta obj_record_ptr   ; $36
    DCC6: A9 01       lda #$01
    DCC8: 85 35       sta obj_collision_state   ; $35
    DCCA: 4C 83 DB    jmp enter_fall   ; $DB83
@DCCD:
    DCCD: A0 06       ldy #$06
    DCCF: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCD1: A0 03       ldy #$03
    DCD3: B1 1E       lda (obj_record_ptr),y   ; $1E
    DCD5: 29 FE       and #$fe
    DCD7: 09 02       ora #$02
    DCD9: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCDB: 88          dey
    DCDC: A9 00       lda #$00
    DCDE: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCE0: A9 10       lda #$10
    DCE2: A0 07       ldy #$07
    DCE4: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCE6: A9 E0       lda #$e0
    DCE8: A0 0B       ldy #$0b
    DCEA: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCEC: A9 04       lda #$04
    DCEE: C8          iny
    DCEF: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCF1: A9 0E       lda #$0e
    DCF3: A0 0F       ldy #$0f
    DCF5: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCF7: A9 04       lda #$04
    DCF9: A0 04       ldy #$04
    DCFB: 91 1E       sta (obj_record_ptr),y   ; $1E
    DCFD: 60          rts

state0E_step_onto_floor:
    DCFE: A0 08       ldy #$08
    DD00: B1 1E       lda (obj_record_ptr),y   ; $1E
    DD02: 38          sec
    DD03: E9 49       sbc #$49
    DD05: C9 10       cmp #$10
    DD07: 90 37       bcc @DD40   ; $DD40
    DD09: A0 07       ldy #$07
    DD0B: B1 1E       lda (obj_record_ptr),y   ; $1E
    DD0D: 38          sec
    DD0E: E9 01       sbc #$01
    DD10: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD12: F0 03       beq land_on_floor   ; $DD17
    DD14: 4C 3D E0    jmp move_hop_arc   ; $E03D

land_on_floor:
    DD17: A9 00       lda #$00
    DD19: A0 02       ldy #$02
    DD1B: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD1D: C8          iny
    DD1E: B1 1E       lda (obj_record_ptr),y   ; $1E
    DD20: 29 FC       and #$fc
    DD22: 09 02       ora #$02
    DD24: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD26: A9 4B       lda #$4b
    DD28: A0 08       ldy #$08
    DD2A: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD2C: A0 05       ldy #$05
    DD2E: B1 1E       lda (obj_record_ptr),y   ; $1E
    DD30: D0 03       bne @DD35   ; $DD35
    DD32: 20 DE E3    jsr restore_trampolines   ; $E3DE
@DD35:
    DD35: A9 02       lda #$02
    DD37: A0 0F       ldy #$0f
    DD39: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD3B: A0 04       ldy #$04
    DD3D: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD3F: 60          rts
@DD40:
    DD40: A5 1E       lda obj_record_ptr   ; $1E
    DD42: C9 20       cmp #$20
    DD44: F0 06       beq @DD4C   ; $DD4C
    DD46: 20 A6 DE    jsr choose_cat_target_floor   ; $DEA6
    DD49: 4C 4F DD    jmp bounce_back_into_shaft   ; $DD4F
@DD4C:
    DD4C: 20 02 DA    jsr slot2_step_target_floor   ; $DA02

bounce_back_into_shaft:
    DD4F: A9 00       lda #$00
    DD51: 38          sec
    DD52: A0 06       ldy #$06
    DD54: F1 1E       sbc (obj_record_ptr),y   ; $1E
    DD56: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD58: A9 06       lda #$06
    DD5A: C8          iny
    DD5B: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD5D: A9 00       lda #$00
    DD5F: 4C B3 DA    jmp start_hop   ; $DAB3

state10_door_knockback:
    DD62: 20 B1 F0    jsr press_floor_traps   ; $F0B1
    DD65: 20 E7 F0    jsr walker_over_open_trap   ; $F0E7
    DD68: F0 38       beq @DDA2   ; $DDA2
    DD6A: A0 08       ldy #$08
    DD6C: B1 1E       lda (obj_record_ptr),y   ; $1E
    DD6E: 38          sec
    DD6F: E9 49       sbc #$49
    DD71: C9 09       cmp #$09
    DD73: B0 30       bcs @DDA5   ; $DDA5
    DD75: A5 1E       lda obj_record_ptr   ; $1E
    DD77: D0 03       bne @DD7C   ; $DD7C
    DD79: 20 34 E1    jsr player_knockback_pushes_cats   ; $E134
@DD7C:
    DD7C: A9 80       lda #$80
    DD7E: 20 09 DF    jsr move_x_turn_at_walls_offset4   ; $DF09
    DD81: A0 07       ldy #$07
    DD83: B1 1E       lda (obj_record_ptr),y   ; $1E
    DD85: 38          sec
    DD86: E9 01       sbc #$01
    DD88: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD8A: D0 15       bne @DDA1   ; $DDA1
    DD8C: A0 05       ldy #$05
    DD8E: B1 1E       lda (obj_record_ptr),y   ; $1E
    DD90: D0 03       bne @DD95   ; $DD95
    DD92: 4C 17 DD    jmp land_on_floor   ; $DD17
@DD95:
    DD95: A5 65       lda active_object_count   ; $65
    DD97: A0 07       ldy #$07
    DD99: 91 1E       sta (obj_record_ptr),y   ; $1E
    DD9B: A9 12       lda #$12
    DD9D: A0 0F       ldy #$0f
    DD9F: 91 1E       sta (obj_record_ptr),y   ; $1E
@DDA1:
    DDA1: 60          rts
@DDA2:
    DDA2: 4C 83 DB    jmp enter_fall   ; $DB83
@DDA5:
    DDA5: 4C A2 DA    jmp start_hop_off_ledge   ; $DAA2

state12_stunned:
    DDA8: A0 07       ldy #$07
    DDAA: B1 1E       lda (obj_record_ptr),y   ; $1E
    DDAC: 38          sec
    DDAD: E9 01       sbc #$01
    DDAF: 91 1E       sta (obj_record_ptr),y   ; $1E
    DDB1: D0 EE       bne @DDA1   ; $DDA1
    DDB3: A9 40       lda #$40
    DDB5: A0 07       ldy #$07
    DDB7: 91 1E       sta (obj_record_ptr),y   ; $1E
    DDB9: A9 0E       lda #$0e
    DDBB: A0 04       ldy #$04
    DDBD: 91 1E       sta (obj_record_ptr),y   ; $1E
    DDBF: A9 14       lda #$14
    DDC1: A0 0F       ldy #$0f
    DDC3: 91 1E       sta (obj_record_ptr),y   ; $1E
@DDC5:
    DDC5: 60          rts

state14_recover:
    DDC6: A0 07       ldy #$07
    DDC8: B1 1E       lda (obj_record_ptr),y   ; $1E
    DDCA: 38          sec
    DDCB: E9 01       sbc #$01
    DDCD: 91 1E       sta (obj_record_ptr),y   ; $1E
    DDCF: D0 F4       bne @DDC5   ; $DDC5
    DDD1: 4C 17 DD    jmp land_on_floor   ; $DD17

state1A_respawn_wait:
    DDD4: A0 07       ldy #$07
    DDD6: B1 1E       lda (obj_record_ptr),y   ; $1E
    DDD8: F0 05       beq @DDDF   ; $DDDF
    DDDA: 38          sec
    DDDB: E9 01       sbc #$01
    DDDD: 91 1E       sta (obj_record_ptr),y   ; $1E
@DDDF:
    DDDF: 60          rts

state1C_respawn_drop:
    DDE0: A5 4B       lda player_down   ; $4B
    DDE2: 05 4F       ora round_cleared   ; $4F
    DDE4: D0 3E       bne @DE24   ; $DE24
    DDE6: A0 08       ldy #$08
    DDE8: B1 1E       lda (obj_record_ptr),y   ; $1E
    DDEA: 38          sec
    DDEB: E9 49       sbc #$49
    DDED: C9 07       cmp #$07
    DDEF: 90 16       bcc @DE07   ; $DE07
    DDF1: A0 03       ldy #$03
    DDF3: B1 1E       lda (obj_record_ptr),y   ; $1E
    DDF5: C9 1C       cmp #$1c
    DDF7: B0 0B       bcs @DE04   ; $DE04
    DDF9: 20 6A E0    jsr fall_step   ; $E06A
    DDFC: 20 69 E4    jsr find_trampoline_below   ; $E469
    DDFF: B0 23       bcs @DE24   ; $DE24
    DE01: 4C BA DB    jmp land_on_trampoline   ; $DBBA
@DE04:
    DE04: 4C D8 DA    jmp catch_player_or_knock_out   ; $DAD8
@DE07:
    DE07: A5 1E       lda obj_record_ptr   ; $1E
    DE09: C9 20       cmp #$20
    DE0B: D0 1D       bne @DE2A   ; $DE2A
    DE0D: A9 24       lda #$24
    DE0F: 8D 2F 04    sta stage_phase_state   ; $042F
    DE12: A9 12       lda #$12
    DE14: 8D 24 04    sta obj_state   ; $0424
    DE17: A9 78       lda #$78
    DE19: 8D 27 04    sta bonus_item_timer   ; $0427
    DE1C: A9 09       lda #$09
    DE1E: 85 36       sta obj_record_ptr   ; $36
    DE20: A9 04       lda #$04
    DE22: 85 37       sta obj_record_ptr_hi   ; $37
@DE24:
    DE24: 60          rts

state24_slot2_landing_pause:
    DE25: CE 27 04    dec bonus_item_timer   ; $0427
    DE28: D0 FA       bne @DE24   ; $DE24
@DE2A:
    DE2A: 4C 17 DD    jmp land_on_floor   ; $DD17

state1E_slot2_on_item:
    DE2D: CE 27 04    dec bonus_item_timer   ; $0427
    DE30: F0 27       beq @DE59   ; $DE59
    DE32: AD 23 04    lda obj_state   ; $0423
    DE35: CD 03 04    cmp $0403
    DE38: D0 3F       bne @DE79   ; $DE79
    DE3A: AD 21 04    lda target_compare_value   ; $0421
    DE3D: 38          sec
    DE3E: ED 01 04    sbc $0401
    DE41: C9 02       cmp #$02
    DE43: B0 34       bcs @DE79   ; $DE79
    DE45: A9 20       lda #$20
    DE47: 8D 2F 04    sta stage_phase_state   ; $042F
    DE4A: A9 15       lda #$15
    DE4C: 8D 24 04    sta obj_state   ; $0424
    DE4F: A9 78       lda #$78
    DE51: 8D 27 04    sta bonus_item_timer   ; $0427
    DE54: A0 44       ldy #$44
    DE56: 4C CA D4    jmp add_score_from_table   ; $D4CA
@DE59:
    DE59: A9 10       lda #$10
    DE5B: 8D 2A 04    sta bonus_item_timer   ; $042A
    DE5E: 4C 17 DD    jmp land_on_floor   ; $DD17

state20_slot2_scored:
    DE61: CE 27 04    dec bonus_item_timer   ; $0427
    DE64: D0 13       bne @DE79   ; $DE79
    DE66: A5 4B       lda player_down   ; $4B
    DE68: 05 4F       ora round_cleared   ; $4F
    DE6A: D0 03       bne clear_object   ; $DE6F
    DE6C: 4C 17 DD    jmp land_on_floor   ; $DD17

clear_object:
    DE6F: A9 00       lda #$00
    DE71: A0 0F       ldy #$0f
    DE73: 91 1E       sta (obj_record_ptr),y   ; $1E
    DE75: A0 04       ldy #$04
    DE77: 91 1E       sta (obj_record_ptr),y   ; $1E
@DE79:
    DE79: 60          rts

state26_stunned_by_drop:
    DE7A: A0 07       ldy #$07
    DE7C: B1 1E       lda (obj_record_ptr),y   ; $1E
    DE7E: 38          sec
    DE7F: E9 01       sbc #$01
    DE81: 91 1E       sta (obj_record_ptr),y   ; $1E
    DE83: D0 12       bne @DE97   ; $DE97
    DE85: A9 28       lda #$28
    DE87: A0 0F       ldy #$0f
    DE89: 91 1E       sta (obj_record_ptr),y   ; $1E
    DE8B: A9 24       lda #$24
    DE8D: A0 04       ldy #$04
    DE8F: 91 1E       sta (obj_record_ptr),y   ; $1E
    DE91: A9 40       lda #$40
    DE93: A0 07       ldy #$07
    DE95: 91 1E       sta (obj_record_ptr),y   ; $1E
@DE97:
    DE97: 60          rts

state28_drop_stun_recover:
    DE98: A0 07       ldy #$07
    DE9A: B1 1E       lda (obj_record_ptr),y   ; $1E
    DE9C: 38          sec
    DE9D: E9 01       sbc #$01
    DE9F: 91 1E       sta (obj_record_ptr),y   ; $1E
    DEA1: D0 F4       bne @DE97   ; $DE97
    DEA3: 4C 83 DB    jmp enter_fall   ; $DB83

choose_cat_target_floor:
    DEA6: A0 06       ldy #$06
    DEA8: B1 1E       lda (obj_record_ptr),y   ; $1E
    DEAA: 29 01       and #$01
    DEAC: 49 01       eor #$01
    DEAE: 85 10       sta src_ptr   ; $10
    DEB0: A0 03       ldy #$03
    DEB2: B1 1E       lda (obj_record_ptr),y   ; $1E
    DEB4: 29 FC       and #$fc
    DEB6: 05 10       ora src_ptr   ; $10
    DEB8: 85 10       sta src_ptr   ; $10
    DEBA: A0 01       ldy #$01
    DEBC: B1 1E       lda (obj_record_ptr),y   ; $1E
    DEBE: CD 01 04    cmp $0401
    DEC1: AD 03 04    lda $0403
    DEC4: 29 FC       and #$fc
    DEC6: 69 00       adc #$00
    DEC8: A0 0A       ldy #$0a
    DECA: 91 1E       sta (obj_record_ptr),y   ; $1E
    DECC: C5 10       cmp src_ptr   ; $10
    DECE: D0 11       bne @DEE1   ; $DEE1
    DED0: A6 21       ldx frame_counter   ; $21
    DED2: BD 00 C0    lda $c000,x
    DED5: 4A          lsr a
    DED6: A9 04       lda #$04
    DED8: 90 02       bcc @DEDC   ; $DEDC
    DEDA: A9 FC       lda #$fc
@DEDC:
    DEDC: 18          clc
    DEDD: 71 1E       adc (obj_record_ptr),y   ; $1E
    DEDF: 91 1E       sta (obj_record_ptr),y   ; $1E
@DEE1:
    DEE1: 60          rts
@DEE2:
    DEE2: A9 00       lda #$00
    DEE4: A0 07       ldy #$07
    DEE6: 91 1E       sta (obj_record_ptr),y   ; $1E
@DEE8:
    DEE8: 60          rts

walk_step:
    DEE9: A5 1E       lda obj_record_ptr   ; $1E
    DEEB: D0 0A       bne @DEF7   ; $DEF7
    DEED: A0 0D       ldy #$0d
    DEEF: B1 1E       lda (obj_record_ptr),y   ; $1E
    DEF1: F0 EF       beq @DEE2   ; $DEE2
    DEF3: A0 06       ldy #$06
    DEF5: 91 1E       sta (obj_record_ptr),y   ; $1E
@DEF7:
    DEF7: A0 07       ldy #$07
    DEF9: B1 1E       lda (obj_record_ptr),y   ; $1E
    DEFB: 18          clc
    DEFC: 69 01       adc #$01
    DEFE: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF00: A0 09       ldy #$09
    DF02: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF04: D0 E2       bne @DEE8   ; $DEE8
    DF06: 20 18 E0    jsr object_speed   ; $E018

move_x_turn_at_walls_offset4:
    DF09: A2 04       ldx #$04

move_x_turn_at_walls:
    DF0B: 85 10       sta src_ptr   ; $10
    DF0D: 20 8A DF    jsr scroll_camera_with_player   ; $DF8A
    DF10: A0 06       ldy #$06
    DF12: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF14: 30 3D       bmi @DF53   ; $DF53
    DF16: A0 01       ldy #$01
    DF18: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF1A: C9 38       cmp #$38
    DF1C: F0 18       beq @DF36   ; $DF36
    DF1E: 88          dey
    DF1F: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF21: 18          clc
    DF22: 65 10       adc src_ptr   ; $10
    DF24: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF26: 90 2A       bcc @DF52   ; $DF52
    DF28: C8          iny
    DF29: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF2B: 69 00       adc #$00
    DF2D: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF2F: C9 38       cmp #$38
    DF31: B0 03       bcs @DF36   ; $DF36
    DF33: 4C CD DF    jmp queue_tile_read   ; $DFCD
@DF36:
    DF36: 88          dey
    DF37: A9 00       lda #$00
    DF39: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF3B: A9 4D       lda #$4d
    DF3D: A0 08       ldy #$08
    DF3F: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF41: A5 1E       lda obj_record_ptr   ; $1E
    DF43: F0 0D       beq @DF52   ; $DF52
    DF45: C9 20       cmp #$20
    DF47: D0 03       bne @DF4C   ; $DF4C
    DF49: 20 F0 D9    jsr slot2_maybe_step_target_floor   ; $D9F0
@DF4C:
    DF4C: A9 FF       lda #$ff
    DF4E: A0 06       ldy #$06
    DF50: 91 1E       sta (obj_record_ptr),y   ; $1E
@DF52:
    DF52: 60          rts
@DF53:
    DF53: A0 00       ldy #$00
    DF55: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF57: 38          sec
    DF58: E5 10       sbc src_ptr   ; $10
    DF5A: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF5C: B0 2B       bcs @DF89   ; $DF89
    DF5E: C8          iny
    DF5F: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF61: E9 00       sbc #$00
    DF63: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF65: C9 02       cmp #$02
    DF67: B0 60       bcs @DFC9   ; $DFC9
    DF69: A9 02       lda #$02
    DF6B: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF6D: 88          dey
    DF6E: A9 00       lda #$00
    DF70: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF72: A9 4C       lda #$4c
    DF74: A0 08       ldy #$08
    DF76: 91 1E       sta (obj_record_ptr),y   ; $1E
    DF78: A5 1E       lda obj_record_ptr   ; $1E
    DF7A: F0 0D       beq @DF89   ; $DF89
    DF7C: C9 20       cmp #$20
    DF7E: D0 03       bne @DF83   ; $DF83
    DF80: 20 F0 D9    jsr slot2_maybe_step_target_floor   ; $D9F0
@DF83:
    DF83: A9 01       lda #$01
    DF85: A0 06       ldy #$06
    DF87: 91 1E       sta (obj_record_ptr),y   ; $1E
@DF89:
    DF89: 60          rts

scroll_camera_with_player:
    DF8A: A0 05       ldy #$05
    DF8C: B1 1E       lda (obj_record_ptr),y   ; $1E
    DF8E: D0 24       bne @DFB4   ; $DFB4
    DF90: AD 01 04    lda $0401
    DF93: 38          sec
    DF94: E9 0F       sbc #$0f
    DF96: C9 1C       cmp #$1c
    DF98: B0 1A       bcs @DFB4   ; $DFB4
    DF9A: AD 06 04    lda $0406
    DF9D: 30 16       bmi @DFB5   ; $DFB5
    DF9F: A5 28       lda camera_x_lo   ; $28
    DFA1: 18          clc
    DFA2: 65 10       adc src_ptr   ; $10
    DFA4: 85 11       sta zp_ptr_hi   ; $11
    DFA6: A5 29       lda camera_x   ; $29
    DFA8: 69 00       adc #$00
    DFAA: C9 1C       cmp #$1c
    DFAC: B0 06       bcs @DFB4   ; $DFB4
    DFAE: 85 29       sta camera_x   ; $29
    DFB0: A5 11       lda zp_ptr_hi   ; $11
    DFB2: 85 28       sta camera_x_lo   ; $28
@DFB4:
    DFB4: 60          rts
@DFB5:
    DFB5: A5 28       lda camera_x_lo   ; $28
    DFB7: 38          sec
    DFB8: E5 10       sbc src_ptr   ; $10
    DFBA: 85 11       sta zp_ptr_hi   ; $11
    DFBC: A5 29       lda camera_x   ; $29
    DFBE: E9 00       sbc #$00
    DFC0: 90 06       bcc @DFC8   ; $DFC8
    DFC2: 85 29       sta camera_x   ; $29
    DFC4: A5 11       lda zp_ptr_hi   ; $11
    DFC6: 85 28       sta camera_x_lo   ; $28
@DFC8:
    DFC8: 60          rts
@DFC9:
    DFC9: 8A          txa
    DFCA: 09 04       ora #$04
    DFCC: AA          tax

queue_tile_read:
    DFCD: A0 01       ldy #$01
    DFCF: B1 1E       lda (obj_record_ptr),y   ; $1E
    DFD1: 18          clc
    DFD2: 7D 10 E0    adc $e010,x
    DFD5: 0A          asl a
    DFD6: 0A          asl a
    DFD7: 0A          asl a
    DFD8: 85 10       sta src_ptr   ; $10
    DFDA: A0 03       ldy #$03
    DFDC: B1 1E       lda (obj_record_ptr),y   ; $1E
    DFDE: 90 02       bcc @DFE2   ; $DFE2
    DFE0: 09 20       ora #$20
@DFE2:
    DFE2: 18          clc
    DFE3: 7D 11 E0    adc $e011,x
    DFE6: 4A          lsr a
    DFE7: 66 10       ror src_ptr   ; $10
    DFE9: 4A          lsr a
    DFEA: 66 10       ror src_ptr   ; $10
    DFEC: 4A          lsr a
    DFED: 66 10       ror src_ptr   ; $10
    DFEF: 09 20       ora #$20
    DFF1: 85 11       sta zp_ptr_hi   ; $11
    DFF3: A6 2B       ldx vram_queue_cursor   ; $2B
    DFF5: A5 10       lda src_ptr   ; $10
    DFF7: 9D C0 04    sta $04c0,x
    DFFA: E8          inx
    DFFB: A5 11       lda zp_ptr_hi   ; $11
    DFFD: 9D C0 04    sta $04c0,x
    E000: E8          inx
    E001: A5 1E       lda obj_record_ptr   ; $1E
    E003: 9D C0 04    sta $04c0,x
    E006: E8          inx
    E007: A5 1F       lda obj_record_ptr_hi   ; $1F
    E009: 9D C0 04    sta $04c0,x
    E00C: E8          inx
    E00D: 86 2B       stx vram_queue_cursor   ; $2B
    E00F: 60          rts
    E010: 01          .byte $01
    E011: 00          .byte $00
    E012: 02          .byte $02
    E013: 01          .byte $01
    E014: 01          .byte $01
    E015: 02          .byte $02
    E016: 00          .byte $00
    E017: 01          .byte $01

object_speed:
    E018: A0 00       ldy #$00
    E01A: A5 60       lda sequence_state   ; $60
    E01C: F0 02       beq @E020   ; $E020
    E01E: A0 04       ldy #$04
@E020:
    E020: 84 10       sty src_ptr   ; $10
    E022: A0 05       ldy #$05
    E024: B1 1E       lda (obj_record_ptr),y   ; $1E
    E026: F0 0A       beq @E032   ; $E032
    E028: C9 03       cmp #$03
    E02A: 90 09       bcc @E035   ; $E035
    E02C: A5 64       lda data_ptr_hi   ; $64
    E02E: 18          clc
    E02F: 65 10       adc src_ptr   ; $10
    E031: 60          rts
@E032:
    E032: A5 63       lda record_ptr   ; $63
    E034: 60          rts
@E035:
    E035: A5 64       lda data_ptr_hi   ; $64
    E037: 18          clc
    E038: 69 04       adc #$04
    E03A: 65 10       adc src_ptr   ; $10
    E03C: 60          rts

move_hop_arc:
    E03D: A0 0C       ldy #$0c
    E03F: B1 1E       lda (obj_record_ptr),y   ; $1E
    E041: 88          dey
    E042: 18          clc
    E043: 71 1E       adc (obj_record_ptr),y   ; $1E
    E045: 91 1E       sta (obj_record_ptr),y   ; $1E
    E047: 0A          asl a
    E048: 90 0B       bcc @E055   ; $E055
    E04A: 48          pha
    E04B: A0 03       ldy #$03
    E04D: B1 1E       lda (obj_record_ptr),y   ; $1E
    E04F: 38          sec
    E050: E9 01       sbc #$01
    E052: 91 1E       sta (obj_record_ptr),y   ; $1E
    E054: 68          pla
@E055:
    E055: A0 02       ldy #$02
    E057: 18          clc
    E058: 71 1E       adc (obj_record_ptr),y   ; $1E
    E05A: 91 1E       sta (obj_record_ptr),y   ; $1E
    E05C: C8          iny
    E05D: B1 1E       lda (obj_record_ptr),y   ; $1E
    E05F: 69 00       adc #$00
    E061: 91 1E       sta (obj_record_ptr),y   ; $1E
    E063: A9 30       lda #$30
    E065: A2 02       ldx #$02
    E067: 4C 0B DF    jmp move_x_turn_at_walls   ; $DF0B

fall_step:
    E06A: 20 18 E0    jsr object_speed   ; $E018
    E06D: 18          clc
    E06E: 69 20       adc #$20
    E070: A0 02       ldy #$02
    E072: 71 1E       adc (obj_record_ptr),y   ; $1E
    E074: 91 1E       sta (obj_record_ptr),y   ; $1E
    E076: 90 2B       bcc @E0A3   ; $E0A3
    E078: C8          iny
    E079: B1 1E       lda (obj_record_ptr),y   ; $1E
    E07B: 69 00       adc #$00
    E07D: 91 1E       sta (obj_record_ptr),y   ; $1E
    E07F: A2 04       ldx #$04
    E081: 4C A0 E0    jmp queue_tile_read_then_tick   ; $E0A0

rise_step:
    E084: 20 18 E0    jsr object_speed   ; $E018
    E087: 18          clc
    E088: 69 20       adc #$20

move_up_by_a:
    E08A: 85 10       sta src_ptr   ; $10
    E08C: A0 02       ldy #$02
    E08E: B1 1E       lda (obj_record_ptr),y   ; $1E
    E090: 38          sec
    E091: E5 10       sbc src_ptr   ; $10
    E093: 91 1E       sta (obj_record_ptr),y   ; $1E
    E095: B0 0C       bcs @E0A3   ; $E0A3
    E097: C8          iny
    E098: B1 1E       lda (obj_record_ptr),y   ; $1E
    E09A: E9 00       sbc #$00
    E09C: 91 1E       sta (obj_record_ptr),y   ; $1E
    E09E: A2 00       ldx #$00

queue_tile_read_then_tick:
    E0A0: 20 CD DF    jsr queue_tile_read   ; $DFCD
@E0A3:
    E0A3: A0 0D       ldy #$0d
    E0A5: B1 1E       lda (obj_record_ptr),y   ; $1E
    E0A7: F0 04       beq @E0AD   ; $E0AD
    E0A9: A0 06       ldy #$06
    E0AB: 91 1E       sta (obj_record_ptr),y   ; $1E
@E0AD:
    E0AD: A0 07       ldy #$07
    E0AF: B1 1E       lda (obj_record_ptr),y   ; $1E
    E0B1: 18          clc
    E0B2: 69 01       adc #$01
    E0B4: 91 1E       sta (obj_record_ptr),y   ; $1E
    E0B6: 60          rts

walking_cat_touches_player:
    E0B7: A5 1E       lda obj_record_ptr   ; $1E
    E0B9: D0 44       bne @E0FF   ; $E0FF
    E0BB: A5 2E       lda $2e
    E0BD: D0 40       bne @E0FF   ; $E0FF
    E0BF: A2 10       ldx #$10
@E0C1:
    E0C1: BD 0F 04    lda $040f,x
    E0C4: C9 02       cmp #$02
    E0C6: D0 2E       bne @E0F6   ; $E0F6
    E0C8: E0 20       cpx #$20
    E0CA: D0 05       bne @E0D1   ; $E0D1
    E0CC: AD 2A 04    lda bonus_item_timer   ; $042A
    E0CF: D0 25       bne @E0F6   ; $E0F6
@E0D1:
    E0D1: BD 03 04    lda $0403,x
    E0D4: CD 03 04    cmp $0403
    E0D7: D0 1D       bne @E0F6   ; $E0F6
    E0D9: BD 00 04    lda $0400,x
    E0DC: 38          sec
    E0DD: ED 00 04    sbc $0400
    E0E0: BD 01 04    lda $0401,x
    E0E3: ED 01 04    sbc $0401
    E0E6: 18          clc
    E0E7: 69 01       adc #$01
    E0E9: C9 02       cmp #$02
    E0EB: B0 09       bcs @E0F6   ; $E0F6
    E0ED: BD 06 04    lda $0406,x
    E0F0: 8D 06 04    sta $0406
    E0F3: A9 00       lda #$00
    E0F5: 60          rts
@E0F6:
    E0F6: 8A          txa
    E0F7: 18          clc
    E0F8: 69 10       adc #$10
    E0FA: AA          tax
    E0FB: E0 90       cpx #$90
    E0FD: D0 C2       bne @E0C1   ; $E0C1
@E0FF:
    E0FF: A9 FF       lda #$ff
    E101: 60          rts

slot1_touches_player:
    E102: A5 1E       lda obj_record_ptr   ; $1E
    E104: D0 2B       bne @E131   ; $E131
    E106: AD 12 04    lda $0412
    E109: 38          sec
    E10A: ED 02 04    sbc $0402
    E10D: AD 13 04    lda $0413
    E110: ED 03 04    sbc $0403
    E113: 18          clc
    E114: 69 01       adc #$01
    E116: C9 02       cmp #$02
    E118: B0 17       bcs @E131   ; $E131
    E11A: AD 10 04    lda $0410
    E11D: 38          sec
    E11E: ED 00 04    sbc $0400
    E121: AD 11 04    lda $0411
    E124: ED 01 04    sbc $0401
    E127: 18          clc
    E128: 69 01       adc #$01
    E12A: C9 02       cmp #$02
    E12C: B0 03       bcs @E131   ; $E131
    E12E: A9 00       lda #$00
    E130: 60          rts
@E131:
    E131: A9 FF       lda #$ff
    E133: 60          rts

player_knockback_pushes_cats:
    E134: A2 20       ldx #$20
@E136:
    E136: BD 0F 04    lda $040f,x
    E139: C9 02       cmp #$02
    E13B: D0 33       bne @E170   ; $E170
    E13D: BD 03 04    lda $0403,x
    E140: CD 03 04    cmp $0403
    E143: D0 2B       bne @E170   ; $E170
    E145: BD 00 04    lda $0400,x
    E148: 38          sec
    E149: ED 00 04    sbc $0400
    E14C: BD 01 04    lda $0401,x
    E14F: ED 01 04    sbc $0401
    E152: 18          clc
    E153: 69 01       adc #$01
    E155: C9 02       cmp #$02
    E157: B0 17       bcs @E170   ; $E170
    E159: AD 06 04    lda $0406
    E15C: 9D 06 04    sta $0406,x
    E15F: A9 0C       lda #$0c
    E161: 9D 04 04    sta $0404,x
    E164: A9 10       lda #$10
    E166: 9D 0F 04    sta $040f,x
    E169: A9 08       lda #$08
    E16B: 9D 07 04    sta $0407,x
    E16E: E6 30       inc pending_score_count   ; $30
@E170:
    E170: 8A          txa
    E171: 18          clc
    E172: 69 01       adc #$01
    E174: AA          tax
    E175: E0 90       cpx #$90
    E177: D0 BD       bne @E136   ; $E136
    E179: 60          rts
    E17A:            .word handler_rts_noop
    E17C:            .word bonus_state02_fall
    E17E:            .word bonus_state04_ended
    E180:            .word bonus_state06_trampoline_bounce
    E182:            .word bonus_state08_rise
    E184:            .word bonus_state0A_walk_off
    E186:            .word bonus_state0C_rebound
    E188:            .word bonus_state0E_goal_object
    E18A:            .word bonus_state10_slot3_timeout
    E18C:            .word bonus_state12_released_cat_rises

end_bonus_round:
    E18E: A9 00       lda #$00
    E190: 8D 07 04    sta $0407
    E193: A9 01       lda #$01
    E195: 85 4B       sta player_down   ; $4B
    E197: A9 04       lda #$04
    E199: 8D 0F 04    sta $040f

bonus_state04_ended:
    E19C: 60          rts

bonus_state02_fall:
    E19D: A0 08       ldy #$08
    E19F: B1 1E       lda (obj_record_ptr),y   ; $1E
    E1A1: 38          sec
    E1A2: E9 49       sbc #$49
    E1A4: C9 07       cmp #$07
    E1A6: 90 E6       bcc end_bonus_round   ; $E18E
    E1A8: A0 03       ldy #$03
    E1AA: B1 1E       lda (obj_record_ptr),y   ; $1E
    E1AC: C9 1C       cmp #$1c
    E1AE: B0 DE       bcs end_bonus_round   ; $E18E
    E1B0: 20 6A E0    jsr fall_step   ; $E06A
    E1B3: 20 69 E4    jsr find_trampoline_below   ; $E469
    E1B6: B0 28       bcs @E1E0   ; $E1E0
    E1B8: A0 05       ldy #$05
    E1BA: B1 1E       lda (obj_record_ptr),y   ; $1E
    E1BC: D0 23       bne @E1E1   ; $E1E1
    E1BE: 86 18       stx scratch_loop_counter   ; $18
    E1C0: A9 01       lda #$01
    E1C2: 8D 0A 06    sta $060a
    E1C5: A0 3C       ldy #$3c
    E1C7: 20 CA D4    jsr add_score_from_table   ; $D4CA
    E1CA: A6 18       ldx scratch_loop_counter   ; $18
    E1CC: BD 02 02    lda obj_timer,x   ; $0202
    E1CF: D0 10       bne @E1E1   ; $E1E1
    E1D1: A9 01       lda #$01
    E1D3: 9D 00 02    sta obj_timer,x   ; $0200
    E1D6: A9 09       lda #$09
    E1D8: 9D 01 02    sta obj_anim_timer,x   ; $0201
    E1DB: A9 80       lda #$80
    E1DD: 9D 02 02    sta obj_timer,x   ; $0202
@E1E0:
    E1E0: 60          rts
@E1E1:
    E1E1: A0 01       ldy #$01
    E1E3: BD 01 02    lda obj_anim_timer,x   ; $0201
    E1E6: C9 08       cmp #$08
    E1E8: 90 01       bcc @E1EB   ; $E1EB
    E1EA: C8          iny
@E1EB:
    E1EB: 98          tya
    E1EC: 9D 00 02    sta obj_timer,x   ; $0200
    E1EF: 8A          txa
    E1F0: A0 0B       ldy #$0b
    E1F2: 91 1E       sta (obj_record_ptr),y   ; $1E
    E1F4: A9 00       lda #$00
    E1F6: A0 07       ldy #$07
    E1F8: 91 1E       sta (obj_record_ptr),y   ; $1E
    E1FA: A9 06       lda #$06
    E1FC: A0 0F       ldy #$0f
    E1FE: 91 1E       sta (obj_record_ptr),y   ; $1E

bonus_state06_trampoline_bounce:
    E200: A0 0B       ldy #$0b
    E202: B1 1E       lda (obj_record_ptr),y   ; $1E
    E204: AA          tax
    E205: 20 A4 E4    jsr trampoline_bounce_step   ; $E4A4
    E208: BD 02 02    lda obj_timer,x   ; $0202
    E20B: 30 50       bmi @E25D   ; $E25D
    E20D: BD 01 02    lda obj_anim_timer,x   ; $0201
    E210: C9 07       cmp #$07
    E212: D0 1B       bne @E22F   ; $E22F
    E214: A0 05       ldy #$05
    E216: B1 1E       lda (obj_record_ptr),y   ; $1E
    E218: D0 03       bne @E21D   ; $E21D
    E21A: DE 02 02    dec obj_timer,x   ; $0202
@E21D:
    E21D: A9 00       lda #$00
    E21F: A0 08       ldy #$08
    E221: 91 1E       sta (obj_record_ptr),y   ; $1E
    E223: A9 08       lda #$08
    E225: A0 0F       ldy #$0f
    E227: 91 1E       sta (obj_record_ptr),y   ; $1E
    E229: A9 06       lda #$06
    E22B: A0 04       ldy #$04
    E22D: 91 1E       sta (obj_record_ptr),y   ; $1E
@E22F:
    E22F: 60          rts

bonus_state08_rise:
    E230: A0 03       ldy #$03
    E232: B1 1E       lda (obj_record_ptr),y   ; $1E
    E234: C9 08       cmp #$08
    E236: 90 0F       bcc @E247   ; $E247
    E238: 29 03       and #$03
    E23A: 38          sec
    E23B: E9 01       sbc #$01
    E23D: C9 02       cmp #$02
    E23F: B0 06       bcs @E247   ; $E247
    E241: A0 0D       ldy #$0d
    E243: B1 1E       lda (obj_record_ptr),y   ; $1E
    E245: D0 29       bne @E270   ; $E270
@E247:
    E247: A0 08       ldy #$08
    E249: B1 1E       lda (obj_record_ptr),y   ; $1E
    E24B: 38          sec
    E24C: E9 30       sbc #$30
    E24E: C9 20       cmp #$20
    E250: 90 0B       bcc @E25D   ; $E25D
    E252: A0 03       ldy #$03
    E254: B1 1E       lda (obj_record_ptr),y   ; $1E
    E256: C9 06       cmp #$06
    E258: 90 03       bcc @E25D   ; $E25D
    E25A: 4C 84 E0    jmp rise_step   ; $E084
@E25D:
    E25D: A9 00       lda #$00
    E25F: A0 08       ldy #$08
    E261: 91 1E       sta (obj_record_ptr),y   ; $1E
    E263: A9 02       lda #$02
    E265: A0 0F       ldy #$0f
    E267: 91 1E       sta (obj_record_ptr),y   ; $1E
    E269: A9 06       lda #$06
    E26B: A0 04       ldy #$04
    E26D: 91 1E       sta (obj_record_ptr),y   ; $1E
    E26F: 60          rts
@E270:
    E270: A0 06       ldy #$06
    E272: 91 1E       sta (obj_record_ptr),y   ; $1E
    E274: A0 03       ldy #$03
    E276: B1 1E       lda (obj_record_ptr),y   ; $1E
    E278: 29 FE       and #$fe
    E27A: 09 02       ora #$02
    E27C: 91 1E       sta (obj_record_ptr),y   ; $1E
    E27E: 88          dey
    E27F: A9 00       lda #$00
    E281: 91 1E       sta (obj_record_ptr),y   ; $1E
    E283: A9 21       lda #$21
    E285: A0 07       ldy #$07
    E287: 91 1E       sta (obj_record_ptr),y   ; $1E
    E289: A9 E0       lda #$e0
    E28B: A0 0B       ldy #$0b
    E28D: 91 1E       sta (obj_record_ptr),y   ; $1E
    E28F: A9 02       lda #$02
    E291: C8          iny
    E292: 91 1E       sta (obj_record_ptr),y   ; $1E
    E294: A9 0A       lda #$0a
    E296: A0 0F       ldy #$0f
    E298: 91 1E       sta (obj_record_ptr),y   ; $1E
    E29A: A9 04       lda #$04
    E29C: A0 04       ldy #$04
    E29E: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2A0: 60          rts

bonus_state0A_walk_off:
    E2A1: A0 08       ldy #$08
    E2A3: B1 1E       lda (obj_record_ptr),y   ; $1E
    E2A5: 38          sec
    E2A6: E9 49       sbc #$49
    E2A8: C9 10       cmp #$10
    E2AA: 90 0E       bcc @E2BA   ; $E2BA

bonus_state0C_rebound:
    E2AC: A0 07       ldy #$07
    E2AE: B1 1E       lda (obj_record_ptr),y   ; $1E
    E2B0: 38          sec
    E2B1: E9 01       sbc #$01
    E2B3: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2B5: F0 A6       beq @E25D   ; $E25D
    E2B7: 4C 3D E0    jmp move_hop_arc   ; $E03D
@E2BA:
    E2BA: A9 00       lda #$00
    E2BC: 38          sec
    E2BD: A0 06       ldy #$06
    E2BF: F1 1E       sbc (obj_record_ptr),y   ; $1E
    E2C1: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2C3: A9 06       lda #$06
    E2C5: C8          iny
    E2C6: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2C8: A9 00       lda #$00
    E2CA: A0 0B       ldy #$0b
    E2CC: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2CE: A9 09       lda #$09
    E2D0: C8          iny
    E2D1: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2D3: A9 0C       lda #$0c
    E2D5: A0 0F       ldy #$0f
    E2D7: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2D9: A9 04       lda #$04
    E2DB: A0 04       ldy #$04
    E2DD: 91 1E       sta (obj_record_ptr),y   ; $1E
    E2DF: 60          rts

bonus_state10_slot3_timeout:
    E2E0: CE 37 04    dec $0437
    E2E3: D0 08       bne @E2ED   ; $E2ED
    E2E5: A9 00       lda #$00
    E2E7: 8D 34 04    sta $0434
    E2EA: 8D 3F 04    sta $043f
@E2ED:
    E2ED: 60          rts

bonus_state0E_goal_object:
    E2EE: AD 13 04    lda $0413
    E2F1: CD 03 04    cmp $0403
    E2F4: D0 3B       bne @E331   ; $E331
    E2F6: AD 11 04    lda $0411
    E2F9: 38          sec
    E2FA: ED 01 04    sbc $0401
    E2FD: C9 02       cmp #$02
    E2FF: B0 30       bcs @E331   ; $E331
    E301: E6 51       inc obj_def_ptr_hi   ; $51
    E303: A9 20       lda #$20
    E305: 85 5A       sta ppu_block_src_ptr   ; $5A
    E307: 20 BF F4    jsr init_sound_voices   ; $F4BF
    E30A: A9 01       lda #$01
    E30C: 8D 06 06    sta $0606
    E30F: A9 00       lda #$00
    E311: 8D 14 04    sta $0414
    E314: 8D 1F 04    sta obj_state   ; $041F
    E317: 20 8E E1    jsr end_bonus_round   ; $E18E
    E31A: A9 12       lda #$12
    E31C: 8D 2F 04    sta stage_phase_state   ; $042F
    E31F: A2 00       ldx #$00
@E321:
    E321: BD 32 E3    lda $e332,x
    E324: 9D 20 04    sta stamp_position_table,x   ; $0420
    E327: E8          inx
    E328: E0 07       cpx #$07
    E32A: D0 F5       bne @E321   ; $E321
    E32C: A9 00       lda #$00
    E32E: 8D 2B 04    sta $042b
@E331:
    E331: 60          rts
    E332: 00          .byte $00
    E333: 05          .byte $05
    E334: 00          .byte $00
    E335: 18          .byte $18
    E336: 06          .byte $06
    E337: 02          .byte $02
    E338: FF          .byte $FF

bonus_state12_released_cat_rises:
    E339: AD 28 04    lda $0428
    E33C: 38          sec
    E33D: E9 30       sbc #$30
    E33F: C9 19       cmp #$19
    E341: B0 03       bcs @E346   ; $E346
    E343: 20 56 E4    jsr erase_first_trampoline   ; $E456
@E346:
    E346: AD 23 04    lda obj_state   ; $0423
    E349: C9 06       cmp #$06
    E34B: 90 05       bcc @E352   ; $E352
    E34D: A9 40       lda #$40
    E34F: 4C 8A E0    jmp move_up_by_a   ; $E08A
@E352:
    E352: A9 00       lda #$00
    E354: 8D 24 04    sta obj_state   ; $0424
    E357: 8D 2F 04    sta stage_phase_state   ; $042F
    E35A: 60          rts

load_round_trampolines:
    E35B: A6 7A       ldx stage_number   ; $7A
    E35D: BC E1 E4    ldy $e4e1,x
    E360: B9 F1 E4    lda $e4f1,y
    E363: 85 1C       sta aux_ptr   ; $1C
    E365: B9 F2 E4    lda $e4f2,y
    E368: 85 1D       sta aux_ptr_hi   ; $1D
    E36A: A0 00       ldy #$00
    E36C: B1 1C       lda (aux_ptr),y   ; $1C
    E36E: C8          iny
    E36F: 85 80       sta object_count   ; $80
    E371: A2 00       ldx #$00
@E373:
    E373: A9 00       lda #$00
    E375: 9D 00 02    sta obj_timer,x   ; $0200
    E378: 9D 01 02    sta obj_anim_timer,x   ; $0201
    E37B: A9 03       lda #$03
    E37D: 9D 02 02    sta obj_timer,x   ; $0202
    E380: B1 1C       lda (aux_ptr),y   ; $1C
    E382: C8          iny
    E383: 84 1B       sty cur_obj_index   ; $1B
    E385: 9D 03 02    sta $0203,x
    E388: A8          tay
    E389: B9 37 E5    lda $e537,y
    E38C: 85 10       sta src_ptr   ; $10
    E38E: B9 38 E5    lda $e538,y
    E391: 85 11       sta zp_ptr_hi   ; $11
    E393: 20 BD E3    jsr ppu_addr_to_tile_xy   ; $E3BD
    E396: A5 10       lda src_ptr   ; $10
    E398: 9D 04 02    sta $0204,x
    E39B: A5 11       lda zp_ptr_hi   ; $11
    E39D: 9D 05 02    sta obj_field_05,x   ; $0205
    E3A0: A4 1B       ldy cur_obj_index   ; $1B
    E3A2: 8A          txa
    E3A3: 18          clc
    E3A4: 69 08       adc #$08
    E3A6: AA          tax
    E3A7: E4 80       cpx object_count   ; $80
    E3A9: D0 C8       bne @E373   ; $E373
    E3AB: A2 00       ldx #$00
@E3AD:
    E3AD: 86 1B       stx cur_obj_index   ; $1B
    E3AF: 20 27 E4    jsr draw_trampoline   ; $E427
    E3B2: A5 1B       lda cur_obj_index   ; $1B
    E3B4: 18          clc
    E3B5: 69 08       adc #$08
    E3B7: AA          tax
    E3B8: E4 80       cpx object_count   ; $80
    E3BA: D0 F1       bne @E3AD   ; $E3AD
    E3BC: 60          rts

ppu_addr_to_tile_xy:
    E3BD: A5 10       lda src_ptr   ; $10
    E3BF: 29 1F       and #$1f
    E3C1: 06 10       asl src_ptr   ; $10
    E3C3: 26 11       rol zp_ptr_hi   ; $11
    E3C5: 06 10       asl src_ptr   ; $10
    E3C7: 26 11       rol zp_ptr_hi   ; $11
    E3C9: 06 10       asl src_ptr   ; $10
    E3CB: 26 11       rol zp_ptr_hi   ; $11
    E3CD: 85 10       sta src_ptr   ; $10
    E3CF: A5 11       lda zp_ptr_hi   ; $11
    E3D1: 29 20       and #$20
    E3D3: 05 10       ora src_ptr   ; $10
    E3D5: 85 10       sta src_ptr   ; $10
    E3D7: A5 11       lda zp_ptr_hi   ; $11
    E3D9: 29 1F       and #$1f
    E3DB: 85 11       sta zp_ptr_hi   ; $11
    E3DD: 60          rts

restore_trampolines:
    E3DE: A2 00       ldx #$00
@E3E0:
    E3E0: 86 1B       stx cur_obj_index   ; $1B
    E3E2: BD 02 02    lda obj_timer,x   ; $0202
    E3E5: 30 0C       bmi @E3F3   ; $E3F3
    E3E7: C9 03       cmp #$03
    E3E9: F0 08       beq @E3F3   ; $E3F3
    E3EB: A9 03       lda #$03
    E3ED: 9D 02 02    sta obj_timer,x   ; $0202
    E3F0: 20 27 E4    jsr draw_trampoline   ; $E427
@E3F3:
    E3F3: A5 1B       lda cur_obj_index   ; $1B
    E3F5: 18          clc
    E3F6: 69 08       adc #$08
    E3F8: AA          tax
    E3F9: E4 80       cpx object_count   ; $80
    E3FB: D0 E3       bne @E3E0   ; $E3E0
    E3FD: 60          rts

animate_trampolines:
    E3FE: A2 00       ldx #$00
@E400:
    E400: 86 1B       stx cur_obj_index   ; $1B
    E402: 20 10 E4    jsr animate_trampoline   ; $E410
    E405: A5 1B       lda cur_obj_index   ; $1B
    E407: 18          clc
    E408: 69 08       adc #$08
    E40A: AA          tax
    E40B: E4 80       cpx object_count   ; $80
    E40D: D0 F1       bne @E400   ; $E400
@E40F:
    E40F: 60          rts

animate_trampoline:
    E410: BD 00 02    lda obj_timer,x   ; $0200
    E413: F0 FA       beq @E40F   ; $E40F
    E415: FE 01 02    inc obj_anim_timer,x   ; $0201
    E418: BD 01 02    lda obj_anim_timer,x   ; $0201
    E41B: C9 0A       cmp #$0a
    E41D: 90 08       bcc draw_trampoline   ; $E427
    E41F: A9 00       lda #$00
    E421: 9D 01 02    sta obj_anim_timer,x   ; $0201
    E424: DE 00 02    dec obj_timer,x   ; $0200

draw_trampoline:
    E427: BC 03 02    ldy $0203,x
    E42A: B9 37 E5    lda $e537,y
    E42D: 85 10       sta src_ptr   ; $10
    E42F: B9 38 E5    lda $e538,y
    E432: 85 11       sta zp_ptr_hi   ; $11
    E434: BD 02 02    lda obj_timer,x   ; $0202
    E437: 10 09       bpl @E442   ; $E442
    E439: A9 00       lda #$00
    E43B: 85 14       sta scan_src_ptr   ; $14
    E43D: A0 14       ldy #$14
    E43F: 4C 49 E4    jmp draw_text_from_table   ; $E449
@E442:
    E442: 85 14       sta scan_src_ptr   ; $14
    E444: BD 01 02    lda obj_anim_timer,x   ; $0201
    E447: 0A          asl a
    E448: A8          tay

draw_text_from_table:
    E449: B9 69 E5    lda $e569,y
    E44C: 85 12       sta gfx_src_ptr   ; $12
    E44E: B9 6A E5    lda $e56a,y
    E451: 85 13       sta data_ptr_hi   ; $13
    E453: 4C FB C6    jmp draw_rle_text   ; $C6FB

erase_first_trampoline:
    E456: AD 37 E5    lda $e537
    E459: 85 10       sta src_ptr   ; $10
    E45B: AD 38 E5    lda $e538
    E45E: 85 11       sta zp_ptr_hi   ; $11
    E460: A9 00       lda #$00
    E462: 85 14       sta scan_src_ptr   ; $14
    E464: A0 14       ldy #$14
    E466: 4C 49 E4    jmp draw_text_from_table   ; $E449

find_trampoline_below:
    E469: A2 00       ldx #$00
@E46B:
    E46B: BD 02 02    lda obj_timer,x   ; $0202
    E46E: 30 27       bmi @E497   ; $E497
    E470: A0 01       ldy #$01
    E472: B1 1E       lda (obj_record_ptr),y   ; $1E
    E474: 38          sec
    E475: FD 04 02    sbc $0204,x
    E478: 18          clc
    E479: 69 01       adc #$01
    E47B: C9 04       cmp #$04
    E47D: B0 18       bcs @E497   ; $E497
    E47F: BD 05 02    lda obj_field_05,x   ; $0205
    E482: 18          clc
    E483: 6D CE E4    adc $e4ce
    E486: 85 11       sta zp_ptr_hi   ; $11
    E488: A0 02       ldy #$02
    E48A: B1 1E       lda (obj_record_ptr),y   ; $1E
    E48C: 18          clc
    E48D: ED CD E4    sbc $e4cd
    E490: C8          iny
    E491: B1 1E       lda (obj_record_ptr),y   ; $1E
    E493: E5 11       sbc zp_ptr_hi   ; $11
    E495: F0 0B       beq @E4A2   ; $E4A2
@E497:
    E497: 8A          txa
    E498: 18          clc
    E499: 69 08       adc #$08
    E49B: AA          tax
    E49C: E4 80       cpx object_count   ; $80
    E49E: D0 CB       bne @E46B   ; $E46B
    E4A0: 38          sec
    E4A1: 60          rts
@E4A2:
    E4A2: 18          clc
    E4A3: 60          rts

trampoline_bounce_step:
    E4A4: A9 06       lda #$06
    E4A6: A0 04       ldy #$04
    E4A8: 91 1E       sta (obj_record_ptr),y   ; $1E
    E4AA: A0 07       ldy #$07
    E4AC: B1 1E       lda (obj_record_ptr),y   ; $1E
    E4AE: 0A          asl a
    E4AF: A8          tay
    E4B0: B9 CE E4    lda $e4ce,y
    E4B3: 48          pha
    E4B4: B9 CD E4    lda $e4cd,y
    E4B7: A0 02       ldy #$02
    E4B9: 91 1E       sta (obj_record_ptr),y   ; $1E
    E4BB: C8          iny
    E4BC: 68          pla
    E4BD: 18          clc
    E4BE: 7D 05 02    adc obj_field_05,x   ; $0205
    E4C1: 91 1E       sta (obj_record_ptr),y   ; $1E
    E4C3: A0 07       ldy #$07
    E4C5: B1 1E       lda (obj_record_ptr),y   ; $1E
    E4C7: 18          clc
    E4C8: 69 01       adc #$01
    E4CA: 91 1E       sta (obj_record_ptr),y   ; $1E
    E4CC: 60          rts
    E4CD: 40          .byte $40
    E4CE: FE          .byte $FE
    E4CF: 80          .byte $80
    E4D0: FE          .byte $FE
    E4D1: C0          .byte $C0
    E4D2: FE          .byte $FE
    E4D3: 00          .byte $00
    E4D4: FF          .byte $FF
    E4D5: C0          .byte $C0
    E4D6: FE          .byte $FE
    E4D7: 80          .byte $80
    E4D8: FE          .byte $FE
    E4D9: 40          .byte $40
    E4DA: FE          .byte $FE
    E4DB: 00          .byte $00
    E4DC: FE          .byte $FE
    E4DD: C0          .byte $C0
    E4DE: FD          .byte $FD
    E4DF: 00          .byte $00
    E4E0: FE          .byte $FE
    E4E1: 00          .byte $00
    E4E2: 0A          .byte $0A
    E4E3: 08          .byte $08
    E4E4: 02          .byte $02
    E4E5: 02          .byte $02
    E4E6: 02          .byte $02
    E4E7: 08          .byte $08
    E4E8: 04          .byte $04
    E4E9: 04          .byte $04
    E4EA: 04          .byte $04
    E4EB: 08          .byte $08
    E4EC: 06          .byte $06
    E4ED: 0C          .byte $0C
    E4EE: 06          .byte $06
    E4EF: 08          .byte $08
    E4F0: 00          .byte $00
    E4F1: FF          .byte $FF
    E4F2: E4          .byte $E4
    E4F3: 0B          .byte $0B
    E4F4: E5          .byte $E5
    E4F5: 12          .byte $12
    E4F6: E5          .byte $E5
    E4F7: 19          .byte $19
    E4F8: E5          .byte $E5
    E4F9: 2A          .byte $2A
    E4FA: E5          .byte $E5
    E4FB: 04          .byte $04
    E4FC: E5          .byte $E5
    E4FD: 21          .byte $21
    E4FE: E5          .byte $E5
    E4FF: 20          .byte $20
    E500: 0E          .byte $0E
    E501: 14          .byte $14
    E502: 28          .byte $28
    E503: 30          .byte $30
    E504: 30          .byte $30
    E505: 0E          .byte $0E
    E506: 14          .byte $14
    E507: 28          .byte $28
    E508: 30          .byte $30
    E509: 06          .byte $06
    E50A: 22          .byte $22
    E50B: 30          .byte $30
    E50C: 04          .byte $04
    E50D: 08          .byte $08
    E50E: 0E          .byte $0E
    E50F: 18          .byte $18
    E510: 20          .byte $20
    E511: 30          .byte $30
    E512: 30          .byte $30
    E513: 04          .byte $04
    E514: 0A          .byte $0A
    E515: 0E          .byte $0E
    E516: 14          .byte $14
    E517: 28          .byte $28
    E518: 30          .byte $30
    E519: 38          .byte $38
    E51A: 02          .byte $02
    E51B: 0C          .byte $0C
    E51C: 0E          .byte $0E
    E51D: 18          .byte $18
    E51E: 1A          .byte $1A
    E51F: 24          .byte $24
    E520: 30          .byte $30
    E521: 40          .byte $40
    E522: 02          .byte $02
    E523: 04          .byte $04
    E524: 0C          .byte $0C
    E525: 0E          .byte $0E
    E526: 18          .byte $18
    E527: 1A          .byte $1A
    E528: 24          .byte $24
    E529: 30          .byte $30
    E52A: 60          .byte $60
    E52B: 00          .byte $00
    E52C: 08          .byte $08
    E52D: 10          .byte $10
    E52E: 12          .byte $12
    E52F: 16          .byte $16
    E530: 18          .byte $18
    E531: 1C          .byte $1C
    E532: 1E          .byte $1E
    E533: 26          .byte $26
    E534: 2A          .byte $2A
    E535: 2C          .byte $2C
    E536: 2E          .byte $2E
    E537: 04          .byte $04
    E538: 22          .byte $22
    E539: 02          .byte $02
    E53A: 22          .byte $22
    E53B: 1C          .byte $1C
    E53C: 22          .byte $22
    E53D: 82          .byte $82
    E53E: 22          .byte $22
    E53F: 90          .byte $90
    E540: 22          .byte $22
    E541: 9C          .byte $9C
    E542: 22          .byte $22
    E543: 0C          .byte $0C
    E544: 23          .byte $23
    E545: 82          .byte $82
    E546: 23          .byte $23
    E547: 8A          .byte $8A
    E548: 23          .byte $23
    E549: 90          .byte $90
    E54A: 23          .byte $23
    E54B: 92          .byte $92
    E54C: 23          .byte $23
    E54D: 96          .byte $96
    E54E: 23          .byte $23
    E54F: 9C          .byte $9C
    E550: 23          .byte $23
    E551: 16          .byte $16
    E552: 26          .byte $26
    E553: 82          .byte $82
    E554: 26          .byte $26
    E555: 14          .byte $14
    E556: 26          .byte $26
    E557: 88          .byte $88
    E558: 26          .byte $26
    E559: 16          .byte $16
    E55A: 26          .byte $26
    E55B: 0C          .byte $0C
    E55C: 27          .byte $27
    E55D: 82          .byte $82
    E55E: 27          .byte $27
    E55F: 86          .byte $86
    E560: 27          .byte $27
    E561: 88          .byte $88
    E562: 27          .byte $27
    E563: 8E          .byte $8E
    E564: 27          .byte $27
    E565: 94          .byte $94
    E566: 27          .byte $27
    E567: 96          .byte $96
    E568: 27          .byte $27
    E569: 7F          .byte $7F
    E56A: E5          .byte $E5
    E56B: 8B          .byte $8B
    E56C: E5          .byte $E5
    E56D: 91          .byte $91
    E56E: E5          .byte $E5
    E56F: 97          .byte $97
    E570: E5          .byte $E5
    E571: 91          .byte $91
    E572: E5          .byte $E5
    E573: 8B          .byte $8B
    E574: E5          .byte $E5
    E575: 7F          .byte $7F
    E576: E5          .byte $E5
    E577: 9D          .byte $9D
    E578: E5          .byte $E5
    E579: A9          .byte $A9
    E57A: E5          .byte $E5
    E57B: 9D          .byte $9D
    E57C: E5          .byte $E5
    E57D: B5          .byte $B5
    E57E: E5          .byte $E5
    E57F: 04          .byte $04
    E580: 30          .byte $30
    E581: 30          .byte $30
    E582: 30          .byte $30
    E583: 30          .byte $30
    E584: DC          .byte $DC
    E585: 04          .byte $04
    E586: 00          .byte $00
    E587: 00          .byte $00
    E588: 00          .byte $00
    E589: 00          .byte $00
    E58A: 00          .byte $00
    E58B: 04          .byte $04
    E58C: 31          .byte $31
    E58D: 32          .byte $32
    E58E: 33          .byte $33
    E58F: 34          .byte $34
    E590: 00          .byte $00
    E591: 04          .byte $04
    E592: 35          .byte $35
    E593: 36          .byte $36
    E594: 37          .byte $37
    E595: 38          .byte $38
    E596: 00          .byte $00
    E597: 04          .byte $04
    E598: 39          .byte $39
    E599: 3A          .byte $3A
    E59A: 3B          .byte $3B
    E59B: 3C          .byte $3C
    E59C: 00          .byte $00
    E59D: 04          .byte $04
    E59E: 3D          .byte $3D
    E59F: 59          .byte $59
    E5A0: 59          .byte $59
    E5A1: 42          .byte $42
    E5A2: DC          .byte $DC
    E5A3: 04          .byte $04
    E5A4: 3E          .byte $3E
    E5A5: 3F          .byte $3F
    E5A6: 40          .byte $40
    E5A7: 41          .byte $41
    E5A8: 00          .byte $00
    E5A9: 04          .byte $04
    E5AA: 43          .byte $43
    E5AB: 59          .byte $59
    E5AC: 59          .byte $59
    E5AD: 48          .byte $48
    E5AE: DC          .byte $DC
    E5AF: 04          .byte $04
    E5B0: 44          .byte $44
    E5B1: 45          .byte $45
    E5B2: 46          .byte $46
    E5B3: 47          .byte $47
    E5B4: 00          .byte $00
    E5B5: 04          .byte $04
    E5B6: 85          .byte $85
    E5B7: 00          .byte $00
    E5B8: 00          .byte $00
    E5B9: 86          .byte $86
    E5BA: 1D          .byte $1D
    E5BB: 02          .byte $02
    E5BC: 00          .byte $00
    E5BD: 00          .byte $00
    E5BE: BD          .byte $BD
    E5BF: 04          .byte $04
    E5C0: 00          .byte $00
    E5C1: 00          .byte $00
    E5C2: 00          .byte $00
    E5C3: 00          .byte $00
    E5C4: 00          .byte $00

load_round_items:
    E5C5: AD 98 E7    lda $e798
    E5C8: 85 1C       sta aux_ptr   ; $1C
    E5CA: AD 99 E7    lda $e799
    E5CD: 85 1D       sta aux_ptr_hi   ; $1D
    E5CF: A0 00       ldy #$00
    E5D1: B1 1C       lda (aux_ptr),y   ; $1C
    E5D3: 85 81       sta item_table_len   ; $81
    E5D5: 4A          lsr a
    E5D6: 4A          lsr a
    E5D7: 4A          lsr a
    E5D8: 85 7B       sta round_items_remaining   ; $7B
    E5DA: F0 57       beq @E633   ; $E633
    E5DC: C8          iny
    E5DD: A2 00       ldx #$00
@E5DF:
    E5DF: A9 02       lda #$02
    E5E1: 9D 60 02    sta item_state,x   ; $0260
    E5E4: A9 00       lda #$00
    E5E6: 9D 63 02    sta obj_type,x   ; $0263
    E5E9: B1 1C       lda (aux_ptr),y   ; $1C
    E5EB: C8          iny
    E5EC: 84 1B       sty cur_obj_index   ; $1B
    E5EE: 9D 61 02    sta obj_type,x   ; $0261
    E5F1: A8          tay
    E5F2: B9 A5 E7    lda $e7a5,y
    E5F5: 85 10       sta src_ptr   ; $10
    E5F7: B9 A6 E7    lda $e7a6,y
    E5FA: 85 11       sta zp_ptr_hi   ; $11
    E5FC: 20 BD E3    jsr ppu_addr_to_tile_xy   ; $E3BD
    E5FF: A5 10       lda src_ptr   ; $10
    E601: 9D 64 02    sta item_x,x   ; $0264
    E604: A5 11       lda zp_ptr_hi   ; $11
    E606: 9D 65 02    sta item_y,x   ; $0265
    E609: A4 1B       ldy cur_obj_index   ; $1B
    E60B: 8A          txa
    E60C: 18          clc
    E60D: 69 08       adc #$08
    E60F: AA          tax
    E610: E4 81       cpx item_table_len   ; $81
    E612: D0 CB       bne @E5DF   ; $E5DF

draw_round_items:
    E614: A2 00       ldx #$00
    E616: 86 31       stx obj_record_ptr   ; $31
@E618:
    E618: 86 1B       stx cur_obj_index   ; $1B
    E61A: BD 60 02    lda item_state,x   ; $0260
    E61D: C9 02       cmp #$02
    E61F: D0 08       bne @E629   ; $E629
    E621: A9 00       lda #$00
    E623: 9D 63 02    sta obj_type,x   ; $0263
    E626: 20 2C E7    jsr draw_item   ; $E72C
@E629:
    E629: A5 1B       lda cur_obj_index   ; $1B
    E62B: 18          clc
    E62C: 69 08       adc #$08
    E62E: AA          tax
    E62F: E4 81       cpx item_table_len   ; $81
    E631: D0 E5       bne @E618   ; $E618
@E633:
    E633: 60          rts

update_items:
    E634: A5 81       lda item_table_len   ; $81
    E636: F0 11       beq @E649   ; $E649
    E638: A2 00       ldx #$00
@E63A:
    E63A: 86 1B       stx cur_obj_index   ; $1B
    E63C: 20 4A E6    jsr dispatch_item_state   ; $E64A
    E63F: A5 1B       lda cur_obj_index   ; $1B
    E641: 18          clc
    E642: 69 08       adc #$08
    E644: AA          tax
    E645: E4 81       cpx item_table_len   ; $81
    E647: D0 F1       bne @E63A   ; $E63A
@E649:
    E649: 60          rts

dispatch_item_state:
    E64A: BC 60 02    ldy item_state,x   ; $0260
    E64D: B9 5A E6    lda $e65a,y
    E650: 85 1C       sta aux_ptr   ; $1C
    E652: B9 5B E6    lda $e65b,y
    E655: 85 1D       sta aux_ptr_hi   ; $1D
    E657: 6C 1C 00    jmp (aux_ptr)   ; $001C
    E65A:            .word handler_rts_noop
    E65C:            .word player_collects_item
    E65E:            .word show_item_points

player_collects_item:
    E660: 20 57 E7    jsr slot2_sits_on_item   ; $E757
    E663: BD 63 02    lda obj_type,x   ; $0263
    E666: F0 05       beq @E66D   ; $E66D
    E668: 20 1E E7    jsr blink_marked_item   ; $E71E
    E66B: A6 1B       ldx cur_obj_index   ; $1B
@E66D:
    E66D: BD 65 02    lda item_y,x   ; $0265
    E670: CD 03 04    cmp $0403
    E673: D0 D4       bne @E649   ; $E649
    E675: BD 64 02    lda item_x,x   ; $0264
    E678: 38          sec
    E679: ED 01 04    sbc $0401
    E67C: C9 02       cmp #$02
    E67E: B0 C9       bcs @E649   ; $E649
    E680: C6 7B       dec round_items_remaining   ; $7B
    E682: D0 13       bne @E697   ; $E697
    E684: A9 01       lda #$01
    E686: 85 4F       sta round_cleared   ; $4F
    E688: A9 00       lda #$00
    E68A: 8D 0F 04    sta $040f
    E68D: 8D 04 04    sta $0404
    E690: 8A          txa
    E691: 48          pha
    E692: 20 EF DA    jsr reset_objects_except_persistent_types   ; $DAEF
    E695: 68          pla
    E696: AA          tax
@E697:
    E697: A5 42       lda game_phase   ; $42
    E699: 8D 08 06    sta $0608
    E69C: A9 04       lda #$04
    E69E: 9D 60 02    sta item_state,x   ; $0260
    E6A1: A9 3C       lda #$3c
    E6A3: 9D 62 02    sta $0262,x
    E6A6: A9 01       lda #$01
    E6A8: 85 18       sta scratch_loop_counter   ; $18
    E6AA: BD 63 02    lda obj_type,x   ; $0263
    E6AD: F0 07       beq @E6B6   ; $E6B6
    E6AF: A5 31       lda obj_record_ptr   ; $31
    E6B1: 18          clc
    E6B2: 69 02       adc #$02
    E6B4: 85 18       sta scratch_loop_counter   ; $18
@E6B6:
    E6B6: BD 61 02    lda obj_type,x   ; $0261
    E6B9: 29 FC       and #$fc
    E6BB: 20 BE D4    jsr add_score_n_times   ; $D4BE
    E6BE: A6 1B       ldx cur_obj_index   ; $1B
    E6C0: 20 0A E7    jsr erase_item   ; $E70A
    E6C3: A6 1B       ldx cur_obj_index   ; $1B
    E6C5: BD 63 02    lda obj_type,x   ; $0263
    E6C8: D0 2D       bne @E6F7   ; $E6F7
    E6CA: A2 00       ldx #$00
@E6CC:
    E6CC: 86 1A       stx data_src_ptr   ; $1A
    E6CE: BD 60 02    lda item_state,x   ; $0260
    E6D1: C9 02       cmp #$02
    E6D3: D0 0D       bne @E6E2   ; $E6E2
    E6D5: BD 63 02    lda obj_type,x   ; $0263
    E6D8: F0 08       beq @E6E2   ; $E6E2
    E6DA: A9 00       lda #$00
    E6DC: 9D 63 02    sta obj_type,x   ; $0263
    E6DF: 20 2C E7    jsr draw_item   ; $E72C
@E6E2:
    E6E2: A5 1A       lda data_src_ptr   ; $1A
    E6E4: 18          clc
    E6E5: 69 08       adc #$08
    E6E7: AA          tax
    E6E8: E4 81       cpx item_table_len   ; $81
    E6EA: D0 E0       bne @E6CC   ; $E6CC
    E6EC: A5 1B       lda cur_obj_index   ; $1B
    E6EE: 49 08       eor #$08
    E6F0: AA          tax
    E6F1: A9 01       lda #$01
    E6F3: 9D 63 02    sta obj_type,x   ; $0263
    E6F6: 60          rts
@E6F7:
    E6F7: E6 31       inc obj_record_ptr   ; $31
    E6F9: 60          rts

show_item_points:
    E6FA: 20 F5 E7    jsr draw_item_points_sprites   ; $E7F5
    E6FD: A6 1B       ldx cur_obj_index   ; $1B
    E6FF: DE 62 02    dec $0262,x
    E702: D0 19       bne @E71D   ; $E71D
    E704: A9 00       lda #$00
    E706: 9D 60 02    sta item_state,x   ; $0260
    E709: 60          rts

erase_item:
    E70A: A0 0A       ldy #$0a
    E70C: B9 B9 E7    lda $e7b9,y
    E70F: 85 12       sta gfx_src_ptr   ; $12
    E711: B9 BA E7    lda $e7ba,y
    E714: 85 13       sta data_ptr_hi   ; $13
    E716: A9 80       lda #$80
    E718: 85 14       sta scan_src_ptr   ; $14
    E71A: 4C 47 E7    jmp draw_at_item_address   ; $E747
@E71D:
    E71D: 60          rts

blink_marked_item:
    E71E: A5 21       lda frame_counter   ; $21
    E720: 29 03       and #$03
    E722: 49 01       eor #$01
    E724: D0 F7       bne @E71D   ; $E71D
    E726: A5 21       lda frame_counter   ; $21
    E728: 29 04       and #$04
    E72A: F0 DE       beq erase_item   ; $E70A

draw_item:
    E72C: BD 61 02    lda obj_type,x   ; $0261
    E72F: 4A          lsr a
    E730: 29 FE       and #$fe
    E732: A8          tay
    E733: C9 06       cmp #$06
    E735: A9 00       lda #$00
    E737: 90 02       bcc @E73B   ; $E73B
    E739: A9 02       lda #$02
@E73B:
    E73B: 85 14       sta scan_src_ptr   ; $14
    E73D: B9 B9 E7    lda $e7b9,y
    E740: 85 12       sta gfx_src_ptr   ; $12
    E742: B9 BA E7    lda $e7ba,y
    E745: 85 13       sta data_ptr_hi   ; $13

draw_at_item_address:
    E747: BC 61 02    ldy obj_type,x   ; $0261
    E74A: B9 A5 E7    lda $e7a5,y
    E74D: 85 10       sta src_ptr   ; $10
    E74F: B9 A6 E7    lda $e7a6,y
    E752: 85 11       sta zp_ptr_hi   ; $11
    E754: 4C FB C6    jmp draw_rle_text   ; $C6FB

slot2_sits_on_item:
    E757: AD 2F 04    lda stage_phase_state   ; $042F
    E75A: C9 02       cmp #$02
    E75C: D0 29       bne @E787   ; $E787
    E75E: AD 2A 04    lda bonus_item_timer   ; $042A
    E761: D0 24       bne @E787   ; $E787
    E763: BD 65 02    lda item_y,x   ; $0265
    E766: CD 23 04    cmp obj_state   ; $0423
    E769: D0 1C       bne @E787   ; $E787
    E76B: BD 64 02    lda item_x,x   ; $0264
    E76E: CD 21 04    cmp target_compare_value   ; $0421
    E771: D0 14       bne @E787   ; $E787
    E773: A9 00       lda #$00
    E775: 8D 20 04    sta stamp_position_table   ; $0420
    E778: A9 13       lda #$13
    E77A: 8D 24 04    sta obj_state   ; $0424
    E77D: A9 1E       lda #$1e
    E77F: 8D 2F 04    sta stage_phase_state   ; $042F
    E782: A9 78       lda #$78
    E784: 8D 27 04    sta bonus_item_timer   ; $0427
@E787:
    E787: 60          rts
    E788: 02          .byte $02
    E789: 02          .byte $02
    E78A: 00          .byte $00
    E78B: 02          .byte $02
    E78C: 02          .byte $02
    E78D: 02          .byte $02
    E78E: 00          .byte $00
    E78F: 02          .byte $02
    E790: 02          .byte $02
    E791: 02          .byte $02
    E792: 00          .byte $00
    E793: 02          .byte $02
    E794: 02          .byte $02
    E795: 02          .byte $02
    E796: 00          .byte $00
    E797: 02          .byte $02
    E798: 9A          .byte $9A
    E799: E7          .byte $E7
    E79A: 50          .byte $50
    E79B: 00          .byte $00
    E79C: 02          .byte $02
    E79D: 04          .byte $04
    E79E: 06          .byte $06
    E79F: 08          .byte $08
    E7A0: 0A          .byte $0A
    E7A1: 0C          .byte $0C
    E7A2: 0E          .byte $0E
    E7A3: 10          .byte $10
    E7A4: 12          .byte $12
    E7A5: 52          .byte $52
    E7A6: 25          .byte $25
    E7A7: D8          .byte $D8
    E7A8: 22          .byte $22
    E7A9: 41          .byte $41
    E7AA: 26          .byte $26
    E7AB: 4A          .byte $4A
    E7AC: 27          .byte $27
    E7AD: 49          .byte $49
    E7AE: 21          .byte $21
    E7AF: 42          .byte $42
    E7B0: 27          .byte $27
    E7B1: D7          .byte $D7
    E7B2: 21          .byte $21
    E7B3: 48          .byte $48
    E7B4: 23          .byte $23
    E7B5: C7          .byte $C7
    E7B6: 21          .byte $21
    E7B7: 53          .byte $53
    E7B8: 26          .byte $26
    E7B9: C5          .byte $C5
    E7BA: E7          .byte $E7
    E7BB: CD          .byte $CD
    E7BC: E7          .byte $E7
    E7BD: D5          .byte $D5
    E7BE: E7          .byte $E7
    E7BF: DD          .byte $DD
    E7C0: E7          .byte $E7
    E7C1: E5          .byte $E5
    E7C2: E7          .byte $E7
    E7C3: ED          .byte $ED
    E7C4: E7          .byte $E7
    E7C5: 02          .byte $02
    E7C6: 8C          .byte $8C
    E7C7: 8D          .byte $8D
    E7C8: 1E          .byte $1E
    E7C9: 02          .byte $02
    E7CA: 8E          .byte $8E
    E7CB: 8F          .byte $8F
    E7CC: 00          .byte $00
    E7CD: 02          .byte $02
    E7CE: 90          .byte $90
    E7CF: 91          .byte $91
    E7D0: 1E          .byte $1E
    E7D1: 02          .byte $02
    E7D2: 92          .byte $92
    E7D3: 93          .byte $93
    E7D4: 00          .byte $00
    E7D5: 02          .byte $02
    E7D6: 94          .byte $94
    E7D7: 95          .byte $95
    E7D8: 1E          .byte $1E
    E7D9: 02          .byte $02
    E7DA: 96          .byte $96
    E7DB: 97          .byte $97
    E7DC: 00          .byte $00
    E7DD: 02          .byte $02
    E7DE: 98          .byte $98
    E7DF: 99          .byte $99
    E7E0: 1E          .byte $1E
    E7E1: 02          .byte $02
    E7E2: 9A          .byte $9A
    E7E3: 9B          .byte $9B
    E7E4: 00          .byte $00
    E7E5: 02          .byte $02
    E7E6: 9C          .byte $9C
    E7E7: 9D          .byte $9D
    E7E8: 1E          .byte $1E
    E7E9: 02          .byte $02
    E7EA: 9E          .byte $9E
    E7EB: 9F          .byte $9F
    E7EC: 00          .byte $00
    E7ED: 02          .byte $02
    E7EE: 00          .byte $00
    E7EF: 00          .byte $00
    E7F0: 1E          .byte $1E
    E7F1: 02          .byte $02
    E7F2: 00          .byte $00
    E7F3: 00          .byte $00
    E7F4: 00          .byte $00

draw_item_points_sprites:
    E7F5: A9 00       lda #$00
    E7F7: 85 11       sta zp_ptr_hi   ; $11
    E7F9: 38          sec
    E7FA: E5 28       sbc camera_x_lo   ; $28
    E7FC: 85 10       sta src_ptr   ; $10
    E7FE: BD 64 02    lda item_x,x   ; $0264
    E801: E5 29       sbc camera_x   ; $29
    E803: 18          clc
    E804: 69 01       adc #$01
    E806: 06 10       asl src_ptr   ; $10
    E808: 2A          rol a
    E809: 06 10       asl src_ptr   ; $10
    E80B: 2A          rol a
    E80C: 06 10       asl src_ptr   ; $10
    E80E: 2A          rol a
    E80F: 85 10       sta src_ptr   ; $10
    E811: 90 02       bcc @E815   ; $E815
    E813: C6 11       dec zp_ptr_hi   ; $11
@E815:
    E815: BD 65 02    lda item_y,x   ; $0265
    E818: 38          sec
    E819: E9 01       sbc #$01
    E81B: 0A          asl a
    E81C: 0A          asl a
    E81D: 0A          asl a
    E81E: 85 16       sta sprite_y   ; $16
    E820: BD 61 02    lda obj_type,x   ; $0261
    E823: 4A          lsr a
    E824: 4A          lsr a
    E825: 18          clc
    E826: 69 AC       adc #$ac
    E828: 85 12       sta gfx_src_ptr   ; $12
    E82A: A9 03       lda #$03
    E82C: 85 13       sta data_ptr_hi   ; $13
    E82E: 20 4D E8    jsr draw_sprite_advance_x   ; $E84D
    E831: A9 67       lda #$67
    E833: 85 12       sta gfx_src_ptr   ; $12
    E835: 20 4D E8    jsr draw_sprite_advance_x   ; $E84D
    E838: A6 1B       ldx cur_obj_index   ; $1B
    E83A: BD 63 02    lda obj_type,x   ; $0263
    E83D: F0 22       beq @E861   ; $E861
    E83F: A9 68       lda #$68
    E841: 85 12       sta gfx_src_ptr   ; $12
    E843: 20 4D E8    jsr draw_sprite_advance_x   ; $E84D
    E846: A5 31       lda obj_record_ptr   ; $31
    E848: 18          clc
    E849: 69 B0       adc #$b0
    E84B: 85 12       sta gfx_src_ptr   ; $12

draw_sprite_advance_x:
    E84D: A9 00       lda #$00
    E84F: 85 14       sta scan_src_ptr   ; $14
    E851: 85 15       sta scratch_counter   ; $15
    E853: 20 15 C4    jsr write_sprite_to_oam   ; $C415
    E856: A5 10       lda src_ptr   ; $10
    E858: 18          clc
    E859: 69 08       adc #$08
    E85B: 85 10       sta src_ptr   ; $10
    E85D: 90 02       bcc @E861   ; $E861
    E85F: E6 11       inc zp_ptr_hi   ; $11
@E861:
    E861: 60          rts

load_round_doors:
    E862: A5 7A       lda stage_number   ; $7A
    E864: 0A          asl a
    E865: A8          tay
    E866: B9 FC EA    lda $eafc,y
    E869: 85 1C       sta aux_ptr   ; $1C
    E86B: B9 FD EA    lda $eafd,y
    E86E: 85 1D       sta aux_ptr_hi   ; $1D
    E870: A0 00       ldy #$00
    E872: B1 1C       lda (aux_ptr),y   ; $1C
    E874: 85 83       sta object_count   ; $83
    E876: F0 53       beq @E8CB   ; $E8CB
    E878: C8          iny
    E879: A2 00       ldx #$00
@E87B:
    E87B: 86 1B       stx cur_obj_index   ; $1B
    E87D: A9 00       lda #$00
    E87F: 9D B0 02    sta obj_anim_timer,x   ; $02B0
    E882: 9D B6 02    sta $02b6,x
    E885: B1 1C       lda (aux_ptr),y   ; $1C
    E887: C8          iny
    E888: 9D B1 02    sta obj_state,x   ; $02B1
    E88B: B1 1C       lda (aux_ptr),y   ; $1C
    E88D: C8          iny
    E88E: 9D B2 02    sta $02b2,x
    E891: 85 10       sta src_ptr   ; $10
    E893: B1 1C       lda (aux_ptr),y   ; $1C
    E895: C8          iny
    E896: 9D B3 02    sta $02b3,x
    E899: 85 11       sta zp_ptr_hi   ; $11
    E89B: 20 BD E3    jsr ppu_addr_to_tile_xy   ; $E3BD
    E89E: A5 10       lda src_ptr   ; $10
    E8A0: 9D B4 02    sta obj_pos,x   ; $02B4
    E8A3: A5 11       lda zp_ptr_hi   ; $11
    E8A5: 9D B5 02    sta obj_x,x   ; $02B5
    E8A8: A5 1B       lda cur_obj_index   ; $1B
    E8AA: 18          clc
    E8AB: 69 08       adc #$08
    E8AD: AA          tax
    E8AE: E4 83       cpx object_count   ; $83
    E8B0: D0 C9       bne @E87B   ; $E87B

close_and_draw_doors:
    E8B2: A2 00       ldx #$00
@E8B4:
    E8B4: 86 1B       stx cur_obj_index   ; $1B
    E8B6: BD B1 02    lda obj_state,x   ; $02B1
    E8B9: 29 FC       and #$fc
    E8BB: 9D B1 02    sta obj_state,x   ; $02B1
    E8BE: 20 FF E8    jsr draw_door   ; $E8FF
    E8C1: A5 1B       lda cur_obj_index   ; $1B
    E8C3: 18          clc
    E8C4: 69 08       adc #$08
    E8C6: AA          tax
    E8C7: E4 83       cpx object_count   ; $83
    E8C9: D0 E9       bne @E8B4   ; $E8B4
@E8CB:
    E8CB: 60          rts

update_doors:
    E8CC: A5 83       lda object_count   ; $83
    E8CE: F0 FB       beq @E8CB   ; $E8CB
    E8D0: A2 00       ldx #$00
@E8D2:
    E8D2: 86 1B       stx cur_obj_index   ; $1B
    E8D4: 20 1D E9    jsr animate_door_swing   ; $E91D
    E8D7: A5 1B       lda cur_obj_index   ; $1B
    E8D9: 18          clc
    E8DA: 69 08       adc #$08
    E8DC: AA          tax
    E8DD: E4 83       cpx object_count   ; $83
    E8DF: D0 F1       bne @E8D2   ; $E8D2
    E8E1: A5 21       lda frame_counter   ; $21
    E8E3: 29 03       and #$03
    E8E5: 0A          asl a
    E8E6: 0A          asl a
    E8E7: 0A          asl a
    E8E8: AA          tax
    E8E9: BD B0 02    lda obj_anim_timer,x   ; $02B0
    E8EC: D0 DD       bne @E8CB   ; $E8CB
    E8EE: BD B1 02    lda obj_state,x   ; $02B1
    E8F1: 29 0A       and #$0a
    E8F3: 49 08       eor #$08
    E8F5: D0 D4       bne @E8CB   ; $E8CB
    E8F7: A0 10       ldy #$10
    E8F9: A5 21       lda frame_counter   ; $21
    E8FB: 29 04       and #$04
    E8FD: F0 03       beq draw_door_kind_y   ; $E902

draw_door:
    E8FF: BC B1 02    ldy obj_state,x   ; $02B1

draw_door_kind_y:
    E902: BD B2 02    lda $02b2,x
    E905: 85 10       sta src_ptr   ; $10
    E907: BD B3 02    lda $02b3,x
    E90A: 85 11       sta zp_ptr_hi   ; $11
    E90C: B9 4F EC    lda $ec4f,y
    E90F: 85 12       sta gfx_src_ptr   ; $12
    E911: B9 50 EC    lda $ec50,y
    E914: 85 13       sta data_ptr_hi   ; $13
    E916: A9 80       lda #$80
    E918: 85 14       sta scan_src_ptr   ; $14
    E91A: 4C FB C6    jmp draw_rle_text   ; $C6FB

animate_door_swing:
    E91D: BD B0 02    lda obj_anim_timer,x   ; $02B0
    E920: F0 20       beq @E942   ; $E942
    E922: FE B6 02    inc $02b6,x
    E925: BD B6 02    lda $02b6,x
    E928: C9 05       cmp #$05
    E92A: 90 17       bcc @E943   ; $E943
    E92C: A9 00       lda #$00
    E92E: 9D B0 02    sta obj_anim_timer,x   ; $02B0
    E931: 9D B6 02    sta $02b6,x
    E934: BD B1 02    lda obj_state,x   ; $02B1
    E937: 29 06       and #$06
    E939: 49 02       eor #$02
    E93B: 9D B1 02    sta obj_state,x   ; $02B1
    E93E: 29 02       and #$02
    E940: F0 BD       beq draw_door   ; $E8FF
@E942:
    E942: 60          rts
@E943:
    E943: 0A          asl a
    E944: 85 10       sta src_ptr   ; $10
    E946: 20 4D E9    jsr door_swing_frame   ; $E94D
    E949: A8          tay
    E94A: 4C 02 E9    jmp draw_door_kind_y   ; $E902

door_swing_frame:
    E94D: BD B1 02    lda obj_state,x   ; $02B1
    E950: 29 06       and #$06
    E952: F0 0C       beq @E960   ; $E960
    E954: C9 04       cmp #$04
    E956: 90 0E       bcc @E966   ; $E966
    E958: F0 12       beq @E96C   ; $E96C
    E95A: A9 22       lda #$22
    E95C: 38          sec
    E95D: E5 10       sbc src_ptr   ; $10
    E95F: 60          rts
@E960:
    E960: A5 10       lda src_ptr   ; $10
    E962: 18          clc
    E963: 69 10       adc #$10
    E965: 60          rts
@E966:
    E966: A9 1A       lda #$1a
    E968: 38          sec
    E969: E5 10       sbc src_ptr   ; $10
    E96B: 60          rts
@E96C:
    E96C: A5 10       lda src_ptr   ; $10
    E96E: 18          clc
    E96F: 69 18       adc #$18
@E971:
    E971: 60          rts

player_opens_nearest_door:
    E972: A5 83       lda object_count   ; $83
    E974: F0 FB       beq @E971   ; $E971
    E976: A0 0E       ldy #$0e
    E978: B1 1E       lda (obj_record_ptr),y   ; $1E
    E97A: 29 03       and #$03
    E97C: C9 01       cmp #$01
    E97E: D0 F1       bne @E971   ; $E971
    E980: A0 00       ldy #$00
    E982: A2 00       ldx #$00
@E984:
    E984: 20 B8 E9    jsr add_door_if_in_reach   ; $E9B8
    E987: 8A          txa
    E988: 18          clc
    E989: 69 08       adc #$08
    E98B: AA          tax
    E98C: E4 83       cpx object_count   ; $83
    E98E: D0 F4       bne @E984   ; $E984
    E990: 88          dey
    E991: 30 DE       bmi @E971   ; $E971
@E993:
    E993: B9 12 00    lda gfx_src_ptr,y   ; $0012
    E996: 88          dey
    E997: B6 12       ldx gfx_src_ptr,y   ; $12
@E999:
    E999: 88          dey
    E99A: 30 08       bmi open_door   ; $E9A4
    E99C: D9 12 00    cmp gfx_src_ptr,y   ; $0012
    E99F: B0 F2       bcs @E993   ; $E993
    E9A1: 88          dey
    E9A2: 90 F5       bcc @E999   ; $E999

open_door:
    E9A4: A9 01       lda #$01
    E9A6: 9D B0 02    sta obj_anim_timer,x   ; $02B0
    E9A9: 20 05 EA    jsr door_knock_back_objects   ; $EA05
    E9AC: BD B1 02    lda obj_state,x   ; $02B1
    E9AF: 29 0A       and #$0a
    E9B1: 49 08       eor #$08
    E9B3: D0 BC       bne @E971   ; $E971
    E9B5: 4C 04 EE    jmp launch_door_wave   ; $EE04

add_door_if_in_reach:
    E9B8: 84 11       sty zp_ptr_hi   ; $11
    E9BA: A5 1E       lda obj_record_ptr   ; $1E
    E9BC: 9D B7 02    sta obj_contact_state,x   ; $02B7
    E9BF: D0 0A       bne @E9CB   ; $E9CB
    E9C1: BD B4 02    lda obj_pos,x   ; $02B4
    E9C4: 38          sec
    E9C5: E5 29       sbc camera_x   ; $29
    E9C7: C9 21       cmp #$21
    E9C9: B0 20       bcs @E9EB   ; $E9EB
@E9CB:
    E9CB: A0 03       ldy #$03
    E9CD: B1 1E       lda (obj_record_ptr),y   ; $1E
    E9CF: 38          sec
    E9D0: FD B5 02    sbc obj_x,x   ; $02B5
    E9D3: C9 02       cmp #$02
    E9D5: B0 14       bcs @E9EB   ; $E9EB
    E9D7: A0 01       ldy #$01
    E9D9: B1 1E       lda (obj_record_ptr),y   ; $1E
    E9DB: 38          sec
    E9DC: FD B4 02    sbc obj_pos,x   ; $02B4
    E9DF: 85 10       sta src_ptr   ; $10
    E9E1: A0 06       ldy #$06
    E9E3: B1 1E       lda (obj_record_ptr),y   ; $1E
    E9E5: 30 07       bmi @E9EE   ; $E9EE
    E9E7: E6 10       inc src_ptr   ; $10
    E9E9: 30 07       bmi @E9F2   ; $E9F2
@E9EB:
    E9EB: A4 11       ldy zp_ptr_hi   ; $11
    E9ED: 60          rts
@E9EE:
    E9EE: A5 10       lda src_ptr   ; $10
    E9F0: 30 F9       bmi @E9EB   ; $E9EB
@E9F2:
    E9F2: A4 11       ldy zp_ptr_hi   ; $11
    E9F4: 96 12       stx gfx_src_ptr,y   ; $12
    E9F6: C8          iny
    E9F7: A5 10       lda src_ptr   ; $10
    E9F9: 10 05       bpl @EA00   ; $EA00
    E9FB: A9 00       lda #$00
    E9FD: 38          sec
    E9FE: E5 10       sbc src_ptr   ; $10
@EA00:
    EA00: 99 12 00    sta gfx_src_ptr,y   ; $0012
    EA03: C8          iny
    EA04: 60          rts

door_knock_back_objects:
    EA05: BD B1 02    lda obj_state,x   ; $02B1
    EA08: 29 06       and #$06
    EA0A: A8          tay
    EA0B: B9 49 EA    lda $ea49,y
    EA0E: 85 1C       sta aux_ptr   ; $1C
    EA10: B9 4A EA    lda $ea4a,y
    EA13: 85 1D       sta aux_ptr_hi   ; $1D
    EA15: A0 00       ldy #$00
@EA17:
    EA17: C0 10       cpy #$10
    EA19: F0 21       beq @EA3C   ; $EA3C
    EA1B: B9 04 04    lda $0404,y
    EA1E: F0 1C       beq @EA3C   ; $EA3C
    EA20: B9 0F 04    lda $040f,y
    EA23: C9 16       cmp #$16
    EA25: F0 15       beq @EA3C   ; $EA3C
    EA27: B9 03 04    lda $0403,y
    EA2A: 38          sec
    EA2B: FD B5 02    sbc obj_x,x   ; $02B5
    EA2E: C9 02       cmp #$02
    EA30: B0 0A       bcs @EA3C   ; $EA3C
    EA32: BD B4 02    lda obj_pos,x   ; $02B4
    EA35: 38          sec
    EA36: F9 01 04    sbc $0401,y
    EA39: 20 46 EA    jsr jmp_indirect_zp_vector   ; $EA46
@EA3C:
    EA3C: 98          tya
    EA3D: 18          clc
    EA3E: 69 10       adc #$10
    EA40: A8          tay
    EA41: C0 90       cpy #$90
    EA43: D0 D2       bne @EA17   ; $EA17
    EA45: 60          rts

jmp_indirect_zp_vector:
    EA46: 6C 1C 00    jmp (aux_ptr)   ; $001C
    EA49:            .word door_kind0_knock_back
    EA4B:            .word door_kind1_knock_back
    EA4D:            .word door_kind2_knock_back
    EA4F:            .word door_kind3_knock_back

door_kind1_knock_back:
    EA51: 18          clc
    EA52: 69 01       adc #$01
    EA54: C9 04       cmp #$04
    EA56: 90 18       bcc @EA70   ; $EA70
    EA58: 60          rts

door_kind3_knock_back:
    EA59: C9 04       cmp #$04
    EA5B: 4C 63 EA    jmp knock_back_right_if_in_range   ; $EA63

door_kind0_knock_back:
    EA5E: 18          clc
    EA5F: 69 02       adc #$02
    EA61: C9 03       cmp #$03

knock_back_right_if_in_range:
    EA63: B0 2A       bcs @EA8F   ; $EA8F
    EA65: A9 01       lda #$01
    EA67: 90 09       bcc @EA72   ; $EA72

door_kind2_knock_back:
    EA69: 38          sec
    EA6A: E9 02       sbc #$02
    EA6C: C9 03       cmp #$03
    EA6E: B0 1F       bcs @EA8F   ; $EA8F
@EA70:
    EA70: A9 FF       lda #$ff
@EA72:
    EA72: 99 06 04    sta $0406,y
    EA75: A9 0C       lda #$0c
    EA77: 99 04 04    sta $0404,y
    EA7A: A9 10       lda #$10
    EA7C: 99 0F 04    sta $040f,y
    EA7F: A9 08       lda #$08
    EA81: 99 07 04    sta $0407,y
    EA84: C0 00       cpy #$00
    EA86: F0 07       beq @EA8F   ; $EA8F
    EA88: BD B7 02    lda obj_contact_state,x   ; $02B7
    EA8B: D0 02       bne @EA8F   ; $EA8F
    EA8D: E6 30       inc pending_score_count   ; $30
@EA8F:
    EA8F: 60          rts

walker_meets_closed_door:
    EA90: A9 00       lda #$00
    EA92: A0 09       ldy #$09
    EA94: 91 1E       sta (obj_record_ptr),y   ; $1E
    EA96: A2 00       ldx #$00
@EA98:
    EA98: BD B0 02    lda obj_anim_timer,x   ; $02B0
    EA9B: D0 4B       bne @EAE8   ; $EAE8
    EA9D: BD B1 02    lda obj_state,x   ; $02B1
    EAA0: 29 02       and #$02
    EAA2: D0 44       bne @EAE8   ; $EAE8
    EAA4: A0 03       ldy #$03
    EAA6: B1 1E       lda (obj_record_ptr),y   ; $1E
    EAA8: 38          sec
    EAA9: FD B5 02    sbc obj_x,x   ; $02B5
    EAAC: C9 02       cmp #$02
    EAAE: B0 38       bcs @EAE8   ; $EAE8
    EAB0: A0 06       ldy #$06
    EAB2: B1 1E       lda (obj_record_ptr),y   ; $1E
    EAB4: 30 28       bmi @EADE   ; $EADE
    EAB6: BD B4 02    lda obj_pos,x   ; $02B4
    EAB9: 38          sec
    EABA: A0 01       ldy #$01
    EABC: F1 1E       sbc (obj_record_ptr),y   ; $1E
    EABE: C9 02       cmp #$02
    EAC0: D0 26       bne @EAE8   ; $EAE8
@EAC2:
    EAC2: A5 1E       lda obj_record_ptr   ; $1E
    EAC4: 9D B7 02    sta obj_contact_state,x   ; $02B7
    EAC7: F0 0E       beq @EAD7   ; $EAD7
    EAC9: C9 20       cmp #$20
    EACB: 90 07       bcc @EAD4   ; $EAD4
    EACD: BD B1 02    lda obj_state,x   ; $02B1
    EAD0: 29 08       and #$08
    EAD2: D0 1E       bne @EAF2   ; $EAF2
@EAD4:
    EAD4: 20 A4 E9    jsr open_door   ; $E9A4
@EAD7:
    EAD7: A9 01       lda #$01
    EAD9: A0 09       ldy #$09
    EADB: 91 1E       sta (obj_record_ptr),y   ; $1E
    EADD: 60          rts
@EADE:
    EADE: BD B4 02    lda obj_pos,x   ; $02B4
    EAE1: 38          sec
    EAE2: A0 01       ldy #$01
    EAE4: D1 1E       cmp (obj_record_ptr),y   ; $1E
    EAE6: F0 DA       beq @EAC2   ; $EAC2
@EAE8:
    EAE8: 8A          txa
    EAE9: 18          clc
    EAEA: 69 08       adc #$08
    EAEC: AA          tax
    EAED: E4 83       cpx object_count   ; $83
    EAEF: D0 A7       bne @EA98   ; $EA98
    EAF1: 60          rts
@EAF2:
    EAF2: A0 06       ldy #$06
    EAF4: 38          sec
    EAF5: A9 00       lda #$00
    EAF7: F1 1E       sbc (obj_record_ptr),y   ; $1E
    EAF9: 91 1E       sta (obj_record_ptr),y   ; $1E
    EAFB: 60          rts
    EAFC: 1C          .byte $1C
    EAFD: EB          .byte $EB
    EAFE: 3B          .byte $3B
    EAFF: EB          .byte $EB
    EB00: 4E          .byte $4E
    EB01: EC          .byte $EC
    EB02: 5A          .byte $5A
    EB03: EB          .byte $EB
    EB04: 73          .byte $73
    EB05: EB          .byte $EB
    EB06: 8C          .byte $8C
    EB07: EB          .byte $EB
    EB08: 4E          .byte $4E
    EB09: EC          .byte $EC
    EB0A: A8          .byte $A8
    EB0B: EB          .byte $EB
    EB0C: C4          .byte $C4
    EB0D: EB          .byte $EB
    EB0E: DD          .byte $DD
    EB0F: EB          .byte $EB
    EB10: 4E          .byte $4E
    EB11: EC          .byte $EC
    EB12: F3          .byte $F3
    EB13: EB          .byte $EB
    EB14: 09          .byte $09
    EB15: EC          .byte $EC
    EB16: 22          .byte $22
    EB17: EC          .byte $EC
    EB18: 4E          .byte $4E
    EB19: EC          .byte $EC
    EB1A: 2F          .byte $2F
    EB1B: EC          .byte $EC
    EB1C: 50          .byte $50
    EB1D: 08          .byte $08
    EB1E: AC          .byte $AC
    EB1F: 21          .byte $21
    EB20: 08          .byte $08
    EB21: 2C          .byte $2C
    EB22: 23          .byte $23
    EB23: 0C          .byte $0C
    EB24: 2F          .byte $2F
    EB25: 25          .byte $25
    EB26: 0C          .byte $0C
    EB27: AF          .byte $AF
    EB28: 26          .byte $26
    EB29: 00          .byte $00
    EB2A: 2C          .byte $2C
    EB2B: 21          .byte $21
    EB2C: 00          .byte $00
    EB2D: BD          .byte $BD
    EB2E: 21          .byte $21
    EB2F: 00          .byte $00
    EB30: AC          .byte $AC
    EB31: 22          .byte $22
    EB32: 04          .byte $04
    EB33: BD          .byte $BD
    EB34: 22          .byte $22
    EB35: 04          .byte $04
    EB36: 3D          .byte $3D
    EB37: 23          .byte $23
    EB38: 04          .byte $04
    EB39: 2F          .byte $2F
    EB3A: 26          .byte $26
    EB3B: 50          .byte $50
    EB3C: 08          .byte $08
    EB3D: 2C          .byte $2C
    EB3E: 22          .byte $22
    EB3F: 08          .byte $08
    EB40: 2C          .byte $2C
    EB41: 23          .byte $23
    EB42: 0C          .byte $0C
    EB43: 2F          .byte $2F
    EB44: 25          .byte $25
    EB45: 0C          .byte $0C
    EB46: 2F          .byte $2F
    EB47: 27          .byte $27
    EB48: 00          .byte $00
    EB49: 2C          .byte $2C
    EB4A: 21          .byte $21
    EB4B: 00          .byte $00
    EB4C: AC          .byte $AC
    EB4D: 22          .byte $22
    EB4E: 00          .byte $00
    EB4F: 3D          .byte $3D
    EB50: 23          .byte $23
    EB51: 00          .byte $00
    EB52: 2A          .byte $2A
    EB53: 26          .byte $26
    EB54: 04          .byte $04
    EB55: 3D          .byte $3D
    EB56: 22          .byte $22
    EB57: 04          .byte $04
    EB58: A5          .byte $A5
    EB59: 25          .byte $25
    EB5A: 40          .byte $40
    EB5B: 08          .byte $08
    EB5C: 2C          .byte $2C
    EB5D: 21          .byte $21
    EB5E: 08          .byte $08
    EB5F: 2C          .byte $2C
    EB60: 23          .byte $23
    EB61: 0C          .byte $0C
    EB62: B0          .byte $B0
    EB63: 25          .byte $25
    EB64: 0C          .byte $0C
    EB65: B0          .byte $B0
    EB66: 26          .byte $26
    EB67: 00          .byte $00
    EB68: 25          .byte $25
    EB69: 27          .byte $27
    EB6A: 04          .byte $04
    EB6B: 2B          .byte $2B
    EB6C: 22          .byte $22
    EB6D: 04          .byte $04
    EB6E: 2F          .byte $2F
    EB6F: 25          .byte $25
    EB70: 04          .byte $04
    EB71: 30          .byte $30
    EB72: 26          .byte $26
    EB73: 40          .byte $40
    EB74: 08          .byte $08
    EB75: AB          .byte $AB
    EB76: 21          .byte $21
    EB77: 08          .byte $08
    EB78: AB          .byte $AB
    EB79: 22          .byte $22
    EB7A: 0C          .byte $0C
    EB7B: B0          .byte $B0
    EB7C: 25          .byte $25
    EB7D: 0C          .byte $0C
    EB7E: B0          .byte $B0
    EB7F: 26          .byte $26
    EB80: 00          .byte $00
    EB81: 26          .byte $26
    EB82: 22          .byte $22
    EB83: 00          .byte $00
    EB84: 2A          .byte $2A
    EB85: 25          .byte $25
    EB86: 04          .byte $04
    EB87: 2F          .byte $2F
    EB88: 27          .byte $27
    EB89: 04          .byte $04
    EB8A: 31          .byte $31
    EB8B: 23          .byte $23
    EB8C: 48          .byte $48
    EB8D: 08          .byte $08
    EB8E: 2C          .byte $2C
    EB8F: 21          .byte $21
    EB90: 08          .byte $08
    EB91: 2C          .byte $2C
    EB92: 23          .byte $23
    EB93: 0C          .byte $0C
    EB94: 2F          .byte $2F
    EB95: 25          .byte $25
    EB96: 0C          .byte $0C
    EB97: B0          .byte $B0
    EB98: 26          .byte $26
    EB99: 00          .byte $00
    EB9A: AB          .byte $AB
    EB9B: 21          .byte $21
    EB9C: 00          .byte $00
    EB9D: A6          .byte $A6
    EB9E: 22          .byte $22
    EB9F: 00          .byte $00
    EBA0: 25          .byte $25
    EBA1: 27          .byte $27
    EBA2: 04          .byte $04
    EBA3: B5          .byte $B5
    EBA4: 25          .byte $25
    EBA5: 04          .byte $04
    EBA6: 30          .byte $30
    EBA7: 26          .byte $26
    EBA8: 48          .byte $48
    EBA9: 08          .byte $08
    EBAA: AC          .byte $AC
    EBAB: 21          .byte $21
    EBAC: 08          .byte $08
    EBAD: 39          .byte $39
    EBAE: 22          .byte $22
    EBAF: 08          .byte $08
    EBB0: 2C          .byte $2C
    EBB1: 23          .byte $23
    EBB2: 0C          .byte $0C
    EBB3: AF          .byte $AF
    EBB4: 26          .byte $26
    EBB5: 00          .byte $00
    EBB6: 26          .byte $26
    EBB7: 22          .byte $22
    EBB8: 00          .byte $00
    EBB9: 3D          .byte $3D
    EBBA: 23          .byte $23
    EBBB: 04          .byte $04
    EBBC: 2F          .byte $2F
    EBBD: 27          .byte $27
    EBBE: 04          .byte $04
    EBBF: 2F          .byte $2F
    EBC0: 25          .byte $25
    EBC1: 04          .byte $04
    EBC2: B5          .byte $B5
    EBC3: 25          .byte $25
    EBC4: 40          .byte $40
    EBC5: 08          .byte $08
    EBC6: 2C          .byte $2C
    EBC7: 23          .byte $23
    EBC8: 08          .byte $08
    EBC9: AF          .byte $AF
    EBCA: 25          .byte $25
    EBCB: 0C          .byte $0C
    EBCC: 39          .byte $39
    EBCD: 22          .byte $22
    EBCE: 0C          .byte $0C
    EBCF: 2F          .byte $2F
    EBD0: 25          .byte $25
    EBD1: 00          .byte $00
    EBD2: 2C          .byte $2C
    EBD3: 22          .byte $22
    EBD4: 00          .byte $00
    EBD5: A6          .byte $A6
    EBD6: 22          .byte $22
    EBD7: 00          .byte $00
    EBD8: AF          .byte $AF
    EBD9: 26          .byte $26
    EBDA: 04          .byte $04
    EBDB: 3D          .byte $3D
    EBDC: 23          .byte $23
    EBDD: 38          .byte $38
    EBDE: 0C          .byte $0C
    EBDF: AC          .byte $AC
    EBE0: 21          .byte $21
    EBE1: 0C          .byte $0C
    EBE2: 39          .byte $39
    EBE3: 22          .byte $22
    EBE4: 0C          .byte $0C
    EBE5: 3D          .byte $3D
    EBE6: 23          .byte $23
    EBE7: 0C          .byte $0C
    EBE8: AF          .byte $AF
    EBE9: 25          .byte $25
    EBEA: 00          .byte $00
    EBEB: 2C          .byte $2C
    EBEC: 22          .byte $22
    EBED: 00          .byte $00
    EBEE: A6          .byte $A6
    EBEF: 22          .byte $22
    EBF0: 00          .byte $00
    EBF1: 2F          .byte $2F
    EBF2: 26          .byte $26
    EBF3: 38          .byte $38
    EBF4: 08          .byte $08
    EBF5: 30          .byte $30
    EBF6: 21          .byte $21
    EBF7: 08          .byte $08
    EBF8: 35          .byte $35
    EBF9: 23          .byte $23
    EBFA: 08          .byte $08
    EBFB: A6          .byte $A6
    EBFC: 25          .byte $25
    EBFD: 0C          .byte $0C
    EBFE: 35          .byte $35
    EBFF: 22          .byte $22
    EC00: 00          .byte $00
    EC01: A6          .byte $A6
    EC02: 26          .byte $26
    EC03: 00          .byte $00
    EC04: 26          .byte $26
    EC05: 27          .byte $27
    EC06: 04          .byte $04
    EC07: 26          .byte $26
    EC08: 25          .byte $25
    EC09: 40          .byte $40
    EC0A: 08          .byte $08
    EC0B: 30          .byte $30
    EC0C: 21          .byte $21
    EC0D: 08          .byte $08
    EC0E: 26          .byte $26
    EC0F: 26          .byte $26
    EC10: 0C          .byte $0C
    EC11: 35          .byte $35
    EC12: 23          .byte $23
    EC13: 0C          .byte $0C
    EC14: 2B          .byte $2B
    EC15: 25          .byte $25
    EC16: 00          .byte $00
    EC17: 30          .byte $30
    EC18: 22          .byte $22
    EC19: 00          .byte $00
    EC1A: A6          .byte $A6
    EC1B: 22          .byte $22
    EC1C: 00          .byte $00
    EC1D: 26          .byte $26
    EC1E: 27          .byte $27
    EC1F: 04          .byte $04
    EC20: AB          .byte $AB
    EC21: 25          .byte $25
    EC22: 20          .byte $20
    EC23: 08          .byte $08
    EC24: 35          .byte $35
    EC25: 21          .byte $21
    EC26: 08          .byte $08
    EC27: 26          .byte $26
    EC28: 25          .byte $25
    EC29: 08          .byte $08
    EC2A: A6          .byte $A6
    EC2B: 26          .byte $26
    EC2C: 0C          .byte $0C
    EC2D: B5          .byte $B5
    EC2E: 22          .byte $22
    EC2F: 50          .byte $50
    EC30: 08          .byte $08
    EC31: BD          .byte $BD
    EC32: 22          .byte $22
    EC33: 08          .byte $08
    EC34: 2C          .byte $2C
    EC35: 23          .byte $23
    EC36: 0C          .byte $0C
    EC37: 2F          .byte $2F
    EC38: 27          .byte $27
    EC39: 0C          .byte $0C
    EC3A: BD          .byte $BD
    EC3B: 21          .byte $21
    EC3C: 00          .byte $00
    EC3D: 2C          .byte $2C
    EC3E: 21          .byte $21
    EC3F: 00          .byte $00
    EC40: 2C          .byte $2C
    EC41: 22          .byte $22
    EC42: 00          .byte $00
    EC43: A6          .byte $A6
    EC44: 22          .byte $22
    EC45: 00          .byte $00
    EC46: AA          .byte $AA
    EC47: 26          .byte $26
    EC48: 04          .byte $04
    EC49: 2F          .byte $2F
    EC4A: 25          .byte $25
    EC4B: 04          .byte $04
    EC4C: 2F          .byte $2F
    EC4D: 26          .byte $26
    EC4E: 00          .byte $00
    EC4F: 71          .byte $71
    EC50: EC          .byte $EC
    EC51: C5          .byte $C5
    EC52: EC          .byte $EC
    EC53: 7A          .byte $7A
    EC54: EC          .byte $EC
    EC55: 01          .byte $01
    EC56: ED          .byte $ED
    EC57: 83          .byte $83
    EC58: EC          .byte $EC
    EC59: C5          .byte $C5
    EC5A: EC          .byte $EC
    EC5B: 8C          .byte $8C
    EC5C: EC          .byte $EC
    EC5D: 01          .byte $01
    EC5E: ED          .byte $ED
    EC5F: 95          .byte $95
    EC60: EC          .byte $EC
    EC61: 9E          .byte $9E
    EC62: EC          .byte $EC
    EC63: AA          .byte $AA
    EC64: EC          .byte $EC
    EC65: B6          .byte $B6
    EC66: EC          .byte $EC
    EC67: C5          .byte $C5
    EC68: EC          .byte $EC
    EC69: D4          .byte $D4
    EC6A: EC          .byte $EC
    EC6B: E2          .byte $E2
    EC6C: EC          .byte $EC
    EC6D: F0          .byte $F0
    EC6E: EC          .byte $EC
    EC6F: 01          .byte $01
    EC70: ED          .byte $ED
    EC71: 01          .byte $01
    EC72: 56          .byte $56
    EC73: 1F          .byte $1F
    EC74: 01          .byte $01
    EC75: 58          .byte $58
    EC76: 1F          .byte $1F
    EC77: 01          .byte $01
    EC78: 56          .byte $56
    EC79: 00          .byte $00
    EC7A: 01          .byte $01
    EC7B: 56          .byte $56
    EC7C: 1F          .byte $1F
    EC7D: 01          .byte $01
    EC7E: 57          .byte $57
    EC7F: 1F          .byte $1F
    EC80: 01          .byte $01
    EC81: 56          .byte $56
    EC82: 00          .byte $00
    EC83: 01          .byte $01
    EC84: 53          .byte $53
    EC85: 1F          .byte $1F
    EC86: 01          .byte $01
    EC87: 55          .byte $55
    EC88: 1F          .byte $1F
    EC89: 01          .byte $01
    EC8A: 53          .byte $53
    EC8B: 00          .byte $00
    EC8C: 01          .byte $01
    EC8D: 53          .byte $53
    EC8E: 1F          .byte $1F
    EC8F: 01          .byte $01
    EC90: 54          .byte $54
    EC91: 1F          .byte $1F
    EC92: 01          .byte $01
    EC93: 53          .byte $53
    EC94: 00          .byte $00
    EC95: 01          .byte $01
    EC96: 52          .byte $52
    EC97: 1F          .byte $1F
    EC98: 01          .byte $01
    EC99: 52          .byte $52
    EC9A: 1F          .byte $1F
    EC9B: 01          .byte $01
    EC9C: 52          .byte $52
    EC9D: 00          .byte $00
    EC9E: 02          .byte $02
    EC9F: 87          .byte $87
    ECA0: 00          .byte $00
    ECA1: 1E          .byte $1E
    ECA2: 02          .byte $02
    ECA3: 87          .byte $87
    ECA4: 00          .byte $00
    ECA5: 1E          .byte $1E
    ECA6: 02          .byte $02
    ECA7: 87          .byte $87
    ECA8: 00          .byte $00
    ECA9: 00          .byte $00
    ECAA: 02          .byte $02
    ECAB: 87          .byte $87
    ECAC: 89          .byte $89
    ECAD: 1E          .byte $1E
    ECAE: 02          .byte $02
    ECAF: 87          .byte $87
    ECB0: 89          .byte $89
    ECB1: 1E          .byte $1E
    ECB2: 02          .byte $02
    ECB3: 87          .byte $87
    ECB4: 89          .byte $89
    ECB5: 00          .byte $00
    ECB6: 03          .byte $03
    ECB7: 87          .byte $87
    ECB8: 88          .byte $88
    ECB9: 00          .byte $00
    ECBA: 1D          .byte $1D
    ECBB: 03          .byte $03
    ECBC: 87          .byte $87
    ECBD: 88          .byte $88
    ECBE: 00          .byte $00
    ECBF: 1D          .byte $1D
    ECC0: 03          .byte $03
    ECC1: 87          .byte $87
    ECC2: 88          .byte $88
    ECC3: 00          .byte $00
    ECC4: 00          .byte $00
    ECC5: 03          .byte $03
    ECC6: 87          .byte $87
    ECC7: 88          .byte $88
    ECC8: 89          .byte $89
    ECC9: 1D          .byte $1D
    ECCA: 03          .byte $03
    ECCB: 87          .byte $87
    ECCC: 88          .byte $88
    ECCD: 89          .byte $89
    ECCE: 1D          .byte $1D
    ECCF: 03          .byte $03
    ECD0: 87          .byte $87
    ECD1: 88          .byte $88
    ECD2: 89          .byte $89
    ECD3: 00          .byte $00
    ECD4: 00          .byte $00
    ECD5: FF          .byte $FF
    ECD6: 02          .byte $02
    ECD7: 00          .byte $00
    ECD8: 89          .byte $89
    ECD9: 1E          .byte $1E
    ECDA: 02          .byte $02
    ECDB: 00          .byte $00
    ECDC: 89          .byte $89
    ECDD: 1E          .byte $1E
    ECDE: 02          .byte $02
    ECDF: 00          .byte $00
    ECE0: 89          .byte $89
    ECE1: 00          .byte $00
    ECE2: 00          .byte $00
    ECE3: FF          .byte $FF
    ECE4: 02          .byte $02
    ECE5: 87          .byte $87
    ECE6: 89          .byte $89
    ECE7: 1E          .byte $1E
    ECE8: 02          .byte $02
    ECE9: 87          .byte $87
    ECEA: 89          .byte $89
    ECEB: 1E          .byte $1E
    ECEC: 02          .byte $02
    ECED: 87          .byte $87
    ECEE: 89          .byte $89
    ECEF: 00          .byte $00
    ECF0: 00          .byte $00
    ECF1: FE          .byte $FE
    ECF2: 03          .byte $03
    ECF3: 00          .byte $00
    ECF4: 88          .byte $88
    ECF5: 89          .byte $89
    ECF6: 1D          .byte $1D
    ECF7: 03          .byte $03
    ECF8: 00          .byte $00
    ECF9: 88          .byte $88
    ECFA: 89          .byte $89
    ECFB: 1D          .byte $1D
    ECFC: 03          .byte $03
    ECFD: 00          .byte $00
    ECFE: 88          .byte $88
    ECFF: 89          .byte $89
    ED00: 00          .byte $00
    ED01: 00          .byte $00
    ED02: FE          .byte $FE
    ED03: 03          .byte $03
    ED04: 87          .byte $87
    ED05: 88          .byte $88
    ED06: 89          .byte $89
    ED07: 1D          .byte $1D
    ED08: 03          .byte $03
    ED09: 87          .byte $87
    ED0A: 88          .byte $88
    ED0B: 89          .byte $89
    ED0C: 1D          .byte $1D
    ED0D: 03          .byte $03
    ED0E: 87          .byte $87
    ED0F: 88          .byte $88
    ED10: 89          .byte $89
    ED11: 00          .byte $00
@ED12:
    ED12: A9 60       lda #$60
    ED14: 20 4D EE    jsr move_record_x_by_direction   ; $EE4D
    ED17: 20 05 C3    jsr draw_object   ; $C305
    ED1A: D0 31       bne @ED4D   ; $ED4D

end_door_wave:
    ED1C: A9 30       lda #$30
    ED1E: 85 4C       sta respawn_slot   ; $4C
    ED20: A9 00       lda #$00
    ED22: A0 05       ldy #$05
    ED24: 91 1E       sta (obj_record_ptr),y   ; $1E
    ED26: A0 04       ldy #$04
    ED28: 91 1E       sta (obj_record_ptr),y   ; $1E
    ED2A: A2 20       ldx #$20
@ED2C:
    ED2C: BD 0B 04    lda $040b,x
    ED2F: C5 1E       cmp obj_record_ptr   ; $1E
    ED31: D0 11       bne @ED44   ; $ED44
    ED33: BD 0F 04    lda $040f,x
    ED36: C9 18       cmp #$18
    ED38: D0 0A       bne @ED44   ; $ED44
    ED3A: A9 1A       lda #$1a
    ED3C: 9D 0F 04    sta $040f,x
    ED3F: A9 3C       lda #$3c
    ED41: 9D 07 04    sta $0407,x
@ED44:
    ED44: 8A          txa
    ED45: 18          clc
    ED46: 69 10       adc #$10
    ED48: AA          tax
    ED49: E0 90       cpx #$90
    ED4B: D0 DF       bne @ED2C   ; $ED2C
@ED4D:
    ED4D: 60          rts

update_door_waves:
    ED4E: A9 A0       lda #$a0
    ED50: 85 1E       sta obj_record_ptr   ; $1E
    ED52: A9 04       lda #$04
    ED54: 85 1F       sta obj_record_ptr_hi   ; $1F
@ED56:
    ED56: 20 65 ED    jsr update_door_wave   ; $ED65
    ED59: A5 1E       lda obj_record_ptr   ; $1E
    ED5B: 18          clc
    ED5C: 69 08       adc #$08
    ED5E: 85 1E       sta obj_record_ptr   ; $1E
    ED60: C9 C0       cmp #$c0
    ED62: D0 F2       bne @ED56   ; $ED56
    ED64: 60          rts

update_door_wave:
    ED65: A0 05       ldy #$05
    ED67: B1 1E       lda (obj_record_ptr),y   ; $1E
    ED69: F0 E2       beq @ED4D   ; $ED4D
    ED6B: C9 02       cmp #$02
    ED6D: B0 A3       bcs @ED12   ; $ED12
    ED6F: A5 42       lda game_phase   ; $42
    ED71: 8D 09 06    sta $0609
    ED74: 20 77 EE    jsr door_wave_catches_cats   ; $EE77
    ED77: 20 C9 EE    jsr carry_wave_cats   ; $EEC9
    ED7A: A9 08       lda #$08
    ED7C: A0 04       ldy #$04
    ED7E: 91 1E       sta (obj_record_ptr),y   ; $1E
    ED80: A5 63       lda record_ptr   ; $63
    ED82: 18          clc
    ED83: 69 08       adc #$08
    ED85: 20 4D EE    jsr move_record_x_by_direction   ; $EE4D
    ED88: 20 05 C3    jsr draw_object   ; $C305
    ED8B: D0 C0       bne @ED4D   ; $ED4D
    ED8D: A0 00       ldy #$00
    ED8F: A2 20       ldx #$20
@ED91:
    ED91: 20 E2 ED    jsr hide_wave_cats   ; $EDE2
    ED94: 8A          txa
    ED95: 18          clc
    ED96: 69 10       adc #$10
    ED98: AA          tax
    ED99: E0 90       cpx #$90
    ED9B: D0 F4       bne @ED91   ; $ED91
    ED9D: 98          tya
    ED9E: D0 03       bne @EDA3   ; $EDA3
    EDA0: 4C 1C ED    jmp end_door_wave   ; $ED1C
@EDA3:
    EDA3: A2 FD       ldx #$fd
    EDA5: 0A          asl a
    EDA6: 69 FE       adc #$fe
    EDA8: 48          pha
    EDA9: 30 02       bmi @EDAD   ; $EDAD
    EDAB: A2 FF       ldx #$ff
@EDAD:
    EDAD: A0 07       ldy #$07
    EDAF: 91 1E       sta (obj_record_ptr),y   ; $1E
    EDB1: A9 02       lda #$02
    EDB3: A0 05       ldy #$05
    EDB5: 91 1E       sta (obj_record_ptr),y   ; $1E
    EDB7: A9 10       lda #$10
    EDB9: A0 04       ldy #$04
    EDBB: 91 1E       sta (obj_record_ptr),y   ; $1E
    EDBD: A9 00       lda #$00
    EDBF: A0 06       ldy #$06
    EDC1: 38          sec
    EDC2: F1 1E       sbc (obj_record_ptr),y   ; $1E
    EDC4: 91 1E       sta (obj_record_ptr),y   ; $1E
    EDC6: 10 02       bpl @EDCA   ; $EDCA
    EDC8: A2 FE       ldx #$fe
@EDCA:
    EDCA: A0 01       ldy #$01
    EDCC: 8A          txa
    EDCD: 18          clc
    EDCE: 71 1E       adc (obj_record_ptr),y   ; $1E
    EDD0: 91 1E       sta (obj_record_ptr),y   ; $1E
    EDD2: A9 01       lda #$01
    EDD4: 85 18       sta scratch_loop_counter   ; $18
    EDD6: 68          pla
    EDD7: 0A          asl a
    EDD8: 90 02       bcc @EDDC   ; $EDDC
    EDDA: E6 18       inc scratch_loop_counter   ; $18
@EDDC:
    EDDC: 18          clc
    EDDD: 69 14       adc #$14
    EDDF: 4C BE D4    jmp add_score_n_times   ; $D4BE

hide_wave_cats:
    EDE2: BD 0B 04    lda $040b,x
    EDE5: C5 1E       cmp obj_record_ptr   ; $1E
    EDE7: D0 1A       bne @EE03   ; $EE03
    EDE9: BD 0F 04    lda $040f,x
    EDEC: C9 16       cmp #$16
    EDEE: D0 13       bne @EE03   ; $EE03
    EDF0: A9 18       lda #$18
    EDF2: 9D 0F 04    sta $040f,x
    EDF5: A9 00       lda #$00
    EDF7: 9D 04 04    sta $0404,x
    EDFA: C8          iny
    EDFB: E0 20       cpx #$20
    EDFD: D0 04       bne @EE03   ; $EE03
    EDFF: 98          tya
    EE00: 09 40       ora #$40
    EE02: A8          tay
@EE03:
    EE03: 60          rts

launch_door_wave:
    EE04: A0 00       ldy #$00
@EE06:
    EE06: B9 A5 04    lda obj_state,y   ; $04A5
    EE09: F0 0A       beq @EE15   ; $EE15
    EE0B: 98          tya
    EE0C: 18          clc
    EE0D: 69 08       adc #$08
    EE0F: A8          tay
    EE10: C0 20       cpy #$20
    EE12: D0 F2       bne @EE06   ; $EE06
    EE14: 60          rts
@EE15:
    EE15: A9 01       lda #$01
    EE17: 99 A5 04    sta obj_state,y   ; $04A5
    EE1A: A9 00       lda #$00
    EE1C: 99 A0 04    sta $04a0,y
    EE1F: 99 A2 04    sta $04a2,y
    EE22: BD B5 02    lda obj_x,x   ; $02B5
    EE25: 38          sec
    EE26: E9 01       sbc #$01
    EE28: 99 A3 04    sta $04a3,y
    EE2B: BD B1 02    lda obj_state,x   ; $02B1
    EE2E: 29 04       and #$04
    EE30: F0 0F       beq @EE41   ; $EE41
    EE32: A9 FF       lda #$ff
    EE34: 99 A6 04    sta $04a6,y
    EE37: BD B4 02    lda obj_pos,x   ; $02B4
    EE3A: 38          sec
    EE3B: E9 02       sbc #$02
    EE3D: 99 A1 04    sta $04a1,y
    EE40: 60          rts
@EE41:
    EE41: A9 01       lda #$01
    EE43: 99 A6 04    sta $04a6,y
    EE46: BD B4 02    lda obj_pos,x   ; $02B4
    EE49: 99 A1 04    sta $04a1,y
    EE4C: 60          rts

move_record_x_by_direction:
    EE4D: 85 10       sta src_ptr   ; $10
    EE4F: A0 06       ldy #$06
    EE51: B1 1E       lda (obj_record_ptr),y   ; $1E
    EE53: 30 11       bmi @EE66   ; $EE66
    EE55: A0 00       ldy #$00
    EE57: B1 1E       lda (obj_record_ptr),y   ; $1E
    EE59: 18          clc
    EE5A: 65 10       adc src_ptr   ; $10
    EE5C: 91 1E       sta (obj_record_ptr),y   ; $1E
    EE5E: C8          iny
    EE5F: B1 1E       lda (obj_record_ptr),y   ; $1E
    EE61: 69 00       adc #$00
    EE63: 91 1E       sta (obj_record_ptr),y   ; $1E
    EE65: 60          rts
@EE66:
    EE66: A0 00       ldy #$00
    EE68: B1 1E       lda (obj_record_ptr),y   ; $1E
    EE6A: 38          sec
    EE6B: E5 10       sbc src_ptr   ; $10
    EE6D: 91 1E       sta (obj_record_ptr),y   ; $1E
    EE6F: C8          iny
    EE70: B1 1E       lda (obj_record_ptr),y   ; $1E
    EE72: E9 00       sbc #$00
    EE74: 91 1E       sta (obj_record_ptr),y   ; $1E
    EE76: 60          rts

door_wave_catches_cats:
    EE77: A2 20       ldx #$20
@EE79:
    EE79: BD 04 04    lda $0404,x
    EE7C: F0 41       beq @EEBF   ; $EEBF
    EE7E: BD 0F 04    lda $040f,x
    EE81: 38          sec
    EE82: E9 16       sbc #$16
    EE84: C9 06       cmp #$06
    EE86: 90 37       bcc @EEBF   ; $EEBF
    EE88: BD 03 04    lda $0403,x
    EE8B: A0 03       ldy #$03
    EE8D: 38          sec
    EE8E: F1 1E       sbc (obj_record_ptr),y   ; $1E
    EE90: 18          clc
    EE91: 69 01       adc #$01
    EE93: C9 04       cmp #$04
    EE95: B0 28       bcs @EEBF   ; $EEBF
    EE97: BD 01 04    lda $0401,x
    EE9A: A0 01       ldy #$01
    EE9C: 38          sec
    EE9D: F1 1E       sbc (obj_record_ptr),y   ; $1E
    EE9F: 48          pha
    EEA0: A0 06       ldy #$06
    EEA2: B1 1E       lda (obj_record_ptr),y   ; $1E
    EEA4: 10 05       bpl @EEAB   ; $EEAB
    EEA6: 68          pla
    EEA7: 18          clc
    EEA8: 69 01       adc #$01
    EEAA: 48          pha
@EEAB:
    EEAB: 68          pla
    EEAC: C9 02       cmp #$02
    EEAE: B0 0F       bcs @EEBF   ; $EEBF
    EEB0: A5 1E       lda obj_record_ptr   ; $1E
    EEB2: 9D 0B 04    sta $040b,x
    EEB5: A9 00       lda #$00
    EEB7: 9D 07 04    sta $0407,x
    EEBA: A9 16       lda #$16
    EEBC: 9D 0F 04    sta $040f,x
@EEBF:
    EEBF: 8A          txa
    EEC0: 18          clc
    EEC1: 69 10       adc #$10
    EEC3: AA          tax
    EEC4: E0 90       cpx #$90
    EEC6: D0 B1       bne @EE79   ; $EE79
    EEC8: 60          rts

carry_wave_cats:
    EEC9: A2 20       ldx #$20
@EECB:
    EECB: BD 0B 04    lda $040b,x
    EECE: C5 1E       cmp obj_record_ptr   ; $1E
    EED0: D0 0F       bne @EEE1   ; $EEE1
    EED2: BD 0F 04    lda $040f,x
    EED5: C9 16       cmp #$16
    EED7: D0 08       bne @EEE1   ; $EEE1
    EED9: A5 63       lda record_ptr   ; $63
    EEDB: 18          clc
    EEDC: 69 08       adc #$08
    EEDE: 20 EB EE    jsr move_cat_x_by_wave_direction   ; $EEEB
@EEE1:
    EEE1: 8A          txa
    EEE2: 18          clc
    EEE3: 69 10       adc #$10
    EEE5: AA          tax
    EEE6: E0 90       cpx #$90
    EEE8: D0 E1       bne @EECB   ; $EECB
    EEEA: 60          rts

move_cat_x_by_wave_direction:
    EEEB: 85 10       sta src_ptr   ; $10
    EEED: A0 06       ldy #$06
    EEEF: B1 1E       lda (obj_record_ptr),y   ; $1E
    EEF1: 30 12       bmi @EF05   ; $EF05
    EEF3: BD 00 04    lda $0400,x
    EEF6: 18          clc
    EEF7: 65 10       adc src_ptr   ; $10
    EEF9: 9D 00 04    sta $0400,x
    EEFC: BD 01 04    lda $0401,x
    EEFF: 69 00       adc #$00
    EF01: 9D 01 04    sta $0401,x
    EF04: 60          rts
@EF05:
    EF05: BD 00 04    lda $0400,x
    EF08: 38          sec
    EF09: E5 10       sbc src_ptr   ; $10
    EF0B: 9D 00 04    sta $0400,x
    EF0E: BD 01 04    lda $0401,x
    EF11: E9 00       sbc #$00
    EF13: 9D 01 04    sta $0401,x
    EF16: 60          rts

load_dropped_objects:
    EF17: A5 7A       lda stage_number   ; $7A
    EF19: 38          sec
    EF1A: E9 07       sbc #$07
    EF1C: C9 03       cmp #$03
    EF1E: A9 00       lda #$00
    EF20: B0 0C       bcs @EF2E   ; $EF2E
    EF22: A2 00       ldx #$00
@EF24:
    EF24: BD 2F EF    lda $ef2f,x
    EF27: 95 A0       sta block_data_ptr,x   ; $A0
    EF29: E8          inx
    EF2A: E0 10       cpx #$10
    EF2C: D0 F6       bne @EF24   ; $EF24
@EF2E:
    EF2E: 60          rts
    EF2F: 00          .byte $00
    EF30: 03          .byte $03
    EF31: 00          .byte $00
    EF32: 06          .byte $06
    EF33: 0A          .byte $0A
    EF34: 01          .byte $01
    EF35: 00          .byte $00
    EF36: 00          .byte $00
    EF37: 00          .byte $00
    EF38: 37          .byte $37
    EF39: 00          .byte $00
    EF3A: 06          .byte $06
    EF3B: 0A          .byte $0A
    EF3C: 01          .byte $01
    EF3D: 00          .byte $00
    EF3E: 00          .byte $00

update_dropped_objects:
    EF3F: A9 A0       lda #$a0
    EF41: 85 1E       sta obj_record_ptr   ; $1E
    EF43: A9 00       lda #$00
    EF45: 85 1F       sta obj_record_ptr_hi   ; $1F
    EF47: 20 4E EF    jsr update_dropped_object   ; $EF4E
    EF4A: A9 A8       lda #$a8
    EF4C: 85 1E       sta obj_record_ptr   ; $1E

update_dropped_object:
    EF4E: A0 05       ldy #$05
    EF50: B1 1E       lda (obj_record_ptr),y   ; $1E
    EF52: F0 DA       beq @EF2E   ; $EF2E
    EF54: C9 02       cmp #$02
    EF56: 90 20       bcc @EF78   ; $EF78
    EF58: 20 9B EF    jsr dropped_object_stuns_cats   ; $EF9B
    EF5B: A0 02       ldy #$02
    EF5D: B1 1E       lda (obj_record_ptr),y   ; $1E
    EF5F: 18          clc
    EF60: 69 80       adc #$80
    EF62: 91 1E       sta (obj_record_ptr),y   ; $1E
    EF64: C8          iny
    EF65: B1 1E       lda (obj_record_ptr),y   ; $1E
    EF67: 69 00       adc #$00
    EF69: 91 1E       sta (obj_record_ptr),y   ; $1E
    EF6B: C9 1C       cmp #$1c
    EF6D: 90 06       bcc @EF75   ; $EF75
    EF6F: A9 00       lda #$00
    EF71: A0 05       ldy #$05
    EF73: 91 1E       sta (obj_record_ptr),y   ; $1E
@EF75:
    EF75: 4C 05 C3    jmp draw_object   ; $C305
@EF78:
    EF78: A0 03       ldy #$03
    EF7A: B1 1E       lda (obj_record_ptr),y   ; $1E
    EF7C: CD 03 04    cmp $0403
    EF7F: D0 17       bne @EF98   ; $EF98
    EF81: A0 01       ldy #$01
    EF83: B1 1E       lda (obj_record_ptr),y   ; $1E
    EF85: 38          sec
    EF86: ED 01 04    sbc $0401
    EF89: C9 02       cmp #$02
    EF8B: B0 0B       bcs @EF98   ; $EF98
    EF8D: A5 42       lda game_phase   ; $42
    EF8F: 8D 07 06    sta $0607
    EF92: A9 02       lda #$02
    EF94: A0 05       ldy #$05
    EF96: 91 1E       sta (obj_record_ptr),y   ; $1E
@EF98:
    EF98: 4C 05 C3    jmp draw_object   ; $C305

dropped_object_stuns_cats:
    EF9B: A2 20       ldx #$20
@EF9D:
    EF9D: BD 0F 04    lda $040f,x
    EFA0: C9 16       cmp #$16
    EFA2: B0 53       bcs @EFF7   ; $EFF7
    EFA4: A0 00       ldy #$00
    EFA6: B1 1E       lda (obj_record_ptr),y   ; $1E
    EFA8: 38          sec
    EFA9: FD 00 04    sbc $0400,x
    EFAC: C8          iny
    EFAD: B1 1E       lda (obj_record_ptr),y   ; $1E
    EFAF: FD 01 04    sbc $0401,x
    EFB2: 18          clc
    EFB3: 69 01       adc #$01
    EFB5: C9 02       cmp #$02
    EFB7: B0 3E       bcs @EFF7   ; $EFF7
    EFB9: C8          iny
    EFBA: B1 1E       lda (obj_record_ptr),y   ; $1E
    EFBC: 38          sec
    EFBD: FD 02 04    sbc $0402,x
    EFC0: C8          iny
    EFC1: B1 1E       lda (obj_record_ptr),y   ; $1E
    EFC3: FD 03 04    sbc $0403,x
    EFC6: 18          clc
    EFC7: 69 01       adc #$01
    EFC9: C9 02       cmp #$02
    EFCB: B0 2A       bcs @EFF7   ; $EFF7
    EFCD: A5 65       lda active_object_count   ; $65
    EFCF: 9D 07 04    sta $0407,x
    EFD2: A9 26       lda #$26
    EFD4: 9D 0F 04    sta $040f,x
    EFD7: A9 22       lda #$22
    EFD9: 9D 04 04    sta $0404,x
    EFDC: BD 03 04    lda $0403,x
    EFDF: C9 19       cmp #$19
    EFE1: 90 05       bcc @EFE8   ; $EFE8
    EFE3: A9 19       lda #$19
    EFE5: 9D 03 04    sta $0403,x
@EFE8:
    EFE8: 86 1B       stx cur_obj_index   ; $1B
    EFEA: A0 08       ldy #$08
    EFEC: E0 20       cpx #$20
    EFEE: D0 02       bne @EFF2   ; $EFF2
    EFF0: A0 44       ldy #$44
@EFF2:
    EFF2: 20 CA D4    jsr add_score_from_table   ; $D4CA
    EFF5: A6 1B       ldx cur_obj_index   ; $1B
@EFF7:
    EFF7: 8A          txa
    EFF8: 18          clc
    EFF9: 69 10       adc #$10
    EFFB: AA          tax
    EFFC: E0 90       cpx #$90
    EFFE: D0 9D       bne @EF9D   ; $EF9D
    F000: 60          rts

spawn_floor_traps:
    F001: A5 7A       lda stage_number   ; $7A
    F003: 0A          asl a
    F004: E9 15       sbc #$15
    F006: C9 06       cmp #$06
    F008: B0 36       bcs @F040   ; $F040
    F00A: 0A          asl a
    F00B: AA          tax
    F00C: A0 00       ldy #$00
    F00E: 20 13 F0    jsr init_floor_trap   ; $F013
    F011: A0 08       ldy #$08

init_floor_trap:
    F013: A9 02       lda #$02
    F015: 99 90 00    sta obj_state,y   ; $0090
    F018: BD 41 F0    lda $f041,x
    F01B: E8          inx
    F01C: 99 92 00    sta obj_trigger_coord,y   ; $0092
    F01F: 85 10       sta src_ptr   ; $10
    F021: BD 41 F0    lda $f041,x
    F024: E8          inx
    F025: 86 1B       stx cur_obj_index   ; $1B
    F027: 99 93 00    sta ppu_block_data_ptr,y   ; $0093
    F02A: 85 11       sta zp_ptr_hi   ; $11
    F02C: 20 BD E3    jsr ppu_addr_to_tile_xy   ; $E3BD
    F02F: A5 10       lda src_ptr   ; $10
    F031: 99 94 00    sta obj_pos_field,y   ; $0094
    F034: A5 11       lda zp_ptr_hi   ; $11
    F036: 99 95 00    sta obj_x,y   ; $0095
    F039: A2 00       ldx #$00
    F03B: 20 6D F0    jsr draw_floor_trap_frame   ; $F06D
    F03E: A6 1B       ldx cur_obj_index   ; $1B
@F040:
    F040: 60          rts
    F041: 09          .byte $09
    F042: 22          .byte $22
    F043: 88          .byte $88
    F044: 25          .byte $25
    F045: 93          .byte $93
    F046: 22          .byte $22
    F047: 11          .byte $11
    F048: 26          .byte $26
    F049: 09          .byte $09
    F04A: 22          .byte $22
    F04B: 07          .byte $07
    F04C: 26          .byte $26

update_floor_traps:
    F04D: A0 00       ldy #$00
    F04F: 20 54 F0    jsr update_floor_trap   ; $F054
    F052: A0 08       ldy #$08

update_floor_trap:
    F054: B9 90 00    lda obj_state,y   ; $0090
    F057: F0 E7       beq @F040   ; $F040
    F059: C9 02       cmp #$02
    F05B: 90 3F       bcc @F09C   ; $F09C
    F05D: D0 29       bne @F088   ; $F088
    F05F: A5 21       lda frame_counter   ; $21
    F061: 29 03       and #$03
    F063: C9 02       cmp #$02
    F065: D0 D9       bne @F040   ; $F040
    F067: A5 21       lda frame_counter   ; $21
    F069: 29 04       and #$04
    F06B: 4A          lsr a
    F06C: AA          tax

draw_floor_trap_frame:
    F06D: B9 92 00    lda obj_trigger_coord,y   ; $0092
    F070: 85 10       sta src_ptr   ; $10
    F072: B9 93 00    lda ppu_block_data_ptr,y   ; $0093
    F075: 85 11       sta zp_ptr_hi   ; $11
    F077: A9 80       lda #$80
    F079: 85 14       sta scan_src_ptr   ; $14
    F07B: BD 28 F1    lda $f128,x
    F07E: 85 12       sta gfx_src_ptr   ; $12
    F080: BD 29 F1    lda $f129,x
    F083: 85 13       sta data_ptr_hi   ; $13
    F085: 4C FB C6    jmp draw_rle_text   ; $C6FB
@F088:
    F088: 20 CE F0    jsr player_on_floor_trap   ; $F0CE
    F08B: F0 B3       beq @F040   ; $F040
    F08D: A9 01       lda #$01
    F08F: 99 90 00    sta obj_state,y   ; $0090
    F092: A9 78       lda #$78
    F094: 99 96 00    sta scratch_bitshift,y   ; $0096
    F097: A2 00       ldx #$00
    F099: 4C 6D F0    jmp draw_floor_trap_frame   ; $F06D
@F09C:
    F09C: B9 96 00    lda scratch_bitshift,y   ; $0096
    F09F: 38          sec
    F0A0: E9 01       sbc #$01
    F0A2: 99 96 00    sta scratch_bitshift,y   ; $0096
    F0A5: D0 99       bne @F040   ; $F040
    F0A7: A9 00       lda #$00
    F0A9: 99 90 00    sta obj_state,y   ; $0090
    F0AC: A2 04       ldx #$04
    F0AE: 4C 6D F0    jmp draw_floor_trap_frame   ; $F06D

press_floor_traps:
    F0B1: A0 00       ldy #$00
    F0B3: 20 B8 F0    jsr press_floor_trap   ; $F0B8
    F0B6: A0 08       ldy #$08

press_floor_trap:
    F0B8: B9 90 00    lda obj_state,y   ; $0090
    F0BB: C9 02       cmp #$02
    F0BD: D0 27       bne @F0E6   ; $F0E6
    F0BF: 20 CE F0    jsr player_on_floor_trap   ; $F0CE
    F0C2: D0 22       bne @F0E6   ; $F0E6
    F0C4: A9 03       lda #$03
    F0C6: 99 90 00    sta obj_state,y   ; $0090
    F0C9: A2 02       ldx #$02
    F0CB: 4C 6D F0    jmp draw_floor_trap_frame   ; $F06D

player_on_floor_trap:
    F0CE: B9 94 00    lda obj_pos_field,y   ; $0094
    F0D1: 38          sec
    F0D2: ED 01 04    sbc $0401
    F0D5: C9 02       cmp #$02
    F0D7: B0 0B       bcs @F0E4   ; $F0E4
    F0D9: B9 95 00    lda obj_x,y   ; $0095
    F0DC: 38          sec
    F0DD: ED 03 04    sbc $0403
    F0E0: C9 02       cmp #$02
    F0E2: F0 02       beq @F0E6   ; $F0E6
@F0E4:
    F0E4: A9 FF       lda #$ff
@F0E6:
    F0E6: 60          rts

walker_over_open_trap:
    F0E7: A2 00       ldx #$00
    F0E9: 20 F0 F0    jsr walker_over_open_trap_x   ; $F0F0
    F0EC: F0 39       beq @F127   ; $F127
    F0EE: A2 08       ldx #$08

walker_over_open_trap_x:
    F0F0: B5 90       lda obj_state,x   ; $90
    F0F2: C9 01       cmp #$01
    F0F4: D0 31       bne @F127   ; $F127
    F0F6: B5 95       lda obj_x,x   ; $95
    F0F8: 38          sec
    F0F9: A0 03       ldy #$03
    F0FB: F1 1E       sbc (obj_record_ptr),y   ; $1E
    F0FD: C9 02       cmp #$02
    F0FF: D0 E3       bne @F0E4   ; $F0E4
    F101: B5 94       lda obj_pos_field,x   ; $94
    F103: 38          sec
    F104: A0 01       ldy #$01
    F106: F1 1E       sbc (obj_record_ptr),y   ; $1E
    F108: F0 0E       beq @F118   ; $F118
    F10A: C9 01       cmp #$01
    F10C: D0 19       bne @F127   ; $F127
    F10E: A0 00       ldy #$00
    F110: B1 1E       lda (obj_record_ptr),y   ; $1E
    F112: C9 C0       cmp #$c0
    F114: 90 CE       bcc @F0E4   ; $F0E4
    F116: B0 08       bcs @F120   ; $F120
@F118:
    F118: A0 00       ldy #$00
    F11A: B1 1E       lda (obj_record_ptr),y   ; $1E
    F11C: C9 40       cmp #$40
    F11E: B0 C4       bcs @F0E4   ; $F0E4
@F120:
    F120: A9 01       lda #$01
    F122: 8D 07 06    sta $0607
    F125: A9 00       lda #$00
@F127:
    F127: 60          rts
    F128: 2E          .byte $2E
    F129: F1          .byte $F1
    F12A: 32          .byte $32
    F12B: F1          .byte $F1
    F12C: 36          .byte $36
    F12D: F1          .byte $F1
    F12E: 02          .byte $02
    F12F: 51          .byte $51
    F130: 51          .byte $51
    F131: 00          .byte $00
    F132: 02          .byte $02
    F133: 50          .byte $50
    F134: 50          .byte $50
    F135: 00          .byte $00
    F136: 02          .byte $02
    F137: 4A          .byte $4A
    F138: 4A          .byte $4A
    F139: 00          .byte $00

load_bonus_targets:
    F13A: A4 7C       ldy is_bonus_round   ; $7C
    F13C: B9 7F F2    lda $f27f,y
    F13F: 85 1C       sta aux_ptr   ; $1C
    F141: B9 80 F2    lda $f280,y
    F144: 85 1D       sta aux_ptr_hi   ; $1D
    F146: A0 00       ldy #$00
    F148: B1 1C       lda (aux_ptr),y   ; $1C
    F14A: C8          iny
    F14B: 85 53       sta object_def_ptr   ; $53
    F14D: 4A          lsr a
    F14E: 4A          lsr a
    F14F: 4A          lsr a
    F150: 85 52       sta object_def_ptr   ; $52
    F152: A9 00       lda #$00
    F154: 85 50       sta obj_table_ptr   ; $50
    F156: 85 51       sta obj_def_ptr_hi   ; $51
    F158: A2 00       ldx #$00
@F15A:
    F15A: 95 54       sta object_table_ptr,x   ; $54
    F15C: E8          inx
    F15D: E0 0C       cpx #$0c
    F15F: D0 F9       bne @F15A   ; $F15A
    F161: A2 00       ldx #$00
@F163:
    F163: A9 02       lda #$02
    F165: 9D 60 02    sta item_state,x   ; $0260
    F168: B1 1C       lda (aux_ptr),y   ; $1C
    F16A: C8          iny
    F16B: 85 10       sta src_ptr   ; $10
    F16D: 9D 66 02    sta $0266,x
    F170: B1 1C       lda (aux_ptr),y   ; $1C
    F172: C8          iny
    F173: 85 11       sta zp_ptr_hi   ; $11
    F175: 9D 67 02    sta $0267,x
    F178: 20 BD E3    jsr ppu_addr_to_tile_xy   ; $E3BD
    F17B: A5 10       lda src_ptr   ; $10
    F17D: 9D 64 02    sta item_x,x   ; $0264
    F180: A5 11       lda zp_ptr_hi   ; $11
    F182: 9D 65 02    sta item_y,x   ; $0265
    F185: 8A          txa
    F186: 18          clc
    F187: 69 08       adc #$08
    F189: AA          tax
    F18A: E4 53       cpx object_def_ptr   ; $53
    F18C: D0 D5       bne @F163   ; $F163
    F18E: 60          rts

update_bonus_targets:
    F18F: A5 53       lda object_def_ptr   ; $53
    F191: F0 11       beq @F1A4   ; $F1A4
    F193: A2 00       ldx #$00
@F195:
    F195: 86 1B       stx cur_obj_index   ; $1B
    F197: 20 A5 F1    jsr dispatch_bonus_target   ; $F1A5
    F19A: A5 1B       lda cur_obj_index   ; $1B
    F19C: 18          clc
    F19D: 69 08       adc #$08
    F19F: AA          tax
    F1A0: E4 53       cpx object_def_ptr   ; $53
    F1A2: D0 F1       bne @F195   ; $F195
@F1A4:
    F1A4: 60          rts

dispatch_bonus_target:
    F1A5: BC 60 02    ldy item_state,x   ; $0260
    F1A8: B9 B5 F1    lda $f1b5,y
    F1AB: 85 1C       sta aux_ptr   ; $1C
    F1AD: B9 B6 F1    lda $f1b6,y
    F1B0: 85 1D       sta aux_ptr_hi   ; $1D
    F1B2: 6C 1C 00    jmp (aux_ptr)   ; $001C
    F1B5:            .word handler_rts_noop
    F1B7:            .word bonus_target_live

bonus_target_live:
    F1B9: 20 33 F2    jsr animate_bonus_target   ; $F233
    F1BC: 20 15 F2    jsr released_cat_pops_target   ; $F215
    F1BF: A6 1B       ldx cur_obj_index   ; $1B
    F1C1: BD 60 02    lda item_state,x   ; $0260
    F1C4: C9 02       cmp #$02
    F1C6: D0 4C       bne @F214   ; $F214
    F1C8: BD 65 02    lda item_y,x   ; $0265
    F1CB: CD 03 04    cmp $0403
    F1CE: D0 44       bne @F214   ; $F214
    F1D0: BD 64 02    lda item_x,x   ; $0264
    F1D3: 38          sec
    F1D4: ED 01 04    sbc $0401
    F1D7: C9 02       cmp #$02
    F1D9: B0 39       bcs @F214   ; $F214
    F1DB: AD 0F 04    lda $040f
    F1DE: C9 08       cmp #$08
    F1E0: D0 0F       bne pop_bonus_target   ; $F1F1
    F1E2: A9 00       lda #$00
    F1E4: 8D 08 04    sta $0408
    F1E7: A9 02       lda #$02
    F1E9: 8D 0F 04    sta $040f
    F1EC: A9 06       lda #$06
    F1EE: 8D 04 04    sta $0404

pop_bonus_target:
    F1F1: A9 01       lda #$01
    F1F3: 8D 08 06    sta $0608
    F1F6: A9 00       lda #$00
    F1F8: 9D 60 02    sta item_state,x   ; $0260
    F1FB: C6 52       dec object_def_ptr   ; $52
    F1FD: A0 06       ldy #$06
    F1FF: 20 E5 D4    jsr bcd_add_from_table   ; $D4E5
    F202: A0 08       ldy #$08
    F204: 20 E5 D4    jsr bcd_add_from_table   ; $D4E5
    F207: AD 77 F2    lda $f277
    F20A: 85 12       sta gfx_src_ptr   ; $12
    F20C: AD 78 F2    lda $f278
    F20F: 85 13       sta data_ptr_hi   ; $13
    F211: 4C 50 F2    jmp draw_bonus_target   ; $F250
@F214:
    F214: 60          rts

released_cat_pops_target:
    F215: BD 65 02    lda item_y,x   ; $0265
    F218: CD 23 04    cmp obj_state   ; $0423
    F21B: D0 F7       bne @F214   ; $F214
    F21D: BD 64 02    lda item_x,x   ; $0264
    F220: 38          sec
    F221: ED 21 04    sbc target_compare_value   ; $0421
    F224: C9 02       cmp #$02
    F226: B0 EC       bcs @F214   ; $F214
    F228: A9 00       lda #$00
    F22A: 8D 2F 04    sta stage_phase_state   ; $042F
    F22D: 8D 24 04    sta obj_state   ; $0424
    F230: 4C F1 F1    jmp pop_bonus_target   ; $F1F1

animate_bonus_target:
    F233: A5 1B       lda cur_obj_index   ; $1B
    F235: 4A          lsr a
    F236: 4A          lsr a
    F237: 4A          lsr a
    F238: 45 21       eor frame_counter   ; $21
    F23A: 29 0F       and #$0f
    F23C: D0 D6       bne @F214   ; $F214
    F23E: A5 21       lda frame_counter   ; $21
    F240: 29 10       and #$10
    F242: 4A          lsr a
    F243: 4A          lsr a
    F244: 4A          lsr a
    F245: A8          tay
    F246: B9 63 F2    lda $f263,y
    F249: 85 12       sta gfx_src_ptr   ; $12
    F24B: B9 64 F2    lda $f264,y
    F24E: 85 13       sta data_ptr_hi   ; $13

draw_bonus_target:
    F250: A6 1B       ldx cur_obj_index   ; $1B
    F252: BD 66 02    lda $0266,x
    F255: 85 10       sta src_ptr   ; $10
    F257: BD 67 02    lda $0267,x
    F25A: 85 11       sta zp_ptr_hi   ; $11
    F25C: A9 00       lda #$00
    F25E: 85 14       sta scan_src_ptr   ; $14
    F260: 4C FB C6    jmp draw_rle_text   ; $C6FB
    F263: 67          .byte $67
    F264: F2          .byte $F2
    F265: 6F          .byte $6F
    F266: F2          .byte $F2
    F267: 02          .byte $02
    F268: 28          .byte $28
    F269: 29          .byte $29
    F26A: 1E          .byte $1E
    F26B: 02          .byte $02
    F26C: 2A          .byte $2A
    F26D: 2B          .byte $2B
    F26E: 00          .byte $00
    F26F: 02          .byte $02
    F270: 2C          .byte $2C
    F271: 2D          .byte $2D
    F272: 1E          .byte $1E
    F273: 02          .byte $02
    F274: 2E          .byte $2E
    F275: 2F          .byte $2F
    F276: 00          .byte $00
    F277: 79          .byte $79
    F278: F2          .byte $F2
    F279: 02          .byte $02
    F27A: 00          .byte $00
    F27B: 00          .byte $00
    F27C: 1E          .byte $1E
    F27D: 02          .byte $02
    F27E: 00          .byte $00
    F27F: 00          .byte $00
    F280: 00          .byte $00
    F281: 89          .byte $89
    F282: F2          .byte $F2
    F283: A8          .byte $A8
    F284: F2          .byte $F2
    F285: C7          .byte $C7
    F286: F2          .byte $F2
    F287: C7          .byte $C7
    F288: F2          .byte $F2
    F289: 78          .byte $78
    F28A: D5          .byte $D5
    F28B: 24          .byte $24
    F28C: 55          .byte $55
    F28D: 26          .byte $26
    F28E: 0F          .byte $0F
    F28F: 25          .byte $25
    F290: 0C          .byte $0C
    F291: 26          .byte $26
    F292: E9          .byte $E9
    F293: 24          .byte $24
    F294: 03          .byte $03
    F295: 25          .byte $25
    F296: C3          .byte $C3
    F297: 26          .byte $26
    F298: FD          .byte $FD
    F299: 20          .byte $20
    F29A: 9A          .byte $9A
    F29B: 22          .byte $22
    F29C: F7          .byte $F7
    F29D: 20          .byte $20
    F29E: 94          .byte $94
    F29F: 21          .byte $21
    F2A0: F1          .byte $F1
    F2A1: 20          .byte $20
    F2A2: EB          .byte $EB
    F2A3: 20          .byte $20
    F2A4: 06          .byte $06
    F2A5: 21          .byte $21
    F2A6: C5          .byte $C5
    F2A7: 20          .byte $20
    F2A8: 78          .byte $78
    F2A9: D5          .byte $D5
    F2AA: 24          .byte $24
    F2AB: 55          .byte $55
    F2AC: 26          .byte $26
    F2AD: EF          .byte $EF
    F2AE: 24          .byte $24
    F2AF: 0C          .byte $0C
    F2B0: 26          .byte $26
    F2B1: 49          .byte $49
    F2B2: 25          .byte $25
    F2B3: C3          .byte $C3
    F2B4: 24          .byte $24
    F2B5: C3          .byte $C3
    F2B6: 26          .byte $26
    F2B7: 9D          .byte $9D
    F2B8: 21          .byte $21
    F2B9: 9A          .byte $9A
    F2BA: 22          .byte $22
    F2BB: 17          .byte $17
    F2BC: 21          .byte $21
    F2BD: D1          .byte $D1
    F2BE: 20          .byte $20
    F2BF: D1          .byte $D1
    F2C0: 22          .byte $22
    F2C1: 0B          .byte $0B
    F2C2: 22          .byte $22
    F2C3: EB          .byte $EB
    F2C4: 20          .byte $20
    F2C5: C5          .byte $C5
    F2C6: 20          .byte $20
    F2C7: 78          .byte $78
    F2C8: D5          .byte $D5
    F2C9: 24          .byte $24
    F2CA: 55          .byte $55
    F2CB: 26          .byte $26
    F2CC: CF          .byte $CF
    F2CD: 24          .byte $24
    F2CE: 29          .byte $29
    F2CF: 25          .byte $25
    F2D0: C3          .byte $C3
    F2D1: 24          .byte $24
    F2D2: C3          .byte $C3
    F2D3: 26          .byte $26
    F2D4: 80          .byte $80
    F2D5: 25          .byte $25
    F2D6: 3D          .byte $3D
    F2D7: 21          .byte $21
    F2D8: 9A          .byte $9A
    F2D9: 22          .byte $22
    F2DA: F7          .byte $F7
    F2DB: 20          .byte $20
    F2DC: 11          .byte $11
    F2DD: 21          .byte $21
    F2DE: D1          .byte $D1
    F2DF: 22          .byte $22
    F2E0: 0B          .byte $0B
    F2E1: 22          .byte $22
    F2E2: EB          .byte $EB
    F2E3: 20          .byte $20
    F2E4: E5          .byte $E5
    F2E5: 20          .byte $20

tick_round_timer:
    F2E6: A5 60       lda sequence_state   ; $60
    F2E8: F0 14       beq @F2FE   ; $F2FE
    F2EA: C9 02       cmp #$02
    F2EC: 90 41       bcc @F32F   ; $F32F
    F2EE: F0 6B       beq @F35B   ; $F35B
    F2F0: A5 61       lda seq_data_ptr   ; $61
    F2F2: C9 3C       cmp #$3c
    F2F4: F0 07       beq @F2FD   ; $F2FD
    F2F6: E6 61       inc seq_data_ptr   ; $61
    F2F8: A5 42       lda game_phase   ; $42
    F2FA: 8D 05 06    sta $0605
@F2FD:
    F2FD: 60          rts
@F2FE:
    F2FE: E6 61       inc seq_data_ptr   ; $61
    F300: A5 61       lda seq_data_ptr   ; $61
    F302: C9 3C       cmp #$3c
    F304: D0 F7       bne @F2FD   ; $F2FD
    F306: A9 00       lda #$00
    F308: 85 61       sta seq_data_ptr   ; $61
    F30A: E6 62       inc seq_data_ptr   ; $62
    F30C: A5 62       lda seq_data_ptr   ; $62
    F30E: C5 66       cmp $66
    F310: D0 EB       bne @F2FD   ; $F2FD
    F312: A9 01       lda #$01
    F314: 85 60       sta sequence_state   ; $60
    F316: A2 00       ldx #$00
@F318:
    F318: BD AA F3    lda $f3aa,x
    F31B: 9D 90 04    sta obj_state_counter,x   ; $0490
    F31E: E8          inx
    F31F: E0 08       cpx #$08
    F321: D0 F5       bne @F318   ; $F318

start_timer_phase_tune:
    F323: 20 BF F4    jsr init_sound_voices   ; $F4BF
    F326: A9 03       lda #$03
    F328: 8D F5 06    sta $06f5
    F32B: 8D F6 06    sta $06f6
    F32E: 60          rts
@F32F:
    F32F: 20 83 F3    jsr draw_hurry_sprite   ; $F383
    F332: 20 B2 F3    jsr scroll_hurry_sprite_left   ; $F3B2
    F335: A5 42       lda game_phase   ; $42
    F337: 8D 05 06    sta $0605
    F33A: AD 91 04    lda $0491
    F33D: F0 BE       beq @F2FD   ; $F2FD
    F33F: A9 02       lda #$02
    F341: 85 60       sta sequence_state   ; $60
    F343: A9 00       lda #$00
    F345: 85 61       sta seq_data_ptr   ; $61
    F347: 85 62       sta seq_data_ptr   ; $62
    F349: A6 68       ldx ptr_hi   ; $68
    F34B: A9 1A       lda #$1a
    F34D: 9D 0F 04    sta $040f,x
    F350: A9 01       lda #$01
    F352: 9D 07 04    sta $0407,x
    F355: A9 03       lda #$03
    F357: 9D 05 04    sta $0405,x
    F35A: 60          rts
@F35B:
    F35B: E6 61       inc seq_data_ptr   ; $61
    F35D: A5 61       lda seq_data_ptr   ; $61
    F35F: C9 3C       cmp #$3c
    F361: D0 9A       bne @F2FD   ; $F2FD
    F363: A9 00       lda #$00
    F365: 85 61       sta seq_data_ptr   ; $61
    F367: E6 62       inc seq_data_ptr   ; $62
    F369: A5 62       lda seq_data_ptr   ; $62
    F36B: C5 67       cmp screen_layout_ptr   ; $67
    F36D: D0 8E       bne @F2FD   ; $F2FD
    F36F: A9 03       lda #$03
    F371: 85 60       sta sequence_state   ; $60
    F373: A9 1A       lda #$1a
    F375: 8D 1F 04    sta obj_state   ; $041F
    F378: A9 01       lda #$01
    F37A: 8D 17 04    sta $0417
    F37D: 8D 15 04    sta $0415
    F380: 4C 23 F3    jmp start_timer_phase_tune   ; $F323

draw_hurry_sprite:
    F383: A2 00       ldx #$00
@F385:
    F385: BD 90 04    lda obj_state_counter,x   ; $0490
    F388: 95 10       sta src_ptr,x   ; $10
    F38A: E8          inx
    F38B: E0 08       cpx #$08
    F38D: D0 F6       bne @F385   ; $F385
    F38F: A5 21       lda frame_counter   ; $21
    F391: 29 03       and #$03
    F393: 85 13       sta data_ptr_hi   ; $13
@F395:
    F395: 20 15 C4    jsr write_sprite_to_oam   ; $C415
    F398: A5 10       lda src_ptr   ; $10
    F39A: 18          clc
    F39B: 69 08       adc #$08
    F39D: 85 10       sta src_ptr   ; $10
    F39F: 90 02       bcc @F3A3   ; $F3A3
    F3A1: E6 11       inc zp_ptr_hi   ; $11
@F3A3:
    F3A3: E6 12       inc gfx_src_ptr   ; $12
    F3A5: C6 17       dec draw_row_counter   ; $17
    F3A7: D0 EC       bne @F395   ; $F395
    F3A9: 60          rts
    F3AA: F8          .byte $F8
    F3AB: 00          .byte $00
    F3AC: A0          .byte $A0
    F3AD: 00          .byte $00
    F3AE: 00          .byte $00
    F3AF: 00          .byte $00
    F3B0: 68          .byte $68
    F3B1: 04          .byte $04

scroll_hurry_sprite_left:
    F3B2: AD 90 04    lda obj_state_counter   ; $0490
    F3B5: 38          sec
    F3B6: E9 02       sbc #$02
    F3B8: 8D 90 04    sta obj_state_counter   ; $0490
    F3BB: B0 03       bcs @F3C0   ; $F3C0
    F3BD: CE 91 04    dec $0491
@F3C0:
    F3C0: 60          rts

load_stage_params:
    F3C1: A9 00       lda #$00
    F3C3: 85 60       sta sequence_state   ; $60
    F3C5: 85 61       sta seq_data_ptr   ; $61
    F3C7: 85 62       sta seq_data_ptr   ; $62
    F3C9: A5 7D       lda stage_index   ; $7D
    F3CB: 0A          asl a
    F3CC: 65 7D       adc stage_index   ; $7D
    F3CE: 0A          asl a
    F3CF: AA          tax
    F3D0: A0 00       ldy #$00
@F3D2:
    F3D2: BD DF F3    lda $f3df,x
    F3D5: 99 63 00    sta record_ptr,y   ; $0063
    F3D8: E8          inx
    F3D9: C8          iny
    F3DA: C0 06       cpy #$06
    F3DC: D0 F4       bne @F3D2   ; $F3D2
    F3DE: 60          rts
    F3DF: 20          .byte $20
    F3E0: 1C          .byte $1C
    F3E1: B4          .byte $B4
    F3E2: 50          .byte $50
    F3E3: 46          .byte $46
    F3E4: 60          .byte $60
    F3E5: 20          .byte $20
    F3E6: 1E          .byte $1E
    F3E7: A0          .byte $A0
    F3E8: 3C          .byte $3C
    F3E9: 46          .byte $46
    F3EA: 60          .byte $60
    F3EB: 1E          .byte $1E
    F3EC: 1C          .byte $1C
    F3ED: B4          .byte $B4
    F3EE: 50          .byte $50
    F3EF: 46          .byte $46
    F3F0: 60          .byte $60
    F3F1: 22          .byte $22
    F3F2: 23          .byte $23
    F3F3: A0          .byte $A0
    F3F4: 46          .byte $46
    F3F5: 37          .byte $37
    F3F6: 60          .byte $60
    F3F7: 22          .byte $22
    F3F8: 24          .byte $24
    F3F9: A0          .byte $A0
    F3FA: 46          .byte $46
    F3FB: 37          .byte $37
    F3FC: 60          .byte $60
    F3FD: 22          .byte $22
    F3FE: 26          .byte $26
    F3FF: 96          .byte $96
    F400: 3C          .byte $3C
    F401: 32          .byte $32
    F402: 60          .byte $60
    F403: 1E          .byte $1E
    F404: 1C          .byte $1C
    F405: B4          .byte $B4
    F406: 50          .byte $50
    F407: 46          .byte $46
    F408: 60          .byte $60
    F409: 24          .byte $24
    F40A: 26          .byte $26
    F40B: 8C          .byte $8C
    F40C: 28          .byte $28
    F40D: 32          .byte $32
    F40E: 70          .byte $70
    F40F: 24          .byte $24
    F410: 28          .byte $28
    F411: 8C          .byte $8C
    F412: 28          .byte $28
    F413: 32          .byte $32
    F414: 70          .byte $70
    F415: 24          .byte $24
    F416: 2A          .byte $2A
    F417: 78          .byte $78
    F418: 1E          .byte $1E
    F419: 41          .byte $41
    F41A: 70          .byte $70
    F41B: 1E          .byte $1E
    F41C: 1C          .byte $1C
    F41D: B4          .byte $B4
    F41E: 50          .byte $50
    F41F: 46          .byte $46
    F420: 60          .byte $60
    F421: 26          .byte $26
    F422: 28          .byte $28
    F423: 78          .byte $78
    F424: 28          .byte $28
    F425: 2D          .byte $2D
    F426: 70          .byte $70
    F427: 26          .byte $26
    F428: 2A          .byte $2A
    F429: 78          .byte $78
    F42A: 28          .byte $28
    F42B: 2D          .byte $2D
    F42C: 70          .byte $70
    F42D: 26          .byte $26
    F42E: 2C          .byte $2C
    F42F: 64          .byte $64
    F430: 1E          .byte $1E
    F431: 32          .byte $32
    F432: 70          .byte $70
    F433: 1E          .byte $1E
    F434: 1C          .byte $1C
    F435: B4          .byte $B4
    F436: 50          .byte $50
    F437: 46          .byte $46
    F438: 60          .byte $60
    F439: 28          .byte $28
    F43A: 2C          .byte $2C
    F43B: 64          .byte $64
    F43C: 1E          .byte $1E
    F43D: 2D          .byte $2D
    F43E: 70          .byte $70
    F43F: 28          .byte $28
    F440: 2E          .byte $2E
    F441: 64          .byte $64
    F442: 1E          .byte $1E
    F443: 2D          .byte $2D
    F444: 70          .byte $70
    F445: 28          .byte $28
    F446: 30          .byte $30
    F447: 5A          .byte $5A
    F448: 14          .byte $14
    F449: 28          .byte $28
    F44A: 70          .byte $70
    F44B: 1E          .byte $1E
    F44C: 1C          .byte $1C
    F44D: B4          .byte $B4
    F44E: 50          .byte $50
    F44F: 46          .byte $46
    F450: 60          .byte $60
    F451: 2A          .byte $2A
    F452: 2E          .byte $2E
    F453: 5A          .byte $5A
    F454: 1E          .byte $1E
    F455: 2D          .byte $2D
    F456: 80          .byte $80
    F457: 2A          .byte $2A
    F458: 30          .byte $30
    F459: 50          .byte $50
    F45A: 14          .byte $14
    F45B: 28          .byte $28
    F45C: 80          .byte $80
    F45D: 2A          .byte $2A
    F45E: 34          .byte $34
    F45F: 5A          .byte $5A
    F460: 1E          .byte $1E
    F461: 2D          .byte $2D
    F462: 80          .byte $80
    F463: 1E          .byte $1E
    F464: 1C          .byte $1C
    F465: B4          .byte $B4
    F466: 50          .byte $50
    F467: 46          .byte $46
    F468: 60          .byte $60
    F469: 2C          .byte $2C
    F46A: 32          .byte $32
    F46B: 50          .byte $50
    F46C: 1E          .byte $1E
    F46D: 28          .byte $28
    F46E: 80          .byte $80
    F46F: 2C          .byte $2C
    F470: 32          .byte $32
    F471: 3C          .byte $3C
    F472: 14          .byte $14
    F473: 28          .byte $28
    F474: 80          .byte $80
    F475: 2C          .byte $2C
    F476: 34          .byte $34
    F477: 50          .byte $50
    F478: 1E          .byte $1E
    F479: 28          .byte $28
    F47A: 80          .byte $80
    F47B: 1E          .byte $1E
    F47C: 1C          .byte $1C
    F47D: B4          .byte $B4
    F47E: 50          .byte $50
    F47F: 46          .byte $46
    F480: 60          .byte $60
    F481: 2C          .byte $2C
    F482: 32          .byte $32
    F483: 3C          .byte $3C
    F484: 14          .byte $14
    F485: 28          .byte $28
    F486: 80          .byte $80
    F487: 2C          .byte $2C
    F488: 36          .byte $36
    F489: 50          .byte $50
    F48A: 1E          .byte $1E
    F48B: 23          .byte $23
    F48C: 80          .byte $80
    F48D: 2C          .byte $2C
    F48E: 38          .byte $38
    F48F: 50          .byte $50
    F490: 1E          .byte $1E
    F491: 28          .byte $28
    F492: 80          .byte $80
    F493: 1E          .byte $1E
    F494: 1C          .byte $1C
    F495: B4          .byte $B4
    F496: 50          .byte $50
    F497: 46          .byte $46
    F498: 60          .byte $60
    F499: 2C          .byte $2C
    F49A: 38          .byte $38
    F49B: 3C          .byte $3C
    F49C: 14          .byte $14
    F49D: 28          .byte $28
    F49E: 80          .byte $80

jump_table_dispatch_via_index:
    F49F: 0A          asl a
    F4A0: A8          tay
    F4A1: C8          iny
    F4A2: 68          pla
    F4A3: 85 F6       sta sound_scratch   ; $F6
    F4A5: 68          pla
    F4A6: 85 F7       sta $f7
    F4A8: B1 F6       lda (sound_scratch),y   ; $F6
    F4AA: AA          tax
    F4AB: C8          iny
    F4AC: B1 F6       lda (sound_scratch),y   ; $F6
    F4AE: 85 F7       sta $f7
    F4B0: 86 F6       stx sound_scratch   ; $F6
    F4B2: 6C F6 00    jmp (sound_scratch)   ; $00F6

init_apu_channels_and_frame_counter:
    F4B5: A9 0F       lda #$0f
    F4B7: 8D 15 40    sta APUSTATUS   ; $4015
    F4BA: A9 C0       lda #$c0
    F4BC: 8D 17 40    sta JOY2   ; $4017

init_sound_voices:
    F4BF: A9 19       lda #$19
    F4C1: 85 F0       sta voice_rec_ptr   ; $F0
    F4C3: A9 06       lda #$06
    F4C5: 85 F1       sta voice_rec_ptr_hi   ; $F1
    F4C7: A2 00       ldx #$00
    F4C9: A0 00       ldy #$00
@F4CB:
    F4CB: A9 00       lda #$00
    F4CD: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F4CF: 9D 00 06    sta sound_trigger,x   ; $0600
    F4D2: 18          clc
    F4D3: A5 F0       lda voice_rec_ptr   ; $F0
    F4D5: 69 08       adc #$08
    F4D7: 85 F0       sta voice_rec_ptr   ; $F0
    F4D9: 90 02       bcc @F4DD   ; $F4DD
    F4DB: E6 F1       inc voice_rec_ptr_hi   ; $F1
@F4DD:
    F4DD: E8          inx
    F4DE: E0 19       cpx #$19
    F4E0: D0 E9       bne @F4CB   ; $F4CB
    F4E2: A2 19       ldx #$19
    F4E4: A0 00       ldy #$00
@F4E6:
    F4E6: B9 9E F8    lda $f89e,y
    F4E9: 99 E2 06    sta $06e2,y
    F4EC: C8          iny
    F4ED: CA          dex
    F4EE: D0 F6       bne @F4E6   ; $F4E6
    F4F0: 60          rts

update_sound_frame:
    F4F1: A5 23       lda paused   ; $23
    F4F3: D0 06       bne @F4FB   ; $F4FB
    F4F5: A9 19       lda #$19
    F4F7: 85 F5       sta voice_count   ; $F5
    F4F9: 10 0E       bpl @F509   ; $F509
@F4FB:
    F4FB: A9 01       lda #$01
    F4FD: 85 F5       sta voice_count   ; $F5
    F4FF: A9 10       lda #$10
    F501: 8D 04 40    sta APU_4004   ; $4004
    F504: A9 00       lda #$00
    F506: 8D 08 40    sta APU_4008   ; $4008
@F509:
    F509: A9 00       lda #$00
    F50B: 85 FC       sta $fc
    F50D: 85 FD       sta $fd
    F50F: 85 FE       sta $fe
    F511: 85 FF       sta $ff
    F513: A5 F5       lda voice_count   ; $F5
    F515: 85 F4       sta voice_index   ; $F4
    F517: A9 19       lda #$19
    F519: 85 F0       sta voice_rec_ptr   ; $F0
    F51B: A9 06       lda #$06
    F51D: 85 F1       sta voice_rec_ptr_hi   ; $F1
@F51F:
    F51F: A0 00       ldy #$00
    F521: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F523: F0 35       beq sound_registers_next_voice   ; $F55A
    F525: C9 05       cmp #$05
    F527: 90 0B       bcc @F534   ; $F534
    F529: 38          sec
    F52A: E9 05       sbc #$05
    F52C: AA          tax
    F52D: A9 01       lda #$01
    F52F: 95 FC       sta $fc,x
    F531: 4C 5A F5    jmp sound_registers_next_voice   ; $F55A
@F534:
    F534: AA          tax
    F535: CA          dex
    F536: B5 FC       lda $fc,x
    F538: D0 20       bne sound_registers_next_voice   ; $F55A
    F53A: A9 01       lda #$01
    F53C: 95 FC       sta $fc,x
    F53E: 8A          txa
    F53F: A8          tay
    F540: 18          clc
    F541: 69 05       adc #$05
    F543: A0 00       ldy #$00
    F545: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F547: 8A          txa
    F548: 0A          asl a
    F549: 0A          asl a
    F54A: AA          tax
    F54B: A9 04       lda #$04
    F54D: 85 F6       sta sound_scratch   ; $F6
@F54F:
    F54F: C8          iny
    F550: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F552: 9D 00 40    sta APU_4000,x   ; $4000
    F555: E8          inx
    F556: C6 F6       dec sound_scratch   ; $F6
    F558: D0 F5       bne @F54F   ; $F54F

sound_registers_next_voice:
    F55A: 18          clc
    F55B: A5 F0       lda voice_rec_ptr   ; $F0
    F55D: 69 08       adc #$08
    F55F: 85 F0       sta voice_rec_ptr   ; $F0
    F561: 90 02       bcc @F565   ; $F565
    F563: E6 F1       inc voice_rec_ptr_hi   ; $F1
@F565:
    F565: C6 F4       dec voice_index   ; $F4
    F567: D0 B6       bne @F51F   ; $F51F
    F569: A2 00       ldx #$00
@F56B:
    F56B: 86 F6       stx sound_scratch   ; $F6
    F56D: B5 FC       lda $fc,x
    F56F: D0 0C       bne @F57D   ; $F57D
    F571: 8A          txa
    F572: 0A          asl a
    F573: 0A          asl a
    F574: AA          tax
    F575: 0A          asl a
    F576: 29 10       and #$10
    F578: 49 10       eor #$10
    F57A: 9D 00 40    sta APU_4000,x   ; $4000
@F57D:
    F57D: A6 F6       ldx sound_scratch   ; $F6
    F57F: E8          inx
    F580: E0 04       cpx #$04
    F582: 90 E7       bcc @F56B   ; $F56B
    F584: A0 00       ldy #$00
    F586: 84 F4       sty voice_index   ; $F4
    F588: A9 19       lda #$19
    F58A: 85 F0       sta voice_rec_ptr   ; $F0
    F58C: A9 06       lda #$06
    F58E: 85 F1       sta voice_rec_ptr_hi   ; $F1
@F590:
    F590: A6 F4       ldx voice_index   ; $F4
    F592: BD 85 F8    lda $f885,x
    F595: F0 0D       beq @F5A4   ; $F5A4
    F597: BD 00 06    lda sound_trigger,x   ; $0600
    F59A: D0 15       bne @F5B1   ; $F5B1
    F59C: A0 00       ldy #$00
    F59E: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F5A0: F0 16       beq sound_streams_next_voice   ; $F5B8
    F5A2: D0 28       bne @F5CC   ; $F5CC
@F5A4:
    F5A4: BD 00 06    lda sound_trigger,x   ; $0600
    F5A7: F0 0F       beq sound_streams_next_voice   ; $F5B8
    F5A9: A0 00       ldy #$00
    F5AB: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F5AD: D0 1D       bne @F5CC   ; $F5CC
    F5AF: F0 28       beq @F5D9   ; $F5D9
@F5B1:
    F5B1: A9 00       lda #$00
    F5B3: 9D 00 06    sta sound_trigger,x   ; $0600
    F5B6: 10 21       bpl @F5D9   ; $F5D9

sound_streams_next_voice:
    F5B8: 18          clc
    F5B9: A5 F0       lda voice_rec_ptr   ; $F0
    F5BB: 69 08       adc #$08
    F5BD: 85 F0       sta voice_rec_ptr   ; $F0
    F5BF: 90 02       bcc @F5C3   ; $F5C3
    F5C1: E6 F1       inc voice_rec_ptr_hi   ; $F1
@F5C3:
    F5C3: E6 F4       inc voice_index   ; $F4
    F5C5: A5 F4       lda voice_index   ; $F4
    F5C7: C5 F5       cmp voice_count   ; $F5
    F5C9: 90 C5       bcc @F590   ; $F590
    F5CB: 60          rts
@F5CC:
    F5CC: A0 07       ldy #$07
    F5CE: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F5D0: 38          sec
    F5D1: E9 01       sbc #$01
    F5D3: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F5D5: F0 5C       beq @F633   ; $F633
    F5D7: D0 DF       bne sound_streams_next_voice   ; $F5B8
@F5D9:
    F5D9: A5 F4       lda voice_index   ; $F4
    F5DB: C9 13       cmp #$13
    F5DD: F0 10       beq @F5EF   ; $F5EF
    F5DF: C9 14       cmp #$14
    F5E1: F0 19       beq @F5FC   ; $F5FC
    F5E3: A9 00       lda #$00
    F5E5: A0 05       ldy #$05
    F5E7: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F5E9: 20 F4 F7    jsr load_voice_stream_ptr   ; $F7F4
    F5EC: 4C 06 F6    jmp start_voice_stream   ; $F606
@F5EF:
    F5EF: AD 79 F8    lda $f879
    F5F2: 85 F8       sta voice13_stream_ptr   ; $F8
    F5F4: AD 7A F8    lda $f87a
    F5F7: 85 F9       sta voice13_stream_ptr_hi   ; $F9
    F5F9: 4C 06 F6    jmp start_voice_stream   ; $F606
@F5FC:
    F5FC: AD 7B F8    lda $f87b
    F5FF: 85 FA       sta voice14_stream_ptr   ; $FA
    F601: AD 7C F8    lda $f87c
    F604: 85 FB       sta voice14_stream_ptr_hi   ; $FB

start_voice_stream:
    F606: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F609: A0 00       ldy #$00
    F60B: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F60D: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F610: A0 01       ldy #$01
    F612: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F614: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F617: A0 02       ldy #$02
    F619: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F61B: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F61E: A0 04       ldy #$04
    F620: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F622: A0 00       ldy #$00
    F624: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F626: C9 04       cmp #$04
    F628: D0 0C       bne run_voice_stream   ; $F636
    F62A: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F62D: A0 03       ldy #$03
    F62F: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F631: 10 03       bpl run_voice_stream   ; $F636
@F633:
    F633: 20 F4 F7    jsr load_voice_stream_ptr   ; $F7F4

run_voice_stream:
    F636: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F639: C9 E8       cmp #$e8
    F63B: B0 6A       bcs @F6A7   ; $F6A7
    F63D: C9 60       cmp #$60
    F63F: F0 3B       beq @F67C   ; $F67C
    F641: B0 5C       bcs @F69F   ; $F69F
    F643: 48          pha
    F644: 29 F8       and #$f8
    F646: 4A          lsr a
    F647: 4A          lsr a
    F648: AA          tax
    F649: BD 3B F8    lda $f83b,x
    F64C: 85 F6       sta sound_scratch   ; $F6
    F64E: BD 3C F8    lda $f83c,x
    F651: 85 F7       sta $f7
    F653: 68          pla
    F654: 29 07       and #$07
    F656: F0 08       beq @F660   ; $F660
    F658: AA          tax
@F659:
    F659: 46 F6       lsr sound_scratch   ; $F6
    F65B: 66 F7       ror $f7
    F65D: CA          dex
    F65E: D0 F9       bne @F659   ; $F659
@F660:
    F660: A0 04       ldy #$04
    F662: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F664: 29 F8       and #$f8
    F666: 05 F6       ora sound_scratch   ; $F6
    F668: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F66A: A5 F7       lda $f7
    F66C: 88          dey
    F66D: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F66F: A0 00       ldy #$00
    F671: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F673: C9 05       cmp #$05
    F675: 90 05       bcc @F67C   ; $F67C
    F677: 38          sec
    F678: E9 04       sbc #$04
    F67A: 91 F0       sta (voice_rec_ptr),y   ; $F0
@F67C:
    F67C: A0 06       ldy #$06
    F67E: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F680: 85 F6       sta sound_scratch   ; $F6
    F682: A6 F4       ldx voice_index   ; $F4
    F684: BD E2 06    lda $06e2,x
    F687: 85 F7       sta $f7
    F689: A9 00       lda #$00
    F68B: A2 08       ldx #$08
@F68D:
    F68D: 46 F7       lsr $f7
    F68F: 90 03       bcc @F694   ; $F694
    F691: 18          clc
    F692: 65 F6       adc sound_scratch   ; $F6
@F694:
    F694: 06 F6       asl sound_scratch   ; $F6
    F696: CA          dex
    F697: D0 F4       bne @F68D   ; $F68D
    F699: C8          iny
    F69A: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F69C: 4C B8 F5    jmp sound_streams_next_voice   ; $F5B8
@F69F:
    F69F: E9 60       sbc #$60
    F6A1: A0 06       ldy #$06
    F6A3: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F6A5: 10 8F       bpl run_voice_stream   ; $F636
@F6A7:
    F6A7: E9 E8       sbc #$e8
    F6A9: 20 9F F4    jsr jump_table_dispatch_via_index   ; $F49F
    F6AC:            .word voice_op_end
    F6AE:            .word voice_op_set_duty
    F6B0:            .word voice_op_set_envelope
    F6B2:            .word voice_op_set_volume
    F6B4:            .word voice_op_set_sweep
    F6B6:            .word voice_op_set_length_period_hi
    F6B8:            .word voice_op_set_control
    F6BA:            .word voice_op_clear_loop_counters
    F6BC:            .word voice_op_repeat_0
    F6BE:            .word voice_op_repeat_1
    F6C0:            .word voice_op_repeat_2
    F6C2:            .word voice_op_jump_on_count_0
    F6C4:            .word voice_op_jump_on_count_1
    F6C6:            .word voice_op_jump_on_count_2
    F6C8:            .word voice_op_jump_on_count_3
    F6CA:            .word voice_op_jump_on_count_4
    F6CC:            .word voice_op_jump_on_count_5
    F6CE:            .word voice_op_jump

voice_op_end:
    F6D0: A6 F4       ldx voice_index   ; $F4
    F6D2: A9 00       lda #$00
    F6D4: 9D 00 06    sta sound_trigger,x   ; $0600
    F6D7: A0 00       ldy #$00
    F6D9: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F6DB: 4C B8 F5    jmp sound_streams_next_voice   ; $F5B8

voice_op_set_duty:
    F6DE: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F6E1: 85 F6       sta sound_scratch   ; $F6
    F6E3: A0 01       ldy #$01
    F6E5: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F6E7: 29 3F       and #$3f
    F6E9: 05 F6       ora sound_scratch   ; $F6
    F6EB: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F6ED: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_set_envelope:
    F6F0: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F6F3: 85 F6       sta sound_scratch   ; $F6
    F6F5: A0 01       ldy #$01
    F6F7: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F6F9: 29 C0       and #$c0
    F6FB: 05 F6       ora sound_scratch   ; $F6
    F6FD: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F6FF: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_set_volume:
    F702: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F705: 85 F6       sta sound_scratch   ; $F6
    F707: A0 01       ldy #$01
    F709: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F70B: 29 F0       and #$f0
    F70D: 05 F6       ora sound_scratch   ; $F6
    F70F: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F711: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_set_sweep:
    F714: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F717: A0 02       ldy #$02
    F719: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F71B: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_set_length_period_hi:
    F71E: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F721: A0 04       ldy #$04
    F723: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F725: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_set_control:
    F728: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F72B: A0 01       ldy #$01
    F72D: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F72F: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_clear_loop_counters:
    F732: A9 00       lda #$00
    F734: A2 08       ldx #$08
@F736:
    F736: 9D 61 01    sta $0161,x
    F739: CA          dex
    F73A: 10 FA       bpl @F736   ; $F736
    F73C: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_repeat_0:
    F73F: A2 00       ldx #$00
    F741: F0 05       beq @F748   ; $F748

voice_op_repeat_1:
    F743: A2 01       ldx #$01
    F745: 2C A2 02    bit $02a2

voice_op_repeat_2:
    F746: A2 02       ldx #$02
@F748:
    F748: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F74B: FE 61 01    inc $0161,x
    F74E: DD 61 01    cmp $0161,x
    F751: D0 6F       bne voice_op_jump   ; $F7C2
    F753: A9 00       lda #$00
    F755: 9D 61 01    sta $0161,x
    F758: F0 36       beq @F790   ; $F790

voice_op_jump_on_count_0:
    F75A: A2 00       ldx #$00
    F75C: F0 05       beq @F763   ; $F763

voice_op_jump_on_count_1:
    F75E: A2 01       ldx #$01
    F760: 2C A2 02    bit $02a2

voice_op_jump_on_count_2:
    F761: A2 02       ldx #$02
@F763:
    F763: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F766: FE 64 01    inc $0164,x
    F769: DD 64 01    cmp $0164,x
    F76C: D0 22       bne @F790   ; $F790
    F76E: A9 00       lda #$00
    F770: 9D 64 01    sta $0164,x
    F773: F0 4D       beq voice_op_jump   ; $F7C2

voice_op_jump_on_count_3:
    F775: A2 00       ldx #$00
    F777: F0 05       beq @F77E   ; $F77E

voice_op_jump_on_count_4:
    F779: A2 01       ldx #$01
    F77B: 2C A2 02    bit $02a2

voice_op_jump_on_count_5:
    F77C: A2 02       ldx #$02
@F77E:
    F77E: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F781: FE 67 01    inc $0167,x
    F784: DD 67 01    cmp $0167,x
    F787: D0 07       bne @F790   ; $F790
    F789: A9 00       lda #$00
    F78B: 9D 67 01    sta $0167,x
    F78E: F0 32       beq voice_op_jump   ; $F7C2
@F790:
    F790: A5 F4       lda voice_index   ; $F4
    F792: C9 13       cmp #$13
    F794: F0 10       beq @F7A6   ; $F7A6
    F796: C9 14       cmp #$14
    F798: F0 1A       beq @F7B4   ; $F7B4
    F79A: A0 05       ldy #$05
    F79C: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F79E: 18          clc
    F79F: 69 01       adc #$01
    F7A1: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F7A3: 4C 36 F6    jmp run_voice_stream   ; $F636
@F7A6:
    F7A6: A5 F8       lda voice13_stream_ptr   ; $F8
    F7A8: 18          clc
    F7A9: 69 02       adc #$02
    F7AB: 85 F8       sta voice13_stream_ptr   ; $F8
    F7AD: 90 02       bcc @F7B1   ; $F7B1
    F7AF: E6 F9       inc voice13_stream_ptr_hi   ; $F9
@F7B1:
    F7B1: 4C 36 F6    jmp run_voice_stream   ; $F636
@F7B4:
    F7B4: A5 FA       lda voice14_stream_ptr   ; $FA
    F7B6: 18          clc
    F7B7: 69 02       adc #$02
    F7B9: 85 FA       sta voice14_stream_ptr   ; $FA
    F7BB: 90 02       bcc @F7BF   ; $F7BF
    F7BD: E6 FB       inc voice14_stream_ptr_hi   ; $FB
@F7BF:
    F7BF: 4C 36 F6    jmp run_voice_stream   ; $F636

voice_op_jump:
    F7C2: A5 F4       lda voice_index   ; $F4
    F7C4: C9 13       cmp #$13
    F7C6: F0 0E       beq @F7D6   ; $F7D6
    F7C8: C9 14       cmp #$14
    F7CA: F0 19       beq @F7E5   ; $F7E5
    F7CC: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F7CF: A0 05       ldy #$05
    F7D1: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F7D3: 4C 36 F6    jmp run_voice_stream   ; $F636
@F7D6:
    F7D6: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F7D9: 48          pha
    F7DA: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F7DD: 85 F9       sta voice13_stream_ptr_hi   ; $F9
    F7DF: 68          pla
    F7E0: 85 F8       sta voice13_stream_ptr   ; $F8
    F7E2: 4C 36 F6    jmp run_voice_stream   ; $F636
@F7E5:
    F7E5: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F7E8: 48          pha
    F7E9: 20 0B F8    jsr fetch_voice_stream_byte   ; $F80B
    F7EC: 85 FB       sta voice14_stream_ptr_hi   ; $FB
    F7EE: 68          pla
    F7EF: 85 FA       sta voice14_stream_ptr   ; $FA
    F7F1: 4C 36 F6    jmp run_voice_stream   ; $F636

load_voice_stream_ptr:
    F7F4: A5 F4       lda voice_index   ; $F4
    F7F6: C9 13       cmp #$13
    F7F8: F0 10       beq @F80A   ; $F80A
    F7FA: C9 14       cmp #$14
    F7FC: F0 0C       beq @F80A   ; $F80A
    F7FE: 0A          asl a
    F7FF: AA          tax
    F800: BD 53 F8    lda $f853,x
    F803: 85 F2       sta voice_stream_ptr   ; $F2
    F805: BD 54 F8    lda $f854,x
    F808: 85 F3       sta voice_stream_ptr_hi   ; $F3
@F80A:
    F80A: 60          rts

fetch_voice_stream_byte:
    F80B: A5 F4       lda voice_index   ; $F4
    F80D: C9 13       cmp #$13
    F80F: F0 14       beq @F825   ; $F825
    F811: C9 14       cmp #$14
    F813: F0 1B       beq @F830   ; $F830
    F815: A0 05       ldy #$05
    F817: B1 F0       lda (voice_rec_ptr),y   ; $F0
    F819: A8          tay
    F81A: B1 F2       lda (voice_stream_ptr),y   ; $F2
    F81C: 48          pha
    F81D: C8          iny
    F81E: 98          tya
    F81F: A0 05       ldy #$05
    F821: 91 F0       sta (voice_rec_ptr),y   ; $F0
    F823: 68          pla
    F824: 60          rts
@F825:
    F825: A0 00       ldy #$00
    F827: B1 F8       lda (voice13_stream_ptr),y   ; $F8
    F829: E6 F8       inc voice13_stream_ptr   ; $F8
    F82B: D0 02       bne @F82F   ; $F82F
    F82D: E6 F9       inc voice13_stream_ptr_hi   ; $F9
@F82F:
    F82F: 60          rts
@F830:
    F830: A0 00       ldy #$00
    F832: B1 FA       lda (voice14_stream_ptr),y   ; $FA
    F834: E6 FA       inc voice14_stream_ptr   ; $FA
    F836: D0 02       bne @F83A   ; $F83A
    F838: E6 FB       inc voice14_stream_ptr_hi   ; $FB
@F83A:
    F83A: 60          rts
    F83B: 07          .byte $07
    F83C: F2          .byte $F2
    F83D: 07          .byte $07
    F83E: 80          .byte $80
    F83F: 07          .byte $07
    F840: 14          .byte $14
    F841: 06          .byte $06
    F842: AE          .byte $AE
    F843: 06          .byte $06
    F844: 43          .byte $43
    F845: 05          .byte $05
    F846: F4          .byte $F4
    F847: 05          .byte $05
    F848: 9E          .byte $9E
    F849: 05          .byte $05
    F84A: 4E          .byte $4E
    F84B: 05          .byte $05
    F84C: 02          .byte $02
    F84D: 04          .byte $04
    F84E: BA          .byte $BA
    F84F: 04          .byte $04
    F850: 76          .byte $76
    F851: 04          .byte $04
    F852: 36          .byte $36
    F853: 86          .byte $86
    F854: FE          .byte $FE
    F855: 92          .byte $92
    F856: FE          .byte $FE
    F857: 13          .byte $13
    F858: FB          .byte $FB
    F859: 2B          .byte $2B
    F85A: FB          .byte $FB
    F85B: 3D          .byte $3D
    F85C: FB          .byte $FB
    F85D: BA          .byte $BA
    F85E: FD          .byte $FD
    F85F: A6          .byte $A6
    F860: FD          .byte $FD
    F861: 9F          .byte $9F
    F862: FD          .byte $FD
    F863: 89          .byte $89
    F864: FD          .byte $FD
    F865: 64          .byte $64
    F866: FD          .byte $FD
    F867: 56          .byte $56
    F868: FD          .byte $FD
    F869: 1A          .byte $1A
    F86A: FD          .byte $FD
    F86B: 38          .byte $38
    F86C: FD          .byte $FD
    F86D: 47          .byte $47
    F86E: FD          .byte $FD
    F86F: 55          .byte $55
    F870: FB          .byte $FB
    F871: F5          .byte $F5
    F872: FB          .byte $FB
    F873: 69          .byte $69
    F874: FC          .byte $FC
    F875: 5A          .byte $5A
    F876: FE          .byte $FE
    F877: 72          .byte $72
    F878: FE          .byte $FE
    F879: B7          .byte $B7
    F87A: F8          .byte $F8
    F87B: 14          .byte $14
    F87C: FA          .byte $FA
    F87D: C2          .byte $C2
    F87E: FD          .byte $FD
    F87F: F9          .byte $F9
    F880: FD          .byte $FD
    F881: 2A          .byte $2A
    F882: FE          .byte $FE
    F883: 0D          .byte $0D
    F884: FF          .byte $FF
    F885: 00          .byte $00
    F886: 00          .byte $00
    F887: 00          .byte $00
    F888: 00          .byte $00
    F889: 00          .byte $00
    F88A: 00          .byte $00
    F88B: 00          .byte $00
    F88C: 00          .byte $00
    F88D: 01          .byte $01
    F88E: 00          .byte $00
    F88F: 01          .byte $01
    F890: 00          .byte $00
    F891: 00          .byte $00
    F892: 00          .byte $00
    F893: 00          .byte $00
    F894: 00          .byte $00
    F895: 00          .byte $00
    F896: 00          .byte $00
    F897: 00          .byte $00
    F898: 00          .byte $00
    F899: 00          .byte $00
    F89A: 00          .byte $00
    F89B: 00          .byte $00
    F89C: 00          .byte $00
    F89D: 00          .byte $00
    F89E: 01          .byte $01
    F89F: 01          .byte $01
    F8A0: 01          .byte $01
    F8A1: 01          .byte $01
    F8A2: 01          .byte $01
    F8A3: 01          .byte $01
    F8A4: 01          .byte $01
    F8A5: 01          .byte $01
    F8A6: 01          .byte $01
    F8A7: 01          .byte $01
    F8A8: 01          .byte $01
    F8A9: 01          .byte $01
    F8AA: 01          .byte $01
    F8AB: 01          .byte $01
    F8AC: 01          .byte $01
    F8AD: 01          .byte $01
    F8AE: 01          .byte $01
    F8AF: 01          .byte $01
    F8B0: 01          .byte $01
    F8B1: 04          .byte $04
    F8B2: 04          .byte $04
    F8B3: 01          .byte $01
    F8B4: 01          .byte $01
    F8B5: 01          .byte $01
    F8B6: 01          .byte $01
    F8B7: 01          .byte $01
    F8B8: 03          .byte $03
    F8B9: 7F          .byte $7F
    F8BA: 40          .byte $40
    F8BB: EF          .byte $EF
    F8BC: 64          .byte $64
    F8BD: 32          .byte $32
    F8BE: 13          .byte $13
    F8BF: 0B          .byte $0B
    F8C0: 13          .byte $13
    F8C1: EA          .byte $EA
    F8C2: 20          .byte $20
    F8C3: 67          .byte $67
    F8C4: 1B          .byte $1B
    F8C5: 69          .byte $69
    F8C6: 13          .byte $13
    F8C7: EA          .byte $EA
    F8C8: 03          .byte $03
    F8C9: 64          .byte $64
    F8CA: 03          .byte $03
    F8CB: 13          .byte $13
    F8CC: 63          .byte $63
    F8CD: 03          .byte $03
    F8CE: 61          .byte $61
    F8CF: 52          .byte $52
    F8D0: 63          .byte $63
    F8D1: 3A          .byte $3A
    F8D2: EA          .byte $EA
    F8D3: 20          .byte $20
    F8D4: 71          .byte $71
    F8D5: 03          .byte $03
    F8D6: EA          .byte $EA
    F8D7: 03          .byte $03
    F8D8: 64          .byte $64
    F8D9: 2A          .byte $2A
    F8DA: 03          .byte $03
    F8DB: 5A          .byte $5A
    F8DC: 03          .byte $03
    F8DD: EA          .byte $EA
    F8DE: 20          .byte $20
    F8DF: 67          .byte $67
    F8E0: 13          .byte $13
    F8E1: 69          .byte $69
    F8E2: 03          .byte $03
    F8E3: EA          .byte $EA
    F8E4: 03          .byte $03
    F8E5: 64          .byte $64
    F8E6: 52          .byte $52
    F8E7: 03          .byte $03
    F8E8: 63          .byte $63
    F8E9: 52          .byte $52
    F8EA: 64          .byte $64
    F8EB: 3A          .byte $3A
    F8EC: EA          .byte $EA
    F8ED: 20          .byte $20
    F8EE: 71          .byte $71
    F8EF: 2A          .byte $2A
    F8F0: EA          .byte $EA
    F8F1: 03          .byte $03
    F8F2: 63          .byte $63
    F8F3: 12          .byte $12
    F8F4: 61          .byte $61
    F8F5: 2A          .byte $2A
    F8F6: 63          .byte $63
    F8F7: 52          .byte $52
    F8F8: 61          .byte $61
    F8F9: 12          .byte $12
    F8FA: 63          .byte $63
    F8FB: 2A          .byte $2A
    F8FC: 61          .byte $61
    F8FD: 52          .byte $52
    F8FE: 63          .byte $63
    F8FF: 12          .byte $12
    F900: 61          .byte $61
    F901: 52          .byte $52
    F902: 63          .byte $63
    F903: 1A          .byte $1A
    F904: 61          .byte $61
    F905: 3A          .byte $3A
    F906: 63          .byte $63
    F907: 52          .byte $52
    F908: 61          .byte $61
    F909: 22          .byte $22
    F90A: 63          .byte $63
    F90B: 3A          .byte $3A
    F90C: 61          .byte $61
    F90D: 52          .byte $52
    F90E: 63          .byte $63
    F90F: 22          .byte $22
    F910: 61          .byte $61
    F911: 52          .byte $52
    F912: F6          .byte $F6
    F913: 04          .byte $04
    F914: FE          .byte $FE
    F915: F9          .byte $F9
    F916: 64          .byte $64
    F917: 60          .byte $60
    F918: 63          .byte $63
    F919: 13          .byte $13
    F91A: 61          .byte $61
    F91B: 0B          .byte $0B
    F91C: 64          .byte $64
    F91D: 03          .byte $03
    F91E: 63          .byte $63
    F91F: 2A          .byte $2A
    F920: 65          .byte $65
    F921: 52          .byte $52
    F922: 64          .byte $64
    F923: 52          .byte $52
    F924: 4A          .byte $4A
    F925: 3A          .byte $3A
    F926: F3          .byte $F3
    F927: 03          .byte $03
    F928: 97          .byte $97
    F929: F9          .byte $F9
    F92A: F0          .byte $F0
    F92B: 02          .byte $02
    F92C: BC          .byte $BC
    F92D: F8          .byte $F8
    F92E: 63          .byte $63
    F92F: 12          .byte $12
    F930: 61          .byte $61
    F931: 4A          .byte $4A
    F932: 63          .byte $63
    F933: 32          .byte $32
    F934: 61          .byte $61
    F935: 12          .byte $12
    F936: 63          .byte $63
    F937: 4A          .byte $4A
    F938: 61          .byte $61
    F939: 32          .byte $32
    F93A: F0          .byte $F0
    F93B: 05          .byte $05
    F93C: 2E          .byte $2E
    F93D: F9          .byte $F9
    F93E: 63          .byte $63
    F93F: 12          .byte $12
    F940: 61          .byte $61
    F941: 4A          .byte $4A
    F942: 63          .byte $63
    F943: 02          .byte $02
    F944: 61          .byte $61
    F945: 3A          .byte $3A
    F946: 63          .byte $63
    F947: 22          .byte $22
    F948: 61          .byte $61
    F949: 02          .byte $02
    F94A: 63          .byte $63
    F94B: 3A          .byte $3A
    F94C: 61          .byte $61
    F94D: 22          .byte $22
    F94E: F0          .byte $F0
    F94F: 05          .byte $05
    F950: 42          .byte $42
    F951: F9          .byte $F9
    F952: 64          .byte $64
    F953: 02          .byte $02
    F954: 63          .byte $63
    F955: 51          .byte $51
    F956: 61          .byte $61
    F957: 02          .byte $02
    F958: 63          .byte $63
    F959: 12          .byte $12
    F95A: 61          .byte $61
    F95B: 51          .byte $51
    F95C: 63          .byte $63
    F95D: 02          .byte $02
    F95E: 61          .byte $61
    F95F: 12          .byte $12
    F960: 63          .byte $63
    F961: 1A          .byte $1A
    F962: 61          .byte $61
    F963: 02          .byte $02
    F964: 63          .byte $63
    F965: 12          .byte $12
    F966: 61          .byte $61
    F967: 1A          .byte $1A
    F968: 63          .byte $63
    F969: 2A          .byte $2A
    F96A: 61          .byte $61
    F96B: 12          .byte $12
    F96C: 63          .byte $63
    F96D: 1A          .byte $1A
    F96E: 61          .byte $61
    F96F: 2A          .byte $2A
    F970: 63          .byte $63
    F971: 3A          .byte $3A
    F972: 61          .byte $61
    F973: 1A          .byte $1A
    F974: 63          .byte $63
    F975: 2A          .byte $2A
    F976: 61          .byte $61
    F977: 3A          .byte $3A
    F978: 63          .byte $63
    F979: 4A          .byte $4A
    F97A: 61          .byte $61
    F97B: 2A          .byte $2A
    F97C: 63          .byte $63
    F97D: 3A          .byte $3A
    F97E: 61          .byte $61
    F97F: 4A          .byte $4A
    F980: 63          .byte $63
    F981: 52          .byte $52
    F982: 61          .byte $61
    F983: 03          .byte $03
    F984: 64          .byte $64
    F985: 13          .byte $13
    F986: 63          .byte $63
    F987: 0B          .byte $0B
    F988: 61          .byte $61
    F989: 13          .byte $13
    F98A: 63          .byte $63
    F98B: 0B          .byte $0B
    F98C: 61          .byte $61
    F98D: 13          .byte $13
    F98E: 63          .byte $63
    F98F: 0B          .byte $0B
    F990: 61          .byte $61
    F991: 13          .byte $13
    F992: F0          .byte $F0
    F993: 02          .byte $02
    F994: BC          .byte $BC
    F995: F8          .byte $F8
    F996: E8          .byte $E8
    F997: 64          .byte $64
    F998: 60          .byte $60
    F999: 13          .byte $13
    F99A: 0B          .byte $0B
    F99B: 13          .byte $13
    F99C: 1B          .byte $1B
    F99D: 13          .byte $13
    F99E: 0B          .byte $0B
    F99F: 13          .byte $13
    F9A0: F3          .byte $F3
    F9A1: 02          .byte $02
    F9A2: C6          .byte $C6
    F9A3: F9          .byte $F9
    F9A4: 64          .byte $64
    F9A5: 3A          .byte $3A
    F9A6: 4B          .byte $4B
    F9A7: 3B          .byte $3B
    F9A8: 13          .byte $13
    F9A9: EA          .byte $EA
    F9AA: 0F          .byte $0F
    F9AB: 70          .byte $70
    F9AC: 52          .byte $52
    F9AD: EA          .byte $EA
    F9AE: 03          .byte $03
    F9AF: 64          .byte $64
    F9B0: 60          .byte $60
    F9B1: 03          .byte $03
    F9B2: 5A          .byte $5A
    F9B3: 03          .byte $03
    F9B4: 13          .byte $13
    F9B5: 03          .byte $03
    F9B6: 13          .byte $13
    F9B7: 23          .byte $23
    F9B8: 2A          .byte $2A
    F9B9: 2B          .byte $2B
    F9BA: 1B          .byte $1B
    F9BB: 13          .byte $13
    F9BC: 68          .byte $68
    F9BD: 03          .byte $03
    F9BE: EA          .byte $EA
    F9BF: 0D          .byte $0D
    F9C0: 0B          .byte $0B
    F9C1: EA          .byte $EA
    F9C2: 03          .byte $03
    F9C3: F9          .byte $F9
    F9C4: 97          .byte $97
    F9C5: F9          .byte $F9
    F9C6: 64          .byte $64
    F9C7: 60          .byte $60
    F9C8: 52          .byte $52
    F9C9: 13          .byte $13
    F9CA: 2B          .byte $2B
    F9CB: 63          .byte $63
    F9CC: 4B          .byte $4B
    F9CD: 61          .byte $61
    F9CE: 3B          .byte $3B
    F9CF: 63          .byte $63
    F9D0: 4B          .byte $4B
    F9D1: 64          .byte $64
    F9D2: 3B          .byte $3B
    F9D3: 61          .byte $61
    F9D4: 3B          .byte $3B
    F9D5: 63          .byte $63
    F9D6: 33          .byte $33
    F9D7: 65          .byte $65
    F9D8: 3B          .byte $3B
    F9D9: EA          .byte $EA
    F9DA: 3C          .byte $3C
    F9DB: 68          .byte $68
    F9DC: 53          .byte $53
    F9DD: EA          .byte $EA
    F9DE: 03          .byte $03
    F9DF: 63          .byte $63
    F9E0: 3B          .byte $3B
    F9E1: 61          .byte $61
    F9E2: 13          .byte $13
    F9E3: 63          .byte $63
    F9E4: 2B          .byte $2B
    F9E5: 61          .byte $61
    F9E6: 3B          .byte $3B
    F9E7: 63          .byte $63
    F9E8: 13          .byte $13
    F9E9: 61          .byte $61
    F9EA: 2B          .byte $2B
    F9EB: 63          .byte $63
    F9EC: 3B          .byte $3B
    F9ED: 61          .byte $61
    F9EE: 0B          .byte $0B
    F9EF: 63          .byte $63
    F9F0: 13          .byte $13
    F9F1: 65          .byte $65
    F9F2: 52          .byte $52
    F9F3: 64          .byte $64
    F9F4: 4A          .byte $4A
    F9F5: 3A          .byte $3A
    F9F6: 2A          .byte $2A
    F9F7: 67          .byte $67
    F9F8: 52          .byte $52
    F9F9: 69          .byte $69
    F9FA: 52          .byte $52
    F9FB: F9          .byte $F9
    F9FC: BC          .byte $BC
    F9FD: F8          .byte $F8
    F9FE: 63          .byte $63
    F9FF: 52          .byte $52
    FA00: 61          .byte $61
    FA01: 03          .byte $03
    FA02: 63          .byte $63
    FA03: 13          .byte $13
    FA04: 61          .byte $61
    FA05: 52          .byte $52
    FA06: 64          .byte $64
    FA07: 3A          .byte $3A
    FA08: 2A          .byte $2A
    FA09: 63          .byte $63
    FA0A: 2A          .byte $2A
    FA0B: 61          .byte $61
    FA0C: 3A          .byte $3A
    FA0D: 64          .byte $64
    FA0E: 4A          .byte $4A
    FA0F: 68          .byte $68
    FA10: 52          .byte $52
    FA11: F9          .byte $F9
    FA12: 54          .byte $54
    FA13: F9          .byte $F9
    FA14: 03          .byte $03
    FA15: 23          .byte $23
    FA16: 7F          .byte $7F
    FA17: 08          .byte $08
    FA18: 68          .byte $68
    FA19: 3A          .byte $3A
    FA1A: 67          .byte $67
    FA1B: 12          .byte $12
    FA1C: 64          .byte $64
    FA1D: 3A          .byte $3A
    FA1E: 61          .byte $61
    FA1F: 3A          .byte $3A
    FA20: 64          .byte $64
    FA21: 12          .byte $12
    FA22: 63          .byte $63
    FA23: 3A          .byte $3A
    FA24: 61          .byte $61
    FA25: 4A          .byte $4A
    FA26: 64          .byte $64
    FA27: 5A          .byte $5A
    FA28: 68          .byte $68
    FA29: 03          .byte $03
    FA2A: 67          .byte $67
    FA2B: 3A          .byte $3A
    FA2C: 64          .byte $64
    FA2D: 03          .byte $03
    FA2E: 61          .byte $61
    FA2F: 03          .byte $03
    FA30: 64          .byte $64
    FA31: 52          .byte $52
    FA32: 4A          .byte $4A
    FA33: 3A          .byte $3A
    FA34: 68          .byte $68
    FA35: 2A          .byte $2A
    FA36: 67          .byte $67
    FA37: 02          .byte $02
    FA38: 64          .byte $64
    FA39: 2A          .byte $2A
    FA3A: 61          .byte $61
    FA3B: 2A          .byte $2A
    FA3C: 64          .byte $64
    FA3D: 02          .byte $02
    FA3E: 63          .byte $63
    FA3F: 2A          .byte $2A
    FA40: 61          .byte $61
    FA41: 3A          .byte $3A
    FA42: 64          .byte $64
    FA43: 4A          .byte $4A
    FA44: 68          .byte $68
    FA45: 52          .byte $52
    FA46: 67          .byte $67
    FA47: 2A          .byte $2A
    FA48: 64          .byte $64
    FA49: 52          .byte $52
    FA4A: 61          .byte $61
    FA4B: 52          .byte $52
    FA4C: 64          .byte $64
    FA4D: 2A          .byte $2A
    FA4E: 22          .byte $22
    FA4F: 1A          .byte $1A
    FA50: 51          .byte $51
    FA51: 52          .byte $52
    FA52: 51          .byte $51
    FA53: 52          .byte $52
    FA54: 02          .byte $02
    FA55: 03          .byte $03
    FA56: 0A          .byte $0A
    FA57: 0B          .byte $0B
    FA58: F8          .byte $F8
    FA59: 04          .byte $04
    FA5A: 0A          .byte $0A
    FA5B: FB          .byte $FB
    FA5C: 74          .byte $74
    FA5D: 12          .byte $12
    FA5E: 64          .byte $64
    FA5F: 52          .byte $52
    FA60: 03          .byte $03
    FA61: 0B          .byte $0B
    FA62: F5          .byte $F5
    FA63: 03          .byte $03
    FA64: AA          .byte $AA
    FA65: FA          .byte $FA
    FA66: F2          .byte $F2
    FA67: 02          .byte $02
    FA68: 18          .byte $18
    FA69: FA          .byte $FA
    FA6A: EE          .byte $EE
    FA6B: 7F          .byte $7F
    FA6C: 68          .byte $68
    FA6D: 12          .byte $12
    FA6E: 66          .byte $66
    FA6F: 32          .byte $32
    FA70: 62          .byte $62
    FA71: 4A          .byte $4A
    FA72: 64          .byte $64
    FA73: 5A          .byte $5A
    FA74: 68          .byte $68
    FA75: 13          .byte $13
    FA76: 64          .byte $64
    FA77: 5A          .byte $5A
    FA78: 68          .byte $68
    FA79: 4A          .byte $4A
    FA7A: 5A          .byte $5A
    FA7B: 64          .byte $64
    FA7C: 32          .byte $32
    FA7D: 6C          .byte $6C
    FA7E: 4A          .byte $4A
    FA7F: 68          .byte $68
    FA80: 02          .byte $02
    FA81: 66          .byte $66
    FA82: 22          .byte $22
    FA83: 62          .byte $62
    FA84: 3A          .byte $3A
    FA85: 64          .byte $64
    FA86: 4A          .byte $4A
    FA87: 68          .byte $68
    FA88: 03          .byte $03
    FA89: 64          .byte $64
    FA8A: 4A          .byte $4A
    FA8B: 68          .byte $68
    FA8C: 3A          .byte $3A
    FA8D: 4A          .byte $4A
    FA8E: 64          .byte $64
    FA8F: 22          .byte $22
    FA90: 6C          .byte $6C
    FA91: 3A          .byte $3A
    FA92: EE          .byte $EE
    FA93: 23          .byte $23
    FA94: 64          .byte $64
    FA95: 51          .byte $51
    FA96: 52          .byte $52
    FA97: 02          .byte $02
    FA98: 03          .byte $03
    FA99: 12          .byte $12
    FA9A: 13          .byte $13
    FA9B: 1A          .byte $1A
    FA9C: 1B          .byte $1B
    FA9D: 2A          .byte $2A
    FA9E: 2B          .byte $2B
    FA9F: 3A          .byte $3A
    FAA0: 3B          .byte $3B
    FAA1: 4A          .byte $4A
    FAA2: 4A          .byte $4A
    FAA3: 32          .byte $32
    FAA4: 12          .byte $12
    FAA5: F2          .byte $F2
    FAA6: 02          .byte $02
    FAA7: 18          .byte $18
    FAA8: FA          .byte $FA
    FAA9: E8          .byte $E8
    FAAA: 68          .byte $68
    FAAB: 13          .byte $13
    FAAC: 67          .byte $67
    FAAD: 4A          .byte $4A
    FAAE: 64          .byte $64
    FAAF: 13          .byte $13
    FAB0: 61          .byte $61
    FAB1: 13          .byte $13
    FAB2: 64          .byte $64
    FAB3: 4A          .byte $4A
    FAB4: 63          .byte $63
    FAB5: 13          .byte $13
    FAB6: 61          .byte $61
    FAB7: 23          .byte $23
    FAB8: 64          .byte $64
    FAB9: 33          .byte $33
    FABA: 68          .byte $68
    FABB: 3B          .byte $3B
    FABC: 67          .byte $67
    FABD: 13          .byte $13
    FABE: 64          .byte $64
    FABF: 3B          .byte $3B
    FAC0: 61          .byte $61
    FAC1: 3B          .byte $3B
    FAC2: 64          .byte $64
    FAC3: 2B          .byte $2B
    FAC4: 63          .byte $63
    FAC5: 23          .byte $23
    FAC6: 61          .byte $61
    FAC7: 23          .byte $23
    FAC8: 64          .byte $64
    FAC9: 13          .byte $13
    FACA: 68          .byte $68
    FACB: 03          .byte $03
    FACC: 67          .byte $67
    FACD: 3A          .byte $3A
    FACE: 64          .byte $64
    FACF: 03          .byte $03
    FAD0: 61          .byte $61
    FAD1: 03          .byte $03
    FAD2: 64          .byte $64
    FAD3: 3A          .byte $3A
    FAD4: 63          .byte $63
    FAD5: 03          .byte $03
    FAD6: 61          .byte $61
    FAD7: 13          .byte $13
    FAD8: 64          .byte $64
    FAD9: 23          .byte $23
    FADA: 78          .byte $78
    FADB: 2B          .byte $2B
    FADC: 68          .byte $68
    FADD: 2B          .byte $2B
    FADE: 13          .byte $13
    FADF: 67          .byte $67
    FAE0: 4A          .byte $4A
    FAE1: 64          .byte $64
    FAE2: 13          .byte $13
    FAE3: 61          .byte $61
    FAE4: 13          .byte $13
    FAE5: 64          .byte $64
    FAE6: 1B          .byte $1B
    FAE7: 63          .byte $63
    FAE8: 13          .byte $13
    FAE9: 61          .byte $61
    FAEA: 13          .byte $13
    FAEB: 64          .byte $64
    FAEC: 03          .byte $03
    FAED: 68          .byte $68
    FAEE: 52          .byte $52
    FAEF: 64          .byte $64
    FAF0: 13          .byte $13
    FAF1: 2B          .byte $2B
    FAF2: 3B          .byte $3B
    FAF3: 68          .byte $68
    FAF4: 5B          .byte $5B
    FAF5: 64          .byte $64
    FAF6: 3B          .byte $3B
    FAF7: 1B          .byte $1B
    FAF8: 1B          .byte $1B
    FAF9: 1B          .byte $1B
    FAFA: 1B          .byte $1B
    FAFB: 2B          .byte $2B
    FAFC: 2B          .byte $2B
    FAFD: 2B          .byte $2B
    FAFE: 2B          .byte $2B
    FAFF: 2A          .byte $2A
    FB00: 2A          .byte $2A
    FB01: 3A          .byte $3A
    FB02: 4A          .byte $4A
    FB03: 67          .byte $67
    FB04: 52          .byte $52
    FB05: 69          .byte $69
    FB06: 52          .byte $52
    FB07: F9          .byte $F9
    FB08: 18          .byte $18
    FB09: FA          .byte $FA
    FB0A: 74          .byte $74
    FB0B: 60          .byte $60
    FB0C: 64          .byte $64
    FB0D: 2A          .byte $2A
    FB0E: 68          .byte $68
    FB0F: 52          .byte $52
    FB10: F9          .byte $F9
    FB11: 94          .byte $94
    FB12: FA          .byte $FA
    FB13: 01          .byte $01
    FB14: 04          .byte $04
    FB15: 7F          .byte $7F
    FB16: 40          .byte $40
    FB17: 6C          .byte $6C
    FB18: 2B          .byte $2B
    FB19: 64          .byte $64
    FB1A: 13          .byte $13
    FB1B: 6C          .byte $6C
    FB1C: 52          .byte $52
    FB1D: 64          .byte $64
    FB1E: 13          .byte $13
    FB1F: 70          .byte $70
    FB20: 2B          .byte $2B
    FB21: 3B          .byte $3B
    FB22: EA          .byte $EA
    FB23: 20          .byte $20
    FB24: 8D          .byte $8D
    FB25: 4B          .byte $4B
    FB26: EA          .byte $EA
    FB27: 10          .byte $10
    FB28: 73          .byte $73
    FB29: 4B          .byte $4B
    FB2A: E8          .byte $E8
    FB2B: 03          .byte $03
    FB2C: 23          .byte $23
    FB2D: 7F          .byte $7F
    FB2E: 08          .byte $08
    FB2F: 70          .byte $70
    FB30: 52          .byte $52
    FB31: 53          .byte $53
    FB32: 3A          .byte $3A
    FB33: 3B          .byte $3B
    FB34: EE          .byte $EE
    FB35: FF          .byte $FF
    FB36: 8D          .byte $8D
    FB37: 32          .byte $32
    FB38: EE          .byte $EE
    FB39: 13          .byte $13
    FB3A: 73          .byte $73
    FB3B: 32          .byte $32
    FB3C: E8          .byte $E8
    FB3D: 02          .byte $02
    FB3E: 04          .byte $04
    FB3F: 7F          .byte $7F
    FB40: 40          .byte $40
    FB41: 6C          .byte $6C
    FB42: 60          .byte $60
    FB43: 64          .byte $64
    FB44: 52          .byte $52
    FB45: 6C          .byte $6C
    FB46: 2A          .byte $2A
    FB47: 64          .byte $64
    FB48: 52          .byte $52
    FB49: 70          .byte $70
    FB4A: 13          .byte $13
    FB4B: 13          .byte $13
    FB4C: EA          .byte $EA
    FB4D: 20          .byte $20
    FB4E: 8D          .byte $8D
    FB4F: 13          .byte $13
    FB50: EA          .byte $EA
    FB51: 10          .byte $10
    FB52: 73          .byte $73
    FB53: 13          .byte $13
    FB54: E8          .byte $E8
    FB55: 01          .byte $01
    FB56: 07          .byte $07
    FB57: 7F          .byte $7F
    FB58: 40          .byte $40
    FB59: EF          .byte $EF
    FB5A: 6C          .byte $6C
    FB5B: 2B          .byte $2B
    FB5C: 66          .byte $66
    FB5D: 2B          .byte $2B
    FB5E: 2B          .byte $2B
    FB5F: 68          .byte $68
    FB60: 2B          .byte $2B
    FB61: 13          .byte $13
    FB62: 2B          .byte $2B
    FB63: 78          .byte $78
    FB64: 3B          .byte $3B
    FB65: 72          .byte $72
    FB66: 43          .byte $43
    FB67: 66          .byte $66
    FB68: 43          .byte $43
    FB69: EA          .byte $EA
    FB6A: 0F          .byte $0F
    FB6B: CC          .byte $CC
    FB6C: 4B          .byte $4B
    FB6D: EA          .byte $EA
    FB6E: 05          .byte $05
    FB6F: 7E          .byte $7E
    FB70: 42          .byte $42
    FB71: 6A          .byte $6A
    FB72: 1A          .byte $1A
    FB73: 03          .byte $03
    FB74: 7E          .byte $7E
    FB75: 1B          .byte $1B
    FB76: 2B          .byte $2B
    FB77: 74          .byte $74
    FB78: 03          .byte $03
    FB79: 6A          .byte $6A
    FB7A: 52          .byte $52
    FB7B: 74          .byte $74
    FB7C: 42          .byte $42
    FB7D: 2A          .byte $2A
    FB7E: 42          .byte $42
    FB7F: F3          .byte $F3
    FB80: 02          .byte $02
    FB81: 51          .byte $51
    FB82: 6A          .byte $6A
    FB83: 42          .byte $42
    FB84: 2A          .byte $2A
    FB85: 03          .byte $03
    FB86: BA          .byte $BA
    FB87: 52          .byte $52
    FB88: F0          .byte $F0
    FB89: 02          .byte $02
    FB8A: 1A          .byte $1A
    FB8B: 74          .byte $74
    FB8C: 60          .byte $60
    FB8D: 6A          .byte $6A
    FB8E: 2A          .byte $2A
    FB8F: 42          .byte $42
    FB90: 42          .byte $42
    FB91: 2A          .byte $2A
    FB92: 42          .byte $42
    FB93: 52          .byte $52
    FB94: 03          .byte $03
    FB95: 74          .byte $74
    FB96: 1B          .byte $1B
    FB97: 2B          .byte $2B
    FB98: 7E          .byte $7E
    FB99: 03          .byte $03
    FB9A: 74          .byte $74
    FB9B: 52          .byte $52
    FB9C: 52          .byte $52
    FB9D: 6A          .byte $6A
    FB9E: 1B          .byte $1B
    FB9F: 7E          .byte $7E
    FBA0: 03          .byte $03
    FBA1: 88          .byte $88
    FBA2: 42          .byte $42
    FBA3: 92          .byte $92
    FBA4: 43          .byte $43
    FBA5: E8          .byte $E8
    FBA6: 6A          .byte $6A
    FBA7: 2A          .byte $2A
    FBA8: 74          .byte $74
    FBA9: 42          .byte $42
    FBAA: BA          .byte $BA
    FBAB: 1A          .byte $1A
    FBAC: 74          .byte $74
    FBAD: 60          .byte $60
    FBAE: 6A          .byte $6A
    FBAF: 2A          .byte $2A
    FBB0: 42          .byte $42
    FBB1: 42          .byte $42
    FBB2: 2A          .byte $2A
    FBB3: 42          .byte $42
    FBB4: 52          .byte $52
    FBB5: F3          .byte $F3
    FBB6: 02          .byte $02
    FBB7: 75          .byte $75
    FBB8: 6A          .byte $6A
    FBB9: 3A          .byte $3A
    FBBA: 74          .byte $74
    FBBB: 1A          .byte $1A
    FBBC: 92          .byte $92
    FBBD: 2A          .byte $2A
    FBBE: 74          .byte $74
    FBBF: 2A          .byte $2A
    FBC0: 74          .byte $74
    FBC1: 42          .byte $42
    FBC2: 6A          .byte $6A
    FBC3: 42          .byte $42
    FBC4: 2A          .byte $2A
    FBC5: 42          .byte $42
    FBC6: BA          .byte $BA
    FBC7: 1A          .byte $1A
    FBC8: F9          .byte $F9
    FBC9: 57          .byte $57
    FBCA: 6A          .byte $6A
    FBCB: 03          .byte $03
    FBCC: 74          .byte $74
    FBCD: 52          .byte $52
    FBCE: 92          .byte $92
    FBCF: 42          .byte $42
    FBD0: 74          .byte $74
    FBD1: 52          .byte $52
    FBD2: 52          .byte $52
    FBD3: 6A          .byte $6A
    FBD4: 52          .byte $52
    FBD5: 74          .byte $74
    FBD6: 03          .byte $03
    FBD7: EA          .byte $EA
    FBD8: 3F          .byte $3F
    FBD9: BA          .byte $BA
    FBDA: 1B          .byte $1B
    FBDB: EA          .byte $EA
    FBDC: 05          .byte $05
    FBDD: 7E          .byte $7E
    FBDE: 2B          .byte $2B
    FBDF: 6A          .byte $6A
    FBE0: 03          .byte $03
    FBE1: 1B          .byte $1B
    FBE2: 7E          .byte $7E
    FBE3: 2B          .byte $2B
    FBE4: 1B          .byte $1B
    FBE5: 74          .byte $74
    FBE6: 03          .byte $03
    FBE7: 6A          .byte $6A
    FBE8: 52          .byte $52
    FBE9: 74          .byte $74
    FBEA: 42          .byte $42
    FBEB: 2A          .byte $2A
    FBEC: 42          .byte $42
    FBED: 6A          .byte $6A
    FBEE: 42          .byte $42
    FBEF: 2A          .byte $2A
    FBF0: 03          .byte $03
    FBF1: BA          .byte $BA
    FBF2: 52          .byte $52
    FBF3: F9          .byte $F9
    FBF4: 1A          .byte $1A
    FBF5: 02          .byte $02
    FBF6: 07          .byte $07
    FBF7: 7F          .byte $7F
    FBF8: 40          .byte $40
    FBF9: 6C          .byte $6C
    FBFA: 13          .byte $13
    FBFB: 66          .byte $66
    FBFC: 13          .byte $13
    FBFD: 13          .byte $13
    FBFE: 68          .byte $68
    FBFF: 13          .byte $13
    FC00: 52          .byte $52
    FC01: 13          .byte $13
    FC02: 78          .byte $78
    FC03: 13          .byte $13
    FC04: 72          .byte $72
    FC05: 1B          .byte $1B
    FC06: 66          .byte $66
    FC07: 1B          .byte $1B
    FC08: EA          .byte $EA
    FC09: 0F          .byte $0F
    FC0A: CC          .byte $CC
    FC0B: 23          .byte $23
    FC0C: E9          .byte $E9
    FC0D: 80          .byte $80
    FC0E: EA          .byte $EA
    FC0F: 03          .byte $03
    FC10: 7E          .byte $7E
    FC11: 41          .byte $41
    FC12: 02          .byte $02
    FC13: 74          .byte $74
    FC14: 1A          .byte $1A
    FC15: 7E          .byte $7E
    FC16: 29          .byte $29
    FC17: 41          .byte $41
    FC18: 74          .byte $74
    FC19: 02          .byte $02
    FC1A: 7E          .byte $7E
    FC1B: 51          .byte $51
    FC1C: 0A          .byte $0A
    FC1D: 74          .byte $74
    FC1E: 2A          .byte $2A
    FC1F: 7E          .byte $7E
    FC20: 1A          .byte $1A
    FC21: 51          .byte $51
    FC22: 74          .byte $74
    FC23: 19          .byte $19
    FC24: F1          .byte $F1
    FC25: 02          .byte $02
    FC26: 1B          .byte $1B
    FC27: 7E          .byte $7E
    FC28: 09          .byte $09
    FC29: 6A          .byte $6A
    FC2A: 09          .byte $09
    FC2B: 29          .byte $29
    FC2C: 7E          .byte $7E
    FC2D: 41          .byte $41
    FC2E: 6A          .byte $6A
    FC2F: 39          .byte $39
    FC30: 02          .byte $02
    FC31: 01          .byte $01
    FC32: 74          .byte $74
    FC33: 29          .byte $29
    FC34: 6A          .byte $6A
    FC35: 41          .byte $41
    FC36: 74          .byte $74
    FC37: 02          .byte $02
    FC38: F7          .byte $F7
    FC39: 03          .byte $03
    FC3A: 65          .byte $65
    FC3B: F4          .byte $F4
    FC3C: 02          .byte $02
    FC3D: 55          .byte $55
    FC3E: 7E          .byte $7E
    FC3F: 51          .byte $51
    FC40: 0A          .byte $0A
    FC41: 74          .byte $74
    FC42: 2A          .byte $2A
    FC43: 7E          .byte $7E
    FC44: 1A          .byte $1A
    FC45: 51          .byte $51
    FC46: 74          .byte $74
    FC47: 19          .byte $19
    FC48: F9          .byte $F9
    FC49: 32          .byte $32
    FC4A: 7E          .byte $7E
    FC4B: 51          .byte $51
    FC4C: 12          .byte $12
    FC4D: 74          .byte $74
    FC4E: 2A          .byte $2A
    FC4F: 6A          .byte $6A
    FC50: 1A          .byte $1A
    FC51: 1A          .byte $1A
    FC52: 0A          .byte $0A
    FC53: 0A          .byte $0A
    FC54: 02          .byte $02
    FC55: 02          .byte $02
    FC56: 51          .byte $51
    FC57: 51          .byte $51
    FC58: F9          .byte $F9
    FC59: 1B          .byte $1B
    FC5A: 6A          .byte $6A
    FC5B: 51          .byte $51
    FC5C: 12          .byte $12
    FC5D: 74          .byte $74
    FC5E: 2A          .byte $2A
    FC5F: 6A          .byte $6A
    FC60: 1A          .byte $1A
    FC61: 51          .byte $51
    FC62: 74          .byte $74
    FC63: 19          .byte $19
    FC64: 88          .byte $88
    FC65: 41          .byte $41
    FC66: 92          .byte $92
    FC67: 42          .byte $42
    FC68: E8          .byte $E8
    FC69: 03          .byte $03
    FC6A: 15          .byte $15
    FC6B: 7F          .byte $7F
    FC6C: 08          .byte $08
    FC6D: 6C          .byte $6C
    FC6E: 53          .byte $53
    FC6F: 66          .byte $66
    FC70: 53          .byte $53
    FC71: 53          .byte $53
    FC72: 68          .byte $68
    FC73: 53          .byte $53
    FC74: 2B          .byte $2B
    FC75: 53          .byte $53
    FC76: EE          .byte $EE
    FC77: 8F          .byte $8F
    FC78: 78          .byte $78
    FC79: 53          .byte $53
    FC7A: EE          .byte $EE
    FC7B: 15          .byte $15
    FC7C: 72          .byte $72
    FC7D: 04          .byte $04
    FC7E: 66          .byte $66
    FC7F: 04          .byte $04
    FC80: EE          .byte $EE
    FC81: 8F          .byte $8F
    FC82: 9C          .byte $9C
    FC83: 14          .byte $14
    FC84: EE          .byte $EE
    FC85: 05          .byte $05
    FC86: 90          .byte $90
    FC87: 14          .byte $14
    FC88: EE          .byte $EE
    FC89: 10          .byte $10
    FC8A: 6A          .byte $6A
    FC8B: 43          .byte $43
    FC8C: 65          .byte $65
    FC8D: 43          .byte $43
    FC8E: 04          .byte $04
    FC8F: 6A          .byte $6A
    FC90: 1C          .byte $1C
    FC91: 04          .byte $04
    FC92: 44          .byte $44
    FC93: 1C          .byte $1C
    FC94: 04          .byte $04
    FC95: 43          .byte $43
    FC96: 2B          .byte $2B
    FC97: 65          .byte $65
    FC98: 2B          .byte $2B
    FC99: 43          .byte $43
    FC9A: 6A          .byte $6A
    FC9B: 04          .byte $04
    FC9C: 43          .byte $43
    FC9D: 2C          .byte $2C
    FC9E: 04          .byte $04
    FC9F: 43          .byte $43
    FCA0: 2B          .byte $2B
    FCA1: 2B          .byte $2B
    FCA2: 65          .byte $65
    FCA3: 2B          .byte $2B
    FCA4: 43          .byte $43
    FCA5: 6A          .byte $6A
    FCA6: 0C          .byte $0C
    FCA7: 43          .byte $43
    FCA8: 2C          .byte $2C
    FCA9: 0C          .byte $0C
    FCAA: 43          .byte $43
    FCAB: 2B          .byte $2B
    FCAC: 1B          .byte $1B
    FCAD: 65          .byte $65
    FCAE: 1B          .byte $1B
    FCAF: 3B          .byte $3B
    FCB0: 6A          .byte $6A
    FCB1: 53          .byte $53
    FCB2: 3B          .byte $3B
    FCB3: 1C          .byte $1C
    FCB4: 53          .byte $53
    FCB5: 3B          .byte $3B
    FCB6: 1B          .byte $1B
    FCB7: F2          .byte $F2
    FCB8: 02          .byte $02
    FCB9: 21          .byte $21
    FCBA: 6A          .byte $6A
    FCBB: 2B          .byte $2B
    FCBC: 65          .byte $65
    FCBD: 2B          .byte $2B
    FCBE: 43          .byte $43
    FCBF: 6A          .byte $6A
    FCC0: 0C          .byte $0C
    FCC1: 43          .byte $43
    FCC2: 2C          .byte $2C
    FCC3: 0C          .byte $0C
    FCC4: 43          .byte $43
    FCC5: 2B          .byte $2B
    FCC6: 1B          .byte $1B
    FCC7: 2B          .byte $2B
    FCC8: 3B          .byte $3B
    FCC9: 74          .byte $74
    FCCA: 43          .byte $43
    FCCB: 6A          .byte $6A
    FCCC: 53          .byte $53
    FCCD: 74          .byte $74
    FCCE: 04          .byte $04
    FCCF: F8          .byte $F8
    FCD0: 03          .byte $03
    FCD1: 9E          .byte $9E
    FCD2: F5          .byte $F5
    FCD3: 02          .byte $02
    FCD4: 85          .byte $85
    FCD5: 6A          .byte $6A
    FCD6: 2B          .byte $2B
    FCD7: 65          .byte $65
    FCD8: 2B          .byte $2B
    FCD9: 43          .byte $43
    FCDA: 6A          .byte $6A
    FCDB: 0C          .byte $0C
    FCDC: 43          .byte $43
    FCDD: 2C          .byte $2C
    FCDE: 0C          .byte $0C
    FCDF: 43          .byte $43
    FCE0: 2B          .byte $2B
    FCE1: 1B          .byte $1B
    FCE2: 65          .byte $65
    FCE3: 1B          .byte $1B
    FCE4: 3B          .byte $3B
    FCE5: 6A          .byte $6A
    FCE6: 53          .byte $53
    FCE7: 3B          .byte $3B
    FCE8: 1C          .byte $1C
    FCE9: 53          .byte $53
    FCEA: 3B          .byte $3B
    FCEB: 1B          .byte $1B
    FCEC: F9          .byte $F9
    FCED: 51          .byte $51
    FCEE: 6A          .byte $6A
    FCEF: 2B          .byte $2B
    FCF0: 65          .byte $65
    FCF1: 2B          .byte $2B
    FCF2: 53          .byte $53
    FCF3: 6A          .byte $6A
    FCF4: 14          .byte $14
    FCF5: 53          .byte $53
    FCF6: 2C          .byte $2C
    FCF7: 14          .byte $14
    FCF8: 53          .byte $53
    FCF9: 2B          .byte $2B
    FCFA: 1B          .byte $1B
    FCFB: 65          .byte $65
    FCFC: 1B          .byte $1B
    FCFD: 3B          .byte $3B
    FCFE: 6A          .byte $6A
    FCFF: 53          .byte $53
    FD00: 3B          .byte $3B
    FD01: 1C          .byte $1C
    FD02: 53          .byte $53
    FD03: 3B          .byte $3B
    FD04: 1B          .byte $1B
    FD05: F9          .byte $F9
    FD06: 21          .byte $21
    FD07: 6A          .byte $6A
    FD08: 2B          .byte $2B
    FD09: 65          .byte $65
    FD0A: 2B          .byte $2B
    FD0B: 43          .byte $43
    FD0C: 6A          .byte $6A
    FD0D: 0C          .byte $0C
    FD0E: 43          .byte $43
    FD0F: 1B          .byte $1B
    FD10: 65          .byte $65
    FD11: 1B          .byte $1B
    FD12: 3B          .byte $3B
    FD13: 6A          .byte $6A
    FD14: 53          .byte $53
    FD15: 3B          .byte $3B
    FD16: 88          .byte $88
    FD17: 43          .byte $43
    FD18: 04          .byte $04
    FD19: E8          .byte $E8
    FD1A: 01          .byte $01
    FD1B: 05          .byte $05
    FD1C: 7F          .byte $7F
    FD1D: 40          .byte $40
    FD1E: 6C          .byte $6C
    FD1F: 52          .byte $52
    FD20: 64          .byte $64
    FD21: 2B          .byte $2B
    FD22: 6C          .byte $6C
    FD23: 13          .byte $13
    FD24: 64          .byte $64
    FD25: 52          .byte $52
    FD26: 6C          .byte $6C
    FD27: 2B          .byte $2B
    FD28: 64          .byte $64
    FD29: 13          .byte $13
    FD2A: 6C          .byte $6C
    FD2B: 52          .byte $52
    FD2C: 64          .byte $64
    FD2D: 3A          .byte $3A
    FD2E: EA          .byte $EA
    FD2F: 20          .byte $20
    FD30: 80          .byte $80
    FD31: 32          .byte $32
    FD32: EA          .byte $EA
    FD33: 05          .byte $05
    FD34: 70          .byte $70
    FD35: 2A          .byte $2A
    FD36: 60          .byte $60
    FD37: E8          .byte $E8
    FD38: 03          .byte $03
    FD39: 2A          .byte $2A
    FD3A: 7F          .byte $7F
    FD3B: 08          .byte $08
    FD3C: 70          .byte $70
    FD3D: 2C          .byte $2C
    FD3E: 14          .byte $14
    FD3F: 53          .byte $53
    FD40: 3B          .byte $3B
    FD41: 80          .byte $80
    FD42: 1B          .byte $1B
    FD43: 70          .byte $70
    FD44: 03          .byte $03
    FD45: 60          .byte $60
    FD46: E8          .byte $E8
    FD47: 02          .byte $02
    FD48: 86          .byte $86
    FD49: 7F          .byte $7F
    FD4A: 40          .byte $40
    FD4B: 70          .byte $70
    FD4C: 50          .byte $50
    FD4D: 51          .byte $51
    FD4E: 50          .byte $50
    FD4F: 51          .byte $51
    FD50: EA          .byte $EA
    FD51: 07          .byte $07
    FD52: 80          .byte $80
    FD53: 59          .byte $59
    FD54: 49          .byte $49
    FD55: E8          .byte $E8
    FD56: 02          .byte $02
    FD57: FF          .byte $FF
    FD58: 7F          .byte $7F
    FD59: 40          .byte $40
    FD5A: 61          .byte $61
    FD5B: 52          .byte $52
    FD5C: 5A          .byte $5A
    FD5D: 03          .byte $03
    FD5E: 0B          .byte $0B
    FD5F: EA          .byte $EA
    FD60: 02          .byte $02
    FD61: 6A          .byte $6A
    FD62: 13          .byte $13
    FD63: E8          .byte $E8
    FD64: 02          .byte $02
    FD65: DF          .byte $DF
    FD66: 7F          .byte $7F
    FD67: 38          .byte $38
    FD68: 62          .byte $62
    FD69: 53          .byte $53
    FD6A: 04          .byte $04
    FD6B: 14          .byte $14
    FD6C: 2C          .byte $2C
    FD6D: 3C          .byte $3C
    FD6E: 53          .byte $53
    FD6F: 3C          .byte $3C
    FD70: 2C          .byte $2C
    FD71: 14          .byte $14
    FD72: 04          .byte $04
    FD73: F7          .byte $F7
    FD74: 04          .byte $04
    FD75: 24          .byte $24
    FD76: F4          .byte $F4
    FD77: 03          .byte $03
    FD78: 20          .byte $20
    FD79: F1          .byte $F1
    FD7A: 02          .byte $02
    FD7B: 1C          .byte $1C
    FD7C: E9          .byte $E9
    FD7D: 40          .byte $40
    FD7E: F9          .byte $F9
    FD7F: 04          .byte $04
    FD80: E9          .byte $E9
    FD81: 80          .byte $80
    FD82: F9          .byte $F9
    FD83: 04          .byte $04
    FD84: E9          .byte $E9
    FD85: 00          .byte $00
    FD86: F9          .byte $F9
    FD87: 04          .byte $04
    FD88: E8          .byte $E8
    FD89: 02          .byte $02
    FD8A: CB          .byte $CB
    FD8B: 7F          .byte $7F
    FD8C: 48          .byte $48
    FD8D: 61          .byte $61
    FD8E: 04          .byte $04
    FD8F: 5B          .byte $5B
    FD90: 53          .byte $53
    FD91: 4B          .byte $4B
    FD92: 43          .byte $43
    FD93: 3B          .byte $3B
    FD94: 33          .byte $33
    FD95: 2B          .byte $2B
    FD96: 04          .byte $04
    FD97: 5B          .byte $5B
    FD98: 53          .byte $53
    FD99: 4B          .byte $4B
    FD9A: 43          .byte $43
    FD9B: 3B          .byte $3B
    FD9C: 33          .byte $33
    FD9D: 2B          .byte $2B
    FD9E: E8          .byte $E8
    FD9F: 02          .byte $02
    FDA0: 89          .byte $89
    FDA1: 7F          .byte $7F
    FDA2: 40          .byte $40
    FDA3: 72          .byte $72
    FDA4: 13          .byte $13
    FDA5: E8          .byte $E8
    FDA6: 02          .byte $02
    FDA7: 7F          .byte $7F
    FDA8: 7F          .byte $7F
    FDA9: 38          .byte $38
    FDAA: 62          .byte $62
    FDAB: 1C          .byte $1C
    FDAC: 14          .byte $14
    FDAD: 0C          .byte $0C
    FDAE: 04          .byte $04
    FDAF: 5B          .byte $5B
    FDB0: 53          .byte $53
    FDB1: 4B          .byte $4B
    FDB2: 43          .byte $43
    FDB3: 3B          .byte $3B
    FDB4: 33          .byte $33
    FDB5: 2B          .byte $2B
    FDB6: EA          .byte $EA
    FDB7: 0F          .byte $0F
    FDB8: 23          .byte $23
    FDB9: E8          .byte $E8
    FDBA: 01          .byte $01
    FDBB: 8F          .byte $8F
    FDBC: 7F          .byte $7F
    FDBD: 68          .byte $68
    FDBE: 63          .byte $63
    FDBF: 0C          .byte $0C
    FDC0: 04          .byte $04
    FDC1: E8          .byte $E8
    FDC2: 01          .byte $01
    FDC3: 07          .byte $07
    FDC4: 7F          .byte $7F
    FDC5: 40          .byte $40
    FDC6: 6E          .byte $6E
    FDC7: 2B          .byte $2B
    FDC8: 67          .byte $67
    FDC9: 23          .byte $23
    FDCA: 6E          .byte $6E
    FDCB: 1B          .byte $1B
    FDCC: 67          .byte $67
    FDCD: 13          .byte $13
    FDCE: 8A          .byte $8A
    FDCF: 0B          .byte $0B
    FDD0: 6E          .byte $6E
    FDD1: 03          .byte $03
    FDD2: 67          .byte $67
    FDD3: 52          .byte $52
    FDD4: 6E          .byte $6E
    FDD5: 4A          .byte $4A
    FDD6: 67          .byte $67
    FDD7: 3A          .byte $3A
    FDD8: 8A          .byte $8A
    FDD9: 2A          .byte $2A
    FDDA: 6E          .byte $6E
    FDDB: 1A          .byte $1A
    FDDC: 67          .byte $67
    FDDD: 22          .byte $22
    FDDE: 6E          .byte $6E
    FDDF: 2A          .byte $2A
    FDE0: 67          .byte $67
    FDE1: 32          .byte $32
    FDE2: 8A          .byte $8A
    FDE3: 3A          .byte $3A
    FDE4: 6E          .byte $6E
    FDE5: 2A          .byte $2A
    FDE6: 67          .byte $67
    FDE7: 32          .byte $32
    FDE8: 6E          .byte $6E
    FDE9: 3A          .byte $3A
    FDEA: 67          .byte $67
    FDEB: 42          .byte $42
    FDEC: 8A          .byte $8A
    FDED: 4A          .byte $4A
    FDEE: 6E          .byte $6E
    FDEF: 13          .byte $13
    FDF0: 67          .byte $67
    FDF1: 0B          .byte $0B
    FDF2: 6E          .byte $6E
    FDF3: 03          .byte $03
    FDF4: 67          .byte $67
    FDF5: 5A          .byte $5A
    FDF6: 8A          .byte $8A
    FDF7: 52          .byte $52
    FDF8: E8          .byte $E8
    FDF9: 02          .byte $02
    FDFA: 07          .byte $07
    FDFB: 7F          .byte $7F
    FDFC: 40          .byte $40
    FDFD: 75          .byte $75
    FDFE: 13          .byte $13
    FDFF: 6E          .byte $6E
    FE00: 03          .byte $03
    FE01: 67          .byte $67
    FE02: 52          .byte $52
    FE03: 75          .byte $75
    FE04: 4A          .byte $4A
    FE05: 2A          .byte $2A
    FE06: 3A          .byte $3A
    FE07: 2A          .byte $2A
    FE08: 8A          .byte $8A
    FE09: 13          .byte $13
    FE0A: 6E          .byte $6E
    FE0B: 03          .byte $03
    FE0C: 67          .byte $67
    FE0D: 13          .byte $13
    FE0E: 6E          .byte $6E
    FE0F: 1B          .byte $1B
    FE10: 67          .byte $67
    FE11: 13          .byte $13
    FE12: 75          .byte $75
    FE13: 03          .byte $03
    FE14: 3A          .byte $3A
    FE15: 6E          .byte $6E
    FE16: 03          .byte $03
    FE17: 67          .byte $67
    FE18: 13          .byte $13
    FE19: 6E          .byte $6E
    FE1A: 1B          .byte $1B
    FE1B: 67          .byte $67
    FE1C: 23          .byte $23
    FE1D: 8A          .byte $8A
    FE1E: 2B          .byte $2B
    FE1F: 6E          .byte $6E
    FE20: 52          .byte $52
    FE21: 67          .byte $67
    FE22: 2B          .byte $2B
    FE23: 6E          .byte $6E
    FE24: 23          .byte $23
    FE25: 67          .byte $67
    FE26: 1B          .byte $1B
    FE27: 8A          .byte $8A
    FE28: 13          .byte $13
    FE29: E8          .byte $E8
    FE2A: 03          .byte $03
    FE2B: 5D          .byte $5D
    FE2C: 7F          .byte $7F
    FE2D: 08          .byte $08
    FE2E: 75          .byte $75
    FE2F: 52          .byte $52
    FE30: 6E          .byte $6E
    FE31: 53          .byte $53
    FE32: 67          .byte $67
    FE33: 2B          .byte $2B
    FE34: 75          .byte $75
    FE35: 2A          .byte $2A
    FE36: 2B          .byte $2B
    FE37: 52          .byte $52
    FE38: 6E          .byte $6E
    FE39: 53          .byte $53
    FE3A: 67          .byte $67
    FE3B: 2B          .byte $2B
    FE3C: 75          .byte $75
    FE3D: 52          .byte $52
    FE3E: 53          .byte $53
    FE3F: 1A          .byte $1A
    FE40: 6E          .byte $6E
    FE41: 1B          .byte $1B
    FE42: 67          .byte $67
    FE43: 52          .byte $52
    FE44: 75          .byte $75
    FE45: 1A          .byte $1A
    FE46: 1B          .byte $1B
    FE47: 2A          .byte $2A
    FE48: 6E          .byte $6E
    FE49: 2B          .byte $2B
    FE4A: 67          .byte $67
    FE4B: 03          .byte $03
    FE4C: 75          .byte $75
    FE4D: 2A          .byte $2A
    FE4E: 2B          .byte $2B
    FE4F: 6E          .byte $6E
    FE50: 52          .byte $52
    FE51: 67          .byte $67
    FE52: 2B          .byte $2B
    FE53: 6E          .byte $6E
    FE54: 53          .byte $53
    FE55: 67          .byte $67
    FE56: 2B          .byte $2B
    FE57: 8A          .byte $8A
    FE58: 52          .byte $52
    FE59: E8          .byte $E8
    FE5A: 01          .byte $01
    FE5B: 03          .byte $03
    FE5C: 7F          .byte $7F
    FE5D: 40          .byte $40
    FE5E: 6C          .byte $6C
    FE5F: 52          .byte $52
    FE60: 64          .byte $64
    FE61: 03          .byte $03
    FE62: 6C          .byte $6C
    FE63: 13          .byte $13
    FE64: 64          .byte $64
    FE65: 52          .byte $52
    FE66: 70          .byte $70
    FE67: 3A          .byte $3A
    FE68: 2A          .byte $2A
    FE69: 6C          .byte $6C
    FE6A: 2A          .byte $2A
    FE6B: 64          .byte $64
    FE6C: 3A          .byte $3A
    FE6D: 70          .byte $70
    FE6E: 4A          .byte $4A
    FE6F: 80          .byte $80
    FE70: 52          .byte $52
    FE71: E8          .byte $E8
    FE72: 02          .byte $02
    FE73: C4          .byte $C4
    FE74: 7F          .byte $7F
    FE75: 40          .byte $40
    FE76: 6C          .byte $6C
    FE77: 52          .byte $52
    FE78: 64          .byte $64
    FE79: 03          .byte $03
    FE7A: 6C          .byte $6C
    FE7B: 13          .byte $13
    FE7C: 64          .byte $64
    FE7D: 52          .byte $52
    FE7E: 70          .byte $70
    FE7F: 3A          .byte $3A
    FE80: 2A          .byte $2A
    FE81: 60          .byte $60
    FE82: 29          .byte $29
    FE83: 80          .byte $80
    FE84: 51          .byte $51
    FE85: E8          .byte $E8
    FE86: 01          .byte $01
    FE87: 87          .byte $87
    FE88: 7F          .byte $7F
    FE89: 40          .byte $40
    FE8A: 68          .byte $68
    FE8B: 3B          .byte $3B
    FE8C: 64          .byte $64
    FE8D: 23          .byte $23
    FE8E: 2B          .byte $2B
    FE8F: 72          .byte $72
    FE90: 3B          .byte $3B
    FE91: E8          .byte $E8
    FE92: 01          .byte $01
    FE93: 05          .byte $05
    FE94: 7F          .byte $7F
    FE95: 40          .byte $40
    FE96: EF          .byte $EF
    FE97: 6C          .byte $6C
    FE98: 0B          .byte $0B
    FE99: 63          .byte $63
    FE9A: 03          .byte $03
    FE9B: 69          .byte $69
    FE9C: 52          .byte $52
    FE9D: 63          .byte $63
    FE9E: 1A          .byte $1A
    FE9F: 69          .byte $69
    FEA0: 32          .byte $32
    FEA1: 63          .byte $63
    FEA2: 3A          .byte $3A
    FEA3: 69          .byte $69
    FEA4: 1A          .byte $1A
    FEA5: 63          .byte $63
    FEA6: 0A          .byte $0A
    FEA7: F6          .byte $F6
    FEA8: 03          .byte $03
    FEA9: 35          .byte $35
    FEAA: F3          .byte $F3
    FEAB: 02          .byte $02
    FEAC: 35          .byte $35
    FEAD: F0          .byte $F0
    FEAE: 02          .byte $02
    FEAF: 27          .byte $27
    FEB0: 6C          .byte $6C
    FEB1: 1A          .byte $1A
    FEB2: 69          .byte $69
    FEB3: 0A          .byte $0A
    FEB4: 63          .byte $63
    FEB5: 1A          .byte $1A
    FEB6: 78          .byte $78
    FEB7: 60          .byte $60
    FEB8: E8          .byte $E8
    FEB9: 69          .byte $69
    FEBA: 1A          .byte $1A
    FEBB: 63          .byte $63
    FEBC: 0A          .byte $0A
    FEBD: 69          .byte $69
    FEBE: 1A          .byte $1A
    FEBF: 63          .byte $63
    FEC0: 32          .byte $32
    FEC1: 69          .byte $69
    FEC2: 60          .byte $60
    FEC3: 6C          .byte $6C
    FEC4: 3A          .byte $3A
    FEC5: F9          .byte $F9
    FEC6: 05          .byte $05
    FEC7: 69          .byte $69
    FEC8: 1A          .byte $1A
    FEC9: 63          .byte $63
    FECA: 0A          .byte $0A
    FECB: 69          .byte $69
    FECC: 1A          .byte $1A
    FECD: 63          .byte $63
    FECE: 0A          .byte $0A
    FECF: 69          .byte $69
    FED0: 60          .byte $60
    FED1: 6C          .byte $6C
    FED2: 1A          .byte $1A
    FED3: F3          .byte $F3
    FED4: 02          .byte $02
    FED5: 62          .byte $62
    FED6: 6C          .byte $6C
    FED7: 33          .byte $33
    FED8: 63          .byte $63
    FED9: 2B          .byte $2B
    FEDA: 69          .byte $69
    FEDB: 1B          .byte $1B
    FEDC: 63          .byte $63
    FEDD: 42          .byte $42
    FEDE: 69          .byte $69
    FEDF: 5A          .byte $5A
    FEE0: 63          .byte $63
    FEE1: 03          .byte $03
    FEE2: 69          .byte $69
    FEE3: 42          .byte $42
    FEE4: 63          .byte $63
    FEE5: 32          .byte $32
    FEE6: 69          .byte $69
    FEE7: 42          .byte $42
    FEE8: 63          .byte $63
    FEE9: 32          .byte $32
    FEEA: 69          .byte $69
    FEEB: 42          .byte $42
    FEEC: 63          .byte $63
    FEED: 5A          .byte $5A
    FEEE: 69          .byte $69
    FEEF: 60          .byte $60
    FEF0: 6C          .byte $6C
    FEF1: 03          .byte $03
    FEF2: F9          .byte $F9
    FEF3: 05          .byte $05
    FEF4: 6C          .byte $6C
    FEF5: 43          .byte $43
    FEF6: 63          .byte $63
    FEF7: 3B          .byte $3B
    FEF8: 69          .byte $69
    FEF9: 2B          .byte $2B
    FEFA: 63          .byte $63
    FEFB: 1B          .byte $1B
    FEFC: 69          .byte $69
    FEFD: 2B          .byte $2B
    FEFE: 6C          .byte $6C
    FEFF: 3B          .byte $3B
    FF00: 33          .byte $33
    FF01: 63          .byte $63
    FF02: 2B          .byte $2B
    FF03: 69          .byte $69
    FF04: 1B          .byte $1B
    FF05: 63          .byte $63
    FF06: 0B          .byte $0B
    FF07: 69          .byte $69
    FF08: 1B          .byte $1B
    FF09: 6C          .byte $6C
    FF0A: 2B          .byte $2B
    FF0B: F9          .byte $F9
    FF0C: 05          .byte $05
    FF0D: 02          .byte $02
    FF0E: 90          .byte $90
    FF0F: 7F          .byte $7F
    FF10: 40          .byte $40
    FF11: EF          .byte $EF
    FF12: 63          .byte $63
    FF13: 60          .byte $60
    FF14: EA          .byte $EA
    FF15: 03          .byte $03
    FF16: 6C          .byte $6C
    FF17: 18          .byte $18
    FF18: 19          .byte $19
    FF19: 09          .byte $09
    FF1A: 01          .byte $01
    FF1B: 69          .byte $69
    FF1C: 50          .byte $50
    FF1D: 63          .byte $63
    FF1E: 50          .byte $50
    FF1F: F7          .byte $F7
    FF20: 03          .byte $03
    FF21: 21          .byte $21
    FF22: F4          .byte $F4
    FF23: 02          .byte $02
    FF24: 21          .byte $21
    FF25: F1          .byte $F1
    FF26: 02          .byte $02
    FF27: 1B          .byte $1B
    FF28: 6C          .byte $6C
    FF29: 40          .byte $40
    FF2A: 38          .byte $38
    FF2B: 28          .byte $28
    FF2C: F9          .byte $F9
    FF2D: 09          .byte $09
    FF2E: 6C          .byte $6C
    FF2F: 30          .byte $30
    FF30: 28          .byte $28
    FF31: 18          .byte $18
    FF32: F4          .byte $F4
    FF33: 02          .byte $02
    FF34: 36          .byte $36
    FF35: 40          .byte $40
    FF36: 41          .byte $41
    FF37: 31          .byte $31
    FF38: 29          .byte $29
    FF39: 69          .byte $69
    FF3A: 19          .byte $19
    FF3B: 63          .byte $63
    FF3C: 19          .byte $19
    FF3D: 6C          .byte $6C
    FF3E: 09          .byte $09
    FF3F: 01          .byte $01
    FF40: 50          .byte $50
    FF41: F9          .byte $F9
    FF42: 09          .byte $09
    FF43: 6C          .byte $6C
    FF44: 50          .byte $50
    FF45: 69          .byte $69
    FF46: 51          .byte $51
    FF47: 6C          .byte $6C
    FF48: 41          .byte $41
    FF49: 63          .byte $63
    FF4A: 41          .byte $41
    FF4B: 6C          .byte $6C
    FF4C: 39          .byte $39
    FF4D: 40          .byte $40
    FF4E: 69          .byte $69
    FF4F: 41          .byte $41
    FF50: 6C          .byte $6C
    FF51: 31          .byte $31
    FF52: 63          .byte $63
    FF53: 31          .byte $31
    FF54: 6C          .byte $6C
    FF55: 29          .byte $29
    FF56: 18          .byte $18
    FF57: 19          .byte $19
    FF58: 09          .byte $09
    FF59: 01          .byte $01
    FF5A: 69          .byte $69
    FF5B: 50          .byte $50
    FF5C: 63          .byte $63
    FF5D: 30          .byte $30
    FF5E: 69          .byte $69
    FF5F: 28          .byte $28
    FF60: 6F          .byte $6F
    FF61: 18          .byte $18
    FF62: 6C          .byte $6C
    FF63: 60          .byte $60
    FF64: E8          .byte $E8

attract_demo:
    FF65: A9 00       lda #$00
    FF67: 85 7A       sta stage_number   ; $7A
    FF69: 85 7D       sta stage_index   ; $7D
    FF6B: A9 01       lda #$01
    FF6D: 85 77       sta ppu_block_src_ptr   ; $77
    FF6F: 20 A7 CA    jsr clear_object_tables   ; $CAA7
    FF72: 20 41 C2    jsr ppu_disable_render   ; $C241
    FF75: 20 49 CD    jsr build_stage_screen_layout   ; $CD49
    FF78: 20 5B E3    jsr load_round_trampolines   ; $E35B
    FF7B: 20 C5 E5    jsr load_round_items   ; $E5C5
    FF7E: 20 62 E8    jsr load_round_doors   ; $E862
    FF81: 20 01 F0    jsr spawn_floor_traps   ; $F001
    FF84: 20 39 C2    jsr ppu_enable_render   ; $C239
    FF87: A2 00       ldx #$00
@FF89:
    FF89: BD 00 02    lda obj_timer,x   ; $0200
    FF8C: 9D 00 03    sta obj_state,x   ; $0300
    FF8F: E8          inx
    FF90: D0 F7       bne @FF89   ; $FF89
    FF92: 20 C1 F3    jsr load_stage_params   ; $F3C1
    FF95: 20 F1 D7    jsr init_player_record   ; $D7F1
    FF98: 20 46 D8    jsr init_round_cats   ; $D846
    FF9B: A9 00       lda #$00
    FF9D: 85 4B       sta player_down   ; $4B
    FF9F: 85 4F       sta round_cleared   ; $4F
    FFA1: 85 31       sta obj_record_ptr   ; $31
    FFA3: 85 3C       sta seq_data_ptr_hi   ; $3C
    FFA5: 85 3D       sta demo_script_cursor   ; $3D
    FFA7: A9 02       lda #$02
    FFA9: 8D 0F 04    sta $040f
    FFAC: A2 20       ldx #$20
@FFAE:
    FFAE: A9 02       lda #$02
    FFB0: 9D 0F 04    sta $040f,x
    FFB3: 8A          txa
    FFB4: 18          clc
    FFB5: 69 10       adc #$10
    FFB7: AA          tax
    FFB8: E4 68       cpx ptr_hi   ; $68
    FFBA: D0 F2       bne @FFAE   ; $FFAE
@FFBC:
    FFBC: 20 41 C1    jsr yield_to_render_loop   ; $C141
    FFBF: 20 60 CB    jsr update_round_frame   ; $CB60
    FFC2: 20 E6 F2    jsr tick_round_timer   ; $F2E6
    FFC5: A5 4F       lda round_cleared   ; $4F
    FFC7: 05 4B       ora player_down   ; $4B
    FFC9: D0 10       bne @FFDB   ; $FFDB
    FFCB: A5 24       lda draw_data_ptr   ; $24
    FFCD: 29 03       and #$03
    FFCF: C9 01       cmp #$01
    FFD1: F0 08       beq @FFDB   ; $FFDB
    FFD3: A5 25       lda joypad_state   ; $25
    FFD5: 29 03       and #$03
    FFD7: C9 01       cmp #$01
    FFD9: D0 E1       bne @FFBC   ; $FFBC
@FFDB:
    FFDB: 20 41 C1    jsr yield_to_render_loop   ; $C141
    FFDE: 4C 4F C8    jmp title_screen   ; $C84F

tbl_demo_input_script:
    FFE1: 85          .byte $85
    FFE2: 11          .byte $11
    FFE3: C8          .byte $C8
    FFE4: 40          .byte $40
    FFE5: D5          .byte $D5
    FFE6: 21          .byte $21
    FFE7: C4          .byte $C4
    FFE8: 85          .byte $85
    FFE9: 15          .byte $15
    FFEA: 84          .byte $84
    FFEB: 40          .byte $40
    FFEC: C5          .byte $C5
    FFED: 09          .byte $09
    FFEE: E5          .byte $E5
    FFEF: 0D          .byte $0D
    FFF0: B2          .byte $B2
    FFF1: CE          .byte $CE
    FFF2: E1          .byte $E1
    FFF3: 11          .byte $11
    FFF4: C8          .byte $C8
    FFF5: 40          .byte $40
    FFF6: D9          .byte $D9
    FFF7: 99          .byte $99
    FFF8: FF          .byte $FF
    FFF9: FF          .byte $FF

cpu_interrupt_vectors:
    FFFA:            .word nmi_count_vblank
    FFFC:            .word reset_cold_boot_init
    FFFE:            .word irq_rti_stub
