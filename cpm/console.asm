; ----------------------------------------------------------------------------
;
; Software emulator of the 8080 CPU for the Mega-65, intended for CP/M or such.
; Please read comments throughout this source for more information.
;
; Copyright (C)2017 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
;
; ----------------------------------------------------------------------------
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Please note: this is *NOT* a Z80 emulator, but a 8080. Still, I
; prefer the Z80 style assembly syntax over 8080, so don't be
; surpised.
;
; ----------------------------------------------------------------------------


.INCLUDE "mega65.inc"
.INCLUDE "cpu.inc"

TEXT_COLOUR	= 13
BG_COLOUR	= 0
BORDER_COLOUR	= 11
CURSOR_COLOUR	= 2


.ZEROPAGE

string_p:	.RES 2
cursor_x:	.RES 1
cursor_y:	.RES 1
cursor_blink_counter:	.RES 1
kbd_last:	.RES 1
kbd_queued:	.RES 1


.CODE

; Note about screen routines: these are highly unoptimazed, the main focus is on CPU emulator
; Surely at many places (scroll, fill) DMA can be more useful. I wait for that to create
; a "library" with possible detecting/using new and old DMA revisions as well. Honestly, I just
; coded it what ideas I have without too much thinking, to allow to focus on the more important
; and speed sensitive part (i8080 emulation). So there is huge amount room here for more sane
; and optimized solution!

; Currently we don't handle colours etc anything, but full colour RAM anyway with a consistent colour
.EXPORT	clear_screen
.PROC	clear_screen
	PHP
	SEI
	LDA	#1
	TSB	$D030		; switch on full 2K colour RAM
	LDA	#$08
	STA	vhi
	LDA	#$D8
	STA	chi
	LDA	#32
	LDX	#0
	STX	cursor_x
	STX	cursor_y
	LDY	#8
	LDZ	#TEXT_COLOUR
loop:
	vhi = * + 2
	STA	$0800,X
	chi = * + 2
	STZ	$D800,X
	INX
	BNE	loop
	INC	vhi
	INC	chi
	DEY
	BNE	loop
	LDA	#1
	TRB	$D030		; OK, release colour RAM, so CIA1/CIA2 can be seen again
	LDA	#15
	STA	4088		; sprite shape
	PLP
	RTS
.ENDPROC


.EXPORT	write_inline_string
write_inline_string:
	PLA
	STA	string_p
	PLA
	STA	string_p+1
	PHZ
	LDZ	#0
@loop:
	INW	string_p
	LDA	(string_p),Z
	BEQ	@eos
	JSR	write_char
	JMP	@loop
@eos:
	INW	string_p
	PLZ
	JMP	(string_p)


write_string:
	PHZ
	LDZ	#0
@loop:
	LDA	(string_p),Z
	BEQ	@eos
	JSR	write_char
	INZ
	BNE	@loop
@eos:
	PLZ
	RTS


.EXPORT	write_hex_word_at_zp
.PROC write_hex_word_at_zp
	PHX
	TAX
	LDA	z:1,X
	JSR	write_hex_byte
that:
	LDA	z:0,X
	JSR	write_hex_byte
	PLX
	RTS
.ENDPROC

.EXPORT	write_hex_byte_at_zp
.EXPORT	write_hex_byte
.EXPORT	write_hex_nib
.EXPORT	write_char
.EXPORT	write_crlf

write_crlf:
	LDA	#13
	JSR	write_char
	LDA	#10
	JMP	write_char

write_hex_byte_at_zp:
	PHX
	TAX
	BSR	write_hex_word_at_zp::that

write_hex_byte:
	PHA
	LSR	A
	LSR	A
	LSR	A
	LSR	A
	JSR	write_hex_nib
	PLA
write_hex_nib:
	AND	#$F
	ORA	#'0'
	CMP	#'9'+1
	BCC	write_char
	ADC	#6
.PROC write_char
	PHX
	CMP	#32
	BCS	normal_char
	CMP	#13
	BEQ	cr_char
	CMP	#10
	BEQ	lf_char
	CMP	#8
	BEQ	bs_char
	TAX
	LDA	#'^'
	JSR	write_char
	TXA
	JSR	write_hex_byte
	PLX
	RTS
bs_char:
	LDA	cursor_x
	BEQ	:+
	DEA
	STA	cursor_x
:	PLX
	RTS
cr_char:
	LDA	#0
	STA	cursor_x
	PLX
	RTS
normal_char:
	PHA
	; load address
	LDX	cursor_y
	LDA	screen_line_tab_lo,X
	STA	self_addr
	LDA	screen_line_tab_hi,X
	STA	self_addr+1
	LDX	cursor_x
	PLA
	AND	#$7F
	;TAX
	;LDA	ascii_to_screencodes-$20,X
	self_addr = * + 1
	STA	$8000,X
	CPX	#79
	BEQ	eol
	INX
	STX	cursor_x
	PLX
	RTS
eol:
	LDA	#0
	STA	cursor_x
lf_char:
	LDA	cursor_y
	CMP	#24
	BEQ	scroll
	INA
	STA	cursor_y
	PLX
	RTS
	; Start of scrolling of screen
scroll:
	LDA	#0
	STA	$D702
	LDA	#.HIBYTE(scroll_dma_list)
	STA	$D701
	LDA	#.LOBYTE(scroll_dma_list)
	STA	$D700	; this actually starts the DMA operation
;	LDX	#0
;scroll0:
;	LDA	$850,X
;	STA	$800,X
;	LDA	$950,X
;	STA	$900,X
;	LDA	$A50,X
;	STA	$A00,X
;	LDA	$B50,X
;	STA	$B00,X
;	LDA	$C50,X
;	STA	$C00,X
;	LDA	$D50,X
;	STA	$D00,X
;	LDA	$E50,X
;	STA	$E00,X
;	LDA	$F50,X
;	STA	$F00,X
;	INX
;	BNE	scroll0
;	LDA	#32
;scroll1:
;	STA	$F80,X
;	INX
;	CPX	#80
;	BNE	scroll1
	; end of scrolling of screen
	PLX
	RTS
screen_line_tab_lo:
	.BYTE	$0,$50,$a0,$f0,$40,$90,$e0,$30,$80,$d0,$20,$70,$c0,$10,$60,$b0,$0,$50,$a0,$f0,$40,$90,$e0,$30,$80
screen_line_tab_hi:
	.BYTE	$8,$8,$8,$8,$9,$9,$9,$a,$a,$a,$b,$b,$b,$c,$c,$c,$d,$d,$d,$d,$e,$e,$e,$f,$f
scroll_dma_list:	; DMA list for scolling
	; First DMA entry (chained) to copy screen content [this is "old DMA behaviour"!]
	.BYTE	4	; DMA command, and other info (bit2=chained, bit0/1=command: copy=0)
	.WORD	24*80	; DMA operation length
	.WORD	$850	; source addr
	.BYTE	0	; source bank + other info
	.WORD	$800	; target addr
	.BYTE	0	; target bank + other info
	.WORD	0	; modulo ... no idea, just skip it
	; Second DMA entry (last) to erase bottom line
	.BYTE	3	; DMA command, and other info (not chained so last, op is 3, which is fill)
	.WORD	80	; DMA operation length
	.WORD	32	; source addr, NOTE: in case of FILL op (now!) this is not an address, but low byte is the fill value!!
	.BYTE	0	; source bank + other info
	.WORD	$F80	; target addr
	.BYTE	0	; target bank + other info
	.WORD	0	; modulo ... no idea, just skip it
.ENDPROC



.MACRO	WRISTR	str
	JSR	write_inline_string
	.BYTE	str
	.BYTE	0
.ENDMACRO


.EXPORT	init_console
.PROC init_console
	; Turn C64 charset at $D000 for starting point of modification
	LDA	#1
	STA	1
	; We use charset "WOM" @ $0FF7 Exxx of M65 directly via linear addressing
	; to submit new charset based on "sliced" original one from C64 ROM
	; Since WOM is "write-only" memory, we need a source, that is C64 charset ROM.
	; *NOTE: umem_p1 *CANNOT* be used after cpu_reset
	LDA	#$F7
	STA	umem_p1+2
	LDA	#$0F
	STA	umem_p1+3
	LDZ	#0
	LDX	#0
	STZ	umem_p1
cp0:
	; ***
	LDY	#$E0
	STY	umem_p1+1
	LDA	#$FF
	STA32Z	umem_p1		; well, that's only for making sure chars 0-31 are "blank" to catch problems, etc?
	; ***
	INY
	STY	umem_p1+1
	LDA	$D000+32*8,X
	STA32Z	umem_p1
	; ***
	INY
	STY	umem_p1+1
	LDA	$D000,X
	STA32Z	umem_p1
	; ***
	INY
	STY	umem_p1+1
	LDA	$D800,X
	STA32Z	umem_p1
	INX
	INZ
	BNE	cp0
	; All RAM, but I/O?
	LDA	#5
	STA	1
	; Set interrupt handler
	LDA	#<irq_handler
	STA	$FFFE
	LDA	#>irq_handler
	STA	$FFFF
	LDA	#1
	STA	$D01A	; enable raster interrupt
	; Sprite
	LDX	#0
sprite_shaper1:
	LDA	#$F0
	STA	$3C0,X
	INX
	LDA	#0
	STA	$3C0,X
	INX
	STA	$3C0,X
	INX
	CPX	#24
	BNE	sprite_shaper1
sprite_shaper2:
	STA	$3C0,X
	INX
	CPX	#63
	BNE	sprite_shaper2


	LDA	#1
	STA	$D015		; sprite enable
	LDA	#100
	STA	$D001		; Y-coord
	STA	$D000		; X-coord
	LDA	#CURSOR_COLOUR
	STA	$D027		; sprite colour
	; 
	LDA	#BORDER_COLOUR
	STA	$D020
	LDA	#BG_COLOUR
	STA	$D021
	; misc
	LDA	#0
	STA	kbd_last
	STA	kbd_queued
	RTS
.ENDPROC


; TODO: also dump the word on the top of the stack!
.EXPORT	reg_dump
.PROC	reg_dump
	WRISTR	"OP="
	LDA	cpu_op
	JSR	write_hex_byte
	WRISTR	" PC="
	LDA	#cpu_pc
	JSR	write_hex_word_at_zp
	WRISTR	" SP="
	LDA	#cpu_sp
	JSR	write_hex_word_at_zp
	WRISTR	" AF="
	LDA	#cpu_af
	JSR	write_hex_word_at_zp
	WRISTR	" BC="
	LDA	#cpu_bc
	JSR	write_hex_word_at_zp
	WRISTR	" DE="
	LDA	#cpu_de
	JSR	write_hex_word_at_zp
	WRISTR	" HL="
	LDA	#cpu_hl
	JSR	write_hex_word_at_zp
	JMP	write_crlf
.ENDPROC


; Keyboard scan codes to ASCII table.
; some keys are handled as control keys with de-facto standard value, eg RETURN = 13
; key positions with 0 values are not handled. Key value 128 means the shift keys
scan2ascii:
	.BYTE	8,13,0,0,0,0,0,0
	.BYTE	"3wa4zse",128
	.BYTE	"5rd6cftx"
	.BYTE	"7yg8bhuv"
	.BYTE	"9ij0mkon"
	.BYTE	"+pl-.:@,"
	.BYTE	"#*;",0,128,"=^/"
	.BYTE	"1",0,0,"2 ",0,"q",0
	; Shifted versions of the keys (here, shift keys must be unhandled!!!)
	.BYTE	0,0,0,0,0,0,0,0
	.BYTE	"3WA4ZSE",0
	.BYTE	"5RD6CFTX"
	.BYTE	"7YG8BHUV"
	.BYTE	"9IJ0MKON"
	.BYTE	"+PL-.:@,"
	.BYTE	"#*;",0,0,"=^/"
	.BYTE	"1",0,0,"2 ",0,"Q",0
	


.PROC	update_keyboard
	CMP	#0
	BNE	no_return
	STA	kbd_last
	RTS
no_return:
	CMP	kbd_last
	BEQ	return
	STA	kbd_last
	LDX	kbd_queued
	BNE	return
	STA	kbd_queued
	STA	$84D
return:
	RTS
.ENDPROC



.PROC	irq_handler
	PHA
	PHX
	PHY
	PHZ
	; Scan the keyboard, use key buffer to store result, etc ...
	; TODO: Keyboard scanning does not need to be done maybe at every VIC frame though ...
	.SCOPE
	LDX	#0
	STX	kbd_pressed
	STA	$DC00
	LDA	$DC01
	INA
	BEQ	not_any
	LDA	#$FE		; start the outer loop, X=0 already
scan1:
	STA	$DC00
	TAY
	LDA	$DC01
	CMP	#$FF
	BEQ	no_key_here
	LDZ	#8
scan2:
	LSR	A
	BCS	not_this_key
	PHA				; BEGIN: a given key is found to be pressed
	LDA	scan2ascii,X		; translate keycode to ASCII (or some other info ...)
	BEQ	key_unhandled		; we don't want to handle this key
	BPL	key_handled
	TXA
	ORA	#64
	TAX
	JMP	key_unhandled
key_handled:
	STA	kbd_pressed
key_unhandled:
	PLA				; END: a given key is found to be pressed
not_this_key:
	INX
	DEZ
	BNE	scan2
	BEQ	was_key_here
no_key_here:
	TXA
	CLC
	ADC	#8
	TAX
was_key_here:
	TYA
	SEC		; this will be the new bit0 (1)
	ROL	A
	BCS	scan1
not_any:
	; Ok, diagnostize the result, we have kbd_modkeys for key modifiers, and kbd_pressed for the pressed non-modifier key
	kbd_pressed = * + 1
	LDA	#0
	JSR	update_keyboard
no_scan:
	.ENDSCOPE
	; TODO: simple audio events like "bell" (ascii code 7)?
	; Cursor blink stuff
	LDA	cursor_blink_counter
	INA
	STA	cursor_blink_counter
	LSR	A
	LSR	A
	LSR	A
	AND	#1
	STA	$D015	; enable
	; Update cursor position (we use a sprite as a cursor, updated in IRQ handler always)
	LDA	cursor_x
	TAX
	ASL	A
	ASL	A
	CLC
	ADC	#24
	STA	$D000	; sprite-0 X coordinate
	TXA
	CMP	#51
	LDA	#0
	ADC	#0
	STA	$D010	; 8th bit stuff
	LDA	cursor_y
	ASL	A
	ASL	A
	ASL	A
	CLC
	ADC	#50
	STA	$D001	; cursor Y coordinate!
	INC	$84E	; "heartbeat"
	PLZ
	PLY
	PLX
	PLA
	ASL	$D019	; acknowledge VIC interrupt (note: it wouldn't work on a real C65 as RMW opcodes are different but it does work on M65 as on C64 too!)
	RTI
.ENDPROC


.EXPORT	conin_check_status
.PROC	conin_check_status
	LDA	kbd_queued
	BEQ	return
	LDA	#$FF
return:
	RTS
.ENDPROC


.EXPORT	conin_get_with_wait
.PROC	conin_get_with_wait
	LDA	kbd_queued
	BEQ	conin_get_with_wait
	PHA
	LDA	#0
	STA	kbd_queued
	PLA
	RTS
.ENDPROC
