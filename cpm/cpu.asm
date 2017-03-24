; ----------------------------------------------------------------------------
; Software emulator of a 8080 CPU for the Mega-65.
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
; *NOTE*: Though this is a 8080 emulator, and not Z80, I still prefer (and
; know) Z80 asm syntax better than 8080, so I will use that terminology! Also,
; the intent, that some day, maybe this can become a Z80 emulator as well,
; though that needs more work ...
;
; ----------------------------------------------------------------------------


.SETCPU "4510"

.ZEROPAGE

; Must be before the first CPU specific ZP label
cpu_first:
; Register pair AF (PSW), not used for indexing, no need for "H16":
cpu_af:
cpu_f:		.RES 1
cpu_a:		.RES 1
; Register pair BC
cpu_bc:
cpu_c:		.RES 1
cpu_b:		.RES 1
cpu_bc_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Register pair DE
cpu_de:
cpu_e:		.RES 1
cpu_d:		.RES 1
cpu_de_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Register pair HL
cpu_hl:
cpu_l:		.RES 1
cpu_h:		.RES 1
cpu_hl_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; The program counter
cpu_pc:
cpu_pcl:	.RES 1
cpu_pch:	.RES 1
cpu_pc_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Stack pointer
cpu_sp:
cpu_spl:	.RES 1
cpu_sph:	.RES 1
cpu_sp_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Memory pointer, used in operations like (1234)
cpu_mem_p:
cpu_mem_l:	.RES 1
cpu_mem_h:	.RES 1
cpu_mem_p_H16:	.RES 2	; high 16 bit address for 8080 memory base [32 bit linear]
; Must be after the last CPU specific ZP label
cpu_last:


.CODE



; Mega-65 32 bit linear ops

.MACRO	LDA32Z	zploc
	EOM
	LDA	(zploc),Z
.ENDMACRO
.MACRO	STA32Z	zploc
	EOM
	STA	(zploc),Z
.ENDMACRO

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





.MACRO	opc_LD_R_N target
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	z:target
	JMP	next_inc1
.ENDMACRO


.MACRO	opc_LD_R_R target,source
	LDA	z:source
	STA	z:target
	JMP	next_inc1
.ENDMACRO
.MACRO	opc_LD_R_RI reg, regpair
	LDA32Z	regpair
	STA	z:reg
	JMP	next_inc1
.ENDMACRO
.MACRO	opc_LD_RI_R regpair, reg
	LDA	z:reg
	STA32Z	regpair
	JMP	next_inc1
.ENDMACRO

.MACRO	opc_LD_RR_NN regpair
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	z:regpair
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA	z:regpair+1
	JMP	next_inc1
.ENDMACRO

.MACRO	opc_LD_RI_N regpair
	INW	cpu_pc
	LDA32Z	cpu_pc
	STA32Z	regpair
	JMP	next_inc1
.ENDMACRO


.MACRO	opc_PUSH_RR regpair
	PUSH_RP	regpair
	JMP	next_inc1
.ENDMACRO

.MACRO	opc_POP_RR regpair
	POP_RP	regpair
	JMP	next_inc1
.ENDMACRO

.MACRO	opc_INC_RR regpair
	INW	z:regpair
	JMP	next_inc1
.ENDMACRO
.MACRO	opc_DEC_RR regpair
	DEW	z:regpair
	JMP	next_inc1
.ENDMACRO

; Z80ex says: value++; F = ( F & FLAG_C ) | ( (value)==0x80 ? FLAG_V : 0 ) | ( (value)&0x0f ? 0 : FLAG_H ) | sz53_table[(value)];
.MACRO	opc_INC_R reg
	LDX	z:reg
	INX
	STX	z:reg
	LDA	cpu_f
	AND	#1			; keep only carry flag from flags
	ORA	inc8_flags_tab,X
	STA	cpu_f
	JMP	next_inc1
.ENDMACRO

; Z80ex says: F = ( F & FLAG_C ) | ( (value)&0x0f ? 0 : FLAG_H ) | FLAG_N; (value)--; F |= ( (value)==0x7f ? FLAG_V : 0 ) | sz53_table[value];
.MACRO	opc_DEC_R reg
	LDX	z:reg
	DEX
	STX	z:reg
	LDA	indec_flags_tab,X
	STA	cpu_f
	JMP	next_inc1
.ENDMACRO

.MACRO	opc_RST	vector
	INW	cpu_pc
	PUSH_RR	cpu_pc
	STZ	cpu_pch		; Z must be zero, so high address of PC will be zero
	LDA	#vector
	STA	cpu_pcl		; set low byte of PC
	JMP	next_no_inc
.ENDMACRO




; User needs to use MEMCONSTPTROP_END at the end to restore Z
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
.MACRO	BR_AUX label
	BBS4	cpu_f, label
.ENDMACRO
.MACRO	BR_NAUX label
	BBR4	cpu_f, label
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





; *** Main opcode fetch, and instruction "decoding" by jump table
next_inc3:
	INW	cpu_pc
next_inc2:
	INW	cpu_pc
next_inc1:
	INW	cpu_pc
next_no_inc:
	LDA32Z	cpu_pc
	ASL	A
	TAX
	BCC	@ops_low_half
	JMP	(opcode_jump_tab+$100,X)
@ops_low_half:
	JMP	(opcode_jump_tab,X)

NO_OP	= next_inc1



opcode_jump_tab:
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


opc_00 = NO_OP				; NOP	(no-effect opcodes can refeer for the main opcode fetch entry point itself, simply ...)
opc_01:	opc_LD_RR_NN	cpu_bc		; LD BC,nn
opc_02:	opc_LD_RI_R	cpu_bc, cpu_a	; LD (BC),A
opc_03:	opc_INC_RR	cpu_bc		; INC BC, 8080 syntax: INX B
opc_04: opc_INC_R	cpu_b		; INC B
opc_05: opc_DEC_R	cpu_b		; DEC B
opc_06:	opc_LD_R_N	cpu_b		; LD B,n
opc_07	= TODO				; RLCA
opc_08	= NO_OP				; *NON-STANDARD* NOP	[EX AF,AF' on Z80]
opc_09	= TODO				; ADD HL,BC
opc_0A:	opc_LD_R_RI	cpu_a, cpu_bc	; LD A,(BC)
opc_0B:	opc_DEC_RR	cpu_bc		; DEC BC
opc_0C: opc_INC_R	cpu_c		; INC C
opc_0D: opc_DEC_R	cpu_c		; DEC C
opc_0E:	opc_LD_R_N	cpu_c		; LD C,n
opc_0F	= TODO				; RRCA
opc_10	= NO_OP				; *NON-STANDARD* NOP	[DJNZ on Z80]
opc_11: opc_LD_RR_NN	cpu_de		; LD DE,nn
opc_12: opc_LD_RI_R	cpu_de, cpu_a	; LD (DE),A
opc_13:	opc_INC_RR	cpu_de		; INC DE
opc_14: opc_INC_R	cpu_d		; INC D
opc_15: opc_DEC_R	cpu_d		; DEC D
opc_16: opc_LD_R_N	cpu_d		; LD D,n
opc_17	= TODO				; RLA
opc_18	= NO_OP				; *NON-STANDARD* NOP	[JR on Z80]
opc_19	= TODO				; ADD HL,DE
opc_1A: opc_LD_R_RI	cpu_a, cpu_de	; LD A,(DE)
opc_1B:	opc_DEC_RR	cpu_de		; DEC DE
opc_1C: opc_INC_R	cpu_e		; INC E
opc_1D: opc_DEC_R	cpu_e		; DEC E
opc_1E:	opc_LD_R_N	cpu_e		; LD E,n
opc_1F	= TODO				; RRA
opc_20	= NO_OP				; *NON-STANDARD* NOP	[JR NZ on Z80]
opc_21: opc_LD_RR_NN	cpu_hl		; LD HL,nn
opc_22:					; LD (nn),HL
	MEMCONSTPTROP_BEGIN
	LDA	cpu_l
	STA32Z	cpu_mem_p
	INZ
	LDA	cpu_h
	STA32Z	cpu_mem_p
	DEZ		; Z=0 again!!!
	MEMCONSTPTROP_END
opc_23:	opc_INC_RR	cpu_hl		; INC HL
opc_24: opc_INC_R	cpu_h		; INC H
opc_25: opc_DEC_R	cpu_h		; DEC H
opc_26:	opc_LD_R_N	cpu_h		; LD H,n
opc_27	= TODO				; DAA
opc_28	= NO_OP				; *NON-STANDARD* NOP	[JR Z on Z80]
opc_29	= TODO				; ADD HL,HL
opc_2A:					; LD HL,(nn)
	MEMCONSTPTROP_BEGIN	
	LDA32Z	cpu_mem_p
	STA	cpu_l
	INZ
	LDA32Z	cpu_mem_p
	STA	cpu_h
	DEZ		; Z=0 again!!!
	MEMCONSTPTROP_END
opc_2B:	opc_DEC_RR	cpu_hl		; DEC HL
opc_2C: opc_INC_R	cpu_l		; INC L
opc_2D: opc_DEC_R	cpu_l		; DEC L
opc_2E:	opc_LD_R_N	cpu_l		; LD L,n
opc_2F	= TODO				; CPL
opc_30	= NO_OP				; *NON-STANDARD* NOP	[JR NC on Z80]
opc_31: opc_LD_RR_NN	cpu_sp		; LD SP,nn
opc_32:					; LD (nn),A
	MEMCONSTPTROP_BEGIN
	LDA	cpu_a
	STA32Z	cpu_mem_p
	MEMCONSTPTROP_END
opc_33:	opc_INC_RR	cpu_sp		; INC SP
opc_34	= TODO				; INC (HL)
opc_35	= TODO				; DEC (HL)
opc_36:	opc_LD_RI_N	cpu_hl		; LD (HL),n
opc_37	= TODO				; SCF
opc_38	= NO_OP				; *NON-STANDARD* NOP	[JR C on Z80]
opc_39	= TODO				; ADD HL,SP
opc_3A:					; LD A,(nn)
	MEMCONSTPTROP_BEGIN
	LDA32Z	cpu_mem_p
	STA	cpu_a
	MEMCONSTPTROP_END
opc_3B:	opc_DEC_RR	cpu_sp		; DEC SP
opc_3C: opc_INC_R	cpu_a		; INC A
opc_3D: opc_DEC_R	cpu_a		; DEC A
opc_3E: opc_LD_R_N	cpu_a		; LD A,n
opc_3F	= TODO				; CCF
opc_40	= NO_OP				; LD B,B *DOES NOTHING*
opc_41:	opc_LD_R_R	cpu_b, cpu_c	; LD B,C
opc_42:	opc_LD_R_R	cpu_b, cpu_d	; LD B,D
opc_43:	opc_LD_R_R	cpu_b, cpu_e	; LD B,E
opc_44:	opc_LD_R_R	cpu_b, cpu_h	; LD B,H
opc_45:	opc_LD_R_R	cpu_b, cpu_l	; LD B,L
opc_46:	opc_LD_R_RI	cpu_b, cpu_hl	; LD B,(HL)
opc_47:	opc_LD_R_R	cpu_b, cpu_a	; LD B,A
opc_48:	opc_LD_R_R	cpu_c, cpu_b	; LD C,B
opc_49	= NO_OP				; LD C,C *DOES NOTHING*
opc_4A:	opc_LD_R_R	cpu_c, cpu_d	; LD C,D
opc_4B:	opc_LD_R_R	cpu_c, cpu_e	; LD C,E
opc_4C:	opc_LD_R_R	cpu_c, cpu_h	; LD C,H
opc_4D:	opc_LD_R_R	cpu_c, cpu_l	; LD C,L
opc_4E:	opc_LD_R_RI	cpu_c, cpu_hl	; LD C,(HL)
opc_4F:	opc_LD_R_R	cpu_c, cpu_a	; LD C,A
opc_50: opc_LD_R_R	cpu_d, cpu_b	; LD D,B
opc_51:	opc_LD_R_R	cpu_d, cpu_c	; LD D,C
opc_52	= NO_OP				; LD D,D *DOES NOTHING*
opc_53:	opc_LD_R_R	cpu_d, cpu_e	; LD D,E
opc_54:	opc_LD_R_R	cpu_d, cpu_h	; LD D,H
opc_55:	opc_LD_R_R	cpu_d, cpu_l	; LD D,L
opc_56:	opc_LD_R_RI	cpu_d, cpu_hl	; LD D,(HL)
opc_57:	opc_LD_R_R	cpu_d, cpu_a	; LD D,A
opc_58:	opc_LD_R_R	cpu_e, cpu_b	; LD E,B
opc_59:	opc_LD_R_R	cpu_e, cpu_c	; LD E,C
opc_5A:	opc_LD_R_R	cpu_e, cpu_d	; LD E,D
opc_5B	= NO_OP				; LD E,E *DOES NOTHING*
opc_5C:	opc_LD_R_R	cpu_e, cpu_h	; LD E,H
opc_5D:	opc_LD_R_R	cpu_e, cpu_l	; LD E,L
opc_5E:	opc_LD_R_RI	cpu_e, cpu_hl	; LD E,(HL)
opc_5F:	opc_LD_R_R	cpu_e, cpu_a	; LD E,A
opc_60: opc_LD_R_R	cpu_h, cpu_b	; LD H,B
opc_61:	opc_LD_R_R	cpu_h, cpu_c	; LD H,C
opc_62:	opc_LD_R_R	cpu_h, cpu_d	; LD H,D
opc_63:	opc_LD_R_R	cpu_h, cpu_e	; LD H,E
opc_64	= NO_OP				; LD H,H *DOES NOTHING*
opc_65:	opc_LD_R_R	cpu_h, cpu_l	; LD H,L
opc_66:	opc_LD_R_RI	cpu_h, cpu_hl	; LD H,(HL)
opc_67:	opc_LD_R_R	cpu_h, cpu_a	; LD H,A
opc_68:	opc_LD_R_R	cpu_l, cpu_b	; LD L,B
opc_69:	opc_LD_R_R	cpu_l, cpu_c	; LD L,C
opc_6A:	opc_LD_R_R	cpu_l, cpu_d	; LD L,D
opc_6B:	opc_LD_R_R	cpu_l, cpu_e	; LD L,E
opc_6C:	opc_LD_R_R	cpu_l, cpu_h	; LD L,H
opc_6D	= NO_OP				; LD L,L *DOES NOTHING*
opc_6E:	opc_LD_R_RI	cpu_l, cpu_hl	; LD L,(HL)
opc_6F:	opc_LD_R_R	cpu_l, cpu_a	; LD L,A
opc_70: opc_LD_RI_R	cpu_hl, cpu_b	; LD (HL),B
opc_71:	opc_LD_RI_R	cpu_hl, cpu_c	; LD (HL),C
opc_72:	opc_LD_RI_R	cpu_hl, cpu_d	; LD (HL),D
opc_73:	opc_LD_RI_R	cpu_hl, cpu_e	; LD (HL),E
opc_74:	opc_LD_RI_R	cpu_hl, cpu_h	; LD (HL),H
opc_75:	opc_LD_RI_R	cpu_hl, cpu_l	; LD (HL),L
opc_76 = cpu_leave			; *HALT*
opc_77:	opc_LD_RI_R	cpu_hl, cpu_a	; LD (HL),A
opc_78:	opc_LD_R_R	cpu_a, cpu_b	; LD A,B
opc_79:	opc_LD_R_R	cpu_a, cpu_c	; LD A,C
opc_7A:	opc_LD_R_R	cpu_a, cpu_d	; LD A,D
opc_7B:	opc_LD_R_R	cpu_a, cpu_e	; LD A,E
opc_7C:	opc_LD_R_R	cpu_a, cpu_h	; LD A,H
opc_7D:	opc_LD_R_R	cpu_a, cpu_l	; LD A,L
opc_7E:	opc_LD_R_RI	cpu_a, cpu_hl	; LD A,(HL)
opc_7F	= NO_OP				; LD A,A *DOES NOTHING*
opc_80	= TODO
opc_81	= TODO
opc_82	= TODO
opc_83	= TODO
opc_84	= TODO
opc_85	= TODO
opc_86	= TODO
opc_87	= TODO
opc_88	= TODO
opc_89	= TODO
opc_8A	= TODO
opc_8B	= TODO
opc_8C	= TODO
opc_8D	= TODO
opc_8E	= TODO
opc_8F	= TODO
opc_90	= TODO
opc_91	= TODO
opc_92	= TODO
opc_93	= TODO
opc_94	= TODO
opc_95	= TODO
opc_96	= TODO
opc_97	= TODO
opc_98	= TODO
opc_99	= TODO
opc_9A	= TODO
opc_9B	= TODO
opc_9C	= TODO
opc_9D	= TODO
opc_9E	= TODO
opc_9F	= TODO
opc_A0	= TODO
opc_A1	= TODO
opc_A2	= TODO
opc_A3	= TODO
opc_A4	= TODO
opc_A5	= TODO
opc_A6	= TODO
opc_A7	= TODO
opc_A8	= TODO
opc_A9	= TODO
opc_AA	= TODO
opc_AB	= TODO
opc_AC	= TODO
opc_AD	= TODO
opc_AE	= TODO
opc_AF	= TODO
opc_B0	= TODO
opc_B1	= TODO
opc_B2	= TODO
opc_B3	= TODO
opc_B4	= TODO
opc_B5	= TODO
opc_B6	= TODO
opc_B7	= TODO
opc_B8	= TODO
opc_B9	= TODO
opc_BA	= TODO
opc_BB	= TODO
opc_BC	= TODO
opc_BD	= TODO
opc_BE	= TODO
opc_BF	= TODO
opc_C0	= opc_RET_NZ			; RET NZ
opc_C1	= TODO
opc_C2	= opc_JP_NZ			; JP NZ,nn
opc_C3	= opc_JP			; JP nn
opc_C4	= opc_CALL_NZ			; CALL NZ
opc_C5	= TODO
opc_C6	= TODO
opc_C7:	opc_RST	$00			; RST 00h
opc_C8	= opc_RET_Z			; RET Z
opc_C9	= opc_RET			; RET
opc_CA	= opc_JP_Z			; JP Z
opc_CB	= opc_JP			; *NON-STANDARD* JP nn	[CB-prefix on Z80]
opc_CC	= opc_CALL_Z			; CALL Z,nn
opc_CD	= opc_CALL			; CALL nn
opc_CE	= TODO
opc_CF:	opc_RST	$08			; RST 08h
opc_D0	= opc_RET_NC			; RET NC
opc_D1	= TODO
opc_D2	= opc_JP_NC			; JP NC,nn
opc_D3	= TODO
opc_D4	= opc_CALL_NC			; CALL NZ,nn
opc_D5	= TODO
opc_D6	= TODO
opc_D7:	opc_RST	$10			; RST 10h
opc_D8	= opc_RET_C			; RET C
opc_D9	= opc_RET			; *NON-STANDARD* RET		[EXX on Z80]
opc_DA	= opc_JP_C			; JP C,nn
opc_DB	= TODO
opc_DC	= opc_CALL_C			; CALL C,nn
opc_DD	= opc_CALL			; *NON-STANDARD* CALL nn	[DD-prefix on Z80]
opc_DE	= TODO
opc_DF:	opc_RST	$18			; RST 18h
opc_E0	= opc_RET_PO			; RET PO
opc_E1	= TODO
opc_E2	= opc_JP_PO			; JP PO,nn
opc_E3	= TODO
opc_E4	= opc_CALL_PO			; CALL PO,nn
opc_E5	= TODO
opc_E6	= TODO
opc_E7:	opc_RST	$20			; RST 20h
opc_E8	= opc_RET_PE			; RET PE
opc_E9:					; JP (HL), though JP HL is what it actually does, 8080 syntax is: PCHL
	LDA	cpu_l
	STA	cpu_pcl
	LDA	cpu_h
	STA	cpu_pch
	JMP	next_no_inc
opc_EA	= opc_JP_PE			; JP PE,nn
opc_EB	= TODO
opc_EC	= opc_CALL_PE			; CALL PE,nn
opc_ED	= opc_CALL			; *NON-STANDARD* CALL nn	[ED-prefix on Z80]
opc_EE	= TODO
opc_EF:	opc_RST	$28			; RST 28h
opc_F0	= opc_RET_P			; RET P
opc_F1	= TODO
opc_F2	= opc_JP_P			; JP P,nn
opc_F3	= TODO
opc_F4	= opc_CALL_P			; CALL P,nn
opc_F5	= TODO
opc_F6	= TODO
opc_F7:	opc_RST	$30			; RST 30h
opc_F8	= opc_RET_M			; RET M
opc_F9:					; LD SP,HL
	LDA	cpu_l
	STA	cpu_spl
	LDA	cpu_h
	STA	cpu_sph
	JMP	next_inc1
opc_FA	= opc_JP_M			; JP M,nn
opc_FB	= TODO
opc_FC	= opc_CALL_M			; CALL M,nn
opc_FD	= opc_CALL			; *NON-STANDARD* CALL nn	[FD-prefix on Z80]
opc_FE	= TODO
opc_FF:	opc_RST	$38			; RST 38h

	
.EXPORT	cpu_start
cpu_start = next_no_inc

.EXPORT cpu_reset
cpu_reset:
	LDX	#cpu_last - cpu_first - 1
	LDA	#0
:	STA	cpu_first,X
	DEX
	BPL	:-
	LDA	#1		; we use the second 64K of M65's memory for 8080 memory ... Yes, that includes colour RAM too, so care should be taken!
	STA	cpu_bc_H16
	STA	cpu_de_H16
	STA	cpu_hl_H16
	STA	cpu_pc_H16
	STA	cpu_sp_H16
	STA	cpu_mem_p_H16
	RTS
	
; Please see comments at cpu_leave! The same things.
; Just this is called if an opcode emulation is not implemented.
cpu_unimplemented:
	TXA
	ROR	A
	SEC		; set carry to signal unimplemented status
	RTS
	
; This is used if an opcode "dispatches" the control. Like HALT.
TODO = cpu_leave
cpu_leave:
	TXA			; (see next op), though A should contain the same as X, just to be sure anyway ...
	ROR	A		; Restore original opcode to report for the caller, A still holds the ASL'ed opcode, and carry should be the old 7th bit of the opcode
	CLC			; the opposite situation done in cpu_unimplemented, please see there
	RTS			; return. caller gets control back here (cpu_start was called) A contains the opcode caused exit, cpu_pc is the PC of opcode
