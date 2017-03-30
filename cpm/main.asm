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


; Needs CPU reset for umem_p1 initialized for bank
.EXPORT	install_software
.PROC	install_software
	; Clear whole RAM, up to (but not including) SYSPAGE
	LDA	#0
	TAZ
	TAX
clear1:
	STX	umem_p1+1
clear2:
	STA32Z	umem_p1
	INZ
	BNE	clear2
	INX
	CPX	#SYSPAGE
	BNE	clear1
	; Prepare upper system page
	STX	umem_p1+1
	LDZ	#0
	LDY	#$C0
fillsyspage1:
	LDA	#JP_OPC_8080
	STA32Z	umem_p1
	INZ
	TYA
	STA32Z	umem_p1
	INZ
	LDA	#SYSPAGE
	STA32Z	umem_p1
	INZ
	INY
	BNE	fillsyspage1
	LDA	#HALT_OPC_8080
fillsyspage2:
	STA32Z	umem_p1
	INZ
	BNE	fillsyspage2
	; Prepare lower system page
	LDA	#0
	STA	umem_p1+1
	TAX
	TAZ
fillzeropage:
	LDA	lowpage,X
	STA32Z	umem_p1
	INZ
	INX
	CPX	#lowpage_bytes
	BNE	fillzeropage
	; Copy program to be executed
	LDX	#1
	STX	umem_p1+1
	DEX
	LDZ	#0
	LDY	#i8080_code_pages
uploadloop:
	LDA	i8080_code,X
	STA32Z	umem_p1
	INZ
	INX
	BNE	uploadloop
	INC	umem_p1+1
	INC	uploadloop+2
	DEY
	BNE	uploadloop
	RTS
lowpage:
	.BYTE	JP_OPC_8080, 2 * 3, SYSPAGE	; CP/M BIOS WARM boot entry point
	.BYTE	0, 0	; I/O byte and disk byte
	.BYTE	JP_OPC_8080, 0 * 3, SYSPAGE	; CP/M BDOS entry point
lowpage_bytes = * - lowpage
i8080_code:
	;.INCBIN "8080/cpmver.com"
	.INCBIN "8080/cpmver-real.com"
	;.INCBIN "8080/wow.com"
	;.INCBIN "8080/mbasic-real.com"
i8080_code_pages = (* - i8080_code) + 1
.ENDPROC


; BDOS function 9 (C_WRITESTR) - Output string
; Entered with C=9, DE=address of string. End of string marker is '$'
.PROC	bdos_9
	LDZ	#0
loop:
	LDA32Z	cpu_de
	INW	cpu_de
	CMP	#'$'
	LBEQ	cpu_start_with_ret
	JSR	write_char
	JMP	loop
.ENDPROC



; BDOS function 12 (S_BDOSVER) - Return version number
; Entered with C=0Ch. Returns B=H=system type, A=L=version number.
.PROC	bdos_12
	LDA	#0
	STA	cpu_bc+1
	STA	cpu_hl+1
	LDA	#$22
	STA	cpu_af+1
	STA	cpu_hl
	JMP	cpu_start_with_ret
.ENDPROC


bdos_call_table:
	.WORD	bdos_unknown		; Call $0
	.WORD	bdos_unknown		; Call $1
	.WORD	bdos_unknown		; Call $2
	.WORD	bdos_unknown		; Call $3
	.WORD	bdos_unknown		; Call $4
	.WORD	bdos_unknown		; Call $5
	.WORD	bdos_unknown		; Call $6
	.WORD	bdos_unknown		; Call $7
	.WORD	bdos_unknown		; Call $8
	.WORD	bdos_9			; Call $9: BDOS function 9 (C_WRITESTR) - Output string
	.WORD	bdos_unknown		; Call $A
	.WORD	bdos_unknown		; Call $B
	.WORD	bdos_12			; Call $C: BDOS function 12 (S_BDOSVER) - Return version number
bdos_call_table_size = (* - bdos_call_table) / 2



.PROC	bdos_unknown
	WRISTR	{13,10,"*** UNKNOWN BDOS call",13,10}
	JMP	halt
.ENDPROC

.PROC	bdos_call
	LDA	cpu_bc		; C register: BDOS call number
	CMP	#bdos_call_table_size
	BCS	bdos_unknown_big
	ASL	A
	TAX
	JMP	(bdos_call_table,X)
bdos_unknown_big:
	WRISTR	{13,10,"*** UNKNOWN BDOS call (too high)",13,10}
	JMP	halt
.ENDPROC



.PROC	bios_call
	WRISTR	{13,10,"*** BIOS is not emulated yet",13,10}
	JMP	halt
.ENDPROC


; This is the "main function" jumped by the loader
.EXPORT	app_main
.PROC	app_main
	JSR	init_m65_ascii_charset
	JSR	clear_screen	; the fist call of this initiailizes console out functions
	WRISTR	{"i8080 emulator and (re-implemented) CP/M for Mega-65 (C)2017 LGB",13,10}
	JSR	cpu_reset
	JSR	install_software	; initializes i8080 CP/M memory, and "uploads" the software there we want to run
	LDA	#1
	STA	cpu_pc+1	; reset address was 0, now with high byte modified to 1, it's 0x100, the start address of CP/M programs.
	WRISTR	{"Entering into i8080 mode",13,10,13,10}
	JMP	cpu_start
.ENDPROC


; i8080 emulator will jump here on "cpu_leave" event
.EXPORT	return_cpu_leave
.PROC	return_cpu_leave
	LDA	cpu_pc+1
	CMP	#SYSPAGE
	BNE	error_nosyspage
	LDA	cpu_pc
	AND	#$3F
	LBNE	bios_call
	LDA	cpu_bc		; load C register (BDOS call number)
	JMP	bdos_call
error_nosyspage:
	WRISTR	{13,10,"*** Emulation trap not on the system page",13,10}
	JMP	halt
.ENDPROC

; i8080 emulator will jump here on "cpu_unimplemented" event
.EXPORT	return_cpu_unimplemented
.PROC	return_cpu_unimplemented
	WRISTR	{13,10,"*** Unimplemented i8080 opcode",13,10}
	JMP	halt
.ENDPROC

.PROC	halt
	JSR	reg_dump
	WRISTR  {13,10,"HALTED.",13,10}
halted:
	INC	$fcf
	JMP	halted
.ENDPROC
