all: test.prg

test.prg: test.a65 Makefile
	cl65 -o test.prg --listing test.lst -t none test.a65

xemu: test.prg
	xemu-xmega65 -prg test.prg -skipunhandledmem

m65: test.prg
	m65 -F -4 -r test.prg

clean:
	rm -f test.prg mega65-screen-*.png *.lst *.o dump.mem

publish: test.prg
	cp $< bin/mega65info.prg

.PHONY: all xemu m65 clean publish

