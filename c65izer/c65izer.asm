; My first attempt to create and ugly "wrapper" to provide a quicky but
; messy way to load C64 programs on C65/M65 without the need to go C64
; mode first. You need only copy the original C64 program (only ones with
; "BASIC stub loader" - ie the SYS stuff) after binary c65izer.
;
; It's really primitive, and maybe I do a lots of redundant things, or
; other stuffs can be treated as already done (ie BANK 0 config, I still
; does MAP etc), or can be done with ROM functions, or can be done much
; better way (ie faking "RUN" with keyboard buffer). Anyway ...
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

.SETCPU "4510"

.SEGMENT "LOADADDR"
	.IMPORT __BASICSTUB_LOAD__
	.WORD   __BASICSTUB_LOAD__


.SEGMENT "BASICSTUB"
.SCOPE
	.WORD lastline
	.WORD $FFFF
	.WORD $02FE	; two-byte "BANK" token
	.BYTE "0:"
	.BYTE $9E	; "SYS" token
	.BYTE $30 + .LOBYTE((main .MOD 10000) / 1000)
	.BYTE $30 + .LOBYTE((main .MOD  1000) /  100)
	.BYTE $30 + .LOBYTE((main .MOD   100) /   10)
	.BYTE $30 + .LOBYTE( main .MOD    10)
	.BYTE 0
lastline:
	.WORD 0
.ENDSCOPE

.SEGMENT "PAYLOAD"
.IMPORT __PAYLOAD_LOAD__
	; !!!! this segment MUST BE EMPTY !!!!


.SEGMENT "CASBUFF"
; We need to copy a relocates stuff to do the copy as we would overwrite ourselves otherwise.
; Yes, it's much mature to use C65 DMA, but I avoid it by will: on  C65 there are more DMA
; revisions, and this stuff intended to be usable (maybe ...) on a C65 as well, not only M65.
; This routine must be no larger than 192 bytes. We use casette buffer space (see linker config).
.PROC copy_relocated
loop:
	LDA	__PAYLOAD_LOAD__ + 2,X
	STA	$7FF + 2,X
	INX
	BNE	loop
	INC	loop + 2
	INC	loop + 5
	DEY
	BNE	loop
	LDA	#64
	STA	0	; on M65 this disables force fast mode
	LDA	#7
	STA	0	; correct CPU I/O DDR, as on C65 the above op would mess things up (bit not on M65)
	STA	1	; also set "default" C64 memory config
	STX	$D031	; C65 fast mode off (X=0)
	STX	$D02F	; VIC-II I/O mode by messing the KEY register up
	CLI
	LDX	#$80
	JMP	($0300)   ; normally E38B
.ENDPROC



.SEGMENT "CODE"

.IMPORT __CASBUFF_SIZE__
.IMPORT __CASBUFF_LOAD__
.IMPORT __CASBUFF_RUN__

.PROC main
	SEI
	CLD
	LDA	#0
	TAX
	TAY
	TAZ
	MAP		; unmapped memory state
	NOP		; "aka EOM", SEI is still in effect, just do not forget this!
	TAB		; zero page is page-0
	DEX
	TXS		; stack pointer is $FF
	INY
	TYS		; stack page is page-1

	LDA	#65
	STA	0	; hopefully this does not do too much on a C65, on M65 it enables the forced_fast stuff
	LDA	#7	; CPU I/O port
	STA	0
	STA	1	

	STZ	$D016
	STZ	$D030	; ROM mapping etc, off
	LDA	#64	; some cheating, use C65 fast mode ... (and disable all other fancy stuffs btw)
	STA	$D031

	; Now calling functions from C64 KERNAL, would be used otherwise too in case of RESET
	JSR	$FDA3       ; initialise I/O
	JSR	$FD50       ; initialise memory
	JSR	$FD15       ; set I/O vectors ($0314..$0333) to kernal defaults
	JSR	$FF5B       ; more initialising... mostly set system IRQ to correct value and start

	; BASIC init stuff?
	JSR	$E453	; initiailize vectors
	JSR	$E3BF	; initialisation of basic
	JSR	$E422	; print BASIC start up messages
	LDX	#$FB
	TXS

	; Ugly trick: put "RUN" (+RETURN) into the keybuffer, so BASIC will execute our command ...
	LDA	#4
	STA	$C6	; keyboard buffer length
	LDA	#'R'
	STA	$277
	LDA	#'U'
	STA	$278
	LDA	#'N'
	STA	$279
	LDA	#13
	STA	$27A

	; Copy the copier ...
	LDX	#.LOBYTE(__CASBUFF_SIZE__)
copy:
	LDA	__CASBUFF_LOAD__-1,X
	STA	__CASBUFF_RUN__-1,X
	DEX
	BNE	copy

	LDX	#0
	LDY	#.LOBYTE($1000 - __PAYLOAD_LOAD__)
	SEI
	STX	1	; all RAM config!!
	JMP	copy_relocated	; (X and Y must be set)
.ENDPROC
