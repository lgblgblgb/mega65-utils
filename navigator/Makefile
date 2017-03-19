all: navigator.d81

navigator.o: navigator.asm Makefile
	ca65 -t none -o navigator.o navigator.asm

navigator.prg: navigator.o navigator.ld Makefile
	ld65 -C navigator.ld -o navigator.prg navigator.o

navigator.d81: navigator.prg Makefile
	rm -f navigator.d81
	echo format navigator,00 d81 navigator.d81 | c1541
	echo write navigator.prg navigator | c1541 navigator.d81

test: navigator.d81 Makefile ../KICKUP.M65 ../sdcard.img
	$(MAKE) navigator.snap
	xemu-xmega65 -8 navigator.d81 -snapload navigator.snap -kickup ../KICKUP.M65 -sdimg ../sdcard.img -kicked 255

navigator.snap:
	$(MAKE) navigator.d81
	@echo "**** NO Xemu snapshot for testing"
	@echo "**** We will create one for you."
	@echo "Please let Xemu/M65 run, and answer for external disk image"
	@echo 'After boot, type this, WITHOUT pressing enter/return: RUN"NAVIGATOR"'
	@echo "Then, just press F9 to exit (and no enter/return key, again)."
	@echo "This will write a snapshot file, so next time you will need"
	@echo "only to hit ENTER to test the new navigator version without"
	@echo "waiting for M65 to boot, or whatever."
	@echo "**** Please hit ENTER now to proceed the described task"
	@read some
	xemu-xmega65 -8 navigator.d81 -snapsave navigator.snap -kickup ../KICKUP.M65 -sdimg ../sdcard.img -kicked 255

clean:
	rm -f navigator.prg *.o navigator.d81 uart.sock dump.mem debug.log

../KICKUP.M65:
	wget -O ../KICKUP.M65 http://github.lgb.hu/xemu/files/KICKUP.M65

../sdcard.img:
	wget -O ../sdcard.img.gz http://github.lgb.hu/xemu/files/sd-card-image-for-xemu-xmega65.img.gz
	gunzip ../sdcard.img.gz

distclean:
	$(MAKE) clean
	rm -f navigator.snap

.PHONY: all clean distclean test

