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


.IMPORTZP umem_p1
.IMPORTZP cpu_af
.IMPORTZP cpu_bc
.IMPORTZP cpu_de
.IMPORTZP cpu_hl
.IMPORTZP cpu_pc
.IMPORTZP cpu_sp
.IMPORTZP cpu_op



.ZEROPAGE

string_p:	.RES 2
cursor_x:	.RES 1
cursor_y:	.RES 1


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
	LDZ	#1
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
	CMP	#13
	BEQ	cr_char
	PHX
	CMP	#10
	BEQ	lf_char
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
	LDX	#0
scroll0:
	LDA	$850,X
	STA	$800,X
	LDA	$950,X
	STA	$900,X
	LDA	$A50,X
	STA	$A00,X
	LDA	$B50,X
	STA	$B00,X
	LDA	$C50,X
	STA	$C00,X
	LDA	$D50,X
	STA	$D00,X
	LDA	$E50,X
	STA	$E00,X
	LDA	$F50,X
	STA	$F00,X
	INX
	BNE	scroll0
	LDA	#32
scroll1:
	STA	$F80,X
	INX
	CPX	#80
	BNE	scroll1
	; end of scrolling of screen
	PLX
	RTS
cr_char:
	LDA	#0
	STA	cursor_x
	RTS
screen_line_tab_lo:
	.BYTE	$0,$50,$a0,$f0,$40,$90,$e0,$30,$80,$d0,$20,$70,$c0,$10,$60,$b0,$0,$50,$a0,$f0,$40,$90,$e0,$30,$80
screen_line_tab_hi:
	.BYTE	$8,$8,$8,$8,$9,$9,$9,$a,$a,$a,$b,$b,$b,$c,$c,$c,$d,$d,$d,$d,$e,$e,$e,$f,$f
.ENDPROC



.MACRO	WRISTR	str
	JSR	write_inline_string
	.BYTE	str
	.BYTE	0
.ENDMACRO


.EXPORT	init_m65_ascii_charset
.PROC init_m65_ascii_charset
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
	RTS
.ENDPROC





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
	LDA	#13
	JSR	write_char
	LDA	#10
	JMP	write_char
.ENDPROC
