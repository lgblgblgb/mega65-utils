TEST_PROGRAMS	= dmatest64.prg dmatest65.prg
DISK_IMAGE	= c65tests.d81
DISK_NAME	= "lgb-test,00"
CL65		= cl65
C1541		= c1541

all: $(DISK_IMAGE)

dmatest64.prg: dmatest.a65
	@rm -f dmatest.o
	$(CL65) -t none -o $@ $<
	@rm -f dmatest.o
dmatest65.prg: dmatest.a65
	@rm -f dmatest.o
	$(CL65) -t none --asm-define C65_MODE -o $@ $<
	@rm -f dmatest.o

$(DISK_IMAGE): $(TEST_PROGRAMS)
	rm -f $@
	( echo "format $(DISK_NAME) d81 $(DISK_IMAGE)" ; for a in $(TEST_PROGRAMS) ; do echo "write $$a `basename $$a .prg`" ; done ; echo -e "version\nvalidate\ndir" ) | $(C1541)
	ls -l $(DISK_IMAGE)

publish: $(DISK_IMAGE) $(TEST_PROGRAMS)
	cp $(DISK_IMAGE) $(TEST_PROGRAMS) bin/
	git status bin/

clean:
	rm -f *.o $(TEST_PROGRAMS) $(DISK_IMAGE)

.PHONY: all clean publish
