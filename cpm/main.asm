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

.SEGMENT "PAYLOAD"
	; Experimental way to include a given CP/M program, since we don't have the ability yet, to load something ...
	; Do not put anything other into this segment only the binary you want to execute!
	.IMPORT	__PAYLOAD_LOAD__
	.IMPORT	__PAYLOAD_SIZE__
	;.INCBIN "8080/cpmver.com"
	;.INCBIN "8080/cpmver-real.com"
	;.INCBIN "8080/wow.com"
	.INCBIN "8080/mbasic-real.com"

.CODE

; Needs CPU reset for umem_p1 initialized for bank
.EXPORT	install_software
.PROC	install_software
	; Clear whole RAM, up to (but not including) BDOSPAGE
	WRISTR	"Init checkpoints: 0"
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
	CPX	#BDOSPAGE
	BNE	clear1
	; Prepare "BDOS page" (fully HALTs)
	WRISTR	"1"
	STX	umem_p1+1
	LDA	#HALT_OPC_8080
fillsyspage0:
	STA32Z	umem_p1
	INZ
	BNE	fillsyspage0
	; Prepare "BIOS page"
	WRISTR	"2"
	INX
	STX	umem_p1+1
	LDY	#$C0
fillsyspage1:
	LDA	#JP_OPC_8080
	STA32Z	umem_p1
	INZ
	TYA
	STA32Z	umem_p1
	INZ
	LDA	#BIOSPAGE
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
	WRISTR	"3"
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
	WRISTR	"4"
	LDX	#1
	STX	umem_p1+1
	DEX
	LDZ	#0
	LDY	#.HIBYTE(__PAYLOAD_SIZE__) + 1
uploadloop:
	LDA	__PAYLOAD_LOAD__,X
	STA32Z	umem_p1
	INZ
	INX
	BNE	uploadloop
	INC	umem_p1+1
	INC	uploadloop+2
	DEY
	BNE	uploadloop
	JSR	write_crlf
	RTS
lowpage:
	.BYTE	JP_OPC_8080, 3, BIOSPAGE	; CP/M BIOS WARM boot entry point
	.BYTE	0, 0	; I/O byte and disk byte
	.BYTE	JP_OPC_8080, 0, BDOSPAGE	; CP/M BDOS entry point
lowpage_bytes = * - lowpage
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

; BIOS CONST  (Returns its status in A; 0 if no character is ready, 0FFh if one is.)
.PROC	bios_2
	JSR	conin_check_status
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

; BIOS CONIN  (Wait until the keyboard is ready to provide a character, and return it in A.)
.PROC	bios_3
	JSR	conin_get_with_wait
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

; BIOS CONOUT (write character in register C)
.PROC	bios_4
	LDA	cpu_c
	JSR	write_char
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


bios_call_table:
	.WORD	bios_unknown		; 0: BOOT
	.WORD	bios_unknown		; 1: WBOOT
	.WORD	bios_2			; 2: CONST  (Returns its status in A; 0 if no character is ready, 0FFh if one is.)
	.WORD	bios_3			; 3: CONIN  (Wait until the keyboard is ready to provide a character, and return it in A.)
	.WORD	bios_4			; 4: CONOUT (write character in register C)
bios_call_table_size = (* - bios_call_table) / 2



.PROC	bdos_unknown
	WRISTR	{13,10,"*** UNKNOWN BDOS call",13,10}
	JMP	halt
.ENDPROC


.PROC	bios_unknown
	WRISTR	{13,10,"*** UNKNOWN BIOS call: $"}
	JMP	bios_call_show_and_halt
.ENDPROC



.PROC	bdos_call
	LDA	cpu_c		; C register: BDOS call number
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
	LDA	cpu_pcl
	AND	#$3F
	CMP	#bios_call_table_size
	BCS	bios_unknown_big
	ASL	A
	TAX
	JMP	(bios_call_table,X)
	WRISTR	{13,10,"*** UNKNOWN BIOS call (too high): $"}
bios_unknown_big:
	LDA	cpu_pcl
	AND	#$3F
	JSR	write_hex_byte
	JSR	write_crlf
	JMP	halt
.ENDPROC
bios_call_show_and_halt = bios_call::bios_unknown_big


; This is the "main function" jumped by the loader
.EXPORT	app_main
.PROC	app_main
	JSR	init_console
	JSR	clear_screen		; the fist call of this initiailizes console out functions
	WRISTR	{"i8080 emulator and (re-implemented) CP/M for Mega-65 (C)2017 LGB",13,10}
	JSR	cpu_reset
	JSR	install_software	; initializes i8080 CP/M memory, and "uploads" the software there we want to run
	LDA	#1
	STA	cpu_pch			; reset address was 0, now with high byte modified to 1, it's 0x100, the start address of CP/M programs.
	WRISTR	{"Entering into i8080 mode",13,10,13,10}
	CLI				; hmmm! enable interrupts oh-oh!
	JMP	cpu_start
.ENDPROC


; i8080 emulator will jump here on "cpu_leave" event
.EXPORT	return_cpu_leave
.PROC	return_cpu_leave
	LDA	cpu_pch
	CMP	#BIOSPAGE
	LBEQ	bios_call
	CMP	#BDOSPAGE
	LBEQ	bdos_call
	WRISTR	{13,10,"*** Emulation trap not on the BIOS or BDOS pages",13,10}
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
