#!/usr/bin/env python

inc8_f_tab = [None] * 0x100
dec8_f_tab = [None] * 0x100
szp_f_tab  = [None] * 0x100
and_f_tab  = [None] * 0x100


S_FLAG = 128
Z_FLAG = 64
H_FLAG = 16
P_FLAG = 4
C_FLAG = 1



def get_parity(n):
	result = 0
	for a in range(8):
		result += n & 1
		n >>= 1
	return 0 if result & 1 else P_FLAG



for i in range(0x100):
	inc8_f_tab[i] = dec8_f_tab[i] = i & 128		# MSB of result is the sign flag directly
	if i == 0:
		inc8_f_tab[i] |= Z_FLAG
		dec8_f_tab[i] |= Z_FLAG
	if (i & 0xF) == 0:
		inc8_f_tab[i] |= H_FLAG
	if not ((i & 0xF) == 0xF):
		dec8_f_tab[i] |= H_FLAG
	inc8_f_tab[i] |= get_parity(i)
	dec8_f_tab[i] |= get_parity(i)
	# SZP table
	szp_f_tab[i] = (i & 128) | get_parity(i) | (Z_FLAG if i == 0 else 0)
	# AND table
	and_f_tab[i] = szp_f_tab[i] | H_FLAG


def dump_table(tab, name, do_flags_filt):
	s = name + ":\n"
	for i in range(0x100):
		if do_flags_filt:
			c = tab[i] & 215 | 2
		else:
			c = tab[i]
		if not (i & 0xF):
			s += "\t.BYTE "
		s += str(c) + ("," if (i & 0xF) != 0xF else "\n")
	print(s)



#print([get_parity(n) for n in range(0x100)])
#dump_table([get_parity(n) for n in range(0x100)], "parity", False)

dump_table(inc8_f_tab, "inc8_f_tab", True)
dump_table(dec8_f_tab, "dec8_f_tab", True)
dump_table(szp_f_tab, "szp_f_tab", True)
dump_table(and_f_tab, "and_f_tab", True)


