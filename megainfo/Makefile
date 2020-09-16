test.prg: test.a65 Makefile
	cl65 -o test.prg --listing test.lst -t none test.a65

xemu: test.prg
	xemu-xmega65 -prg test.prg -skipunhandledmem

m65: test.prg
	m65 -F -4 -r test.prg

.PHONY: xemu m65

