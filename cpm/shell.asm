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
.INCLUDE "emu.inc"
.INCLUDE "console.inc"
.INCLUDE "cpu.inc"

.BSS

cli_buffer:	.RES	80
hex_input:	.RES	2

.ZEROPAGE

memdump_addr:	.RES	4

.CODE



.PROC	skip_spaces_in_cli_buffer
	LDA	cli_buffer,X
	BEQ	return
	CMP	#32
	BNE	return
	INX
	JMP	skip_spaces_in_cli_buffer
return:
	RTS
.ENDPROC




; Input: X = position in cli_buffer to start
; Output: X = new position ...
;	  A = number of hex digits read
.PROC	get_hex_from_cli_buffer
	PHY
	LDA	#0
	TAY				; Y = number of hex digits could entered
	STA	hex_input
	STA	hex_input+1
loop:
	LDA	cli_buffer,X
	BEQ	end_of_hex		; end of buffer, end of hex input mode
	CMP	#32
	BEQ	end_of_hex		; space char, end of hex input mode
	SEC
	SBC	#'0'
	CMP	#10
	BCC	no_correction
	SBC	#7
	AND	#$F
no_correction:
	ASW	hex_input
	ASW	hex_input
	ASW	hex_input
	ASW	hex_input
	ORA	hex_input
	STA	hex_input	
	INX
	INY
	JMP	loop
end_of_hex:
	TYA
	PLY
	ORA	#0
	RTS
.ENDPROC




.PROC	memdump
	LDX	#16
	; Begin: one line
line_loop:
	LDA	#' '
	JSR	write_char
	LDA	memdump_addr+3
	JSR	write_hex_byte
	LDA	memdump_addr+2
	JSR	write_hex_byte
	LDA	#':'
	JSR	write_char
	LDA	memdump_addr+1
	JSR	write_hex_byte
	LDA	memdump_addr
	JSR	write_hex_byte
	LDA	#' '
	JSR	write_char
	LDA	#' '
	JSR	write_char
	LDZ	#0
hex_loop:
	LDA32Z	memdump_addr
	JSR	write_hex_byte
	LDA	#' '
	JSR	write_char
	INZ
	CPZ	#16
	BNE	hex_loop
	LDA	#' '
	JSR	write_char
	LDA	#' '
	JSR	write_char
	LDZ	#0
char_loop:
	LDA32Z	memdump_addr
	BMI	:+
	CMP	#32
	BCS	:++
:	LDA	#'.'
:	JSR	write_char
	INZ
	CPZ	#16
	BNE	char_loop
	JSR	write_crlf
	; end: one line
	LDA	memdump_addr
	CLC
	ADC	#16
	STA	memdump_addr
	BCC	:+
	INC	memdump_addr+1
:	DEX
	BNE	line_loop
	RTS
.ENDPROC





.EXPORT	command_processor
.PROC	command_processor
	; TODO: move init to another place ...
	LDA	#.LOBYTE(I8080_BANK)
	STA	memdump_addr + 2
	LDA	#.HIBYTE(I8080_BANK)
	STA	memdump_addr + 3
	LDA	#0
	STA	memdump_addr
	STA	memdump_addr+1
shell_loop:
	LDA	#':'			; Console prompt
	JSR	write_char
	LDX	#0			; input buffer pointer
input_loop:
	JSR	conin_get_with_wait	; wait for next character ....
	CMP	#' '+1
	BCS	normal_char		; char code higher than space
	CPX	#0			; if not, check if buffer is empty
	BEQ	input_loop		; empty buffer cannot be entered, nor use delete key with, etc
	CMP	#' '
	BEQ	space_char		; special handle for space (see below at space_char label)
	CMP	#8
	BEQ	backspace_char		; backspace to delete
	CMP	#13
	BEQ	return_char		; return to enter buffer
	BNE	input_loop		; if non of above, let's loop back for waiting input
backspace_char:
	DEX
	WRISTR	{8,32,8}
	JMP	input_loop
space_char:
	CMP	cli_buffer-1,X		; we don't allow more spaces to be entered after each other
	BEQ	input_loop
normal_char:
	CPX	#78
	BEQ	input_loop
	JSR	write_char
	STA	cli_buffer,X
	INX
	BNE	input_loop
return_char:
	LDA	#0
	STA	cli_buffer,X		; store a null terminator in the buffer for easier processing later
	JSR	write_crlf
	; Start to eval the command
	LDA	cli_buffer
	CMP	#'b'
	BEQ	command_b
	CMP	#'j'
	BEQ	command_j
	CMP	#'r'
	BEQ	command_r
	CMP	#'m'
	LBEQ	command_m
	CMP	#'x'
	LBEQ	command_x
	WRISTR	{"?Bad command.",13,10}
	JMP	shell_loop
command_r:
	JSR	reg_dump
	JMP	shell_loop
command_b:
	LDX	#1
	JSR	skip_spaces_in_cli_buffer
	JSR	get_hex_from_cli_buffer
	LBEQ	shell_loop
	WRISTR	"Dump bank is set to "
	LDA	hex_input+1
	AND	#$F
	STA	memdump_addr+3
	JSR	write_hex_byte
	LDA	hex_input
	STA	memdump_addr+2
	JSR	write_hex_byte
	JSR	write_crlf
	JMP	shell_loop
command_j:
	LDX	#1
	JSR	skip_spaces_in_cli_buffer
	JSR	get_hex_from_cli_buffer
	LBEQ	shell_loop
	WRISTR	"8080 PC is set to "
	LDA	hex_input+1
	STA	cpu_pch
	JSR	write_hex_byte
	LDA	hex_input
	STA	cpu_pcl
	JSR	write_hex_byte
	JSR	write_crlf
	JMP	shell_loop
command_m:
	LDX	#1				; position after one letter command in cli-buffer
	JSR	skip_spaces_in_cli_buffer	; skip possible space
	JSR	get_hex_from_cli_buffer		; read hex value
	BEQ	:+				; zero bit is set, if no hex val could read at all
	LDA	hex_input
	STA	memdump_addr
	LDA	hex_input+1
	STA	memdump_addr+1
:	JSR	memdump
	JMP	shell_loop
command_x:
	RTS
.ENDPROC
