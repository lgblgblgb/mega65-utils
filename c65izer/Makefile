all: disk.d81

c65izer.o: c65izer.asm Makefile
	ca65 -t none c65izer.asm

c65izer: c65izer.o c65izer.cfg Makefile
	ld65 -C c65izer.cfg -o c65izer c65izer.o

equinoxe-c65: equinoxe-c64 c65izer Makefile
	cat c65izer equinoxe-c64 > equinoxe-c65

disk.d81: equinoxe-c64 equinoxe-c65 Makefile
	cbmconvert -D8o disk.d81 equinoxe-c64 equinoxe-c65

test: disk.d81 Makefile
	xemu-xc65 -8 disk.d81

clean:
	rm -f equinoxe-c65 disk.d81 c65izer *.o

.PHONY: clean test
