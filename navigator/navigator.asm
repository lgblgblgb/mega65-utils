; System/file navigator for Mega-65
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
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

.SETCPU "4510"	; This requires quite new CA65 (from CC65 suite) version, maybe git version only can do this ...

.SEGMENT "LOADADDR"
	.IMPORT __BASICSTUB_LOAD__
	.WORD __BASICSTUB_LOAD__
.SEGMENT "BASICSTUB"
.SCOPE
	.WORD lastline, $FFFF
	.BYTE $FE, $02					; "BANK" basic 10 token (double byte token, btw)
	.BYTE " 0 : "
	.BYTE $9E					; "SYS" basic token
	.BYTE " "
	.BYTE $30+.LOBYTE(main/10000)
	.BYTE $30+.LOBYTE((main .MOD 10000)/1000)
	.BYTE $30+.LOBYTE((main .MOD 1000)/100)
	.BYTE $30+.LOBYTE((main .MOD 100)/10)
	.BYTE $30+.LOBYTE( main .MOD 10)
	.BYTE 0
lastline:
	.WORD 0
.ENDSCOPE


.CODE
main:
	SEI
	CLD
	LDA	#0
	TAX
	TAZ
	TAY
	MAP
	TAB
	INY
	TYS
	SEE
	EOM

	LDA	#$2F
	STA	0
	LDA	#$35
	STA	1
	

	STX	53280
	STX	53281

;@loop:
;	JMP	@loop

	CLI

	RTS


