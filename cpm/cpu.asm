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
;
; **WARNING** The code assumes that Z is zero. If we need to set it to another
; value, we must set back to zero ASAP! This rule remains valid throughout
; this source file!
; **WARNING** This 8080 emulation is not fully correct. Surely, not its by
; timing, but there can be "corner cases" where it fails, ie, wrapping around
; memory reference at the end of 64K, possible many flag handling bugs, etc.
; *NOTE*: Though this is a 8080 emulator, and not Z80, I still prefer (and
; know) Z80 asm syntax better than 8080, so I will use that terminology! Also,
; the intent, that some day, maybe this can become a Z80 emulator as well,
; though that needs more work ...
;
; ----------------------------------------------------------------------------

.INCLUDE "mega65.inc"

.ZEROPAGE

; Must be before the first CPU specific ZP label
cpu_first:
; Register pair AF (PSW), not used for indexing, no need for "H16":
.EXPORTZP	cpu_af
cpu_af:
cpu_f:		.RES 1
cpu_a:		.RES 1
; Register pair BC
.EXPORTZP	cpu_bc
cpu_bc:
cpu_c:		.RES 1
cpu_b:		.RES 1
cpu_bc_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Register pair DE
.EXPORTZP	cpu_de
cpu_de:
cpu_e:		.RES 1
cpu_d:		.RES 1
cpu_de_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Register pair HL
.EXPORTZP	cpu_hl
cpu_hl:
cpu_l:		.RES 1
cpu_h:		.RES 1
cpu_hl_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; The program counter
.EXPORTZP	cpu_pc
cpu_pc:
cpu_pcl:	.RES 1
cpu_pch:	.RES 1
cpu_pc_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Stack pointer
.EXPORTZP	cpu_sp
cpu_sp:
cpu_spl:	.RES 1
cpu_sph:	.RES 1
cpu_sp_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Memory pointer, used in operations like (1234)
.EXPORTZP	cpu_mem_p	; this is provided for INITIAL usage of emulator but never after CPU reset!!!
cpu_mem_p:
cpu_mem_l:	.RES 1
cpu_mem_h:	.RES 1
cpu_mem_p_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Only updated at exit, the CPU opcode (at cpu_pc) which caused the exit of i8080 mode
.EXPORTZP	cpu_op
cpu_op:		.RES 1
; Must be after the last CPU specific ZP label
cpu_last:


.CODE

.INCLUDE "cpu_tables.inc"

; Mega-65 32 bit linear ops from mega65.inc
;
; NOTE: ZP locations above holds 4 bytes for pointers, the second two bytes
; are the higher 16 bits of 32 bits address which is fixed for the emulation,
; and only the lower 16 bits are used as registers. These 4 bytes pointers
; are used by the special Mega-65 addressing modes capable of addressing the
; whole memory space. This allows us to have own memory for the emulator
; itself, and still having 64K fully for the 8080 emulation without the need
; of slow memory paing, address calculating etc, on each 8080 memory references.
; NOTE: using this M65-specific feature is actually slower than "normal"
; memory acces, but the only sane way to provide full 64K for 8080 and also avoid
; memory mapping tricks all the time during the emulation which would be even
; much more slower anyway!

; Stack byte level POP/PUSH primitives

.MACRO	POPB
	LDA32Z	cpu_sp
	INW	cpu_sp
.ENDMACRO
.MACRO	PUSHB
	DEW	cpu_sp
	STA32Z	cpu_sp
.ENDMACRO

; Stack pop/push register pair

.MACRO	POP_RR	rpa
	POPB
	STA	z:rpa
	POPB
	STA	z:rpa + 1
.ENDMACRO
.MACRO	PUSH_RR	rpa
	LDA	z:rpa + 1
	PUSHB
	LDA	z:rpa
	PUSHB
.ENDMACRO

; Load/store LD ops

.MACRO	OPC_LD_R_N target
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	z:target
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_LD_R_R target,source
	LDA	z:source
	STA	z:target
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_LD_R_RI reg, regpair
	LDA32Z	regpair
	STA	z:reg
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_LD_RI_R regpair, reg
	LDA	z:reg
	STA32Z	regpair
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_LD_RR_NN regpair
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	z:regpair
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	z:regpair+1
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_LD_RI_N regpair
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA32Z	regpair
	JMP	next_inc1
.ENDMACRO

; Final stack POP/PUSH implementations, can be directly used by opcode realization for 8080

.MACRO	OPC_PUSH_RR regpair
	PUSH_RR	regpair
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_POP_RR regpair
	POP_RR	regpair
	JMP	next_inc1
.ENDMACRO

; INC/DEC 16 bit registers (the more easy stuff, as register pairs INC/DEC do not modify any 8080 flags bit!)

.MACRO	OPC_INC_RR regpair
	INW	z:regpair
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_DEC_RR regpair
	DEW	z:regpair
	JMP	next_inc1
.ENDMACRO

; INC/DEC 8 bit registers

.MACRO	OPC_INC_R reg
	LDX	z:reg
	INX
	STX	z:reg
	LDA	cpu_f
	AND	#1			; keep only carry flag from flags
	ORA	inc8_f_tab,X
	STA	cpu_f
	JMP	next_inc1
.ENDMACRO
.MACRO	OPC_DEC_R reg
	LDX	z:reg
	DEX
	STX	z:reg
	LDA	cpu_f
	AND	#1
	ORA	dec8_f_tab,X
	STA	cpu_f
	JMP	next_inc1
.ENDMACRO

; 16 bit ADD HL,RR operations

.MACRO	OPC_ADD_HL_RR	regpair
	CLC
	LDA	z:regpair
	ADC	cpu_l
	STA	cpu_l
	LDA	z:regpair+1
	ADC	cpu_h
	STA	cpu_h
	BCS	:+
	RMB0	cpu_f
	JMP	next_inc1
:	SMB0	cpu_f
	JMP	next_inc1
.ENDMACRO

; 8 bit "ADD" operations

.MACRO	ADC_ADD_OPS	addop, value
	LDA	cpu_a
	addop	value		; addop: ADC or ADC32Z (for immed. value or (HL) indexed), for ADC32Z, value must be cpu_pc/cpu_hl pointing to the value itself
	STA	cpu_a		; this was the easy part, but the flags, oh my!!! :-@
	TAX
	LDA	szp_f_tab,X
	ADC	#0		; based on the carry of the "main" ADC ("addop") op's result, this will set bit0 of flags (from szp_f_tab) as it was zero before!
	STA	cpu_f		; store flags: FIXME no Half-carry yet :(
	; Now S,Z,P,C is handled, the most problematic stuff remains: H
	; FIXME: H is not handled yet, that damn too complex according to some emulator sources, I had to look up. In theory it's easy,
	; just carry from bit 3 to bit 4, but it looks something really odd, using look-up tables and ugly index generation, which would be really slow here!
.ENDMACRO
.MACRO	OPC_ADD_A_R	addop, value
	CLC
	ADC_ADD_OPS	addop, value
	JMP		next_inc1
.ENDMACRO
.MACRO	OPC_ADC_A_R	addop, value
	; Moving i8080's carry flag into our actual 65xx CPU's carry flag:
	LDA		cpu_f
	LSR		A
	; Now the operation
	ADC_ADD_OPS	addop, value
	JMP		next_inc1
.ENDMACRO



; RST "generator"

.MACRO	OPC_RST	vector
	INW	cpu_pc
	PUSH_RR	cpu_pc
	STZ	cpu_pch		; Z = 0, so high address of PC will be zero
	LDA	#vector
	STA	cpu_pcl		; set low byte of PC
	JMP	next_no_inc
.ENDMACRO

; Memory pointer helpers (contant memory pointer in opcode to fetch/store data from/to)

.MACRO	MEMCONSTPTROP_BEGIN	; for things like LD ..,(1123)
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	cpu_mem_l
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	cpu_mem_h
.ENDMACRO
.MACRO	MEMCONSTPTROP_END
	JMP	next_inc1
.ENDMACRO

; Conditional opcodes related stuffs

.MACRO	BR_SIGN label
	BBS7    cpu_f, label
.ENDMACRO
.MACRO	BR_NSIGN label
	BBR7	cpu_f, label
.ENDMACRO
.MACRO	BR_ZERO label
	BBS6	cpu_f, label
.ENDMACRO
.MACRO	BR_NZERO label
	BBR6	cpu_f, label
.ENDMACRO
.MACRO	BR_PAR label
	BBS2	cpu_f, label
.ENDMACRO
.MACRO	BR_NPAR label
	BBR2	cpu_f, label
.ENDMACRO
.MACRO	BR_CARRY label
	BBS0	cpu_f, label
.ENDMACRO
.MACRO	BR_NCARRY label
	BBR0	cpu_f, label
.ENDMACRO
.MACRO	COND_OP	cond,do,skip
	cond	do
	JMP	skip
.ENDMACRO


.MACRO	OPC_LOGICOP_GEN op,reg,ftab
	LDA	cpu_a
	op	reg
	STA	cpu_a
	TAX
	LDA	ftab,X
	STA	cpu_f
	JMP	next_inc1
.ENDMACRO


; *******************************************************************
; *** Main opcode fetch, and instruction "decoding" by jump table ***
; *******************************************************************

; NOTE: general design of the CPU emulator is to keep it simple for now.
; Actually, on 65CE02 at least "INW" in kinda slow (7 cycles?). It would
; be better to use "Z" register as an offset from a base, and only adjust
; that base if Z overflows. It would help to gain more speed. However,
; that makes many operation (requires PC to calculated, etc, for example
; on CALLs) more complex, and also more complex way to always save Z
; in case if we need it (for SP reference, or direct memory pointer).
; My general idea, to use the most simple method for now, at least.
; Anyway, maybe M65 will use ZP caching, so INW will be anyway fast
; enough. Also don't forget, that we're running on 48Mhz 65CE02-like
; CPU, so it not so bad at least, we can say.

next_inc3:
	INW	cpu_pc
next_inc2:
	INW	cpu_pc
next_inc1:
	INW	cpu_pc
next_no_inc:
	LDA32Z	cpu_pc				; fetch opcode byte
	ASL	A				; multiply by two, since word based table. Old 7th bit is the carry flag now
	TAX					; prepare for the JMP (nnnn,X) opcode
	BCC	@ops_low_half			; we have 256 ops, but because of ASL, we must halve their handling (see comment at ASL above about carry)
	JMP	(opcode_jump_table+$100,X)	; upper half of the opcodes
@ops_low_half:
	JMP	(opcode_jump_table,X)		; lower half of the opcodes

NO_OP	= next_inc1

; NOTE: much compact decoding can be done for sure without a full
; jump table, and trickier way to decode opcodes. However I simply
; don't care about size, I am happy with jump tables, or even kinda
; big data tables for flags, etc, if it helps to gain speed!
; After all, the goal it to have "okey" speed of 8080 emulation
; for CP/M and such running on the M65, it does not help too much
; if the emulated 8080 runs like a 8080 locked on 10KHz or such ...

opcode_jump_table:
	.WORD opc_00,opc_01,opc_02,opc_03,opc_04,opc_05,opc_06,opc_07,opc_08,opc_09,opc_0A,opc_0B,opc_0C,opc_0D,opc_0E,opc_0F
	.WORD opc_10,opc_11,opc_12,opc_13,opc_14,opc_15,opc_16,opc_17,opc_18,opc_19,opc_1A,opc_1B,opc_1C,opc_1D,opc_1E,opc_1F
	.WORD opc_20,opc_21,opc_22,opc_23,opc_24,opc_25,opc_26,opc_27,opc_28,opc_29,opc_2A,opc_2B,opc_2C,opc_2D,opc_2E,opc_2F
	.WORD opc_30,opc_31,opc_32,opc_33,opc_34,opc_35,opc_36,opc_37,opc_38,opc_39,opc_3A,opc_3B,opc_3C,opc_3D,opc_3E,opc_3F
	.WORD opc_40,opc_41,opc_42,opc_43,opc_44,opc_45,opc_46,opc_47,opc_48,opc_49,opc_4A,opc_4B,opc_4C,opc_4D,opc_4E,opc_4F
	.WORD opc_50,opc_51,opc_52,opc_53,opc_54,opc_55,opc_56,opc_57,opc_58,opc_59,opc_5A,opc_5B,opc_5C,opc_5D,opc_5E,opc_5F
	.WORD opc_60,opc_61,opc_62,opc_63,opc_64,opc_65,opc_66,opc_67,opc_68,opc_69,opc_6A,opc_6B,opc_6C,opc_6D,opc_6E,opc_6F
	.WORD opc_70,opc_71,opc_72,opc_73,opc_74,opc_75,opc_76,opc_77,opc_78,opc_79,opc_7A,opc_7B,opc_7C,opc_7D,opc_7E,opc_7F
	.WORD opc_80,opc_81,opc_82,opc_83,opc_84,opc_85,opc_86,opc_87,opc_88,opc_89,opc_8A,opc_8B,opc_8C,opc_8D,opc_8E,opc_8F
	.WORD opc_90,opc_91,opc_92,opc_93,opc_94,opc_95,opc_96,opc_97,opc_98,opc_99,opc_9A,opc_9B,opc_9C,opc_9D,opc_9E,opc_9F
	.WORD opc_A0,opc_A1,opc_A2,opc_A3,opc_A4,opc_A5,opc_A6,opc_A7,opc_A8,opc_A9,opc_AA,opc_AB,opc_AC,opc_AD,opc_AE,opc_AF
	.WORD opc_B0,opc_B1,opc_B2,opc_B3,opc_B4,opc_B5,opc_B6,opc_B7,opc_B8,opc_B9,opc_BA,opc_BB,opc_BC,opc_BD,opc_BE,opc_BF
	.WORD opc_C0,opc_C1,opc_C2,opc_C3,opc_C4,opc_C5,opc_C6,opc_C7,opc_C8,opc_C9,opc_CA,opc_CB,opc_CC,opc_CD,opc_CE,opc_CF
	.WORD opc_D0,opc_D1,opc_D2,opc_D3,opc_D4,opc_D5,opc_D6,opc_D7,opc_D8,opc_D9,opc_DA,opc_DB,opc_DC,opc_DD,opc_DE,opc_DF
	.WORD opc_E0,opc_E1,opc_E2,opc_E3,opc_E4,opc_E5,opc_E6,opc_E7,opc_E8,opc_E9,opc_EA,opc_EB,opc_EC,opc_ED,opc_EE,opc_EF
	.WORD opc_F0,opc_F1,opc_F2,opc_F3,opc_F4,opc_F5,opc_F6,opc_F7,opc_F8,opc_F9,opc_FA,opc_FB,opc_FC,opc_FD,opc_FE,opc_FF

; NOTE: the emulation (it's more simple for *MYSELF* at least) of opcodes consits of linear
; sequence of opcode emulation (see later). It's more easy to compare with opcode lists, etc.
; However some opcodes requires to be "groupped" so that 8 bit relate branches can be used,
; with conditional opcodes. That is the reason, I include them here, and only refeer them
; on the "opcode emulation" part later.

opc_CALL_Z:	COND_OP BR_ZERO,  opc_CALL, next_inc3
opc_CALL_NZ:	COND_OP BR_NZERO, opc_CALL, next_inc3
opc_CALL_C:	COND_OP BR_CARRY, opc_CALL, next_inc3
opc_CALL_NC:	COND_OP BR_NCARRY,opc_CALL, next_inc3
opc_CALL_PE:	COND_OP BR_PAR,   opc_CALL, next_inc3
opc_CALL_PO:	COND_OP BR_NPAR,  opc_CALL, next_inc3
opc_CALL_P:	COND_OP BR_NSIGN, opc_CALL, next_inc3
opc_CALL_M:	COND_OP BR_SIGN,  opc_CALL, next_inc3
opc_CALL:
	INW	cpu_pc
	LDA32Z	cpu_pc
	TAX			; X = low byte of call address
	INW	cpu_pc
	LDA32Z	cpu_pc
	TAY			; Y = high byte of call address
	INW	cpu_pc
	PUSH_RR	cpu_pc
	STX	cpu_pcl
	STY	cpu_pch
	JMP	next_no_inc

opc_JP_Z:	COND_OP BR_ZERO,  opc_JP, next_inc3
opc_JP_NZ:	COND_OP BR_NZERO, opc_JP, next_inc3
opc_JP_C:	COND_OP BR_CARRY, opc_JP, next_inc3
opc_JP_NC:	COND_OP BR_NCARRY,opc_JP, next_inc3
opc_JP_PE:	COND_OP BR_PAR,   opc_JP, next_inc3
opc_JP_PO:	COND_OP BR_NPAR,  opc_JP, next_inc3
opc_JP_P:	COND_OP BR_NSIGN, opc_JP, next_inc3
opc_JP_M:	COND_OP BR_SIGN,  opc_JP, next_inc3
opc_JP:
	INZ
	LDA32Z	cpu_pc		; Z = 1 now, reads byte after the opcode of JP, that is, low byte of jump address
	TAX			; X := low byte of jump address
	INZ
	LDA32Z	cpu_pc		; Z = 2 now, reads the high byte of jump addres
	DEZ
	DEZ			; Z is zero again, as it should be! (hmm it should be faster with two DEZs than a single LDZ #0 ...)
	STA	cpu_pch		; store high byte of new PC
	STX	cpu_pcl		; store low byte of new PC
	JMP	next_no_inc	; continue at the given new PC, no need for incrementing it, for sure!


opc_RET_Z:	COND_OP BR_ZERO,  opc_RET, next_inc1
opc_RET_NZ:	COND_OP BR_NZERO, opc_RET, next_inc1
opc_RET_C:	COND_OP BR_CARRY, opc_RET, next_inc1
opc_RET_NC:	COND_OP BR_NCARRY,opc_RET, next_inc1
opc_RET_PE:	COND_OP BR_PAR,   opc_RET, next_inc1
opc_RET_PO:	COND_OP BR_NPAR,  opc_RET, next_inc1
opc_RET_P:	COND_OP BR_NSIGN, opc_RET, next_inc1
opc_RET_M:	COND_OP BR_SIGN,  opc_RET, next_inc1
opc_RET:
	POP_RR	cpu_pc
	JMP	next_no_inc


; ****************************************************************************
; Now the opcodes themselves from 00-FF
; Please note, that some opcodes are defined above, or do no nothing
; (ie opc_00 = NO_OP). The reason for the first issue: some opcodes are more
; optimized to put together, eg need for "8 bit relativ branch distance", etc
; ****************************************************************************


opc_00= NO_OP				; NOP	(no-effect opcodes can refeer for the main opcode fetch entry point itself, simply ...)
opc_01:	OPC_LD_RR_NN	cpu_bc		; LD BC,nn
opc_02:	OPC_LD_RI_R	cpu_bc, cpu_a	; LD (BC),A
opc_03:	OPC_INC_RR	cpu_bc		; INC BC, 8080 syntax: INX B
opc_04: OPC_INC_R	cpu_b		; INC B
opc_05: OPC_DEC_R	cpu_b		; DEC B
opc_06:	OPC_LD_R_N	cpu_b		; LD B,n
opc_07:					; RLCA
	LDA	cpu_a
	ASL	A	; shift left, original bit 7 in the carry now, bit 0 become 0
	BCS	:+
	; Carry should be clear, bit 0 of A is OK to leave that way
	STA	cpu_a
	RMB0	cpu_f
	JMP	next_inc1
:	; Carry to set! bit0 of A should be set!
	INA	; sets bit0 to 1 since it was zero before
	STA	cpu_a
	SMB0	cpu_f
	JMP	next_inc1
opc_08= NO_OP				; *NON-STANDARD* NOP	[EX AF,AF' on Z80]
opc_09: OPC_ADD_HL_RR	cpu_bc		; ADD HL,BC
opc_0A:	OPC_LD_R_RI	cpu_a, cpu_bc	; LD A,(BC)
opc_0B:	OPC_DEC_RR	cpu_bc		; DEC BC
opc_0C: OPC_INC_R	cpu_c		; INC C
opc_0D: OPC_DEC_R	cpu_c		; DEC C
opc_0E:	OPC_LD_R_N	cpu_c		; LD C,n
opc_0F:					; RRCA
	LDA	cpu_a
	LSR	A
	BCS	:+
	; Carry should be clear, bit 7 of A is OK to leave that way
	STA	cpu_a
	RMB0	cpu_f
	JMP	next_inc1
:	; Carry to set! bit7 of A should be set!
	ORA	#$80	; sets bit 7 of A
	STA	cpu_a
	SMB0	cpu_f
	JMP	next_inc1
opc_10= NO_OP				; *NON-STANDARD* NOP	[DJNZ on Z80]
opc_11: OPC_LD_RR_NN	cpu_de		; LD DE,nn
opc_12: OPC_LD_RI_R	cpu_de, cpu_a	; LD (DE),A
opc_13:	OPC_INC_RR	cpu_de		; INC DE
opc_14: OPC_INC_R	cpu_d		; INC D
opc_15: OPC_DEC_R	cpu_d		; DEC D
opc_16: OPC_LD_R_N	cpu_d		; LD D,n
opc_17:					; RLA
	LDA	cpu_f
	LSR	A		; now i8080 carry is in 65xx real carry
	ROL	cpu_a		; do the major job of the opcode, RMW-style
	ROL	A		; shift back i8080 flags WITH feeding carry with the previouS ROL
	STA	cpu_f
	JMP	next_inc1
opc_18= NO_OP				; *NON-STANDARD* NOP	[JR on Z80]
opc_19:	OPC_ADD_HL_RR	cpu_de		; ADD HL,DE
opc_1A: OPC_LD_R_RI	cpu_a, cpu_de	; LD A,(DE)
opc_1B:	OPC_DEC_RR	cpu_de		; DEC DE
opc_1C: OPC_INC_R	cpu_e		; INC E
opc_1D: OPC_DEC_R	cpu_e		; DEC E
opc_1E:	OPC_LD_R_N	cpu_e		; LD E,n
opc_1F: 				; RRA
	LDA	cpu_f
	LSR	A
	ROR	cpu_a
	ROL	A
	STA	cpu_f
	JMP	next_inc1
opc_20= NO_OP				; *NON-STANDARD* NOP	[JR NZ on Z80]
opc_21: OPC_LD_RR_NN	cpu_hl		; LD HL,nn
opc_22:					; LD (nn),HL
	MEMCONSTPTROP_BEGIN
	LDA	cpu_l
	STA32Z	cpu_mem_p
	INZ
	LDA	cpu_h
	STA32Z	cpu_mem_p	; writes byte indexed by (cpu_mem_p)+1 becasuse Z=1 now
	DEZ		; Z=0 again!!!
	MEMCONSTPTROP_END
opc_23:	OPC_INC_RR	cpu_hl		; INC HL
opc_24: OPC_INC_R	cpu_h		; INC H
opc_25: OPC_DEC_R	cpu_h		; DEC H
opc_26:	OPC_LD_R_N	cpu_h		; LD H,n
opc_27= TODO				; DAA
opc_28= NO_OP				; *NON-STANDARD* NOP	[JR Z on Z80]
opc_29: OPC_ADD_HL_RR	cpu_hl		; ADD HL,HL
opc_2A:					; LD HL,(nn)
	MEMCONSTPTROP_BEGIN	
	LDA32Z	cpu_mem_p
	STA	cpu_l
	INZ
	LDA32Z	cpu_mem_p	; reads byte indexed by (cpu_mem_p)+1 becasuse Z=1 now
	STA	cpu_h
	DEZ		; Z=0 again!!!
	MEMCONSTPTROP_END
opc_2B:	OPC_DEC_RR	cpu_hl		; DEC HL
opc_2C: OPC_INC_R	cpu_l		; INC L
opc_2D: OPC_DEC_R	cpu_l		; DEC L
opc_2E:	OPC_LD_R_N	cpu_l		; LD L,n
opc_2F:					; CPL
	LDA	cpu_a
	EOR	#$FF
	STA	cpu_a
	JMP	next_inc1
opc_30= NO_OP				; *NON-STANDARD* NOP	[JR NC on Z80]
opc_31: OPC_LD_RR_NN	cpu_sp		; LD SP,nn
opc_32:					; LD (nn),A
	MEMCONSTPTROP_BEGIN
	LDA	cpu_a
	STA32Z	cpu_mem_p
	MEMCONSTPTROP_END
opc_33:	OPC_INC_RR	cpu_sp		; INC SP
opc_34:					; INC (HL)
	LDA32Z	cpu_hl
	INA
	STA32Z	cpu_hl
	TAX
	LDA	cpu_f
	AND	#1
	ORA	inc8_f_tab,X
	STA	cpu_f
	JMP	next_inc1
opc_35:					; DEC (HL)
	LDA32Z	cpu_hl
	DEA
	STA32Z	cpu_hl
	TAX
	LDA	cpu_f
	AND	#1
	ORA	dec8_f_tab,X
	STA	cpu_f
	JMP	next_inc1
opc_36:	OPC_LD_RI_N	cpu_hl		; LD (HL),n
opc_37:					; SCF
	SMB0	cpu_f
	JMP	next_inc1
opc_38= NO_OP				; *NON-STANDARD* NOP	[JR C on Z80]
opc_39:	OPC_ADD_HL_RR	cpu_sp		; ADD HL,SP
opc_3A:					; LD A,(nn)
	MEMCONSTPTROP_BEGIN
	LDA32Z	cpu_mem_p
	STA	cpu_a
	MEMCONSTPTROP_END
opc_3B:	OPC_DEC_RR	cpu_sp		; DEC SP
opc_3C: OPC_INC_R	cpu_a		; INC A
opc_3D: OPC_DEC_R	cpu_a		; DEC A
opc_3E: OPC_LD_R_N	cpu_a		; LD A,n
opc_3F:					; CCF
	LDA	cpu_f
	EOR	#1	; 8080 carry bit mask in flags
	STA	cpu_f
	JMP	next_inc1
opc_40= NO_OP				; LD B,B *DOES NOTHING*
opc_41:	OPC_LD_R_R	cpu_b, cpu_c	; LD B,C
opc_42:	OPC_LD_R_R	cpu_b, cpu_d	; LD B,D
opc_43:	OPC_LD_R_R	cpu_b, cpu_e	; LD B,E
opc_44:	OPC_LD_R_R	cpu_b, cpu_h	; LD B,H
opc_45:	OPC_LD_R_R	cpu_b, cpu_l	; LD B,L
opc_46:	OPC_LD_R_RI	cpu_b, cpu_hl	; LD B,(HL)
opc_47:	OPC_LD_R_R	cpu_b, cpu_a	; LD B,A
opc_48:	OPC_LD_R_R	cpu_c, cpu_b	; LD C,B
opc_49= NO_OP				; LD C,C *DOES NOTHING*
opc_4A:	OPC_LD_R_R	cpu_c, cpu_d	; LD C,D
opc_4B:	OPC_LD_R_R	cpu_c, cpu_e	; LD C,E
opc_4C:	OPC_LD_R_R	cpu_c, cpu_h	; LD C,H
opc_4D:	OPC_LD_R_R	cpu_c, cpu_l	; LD C,L
opc_4E:	OPC_LD_R_RI	cpu_c, cpu_hl	; LD C,(HL)
opc_4F:	OPC_LD_R_R	cpu_c, cpu_a	; LD C,A
opc_50: OPC_LD_R_R	cpu_d, cpu_b	; LD D,B
opc_51:	OPC_LD_R_R	cpu_d, cpu_c	; LD D,C
opc_52= NO_OP				; LD D,D *DOES NOTHING*
opc_53:	OPC_LD_R_R	cpu_d, cpu_e	; LD D,E
opc_54:	OPC_LD_R_R	cpu_d, cpu_h	; LD D,H
opc_55:	OPC_LD_R_R	cpu_d, cpu_l	; LD D,L
opc_56:	OPC_LD_R_RI	cpu_d, cpu_hl	; LD D,(HL)
opc_57:	OPC_LD_R_R	cpu_d, cpu_a	; LD D,A
opc_58:	OPC_LD_R_R	cpu_e, cpu_b	; LD E,B
opc_59:	OPC_LD_R_R	cpu_e, cpu_c	; LD E,C
opc_5A:	OPC_LD_R_R	cpu_e, cpu_d	; LD E,D
opc_5B= NO_OP				; LD E,E *DOES NOTHING*
opc_5C:	OPC_LD_R_R	cpu_e, cpu_h	; LD E,H
opc_5D:	OPC_LD_R_R	cpu_e, cpu_l	; LD E,L
opc_5E:	OPC_LD_R_RI	cpu_e, cpu_hl	; LD E,(HL)
opc_5F:	OPC_LD_R_R	cpu_e, cpu_a	; LD E,A
opc_60: OPC_LD_R_R	cpu_h, cpu_b	; LD H,B
opc_61:	OPC_LD_R_R	cpu_h, cpu_c	; LD H,C
opc_62:	OPC_LD_R_R	cpu_h, cpu_d	; LD H,D
opc_63:	OPC_LD_R_R	cpu_h, cpu_e	; LD H,E
opc_64= NO_OP				; LD H,H *DOES NOTHING*
opc_65:	OPC_LD_R_R	cpu_h, cpu_l	; LD H,L
opc_66:	OPC_LD_R_RI	cpu_h, cpu_hl	; LD H,(HL)
opc_67:	OPC_LD_R_R	cpu_h, cpu_a	; LD H,A
opc_68:	OPC_LD_R_R	cpu_l, cpu_b	; LD L,B
opc_69:	OPC_LD_R_R	cpu_l, cpu_c	; LD L,C
opc_6A:	OPC_LD_R_R	cpu_l, cpu_d	; LD L,D
opc_6B:	OPC_LD_R_R	cpu_l, cpu_e	; LD L,E
opc_6C:	OPC_LD_R_R	cpu_l, cpu_h	; LD L,H
opc_6D= NO_OP				; LD L,L *DOES NOTHING*
opc_6E:	OPC_LD_R_RI	cpu_l, cpu_hl	; LD L,(HL)
opc_6F:	OPC_LD_R_R	cpu_l, cpu_a	; LD L,A
opc_70: OPC_LD_RI_R	cpu_hl, cpu_b	; LD (HL),B
opc_71:	OPC_LD_RI_R	cpu_hl, cpu_c	; LD (HL),C
opc_72:	OPC_LD_RI_R	cpu_hl, cpu_d	; LD (HL),D
opc_73:	OPC_LD_RI_R	cpu_hl, cpu_e	; LD (HL),E
opc_74:	OPC_LD_RI_R	cpu_hl, cpu_h	; LD (HL),H
opc_75:	OPC_LD_RI_R	cpu_hl, cpu_l	; LD (HL),L
opc_76= cpu_leave			; *HALT*
opc_77:	OPC_LD_RI_R	cpu_hl, cpu_a	; LD (HL),A
opc_78:	OPC_LD_R_R	cpu_a, cpu_b	; LD A,B
opc_79:	OPC_LD_R_R	cpu_a, cpu_c	; LD A,C
opc_7A:	OPC_LD_R_R	cpu_a, cpu_d	; LD A,D
opc_7B:	OPC_LD_R_R	cpu_a, cpu_e	; LD A,E
opc_7C:	OPC_LD_R_R	cpu_a, cpu_h	; LD A,H
opc_7D:	OPC_LD_R_R	cpu_a, cpu_l	; LD A,L
opc_7E:	OPC_LD_R_RI	cpu_a, cpu_hl	; LD A,(HL)
opc_7F= NO_OP				; LD A,A *DOES NOTHING*
opc_80:	OPC_ADD_A_R	ADC, cpu_b	; ADD A,B
opc_81:	OPC_ADD_A_R	ADC, cpu_c	; ADD A,C
opc_82:	OPC_ADD_A_R	ADC, cpu_d	; ADD A,D
opc_83:	OPC_ADD_A_R	ADC, cpu_e	; ADD A,E
opc_84:	OPC_ADD_A_R	ADC, cpu_h	; ADD A,H
opc_85:	OPC_ADD_A_R	ADC, cpu_l	; ADD A,L
opc_86:	OPC_ADD_A_R	ADC32Z, cpu_hl	; ADD A,(HL)
opc_87:	OPC_ADD_A_R	ADC, cpu_a	; ADD A,A
opc_88:	OPC_ADC_A_R	ADC, cpu_b	; ADC A,B
opc_89:	OPC_ADC_A_R	ADC, cpu_c	; ADC A,C
opc_8A:	OPC_ADC_A_R	ADC, cpu_d	; ADC A,D
opc_8B:	OPC_ADC_A_R	ADC, cpu_e	; ADC A,E
opc_8C:	OPC_ADC_A_R	ADC, cpu_h	; ADC A,H
opc_8D:	OPC_ADC_A_R	ADC, cpu_l	; ADC A,L
opc_8E:	OPC_ADC_A_R	ADC32Z, cpu_hl	; ADC A,(HL)
opc_8F:	OPC_ADC_A_R	ADC, cpu_a	; ADC A,A
opc_90= TODO
opc_91= TODO
opc_92= TODO
opc_93= TODO
opc_94= TODO
opc_95= TODO
opc_96= TODO
opc_97= TODO
opc_98= TODO
opc_99= TODO
opc_9A= TODO
opc_9B= TODO
opc_9C= TODO
opc_9D= TODO
opc_9E= TODO
opc_9F= TODO
opc_A0:	OPC_LOGICOP_GEN AND, cpu_b,and_f_tab	; AND A,B
opc_A1:	OPC_LOGICOP_GEN AND, cpu_c,and_f_tab	; AND A,C
opc_A2: OPC_LOGICOP_GEN AND, cpu_d,and_f_tab	; AND A,D
opc_A3: OPC_LOGICOP_GEN AND, cpu_e,and_f_tab	; AND A,E
opc_A4: OPC_LOGICOP_GEN AND, cpu_h,and_f_tab	; AND A,H
opc_A5: OPC_LOGICOP_GEN AND, cpu_l,and_f_tab	; AND A,L
opc_A6:	OPC_LOGICOP_GEN AND32Z, cpu_hl,and_f_tab ; AND A,(HL)
opc_A7: OPC_LOGICOP_GEN AND, cpu_a,and_f_tab	; AND A,A
opc_A8:	OPC_LOGICOP_GEN EOR, cpu_b,szp_f_tab	; XOR A,B
opc_A9:	OPC_LOGICOP_GEN EOR, cpu_c,szp_f_tab	; XOR A,C
opc_AA: OPC_LOGICOP_GEN EOR, cpu_d,szp_f_tab	; XOR A,D
opc_AB: OPC_LOGICOP_GEN EOR, cpu_e,szp_f_tab	; XOR A,E
opc_AC: OPC_LOGICOP_GEN EOR, cpu_h,szp_f_tab	; XOR A,H
opc_AD: OPC_LOGICOP_GEN EOR, cpu_l,szp_f_tab	; XOR A,L
opc_AE:	OPC_LOGICOP_GEN EOR32Z, cpu_hl,szp_f_tab	; XOR A,(HL)
opc_AF: OPC_LOGICOP_GEN EOR, cpu_a,szp_f_tab	; XOR A,A
opc_B0:	OPC_LOGICOP_GEN ORA, cpu_b,szp_f_tab	; OR A,B
opc_B1:	OPC_LOGICOP_GEN ORA, cpu_c,szp_f_tab	; OR A,C
opc_B2: OPC_LOGICOP_GEN ORA, cpu_d,szp_f_tab	; OR A,D
opc_B3: OPC_LOGICOP_GEN ORA, cpu_e,szp_f_tab	; OR A,E
opc_B4: OPC_LOGICOP_GEN ORA, cpu_h,szp_f_tab	; OR A,H
opc_B5: OPC_LOGICOP_GEN ORA, cpu_l,szp_f_tab	; OR A,L
opc_B6:	OPC_LOGICOP_GEN ORA32Z, cpu_hl,szp_f_tab	; OR A,(HL)
opc_B7: OPC_LOGICOP_GEN ORA, cpu_a,szp_f_tab	; OR A,A
opc_B8= TODO	; CP B
opc_B9= TODO	; CP C
opc_BA= TODO	; CP D
opc_BB= TODO	; CP E
opc_BC= TODO	; CP H
opc_BD= TODO	; CP L
opc_BE= TODO	; CP (HL)
opc_BF= TODO	; CP A
opc_C0= opc_RET_NZ			; RET NZ
opc_C1:	OPC_POP_RR	cpu_bc		; POP BC
opc_C2= opc_JP_NZ			; JP NZ,nn
opc_C3= opc_JP				; JP nn
opc_C4= opc_CALL_NZ			; CALL NZ
opc_C5:	OPC_PUSH_RR	cpu_bc		; PUSH BC
opc_C6:	INW		cpu_pc		; ADD A,n
	OPC_ADD_A_R	ADC32Z, cpu_pc
opc_C7:	OPC_RST		$00		; RST 00h
opc_C8= opc_RET_Z			; RET Z
opc_C9= opc_RET				; RET
opc_CA= opc_JP_Z			; JP Z
opc_CB= opc_JP				; *NON-STANDARD* JP nn	[CB-prefix on Z80]
opc_CC= opc_CALL_Z			; CALL Z,nn
opc_CD= opc_CALL			; CALL nn
opc_CE:	INW		cpu_pc		; ADC A,n
	OPC_ADD_A_R	ADC32Z, cpu_pc
opc_CF:	OPC_RST		$08		; RST 08h
opc_D0= opc_RET_NC			; RET NC
opc_D1:	OPC_POP_RR	cpu_de		; POP DE
opc_D2= opc_JP_NC			; JP NC,nn
opc_D3= TODO				; OUT (n),A
opc_D4= opc_CALL_NC			; CALL NZ,nn
opc_D5:	OPC_PUSH_RR	cpu_de		; PUSH DE
opc_D6= TODO				; SUB A,byte
opc_D7:	OPC_RST		$10		; RST 10h
opc_D8= opc_RET_C			; RET C
opc_D9= opc_RET				; *NON-STANDARD* RET		[EXX on Z80]
opc_DA= opc_JP_C			; JP C,nn
opc_DB= TODO				; IN A,(n)
opc_DC= opc_CALL_C			; CALL C,nn
opc_DD= opc_CALL			; *NON-STANDARD* CALL nn	[DD-prefix on Z80]
opc_DE= TODO				; SBC A,byte
opc_DF:	OPC_RST		$18		; RST 18h
opc_E0= opc_RET_PO			; RET PO
opc_E1:	OPC_POP_RR	cpu_hl		; POP HL
opc_E2= opc_JP_PO			; JP PO,nn
opc_E3:					; EX (SP),HL
	LDA32Z	cpu_sp	; (SP)<->L
	LDX	cpu_l
	STA	cpu_l
	TXA
	STA32Z	cpu_sp
	INZ		; Z = 1, next LDA32Z will access (zp pointer)+1
	LDA32Z	cpu_sp	; (SP+1)<->H
	LDX	cpu_h
	STA	cpu_h
	TXA
	STA32Z	cpu_sp
	DEZ		; restore Z=0 ...
	JMP	next_inc1
opc_E4= opc_CALL_PO			; CALL PO,nn
opc_E5:	OPC_PUSH_RR	cpu_hl		; PUSH HL
opc_E6:	INW		cpu_pc		; AND A,n
	OPC_LOGICOP_GEN AND32Z, cpu_pc, and_f_tab
opc_E7:	OPC_RST		$20		; RST 20h
opc_E8= opc_RET_PE			; RET PE
opc_E9:					; JP (HL), though JP HL is what it actually does, 8080 syntax is better this time I think: PCHL
	LDA	cpu_l
	STA	cpu_pcl
	LDA	cpu_h
	STA	cpu_pch
	JMP	next_no_inc
opc_EA= opc_JP_PE			; JP PE,nn
opc_EB:					; EX DE,HL
	LDA	cpu_l
	LDX	cpu_e
	STA	cpu_e
	STX	cpu_l
	LDA	cpu_h
	LDX	cpu_d
	STA	cpu_d
	STX	cpu_h
	JMP	next_inc1
opc_EC= opc_CALL_PE			; CALL PE,nn
opc_ED= opc_CALL			; *NON-STANDARD* CALL nn	[ED-prefix on Z80]
opc_EE:	INW		cpu_pc		; XOR A,n
	OPC_LOGICOP_GEN EOR32Z, cpu_pc, szp_f_tab
opc_EF:	OPC_RST		$28		; RST 28h
opc_F0= opc_RET_P			; RET P
opc_F1:	OPC_POP_RR	cpu_af		; POP AF
opc_F2= opc_JP_P			; JP P,nn
opc_F3= next_inc1			; DI	!!INTERRUPTS ARE NOT EMULATED!!
opc_F4= opc_CALL_P			; CALL P,nn
opc_F5:	OPC_PUSH_RR	cpu_af		; PUSH AF
opc_F6:	INW		cpu_pc		; OR A,n
	OPC_LOGICOP_GEN ORA32Z, cpu_pc, szp_f_tab
opc_F7:	OPC_RST		$30		; RST 30h
opc_F8= opc_RET_M			; RET M
opc_F9:					; LD SP,HL
	LDA	cpu_l
	STA	cpu_spl
	LDA	cpu_h
	STA	cpu_sph
	JMP	next_inc1
opc_FA= opc_JP_M			; JP M,nn
opc_FB= next_inc1			; EI	!!INTERRUPTS ARE NOT EMULATED!!
opc_FC= opc_CALL_M			; CALL M,nn
opc_FD= opc_CALL			; *NON-STANDARD* CALL nn	[FD-prefix on Z80]
opc_FE= TODO				; CP n
opc_FF:	OPC_RST		$38		; RST 38h


; Call this to start to execute 8080 code. About 8080 memory position see comments at cpu_reset.
; CPU emulator returns, in case of HALT opcode or any not yet emulated opcode.
; About these, please read comments at cpu_leave and cpu_unimplemented.
.EXPORT	cpu_start
cpu_start:
	LDZ	#0		; we use Z=0 in *most* cases through the CPU emulation (it may be set temporarly to other values but it is reset then to zero ASAP!)
	JMP	next_no_inc


.EXPORT cpu_reset
cpu_reset:
	LDX	#cpu_last - cpu_first - 1
	LDA	#0
:	STA	cpu_first,X
	DEX
	BPL	:-
	; "2" as "H16"s: we use the "ROM" of M65 as 8080 memory. That is writable (if enabled) on M65 and with zero wait states, good enough!
	; Reason: we need a 64K aligned 64K (and linearly!), the first 64K of RAM cannot be used since 0/1 addresses are the CPU port.
	; The second 64K of RAM would be ok, but then, colour RAM is a bit problematic (if we want to use that area for VIC colour RAM) and
	; also one wait state for colour RAM. However what is ROM on the C65, on M65 that is writable! So basically it's RAM, and zero
	; wait state, and no disturbing fixed functionality there like colour RAM or CPU port. So we want to use this!
	; The most significant byte of linear address is zero already (see above the clear loop of ZP locs!)
	LDA	#2
	STA	cpu_bc_H16
	STA	cpu_de_H16
	STA	cpu_hl_H16
	STA	cpu_pc_H16
	STA	cpu_sp_H16
	STA	cpu_mem_p_H16
	; CPU flags on 8080 has an unused always '1' item
	LDA	#2
	STA	cpu_f
	RTS
	
; Please see comments at cpu_leave! The same things.
; Just this is one jumped on, if an opcode emulation is not implemented.
TODO = cpu_unimplemented
cpu_unimplemented:
	TXA
	ROR	A
	STA	cpu_op
	SEC		; set carry to signal unimplemented status
	RTS
	
; This is used if an opcode "dispatches" the control. Like HALT.
; Note: if you want to continue, you need to increment cpu_pc by your own before calling cpu_start again!
; this is true for cpu_unimplemented as well
cpu_leave:
	TXA			; (see next op), though A should contain the same as X, just to be sure anyway ...
	ROR	A		; Restore original opcode to report for the caller, A still holds the ASL'ed opcode, and carry should be the old 7th bit of the opcode
	STA	cpu_op
	CLC			; the opposite situation done in cpu_unimplemented, please see there
	RTS			; return. caller gets control back here (cpu_start was called) A contains the opcode caused exit, cpu_pc is the PC of opcode
