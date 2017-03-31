; Some misc. Mega-65 specific CA65 helpers
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

.SETCPU "4510"		; This requires quite new CA65 (of the CC65 suite) version, maybe only the git version can do this ...

.MACRO  HYPERDOS
	STA	$D640	; DOS hypervisor trap on write (I/O mode for M65 should be enabled for this)
	NOP		; I am not really understand this, but it seems there can (?) be situation when an opcode is not executed after a hypervisor trap?!
.ENDMACRO

; Mega-65 32 bit linear ops

.MACRO	LDA32Z	zploc
	NOP
	LDA	(zploc),Z
.ENDMACRO
.MACRO	STA32Z	zploc
	NOP
	STA	(zploc),Z
.ENDMACRO
.MACRO	ORA32Z	zploc
	NOP
	ORA	(zploc),Z
.ENDMACRO
.MACRO	AND32Z	zploc
	NOP
	AND	(zploc),Z
.ENDMACRO
.MACRO	EOR32Z	zploc
	NOP
	EOR	(zploc),Z
.ENDMACRO
.MACRO	ADC32Z	zploc
	NOP
	ADC	(zploc),Z
.ENDMACRO
.MACRO	SBC32Z	zploc
	NOP
	SBC	(zploc),Z
.ENDMACRO

.MACRO __DMA_COPY_OP__		sourcebank, source, targetbank, target, length, upward, chained
.ENDMACRO
.MACRO __DMA_FILL_OP__		targetbank, target, filler, length, upward, chained
.ENDMACRO
.MACRO DMA_COPY_OP_CHAINED	sourcebank, source, targetbank, target, length, upward
.ENDMACRO
.MACRO DMA_COPY_OP_LAST		sourcebank, source, targetbank, target, length, upward
.ENDMACRO
.MACRO DMA_FILL_OP_CHAINED	targetbank, target, filler, length, upward
.ENDMACRO
.MACRO DMA_FILL_OP_LAST		targetbank, target, filler, length, upward
.ENDMACRO
