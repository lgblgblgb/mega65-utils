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


.IMPORT cpu_reset
.IMPORT cpu_start
.IMPORT exit_system
.IMPORTZP cpu_af
.IMPORTZP cpu_bc
.IMPORTZP cpu_de
.IMPORTZP cpu_hl
.IMPORTZP cpu_pc
.IMPORTZP cpu_sp
.IMPORTZP cpu_op
.IMPORTZp umem_p1


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
	;.INCBIN "8080/mbasic-real.com"
i8080_code_pages = (* - i8080_code) + 1
.ENDPROC




; This test version runs 8080 code wich uses HALT opcode to return from emulation
; The odd theory now: if high byte of 8080 SP is set to $FF then it means exit
; program, otherwise "A" register should be printed on the screen. yeah, it's far
; from anything to be a normal behaviour but now this is the fastest way around
; to test basic 8080 emulation stuffs before CP/M specific projects ...

.EXPORT	app_main
.PROC	app_main
	JSR	init_m65_ascii_charset
	JSR	clear_screen	; the fist call of this initiailizes console out functions
	WRISTR	{"i8080 emulator and CP/M CBIOS for Mega-65 (C)2017 LGB",13,10}
	JSR	cpu_reset
	JSR	install_software
	LDA	#1
	STA	cpu_pc+1	; reset address was 0, now with high byte modified to 1, it's 0x100, the start address of CP/M programs.
	WRISTR	{"Entering into i8080 mode",13,10,13,10}
run:
	JSR	cpu_start
	LBCS	error_unimp	; check the reason of exit in the emulator, if Carry is set, then unimplemented opcode found!
	; Now next task is check where it happened
	LDA	cpu_pc+1
	CMP	#SYSPAGE
	BNE	error_nosyspage
	LDA	cpu_pc
	AND	#$3F
	BEQ	cpm_bdos_entry
	JMP	error_no_bios
error_no_bios:
	WRISTR	{13,10,"*** BIOS is not emulated yet",13,10}
	JMP	halt
cpm_bdos_entry = error_no_bdos
error_no_bdos:
	WRISTR	{13,10,"*** BDOS is not emulated yet",13,10}
	JMP	halt
error_nosyspage:
	WRISTR	{13,10,"*** Emulation trap not on the system page",13,10}
	JMP	halt
error_unimp:
	WRISTR	{13,10,"*** Unimplemented i8080 opcode",13,10}
halt:
	JSR	reg_dump
	WRISTR  {13,10,"HALTED.",13,10}
halted_loop:
	INC	$fcf
	JMP	halted_loop
.ENDPROC
