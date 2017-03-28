; Little CP/M utility to display CP/M version and
; some information, to test my emulator.
; Note: currently it's coded in an odd way, to
; bridge problems present in my 8080 emulator.

	ORG	0x100

	LD	SP,0x100
	LD	HL,text
	CALL	print_string
	LD	HL,0x89AB
	CALL	print_hex_word
	LD	SP,0xFFFF ; now we signal exit with SP ;-P
	HALT


text:
	DB	"Hi, this is a simple CP/M program (for 8080 CPU), CPMVER.COM ",13,10,"89AB=",0


; We use our OWN function by will.
print_string:
.loop:
	LD	A,(HL)
	OR	A
	RET	Z
	INC	HL
	CALL	print_char
	JP	.loop


print_hex_word:
	PUSH	HL
	LD	A,H
	CALL	print_hex_byte
	POP	HL
	LD	A,L
print_hex_byte:
	PUSH	AF
	[4]RRCA
	CALL	print_hex_nib
	POP	AF
print_hex_nib:
	AND	15
	LD	B,0
	LD	C,A
	LD	HL,hextab
	ADD	HL,BC
	LD	A,(HL)
print_char:
	HALT
	RET


hextab:
	DB	'0123456789ABCDEF'


