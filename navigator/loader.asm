; System/file navigator for Mega-65
;
; This file (with the Makefile too) also functions as an intended example
; for M65 development, using C65 mode loader, and Xemu to test (see Makefile)
; during the development. Please feel free to contant me with suggested
; modifications, it's higly onl a try&error method to do something useful.
;
; Copyright (C)2017 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
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


.SETCPU "4510"	; This requires quite new CA65 (of the CC65 suite) version, maybe git version can only do this ...

.SEGMENT "LOADADDR"
	.IMPORT __BASICSTUB_LOAD__
	.WORD   __BASICSTUB_LOAD__

.SEGMENT "BASICSTUB"
.SCOPE
	.WORD lastline, $FFFF
	; TODO: for me, BASIC 10 "BANK" keyword is quite confusing. According to the available documentation,
	; It's set the BANK number, with the extension that +128 means the "BASIC configuration" (I/O, etc)
	; However according to my tests, it's not true. Using BANK 128 here, still does not work. What I can
	; found only for a sane C65 loader is using BANK 0 before SYS, and doing all the memory MAP, etc then
	; in machine code for the desired mode. I will do that, in routine init_system, see later.
	.WORD $02FE					; "BANK" basic 10 token (double byte token, btw)
	.BYTE " 0 : "
	.BYTE $9E					; "SYS" basic token
	.BYTE " "
	.BYTE $30+.LOBYTE((stub_main .MOD 10000)/ 1000)
	.BYTE $30+.LOBYTE((stub_main .MOD  1000)/  100)
	.BYTE $30+.LOBYTE((stub_main .MOD   100)/   10)
	.BYTE $30+.LOBYTE( stub_main .MOD    10)
	.BYTE 0
lastline:
	.WORD 0
stub_main:
	LDA	#$60		; disallows re-run of the program (patches the first opcode to RTS at stub_main) ...
	STA	stub_main	; ... this process can be important as most programs don't like to be-executed
	JMP	main
.ENDSCOPE


.MACRO	HYPERDOS
	STA	$D640	; DOS hypervisor trap on write (I/O mode for M65 should be enabled for this)
	NOP		; I am not really understand this, but it seems there can (?) be situation when an opcode is not executed after a hypervisor trap?!
.ENDMACRO



.CODE


.PROC set_c65_io_mode
	LDA	#$A5
	STA	$D02F
	LDA	#$96
	STA	$D02F
	RTS
.ENDPROC


.PROC set_m65_io_mode
	LDA	#$47
	STA	$D02F
	LDA	#$53
	STA	$D02F
	RTS
.ENDPROC



.PROC init_system
	; Generic stuffs
	; TODO: if only used as PRG file, BASIC stub should be modified for BANK other than 0 to avoid re-mapping?
	; Also many things are initialized here quite "low-level style", the idea: maybe can be used without any ROM, pre-init etc as well later ...
	SEI
	CLD
	LDA	#0		; A:=0
	TAX			; X:=0
	TAZ			; Z:=0
	TAY			; Y:=0
	MAP			; basically switch MAP'ping off, zero offsets, and unmapped states (we assume, that in C65 mode, basic memory is really "linear" etc)
	TAB			; zero page is ... zero page
	INY			; Y:=1
	TYS			; std stack page (page-1) [if it was not before, we're in trouble at RTS at the end ...]
	SEE
	EOM
	DEX			; X:=$FF
	STX	0
	STX	1		; default "C64 style" memory configutation
	JSR	set_c65_io_mode	; for accessing $D030, since we are not sure if it's M65, we use C65 I/O mode only, not M65 yet!
	STZ	$D030		; turn VIC-III ROM mappings (Z=0!), what may be active (which overrides all other memory mapping methods). For this, we need at least C65 I/O mode (?)
	; Check hypervisor
	JSR	set_m65_io_mode	; We need M65 I/O mode for this ...
	TZA			; A:=$00
	HYPERDOS		; get version (A=0) hypervisor call
	LDZ	#0		; the hypervisor/dos trap sets Z, let's set to zero
	CMP	#0		; now check if "A" is still zero. If does, it's not an M65 with proper KS/hypervisor trapping
	BNE	hypervisor_ok
	; Problem, hypervisor not responding ... Is it possible that it's not M65? Maybe "only" C65?
	; Try a "software reset" as exit ... (with C64's RAM, it will drop into C65 mode if no reason found to stay in C64 mode, the normal C65 boot-up process btw)
	JSR	set_c65_io_mode	; TODO: really needed here?
	JMP	($FFFC)		; execute std reset vector stuff from ("C64") ROM
hypervisor_ok:
	; At this point, we identified a working M65, in M65 (!) I/O mode, though the memory configuration
	; it like C64, with RAM, KERNAL+BASIC+I/O mapped
	STZ	$D418	; Set SIDs' volume to zero to mute possible "forgotten" turned on sounds
	STZ	$D458
	; TODO: I am lazy now. Implement VIC, mode reset, etc etc, CIA bank
	; M65 specific speed controll stuff ...

	LDA	#$40
	TSB	$D031	; C65 speed
	TSB	$D054	; M65 speed (M65 CPU speed, seems C65-speed to set first for this)

	RTS
.ENDPROC


main:
	JSR	init_system		; resets memory mapping, VIC mode, etc
@loop:
	INC	53281
	JMP	@loop

